import '../../tv/providers/tv_cast_provider.dart';

/// Zikirce TV modu ve harici ekran yansıtmalarında Mukabele ses–ok
/// senkronizasyon ofsetini ve efektif oynatma saatini hesaplayan saf yardımcı sınıf.
class MukabeleTvSyncHelper {
  MukabeleTvSyncHelper._();

  static const String prefKey = 'tv_mukabele_audio_offset_ms_v1';
  static const int minOffsetMs = -600;
  static const int maxOffsetMs = 300;
  static const int stepMs = 20;

  static const int defaultWirelessCastOffsetMs = -280;
  static const int defaultTvOrWiredOffsetMs = -180;
  static const int defaultLocalTvModeOffsetMs = -60;

  /// Aktif moda ve bağlantıya göre milisaniye cinsinden ses-ok senkron ofsetini döndürür.
  ///
  /// Negatif ofset, ses çıkış gecikmesi (Bluetooth/HDMI/Miracast/TV hoparlör) varken
  /// okun sesin önüne geçmesini engeller.
  static int resolveEffectiveOffsetMs({
    required bool isTvMode,
    required bool isHardwareTv,
    required TvCastState castState,
    int? savedTvOffsetMs,
  }) {
    if (!isTvMode) return 0;
    if (savedTvOffsetMs != null) {
      return savedTvOffsetMs.clamp(minOffsetMs, maxOffsetMs);
    }
    if (castState.isConnected &&
        castState.connectionType == TvCastConnectionType.wireless) {
      return defaultWirelessCastOffsetMs;
    }
    if (isHardwareTv ||
        (castState.isConnected &&
            castState.connectionType == TvCastConnectionType.wired)) {
      return defaultTvOrWiredOffsetMs;
    }
    return defaultLocalTvModeOffsetMs;
  }

  /// Oynatıcı pozisyonu, mikro enterpolasyon ve TV senkron ofsetinden efektif konumu hesaplar.
  static double computeSyncedPositionMs({
    required double playerMs,
    required double microInterpMs,
    required double playbackSpeed,
    required bool isPlayingReady,
    required bool isTvMode,
    required int offsetMs,
  }) {
    if (playerMs <= 0.0) return 0.0;

    final safeSpeed = playbackSpeed <= 0.1 ? 1.0 : playbackSpeed;
    final safeInterp = isPlayingReady
        ? (isTvMode ? 0.0 : (microInterpMs * safeSpeed).clamp(0.0, 16.0))
        : 0.0;

    final synced = playerMs + safeInterp + offsetMs;
    return synced.clamp(0.0, 600000.0);
  }
}
