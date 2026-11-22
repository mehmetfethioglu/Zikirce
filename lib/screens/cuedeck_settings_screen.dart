import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/cue_models.dart';
import '../providers/cuedeck_providers.dart';
import '../widgets/modals/cue_pro_paywall_sheet.dart';
import '../widgets/modals/google_oauth_sheet.dart';
import '../widgets/modals/share_to_tv_beam_sheet.dart';
import '../widgets/modals/tv_discovery_pairing_sheets.dart';
import '../widgets/modals/wake_on_lan_setup_sheet.dart';
import '../widgets/remote/cue_ad_banner.dart';
import '../widgets/remote/quick_launch_app_dock.dart';
import '../widgets/remote/remote_shortcut_picker_sheet.dart';

/// Simplified, calm Settings screen opened via Settings (`⚙️`) or Top-Center TV Status Icon.
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
  bool _showAdvancedConnection = false;

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
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final device = ref.watch(cueDeckProvider.select((s) => s.selectedDevice));
    final discoveredDevices = ref.watch(
      cueDeckProvider.select((s) => s.discoveredDevices),
    );
    final isScanning = ref.watch(cueDeckProvider.select((s) => s.isScanning));
    final status = ref.watch(
      cueDeckProvider.select((s) => s.lastCommandStatus),
    );
    final localWifiIp = ref.watch(
      cueDeckProvider.select((s) => s.localWifiIp),
    );
    final localNetworkPermissionDenied = ref.watch(
      cueDeckProvider.select((s) => s.localNetworkPermissionDenied),
    );
    final sensitivity = ref.watch(
      cueDeckProvider.select((s) => s.touchpadSensitivity),
    );
    final isGoogleSignedIn = ref.watch(
      cueDeckProvider.select((s) => s.isGoogleSignedIn),
    );
    final googleEmail = ref.watch(
      cueDeckProvider.select((s) => s.googleUserEmail),
    );

    final pageBg = isDarkMode ? Colors.black : const Color(0xFFF3F6FA);
    final cardBg = isDarkMode ? const Color(0xFF0A0C12) : Colors.white;
    final cardBorder = isDarkMode
        ? Colors.white.withValues(alpha: 0.08)
        : const Color(0xFFE2E8F0);
    final dividerColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.06)
        : const Color(0xFFEDF2F7);
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
                  const CueDeckBrandBadge(size: 32),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Ayarlar',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: primaryText,
                        fontWeight: FontWeight.w800,
                        fontSize: 17,
                      ),
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
                          device.isOnline ? 'Çevrimiçi' : 'Bağlı Değil',
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
              const SizedBox(height: 12),
              Expanded(
                child: SingleChildScrollView(
                  padding: EdgeInsets.only(bottom: bottomSafePadding + 24),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: <Widget>[
                      // CARD 1: TV BAĞLANTISI
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
                                  size: 19,
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: <Widget>[
                                      Text(
                                        device.name,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: primaryText,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        isScanning
                                            ? 'Ağdaki TV cihazları aranıyor...'
                                            : '${device.displayEndpoint} • $status',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          color: device.isOnline
                                              ? softMint
                                              : secondaryText,
                                          fontSize: 11,
                                          fontWeight: device.isOnline
                                              ? FontWeight.w600
                                              : FontWeight.w400,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                if (device.hasValidIp)
                                  IconButton(
                                    key: const Key('disconnect_tv_button'),
                                    tooltip: 'Bağlantıyı Sıfırla',
                                    visualDensity: VisualDensity.compact,
                                    onPressed: () {
                                      HapticFeedback.selectionClick();
                                      _ipController.clear();
                                      ref
                                          .read(cueDeckProvider.notifier)
                                          .disconnectCurrentTv();
                                    },
                                    icon: Icon(
                                      Icons.link_off_rounded,
                                      size: 18,
                                      color: secondaryText,
                                    ),
                                  ),
                              ],
                            ),

                            if (localNetworkPermissionDenied) ...<Widget>[
                              const SizedBox(height: 10),
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
                                      'iPhone "Yerel Ağ" İzni Kapalı',
                                      style: TextStyle(
                                        color: Color(0xFFFCA5A5),
                                        fontWeight: FontWeight.w800,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    const Text(
                                      'Ayarlar > CueDeck > Yerel Ağ anahtarını açın.',
                                      style: TextStyle(
                                        color: Color(0xFFFECACA),
                                        fontSize: 10.5,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton(
                                        style: FilledButton.styleFrom(
                                          backgroundColor:
                                              const Color(0xFFF87171),
                                          foregroundColor: Colors.black,
                                          padding: const EdgeInsets.symmetric(
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
                                        child: const Text(
                                          'Ayarlarda Yerel Ağ İznini Aç',
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

                            const SizedBox(height: 12),
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
                                      ? 'Cihazlar Aranıyor...'
                                      : 'Ağdaki Cihazları Ara',
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 12.5,
                                  ),
                                ),
                              ),
                            ),

                            if (discoveredDevices.isNotEmpty) ...<Widget>[
                              const SizedBox(height: 10),
                              SingleChildScrollView(
                                scrollDirection: Axis.horizontal,
                                child: Row(
                                  children: discoveredDevices.map((d) {
                                    final isSelected = d.ip == device.ip;
                                    return Padding(
                                      padding: const EdgeInsets.only(right: 6),
                                      child: ChoiceChip(
                                        visualDensity: VisualDensity.compact,
                                        label: Text(
                                          '${d.name} (${d.ip})',
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
                                        onSelected: (_) =>
                                            _connectDiscoveredDevice(d),
                                      ),
                                    );
                                  }).toList(growable: false),
                                ),
                              ),
                            ],

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
                                      'IR Kumanda',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontWeight: FontWeight.w700,
                                        fontSize: 11.5,
                                      ),
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 8),
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
                                      if (device.hasValidMac) {
                                        ref
                                            .read(cueDeckProvider.notifier)
                                            .wakeUpSelectedTv();
                                      } else {
                                        showWakeOnLanSetupSheet(context);
                                      }
                                    },
                                    child: const Text(
                                      'TV Uyandır',
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

                            const SizedBox(height: 6),
                            InkWell(
                              key: const Key(
                                'settings_advanced_connection_toggle',
                              ),
                              borderRadius: BorderRadius.circular(10),
                              onTap: () {
                                HapticFeedback.selectionClick();
                                setState(() {
                                  _showAdvancedConnection =
                                      !_showAdvancedConnection;
                                });
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 6,
                                  horizontal: 2,
                                ),
                                child: Row(
                                  children: <Widget>[
                                    Text(
                                      'Gelişmiş Bağlantı',
                                      style: TextStyle(
                                        color: secondaryText,
                                        fontSize: 11.5,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    const Spacer(),
                                    Icon(
                                      _showAdvancedConnection
                                          ? Icons.keyboard_arrow_up_rounded
                                          : Icons.keyboard_arrow_down_rounded,
                                      size: 18,
                                      color: secondaryText,
                                    ),
                                  ],
                                ),
                              ),
                            ),

                            AnimatedSize(
                              duration: const Duration(milliseconds: 200),
                              curve: Curves.easeOutCubic,
                              child: _showAdvancedConnection
                                  ? _buildAdvancedConnectionPanel(
                                      context: context,
                                      device: device,
                                      localWifiIp: localWifiIp,
                                      primaryText: primaryText,
                                      secondaryText: secondaryText,
                                      goldText: goldText,
                                      cardBorder: cardBorder,
                                      inputFill: inputFill,
                                    )
                                  : const SizedBox.shrink(),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // CARD 2: KUMANDA & GÖRÜNÜM
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
                            Text(
                              'Kumanda & Görünüm',
                              style: TextStyle(
                                color: primaryText,
                                fontWeight: FontWeight.w700,
                                fontSize: 14,
                              ),
                            ),
                            const SizedBox(height: 10),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    'Tema',
                                    style: TextStyle(
                                      color: secondaryText,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                _SegmentedOptionPill(
                                  key: const Key('theme_dark_chip'),
                                  label: 'Koyu',
                                  selected: isDarkMode,
                                  goldColor: goldText,
                                  fillColor: inputFill,
                                  borderColor: cardBorder,
                                  primaryText: primaryText,
                                  secondaryText: secondaryText,
                                  onTap: () => ref
                                      .read(cueDeckProvider.notifier)
                                      .setDarkMode(true),
                                ),
                                const SizedBox(width: 6),
                                _SegmentedOptionPill(
                                  key: const Key('theme_light_chip'),
                                  label: 'Açık',
                                  selected: !isDarkMode,
                                  goldColor: goldText,
                                  fillColor: inputFill,
                                  borderColor: cardBorder,
                                  primaryText: primaryText,
                                  secondaryText: secondaryText,
                                  onTap: () => ref
                                      .read(cueDeckProvider.notifier)
                                      .setDarkMode(false),
                                ),
                              ],
                            ),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Divider(height: 1, color: dividerColor),
                            ),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: Text(
                                    'Hızlı Tuşlar',
                                    style: TextStyle(
                                      color: secondaryText,
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ),
                                TextButton(
                                  style: TextButton.styleFrom(
                                    foregroundColor: goldText,
                                    visualDensity: VisualDensity.compact,
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                    ),
                                    minimumSize: Size.zero,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  onPressed: () {
                                    HapticFeedback.selectionClick();
                                    ref
                                        .read(cueDeckProvider.notifier)
                                        .resetRemoteShortcutsToDefault();
                                  },
                                  child: const Text(
                                    'Sıfırla',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            const RemoteShortcutSlotPairRow(),
                            Padding(
                              padding: const EdgeInsets.symmetric(vertical: 10),
                              child: Divider(height: 1, color: dividerColor),
                            ),
                            Text(
                              'Mouse Hassasiyeti',
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: secondaryText,
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: <Widget>[
                                Expanded(
                                  child: _SegmentedOptionPill(
                                    label: 'Hassas',
                                    centered: true,
                                    selected: sensitivity <= 0.95,
                                    goldColor: goldText,
                                    fillColor: inputFill,
                                    borderColor: cardBorder,
                                    primaryText: primaryText,
                                    secondaryText: secondaryText,
                                    onTap: () => ref
                                        .read(cueDeckProvider.notifier)
                                        .setTouchpadSensitivity(0.85),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _SegmentedOptionPill(
                                    label: 'Normal',
                                    centered: true,
                                    selected:
                                        sensitivity > 0.95 && sensitivity <= 1.5,
                                    goldColor: goldText,
                                    fillColor: inputFill,
                                    borderColor: cardBorder,
                                    primaryText: primaryText,
                                    secondaryText: secondaryText,
                                    onTap: () => ref
                                        .read(cueDeckProvider.notifier)
                                        .setTouchpadSensitivity(1.25),
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: _SegmentedOptionPill(
                                    label: 'Hızlı',
                                    centered: true,
                                    selected: sensitivity > 1.5,
                                    goldColor: goldText,
                                    fillColor: inputFill,
                                    borderColor: cardBorder,
                                    primaryText: primaryText,
                                    secondaryText: secondaryText,
                                    onTap: () => ref
                                        .read(cueDeckProvider.notifier)
                                        .setTouchpadSensitivity(1.85),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),

                      // CARD 3: CUEDECK PRO
                      const CueDeckProPassAndUpgradeSection(),
                      const SizedBox(height: 12),

                      // CARD 4: YEDEKLEME & HAKKINDA
                      Container(
                        decoration: BoxDecoration(
                          color: cardBg,
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(color: cardBorder),
                        ),
                        child: Column(
                          children: <Widget>[
                            _SettingsNavTile(
                              key: const Key('settings_backup_tile'),
                              icon: isGoogleSignedIn
                                  ? Icons.cloud_done_outlined
                                  : Icons.cloud_upload_outlined,
                              iconColor:
                                  isGoogleSignedIn ? softMint : goldText,
                              title: 'Bulut & Yerel Yedekleme',
                              subtitle: isGoogleSignedIn &&
                                      googleEmail.isNotEmpty
                                  ? googleEmail
                                  : 'Yedekle / Geri Yükle',
                              primaryText: primaryText,
                              secondaryText: secondaryText,
                              onTap: () => _showBackupManagementSheet(context),
                            ),
                            Divider(
                              height: 1,
                              indent: 48,
                              color: dividerColor,
                            ),
                            _SettingsNavTile(
                              key: const Key('settings_link_beam_tile'),
                              icon: Icons.cast_connected_rounded,
                              iconColor: goldText,
                              title: 'Link Işınla veya Planla',
                              subtitle: 'YouTube veya video bağlantısı ekle',
                              primaryText: primaryText,
                              secondaryText: secondaryText,
                              onTap: () => _openLinkBeam(context),
                            ),
                            Divider(
                              height: 1,
                              indent: 48,
                              color: dividerColor,
                            ),
                            _SettingsNavTile(
                              key: const Key('settings_release_notes_tile'),
                              icon: Icons.article_outlined,
                              iconColor: secondaryText,
                              title: 'Sürüm Notları',
                              trailingBadge:
                                  CueReleaseNotesCatalog.currentShortVersion,
                              primaryText: primaryText,
                              secondaryText: secondaryText,
                              goldText: goldText,
                              onTap: () {
                                HapticFeedback.selectionClick();
                                showCueWhatsNewModal(
                                  context,
                                  isDarkMode: isDarkMode,
                                  initialStartupMode: false,
                                );
                              },
                            ),
                          ],
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

  Widget _buildAdvancedConnectionPanel({
    required BuildContext context,
    required TvDevice device,
    required String localWifiIp,
    required Color primaryText,
    required Color secondaryText,
    required Color goldText,
    required Color cardBorder,
    required Color inputFill,
  }) {
    return Padding(
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _ipController,
                  focusNode: _ipFocusNode,
                  style: TextStyle(color: primaryText, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'TV IP (192.168.1.x)',
                    hintStyle: TextStyle(color: secondaryText, fontSize: 12),
                    isDense: true,
                    filled: true,
                    fillColor: inputFill,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cardBorder),
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
                  side: BorderSide(color: goldText.withValues(alpha: 0.45)),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
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
                  'Bağlan',
                  style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5),
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
                    side: BorderSide(color: goldText.withValues(alpha: 0.45)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    _openInteractiveRsaPairingSheet(
                      context,
                      _ipController.text.trim(),
                    );
                  },
                  child: const Text(
                    'RSA Eşleştir',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11),
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
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    _openPin6466Dialog(context, _ipController.text.trim());
                  },
                  child: const Text(
                    'PIN Eşleştir',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton(
                  key: const Key('switch_tv_profile_button'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryText,
                    side: BorderSide(color: cardBorder),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const TvAlternativeProfileSheet(),
                    );
                  },
                  child: const Text(
                    'Alternatif Profil',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                  ),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: OutlinedButton(
                  key: const Key('tv_diagnostic_report_button'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: secondaryText,
                    side: BorderSide(color: cardBorder),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  onPressed: () {
                    HapticFeedback.selectionClick();
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => const ConnectionDiagnosticSheet(),
                    );
                  },
                  child: const Text(
                    'Tanılama Raporu',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: <Widget>[
              if (!device.isIrBlaster)
                Expanded(
                  child: InkWell(
                    key: const Key('settings_edit_mac_button'),
                    borderRadius: BorderRadius.circular(8),
                    onTap: () {
                      HapticFeedback.selectionClick();
                      showWakeOnLanSetupSheet(context);
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Text(
                        device.hasValidMac
                            ? 'WoL MAC: ${device.macAddress}'
                            : 'WoL MAC Ekle',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: goldText,
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                ),
              InkWell(
                borderRadius: BorderRadius.circular(8),
                onTap: () => _openTvSetupGuideSheet(context),
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    vertical: 4,
                    horizontal: 6,
                  ),
                  child: Text(
                    'Kurulum Rehberi',
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
          if (localWifiIp.isNotEmpty)
            Text(
              'Wi-Fi IP: $localWifiIp',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(color: secondaryText, fontSize: 10.5),
            ),
        ],
      ),
    );
  }

  Future<void> _connectDiscoveredDevice(TvDevice d) async {
    HapticFeedback.selectionClick();
    _ipController.text = d.ip;
    final ok = await ref
        .read(cueDeckProvider.notifier)
        .connectAndPairDevice(d);
    if (!mounted) return;
    if ((d.protocol == TvConnectionProtocol.remotePort6466 &&
            d.port == 6466 &&
            !d.isPaired) ||
        ((d.protocol == TvConnectionProtocol.philipsJointSpace1925 ||
                d.protocol == TvConnectionProtocol.vidaaSmart36669) &&
            !d.isPaired &&
            !ok)) {
      _openPin6466Dialog(context, d.ip);
    } else if (!ok) {
      _openInteractiveRsaPairingSheet(context, d.ip);
    }
  }

  Future<void> _openLinkBeam(BuildContext context) async {
    HapticFeedback.mediumImpact();
    final foundFromClipboard = await ref
        .read(cueDeckProvider.notifier)
        .importClipboardAsSharedPayload();
    if (!context.mounted) return;
    if (!foundFromClipboard) {
      await showShareToTvBeamSheet(
        context,
        SharedCuePayload(
          url: '',
          title: '',
          platform: StreamingPlatform.youtube,
          receivedAtEpochMs: DateTime.now().millisecondsSinceEpoch,
        ),
      );
      return;
    }
    final payload = ref.read(cueDeckProvider).pendingSharedPayload;
    if (payload != null) {
      await showShareToTvBeamSheet(context, payload);
    }
  }

  void _showBackupManagementSheet(BuildContext context) {
    HapticFeedback.selectionClick();
    final isDarkMode = ref.read(cueDeckProvider).isDarkMode;
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => Container(
        key: const Key('backup_management_sheet'),
        decoration: BoxDecoration(
          color: isDarkMode ? const Color(0xFF10131C) : const Color(0xFFF3F6FA),
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: const SafeArea(
          top: false,
          child: SingleChildScrollView(
            child: _GoogleDriveBackupSection(),
          ),
        ),
      ),
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

class _SegmentedOptionPill extends StatelessWidget {
  const _SegmentedOptionPill({
    super.key,
    required this.label,
    required this.selected,
    required this.goldColor,
    required this.fillColor,
    required this.borderColor,
    required this.primaryText,
    required this.secondaryText,
    required this.onTap,
    this.centered = false,
  });

  final String label;
  final bool selected;
  final Color goldColor;
  final Color fillColor;
  final Color borderColor;
  final Color primaryText;
  final Color secondaryText;
  final VoidCallback onTap;
  final bool centered;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: () {
        HapticFeedback.selectionClick();
        onTap();
      },
      child: Container(
        alignment: centered ? Alignment.center : null,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: selected ? goldColor.withValues(alpha: 0.16) : fillColor,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? goldColor : borderColor,
            width: selected ? 1.2 : 1.0,
          ),
        ),
        child: Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            color: selected ? primaryText : secondaryText,
            fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 11,
          ),
        ),
      ),
    );
  }
}

class _SettingsNavTile extends StatelessWidget {
  const _SettingsNavTile({
    super.key,
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.primaryText,
    required this.secondaryText,
    required this.onTap,
    this.subtitle,
    this.trailingBadge,
    this.goldText,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String? subtitle;
  final String? trailingBadge;
  final Color primaryText;
  final Color secondaryText;
  final Color? goldText;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
        child: Row(
          children: <Widget>[
            Icon(icon, color: iconColor, size: 19),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: primaryText,
                      fontWeight: FontWeight.w600,
                      fontSize: 13.5,
                    ),
                  ),
                  if (subtitle != null && subtitle!.isNotEmpty) ...<Widget>[
                    const SizedBox(height: 1),
                    Text(
                      subtitle!,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            if (trailingBadge != null) ...<Widget>[
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 8,
                  vertical: 3,
                ),
                decoration: BoxDecoration(
                  color: (goldText ?? secondaryText).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  trailingBadge!,
                  style: TextStyle(
                    color: goldText ?? secondaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                  ),
                ),
              ),
              const SizedBox(width: 4),
            ],
            Icon(
              Icons.chevron_right_rounded,
              color: secondaryText,
              size: 19,
            ),
          ],
        ),
      ),
    );
  }
}

/// Calm CueDeck Pro & 24-Hour Rewarded Pass card.
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
        ? Colors.white.withValues(alpha: 0.08)
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
        borderRadius: BorderRadius.circular(20),
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
                  'CueDeck Pro',
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
                            ? 'AKTİF'
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
              'Reklamsız kullanım, sınırsız izleme planı ve bulut yedekleme aktif.',
              style: TextStyle(color: secondaryText, fontSize: 11.5),
            ),
          ] else ...<Widget>[
            Text(
              'Reklamsız deneyim, sınırsız izleme planı ve ışınlama.',
              style: TextStyle(color: secondaryText, fontSize: 11.5),
            ),
            if (rewardedDays > 0) ...<Widget>[
              const SizedBox(height: 8),
              Row(
                children: <Widget>[
                  Expanded(
                    child: ClipRRect(
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
                  ),
                  const SizedBox(width: 8),
                  Text(
                    '$rewardedDays/${CueProProductCatalog.loyaltyDiscountTargetDays} gün',
                    style: TextStyle(
                      color: goldText,
                      fontWeight: FontWeight.w700,
                      fontSize: 10.5,
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: <Widget>[
                Expanded(
                  child: FilledButton(
                    key: const Key('settings_open_paywall_button'),
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
                    onPressed: () {
                      HapticFeedback.selectionClick();
                      showCueProPaywallSheet(context);
                    },
                    child: const Text(
                      'Pro Planları',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
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
                      '24s Reklamsız',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
          if (isProLifetime || isSubActive || isPassActive) ...<Widget>[
            const SizedBox(height: 6),
            SizedBox(
              width: double.infinity,
              child: TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: secondaryText,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: () async {
                  HapticFeedback.selectionClick();
                  final res = await ref
                      .read(cueDeckProvider.notifier)
                      .resetProPassToFree();
                  showToast(res.message);
                },
                child: const Text(
                  'Ücretsiz Sürüme Dön',
                  style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
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

    final primaryText =
        isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
    final secondaryText =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final goldText =
        isDarkMode ? const Color(0xFFE6C17A) : const Color(0xFFB48328);
    final mintText =
        isDarkMode ? const Color(0xFF6EE7B7) : const Color(0xFF059669);
    final subSurfaceBg =
        isDarkMode ? const Color(0xFF161A26) : Colors.white;
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

    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: <Widget>[
        Center(
          child: Container(
            width: 38,
            height: 4,
            decoration: BoxDecoration(
              color: secondaryText.withValues(alpha: 0.35),
              borderRadius: BorderRadius.circular(4),
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          children: <Widget>[
            Icon(
              isSignedIn ? Icons.cloud_done_rounded : Icons.cloud_upload_rounded,
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
                  fontWeight: FontWeight.w800,
                  fontSize: 15,
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
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: () => Navigator.of(context).pop(),
              icon: Icon(Icons.close_rounded, color: secondaryText),
            ),
          ],
        ),
        const SizedBox(height: 8),

        if (!isSignedIn) ...<Widget>[
          Text(
            'Planlarınızı Google Drive veya yerel dosyaya yedekleyin.',
            style: TextStyle(color: secondaryText, fontSize: 12),
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
                        final syncRes = await notifier.syncDevicesWithCloud();
                        showMessage(syncRes.message);
                      }
                    },
              child: const Text(
                'Google Hesabını Bağla',
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
                        style: TextStyle(color: secondaryText, fontSize: 11),
                      ),
                    ),
                    Transform.scale(
                      scale: 0.82,
                      child: Switch(
                        value: isAutoEnabled,
                        activeThumbColor: mintText,
                        materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
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
                    'Eşitle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
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
                    'Yedekle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5),
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
                          final notifier = ref.read(cueDeckProvider.notifier);
                          final backups = await notifier.fetchAvailableBackups();
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
                    'Yükle',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w700, fontSize: 11.5),
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
                  'Dosyaya Yedekle',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5),
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
                  'Dosyadan Yükle',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontWeight: FontWeight.w600, fontSize: 11.5),
                ),
              ),
            ),
          ],
        ),
      ],
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
        isDarkMode ? const Color(0xFF10131C) : const Color(0xFFF3F6FA);
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
                          'Bulut Yedeği Seçin',
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
                                Icon(
                                  item.isLocal
                                      ? Icons.save_alt_rounded
                                      : Icons.cloud_outlined,
                                  color: goldText,
                                  size: 20,
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
                                                'EN YENİ',
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
                                        '${item.formattedDate} • ${item.deviceName}'
                                        '${item.planCount != null ? ' • Plan: ${item.planCount}' : ''}',
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
