import '../models/cue_models.dart';

/// Diagnostic log callback passed from the orchestrator to modular drivers.
typedef TvDiagLogger = void Function(String message);

/// Fine-grained capabilities supported by an individual [TvRemoteDriver].
enum TvCapability {
  keyNavigation,
  pointerCursor,
  scrollWheel,
  liveKeyboard,
  appLaunch,
  youtubePlaylistBeam,
  wakeOnLan,
  pinPairing,
  irBlaster,
}

/// Encrypted key-value vault abstraction for persistent Smart TV pairing tokens
/// (Samsung `token`, LG `client-key`, Sony `PSK`, etc.).
abstract interface class TvSecretVault {
  Future<String?> readSecret(String key);
  Future<void> writeSecret(String key, String value);
  Future<void> deleteSecret(String key);
}

/// Uniform SOLID / LSP driver contract implemented by every Smart TV protocol driver.
/// Unsupported actions MUST deterministically return `false` (never throw `UnimplementedError`).
abstract interface class TvRemoteDriver {
  TvConnectionProtocol get protocol;
  Set<TvCapability> get capabilities;

  Future<TvDevice> pair(TvDevice device, {String? pinCode});
  Future<bool> sendKey(TvDevice device, TvKeyCommand command);
  Future<bool> movePointer(TvDevice device, double dx, double dy);
  Future<bool> clickPointer(TvDevice device, {bool rightClick = false});
  Future<bool> scrollWheel(TvDevice device, int wheelClicks);
  Future<bool> sendText(
    TvDevice device,
    String text, {
    bool submitEnter = false,
    bool clearExisting = false,
  });
  Future<bool> sendBackspace(TvDevice device, {int count = 1});
  Future<bool> sendEnter(TvDevice device);
  Future<bool> launchContent(
    TvDevice device, {
    required StreamingPlatform platform,
    String deepLinkUrl = '',
    String fallbackSearchQuery = '',
  });
  Future<bool> wakeOnLan(TvDevice device);
  void dispose();
}
