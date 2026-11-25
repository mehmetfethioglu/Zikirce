using System.Text.Json.Serialization;

namespace HasibuBranchBridge.Models;

/// <summary>
/// Şube akıllı terazi köprüsü çalışma yapılandırması (hassas sırlar DPAPI kasasında tutulur).
/// </summary>
public sealed record BridgeConfig
{
    public string DeviceSlug { get; init; } = "sube_d35";
    public string DeviceName { get; init; } = "Hasibu Şube Terazi Köprüsü";
    public string CloudProfileId { get; init; } = "default";
    public int BranchId { get; init; } = 1;
    public string BranchCode { get; init; } = "MERKEZ";
    public string BranchName { get; init; } = "Merkez";
    public string TerminalIp { get; init; } = "192.168.9.150";
    public int TerminalPort { get; init; } = 4370;
    public int MachineNo { get; init; } = 1;
    public int CommKey { get; init; } = 437029;
    public int DebounceSeconds { get; init; } = 3;
    public int CatchUpPollMinutes { get; init; } = 3;
    public int KeepAliveSeconds { get; init; } = 30;
    public string LocalMirrorFolder { get; init; } = "auto";
    /// <summary>
    /// true ise bağlı Google hesabından türetilen <c>account_auto</c> yerine DPAPI kasasındaki özel <c>WorkspaceKey</c> kullanılır.
    /// </summary>
    public bool UseCustomWorkspaceKey { get; init; } = false;
    /// <summary>
    /// Yalnızca --import-config içe aktarımında okunur; sonrasında config.json'dan temizlenip DPAPI'ye taşınır.
    /// </summary>
    public string? WorkspaceKey { get; init; }
}

/// <summary>
/// Windows DPAPI (CurrentUser) ile şifrelenerek saklanan hassas kimlik ve şifreleme bilgileri.
/// </summary>
public sealed record BridgeSecrets
{
    public string AccessToken { get; init; } = string.Empty;
    public string RefreshToken { get; init; } = string.Empty;
    public string WorkspaceKey { get; init; } = string.Empty;
    public string GoogleClientId { get; init; } = string.Empty;
    public string GoogleClientSecret { get; init; } = string.Empty;
    public string ConnectedEmail { get; init; } = string.Empty;
}

public sealed record AttendanceRecord
{
    public string Id { get; init; } = string.Empty;
    public string CardNo { get; init; } = string.Empty;
    public int BranchId { get; init; }
    public int DeviceNo { get; init; }
    public string Timestamp { get; init; } = string.Empty;
    public bool IsCheckIn { get; init; }
    public string Source { get; init; } = "tenfeiD35";
    public string VerifyMethod { get; init; } = "face";
    public string IntegrityHash { get; init; } = string.Empty;
}

public sealed record DeviceUserRecord
{
    public string CardNo { get; init; } = string.Empty;
    public string FullName { get; init; } = string.Empty;
}

public sealed record BranchInboxPayload
{
    public int SchemaVersion { get; init; } = 1;
    public string VaultRole { get; init; } = "branch_inbox";
    public string CloudProfileId { get; init; } = "default";
    public string DeviceSlug { get; init; } = string.Empty;
    public int BranchId { get; init; }
    public string BranchCode { get; init; } = string.Empty;
    public string BranchName { get; init; } = string.Empty;
    public string DeviceName { get; init; } = string.Empty;
    public string ExportedAt { get; init; } = string.Empty;
    public List<AttendanceRecord> AttendanceLogs { get; init; } = new();
    public List<DeviceUserRecord> DeviceUsers { get; init; } = new();
}

public sealed record BranchInboxEnvelope
{
    public string Format { get; init; } = "hasibu_aes256_gcm_v1";
    public string VaultRole { get; init; } = "branch_inbox";
    public string? KeyMode { get; init; }
    public string EncryptedAt { get; init; } = string.Empty;
    public string Iv { get; init; } = string.Empty;
    public string Tag { get; init; } = string.Empty;
    public string Ciphertext { get; init; } = string.Empty;
}

public sealed record LocalInboxCacheState
{
    public bool PendingUpload { get; init; }
    public string? LastUploadedAtUtc { get; init; }
    public string? LastEncryptionKeyMode { get; init; }
    public List<AttendanceRecord> AttendanceLogs { get; init; } = new();
    public List<DeviceUserRecord> DeviceUsers { get; init; } = new();
}

[JsonSourceGenerationOptions(
    PropertyNamingPolicy = JsonKnownNamingPolicy.CamelCase,
    DefaultIgnoreCondition = JsonIgnoreCondition.WhenWritingNull,
    WriteIndented = false)]
[JsonSerializable(typeof(BridgeConfig))]
[JsonSerializable(typeof(BridgeSecrets))]
[JsonSerializable(typeof(AttendanceRecord))]
[JsonSerializable(typeof(DeviceUserRecord))]
[JsonSerializable(typeof(BranchInboxPayload))]
[JsonSerializable(typeof(BranchInboxEnvelope))]
[JsonSerializable(typeof(LocalInboxCacheState))]
internal sealed partial class BridgeJsonContext : JsonSerializerContext
{
}
