import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/pdks_models.dart';
import '../../domain/pdks_print_builders.dart';
import '../providers/pdks_providers.dart';
import '../widgets/employee_profile_avatar.dart';
import '../widgets/hasibu_theme_palette.dart';
import 'employee_history_dossier_dialog.dart';
import 'hasibu_print_preview_dialog.dart';
import 'live_attendance_punch_dialog.dart';
import 'pdks_operational_dialogs.dart';

/// Canlı Yoklama ve Günlük PDKS izleme ekranı.
class LiveAttendanceDashboardView extends ConsumerStatefulWidget {
  final VoidCallback? onOpenHrCompliance;

  const LiveAttendanceDashboardView({
    super.key,
    this.onOpenHrCompliance,
  });

  @override
  ConsumerState<LiveAttendanceDashboardView> createState() =>
      _LiveAttendanceDashboardViewState();
}

class _LiveAttendanceDashboardViewState
    extends ConsumerState<LiveAttendanceDashboardView> {
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    final initialQuery = ref.read(pdksDashboardProvider).searchQuery;
    _searchController = TextEditingController(text: initialQuery);
    _searchController.addListener(_onSearchControllerChanged);
  }

  void _onSearchControllerChanged() {
    if (!mounted) return;
    final notifier = ref.read(pdksDashboardProvider.notifier);
    final current = ref.read(pdksDashboardProvider).searchQuery;
    final text = _searchController.text;
    final normalized = text.trim().isEmpty ? '' : text;
    if (current != normalized) {
      notifier.setSearchQuery(text);
    }
  }

  @override
  void dispose() {
    _searchController.removeListener(_onSearchControllerChanged);
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _openLiveAttendancePrintDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final s = ref.read(pdksDashboardProvider);
    final branchName = s.effectiveSelectedBranchId == null
        ? 'Tüm Yetkili Şubeler'
        : (s.branches
                .where((b) => b.id == s.effectiveSelectedBranchId)
                .map((b) => b.name)
                .firstOrNull ??
            'Şube #${s.effectiveSelectedBranchId}');
    final parts = <String>[
      branchName,
      if (s.selectedStateFilter != null) s.selectedStateFilter!.label,
      if (s.selectedAnomalyFilter != PdksAnomalyFilter.all)
        s.selectedAnomalyFilter.label,
      if (s.searchQuery.trim().isNotEmpty) 'Arama: "${s.searchQuery.trim()}"',
    ];
    final doc = HasibuPrintBuilders.buildLiveAttendanceListDocument(
      companySettings: s.companySettings,
      selectedDateKey: s.selectedDate,
      filterDescription: parts.join(' • '),
      items: s.visibleStatuses,
      totalCount: s.totalCount,
      presentCount: s.presentCount,
      lateCount: s.lateCount,
      absentCount: s.absentCount,
      onLeaveCount: s.onLeaveCount,
      sickReportCount: s.sickReportCount,
    );
    await showHasibuPrintPreviewDialog(context, ref, document: doc);
  }

  @override
  Widget build(BuildContext context) {
    ref.listen<String>(
      pdksDashboardProvider.select((s) => s.searchQuery),
      (prev, next) {
        if (_searchController.text != next) {
          _searchController.value = TextEditingValue(
            text: next,
            selection: TextSelection.collapsed(offset: next.length),
          );
        }
      },
    );

    final selectedDate =
        ref.watch(pdksDashboardProvider.select((s) => s.selectedDate));
    final activeSearchQuery =
        ref.watch(pdksDashboardProvider.select((s) => s.searchQuery));
    final pendingReqCount = ref.watch(
      pdksDashboardProvider.select((s) => s.pendingHrRequestsCount),
    );
    final criticalAlertsCount = ref.watch(
      pdksDashboardProvider.select((s) => s.criticalProactiveAlertsCount),
    );
    final totalAlertsCount = ref.watch(
      pdksDashboardProvider.select((s) => s.proactiveAlerts.length),
    );
    final pal = HasibuPalette.of(context);
    final screenWidth = MediaQuery.sizeOf(context).width;
    final isMobile = screenWidth < 700;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isMobile ? 12 : 20,
              isMobile ? 12 : 16,
              isMobile ? 12 : 20,
              8,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (criticalAlertsCount > 0) ...[
                  Material(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.11),
                    borderRadius: BorderRadius.circular(10),
                    child: InkWell(
                      key: const ValueKey('live_pdks_proactive_alert_banner'),
                      borderRadius: BorderRadius.circular(10),
                      onTap: widget.onOpenHrCompliance,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 9,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: const Color(0xFFDC2626)
                                .withValues(alpha: 0.45),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.notification_important_rounded,
                              color: Color(0xFFDC2626),
                              size: 18,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                '$criticalAlertsCount kritik İK & 4857 uyum uyarısı aktif '
                                '(Toplam $totalAlertsCount ihbar). İncelemek için dokunun.',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: Color(0xFFB91C1C),
                                ),
                              ),
                            ),
                            const Icon(
                              Icons.chevron_right_rounded,
                              color: Color(0xFFDC2626),
                              size: 18,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 10),
                ],
                // 1. ÖZET KPI KARTLARI (En üstte ferah ve net görünüm)
                const _KpiSummaryCards(),
                const SizedBox(height: 10),

                // 2. MODERN EXCEL RIBBON FİLTRE & ARAMA ŞERİDİ (Kompakt 2 satırlı şerit)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: pal.card,
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: pal.border),
                  ),
                  child: LayoutBuilder(
                    builder: (context, toolbarConstraints) {
                      final useSingleDesktopRow =
                          !isMobile && toolbarConstraints.maxWidth >= 1220;

                      final searchField = TextField(
                        key: const ValueKey('live_pdks_search_field'),
                        controller: _searchController,
                        onChanged: (val) => ref
                            .read(pdksDashboardProvider.notifier)
                            .setSearchQuery(val),
                        decoration: InputDecoration(
                          hintText:
                              'Personel adı, sicil/kart no veya bölüm ara...',
                          prefixIcon:
                              const Icon(Icons.search_rounded, size: 18),
                          suffixIcon: activeSearchQuery.isNotEmpty
                              ? IconButton(
                                  key: const ValueKey(
                                    'live_pdks_clear_search_button',
                                  ),
                                  tooltip: 'Aramayı Temizle',
                                  icon: const Icon(
                                    Icons.clear_rounded,
                                    size: 18,
                                  ),
                                  onPressed: () {
                                    _searchController.clear();
                                    ref
                                        .read(
                                          pdksDashboardProvider.notifier,
                                        )
                                        .clearSearchQuery();
                                  },
                                )
                              : null,
                          contentPadding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 8,
                          ),
                          fillColor: pal.subtle,
                        ),
                      );

                      final desktopActionButtons = <Widget>[
                        FilledButton.icon(
                          key: const ValueKey('live_pdks_add_punch_button'),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () async {
                            final saved = await showLiveAttendancePunchDialog(
                              context,
                              ref,
                            );
                            if (saved == true && context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    'Personel giriş/çıkış hareketi kaydedildi.',
                                  ),
                                ),
                              );
                            }
                          },
                          icon: const Icon(Icons.add_alarm_rounded, size: 15),
                          label: const Text(
                            'Hareket Ekle',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          key: const ValueKey('open_hr_requests_modal_button'),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                            foregroundColor: pendingReqCount > 0
                                ? const Color(0xFFD97706)
                                : null,
                          ),
                          onPressed: widget.onOpenHrCompliance,
                          icon: const Icon(
                            Icons.fact_check_outlined,
                            size: 15,
                          ),
                          label: Text(
                            pendingReqCount > 0
                                ? 'İK Talepleri ($pendingReqCount)'
                                : 'İK Talepleri',
                            style: const TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        OutlinedButton.icon(
                          key: const ValueKey('export_puantaj_csv_button'),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () =>
                              showPuantajCsvExportDialog(context, ref),
                          icon: const Icon(Icons.table_view_rounded, size: 15),
                          label: const Text(
                            'Excel / CSV',
                            style: TextStyle(fontSize: 11.5),
                          ),
                        ),
                        OutlinedButton.icon(
                          key: const ValueKey('live_pdks_print_list_button'),
                          style: OutlinedButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () =>
                              _openLiveAttendancePrintDialog(context, ref),
                          icon: const Icon(Icons.print_outlined, size: 15),
                          label: const Text(
                            'Yazdır',
                            style: TextStyle(fontSize: 11.5),
                          ),
                        ),
                        FilledButton.tonalIcon(
                          key: const ValueKey('ribbon_terminal_pull_button'),
                          style: FilledButton.styleFrom(
                            visualDensity: VisualDensity.compact,
                          ),
                          onPressed: () =>
                              pullTerminalAndShowPopup(context, ref),
                          icon: const Icon(Icons.sync_rounded, size: 15),
                          label: const Text(
                            'Terminalden Veri Çek',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                      ];

                      return Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Expanded(child: searchField),
                              if (isMobile) ...[
                                const SizedBox(width: 6),
                                IconButton.filledTonal(
                                  key: const ValueKey(
                                    'live_pdks_mobile_add_punch_button',
                                  ),
                                  style: IconButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  tooltip: 'Giriş / Çıkış Hareketi Ekle',
                                  onPressed: () async {
                                    final saved =
                                        await showLiveAttendancePunchDialog(
                                      context,
                                      ref,
                                    );
                                    if (saved == true && context.mounted) {
                                      ScaffoldMessenger.of(context)
                                          .showSnackBar(
                                        const SnackBar(
                                          content: Text(
                                            'Personel giriş/çıkış hareketi kaydedildi.',
                                          ),
                                        ),
                                      );
                                    }
                                  },
                                  icon: const Icon(
                                    Icons.add_alarm_rounded,
                                    size: 18,
                                  ),
                                ),
                                const SizedBox(width: 4),
                                IconButton.outlined(
                                  key: const ValueKey(
                                    'live_pdks_mobile_print_button',
                                  ),
                                  style: IconButton.styleFrom(
                                    visualDensity: VisualDensity.compact,
                                    tapTargetSize:
                                        MaterialTapTargetSize.shrinkWrap,
                                  ),
                                  tooltip: 'Yoklama Listesini Yazdır',
                                  onPressed: () =>
                                      _openLiveAttendancePrintDialog(
                                    context,
                                    ref,
                                  ),
                                  icon: const Icon(
                                    Icons.print_outlined,
                                    size: 18,
                                  ),
                                ),
                              ],
                              if (useSingleDesktopRow) ...[
                                const SizedBox(width: 10),
                                for (var i = 0;
                                    i < desktopActionButtons.length;
                                    i++) ...[
                                  if (i > 0) const SizedBox(width: 6),
                                  desktopActionButtons[i],
                                ],
                              ],
                            ],
                          ),
                          if (!isMobile && !useSingleDesktopRow) ...[
                            const SizedBox(height: 6),
                            Wrap(
                              spacing: 6,
                              runSpacing: 6,
                              children: desktopActionButtons,
                            ),
                          ],
                          const SizedBox(height: 6),
                          // TEK SATIRDA BİRLEŞTİRİLMİŞ EXCEL ŞERİDİ (Takvim Tarih Seçici | Şube | Durum Filtresi)
                          SingleChildScrollView(
                            scrollDirection: Axis.horizontal,
                            child: Row(
                              children: [
                                ActionChip(
                                  key: const ValueKey(
                                    'calendar_date_picker_button',
                                  ),
                                  visualDensity: VisualDensity.compact,
                                  avatar: const Icon(
                                    Icons.calendar_month_rounded,
                                    size: 15,
                                    color: Color(0xFF0284C7),
                                  ),
                                  label: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      Text(
                                        PdksDashboardNotifier.formatDisplayDate(
                                          selectedDate,
                                        ),
                                        style: const TextStyle(
                                          fontSize: 11.5,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.arrow_drop_down_rounded,
                                        size: 16,
                                      ),
                                    ],
                                  ),
                                  tooltip: 'Takvimden Tarih Seçmek İçin Dokunun',
                                  onPressed: () =>
                                      pickPdksDateWithCalendar(context, ref),
                                ),
                                if (selectedDate !=
                                    PdksDashboardNotifier.todayDateKey()) ...[
                                  const SizedBox(width: 4),
                                  ActionChip(
                                    key:
                                        const ValueKey('jump_to_today_button'),
                                    visualDensity: VisualDensity.compact,
                                    avatar: const Icon(
                                      Icons.today_rounded,
                                      size: 14,
                                      color: Color(0xFF10B981),
                                    ),
                                    label: const Text(
                                      'Bugüne Dön',
                                      style: TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                    onPressed: () => ref
                                        .read(pdksDashboardProvider.notifier)
                                        .setSelectedDate(
                                          PdksDashboardNotifier.todayDateKey(),
                                        ),
                                  ),
                                ],
                                Container(
                                  width: 1,
                                  height: 22,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 6),
                                  color: pal.border,
                                ),
                                const _BranchSelectorChips(),
                                Container(
                                  width: 1,
                                  height: 22,
                                  margin:
                                      const EdgeInsets.symmetric(horizontal: 6),
                                  color: pal.border,
                                ),
                                const _PdksAnomalyFilterRibbon(),
                                if (activeSearchQuery.trim().isNotEmpty) ...[
                                  const SizedBox(width: 8),
                                  InputChip(
                                    key: const ValueKey(
                                      'live_pdks_active_search_chip',
                                    ),
                                    visualDensity: VisualDensity.compact,
                                    avatar: const Icon(
                                      Icons.search_rounded,
                                      size: 14,
                                      color: Color(0xFF0284C7),
                                    ),
                                    label: Text(
                                      'Arama: "${activeSearchQuery.trim()}"',
                                      style: const TextStyle(
                                        fontSize: 11,
                                        fontWeight: FontWeight.w700,
                                      ),
                                    ),
                                    deleteIcon: const Tooltip(
                                      message: 'Aramayı Kaldır',
                                      child: Icon(Icons.close_rounded, size: 15),
                                    ),
                                    onDeleted: () {
                                      _searchController.clear();
                                      ref
                                          .read(pdksDashboardProvider.notifier)
                                          .clearSearchQuery();
                                    },
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
        ),
        const _EmployeeDailyStatusSliverList(),
      ],
    );
  }
}

class _BranchSelectorChips extends ConsumerWidget {
  const _BranchSelectorChips();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final branches = ref.watch(pdksDashboardProvider.select((s) => s.branches));
    final isBranchScoped =
        ref.watch(pdksDashboardProvider.select((s) => s.isBranchScoped));
    final isSingleBranchScoped = ref.watch(
      pdksDashboardProvider.select((s) => s.isSingleBranchScoped),
    );
    final selectedBranchId = ref.watch(
      pdksDashboardProvider.select((s) => s.effectiveSelectedBranchId),
    );

    if (isSingleBranchScoped) {
      final scopedMatch = branches.where((b) => b.id == selectedBranchId);
      final label = scopedMatch.isNotEmpty
          ? scopedMatch.first.name
          : 'Yetkili Şube #$selectedBranchId';
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              key: const ValueKey('locked_branch_scope_chip'),
              visualDensity: VisualDensity.compact,
              avatar: const Icon(Icons.lock_outline_rounded, size: 14),
              label: Text(label, style: const TextStyle(fontSize: 11.5)),
              selected: true,
              onSelected: null,
            ),
          ],
        ),
      );
    }

    if (isBranchScoped) {
      return SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            ChoiceChip(
              key: const ValueKey('scoped_all_my_branches_chip'),
              visualDensity: VisualDensity.compact,
              avatar: const Icon(Icons.lock_outline_rounded, size: 14),
              label: Text(
                'Yetkili Şubelerim (${branches.length})',
                style: const TextStyle(fontSize: 11.5),
              ),
              selected: selectedBranchId == null,
              onSelected: (_) => ref
                  .read(pdksDashboardProvider.notifier)
                  .setBranchFilter(null),
            ),
            const SizedBox(width: 6),
            for (final b in branches) ...[
              ChoiceChip(
                visualDensity: VisualDensity.compact,
                avatar: Icon(
                  b.hasTerminal
                      ? Icons.face_retouching_natural
                      : Icons.storefront,
                  size: 14,
                ),
                label: Text(b.name, style: const TextStyle(fontSize: 11.5)),
                selected: selectedBranchId == b.id,
                onSelected: (_) => ref
                    .read(pdksDashboardProvider.notifier)
                    .setBranchFilter(b.id),
              ),
              const SizedBox(width: 6),
            ],
          ],
        ),
      );
    }

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          ChoiceChip(
            visualDensity: VisualDensity.compact,
            label: const Text(
              'Tüm Şubeler & Merkez',
              style: TextStyle(fontSize: 11.5),
            ),
            selected: selectedBranchId == null,
            onSelected: (_) => ref
                .read(pdksDashboardProvider.notifier)
                .setBranchFilter(null),
          ),
          const SizedBox(width: 6),
          for (final b in branches) ...[
            ChoiceChip(
              visualDensity: VisualDensity.compact,
              avatar: Icon(
                b.hasTerminal
                    ? Icons.face_retouching_natural
                    : Icons.storefront,
                size: 14,
              ),
              label: Text(b.name, style: const TextStyle(fontSize: 11.5)),
              selected: selectedBranchId == b.id,
              onSelected: (_) => ref
                  .read(pdksDashboardProvider.notifier)
                  .setBranchFilter(b.id),
            ),
            const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }
}

class _KpiSummaryCards extends ConsumerWidget {
  const _KpiSummaryCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(pdksDashboardProvider.select((s) => s.totalCount));
    final present =
        ref.watch(pdksDashboardProvider.select((s) => s.presentCount));
    final lateCount =
        ref.watch(pdksDashboardProvider.select((s) => s.lateCount));
    final absent =
        ref.watch(pdksDashboardProvider.select((s) => s.absentCount));
    final onLeave =
        ref.watch(pdksDashboardProvider.select((s) => s.onLeaveCount));
    final sick =
        ref.watch(pdksDashboardProvider.select((s) => s.sickReportCount));
    final activeFilter =
        ref.watch(pdksDashboardProvider.select((s) => s.selectedStateFilter));
    final pal = HasibuPalette.of(context);

    return LayoutBuilder(
      builder: (context, constraints) {
        final double cardWidth;
        if (constraints.maxWidth >= 980) {
          cardWidth = (constraints.maxWidth - 50) / 6;
        } else {
          cardWidth = (constraints.maxWidth - 20) / 3;
        }

        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            _StatFilterCard(
              title: 'Toplam Kadro',
              count: total,
              color: pal.isDark
                  ? const Color(0xFF38BDF8)
                  : const Color(0xFF0F172A),
              icon: Icons.groups_rounded,
              isSelected: activeFilter == null,
              width: cardWidth,
              onTap: () =>
                  ref.read(pdksDashboardProvider.notifier).setStateFilter(null),
            ),
            _StatFilterCard(
              title: 'Giriş Yapan',
              count: present,
              color: const Color(0xFF059669),
              icon: Icons.check_circle_rounded,
              isSelected: activeFilter == DailyAttendanceState.present,
              width: cardWidth,
              onTap: () => ref
                  .read(pdksDashboardProvider.notifier)
                  .setStateFilter(DailyAttendanceState.present),
            ),
            _StatFilterCard(
              title: 'Geç Gelen',
              count: lateCount,
              color: const Color(0xFFD97706),
              icon: Icons.schedule_rounded,
              isSelected: activeFilter == DailyAttendanceState.late,
              width: cardWidth,
              onTap: () => ref
                  .read(pdksDashboardProvider.notifier)
                  .setStateFilter(DailyAttendanceState.late),
            ),
            _StatFilterCard(
              title: 'Devamsız',
              count: absent,
              color: const Color(0xFFDC2626),
              icon: Icons.person_off_rounded,
              isSelected: activeFilter == DailyAttendanceState.absent,
              width: cardWidth,
              onTap: () => ref
                  .read(pdksDashboardProvider.notifier)
                  .setStateFilter(DailyAttendanceState.absent),
            ),
            _StatFilterCard(
              title: 'İzinli',
              count: onLeave,
              color: const Color(0xFF0284C7),
              icon: Icons.beach_access_rounded,
              isSelected: activeFilter == DailyAttendanceState.onLeave,
              width: cardWidth,
              onTap: () => ref
                  .read(pdksDashboardProvider.notifier)
                  .setStateFilter(DailyAttendanceState.onLeave),
            ),
            _StatFilterCard(
              title: 'Raporlu',
              count: sick,
              color: const Color(0xFF7C3AED),
              icon: Icons.medical_services_rounded,
              isSelected: activeFilter == DailyAttendanceState.sickReport,
              width: cardWidth,
              onTap: () => ref
                  .read(pdksDashboardProvider.notifier)
                  .setStateFilter(DailyAttendanceState.sickReport),
            ),
          ],
        );
      },
    );
  }
}

class _StatFilterCard extends StatelessWidget {
  final String title;
  final int count;
  final Color color;
  final IconData icon;
  final bool isSelected;
  final double width;
  final VoidCallback onTap;

  const _StatFilterCard({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
    required this.isSelected,
    this.width = 152.0,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    final isCompactCard = width < 135;
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: width,
        padding: EdgeInsets.symmetric(
          horizontal: isCompactCard ? 9 : 12,
          vertical: isCompactCard ? 8 : 9,
        ),
        decoration: BoxDecoration(
          color: isSelected ? color.withValues(alpha: 0.12) : pal.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? color : pal.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: EdgeInsets.all(isCompactCard ? 5 : 6),
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(7),
              ),
              child: Icon(icon, color: color, size: isCompactCard ? 15 : 17),
            ),
            SizedBox(width: isCompactCard ? 7 : 9),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '$count',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isCompactCard ? 15 : 17,
                      fontWeight: FontWeight.w800,
                      color: color,
                    ),
                  ),
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: isCompactCard ? 10.5 : 11,
                      fontWeight: FontWeight.w600,
                      color: pal.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PdksAnomalyFilterRibbon extends ConsumerWidget {
  const _PdksAnomalyFilterRibbon();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final activeAnomaly = ref.watch(
      pdksDashboardProvider.select((s) => s.selectedAnomalyFilter),
    );
    final missingOutCount = ref.watch(
      pdksDashboardProvider.select((s) => s.missingCheckOutCount),
    );
    final overtimeCount = ref.watch(
      pdksDashboardProvider.select((s) => s.overtimeStaffCount),
    );
    final totalOvertimeMins = ref.watch(
      pdksDashboardProvider.select((s) => s.totalOvertimeMinutes),
    );
    final earlyLeaveCount = ref.watch(
      pdksDashboardProvider.select((s) => s.earlyLeaveCount),
    );
    final missingDocsCount = ref.watch(
      pdksDashboardProvider.select((s) => s.missingDocsStaffCount),
    );
    final terminatedCount = ref.watch(
      pdksDashboardProvider.select((s) => s.terminatedCount),
    );
    final selectedStateFilter = ref.watch(
      pdksDashboardProvider.select((s) => s.selectedStateFilter),
    );
    final pal = HasibuPalette.of(context);

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Icon(
            Icons.radar_rounded,
            size: 15,
            color: pal.textSecondary,
          ),
          const SizedBox(width: 5),
          Text(
            'Filtre:',
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w700,
              color: pal.textSecondary,
            ),
          ),
          const SizedBox(width: 6),
          ChoiceChip(
            key: const ValueKey('anomaly_filter_all'),
            visualDensity: VisualDensity.compact,
            label: const Text(
              'Tüm Kadro',
              style: TextStyle(fontSize: 11.5),
            ),
            selected: activeAnomaly == PdksAnomalyFilter.all,
            onSelected: (_) => ref
                .read(pdksDashboardProvider.notifier)
                .setAnomalyFilter(PdksAnomalyFilter.all),
          ),
          const SizedBox(width: 6),
          ChoiceChip(
            key: const ValueKey('anomaly_filter_missing_out'),
            visualDensity: VisualDensity.compact,
            avatar: const Icon(
              Icons.warning_amber_rounded,
              size: 14,
              color: Color(0xFFD97706),
            ),
            label: Text(
              'Eksik Çıkış ($missingOutCount)',
              style: const TextStyle(fontSize: 11.5),
            ),
            selected: activeAnomaly == PdksAnomalyFilter.missingCheckOut,
            onSelected: (_) => ref
                .read(pdksDashboardProvider.notifier)
                .setAnomalyFilter(PdksAnomalyFilter.missingCheckOut),
          ),
          const SizedBox(width: 6),
          ChoiceChip(
            key: const ValueKey('anomaly_filter_overtime'),
            visualDensity: VisualDensity.compact,
            avatar: const Icon(
              Icons.more_time_rounded,
              size: 14,
              color: Color(0xFF059669),
            ),
            label: Text(
              'Fazla Mesai ($overtimeCount • +$totalOvertimeMins dk)',
              style: const TextStyle(fontSize: 11.5),
            ),
            selected: activeAnomaly == PdksAnomalyFilter.overtime,
            onSelected: (_) => ref
                .read(pdksDashboardProvider.notifier)
                .setAnomalyFilter(PdksAnomalyFilter.overtime),
          ),
          const SizedBox(width: 6),
          ChoiceChip(
            key: const ValueKey('anomaly_filter_early_leave'),
            visualDensity: VisualDensity.compact,
            avatar: const Icon(
              Icons.directions_run_rounded,
              size: 14,
              color: Color(0xFFDC2626),
            ),
            label: Text(
              'Erken Çıkış ($earlyLeaveCount)',
              style: const TextStyle(fontSize: 11.5),
            ),
            selected: activeAnomaly == PdksAnomalyFilter.earlyLeave,
            onSelected: (_) => ref
                .read(pdksDashboardProvider.notifier)
                .setAnomalyFilter(PdksAnomalyFilter.earlyLeave),
          ),
          const SizedBox(width: 6),
          ChoiceChip(
            key: const ValueKey('anomaly_filter_missing_docs'),
            visualDensity: VisualDensity.compact,
            avatar: const Icon(
              Icons.folder_off_outlined,
              size: 14,
              color: Color(0xFF7C3AED),
            ),
            label: Text(
              'Eksik Evrak ($missingDocsCount)',
              style: const TextStyle(fontSize: 11.5),
            ),
            selected: activeAnomaly == PdksAnomalyFilter.missingDocs,
            onSelected: (_) => ref
                .read(pdksDashboardProvider.notifier)
                .setAnomalyFilter(PdksAnomalyFilter.missingDocs),
          ),
          if (terminatedCount > 0) ...[
            const SizedBox(width: 6),
            ChoiceChip(
              key: const ValueKey('anomaly_filter_terminated'),
              visualDensity: VisualDensity.compact,
              avatar: const Icon(
                Icons.person_off_outlined,
                size: 14,
                color: Color(0xFF64748B),
              ),
              label: Text(
                'İşten Ayrılan ($terminatedCount)',
                style: const TextStyle(fontSize: 11.5),
              ),
              selected: selectedStateFilter == DailyAttendanceState.terminated,
              onSelected: (selected) => ref
                  .read(pdksDashboardProvider.notifier)
                  .setStateFilter(
                    selected ? DailyAttendanceState.terminated : null,
                  ),
            ),
          ],
          if (missingOutCount > 0) ...[
            const SizedBox(width: 8),
            FilledButton.tonalIcon(
              key: const ValueKey('batch_complete_missing_out_button'),
              style: FilledButton.styleFrom(
                visualDensity: VisualDensity.compact,
              ),
              onPressed: () async {
                final count = await ref
                    .read(pdksDashboardProvider.notifier)
                    .batchCompleteAllMissingCheckOuts();
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        '$count personelin eksik çıkış hareketi vardiya bitiş saatine göre tamamlandı.',
                      ),
                    ),
                  );
                }
              },
              icon: const Icon(Icons.auto_fix_high_rounded, size: 14),
              label: Text(
                'Eksik Çıkışları Tamamla ($missingOutCount)',
                style: const TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _EmployeeDailyStatusSliverList extends ConsumerWidget {
  const _EmployeeDailyStatusSliverList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items =
        ref.watch(pdksDashboardProvider.select((s) => s.visibleStatuses));
    final hasActiveFilters = ref.watch(
      pdksDashboardProvider.select(
        (s) =>
            s.searchQuery.trim().isNotEmpty ||
            s.selectedStateFilter != null ||
            s.selectedAnomalyFilter != PdksAnomalyFilter.all,
      ),
    );
    final isMobile = MediaQuery.sizeOf(context).width < 700;

    if (items.isEmpty) {
      return SliverToBoxAdapter(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Seçili filtreye uygun personel kaydı bulunamadı.'),
                if (hasActiveFilters) ...[
                  const SizedBox(height: 10),
                  OutlinedButton.icon(
                    key: const ValueKey('live_pdks_reset_empty_filters_button'),
                    onPressed: () => ref
                        .read(pdksDashboardProvider.notifier)
                        .clearAllAttendanceFilters(),
                    icon: const Icon(Icons.filter_alt_off_rounded, size: 16),
                    label: const Text('Arama ve Filtreleri Temizle'),
                  ),
                ],
              ],
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: EdgeInsets.fromLTRB(
        isMobile ? 12 : 20,
        4,
        isMobile ? 12 : 20,
        24,
      ),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (context, index) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          return _EmployeeStatusRowCard(
            key: ValueKey('employee_status_row_${item.employee.id}'),
            item: item,
          );
        },
      ),
    );
  }
}

/// Sadeleştirilmiş Personel Kartı
/// Kart üzerinde yalnızca Avatar, Tam Ad Soyad, Bölüm/Giriş Saati ve Durum Rozeti yer alır.
/// Kart numaraları, vardiya saatleri, özlük evrakları ve hızlı aksiyonlar karta dokunulduğunda açılan pencerede gösterilir.
class _EmployeeStatusRowCard extends ConsumerWidget {
  final EmployeeDailyStatus item;

  const _EmployeeStatusRowCard({super.key, required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = HasibuPalette.of(context);
    final Color badgeColor = attendanceStateColor(item.state);

    final String shortTimeText;
    if (item.firstCheckIn != null) {
      final outPart = item.lastCheckOut != null &&
              item.lastCheckOut!.id != item.firstCheckIn!.id
          ? ' - ${item.lastCheckOut!.timeFormatted}'
          : '';
      shortTimeText = '${item.firstCheckIn!.timeFormatted}$outPart';
    } else if (item.state == DailyAttendanceState.terminated) {
      shortTimeText = item.employee.hasExitDate
          ? 'Çıkış: ${PdksDashboardNotifier.formatDisplayDate(item.employee.normalizedExitDate!, includeTodayBadge: false)}'
          : 'İşten Ayrıldı';
    } else if (item.state == DailyAttendanceState.notYetHired) {
      shortTimeText =
          'Giriş: ${PdksDashboardNotifier.formatDisplayDate(item.employee.hireDate, includeTodayBadge: false)}';
    } else if (item.publicHoliday != null) {
      shortTimeText = 'Resmi Tatil: ${item.publicHoliday!.name}';
    } else if (item.state == DailyAttendanceState.weeklyOff) {
      shortTimeText = 'Hafta Tatili';
    } else {
      shortTimeText = item.leaveRecord?.leaveType.label ?? 'Giriş Yok';
    }

    return Material(
      color: pal.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: ValueKey('employee_card_${item.employee.cardNo}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => showEmployeeHistoryAndDossierDialog(
          context,
          ref,
          item.employee,
          initialTabIndex: 0,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: pal.border),
          ),
          child: Row(
            children: [
              EmployeeProfileAvatar(
                employee: item.employee,
                size: 40,
                borderColor: badgeColor.withValues(alpha: 0.45),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      item.employee.fullName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        color: pal.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${item.department.name} • $shortTimeText',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 11.5,
                        color: pal.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxWidth: MediaQuery.sizeOf(context).width < 460 ? 150 : 260,
                ),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 9,
                    vertical: 4,
                  ),
                  decoration: BoxDecoration(
                    color: badgeColor.withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Text(
                    item.lateMinutes > 0
                        ? '${item.state.label} (+${item.lateMinutes} dk)'
                        : item.state.label,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: badgeColor,
                      fontWeight: FontWeight.w700,
                      fontSize: 11,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 4),
              IconButton(
                key: ValueKey('employee_quick_punch_${item.employee.cardNo}'),
                tooltip: 'Giriş / Çıkış Hareketi Ekle',
                style: IconButton.styleFrom(
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  minimumSize: const Size(30, 30),
                  padding: const EdgeInsets.all(4),
                ),
                icon: Icon(
                  Icons.more_time_rounded,
                  size: 18,
                  color: pal.textSecondary,
                ),
                onPressed: () => showLiveAttendancePunchDialog(
                  context,
                  ref,
                  initialEmployee: item.employee,
                ),
              ),
              Icon(
                Icons.chevron_right_rounded,
                size: 18,
                color: pal.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
