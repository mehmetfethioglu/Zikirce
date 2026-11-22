import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../models/cue_models.dart';
import '../../providers/cuedeck_providers.dart';
import '../tactile_dpad_painter.dart';

/// Opens a compact detail sheet wrapping [WatchCueCard] so users can adjust
/// sliders, progress steps, edit, delete, test reminders, or beam directly from
/// the remote's plan carousel.
Future<void> showWatchPlanDetailSheet(
  BuildContext context,
  WatchCueItem item,
) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => WatchPlanDetailSheet(cueId: item.id, initialItem: item),
  );
}

/// Interactive detail bottom sheet hosting a single [WatchCueCard].
class WatchPlanDetailSheet extends ConsumerWidget {
  const WatchPlanDetailSheet({
    super.key,
    required this.cueId,
    required this.initialItem,
  });

  final String cueId;
  final WatchCueItem initialItem;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final cueItems = ref.watch(cueDeckProvider.select((s) => s.cueItems));
    final activePlayingId = ref.watch(
      cueDeckProvider.select((s) => s.activePlayingCueId),
    );

    WatchCueItem? liveItem;
    for (final candidate in cueItems) {
      if (candidate.id == cueId) {
        liveItem = candidate;
        break;
      }
    }

    if (liveItem == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (context.mounted && Navigator.of(context).canPop()) {
          Navigator.of(context).pop();
        }
      });
      return const SizedBox.shrink();
    }

    final sheetBg =
        isDarkMode ? const Color(0xFF10131C) : const Color(0xFFF3F6FA);
    final primaryText =
        isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
    final secondaryText =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);

    return Container(
      key: const Key('watch_plan_detail_sheet'),
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
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
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: <Widget>[
                  Expanded(
                    child: Text(
                      'Plan Detayı & İlerleme',
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
              const SizedBox(height: 8),
              WatchCueCard(
                item: liveItem,
                isPlayingOnTv: liveItem.id == activePlayingId,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Header card summarizing daily watch plan progress (`WatchPlanMasteryHeader`).
class WatchPlanMasteryHeader extends ConsumerWidget {
  const WatchPlanMasteryHeader({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final overallPercent = ref.watch(
      cueDeckProvider.select((s) => s.overallCompletionPercent),
    );
    final watchedMins = ref.watch(
      cueDeckProvider.select((s) => s.totalWatchedMinutes),
    );
    final totalMins = ref.watch(
      cueDeckProvider.select((s) => s.totalPlannedMinutes),
    );
    final completedCount = ref.watch(
      cueDeckProvider.select((s) => s.completedCount),
    );
    final totalCount = ref.watch(
      cueDeckProvider.select((s) => s.cueItems.length),
    );

    final primaryText =
        isDarkMode ? const Color(0xFFF1F5F9) : const Color(0xFF1E293B);
    final secondaryText =
        isDarkMode ? const Color(0xFF94A3B8) : const Color(0xFF64748B);
    final goldText =
        isDarkMode ? const Color(0xFFE6C17A) : const Color(0xFFB48328);
    final borderColor = isDarkMode
        ? Colors.white.withValues(alpha: 0.09)
        : const Color(0xFFE2E8F0);

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(18),
        color: isDarkMode ? const Color(0xFF0A0C12) : Colors.white,
        border: Border.all(color: borderColor),
      ),
      child: Row(
        children: <Widget>[
          SizedBox(
            width: 68,
            height: 68,
            child: Stack(
              alignment: Alignment.center,
              children: <Widget>[
                Positioned.fill(
                  child: CustomPaint(
                    painter: CircularProgressRingPainter(
                      progress: overallPercent / 100.0,
                      primaryColor: const Color(0xFFE6C17A),
                      secondaryColor: const Color(0xFF818CF8),
                      isDarkMode: isDarkMode,
                    ),
                  ),
                ),
                Text(
                  '%$overallPercent',
                  style: TextStyle(
                    color: primaryText,
                    fontWeight: FontWeight.w800,
                    fontSize: 15,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'GÜNLÜK İZLEME PLANI TAMAMLAMA',
                  style: TextStyle(
                    color: goldText,
                    fontWeight: FontWeight.w700,
                    fontSize: 10.5,
                    letterSpacing: 0.4,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  '$watchedMins / $totalMins dakika izlendi',
                  style: TextStyle(
                    color: primaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 14,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '$completedCount / $totalCount içerik tamamlandı',
                  style: TextStyle(
                    color: secondaryText,
                    fontSize: 11.5,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Detailed card for each scheduled watch item with recurrence/session badge,
/// YouTube Playlist & deep-link status badges, progress slider, +Seans/+10m/+1Unit,
/// Edit modal trigger, reminder test trigger, and 1-tap "TV'de Başlat".
class WatchCueCard extends ConsumerWidget {
  const WatchCueCard({
    super.key,
    required this.item,
    required this.isPlayingOnTv,
  });

  final WatchCueItem item;
  final bool isPlayingOnTv;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final brandColor = item.platform.brandColor;
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
    final borderColor = isPlayingOnTv
        ? goldText.withValues(alpha: 0.50)
        : (isDarkMode
            ? Colors.white.withValues(alpha: 0.09)
            : const Color(0xFFE2E8F0));

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: cardBg,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: borderColor,
          width: isPlayingOnTv ? 1.4 : 1.0,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Row(
            children: <Widget>[
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: brandColor.withValues(alpha: isDarkMode ? 0.14 : 0.10),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Icon(item.platform.icon, color: brandColor, size: 14),
                    const SizedBox(width: 5),
                    Text(
                      item.platform.label,
                      style: TextStyle(
                        color: brandColor,
                        fontWeight: FontWeight.w700,
                        fontSize: 11.5,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: subSurfaceBg,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    item.scheduleBadgeText,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: secondaryText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '%${item.progressPercent}',
                style: TextStyle(
                  color: goldText,
                  fontWeight: FontWeight.w800,
                  fontSize: 14.5,
                ),
              ),
            ],
          ),
          if (item.isYoutubePlaylist || item.deepLinkUrl.isNotEmpty) ...<Widget>[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: <Widget>[
                if (item.isYoutubePlaylist)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: subSurfaceBg,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: buttonBorder),
                    ),
                    child: Text(
                      'YouTube Playlist (${item.totalEpisodes} Video)',
                      style: TextStyle(
                        color: secondaryText,
                        fontWeight: FontWeight.w600,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
                if (item.deepLinkUrl.isNotEmpty)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 3,
                    ),
                    decoration: BoxDecoration(
                      color: mintText.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      'Bağlantı Aktif',
                      style: TextStyle(
                        color: mintText,
                        fontWeight: FontWeight.w600,
                        fontSize: 10.5,
                      ),
                    ),
                  ),
              ],
            ),
          ],
          const SizedBox(height: 10),
          Text(
            item.title,
            style: TextStyle(
              color: primaryText,
              fontWeight: FontWeight.w700,
              fontSize: 14.5,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            item.checkpointSummary,
            style: TextStyle(
              color: secondaryText,
              fontSize: 12,
            ),
          ),
          const SizedBox(height: 6),
          SliderTheme(
            data: SliderTheme.of(context).copyWith(
              trackHeight: 5,
              thumbShape: const RoundSliderThumbShape(enabledThumbRadius: 6.5),
              overlayShape: const RoundSliderOverlayShape(overlayRadius: 13),
              activeTrackColor: brandColor.withValues(alpha: 0.85),
              inactiveTrackColor: isDarkMode
                  ? Colors.white.withValues(alpha: 0.08)
                  : Colors.black.withValues(alpha: 0.08),
              thumbColor: goldText,
            ),
            child: Slider(
              value: item.watchedMinutes.toDouble().clamp(
                    0,
                    item.totalMinutes.toDouble(),
                  ),
              max: item.totalMinutes.toDouble(),
              onChanged: (val) {
                ref.read(cueDeckProvider.notifier).updateProgress(
                      item.id,
                      watchedMinutes: val.round(),
                    );
              },
            ),
          ),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: <Widget>[
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: goldText,
                  side: BorderSide(color: buttonBorder),
                  backgroundColor: subSurfaceBg,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  ref
                      .read(cueDeckProvider.notifier)
                      .completeSessionStep(item.id);
                },
                child: Text(
                  '+Seans (${item.sessionMinutes}dk)',
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              OutlinedButton(
                style: OutlinedButton.styleFrom(
                  foregroundColor: primaryText,
                  side: BorderSide(color: buttonBorder),
                  backgroundColor: subSurfaceBg,
                  padding: const EdgeInsets.symmetric(horizontal: 9),
                  minimumSize: const Size(0, 30),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  ref.read(cueDeckProvider.notifier).stepProgress(item.id, 10);
                },
                child: const Text('+10 dk', style: TextStyle(fontSize: 11)),
              ),
              if (item.totalEpisodes > 1)
                OutlinedButton(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: primaryText,
                    side: BorderSide(color: buttonBorder),
                    backgroundColor: subSurfaceBg,
                    padding: const EdgeInsets.symmetric(horizontal: 9),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    ref.read(cueDeckProvider.notifier).updateProgress(
                          item.id,
                          currentEpisode: item.currentEpisode + 1,
                        );
                  },
                  child: Text(
                    '+1 ${item.platform.unitLabel}',
                    style: const TextStyle(fontSize: 11),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            children: <Widget>[
              IconButton(
                tooltip: 'Planı Düzenle',
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(28, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () => _openEditCueModal(context, item),
                icon: Icon(
                  Icons.edit_outlined,
                  color: secondaryText,
                  size: 17,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Hatırlatma Bildirimini Test Et',
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(28, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  ref.read(cueDeckProvider.notifier).triggerTestReminder(item);
                },
                icon: Icon(
                  Icons.notifications_active_outlined,
                  color: goldText,
                  size: 17,
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                tooltip: 'Planı Sil',
                style: IconButton.styleFrom(
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(28, 28),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                onPressed: () {
                  ref.read(cueDeckProvider.notifier).deleteWatchCue(item.id);
                },
                icon: Icon(
                  Icons.delete_outline_rounded,
                  color: secondaryText,
                  size: 17,
                ),
              ),
              const Spacer(),
              Flexible(
                child: FilledButton.icon(
                  style: FilledButton.styleFrom(
                    backgroundColor: brandColor,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    minimumSize: const Size(0, 30),
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    ref.read(cueDeckProvider.notifier).beamCueToTv(item);
                  },
                  icon: const Icon(Icons.play_arrow_rounded, size: 15),
                  label: const Text(
                    'TV\'de Başlat',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  void _openEditCueModal(BuildContext context, WatchCueItem existing) {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (_) => AddWatchCueSheet(existingItem: existing),
    );
  }
}

/// Advanced Bottom Sheet form for adding or editing a scheduled watch plan item
/// with YouTube Playlist / deep-link support, clipboard paste, recurrence period,
/// weekday selector, exact clock time, session duration, and multi-video/episode tracking.
class AddWatchCueSheet extends ConsumerStatefulWidget {
  const AddWatchCueSheet({super.key, this.existingItem});

  final WatchCueItem? existingItem;

  @override
  ConsumerState<AddWatchCueSheet> createState() => _AddWatchCueSheetState();
}

class _AddWatchCueSheetState extends ConsumerState<AddWatchCueSheet> {
  static const List<String> _quickClockPresets = <String>[
    '20:00',
    '21:00',
    '21:30',
    '22:30',
  ];

  static const List<int> _sessionDurationPresets = <int>[30, 45, 60, 90];
  static const List<int> _reminderLeadPresets = <int>[5, 10, 15, 30];

  late final TextEditingController _titleController;
  late final TextEditingController _subtitleController;
  late final TextEditingController _urlController;
  late final TextEditingController _durationController;
  late final TextEditingController _sessionDurationController;
  late final TextEditingController _currentEpisodeController;
  late final TextEditingController _totalEpisodesController;
  late final FocusNode _titleFocusNode;
  late final FocusNode _urlFocusNode;

  late StreamingPlatform _selectedPlatform;
  late WatchRecurrence _selectedRecurrence;
  late List<int> _selectedWeekdays;
  late int _selectedHour;
  late int _selectedMinute;
  late int _selectedReminderMinutes;

  @override
  void initState() {
    super.initState();
    final existing = widget.existingItem;
    final defaultTime =
        existing?.scheduledTime ?? DateTime.now().add(const Duration(minutes: 30));

    _selectedPlatform = existing?.platform ?? StreamingPlatform.youtube;
    _selectedRecurrence = existing?.recurrence ?? WatchRecurrence.daily;
    _selectedWeekdays = existing != null
        ? List<int>.from(existing.activeWeekdays)
        : List<int>.from(_selectedRecurrence.defaultDays);
    _selectedHour = defaultTime.hour;
    _selectedMinute = defaultTime.minute;
    _selectedReminderMinutes = existing?.reminderMinutesBefore ?? 15;

    _titleController = TextEditingController(text: existing?.title ?? '');
    _subtitleController = TextEditingController(
      text: existing?.subtitle ?? 'Oynatma Listesi • Kaldığın Yerden Devam',
    );
    _urlController = TextEditingController(text: existing?.deepLinkUrl ?? '');
    _durationController = TextEditingController(
      text: (existing?.totalMinutes ?? 180).toString(),
    );
    _sessionDurationController = TextEditingController(
      text: (existing?.sessionMinutes ?? 45).toString(),
    );
    _currentEpisodeController = TextEditingController(
      text: (existing?.currentEpisode ?? 1).toString(),
    );
    _totalEpisodesController = TextEditingController(
      text: (existing?.totalEpisodes ?? 8).toString(),
    );
    _titleFocusNode = FocusNode();
    _urlFocusNode = FocusNode();
  }

  @override
  void dispose() {
    _titleController.dispose();
    _subtitleController.dispose();
    _urlController.dispose();
    _durationController.dispose();
    _sessionDurationController.dispose();
    _currentEpisodeController.dispose();
    _totalEpisodesController.dispose();
    _titleFocusNode.dispose();
    _urlFocusNode.dispose();
    super.dispose();
  }

  String get _formattedSelectedClock {
    final h = _selectedHour.toString().padLeft(2, '0');
    final m = _selectedMinute.toString().padLeft(2, '0');
    return '$h:$m';
  }

  bool get _isYoutubePlaylistDetected {
    if (_selectedPlatform != StreamingPlatform.youtube) return false;
    final raw = _urlController.text.trim();
    if (raw.isEmpty) return false;
    final normalized = WatchCueItem.normalizeContentLink(_selectedPlatform, raw);
    return normalized.contains('list=') ||
        RegExp(r'^(PL|UU|FL|RD|OL)[a-zA-Z0-9_-]{8,}$').hasMatch(raw);
  }

  @override
  Widget build(BuildContext context) {
    final isDarkMode = ref.watch(cueDeckProvider.select((s) => s.isDarkMode));
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isEditing = widget.existingItem != null;
    final unit = _selectedPlatform.unitLabel;
    final normalizedUrl = WatchCueItem.normalizeContentLink(
      _selectedPlatform,
      _urlController.text,
    );

    final sheetBg =
        isDarkMode ? const Color(0xFF141722) : const Color(0xFFF3F5F9);
    final primaryText = isDarkMode ? Colors.white : const Color(0xFF141821);
    final secondaryText =
        isDarkMode ? Colors.white70 : const Color(0xFF525B6C);
    final goldText =
        isDarkMode ? const Color(0xFFE2A84B) : const Color(0xFFB87818);
    final subSurfaceBg = isDarkMode ? const Color(0xFF0E1018) : Colors.white;
    final chipBg =
        isDarkMode ? const Color(0xFF1A1E2D) : const Color(0xFFEDEFF5);
    final chipSelectedBg =
        isDarkMode ? const Color(0xFF3A2E1B) : const Color(0xFFF9E6C0);
    final subtleBorder = isDarkMode
        ? Colors.white.withValues(alpha: 0.14)
        : const Color(0xFFCFD6E2);

    return Container(
      decoration: BoxDecoration(
        color: sheetBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      ),
      padding: EdgeInsets.fromLTRB(16, 16, 16, bottomInset + 20),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            Row(
              children: <Widget>[
                Expanded(
                  child: Text(
                    isEditing
                        ? 'İzleme Planını Düzenle'
                        : 'Yeni Kişisel İzleme Planı Ekle',
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
                  onPressed: () => Navigator.of(context).pop(),
                  icon: Icon(Icons.close_rounded, color: secondaryText),
                ),
              ],
            ),
            const SizedBox(height: 8),

            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: StreamingPlatform.values.map((p) {
                final selected = p == _selectedPlatform;
                return ChoiceChip(
                  label: Text(p.label),
                  selected: selected,
                  backgroundColor: chipBg,
                  selectedColor:
                      p.brandColor.withValues(alpha: isDarkMode ? 0.35 : 0.22),
                  checkmarkColor: isDarkMode ? Colors.white : p.brandColor,
                  side: BorderSide(
                    color: selected ? p.brandColor : subtleBorder,
                  ),
                  labelStyle: TextStyle(
                    color: selected
                        ? (isDarkMode ? Colors.white : const Color(0xFF141821))
                        : secondaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 11.5,
                  ),
                  onSelected: (_) => setState(() => _selectedPlatform = p),
                );
              }).toList(),
            ),
            const SizedBox(height: 10),

            TextField(
              controller: _titleController,
              focusNode: _titleFocusNode,
              style: TextStyle(color: primaryText, fontSize: 13),
              decoration: InputDecoration(
                labelText: 'İçerik / Oynatma Listesi Adı',
                labelStyle: TextStyle(color: secondaryText),
                hintText: _selectedPlatform.titleHint,
                hintStyle: TextStyle(color: secondaryText),
                filled: !isDarkMode,
                fillColor: Colors.white,
                isDense: true,
              ),
            ),
            const SizedBox(height: 10),

            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _urlController,
                    focusNode: _urlFocusNode,
                    style: TextStyle(color: primaryText, fontSize: 12.5),
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: _selectedPlatform == StreamingPlatform.youtube
                          ? 'YouTube Playlist / Video Linki'
                          : '${_selectedPlatform.label} İçerik Linki (Opsiyonel)',
                      labelStyle: TextStyle(color: secondaryText),
                      hintText: _selectedPlatform.linkHint,
                      hintStyle: TextStyle(color: secondaryText),
                      filled: !isDarkMode,
                      fillColor: Colors.white,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: goldText,
                    side: BorderSide(
                      color: const Color(0xFFE2A84B).withValues(alpha: 0.55),
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 10,
                    ),
                  ),
                  onPressed: _pasteFromClipboard,
                  icon: const Icon(Icons.content_paste_rounded, size: 15),
                  label: const Text(
                    'Yapıştır',
                    style: TextStyle(fontSize: 11.5, fontWeight: FontWeight.w700),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: _isYoutubePlaylistDetected
                    ? const Color(0xFF00C853).withValues(alpha: 0.14)
                    : subSurfaceBg,
                borderRadius: BorderRadius.circular(8),
                border: Border.all(
                  color: _isYoutubePlaylistDetected
                      ? const Color(0xFF00C853).withValues(alpha: 0.45)
                      : subtleBorder,
                ),
              ),
              child: Text(
                _isYoutubePlaylistDetected
                    ? '✓ YouTube Oynatma Listesi (Playlist) algılandı — TV\'de doğrudan liste açılacak'
                    : (normalizedUrl.isNotEmpty
                        ? '✓ Doğrudan içerik bağlantısı aktif'
                        : '⚡ TV\'de uygulama/arama ile doğrudan başlatılacak'),
                style: TextStyle(
                  color: _isYoutubePlaylistDetected
                      ? (isDarkMode
                          ? const Color(0xFF00E676)
                          : const Color(0xFF008E3B))
                      : secondaryText,
                  fontSize: 11,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
            const SizedBox(height: 12),

            Text(
              'İzleme Periyodu & Günler',
              style: TextStyle(
                color: goldText,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              children: WatchRecurrence.values.map((r) {
                final selected = r == _selectedRecurrence;
                return ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(r.label),
                  selected: selected,
                  backgroundColor: chipBg,
                  selectedColor: chipSelectedBg,
                  checkmarkColor: goldText,
                  side: BorderSide(
                    color: selected ? const Color(0xFFE2A84B) : subtleBorder,
                  ),
                  labelStyle: TextStyle(
                    color: selected ? primaryText : secondaryText,
                    fontWeight: FontWeight.w700,
                    fontSize: 11,
                  ),
                  onSelected: (_) {
                    setState(() {
                      _selectedRecurrence = r;
                      _selectedWeekdays = List<int>.from(r.defaultDays);
                    });
                  },
                );
              }).toList(),
            ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 5,
              runSpacing: 5,
              children: List<Widget>.generate(7, (index) {
                final dayNum = index + 1;
                final dayLabel = WatchCueItem.weekdayShortLabels[index];
                final isDayActive = _selectedWeekdays.contains(dayNum);
                return InkWell(
                  borderRadius: BorderRadius.circular(8),
                  onTap: () {
                    setState(() {
                      if (isDayActive && _selectedWeekdays.length > 1) {
                        _selectedWeekdays.remove(dayNum);
                      } else if (!isDayActive) {
                        _selectedWeekdays.add(dayNum);
                      }
                      _selectedRecurrence = WatchRecurrence.customDays;
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: isDayActive ? chipSelectedBg : subSurfaceBg,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: isDayActive
                            ? const Color(0xFFE2A84B)
                            : subtleBorder,
                      ),
                    ),
                    child: Text(
                      dayLabel,
                      style: TextStyle(
                        color: isDayActive ? goldText : secondaryText,
                        fontWeight: FontWeight.w700,
                        fontSize: 11,
                      ),
                    ),
                  ),
                );
              }),
            ),
            const SizedBox(height: 12),

            Text(
              'Planlanan Saat',
              style: TextStyle(
                color: goldText,
                fontWeight: FontWeight.w800,
                fontSize: 11.5,
              ),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    foregroundColor: goldText,
                    side: const BorderSide(color: Color(0xFFE2A84B)),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                  ),
                  onPressed: _pickClockTime,
                  icon: const Icon(Icons.access_time_filled_rounded, size: 16),
                  label: Text(
                    '⏰ $_formattedSelectedClock',
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 12,
                    ),
                  ),
                ),
                for (final preset in _quickClockPresets)
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    backgroundColor: _formattedSelectedClock == preset
                        ? chipSelectedBg
                        : subSurfaceBg,
                    side: BorderSide(
                      color: _formattedSelectedClock == preset
                          ? const Color(0xFFE2A84B)
                          : subtleBorder,
                    ),
                    label: Text(
                      preset,
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () {
                      final parts = preset.split(':');
                      setState(() {
                        _selectedHour = int.parse(parts[0]);
                        _selectedMinute = int.parse(parts[1]);
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  'Seans Hızlı Seçim:',
                  style: TextStyle(color: secondaryText, fontSize: 11.5),
                ),
                for (final mins in _sessionDurationPresets)
                  ActionChip(
                    visualDensity: VisualDensity.compact,
                    backgroundColor:
                        _sessionDurationController.text.trim() == '$mins'
                            ? chipSelectedBg
                            : subSurfaceBg,
                    side: BorderSide(
                      color: _sessionDurationController.text.trim() == '$mins'
                          ? const Color(0xFFE2A84B)
                          : subtleBorder,
                    ),
                    label: Text(
                      '$mins dk',
                      style: TextStyle(
                        color: primaryText,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () {
                      setState(() {
                        _sessionDurationController.text = '$mins';
                      });
                    },
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _sessionDurationController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: primaryText, fontSize: 12.5),
                    decoration: InputDecoration(
                      labelText: 'Seans Süresi (Dk)',
                      labelStyle: TextStyle(color: secondaryText),
                      filled: !isDarkMode,
                      fillColor: Colors.white,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _durationController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: primaryText, fontSize: 12.5),
                    decoration: InputDecoration(
                      labelText: 'Toplam Süre (Dk)',
                      labelStyle: TextStyle(color: secondaryText),
                      filled: !isDarkMode,
                      fillColor: Colors.white,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            Row(
              children: <Widget>[
                Expanded(
                  child: TextField(
                    controller: _currentEpisodeController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: primaryText, fontSize: 12.5),
                    decoration: InputDecoration(
                      labelText: 'Kaçıncı $unit',
                      labelStyle: TextStyle(color: secondaryText),
                      filled: !isDarkMode,
                      fillColor: Colors.white,
                      isDense: true,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: TextField(
                    controller: _totalEpisodesController,
                    keyboardType: TextInputType.number,
                    style: TextStyle(color: primaryText, fontSize: 12.5),
                    decoration: InputDecoration(
                      labelText: 'Toplam $unit Sayısı',
                      labelStyle: TextStyle(color: secondaryText),
                      filled: !isDarkMode,
                      fillColor: Colors.white,
                      isDense: true,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _subtitleController,
              style: TextStyle(color: primaryText, fontSize: 12.5),
              decoration: InputDecoration(
                labelText: 'Bölüm / Liste Notu',
                labelStyle: TextStyle(color: secondaryText),
                filled: !isDarkMode,
                fillColor: Colors.white,
                isDense: true,
              ),
            ),
            const SizedBox(height: 12),

            Wrap(
              spacing: 6,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: <Widget>[
                Text(
                  'Hatırlatıcı:',
                  style: TextStyle(color: secondaryText, fontSize: 11.5),
                ),
                for (final rem in _reminderLeadPresets)
                  ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text('$rem dk önce'),
                    selected: _selectedReminderMinutes == rem,
                    backgroundColor: chipBg,
                    selectedColor: chipSelectedBg,
                    checkmarkColor: goldText,
                    side: BorderSide(
                      color: _selectedReminderMinutes == rem
                          ? const Color(0xFFE2A84B)
                          : subtleBorder,
                    ),
                    labelStyle: TextStyle(
                      color: _selectedReminderMinutes == rem
                          ? primaryText
                          : secondaryText,
                      fontSize: 11,
                      fontWeight: FontWeight.w600,
                    ),
                    onSelected: (_) {
                      setState(() => _selectedReminderMinutes = rem);
                    },
                  ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFE2A84B),
                  foregroundColor: const Color(0xFF090A0F),
                  padding: const EdgeInsets.symmetric(vertical: 12),
                ),
                onPressed: _saveCue,
                icon: Icon(
                  isEditing ? Icons.save_rounded : Icons.add_task_rounded,
                  size: 18,
                ),
                label: Text(
                  isEditing ? 'Değişiklikleri Kaydet' : 'Plana Ekle',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _pasteFromClipboard() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final pasted = data?.text?.trim() ?? '';
    if (pasted.isEmpty || !mounted) return;
    setState(() {
      _urlController.text = pasted;
    });
  }

  Future<void> _pickClockTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: _selectedHour, minute: _selectedMinute),
    );
    if (picked == null || !mounted) return;
    setState(() {
      _selectedHour = picked.hour;
      _selectedMinute = picked.minute;
    });
  }

  void _saveCue() {
    final existing = widget.existingItem;
    final notifier = ref.read(cueDeckProvider.notifier);
    if (existing == null && !notifier.canAddMoreWatchPlans) {
      Navigator.of(context).pop();
      notifier.triggerPaywallPrompt();
      return;
    }
    final title = _titleController.text.trim().isEmpty
        ? '${_selectedPlatform.label} İzleme Planı'
        : _titleController.text.trim();
    final totalMins =
        (int.tryParse(_durationController.text.trim()) ?? 60).clamp(5, 1200);
    final sessionMins =
        (int.tryParse(_sessionDurationController.text.trim()) ?? 45)
            .clamp(5, totalMins);
    final totalEps =
        (int.tryParse(_totalEpisodesController.text.trim()) ?? 1).clamp(1, 500);
    final currentEp =
        (int.tryParse(_currentEpisodeController.text.trim()) ?? 1)
            .clamp(1, totalEps);
    final normalizedLink = WatchCueItem.normalizeContentLink(
      _selectedPlatform,
      _urlController.text,
    );

    final now = DateTime.now();
    final scheduledDateTime = DateTime(
      now.year,
      now.month,
      now.day,
      _selectedHour,
      _selectedMinute,
    );

    final item = WatchCueItem(
      id: existing?.id ?? 'cue_${now.millisecondsSinceEpoch}',
      title: title,
      subtitle: _subtitleController.text.trim(),
      platform: _selectedPlatform,
      scheduledTime: scheduledDateTime,
      totalMinutes: totalMins,
      watchedMinutes: existing != null
          ? existing.watchedMinutes.clamp(0, totalMins)
          : 0,
      sessionMinutes: sessionMins,
      currentEpisode: currentEp,
      totalEpisodes: totalEps,
      deepLinkUrl: normalizedLink,
      recurrence: _selectedRecurrence,
      activeWeekdays: List<int>.from(_selectedWeekdays)..sort(),
      reminderMinutesBefore: _selectedReminderMinutes,
    );

    if (existing != null) {
      notifier.updateWatchCue(item);
    } else {
      notifier.addWatchCue(item);
    }
    Navigator.of(context).pop();
  }
}
