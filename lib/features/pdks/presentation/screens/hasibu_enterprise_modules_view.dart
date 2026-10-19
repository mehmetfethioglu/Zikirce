import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/pdks_models.dart';
import '../providers/pdks_providers.dart';

/// Hasibu Kurumsal Oturum Açma (Login Gate) Ekranı.
/// Yönetici/İK girişi tüm üst modülleri açar; Personel girişi yalnızca
/// personelin kendi Self-Servis portalını açar.
class HasibuLoginScreen extends ConsumerStatefulWidget {
  const HasibuLoginScreen({super.key});

  @override
  ConsumerState<HasibuLoginScreen> createState() => _HasibuLoginScreenState();
}

class _HasibuLoginScreenState extends ConsumerState<HasibuLoginScreen> {
  UserRole _selectedRole = UserRole.admin;
  late final TextEditingController _usernameOrCardCtrl;
  late final TextEditingController _passwordOrPinCtrl;
  bool _obscurePassword = true;

  @override
  void initState() {
    super.initState();
    _usernameOrCardCtrl = TextEditingController(text: 'admin');
    _passwordOrPinCtrl = TextEditingController(text: '123');
  }

  @override
  void dispose() {
    _usernameOrCardCtrl.dispose();
    _passwordOrPinCtrl.dispose();
    super.dispose();
  }

  void _switchRole(UserRole role) {
    setState(() {
      _selectedRole = role;
      if (role == UserRole.admin) {
        _usernameOrCardCtrl.text = 'admin';
        _passwordOrPinCtrl.text = '123';
      } else {
        _usernameOrCardCtrl.text = '00064';
        _passwordOrPinCtrl.text = '1234';
      }
    });
  }

  void _submitLogin() {
    final notifier = ref.read(pdksDashboardProvider.notifier);
    if (_selectedRole == UserRole.admin) {
      notifier.loginAsAdmin(
        username: _usernameOrCardCtrl.text,
        password: _passwordOrPinCtrl.text,
      );
    } else {
      notifier.loginAsEmployee(
        cardNo: _usernameOrCardCtrl.text,
        pin: _passwordOrPinCtrl.text,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final companyName = ref.watch(
      pdksDashboardProvider.select((s) => s.companySettings.companyName),
    );
    final errorMsg = ref.watch(
      pdksDashboardProvider.select((s) => s.authSession.errorMessage),
    );

    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 440),
            child: Card(
              elevation: 8,
              color: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              child: Padding(
                padding: const EdgeInsets.all(28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: const Color(0xFFE0F2FE),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.precision_manufacturing_rounded,
                            color: Color(0xFF0284C7),
                            size: 32,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 14),
                    Text(
                      companyName,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w800,
                        color: Color(0xFF0F172A),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'PDKS • Yalın Üretim • İK • Ön Muhasebe Platformu',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 12,
                        color: Color(0xFF64748B),
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 20),
                    SegmentedButton<UserRole>(
                      segments: const [
                        ButtonSegment<UserRole>(
                          value: UserRole.admin,
                          icon: Icon(Icons.admin_panel_settings_rounded),
                          label: Text('Yönetici / İK'),
                        ),
                        ButtonSegment<UserRole>(
                          value: UserRole.employee,
                          icon: Icon(Icons.badge_rounded),
                          label: Text('Personel Girişi'),
                        ),
                      ],
                      selected: {_selectedRole},
                      onSelectionChanged: (sel) => _switchRole(sel.first),
                    ),
                    const SizedBox(height: 20),
                    TextField(
                      key: const ValueKey('login_username_field'),
                      controller: _usernameOrCardCtrl,
                      onSubmitted: (_) => _submitLogin(),
                      decoration: InputDecoration(
                        labelText: _selectedRole == UserRole.admin
                            ? 'Yönetici Kullanıcı Adı'
                            : 'Personel Kart / Sicil No (örn. 00064)',
                        prefixIcon: Icon(
                          _selectedRole == UserRole.admin
                              ? Icons.person_outline_rounded
                              : Icons.credit_card_rounded,
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    const SizedBox(height: 14),
                    TextField(
                      key: const ValueKey('login_password_field'),
                      controller: _passwordOrPinCtrl,
                      obscureText: _obscurePassword,
                      onSubmitted: (_) => _submitLogin(),
                      decoration: InputDecoration(
                        labelText: _selectedRole == UserRole.admin
                            ? 'Parola'
                            : 'Personel PIN Kodu',
                        prefixIcon: const Icon(Icons.lock_outline_rounded),
                        suffixIcon: IconButton(
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_outlined
                                : Icons.visibility_off_outlined,
                          ),
                        ),
                        border: const OutlineInputBorder(),
                      ),
                    ),
                    if (errorMsg != null) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: const Color(0xFFFEE2E2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          errorMsg,
                          style: const TextStyle(
                            color: Color(0xFFB91C1C),
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                    const SizedBox(height: 18),
                    FilledButton.icon(
                      key: const ValueKey('login_submit_button'),
                      style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFF0284C7),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      onPressed: _submitLogin,
                      icon: const Icon(Icons.login_rounded),
                      label: const Text(
                        'Oturum Aç',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      _selectedRole == UserRole.admin
                          ? 'Bilgi: Varsayılan Yönetici -> admin / 123 (Sistem Ayarlarından değiştirilebilir)'
                          : 'Bilgi: Örnek Personel Kart No -> 00064 / PIN: 1234',
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 11,
                        color: Color(0xFF64748B),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// YALIN ÜRETİM & KPI MODÜLÜ EKRANLARI
// ============================================================================
class LeanProductionStationsView extends ConsumerWidget {
  const LeanProductionStationsView({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final departments =
        ref.watch(pdksDashboardProvider.select((s) => s.departments));
    final statuses =
        ref.watch(pdksDashboardProvider.select((s) => s.dailyStatuses));

    final prodDepts = departments
        .where((d) => d.isProductionLine)
        .toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Yalın Üretim İstasyonları • Canlı Hat Doluluk ve KPI Panosu',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 4),
        const Text(
          'Tenfei D35 yüz okutma verilerine göre bugün üretim istasyonlarında iş başı yapan ustalar, eksik kadrolar ve hat verimliliği.',
          style: TextStyle(fontSize: 13, color: Color(0xFF475569)),
        ),
        const SizedBox(height: 14),
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
        ? const Color(0xFF64748B)
        : (active == total
            ? const Color(0xFF16A34A)
            : (active > 0
                ? const Color(0xFFD97706)
                : const Color(0xFFDC2626)));

    return Container(
      width: 280,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
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
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 14,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: statusColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '$active / $total Aktif',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w800,
                    color: statusColor,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          LinearProgressIndicator(
            value: total == 0 ? 0 : active / total,
            backgroundColor: const Color(0xFFF1F5F9),
            color: statusColor,
            minHeight: 6,
            borderRadius: BorderRadius.circular(4),
          ),
          const SizedBox(height: 8),
          Text(
            'Ortalama İstasyon KPI: %${avgKpi.toStringAsFixed(1)}',
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: Color(0xFF475569),
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
    final statuses =
        ref.watch(pdksDashboardProvider.select((s) => s.dailyStatuses));
    final sorted = List<EmployeeDailyStatus>.from(statuses)
      ..sort((a, b) => b.employee.kpiScore.compareTo(a.employee.kpiScore));

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Personel Yalın Üretim KPI & Disiplin Sıralaması',
          style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 12),
        for (int i = 0; i < sorted.length; i++)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor: const Color(0xFFE0F2FE),
                child: Text(
                  '${i + 1}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF0369A1),
                  ),
                ),
              ),
              title: Text(
                '${sorted[i].employee.fullName} (#${sorted[i].employee.cardNo})',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${sorted[i].department.name} • ${sorted[i].branch.name} • Bugün: ${sorted[i].state.label}',
              ),
              trailing: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0xFFDCFCE7),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  'KPI %${sorted[i].employee.kpiScore.toStringAsFixed(0)}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    color: Color(0xFF15803D),
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
    final statuses =
        ref.watch(pdksDashboardProvider.select((s) => s.dailyStatuses));
    final selectedDate =
        ref.watch(pdksDashboardProvider.select((s) => s.selectedDate));

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

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Ön Muhasebe & Günlük Puantaj Tahakkuk Özeti ($selectedDate)',
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
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
              color: const Color(0xFF16A34A),
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
              subtitle: 'Bordroda ücretli izinli',
              color: const Color(0xFF0284C7),
            ),
            _AccountingSummaryBox(
              title: 'Devamsızlık Kesintisi',
              value: '$unpaidAbsentCount Personel',
              subtitle: 'Günlük yevmiye kesintisi adayları',
              color: const Color(0xFFDC2626),
            ),
          ],
        ),
        const SizedBox(height: 18),
        const Text(
          'Personel Bazlı Puantaj & Bordro Durum Çizelgesi',
          style: TextStyle(fontSize: 15, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        for (final item in statuses)
          Card(
            margin: const EdgeInsets.only(bottom: 8),
            elevation: 0,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: const BorderSide(color: Color(0xFFE2E8F0)),
            ),
            child: ListTile(
              title: Text(
                '${item.employee.fullName} (#${item.employee.cardNo})',
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
              subtitle: Text(
                '${item.branch.name} • ${item.department.name} • SGK: ${item.employee.sgkActive ? "Aktif" : "Pasif"}',
              ),
              trailing: Text(
                item.state == DailyAttendanceState.present
                    ? 'TAM YEVMİYE'
                    : item.state == DailyAttendanceState.late
                        ? 'GEÇ MESAI (-${item.lateMinutes} dk)'
                        : item.state == DailyAttendanceState.absent
                            ? 'YEVMİYE KESİNTİSİ'
                            : 'İZİNLİ / RAPORLU',
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  color: item.state == DailyAttendanceState.absent
                      ? const Color(0xFFDC2626)
                      : item.state == DailyAttendanceState.late
                          ? const Color(0xFFD97706)
                          : const Color(0xFF15803D),
                ),
              ),
            ),
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
    return Container(
      width: 220,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w700,
              color: Color(0xFF64748B),
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
            style: const TextStyle(fontSize: 11, color: Color(0xFF94A3B8)),
          ),
        ],
      ),
    );
  }
}
