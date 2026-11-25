using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using HasibuBranchBridge.Models;

namespace HasibuBranchBridge.Crypto;

/// <summary>
/// Hasibu Dart <c>HasibuSecurityService.encryptSyncJsonPayload</c> ile bit-düzeyinde uyumlu
/// AES-256-GCM zarf şifreleme ve çözme motoru.
/// </summary>
public static class HasibuSyncCrypto
{
    private const string KeyContextLabel = "hasibu_drive_aes256_gcm";
    private const string VaultRole = "branch_inbox";
    private const string EnvelopeFormat = "hasibu_aes256_gcm_v1";
    private static readonly byte[] AadBytes = Encoding.UTF8.GetBytes($"hasibu-sync-v1:{VaultRole}");

    /// <summary>
    /// Aynı Google hesabında çalışan cihazların (mobil, masaüstü ve şube köprüsü) anahtar
    /// kopyalamadan otomatik çözümleyebilmesi için Dart <c>HasibuSecurityService.deriveAccountWorkspaceKey</c>
    /// ile bit-düzeyinde uyumlu PBKDF2-HMAC-SHA256 hesap anahtarı türetir.
    /// </summary>
    public static string DeriveAccountWorkspaceKey(string googleEmail, string? cloudProfileId = "default")
    {
        var cleanEmail = (googleEmail ?? string.Empty).Trim().ToLowerInvariant();
        var rawProfile = (cloudProfileId ?? string.Empty).Trim().ToLowerInvariant();
        var cleanProfile = string.IsNullOrEmpty(rawProfile) ? "default" : rawProfile;

        var passwordBytes = Encoding.UTF8.GetBytes($"{cleanEmail}|{cleanProfile}");
        var saltBytes = Encoding.UTF8.GetBytes($"hasibu-cloud-account-vault-v1:{cleanProfile}");
        var derived = Rfc2898DeriveBytes.Pbkdf2(
            passwordBytes,
            saltBytes,
            10_000,
            HashAlgorithmName.SHA256,
            32);
        return Convert.ToHexStringLower(derived);
    }

    /// <summary>
    /// Workspace anahtarından HMAC-SHA256 ile 256-bit AES anahtarı türetir.
    /// </summary>
    public static byte[] Derive256BitKey(string workspaceKey)
    {
        var trimmed = (workspaceKey ?? string.Empty).Trim();
        if (string.IsNullOrEmpty(trimmed))
        {
            throw new ArgumentException("Workspace Key boş olamaz.", nameof(workspaceKey));
        }

        using var hmac = new HMACSHA256(Encoding.UTF8.GetBytes(KeyContextLabel));
        return hmac.ComputeHash(Encoding.UTF8.GetBytes(trimmed));
    }

    /// <summary>
    /// Şube gelen kutusu verisini AES-256-GCM (<c>hasibu_aes256_gcm_v1</c>) zarfı olarak şifreler.
    /// </summary>
    public static string EncryptBranchInbox(
        BranchInboxPayload payload,
        string workspaceKey,
        string keyMode = "workspace_key")
    {
        var keyBytes = Derive256BitKey(workspaceKey);
        var normalizedPayload = payload with { VaultRole = VaultRole };
        var plainJson = JsonSerializer.Serialize(normalizedPayload, BridgeJsonContext.Default.BranchInboxPayload);
        var plainBytes = Encoding.UTF8.GetBytes(plainJson);

        var nonce = RandomNumberGenerator.GetBytes(12);
        var cipherBytes = new byte[plainBytes.Length];
        var tag = new byte[16];

        using (var aes = new AesGcm(keyBytes, tagSizeInBytes: 16))
        {
            aes.Encrypt(nonce, plainBytes, cipherBytes, tag, AadBytes);
        }

        var envelope = new BranchInboxEnvelope
        {
            Format = EnvelopeFormat,
            VaultRole = VaultRole,
            KeyMode = string.IsNullOrWhiteSpace(keyMode) ? "workspace_key" : keyMode.Trim(),
            EncryptedAt = DateTime.UtcNow.ToString("O"),
            Iv = Convert.ToBase64String(nonce),
            Tag = Convert.ToBase64String(tag),
            Ciphertext = Convert.ToBase64String(cipherBytes),
        };
        return JsonSerializer.Serialize(envelope, BridgeJsonContext.Default.BranchInboxEnvelope);
    }

    /// <summary>
    /// Şifreli şube gelen kutusu zarfını doğrular ve çözer.
    /// </summary>
    public static BranchInboxPayload DecryptBranchInbox(string rawEnvelope, string workspaceKey)
    {
        var envelope = JsonSerializer.Deserialize(rawEnvelope, BridgeJsonContext.Default.BranchInboxEnvelope)
            ?? throw new FormatException("Geçersiz şube kutusu zarfı.");

        if (!string.Equals(envelope.Format, EnvelopeFormat, StringComparison.Ordinal))
        {
            throw new FormatException($"Desteklenmeyen zarf biçimi: {envelope.Format}");
        }
        if (!string.Equals(envelope.VaultRole, VaultRole, StringComparison.Ordinal))
        {
            throw new InvalidOperationException($"Rol izolasyonu ihlali: {envelope.VaultRole}");
        }

        var keyBytes = Derive256BitKey(workspaceKey);
        var nonce = Convert.FromBase64String(envelope.Iv);
        var tag = Convert.FromBase64String(envelope.Tag);
        var cipherBytes = Convert.FromBase64String(envelope.Ciphertext);
        var plainBytes = new byte[cipherBytes.Length];

        using (var aes = new AesGcm(keyBytes, tagSizeInBytes: 16))
        {
            aes.Decrypt(nonce, cipherBytes, tag, plainBytes, AadBytes);
        }

        var clearJson = Encoding.UTF8.GetString(plainBytes);
        return JsonSerializer.Deserialize(clearJson, BridgeJsonContext.Default.BranchInboxPayload)
            ?? throw new FormatException("Çözülen şube kutusu içeriği boş.");
    }
}
