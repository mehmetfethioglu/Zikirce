using HasibuBranchBridge.Models;

namespace HasibuBranchBridge.Cloud;

public sealed record InboxUploadResult(
    bool Success,
    bool CloudApiVerified,
    bool LocalMirrorWritten,
    string FileName,
    string Detail,
    string KeyMode = "");

/// <summary>
/// Şifreli şube cihaz gelen kutusu yükleme soyutlaması (DIP).
/// </summary>
public interface ICloudInboxUploader : IDisposable
{
    Task<InboxUploadResult> UploadBranchInboxAsync(
        BridgeConfig config,
        BranchInboxPayload payload,
        CancellationToken ct = default);
}
