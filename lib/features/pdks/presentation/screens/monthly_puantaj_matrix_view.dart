import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/pdks_models.dart';
import '../../domain/pdks_print_builders.dart';
import '../providers/pdks_providers.dart';
import '../widgets/employee_profile_avatar.dart';
import '../widgets/hasibu_theme_palette.dart';
import 'hasibu_print_preview_dialog.dart';

/// Aylık 31 Günlük İnteraktif Puantaj Cetveli + İmzalı Yazdırma & CSV Aktarım Ekranı.
class MonthlyPuantajMatrixView extends ConsumerStatefulWidget {
  const MonthlyPuantajMatrixView({super.key});

  @override
  ConsumerState<MonthlyPuantajMatrixView> createState() =>
      _MonthlyPuantajMatrixViewState();
}

class _MonthlyPuantajMatrixViewState
    extends ConsumerState<MonthlyPuantajMatrixView> {
  static const List<String> _monthNames = [
    'Ocak',
    'Şubat',
    'Mart',
    'Nisan',
    'Mayıs',
    'Haziran',
    'Temmuz',
    'Ağustos',
    'Eylül',
    'Ekim',
    'Kasım',
    'Aralık',
  ];

  late int _year;
  late int _month;
  int? _branchId;
  late final TextEditingController _searchCtrl;
  String _searchQuery = '';

  @override
  void initState() {
    super.initState();
    final selectedDate = ref.read(pdksDashboardProvider).selectedDate;
    final parsed = Employee.parseDateKey(selectedDate) ?? DateTime.now();
    _year = parsed.year;
    _month = parsed.month;
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  void _stepMonth(int delta) {
    final next = DateTime(_year, _month + delta, 1);
    setState(() {
      _year = next.year;
      _month = next.month;
    });
  }

  Color _cellColor(String code, DailyAttendanceState state) {
    return switch (code) {
      'FM' => const Color(0xFF047857),
      'HT' => const Color(0xFF0F766E),
      'BM' => const Color(0xFF4338CA),
      'X' => const Color(0xFF059669),
      'G' => const Color(0xFFD97706),
      'İ' => const Color(0xFF0284C7),
      'R' => const Color(0xFF7C3AED),
      'T' => const Color(0xFF2563EB),
      'B' => const Color(0xFF0D9488),
      'D' => const Color(0xFFDC2626),
      _ => attendanceStateColor(state),
    };
  }

  Future<void> _exportCsv(
    BuildContext context, {
    required int? effectiveBranchId,
  }) async {
    final notifier = ref.read(pdksDashboardProvider.notifier);
    final csv = notifier.generateMonthlyPuantajCsv(
      year: _year,
      month: _month,
      branchId: effectiveBranchId,
      searchQuery: _searchQuery,
    );
    await Clipboard.setData(ClipboardData(text: csv));
    if (!context.mounted) return;

    final fileCtrl = TextEditingController(
      text: 'hasibu_puantaj_${_year}_${_month.toString().padLeft(2, '0')}.csv',
    );
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('${_monthNames[_month - 1]} $_year Aylık Puantaj CSV'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Excel uyumlu CSV içeriği panoya kopyalandı. İsterseniz dosya yolunu düzenleyip diske kaydedebilirsiniz:',
                style: TextStyle(fontSize: 12),
              ),
              const SizedBox(height: 10),
              TextField(
                controller: fileCtrl,
                decoration: const InputDecoration(
                  labelText: 'Dosya Adı / Yolu (.csv)',
                ),
              ),
              const SizedBox(height: 10),
              Container(
                constraints: const BoxConstraints(maxHeight: 180),
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.grey.withValues(alpha: 0.35)),
                ),
                child: SingleChildScrollView(
                  child: SelectableText(
                    csv,
                    style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
                  ),
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('Kapat'),
          ),
          FilledButton.icon(
            onPressed: () async {
              final target = fileCtrl.text.trim();
              if (target.isEmpty) return;
              try {
                await File(target).writeAsString('\uFEFF$csv');
                if (dialogCtx.mounted) {
                  Navigator.of(dialogCtx).pop();
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('CSV kaydedildi: $target')),
                  );
                }
              } catch (e) {
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Dosya kaydedilemedi: $e')),
                  );
                }
              }
            },
            icon: const Icon(Icons.save_alt_rounded, size: 17),
            label: const Text('Dosyaya Kaydet'),
          ),
        ],
      ),
    );
    fileCtrl.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdksDashboardProvider);
    final notifier = ref.read(pdksDashboardProvider.notifier);
    final pal = HasibuPalette.of(context);
    final effectiveBranchId = state.effectiveBranchScopeId ?? _branchId;

    final rows = notifier.buildMonthlyPuantajMatrix(
      year: _year,
      month: _month,
      branchId: effectiveBranchId,
      searchQuery: _searchQuery,
    );
    final daysInMonth = DateUtils.getDaysInMonth(_year, _month);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            color: pal.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: pal.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 12,
                runSpacing: 10,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Aylık 31 Günlük Puantaj Cetveli & İmzalı Teslim',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: pal.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Her gün için puantaj kodu (X/G/FM/İ/R/T/B/D), aylık toplamlar, Excel CSV aktarım ve SGK/4857 uyumlu personel imzalı çıktı.',
                        style: TextStyle(
                          fontSize: 12,
                          color: pal.textSecondary,
                        ),
                      ),
                    ],
                  ),
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      IconButton.outlined(
                        key: const ValueKey('monthly_puantaj_prev_month'),
                        tooltip: 'Önceki Ay',
                        onPressed: () => _stepMonth(-1),
                        icon: const Icon(Icons.chevron_left_rounded),
                      ),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 14,
                          vertical: 8,
                        ),
                        decoration: BoxDecoration(
                          color: pal.subtle,
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(color: pal.border),
                        ),
                        child: Text(
                          '${_monthNames[_month - 1]} $_year',
                          key: const ValueKey('monthly_puantaj_period_label'),
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w800,
                            color: pal.textPrimary,
                          ),
                        ),
                      ),
                      IconButton.outlined(
                        key: const ValueKey('monthly_puantaj_next_month'),
                        tooltip: 'Sonraki Ay',
                        onPressed: () => _stepMonth(1),
                        icon: const Icon(Icons.chevron_right_rounded),
                      ),
                      FilledButton.icon(
                        key: const ValueKey('monthly_puantaj_csv_button'),
                        onPressed: state.isCommercialWriteLocked
                            ? null
                            : () => _exportCsv(
                                  context,
                                  effectiveBranchId: effectiveBranchId,
                                ),
                        icon: const Icon(Icons.table_view_rounded, size: 17),
                        label: const Text('Aylık CSV Aktar'),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 10,
                runSpacing: 8,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 280,
                    child: TextField(
                      key: const ValueKey('monthly_puantaj_search_field'),
                      controller: _searchCtrl,
                      onChanged: (val) => setState(() => _searchQuery = val),
                      decoration: InputDecoration(
                        hintText: 'Personel adı, kart no veya bölüm...',
                        prefixIcon: const Icon(Icons.search_rounded, size: 18),
                        isDense: true,
                        fillColor: pal.subtle,
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 16),
                                onPressed: () {
                                  _searchCtrl.clear();
                                  setState(() => _searchQuery = '');
                                },
                              )
                            : null,
                      ),
                    ),
                  ),
                  if (!state.isSingleBranchScoped) ...[
                    ChoiceChip(
                      label: const Text('Tüm Şubeler'),
                      selected: effectiveBranchId == null,
                      onSelected: (_) => setState(() => _branchId = null),
                    ),
                    for (final b in state.branches)
                      ChoiceChip(
                        label: Text(b.name),
                        selected: effectiveBranchId == b.id,
                        onSelected: (_) => setState(() => _branchId = b.id),
                      ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              const Wrap(
                spacing: 10,
                runSpacing: 6,
                children: [
                  _LegendPill(code: 'X', label: 'Normal', color: Color(0xFF059669)),
                  _LegendPill(code: 'FM', label: 'Fazla Mesai', color: Color(0xFF047857)),
                  _LegendPill(code: 'HT', label: 'H.Tatili Mesai', color: Color(0xFF0F766E)),
                  _LegendPill(code: 'BM', label: 'Bayram Mesai', color: Color(0xFF4338CA)),
                  _LegendPill(code: 'G', label: 'Geç', color: Color(0xFFD97706)),
                  _LegendPill(code: 'İ', label: 'İzinli', color: Color(0xFF0284C7)),
                  _LegendPill(code: 'R', label: 'Raporlu', color: Color(0xFF7C3AED)),
                  _LegendPill(code: 'T', label: 'Hafta Tatili', color: Color(0xFF2563EB)),
                  _LegendPill(code: 'B', label: 'Resmi Tatil (UBGT)', color: Color(0xFF0D9488)),
                  _LegendPill(code: 'D', label: 'Devamsız', color: Color(0xFFDC2626)),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        Container(
          decoration: BoxDecoration(
            color: pal.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: pal.border),
          ),
          child: rows.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(28),
                  child: Center(
                    child: Text(
                      'Seçili ay ve filtreye uygun personel puantaj kaydı bulunamadı.',
                      style: TextStyle(color: pal.textSecondary),
                    ),
                  ),
                )
              : SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Table(
                      defaultVerticalAlignment: TableCellVerticalAlignment.middle,
                      border: TableBorder.all(
                        color: pal.border.withValues(alpha: 0.7),
                        width: 0.7,
                      ),
                      columnWidths: {
                        0: const FixedColumnWidth(205),
                        for (var d = 1; d <= daysInMonth; d++)
                          d: const FixedColumnWidth(28),
                        daysInMonth + 1: const FixedColumnWidth(54),
                        daysInMonth + 2: const FixedColumnWidth(56),
                        daysInMonth + 3: const FixedColumnWidth(56),
                        daysInMonth + 4: const FixedColumnWidth(50),
                        daysInMonth + 5: const FixedColumnWidth(54),
                      },
                      children: [
                        TableRow(
                          decoration: BoxDecoration(color: pal.subtle),
                          children: [
                            const Padding(
                              padding: EdgeInsets.symmetric(
                                horizontal: 8,
                                vertical: 8,
                              ),
                              child: Text(
                                'Personel',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                            for (var d = 1; d <= daysInMonth; d++)
                              Center(
                                child: Text(
                                  '$d',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w700,
                                    fontSize: 10.5,
                                  ),
                                ),
                              ),
                            const _HeaderCell('Çal.'),
                            const _HeaderCell('FM(dk)'),
                            const _HeaderCell('İzn/Rp'),
                            const _HeaderCell('Dev.'),
                            const _HeaderCell('İmza'),
                          ],
                        ),
                        for (final row in rows)
                          TableRow(
                            children: [
                              Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 6,
                                ),
                                child: Row(
                                  children: [
                                    EmployeeProfileAvatar(
                                      employee: row.employee,
                                      size: 26,
                                    ),
                                    const SizedBox(width: 7),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            row.employee.fullName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w700,
                                              color: pal.textPrimary,
                                            ),
                                          ),
                                          Text(
                                            '#${row.employee.cardNo} • ${row.department.name}',
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: pal.textMuted,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              for (final cell in row.cells)
                                Tooltip(
                                  message:
                                      '${cell.dateKey}: ${cell.state.label}'
                                      '${cell.workedMinutes > 0 ? " (${cell.workedMinutes} dk)" : ""}'
                                      '${cell.overtimeMinutes > 0 ? " • FM +${cell.overtimeMinutes} dk" : ""}',
                                  child: Container(
                                    height: 30,
                                    alignment: Alignment.center,
                                    color: _cellColor(cell.code, cell.state)
                                        .withValues(alpha: 0.14),
                                    child: Text(
                                      cell.code,
                                      style: TextStyle(
                                        fontSize: 10.5,
                                        fontWeight: FontWeight.w800,
                                        color: _cellColor(cell.code, cell.state),
                                      ),
                                    ),
                                  ),
                                ),
                              _MetricCell('${row.workedDays}g'),
                              _MetricCell('+${row.totalOvertimeMinutes}'),
                              _MetricCell('${row.leaveDays + row.sickDays}g'),
                              _MetricCell(
                                '${row.absentDays}g',
                                color: row.absentDays > 0
                                    ? const Color(0xFFDC2626)
                                    : null,
                              ),
                              Center(
                                child: IconButton(
                                  key: ValueKey(
                                    'monthly_puantaj_print_${row.employee.cardNo}',
                                  ),
                                  tooltip: 'İmzalı Puantaj Fişi Yazdır',
                                  icon: const Icon(
                                    Icons.print_rounded,
                                    size: 17,
                                  ),
                                  onPressed: () {
                                    final doc = HasibuPrintBuilders
                                        .buildMonthlyPuantajSignatureDocument(
                                      companySettings: state.companySettings,
                                      row: row,
                                    );
                                    showHasibuPrintPreviewDialog(
                                      context,
                                      ref,
                                      document: doc,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                      ],
                    ),
                  ),
                ),
        ),
      ],
    );
  }
}

class _LegendPill extends StatelessWidget {
  final String code;
  final String label;
  final Color color;

  const _LegendPill({
    required this.code,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        '$code: $label',
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _HeaderCell extends StatelessWidget {
  final String text;
  const _HeaderCell(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Center(
        child: Text(
          text,
          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 11),
        ),
      ),
    );
  }
}

class _MetricCell extends StatelessWidget {
  final String text;
  final Color? color;
  const _MetricCell(this.text, {this.color});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}
