import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/pdks_models.dart';
import '../../domain/pdks_print_builders.dart';
import '../providers/pdks_providers.dart';
import 'hasibu_print_preview_dialog.dart';
import 'hasibu_settings_view.dart';

/// Çok Günlü Personel Devam / Devamsızlık, Geç Kalma ve İzin Analiz Raporu Ekranı.
class AttendanceAbsenceReportView extends ConsumerStatefulWidget {
  const AttendanceAbsenceReportView({super.key});

  @override
  ConsumerState<AttendanceAbsenceReportView> createState() =>
      _AttendanceAbsenceReportViewState();
}

class _AttendanceAbsenceReportViewState
    extends ConsumerState<AttendanceAbsenceReportView> {
  AttendanceReportPreset _preset = AttendanceReportPreset.last7Days;
  late DateTime _startDate;
  late DateTime _endDate;
  int? _branchId;
  int? _departmentId;
  bool _onlyWithAbsences = false;
  bool _onlyWithLates = false;
  bool _excludeSundays = true;
  late final TextEditingController _searchCtrl;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
    final initialState = ref.read(pdksDashboardProvider);
    _branchId = initialState.effectiveBranchScopeId;
    final anchor = DateTime.tryParse(initialState.selectedDate) ?? DateTime.now();
    final endDay = DateTime(anchor.year, anchor.month, anchor.day);
    _endDate = endDay;
    _startDate = endDay.subtract(const Duration(days: 6));
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  DateTime _anchorDay() {
    final parsed =
        DateTime.tryParse(ref.read(pdksDashboardProvider).selectedDate) ??
            DateTime.now();
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  void _applyPreset(AttendanceReportPreset preset) {
    if (preset == AttendanceReportPreset.custom) {
      _pickDateRange();
      return;
    }
    final endDay = _anchorDay();
    final DateTime startDay;
    switch (preset) {
      case AttendanceReportPreset.today:
        startDay = endDay;
      case AttendanceReportPreset.last7Days:
        startDay = endDay.subtract(const Duration(days: 6));
      case AttendanceReportPreset.thisMonth:
        startDay = DateTime(endDay.year, endDay.month, 1);
      case AttendanceReportPreset.custom:
        startDay = _startDate;
    }
    setState(() {
      _preset = preset;
      _startDate = startDay;
      _endDate = endDay;
    });
  }

  Future<void> _pickDateRange() async {
    final picked = await showDateRangePicker(
      context: context,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2035, 12, 31),
      initialDateRange: DateTimeRange(start: _startDate, end: _endDate),
      locale: const Locale('tr', 'TR'),
      helpText: 'Rapor Tarih Aralığını Seçin',
      cancelText: 'İptal',
      confirmText: 'Uygula',
      saveText: 'Uygula',
    );
    if (picked == null || !mounted) return;
    setState(() {
      _preset = AttendanceReportPreset.custom;
      _startDate = DateTime(
        picked.start.year,
        picked.start.month,
        picked.start.day,
      );
      _endDate = DateTime(
        picked.end.year,
        picked.end.month,
        picked.end.day,
      );
    });
  }

  Future<void> _showPeriodCsvExportDialog({
    required String startKey,
    required String endKey,
  }) async {
    final state = ref.read(pdksDashboardProvider);
    if (state.isCommercialWriteLocked) {
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Row(
            children: [
              Icon(Icons.lock_clock_rounded, color: Color(0xFFDC2626)),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Salt-Okunur (Read-Only) Abonelik Kilidi',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
                ),
              ),
            ],
          ),
          content: Text(
            '${state.licenseStatusMessage}\n\n'
            'Devam / Devamsızlık raporu Excel/CSV dışa aktarımı aktif lisans gerektirir.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(),
              child: const Text('Kapat'),
            ),
          ],
        ),
      );
      return;
    }

    final scopedBranchIds = state.effectiveBranchScopeIds;
    final effectiveBranchId = scopedBranchIds.length == 1
        ? scopedBranchIds.first
        : (_branchId != null &&
                (scopedBranchIds.isEmpty ||
                    scopedBranchIds.contains(_branchId))
            ? _branchId
            : null);
    final effectiveDepartmentId =
        state.departments.any((d) => d.id == _departmentId)
            ? _departmentId
            : null;
    final csvContent = ref
        .read(pdksDashboardProvider.notifier)
        .generatePeriodAttendanceReportCsv(
          startDateKey: startKey,
          endDateKey: endKey,
          branchId: effectiveBranchId,
          departmentId: effectiveDepartmentId,
          searchQuery: _searchCtrl.text,
          onlyWithAbsences: _onlyWithAbsences,
          onlyWithLates: _onlyWithLates,
          excludeSundays: _excludeSundays,
        );
    final filePathCtrl = TextEditingController(
      text: 'Hasibu_Devam_Raporu_${startKey}_$endKey.csv',
    );
    String? exportFeedback;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final pal = HasibuPalette.of(ctx);
          return AlertDialog(
            title: Row(
              children: [
                const Icon(
                  Icons.table_view_rounded,
                  color: Color(0xFF059669),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Devam / Devamsızlık Raporu CSV ($startKey → $endKey)',
                    style: const TextStyle(
                      fontSize: 15.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: 680,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Excel ile doğrudan uyumlu (; ayraçlı, UTF-8 BOM destekli) dönemlik devam/devamsızlık raporu.',
                    style: TextStyle(fontSize: 12, color: pal.textSecondary),
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    key: const ValueKey('report_export_path_field'),
                    controller: filePathCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Kaydedilecek Dosya Adı / Yolu (.csv)',
                      prefixIcon: Icon(Icons.save_alt_rounded, size: 18),
                    ),
                  ),
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    height: 240,
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: pal.subtle,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: pal.border),
                    ),
                    child: SingleChildScrollView(
                      child: SelectableText(
                        csvContent,
                        style: TextStyle(
                          fontFamily: 'Consolas',
                          fontSize: 11.5,
                          color: pal.textPrimary,
                        ),
                      ),
                    ),
                  ),
                  if (exportFeedback != null) ...[
                    const SizedBox(height: 10),
                    Text(
                      exportFeedback!,
                      style: const TextStyle(
                        color: Color(0xFF059669),
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Kapat'),
              ),
              OutlinedButton.icon(
                key: const ValueKey('report_copy_csv_button'),
                onPressed: () async {
                  await Clipboard.setData(ClipboardData(text: csvContent));
                  if (dialogCtx.mounted) {
                    setDialogState(() {
                      exportFeedback =
                          'Devam / Devamsızlık raporu panoya kopyalandı.';
                    });
                  }
                },
                icon: const Icon(Icons.copy_all_rounded, size: 16),
                label: const Text('Panoya Kopyala'),
              ),
              FilledButton.icon(
                key: const ValueKey('report_save_csv_file_button'),
                onPressed: () async {
                  try {
                    final targetPath = filePathCtrl.text.trim().isEmpty
                        ? 'Hasibu_Devam_Raporu_${startKey}_$endKey.csv'
                        : filePathCtrl.text.trim();
                    final f = File(targetPath);
                    await f.writeAsString('\uFEFF$csvContent');
                    if (dialogCtx.mounted) {
                      setDialogState(() {
                        exportFeedback =
                            'Excel uyumlu CSV dosyası kaydedildi: ${f.path}';
                      });
                    }
                  } catch (_) {
                    if (dialogCtx.mounted) {
                      setDialogState(() {
                        exportFeedback =
                            'Panoya kopyalama hazır (Dosya yazma izni kısıtlı).';
                      });
                    }
                  }
                },
                icon: const Icon(Icons.download_done_rounded, size: 16),
                label: const Text('CSV Olarak Kaydet'),
              ),
            ],
          );
        },
      ),
    );

    filePathCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Panel verileri güncellendiğinde raporun otomatik tazelenmesi için izle
    ref.watch(pdksDashboardProvider.select((s) => s.dailyStatuses));
    ref.watch(pdksDashboardProvider.select((s) => s.allLeaveRecords));
    final branches = ref.watch(pdksDashboardProvider.select((s) => s.branches));
    final departments =
        ref.watch(pdksDashboardProvider.select((s) => s.departments));
    final scopedBranchIds = ref.watch(
      pdksDashboardProvider.select((s) => s.effectiveBranchScopeIds),
    );
    final isSingleScoped = scopedBranchIds.length == 1;
    final isMultiScoped = scopedBranchIds.length > 1;
    final effectiveBranchId = isSingleScoped
        ? scopedBranchIds.first
        : (_branchId != null &&
                (scopedBranchIds.isEmpty ||
                    scopedBranchIds.contains(_branchId))
            ? _branchId
            : null);
    final effectiveDepartmentId =
        departments.any((d) => d.id == _departmentId) ? _departmentId : null;
    final pal = HasibuPalette.of(context);
    final isMobile = MediaQuery.sizeOf(context).width < 700;

    final startKey = PdksDashboardNotifier.formatDateKey(_startDate);
    final endKey = PdksDashboardNotifier.formatDateKey(_endDate);
    final rangeDisplay =
        '${PdksDashboardNotifier.formatDisplayDate(startKey, includeTodayBadge: false)} – ${PdksDashboardNotifier.formatDisplayDate(endKey, includeTodayBadge: false)}';

    final rows =
        ref.read(pdksDashboardProvider.notifier).buildAttendancePeriodReport(
              startDateKey: startKey,
              endDateKey: endKey,
              branchId: effectiveBranchId,
              departmentId: effectiveDepartmentId,
              searchQuery: _searchCtrl.text,
              onlyWithAbsences: _onlyWithAbsences,
              onlyWithLates: _onlyWithLates,
              excludeSundays: _excludeSundays,
            );

    final totalStaff = rows.length;
    final totalPresentDays = rows.fold<int>(0, (s, r) => s + r.presentDays);
    final totalAbsentDays = rows.fold<int>(0, (s, r) => s + r.absentDays);
    final totalLateDays = rows.fold<int>(0, (s, r) => s + r.lateDays);
    final totalLateMinutes =
        rows.fold<int>(0, (s, r) => s + r.totalLateMinutes);
    final totalLeaveAndSickDays =
        rows.fold<int>(0, (s, r) => s + r.onLeaveDays + r.sickReportDays);
    final totalMissingOutDays =
        rows.fold<int>(0, (s, r) => s + r.missingCheckOutDays);
    final showBranchInCards = branches.length > 1 && effectiveBranchId == null;

    return CustomScrollView(
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: EdgeInsets.fromLTRB(
              isMobile ? 12 : 20,
              isMobile ? 12 : 16,
              isMobile ? 12 : 20,
              10,
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // 1. SADE ÜST BAŞLIK, DÖNEM VE FİLTRE KARTI
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: pal.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: pal.border),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 10,
                        runSpacing: 8,
                        alignment: WrapAlignment.spaceBetween,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Çok Günlü Devam / Devamsızlık Raporu',
                                style: TextStyle(
                                  fontSize: 15.5,
                                  fontWeight: FontWeight.w800,
                                  color: pal.textPrimary,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                'Dönem: $rangeDisplay',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: pal.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          Wrap(
                            spacing: 8,
                            runSpacing: 6,
                            children: [
                              OutlinedButton.icon(
                                key: const ValueKey(
                                  'report_pick_date_range_button',
                                ),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: _pickDateRange,
                                icon: const Icon(
                                  Icons.date_range_rounded,
                                  size: 16,
                                ),
                                label: Text(
                                  rangeDisplay,
                                  style: const TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                              ),
                              FilledButton.icon(
                                key: const ValueKey(
                                  'report_export_period_csv_button',
                                ),
                                style: FilledButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () => _showPeriodCsvExportDialog(
                                  startKey: startKey,
                                  endKey: endKey,
                                ),
                                icon: const Icon(
                                  Icons.table_view_rounded,
                                  size: 16,
                                ),
                                label: const Text('Excel / CSV'),
                              ),
                              OutlinedButton.icon(
                                key: const ValueKey('report_print_button'),
                                style: OutlinedButton.styleFrom(
                                  visualDensity: VisualDensity.compact,
                                ),
                                onPressed: () {
                                  final branchName = effectiveBranchId == null
                                      ? 'Tüm Yetkili Şubeler'
                                      : (branches
                                              .where((b) =>
                                                  b.id == effectiveBranchId)
                                              .map((b) => b.name)
                                              .firstOrNull ??
                                          'Şube #$effectiveBranchId');
                                  final deptName = effectiveDepartmentId == null
                                      ? 'Tüm Bölümler'
                                      : (departments
                                              .where((d) =>
                                                  d.id == effectiveDepartmentId)
                                              .map((d) => d.name)
                                              .firstOrNull ??
                                          'Bölüm #$effectiveDepartmentId');
                                  final filterParts = <String>[
                                    branchName,
                                    deptName,
                                    if (_onlyWithAbsences) 'Sadece Devamsızlar',
                                    if (_onlyWithLates) 'Sadece Geç Kalanlar',
                                    if (_excludeSundays) 'Pazar Hariç',
                                    if (_searchCtrl.text.trim().isNotEmpty)
                                      'Arama: "${_searchCtrl.text.trim()}"',
                                  ];
                                  final doc = HasibuPrintBuilders
                                      .buildAttendancePeriodReportDocument(
                                    companySettings: ref
                                        .read(pdksDashboardProvider)
                                        .companySettings,
                                    startDateKey: startKey,
                                    endDateKey: endKey,
                                    filterDescription: filterParts.join(' • '),
                                    rows: rows,
                                  );
                                  showHasibuPrintPreviewDialog(
                                    context,
                                    ref,
                                    document: doc,
                                  );
                                },
                                icon: const Icon(
                                  Icons.print_outlined,
                                  size: 16,
                                ),
                                label: const Text('Yazdır'),
                              ),
                            ],
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      LayoutBuilder(
                        builder: (ctx, constraints) {
                          final wideFilters = constraints.maxWidth >= 760;
                          final searchBox = TextField(
                            key: const ValueKey('report_search_field'),
                            controller: _searchCtrl,
                            onChanged: (_) => setState(() {}),
                            decoration: InputDecoration(
                              hintText:
                                  'Personel adı, kart no veya bölüm ara...',
                              prefixIcon: const Icon(
                                Icons.search_rounded,
                                size: 18,
                              ),
                              suffixIcon: _searchCtrl.text.isNotEmpty
                                  ? IconButton(
                                      key: const ValueKey(
                                        'report_clear_search_button',
                                      ),
                                      tooltip: 'Aramayı Temizle',
                                      icon: const Icon(
                                        Icons.clear_rounded,
                                        size: 18,
                                      ),
                                      onPressed: () {
                                        _searchCtrl.clear();
                                        setState(() {});
                                      },
                                    )
                                  : null,
                              fillColor: pal.subtle,
                            ),
                          );
                          final branchDropdown = isSingleScoped
                              ? DropdownButtonFormField<int?>(
                                  key: ValueKey(
                                    'report_branch_locked_${scopedBranchIds.first}',
                                  ),
                                  isExpanded: true,
                                  initialValue: scopedBranchIds.first,
                                  decoration: const InputDecoration(
                                    labelText: 'Şube',
                                  ),
                                  items: [
                                    if (branches.any(
                                      (b) => b.id == scopedBranchIds.first,
                                    ))
                                      for (final b in branches.where(
                                        (b) => b.id == scopedBranchIds.first,
                                      ))
                                        DropdownMenuItem<int?>(
                                          value: b.id,
                                          child: Text(
                                            b.name,
                                            overflow: TextOverflow.ellipsis,
                                          ),
                                        )
                                    else
                                      DropdownMenuItem<int?>(
                                        value: scopedBranchIds.first,
                                        child: Text(
                                          'Şube #${scopedBranchIds.first}',
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: null,
                                )
                              : DropdownButtonFormField<int?>(
                                  key: ValueKey(
                                    'report_branch_${scopedBranchIds.join("_")}_$effectiveBranchId',
                                  ),
                                  isExpanded: true,
                                  initialValue: branches
                                          .any((b) => b.id == effectiveBranchId)
                                      ? effectiveBranchId
                                      : null,
                                  decoration: const InputDecoration(
                                    labelText: 'Şube',
                                  ),
                                  items: [
                                    DropdownMenuItem<int?>(
                                      value: null,
                                      child: Text(
                                        isMultiScoped
                                            ? 'Yetkili Şubelerim (${branches.length})'
                                            : 'Tüm Şubeler',
                                      ),
                                    ),
                                    for (final b in branches)
                                      DropdownMenuItem<int?>(
                                        value: b.id,
                                        child: Text(
                                          b.name,
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                  ],
                                  onChanged: (val) =>
                                      setState(() => _branchId = val),
                                );
                          final deptDropdown = DropdownButtonFormField<int?>(
                            key: ValueKey(
                              'report_dept_${scopedBranchIds.join("_")}_$effectiveDepartmentId',
                            ),
                            isExpanded: true,
                            initialValue: effectiveDepartmentId,
                            decoration: const InputDecoration(
                              labelText: 'Bölüm / Departman',
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('Tüm Bölümler'),
                              ),
                              for (final d in departments)
                                DropdownMenuItem<int?>(
                                  value: d.id,
                                  child: Text(
                                    d.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (val) =>
                                setState(() => _departmentId = val),
                          );

                          if (wideFilters) {
                            return Row(
                              children: [
                                Expanded(flex: 3, child: searchBox),
                                const SizedBox(width: 10),
                                Expanded(flex: 2, child: branchDropdown),
                                const SizedBox(width: 10),
                                Expanded(flex: 2, child: deptDropdown),
                              ],
                            );
                          }
                          return Column(
                            children: [
                              searchBox,
                              const SizedBox(height: 8),
                              Row(
                                children: [
                                  Expanded(child: branchDropdown),
                                  const SizedBox(width: 8),
                                  Expanded(child: deptDropdown),
                                ],
                              ),
                            ],
                          );
                        },
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final preset in AttendanceReportPreset.values)
                            ChoiceChip(
                              key: ValueKey('report_preset_${preset.name}'),
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                preset.label,
                                style: const TextStyle(fontSize: 11.5),
                              ),
                              selected: _preset == preset,
                              onSelected: (_) => _applyPreset(preset),
                            ),
                          FilterChip(
                            key: const ValueKey('report_filter_only_absent'),
                            visualDensity: VisualDensity.compact,
                            label: const Text(
                              'Sadece Devamsızlar',
                              style: TextStyle(fontSize: 11.5),
                            ),
                            selected: _onlyWithAbsences,
                            onSelected: (v) =>
                                setState(() => _onlyWithAbsences = v),
                          ),
                          FilterChip(
                            key: const ValueKey('report_filter_only_late'),
                            visualDensity: VisualDensity.compact,
                            label: const Text(
                              'Sadece Geç Kalanlar',
                              style: TextStyle(fontSize: 11.5),
                            ),
                            selected: _onlyWithLates,
                            onSelected: (v) =>
                                setState(() => _onlyWithLates = v),
                          ),
                          FilterChip(
                            key: const ValueKey(
                              'report_filter_exclude_sundays',
                            ),
                            visualDensity: VisualDensity.compact,
                            label: const Text(
                              'Pazar Hariç',
                              style: TextStyle(fontSize: 11.5),
                            ),
                            selected: _excludeSundays,
                            onSelected: (v) =>
                                setState(() => _excludeSundays = v),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                // 2. SADE 4'LÜ ÖZET ŞERİDİ
                _CompactReportSummaryStrip(
                  totalStaff: totalStaff,
                  totalPresentDays: totalPresentDays,
                  totalAbsentDays: totalAbsentDays,
                  totalLateDays: totalLateDays,
                  totalLateMinutes: totalLateMinutes,
                  totalLeaveAndSickDays: totalLeaveAndSickDays,
                  totalMissingOutDays: totalMissingOutDays,
                ),
              ],
            ),
          ),
        ),
        if (rows.isEmpty)
          const SliverToBoxAdapter(
            child: Padding(
              padding: EdgeInsets.all(32),
              child: Center(
                child: Text('Seçili kriterlere uygun rapor kaydı bulunamadı.'),
              ),
            ),
          )
        else
          SliverPadding(
            padding: EdgeInsets.fromLTRB(
              isMobile ? 12 : 20,
              0,
              isMobile ? 12 : 20,
              24,
            ),
            sliver: SliverList.separated(
              itemCount: rows.length,
              separatorBuilder: (context, index) => const SizedBox(height: 8),
              itemBuilder: (ctx, idx) => _PeriodSummaryCard(
                item: rows[idx],
                showBranchName: showBranchInCards,
              ),
            ),
          ),
      ],
    );
  }
}

class _CompactReportSummaryStrip extends StatelessWidget {
  final int totalStaff;
  final int totalPresentDays;
  final int totalAbsentDays;
  final int totalLateDays;
  final int totalLateMinutes;
  final int totalLeaveAndSickDays;
  final int totalMissingOutDays;

  const _CompactReportSummaryStrip({
    required this.totalStaff,
    required this.totalPresentDays,
    required this.totalAbsentDays,
    required this.totalLateDays,
    required this.totalLateMinutes,
    required this.totalLeaveAndSickDays,
    required this.totalMissingOutDays,
  });

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    final lateText = totalLateDays > 0
        ? '$totalLateDays gün • $totalLateMinutes dk'
        : '0 gün';
    final items = <({String label, String value, Color color})>[
      (
        label: 'Personel',
        value: '$totalStaff',
        color: pal.textPrimary,
      ),
      (
        label: 'Toplam Devam (Gün)',
        value: '$totalPresentDays',
        color: const Color(0xFF059669),
      ),
      (
        label: 'Devamsızlık (Gün)',
        value: '$totalAbsentDays',
        color: totalAbsentDays > 0
            ? const Color(0xFFDC2626)
            : pal.textSecondary,
      ),
      (
        label: 'Geç Kalma',
        value: lateText,
        color: totalLateDays > 0
            ? const Color(0xFFD97706)
            : pal.textSecondary,
      ),
    ];

    final hasExtras = totalLeaveAndSickDays > 0 || totalMissingOutDays > 0;
    final extraParts = <String>[
      if (totalLeaveAndSickDays > 0) 'İzin / Rapor: ${totalLeaveAndSickDays}g',
      if (totalMissingOutDays > 0) 'Eksik Çıkış: ${totalMissingOutDays}g',
    ];

    return Container(
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              if (constraints.maxWidth >= 640) {
                return IntrinsicHeight(
                  child: Row(
                    children: [
                      for (int i = 0; i < items.length; i++) ...[
                        if (i > 0)
                          VerticalDivider(width: 1, color: pal.border),
                        Expanded(
                          child: _SummaryStripCell(
                            label: items[i].label,
                            value: items[i].value,
                            color: items[i].color,
                          ),
                        ),
                      ],
                    ],
                  ),
                );
              }

              return Column(
                children: [
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: _SummaryStripCell(
                            label: items[0].label,
                            value: items[0].value,
                            color: items[0].color,
                          ),
                        ),
                        VerticalDivider(width: 1, color: pal.border),
                        Expanded(
                          child: _SummaryStripCell(
                            label: items[1].label,
                            value: items[1].value,
                            color: items[1].color,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Divider(height: 1, color: pal.border),
                  IntrinsicHeight(
                    child: Row(
                      children: [
                        Expanded(
                          child: _SummaryStripCell(
                            label: items[2].label,
                            value: items[2].value,
                            color: items[2].color,
                          ),
                        ),
                        VerticalDivider(width: 1, color: pal.border),
                        Expanded(
                          child: _SummaryStripCell(
                            label: items[3].label,
                            value: items[3].value,
                            color: items[3].color,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
          if (hasExtras) ...[
            Divider(height: 1, color: pal.border),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
              child: Text(
                extraParts.join('  •  '),
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w600,
                  color: pal.textSecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _SummaryStripCell extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _SummaryStripCell({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 15.5,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: pal.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _PeriodSummaryCard extends ConsumerWidget {
  final EmployeeAttendancePeriodSummary item;
  final bool showBranchName;

  const _PeriodSummaryCard({
    required this.item,
    required this.showBranchName,
  });

  static String _shortDayMonth(String dateKey) {
    final parts = dateKey.split('-');
    if (parts.length == 3) {
      return '${parts[2].padLeft(2, '0')}.${parts[1].padLeft(2, '0')}';
    }
    return dateKey;
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = HasibuPalette.of(context);
    final workedHours = (item.totalWorkedMinutes / 60.0).toStringAsFixed(1);
    final ratePercent = item.attendanceRatePercent.toStringAsFixed(0);
    final Color rateColor = item.absentDays > 0
        ? const Color(0xFFDC2626)
        : (item.lateDays > 0
            ? const Color(0xFFD97706)
            : const Color(0xFF059669));

    final subtitle = showBranchName
        ? '#${item.employee.cardNo} • ${item.department.name} • ${item.branch.name}'
        : '#${item.employee.cardNo} • ${item.department.name}';

    final visibleAbsentDates =
        item.absentDateKeys.take(4).map(_shortDayMonth).toList(growable: false);
    final hiddenAbsentCount =
        item.absentDateKeys.length - visibleAbsentDates.length;

    final extraParts = <String>[
      if (item.onLeaveDays > 0) 'İzin: ${item.onLeaveDays}g',
      if (item.sickReportDays > 0) 'Rapor: ${item.sickReportDays}g',
      if (item.missingCheckOutDays > 0)
        'Eksik çıkış: ${item.missingCheckOutDays}g',
    ];

    return Material(
      color: pal.card,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        key: ValueKey('report_employee_card_${item.employee.cardNo}'),
        borderRadius: BorderRadius.circular(12),
        onTap: () => showEmployeeHistoryAndDossierDialog(
          context,
          ref,
          item.employee,
          initialTabIndex: 0,
        ),
        child: Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: pal.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Satır 1: Avatar + İsim/Bölüm + Sade Devam Oranı
              Row(
                children: [
                  EmployeeProfileAvatar(
                    employee: item.employee,
                    size: 38,
                    borderColor: rateColor.withValues(alpha: 0.40),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.employee.fullName,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: pal.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 1),
                        Text(
                          subtitle,
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
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 9,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: rateColor.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      '%$ratePercent',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w800,
                        color: rateColor,
                      ),
                    ),
                  ),
                  const SizedBox(width: 2),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 18,
                    color: pal.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 10),
              // Satır 2: Sade 4 Sütunlu Metrik Çubuğu
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: pal.subtle,
                  borderRadius: BorderRadius.circular(9),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: _CardMetricColumn(
                        label: 'Devam',
                        value: '${item.presentDays}g',
                        valueColor: item.presentDays > 0
                            ? const Color(0xFF059669)
                            : pal.textMuted,
                      ),
                    ),
                    Expanded(
                      child: _CardMetricColumn(
                        label: 'Devamsız',
                        value: '${item.absentDays}g',
                        valueColor: item.absentDays > 0
                            ? const Color(0xFFDC2626)
                            : pal.textMuted,
                      ),
                    ),
                    Expanded(
                      child: _CardMetricColumn(
                        label: 'Geç',
                        value: item.lateDays > 0
                            ? '${item.lateDays}g (${item.totalLateMinutes}d)'
                            : '—',
                        valueColor: item.lateDays > 0
                            ? const Color(0xFFD97706)
                            : pal.textMuted,
                      ),
                    ),
                    Expanded(
                      child: _CardMetricColumn(
                        label: 'Net Süre',
                        value: '$workedHours sa',
                        valueColor: pal.textPrimary,
                      ),
                    ),
                  ],
                ),
              ),
              // Satır 3: Yalnızca istisna varsa tek sakin metin satırı
              if (visibleAbsentDates.isNotEmpty) ...[
                const SizedBox(height: 7),
                Text(
                  'Devamsız günler: ${visibleAbsentDates.join(', ')}'
                  '${hiddenAbsentCount > 0 ? ' (+$hiddenAbsentCount)' : ''}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFFDC2626),
                  ),
                ),
              ],
              if (extraParts.isNotEmpty) ...[
                SizedBox(height: visibleAbsentDates.isNotEmpty ? 3 : 7),
                Text(
                  extraParts.join(' • '),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w500,
                    color: pal.textSecondary,
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _CardMetricColumn extends StatelessWidget {
  final String label;
  final String value;
  final Color valueColor;

  const _CardMetricColumn({
    required this.label,
    required this.value,
    required this.valueColor,
  });

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          label,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 10.5,
            fontWeight: FontWeight.w600,
            color: pal.textMuted,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
            fontSize: 12.5,
            fontWeight: FontWeight.w800,
            color: valueColor,
          ),
        ),
      ],
    );
  }
}
