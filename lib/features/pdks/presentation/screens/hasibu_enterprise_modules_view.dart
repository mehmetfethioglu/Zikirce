import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/pdks_models.dart';
import '../providers/accounting_providers.dart';
import '../providers/pdks_providers.dart';
import 'hasibu_accounting_views.dart';
import 'hasibu_settings_view.dart';

export 'hasibu_login_screen.dart';

// ============================================================================
// YALIN ÜRETİM & KPI MODÜLÜ EKRANLARI
// ============================================================================
class LeanProductionStationsView extends ConsumerWidget {
  const LeanProductionStationsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departments =
        ref.watch(pdksDashboardProvider.select((s) => s.departments));
    final statuses = ref
        .watch(pdksDashboardProvider.select((s) => s.dailyStatuses))
        .where((s) => !s.state.isNonActiveEmployment)
        .toList(growable: false);
    final pal = HasibuPalette.of(context);

    final prodDepts = departments
        .where((d) => d.isProductionLine)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Yalın Üretim İstasyonları • Canlı Hat Doluluk ve KPI Panosu',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: pal.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Cihazlardan gelen canlı yoklama verilerine göre üretim istasyonlarında iş başı yapan ustalar ve hat verimliliği.',
          style: TextStyle(fontSize: 12, color: pal.textSecondary),
        ),
        const SizedBox(height: 16),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            for (final dept in prodDepts)
              _ProductionStationCard(
                department: dept,
                stationStaff: statuses
                    .where((s) => s.department.id == dept.id)
                    .toList(growable: false),
              ),
          ],
        ),
      ],
    );
  }
}

class _ProductionStationCard extends StatelessWidget {
  final Department department;
  final List<EmployeeDailyStatus> stationStaff;

  const _ProductionStationCard({
    required this.department,
    required this.stationStaff,
  });

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    final int total = stationStaff.length;
    final int active = stationStaff
        .where(
          (s) =>
              s.state == DailyAttendanceState.present ||
              s.state == DailyAttendanceState.late,
        )
        .length;
    final double avgKpi = total == 0
        ? 100
        : stationStaff
                .map((s) => s.employee.kpiScore)
                .reduce((a, b) => a + b) /
            total;

    final Color statusColor = total == 0
        ? pal.textSecondary
        : (active == total
            ? const Color(0xFF059669)
            : (active > 0
                ? const Color(0xFFD97706)
                : const Color(0xFFDC2626)));

    return Container(
      width: 280,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Flexible(
                child: Text(
                  department.name,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 13.5,
                    color: pal.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(6),
                ),
                child: Text(
                  '$active / $total Aktif',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            value: total == 0 ? 0 : active / total,
            backgroundColor: pal.chip,
            color: statusColor,
            minHeight: 5,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 10),
          Text(
            'Ortalama İstasyon KPI: %${avgKpi.toStringAsFixed(1)}',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w500,
              color: pal.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class LeanKpiLeaderboardView extends ConsumerWidget {
  const LeanKpiLeaderboardView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref
        .watch(pdksDashboardProvider.select((s) => s.dailyStatuses))
        .where((s) => !s.state.isNonActiveEmployment)
        .toList(growable: false);
    final pal = HasibuPalette.of(context);
    final sorted = List<EmployeeDailyStatus>.from(statuses)
      ..sort((a, b) => b.employee.kpiScore.compareTo(a.employee.kpiScore));

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Personel Yalın Üretim KPI & Disiplin Sıralaması',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: pal.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < sorted.length; i++)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: pal.border),
            ),
            child: ListTile(
              onTap: () => showEmployeeHistoryAndDossierDialog(
                context,
                ref,
                sorted[i].employee,
                initialTabIndex: 0,
              ),
              leading: EmployeeProfileAvatar(
                employee: sorted[i].employee,
                size: 40,
              ),
              title: Text(
                '${i + 1}. ${sorted[i].employee.fullName} (#${sorted[i].employee.cardNo})',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: pal.textPrimary,
                ),
              ),
              subtitle: Text(
                '${sorted[i].department.name} • ${sorted[i].branch.name} • Bugün: ${sorted[i].state.label}',
                style: TextStyle(fontSize: 12, color: pal.textSecondary),
              ),
              trailing: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                decoration: BoxDecoration(
                  color: const Color(0xFF059669).withValues(alpha: 0.14),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  'KPI %${sorted[i].employee.kpiScore.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w700,
                    fontSize: 12,
                    color: Color(0xFF059669),
                  ),
                ),
              ),
            ),
          ),
      ],
    );
  }
}

// ============================================================================
// ÖN MUHASEBE & PUANTAJ MODÜLÜ EKRANLARI
// ============================================================================
class PreAccountingPayrollSummaryView extends ConsumerWidget {
  const PreAccountingPayrollSummaryView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final statuses = ref
        .watch(pdksDashboardProvider.select((s) => s.dailyStatuses))
        .where((s) => !s.state.isNonActiveEmployment)
        .toList(growable: false);
    final selectedDate =
        ref.watch(pdksDashboardProvider.select((s) => s.selectedDate));
    final puantajRows =
        ref.watch(accountingProvider.select((s) => s.puantajRows));
    final periodKey =
        ref.watch(accountingProvider.select((s) => s.selectedPeriodKey));
    final pal = HasibuPalette.of(context);

    final puantajByCard = {
      for (final r in puantajRows) r.cardNo: r,
    };

    final int normalCount = statuses
        .where((s) => s.state == DailyAttendanceState.present)
        .length;
    final int lateCount =
        statuses.where((s) => s.state == DailyAttendanceState.late).length;
    final int paidLeaveCount = statuses
        .where(
          (s) =>
              s.state == DailyAttendanceState.onLeave ||
              s.state == DailyAttendanceState.sickReport,
        )
        .length;
    final int unpaidAbsentCount =
        statuses.where((s) => s.state == DailyAttendanceState.absent).length;
    final int totalLateMins =
        statuses.fold<int>(0, (sum, item) => sum + item.lateMinutes);
    final double totalTreasurySubsidy = puantajRows.fold<double>(
      0.0,
      (sum, r) => sum + r.sgkTreasurySubsidyTl,
    );

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Ön Muhasebe & GMS.NET Günlük Puantaj Tahakkuk Özeti ($selectedDate)',
          style: TextStyle(
            fontSize: 15,
            fontWeight: FontWeight.w700,
            color: pal.textPrimary,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 12,
          runSpacing: 12,
          children: [
            _AccountingSummaryBox(
              title: 'Tam Mesai Hakedişi',
              value: '$normalCount Personel',
              subtitle: 'Kesintisiz tam gün puantaj',
              color: const Color(0xFF059669),
            ),
            _AccountingSummaryBox(
              title: 'Geç Kalma Kesintisi',
              value: '$lateCount Kişi ($totalLateMins dk)',
              subtitle: 'Tolerans aşımı toplam süre',
              color: const Color(0xFFD97706),
            ),
            _AccountingSummaryBox(
              title: 'Ücretli İzin / Rapor',
              value: '$paidLeaveCount Personel',
              subtitle: 'Bordroda ücretli izinli (01-İstirahat)',
              color: const Color(0xFF0284C7),
            ),
            _AccountingSummaryBox(
              title: 'Devamsızlık Kesintisi',
              value: '$unpaidAbsentCount Personel',
              subtitle: 'Günlük yevmiye kesintisi (15-Devamsız)',
              color: const Color(0xFFDC2626),
            ),
            _AccountingSummaryBox(
              title: 'SGK Teşvik Kazancı',
              value: '${totalTreasurySubsidy.toStringAsFixed(0)} ₺',
              subtitle: '5510 / 6111 / 17103 Hazine İndirimi',
              color: const Color(0xFF7C3AED),
            ),
          ],
        ),
        const SizedBox(height: 20),
        Text(
          'Personel Bazlı GMS.NET Puantaj & Bordro Durum Çizelgesi',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: pal.textPrimary,
          ),
        ),
        const SizedBox(height: 10),
        for (final item in statuses)
          Builder(
            builder: (context) {
              final pRow = puantajByCard[item.employee.cardNo];
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                decoration: BoxDecoration(
                  color: pal.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: pal.border),
                ),
                child: ListTile(
                  onTap: () {
                    if (pRow != null) {
                      showGmsPayrollEnvelopeDialog(
                        context,
                        ref,
                        row: pRow,
                        periodKey: periodKey,
                      );
                    } else {
                      showEmployeeHistoryAndDossierDialog(
                        context,
                        ref,
                        item.employee,
                        initialTabIndex: 0,
                      );
                    }
                  },
                  leading: EmployeeProfileAvatar(
                    employee: item.employee,
                    size: 38,
                  ),
                  title: Text(
                    '${item.employee.fullName} (#${item.employee.cardNo})',
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13.5,
                      color: pal.textPrimary,
                    ),
                  ),
                  subtitle: Text(
                    '${item.branch.name} • ${item.department.name} • SGK: ${item.employee.sgkActive ? "Aktif" : "Pasif"}'
                    '${pRow != null ? " • Kanun: ${pRow.sgkLaw.code} • Eksik Gün: ${pRow.missingDayReason.code} • Net: ${pRow.gmsNetBankPayableTl.toStringAsFixed(0)} ₺" : ""}',
                    style: TextStyle(fontSize: 12, color: pal.textSecondary),
                  ),
                  trailing: Text(
                    switch (item.state) {
                      DailyAttendanceState.present => 'TAM YEVMİYE',
                      DailyAttendanceState.late =>
                        'GEÇ MESAI (-${item.lateMinutes} dk)',
                      DailyAttendanceState.absent => 'YEVMİYE KESİNTİSİ',
                      DailyAttendanceState.onLeave ||
                      DailyAttendanceState.sickReport =>
                        'İZİNLİ / RAPORLU',
                      DailyAttendanceState.terminated => 'İŞTEN AYRILDI',
                      DailyAttendanceState.notYetHired => 'KADRO DIŞI',
                    },
                    style: TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                      color: switch (item.state) {
                        DailyAttendanceState.absent => const Color(0xFFDC2626),
                        DailyAttendanceState.late => const Color(0xFFD97706),
                        DailyAttendanceState.terminated ||
                        DailyAttendanceState.notYetHired =>
                          const Color(0xFF64748B),
                        _ => const Color(0xFF059669),
                      },
                    ),
                  ),
                ),
              );
            },
          ),
      ],
    );
  }
}

class _AccountingSummaryBox extends StatelessWidget {
  final String title;
  final String value;
  final String subtitle;
  final Color color;

  const _AccountingSummaryBox({
    required this.title,
    required this.value,
    required this.subtitle,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    return Container(
      width: 220,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: pal.textSecondary,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            value,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: color,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: TextStyle(fontSize: 11, color: pal.textMuted),
          ),
        ],
      ),
    );
  }
}
