using System.Diagnostics;
using System.Runtime.InteropServices;
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

    public static string StageLocalExecutable(string sourceExePath, string? targetDirectory = null)
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
            ? StageLocalExecutable(sourceExe)
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
