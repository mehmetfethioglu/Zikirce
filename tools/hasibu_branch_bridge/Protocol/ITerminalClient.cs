using HasibuBranchBridge.Models;

namespace HasibuBranchBridge.Protocol;

/// <summary>
/// Şube yüz tanıma / parmak izi terminaline soyut erişim sözleşmesi (DIP).
/// </summary>
public interface ITerminalClient : IAsyncDisposable
{
    bool IsConnected { get; }
    event EventHandler<AttendanceRecord>? RealtimeLogReceived;
    event EventHandler<string>? Disconnected;

    Task ConnectAsync(CancellationToken ct = default);
    Task EnableRealtimeEventsAsync(CancellationToken ct = default);
    Task<List<AttendanceRecord>> FetchAttendanceLogsAsync(CancellationToken ct = default);
    Task<List<DeviceUserRecord>> FetchDeviceUsersAsync(CancellationToken ct = default);
    Task<bool> SendKeepAliveAsync(CancellationToken ct = default);
    Task DisconnectAsync();
}
