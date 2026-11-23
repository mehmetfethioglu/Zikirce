using System.Buffers.Binary;
using System.Globalization;
using System.Net.Sockets;
using System.Text;
using HasibuBranchBridge.Models;

namespace HasibuBranchBridge.Protocol;

/// <summary>
/// Saf C# ZKTeco / Tenfei D35 TCP (Port 4370) Protokol İstemcisi.
/// Hasibu Dart <c>TenfeiZkClient</c> ile birebir protokol ve kimlik paritesi sağlar.
/// </summary>
public sealed class TenfeiZkClient : ITerminalClient
{
    public const int CmdConnect = 1000;
    public const int CmdExit = 1001;
    public const int CmdEnableDevice = 1002;
    public const int CmdDisableDevice = 1003;
    public const int CmdUserTempRrq = 9;
    public const byte FctUser = 5;
    public const int CmdAuth = 1102;
    public const int CmdAckOk = 2000;
    public const int CmdAckUnauth = 2005;
    public const int CmdPrepareData = 1500;
    public const int CmdData = 1501;
    public const int CmdFreeData = 1502;
    public const int CmdAttLogRrq = 13;
    public const int CmdRegEvent = 500;
    public const int EfAttLog = 1;

    private static readonly byte[] TcpMagic = { 0x50, 0x50, 0x82, 0x7D };

    private readonly string _host;
    private readonly int _port;
    private readonly int _branchId;
    private readonly int _machineNo;
    private readonly int _commKey;
    private readonly TimeSpan _timeout;

    private readonly SemaphoreSlim _commandLock = new(1, 1);
    private readonly object _rxSync = new();
    private readonly MemoryStream _rxBuffer = new();
    private readonly Queue<byte[]> _packetQueue = new();
    private readonly Queue<TaskCompletionSource<byte[]>> _packetWaiters = new();

    private TcpClient? _tcpClient;
    private NetworkStream? _stream;
    private CancellationTokenSource? _rxCts;
    private Task? _rxTask;
    private ushort _sessionId;
    private ushort _replyId;
    private volatile bool _isConnected;

    public TenfeiZkClient(
        string host,
        int port = 4370,
        int branchId = 1,
        int machineNo = 1,
        int commKey = 437029,
        TimeSpan? timeout = null)
    {
        _host = host.Trim();
        _port = port;
        _branchId = branchId;
        _machineNo = machineNo;
        _commKey = commKey;
        _timeout = timeout ?? TimeSpan.FromSeconds(5);
    }

    public bool IsConnected => _isConnected && _tcpClient?.Connected == true;

    public event EventHandler<AttendanceRecord>? RealtimeLogReceived;
    public event EventHandler<string>? Disconnected;

    public async Task ConnectAsync(CancellationToken ct = default)
    {
        await _commandLock.WaitAsync(ct).ConfigureAwait(false);
        try
        {
            if (IsConnected) return;
            await DisconnectCoreAsync(sendExit: false).ConfigureAwait(false);

            var client = new TcpClient();
            using (var timeoutCts = CancellationTokenSource.CreateLinkedTokenSource(ct))
            {
                timeoutCts.CancelAfter(_timeout);
                await client.ConnectAsync(_host, _port, timeoutCts.Token).ConfigureAwait(false);
            }

            _tcpClient = client;
            _stream = client.GetStream();
            _sessionId = 0;
            _replyId = 0;
            lock (_rxSync)
            {
                _rxBuffer.SetLength(0);
                _packetQueue.Clear();
                while (_packetWaiters.Count > 0)
                {
                    _packetWaiters.Dequeue().TrySetCanceled();
                }
            }

            _rxCts = new CancellationTokenSource();
            _rxTask = Task.Run(() => ReceiveLoopAsync(_stream, _rxCts.Token));

            var resp = await SendCommandCoreAsync(CmdConnect, null, ct).ConfigureAwait(false);
            if (resp.Command == CmdAckUnauth)
            {
                _sessionId = resp.SessionId;
                var effectiveKey = _commKey <= 0 ? 437029 : _commKey;
                var authResp = await SendCommandCoreAsync(
                    CmdAuth,
                    MakeCommKey(effectiveKey, _sessionId),
                    ct).ConfigureAwait(false);

                if (authResp.Command != CmdAckOk && effectiveKey != 0)
                {
                    authResp = await SendCommandCoreAsync(
                        CmdAuth,
                        MakeCommKey(0, _sessionId),
                        ct).ConfigureAwait(false);
                }

                if (authResp.Command != CmdAckOk)
                {
                    await DisconnectCoreAsync(sendExit: false).ConfigureAwait(false);
                    throw new IOException($"Tenfei D35 iletişim parolası reddedildi (Kod: {authResp.Command}).");
                }
                _isConnected = true;
                return;
            }

            if (resp.Command != CmdAckOk)
            {
                await DisconnectCoreAsync(sendExit: false).ConfigureAwait(false);
                throw new IOException($"Tenfei D35 el sıkışması reddedildi (Kod: {resp.Command}).");
            }

            _sessionId = resp.SessionId;
            _isConnected = true;
        }
        finally
        {
            _commandLock.Release();
        }
    }

    public async Task EnableRealtimeEventsAsync(CancellationToken ct = default)
    {
        if (!IsConnected)
        {
            await ConnectAsync(ct).ConfigureAwait(false);
        }

        await _commandLock.WaitAsync(ct).ConfigureAwait(false);
        try
        {
            var payload = new byte[4];
            BinaryPrimitives.WriteUInt32LittleEndian(payload, EfAttLog);
            await SendCommandCoreAsync(CmdRegEvent, payload, ct).ConfigureAwait(false);
        }
        finally
        {
            _commandLock.Release();
        }
    }

    public async Task<List<AttendanceRecord>> FetchAttendanceLogsAsync(CancellationToken ct = default)
    {
        var openedHere = !IsConnected;
        if (openedHere)
        {
            await ConnectAsync(ct).ConfigureAwait(false);
        }

        await _commandLock.WaitAsync(ct).ConfigureAwait(false);
        try
        {
            try
            {
                await SendCommandCoreAsync(CmdDisableDevice, null, ct).ConfigureAwait(false);
            }
            catch
            {
                // Bazı firmware sürümlerinde opsiyonel olabilir
            }

            var resp = await SendCommandCoreAsync(CmdAttLogRrq, null, ct).ConfigureAwait(false);
            var rawLogs = await ReadBulkPayloadCoreAsync(resp, ct).ConfigureAwait(false);

            try
            {
                await SendCommandCoreAsync(CmdEnableDevice, null, ct).ConfigureAwait(false);
            }
            catch
            {
                // Yoksay
            }

            return DecodeAttendanceBuffer(rawLogs, _branchId, _machineNo);
        }
        finally
        {
            _commandLock.Release();
            if (openedHere)
            {
                await DisconnectAsync().ConfigureAwait(false);
            }
        }
    }

    public async Task<List<DeviceUserRecord>> FetchDeviceUsersAsync(CancellationToken ct = default)
    {
        var openedHere = !IsConnected;
        if (openedHere)
        {
            await ConnectAsync(ct).ConfigureAwait(false);
        }

        await _commandLock.WaitAsync(ct).ConfigureAwait(false);
        try
        {
            try
            {
                await SendCommandCoreAsync(CmdDisableDevice, null, ct).ConfigureAwait(false);
            }
            catch
            {
                // Yoksay
            }

            var resp = await SendCommandCoreAsync(CmdUserTempRrq, new[] { FctUser }, ct).ConfigureAwait(false);
            var rawUsers = await ReadBulkPayloadCoreAsync(resp, ct).ConfigureAwait(false);

            try
            {
                await SendCommandCoreAsync(CmdEnableDevice, null, ct).ConfigureAwait(false);
            }
            catch
            {
                // Yoksay
            }

            return DecodeUserBuffer(rawUsers);
        }
        finally
        {
            _commandLock.Release();
            if (openedHere)
            {
                await DisconnectAsync().ConfigureAwait(false);
            }
        }
    }

    public async Task<bool> SendKeepAliveAsync(CancellationToken ct = default)
    {
        if (!IsConnected) return false;
        await _commandLock.WaitAsync(ct).ConfigureAwait(false);
        try
        {
            using var shortCts = CancellationTokenSource.CreateLinkedTokenSource(ct);
            shortCts.CancelAfter(TimeSpan.FromSeconds(4));
            await SendCommandCoreAsync(CmdEnableDevice, null, shortCts.Token).ConfigureAwait(false);
            return true;
        }
        catch
        {
            _isConnected = false;
            return false;
        }
        finally
        {
            _commandLock.Release();
        }
    }

    public async Task DisconnectAsync()
    {
        await _commandLock.WaitAsync().ConfigureAwait(false);
        try
        {
            await DisconnectCoreAsync(sendExit: true).ConfigureAwait(false);
        }
        finally
        {
            _commandLock.Release();
        }
    }

    public async ValueTask DisposeAsync()
    {
        await DisconnectAsync().ConfigureAwait(false);
        _commandLock.Dispose();
        lock (_rxSync)
        {
            _rxBuffer.Dispose();
        }
    }

    private async Task DisconnectCoreAsync(bool sendExit)
    {
        if (sendExit && _isConnected && _stream != null)
        {
            try
            {
                using var exitCts = new CancellationTokenSource(TimeSpan.FromMilliseconds(600));
                await SendCommandCoreAsync(CmdExit, null, exitCts.Token).ConfigureAwait(false);
            }
            catch
            {
                // Bağlantı zaten kapanmış olabilir
            }
        }

        _isConnected = false;

        try
        {
            _rxCts?.Cancel();
        }
        catch
        {
            // Yoksay
        }

        try { _stream?.Dispose(); } catch { }
        try { _tcpClient?.Dispose(); } catch { }
        _stream = null;
        _tcpClient = null;

        if (_rxTask != null)
        {
            try
            {
                await _rxTask.ConfigureAwait(false);
            }
            catch
            {
                // Yoksay
            }
            _rxTask = null;
        }
        _rxCts?.Dispose();
        _rxCts = null;

        lock (_rxSync)
        {
            _packetQueue.Clear();
            while (_packetWaiters.Count > 0)
            {
                _packetWaiters.Dequeue().TrySetCanceled();
            }
        }
    }

    private async Task ReceiveLoopAsync(NetworkStream stream, CancellationToken ct)
    {
        var chunk = new byte[8192];
        var disconnectReason = string.Empty;
        try
        {
            while (!ct.IsCancellationRequested)
            {
                var read = await stream.ReadAsync(chunk, ct).ConfigureAwait(false);
                if (read <= 0)
                {
                    disconnectReason = "Uzak soket kapatıldı.";
                    break;
                }
                ProcessRxChunk(chunk.AsSpan(0, read));
            }
        }
        catch (OperationCanceledException)
        {
            return;
        }
        catch (Exception ex)
        {
            disconnectReason = ex.Message;
        }

        _isConnected = false;
        lock (_rxSync)
        {
            while (_packetWaiters.Count > 0)
            {
                _packetWaiters.Dequeue().TrySetException(
                    new IOException(string.IsNullOrEmpty(disconnectReason) ? "Bağlantı kesildi." : disconnectReason));
            }
        }
        if (!string.IsNullOrEmpty(disconnectReason))
        {
            Disconnected?.Invoke(this, disconnectReason);
        }
    }

    private void ProcessRxChunk(ReadOnlySpan<byte> chunk)
    {
        var realtimeToRaise = new List<AttendanceRecord>();

        lock (_rxSync)
        {
            _rxBuffer.Position = _rxBuffer.Length;
            _rxBuffer.Write(chunk);

            while (true)
            {
                var buffer = _rxBuffer.GetBuffer();
                var len = (int)_rxBuffer.Length;
                if (len < 16) break;

                if (buffer[0] != TcpMagic[0] ||
                    buffer[1] != TcpMagic[1] ||
                    buffer[2] != TcpMagic[2] ||
                    buffer[3] != TcpMagic[3])
                {
                    _rxBuffer.SetLength(0);
                    break;
                }

                var payloadLength = BinaryPrimitives.ReadUInt32LittleEndian(buffer.AsSpan(4, 4));
                var totalPacketSize = 8 + (int)payloadLength;
                if (payloadLength > 16 * 1024 * 1024)
                {
                    _rxBuffer.SetLength(0);
                    break;
                }
                if (len < totalPacketSize) break;

                var zkPayload = new byte[payloadLength];
                Array.Copy(buffer, 8, zkPayload, 0, (int)payloadLength);

                var remainingCount = len - totalPacketSize;
                if (remainingCount > 0)
                {
                    Buffer.BlockCopy(buffer, totalPacketSize, buffer, 0, remainingCount);
                }
                _rxBuffer.SetLength(remainingCount);

                var pkt = ZkPacket.FromBytes(zkPayload);
                if (pkt.Command == CmdRegEvent && pkt.Payload.Length >= 12)
                {
                    var rt = ParseRealtimeEvent(pkt.Payload, _branchId, _machineNo);
                    if (rt != null)
                    {
                        realtimeToRaise.Add(rt);
                    }
                }
                else
                {
                    var delivered = false;
                    while (_packetWaiters.Count > 0)
                    {
                        var waiter = _packetWaiters.Dequeue();
                        if (waiter.TrySetResult(zkPayload))
                        {
                            delivered = true;
                            break;
                        }
                    }
                    if (!delivered)
                    {
                        _packetQueue.Enqueue(zkPayload);
                    }
                }
            }
        }

        foreach (var record in realtimeToRaise)
        {
            RealtimeLogReceived?.Invoke(this, record);
        }
    }

    private async Task<ZkPacket> SendCommandCoreAsync(int command, byte[]? payload, CancellationToken ct)
    {
        var stream = _stream ?? throw new IOException("Tenfei D35 soketi açık değil.");
        lock (_rxSync)
        {
            _packetQueue.Clear();
        }
        _replyId = (ushort)((_replyId + 1) & 0xFFFF);
        var frame = BuildTcpFrame(command, _sessionId, _replyId, payload ?? Array.Empty<byte>());
        var waitTask = NextRawPacketCoreAsync(_timeout, ct);
        await stream.WriteAsync(frame, ct).ConfigureAwait(false);
        await stream.FlushAsync(ct).ConfigureAwait(false);
        var rawResp = await waitTask.ConfigureAwait(false);
        return ZkPacket.FromBytes(rawResp);
    }

    private Task<byte[]> NextRawPacketCoreAsync(TimeSpan timeout, CancellationToken ct)
    {
        TaskCompletionSource<byte[]> tcs;
        lock (_rxSync)
        {
            if (_packetQueue.Count > 0)
            {
                return Task.FromResult(_packetQueue.Dequeue());
            }
            tcs = new TaskCompletionSource<byte[]>(TaskCreationOptions.RunContinuationsAsynchronously);
            _packetWaiters.Enqueue(tcs);
        }

        return WaitWithTimeoutAsync(tcs, timeout, ct);
    }

    private static async Task<byte[]> WaitWithTimeoutAsync(
        TaskCompletionSource<byte[]> tcs,
        TimeSpan timeout,
        CancellationToken ct)
    {
        using var timeoutCts = CancellationTokenSource.CreateLinkedTokenSource(ct);
        timeoutCts.CancelAfter(timeout);
        using var reg = timeoutCts.Token.Register(() =>
        {
            if (ct.IsCancellationRequested)
            {
                tcs.TrySetCanceled(ct);
            }
            else
            {
                tcs.TrySetException(new TimeoutException("Tenfei D35 paket yanıt süresi aşıldı."));
            }
        });
        return await tcs.Task.ConfigureAwait(false);
    }

    private async Task<byte[]> ReadBulkPayloadCoreAsync(ZkPacket initialResp, CancellationToken ct)
    {
        if (initialResp.Command == CmdData)
        {
            return initialResp.Payload;
        }
        if (initialResp.Command != CmdPrepareData || initialResp.Payload.Length < 4)
        {
            return Array.Empty<byte>();
        }

        var totalBytes = BinaryPrimitives.ReadUInt32LittleEndian(initialResp.Payload.AsSpan(0, 4));
        using var builder = new MemoryStream((int)Math.Min(totalBytes, 4 * 1024 * 1024));

        while (builder.Length < totalBytes)
        {
            var raw = await NextRawPacketCoreAsync(_timeout, ct).ConfigureAwait(false);
            var pkt = ZkPacket.FromBytes(raw);
            if (pkt.Command == CmdData)
            {
                builder.Write(pkt.Payload);
            }
            else if (pkt.Command == CmdAckOk)
            {
                break;
            }
        }

        try
        {
            await NextRawPacketCoreAsync(TimeSpan.FromMilliseconds(350), ct).ConfigureAwait(false);
        }
        catch
        {
            // Sonlandırıcı ACK paketi bazen gelmeyebilir
        }

        try
        {
            using var freeCts = CancellationTokenSource.CreateLinkedTokenSource(ct);
            freeCts.CancelAfter(TimeSpan.FromMilliseconds(800));
            await SendCommandCoreAsync(CmdFreeData, null, freeCts.Token).ConfigureAwait(false);
        }
        catch
        {
            // Yoksay
        }

        return builder.ToArray();
    }

    /// <summary>
    /// ZKTeco / Tenfei D35 CMD_AUTH (1102) oturum anahtarı şifrelemesi.
    /// </summary>
    public static byte[] MakeCommKey(int key, int sessionId, int ticks = 50)
    {
        uint k = 0;
        for (var i = 0; i < 32; i++)
        {
            if ((key & (1 << i)) != 0)
            {
                k = (k << 1) | 1u;
            }
            else
            {
                k <<= 1;
            }
        }
        k += (uint)sessionId;

        var b1 = (byte)(((k >> 8) & 0xFF) ^ 0x4B);
        var b2 = (byte)(((k >> 16) & 0xFF) ^ 0x53);
        var b3 = (byte)(((k >> 24) & 0xFF) ^ 0x4F);
        var b = (byte)(ticks & 0xFF);

        return new byte[]
        {
            (byte)(b2 ^ b),
            (byte)(b3 ^ b),
            b,
            (byte)(b1 ^ b),
        };
    }

    public static byte[] BuildTcpFrame(int command, int sessionId, int replyId, ReadOnlySpan<byte> payload)
    {
        var zkLength = 8 + payload.Length;
        var buffer = new byte[8 + zkLength];

        TcpMagic.CopyTo(buffer, 0);
        BinaryPrimitives.WriteUInt32LittleEndian(buffer.AsSpan(4, 4), (uint)zkLength);

        BinaryPrimitives.WriteUInt16LittleEndian(buffer.AsSpan(8, 2), (ushort)command);
        BinaryPrimitives.WriteUInt16LittleEndian(buffer.AsSpan(10, 2), 0);
        BinaryPrimitives.WriteUInt16LittleEndian(buffer.AsSpan(12, 2), (ushort)sessionId);
        BinaryPrimitives.WriteUInt16LittleEndian(buffer.AsSpan(14, 2), (ushort)replyId);

        if (!payload.IsEmpty)
        {
            payload.CopyTo(buffer.AsSpan(16));
        }

        var crc = ComputeChecksum(buffer.AsSpan(8));
        BinaryPrimitives.WriteUInt16LittleEndian(buffer.AsSpan(10, 2), crc);
        return buffer;
    }

    public static ushort ComputeChecksum(ReadOnlySpan<byte> data)
    {
        int sum = 0;
        int i = 0;
        while (i + 1 < data.Length)
        {
            sum += data[i] | (data[i + 1] << 8);
            while (sum > 0xFFFF)
            {
                sum = (sum & 0xFFFF) + (sum >> 16);
            }
            i += 2;
        }
        if (i < data.Length)
        {
            sum += data[i];
            while (sum > 0xFFFF)
            {
                sum = (sum & 0xFFFF) + (sum >> 16);
            }
        }
        return (ushort)((~sum) & 0xFFFF);
    }

    public static DateTime DecodeZkTime(uint packedTime)
    {
        var t = packedTime;
        var second = (int)(t % 60);
        t /= 60;
        var minute = (int)(t % 60);
        t /= 60;
        var hour = (int)(t % 24);
        t /= 24;
        var day = (int)((t % 31) + 1);
        t /= 31;
        var month = (int)((t % 12) + 1);
        t /= 12;
        var year = (int)(t + 2000);
        return new DateTime(year, Math.Clamp(month, 1, 12), Math.Clamp(day, 1, DateTime.DaysInMonth(year, Math.Clamp(month, 1, 12))),
            Math.Clamp(hour, 0, 23), Math.Clamp(minute, 0, 59), Math.Clamp(second, 0, 59), DateTimeKind.Unspecified);
    }

    public static string BuildDeterministicLogId(int branchId, string cardNo, DateTime timestamp)
    {
        return $"{branchId}_{cardNo}_{timestamp:yyyyMMdd}_{timestamp:HHmm}";
    }

    public static string FormatTimestampIso(DateTime timestamp)
    {
        return timestamp.ToString("yyyy-MM-dd'T'HH:mm:ss.fff", CultureInfo.InvariantCulture);
    }

    public static AttendanceRecord? ParseRealtimeEvent(
        ReadOnlySpan<byte> payload,
        int branchId = 1,
        int machineNo = 1,
        DateTime? fallbackNow = null)
    {
        try
        {
            if (payload.Length < 12) return null;
            var nullIdx = payload.IndexOf((byte)0);
            var endIdx = (nullIdx > 0 && nullIdx <= 24) ? nullIdx : Math.Min(9, payload.Length);
            var rawPin = Encoding.ASCII.GetString(payload.Slice(0, endIdx)).Trim();
            if (string.IsNullOrEmpty(rawPin)) return null;

            var cardNo = rawPin.PadLeft(5, '0');
            var verifyCode = payload.Length > 24 ? payload[24] : 15;
            var inOutState = payload.Length > 25 ? payload[25] : 0;

            var timestamp = fallbackNow ?? DateTime.Now;
            if (payload.Length >= 32)
            {
                var year = 2000 + payload[26];
                var month = Math.Clamp((int)payload[27], 1, 12);
                var day = Math.Clamp((int)payload[28], 1, DateTime.DaysInMonth(year, month));
                var hour = Math.Clamp((int)payload[29], 0, 23);
                var minute = Math.Clamp((int)payload[30], 0, 59);
                var second = Math.Clamp((int)payload[31], 0, 59);
                timestamp = new DateTime(year, month, day, hour, minute, second, DateTimeKind.Unspecified);
            }

            var isCheckIn = inOutState == 0 || inOutState == 4 || inOutState == 2;
            var verifyMethod = MapVerifyMethod(verifyCode);

            return new AttendanceRecord
            {
                Id = BuildDeterministicLogId(branchId, cardNo, timestamp),
                CardNo = cardNo,
                BranchId = branchId,
                DeviceNo = machineNo,
                Timestamp = FormatTimestampIso(timestamp),
                IsCheckIn = isCheckIn,
                Source = "tenfeiD35",
                VerifyMethod = verifyMethod,
                IntegrityHash = string.Empty,
            };
        }
        catch
        {
            return null;
        }
    }

    public static List<AttendanceRecord> DecodeAttendanceBuffer(
        ReadOnlySpan<byte> raw,
        int branchId = 1,
        int deviceNo = 1)
    {
        if (raw.IsEmpty) return new List<AttendanceRecord>();

        var recordsBytes = raw;
        if (raw.Length >= 44)
        {
            var innerLen = BinaryPrimitives.ReadUInt32LittleEndian(raw.Slice(0, 4));
            if (innerLen == raw.Length - 4 || raw.Length % 40 == 4)
            {
                recordsBytes = raw.Slice(4);
            }
        }

        var logs = new List<AttendanceRecord>();
        var lastScanByCard = new Dictionary<string, DateTime>(StringComparer.Ordinal);
        var firstScanOfDayByCard = new Dictionary<string, DateTime>(StringComparer.Ordinal);

        const int recordSize = 40;
        for (var offset = 0; offset + recordSize <= recordsBytes.Length; offset += recordSize)
        {
            var slice = recordsBytes.Slice(offset, recordSize);
            var pinSpan = slice.Slice(2, 24);
            var zeroPos = pinSpan.IndexOf((byte)0);
            var pinStr = Encoding.ASCII.GetString(zeroPos >= 0 ? pinSpan.Slice(0, zeroPos) : pinSpan).Trim();
            if (string.IsNullOrEmpty(pinStr)) continue;

            var cardNo = pinStr.PadLeft(5, '0');
            var verifyType = slice[26];
            var packedTime = BinaryPrimitives.ReadUInt32LittleEndian(slice.Slice(27, 4));
            var status = slice[31];
            var timestamp = DecodeZkTime(packedTime);

            if (lastScanByCard.TryGetValue(cardNo, out var prevScan) &&
                Math.Abs((timestamp - prevScan).TotalSeconds) < 120)
            {
                continue;
            }
            lastScanByCard[cardNo] = timestamp;

            var dayKey = $"{cardNo}_{timestamp.Year}-{timestamp.Month}-{timestamp.Day}";
            firstScanOfDayByCard.TryGetValue(dayKey, out var firstOfDay);

            bool isCheckIn;
            if (status == 1 || status == 3 || status == 5)
            {
                isCheckIn = false;
            }
            else if (firstOfDay != default && (timestamp - firstOfDay).TotalMinutes >= 30)
            {
                isCheckIn = false;
            }
            else
            {
                isCheckIn = true;
                firstScanOfDayByCard[dayKey] = timestamp;
            }

            logs.Add(new AttendanceRecord
            {
                Id = BuildDeterministicLogId(branchId, cardNo, timestamp),
                CardNo = cardNo,
                BranchId = branchId,
                DeviceNo = deviceNo,
                Timestamp = FormatTimestampIso(timestamp),
                IsCheckIn = isCheckIn,
                Source = "tenfeiD35",
                VerifyMethod = MapVerifyMethod(verifyType),
                IntegrityHash = string.Empty,
            });
        }

        return logs;
    }

    public static string DecodeCp1254(ReadOnlySpan<byte> bytes, bool stopAtNull = true)
    {
        var sb = new StringBuilder(bytes.Length);
        foreach (var b in bytes)
        {
            if (b == 0)
            {
                if (stopAtNull) break;
                continue;
            }
            switch (b)
            {
                case 0xD0: sb.Append('Ğ'); break;
                case 0xDD: sb.Append('İ'); break;
                case 0xDE: sb.Append('Ş'); break;
                case 0xF0: sb.Append('ğ'); break;
                case 0xFD: sb.Append('ı'); break;
                case 0xFE: sb.Append('ş'); break;
                default: sb.Append((char)b); break;
            }
        }
        return sb.ToString();
    }

    public static List<DeviceUserRecord> DecodeUserBuffer(ReadOnlySpan<byte> raw)
    {
        if (raw.IsEmpty) return new List<DeviceUserRecord>();

        var recordsBytes = raw;
        if (raw.Length >= 76)
        {
            var innerLen = BinaryPrimitives.ReadUInt32LittleEndian(raw.Slice(0, 4));
            if (innerLen == raw.Length - 4 || raw.Length % 72 == 4)
            {
                recordsBytes = raw.Slice(4);
            }
        }

        const int recordSize = 72;
        var users = new List<DeviceUserRecord>();
        var seenCards = new HashSet<string>(StringComparer.Ordinal);

        for (var offset = 0; offset + recordSize <= recordsBytes.Length; offset += recordSize)
        {
            var slice = recordsBytes.Slice(offset, recordSize);
            var uid = BinaryPrimitives.ReadUInt16LittleEndian(slice.Slice(0, 2));
            var name = DecodeCp1254(slice.Slice(11, 24)).Trim();
            var pinSpan = slice.Slice(48, 24);
            var pinNull = pinSpan.IndexOf((byte)0);
            var rawPin = Encoding.ASCII.GetString(pinNull >= 0 ? pinSpan.Slice(0, pinNull) : pinSpan).Trim();
            var effectivePin = string.IsNullOrEmpty(rawPin) ? uid.ToString(CultureInfo.InvariantCulture) : rawPin;
            if (string.IsNullOrEmpty(effectivePin) || effectivePin == "0") continue;

            var cardNo = effectivePin.PadLeft(5, '0');
            if (!seenCards.Add(cardNo)) continue;

            users.Add(new DeviceUserRecord
            {
                CardNo = cardNo,
                FullName = string.IsNullOrEmpty(name) ? $"PERSONEL #{cardNo}" : name,
            });
        }

        return users;
    }

    private static string MapVerifyMethod(int code)
    {
        if (code >= 15) return "face";
        if (code == 1) return "fingerprint";
        if (code == 2 || code == 4) return "card";
        if (code == 3) return "password";
        return "face";
    }

    private readonly record struct ZkPacket(int Command, int Checksum, ushort SessionId, ushort ReplyId, byte[] Payload)
    {
        public static ZkPacket FromBytes(byte[] bytes)
        {
            if (bytes.Length < 8)
            {
                return new ZkPacket(0, 0, 0, 0, Array.Empty<byte>());
            }
            var cmd = BinaryPrimitives.ReadUInt16LittleEndian(bytes.AsSpan(0, 2));
            var csum = BinaryPrimitives.ReadUInt16LittleEndian(bytes.AsSpan(2, 2));
            var sess = BinaryPrimitives.ReadUInt16LittleEndian(bytes.AsSpan(4, 2));
            var rep = BinaryPrimitives.ReadUInt16LittleEndian(bytes.AsSpan(6, 2));
            var payload = bytes.Length > 8 ? bytes[8..] : Array.Empty<byte>();
            return new ZkPacket(cmd, csum, sess, rep, payload);
        }
    }
}
