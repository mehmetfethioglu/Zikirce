/// Build-time configuration for Kilerce Cloudflare Edge API and RevenueCat SDK.
class KilerceEdgeConfig {
  const KilerceEdgeConfig._();

  static const String apiBaseUrl = String.fromEnvironment(
    'KILERCE_API_BASE_URL',
    defaultValue: 'https://kilerce-edge-api.kilerce.workers.dev',
  );

  static const String hmacSecret = String.fromEnvironment(
    'KILERCE_HMAC_SECRET',
    defaultValue: '',
  );

  static const String revenueCatAndroidKey = String.fromEnvironment(
    'REVENUECAT_ANDROID_KEY',
    defaultValue: '',
  );

  static const String revenueCatIosKey = String.fromEnvironment(
    'REVENUECAT_IOS_KEY',
    defaultValue: '',
  );

  static bool get hasHmacSecret => hmacSecret.trim().isNotEmpty;
}
