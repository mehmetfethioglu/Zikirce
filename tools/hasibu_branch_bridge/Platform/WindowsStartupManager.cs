using System.Diagnostics;
using System.Runtime.InteropServices;
using HasibuBranchBridge.Cloud;
using HasibuBranchBridge.Storage;
using Microsoft.Win32;

namespace HasibuBranchBridge.Platform;

public readonly record struct StartupInstallResult(
    bool UsedTaskScheduler,
    string TargetExecutablePath,
    string EntryName);

/// <summary>
/// Yönetici yetkisi gerektirmeden Mark of the Web (`Zone.Identifier`) temizliği yapar,
/// çalıştırılabilir dosyayı yerel `%LOCALAPPDATA%\HasibuBranchBridge\bin` dizinine yerleştirir
/// ve Windows Görev Zamanlayıcı (`ONLOGON /RL LIMITED`) üzerinden güvenlik uyarısız otomatik başlatır.
/// </summary>
public static class WindowsStartupManager
{
    private const string RunKeyPath = @"Software\Microsoft\Windows\CurrentVersion\Run";
    private const uint InvalidFileAttributes = 0xFFFFFFFF;
    private const int ErrorFileNotFound = 2;

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern bool DeleteFileW(string lpFileName);

    [DllImport("kernel32.dll", CharSet = CharSet.Unicode, SetLastError = true)]
    private static extern uint GetFileAttributesW(string lpFileName);

    public static string GetRegistryValueName(string deviceSlug) =>
        $"HasibuBranchBridge_{deviceSlug}";

    public static string GetInstanceMutexName(string deviceSlug) =>
        $@"Local\HasibuBranchBridge_{GoogleDriveInboxUploader.NormalizeDeviceSlug(deviceSlug)}";

    /// <summary>
    /// Arka plan köprü ajanı (<c>--run</c>) zaten çalışmıyorsa görünmez pencereyle hemen başlatır.
    /// </summary>
    public static (bool Started, bool AlreadyRunning, string Message) StartBackgroundAgent(
        string executablePath,
        string deviceSlug)
    {
        var mutexName = GetInstanceMutexName(deviceSlug);
        try
        {
            if (Mutex.TryOpenExisting(mutexName, out var existing))
            {
                existing.Dispose();
                return (true, true, "Arka plan köprüsü zaten çalışıyor.");
            }
        }
        catch (Exception ex) when (ex is WaitHandleCannotBeOpenedException || ex is UnauthorizedAccessException)
        {
            // Mutex henüz yoksa veya erişilemiyorsa başlatmayı dene
        }
        catch
        {
            // Denetim hatasında başlatmayı dene
        }

        if (string.IsNullOrWhiteSpace(executablePath) || !File.Exists(executablePath))
        {
            return (false, false, $"Arka plan köprüsü çalıştırılabilir dosyası bulunamadı: {executablePath}");
        }

        try
        {
            RemoveMarkOfTheWeb(executablePath);
            using var proc = Process.Start(new ProcessStartInfo
            {
                FileName = executablePath,
                Arguments = "--run",
                WorkingDirectory = Path.GetDirectoryName(executablePath) ?? AppContext.BaseDirectory,
                UseShellExecute = false,
                CreateNoWindow = true,
            });
            if (proc == null)
            {
                return (false, false, "Arka plan köprüsü süreci başlatılamadı.");
            }
            return (true, false, $"Arka plan köprüsü başlatıldı (PID: {proc.Id}).");
        }
        catch (Exception ex)
        {
            return (false, false, $"Arka plan köprüsü başlatma hatası: {ex.Message}");
        }
    }

    /// <summary>
    /// Dosya üzerindeki NTFS `Zone.Identifier` (Mark of the Web) akışını temizleyerek
    /// Windows "Yayımcı doğrulanamadı / Çalıştır-İptal" güvenlik uyarısını kaldırır.
    /// </summary>
    public static bool RemoveMarkOfTheWeb(string? filePath)
    {
        if (string.IsNullOrWhiteSpace(filePath) || !File.Exists(filePath))
        {
            return false;
        }
        try
        {
            var streamPath = $"{filePath}:Zone.Identifier";
            if (DeleteFileW(streamPath))
            {
                return true;
            }
            return Marshal.GetLastWin32Error() == ErrorFileNotFound;
        }
        catch
        {
            return false;
        }
    }

    /// <summary>
    /// Test ve tanılama için dosya üzerinde `Zone.Identifier` akışı olup olmadığını döner.
    /// </summary>
    internal static bool HasMarkOfTheWeb(string? filePath)
    {
        if (string.IsNullOrWhiteSpace(filePath) || !File.Exists(filePath))
        {
            return false;
        }
        try
        {
            return GetFileAttributesW($"{filePath}:Zone.Identifier") != InvalidFileAttributes;
        }
        catch
        {
            return false;
        }
    }

    public static void UnblockDirectory(string? directoryPath)
    {
        if (string.IsNullOrWhiteSpace(directoryPath) || !Directory.Exists(directoryPath))
        {
            return;
        }
        try
        {
            foreach (var file in Directory.EnumerateFiles(directoryPath, "*", SearchOption.TopDirectoryOnly))
            {
                var ext = Path.GetExtension(file);
                if (ext.Equals(".exe", StringComparison.OrdinalIgnoreCase) ||
                    ext.Equals(".bat", StringComparison.OrdinalIgnoreCase) ||
                    ext.Equals(".cmd", StringComparison.OrdinalIgnoreCase) ||
                    ext.Equals(".json", StringComparison.OrdinalIgnoreCase))
                {
                    RemoveMarkOfTheWeb(file);
                }
            }
        }
        catch
        {
            // Salt-okunur veya paylaşılan klasörlerde tarama hatasını yut
        }
    }

    /// <summary>
    /// Hedef çalıştırılabilir dosya yolundan çalışmakta olan arka plan köprü süreçlerini durdurur.
    /// Böylece güncelleme sırasında kilitli EXE dosyası temiz şekilde yenilenebilir.
    /// </summary>
    internal static int StopRunningAgentsAtPath(string targetExecutablePath)
    {
        if (string.IsNullOrWhiteSpace(targetExecutablePath))
        {
            return 0;
        }

        string fullTargetPath;
        try
        {
            fullTargetPath = Path.GetFullPath(targetExecutablePath);
        }
        catch
        {
            return 0;
        }

        var procName = Path.GetFileNameWithoutExtension(fullTargetPath);
        if (string.IsNullOrWhiteSpace(procName))
        {
            return 0;
        }

        var stopped = 0;
        Process[] candidates;
        try
        {
            candidates = Process.GetProcessesByName(procName);
        }
        catch
        {
            return 0;
        }

        foreach (var proc in candidates)
        {
            try
            {
                if (proc.Id == Environment.ProcessId)
                {
                    continue;
                }
                string? modulePath = null;
                try
                {
                    modulePath = proc.MainModule?.FileName;
                }
                catch
                {
                    // Erişilemeyen sistem/yetkili süreçleri atla
                }
                if (string.IsNullOrWhiteSpace(modulePath))
                {
                    continue;
                }
                var fullModulePath = Path.GetFullPath(modulePath);
                if (!string.Equals(fullModulePath, fullTargetPath, StringComparison.OrdinalIgnoreCase))
                {
                    continue;
                }
                proc.Kill(entireProcessTree: false);
                proc.WaitForExit(3000);
                stopped++;
            }
            catch
            {
                // Süreç zaten kapanmış veya sonlandırılamıyor
            }
            finally
            {
                proc.Dispose();
            }
        }
        return stopped;
    }

    public static string StageLocalExecutable(
        string sourceExePath,
        string? targetDirectory = null,
        bool stopRunningTarget = false)
    {
        var destDir = string.IsNullOrWhiteSpace(targetDirectory)
            ? Path.Combine(BridgePaths.GetAppDataDirectory(), "bin")
            : targetDirectory;
        Directory.CreateDirectory(destDir);
        var targetExe = Path.Combine(destDir, Path.GetFileName(sourceExePath));

        RemoveMarkOfTheWeb(sourceExePath);
        if (!string.Equals(
                Path.GetFullPath(sourceExePath),
                Path.GetFullPath(targetExe),
                StringComparison.OrdinalIgnoreCase))
        {
            if (stopRunningTarget && File.Exists(targetExe))
            {
                var stopped = StopRunningAgentsAtPath(targetExe);
                if (stopped > 0)
                {
                    Thread.Sleep(250);
                }
            }
            try
            {
                File.Copy(sourceExePath, targetExe, overwrite: true);
            }
            catch
            {
                if (!File.Exists(targetExe))
                {
                    return sourceExePath;
                }
            }
        }

        RemoveMarkOfTheWeb(targetExe);
        return targetExe;
    }

    private static int TryRunSchtasks(string arguments)
    {
        try
        {
            using var proc = Process.Start(new ProcessStartInfo
            {
                FileName = "schtasks.exe",
                Arguments = arguments,
                CreateNoWindow = true,
                UseShellExecute = false,
                RedirectStandardOutput = true,
                RedirectStandardError = true,
            });
            if (proc == null) return -1;
            if (!proc.WaitForExit(10000))
            {
                try { proc.Kill(); } catch { }
                return -1;
            }
            return proc.ExitCode;
        }
        catch
        {
            return -1;
        }
    }

    private static bool DeleteLegacyRunValue(string deviceSlug)
    {
        try
        {
            using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, writable: true);
            if (key == null) return false;
            var name = GetRegistryValueName(deviceSlug);
            if (key.GetValue(name) == null) return false;
            key.DeleteValue(name, throwOnMissingValue: false);
            return true;
        }
        catch
        {
            return false;
        }
    }

    public static bool IsRegistered(string deviceSlug)
    {
        var name = GetRegistryValueName(deviceSlug);
        if (TryRunSchtasks($"/Query /TN \"{name}\"") == 0)
        {
            return true;
        }
        using var key = Registry.CurrentUser.OpenSubKey(RunKeyPath, writable: false);
        var val = key?.GetValue(name) as string;
        return !string.IsNullOrWhiteSpace(val);
    }

    public static StartupInstallResult Install(
        string deviceSlug,
        string? executablePath = null,
        bool stageToLocalAppData = true)
    {
        var name = GetRegistryValueName(deviceSlug);
        var sourceExe = executablePath ?? Environment.ProcessPath ?? AppContext.BaseDirectory;
        RemoveMarkOfTheWeb(sourceExe);
        UnblockDirectory(Path.GetDirectoryName(sourceExe));

        var targetExe = (stageToLocalAppData &&
            File.Exists(sourceExe) &&
            sourceExe.EndsWith(".exe", StringComparison.OrdinalIgnoreCase))
            ? StageLocalExecutable(sourceExe, stopRunningTarget: true)
            : sourceExe;

        // Explorer'ın ShellExecute üzerinden güvenlik uyarısı tetiklediği eski HKCU\Run kaydını temizle
        DeleteLegacyRunValue(deviceSlug);

        var schtasksArgs = $"/Create /TN \"{name}\" /SC ONLOGON /RL LIMITED /F /TR \"\\\"{targetExe}\\\" --run\"";
        if (TryRunSchtasks(schtasksArgs) == 0)
        {
            return new StartupInstallResult(true, targetExe, name);
        }

        using var key = Registry.CurrentUser.CreateSubKey(RunKeyPath, writable: true)
            ?? throw new InvalidOperationException("Windows Başlangıç kayıt defteri anahtarı açılamadı.");
        key.SetValue(name, $"\"{targetExe}\" --run", RegistryValueKind.String);
        return new StartupInstallResult(false, targetExe, name);
    }

    public static bool Uninstall(string deviceSlug)
    {
        var name = GetRegistryValueName(deviceSlug);
        var taskRemoved = TryRunSchtasks($"/Delete /TN \"{name}\" /F") == 0;
        var regRemoved = DeleteLegacyRunValue(deviceSlug);
        return taskRemoved || regRemoved;
    }
}
