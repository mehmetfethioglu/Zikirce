import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cue_models.dart';
import '../providers/cuedeck_providers.dart';
import '../widgets/modals/cue_pro_paywall_sheet.dart';
import '../widgets/modals/google_oauth_sheet.dart';
import '../widgets/modals/tv_discovery_pairing_sheets.dart';
import '../widgets/planner/watch_planner_widgets.dart';
import '../widgets/remote/cue_ad_banner.dart';
import '../widgets/remote/quick_launch_app_dock.dart';
import '../widgets/remote/remote_shortcut_picker_sheet.dart';

/// Full-Screen Settings, Theme Switcher, TV Connection Details, Backup, Pro Upgrade
/// & Watch Planner Screen opened via Settings (`⚙️`) or Top-Center TV Status Icon.
class CueDeckSettingsScreen extends ConsumerStatefulWidget {
  const CueDeckSettingsScreen({super.key});

  @override
  ConsumerState<CueDeckSettingsScreen> createState() =>
      _CueDeckSettingsScreenState();
}

class _CueDeckSettingsScreenState
    extends ConsumerState<CueDeckSettingsScreen> {
  late final TextEditingController _ipController;
  late final FocusNode _ipFocusNode;

  @override
  void initState() {
    super.initState();
    final currentDevice = ref.read(cueDeckProvider).selectedDevice;
    _ipController = TextEditingController(
      text: currentDevice.hasValidIp ? currentDevice.ip : '',
    );
    _ipFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _ipController.dispose();
    _ipFocusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<bool>(
      cueDeckProvider.select((s) => s.shouldPromptPaywall),
      (bool? previous, bool next) {
        if (next && mounted && (ModalRoute.of(context)?.isCurrent ?? false)) {
          ref.read(cueDeckProvider.notifier).dismissPaywallPrompt();
          showCueProPaywallSheet(
            context,
            reasonMessage:
                'Ücretsiz planda en fazla ${CueProProductCatalog.maxFreeWatchPlans} özel izleme planı veya günlük ${CueProProductCatalog.maxFreeDailyBeams} ışınlama eklenebilir.',
          );
        }
      },
    );

    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final device = ref.watch(cueDeckProvider.select((s) => s.selectedDevice));
    final discoveredDevices = ref.watch(
      cueDeckProvider.select((s) => s.discoveredDevices),
    );
    final isScanning = ref.watch(cueDeckProvider.select((s) => s.isScanning));
    final status = ref.watch(
      cueDeckProvider.select((s) => s.lastCommandStatus),
    );
    final cueItems = ref.watch(cueDeckProvider.select((s) => s.cueItems));
    final activePlayingId = ref.watch(
      cueDeckProvider.select((s) => s.activePlayingCueId),
    );
    final localWifiIp = ref.watch(
      cueDeckProvider.select((s) => s.localWifiIp),
    );
    final localNetworkPermissionDenied = ref.watch(
      cueDeckProvider.select((s) => s.localNetworkPermissionDenied),
    );

    final pageBg = isDarkMode ? Colors.black : const Color(0xFFF3F6FA);
    final cardBg = isDarkMode ? const Color(0xFF0A0C12) : Colors.white;
    final cardBorder = isDarkMode
        ? Colors.white.withValues(alpha: 0.09)
        : const Color(0xFFE2E8F0);
    final primaryText =
        isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
    final secondaryText =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final goldText =
        isDarkMode ? const Color(0xFFE6C17A) : const Color(0xFFB07A28);
    final softAccentFill =
        isDarkMode ? const Color(0xFFE6C17A) : const Color(0xFFD99B38);
    final inputFill =
        isDarkMode ? const Color(0xFF11141E) : const Color(0xFFF1F5F9);
    final softMint =
        isDarkMode ? const Color(0xFF6EE7B7) : const Color(0xFF059669);
    final softAmber =
        isDarkMode ? const Color(0xFFFCD34D) : const Color(0xFFD97706);
    final bottomSafePadding = MediaQuery.of(context).padding.bottom;

    return Scaffold(
      backgroundColor: pageBg,
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
          child: Column(
            children: <Widget>[
              // Top header bar
              Row(
                children: <Widget>[
                  IconButton(
                    tooltip: 'Kumandaya Dön',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(
                      Icons.arrow_back_ios_new_rounded,
                      size: 19,
                      color: primaryText,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const CueDeckBrandBadge(size: 34),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Text(
                          'CueDeck',
                          style: TextStyle(
                            color: goldText,
                            fontWeight: FontWeight.w800,
                            fontSize: 11.5,
                            letterSpacing: 0.4,
                          ),
                        ),
                        Text(
                          'Ayarlar & İzleme Planı',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: primaryText,
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 5,
                    ),
                    decoration: BoxDecoration(
                      color: (device.isOnline ? softMint : softAmber)
                          .withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Container(
                          width: 6.5,
                          height: 6.5,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: device.isOnline ? softMint : softAmber,
                          ),
                        ),
                        const SizedBox(width: 6),
                        Text(
                          device.isOnline ? 'Çevrimiçi' : 'Simülasyon',
                          style: TextStyle(
                            color: device.isOnline ? softMint : softAmber,
                            fontWeight: FontWeight.w700,
                            fontSize: 11,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const ReminderAlertBanner(),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: bottomSafePadding + 28),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // 1. COMPACT THEME PILL CARD
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 12,
                        ),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Icon(
                                  isDarkMode
                                      ? Icons.dark_mode_outlined
                                      : Icons.light_mode_outlined,
                                  color: goldText,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    'Görünüm Teması',
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: primaryText,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 13.5,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: InkWell(
                                    borderRadius: BorderRadius.circular(20),
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      showCueWhatsNewModal(
                                        context,
                                        isDarkMode: isDarkMode,
                                        initialStartupMode: false,
                                      );
                                    },
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: goldText.withValues(alpha: 0.14),
                                        borderRadius: BorderRadius.circular(20),
                                        border: Border.all(
                                          color: goldText.withValues(
                                            alpha: 0.35,
                                          ),
                                        ),
                                      ),
                                      child: Text(
                                        '📋 Sürüm Notları (${CueReleaseNotesCatalog.currentShortVersion})',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: goldText,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 10.5,
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: ChoiceChip(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    label: const Text(
                                      'Gerçek Siyah (#000000)',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    selected: isDarkMode,
                                    backgroundColor: isDarkMode
                                        ? const Color(0xFF11141E)
                                        : const Color(0xFFF1F5F9),
                                    selectedColor: isDarkMode
                                        ? const Color(0xFF2D2920)
                                        : const Color(0xFFFEF3C7),
                                    checkmarkColor: goldText,
                                    side: BorderSide(
                                      color: isDarkMode
                                          ? goldText.withValues(alpha: 0.55)
                                          : const Color(0xFFCBD5E1),
                                    ),
                                    labelStyle: TextStyle(
                                      color: isDarkMode
                                          ? const Color(0xFFF1F5F9)
                                          : const Color(0xFF2C3342),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                    onSelected: (_) {
                                      ref
                                          .read(cueDeckProvider.notifier)
                                          .setDarkMode(true);
                                    },
                                  ),
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: ChoiceChip(
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 4,
                                    ),
                                    label: const Text(
                                      'Klasik Beyaz Kumanda',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    selected: !isDarkMode,
                                    backgroundColor: isDarkMode
                                        ? const Color(0xFF11141E)
                                        : const Color(0xFFF1F5F9),
                                    selectedColor: isDarkMode
                                        ? const Color(0xFF2D2920)
                                        : const Color(0xFFFEF3C7),
                                    checkmarkColor: goldText,
                                    side: BorderSide(
                                      color: !isDarkMode
                                          ? goldText.withValues(alpha: 0.65)
                                          : cardBorder,
                                    ),
                                    labelStyle: TextStyle(
                                      color: !isDarkMode
                                          ? const Color(0xFF1E293B)
                                          : const Color(0xFFCBD5E1),
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                    onSelected: (_) {
                                      ref
                                          .read(cueDeckProvider.notifier)
                                          .setDarkMode(false);
                                    },
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // 2. UNIVERSAL SMART TV CONNECTION CARD
                      Container(
                        padding: const EdgeInsets.all(14),
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: <Widget>[
                            Row(
                              children: <Widget>[
                                Icon(
                                  Icons.tv_rounded,
                                  color: device.isOnline ? softMint : goldText,
                                  size: 18,
                                ),
                                const SizedBox(width: 8),
                                Expanded(
                                  child: Text(
                                    device.name,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: primaryText,
                                      fontWeight: FontWeight.w700,
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Flexible(
                                  child: Text(
                                    device.displayEndpoint,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      color: secondaryText,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                if (device.hasValidIp) ...<Widget>[
                                  const SizedBox(width: 4),
                                  InkWell(
                                    key: const Key('disconnect_tv_button'),
                                    borderRadius: BorderRadius.circular(14),
                                    onTap: () {
                                      HapticFeedback.selectionClick();
                                      _ipController.clear();
                                      ref
                                          .read(cueDeckProvider.notifier)
                                          .disconnectCurrentTv();
                                    },
                                    child: Padding(
                                      padding: const EdgeInsets.all(2),
                                      child: Icon(
                                        Icons.link_off_rounded,
                                        size: 17,
                                        color: secondaryText,
                                      ),
                                    ),
                                  ),
                                ],
                                const SizedBox(width: 6),
                                InkWell(
                                  borderRadius: BorderRadius.circular(14),
                                  onTap: () => _openTvSetupGuideSheet(context),
                                  child: Padding(
                                    padding: const EdgeInsets.all(2),
                                    child: Icon(
                                      Icons.help_outline_rounded,
                                      size: 17,
                                      color: goldText,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isScanning
                                  ? '📡 Ağdaki Akıllı TV ve Android TV cihazları aranıyor...'
                                  : status,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: device.isOnline ? softMint : secondaryText,
                                fontSize: 11.5,
                                fontWeight: device.isOnline
                                    ? FontWeight.w600
                                    : FontWeight.w400,
                              ),
                            ),
                            if (localWifiIp.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 3),
                              Text(
                                '📱 Telefon Wi-Fi IP: $localWifiIp',
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  color: goldText,
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ],
                            if (localNetworkPermissionDenied) ...<Widget>[
                              const SizedBox(height: 8),
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: const Color(0xFF3F1518),
                                  borderRadius: BorderRadius.circular(12),
                                  border: Border.all(
                                    color: const Color(0xFFF87171),
                                  ),
                                ),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    const Text(
                                      '⚠️ iPhone "Yerel Ağ" İzni Kapalı!',
                                      style: TextStyle(
                                        color: Color(0xFFFCA5A5),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'iOS güvenlik ayarı nedeniyle CueDeck\'in Wi-Fi ağındaki TV\'ye erişimi engelleniyor. Lütfen iPhone Ayarlar > Uygulamalar > CueDeck > Yerel Ağ anahtarını açın.',
                                      style: TextStyle(
                                        color: Color(0xFFFECACA),
                                        fontSize: 10.5,
                                        height: 1.35,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFFF87171),
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(
                                            horizontal: 10,
                                            vertical: 8,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius:
                                                BorderRadius.circular(10),
                                          ),
                                        ),
                                        onPressed: () {
                                          ref
                                              .read(cueDeckProvider.notifier)
                                              .openIosLocalNetworkSettings();
                                        },
                                        icon: const Icon(
                                          Icons.settings_suggest_rounded,
                                          size: 16,
                                        ),
                                        label: const Text(
                                          '📲 iPhone Ayarlarında "Yerel Ağ" İznini Aç',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                            const SizedBox(height: 10),

                            SizedBox(
                              width: double.infinity,
                              child: FilledButton.icon(
                                key: const Key('scan_network_devices_button'),
                                style: FilledButton.styleFrom(
                                  backgroundColor: softAccentFill,
                                  foregroundColor: const Color(0xFF0A0C12),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 14,
                                    vertical: 11,
                                  ),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                                onPressed: () {
                                  HapticFeedback.mediumImpact();
                                  unawaited(
                                    ref
                                        .read(cueDeckProvider.notifier)
                                        .scanNetworkForTvs(),
                                  );
                                  showTvDiscoveryModal(context);
                                },
                                icon: Icon(
                                  isScanning
                                      ? Icons.radar_rounded
                                      : Icons.wifi_find_rounded,
                                  size: 18,
                                ),
                                label: Text(
                                  isScanning
                                      ? 'Ağdaki Cihazlar Aranıyor... (Listeyi Aç)'
                                      : '🔍 Ağdaki Cihazları Ara',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ),

                            const SizedBox(height: 8),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: OutlinedButton(
                                    key: const Key('settings_ir_blaster_button'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: goldText,
                                      side: BorderSide(
                                        color: goldText.withValues(alpha: 0.45),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 9,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      showIrBlasterBrandPickerSheet(context);
                                    },
                                    child: const Text(
                                      '📡 Kızılötesi (IR) Kumanda',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: OutlinedButton(
                                    key: const Key('settings_wake_wol_button'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: primaryText,
                                      side: BorderSide(color: cardBorder),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 9,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () {
                                      HapticFeedback.mediumImpact();
                                      ref
                                          .read(cueDeckProvider.notifier)
                                          .wakeUpSelectedTv();
                                    },
                                    child: const Text(
                                      '⚡ TV Uyandır (WoL)',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),

                            if (discoveredDevices.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 10),
                              Row(
                                children: <Widget>[
                                  Expanded(
                                    child: Text(
                                      'Ağda Bulunan TV\'ler (${discoveredDevices.length}) — Bağlanmak için seçin:',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: secondaryText,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ),
                                  InkWell(
                                    borderRadius: BorderRadius.circular(8),
                                    onTap: () => showTvDiscoveryModal(context),
                                    child: Padding(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 4,
                                        vertical: 2,
                                      ),
                                      child: Text(
                                        'Tümünü Gör',
                                        style: TextStyle(
                                          color: goldText,
                                          fontSize: 11,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 6),
                              Wrap(
                                spacing: 6,
                                runSpacing: 6,
                                children: discoveredDevices.map((d) {
                                  final isSelected = d.ip == device.ip;
                                  return ChoiceChip(
                                    visualDensity: VisualDensity.compact,
                                    label: Text(
                                      '${d.isOnline ? "🟢" : "⚪"} ${d.name} (${d.ip})',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    selected: isSelected,
                                    backgroundColor: inputFill,
                                    selectedColor: isDarkMode
                                        ? const Color(0xFF2D2920)
                                        : const Color(0xFFFEF3C7),
                                    checkmarkColor: goldText,
                                    side: BorderSide(
                                      color: isSelected
                                          ? goldText.withValues(alpha: 0.65)
                                          : cardBorder,
                                    ),
                                    labelStyle: TextStyle(
                                      color: isSelected
                                          ? primaryText
                                          : secondaryText,
                                      fontWeight: FontWeight.w600,
                                      fontSize: 11,
                                    ),
                                    onSelected: (_) async {
                                      HapticFeedback.selectionClick();
                                      _ipController.text = d.ip;
                                      final ok = await ref
                                          .read(cueDeckProvider.notifier)
                                          .connectAndPairDevice(d);
                                      if (!context.mounted) return;
                                      if ((d.protocol ==
                                                  TvConnectionProtocol
                                                      .remotePort6466 &&
                                              d.port == 6466 &&
                                              !d.isPaired) ||
                                          ((d.protocol ==
                                                      TvConnectionProtocol
                                                          .philipsJointSpace1925 ||
                                                  d.protocol ==
                                                      TvConnectionProtocol
                                                          .vidaaSmart36669) &&
                                              !d.isPaired &&
                                              !ok)) {
                                        _openPin6466Dialog(context, d.ip);
                                      } else if (!ok) {
                                        _openInteractiveRsaPairingSheet(
                                          context,
                                          d.ip,
                                        );
                                      }
                                    },
                                  );
                                }).toList(),
                              ),
                            ],

                            const SizedBox(height: 10),

                            Container(
                              width: double.infinity,
                              padding: const EdgeInsets.all(11),
                              decoration: BoxDecoration(
                                color: inputFill,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(
                                  color: goldText.withValues(alpha: 0.25),
                                ),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: <Widget>[
                                  Row(
                                    children: <Widget>[
                                      Icon(
                                        Icons.tips_and_updates_outlined,
                                        color: goldText,
                                        size: 15,
                                      ),
                                      const SizedBox(width: 6),
                                      Expanded(
                                        child: Text(
                                          '3 Adımda Kolay Eşleştirme & Bağlantı',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            color: goldText,
                                            fontWeight: FontWeight.w800,
                                            fontSize: 11.5,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '1️⃣ Yukarıdan "🔍 Ağdaki Cihazları Ara"ya basın. Samsung, LG, Roku, Philips, VIDAA, Sony, Arçelik/Vestel veya Android TV cihazınızı seçin.\n'
                                    '2️⃣ Android TV ise Ayarlar > Cihaz Tercihleri > Hakkında > Yapı Numarası (7 kez) > Geliştirici Seçenekleri > ADB Hata Ayıklama\'yı açın.\n'
                                    '3️⃣ Aşağıdaki "🔐 TV Eşleştir (RSA Onayı)" veya TV ekranındaki 6 haneli PIN ile bağlanın.',
                                    style: TextStyle(
                                      color: secondaryText,
                                      fontSize: 11,
                                      height: 1.4,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            const SizedBox(height: 10),

                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: TextField(
                                    controller: _ipController,
                                    focusNode: _ipFocusNode,
                                    style: TextStyle(
                                      color: primaryText,
                                      fontSize: 13,
                                    ),
                                    decoration: InputDecoration(
                                      hintText: 'TV IP (192.168.1.x)',
                                      hintStyle: TextStyle(
                                        color: secondaryText,
                                        fontSize: 12,
                                      ),
                                      isDense: true,
                                      filled: true,
                                      fillColor: inputFill,
                                      contentPadding:
                                          const EdgeInsets.symmetric(
                                        horizontal: 12,
                                        vertical: 10,
                                      ),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide:
                                            BorderSide(color: cardBorder),
                                      ),
                                      border: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
                                OutlinedButton(
                                  style: OutlinedButton.styleFrom(
                                    foregroundColor: goldText,
                                    side: BorderSide(
                                      color: goldText.withValues(alpha: 0.45),
                                    ),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 10,
                                    ),
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                  ),
                                  onPressed: () {
                                    HapticFeedback.mediumImpact();
                                    final ip = _ipController.text.trim();
                                    unawaited(
                                      ref
                                          .read(cueDeckProvider.notifier)
                                          .scanNetworkForTvs(customIp: ip),
                                    );
                                    if (ip.isEmpty) {
                                      showTvDiscoveryModal(context);
                                    }
                                  },
                                  child: const Text(
                                    'Tara ve Bağlan',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: OutlinedButton(
                                    key: const Key('pair_tv_rsa_button'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: goldText,
                                      backgroundColor:
                                          goldText.withValues(alpha: 0.10),
                                      side: BorderSide(
                                        color: goldText.withValues(alpha: 0.45),
                                      ),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 9,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () {
                                      HapticFeedback.mediumImpact();
                                      final ip = _ipController.text.trim();
                                      _openInteractiveRsaPairingSheet(
                                        context,
                                        ip,
                                      );
                                    },
                                    child: const Text(
                                      '🔐 TV Eşleştir (RSA Onayı)',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: OutlinedButton(
                                    key: const Key('pair_tv_pin_button'),
                                    style: OutlinedButton.styleFrom(
                                      foregroundColor: primaryText,
                                      side: BorderSide(color: cardBorder),
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 9,
                                      ),
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                    ),
                                    onPressed: () {
                                      HapticFeedback.mediumImpact();
                                      final ip = _ipController.text.trim();
                                      _openPin6466Dialog(context, ip);
                                    },
                                    child: const Text(
                                      '🔢 PIN Eşleştir (6466)',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 6),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: TextButton.icon(
                                    key: const Key('switch_tv_profile_button'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: goldText,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      showModalBottomSheet<void>(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (_) =>
                                            const TvAlternativeProfileSheet(),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.tune_rounded,
                                      size: 15,
                                    ),
                                    label: const Text(
                                      '🔄 Alternatif Profil',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                                Expanded(
                                  child: TextButton.icon(
                                    key: const Key('tv_diagnostic_report_button'),
                                    style: TextButton.styleFrom(
                                      foregroundColor: secondaryText,
                                      visualDensity: VisualDensity.compact,
                                    ),
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      showModalBottomSheet<void>(
                                        context: context,
                                        isScrollControlled: true,
                                        backgroundColor: Colors.transparent,
                                        builder: (_) =>
                                            const ConnectionDiagnosticSheet(),
                                      );
                                    },
                                    icon: const Icon(
                                      Icons.medical_information_outlined,
                                      size: 15,
                                    ),
                                    label: const Text(
                                      '🩺 Tanılama Raporu',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      const RemoteShortcutCustomizationCard(),
                      const SizedBox(height: 12),

                      const CueDeckProPassAndUpgradeSection(),
                      const SizedBox(height: 12),

                      const _GoogleDriveBackupSection(),
                      const SizedBox(height: 14),

                      const WatchPlanMasteryHeader(),
                      const SizedBox(height: 12),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: <Widget>[
                          Expanded(
                            child: Text(
                              'İzleme Planı (${cueItems.length})',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: primaryText,
                                fontWeight: FontWeight.w700,
                                fontSize: 14.5,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          FilledButton.icon(
                            style: FilledButton.styleFrom(
                              backgroundColor: softAccentFill,
                              foregroundColor: const Color(0xFF141824),
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 8,
                              ),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                              ),
                            ),
                            onPressed: () => _openAddCueModal(context),
                            icon: const Icon(Icons.add_rounded, size: 17),
                            label: const Text(
                              'Plan Ekle',
                              style: TextStyle(
                                fontWeight: FontWeight.w700,
                                fontSize: 12,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      for (final item in cueItems)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 10),
                          child: WatchCueCard(
                            item: item,
                            isPlayingOnTv: item.id == activePlayingId,
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const Padding(
                padding: EdgeInsets.only(top: 6, bottom: 8),
                child: CueNonIntrusiveAdBanner(),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _openAddCueModal(BuildContext context) {
    final notifier = ref.read(cueDeckProvider.notifier);
    if (!notifier.canAddMoreWatchPlans) {
      showCueProPaywallSheet(
        context,
        reasonMessage:
            'Ücretsiz sürümde en fazla ${CueProProductCatalog.maxFreeWatchPlans} özel izleme planı ekleyebilirsiniz.',
      );
      return;
    }
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const AddWatchCueSheet(),
    );
  }

  void _openInteractiveRsaPairingSheet(BuildContext context, String targetIp) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => InteractiveTvPairingSheet(customIp: targetIp),
    );
  }

  void _openPin6466Dialog(BuildContext context, String targetIp) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Pin6466PairingSheet(targetIp: targetIp),
    );
  }

  void _openTvSetupGuideSheet(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => const TvSetupGuideSheet(),
    );
  }
}

/// CueDeck Pro Lifetime + 3-Tier Paywall Launch + 24-Hour Rewarded Pro Pass + Loyalty card.
class CueDeckProPassAndUpgradeSection extends ConsumerWidget {
  const CueDeckProPassAndUpgradeSection({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final entitlement = ref.watch(cueDeckProvider.select((s) => s.entitlement));

    final isProLifetime = entitlement.isProLifetime;
    final isPassActive = entitlement.isProPassActive();
    final isSubActive = entitlement.isSubscriptionActive();
    final rewardedDays = entitlement.rewardedDaysCount;
    final isLoyaltyUnlocked = entitlement.isLoyaltyDiscountUnlocked;

    final cardBg = isDarkMode ? const Color(0xFF0A0C12) : Colors.white;
    final primaryText =
        isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
    final secondaryText =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final goldText =
        isDarkMode ? const Color(0xFFE6C17A) : const Color(0xFFB48328);
    final mintText =
        isDarkMode ? const Color(0xFF6EE7B7) : const Color(0xFF059669);
    final subSurfaceBg =
        isDarkMode ? const Color(0xFF11141E) : const Color(0xFFF8FAFC);
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.09)
        : const Color(0xFFE2E8F0);

    void showToast(String message) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF0A0C12),
            content: Text(
              message,
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
            ),
          ),
        );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                (isProLifetime || isSubActive)
                    ? Icons.verified_rounded
                    : Icons.workspace_premium_rounded,
                color: (isProLifetime || isSubActive) ? mintText : goldText,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  isProLifetime ? 'CueDeck Pro' : 'CueDeck Pro & 24s Pass',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: (isProLifetime || isSubActive || isPassActive)
                      ? mintText.withValues(alpha: 0.14)
                      : goldText.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  isProLifetime
                      ? 'ÖMÜR BOYU'
                      : (isSubActive
                            ? 'ABONELİK AKTİF'
                            : (isPassActive
                                  ? 'PASS (${entitlement.formattedRemainingProPass()})'
                                  : 'ÜCRETSİZ')),
                  style: TextStyle(
                    color: (isProLifetime || isSubActive || isPassActive)
                        ? mintText
                        : goldText,
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          if (isProLifetime || isSubActive) ...<Widget>[
            Text(
              'Reklamsız kullanım, sınırsız izleme planı, Share-to-TV ışınlama ve bulut yedekleme aktif.',
              style: TextStyle(
                color: secondaryText,
                fontSize: 12,
              ),
            ),
          ] else ...<Widget>[
            Text(
              '3 Gün Ücretsiz Yıllık Deneme, Tek Seferlik Ömür Boyu veya 1 Reklamla 24s Pro.',
              style: TextStyle(
                color: secondaryText,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: subSurfaceBg,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    isLoyaltyUnlocked
                        ? '🎉 %40 Sadakat İndirimi Açıldı (${CueProProductCatalog.priceLoyalty40Tr})'
                        : '🎁 Sadakat İndirimi: $rewardedDays/${CueProProductCatalog.loyaltyDiscountTargetDays} Gün (%40 İndirim)',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: goldText,
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(6),
                    child: LinearProgressIndicator(
                      value: entitlement.loyaltyProgressRatio,
                      minHeight: 4,
                      backgroundColor: isDarkMode
                          ? Colors.white.withValues(alpha: 0.08)
                          : Colors.black.withValues(alpha: 0.06),
                      valueColor: AlwaysStoppedAnimation<Color>(goldText),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: goldText,
                      foregroundColor: const Color(0xFF0A0C12),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    onPressed: () async {
                      HapticFeedback.mediumImpact();
                      final res = await ref
                          .read(cueDeckProvider.notifier)
                          .purchaseLifetimePro();
                      showToast(res.message);
                    },
                    child: Text(
                      isLoyaltyUnlocked
                          ? '💎 Pro Al (${CueProProductCatalog.priceLoyalty40Tr})'
                          : '💎 Pro Al (${CueProProductCatalog.priceLaunchTr})',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryText,
                      side: BorderSide(color: borderColor),
                      backgroundColor: subSurfaceBg,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 10,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(11),
                      ),
                    ),
                    onPressed: () async {
                      HapticFeedback.selectionClick();
                      final res = await ref
                          .read(cueDeckProvider.notifier)
                          .unlockProPassWithRewardedAd();
                      showToast(res.message);
                    },
                    child: const Text(
                      '🎬 24 Saat Ücretsiz Aç',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                key: const Key('settings_open_paywall_button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: goldText,
                  side: BorderSide(color: goldText.withValues(alpha: 0.45)),
                  padding: const EdgeInsets.symmetric(vertical: 9),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                onPressed: () {
                  HapticFeedback.selectionClick();
                  showCueProPaywallSheet(context);
                },
                child: const Text(
                  '✨ Tüm Planları Gör (3 Gün Ücretsiz Dene)',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5),
                ),
              ),
            ),
          ],
          if (isProLifetime || isSubActive || isPassActive) ...<Widget>[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: secondaryText,
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(vertical: 6),
                ),
                onPressed: () async {
                  HapticFeedback.selectionClick();
                  final res = await ref
                      .read(cueDeckProvider.notifier)
                      .resetProPassToFree();
                  showToast(res.message);
                },
                icon: const Icon(Icons.restart_alt_rounded, size: 15),
                label: Text(
                  isProLifetime
                      ? 'Ücretsiz Sürüme Dön (Test Pro Sıfırla)'
                      : 'Ücretsiz Sürüme Dön (Pass Sıfırla)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _GoogleDriveBackupSection extends ConsumerWidget {
  const _GoogleDriveBackupSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final isSignedIn = ref.watch(
      cueDeckProvider.select((s) => s.isGoogleSignedIn),
    );
    final userEmail = ref.watch(
      cueDeckProvider.select((s) => s.googleUserEmail),
    );
    final userName = ref.watch(
      cueDeckProvider.select((s) => s.googleUserName),
    );
    final lastBackupFormatted = ref.watch(
      cueDeckProvider.select((s) => s.lastBackupTimeFormatted),
    );
    final isAutoEnabled = ref.watch(
      cueDeckProvider.select((s) => s.isAutoCloudBackupEnabled),
    );
    final isProcessing = ref.watch(
      cueDeckProvider.select((s) => s.isProcessingBackup),
    );

    final cardBg = isDarkMode ? const Color(0xFF0A0C12) : Colors.white;
    final primaryText =
        isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
    final secondaryText =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final goldText =
        isDarkMode ? const Color(0xFFE6C17A) : const Color(0xFFB48328);
    final mintText =
        isDarkMode ? const Color(0xFF6EE7B7) : const Color(0xFF059669);
    final subSurfaceBg =
        isDarkMode ? const Color(0xFF11141E) : const Color(0xFFF8FAFC);
    final buttonBorder = isDarkMode
        ? Colors.white.withValues(alpha: 0.09)
        : const Color(0xFFE2E8F0);
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.09)
        : const Color(0xFFE2E8F0);

    void showMessage(String msg) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF0A0C12),
            content: Text(
              msg,
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
            ),
          ),
        );
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: borderColor),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(
                isSignedIn
                    ? Icons.cloud_done_rounded
                    : Icons.cloud_upload_rounded,
                color: isSignedIn ? mintText : goldText,
                size: 19,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Bulut & Yerel Yedekleme',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    color: primaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
              ),
              if (isProcessing)
                SizedBox(
                  width: 15,
                  height: 15,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: goldText,
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),

          if (!isSignedIn) ...<Widget>[
            Text(
              'Planlarınızı Google Drive veya yerel dosyaya yedekleyin.',
              style: TextStyle(
                color: secondaryText,
                fontSize: 12,
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: goldText,
                  foregroundColor: const Color(0xFF141824),
                  elevation: 0,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                onPressed: isProcessing
                    ? null
                    : () async {
                        HapticFeedback.mediumImpact();
                        final ok = await GoogleOAuthSheet.startOAuth(context);
                        if (!context.mounted) return;
                        if (ok) {
                          final notifier = ref.read(cueDeckProvider.notifier);
                          await notifier.refreshGoogleDriveStatus();
                          final syncRes =
                              await notifier.syncDevicesWithCloud();
                          showMessage(syncRes.message);
                        }
                      },
                child: const Text(
                  '🔑 Google Hesabını Bağla',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12.5),
                ),
              ),
            ),
          ] else ...<Widget>[
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: subSurfaceBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Container(
                        width: 7,
                        height: 7,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: mintText,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          userEmail.isNotEmpty
                              ? '${userName.isNotEmpty ? userName : "Google Drive"} ($userEmail)'
                              : (userName.isNotEmpty
                                  ? userName
                                  : 'Google Drive Bağlı'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: primaryText,
                            fontWeight: FontWeight.w600,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Google Hesabından Çıkış Yap',
                        visualDensity: VisualDensity.compact,
                        onPressed: isProcessing
                            ? null
                            : () async {
                                final res = await ref
                                    .read(cueDeckProvider.notifier)
                                    .signOutGoogleDrive();
                                showMessage(res.message);
                              },
                        icon: Icon(
                          Icons.close_rounded,
                          color: secondaryText,
                          size: 16,
                        ),
                      ),
                    ],
                  ),
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          'Otomatik yedekleme • Son: $lastBackupFormatted',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: secondaryText,
                            fontSize: 11,
                          ),
                        ),
                      ),
                      Transform.scale(
                        scale: 0.82,
                        child: Switch(
                          value: isAutoEnabled,
                          activeThumbColor: mintText,
                          materialTapTargetSize:
                              MaterialTapTargetSize.shrinkWrap,
                          onChanged: isProcessing
                              ? null
                              : (val) {
                                  HapticFeedback.selectionClick();
                                  ref
                                      .read(cueDeckProvider.notifier)
                                      .toggleAutoCloudBackup(val);
                                },
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 8),

            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    style: FilledButton.styleFrom(
                      backgroundColor: mintText,
                      foregroundColor: const Color(0xFF0F172A),
                      elevation: 0,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 9,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: isProcessing
                        ? null
                        : () async {
                            HapticFeedback.mediumImpact();
                            final res = await ref
                                .read(cueDeckProvider.notifier)
                                .syncDevicesWithCloud();
                            showMessage(res.message);
                          },
                    child: const Text(
                      '🔄 Eşitle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: goldText,
                      side: BorderSide(color: buttonBorder),
                      backgroundColor: subSurfaceBg,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 9,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: isProcessing
                        ? null
                        : () async {
                            HapticFeedback.mediumImpact();
                            final res = await ref
                                .read(cueDeckProvider.notifier)
                                .backupNowToCloud();
                            showMessage(res.message);
                          },
                    child: const Text(
                      '☁️ Yedekle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      foregroundColor: primaryText,
                      side: BorderSide(color: buttonBorder),
                      backgroundColor: subSurfaceBg,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 9,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                    onPressed: isProcessing
                        ? null
                        : () async {
                            HapticFeedback.selectionClick();
                            final notifier =
                                ref.read(cueDeckProvider.notifier);
                            final backups =
                                await notifier.fetchAvailableBackups();
                            if (!context.mounted) return;
                            if (backups.isEmpty) {
                              showMessage(
                                'Bulutta veya cihazda kayıtlı yedek bulunamadı.',
                              );
                              return;
                            }
                            _showCloudBackupPickerSheet(
                              context,
                              ref,
                              backups,
                              showMessage,
                            );
                          },
                    child: const Text(
                      '☁️ Yükle',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(height: 8),

          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryText,
                    side: BorderSide(color: buttonBorder),
                    backgroundColor: subSurfaceBg,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 9,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: isProcessing
                      ? null
                      : () async {
                          HapticFeedback.selectionClick();
                          final res = await ref
                              .read(cueDeckProvider.notifier)
                              .exportLocalBackupFile();
                          showMessage(res.message);
                        },
                  child: const Text(
                    '💾 Dosyaya Yedekle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryText,
                    side: BorderSide(color: buttonBorder),
                    backgroundColor: subSurfaceBg,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 9,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: isProcessing
                      ? null
                      : () async {
                          HapticFeedback.selectionClick();
                          final res = await ref
                              .read(cueDeckProvider.notifier)
                              .importLocalBackupFile();
                          showMessage(res.message);
                        },
                  child: const Text(
                    '📂 Dosyadan Yükle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 11.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _showCloudBackupPickerSheet(
    BuildContext context,
    WidgetRef ref,
    List<CloudBackupInfo> backups,
    void Function(String) showMessage,
  ) {
    final isDarkMode = ref.read(cueDeckProvider).isDarkMode;
    final sheetBg =
        isDarkMode ? const Color(0xFF10131C) : const Color(0xFFF3F5F9);
    final itemBg = isDarkMode ? const Color(0xFF161A26) : Colors.white;
    final primaryText = isDarkMode ? Colors.white : const Color(0xFF141821);
    final secondaryText = isDarkMode
        ? Colors.white.withValues(alpha: 0.68)
        : const Color(0xFF525B6C);
    final goldText =
        isDarkMode ? const Color(0xFFE2A84B) : const Color(0xFFB87818);

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (sheetCtx) {
        return Container(
          decoration: BoxDecoration(
            color: sheetBg,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    children: <Widget>[
                      Expanded(
                        child: Text(
                          '☁️ Bulut Yedeği Seçin',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            color: primaryText,
                            fontWeight: FontWeight.w800,
                            fontSize: 15.5,
                          ),
                        ),
                      ),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: () => Navigator.of(sheetCtx).pop(),
                        icon: Icon(
                          Icons.close_rounded,
                          color: secondaryText,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ListView.separated(
                      shrinkWrap: true,
                      itemCount: backups.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 8),
                      itemBuilder: (_, index) {
                        final item = backups[index];
                        final isNewest = index == 0;
                        return InkWell(
                          borderRadius: BorderRadius.circular(14),
                          onTap: () async {
                            Navigator.of(sheetCtx).pop();
                            final res = await ref
                                .read(cueDeckProvider.notifier)
                                .restoreFromBackup(fileId: item.fileId);
                            showMessage(res.message);
                          },
                          child: Container(
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: itemBg,
                              borderRadius: BorderRadius.circular(14),
                              border: Border.all(
                                color: isNewest
                                    ? const Color(0xFFE2A84B)
                                        .withValues(alpha: 0.65)
                                    : (isDarkMode
                                        ? Colors.white.withValues(alpha: 0.10)
                                        : const Color(0xFFD8DEE8)),
                              ),
                            ),
                            child: Row(
                              children: <Widget>[
                                Text(
                                  item.isLocal ? '💾' : '☁️',
                                  style: const TextStyle(fontSize: 20),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Row(
                                        children: <Widget>[
                                          Flexible(
                                            child: Text(
                                              item.displayName,
                                              maxLines: 1,
                                              overflow: TextOverflow.ellipsis,
                                              style: TextStyle(
                                                color: primaryText,
                                                fontWeight: FontWeight.w700,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          if (isNewest) ...<Widget>[
                                            const SizedBox(width: 6),
                                            Container(
                                              padding:
                                                  const EdgeInsets.symmetric(
                                                horizontal: 6,
                                                vertical: 2,
                                              ),
                                              decoration: BoxDecoration(
                                                color: const Color(0xFFE2A84B)
                                                    .withValues(alpha: 0.22),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Text(
                                                '⭐ EN YENİ',
                                                style: TextStyle(
                                                  color: goldText,
                                                  fontWeight: FontWeight.w800,
                                                  fontSize: 9.5,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
                                      ),
                                      const SizedBox(height: 3),
                                      Text(
                                        '📅 ${item.formattedDate} • 📱 ${item.deviceName}'
                                        '${item.planCount != null ? ' • 🎬 Plan: ${item.planCount}' : ''}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: secondaryText,
                                          fontSize: 11,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Icon(
                                  Icons.download_rounded,
                                  color: goldText,
                                  size: 18,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Opens the CueDeck "What's New & Release Notes" modal sheet.
Future<void> showCueWhatsNewModal(
  BuildContext context, {
  required bool isDarkMode,
  bool initialStartupMode = false,
}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (BuildContext ctx) {
      return CueWhatsNewModalSheet(
        isDarkMode: isDarkMode,
        initialStartupMode: initialStartupMode,
      );
    },
  );
}

/// Scrollable Release Notes modal sheet displaying current and historical CueDeck versions.
class CueWhatsNewModalSheet extends StatefulWidget {
  const CueWhatsNewModalSheet({
    super.key,
    required this.isDarkMode,
    required this.initialStartupMode,
  });

  final bool isDarkMode;
  final bool initialStartupMode;

  @override
  State<CueWhatsNewModalSheet> createState() => _CueWhatsNewModalSheetState();
}

class _CueWhatsNewModalSheetState extends State<CueWhatsNewModalSheet> {
  late bool _showAllHistory;

  @override
  void initState() {
    super.initState();
    _showAllHistory = !widget.initialStartupMode;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = widget.isDarkMode;
    final sheetBg = isDark ? const Color(0xFF141824) : const Color(0xFFF3F6FA);
    final cardBg = isDark ? const Color(0xFF1E2433) : Colors.white;
    final borderColor = isDark
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);
    final primaryText =
        isDark ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
    final secondaryText =
        isDark ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final goldText = isDark ? const Color(0xFFE6C17A) : const Color(0xFFB07A28);
    final mintText = isDark ? const Color(0xFF6EE7B7) : const Color(0xFF059669);

    final visibleEntries = _showAllHistory
        ? CueReleaseNotesCatalog.versions
        : <CueReleaseVersionEntry>[CueReleaseNotesCatalog.latest];

    return FractionallySizedBox(
      heightFactor: 0.82,
      child: Container(
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
          border: Border.all(color: borderColor),
        ),
        child: SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Center(
                  child: Container(
                    width: 40,
                    height: 4,
                    decoration: BoxDecoration(
                      color: secondaryText.withValues(alpha: 0.35),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Row(
                  children: <Widget>[
                    const CueDeckBrandBadge(size: 36),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            widget.initialStartupMode
                                ? '🎉 CueDeck Güncellendi!'
                                : '📋 CueDeck Sürüm Notları',
                            style: TextStyle(
                              color: primaryText,
                              fontWeight: FontWeight.w800,
                              fontSize: 16,
                            ),
                          ),
                          Text(
                            'Bu sürümde neler değişti • ${CueReleaseNotesCatalog.latest.versionLabel}',
                            style: TextStyle(
                              color: goldText,
                              fontWeight: FontWeight.w600,
                              fontSize: 12,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Kapat',
                      onPressed: () => Navigator.of(context).pop(),
                      icon: Icon(Icons.close_rounded, color: secondaryText),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Expanded(
                  child: SingleChildScrollView(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: <Widget>[
                        for (var index = 0;
                            index < visibleEntries.length;
                            index++) ...<Widget>[
                          if (index > 0) const SizedBox(height: 12),
                          _buildVersionEntryCard(
                            entry: visibleEntries[index],
                            isLatest: index == 0,
                            cardBg: cardBg,
                            borderColor: borderColor,
                            primaryText: primaryText,
                            secondaryText: secondaryText,
                            goldText: goldText,
                            mintText: mintText,
                          ),
                        ],
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                Row(
                  children: <Widget>[
                    if (!_showAllHistory &&
                        CueReleaseNotesCatalog.versions.length > 1) ...<Widget>[
                      Expanded(
                        child: OutlinedButton.icon(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: primaryText,
                            side: BorderSide(color: borderColor),
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              _showAllHistory = true;
                            });
                          },
                          icon: const Icon(Icons.history_rounded, size: 17),
                          label: const Text(
                            'Önceki Sürümler',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: FilledButton(
                        style: FilledButton.styleFrom(
                          backgroundColor: goldText,
                          foregroundColor: const Color(0xFF141824),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text(
                          'Harika, Devam Et',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 12.5,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildVersionEntryCard({
    required CueReleaseVersionEntry entry,
    required bool isLatest,
    required Color cardBg,
    required Color borderColor,
    required Color primaryText,
    required Color secondaryText,
    required Color goldText,
    required Color mintText,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: isLatest ? goldText.withValues(alpha: 0.35) : borderColor,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: <Widget>[
              Flexible(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: (isLatest ? mintText : goldText)
                        .withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    isLatest
                        ? 'AKTİF SÜRÜM • ${entry.versionLabel}'
                        : entry.versionLabel,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: isLatest ? mintText : goldText,
                      fontWeight: FontWeight.w800,
                      fontSize: 10.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                entry.releaseDate,
                style: TextStyle(
                  color: secondaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            entry.headline,
            style: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.w700,
              fontSize: 13.5,
            ),
          ),
          const SizedBox(height: 10),
          ...entry.highlights.map(
            (CueReleaseNoteItem item) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Container(
                    margin: const EdgeInsets.only(top: 2),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 2,
                    ),
                    decoration: BoxDecoration(
                      color: goldText.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      item.badge,
                      style: TextStyle(
                        color: goldText,
                        fontWeight: FontWeight.w800,
                        fontSize: 9.5,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Text(
                          item.title,
                          style: TextStyle(
                            color: primaryText,
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          item.description,
                          style: TextStyle(
                            color: secondaryText,
                            fontSize: 11.5,
                            height: 1.35,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
