using System.Text;
using HasibuBranchBridge.Storage;

namespace HasibuBranchBridge.Platform;

/// <summary>
/// Günlük dosyaya dönen ve 14 günden eski kayıtları otomatik temizleyen hafif günlükleyici.
/// </summary>
public sealed class RotatingFileLogger
{
    private const int RetentionDays = 14;
    private readonly string _logDirectory;
    private readonly bool _echoToConsole;
    private readonly object _sync = new();
    private DateTime _lastPruneDate = DateTime.MinValue;

    public RotatingFileLogger(string? logDirectory = null, bool echoToConsole = false)
    {
        _logDirectory = logDirectory ?? Path.Combine(BridgePaths.GetAppDataDirectory(), "logs");
        _echoToConsole = echoToConsole;
        Directory.CreateDirectory(_logDirectory);
    }

    public string LogDirectory => _logDirectory;

    public void Info(string message) => Write("INFO", message);
    public void Warn(string message) => Write("WARN", message);
    public void Error(string message) => Write("ERR ", message);

    private void Write(string level, string message)
    {
        var now = DateTime.Now;
        var line = $"[{now:yyyy-MM-dd HH:mm:ss}] [{level}] {message}";
        if (_echoToConsole)
        {
            Console.WriteLine(line);
        }

        lock (_sync)
        {
            try
            {
                var filePath = Path.Combine(_logDirectory, $"bridge_{now:yyyy-MM-dd}.log");
                File.AppendAllText(filePath, line + Environment.NewLine, Encoding.UTF8);
                if (_lastPruneDate.Date != now.Date)
                {
                    _lastPruneDate = now.Date;
                    PruneOldLogs(now.Date.AddDays(-RetentionDays));
                }
            }
            catch
            {
                // Günlük yazma hatası arka plan ajanını durdurmamalı
            }
        }
    }

    private void PruneOldLogs(DateTime cutoffDate)
    {
        foreach (var file in Directory.EnumerateFiles(_logDirectory, "bridge_*.log"))
        {
            try
            {
                var info = new FileInfo(file);
                if (info.LastWriteTime < cutoffDate)
                {
                    info.Delete();
                }
            }
            catch
            {
                // Yoksay
            }
        }
    }
}
