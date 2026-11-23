using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using HasibuBranchBridge.Cloud;
using HasibuBranchBridge.Crypto;
using HasibuBranchBridge.Models;
using Xunit;

namespace HasibuBranchBridge.Tests;

public class HasibuSyncCryptoTests
{
    [Fact]
    public void EncryptAndDecryptBranchInbox_RoundTripsWithTurkishMetadata()
    {
        const string workspaceKey = "hasibu-test-workspace-key-2026";
        var payload = new BranchInboxPayload
        {
            CloudProfileId = "default",
            DeviceSlug = "devteysti_d35",
            BranchId = 38,
            BranchCode = "DEVTEYSTI",
            BranchName = "Şube Devteyşti",
            DeviceName = "Devteyşti Akıllı Terazi",
            ExportedAt = "2026-11-22T12:00:00.000Z",
            AttendanceLogs = new List<AttendanceRecord>
            {
                new()
                {
                    Id = "38_00101_20261122_0830",
                    CardNo = "00101",
                    BranchId = 38,
                    DeviceNo = 2,
                    Timestamp = "2026-11-22T08:30:10.000",
                    IsCheckIn = true,
                    Source = "tenfeiD35",
                    VerifyMethod = "face",
                    IntegrityHash = string.Empty,
                },
            },
            DeviceUsers = new List<DeviceUserRecord>
            {
                new() { CardNo = "00101", FullName = "MEHMET ŞİRİN GÜNEŞ" },
            },
        };

        var encrypted = HasibuSyncCrypto.EncryptBranchInbox(payload, workspaceKey);
        var envelope = JsonSerializer.Deserialize<BranchInboxEnvelope>(encrypted, BridgeJsonContext.Default.BranchInboxEnvelope);
        Assert.NotNull(envelope);
        Assert.Equal("hasibu_aes256_gcm_v1", envelope!.Format);
        Assert.Equal("branch_inbox", envelope.VaultRole);

        var decrypted = HasibuSyncCrypto.DecryptBranchInbox(encrypted, workspaceKey);
        Assert.Equal(38, decrypted.BranchId);
        Assert.Equal("DEVTEYSTI", decrypted.BranchCode);
        Assert.Single(decrypted.AttendanceLogs);
        Assert.Equal("00101", decrypted.AttendanceLogs[0].CardNo);
        Assert.Single(decrypted.DeviceUsers);
        Assert.Equal("MEHMET ŞİRİN GÜNEŞ", decrypted.DeviceUsers[0].FullName);
    }

    [Fact]
    public void DecryptBranchInbox_RejectsWrongKeyOrWrongRole()
    {
        var payload = new BranchInboxPayload { BranchId = 38, DeviceSlug = "devteysti_d35" };
        var encrypted = HasibuSyncCrypto.EncryptBranchInbox(payload, "correct-key");

        Assert.ThrowsAny<CryptographicException>(() =>
            HasibuSyncCrypto.DecryptBranchInbox(encrypted, "wrong-key"));

        var tamperedRole = encrypted.Replace("\"branch_inbox\"", "\"master_vault\"");
        Assert.Throws<InvalidOperationException>(() =>
            HasibuSyncCrypto.DecryptBranchInbox(tamperedRole, "correct-key"));
    }

    [Fact]
    public void Derive256BitKey_MatchesDartHmacSha256Vector()
    {
        var key = HasibuSyncCrypto.Derive256BitKey("  hasibu-vector-2026  ");
        var hex = Convert.ToHexStringLower(key);
        using var expectedHmac = new HMACSHA256(Encoding.UTF8.GetBytes("hasibu_drive_aes256_gcm"));
        var expectedHex = Convert.ToHexStringLower(expectedHmac.ComputeHash(Encoding.UTF8.GetBytes("hasibu-vector-2026")));
        Assert.Equal(expectedHex, hex);
    }

    [Fact]
    public void BranchInboxFileName_MatchesDartSlugNormalization()
    {
        Assert.Equal(
            "hasibu_branch_inbox_sube_yenisehir_d35.enc",
            GoogleDriveInboxUploader.GetBranchInboxFileName("Şube__Yenişehir D35", "default"));
        Assert.Equal(
            "hasibu_branch_inbox_gaziantep__karakopru_d35.enc",
            GoogleDriveInboxUploader.GetBranchInboxFileName("Karaköprü D35", "Gaziantep"));
    }
}
