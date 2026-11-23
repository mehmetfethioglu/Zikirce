using HasibuBranchBridge.Cloud;
using HasibuBranchBridge.Models;
using HasibuBranchBridge.Platform;
using HasibuBranchBridge.Protocol;
using HasibuBranchBridge.Storage;

namespace HasibuBranchBridge.Engine;

/// <summary>
/// Şube yüz tanıma terminalini canlı dinleyip (CMD_REG_EVENT + emniyet taraması + yeniden bağlanma)
/// yüz okutulduğu anda şifreli Google Drive şube kutusuna yükleyen ana köprü motoru.
/// </summary>
public sealed class BranchBridgeService : IAsyncDisposable
{
    private readonly BridgeConfig _config;
    private readonly ITerminalClient _terminal;
    private readonly ICloudInboxUploader _uploader;
    private readonly LocalInboxCache _cache;
    private readonly RotatingFileLogger _logger;

    private readonly TimeSpan _debounceDelay;
    private readonly TimeSpan _keepAliveInterval;
    private readonly TimeSpan _catchUpInterval;
    private readonly TimeSpan _offlineRetryInterval;
    private readonly TimeSpan[] _reconnectBackoffs;

    private readonly SemaphoreSlim _uploadLock = new(1, 1);
    private readonly SemaphoreSlim _pullLock = new(1, 1);
    private readonly object _debounceSync = new();
    private CancellationTokenSource? _debounceCts;
    private Task? _debounceTask;
    private TaskCompletionSource<bool>? _disconnectSignal;
    private readonly object _signalSync = new();

    public BranchBridgeService(
        BridgeConfig config,
        ITerminalClient terminal,
        ICloudInboxUploader uploader,
        LocalInboxCache cache,
        RotatingFileLogger logger,
        TimeSpan? debounceDelay = null,
        TimeSpan? keepAliveInterval = null,
        TimeSpan? catchUpInterval = null,
        TimeSpan? offlineRetryInterval = null,
        TimeSpan[]? reconnectBackoffs = null)
    {
        _config = config;
        _terminal = terminal;
        _uploader = uploader;
        _cache = cache;
        _logger = logger;
        _debounceDelay = debounceDelay ?? TimeSpan.FromSeconds(Math.Clamp(config.DebounceSeconds, 1, 60));
        _keepAliveInterval = keepAliveInterval ?? TimeSpan.FromSeconds(Math.Clamp(config.KeepAliveSeconds, 5, 300));
        _catchUpInterval = catchUpInterval ?? TimeSpan.FromMinutes(Math.Clamp(config.CatchUpPollMinutes, 1, 60));
        _offlineRetryInterval = offlineRetryInterval ?? TimeSpan.FromSeconds(20);
        _reconnectBackoffs = reconnectBackoffs ?? new[]
        {
            TimeSpan.FromSeconds(3),
            TimeSpan.FromSeconds(6),
            TimeSpan.FromSeconds(15),
            TimeSpan.FromSeconds(30),
        };
    }

    /// <summary>
    /// Tek seferlik terminal çekimi + şube kutusu yüklemesi (--run-once / --test).
    /// </summary>
    public async Task<(bool TerminalOk, int LogsFetched, int UsersFetched, InboxUploadResult Upload)> RunOnceAsync(
        bool forceUpload = true,
        CancellationToken ct = default)
    {
        var logs = new List<AttendanceRecord>();
        var users = new List<DeviceUserRecord>();
        var terminalOk = false;

        try
        {
            logs = await _terminal.FetchAttendanceLogsAsync(ct).ConfigureAwait(false);
            users = await _terminal.FetchDeviceUsersAsync(ct).ConfigureAwait(false);
            terminalOk = true;
            var merged = _cache.MergeLogs(logs);
            var userChanges = _cache.MergeUsers(users);
            _logger.Info($"Terminal çekimi tamamlandı: {logs.Count} hareket ({merged.addedOrUpdated} yeni), {users.Count} kişi ({userChanges} değişen).");
        }
        catch (Exception ex)
        {
            _logger.Warn($"Terminal çekim hatası: {ex.Message}");
        }

        if (!forceUpload && !_cache.PendingUpload)
        {
            return (terminalOk, logs.Count, users.Count, new InboxUploadResult(true, true, false, string.Empty, "Değişiklik yok."));
        }

        var upload = await FlushPendingUploadAsync(force: forceUpload, ct).ConfigureAwait(false);
        return (terminalOk, logs.Count, users.Count, upload);
    }

    /// <summary>
    /// Ekransız arka plan canlı dinleme, kopma kurtarma, periyodik güvenlik taraması ve çevrimdışı tekrar deneme döngüsü.
    /// </summary>
    public async Task RunLoopAsync(CancellationToken ct)
    {
        _logger.Info($"Şube köprüsü başlatıldı: {_config.BranchName} ({_config.DeviceSlug}) -> {_config.TerminalIp}:{_config.TerminalPort}");

        void OnRealtimeLog(object? sender, AttendanceRecord record)
        {
            try
            {
                var (added, total) = _cache.MergeLogs(new[] { record });
                _logger.Info($"Anlık okutma yakalandı: kart={record.CardNo}, saat={record.Timestamp}, yeni={added}, toplam={total}");
                _cache.MarkPendingUpload();
                ScheduleDebouncedUpload(ct);
            }
            catch (Exception ex)
            {
                _logger.Error($"Anlık okutma işleme hatası: {ex.Message}");
            }
        }

        void OnDisconnected(object? sender, string reason)
        {
            _logger.Warn($"Terminal bağlantısı kesildi: {reason}");
            SignalDisconnect();
        }

        _terminal.RealtimeLogReceived += OnRealtimeLog;
        _terminal.Disconnected += OnDisconnected;

        var catchUpTask = RunCatchUpLoopAsync(ct);
        var retryTask = RunOfflineRetryLoopAsync(ct);

        try
        {
            var backoffIndex = 0;
            while (!ct.IsCancellationRequested)
            {
                ResetDisconnectSignal();
                try
                {
                    await _terminal.ConnectAsync(ct).ConfigureAwait(false);
                    await PullAndMergeCatchUpCoreAsync(reEnableRealtime: true, ct).ConfigureAwait(false);
                    backoffIndex = 0;
                    _logger.Info($"Canlı olay dinleyici (CMD_REG_EVENT) aktif: {_config.TerminalIp}:{_config.TerminalPort}");

                    while (!ct.IsCancellationRequested && _terminal.IsConnected)
                    {
                        var signalTask = GetDisconnectSignalTask();
                        var delayTask = Task.Delay(_keepAliveInterval, ct);
                        var finished = await Task.WhenAny(signalTask, delayTask).ConfigureAwait(false);
                        if (finished == signalTask)
                        {
                            break;
                        }

                        var alive = await _terminal.SendKeepAliveAsync(ct).ConfigureAwait(false);
                        if (!alive)
                        {
                            _logger.Warn("KeepAlive yanıt vermedi; yeniden bağlanılacak.");
                            break;
                        }
                    }
                }
                catch (OperationCanceledException) when (ct.IsCancellationRequested)
                {
                    break;
                }
                catch (Exception ex)
                {
                    _logger.Warn($"Terminal canlı oturum hatası: {ex.Message}");
                }

                await _terminal.DisconnectAsync().ConfigureAwait(false);
                if (ct.IsCancellationRequested) break;

                var wait = _reconnectBackoffs[Math.Min(backoffIndex, _reconnectBackoffs.Length - 1)];
                backoffIndex++;
                _logger.Info($"{wait.TotalSeconds:0.#} sn sonra yeniden bağlanılacak...");
                try
                {
                    await Task.Delay(wait, ct).ConfigureAwait(false);
                }
                catch (OperationCanceledException)
                {
                    break;
                }
            }
        }
        finally
        {
            _terminal.RealtimeLogReceived -= OnRealtimeLog;
            _terminal.Disconnected -= OnDisconnected;
            CancelPendingDebounce();

            try { await Task.WhenAll(catchUpTask, retryTask).ConfigureAwait(false); } catch { }
            if (_debounceTask != null)
            {
                try { await _debounceTask.ConfigureAwait(false); } catch { }
            }
            await _terminal.DisconnectAsync().ConfigureAwait(false);
            _logger.Info("Şube köprüsü temiz şekilde durduruldu.");
        }
    }

    private async Task RunCatchUpLoopAsync(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            try
            {
                await Task.Delay(_catchUpInterval, ct).ConfigureAwait(false);
            }
            catch (OperationCanceledException)
            {
                break;
            }

            try
            {
                if (_terminal.IsConnected)
                {
                    await PullAndMergeCatchUpCoreAsync(reEnableRealtime: true, ct).ConfigureAwait(false);
                }
            }
            catch (OperationCanceledException) when (ct.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.Warn($"Periyodik güvenlik taraması uyarısı: {ex.Message}");
            }
        }
    }

    private async Task RunOfflineRetryLoopAsync(CancellationToken ct)
    {
        while (!ct.IsCancellationRequested)
        {
            try
            {
                await Task.Delay(_offlineRetryInterval, ct).ConfigureAwait(false);
            }
            catch (OperationCanceledException)
            {
                break;
            }

            if (!_cache.PendingUpload) continue;
            try
            {
                await FlushPendingUploadAsync(force: false, ct).ConfigureAwait(false);
            }
            catch (OperationCanceledException) when (ct.IsCancellationRequested)
            {
                break;
            }
            catch (Exception ex)
            {
                _logger.Warn($"Çevrimdışı bekleyen yükleme denemesi başarısız: {ex.Message}");
            }
        }
    }

    private async Task PullAndMergeCatchUpCoreAsync(bool reEnableRealtime, CancellationToken ct)
    {
        await _pullLock.WaitAsync(ct).ConfigureAwait(false);
        try
        {
            var logs = await _terminal.FetchAttendanceLogsAsync(ct).ConfigureAwait(false);
            var users = await _terminal.FetchDeviceUsersAsync(ct).ConfigureAwait(false);
            if (reEnableRealtime && _terminal.IsConnected)
            {
                await _terminal.EnableRealtimeEventsAsync(ct).ConfigureAwait(false);
            }

            var mergedLogs = _cache.MergeLogs(logs);
            var mergedUsers = _cache.MergeUsers(users);
            if (mergedLogs.addedOrUpdated > 0 || mergedUsers > 0 || _cache.PendingUpload)
            {
                _logger.Info($"Tamamlayıcı tarama: +{mergedLogs.addedOrUpdated} hareket, +{mergedUsers} kişi.");
                await FlushPendingUploadAsync(force: false, ct).ConfigureAwait(false);
            }
        }
        finally
        {
            _pullLock.Release();
        }
    }

    public async Task<InboxUploadResult> FlushPendingUploadAsync(bool force = false, CancellationToken ct = default)
    {
        await _uploadLock.WaitAsync(ct).ConfigureAwait(false);
        try
        {
            if (!force && !_cache.PendingUpload)
            {
                return new InboxUploadResult(true, true, false, string.Empty, "Bekleyen değişiklik yok.");
            }

            var payload = _cache.BuildPayload(_config);
            var result = await _uploader.UploadBranchInboxAsync(_config, payload, ct).ConfigureAwait(false);
            if (result.Success)
            {
                _cache.MarkUploaded(DateTime.UtcNow);
                _logger.Info($"Bulut aktarımı başarılı: {result.Detail}");
            }
            else
            {
                _logger.Warn($"Bulut aktarımı beklemede: {result.Detail}");
            }
            return result;
        }
        finally
        {
            _uploadLock.Release();
        }
    }

    private void ScheduleDebouncedUpload(CancellationToken lifecycleCt)
    {
        lock (_debounceSync)
        {
            _debounceCts?.Cancel();
            _debounceCts?.Dispose();
            _debounceCts = CancellationTokenSource.CreateLinkedTokenSource(lifecycleCt);
            var token = _debounceCts.Token;

            _debounceTask = Task.Run(async () =>
            {
                try
                {
                    await Task.Delay(_debounceDelay, token).ConfigureAwait(false);
                    await FlushPendingUploadAsync(force: false, token).ConfigureAwait(false);
                }
                catch (OperationCanceledException)
                {
                    // Yeni okuma geldiğinde veya kapatılırken iptal edilir
                }
                catch (Exception ex)
                {
                    _logger.Warn($"Anlık yükleme hatası (yeniden denenecek): {ex.Message}");
                }
            }, CancellationToken.None);
        }
    }

    private void CancelPendingDebounce()
    {
        lock (_debounceSync)
        {
            _debounceCts?.Cancel();
            _debounceCts?.Dispose();
            _debounceCts = null;
        }
    }

    private void ResetDisconnectSignal()
    {
        lock (_signalSync)
        {
            _disconnectSignal = new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
        }
    }

    private void SignalDisconnect()
    {
        lock (_signalSync)
        {
            _disconnectSignal?.TrySetResult(true);
        }
    }

    private Task GetDisconnectSignalTask()
    {
        lock (_signalSync)
        {
            _disconnectSignal ??= new TaskCompletionSource<bool>(TaskCreationOptions.RunContinuationsAsynchronously);
            return _disconnectSignal.Task;
        }
    }

    public ValueTask DisposeAsync()
    {
        CancelPendingDebounce();
        _uploadLock.Dispose();
        _pullLock.Dispose();
        return ValueTask.CompletedTask;
    }
}
