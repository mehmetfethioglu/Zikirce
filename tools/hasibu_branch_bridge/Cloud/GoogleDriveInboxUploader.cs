using System.Net;
using System.Net.Http.Headers;
using System.Text;
using System.Text.Json;
using System.Text.RegularExpressions;
using HasibuBranchBridge.Crypto;
using HasibuBranchBridge.Models;
using HasibuBranchBridge.Storage;

namespace HasibuBranchBridge.Cloud;

/// <summary>
/// Şube gelen kutusu paketini AES-256-GCM ile şifreleyip Google Drive v3 API'ye
/// (`hasibu_branch_inbox_&lt;slug&gt;.enc`) ve isteğe bağlı yerel Drive Masaüstü klasörüne yazar.
/// </summary>
public sealed partial class GoogleDriveInboxUploader : ICloudInboxUploader
{
    private const string BranchInboxPrefix = "hasibu_branch_inbox_";
    private const string DriveFilesEndpoint = "https://www.googleapis.com/drive/v3/files";
    private const string DriveUploadEndpoint = "https://www.googleapis.com/upload/drive/v3/files";

    private static readonly Dictionary<char, char> TurkishFoldMap = new()
    {
        ['ç'] = 'c', ['Ç'] = 'c',
        ['ğ'] = 'g', ['Ğ'] = 'g',
        ['ı'] = 'i', ['İ'] = 'i',
        ['ö'] = 'o', ['Ö'] = 'o',
        ['ş'] = 's', ['Ş'] = 's',
        ['ü'] = 'u', ['Ü'] = 'u',
    };

    private readonly DpapiSecretStore _secretStore;
    private readonly GoogleOAuthPkceClient _oauthClient;
    private readonly HttpClient _http;
    private readonly bool _ownsHttpClient;

    public GoogleDriveInboxUploader(
        DpapiSecretStore secretStore,
        GoogleOAuthPkceClient oauthClient,
        HttpClient? httpClient = null)
    {
        _secretStore = secretStore;
        _oauthClient = oauthClient;
        _ownsHttpClient = httpClient == null;
        _http = httpClient ?? new HttpClient { Timeout = TimeSpan.FromSeconds(15) };
    }

    public static string NormalizeCloudProfileId(string? raw)
    {
        var slug = FoldAndSanitizeSlug(raw, fallback: "default", maxLength: 32);
        return slug is "default" or "varsayilan" or "ana" ? "default" : slug;
    }

    public static string NormalizeDeviceSlug(string? raw) =>
        FoldAndSanitizeSlug(raw, fallback: "device", maxLength: 40);

    public static string GetBranchInboxFileName(string deviceSlug, string? profileId)
    {
        var cleanProfile = NormalizeCloudProfileId(profileId);
        var cleanSlug = NormalizeDeviceSlug(deviceSlug);
        return cleanProfile == "default"
            ? $"{BranchInboxPrefix}{cleanSlug}.enc"
            : $"{BranchInboxPrefix}{cleanProfile}__{cleanSlug}.enc";
    }

    public static string DetectDefaultGoogleDriveFolder()
    {
        var userProfile = Environment.GetFolderPath(Environment.SpecialFolder.UserProfile);
        var candidates = new List<string>
        {
            @"G:\Drive'ım",
            @"G:\My Drive",
        };
        if (!string.IsNullOrWhiteSpace(userProfile))
        {
            candidates.Add(Path.Combine(userProfile, "Google Drive"));
            candidates.Add(Path.Combine(userProfile, "GoogleDrive"));
            candidates.Add(Path.Combine(userProfile, "Drive'ım"));
        }

        foreach (var root in candidates)
        {
            if (Directory.Exists(root))
            {
                return Path.Combine(root, "Hasibu", "CloudSync");
            }
        }
        return string.Empty;
    }

    internal static (string WorkspaceKey, string KeyMode) ResolveEffectiveEncryptionKey(
        BridgeConfig config,
        BridgeSecrets secrets,
        string? resolvedEmail = null)
    {
        var profileId = NormalizeCloudProfileId(config.CloudProfileId);
        var email = (resolvedEmail ?? secrets.ConnectedEmail ?? string.Empty).Trim().ToLowerInvariant();

        if (!config.UseCustomWorkspaceKey && !string.IsNullOrEmpty(email))
        {
            return (HasibuSyncCrypto.DeriveAccountWorkspaceKey(email, profileId), "account_auto");
        }
        if (!string.IsNullOrWhiteSpace(secrets.WorkspaceKey))
        {
            return (secrets.WorkspaceKey.Trim(), "workspace_key");
        }
        if (!string.IsNullOrEmpty(email))
        {
            return (HasibuSyncCrypto.DeriveAccountWorkspaceKey(email, profileId), "account_auto");
        }
        return (string.Empty, string.Empty);
    }

    public async Task<InboxUploadResult> UploadBranchInboxAsync(
        BridgeConfig config,
        BranchInboxPayload payload,
        CancellationToken ct = default)
    {
        var secrets = _secretStore.Load();
        var accessToken = secrets.AccessToken.Trim();
        if (string.IsNullOrWhiteSpace(accessToken) && !string.IsNullOrWhiteSpace(secrets.RefreshToken))
        {
            accessToken = await _oauthClient.RefreshAccessTokenAsync(ct).ConfigureAwait(false) ?? string.Empty;
        }

        var resolvedEmail = secrets.ConnectedEmail;
        if (!config.UseCustomWorkspaceKey &&
            string.IsNullOrWhiteSpace(resolvedEmail) &&
            !string.IsNullOrWhiteSpace(accessToken))
        {
            resolvedEmail = await _oauthClient.ResolveAndCacheConnectedEmailAsync(accessToken, ct).ConfigureAwait(false);
        }

        var (effectiveKey, keyMode) = ResolveEffectiveEncryptionKey(config, secrets, resolvedEmail);
        if (string.IsNullOrWhiteSpace(effectiveKey))
        {
            return new InboxUploadResult(
                false,
                false,
                false,
                string.Empty,
                "Şifreleme anahtarı (account_auto veya Workspace Key) DPAPI kasasında bulunamadı (--setup çalıştırın).");
        }

        var fileName = GetBranchInboxFileName(config.DeviceSlug, config.CloudProfileId);
        var normalizedPayload = payload with
        {
            CloudProfileId = NormalizeCloudProfileId(config.CloudProfileId),
            DeviceSlug = NormalizeDeviceSlug(config.DeviceSlug),
        };
        var encryptedPayload = HasibuSyncCrypto.EncryptBranchInbox(normalizedPayload, effectiveKey, keyMode);

        var mirrorWritten = WriteLocalMirrorIfAvailable(config.LocalMirrorFolder, fileName, encryptedPayload);

        if (string.IsNullOrWhiteSpace(accessToken))
        {
            return new InboxUploadResult(
                mirrorWritten,
                false,
                mirrorWritten,
                fileName,
                mirrorWritten
                    ? $"OAuth belirteci yok; yalnızca yerel Drive klasörüne yazıldı ({fileName})."
                    : "Google Drive OAuth oturumu bulunamadı (--setup çalıştırın).",
                keyMode);
        }

        try
        {
            await UploadWithAutoRefreshAsync(accessToken, fileName, encryptedPayload, ct).ConfigureAwait(false);
            return new InboxUploadResult(
                true,
                true,
                mirrorWritten,
                fileName,
                $"Google Drive'a yüklendi ({fileName} • {normalizedPayload.AttendanceLogs.Count} hareket • {keyMode}).",
                keyMode);
        }
        catch (Exception ex)
        {
            return new InboxUploadResult(
                mirrorWritten,
                false,
                mirrorWritten,
                fileName,
                mirrorWritten
                    ? $"Bulut API hatası ({ex.Message}); yerel Drive klasörüne yazıldı."
                    : $"Google Drive yükleme hatası: {ex.Message}",
                keyMode);
        }
    }

    private async Task UploadWithAutoRefreshAsync(
        string initialToken,
        string fileName,
        string encryptedPayload,
        CancellationToken ct)
    {
        try
        {
            await UploadEncryptedFileCoreAsync(initialToken, fileName, encryptedPayload, ct).ConfigureAwait(false);
        }
        catch (HttpRequestException ex) when (ex.StatusCode == HttpStatusCode.Unauthorized)
        {
            var refreshed = await _oauthClient.RefreshAccessTokenAsync(ct).ConfigureAwait(false);
            if (string.IsNullOrWhiteSpace(refreshed))
            {
                throw;
            }
            await UploadEncryptedFileCoreAsync(refreshed, fileName, encryptedPayload, ct).ConfigureAwait(false);
        }
    }

    private async Task UploadEncryptedFileCoreAsync(
        string token,
        string fileName,
        string encryptedPayload,
        CancellationToken ct)
    {
        var existingId = await FindRemoteFileIdAsync(token, fileName, ct).ConfigureAwait(false);
        var payloadBytes = Encoding.UTF8.GetBytes(encryptedPayload);

        if (!string.IsNullOrEmpty(existingId))
        {
            using var req = new HttpRequestMessage(
                HttpMethod.Patch,
                $"{DriveUploadEndpoint}/{Uri.EscapeDataString(existingId)}?uploadType=media");
            req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
            req.Content = new ByteArrayContent(payloadBytes);
            req.Content.Headers.ContentType = new MediaTypeHeaderValue("application/octet-stream");

            using var resp = await _http.SendAsync(req, ct).ConfigureAwait(false);
            resp.EnsureSuccessStatusCode();
            return;
        }

        var boundary = $"hasibu_sync_{DateTimeOffset.UtcNow.ToUnixTimeMilliseconds()}";
        var metaJson = BuildDriveMetadataJson(fileName);
        var body =
            $"--{boundary}\r\n" +
            "Content-Type: application/json; charset=UTF-8\r\n\r\n" +
            $"{metaJson}\r\n" +
            $"--{boundary}\r\n" +
            "Content-Type: application/octet-stream\r\n\r\n" +
            $"{encryptedPayload}\r\n" +
            $"--{boundary}--";

        using var createReq = new HttpRequestMessage(HttpMethod.Post, $"{DriveUploadEndpoint}?uploadType=multipart");
        createReq.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        createReq.Content = new StringContent(body, Encoding.UTF8);
        createReq.Content.Headers.ContentType = MediaTypeHeaderValue.Parse($"multipart/related; boundary={boundary}");

        using var createResp = await _http.SendAsync(createReq, ct).ConfigureAwait(false);
        createResp.EnsureSuccessStatusCode();
    }

    private async Task<string?> FindRemoteFileIdAsync(string token, string fileName, CancellationToken ct)
    {
        var escapedName = fileName.Replace("'", "\\'");
        var q = $"name = '{escapedName}' and trashed = false";
        var url = $"{DriveFilesEndpoint}?q={Uri.EscapeDataString(q)}&spaces=drive&fields={Uri.EscapeDataString("files(id,name,modifiedTime)")}&pageSize=1";

        using var req = new HttpRequestMessage(HttpMethod.Get, url);
        req.Headers.Authorization = new AuthenticationHeaderValue("Bearer", token);
        using var resp = await _http.SendAsync(req, ct).ConfigureAwait(false);
        resp.EnsureSuccessStatusCode();

        var json = await resp.Content.ReadAsStringAsync(ct).ConfigureAwait(false);
        using var doc = JsonDocument.Parse(json);
        if (doc.RootElement.TryGetProperty("files", out var files) &&
            files.ValueKind == JsonValueKind.Array &&
            files.GetArrayLength() > 0)
        {
            var first = files[0];
            if (first.TryGetProperty("id", out var idProp))
            {
                return idProp.GetString();
            }
        }
        return null;
    }

    private static bool WriteLocalMirrorIfAvailable(string configuredMirror, string fileName, string encryptedPayload)
    {
        try
        {
            var folder = configuredMirror.Trim();
            if (string.Equals(folder, "auto", StringComparison.OrdinalIgnoreCase))
            {
                folder = DetectDefaultGoogleDriveFolder();
            }
            if (string.IsNullOrWhiteSpace(folder)) return false;

            var root = Path.GetPathRoot(folder);
            if (!string.IsNullOrEmpty(root) && !Directory.Exists(root)) return false;

            Directory.CreateDirectory(folder);
            var target = Path.Combine(folder, fileName);
            var temp = $"{target}.{Guid.NewGuid():N}.tmp";
            File.WriteAllText(temp, encryptedPayload, Encoding.UTF8);
            File.Move(temp, target, overwrite: true);
            return true;
        }
        catch
        {
            return false;
        }
    }

    private static string BuildDriveMetadataJson(string fileName)
    {
        using var ms = new MemoryStream();
        using (var writer = new Utf8JsonWriter(ms))
        {
            writer.WriteStartObject();
            writer.WriteString("name", fileName);
            writer.WriteString("mimeType", "application/octet-stream");
            writer.WriteEndObject();
        }
        return Encoding.UTF8.GetString(ms.ToArray());
    }

    private static string FoldAndSanitizeSlug(string? raw, string fallback, int maxLength)
    {
        if (string.IsNullOrWhiteSpace(raw)) return fallback;
        var sb = new StringBuilder(raw.Length);
        foreach (var ch in raw.Trim())
        {
            sb.Append(TurkishFoldMap.TryGetValue(ch, out var mapped) ? mapped : ch);
        }

        var slug = InvalidSlugCharsRegex().Replace(sb.ToString().ToLowerInvariant(), "_");
        slug = MultiUnderscoreRegex().Replace(slug, "_").Trim('_', '-');
        if (slug.Length > maxLength)
        {
            slug = slug[..maxLength].Trim('_', '-');
        }
        return string.IsNullOrEmpty(slug) ? fallback : slug;
    }

    [GeneratedRegex("[^a-z0-9_-]+")]
    private static partial Regex InvalidSlugCharsRegex();

    [GeneratedRegex("_+")]
    private static partial Regex MultiUnderscoreRegex();

    public void Dispose()
    {
        if (_ownsHttpClient)
        {
            _http.Dispose();
        }
    }
}
