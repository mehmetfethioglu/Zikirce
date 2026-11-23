import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/pdks_models.dart';
import '../providers/pdks_providers.dart';
import 'employee_directory_picker.dart';
import 'hasibu_settings_view.dart';

/// İzinli ve Raporlu Personel Bilgilerini Girme / Yönetme Ekranı.
/// Personel Portalı tarzı aramalı sol rehber (masaüstü) ve yapışkan seçici/bottom-sheet
/// (mobil/dar) ile hızlı personel geçişi sağlar.
class LeavesAndReportsSettingsView extends ConsumerStatefulWidget {
  const LeavesAndReportsSettingsView({super.key});

  @override
  ConsumerState<LeavesAndReportsSettingsView> createState() =>
      _LeavesAndReportsSettingsViewState();
}

class _LeavesAndReportsSettingsViewState
    extends ConsumerState<LeavesAndReportsSettingsView> {
  int? _selectedEmployeeId;
  EmployeeDirectoryFilter _employmentFilter = EmployeeDirectoryFilter.active;
  int? _branchFilterId;
  LeaveType _selectedLeaveType = LeaveType.yillikIzin;
  bool _showAllEmployeesRecords = false;

  late final TextEditingController _searchCtrl;
  late final TextEditingController _startDateCtrl;
  late final TextEditingController _endDateCtrl;
  late final TextEditingController _noteCtrl;

  @override
  void initState() {
    super.initState();
    final date = ref.read(pdksDashboardProvider).selectedDate;
    _searchCtrl = TextEditingController();
    _startDateCtrl = TextEditingController(text: date);
    _endDateCtrl = TextEditingController(text: date);
    _noteCtrl = TextEditingController();
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    _startDateCtrl.dispose();
    _endDateCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  int? _resolveBranchFilterId(List<int> scopedBranchIds) {
    if (scopedBranchIds.length == 1) return scopedBranchIds.first;
    if (_branchFilterId != null &&
        (scopedBranchIds.isEmpty ||
            scopedBranchIds.contains(_branchFilterId))) {
      return _branchFilterId;
    }
    return null;
  }

  Future<void> _pickLeaveDate(TextEditingController ctrl) async {
    final initial = DateTime.tryParse(ctrl.text.trim()) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2035, 12, 31),
      locale: const Locale('tr', 'TR'),
    );
    if (picked == null || !mounted) return;
    setState(() {
      ctrl.text = PdksDashboardNotifier.formatDateKey(picked);
    });
  }

  void _applyQuickDayCount(int days) {
    final start = DateTime.tryParse(_startDateCtrl.text.trim()) ??
        DateTime.tryParse(ref.read(pdksDashboardProvider).selectedDate) ??
        DateTime.now();
    final normalizedStart = DateTime(start.year, start.month, start.day);
    final end = normalizedStart.add(Duration(days: days - 1));
    setState(() {
      _startDateCtrl.text = PdksDashboardNotifier.formatDateKey(normalizedStart);
      _endDateCtrl.text = PdksDashboardNotifier.formatDateKey(end);
    });
  }

  void _stepEmployee(
    List<EmployeeDailyStatus> directory,
    EmployeeDailyStatus current,
    int delta,
  ) {
    if (directory.isEmpty) return;
    final idx = directory.indexWhere(
      (s) => s.employee.id == current.employee.id,
    );
    final nextIdx = idx < 0
        ? 0
        : (idx + delta + directory.length) % directory.length;
    setState(() => _selectedEmployeeId = directory[nextIdx].employee.id);
  }

  Widget _buildRemainingLeavePill(Employee emp) {
    final color = emp.remainingAnnualLeave > 0
        ? const Color(0xFF0284C7)
        : const Color(0xFFD97706);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(
        '${emp.remainingAnnualLeave}g',
        style: TextStyle(
          fontSize: 10.5,
          fontWeight: FontWeight.w800,
          color: color,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdksDashboardProvider);
    final pal = HasibuPalette.of(context);
    final statuses = state.dailyStatuses;
    final branches = state.branches;
    final scopedBranchIds = state.effectiveBranchScopeIds;

    if (statuses.isEmpty) {
      return const Center(
        child: Text('Yetkili kapsamda personel bulunamadı.'),
      );
    }

    final statusById = {for (final s in statuses) s.employee.id: s};
    final effectiveBranchFilterId = _resolveBranchFilterId(scopedBranchIds);
    final directory = filterEmployeeDirectory(
      statuses,
      employmentFilter: _employmentFilter,
      branchFilterId: effectiveBranchFilterId,
      query: _searchCtrl.text,
    );

    final fallbackStatus = directory.isNotEmpty
        ? directory.first
        : statuses.firstWhere(
            (s) => !s.employee.isSeparatedNow,
            orElse: () => statuses.first,
          );

    final currentStatus = (_selectedEmployeeId != null &&
            statusById.containsKey(_selectedEmployeeId))
        ? statusById[_selectedEmployeeId]!
        : fallbackStatus;
    final selectedEmp = currentStatus.employee;

    final int entitlement = selectedEmp.annualLeaveEntitlement <= 0
        ? 14
        : selectedEmp.annualLeaveEntitlement;
    final double leaveProgress =
        (selectedEmp.remainingAnnualLeave / entitlement).clamp(0.0, 1.0);

    final selectedEmpRecords = state.allLeaveRecords
        .where((r) => r.employeeId == selectedEmp.id)
        .toList(growable: false);
    final visibleRecords = _showAllEmployeesRecords
        ? state.allLeaveRecords
        : selectedEmpRecords;

    return LayoutBuilder(
      builder: (context, constraints) {
        final bool isWideMasterDetail = constraints.maxWidth >= 1040;
        final EdgeInsets pagePadding = EdgeInsets.all(
          constraints.maxWidth < 600 ? 12 : 20,
        );

        final workspace = Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            EmployeeQuickSwitcherBar(
              keyPrefix: 'leaves_employee',
              current: currentStatus,
              positionLabel: formatDirectoryPositionText(
                directory,
                selectedEmp.cardNo,
              ),
              isWideMasterDetail: isWideMasterDetail,
              onPrev: directory.length > 1
                  ? () => _stepEmployee(directory, currentStatus, -1)
                  : null,
              onNext: directory.length > 1
                  ? () => _stepEmployee(directory, currentStatus, 1)
                  : null,
              onOpenPicker: () => showEmployeeDirectoryBottomSheet(
                context: context,
                keyPrefix: 'leaves_employee',
                allStatuses: statuses,
                branches: branches,
                currentCardNo: selectedEmp.cardNo,
                scopedBranchIds: scopedBranchIds,
                initialEmploymentFilter: _employmentFilter,
                initialBranchFilterId: effectiveBranchFilterId,
                searchController: _searchCtrl,
                onEmploymentFilterChanged: (f) =>
                    setState(() => _employmentFilter = f),
                onBranchFilterChanged: (bId) =>
                    setState(() => _branchFilterId = bId),
                trailingBuilder: (item) =>
                    _buildRemainingLeavePill(item.employee),
                onSelectEmployee: (item) =>
                    setState(() => _selectedEmployeeId = item.employee.id),
              ),
            ),
            const SizedBox(height: 12),
            // Yıllık İzin Bakiyesi Özeti
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
                  Row(
                    children: [
                      EmployeeProfileAvatar(employee: selectedEmp, size: 42),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              selectedEmp.fullName,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                fontSize: 14.5,
                                fontWeight: FontWeight.w800,
                                color: pal.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '#${selectedEmp.cardNo} • ${currentStatus.department.name} • ${currentStatus.branch.name}',
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
                          color: const Color(0xFF0284C7).withValues(alpha: 0.11),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          'Kalan: ${selectedEmp.remainingAnnualLeave} Gün',
                          style: const TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w800,
                            color: Color(0xFF0284C7),
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: leaveProgress,
                      minHeight: 5,
                      backgroundColor: pal.chip,
                      color: const Color(0xFF0284C7),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    'Yıllık İzin Hakkı: ${selectedEmp.annualLeaveEntitlement} Gün • '
                    'Kullanılan: ${selectedEmp.usedAnnualLeave} Gün',
                    style: TextStyle(
                      fontSize: 11.5,
                      color: pal.textSecondary,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            // İzin / Rapor Kaydı Oluşturma Formu
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: pal.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: pal.border),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'İzinli veya Raporlu Personel Kaydı Oluştur',
                    style: TextStyle(
                      fontSize: 14.5,
                      fontWeight: FontWeight.w800,
                      color: pal.textPrimary,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final lt in LeaveType.values)
                        ChoiceChip(
                          key: ValueKey('leaves_type_${lt.name}'),
                          visualDensity: VisualDensity.compact,
                          label: Text(
                            lt.label,
                            style: const TextStyle(fontSize: 11.5),
                          ),
                          selected: _selectedLeaveType == lt,
                          onSelected: (_) =>
                              setState(() => _selectedLeaveType = lt),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  LayoutBuilder(
                    builder: (ctx, box) {
                      final twoCols = box.maxWidth >= 520;
                      final startField = TextField(
                        controller: _startDateCtrl,
                        decoration: InputDecoration(
                          labelText: 'Başlangıç (YYYY-AA-GG)',
                          suffixIcon: IconButton(
                            tooltip: 'Takvimden Başlangıç Tarihi Seç',
                            icon: const Icon(
                              Icons.calendar_today_rounded,
                              size: 16,
                            ),
                            onPressed: () => _pickLeaveDate(_startDateCtrl),
                          ),
                        ),
                      );
                      final endField = TextField(
                        controller: _endDateCtrl,
                        decoration: InputDecoration(
                          labelText: 'Bitiş (YYYY-AA-GG)',
                          suffixIcon: IconButton(
                            tooltip: 'Takvimden Bitiş Tarihi Seç',
                            icon: const Icon(
                              Icons.calendar_today_rounded,
                              size: 16,
                            ),
                            onPressed: () => _pickLeaveDate(_endDateCtrl),
                          ),
                        ),
                      );
                      if (twoCols) {
                        return Row(
                          children: [
                            Expanded(child: startField),
                            const SizedBox(width: 10),
                            Expanded(child: endField),
                          ],
                        );
                      }
                      return Column(
                        children: [
                          startField,
                          const SizedBox(height: 10),
                          endField,
                        ],
                      );
                    },
                  ),
                  const SizedBox(height: 8),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      Text(
                        'Hızlı süre:',
                        style: TextStyle(
                          fontSize: 11,
                          fontWeight: FontWeight.w600,
                          color: pal.textMuted,
                        ),
                      ),
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        label: const Text('1 Gün', style: TextStyle(fontSize: 11)),
                        onPressed: () => _applyQuickDayCount(1),
                      ),
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        label: const Text('3 Gün', style: TextStyle(fontSize: 11)),
                        onPressed: () => _applyQuickDayCount(3),
                      ),
                      ActionChip(
                        visualDensity: VisualDensity.compact,
                        label: const Text(
                          '1 Hafta',
                          style: TextStyle(fontSize: 11),
                        ),
                        onPressed: () => _applyQuickDayCount(7),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  TextField(
                    controller: _noteCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Açıklama / Rapor Notu',
                      hintText: 'Örn: 3 Günlük Hastane Raporu',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Align(
                    alignment: Alignment.centerRight,
                    child: FilledButton.icon(
                      key: const ValueKey('leaves_save_record_button'),
                      onPressed: () async {
                        try {
                          final start =
                              DateTime.tryParse(_startDateCtrl.text.trim()) ??
                                  DateTime.tryParse(state.selectedDate) ??
                                  DateTime.now();
                          final end =
                              DateTime.tryParse(_endDateCtrl.text.trim()) ??
                                  start;
                          final count = await ref
                              .read(pdksDashboardProvider.notifier)
                              .assignLeaveDateRange(
                                employeeId: selectedEmp.id,
                                startDate: start,
                                endDate: end,
                                leaveType: _selectedLeaveType,
                                note: _noteCtrl.text,
                              );
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  '${selectedEmp.fullName}: $count günlük ${_selectedLeaveType.label} kaydı eklendi.',
                                ),
                              ),
                            );
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text(
                                  'İzin/rapor kaydı eklenemedi: $e',
                                ),
                                backgroundColor: const Color(0xFFDC2626),
                                behavior: SnackBarBehavior.floating,
                              ),
                            );
                          }
                        }
                      },
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('İzin / Rapor Kaydet'),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            // Kayıtlı İzinler & Sağlık Raporları Listesi
            Wrap(
              spacing: 8,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Kayıtlı İzinler & Sağlık Raporları (${visibleRecords.length})',
                  style: TextStyle(
                    fontSize: 14.5,
                    fontWeight: FontWeight.w800,
                    color: pal.textPrimary,
                  ),
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    ChoiceChip(
                      key: const ValueKey('leaves_scope_selected'),
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        'Seçili Personel (${selectedEmpRecords.length})',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      selected: !_showAllEmployeesRecords,
                      onSelected: (_) =>
                          setState(() => _showAllEmployeesRecords = false),
                    ),
                    ChoiceChip(
                      key: const ValueKey('leaves_scope_all'),
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        'Tüm Personel (${state.allLeaveRecords.length})',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      selected: _showAllEmployeesRecords,
                      onSelected: (_) =>
                          setState(() => _showAllEmployeesRecords = true),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 8),
            if (visibleRecords.isEmpty)
              Container(
                padding: const EdgeInsets.all(18),
                decoration: BoxDecoration(
                  color: pal.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: pal.border),
                ),
                child: Text(
                  _showAllEmployeesRecords
                      ? 'Henüz kayıtlı izin veya sağlık raporu bulunmuyor.'
                      : '${selectedEmp.fullName} için kayıtlı izin veya sağlık raporu bulunmuyor.',
                  style: TextStyle(fontSize: 12.5, color: pal.textSecondary),
                ),
              ),
            for (final rec in visibleRecords)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Material(
                  color: pal.card,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: pal.border),
                  ),
                  clipBehavior: Clip.antiAlias,
                  child: ListTile(
                  onTap: _showAllEmployeesRecords &&
                          statusById.containsKey(rec.employeeId)
                      ? () => setState(
                            () => _selectedEmployeeId = rec.employeeId,
                          )
                      : null,
                  leading: statusById[rec.employeeId] != null
                      ? EmployeeProfileAvatar(
                          employee: statusById[rec.employeeId]!.employee,
                          size: 36,
                        )
                      : const CircleAvatar(child: Icon(Icons.person_outline)),
                  title: Text(
                    '${statusById[rec.employeeId]?.employee.fullName ?? "Personel #${rec.employeeId}"} • ${rec.leaveType.label}',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                    ),
                  ),
                  subtitle: Text(
                    '${PdksDashboardNotifier.formatDisplayDate(rec.date, includeTodayBadge: false)}'
                    '${rec.note.trim().isNotEmpty ? " • ${rec.note}" : ""}',
                    style: TextStyle(fontSize: 11.5, color: pal.textSecondary),
                  ),
                  trailing: IconButton(
                    color: const Color(0xFFDC2626),
                    tooltip: 'İzin/Rapor Kaydını Sil',
                    onPressed: () async {
                      try {
                        await ref
                            .read(pdksDashboardProvider.notifier)
                            .deleteLeaveRecord(rec.id);
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('İzin/rapor kaydı silinemedi: $e'),
                              backgroundColor: const Color(0xFFDC2626),
                              behavior: SnackBarBehavior.floating,
                            ),
                          );
                        }
                      }
                    },
                    icon: const Icon(Icons.delete_outline_rounded, size: 20),
                  ),
                ),
                ),
              ),
          ],
        );

        if (!isWideMasterDetail) {
          return ListView(
            padding: pagePadding,
            children: [workspace],
          );
        }

        final double panelHeight = constraints.hasBoundedHeight
            ? (constraints.maxHeight - pagePadding.vertical).clamp(380.0, 820.0)
            : 640.0;

        return Padding(
          padding: pagePadding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 310,
                height: panelHeight,
                child: EmployeeDirectoryPickerPanel(
                  keyPrefix: 'leaves_employee',
                  allStatuses: statuses,
                  filteredStatuses: directory,
                  branches: branches,
                  selectedCardNo: selectedEmp.cardNo,
                  employmentFilter: _employmentFilter,
                  branchFilterId: effectiveBranchFilterId,
                  allBranchesLabel: scopedBranchIds.isNotEmpty
                      ? 'Yetkili Şubelerim'
                      : 'Tüm Şubeler',
                  searchController: _searchCtrl,
                  onSearchChanged: () => setState(() {}),
                  onEmploymentFilterChanged: (f) =>
                      setState(() => _employmentFilter = f),
                  onBranchChanged: (bId) {
                    if (scopedBranchIds.length == 1) return;
                    if (bId != null &&
                        scopedBranchIds.isNotEmpty &&
                        !scopedBranchIds.contains(bId)) {
                      return;
                    }
                    setState(() => _branchFilterId = bId);
                  },
                  trailingBuilder: (item) =>
                      _buildRemainingLeavePill(item.employee),
                  onSelectEmployee: (item) =>
                      setState(() => _selectedEmployeeId = item.employee.id),
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
}
