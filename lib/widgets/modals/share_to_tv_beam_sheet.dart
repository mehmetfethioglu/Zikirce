import 'dart:async';

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

enum _QuickSchedulePreset { in30Min, tonight, tomorrow, custom }

/// Bottom sheet allowing the user to immediately schedule a shared YouTube/video URL
/// into CueDeck's Watch Plan or beam it straight onto the active TV.
class ShareToTvBeamSheet extends ConsumerStatefulWidget {
  const ShareToTvBeamSheet({super.key, required this.initialPayload});

  final SharedCuePayload initialPayload;

  @override
  ConsumerState<ShareToTvBeamSheet> createState() => _ShareToTvBeamSheetState();
}

class _ShareToTvBeamSheetState extends ConsumerState<ShareToTvBeamSheet> {
  static const Set<String> _genericYoutubeTitles = <String>{
    'YouTube Paylaşımı',
    'YouTube Videosu',
    'YouTube Oynatma Listesi',
    'YouTube Shorts',
  };

  static const List<WatchRecurrence> _quickRecurrences = <WatchRecurrence>[
    WatchRecurrence.once,
    WatchRecurrence.daily,
    WatchRecurrence.weekdays,
    WatchRecurrence.weekends,
  ];

  late final TextEditingController _titleController;
  late final TextEditingController _urlController;
  late StreamingPlatform _platform;
  late DateTime _selectedDateTime;
  _QuickSchedulePreset _activePreset = _QuickSchedulePreset.in30Min;
  WatchRecurrence _selectedRecurrence = WatchRecurrence.once;
  bool _busy = false;
  bool _fetchingTitle = false;
  bool _userEditedTitle = false;

  @override
  void initState() {
    super.initState();
    _platform = widget.initialPayload.platform;
    _titleController = TextEditingController(text: widget.initialPayload.title);
    _urlController = TextEditingController(text: widget.initialPayload.url);
    _selectedDateTime = DateTime.now().add(const Duration(minutes: 30));

    final initialTitle = widget.initialPayload.title.trim();
    if (_platform == StreamingPlatform.youtube &&
        (initialTitle.isEmpty || _genericYoutubeTitles.contains(initialTitle))) {
      unawaited(_fetchYoutubeTitleIfNeeded());
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    super.dispose();
  }

  Future<void> _fetchYoutubeTitleIfNeeded() async {
    final url = _urlController.text.trim();
    if (url.isEmpty) return;
    if (mounted) {
      setState(() => _fetchingTitle = true);
    }
    try {
      final fetched = await ref
          .read(cueShareIntentServiceProvider)
          .fetchYoutubeTitle(url);
      if (!mounted || _userEditedTitle) return;
      if (fetched != null && fetched.isNotEmpty) {
        _titleController.text = fetched;
      }
    } finally {
      if (mounted) {
        setState(() => _fetchingTitle = false);
      }
    }
  }

  String _tonightLabel(DateTime now) {
    final at21 = DateTime(now.year, now.month, now.day, 21, 0);
    if (at21.isAfter(now.add(const Duration(minutes: 10)))) {
      return 'Bu Akşam 21:00';
    }
    final at2230 = DateTime(now.year, now.month, now.day, 22, 30);
    if (at2230.isAfter(now.add(const Duration(minutes: 10)))) {
      return 'Bu Gece 22:30';
    }
    return 'Yarın 21:00';
  }

  DateTime _computeTonightDateTime(DateTime now) {
    final at21 = DateTime(now.year, now.month, now.day, 21, 0);
    if (at21.isAfter(now.add(const Duration(minutes: 10)))) {
      return at21;
    }
    final at2230 = DateTime(now.year, now.month, now.day, 22, 30);
    if (at2230.isAfter(now.add(const Duration(minutes: 10)))) {
      return at2230;
    }
    return at21.add(const Duration(days: 1));
  }

  String get _formattedSelectedSchedule {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final targetDay = DateTime(
      _selectedDateTime.year,
      _selectedDateTime.month,
      _selectedDateTime.day,
    );
    final diffDays = targetDay.difference(today).inDays;
    final hh = _selectedDateTime.hour.toString().padLeft(2, '0');
    final mm = _selectedDateTime.minute.toString().padLeft(2, '0');
    if (diffDays == 0) return 'Bugün $hh:$mm';
    if (diffDays == 1) return 'Yarın $hh:$mm';
    final dd = _selectedDateTime.day.toString().padLeft(2, '0');
    final mo = _selectedDateTime.month.toString().padLeft(2, '0');
    return '$dd.$mo $hh:$mm';
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
    final surfaceBg = isDarkMode ? const Color(0xFF161B28) : Colors.white;
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.10)
        : const Color(0xFFD6DCE8);
    final primaryText = isDarkMode ? Colors.white : const Color(0xFF141821);
    final secondaryText =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF525B6C);
    final goldText =
        isDarkMode ? const Color(0xFFE6C17A) : const Color(0xFFB48328);

    final now = DateTime.now();

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
                      'CueDeck Planına Ekle veya TV\'ye Işınla',
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
                onChanged: (_) => _userEditedTitle = true,
                style: TextStyle(color: primaryText, fontSize: 13),
                decoration: InputDecoration(
                  labelText: 'İçerik Başlığı',
                  labelStyle: TextStyle(color: secondaryText),
                  filled: !isDarkMode,
                  fillColor: Colors.white,
                  isDense: true,
                  suffixIcon: _fetchingTitle
                      ? Padding(
                          padding: const EdgeInsets.all(10),
                          child: SizedBox(
                            width: 14,
                            height: 14,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: goldText,
                            ),
                          ),
                        )
                      : null,
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
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  Icon(Icons.schedule_rounded, size: 15, color: goldText),
                  const SizedBox(width: 6),
                  Text(
                    'İzleme Zamanı',
                    style: TextStyle(
                      color: primaryText,
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                  const Spacer(),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: goldText.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      _formattedSelectedSchedule,
                      style: TextStyle(
                        color: goldText,
                        fontWeight: FontWeight.w800,
                        fontSize: 11,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: <Widget>[
                  _SchedulePresetPill(
                    label: '30 dk sonra',
                    selected: _activePreset == _QuickSchedulePreset.in30Min,
                    surfaceBg: surfaceBg,
                    borderColor: borderColor,
                    goldColor: goldText,
                    textColor: primaryText,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _activePreset = _QuickSchedulePreset.in30Min;
                        _selectedDateTime = DateTime.now().add(
                          const Duration(minutes: 30),
                        );
                      });
                    },
                  ),
                  _SchedulePresetPill(
                    label: _tonightLabel(now),
                    selected: _activePreset == _QuickSchedulePreset.tonight,
                    surfaceBg: surfaceBg,
                    borderColor: borderColor,
                    goldColor: goldText,
                    textColor: primaryText,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      setState(() {
                        _activePreset = _QuickSchedulePreset.tonight;
                        _selectedDateTime = _computeTonightDateTime(
                          DateTime.now(),
                        );
                      });
                    },
                  ),
                  _SchedulePresetPill(
                    label: 'Yarın 20:00',
                    selected: _activePreset == _QuickSchedulePreset.tomorrow,
                    surfaceBg: surfaceBg,
                    borderColor: borderColor,
                    goldColor: goldText,
                    textColor: primaryText,
                    onTap: () {
                      HapticFeedback.selectionClick();
                      final cur = DateTime.now();
                      setState(() {
                        _activePreset = _QuickSchedulePreset.tomorrow;
                        _selectedDateTime = DateTime(
                          cur.year,
                          cur.month,
                          cur.day + 1,
                          20,
                          0,
                        );
                      });
                    },
                  ),
                  _SchedulePresetPill(
                    key: const Key('share_sheet_pick_time_button'),
                    label: 'Saat Seç',
                    icon: Icons.access_time_rounded,
                    selected: _activePreset == _QuickSchedulePreset.custom,
                    surfaceBg: surfaceBg,
                    borderColor: borderColor,
                    goldColor: goldText,
                    textColor: primaryText,
                    onTap: _pickCustomTime,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: _quickRecurrences.map((rec) {
                  final isSelected = rec == _selectedRecurrence;
                  return ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(rec.label),
                    selected: isSelected,
                    backgroundColor: surfaceBg,
                    selectedColor: goldText.withValues(alpha: 0.20),
                    checkmarkColor: goldText,
                    side: BorderSide(
                      color: isSelected ? goldText : borderColor,
                    ),
                    labelStyle: TextStyle(
                      color: isSelected ? primaryText : secondaryText,
                      fontWeight: FontWeight.w600,
                      fontSize: 10.5,
                    ),
                    onSelected: (_) {
                      HapticFeedback.selectionClick();
                      setState(() => _selectedRecurrence = rec);
                    },
                  );
                }).toList(growable: false),
              ),
              const SizedBox(height: 14),
              Row(
                children: <Widget>[
                  Expanded(
                    flex: 5,
                    child: FilledButton.icon(
                      key: const Key('share_sheet_schedule_button'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFE2A84B),
                        foregroundColor: const Color(0xFF090A0F),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: _busy ? null : _handleSchedule,
                      icon: const Icon(Icons.playlist_add_check_rounded, size: 18),
                      label: const Text(
                        'Plana Ekle',
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
                    flex: 4,
                    child: OutlinedButton.icon(
                      key: const Key('share_sheet_launch_now_button'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: goldText,
                        side: BorderSide(color: goldText.withValues(alpha: 0.6)),
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
                        'TV\'de Aç',
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
          ),
        ),
      ),
    );
  }

  Future<void> _pickCustomTime() async {
    HapticFeedback.selectionClick();
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(
        hour: _selectedDateTime.hour,
        minute: _selectedDateTime.minute,
      ),
    );
    if (picked == null || !mounted) return;
    final now = DateTime.now();
    var next = DateTime(now.year, now.month, now.day, picked.hour, picked.minute);
    if (!next.isAfter(now)) {
      next = next.add(const Duration(days: 1));
    }
    setState(() {
      _activePreset = _QuickSchedulePreset.custom;
      _selectedDateTime = next;
    });
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
    HapticFeedback.mediumImpact();
    final payload = _buildEditedPayload();
    final ok = ref.read(cueDeckProvider.notifier).scheduleSharedPayload(
          payload,
          hour: _selectedDateTime.hour,
          minute: _selectedDateTime.minute,
          scheduledDateTime: _selectedDateTime,
          recurrence: _selectedRecurrence,
        );
    if (!mounted) return;
    final messenger = ScaffoldMessenger.maybeOf(context);
    Navigator.of(context).pop();
    if (!ok) {
      await showCueProPaywallSheet(
        context,
        reasonMessage:
            'Ücretsiz sürümde en fazla ${CueProProductCatalog.maxFreeWatchPlans} özel izleme planı ekleyebilirsiniz.',
      );
      return;
    }
    messenger
      ?..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          behavior: SnackBarBehavior.floating,
          backgroundColor: const Color(0xFF0A0C12),
          content: Text(
            '✓ CueDeck planına eklendi: ${payload.title}',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: const TextStyle(color: Colors.white, fontSize: 12.5),
          ),
        ),
      );
  }
}

class _SchedulePresetPill extends StatelessWidget {
  const _SchedulePresetPill({
    super.key,
    required this.label,
    required this.selected,
    required this.surfaceBg,
    required this.borderColor,
    required this.goldColor,
    required this.textColor,
    required this.onTap,
    this.icon,
  });

  final String label;
  final bool selected;
  final Color surfaceBg;
  final Color borderColor;
  final Color goldColor;
  final Color textColor;
  final VoidCallback onTap;
  final IconData? icon;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
        decoration: BoxDecoration(
          color: selected ? goldColor.withValues(alpha: 0.16) : surfaceBg,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: selected ? goldColor : borderColor,
            width: selected ? 1.2 : 1.0,
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            if (icon != null) ...<Widget>[
              Icon(icon, size: 13, color: selected ? goldColor : textColor),
              const SizedBox(width: 4),
            ],
            Text(
              label,
              style: TextStyle(
                color: selected ? goldColor : textColor,
                fontWeight: selected ? FontWeight.w800 : FontWeight.w600,
                fontSize: 11,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
