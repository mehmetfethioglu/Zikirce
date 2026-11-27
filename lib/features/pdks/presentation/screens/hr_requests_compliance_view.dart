import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/pdks_models.dart';
import '../providers/pdks_providers.dart';
import '../widgets/hasibu_theme_palette.dart';
import 'pdks_operational_dialogs.dart';

// ============================================================================
// İK TALEP ONAY MERKEZİ & 4857 UYUM RADARI
// ============================================================================
class _HrComplianceMetricTile extends StatelessWidget {
  final String label;
  final String value;
  final String subValue;

  const _HrComplianceMetricTile({
    required this.label,
    required this.value,
    required this.subValue,
  });

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    return Container(
      width: 210,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pal.subtle,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: TextStyle(color: pal.textSecondary, fontSize: 12),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              color: pal.textPrimary,
              fontSize: 17,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            subValue,
            style: TextStyle(color: pal.textMuted, fontSize: 11),
          ),
        ],
      ),
    );
  }
}

class HrRequestsAndComplianceView extends ConsumerStatefulWidget {
  const HrRequestsAndComplianceView({super.key});

  @override
  ConsumerState<HrRequestsAndComplianceView> createState() =>
      _HrRequestsAndComplianceViewState();
}

class _HrRequestsAndComplianceViewState
    extends ConsumerState<HrRequestsAndComplianceView> {
  String? _lastFeedback;

  Color _alertSeverityColor(PdksAlertSeverity severity) {
    return switch (severity) {
      PdksAlertSeverity.critical => const Color(0xFFDC2626),
      PdksAlertSeverity.warning => const Color(0xFFD97706),
      PdksAlertSeverity.info => const Color(0xFF0284C7),
    };
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdksDashboardProvider);
    final pal = HasibuPalette.of(context);
    final requests = state.allHrRequests;
    final pendingCount = state.pendingHrRequestsCount;
    final mismatchCount = state.statutoryLeaveMismatchCount;
    final missingOutCount = state.missingCheckOutCount;
    final missingDocsCount = state.missingDocsStaffCount;
    final tamperedLogs = state.tamperedAttendanceLogs;
    final proactiveAlerts = state.proactiveAlerts;
    final auditLogs = state.auditLogs;

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        // [HW-04] MANİPÜLE EDİLMİŞ KAYIT (HMAC-SHA256 integrityHash) KIRMIZI ALARM KALKANI
        if (tamperedLogs.isNotEmpty)
          Container(
            key: const ValueKey('tampered_attendance_alarm_card'),
            margin: const EdgeInsets.only(bottom: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: const Color(0xFFDC2626), width: 1.5),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.gpp_bad_rounded,
                      color: Color(0xFFDC2626),
                      size: 22,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'KIRMIZI ALARM — Manipüle Edilmiş Kayıt Tespit Edildi (${tamperedLogs.length} Kayıt)',
                        style: const TextStyle(
                          color: Color(0xFFDC2626),
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                const Text(
                  'Aşağıdaki puantaj kayıtlarının veritabanındaki saati veya doğrulama verisi HMAC-SHA256 (integrityHash) imzasıyla uyuşmuyor:',
                  style: TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                for (final tLog in tamperedLogs.take(5))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Text(
                      '• Manipüle Edilmiş Kayıt: Kart #${tLog.cardNo} • Tarih/Saat: ${tLog.dateKey} ${tLog.timeFormatted} • Kayıt ID: ${tLog.id}',
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
              ],
            ),
          ),
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
                runSpacing: 8,
                alignment: WrapAlignment.spaceBetween,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'İK Talep Onay Merkezi & 4857 İş Kanunu Uyum Radarı',
                        style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w800,
                          color: pal.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Personel portalından gelen izin, fazla mesai ve unutulan giriş/çıkış taleplerini tek tıkla onaylayın; onaylanan kayıtlar doğrudan puantaja işlenir.',
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
                    children: [
                      OutlinedButton.icon(
                        key: const ValueKey('hr_radar_new_request_button'),
                        onPressed: () {
                          final activeStaff = state.filteredByBranch;
                          final defaultEmp = activeStaff.isNotEmpty
                              ? activeStaff.first.employee
                              : (state.dailyStatuses.isNotEmpty
                                  ? state.dailyStatuses.first.employee
                                  : null);
                          if (defaultEmp != null) {
                            showCreateHrRequestDialog(
                              context,
                              ref,
                              employee: defaultEmp,
                              allowEmployeeSwitch: true,
                            );
                          }
                        },
                        icon: const Icon(Icons.add_task_rounded, size: 16),
                        label: const Text('Yeni Talep Kaydı Aç'),
                      ),
                      FilledButton.tonalIcon(
                        key: const ValueKey('sync_4857_leave_button'),
                        onPressed: () async {
                          final updated = await ref
                              .read(pdksDashboardProvider.notifier)
                              .syncStatutoryLeaveEntitlements();
                          if (mounted) {
                            setState(() {
                              _lastFeedback = updated > 0
                                  ? '4857 İş Kanunu Md. 53 uyarınca $updated personelin yıllık izin hakedişi kıdem yılına göre güncellendi.'
                                  : 'Tüm personellerin yıllık izin hakedişleri 4857 İş Kanunu kıdem süreleriyle tam uyumlu.';
                            });
                          }
                        },
                        icon: const Icon(Icons.gavel_rounded, size: 16),
                        label: Text(
                          mismatchCount > 0
                              ? '4857 Kıdem İzinlerini Eşitle ($mismatchCount)'
                              : '4857 Kıdem İzin Uyumunu Denetle',
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  _HrComplianceMetricTile(
                    label: 'Onay Bekleyen Talepler',
                    value: '$pendingCount Talep',
                    subValue: 'Toplam Kayıt: ${requests.length}',
                  ),
                  _HrComplianceMetricTile(
                    label: 'Bugün Eksik Çıkış (Tek Okuma)',
                    value: '$missingOutCount Kişi',
                    subValue: 'Tarih: ${state.selectedDate}',
                  ),
                  _HrComplianceMetricTile(
                    label: 'Eksik Zorunlu Özlük Evrakı',
                    value: '$missingDocsCount Personel',
                    subValue: '6 zorunlu resmi evrak denetimi',
                  ),
                  _HrComplianceMetricTile(
                    label: '4857 Kıdem İzin Farkı',
                    value: '$mismatchCount Personel',
                    subValue: '1-5y: 14g • 5-15y: 20g • 15+y: 26g',
                  ),
                  _HrComplianceMetricTile(
                    label: 'Proaktif İhbar & Uyum',
                    value: '${proactiveAlerts.length} Uyarı',
                    subValue:
                        'Kritik: ${state.criticalProactiveAlertsCount} • Evrak/25-II-g',
                  ),
                  _HrComplianceMetricTile(
                    label: 'HMAC-SHA256 Bütünlük Denetimi',
                    value: tamperedLogs.isEmpty
                        ? 'Tam Bütünlük'
                        : '${tamperedLogs.length} Manipüle Kayıt!',
                    subValue: tamperedLogs.isEmpty
                        ? 'Tüm puantaj imzaları doğrulandı'
                        : 'Manipüle Edilmiş Kayıt Alarmı',
                  ),
                ],
              ),
              if (_lastFeedback != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFF059669).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _lastFeedback!,
                    style: const TextStyle(
                      color: Color(0xFF059669),
                      fontWeight: FontWeight.w700,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        // PROAKTİF UYUM & İHBAR RADARI (4857 25/II-g, Evrak Bitiş, Deneme Süresi, Eksik Çıkış)
        Container(
          key: const ValueKey('proactive_compliance_alerts_card'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: pal.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: proactiveAlerts.any(
                (a) => a.severity == PdksAlertSeverity.critical,
              )
                  ? const Color(0xFFDC2626).withValues(alpha: 0.45)
                  : pal.border,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(
                    Icons.shield_outlined,
                    color: proactiveAlerts.isEmpty
                        ? const Color(0xFF059669)
                        : const Color(0xFFD97706),
                    size: 20,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Proaktif Uyum & İhbar Radarı (${proactiveAlerts.length} Bildirim)',
                      style: TextStyle(
                        fontSize: 14.5,
                        fontWeight: FontWeight.w800,
                        color: pal.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Ardışık 2+ gün devamsızlık (4857 Md. 25/II-g), süresi dolan/yaklaşan İSG ve sağlık raporları, deneme süresi bitişleri ve eksik çıkış kayıtları otomatik taranır.',
                style: TextStyle(fontSize: 11.5, color: pal.textSecondary),
              ),
              const SizedBox(height: 10),
              if (proactiveAlerts.isEmpty)
                Text(
                  'Seçili tarih itibarıyla kritik İK veya mevzuat uyarısı bulunmuyor.',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                    color: pal.textMuted,
                  ),
                )
              else
                for (final alert in proactiveAlerts)
                  Container(
                    key: ValueKey('proactive_alert_${alert.id}'),
                    margin: const EdgeInsets.only(bottom: 8),
                    padding: const EdgeInsets.all(11),
                    decoration: BoxDecoration(
                      color: _alertSeverityColor(alert.severity)
                          .withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(
                        color: _alertSeverityColor(alert.severity)
                            .withValues(alpha: 0.35),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Wrap(
                          spacing: 8,
                          runSpacing: 4,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 7,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: _alertSeverityColor(alert.severity)
                                    .withValues(alpha: 0.16),
                                borderRadius: BorderRadius.circular(5),
                              ),
                              child: Text(
                                '${alert.severity.label.toUpperCase()} • ${alert.category.label}',
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w800,
                                  color: _alertSeverityColor(alert.severity),
                                ),
                              ),
                            ),
                            Text(
                              '${alert.employeeName} (#${alert.employeeCardNo})',
                              style: TextStyle(
                                fontSize: 12.5,
                                fontWeight: FontWeight.w800,
                                color: pal.textPrimary,
                              ),
                            ),
                            Text(
                              alert.dateKey,
                              style: TextStyle(
                                fontSize: 11,
                                color: pal.textMuted,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        Text(
                          alert.title,
                          style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: pal.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          alert.detail,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: pal.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Personel İzin, Fazla Mesai & Hareket Düzeltme Talepleri (${requests.length})',
          style: TextStyle(
            fontSize: 14.5,
            fontWeight: FontWeight.w700,
            color: pal.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        for (final req in requests)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: req.status == HrRequestStatus.pending
                    ? const Color(0xFFD97706).withValues(alpha: 0.45)
                    : pal.border,
              ),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 560),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Wrap(
                        spacing: 8,
                        runSpacing: 4,
                        crossAxisAlignment: WrapCrossAlignment.center,
                        children: [
                          Text(
                            '${req.employeeName} (#${req.employeeCardNo})',
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13.5,
                              color: pal.textPrimary,
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: const Color(0xFF0284C7)
                                  .withValues(alpha: 0.14),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              req.type.label,
                              style: const TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: Color(0xFF0284C7),
                              ),
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: switch (req.status) {
                                HrRequestStatus.pending =>
                                  const Color(0xFFD97706).withValues(alpha: 0.15),
                                HrRequestStatus.approved =>
                                  const Color(0xFF059669).withValues(alpha: 0.15),
                                HrRequestStatus.rejected =>
                                  const Color(0xFFDC2626).withValues(alpha: 0.15),
                              },
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              req.status.label,
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w700,
                                color: switch (req.status) {
                                  HrRequestStatus.pending =>
                                    const Color(0xFFD97706),
                                  HrRequestStatus.approved =>
                                    const Color(0xFF059669),
                                  HrRequestStatus.rejected =>
                                    const Color(0xFFDC2626),
                                },
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Tarih: ${req.targetDate}${req.endDate != null ? " -> ${req.endDate}" : ""}'
                        '${req.requestedTime != null ? " • Saat: ${req.requestedTime}" : ""}'
                        '${req.overtimeMinutes > 0 ? " • Süre: +${req.overtimeMinutes} dk" : ""}'
                        ' • Açıklama: ${req.reason}',
                        style: TextStyle(
                          fontSize: 12,
                          color: pal.textSecondary,
                        ),
                      ),
                      if (req.reviewerNote != null &&
                          req.reviewerNote!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          'İK Notu: ${req.reviewerNote}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w600,
                            color: pal.textPrimary,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                if (req.status == HrRequestStatus.pending)
                  Wrap(
                    spacing: 8,
                    children: [
                      FilledButton.icon(
                        key: ValueKey('approve_hr_req_${req.id}'),
                        style: FilledButton.styleFrom(
                          backgroundColor: const Color(0xFF059669),
                          foregroundColor: Colors.white,
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: state.isCommercialWriteLocked
                            ? null
                            : () async {
                                final msg = await ref
                                    .read(pdksDashboardProvider.notifier)
                                    .reviewHrRequest(
                                      request: req,
                                      approve: true,
                                    );
                                if (mounted) {
                                  setState(() => _lastFeedback = msg);
                                }
                              },
                        icon: const Icon(Icons.check_rounded, size: 16),
                        label: Text(
                          state.isCommercialWriteLocked
                              ? 'Salt-Okunur Kilitli'
                              : 'Onayla & Puantaja İşle',
                        ),
                      ),
                      OutlinedButton.icon(
                        key: ValueKey('reject_hr_req_${req.id}'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                          visualDensity: VisualDensity.compact,
                        ),
                        onPressed: state.isCommercialWriteLocked
                            ? null
                            : () async {
                                final msg = await ref
                                    .read(pdksDashboardProvider.notifier)
                                    .reviewHrRequest(
                                      request: req,
                                      approve: false,
                                    );
                                if (mounted) {
                                  setState(() => _lastFeedback = msg);
                                }
                              },
                        icon: const Icon(Icons.close_rounded, size: 16),
                        label: const Text('Reddet'),
                      ),
                    ],
                  ),
              ],
            ),
          ),
        const SizedBox(height: 18),
        // [AUD-01] & [AUD-02] SİLİNEMEZ DENETİM İZİ (audit_logs) TABLOSU
        Container(
          key: const ValueKey('immutable_audit_logs_section'),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: pal.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: pal.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  const Icon(
                    Icons.verified_user_rounded,
                    color: Color(0xFF0284C7),
                    size: 19,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Silinemez Denetim İzi — Audit Logs (${auditLogs.length} Kayıt)',
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w800,
                        color: pal.textPrimary,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                '1-Tıkla Eksik Çıkış Tamamlama, İK Talep Onaylama, Yıllık İzin Hakediş Eşitleme ve Sahte GPS engellemeleri HMAC-SHA256 zinciriyle değiştirilemez şekilde kaydedilir.',
                style: TextStyle(fontSize: 11.5, color: pal.textSecondary),
              ),
              const SizedBox(height: 8),
              if (auditLogs.isEmpty)
                Text(
                  'Henüz denetim izi kaydı oluşmadı.',
                  style: TextStyle(fontSize: 12, color: pal.textMuted),
                ),
              for (final entry in auditLogs.take(8))
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(
                    '[${entry.timestamp.toIso8601String().substring(0, 16).replaceFirst('T', ' ')}] '
                    '${entry.actionType} • Aktör: ${entry.actorEmployeeId} • Hedef: ${entry.targetRecordId} '
                    '(${entry.oldValue} -> ${entry.newValue}) • Hash: #${entry.hash.substring(0, 10)}',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: pal.textPrimary,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }
}

Future<void> showHrRequestsAndComplianceDialog(
  BuildContext context,
  WidgetRef ref,
) async {
  await showDialog<void>(
    context: context,
    builder: (dialogCtx) => AlertDialog(
      title: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          const Flexible(
            child: Text(
              'İK Talep Onay Merkezi & 4857 Uyum Radarı',
              style: TextStyle(fontSize: 16.5, fontWeight: FontWeight.w800),
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            icon: const Icon(Icons.close_rounded),
          ),
        ],
      ),
      content: const SizedBox(
        width: 860,
        height: 540,
        child: HrRequestsAndComplianceView(),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(dialogCtx).pop(),
          child: const Text('Kapat'),
        ),
      ],
    ),
  );
}
