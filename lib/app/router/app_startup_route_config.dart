/// Holds the pre-loaded startup route preference so `appRouter` resolves its
/// initial location synchronously on the very first frame without flicker.
class AppStartupRouteConfig {
  static bool openDirectlyOnZikir = false;

  static String resolveInitialLocation({required bool isHardwareTv}) {
    if (isHardwareTv) return '/';
    return openDirectlyOnZikir ? '/zikir' : '/';
  }
}
