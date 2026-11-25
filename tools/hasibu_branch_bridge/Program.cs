using System.Text;
using System.Text.Json;
using HasibuBranchBridge.Cloud;
using HasibuBranchBridge.Engine;
using HasibuBranchBridge.Models;
using HasibuBranchBridge.Platform;
using HasibuBranchBridge.Protocol;
using HasibuBranchBridge.Storage;

namespace HasibuBranchBridge;

internal static class Program
{
    private static readonly JsonSerializerOptions PrettyConfigJsonOptions = new()
    {
        PropertyNamingPolicy = JsonNamingPolicy.CamelCase,
        WriteIndented = true,
        DefaultIgnoreCondition = System.Text.Json.Serialization.JsonIgnoreCondition.WhenWritingNull,
    };

    private static async Task<int> Main(string[] args)
    {
        WindowsStartupManager.RemoveMarkOfTheWeb(Environment.ProcessPath);
        var command = args.Length == 0 ? "--run" : args[0].Trim().ToLowerInvariant();
        var isBackgroundRun = command is "--run" or "-r";

        if (!isBackgroundRun)
        {
            ConsoleHelper.EnsureInteractiveConsole();
        }

        if (command is "--help" or "-h" or "/?")
        {
            PrintUsage();
            return 0;
        }

        var logger = new RotatingFileLogger(echoToConsole: !isBackgroundRun);
        var secretStore = new DpapiSecretStore();

        try
        {
            return command switch
            {
                "--setup" => await RunSetupWizardAsync(secretStore, logger),
                "--import-config" => ImportConfigCommand(args.Skip(1).FirstOrDefault(), secretStore, logger),
                "--test" => await RunOnceOrTestAsync(secretStore, logger, isTestMode: true),
                "--run-once" => await RunOnceOrTestAsync(secretStore, logger, isTestMode: false),
                "--install-startup" => InstallStartupCommand(secretStore, logger),
                "--uninstall-startup" => UninstallStartupCommand(secretStore, logger),
                "--run" or "-r" => await RunHeadlessBackgroundAsync(secretStore, logger),
                _ => UnknownCommand(command),
            };
        }
        catch (Exception ex)
        {
            logger.Error($"Beklenmeyen hata: {ex}");
            if (!isBackgroundRun)
            {
                Console.Error.WriteLine($"HATA: {ex.Message}");
            }
            return 1;
        }
    }

    private static int UnknownCommand(string command)
    {
        Console.Error.WriteLine($"Bilinmeyen komut: {command}");
        PrintUsage();
        return 64;
    }

    private static void PrintUsage()
    {
        Console.WriteLine("""
            Hasibu Şube Yüz Okutma Köprüsü (Windows 10 x64 Arka Plan Ajanı)

            Kullanım:
              HasibuBranchBridge.exe                 Ekransız arka plan dinleme modunu başlatır (--run)
              HasibuBranchBridge.exe --setup         Etkileşimli kurulum & Google Drive giriş sihirbazı
              HasibuBranchBridge.exe --import-config <dosya.json>
                                                     Hasibu'dan kopyalanan şube ayar JSON'unu içe aktarır
              HasibuBranchBridge.exe --test          Terminal TCP 4370 ve Google Drive yüklemesini test eder
              HasibuBranchBridge.exe --run-once      Tek seferlik çekim + Drive yüklemesi yapıp çıkar
              HasibuBranchBridge.exe --install-startup
                                                     Windows oturum açılışında otomatik başlamayı ekler
              HasibuBranchBridge.exe --uninstall-startup
                                                     Windows başlangıcından kaldırır
              HasibuBranchBridge.exe --help          Bu yardım bilgisini gösterir
            """);
    }

    private static BridgeConfig? TryLoadConfig(DpapiSecretStore secretStore)
    {
        var path = BridgePaths.ResolveReadableConfigPath();
        if (!File.Exists(path)) return null;
        var json = File.ReadAllText(path, Encoding.UTF8);
        var cfg = JsonSerializer.Deserialize(json, BridgeJsonContext.Default.BridgeConfig);
        if (cfg != null && !string.IsNullOrWhiteSpace(cfg.WorkspaceKey))
        {
            SaveSanitizedConfig(cfg, secretStore);
            var portablePath = Path.Combine(AppContext.BaseDirectory, "config.json");
            if (string.Equals(path, portablePath, StringComparison.OrdinalIgnoreCase))
            {
                try
                {
                    var sanitized = cfg with { WorkspaceKey = null };
                    File.WriteAllText(portablePath, JsonSerializer.Serialize(sanitized, PrettyConfigJsonOptions), Encoding.UTF8);
                }
                catch
                {
                    // Kurulum dizini salt-okunur olabilir; %LOCALAPPDATA% kopyası temizlendi.
                }
            }
            return cfg with { WorkspaceKey = null };
        }
        return cfg;
    }

    private static void SaveSanitizedConfig(BridgeConfig config, DpapiSecretStore secretStore)
    {
        if (!string.IsNullOrWhiteSpace(config.WorkspaceKey))
        {
            secretStore.Update(s => s with { WorkspaceKey = config.WorkspaceKey.Trim() });
        }

        var normalizedSlug = GoogleDriveInboxUploader.NormalizeDeviceSlug(config.DeviceSlug);
        var sanitized = config with
        {
            DeviceSlug = normalizedSlug,
            CloudProfileId = GoogleDriveInboxUploader.NormalizeCloudProfileId(config.CloudProfileId),
            WorkspaceKey = null,
        };

        var targetPath = BridgePaths.GetDefaultConfigPath();
        Directory.CreateDirectory(Path.GetDirectoryName(targetPath)!);
        var json = JsonSerializer.Serialize(sanitized, PrettyConfigJsonOptions);
        var temp = $"{targetPath}.{Guid.NewGuid():N}.tmp";
        File.WriteAllText(temp, json, Encoding.UTF8);
        File.Move(temp, targetPath, overwrite: true);
    }

    private static int ImportConfigCommand(string? sourcePath, DpapiSecretStore secretStore, RotatingFileLogger logger)
    {
        if (string.IsNullOrWhiteSpace(sourcePath) || !File.Exists(sourcePath))
        {
            Console.Error.WriteLine("HATA: Geçerli bir ayar JSON dosya yolu verin (--import-config <dosya.json>).");
            return 64;
        }

        var raw = File.ReadAllText(sourcePath, Encoding.UTF8);
        var cfg = JsonSerializer.Deserialize(raw, BridgeJsonContext.Default.BridgeConfig)
            ?? throw new InvalidDataException("Ayar JSON dosyası okunamadı.");

        SaveSanitizedConfig(cfg, secretStore);
        logger.Info($"Ayarlar içe aktarıldı ve Workspace Key DPAPI kasasına taşındı: {BridgePaths.GetDefaultConfigPath()}");
        return 0;
    }

    private static async Task<int> RunSetupWizardAsync(DpapiSecretStore secretStore, RotatingFileLogger logger)
    {
        Console.WriteLine("=================================================================");
        Console.WriteLine(" Hasibu Şube Yüz Okutma Köprüsü — Kurulum Sihirbazı");
        Console.WriteLine("=================================================================");
        Console.WriteLine();
        Console.WriteLine("İsterseniz Hasibu -> Bulut Merkezi -> 'Şube Köprüsü Ayar JSON Kopyala'");
        Console.WriteLine("ile aldığınız JSON dosyasının yolunu girin veya Enter ile elle devam edin.");
        Console.Write("Ayar JSON dosya yolu (boş = elle giriş): ");
        var importPath = (Console.ReadLine() ?? string.Empty).Trim().Trim('"');

        BridgeConfig config;
        if (!string.IsNullOrEmpty(importPath) && File.Exists(importPath))
        {
            var imported = JsonSerializer.Deserialize(File.ReadAllText(importPath, Encoding.UTF8), BridgeJsonContext.Default.BridgeConfig)
                ?? throw new InvalidDataException("JSON ayrıştırılamadı.");
            SaveSanitizedConfig(imported, secretStore);
            config = TryLoadConfig(secretStore) ?? imported;
            Console.WriteLine($"✓ Ayarlar içe aktarıldı: {config.BranchName} ({config.TerminalIp}:{config.TerminalPort})");
        }
        else
        {
            var existing = TryLoadConfig(secretStore) ?? new BridgeConfig();
            Console.Write($"Şube Adı [{existing.BranchName}]: ");
            var branchName = ReadOrDefault(existing.BranchName);
            Console.Write($"Şube Kodu [{existing.BranchCode}]: ");
            var branchCode = ReadOrDefault(existing.BranchCode).ToUpperInvariant();
            Console.Write($"Şube ID [{existing.BranchId}]: ");
            var branchId = int.TryParse(ReadOrDefault(existing.BranchId.ToString()), out var bid) ? bid : existing.BranchId;
            Console.Write($"Cihaz Kısa Adı (Slug) [{GoogleDriveInboxUploader.NormalizeDeviceSlug($"{branchCode}_d35")}]: ");
            var deviceSlug = GoogleDriveInboxUploader.NormalizeDeviceSlug(
                ReadOrDefault(GoogleDriveInboxUploader.NormalizeDeviceSlug($"{branchCode}_d35")));
            Console.Write($"Yüz Okutma Cihazı IP [{existing.TerminalIp}]: ");
            var ip = ReadOrDefault(existing.TerminalIp);
            Console.Write($"TCP Port [{existing.TerminalPort}]: ");
            var port = int.TryParse(ReadOrDefault(existing.TerminalPort.ToString()), out var p) ? p : existing.TerminalPort;
            Console.Write($"CommKey [{existing.CommKey}]: ");
            var commKey = int.TryParse(ReadOrDefault(existing.CommKey.ToString()), out var ck) ? ck : existing.CommKey;
            Console.Write($"Bulut Profil Kodu [{existing.CloudProfileId}]: ");
            var profileId = GoogleDriveInboxUploader.NormalizeCloudProfileId(ReadOrDefault(existing.CloudProfileId));

            var currentSecrets = secretStore.Load();
            Console.Write(string.IsNullOrEmpty(currentSecrets.WorkspaceKey)
                ? "Hasibu Workspace Key (Şifreleme Anahtarı): "
                : "Hasibu Workspace Key [kayıtlı anahtarı korumak için Enter]: ");
            var wkInput = Console.ReadLine()?.Trim() ?? string.Empty;
            var finalWk = string.IsNullOrEmpty(wkInput) ? currentSecrets.WorkspaceKey : wkInput;

            config = new BridgeConfig
            {
                DeviceSlug = deviceSlug,
                DeviceName = $"{branchName} Akıllı Terazi Köprüsü",
                CloudProfileId = profileId,
                BranchId = branchId,
                BranchCode = branchCode,
                BranchName = branchName,
                TerminalIp = ip,
                TerminalPort = port,
                MachineNo = Math.Max(1, branchId),
                CommKey = commKey,
                WorkspaceKey = finalWk,
            };
            SaveSanitizedConfig(config, secretStore);
            config = TryLoadConfig(secretStore) ?? config;
        }

        Console.WriteLine();
        Console.Write("Google Drive hesabıyla şimdi tarayıcı üzerinden oturum açılsın mı? [E/h]: ");
        var signInAns = (Console.ReadLine() ?? "E").Trim();
        if (!signInAns.StartsWith("h", StringComparison.OrdinalIgnoreCase))
        {
            using var oauth = new GoogleOAuthPkceClient(secretStore);
            var (cid, csec) = oauth.ResolveClientCredentials();
            string? overrideId = null;
            string? overrideSecret = null;
            if (string.IsNullOrWhiteSpace(cid))
            {
                Console.Write("Google OAuth Client ID (.apps.googleusercontent.com): ");
                overrideId = Console.ReadLine()?.Trim();
            }
            if (string.IsNullOrWhiteSpace(csec))
            {
                Console.Write("Google OAuth Client Secret (varsa): ");
                overrideSecret = Console.ReadLine()?.Trim();
            }
            Console.Write("Google (Gmail) E-Posta İpucu [isteğe bağlı]: ");
            var hint = Console.ReadLine()?.Trim();

            Console.WriteLine("Tarayıcıda Google giriş penceresi açılıyor...");
            var res = await oauth.SignInInteractiveAsync(hint, overrideId, overrideSecret);
            Console.WriteLine(res.Success
                ? $"✓ {res.Message} ({res.Email})"
                : $"⚠️ OAuth girişi tamamlanamadı: {res.Message}");
        }

        Console.WriteLine();
        Console.WriteLine("Canlı bağlantı & Google Drive kutu testi çalıştırılıyor...");
        var testExit = await RunOnceOrTestAsync(secretStore, logger, isTestMode: true);

        Console.WriteLine();
        Console.Write("Windows açılışında arka planda otomatik başlasın mı? [E/h]: ");
        var startupAns = (Console.ReadLine() ?? "E").Trim();
        if (!startupAns.StartsWith("h", StringComparison.OrdinalIgnoreCase))
        {
            var installRes = WindowsStartupManager.Install(config.DeviceSlug);
            var modeLabel = installRes.UsedTaskScheduler
                ? "Görev Zamanlayıcı (uyarısız)"
                : "Başlangıç kayıt defteri";
            Console.WriteLine($"✓ Windows başlangıcına eklendi [{modeLabel}]: {installRes.EntryName} -> {installRes.TargetExecutablePath}");
            var startRes = WindowsStartupManager.StartBackgroundAgent(installRes.TargetExecutablePath, config.DeviceSlug);
            Console.WriteLine(startRes.Started
                ? $"✓ {startRes.Message}"
                : $"⚠️ {startRes.Message}");
        }
        else
        {
            Console.Write("Şube köprüsü şimdi arka planda başlatılsın mı? [E/h]: ");
            var runNowAns = (Console.ReadLine() ?? "E").Trim();
            if (!runNowAns.StartsWith("h", StringComparison.OrdinalIgnoreCase))
            {
                var targetExe = Environment.ProcessPath ?? AppContext.BaseDirectory;
                var startRes = WindowsStartupManager.StartBackgroundAgent(targetExe, config.DeviceSlug);
                Console.WriteLine(startRes.Started
                    ? $"✓ {startRes.Message}"
                    : $"⚠️ {startRes.Message}");
            }
        }

        Console.WriteLine();
        Console.WriteLine($"Kurulum dosyası: {BridgePaths.GetDefaultConfigPath()}");
        Console.WriteLine($"Günlük klasörü : {logger.LogDirectory}");
        return testExit;
    }

    private static async Task<int> RunOnceOrTestAsync(DpapiSecretStore secretStore, RotatingFileLogger logger, bool isTestMode)
    {
        var config = TryLoadConfig(secretStore);
        if (config == null)
        {
            Console.Error.WriteLine("HATA: Yapılandırma bulunamadı. Önce --setup veya --import-config çalıştırın.");
            return 78;
        }

        await using var terminal = new TenfeiZkClient(config.TerminalIp, config.TerminalPort, config.BranchId, config.MachineNo, config.CommKey);
        using var oauth = new GoogleOAuthPkceClient(secretStore);
        using var uploader = new GoogleDriveInboxUploader(secretStore, oauth);
        var cache = new LocalInboxCache(config.DeviceSlug);
        await using var service = new BranchBridgeService(config, terminal, uploader, cache, logger);

        var (terminalOk, logsFetched, usersFetched, upload) = await service.RunOnceAsync(forceUpload: isTestMode);
        logger.Info($"Test/Tekil Çalışma -> Terminal={(terminalOk ? "BAĞLI" : "ULAŞILAMADI")}, Kayıt={logsFetched}, Kişi={usersFetched}, Bulut={upload.Detail}");
        return upload.Success ? 0 : 1;
    }

    private static int InstallStartupCommand(DpapiSecretStore secretStore, RotatingFileLogger logger)
    {
        var config = TryLoadConfig(secretStore);
        var slug = GoogleDriveInboxUploader.NormalizeDeviceSlug(config?.DeviceSlug ?? "sube_d35");
        var installRes = WindowsStartupManager.Install(slug);
        var modeLabel = installRes.UsedTaskScheduler
            ? "Görev Zamanlayıcı (uyarısız)"
            : "Başlangıç kayıt defteri";
        logger.Info($"Windows başlangıcına kaydedildi [{modeLabel}]: {installRes.EntryName} -> {installRes.TargetExecutablePath}");
        var startRes = WindowsStartupManager.StartBackgroundAgent(installRes.TargetExecutablePath, slug);
        if (startRes.Started)
        {
            logger.Info(startRes.Message);
        }
        else
        {
            logger.Warn(startRes.Message);
        }
        return 0;
    }

    private static int UninstallStartupCommand(DpapiSecretStore secretStore, RotatingFileLogger logger)
    {
        var config = TryLoadConfig(secretStore);
        var slug = GoogleDriveInboxUploader.NormalizeDeviceSlug(config?.DeviceSlug ?? "sube_d35");
        var removed = WindowsStartupManager.Uninstall(slug);
        logger.Info(removed
            ? $"Windows başlangıcından kaldırıldı: {WindowsStartupManager.GetRegistryValueName(slug)}"
            : "Kayıtlı başlangıç girdisi bulunamadı.");
        return 0;
    }

    private static async Task<int> RunHeadlessBackgroundAsync(DpapiSecretStore secretStore, RotatingFileLogger logger)
    {
        var config = TryLoadConfig(secretStore);
        if (config == null)
        {
            logger.Error($"Yapılandırma bulunamadı ({BridgePaths.GetDefaultConfigPath()}). Önce --setup çalıştırın.");
            return 78;
        }

        var mutexName = WindowsStartupManager.GetInstanceMutexName(config.DeviceSlug);
        using var instanceMutex = new Mutex(initiallyOwned: true, mutexName, out var createdNew);
        if (!createdNew)
        {
            logger.Warn($"Ajan zaten çalışıyor ({mutexName}); ikinci örnek kapatılıyor.");
            return 0;
        }

        using var cts = new CancellationTokenSource();
        void OnCancelKeyPress(object? _, ConsoleCancelEventArgs e)
        {
            e.Cancel = true;
            cts.Cancel();
        }
        void OnProcessExit(object? _, EventArgs __) => cts.Cancel();

        Console.CancelKeyPress += OnCancelKeyPress;
        AppDomain.CurrentDomain.ProcessExit += OnProcessExit;

        try
        {
            await using var terminal = new TenfeiZkClient(config.TerminalIp, config.TerminalPort, config.BranchId, config.MachineNo, config.CommKey);
            using var oauth = new GoogleOAuthPkceClient(secretStore);
            using var uploader = new GoogleDriveInboxUploader(secretStore, oauth);
            var cache = new LocalInboxCache(config.DeviceSlug);
            await using var service = new BranchBridgeService(config, terminal, uploader, cache, logger);

            await service.RunLoopAsync(cts.Token).ConfigureAwait(false);
            return 0;
        }
        finally
        {
            Console.CancelKeyPress -= OnCancelKeyPress;
            AppDomain.CurrentDomain.ProcessExit -= OnProcessExit;
        }
    }

    private static string ReadOrDefault(string fallback)
    {
        var val = Console.ReadLine()?.Trim();
        return string.IsNullOrEmpty(val) ? fallback : val;
    }
}
