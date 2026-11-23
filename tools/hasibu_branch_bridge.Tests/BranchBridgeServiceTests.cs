using System.Runtime.InteropServices;
using System.Text;
using HasibuBranchBridge.Cloud;
using HasibuBranchBridge.Engine;
using HasibuBranchBridge.Models;
using HasibuBranchBridge.Platform;
using HasibuBranchBridge.Protocol;
using HasibuBranchBridge.Storage;
using Xunit;

namespace HasibuBranchBridge.Tests;

public class BranchBridgeServiceTests
{
    private sealed class FakeTerminalClient : ITerminalClient
    {
        public bool IsConnected { get; private set; }
        public List<AttendanceRecord> LogsToReturn { get; } = new();
        public List<DeviceUserRecord> UsersToReturn { get; } = new();
        public int ConnectCount { get; private set; }
        public int FetchCount { get; private set; }
        public bool KeepAliveResult { get; set; } = true;

        public event EventHandler<AttendanceRecord>? RealtimeLogReceived;
        public event EventHandler<string>? Disconnected;

        public Task ConnectAsync(CancellationToken ct = default)
        {
            ConnectCount++;
            IsConnected = true;
            return Task.CompletedTask;
        }

        public Task EnableRealtimeEventsAsync(CancellationToken ct = default) => Task.CompletedTask;

        public Task<List<AttendanceRecord>> FetchAttendanceLogsAsync(CancellationToken ct = default)
        {
            FetchCount++;
            return Task.FromResult(LogsToReturn.ToList());
        }

        public Task<List<DeviceUserRecord>> FetchDeviceUsersAsync(CancellationToken ct = default) =>
            Task.FromResult(UsersToReturn.ToList());

        public Task<bool> SendKeepAliveAsync(CancellationToken ct = default) =>
            Task.FromResult(KeepAliveResult);

        public Task DisconnectAsync()
        {
            IsConnected = false;
            return Task.CompletedTask;
        }

        public ValueTask DisposeAsync() => ValueTask.CompletedTask;

        public void EmitRealtimeScan(AttendanceRecord record) =>
            RealtimeLogReceived?.Invoke(this, record);

        public void SimulateDisconnect(string reason = "Ağ koptu")
        {
            IsConnected = false;
            Disconnected?.Invoke(this, reason);
        }
    }

    private sealed class FakeCloudUploader : ICloudInboxUploader
    {
        public readonly List<BranchInboxPayload> UploadedPayloads = new();
        public bool FailNextUpload { get; set; }
        private int _remainingFailures;

        public void FailUploads(int count) => _remainingFailures = count;

        public Task<InboxUploadResult> UploadBranchInboxAsync(
            BridgeConfig config,
            BranchInboxPayload payload,
            CancellationToken ct = default)
        {
            if (FailNextUpload || _remainingFailures > 0)
            {
                if (_remainingFailures > 0) _remainingFailures--;
                return Task.FromResult(new InboxUploadResult(false, false, false, "test.enc", "İnternet yok"));
            }
            lock (UploadedPayloads)
            {
                UploadedPayloads.Add(payload);
            }
            return Task.FromResult(new InboxUploadResult(true, true, false, "hasibu_branch_inbox_devteysti_d35.enc", "OK"));
        }

        public void Dispose() { }
    }

    private static (string tempDir, BridgeConfig cfg, LocalInboxCache cache, RotatingFileLogger logger) CreateHarness(string slug = "devteysti_d35")
    {
        var dir = Path.Combine(Path.GetTempPath(), $"hasibu_bridge_test_{Guid.NewGuid():N}");
        Directory.CreateDirectory(dir);
        var cfg = new BridgeConfig
        {
            DeviceSlug = slug,
            BranchId = 38,
            BranchCode = "DEVTEYSTI",
            BranchName = "Şube Devteyşti",
            TerminalIp = "127.0.0.1",
            DebounceSeconds = 1,
            CatchUpPollMinutes = 1,
            KeepAliveSeconds = 5,
        };
        var cache = new LocalInboxCache(slug, dir);
        var logger = new RotatingFileLogger(Path.Combine(dir, "logs"));
        return (dir, cfg, cache, logger);
    }

    [Fact]
    public async Task RealtimeScans_BatchIntoDebouncedUploadAndRetryAfterOfflineFailure()
    {
        var (dir, cfg, cache, logger) = CreateHarness();
        try
        {
            var terminal = new FakeTerminalClient();
            var uploader = new FakeCloudUploader();
            await using var service = new BranchBridgeService(
                cfg,
                terminal,
                uploader,
                cache,
                logger,
                debounceDelay: TimeSpan.FromMilliseconds(60),
                keepAliveInterval: TimeSpan.FromSeconds(5),
                catchUpInterval: TimeSpan.FromSeconds(10),
                offlineRetryInterval: TimeSpan.FromMilliseconds(90),
                reconnectBackoffs: new[] { TimeSpan.FromMilliseconds(30) });

            using var cts = new CancellationTokenSource();
            var loopTask = service.RunLoopAsync(cts.Token);

            // Bağlantı kurulana kadar bekle
            await WaitUntilAsync(() => terminal.IsConnected, TimeSpan.FromSeconds(2));

            // 1. Seri halde 3 yüz okutma -> debounce ile tek pakette birleşmeli
            terminal.EmitRealtimeScan(new AttendanceRecord { Id = "38_00101_20261122_0900", CardNo = "00101", BranchId = 38, Timestamp = "2026-11-22T09:00:05.000", IsCheckIn = true });
            terminal.EmitRealtimeScan(new AttendanceRecord { Id = "38_00102_20261122_0900", CardNo = "00102", BranchId = 38, Timestamp = "2026-11-22T09:00:12.000", IsCheckIn = true });
            terminal.EmitRealtimeScan(new AttendanceRecord { Id = "38_00103_20261122_0901", CardNo = "00103", BranchId = 38, Timestamp = "2026-11-22T09:01:02.000", IsCheckIn = true });

            await WaitUntilAsync(() => uploader.UploadedPayloads.Count >= 1, TimeSpan.FromSeconds(2));
            Assert.Single(uploader.UploadedPayloads);
            Assert.Equal(3, uploader.UploadedPayloads[0].AttendanceLogs.Count);
            Assert.False(cache.PendingUpload);

            // 2. İnternet kesikken yeni okutma -> ilk yükleme başarısız, retry döngüsü kurtarmalı
            uploader.FailUploads(1);
            terminal.EmitRealtimeScan(new AttendanceRecord { Id = "38_00104_20261122_0905", CardNo = "00104", BranchId = 38, Timestamp = "2026-11-22T09:05:00.000", IsCheckIn = true });

            await WaitUntilAsync(() => uploader.UploadedPayloads.Count >= 2, TimeSpan.FromSeconds(3));
            Assert.Equal(4, uploader.UploadedPayloads.Last().AttendanceLogs.Count);
            Assert.False(cache.PendingUpload);

            // 3. Terminal soketi koparsa yeniden bağlanıp kopma sırasındaki kayıtları yakalamalı
            terminal.LogsToReturn.Add(new AttendanceRecord { Id = "38_00105_20261122_0910", CardNo = "00105", BranchId = 38, Timestamp = "2026-11-22T09:10:00.000", IsCheckIn = true });
            terminal.SimulateDisconnect();

            await WaitUntilAsync(() => terminal.ConnectCount >= 2 && uploader.UploadedPayloads.Count >= 3, TimeSpan.FromSeconds(3));
            Assert.Equal(5, uploader.UploadedPayloads.Last().AttendanceLogs.Count);

            cts.Cancel();
            await loopTask;
        }
        finally
        {
            try { Directory.Delete(dir, recursive: true); } catch { }
        }
    }

    private static async Task WaitUntilAsync(Func<bool> predicate, TimeSpan timeout)
    {
        var deadline = DateTime.UtcNow + timeout;
        while (!predicate() && DateTime.UtcNow < deadline)
        {
            await Task.Delay(15);
        }
    }

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern Microsoft.Win32.SafeHandles.SafeFileHandle CreateFileW(
        string lpFileName,
        uint dwDesiredAccess,
        uint dwShareMode,
        IntPtr lpSecurityAttributes,
        uint dwCreationDisposition,
        uint dwFlagsAndAttributes,
        IntPtr hTemplateFile);

    [Fact]
    public void WindowsStartupManager_RemovesZoneIdentifierAndStagesCleanLocalExecutable()
    {
        var tempRoot = Path.Combine(Path.GetTempPath(), $"hasibu_motw_test_{Guid.NewGuid():N}");
        var srcDir = Path.Combine(tempRoot, "src");
        var dstDir = Path.Combine(tempRoot, "dst");
        Directory.CreateDirectory(srcDir);
        try
        {
            var srcExe = Path.Combine(srcDir, "HasibuBranchBridge.exe");
            File.WriteAllBytes(srcExe, new byte[] { 0x4D, 0x5A, 0x90, 0x00 });

            using (var handle = CreateFileW(
                $"{srcExe}:Zone.Identifier",
                0x40000000u,
                0u,
                IntPtr.Zero,
                2u,
                0x80u,
                IntPtr.Zero))
            {
                Assert.False(handle.IsInvalid);
                using var stream = new FileStream(handle, FileAccess.Write);
                var zoneBytes = Encoding.ASCII.GetBytes("[ZoneTransfer]\r\nZoneId=3\r\n");
                stream.Write(zoneBytes, 0, zoneBytes.Length);
            }

            Assert.True(WindowsStartupManager.HasMarkOfTheWeb(srcExe));

            var stagedExe = WindowsStartupManager.StageLocalExecutable(srcExe, dstDir);

            Assert.True(File.Exists(stagedExe));
            Assert.False(WindowsStartupManager.HasMarkOfTheWeb(srcExe));
            Assert.False(WindowsStartupManager.HasMarkOfTheWeb(stagedExe));
        }
        finally
        {
            try { Directory.Delete(tempRoot, recursive: true); } catch { }
        }
    }
}
