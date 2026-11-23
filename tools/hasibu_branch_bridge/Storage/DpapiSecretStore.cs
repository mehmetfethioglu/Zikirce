using System.Security.Cryptography;
using System.Text;
using System.Text.Json;
using HasibuBranchBridge.Models;

namespace HasibuBranchBridge.Storage;

/// <summary>
/// Windows DPAPI (CurrentUser) kullanarak OAuth belirteçlerini ve Workspace Key sırrını
/// şifreli şekilde saklar; disk yazımlarını atomik dosya değişimiyle yapar.
/// </summary>
public sealed class DpapiSecretStore
{
    private static readonly byte[] Entropy = Encoding.UTF8.GetBytes("hasibu-branch-bridge-dpapi-v1");
    private readonly string _secretFilePath;
    private readonly object _sync = new();

    public DpapiSecretStore(string? dataDirectory = null)
    {
        var dir = dataDirectory ?? BridgePaths.GetAppDataDirectory();
        Directory.CreateDirectory(dir);
        _secretFilePath = Path.Combine(dir, "secrets.dpapi");
    }

    public BridgeSecrets Load()
    {
        lock (_sync)
        {
            if (!File.Exists(_secretFilePath))
            {
                return new BridgeSecrets();
            }
            try
            {
                var protectedBytes = File.ReadAllBytes(_secretFilePath);
                var clearBytes = ProtectedData.Unprotect(protectedBytes, Entropy, DataProtectionScope.CurrentUser);
                var json = Encoding.UTF8.GetString(clearBytes);
                return JsonSerializer.Deserialize(json, BridgeJsonContext.Default.BridgeSecrets)
                    ?? new BridgeSecrets();
            }
            catch
            {
                return new BridgeSecrets();
            }
        }
    }

    public void Save(BridgeSecrets secrets)
    {
        lock (_sync)
        {
            var dir = Path.GetDirectoryName(_secretFilePath);
            if (!string.IsNullOrEmpty(dir))
            {
                Directory.CreateDirectory(dir);
            }
            var json = JsonSerializer.Serialize(secrets, BridgeJsonContext.Default.BridgeSecrets);
            var clearBytes = Encoding.UTF8.GetBytes(json);
            var protectedBytes = ProtectedData.Protect(clearBytes, Entropy, DataProtectionScope.CurrentUser);
            var tempPath = $"{_secretFilePath}.{Guid.NewGuid():N}.tmp";
            File.WriteAllBytes(tempPath, protectedBytes);
            File.Move(tempPath, _secretFilePath, overwrite: true);
        }
    }

    public void Update(Func<BridgeSecrets, BridgeSecrets> updater)
    {
        lock (_sync)
        {
            var current = Load();
            Save(updater(current));
        }
    }
}

public static class BridgePaths
{
    public static string GetAppDataDirectory()
    {
        var localAppData = Environment.GetFolderPath(Environment.SpecialFolder.LocalApplicationData);
        if (string.IsNullOrWhiteSpace(localAppData))
        {
            localAppData = AppContext.BaseDirectory;
        }
        return Path.Combine(localAppData, "HasibuBranchBridge");
    }

    public static string GetDefaultConfigPath() =>
        Path.Combine(GetAppDataDirectory(), "config.json");

    public static string ResolveReadableConfigPath()
    {
        var appDataConfig = GetDefaultConfigPath();
        if (File.Exists(appDataConfig)) return appDataConfig;
        var portableConfig = Path.Combine(AppContext.BaseDirectory, "config.json");
        return File.Exists(portableConfig) ? portableConfig : appDataConfig;
    }
}
