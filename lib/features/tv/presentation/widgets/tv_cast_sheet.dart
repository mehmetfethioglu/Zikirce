import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/haptic_service.dart';
import '../../../../core/theme/app_theme_colors.dart';
import '../../providers/tv_cast_provider.dart';

/// Zikirce TV modunda harici televizyona (Samsung Smart View, LG Screen Share,
/// Miracast, Apple TV, AirPlay 2, Chromecast, HDMI/USB-C) ekran yansıtmayı
/// yöneten modal pencere.
class TvCastSheet extends ConsumerStatefulWidget {
  const TvCastSheet({super.key});

  static Future<void> show(BuildContext context) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TvCastSheet(),
    );
  }

  @override
  ConsumerState<TvCastSheet> createState() => _TvCastSheetState();
}

class _TvCastSheetState extends ConsumerState<TvCastSheet> {
  Timer? _autoCloseTimer;
  bool _pickerFallbackHintVisible = false;

  @override
  void initState() {
    super.initState();
    unawaited(ref.read(tvCastProvider.notifier).refreshStatus());
  }

  @override
  void dispose() {
    _autoCloseTimer?.cancel();
    super.dispose();
  }

  Future<void> _handleOpenPicker() async {
    HapticService.tapClick();
    final opened = await ref.read(tvCastProvider.notifier).openCastPicker();
    if (!opened && mounted) {
      setState(() {
        _pickerFallbackHintVisible = true;
      });
    }
  }

  void _scheduleAutoCloseOnMirroring() {
    _autoCloseTimer?.cancel();
    _autoCloseTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted && Navigator.of(context).canPop()) {
        Navigator.of(context).pop();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<TvCastState>(tvCastProvider, (prev, next) {
      if (prev != null && !prev.isVisualMirroring && next.isVisualMirroring) {
        _scheduleAutoCloseOnMirroring();
      }
    });

    final castState = ref.watch(tvCastProvider);
    final colors = context.colors;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isTr = AppLocalizations.of(context).isTurkish;
    final screenHeight = MediaQuery.sizeOf(context).height;

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        child: ConstrainedBox(
          constraints: BoxConstraints(
            maxWidth: 560,
            maxHeight: screenHeight * 0.9,
          ),
          child: Material(
            color: Colors.transparent,
            child: Container(
              decoration: BoxDecoration(
                color: colors.bottomSheetBg,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                  color: colors.borderStroke,
                  width: 1.2,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: isDark ? 0.45 : 0.16),
                    blurRadius: 24,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: colors.borderStroke,
                          borderRadius: BorderRadius.circular(999),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    _CastSheetHeader(
                      colors: colors,
                      isTr: isTr,
                      isConnected: castState.isVisualMirroring,
                      onClose: () => Navigator.of(context).pop(),
                    ),
                    const SizedBox(height: 14),
                    if (castState.isVisualMirroring)
                      _CastConnectedCard(
                        colors: colors,
                        isDark: isDark,
                        isTr: isTr,
                        castState: castState,
                        onContinue: () => Navigator.of(context).pop(),
                        onSwitchDevice: _handleOpenPicker,
                      )
                    else ...[
                      if (castState.connectionType ==
                          TvCastConnectionType.airplayAudio) ...[
                        _AirPlayAudioOnlyNotice(
                          colors: colors,
                          isTr: isTr,
                          deviceName: castState.deviceName,
                        ),
                        const SizedBox(height: 10),
                      ],
                      if (castState.isIos)
                        _CastIosGuideCard(colors: colors, isTr: isTr)
                      else
                        _CastAndroidGuideCard(colors: colors, isTr: isTr),
                      const SizedBox(height: 12),
                      ElevatedButton.icon(
                        key: const Key('tv_cast_open_picker_button'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: colors.accent,
                          foregroundColor: Colors.white,
                          minimumSize: const Size.fromHeight(46),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        onPressed: castState.isOpeningPicker
                            ? null
                            : _handleOpenPicker,
                        icon: castState.isOpeningPicker
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : const Icon(Icons.cast_rounded, size: 20),
                        label: Text(
                          castState.isIos
                              ? (isTr
                                  ? 'AirPlay TV / Ses Cihazı Seç'
                                  : 'Select AirPlay TV / Audio')
                              : (isTr
                                  ? 'TV / Ekran Yansıtma Seçicisini Aç'
                                  : 'Open TV / Screen Cast Picker'),
                          style: const TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                    if (_pickerFallbackHintVisible) ...[
                      const SizedBox(height: 10),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: colors.cardBackgroundAlt,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.borderStroke),
                        ),
                        child: Text(
                          isTr
                              ? 'Cihazınız sistem yansıtma penceresini doğrudan açmaya izin vermediyse, telefonun Hızlı Ayarlar panelinden «Yayınla / Smart View / Ekran Yansıtma» seçeneğini kullanabilirsiniz.'
                              : 'If your device did not open the cast sheet automatically, open Quick Settings and tap Cast / Smart View / Screen Mirroring.',
                          style: TextStyle(
                            fontSize: 11.5,
                            height: 1.35,
                            color: colors.secondaryTextAlt,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 8),
                    TextButton(
                      key: const Key('tv_cast_skip_button'),
                      onPressed: () => Navigator.of(context).pop(),
                      child: Text(
                        isTr
                            ? 'Şimdilik Bu Cihazda Kullan'
                            : 'Use on This Device for Now',
                        style: TextStyle(
                          fontSize: 12.5,
                          fontWeight: FontWeight.w700,
                          color: colors.secondaryTextAlt,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _CastSheetHeader extends StatelessWidget {
  final AppThemeColors colors;
  final bool isTr;
  final bool isConnected;
  final VoidCallback onClose;

  const _CastSheetHeader({
    required this.colors,
    required this.isTr,
    required this.isConnected,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.accent.withValues(alpha: 0.14),
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            isConnected ? Icons.cast_connected_rounded : Icons.cast_rounded,
            color: colors.accent,
            size: 22,
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                isTr
                    ? "TV'ye Yansıt (Büyük Ekran)"
                    : 'Cast to TV (Big Screen)',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                  color: colors.primaryText,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                isTr
                    ? 'Android olmayan akıllı TV’lerde Zikirce TV görünümünü yansıtın'
                    : 'Mirror Zikirce TV onto non-Android smart TVs',
                style: TextStyle(
                  fontSize: 11.5,
                  color: colors.secondaryTextAlt,
                ),
              ),
            ],
          ),
        ),
        Semantics(
          button: true,
          label: isTr ? 'Kapat' : 'Close',
          child: Tooltip(
            message: isTr ? 'Kapat' : 'Close',
            child: InkWell(
              key: const Key('tv_cast_sheet_close_button'),
              onTap: onClose,
              borderRadius: BorderRadius.circular(22),
              child: SizedBox(
                width: 44,
                height: 44,
                child: Center(
                  child: Icon(
                    Icons.close_rounded,
                    size: 20,
                    color: colors.secondaryTextAlt,
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _CastConnectedCard extends StatelessWidget {
  final AppThemeColors colors;
  final bool isDark;
  final bool isTr;
  final TvCastState castState;
  final VoidCallback onContinue;
  final VoidCallback onSwitchDevice;

  const _CastConnectedCard({
    required this.colors,
    required this.isDark,
    required this.isTr,
    required this.castState,
    required this.onContinue,
    required this.onSwitchDevice,
  });

  @override
  Widget build(BuildContext context) {
    final successColor =
        isDark ? const Color(0xFF4ADE80) : const Color(0xFF15803D);
    final deviceLabel = castState.deviceName ??
        (isTr ? 'Harici TV Ekranı' : 'External TV Display');
    final typeLabel = castState.connectionType == TvCastConnectionType.wired
        ? (isTr ? 'Kablolu (HDMI / USB-C)' : 'Wired (HDMI / USB-C)')
        : (isTr ? 'Kablosuz Yansıtma' : 'Wireless Mirroring');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: successColor.withValues(alpha: isDark ? 0.14 : 0.08),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: successColor.withValues(alpha: 0.45),
          width: 1.2,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(Icons.check_circle_rounded, color: successColor, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isTr ? "TV'ye Yansıtılıyor" : 'Mirroring to TV',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: colors.primaryText,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: successColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  typeLabel,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w700,
                    color: successColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            deviceLabel,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w700,
              color: colors.secondaryText,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: colors.accent,
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  onPressed: onContinue,
                  child: Text(
                    isTr ? 'Büyük Ekranda Devam Et' : 'Continue on Big Screen',
                    style: const TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: colors.primaryText,
                  side: BorderSide(color: colors.borderStroke),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                onPressed: onSwitchDevice,
                child: Text(
                  isTr ? 'Cihaz Değiştir' : 'Switch TV',
                  style: const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CastAndroidGuideCard extends StatelessWidget {
  final AppThemeColors colors;
  final bool isTr;

  const _CastAndroidGuideCard({
    required this.colors,
    required this.isTr,
  });

  static const List<String> _supportedTargets = [
    'Samsung Smart View',
    'LG Screen Share',
    'Miracast',
    'Chromecast',
    'HDMI / USB-C',
  ];

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: _supportedTargets
                .map(
                  (label) => Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: colors.accent.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      label,
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: colors.accentText,
                      ),
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 10),
          Text(
            isTr
                ? 'Telefonunuz ve TV’niz aynı Wi-Fi ağındayken aşağıdaki butondan TV’nizi seçin; Zikirce TV tam ekran yatay düzeniyle doğrudan büyük ekrana yansıtılır.'
                : 'Make sure your phone and TV are on the same Wi-Fi network, then select your TV below to mirror Zikirce TV in full-screen landscape.',
            style: TextStyle(
              fontSize: 12,
              height: 1.35,
              color: colors.secondaryText,
            ),
          ),
        ],
      ),
    );
  }
}

class _CastIosGuideCard extends StatelessWidget {
  final AppThemeColors colors;
  final bool isTr;

  const _CastIosGuideCard({
    required this.colors,
    required this.isTr,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(13),
      decoration: BoxDecoration(
        color: colors.cardBackground,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: colors.borderStroke),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            isTr
                ? 'AirPlay 2 TV (Samsung, LG, Sony, Apple TV)'
                : 'AirPlay 2 TV (Samsung, LG, Sony, Apple TV)',
            style: TextStyle(
              fontSize: 12.5,
              fontWeight: FontWeight.w800,
              color: colors.primaryText,
            ),
          ),
          const SizedBox(height: 8),
          _IosStepRow(
            number: '1',
            text: isTr
                ? "Ekranın sağ üst köşesinden Denetim Merkezi'ni aşağı kaydırın."
                : 'Swipe down from the top-right corner to open Control Center.',
            colors: colors,
          ),
          const SizedBox(height: 6),
          _IosStepRow(
            number: '2',
            text: isTr
                ? "«Ekran Yansıtma» simgesine dokunup TV'nizi seçin; bağlanınca bu pencere otomatik kapanır."
                : 'Tap «Screen Mirroring» and choose your TV; this sheet closes once connected.',
            colors: colors,
          ),
          const SizedBox(height: 8),
          Text(
            isTr
                ? 'Kablolu bağlantı için HDMI / USB-C adaptörü taktığınızda büyük ekran otomatik algılanır.'
                : 'For wired connections, plug in an HDMI / USB-C adapter to mirror automatically.',
            style: TextStyle(
              fontSize: 11,
              color: colors.secondaryTextAlt,
              height: 1.3,
            ),
          ),
        ],
      ),
    );
  }
}

class _IosStepRow extends StatelessWidget {
  final String number;
  final String text;
  final AppThemeColors colors;

  const _IosStepRow({
    required this.number,
    required this.text,
    required this.colors,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 20,
          height: 20,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: colors.accent.withValues(alpha: 0.16),
          ),
          child: Text(
            number,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w800,
              color: colors.accentText,
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            text,
            style: TextStyle(
              fontSize: 12,
              height: 1.3,
              color: colors.secondaryText,
            ),
          ),
        ),
      ],
    );
  }
}

class _AirPlayAudioOnlyNotice extends StatelessWidget {
  final AppThemeColors colors;
  final bool isTr;
  final String? deviceName;

  const _AirPlayAudioOnlyNotice({
    required this.colors,
    required this.isTr,
    required this.deviceName,
  });

  @override
  Widget build(BuildContext context) {
    final target = deviceName ?? 'AirPlay';
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: colors.accent.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: colors.accent.withValues(alpha: 0.35)),
      ),
      child: Row(
        children: [
          Icon(Icons.speaker_group_rounded, color: colors.accent, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              isTr
                  ? '$target ses çıkışı bağlı. Tam ekran görüntü için Denetim Merkezi → Ekran Yansıtma seçeneğini açın.'
                  : '$target audio is connected. For full-screen video, enable Control Center → Screen Mirroring.',
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: colors.primaryText,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
