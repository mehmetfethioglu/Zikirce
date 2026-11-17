import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/cue_models.dart';
import '../../providers/cuedeck_providers.dart';
import 'cue_pro_paywall_sheet.dart';

/// Opens the Share-to-TV & Watch Scheduling modal for [initialPayload].
Future<void> showShareToTvBeamSheet(
  BuildContext context,
  SharedCuePayload initialPayload,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => ShareToTvBeamSheet(initialPayload: initialPayload),
  );
}

/// Bottom sheet allowing the user to immediately launch a shared/copied video URL
/// onto the active TV or schedule it for tonight's watch planner.
class ShareToTvBeamSheet extends ConsumerStatefulWidget {
  const ShareToTvBeamSheet({super.key, required this.initialPayload});

  final SharedCuePayload initialPayload;

  @override
  ConsumerState<ShareToTvBeamSheet> createState() => _ShareToTvBeamSheetState();
}

class _ShareToTvBeamSheetState extends ConsumerState<ShareToTvBeamSheet> {
  late final TextEditingController _titleController;
  late final TextEditingController _urlController;
  late StreamingPlatform _platform;
  bool _busy = false;

  @override
  void initState() {
    super.initState();
    _platform = widget.initialPayload.platform;
    _titleController = TextEditingController(text: widget.initialPayload.title);
    _urlController = TextEditingController(text: widget.initialPayload.url);
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  SharedCuePayload _buildEditedPayload() {
    final cleanUrl = _urlController.text.trim();
    final cleanTitle = _titleController.text.trim().isEmpty
        ? '${_platform.label} Yayını'
        : _titleController.text.trim();
    return widget.initialPayload.copyWith(
      url: cleanUrl,
      title: cleanTitle,
      platform: _platform,
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final hasProAccess =
        ref.watch(cueDeckProvider.select((s) => s.hasProAccess));
    final entitlement = ref.watch(cueDeckProvider.select((s) => s.entitlement));
    final remainingBeams = entitlement.remainingDailyFreeBeams();
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;

    final sheetBg =
        isDarkMode ? const Color(0xFF10131C) : const Color(0xFFF3F6FA);
    final primaryText = isDarkMode ? Colors.white : const Color(0xFF141821);
    final secondaryText =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF525B6C);
    final goldText =
        isDarkMode ? const Color(0xFFE6C17A) : const Color(0xFFB48328);

    return Container(
      key: const Key('share_to_tv_beam_sheet'),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.fromLTRB(16, 14, 16, bottomInset + 18),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Row(
                children: <Widget>[
                  Icon(_platform.icon, color: _platform.brandColor, size: 22),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Linki TV\'ye Işınla veya Planla',
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
                    onPressed: _dismissSheet,
                    icon: Icon(Icons.close_rounded, color: secondaryText),
                  ),
                ],
              ),
              const SizedBox(height: 6),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
                decoration: BoxDecoration(
                  color: goldText.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: goldText.withValues(alpha: 0.35)),
                ),
                child: Row(
                  children: <Widget>[
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: _platform.brandColor.withValues(alpha: 0.18),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        _platform.label,
                        style: TextStyle(
                          color: _platform.brandColor,
                          fontWeight: FontWeight.w800,
                          fontSize: 10.5,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        hasProAccess
                            ? 'Pro: Sınırsız Işınlama Aktif'
                            : 'Bugün kalan ücretsiz ışınlama: $remainingBeams / ${CueProProductCatalog.maxFreeDailyBeams}',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          color: primaryText,
                          fontWeight: FontWeight.w600,
                          fontSize: 11,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: _titleController,
                style: TextStyle(color: primaryText, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'İçerik Başlığı',
                  labelStyle: TextStyle(color: secondaryText),
                  filled: !isDarkMode,
                  fillColor: Colors.white,
                  isDense: true,
                ),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: _urlController,
                style: TextStyle(color: primaryText, fontSize: 12),
                decoration: InputDecoration(
                  labelText: 'Video / Playlist Bağlantısı',
                  labelStyle: TextStyle(color: secondaryText),
                  filled: !isDarkMode,
                  fillColor: Colors.white,
                  isDense: true,
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('share_sheet_schedule_button'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: goldText,
                        side: BorderSide(color: goldText.withValues(alpha: 0.6)),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _busy ? null : _handleSchedule,
                      icon: const Icon(Icons.schedule_rounded, size: 17),
                      label: const Text(
                        '⏰ Saati Seç & Planla',
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
                    child: FilledButton.icon(
                      key: const Key('share_sheet_launch_now_button'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE2A84B),
                        foregroundColor: const Color(0xFF090A0F),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _busy ? null : _handleLaunchNow,
                      icon: Icon(
                        _busy
                            ? Icons.hourglass_top_rounded
                            : Icons.cast_connected_rounded,
                        size: 17,
                      ),
                      label: const Text(
                        '🔥 Şimdi TV\'de Başlat',
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 11.5,
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

  void _dismissSheet() {
    ref.read(cueDeckProvider.notifier).clearPendingSharedPayload();
    Navigator.of(context).pop();
  }

  Future<void> _handleLaunchNow() async {
    HapticFeedback.mediumImpact();
    setState(() => _busy = true);
    final payload = _buildEditedPayload();
    final res = await ref
        .read(cueDeckProvider.notifier)
        .beamSharedPayloadNow(payload);
    if (!mounted) return;
    setState(() => _busy = false);
    if (res.needsPaywall) {
      Navigator.of(context).pop();
      await showCueProPaywallSheet(
        context,
        reasonMessage:
            'Günlük ${CueProProductCatalog.maxFreeDailyBeams} ücretsiz ışınlama hakkınız doldu. Sınırsız TV yayını için Pro\'yu açın.',
      );
      return;
    }
    Navigator.of(context).pop();
  }

  Future<void> _handleSchedule() async {
    HapticFeedback.selectionClick();
    final now = TimeOfDay.now();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: now.hour >= 21 ? now.hour : 21,
        minute: now.hour >= 21 ? now.minute : 30,
      ),
    );
    if (picked == null || !mounted) return;
    final payload = _buildEditedPayload();
    final ok = ref.read(cueDeckProvider.notifier).scheduleSharedPayload(
          payload,
          hour: picked.hour,
          minute: picked.minute,
        );
    if (!mounted) return;
    Navigator.of(context).pop();
    if (!ok) {
      await showCueProPaywallSheet(
        context,
        reasonMessage:
            'Ücretsiz sürümde en fazla ${CueProProductCatalog.maxFreeWatchPlans} özel izleme planı ekleyebilirsiniz.',
      );
    }
  }
}
