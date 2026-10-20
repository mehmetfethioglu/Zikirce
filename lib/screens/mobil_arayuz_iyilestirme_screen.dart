import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../features/pdks/domain/pdks_models.dart';
import '../features/pdks/presentation/providers/pdks_providers.dart';
import '../features/pdks/presentation/screens/hasibu_settings_view.dart';
import '../providers/mobil_arayuz_iyilestirme_provider.dart';

/// Modern Mobil Kullanıcı Arayüzü Ekranı
/// Tek elle rahat kullanım, responsive kart hiyerarşisi ve akıcı dokunmatik etkileşim.
class MobilArayuzIyilestirmeScreen extends ConsumerWidget {
  const MobilArayuzIyilestirmeScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = HasibuPalette.of(context);
    final companySettings = ref.watch(
      pdksDashboardProvider.select((s) => s.companySettings),
    );
    final authSession = ref.watch(
      pdksDashboardProvider.select((s) => s.authSession),
    );
    final densityMode = ref.watch(
      mobileUiProvider.select((s) => s.densityMode),
    );
    final isCompact = densityMode == MobileDensityMode.compact;

    return Scaffold(
      backgroundColor: pal.bg,
      appBar: AppBar(
        elevation: 0,
        scrolledUnderElevation: 1,
        backgroundColor: pal.card,
        foregroundColor: pal.textPrimary,
        titleSpacing: 12,
        title: Row(
          children: [
            CompanyLogoBadge(
              key: const ValueKey('mobile_company_logo_badge'),
              settings: companySettings,
              size: 32,
              borderRadius: 8,
              onTap: authSession.canAccess(HasibuModule.systemSettings)
                  ? () => showCompanyLogoDialog(context, ref)
                  : null,
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    companySettings.companyName,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w800,
                      color: pal.textPrimary,
                    ),
                  ),
                  Text(
                    'Mobil PDKS & Saha Yönetimi',
                    style: TextStyle(
                      fontSize: 10.5,
                      fontWeight: FontWeight.w500,
                      color: pal.textSecondary,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          // Görünüm yoğunluğu değiştirici (Ferah / Kompakt)
          IconButton(
            tooltip: isCompact ? 'Ferah Kart Görünümü' : 'Kompakt Liste',
            icon: Icon(
              isCompact ? Icons.view_agenda_rounded : Icons.view_headline_rounded,
              size: 20,
              color: const Color(0xFF0284C7),
            ),
            onPressed: () =>
                ref.read(mobileUiProvider.notifier).toggleDensityMode(),
          ),
          // Tema değiştirici
          const UserThemeSelectorBar(compact: true),
          // Mobil Hızlı Menü
          IconButton(
            tooltip: 'Hızlı İşlemler',
            icon: const Icon(Icons.more_vert_rounded, size: 20),
            onPressed: () => _showMobileActionMenu(context, ref),
          ),
          const SizedBox(width: 4),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(1),
          child: Divider(height: 1, thickness: 1, color: pal.border),
        ),
      ),
      body: RefreshIndicator(
        color: const Color(0xFF0284C7),
        backgroundColor: pal.card,
        onRefresh: () async {
          await ref.read(mobileUiProvider.notifier).triggerMobileRefresh(
            onRefreshCallback: () async {
              await ref
                  .read(pdksDashboardProvider.notifier)
                  .pullFromTenfeiTerminals();
            },
          );
        },
        child: const CustomScrollView(
          physics: AlwaysScrollableScrollPhysics(),
          slivers: [
            SliverToBoxAdapter(child: _MobileTopHeaderSection()),
            SliverToBoxAdapter(child: _MobileFilterAndSearchSection()),
            _MobileEmployeeSliverList(),
          ],
        ),
      ),
      bottomNavigationBar: const _MobileBottomNavigationBar(),
    );
  }

  void _showMobileActionMenu(BuildContext context, WidgetRef ref) {
    final pal = HasibuPalette.of(context);
    final authSession = ref.read(
      pdksDashboardProvider.select((s) => s.authSession),
    );

    showModalBottomSheet<void>(
      context: context,
      backgroundColor: pal.card,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 38,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: pal.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
                ListTile(
                  leading: const Icon(Icons.radar_rounded, color: Color(0xFF0284C7)),
                  title: const Text('Cihaz Bağlantı Tanılama (Tenfei D35)'),
                  subtitle: const Text('TCP 4370 soket ve veri akış testi'),
                  onTap: () {
                    Navigator.pop(ctx);
                    showTerminalDiagnosticsDialog(context, ref);
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.cloud_sync_rounded, color: Color(0xFF10B981)),
                  title: const Text('Google Drive & Gmail Eşitleme'),
                  subtitle: const Text('Bulut yedekleme ve anlık veri aktarımı'),
                  onTap: () {
                    Navigator.pop(ctx);
                    showGmailDriveSyncDialog(context, ref);
                  },
                ),
                if (authSession.canAccess(HasibuModule.systemSettings))
                  ListTile(
                    leading: const Icon(Icons.settings_suggest_rounded, color: Color(0xFFF59E0B)),
                    title: const Text('Sistem & Firma Parametreleri'),
                    subtitle: const Text('Şubeler, vardiyalar ve kullanıcı yetkileri'),
                    onTap: () {
                      Navigator.pop(ctx);
                      ref
                          .read(pdksDashboardProvider.notifier)
                          .selectModule(HasibuModule.systemSettings);
                    },
                  ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.logout_rounded, color: Color(0xFFEF4444)),
                  title: Text(
                    'Oturumu Kapat (${authSession.displayName})',
                    style: const TextStyle(color: Color(0xFFEF4444), fontWeight: FontWeight.w600),
                  ),
                  onTap: () {
                    Navigator.pop(ctx);
                    ref.read(pdksDashboardProvider.notifier).logout();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Üst Tarih ve Durum Bilgi Şeridi
class _MobileTopHeaderSection extends ConsumerWidget {
  const _MobileTopHeaderSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = HasibuPalette.of(context);
    final selectedDate =
        ref.watch(pdksDashboardProvider.select((s) => s.selectedDate));
    final terminalMsg =
        ref.watch(pdksDashboardProvider.select((s) => s.terminalStatusMessage));
    final isPolling =
        ref.watch(pdksDashboardProvider.select((s) => s.isPollingTerminal));

    final dates = const ['2026-10-20', '2026-10-19', '2026-10-17'];

    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 14, 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Canlı durum kapsülü
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: pal.border),
            ),
            child: Row(
              children: [
                AnimatedContainer(
                  duration: const Duration(milliseconds: 300),
                  width: 8,
                  height: 8,
                  decoration: BoxDecoration(
                    color: isPolling ? const Color(0xFFF59E0B) : const Color(0xFF10B981),
                    shape: BoxShape.circle,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    terminalMsg,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: pal.textPrimary,
                    ),
                  ),
                ),
                if (isPolling)
                  const SizedBox(
                    width: 14,
                    height: 14,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Tarih Seçici Yatay Liste
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final d in dates) ...[
                  ChoiceChip(
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      d == '2026-10-20' ? '$d (Bugün)' : d,
                      style: const TextStyle(fontSize: 11.5, fontWeight: FontWeight.w600),
                    ),
                    selected: selectedDate == d,
                    onSelected: (_) => ref
                        .read(pdksDashboardProvider.notifier)
                        .setSelectedDate(d),
                  ),
                  const SizedBox(width: 6),
                ],
              ],
            ),
          ),
          const SizedBox(height: 10),
          // Mobil Uyumlu Responsive KPI Özeti
          const _MobileResponsiveKpiCards(),
        ],
      ),
    );
  }
}

/// Mobil Ekrana Tam Uyum Sağlayan 2x3 Responsive KPI Izgarası
class _MobileResponsiveKpiCards extends ConsumerWidget {
  const _MobileResponsiveKpiCards();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = ref.watch(pdksDashboardProvider.select((s) => s.totalCount));
    final present = ref.watch(pdksDashboardProvider.select((s) => s.presentCount));
    final lateCount = ref.watch(pdksDashboardProvider.select((s) => s.lateCount));
    final absent = ref.watch(pdksDashboardProvider.select((s) => s.absentCount));
    final onLeave = ref.watch(pdksDashboardProvider.select((s) => s.onLeaveCount));
    final sick = ref.watch(pdksDashboardProvider.select((s) => s.sickReportCount));
    final activeFilter =
        ref.watch(pdksDashboardProvider.select((s) => s.selectedStateFilter));

    final items = [
      _KpiData(
        title: 'Toplam Kadro',
        count: total,
        color: const Color(0xFF0284C7),
        icon: Icons.people_alt_rounded,
        filter: null,
      ),
      _KpiData(
        title: 'Zamanında',
        count: present,
        color: const Color(0xFF059669),
        icon: Icons.check_circle_rounded,
        filter: DailyAttendanceState.present,
      ),
      _KpiData(
        title: 'Geç Kalan',
        count: lateCount,
        color: const Color(0xFFD97706),
        icon: Icons.access_time_filled_rounded,
        filter: DailyAttendanceState.late,
      ),
      _KpiData(
        title: 'Devamsız',
        count: absent,
        color: const Color(0xFFDC2626),
        icon: Icons.cancel_rounded,
        filter: DailyAttendanceState.absent,
      ),
      _KpiData(
        title: 'İzinli',
        count: onLeave,
        color: const Color(0xFF0EA5E9),
        icon: Icons.beach_access_rounded,
        filter: DailyAttendanceState.onLeave,
      ),
      _KpiData(
        title: 'Raporlu',
        count: sick,
        color: const Color(0xFF7C3AED),
        icon: Icons.medical_services_rounded,
        filter: DailyAttendanceState.sickReport,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        // 2 eşit sütun hesaplama
        final cardWidth = (constraints.maxWidth - 8) / 2;
        return Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final item in items)
              _MobileKpiTile(
                data: item,
                width: cardWidth,
                isSelected: activeFilter == item.filter,
                onTap: () {
                  ref
                      .read(pdksDashboardProvider.notifier)
                      .setStateFilter(item.filter);
                },
              ),
          ],
        );
      },
    );
  }
}

class _KpiData {
  final String title;
  final int count;
  final Color color;
  final IconData icon;
  final DailyAttendanceState? filter;

  const _KpiData({
    required this.title,
    required this.count,
    required this.color,
    required this.icon,
    this.filter,
  });
}

class _MobileKpiTile extends StatelessWidget {
  final _KpiData data;
  final double width;
  final bool isSelected;
  final VoidCallback onTap;

  const _MobileKpiTile({
    required this.data,
    required this.width,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    return InkWell(
      borderRadius: BorderRadius.circular(10),
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 140),
        width: width,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isSelected ? data.color.withValues(alpha: 0.12) : pal.card,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(
            color: isSelected ? data.color : pal.border,
            width: isSelected ? 1.5 : 1,
          ),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: data.color.withValues(alpha: 0.14),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Icon(data.icon, color: data.color, size: 16),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    '${data.count}',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w800,
                      color: data.color,
                    ),
                  ),
                  Text(
                    data.title,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      fontSize: 11,
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

/// Arama ve Şube Filtreleme
class _MobileFilterAndSearchSection extends ConsumerWidget {
  const _MobileFilterAndSearchSection();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = HasibuPalette.of(context);
    final branches = ref.watch(pdksDashboardProvider.select((s) => s.branches));
    final selectedBranchId =
        ref.watch(pdksDashboardProvider.select((s) => s.selectedBranchId));

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Şube Filtreleme Çipleri
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: const Text('Tümü', style: TextStyle(fontSize: 11.5)),
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
                      size: 13,
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
          ),
          const SizedBox(height: 8),
          // Hızlı Arama
          TextField(
            onChanged: (val) {
              ref.read(pdksDashboardProvider.notifier).setSearchQuery(val);
              ref.read(mobileUiProvider.notifier).setQuickSearchQuery(val);
            },
            decoration: InputDecoration(
              hintText: 'Personel adı, kart no veya bölüm ara...',
              hintStyle: TextStyle(fontSize: 12.5, color: pal.textMuted),
              prefixIcon: const Icon(Icons.search_rounded, size: 18),
              contentPadding:
                  const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              fillColor: pal.card,
            ),
          ),
          const SizedBox(height: 6),
        ],
      ),
    );
  }
}

/// Personel Durum Listesi (Mobil Uyumlu)
class _MobileEmployeeSliverList extends ConsumerWidget {
  const _MobileEmployeeSliverList();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final items =
        ref.watch(pdksDashboardProvider.select((s) => s.visibleStatuses));
    final densityMode =
        ref.watch(mobileUiProvider.select((s) => s.densityMode));
    final isCompact = densityMode == MobileDensityMode.compact;

    if (items.isEmpty) {
      return const SliverToBoxAdapter(
        child: Padding(
          padding: EdgeInsets.all(32),
          child: Center(
            child: Text(
              'Aramaya veya filtreye uygun personel bulunamadı.',
              style: TextStyle(fontSize: 13),
            ),
          ),
        ),
      );
    }

    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(14, 4, 14, 20),
      sliver: SliverList.separated(
        itemCount: items.length,
        separatorBuilder: (_, __) => SizedBox(height: isCompact ? 4 : 8),
        itemBuilder: (context, index) {
          final item = items[index];
          if (isCompact) {
            return _MobileCompactEmployeeTile(item: item);
          }
          return _MobileComfortableEmployeeCard(item: item);
        },
      ),
    );
  }
}

/// Ferah Görünüm Kartı
class _MobileComfortableEmployeeCard extends ConsumerWidget {
  final EmployeeDailyStatus item;

  const _MobileComfortableEmployeeCard({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = HasibuPalette.of(context);
    final Color badgeColor = switch (item.state) {
      DailyAttendanceState.present => const Color(0xFF059669),
      DailyAttendanceState.late => const Color(0xFFD97706),
      DailyAttendanceState.onLeave => const Color(0xFF0284C7),
      DailyAttendanceState.sickReport => const Color(0xFF7C3AED),
      DailyAttendanceState.absent => const Color(0xFFDC2626),
    };

    final String checkInText;
    if (item.firstCheckIn != null) {
      final outPart = item.lastCheckOut != null &&
              item.lastCheckOut!.id != item.firstCheckIn!.id
          ? ' • Çıkış: ${item.lastCheckOut!.timeFormatted}'
          : '';
      checkInText =
          'Giriş: ${item.firstCheckIn!.timeFormatted}$outPart (${item.firstCheckIn!.verifyMethod.label})';
    } else {
      checkInText = item.leaveRecord?.note ?? 'Giriş Yok';
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
          padding: const EdgeInsets.all(12),
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
                    borderColor: badgeColor.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Flexible(
                              child: Text(
                                item.employee.fullName,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 13.5,
                                  color: pal.textPrimary,
                                ),
                              ),
                            ),
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: badgeColor.withValues(alpha: 0.12),
                                borderRadius: BorderRadius.circular(6),
                              ),
                              child: Text(
                                item.state.label,
                                style: TextStyle(
                                  fontSize: 10.5,
                                  fontWeight: FontWeight.w700,
                                  color: badgeColor,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 2),
                        Text(
                          '${item.department.name} • Kart #${item.employee.cardNo}',
                          style: TextStyle(
                            fontSize: 11,
                            color: pal.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Icon(
                    Icons.chevron_right_rounded,
                    size: 20,
                    color: pal.textMuted,
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                decoration: BoxDecoration(
                  color: pal.subtle,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Row(
                  children: [
                    Icon(
                      item.firstCheckIn != null
                          ? Icons.access_time_filled_rounded
                          : Icons.event_busy_rounded,
                      size: 14,
                      color: badgeColor,
                    ),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        checkInText,
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: pal.textPrimary,
                        ),
                      ),
                    ),
                    Text(
                      'Vardiya: ${item.shift.startTime}-${item.shift.endTime}',
                      style: TextStyle(
                        fontSize: 10.5,
                        color: pal.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Kompakt Liste Satırı (Hızlı Tarama)
class _MobileCompactEmployeeTile extends ConsumerWidget {
  final EmployeeDailyStatus item;

  const _MobileCompactEmployeeTile({required this.item});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = HasibuPalette.of(context);
    final Color badgeColor = switch (item.state) {
      DailyAttendanceState.present => const Color(0xFF059669),
      DailyAttendanceState.late => const Color(0xFFD97706),
      DailyAttendanceState.onLeave => const Color(0xFF0284C7),
      DailyAttendanceState.sickReport => const Color(0xFF7C3AED),
      DailyAttendanceState.absent => const Color(0xFFDC2626),
    };

    final time = item.firstCheckIn?.timeFormatted ?? '-';

    return Material(
      color: pal.card,
      borderRadius: BorderRadius.circular(8),
      child: InkWell(
        key: ValueKey('employee_compact_${item.employee.cardNo}'),
        borderRadius: BorderRadius.circular(8),
        onTap: () => showEmployeeHistoryAndDossierDialog(
          context,
          ref,
          item.employee,
          initialTabIndex: 0,
        ),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: pal.border),
          ),
          child: Row(
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: badgeColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  item.employee.fullName,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: pal.textPrimary,
                  ),
                ),
              ),
              Text(
                item.department.name,
                style: TextStyle(fontSize: 11, color: pal.textSecondary),
              ),
              const SizedBox(width: 10),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                decoration: BoxDecoration(
                  color: badgeColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Text(
                  time,
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                    color: badgeColor,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Mobil Alt Gezinme Çubuğu
class _MobileBottomNavigationBar extends ConsumerWidget {
  const _MobileBottomNavigationBar();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = HasibuPalette.of(context);
    final activeModule =
        ref.watch(pdksDashboardProvider.select((s) => s.activeModule));
    final allowedModules = ref.watch(
      pdksDashboardProvider.select((s) => s.authSession.allowedModules),
    );

    return Container(
      decoration: BoxDecoration(
        color: pal.card,
        border: Border(top: BorderSide(color: pal.border, width: 1)),
      ),
      child: NavigationBar(
        height: 60,
        backgroundColor: pal.card,
        indicatorColor: const Color(0xFF0284C7).withValues(alpha: 0.15),
        selectedIndex: allowedModules.contains(activeModule)
            ? allowedModules.indexOf(activeModule)
            : 0,
        onDestinationSelected: (idx) {
          if (idx >= 0 && idx < allowedModules.length) {
            ref
                .read(pdksDashboardProvider.notifier)
                .selectModule(allowedModules[idx]);
          }
        },
        destinations: [
          for (final m in allowedModules)
            NavigationDestination(
              icon: Icon(_moduleIcon(m), color: pal.textSecondary, size: 20),
              selectedIcon:
                  Icon(_moduleIcon(m), color: const Color(0xFF0284C7), size: 20),
              label: _shortModuleTitle(m),
            ),
        ],
      ),
    );
  }

  static IconData _moduleIcon(HasibuModule m) {
    switch (m) {
      case HasibuModule.pdksHr:
        return Icons.fingerprint_rounded;
      case HasibuModule.leanProduction:
        return Icons.precision_manufacturing_rounded;
      case HasibuModule.preAccounting:
        return Icons.account_balance_wallet_rounded;
      case HasibuModule.employeePortal:
        return Icons.badge_rounded;
      case HasibuModule.systemSettings:
        return Icons.tune_rounded;
    }
  }

  static String _shortModuleTitle(HasibuModule m) {
    switch (m) {
      case HasibuModule.pdksHr:
        return 'PDKS & İK';
      case HasibuModule.leanProduction:
        return 'Yalın Üretim';
      case HasibuModule.preAccounting:
        return 'Ön Muhasebe';
      case HasibuModule.employeePortal:
        return 'Portalım';
      case HasibuModule.systemSettings:
        return 'Ayarlar';
    }
  }
}
