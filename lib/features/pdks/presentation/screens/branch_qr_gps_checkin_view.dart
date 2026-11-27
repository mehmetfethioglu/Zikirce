import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/pdks_models.dart';
import '../providers/pdks_providers.dart';
import '../widgets/employee_profile_avatar.dart';
import '../widgets/hasibu_theme_palette.dart';

/// Şube Mobil Konum (GPS Geofence) Giriş-Çıkış Ekranı.
class BranchQrGpsCheckInView extends ConsumerStatefulWidget {
  const BranchQrGpsCheckInView({super.key});

  @override
  ConsumerState<BranchQrGpsCheckInView> createState() =>
      _BranchQrGpsCheckInViewState();
}

class _BranchQrGpsCheckInViewState
    extends ConsumerState<BranchQrGpsCheckInView> {
  int _selectedBranchId = 1;
  bool _isCheckIn = true;
  String? _lastActionFeedback;

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdksDashboardProvider);
    final pal = HasibuPalette.of(context);
    if (state.branches.isEmpty) {
      return const Center(
        child: Text('Yetkili şube kaydı bulunamadı.'),
      );
    }
    final isEmployeeRole = state.authSession.role == UserRole.employee;
    final sessionCardNo = state.authSession.employeeCardNo?.trim() ?? '';
    final effectiveBranchId =
        state.effectiveBranchScopeId ?? _selectedBranchId;
    final branch = state.branches.firstWhere(
      (b) => b.id == effectiveBranchId,
      orElse: () => state.branches.first,
    );
    final branchStaff = state.dailyStatuses.where((s) {
      if (s.branch.id != branch.id || s.state.isNonActiveEmployment) {
        return false;
      }
      if (isEmployeeRole) {
        return s.employee.cardNo == sessionCardNo;
      }
      return true;
    }).toList(growable: false);

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
              Text(
                'Şube Mobil Konum (GPS Geofence) Giriş-Çıkış Sistemi',
                style: TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                  color: pal.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                isEmployeeRole
                    ? 'Kendi şubeniz için GPS konum doğrulamasıyla (anti-spoof korumalı) yalnızca kendi adınıza giriş-çıkış kaydı oluşturabilirsiniz.'
                    : 'Yüz tanıma terminali bulunmayan şubelerde personeller gerçek GPS konum doğrulaması (Geofence) ile giriş-çıkış yapar.',
                style: TextStyle(fontSize: 12.5, color: pal.textSecondary),
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 12,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                alignment: WrapAlignment.spaceBetween,
                children: [
                  Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      if (state.isSingleBranchScoped || isEmployeeRole)
                        ChoiceChip(
                          avatar: const Icon(Icons.lock_outline_rounded, size: 14),
                          label: Text(branch.name),
                          selected: true,
                          onSelected: null,
                        )
                      else
                        for (final b in state.branches)
                          ChoiceChip(
                            label: Text(b.name),
                            selected: branch.id == b.id,
                            onSelected: (_) =>
                                setState(() => _selectedBranchId = b.id),
                          ),
                    ],
                  ),
                  SegmentedButton<bool>(
                    key: const ValueKey('branch_qr_gps_direction_selector'),
                    segments: const [
                      ButtonSegment<bool>(
                        value: true,
                        icon: Icon(Icons.login_rounded, size: 16),
                        label: Text('Giriş Yap'),
                      ),
                      ButtonSegment<bool>(
                        value: false,
                        icon: Icon(Icons.logout_rounded, size: 16),
                        label: Text('Çıkış Yap'),
                      ),
                    ],
                    selected: {_isCheckIn},
                    onSelectionChanged: (selection) {
                      if (selection.isNotEmpty) {
                        setState(() => _isCheckIn = selection.first);
                      }
                    },
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.25),
                      ),
                    ),
                    child: const Icon(
                      Icons.my_location_rounded,
                      size: 32,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          branch.name,
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 15,
                            color: pal.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'GPS Merkez: ${branch.latitude}, ${branch.longitude}\n'
                          'Geofence Sınırı: ${branch.geofenceRadiusMeters.round()} metre\n'
                          'Sahte Konum (Mock Location) Kalkanı: Aktif',
                          style: TextStyle(
                            fontSize: 12,
                            color: pal.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              if (_lastActionFeedback != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: _lastActionFeedback!.contains('reddedildi') ||
                            _lastActionFeedback!.contains('dışında') ||
                            _lastActionFeedback!.contains('SAHTE')
                        ? const Color(0xFFDC2626).withValues(alpha: 0.14)
                        : const Color(0xFF059669).withValues(alpha: 0.14),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _lastActionFeedback!,
                    style: TextStyle(
                      color: _lastActionFeedback!.contains('reddedildi') ||
                              _lastActionFeedback!.contains('dışında') ||
                              _lastActionFeedback!.contains('SAHTE')
                          ? const Color(0xFFDC2626)
                          : const Color(0xFF059669),
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text(
          isEmployeeRole
              ? 'Kendi GPS Yoklama Kartım'
              : '${branch.name} Personelleri (${branchStaff.length} Kişi)',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: pal.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        for (final s in branchStaff)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: pal.border),
            ),
            child: ListTile(
              leading: EmployeeProfileAvatar(employee: s.employee, size: 38),
              title: Text(
                '${s.employee.fullName} (#${s.employee.cardNo})',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: pal.textPrimary,
                ),
              ),
              subtitle: Text(
                '${s.employee.title} • Durum: ${s.state.label}',
                style: TextStyle(color: pal.textSecondary, fontSize: 12),
              ),
              trailing: FilledButton.tonalIcon(
                key: ValueKey('branch_gps_action_${s.employee.cardNo}'),
                onPressed: () async {
                  final gateway = ref.read(mobileLocationGatewayProvider);
                  final reading = await gateway.getCurrentLocation(
                    fallbackBranch: branch,
                  );
                  final msg = await ref
                      .read(pdksDashboardProvider.notifier)
                      .recordBranchMobileCheckIn(
                        employee: s.employee,
                        branch: branch,
                        source: AttendanceSource.mobileGps,
                        isCheckIn: _isCheckIn,
                        currentLat: reading.latitude,
                        currentLng: reading.longitude,
                        isMockedGps: reading.isMocked,
                        isSimulatedFallback: reading.isSimulatedFallback,
                      );
                  if (mounted) {
                    setState(() => _lastActionFeedback = msg);
                  }
                },
                icon: const Icon(Icons.my_location_rounded, size: 15),
                label: Text(_isCheckIn ? 'GPS Giriş' : 'GPS Çıkış'),
              ),
            ),
          ),
      ],
    );
  }
}
