import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/pdks_models.dart';
import '../providers/pdks_providers.dart';
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
    final anchor =
        DateTime.tryParse(ref.read(pdksDashboardProvider).selectedDate) ??
            DateTime.now();
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

    final csvContent = ref
        .read(pdksDashboardProvider.notifier)
        .generatePeriodAttendanceReportCsv(
          startDateKey: startKey,
          endDateKey: endKey,
          branchId: _branchId,
          departmentId: _departmentId,
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
              branchId: _branchId,
              departmentId: _departmentId,
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
                // 1. ÜST KONTROL VE FİLTRE KARTI
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
                                'Seçili Dönem: $rangeDisplay • Yüz okutma, geç kalma, izin ve devamsızlık icmali',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: pal.textSecondary,
                                ),
                              ),
                            ],
                          ),
                          FilledButton.icon(
                            key: const ValueKey(
                              'report_export_period_csv_button',
                            ),
                            onPressed: () => _showPeriodCsvExportDialog(
                              startKey: startKey,
                              endKey: endKey,
                            ),
                            icon: const Icon(Icons.table_view_rounded, size: 17),
                            label: const Text('Excel / CSV Rapor İndir'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Wrap(
                        spacing: 8,
                        runSpacing: 8,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          for (final preset in AttendanceReportPreset.values)
                            ChoiceChip(
                              key: ValueKey('report_preset_${preset.name}'),
                              visualDensity: VisualDensity.compact,
                              label: Text(
                                preset.label,
                                style: const TextStyle(fontSize: 12),
                              ),
                              selected: _preset == preset,
                              onSelected: (_) => _applyPreset(preset),
                            ),
                          OutlinedButton.icon(
                            key: const ValueKey('report_pick_date_range_button'),
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
                              fillColor: pal.subtle,
                            ),
                          );
                          final branchDropdown = DropdownButtonFormField<int?>(
                            isExpanded: true,
                            initialValue: _branchId,
                            decoration: const InputDecoration(
                              labelText: 'Şube',
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('Tüm Şubeler'),
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
                            isExpanded: true,
                            initialValue: _departmentId,
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
                        spacing: 8,
                        runSpacing: 6,
                        children: [
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
                const SizedBox(height: 12),
                // 2. 6'LI ÖZET KPI KARTLARI
                LayoutBuilder(
                  builder: (ctx, constraints) {
                    final double w;
                    if (constraints.maxWidth >= 980) {
                      w = (constraints.maxWidth - 40) / 6;
                    } else if (constraints.maxWidth >= 560) {
                      w = (constraints.maxWidth - 16) / 3;
                    } else {
                      w = (constraints.maxWidth - 8) / 2;
                    }
                    return Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        _ReportKpiCard(
                          width: w,
                          title: 'Personel',
                          value: '$totalStaff',
                          icon: Icons.groups_rounded,
                          color: pal.isDark
                              ? const Color(0xFF38BDF8)
                              : const Color(0xFF0F172A),
                        ),
                        _ReportKpiCard(
                          width: w,
                          title: 'Toplam Devam (Gün)',
                          value: '$totalPresentDays',
                          icon: Icons.check_circle_rounded,
                          color: const Color(0xFF059669),
                        ),
                        _ReportKpiCard(
                          width: w,
                          title: 'Devamsızlık (Gün)',
                          value: '$totalAbsentDays',
                          icon: Icons.person_off_rounded,
                          color: const Color(0xFFDC2626),
                        ),
                        _ReportKpiCard(
                          width: w,
                          title: 'Geç Kalma (Gün / Dk)',
                          value: '$totalLateDays / $totalLateMinutes',
                          icon: Icons.schedule_rounded,
                          color: const Color(0xFFD97706),
                        ),
                        _ReportKpiCard(
                          width: w,
                          title: 'İzinli / Raporlu',
                          value: '$totalLeaveAndSickDays',
                          icon: Icons.beach_access_rounded,
                          color: const Color(0xFF0284C7),
                        ),
                        _ReportKpiCard(
                          width: w,
                          title: 'Eksik Çıkış',
                          value: '$totalMissingOutDays',
                          icon: Icons.warning_amber_rounded,
                          color: const Color(0xFFEA580C),
                        ),
                      ],
                    );
                  },
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
              itemBuilder: (ctx, idx) => _PeriodSummaryCard(item: rows[idx]),
            ),
          ),
      ],
    );
  }
}

class _ReportKpiCard extends StatelessWidget {
  final double width;
  final String title;
  final String value;
  final IconData icon;
  final Color color;

  const _ReportKpiCard({
    required this.width,
    required this.title,
    required this.value,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    return Container(
      width: width,
      padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 9),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: pal.border),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.13),
              borderRadius: BorderRadius.circular(7),
            ),
            child: Icon(icon, size: 16, color: color),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
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
                Text(
                  title,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 10.5,
                    fontWeight: FontWeight.w600,
                    color: pal.textSecondary,
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

class _PeriodSummaryCard extends ConsumerWidget {
  final EmployeeAttendancePeriodSummary item;

  const _PeriodSummaryCard({required this.item});

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

    final visibleAbsentDates = item.absentDateKeys.take(6).toList(growable: false);
    final hiddenAbsentCount = item.absentDateKeys.length - visibleAbsentDates.length;

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
          padding: const EdgeInsets.all(13),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: pal.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  EmployeeProfileAvatar(
                    employee: item.employee,
                    size: 40,
                    borderColor: rateColor.withValues(alpha: 0.45),
                  ),
                  const SizedBox(width: 12),
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
                        const SizedBox(height: 2),
                        Text(
                          '#${item.employee.cardNo} • ${item.department.name} • ${item.branch.name}',
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
                      color: rateColor.withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '%$ratePercent Devam',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w800,
                        color: rateColor,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  _MetricBadge(
                    label: 'Devam: ${item.presentDays}g',
                    color: const Color(0xFF059669),
                  ),
                  _MetricBadge(
                    label: 'Devamsız: ${item.absentDays}g',
                    color: item.absentDays > 0
                        ? const Color(0xFFDC2626)
                        : pal.textSecondary,
                  ),
                  _MetricBadge(
                    label: item.lateDays > 0
                        ? 'Geç: ${item.lateDays}g (+${item.totalLateMinutes} dk)'
                        : 'Geç: 0',
                    color: item.lateDays > 0
                        ? const Color(0xFFD97706)
                        : pal.textSecondary,
                  ),
                  if (item.onLeaveDays > 0)
                    _MetricBadge(
                      label: 'İzin: ${item.onLeaveDays}g',
                      color: const Color(0xFF0284C7),
                    ),
                  if (item.sickReportDays > 0)
                    _MetricBadge(
                      label: 'Rapor: ${item.sickReportDays}g',
                      color: const Color(0xFF7C3AED),
                    ),
                  if (item.missingCheckOutDays > 0)
                    _MetricBadge(
                      label: 'Eksik Çıkış: ${item.missingCheckOutDays}g',
                      color: const Color(0xFFEA580C),
                    ),
                  _MetricBadge(
                    label: 'Net: $workedHours sa',
                    color: const Color(0xFF0F766E),
                  ),
                ],
              ),
              if (visibleAbsentDates.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const Text(
                      'Devamsız Günler:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFFDC2626),
                      ),
                    ),
                    for (final dateKey in visibleAbsentDates)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFDC2626).withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(5),
                          border: Border.all(
                            color: const Color(0xFFDC2626)
                                .withValues(alpha: 0.35),
                          ),
                        ),
                        child: Text(
                          PdksDashboardNotifier.formatDisplayDate(
                            dateKey,
                            includeTodayBadge: false,
                          ),
                          style: const TextStyle(
                            fontSize: 10.5,
                            fontWeight: FontWeight.w700,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    if (hiddenAbsentCount > 0)
                      Text(
                        '+$hiddenAbsentCount gün',
                        style: const TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class _MetricBadge extends StatelessWidget {
  final String label;
  final Color color;

  const _MetricBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.11),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
