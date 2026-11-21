import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/pdks_models.dart';
import '../providers/pdks_providers.dart';
import 'hasibu_settings_view.dart';

enum _PortalEmploymentFilter { active, terminated, all }

class EmployeeSelfServicePortalView extends ConsumerStatefulWidget {
  const EmployeeSelfServicePortalView({super.key});

  @override
  ConsumerState<EmployeeSelfServicePortalView> createState() =>
      _EmployeeSelfServicePortalViewState();
}

class _EmployeeSelfServicePortalViewState
    extends ConsumerState<EmployeeSelfServicePortalView> {
  late final TextEditingController _searchCtrl;
  _PortalEmploymentFilter _employmentFilter = _PortalEmploymentFilter.active;
  int? _branchFilterId;
  HrRequestStatus? _requestStatusFilter;

  @override
  void initState() {
    super.initState();
    _searchCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  List<EmployeeDailyStatus> _filterDirectory(
    List<EmployeeDailyStatus> statuses, {
    required _PortalEmploymentFilter employmentFilter,
    required int? branchFilterId,
    required String query,
  }) {
    final q = query.trim().toUpperCase();
    final filtered = statuses.where((s) {
      final isSeparated = s.employee.isSeparatedNow;
      if (employmentFilter == _PortalEmploymentFilter.active && isSeparated) {
        return false;
      }
      if (employmentFilter == _PortalEmploymentFilter.terminated &&
          !isSeparated) {
        return false;
      }
      if (branchFilterId != null && s.branch.id != branchFilterId) {
        return false;
      }
      if (q.isEmpty) return true;
      return s.employee.fullName.toUpperCase().contains(q) ||
          s.employee.cardNo.toUpperCase().contains(q) ||
          s.department.name.toUpperCase().contains(q) ||
          s.employee.title.toUpperCase().contains(q);
    }).toList(growable: false);

    return filtered
      ..sort((a, b) {
        final sepCmp = (a.employee.isSeparatedNow ? 1 : 0)
            .compareTo(b.employee.isSeparatedNow ? 1 : 0);
        if (sepCmp != 0) return sepCmp;
        return a.employee.fullName.compareTo(b.employee.fullName);
      });
  }

  void _stepEmployee(
    List<EmployeeDailyStatus> directory,
    EmployeeDailyStatus current,
    int delta,
  ) {
    if (directory.isEmpty) return;
    final idx = directory.indexWhere(
      (s) => s.employee.cardNo == current.employee.cardNo,
    );
    final nextIdx = idx < 0
        ? 0
        : (idx + delta + directory.length) % directory.length;
    ref
        .read(pdksDashboardProvider.notifier)
        .setSelfServiceEmployee(directory[nextIdx].employee.cardNo);
  }

  Future<void> _openMobileDirectoryPicker(
    BuildContext context,
    List<EmployeeDailyStatus> allStatuses,
    List<Branch> branches,
    String currentCardNo,
  ) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetCtx) => StatefulBuilder(
        builder: (ctx, setSheetState) {
          final filtered = _filterDirectory(
            allStatuses,
            employmentFilter: _employmentFilter,
            branchFilterId: _branchFilterId,
            query: _searchCtrl.text,
          );
          return SizedBox(
            height: MediaQuery.sizeOf(ctx).height * 0.82,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: _PortalEmployeeDirectoryPanel(
                allStatuses: allStatuses,
                filteredStatuses: filtered,
                branches: branches,
                selectedCardNo: currentCardNo,
                employmentFilter: _employmentFilter,
                branchFilterId: _branchFilterId,
                searchController: _searchCtrl,
                onSearchChanged: () {
                  setState(() {});
                  setSheetState(() {});
                },
                onEmploymentFilterChanged: (f) {
                  setState(() => _employmentFilter = f);
                  setSheetState(() {});
                },
                onBranchChanged: (bId) {
                  setState(() => _branchFilterId = bId);
                  setSheetState(() {});
                },
                onSelectEmployee: (cardNo) {
                  ref
                      .read(pdksDashboardProvider.notifier)
                      .setSelfServiceEmployee(cardNo);
                  Navigator.of(sheetCtx).pop();
                },
                onClose: () => Navigator.of(sheetCtx).pop(),
              ),
            ),
          );
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final statuses =
        ref.watch(pdksDashboardProvider.select((s) => s.dailyStatuses));
    final selectedCard = ref.watch(
      pdksDashboardProvider.select((s) => s.activeSelfServiceCardNo),
    );
    final authRole =
        ref.watch(pdksDashboardProvider.select((s) => s.authSession.role));
    final companySettings = ref.watch(
      pdksDashboardProvider.select((s) => s.companySettings),
    );
    final branches =
        ref.watch(pdksDashboardProvider.select((s) => s.branches));
    final allDocs = ref.watch(
      pdksDashboardProvider.select((s) => s.allPersonnelDocuments),
    );
    final allRequests =
        ref.watch(pdksDashboardProvider.select((s) => s.allHrRequests));

    if (statuses.isEmpty) {
      return const Center(child: Text('Personel verisi bulunamadı.'));
    }

    final defaultEmployee = statuses.firstWhere(
      (s) => !s.employee.isSeparatedNow,
      orElse: () => statuses.first,
    );
    final current = statuses.firstWhere(
      (s) => s.employee.cardNo == selectedCard,
      orElse: () => defaultEmployee,
    );
    final emp = current.employee;
    final empDocs = allDocs
        .where((d) => d.employeeId == emp.id)
        .toList(growable: false);
    final empRequests = allRequests
        .where((r) => r.employeeId == emp.id)
        .toList(growable: false);
    final historyEntries =
        ref.read(pdksDashboardProvider.notifier).getEmployeeHistory(emp);

    final isAdminPreview = authRole == UserRole.admin;
    final directory = _filterDirectory(
      statuses,
      employmentFilter: _employmentFilter,
      branchFilterId: _branchFilterId,
      query: _searchCtrl.text,
    );

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWideMasterDetail =
            isAdminPreview && constraints.maxWidth >= 1080;
        final EdgeInsets pagePadding = EdgeInsets.all(
          constraints.maxWidth < 600 ? 12 : 20,
        );

        final workspace = _PortalWorkspaceContent(
          current: current,
          companySettings: companySettings,
          empDocs: empDocs,
          empRequests: empRequests,
          historyEntries: historyEntries,
          requestStatusFilter: _requestStatusFilter,
          onRequestFilterChanged: (status) =>
              setState(() => _requestStatusFilter = status),
          isAdminPreview: isAdminPreview,
          isWideMasterDetail: isWideMasterDetail,
          directoryPositionLabel: _directoryPositionText(directory, emp.cardNo),
          onPrevEmployee: directory.length > 1
              ? () => _stepEmployee(directory, current, -1)
              : null,
          onNextEmployee: directory.length > 1
              ? () => _stepEmployee(directory, current, 1)
              : null,
          onOpenDirectoryModal: () => _openMobileDirectoryPicker(
            context,
            statuses,
            branches,
            emp.cardNo,
          ),
        );

        if (!isWideMasterDetail) {
          return ListView(
            padding: pagePadding,
            children: [workspace],
          );
        }

        final double panelHeight = constraints.hasBoundedHeight
            ? (constraints.maxHeight - pagePadding.vertical).clamp(360.0, 820.0)
            : 640.0;

        return Padding(
          padding: pagePadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 320,
                height: panelHeight,
                child: _PortalEmployeeDirectoryPanel(
                  allStatuses: statuses,
                  filteredStatuses: directory,
                  branches: branches,
                  selectedCardNo: emp.cardNo,
                  employmentFilter: _employmentFilter,
                  branchFilterId: _branchFilterId,
                  searchController: _searchCtrl,
                  onSearchChanged: () => setState(() {}),
                  onEmploymentFilterChanged: (f) =>
                      setState(() => _employmentFilter = f),
                  onBranchChanged: (bId) =>
                      setState(() => _branchFilterId = bId),
                  onSelectEmployee: (cardNo) => ref
                      .read(pdksDashboardProvider.notifier)
                      .setSelfServiceEmployee(cardNo),
                ),
              ),
              const SizedBox(width: 18),
              Expanded(
                child: SingleChildScrollView(
                  child: workspace,
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  String _directoryPositionText(
    List<EmployeeDailyStatus> directory,
    String currentCardNo,
  ) {
    if (directory.isEmpty) return '0 / 0';
    final idx =
        directory.indexWhere((s) => s.employee.cardNo == currentCardNo);
    return idx < 0 ? '${directory.length} kişi' : '${idx + 1} / ${directory.length}';
  }
}

class _PortalEmployeeDirectoryPanel extends StatelessWidget {
  final List<EmployeeDailyStatus> allStatuses;
  final List<EmployeeDailyStatus> filteredStatuses;
  final List<Branch> branches;
  final String selectedCardNo;
  final _PortalEmploymentFilter employmentFilter;
  final int? branchFilterId;
  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final ValueChanged<_PortalEmploymentFilter> onEmploymentFilterChanged;
  final ValueChanged<int?> onBranchChanged;
  final ValueChanged<String> onSelectEmployee;
  final VoidCallback? onClose;

  const _PortalEmployeeDirectoryPanel({
    required this.allStatuses,
    required this.filteredStatuses,
    required this.branches,
    required this.selectedCardNo,
    required this.employmentFilter,
    required this.branchFilterId,
    required this.searchController,
    required this.onSearchChanged,
    required this.onEmploymentFilterChanged,
    required this.onBranchChanged,
    required this.onSelectEmployee,
    this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    final totalCount = allStatuses.length;
    final separatedCount =
        allStatuses.where((s) => s.employee.isSeparatedNow).length;
    final activeCount = totalCount - separatedCount;

    return Container(
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Icon(
                      Icons.people_alt_rounded,
                      size: 18,
                      color: Color(0xFF0284C7),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Personel Rehberi',
                        style: TextStyle(
                          fontSize: 14.5,
                          fontWeight: FontWeight.w800,
                          color: pal.textPrimary,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 3,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Text(
                        '${filteredStatuses.length}',
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w800,
                          color: Color(0xFF0284C7),
                        ),
                      ),
                    ),
                    if (onClose != null) ...[
                      const SizedBox(width: 4),
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        onPressed: onClose,
                        icon: const Icon(Icons.close_rounded, size: 20),
                      ),
                    ],
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey('portal_employee_search_field'),
                  controller: searchController,
                  onChanged: (_) => onSearchChanged(),
                  decoration: InputDecoration(
                    isDense: true,
                    hintText: 'Ad, kart no, bölüm veya unvan ara...',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    suffixIcon: searchController.text.isNotEmpty
                        ? IconButton(
                            icon: const Icon(Icons.clear_rounded, size: 16),
                            onPressed: () {
                              searchController.clear();
                              onSearchChanged();
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        'Aktif ($activeCount)',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      selected:
                          employmentFilter == _PortalEmploymentFilter.active,
                      onSelected: (_) => onEmploymentFilterChanged(
                        _PortalEmploymentFilter.active,
                      ),
                    ),
                    ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        'Ayrılan ($separatedCount)',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      selected: employmentFilter ==
                          _PortalEmploymentFilter.terminated,
                      onSelected: (_) => onEmploymentFilterChanged(
                        _PortalEmploymentFilter.terminated,
                      ),
                    ),
                    ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        'Tümü ($totalCount)',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      selected: employmentFilter == _PortalEmploymentFilter.all,
                      onSelected: (_) =>
                          onEmploymentFilterChanged(_PortalEmploymentFilter.all),
                    ),
                  ],
                ),
                if (branches.length > 1) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    isExpanded: true,
                    initialValue: branchFilterId,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Şube Filtresi',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
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
                    onChanged: onBranchChanged,
                  ),
                ],
              ],
            ),
          ),
          Divider(height: 1, color: pal.border),
          Expanded(
            child: filteredStatuses.isEmpty
                ? Padding(
                    padding: const EdgeInsets.all(24),
                    child: Center(
                      child: Text(
                        'Arama veya filtreye uygun personel bulunamadı.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12.5,
                          color: pal.textSecondary,
                        ),
                      ),
                    ),
                  )
                : ListView.separated(
                    padding: const EdgeInsets.all(8),
                    itemCount: filteredStatuses.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 4),
                    itemBuilder: (context, index) {
                      final item = filteredStatuses[index];
                      final emp = item.employee;
                      final isSelected = emp.cardNo == selectedCardNo;
                      final Color statusColor =
                          attendanceStateColor(item.state);

                      return Material(
                        color: isSelected
                            ? const Color(0xFF0284C7).withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          key: ValueKey('portal_employee_tile_${emp.cardNo}'),
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => onSelectEmployee(emp.cardNo),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 9,
                            ),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(10),
                              border: Border.all(
                                color: isSelected
                                    ? const Color(0xFF0284C7)
                                    : Colors.transparent,
                                width: 1.2,
                              ),
                            ),
                            child: Row(
                              children: [
                                EmployeeProfileAvatar(
                                  employee: emp,
                                  size: 36,
                                  borderColor:
                                      statusColor.withValues(alpha: 0.55),
                                ),
                                const SizedBox(width: 10),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        emp.fullName,
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 12.5,
                                          fontWeight: isSelected
                                              ? FontWeight.w800
                                              : FontWeight.w700,
                                          color: pal.textPrimary,
                                        ),
                                      ),
                                      const SizedBox(height: 2),
                                      Text(
                                        '#${emp.cardNo} • ${item.department.name}',
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: pal.textSecondary,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 6),
                                Container(
                                  width: 9,
                                  height: 9,
                                  decoration: BoxDecoration(
                                    color: statusColor,
                                    shape: BoxShape.circle,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}

class _PortalWorkspaceContent extends ConsumerWidget {
  final EmployeeDailyStatus current;
  final CompanySettings companySettings;
  final List<PersonnelDocument> empDocs;
  final List<HrRequest> empRequests;
  final List<EmployeeHistoryDayEntry> historyEntries;
  final HrRequestStatus? requestStatusFilter;
  final ValueChanged<HrRequestStatus?> onRequestFilterChanged;
  final bool isAdminPreview;
  final bool isWideMasterDetail;
  final String directoryPositionLabel;
  final VoidCallback? onPrevEmployee;
  final VoidCallback? onNextEmployee;
  final VoidCallback onOpenDirectoryModal;

  const _PortalWorkspaceContent({
    required this.current,
    required this.companySettings,
    required this.empDocs,
    required this.empRequests,
    required this.historyEntries,
    required this.requestStatusFilter,
    required this.onRequestFilterChanged,
    required this.isAdminPreview,
    required this.isWideMasterDetail,
    required this.directoryPositionLabel,
    required this.onPrevEmployee,
    required this.onNextEmployee,
    required this.onOpenDirectoryModal,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = HasibuPalette.of(context);
    final emp = current.employee;
    final bool isSeparated = emp.isSeparatedNow;
    final bool hasScheduledExit = emp.hasExitDate && !isSeparated;
    final activeEmployeeModules = HasibuModule.filterActive(emp.allowedModules);

    final mandatoryCategories = PersonnelDocumentCategory.values
        .where((c) => c.isMandatory)
        .toList(growable: false);
    final uploadedCategorySet = empDocs.map((d) => d.category).toSet();
    final int completedMandatory = mandatoryCategories
        .where((c) => uploadedCategorySet.contains(c))
        .length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (isAdminPreview)
          _PortalAdminPreviewBar(
            current: current,
            isWideMasterDetail: isWideMasterDetail,
            positionLabel: directoryPositionLabel,
            onPrev: onPrevEmployee,
            onNext: onNextEmployee,
            onOpenPicker: onOpenDirectoryModal,
          ),
        if (isAdminPreview) const SizedBox(height: 14),
        _PortalHeroIdentityCard(
          current: current,
          companySettings: companySettings,
          activeModules: activeEmployeeModules,
          isSeparated: isSeparated,
          hasScheduledExit: hasScheduledExit,
        ),
        if (isSeparated) ...[
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFFDC2626).withValues(alpha: 0.35),
              ),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.info_outline_rounded,
                  size: 19,
                  color: Color(0xFFDC2626),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Bu personel ${PdksDashboardNotifier.formatDisplayDate(emp.normalizedExitDate!, includeTodayBadge: false)} tarihinde işten ayrılmıştır. Arşiv görünümüdür; devamsızlık istatistiklerine dahil edilmez ve portal oturumu kapalıdır.',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: pal.textPrimary,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        _PortalKpiGrid(
          current: current,
          completedMandatoryDocs: completedMandatory,
          totalMandatoryDocs: mandatoryCategories.length,
          totalDocs: empDocs.length,
        ),
        const SizedBox(height: 14),
        _PortalQuickActionHub(
          employee: emp,
          isSeparated: isSeparated,
        ),
        const SizedBox(height: 14),
        LayoutBuilder(
          builder: (context, constraints) {
            final timelineCard = _PortalAttendanceTimelineCard(
              employee: emp,
              entries: historyEntries,
            );
            final requestsCard = _PortalHrRequestsCard(
              requests: empRequests,
              statusFilter: requestStatusFilter,
              onFilterChanged: onRequestFilterChanged,
            );
            if (constraints.maxWidth >= 900) {
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(child: timelineCard),
                  const SizedBox(width: 14),
                  Expanded(child: requestsCard),
                ],
              );
            }
            return Column(
              children: [
                timelineCard,
                const SizedBox(height: 14),
                requestsCard,
              ],
            );
          },
        ),
        const SizedBox(height: 14),
        Container(
          width: double.infinity,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: pal.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: pal.border),
          ),
          child: const UserThemeSelectorBar(),
        ),
      ],
    );
  }
}

class _PortalAdminPreviewBar extends StatelessWidget {
  final EmployeeDailyStatus current;
  final bool isWideMasterDetail;
  final String positionLabel;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onOpenPicker;

  const _PortalAdminPreviewBar({
    required this.current,
    required this.isWideMasterDetail,
    required this.positionLabel,
    required this.onPrev,
    required this.onNext,
    required this.onOpenPicker,
  });

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    final emp = current.employee;
    final stateColor = attendanceStateColor(current.state);

    if (isWideMasterDetail) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: pal.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: pal.border),
        ),
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF0284C7).withValues(alpha: 0.13),
                borderRadius: BorderRadius.circular(8),
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.visibility_rounded,
                    size: 14,
                    color: Color(0xFF0284C7),
                  ),
                  SizedBox(width: 5),
                  Text(
                    'Yönetici Önizleme',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w800,
                      color: Color(0xFF0284C7),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Text(
                'Seçili Personel: ${emp.fullName} (#${emp.cardNo})',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: pal.textPrimary,
                ),
              ),
            ),
            Text(
              positionLabel,
              style: TextStyle(
                fontSize: 11.5,
                fontWeight: FontWeight.w600,
                color: pal.textSecondary,
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Önceki Personel',
              onPressed: onPrev,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: 'Sonraki Personel',
              onPressed: onNext,
              icon: const Icon(Icons.chevron_right_rounded),
            ),
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pal.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: const ValueKey('portal_employee_picker_button'),
              borderRadius: BorderRadius.circular(10),
              onTap: onOpenPicker,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    EmployeeProfileAvatar(
                      employee: emp,
                      size: 38,
                      borderColor: stateColor.withValues(alpha: 0.55),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            emp.fullName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13.5,
                              fontWeight: FontWeight.w800,
                              color: pal.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            '#${emp.cardNo} • ${current.department.name}',
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
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 5,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0284C7).withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: const Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'Personel Seç',
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                          SizedBox(width: 3),
                          Icon(
                            Icons.expand_more_rounded,
                            size: 16,
                            color: Color(0xFF0284C7),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Önceki Personel',
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            visualDensity: VisualDensity.compact,
            tooltip: 'Sonraki Personel',
            onPressed: onNext,
            icon: const Icon(Icons.chevron_right_rounded),
          ),
        ],
      ),
    );
  }
}

class _PortalHeroIdentityCard extends StatelessWidget {
  final EmployeeDailyStatus current;
  final CompanySettings companySettings;
  final List<HasibuModule> activeModules;
  final bool isSeparated;
  final bool hasScheduledExit;

  const _PortalHeroIdentityCard({
    required this.current,
    required this.companySettings,
    required this.activeModules,
    required this.isSeparated,
    required this.hasScheduledExit,
  });

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    final emp = current.employee;
    final stateColor = attendanceStateColor(current.state);

    final (Color empBg, Color empFg, String empLabel) = isSeparated
        ? (
            const Color(0xFFDC2626).withValues(alpha: 0.14),
            const Color(0xFFDC2626),
            'İŞTEN AYRILDI',
          )
        : (hasScheduledExit
            ? (
                const Color(0xFFD97706).withValues(alpha: 0.14),
                const Color(0xFFD97706),
                'ÇIKIŞ PLANLI',
              )
            : (
                const Color(0xFF059669).withValues(alpha: 0.14),
                const Color(0xFF059669),
                'AKTİF PERSONEL',
              ));

    final Color sgkColor = emp.sgkActive
        ? const Color(0xFF059669)
        : const Color(0xFF64748B);

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  pal.subtle,
                  const Color(0xFF0284C7).withValues(
                    alpha: pal.isDark ? 0.12 : 0.06,
                  ),
                ],
              ),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: pal.border),
            ),
            child: LayoutBuilder(
              builder: (headerCtx, constraints) {
                final companyInfo = Row(
                  children: [
                    CompanyLogoBadge(
                      settings: companySettings,
                      size: 34,
                      borderRadius: 9,
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            companySettings.companyName,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontWeight: FontWeight.w800,
                              fontSize: 13,
                              color: pal.textPrimary,
                            ),
                          ),
                          Text(
                            'Kurumsal Personel Self-Servis Portalı',
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 11,
                              color: pal.textSecondary,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                );
                final pills = Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    _PortalPillBadge(
                      label: empLabel,
                      bg: empBg,
                      fg: empFg,
                    ),
                    _PortalPillBadge(
                      label: emp.sgkActive ? 'SGK AKTİF' : 'SGK PASİF',
                      bg: sgkColor.withValues(alpha: 0.14),
                      fg: sgkColor,
                    ),
                  ],
                );
                if (constraints.maxWidth >= 520) {
                  return Row(
                    children: [
                      Expanded(child: companyInfo),
                      const SizedBox(width: 10),
                      pills,
                    ],
                  );
                }
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    companyInfo,
                    const SizedBox(height: 8),
                    pills,
                  ],
                );
              },
            ),
          ),
          const SizedBox(height: 16),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              EmployeeProfileAvatar(
                employee: emp,
                size: 64,
                borderColor: stateColor.withValues(alpha: 0.6),
              ),
              const SizedBox(width: 14),
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
                            color: pal.textPrimary,
                            fontSize: 19,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 3,
                          ),
                          decoration: BoxDecoration(
                            color: pal.chip,
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            '#${emp.cardNo}',
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
                    Text(
                      '${emp.title} • ${current.department.name} • ${current.branch.name}',
                      style: TextStyle(
                        color: pal.textSecondary,
                        fontSize: 12.5,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _PortalPillBadge(
                icon: Icons.login_rounded,
                label:
                    'İşe Giriş: ${PdksDashboardNotifier.formatDisplayDate(emp.hireDate, includeTodayBadge: false)}',
                bg: pal.chip,
                fg: pal.textPrimary,
              ),
              if (emp.hasExitDate)
                _PortalPillBadge(
                  icon: Icons.logout_rounded,
                  label:
                      'İşten Çıkış: ${PdksDashboardNotifier.formatDisplayDate(emp.normalizedExitDate!, includeTodayBadge: false)}',
                  bg: const Color(0xFFDC2626).withValues(alpha: 0.12),
                  fg: const Color(0xFFDC2626),
                ),
              _PortalPillBadge(
                icon: Icons.workspace_premium_outlined,
                label: 'Kıdem: ${emp.tenureSummaryAt()}',
                bg: const Color(0xFF0284C7).withValues(alpha: 0.11),
                fg: const Color(0xFF0284C7),
              ),
              _PortalPillBadge(
                icon: Icons.schedule_rounded,
                label:
                    'Vardiya: ${current.shift.startTime} - ${current.shift.endTime}',
                bg: pal.chip,
                fg: pal.textSecondary,
              ),
            ],
          ),
          if (activeModules.isNotEmpty) ...[
            const SizedBox(height: 8),
            Wrap(
              spacing: 6,
              runSpacing: 4,
              children: [
                for (final mod in activeModules)
                  _PortalPillBadge(
                    label: 'Yetki: ${mod.title}',
                    bg: const Color(0xFF0284C7).withValues(alpha: 0.11),
                    fg: const Color(0xFF0284C7),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

class _PortalKpiGrid extends StatelessWidget {
  final EmployeeDailyStatus current;
  final int completedMandatoryDocs;
  final int totalMandatoryDocs;
  final int totalDocs;

  const _PortalKpiGrid({
    required this.current,
    required this.completedMandatoryDocs,
    required this.totalMandatoryDocs,
    required this.totalDocs,
  });

  @override
  Widget build(BuildContext context) {
    final emp = current.employee;
    final stateColor = attendanceStateColor(current.state);

    final String todaySub;
    if (current.firstCheckIn != null) {
      final outPart = current.lastCheckOut != null &&
              current.lastCheckOut!.id != current.firstCheckIn!.id
          ? ' • Çıkış: ${current.lastCheckOut!.timeFormatted}'
          : ' • Çıkış bekleniyor';
      todaySub = 'Giriş: ${current.firstCheckIn!.timeFormatted}$outPart';
    } else if (current.leaveRecord != null) {
      todaySub = current.leaveRecord!.note;
    } else if (current.state == DailyAttendanceState.terminated &&
        emp.hasExitDate) {
      todaySub =
          'Ayrılış: ${PdksDashboardNotifier.formatDisplayDate(emp.normalizedExitDate!, includeTodayBadge: false)}';
    } else {
      todaySub = '${current.shift.startTime} - ${current.shift.endTime}';
    }

    final double leaveProgress = emp.annualLeaveEntitlement <= 0
        ? 0.0
        : (emp.usedAnnualLeave / emp.annualLeaveEntitlement).clamp(0.0, 1.0);
    final double docsProgress = totalMandatoryDocs <= 0
        ? 1.0
        : (completedMandatoryDocs / totalMandatoryDocs).clamp(0.0, 1.0);

    final String tenureValue = emp.tenureYearsAt() > 0
        ? '${emp.tenureYearsAt()} Yıl Kıdem'
        : emp.tenureSummaryAt();
    final String hireSub = emp.hasExitDate
        ? 'Giriş: ${PdksDashboardNotifier.formatDisplayDate(emp.hireDate, includeTodayBadge: false)} • Çıkış: ${PdksDashboardNotifier.formatDisplayDate(emp.normalizedExitDate!, includeTodayBadge: false)}'
        : 'Giriş: ${PdksDashboardNotifier.formatDisplayDate(emp.hireDate, includeTodayBadge: false)} • 4857 Hak: ${emp.statutoryAnnualLeaveEntitlement} Gün';

    final cards = <Widget>[
      _PortalKpiCard(
        icon: Icons.fact_check_rounded,
        accent: stateColor,
        label: 'Bugünkü Yoklama Durumu',
        value: current.lateMinutes > 0
            ? '${current.state.label} (+${current.lateMinutes} dk)'
            : current.state.label,
        subValue: todaySub,
      ),
      _PortalKpiCard(
        icon: Icons.beach_access_rounded,
        accent: const Color(0xFF0284C7),
        label: 'Kalan Yıllık İzin',
        value: '${emp.remainingAnnualLeave} Gün',
        subValue:
            'Hak: ${emp.annualLeaveEntitlement} • Kullanılan: ${emp.usedAnnualLeave}',
        progress: leaveProgress,
      ),
      _PortalKpiCard(
        icon: Icons.work_history_rounded,
        accent: const Color(0xFF059669),
        label: 'İstihdam & Kıdem',
        value: tenureValue,
        subValue: hireSub,
      ),
      _PortalKpiCard(
        icon: Icons.folder_shared_rounded,
        accent: completedMandatoryDocs >= totalMandatoryDocs
            ? const Color(0xFF059669)
            : const Color(0xFFD97706),
        label: 'Özlük Dosyası Durumu',
        value: '$completedMandatoryDocs / $totalMandatoryDocs Zorunlu',
        subValue: 'Toplam $totalDocs dijital evrak kayıtlı',
        progress: docsProgress,
      ),
    ];

    return LayoutBuilder(
      builder: (context, constraints) {
        final double width = constraints.maxWidth;
        final int cols = width >= 920 ? 4 : 2;
        final double spacing = 10;
        final double cardWidth = (width - spacing * (cols - 1)) / cols;
        return Wrap(
          spacing: spacing,
          runSpacing: spacing,
          children: [
            for (final card in cards) SizedBox(width: cardWidth, child: card),
          ],
        );
      },
    );
  }
}

class _PortalKpiCard extends StatelessWidget {
  final IconData icon;
  final Color accent;
  final String label;
  final String value;
  final String subValue;
  final double? progress;

  const _PortalKpiCard({
    required this.icon,
    required this.accent,
    required this.label,
    required this.value,
    required this.subValue,
    this.progress,
  });

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(14),
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
              Container(
                padding: const EdgeInsets.all(6),
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.13),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Icon(icon, size: 16, color: accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  label,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 11.5,
                    fontWeight: FontWeight.w600,
                    color: pal.textSecondary,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w800,
              color: pal.textPrimary,
            ),
          ),
          if (progress != null) ...[
            const SizedBox(height: 7),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 5,
                backgroundColor: pal.chip,
                color: accent,
              ),
            ),
          ],
          const SizedBox(height: 6),
          Text(
            subValue,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(fontSize: 11, color: pal.textMuted),
          ),
        ],
      ),
    );
  }
}

class _PortalQuickActionHub extends ConsumerWidget {
  final Employee employee;
  final bool isSeparated;

  const _PortalQuickActionHub({
    required this.employee,
    required this.isSeparated,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = HasibuPalette.of(context);
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pal.border),
      ),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          FilledButton.icon(
            key: const ValueKey('self_service_new_request_button'),
            onPressed: isSeparated
                ? null
                : () => showCreateHrRequestDialog(
                      context,
                      ref,
                      employee: employee,
                    ),
            icon: const Icon(Icons.add_task_rounded, size: 18),
            label: const Text('Yeni İK Talebi Oluştur'),
          ),
          FilledButton.tonalIcon(
            onPressed: isSeparated
                ? null
                : () => showCreateHrRequestDialog(
                      context,
                      ref,
                      employee: employee,
                      initialRequestType: HrRequestType.annualLeave,
                    ),
            icon: const Icon(Icons.beach_access_outlined, size: 17),
            label: const Text('İzin Talebi'),
          ),
          FilledButton.tonalIcon(
            onPressed: isSeparated
                ? null
                : () => showCreateHrRequestDialog(
                      context,
                      ref,
                      employee: employee,
                      initialRequestType: HrRequestType.missingPunchCorrection,
                    ),
            icon: const Icon(Icons.edit_calendar_outlined, size: 17),
            label: const Text('Hareket Düzeltme'),
          ),
          OutlinedButton.icon(
            onPressed: () => showEmployeeHistoryAndDossierDialog(
              context,
              ref,
              employee,
              initialTabIndex: 0,
            ),
            icon: const Icon(Icons.history_rounded, size: 17),
            label: const Text('Giriş-Çıkış Geçmişi'),
          ),
          OutlinedButton.icon(
            onPressed: () => showEmployeeHistoryAndDossierDialog(
              context,
              ref,
              employee,
              initialTabIndex: 1,
            ),
            icon: const Icon(Icons.folder_shared_outlined, size: 17),
            label: const Text('Özlük & Evraklar'),
          ),
        ],
      ),
    );
  }
}

class _PortalAttendanceTimelineCard extends ConsumerWidget {
  final Employee employee;
  final List<EmployeeHistoryDayEntry> entries;

  const _PortalAttendanceTimelineCard({
    required this.employee,
    required this.entries,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pal = HasibuPalette.of(context);
    final recent = entries.take(7).toList(growable: false);
    final int onTimeCount =
        entries.where((e) => e.state == DailyAttendanceState.present).length;
    final int lateCount =
        entries.where((e) => e.state == DailyAttendanceState.late).length;
    final int leaveCount = entries
        .where(
          (e) =>
              e.state == DailyAttendanceState.onLeave ||
              e.state == DailyAttendanceState.sickReport,
        )
        .length;
    final int overtimeMins =
        entries.fold<int>(0, (sum, e) => sum + e.overtimeMinutes);

    return Container(
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
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Expanded(
                child: Text(
                  'Son Yoklama Hareketleri',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: pal.textPrimary,
                  ),
                ),
              ),
              TextButton(
                onPressed: () => showEmployeeHistoryAndDossierDialog(
                  context,
                  ref,
                  employee,
                  initialTabIndex: 0,
                ),
                child: const Text('Tüm Geçmişi Aç'),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              _PortalPillBadge(
                label: 'Zamanında: $onTimeCount',
                bg: const Color(0xFF059669).withValues(alpha: 0.12),
                fg: const Color(0xFF059669),
              ),
              _PortalPillBadge(
                label: 'Geç: $lateCount',
                bg: const Color(0xFFD97706).withValues(alpha: 0.12),
                fg: const Color(0xFFD97706),
              ),
              _PortalPillBadge(
                label: 'İzin/Rapor: $leaveCount',
                bg: const Color(0xFF0284C7).withValues(alpha: 0.12),
                fg: const Color(0xFF0284C7),
              ),
              if (overtimeMins > 0)
                _PortalPillBadge(
                  label: 'Mesai: +$overtimeMins dk',
                  bg: const Color(0xFF059669).withValues(alpha: 0.12),
                  fg: const Color(0xFF059669),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (recent.isEmpty)
            Text(
              'Henüz kayıtlı yoklama hareketi bulunmuyor.',
              style: TextStyle(fontSize: 12, color: pal.textSecondary),
            ),
          for (final entry in recent)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: pal.subtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: pal.border),
              ),
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: pal.card,
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: pal.border),
                    ),
                    child: Text(
                      PdksDashboardNotifier.formatDisplayDate(
                        entry.dateKey,
                        includeTodayBadge: false,
                      ),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: pal.textPrimary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _timelineDetailText(entry),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: pal.textPrimary,
                          ),
                        ),
                        if (entry.workedMinutes > 0)
                          Text(
                            'Net: ${entry.workedDurationFormatted}',
                            style: TextStyle(
                              fontSize: 11,
                              color: pal.textSecondary,
                            ),
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 6),
                  _PortalPillBadge(
                    label: entry.lateMinutes > 0
                        ? '${entry.state.label} (+${entry.lateMinutes} dk)'
                        : entry.state.label,
                    bg: attendanceStateColor(entry.state)
                        .withValues(alpha: 0.14),
                    fg: attendanceStateColor(entry.state),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  String _timelineDetailText(EmployeeHistoryDayEntry entry) {
    if (entry.firstCheckIn != null) {
      final outPart = entry.lastCheckOut != null &&
              entry.lastCheckOut!.id != entry.firstCheckIn!.id
          ? ' → ${entry.lastCheckOut!.timeFormatted}'
          : '';
      return '${entry.firstCheckIn!.timeFormatted}$outPart';
    }
    if (entry.leaveRecord != null) {
      return entry.leaveRecord!.note;
    }
    return switch (entry.state) {
      DailyAttendanceState.terminated => 'İşten ayrılış sonrası dönem',
      DailyAttendanceState.notYetHired => 'İşe giriş tarihi öncesi',
      _ => 'Cihaz / mobil okutma kaydı yok',
    };
  }
}

class _PortalHrRequestsCard extends StatelessWidget {
  final List<HrRequest> requests;
  final HrRequestStatus? statusFilter;
  final ValueChanged<HrRequestStatus?> onFilterChanged;

  const _PortalHrRequestsCard({
    required this.requests,
    required this.statusFilter,
    required this.onFilterChanged,
  });

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    final filtered = statusFilter == null
        ? requests
        : requests
            .where((r) => r.status == statusFilter)
            .toList(growable: false);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pal.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: double.infinity,
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'İK Taleplerim (${requests.length})',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w800,
                    color: pal.textPrimary,
                  ),
                ),
                Text(
                  'Onaylananlar puantaja işlenir',
                  style: TextStyle(fontSize: 11, color: pal.textSecondary),
                ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 6,
            runSpacing: 6,
            children: [
              ChoiceChip(
                visualDensity: VisualDensity.compact,
                label: const Text('Tümü', style: TextStyle(fontSize: 11.5)),
                selected: statusFilter == null,
                onSelected: (_) => onFilterChanged(null),
              ),
              for (final st in HrRequestStatus.values)
                ChoiceChip(
                  visualDensity: VisualDensity.compact,
                  label: Text(
                    st.label,
                    style: const TextStyle(fontSize: 11.5),
                  ),
                  selected: statusFilter == st,
                  onSelected: (_) =>
                      onFilterChanged(statusFilter == st ? null : st),
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (filtered.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: pal.subtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: pal.border),
              ),
              child: Text(
                requests.isEmpty
                    ? 'Henüz oluşturduğunuz bir izin, fazla mesai veya hareket düzeltme talebi bulunmuyor.'
                    : 'Seçili duruma ait talep bulunmuyor.',
                style: TextStyle(fontSize: 12, color: pal.textSecondary),
              ),
            ),
          for (final r in filtered)
            Container(
              margin: const EdgeInsets.only(top: 6),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: pal.subtle,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: pal.border),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(
                    _requestIcon(r.type),
                    size: 18,
                    color: const Color(0xFF0284C7),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${r.type.label} (${r.targetDate}${r.endDate != null ? " → ${r.endDate}" : ""})',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12,
                            color: pal.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          r.reason,
                          style: TextStyle(
                            fontSize: 11.5,
                            color: pal.textSecondary,
                          ),
                        ),
                        if (r.reviewerNote != null &&
                            r.reviewerNote!.trim().isNotEmpty) ...[
                          const SizedBox(height: 3),
                          Text(
                            'İK Notu: ${r.reviewerNote}',
                            style: TextStyle(
                              fontSize: 11,
                              fontStyle: FontStyle.italic,
                              color: pal.textMuted,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _PortalPillBadge(
                    label: r.status.label,
                    bg: _requestStatusColor(r.status).withValues(alpha: 0.14),
                    fg: _requestStatusColor(r.status),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  IconData _requestIcon(HrRequestType type) => switch (type) {
        HrRequestType.annualLeave => Icons.beach_access_rounded,
        HrRequestType.missingPunchCorrection => Icons.edit_calendar_rounded,
        HrRequestType.overtimeApproval => Icons.more_time_rounded,
        HrRequestType.advancePayment => Icons.payments_outlined,
      };

  Color _requestStatusColor(HrRequestStatus status) => switch (status) {
        HrRequestStatus.pending => const Color(0xFFD97706),
        HrRequestStatus.approved => const Color(0xFF059669),
        HrRequestStatus.rejected => const Color(0xFFDC2626),
      };
}

class _PortalPillBadge extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color bg;
  final Color fg;

  const _PortalPillBadge({
    this.icon,
    required this.label,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12.5, color: fg),
            const SizedBox(width: 4),
          ],
          Flexible(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: fg,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
