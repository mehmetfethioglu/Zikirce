using System.Text;
using System.Text.Json;
using HasibuBranchBridge.Models;

namespace HasibuBranchBridge.Storage;

/// <summary>
/// Çevrimdışı dayanıklılık ve anlık yükleme tekrar denemeleri için şube bazlı yerel önbellek.
/// </summary>
public sealed class LocalInboxCache
{
    private const int MaxStoredLogs = 5000;
    private readonly string _cacheFilePath;
    private readonly object _sync = new();
    private LocalInboxCacheState _state;

    public LocalInboxCache(string deviceSlug, string? dataDirectory = null)
    {
        var dir = dataDirectory ?? BridgePaths.GetAppDataDirectory();
        Directory.CreateDirectory(dir);
        _cacheFilePath = Path.Combine(dir, $"cache_{deviceSlug}.json");
        _state = LoadFromDisk();
    }

    public bool PendingUpload
    {
        get { lock (_sync) return _state.PendingUpload; }
    }

    public (int addedOrUpdated, int totalCount) MergeLogs(IEnumerable<AttendanceRecord> incoming)
    {
        lock (_sync)
        {
            var byId = new Dictionary<string, AttendanceRecord>(_state.AttendanceLogs.Count, StringComparer.Ordinal);
            foreach (var item in _state.AttendanceLogs)
            {
                if (!string.IsNullOrWhiteSpace(item.Id))
                {
                    byId[item.Id] = item;
                }
            }

            var changed = 0;
            foreach (var raw in incoming)
            {
                if (string.IsNullOrWhiteSpace(raw.Id) || string.IsNullOrWhiteSpace(raw.CardNo))
                {
                    continue;
                }
                if (byId.TryGetValue(raw.Id, out var existing))
                {
                    if (existing.IsCheckIn != raw.IsCheckIn ||
                        !string.Equals(existing.Timestamp, raw.Timestamp, StringComparison.Ordinal))
                    {
                        byId[raw.Id] = raw;
                        changed++;
                    }
                }
                else
                {
                    byId[raw.Id] = raw;
                    changed++;
                }
            }

            if (changed > 0)
            {
                var trimmed = byId.Values
                    .OrderByDescending(l => l.Timestamp, StringComparer.Ordinal)
                    .Take(MaxStoredLogs)
                    .ToList();
                _state = _state with
                {
                    PendingUpload = true,
                    AttendanceLogs = trimmed,
                };
                SaveToDiskCore(_state);
            }

            return (changed, _state.AttendanceLogs.Count);
        }
    }

    public int MergeUsers(IEnumerable<DeviceUserRecord> incoming)
    {
        lock (_sync)
        {
            var byCard = new Dictionary<string, DeviceUserRecord>(_state.DeviceUsers.Count, StringComparer.Ordinal);
            foreach (var u in _state.DeviceUsers)
            {
                if (!string.IsNullOrWhiteSpace(u.CardNo))
                {
                    byCard[u.CardNo] = u;
                }
            }

            var changed = 0;
            foreach (var u in incoming)
            {
                var card = (u.CardNo ?? string.Empty).Trim().PadLeft(5, '0');
                var name = (u.FullName ?? string.Empty).Trim();
                if (string.IsNullOrEmpty(card) || string.IsNullOrEmpty(name)) continue;

                if (byCard.TryGetValue(card, out var existing))
                {
                    var existingPlaceholder = existing.FullName.StartsWith("PERSONEL #", StringComparison.OrdinalIgnoreCase);
                    var incomingReal = !name.StartsWith("PERSONEL #", StringComparison.OrdinalIgnoreCase);
                    if ((existingPlaceholder && incomingReal) ||
                        (!existingPlaceholder && incomingReal && !string.Equals(existing.FullName, name, StringComparison.Ordinal)))
                    {
                        byCard[card] = new DeviceUserRecord { CardNo = card, FullName = name };
                        changed++;
                    }
                }
                else
                {
                    byCard[card] = new DeviceUserRecord { CardNo = card, FullName = name };
                    changed++;
                }
            }

            if (changed > 0)
            {
                _state = _state with
                {
                    PendingUpload = true,
                    DeviceUsers = byCard.Values.OrderBy(u => u.CardNo, StringComparer.Ordinal).ToList(),
                };
                SaveToDiskCore(_state);
            }
            return changed;
        }
    }

    public BranchInboxPayload BuildPayload(BridgeConfig config)
    {
        lock (_sync)
        {
            return new BranchInboxPayload
            {
                SchemaVersion = 1,
                VaultRole = "branch_inbox",
                CloudProfileId = config.CloudProfileId,
                DeviceSlug = config.DeviceSlug,
                BranchId = config.BranchId,
                BranchCode = config.BranchCode,
                BranchName = config.BranchName,
                DeviceName = config.DeviceName,
                ExportedAt = DateTime.UtcNow.ToString("O"),
                AttendanceLogs = _state.AttendanceLogs.ToList(),
                DeviceUsers = _state.DeviceUsers.ToList(),
            };
        }
    }

    public void MarkPendingUpload()
    {
        lock (_sync)
        {
            if (_state.PendingUpload) return;
            _state = _state with { PendingUpload = true };
            SaveToDiskCore(_state);
        }
    }

    public void MarkUploaded(DateTime utcNow)
    {
        lock (_sync)
        {
            _state = _state with
            {
                PendingUpload = false,
                LastUploadedAtUtc = utcNow.ToString("O"),
            };
            SaveToDiskCore(_state);
        }
    }

    private LocalInboxCacheState LoadFromDisk()
    {
        if (!File.Exists(_cacheFilePath))
        {
            return new LocalInboxCacheState();
        }
        try
        {
            var json = File.ReadAllText(_cacheFilePath, Encoding.UTF8);
            return JsonSerializer.Deserialize(json, BridgeJsonContext.Default.LocalInboxCacheState)
                ?? new LocalInboxCacheState();
        }
        catch
        {
            return new LocalInboxCacheState();
        }
    }

    private void SaveToDiskCore(LocalInboxCacheState state)
    {
        var dir = Path.GetDirectoryName(_cacheFilePath);
        if (!string.IsNullOrEmpty(dir))
        {
            Directory.CreateDirectory(dir);
        }
        var json = JsonSerializer.Serialize(state, BridgeJsonContext.Default.LocalInboxCacheState);
        var tempPath = $"{_cacheFilePath}.{Guid.NewGuid():N}.tmp";
        File.WriteAllText(tempPath, json, Encoding.UTF8);
        File.Move(tempPath, _cacheFilePath, overwrite: true);
    }
}
