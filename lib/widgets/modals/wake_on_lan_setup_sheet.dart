import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../providers/cuedeck_providers.dart';

/// Opens the Wake-on-LAN MAC configuration and closed-TV wake modal sheet.
Future<void> showWakeOnLanSetupSheet(BuildContext context) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => const WakeOnLanSetupSheet(),
  );
}

/// Modal sheet for entering or editing a TV's MAC address (and optional IP)
/// to wake a turned-off TV via Wake-on-LAN without an IR blaster.
class WakeOnLanSetupSheet extends ConsumerStatefulWidget {
  const WakeOnLanSetupSheet({super.key});

  @override
  ConsumerState<WakeOnLanSetupSheet> createState() =>
      _WakeOnLanSetupSheetState();
}

class _WakeOnLanSetupSheetState extends ConsumerState<WakeOnLanSetupSheet> {
  late final TextEditingController _macController;
  late final TextEditingController _ipController;
  String? _errorText;
  bool _submitting = false;

  @override
  void initState() {
    super.initState();
    final device = ref.read(cueDeckProvider).selectedDevice;
    _macController = TextEditingController(text: device.macAddress);
    _ipController = TextEditingController(text: device.ip);
  }

  @override
  void dispose() {
    _macController.dispose();
    _ipController.dispose();
    super.dispose();
  }

  Future<void> _handleSave({required bool wakeImmediately}) async {
    if (_submitting) return;
    final normalizedMac = TvNetworkValidators.normalizeMacAddress(
      _macController.text,
    );
    if (normalizedMac.isEmpty) {
      setState(() {
        _errorText =
            'Geçerli bir MAC adresi girin (Örn: AA:BB:CC:DD:EE:FF)';
      });
      return;
    }
    final rawIp = _ipController.text.trim();
    if (rawIp.isNotEmpty && !TvNetworkValidators.isValidIp(rawIp)) {
      setState(() {
        _errorText = 'Geçerli bir TV IPv4 adresi girin veya boş bırakın';
      });
      return;
    }

    HapticFeedback.mediumImpact();
    setState(() {
      _errorText = null;
      _submitting = true;
    });

    final ok = await ref.read(cueDeckProvider.notifier).saveSelectedTvMacAddress(
          normalizedMac,
          optionalIp: rawIp,
          wakeImmediately: wakeImmediately,
        );
    if (!mounted) return;
    setState(() {
      _submitting = false;
    });
    if (ok) {
      Navigator.of(context).pop();
    } else {
      setState(() {
        _errorText =
            'WoL paketi gönderilemedi — aynı Wi-Fi ağında olduğunuzu kontrol edin';
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final selectedDevice = ref.watch(
      cueDeckProvider.select((s) => s.selectedDevice),
    );
    final showOptionalIpField = !selectedDevice.hasValidIp;
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

    return Container(
      key: const Key('wake_on_lan_setup_sheet'),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        border: Border.all(color: cardBorder),
      ),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: EdgeInsets.fromLTRB(18, 16, 18, bottomInset + 22),
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
                      Icons.power_settings_new_rounded,
                      color: goldText,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      '⚡ Kapalı TV Uyandır (Wake-on-LAN)',
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
              const SizedBox(height: 10),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: cardBg,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: cardBorder),
                ),
                child: Text(
                  '• Kumanda kayıpsa ve TV kapalıysa, modem arayüzündeki bağlı/geçmiş cihazlardan veya TV arkasındaki etiketten MAC adresini yazarak uyandırma paketi gönderebilirsiniz.\n'
                  '• TV fişte (Standby) olmalı ve TV ayarlarında "Mobil ile Aç / Ağdan Uyandır / WoL" özelliği açık olmalıdır.',
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 11.5,
                    height: 1.4,
                  ),
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                key: const Key('wol_mac_input'),
                controller: _macController,
                textCapitalization: TextCapitalization.characters,
                autocorrect: false,
                style: TextStyle(color: primaryText, fontSize: 13),
                onChanged: (_) {
                  if (_errorText != null) {
                    setState(() => _errorText = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'TV MAC Adresi',
                  labelStyle: TextStyle(color: goldText, fontSize: 12),
                  hintText: 'AA:BB:CC:DD:EE:FF',
                  hintStyle: TextStyle(color: secondaryText, fontSize: 12),
                  isDense: true,
                  filled: true,
                  fillColor: cardBg,
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 11,
                  ),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cardBorder),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: cardBorder),
                  ),
                ),
              ),
              if (showOptionalIpField) ...<Widget>[
                const SizedBox(height: 10),
                TextField(
                  key: const Key('wol_ip_input'),
                  controller: _ipController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  autocorrect: false,
                  style: TextStyle(color: primaryText, fontSize: 13),
                  onChanged: (_) {
                    if (_errorText != null) {
                      setState(() => _errorText = null);
                    }
                  },
                  decoration: InputDecoration(
                    labelText: 'TV IP Adresi (Opsiyonel)',
                    labelStyle: TextStyle(color: secondaryText, fontSize: 12),
                    hintText: 'Opsiyonel TV IP (Örn: 192.168.1.50)',
                    hintStyle: TextStyle(color: secondaryText, fontSize: 11.5),
                    isDense: true,
                    filled: true,
                    fillColor: cardBg,
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 11,
                    ),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cardBorder),
                    ),
                    enabledBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide(color: cardBorder),
                    ),
                  ),
                ),
              ],
              if (_errorText != null) ...<Widget>[
                const SizedBox(height: 8),
                Text(
                  _errorText!,
                  key: const Key('wol_error_text'),
                  style: const TextStyle(
                    color: Color(0xFFF87171),
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      key: const Key('wol_save_only_button'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: primaryText,
                        side: BorderSide(color: cardBorder),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _submitting
                          ? null
                          : () => _handleSave(wakeImmediately: false),
                      child: const Text(
                        'Kaydet',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          fontSize: 12.5,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: FilledButton(
                      key: const Key('wol_save_and_wake_button'),
                      style: FilledButton.styleFrom(
                        backgroundColor: goldText,
                        foregroundColor: const Color(0xFF0A0C12),
                        padding: const EdgeInsets.symmetric(vertical: 11),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _submitting
                          ? null
                          : () => _handleSave(wakeImmediately: true),
                      child: const Text(
                        '⚡ Kaydet ve TV\'yi Uyandır',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
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
    );
  }
}
