import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/pdks_models.dart';
import '../../domain/pdks_print_builders.dart';
import '../providers/pdks_providers.dart';
import '../widgets/employee_profile_avatar.dart';
import '../widgets/hasibu_theme_palette.dart';
import 'employee_dossier_panel.dart';
import 'hasibu_print_preview_dialog.dart';
import 'live_attendance_punch_dialog.dart';

/// Personel Geçmişi & Dijital Özlük Dosyası (Resmi Evraklar) Modalı (Katman 5).
Future<void> showEmployeeHistoryAndDossierDialog(
  BuildContext context,
  WidgetRef ref,
  Employee employee, {
  int initialTabIndex = 0,
}) async {
  final initState = ref.read(pdksDashboardProvider);
  if (!initState.canAccessBranch(employee.branchId)) {
    return;
  }
  int activeTab = initialTabIndex.clamp(0, 1);

  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => Consumer(
      builder: (ctx, dialogRef, _) => StatefulBuilder(
        builder: (ctx, setDialogState) {
          final pal = HasibuPalette.of(ctx);
          final state = dialogRef.watch(pdksDashboardProvider);
          final notifier = dialogRef.read(pdksDashboardProvider.notifier);

          final matchedStatuses = state.dailyStatuses
              .where((s) => s.employee.id == employee.id)
              .toList(growable: false);
          if (matchedStatuses.isEmpty) {
            return AlertDialog(
              title: Text(employee.fullName),
              content:
                  const Text('Personel kaydı yetkili kapsamda bulunamadı.'),
              actions: [
                TextButton(
                  onPressed: () => Navigator.of(dialogCtx).pop(),
                  child: const Text('Kapat'),
                ),
              ],
            );
          }
          final currentStatus = matchedStatuses.first;
          final emp = currentStatus.employee;
          final historyEntries = notifier.getEmployeeHistory(emp);
          final empDocs = state.documentsForEmployee(emp.id);

          final int presentDays = historyEntries
              .where((e) => e.state == DailyAttendanceState.present)
              .length;
          final int lateDays = historyEntries
              .where((e) => e.state == DailyAttendanceState.late)
              .length;
          final int totalLateMins =
              historyEntries.fold<int>(0, (sum, e) => sum + e.lateMinutes);
          final int totalOvertimeMins =
              historyEntries.fold<int>(0, (sum, e) => sum + e.overtimeMinutes);
          final int leaveOrSickDays = historyEntries
              .where(
                (e) =>
                    e.state == DailyAttendanceState.onLeave ||
                    e.state == DailyAttendanceState.sickReport,
              )
              .length;

          return AlertDialog(
            insetPadding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 18),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
            titlePadding: const EdgeInsets.fromLTRB(18, 16, 18, 10),
            contentPadding: const EdgeInsets.fromLTRB(18, 6, 18, 14),
            title: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    EmployeeProfileAvatar(employee: emp, size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 8,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                emp.fullName,
                                style: TextStyle(
                                  fontSize: 16.5,
                                  fontWeight: FontWeight.w800,
                                  color: pal.textPrimary,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: pal.chip,
                                  borderRadius: BorderRadius.circular(6),
                                ),
                                child: Text(
                                  'Sicil / Kart No: #${emp.cardNo}',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    fontWeight: FontWeight.w700,
                                    color: pal.textSecondary,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 3),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '${currentStatus.branch.name} • ${currentStatus.department.name} • ${emp.title} • '
                                'İşe Giriş: ${PdksDashboardNotifier.formatDisplayDate(emp.hireDate, includeTodayBadge: false)}',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: pal.textSecondary,
                                ),
                              ),
                              if (emp.hasExitDate)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFFDC2626)
                                        .withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(5),
                                  ),
                                  child: Text(
                                    'İşten Çıkış: ${PdksDashboardNotifier.formatDisplayDate(emp.normalizedExitDate!, includeTodayBadge: false)} • '
                                    '${emp.isSeparatedNow ? "İŞTEN AYRILDI" : "ÇIKIŞ PLANLI"}',
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w700,
                                      color: Color(0xFFDC2626),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Kapat',
                      onPressed: () => Navigator.of(dialogCtx).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: pal.subtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: pal.border),
                  ),
                  child: Wrap(
                    spacing: 10,
                    runSpacing: 8,
                    alignment: WrapAlignment.spaceBetween,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: attendanceStateColor(currentStatus.state)
                                  .withValues(alpha: 0.16),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              currentStatus.lateMinutes > 0
                                  ? '${currentStatus.state.label} (+${currentStatus.lateMinutes} dk)'
                                  : currentStatus.state.label,
                              style: TextStyle(
                                fontSize: 11.5,
                                fontWeight: FontWeight.w800,
                                color:
                                    attendanceStateColor(currentStatus.state),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Flexible(
                            child: Text(
                              currentStatus.firstCheckIn != null
                                  ? 'Giriş: ${currentStatus.firstCheckIn!.timeFormatted}'
                                      '${currentStatus.lastCheckOut != null && currentStatus.lastCheckOut!.id != currentStatus.firstCheckIn!.id ? " • Çıkış: ${currentStatus.lastCheckOut!.timeFormatted}" : " • Çıkış Yok"}'
                                      ' (${currentStatus.firstCheckIn!.verifyMethod.label}) • Vardiya: ${currentStatus.shift.startTime}-${currentStatus.shift.endTime}'
                                  : '${currentStatus.leaveRecord?.note ?? currentStatus.publicHoliday?.name ?? "Giriş Yok"} • Vardiya: ${currentStatus.shift.startTime}-${currentStatus.shift.endTime}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: pal.textPrimary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          OutlinedButton.icon(
                            key: ValueKey('detail_add_punch_${emp.cardNo}'),
                            style: OutlinedButton.styleFrom(
                              visualDensity: VisualDensity.compact,
                            ),
                            onPressed: () => showLiveAttendancePunchDialog(
                              ctx,
                              dialogRef,
                              initialEmployee: emp,
                            ),
                            icon: const Icon(Icons.more_time_rounded, size: 15),
                            label: const Text(
                              'Giriş / Çıkış Ekle',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                          if (currentStatus.hasMissingCheckOut)
                            FilledButton.tonalIcon(
                              key: ValueKey('quick_complete_out_${emp.cardNo}'),
                              style: FilledButton.styleFrom(
                                visualDensity: VisualDensity.compact,
                                backgroundColor: const Color(0xFFD97706)
                                    .withValues(alpha: 0.18),
                                foregroundColor: const Color(0xFFF59E0B),
                              ),
                              onPressed: () => notifier
                                  .quickCompleteMissingCheckOut(currentStatus),
                              icon: const Icon(Icons.bolt_rounded, size: 15),
                              label: Text(
                                'Eksik Çıkış (${currentStatus.shift.endTime} Tamamla)',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          PopupMenuButton<LeaveType>(
                            tooltip: 'Hızlı İzin / Rapor Durumu Ata',
                            onSelected: (leaveType) {
                              notifier.assignLeaveOrReport(
                                employeeId: emp.id,
                                leaveType: leaveType,
                                note: '${leaveType.label} (Detay Penceresi)',
                              );
                            },
                            itemBuilder: (_) => [
                              for (final lt in LeaveType.values)
                                PopupMenuItem<LeaveType>(
                                  value: lt,
                                  child: Text('${lt.label} Olarak İşaretle'),
                                ),
                            ],
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 9,
                                vertical: 5,
                              ),
                              decoration: BoxDecoration(
                                color: pal.card,
                                borderRadius: BorderRadius.circular(8),
                                border: Border.all(color: pal.border),
                              ),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.edit_calendar_rounded,
                                    size: 14,
                                    color: pal.textSecondary,
                                  ),
                                  const SizedBox(width: 5),
                                  Text(
                                    'Durum Ata',
                                    style: TextStyle(
                                      fontSize: 11,
                                      fontWeight: FontWeight.w700,
                                      color: pal.textPrimary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: SegmentedButton<int>(
                    key: const ValueKey('employee_detail_tab_selector'),
                    showSelectedIcon: false,
                    segments: [
                      ButtonSegment<int>(
                        value: 0,
                        icon: const Icon(Icons.history_rounded, size: 16),
                        label: Text(
                          'Personel Geçmişi (${historyEntries.length} Gün)',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      ButtonSegment<int>(
                        value: 1,
                        icon:
                            const Icon(Icons.folder_shared_outlined, size: 16),
                        label: Text(
                          'Özlük Dosyası & Resmi Evraklar (${empDocs.length})',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                    ],
                    selected: {activeTab},
                    onSelectionChanged: (sel) =>
                        setDialogState(() => activeTab = sel.first),
                  ),
                ),
              ],
            ),
            content: SizedBox(
              width: (MediaQuery.sizeOf(ctx).width - 56).clamp(280.0, 740.0),
              height:
                  (MediaQuery.sizeOf(ctx).height * 0.60).clamp(280.0, 540.0),
              child: activeTab == 0
                  ? ListView(
                      children: [
                        Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            _EmployeeHistorySummaryChip(
                              label: 'Zamanında Giriş',
                              value: '$presentDays Gün',
                              color: const Color(0xFF059669),
                            ),
                            _EmployeeHistorySummaryChip(
                              label: 'Geç Kalma',
                              value: '$lateDays Kez ($totalLateMins dk)',
                              color: const Color(0xFFD97706),
                            ),
                            _EmployeeHistorySummaryChip(
                              label: 'Toplam Fazla Mesai',
                              value: '+$totalOvertimeMins dk',
                              color: const Color(0xFF059669),
                            ),
                            _EmployeeHistorySummaryChip(
                              label: 'İzinli / Raporlu',
                              value: '$leaveOrSickDays Gün',
                              color: const Color(0xFF0284C7),
                            ),
                            _EmployeeHistorySummaryChip(
                              label: 'Kalan Yıllık İzin',
                              value: '${emp.remainingAnnualLeave} Gün',
                              color: const Color(0xFF7C3AED),
                            ),
                          ],
                        ),
                        const SizedBox(height: 14),
                        Text(
                          'Kronolojik Giriş-Çıkış, Mesai & İzin Geçmişi',
                          style: TextStyle(
                            fontSize: 13.5,
                            fontWeight: FontWeight.w700,
                            color: pal.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        for (final entry in historyEntries)
                          Container(
                            margin: const EdgeInsets.only(bottom: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 14,
                              vertical: 10,
                            ),
                            decoration: BoxDecoration(
                              color: pal.subtle,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: pal.border),
                            ),
                            child: Row(
                              children: [
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 6,
                                  ),
                                  decoration: BoxDecoration(
                                    color: pal.card,
                                    borderRadius: BorderRadius.circular(8),
                                    border: Border.all(color: pal.border),
                                  ),
                                  child: Text(
                                    entry.dateKey,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 12.5,
                                      color: pal.textPrimary,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        entry.firstCheckIn != null
                                            ? 'İlk Giriş: ${entry.firstCheckIn!.timeFormatted}'
                                                '${entry.lastCheckOut != null && entry.lastCheckOut!.id != entry.firstCheckIn!.id ? " • Son Çıkış: ${entry.lastCheckOut!.timeFormatted}" : ""}'
                                                ' (${entry.firstCheckIn!.verifyMethod.label})'
                                            : (entry.leaveRecord?.note ??
                                                entry.publicHoliday?.name ??
                                                (entry.state ==
                                                        DailyAttendanceState
                                                            .terminated
                                                    ? 'İşten ayrıldı (${PdksDashboardNotifier.formatDisplayDate(emp.normalizedExitDate ?? entry.dateKey, includeTodayBadge: false)})'
                                                    : (entry.state ==
                                                            DailyAttendanceState
                                                                .notYetHired
                                                        ? 'İşe giriş tarihi (${PdksDashboardNotifier.formatDisplayDate(emp.hireDate, includeTodayBadge: false)}) öncesi'
                                                        : (entry.state ==
                                                                DailyAttendanceState
                                                                    .weeklyOff
                                                            ? 'Planlı hafta tatili'
                                                            : 'Cihaz veya mobil giriş kaydı bulunmuyor')))),
                                        style: TextStyle(
                                          fontWeight: FontWeight.w600,
                                          fontSize: 12.5,
                                          color: pal.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        'Vardiya: ${currentStatus.shift.name} (${currentStatus.shift.startTime}-${currentStatus.shift.endTime}) • '
                                        'Net Çalışma: ${entry.workedDurationFormatted}'
                                        '${entry.breakDeductedMinutes > 0 ? " (-${entry.breakDeductedMinutes} dk mola)" : ""}'
                                        '${entry.overtimeMinutes > 0 ? " • +${entry.overtimeMinutes} dk Mesai" : ""}'
                                        '${entry.earlyLeaveMinutes > 0 ? " • -${entry.earlyLeaveMinutes} dk Erken Çıkış" : ""}',
                                        style: TextStyle(
                                          fontSize: 11.5,
                                          color: pal.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 9,
                                    vertical: 4,
                                  ),
                                  decoration: BoxDecoration(
                                    color: attendanceStateColor(entry.state)
                                        .withValues(alpha: 0.14),
                                    borderRadius: BorderRadius.circular(6),
                                  ),
                                  child: Text(
                                    entry.lateMinutes > 0
                                        ? '${entry.state.label} (+${entry.lateMinutes} dk)'
                                        : entry.state.label,
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: attendanceStateColor(entry.state),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                      ],
                    )
                  : EmployeeDossierPanel(employee: emp),
            ),
            actions: [
              OutlinedButton.icon(
                key: const ValueKey('print_dossier_dialog_button'),
                onPressed: () {
                  final doc = HasibuPrintBuilders.buildEmployeeCardDocument(
                    companySettings: state.companySettings,
                    status: currentStatus,
                    selectedDateKey: state.selectedDate,
                    documents: empDocs,
                    historyEntries: historyEntries,
                  );
                  showHasibuPrintPreviewDialog(ctx, dialogRef, document: doc);
                },
                icon: const Icon(Icons.print_outlined, size: 17),
                label: const Text('Yazdır'),
              ),
              TextButton(
                onPressed: () => Navigator.of(dialogCtx).pop(),
                child: const Text('Kapat'),
              ),
            ],
          );
        },
      ),
    ),
  );
}

class _EmployeeHistorySummaryChip extends StatelessWidget {
  final String label;
  final String value;
  final Color color;

  const _EmployeeHistorySummaryChip({
    required this.label,
    required this.value,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    return Container(
      width: 175,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: pal.subtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(
              fontSize: 11.5,
              fontWeight: FontWeight.w600,
              color: pal.textSecondary,
            ),
          ),
          const SizedBox(height: 3),
          Text(
            value,
            style: TextStyle(
              fontSize: 15,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
