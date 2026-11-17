import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/cue_models.dart';
import '../../providers/cuedeck_providers.dart';

/// Opens the modern network device discovery modal popup so the user can view
/// all discovered TVs on the Wi-Fi network, select IR Blaster fallback, or pair.
void showTvDiscoveryModal(BuildContext context) {
  showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const TvDiscoveryModalSheet(),
  );
}

/// Opens the 7-brand Android IR Blaster picker modal (`ConsumerIrManager` zero-Wi-Fi control).
Future<void> showIrBlasterBrandPickerSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const IrBlasterBrandPickerSheet(),
  );
}

/// Modern Network TV Discovery Popup (`showTvDiscoveryModal`).
class TvDiscoveryModalSheet extends ConsumerStatefulWidget {
  const TvDiscoveryModalSheet({super.key});

  @override
  ConsumerState<TvDiscoveryModalSheet> createState() =>
      _TvDiscoveryModalSheetState();
}

class _TvDiscoveryModalSheetState extends ConsumerState<TvDiscoveryModalSheet> {
  late final TextEditingController _manualIpController;
  String? _connectingIp;

  @override
  void initState() {
    super.initState();
    _manualIpController = TextEditingController();
  }

  @override
  void dispose() {
    _manualIpController.dispose();
    super.dispose();
  }

  Future<void> _connectToDevice(TvDevice device) async {
    if (_connectingIp != null) return;
    HapticFeedback.mediumImpact();
    setState(() {
      _connectingIp = device.ip;
    });
    final notifier = ref.read(cueDeckProvider.notifier);
    final ok = await notifier.connectAndPairDevice(device);
    if (!mounted) return;
    setState(() {
      _connectingIp = null;
    });

    final updated = ref.read(cueDeckProvider).selectedDevice;
    if (device.protocol == TvConnectionProtocol.remotePort6466 &&
        updated.port == 6466 &&
        !updated.isPaired) {
      Navigator.of(context).pop();
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => Pin6466PairingSheet(targetIp: device.ip),
      );
      return;
    }

    if (ok || updated.isOnline) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            backgroundColor: const Color(0xFF0A0C12),
            content: Text(
              '✓ Bağlandı: ${updated.name} (${updated.ip})',
              style: const TextStyle(color: Colors.white, fontSize: 12.5),
            ),
          ),
        );
      Navigator.of(context).pop();
    } else {
      Navigator.of(context).pop();
      showModalBottomSheet<void>(
        context: context,
        isScrollControlled: true,
        backgroundColor: Colors.transparent,
        builder: (_) => InteractiveTvPairingSheet(customIp: device.ip),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final isScanning = ref.watch(cueDeckProvider.select((s) => s.isScanning));
    final discoveredDevices = ref.watch(
      cueDeckProvider.select((s) => s.discoveredDevices),
    );
    final selectedDevice = ref.watch(
      cueDeckProvider.select((s) => s.selectedDevice),
    );
    final localWifiIp = ref.watch(
      cueDeckProvider.select((s) => s.localWifiIp),
    );
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final sheetBg =
        isDarkMode ? const Color(0xFF0A0C12) : const Color(0xFFF3F6FA);
    final cardBg = isDarkMode ? const Color(0xFF11141E) : Colors.white;
    final cardBorder = isDarkMode
        ? Colors.white.withValues(alpha: 0.09)
        : const Color(0xFFE2E8F0);
    final primaryText = isDarkMode ? Colors.white : const Color(0xFF141821);
    final secondaryText =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final goldText =
        isDarkMode ? const Color(0xFFE6C17A) : const Color(0xFFB48328);
    final mintText =
        isDarkMode ? const Color(0xFF6EE7B7) : const Color(0xFF059669);

    return Container(
      key: const Key('tv_discovery_modal_sheet'),
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.82,
      ),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: cardBorder),
      ),
      padding: EdgeInsets.fromLTRB(18, 14, 18, bottomInset + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Center(
            child: Container(
              width: 38,
              height: 4,
              decoration: BoxDecoration(
                color: secondaryText.withValues(alpha: 0.35),
                borderRadius: BorderRadius.circular(999),
              ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: BoxDecoration(
                  color: goldText.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(11),
                ),
                child: Icon(
                  isScanning ? Icons.radar_rounded : Icons.tv_rounded,
                  color: goldText,
                  size: 20,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      '📡 Ağdaki Akıllı TV Cihazları',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: primaryText,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                    Text(
                      localWifiIp.isNotEmpty
                          ? 'Telefon Wi-Fi IP: $localWifiIp • Seçerek bağlanın'
                          : 'Wi-Fi ağındaki Smart TV & Android TV cihazları',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: secondaryText,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              OutlinedButton.icon(
                key: const Key('rescan_network_modal_button'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: goldText,
                  side: BorderSide(color: goldText.withValues(alpha: 0.45)),
                  visualDensity: VisualDensity.compact,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: isScanning
                    ? null
                    : () {
                        HapticFeedback.selectionClick();
                        ref.read(cueDeckProvider.notifier).scanNetworkForTvs();
                      },
                icon: const Icon(Icons.refresh_rounded, size: 15),
                label: Text(
                  isScanning ? 'Taranıyor' : 'Yenile',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: secondaryText, size: 20),
              ),
            ],
          ),
          if (isScanning) ...<Widget>[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 3.5,
                backgroundColor: cardBorder,
                valueColor: AlwaysStoppedAnimation<Color>(goldText),
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '🔍 Yerel Wi-Fi ağı taranıyor (ADB 5555 • Google TV 6466 • Samsung/LG/Roku • mDNS)...',
              style: TextStyle(
                color: goldText,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          const SizedBox(height: 10),
          OutlinedButton.icon(
            key: const Key('discovery_ir_blaster_button'),
            style: OutlinedButton.styleFrom(
              foregroundColor: goldText,
              side: BorderSide(color: goldText.withValues(alpha: 0.45)),
              visualDensity: VisualDensity.compact,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              showIrBlasterBrandPickerSheet(context);
            },
            icon: const Icon(Icons.settings_remote_rounded, size: 16),
            label: const Text(
              '📡 Kızılötesi (IR) Kumanda — Wi-Fi Olmadan Kontrol',
              style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 10),
          Flexible(
            child: discoveredDevices.isEmpty
                ? Container(
                    width: double.infinity,
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: cardBg,
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: cardBorder),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: <Widget>[
                        Row(
                          children: <Widget>[
                            Icon(
                              isScanning
                                  ? Icons.wifi_tethering_rounded
                                  : Icons.info_outline_rounded,
                              color: goldText,
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                isScanning
                                    ? 'Ağdaki TV\'ler aranıyor, lütfen bekleyin...'
                                    : 'Henüz açık bir TV bulunamadı',
                                style: TextStyle(
                                  color: primaryText,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 6),
                        Text(
                          '• TV\'nizin açık ve telefonunuzla aynı Wi-Fi ağında olduğundan emin olun.\n'
                          '• Samsung, LG, Roku, Philips, VIDAA, Sony, Arçelik/Vestel & Android TV desteklenir.\n'
                          '• TV IP adresini biliyorsanız aşağıdan doğrudan bağlanabilirsiniz.',
                          style: TextStyle(
                            color: secondaryText,
                            fontSize: 11.5,
                            height: 1.4,
                          ),
                        ),
                      ],
                    ),
                  )
                : ListView.separated(
                    shrinkWrap: true,
                    itemCount: discoveredDevices.length,
                    separatorBuilder: (_, _) => const SizedBox(height: 8),
                    itemBuilder: (context, index) {
                      final d = discoveredDevices[index];
                      final isSelected =
                          d.ip == selectedDevice.ip && selectedDevice.isOnline;
                      final isConnectingThis = _connectingIp == d.ip;

                      return InkWell(
                        key: Key('discovered_tv_card_${d.ip}'),
                        borderRadius: BorderRadius.circular(15),
                        onTap: () => _connectToDevice(d),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 11,
                          ),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(15),
                            border: Border.all(
                              color: isSelected
                                  ? mintText.withValues(alpha: 0.7)
                                  : goldText.withValues(alpha: 0.32),
                              width: isSelected ? 1.4 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              Container(
                                width: 38,
                                height: 38,
                                decoration: BoxDecoration(
                                  color: (isSelected ? mintText : goldText)
                                      .withValues(alpha: 0.14),
                                  borderRadius: BorderRadius.circular(11),
                                ),
                                child: Icon(
                                  Icons.tv_rounded,
                                  color: isSelected ? mintText : goldText,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      d.name,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: primaryText,
                                        fontWeight: FontWeight.w800,
                                        fontSize: 13.5,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${d.ip}:${d.port} • ${d.protocolBadgeLabel}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: goldText,
                                        fontWeight: FontWeight.w600,
                                        fontSize: 11,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      d.boardInfo,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        color: secondaryText,
                                        fontSize: 10.5,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 8),
                              if (isConnectingThis)
                                SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                    color: goldText,
                                  ),
                                )
                              else
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: isSelected
                                        ? mintText.withValues(alpha: 0.16)
                                        : goldText,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                  child: Text(
                                    isSelected ? '✓ Bağlı' : 'Bağlan',
                                    style: TextStyle(
                                      color: isSelected
                                          ? mintText
                                          : const Color(0xFF0A0C12),
                                      fontWeight: FontWeight.w800,
                                      fontSize: 11.5,
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: TextField(
                  controller: _manualIpController,
                  style: TextStyle(color: primaryText, fontSize: 12.5),
                  decoration: InputDecoration(
                    hintText: 'Manuel TV IP ile ekle (Örn: 192.168.1.50)',
                    hintStyle: TextStyle(color: secondaryText, fontSize: 11.5),
                    isDense: true,
                    filled: true,
                    fillColor: cardBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide: BorderSide(color: cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(11),
                      borderSide: BorderSide(color: cardBorder),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: goldText,
                  foregroundColor: const Color(0xFF0A0C12),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(11),
                  ),
                ),
                onPressed: () async {
                  final rawIp = _manualIpController.text.trim();
                  if (!TvNetworkValidators.isValidIp(rawIp)) return;
                  await ref
                      .read(cueDeckProvider.notifier)
                      .scanNetworkForTvs(customIp: rawIp);
                },
                child: const Text(
                  'Ekle & Ara',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// 7-brand Android IR Blaster picker allowing instant zero-Wi-Fi control on IR phones.
class IrBlasterBrandPickerSheet extends ConsumerWidget {
  const IrBlasterBrandPickerSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final hasIrEmitter =
        ref.watch(cueDeckProvider.select((s) => s.hasIrEmitter));
    final selectedDevice =
        ref.watch(cueDeckProvider.select((s) => s.selectedDevice));

    final sheetBg =
        isDarkMode ? const Color(0xFF0A0C12) : const Color(0xFFF3F6FA);
    final cardBg = isDarkMode ? const Color(0xFF11141E) : Colors.white;
    final primaryText = isDarkMode ? Colors.white : const Color(0xFF141821);
    final secondaryText =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final goldText =
        isDarkMode ? const Color(0xFFE6C17A) : const Color(0xFFB48328);
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.09)
        : const Color(0xFFE2E8F0);

    final profiles = IrBlasterDriver.brandProfiles.values.toList();

    return Container(
      key: const Key('ir_blaster_brand_picker_sheet'),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 22),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Icon(Icons.settings_remote_rounded, color: goldText),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '📡 Kızılötesi (IR) TV Markası Seç',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: primaryText,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                  ),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: secondaryText),
                ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              hasIrEmitter
                  ? '✓ Telefonunuzda IR Blaster donanımı algılandı. Wi-Fi olmadan doğrudan kontrol edebilirsiniz.'
                  : 'ℹ️ Bu cihazda yerleşik IR vericisi doğrulanamadı; profil seçildiğinde destekli Android telefonlarda aktifleşir.',
              style: TextStyle(
                color: secondaryText,
                fontSize: 11.5,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  children: profiles.map((IrBrandProfile profile) {
                    final active = selectedDevice.isIrBlaster &&
                        selectedDevice.irBrandCode == profile.code;
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: InkWell(
                        key: Key('ir_brand_${profile.code}'),
                        borderRadius: BorderRadius.circular(14),
                        onTap: () async {
                          HapticFeedback.mediumImpact();
                          await ref
                              .read(cueDeckProvider.notifier)
                              .activateIrBlasterBrand(profile.code);
                          if (!context.mounted) return;
                          Navigator.of(context).pop();
                        },
                        child: Container(
                          width: double.infinity,
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 10,
                          ),
                          decoration: BoxDecoration(
                            color: cardBg,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: active ? goldText : borderColor,
                              width: active ? 1.4 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: <Widget>[
                              Icon(
                                Icons.tv_rounded,
                                color: active ? goldText : secondaryText,
                                size: 20,
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: <Widget>[
                                    Text(
                                      profile.displayName,
                                      style: TextStyle(
                                        color: primaryText,
                                        fontWeight: FontWeight.w700,
                                        fontSize: 13,
                                      ),
                                    ),
                                    Text(
                                      '${profile.protocolName.toUpperCase()} • ${profile.carrierHz ~/ 1000} kHz IR',
                                      style: TextStyle(
                                        color: secondaryText,
                                        fontSize: 11,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              if (active)
                                Icon(
                                  Icons.check_circle_rounded,
                                  color: goldText,
                                  size: 18,
                                ),
                            ],
                          ),
                        ),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Interactive RSA-2048 ADB / Smart TV Pairing Modal Sheet.
class InteractiveTvPairingSheet extends ConsumerStatefulWidget {
  const InteractiveTvPairingSheet({super.key, required this.customIp});

  final String customIp;

  @override
  ConsumerState<InteractiveTvPairingSheet> createState() =>
      _InteractiveTvPairingSheetState();
}

class _InteractiveTvPairingSheetState
    extends ConsumerState<InteractiveTvPairingSheet> {
  late final TextEditingController _ipController;
  bool _isPairing = false;
  bool? _pairSuccess;
  String _statusMessage = '';

  @override
  void initState() {
    super.initState();
    final state = ref.read(cueDeckProvider);
    final initialIp = TvNetworkValidators.isValidIp(widget.customIp)
        ? widget.customIp.trim()
        : (state.selectedDevice.hasValidIp
            ? state.selectedDevice.ip
            : (state.discoveredDevices.isNotEmpty
                ? state.discoveredDevices.first.ip
                : ''));
    _ipController = TextEditingController(text: initialIp);
    if (TvNetworkValidators.isValidIp(initialIp)) {
      Future<void>.microtask(_startRsaPairing);
    } else {
      _statusMessage =
          'Eşleştirilecek TV IP adresini girin veya "Ağdaki Cihazları Ara" ile TV seçin.';
    }
  }

  @override
  void dispose() {
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _startRsaPairing() async {
    final targetIp = _ipController.text.trim();
    if (!TvNetworkValidators.isValidIp(targetIp)) {
      setState(() {
        _pairSuccess = false;
        _statusMessage =
            'Lütfen geçerli bir TV IP adresi girin (Örn: 192.168.1.50) veya ağdan TV seçin.';
      });
      return;
    }

    setState(() {
      _isPairing = true;
      _pairSuccess = null;
      _statusMessage =
          '🔐 $targetIp adresine eşleştirme isteği gönderildi. Lütfen TV ekranında çıkan onay penceresini kumandayla kabul edin...';
    });

    final ok = await ref
        .read(cueDeckProvider.notifier)
        .pairWithSelectedTv(customIp: targetIp);
    if (!mounted) return;
    final currentDevice = ref.read(cueDeckProvider).selectedDevice;
    setState(() {
      _isPairing = false;
      _pairSuccess = ok;
      _statusMessage = ok
          ? '✓ Eşleşti ve Bağlandı: ${currentDevice.name} (${currentDevice.ip})'
          : '⚠️ ${currentDevice.boardInfo}';
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final sheetBg =
        isDarkMode ? const Color(0xFF0A0C12) : const Color(0xFFF3F5F9);
    final cardBg = isDarkMode ? const Color(0xFF11141E) : Colors.white;
    final primaryText = isDarkMode ? Colors.white : const Color(0xFF141821);
    final secondaryText =
        isDarkMode ? Colors.white70 : const Color(0xFF525B6C);
    final goldText =
        isDarkMode ? const Color(0xFFE2A84B) : const Color(0xFFB87818);
    final mintText =
        isDarkMode ? const Color(0xFF6EE7B7) : const Color(0xFF059669);

    return Container(
      key: const Key('interactive_tv_pairing_sheet'),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(18, 16, 18, bottomInset + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Icon(Icons.security_rounded, color: goldText, size: 20),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  '🔐 TV Eşleştirme (ADB RSA-2048 Onayı)',
                  style: TextStyle(
                    color: primaryText,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              IconButton(
                visualDensity: VisualDensity.compact,
                onPressed: () => Navigator.of(context).pop(),
                icon: Icon(Icons.close_rounded, color: secondaryText, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'TV\'de Geliştirici Seçenekleri > USB / Ağ Hata Ayıklama açıkken (veya Samsung/LG TV\'de onay sorulduğunda) ekrandaki izni kabul ederek tam kontrol sağlayın.',
            style: TextStyle(
              color: secondaryText,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _ipController,
            style: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.w700,
              fontSize: 14,
            ),
            decoration: InputDecoration(
              labelText: 'Hedef TV IP Adresi',
              hintText: 'Örn: 192.168.1.50',
              labelStyle: TextStyle(color: goldText, fontSize: 12),
              filled: true,
              fillColor: cardBg,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (_isPairing) ...<Widget>[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                minHeight: 4,
                valueColor: AlwaysStoppedAnimation<Color>(goldText),
              ),
            ),
          ],
          if (_statusMessage.isNotEmpty) ...<Widget>[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(11),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: _pairSuccess == true
                      ? mintText.withValues(alpha: 0.6)
                      : goldText.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                _statusMessage,
                style: TextStyle(
                  color: _pairSuccess == true ? mintText : primaryText,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: <Widget>[
              Expanded(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: const Color(0xFFE2A84B),
                    foregroundColor: const Color(0xFF090A0F),
                    padding: const EdgeInsets.symmetric(vertical: 12),
                  ),
                  onPressed: _isPairing ? null : _startRsaPairing,
                  icon: Icon(
                    _isPairing
                        ? Icons.hourglass_top_rounded
                        : Icons.vpn_key_rounded,
                    size: 16,
                  ),
                  label: Text(
                    _isPairing
                        ? 'TV Onayı Bekleniyor...'
                        : '🔐 RSA Onayı Gönder ve Eşleştir',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12.5,
                    ),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    final ip = _ipController.text.trim();
                    Navigator.of(context).pop();
                    showModalBottomSheet<void>(
                      context: context,
                      isScrollControlled: true,
                      backgroundColor: Colors.transparent,
                      builder: (_) => Pin6466PairingSheet(targetIp: ip),
                    );
                  },
                  icon: const Icon(Icons.pin_rounded, size: 15),
                  label: const Text(
                    '🔢 PIN ile Eşleştir (6466)',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: () {
                    Navigator.of(context).pop();
                    unawaited(
                      ref.read(cueDeckProvider.notifier).scanNetworkForTvs(),
                    );
                    showTvDiscoveryModal(context);
                  },
                  icon: const Icon(Icons.wifi_find_rounded, size: 15),
                  label: const Text(
                    '🔍 Ağdan TV Seç',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
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

/// 6-Character PIN Pairing Sheet for Port 6466/6467 (`Android TV Remote Protocol v2`).
class Pin6466PairingSheet extends ConsumerStatefulWidget {
  const Pin6466PairingSheet({super.key, required this.targetIp});

  final String targetIp;

  @override
  ConsumerState<Pin6466PairingSheet> createState() =>
      _Pin6466PairingSheetState();
}

class _Pin6466PairingSheetState extends ConsumerState<Pin6466PairingSheet> {
  late final TextEditingController _pinController;
  late final TextEditingController _ipController;
  bool _isRequestingPin = false;
  bool _isVerifyingPin = false;
  bool _pinDisplayedOnTv = false;
  bool _adb5555OpenOnTv = false;
  String _sessionMessage = '';

  @override
  void initState() {
    super.initState();
    _pinController = TextEditingController();
    final state = ref.read(cueDeckProvider);
    final initialIp = TvNetworkValidators.isValidIp(widget.targetIp)
        ? widget.targetIp.trim()
        : (state.selectedDevice.hasValidIp
            ? state.selectedDevice.ip
            : (state.discoveredDevices.isNotEmpty
                ? state.discoveredDevices.first.ip
                : ''));
    _ipController = TextEditingController(text: initialIp);
    if (TvNetworkValidators.isValidIp(initialIp)) {
      Future<void>.microtask(_triggerTvPinDisplay);
    } else {
      _sessionMessage =
          'Önce TV IP adresini girin veya "Ağdaki Cihazları Ara" ile TV\'nizi seçin.';
    }
  }

  @override
  void dispose() {
    _pinController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _triggerTvPinDisplay({bool forceRestart = false}) async {
    final ip = _ipController.text.trim();
    if (!TvNetworkValidators.isValidIp(ip)) {
      setState(() {
        _sessionMessage = 'Lütfen geçerli bir TV IP adresi girin.';
      });
      return;
    }

    setState(() {
      _isRequestingPin = true;
      _sessionMessage =
          '📡 $ip adresindeki TV ekranında 6 haneli PIN kodu oluşturuluyor...';
    });

    final res = await ref
        .read(cueDeckProvider.notifier)
        .startPin6467Pairing(customIp: ip, forceRestart: forceRestart);
    if (!mounted) return;
    setState(() {
      _isRequestingPin = false;
      _pinDisplayedOnTv = res['pinDisplayed'] == true;
      _adb5555OpenOnTv = res['adb5555Open'] == true;
      _sessionMessage = (res['message'] as String?) ?? '';
    });
  }

  Future<void> _submitPinAndPair() async {
    final pin = _pinController.text.trim();
    final ip = _ipController.text.trim();
    if (!TvNetworkValidators.isValidPairingPinCode(pin)) {
      setState(() {
        _sessionMessage =
            '⚠️ Lütfen TV ekranında görünen 6 karakterli PIN kodunu eksiksiz girin (0-9 / A-F).';
      });
      return;
    }

    setState(() {
      _isVerifyingPin = true;
      _sessionMessage = '🔢 PIN kodu ($pin) TV ile doğrulanıyor...';
    });

    final nav = Navigator.of(context);
    final ok = await ref
        .read(cueDeckProvider.notifier)
        .pairWithSelectedTvPin6466(pin, customIp: ip);
    if (!mounted) return;
    setState(() {
      _isVerifyingPin = false;
    });
    if (ok) {
      nav.pop();
    } else {
      final board = ref.read(cueDeckProvider).selectedDevice.boardInfo;
      setState(() {
        _sessionMessage = '⚠️ $board';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final sheetBg =
        isDarkMode ? const Color(0xFF0A0C12) : const Color(0xFFF3F5F9);
    final cardBg = isDarkMode ? const Color(0xFF11141E) : Colors.white;
    final primaryText = isDarkMode ? Colors.white : const Color(0xFF141821);
    final secondaryText =
        isDarkMode ? Colors.white70 : const Color(0xFF525B6C);
    final goldText =
        isDarkMode ? const Color(0xFFE2A84B) : const Color(0xFFB87818);
    final mintText =
        isDarkMode ? const Color(0xFF6EE7B7) : const Color(0xFF059669);

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(18, 16, 18, bottomInset + 20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Expanded(
                child: Text(
                  '🔢 Standart TV PIN Eşleştirme (Port 6466)',
                  style: TextStyle(
                    color: primaryText,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ),
              TextButton.icon(
                style: TextButton.styleFrom(
                  foregroundColor: goldText,
                  visualDensity: VisualDensity.compact,
                ),
                onPressed: _isRequestingPin
                    ? null
                    : () => _triggerTvPinDisplay(forceRestart: true),
                icon: const Icon(Icons.refresh_rounded, size: 15),
                label: const Text(
                  'PIN İste',
                  style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            'Standart Google TV / Android TV cihazlarında TV ekranında beliren 6 karakterli PIN kodunu (rakam veya A-F harf) girin.',
            style: TextStyle(
              color: secondaryText,
              fontSize: 12,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 10),
          TextField(
            controller: _ipController,
            style: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.w700,
              fontSize: 13,
            ),
            decoration: InputDecoration(
              labelText: 'TV IP Adresi',
              hintText: 'Örn: 192.168.1.50',
              labelStyle: TextStyle(color: goldText, fontSize: 11.5),
              filled: true,
              fillColor: cardBg,
              isDense: true,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
          if (_sessionMessage.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: cardBg,
                borderRadius: BorderRadius.circular(11),
                border: Border.all(
                  color: _pinDisplayedOnTv
                      ? mintText.withValues(alpha: 0.6)
                      : goldText.withValues(alpha: 0.4),
                ),
              ),
              child: Text(
                _sessionMessage,
                style: TextStyle(
                  color: _pinDisplayedOnTv ? mintText : primaryText,
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  height: 1.35,
                ),
              ),
            ),
          ],
          if (_adb5555OpenOnTv) ...<Widget>[
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  foregroundColor: mintText,
                  side: BorderSide(color: mintText.withValues(alpha: 0.65)),
                ),
                onPressed: () async {
                  final ip = _ipController.text.trim();
                  final nav = Navigator.of(context);
                  final ok = await ref
                      .read(cueDeckProvider.notifier)
                      .pairWithSelectedTv(customIp: ip);
                  if (mounted && ok) nav.pop();
                },
                icon: const Icon(Icons.flash_on_rounded, size: 16),
                label: const Text(
                  '⚡ PIN Olmadan Doğrudan Bağlan (Port 5555 Açık)',
                  style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11.5),
                ),
              ),
            ),
          ],
          const SizedBox(height: 10),
          TextField(
            controller: _pinController,
            keyboardType: TextInputType.visiblePassword,
            textCapitalization: TextCapitalization.characters,
            maxLength: 6,
            style: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.w800,
              fontSize: 16,
              letterSpacing: 4,
            ),
            decoration: InputDecoration(
              labelText: '6 Karakterli TV PIN Kodu (Örn: 123456 veya A1B2C3)',
              labelStyle: TextStyle(color: goldText, fontSize: 12),
              counterText: '',
              filled: true,
              fillColor: cardBg,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            onSubmitted: (_) => _submitPinAndPair(),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: const Color(0xFFE2A84B),
                foregroundColor: const Color(0xFF090A0F),
                padding: const EdgeInsets.symmetric(vertical: 12),
              ),
              onPressed: _isVerifyingPin ? null : _submitPinAndPair,
              child: Text(
                _isVerifyingPin
                    ? 'PIN Doğrulanıyor...'
                    : 'PIN ile Eşleştir ve Bağlan',
                style: const TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 13,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Step-by-Step Visual TV Setup Guide Sheet.
class TvSetupGuideSheet extends ConsumerWidget {
  const TvSetupGuideSheet({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final sheetBg =
        isDarkMode ? const Color(0xFF0A0C12) : const Color(0xFFF3F5F9);
    final primaryText = isDarkMode ? Colors.white : const Color(0xFF141821);
    final secondaryText =
        isDarkMode ? Colors.white70 : const Color(0xFF525B6C);
    final goldText =
        isDarkMode ? const Color(0xFFE2A84B) : const Color(0xFFB87818);

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: const EdgeInsets.fromLTRB(18, 16, 18, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(
            '📖 Adım Adım TV Eşleştirme & Bağlantı Rehberi',
            style: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            '1️⃣ Evrensel Smart TV & ADB Turbo Modu (Önerilen):',
            style: TextStyle(
              color: goldText,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '• Adım 1: Telefon ve TV aynı Wi-Fi ağında olsun.\n'
            '• Adım 2: Samsung Tizen ve LG webOS TV\'lerde ekranda çıkan "Bağlantıya İzin Ver" penceresini onaylayın.\n'
            '• Adım 3: Android TV\'de Geliştirici Seçenekleri > Kablosuz Ağ Hata Ayıklama (ADB) açın.\n'
            '• Adım 4: Wi-Fi erişilemezse "📡 Kızılötesi (IR) Kumanda" ile doğrudan kullanabilirsiniz.',
            style: TextStyle(color: secondaryText, fontSize: 12, height: 1.4),
          ),
          const SizedBox(height: 10),
          Text(
            '2️⃣ Standart Kumanda Modu (Port 6466 • 6 Haneli PIN):',
            style: TextStyle(
              color: goldText,
              fontWeight: FontWeight.w800,
              fontSize: 12.5,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            '• Geliştirici Seçenekleri olmayan standart Google TV cihazlarında "🔢 PIN Eşleştir (6466)" butonuna basıp TV ekranında beliren 6 haneli kodu girmeniz yeterlidir.',
            style: TextStyle(color: secondaryText, fontSize: 12, height: 1.35),
          ),
        ],
      ),
    );
  }
}

/// Runs diagnostic probes via `CueDeckNotifier.generateConnectionDiagnosticReport`
/// and presents a copyable troubleshooting summary.
class ConnectionDiagnosticSheet extends ConsumerStatefulWidget {
  const ConnectionDiagnosticSheet({super.key});

  @override
  ConsumerState<ConnectionDiagnosticSheet> createState() =>
      _ConnectionDiagnosticSheetState();
}

class _ConnectionDiagnosticSheetState
    extends ConsumerState<ConnectionDiagnosticSheet> {
  String _report = '';
  bool _running = false;

  @override
  void initState() {
    super.initState();
    Future<void>.microtask(_run);
  }

  Future<void> _run() async {
    setState(() {
      _running = true;
      _report = '';
    });
    final text = await ref
        .read(cueDeckProvider.notifier)
        .generateConnectionDiagnosticReport();
    if (!mounted) return;
    setState(() {
      _running = false;
      _report = text;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final sheetBg =
        isDarkMode ? const Color(0xFF0A0C12) : const Color(0xFFF3F5F9);
    final cardBg = isDarkMode ? const Color(0xFF11141E) : Colors.white;
    final primaryText = isDarkMode ? Colors.white : const Color(0xFF141821);
    final secondaryText =
        isDarkMode ? Colors.white70 : const Color(0xFF525B6C);
    final goldText =
        isDarkMode ? const Color(0xFFE2A84B) : const Color(0xFFB87818);

    return FractionallySizedBox(
      heightFactor: 0.85,
      child: Container(
        key: const Key('connection_diagnostic_sheet'),
        decoration: BoxDecoration(
          color: sheetBg,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
        ),
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
        child: SafeArea(
          top: false,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      '🩺 Bağlantı Tanılama Raporu',
                      style: TextStyle(
                        color: primaryText,
                        fontWeight: FontWeight.w800,
                        fontSize: 15,
                      ),
                    ),
                  ),
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close_rounded, color: secondaryText),
                  ),
                ],
              ),
              Text(
                'Önce kumandada 1-2 tuşa basın, sonra bu raporu kopyalayıp geliştiriciye gönderin.',
                style: TextStyle(color: secondaryText, fontSize: 11.5),
              ),
              const SizedBox(height: 10),
              Expanded(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: cardBg,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: _running
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: <Widget>[
                              CircularProgressIndicator(color: goldText),
                              const SizedBox(height: 10),
                              Text(
                                'TV portları ve yanıtları test ediliyor (~10 sn)...',
                                style: TextStyle(
                                  color: secondaryText,
                                  fontSize: 11.5,
                                ),
                              ),
                            ],
                          ),
                        )
                      : SingleChildScrollView(
                          child: SelectableText(
                            _report,
                            style: TextStyle(
                              color: primaryText,
                              fontSize: 10.5,
                              fontFamily: 'monospace',
                              height: 1.3,
                            ),
                          ),
                        ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _running ? null : _run,
                      icon: const Icon(Icons.refresh_rounded, size: 16),
                      label: const Text('Yeniden Test Et'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      style: FilledButton.styleFrom(
                        backgroundColor: goldText,
                        foregroundColor: const Color(0xFF090A0F),
                      ),
                      onPressed: _running || _report.isEmpty
                          ? null
                          : () async {
                              await Clipboard.setData(
                                ClipboardData(text: _report),
                              );
                              if (!context.mounted) return;
                              ScaffoldMessenger.of(context)
                                ..hideCurrentSnackBar()
                                ..showSnackBar(
                                  const SnackBar(
                                    content: Text(
                                      '✓ Rapor kopyalandı — WhatsApp\'a yapıştırabilirsiniz',
                                    ),
                                  ),
                                );
                            },
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Raporu Kopyala'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
