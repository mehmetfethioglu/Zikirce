import 'package:flutter/material.dart';

import '../../../../core/utils/turkish_search.dart';
import '../../domain/pdks_models.dart';
import 'hasibu_settings_view.dart';

enum EmployeeDirectoryFilter {
  active,
  terminated,
  all,
}

/// Arama sorgusu, çalışma durumu ve şube filtresine göre personel rehberini filtreler ve sıralar.
List<EmployeeDailyStatus> filterEmployeeDirectory(
  List<EmployeeDailyStatus> statuses, {
  required EmployeeDirectoryFilter employmentFilter,
  required int? branchFilterId,
  required String query,
}) {
  final q = normalizeTurkishSearch(query);
  final filtered = statuses.where((s) {
    final isSeparated = s.employee.isSeparatedNow;
    if (employmentFilter == EmployeeDirectoryFilter.active && isSeparated) {
      return false;
    }
    if (employmentFilter == EmployeeDirectoryFilter.terminated && !isSeparated) {
      return false;
    }
    if (branchFilterId != null && s.branch.id != branchFilterId) {
      return false;
    }
    if (q.isEmpty) return true;
    return matchesTurkishSearch(s.employee.fullName, q) ||
        matchesTurkishSearch(s.employee.cardNo, q) ||
        matchesTurkishSearch(s.department.name, q) ||
        matchesTurkishSearch(s.employee.title, q);
  }).toList(growable: false);

  final sorted = List<EmployeeDailyStatus>.from(filtered);
  sorted.sort((a, b) {
    final sepCmp = (a.employee.isSeparatedNow ? 1 : 0)
        .compareTo(b.employee.isSeparatedNow ? 1 : 0);
    if (sepCmp != 0) return sepCmp;
    return a.employee.fullName.compareTo(b.employee.fullName);
  });
  return sorted;
}

/// Sıra göstergesi metnini üretir (`3 / 24`).
String formatDirectoryPositionText(
  List<EmployeeDailyStatus> directory,
  String currentCardNo,
) {
  if (directory.isEmpty) return '0 / 0';
  final idx = directory.indexWhere((s) => s.employee.cardNo == currentCardNo);
  return idx < 0 ? '${directory.length} kişi' : '${idx + 1} / ${directory.length}';
}

/// Personel Portalı ve İzin & Raporlar ekranları için ortak aramalı/filtreli personel rehberi.
class EmployeeDirectoryPickerPanel extends StatelessWidget {
  final String keyPrefix;
  final String title;
  final List<EmployeeDailyStatus> allStatuses;
  final List<EmployeeDailyStatus> filteredStatuses;
  final List<Branch> branches;
  final String selectedCardNo;
  final EmployeeDirectoryFilter employmentFilter;
  final int? branchFilterId;
  final String allBranchesLabel;
  final TextEditingController searchController;
  final VoidCallback onSearchChanged;
  final ValueChanged<EmployeeDirectoryFilter> onEmploymentFilterChanged;
  final ValueChanged<int?> onBranchChanged;
  final ValueChanged<EmployeeDailyStatus> onSelectEmployee;
  final Widget? Function(EmployeeDailyStatus item)? trailingBuilder;
  final VoidCallback? onClose;

  const EmployeeDirectoryPickerPanel({
    super.key,
    this.keyPrefix = 'directory_employee',
    this.title = 'Personel Rehberi',
    required this.allStatuses,
    required this.filteredStatuses,
    required this.branches,
    required this.selectedCardNo,
    required this.employmentFilter,
    required this.branchFilterId,
    this.allBranchesLabel = 'Tüm Şubeler',
    required this.searchController,
    required this.onSearchChanged,
    required this.onEmploymentFilterChanged,
    required this.onBranchChanged,
    required this.onSelectEmployee,
    this.trailingBuilder,
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
                        title,
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
                  key: ValueKey('${keyPrefix}_search_field'),
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
                          employmentFilter == EmployeeDirectoryFilter.active,
                      onSelected: (_) => onEmploymentFilterChanged(
                        EmployeeDirectoryFilter.active,
                      ),
                    ),
                    ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        'Ayrılan ($separatedCount)',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      selected: employmentFilter ==
                          EmployeeDirectoryFilter.terminated,
                      onSelected: (_) => onEmploymentFilterChanged(
                        EmployeeDirectoryFilter.terminated,
                      ),
                    ),
                    ChoiceChip(
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        'Tümü ($totalCount)',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      selected: employmentFilter == EmployeeDirectoryFilter.all,
                      onSelected: (_) =>
                          onEmploymentFilterChanged(EmployeeDirectoryFilter.all),
                    ),
                  ],
                ),
                if (branches.length > 1) ...[
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int?>(
                    key: ValueKey(
                      '${keyPrefix}_branch_${allBranchesLabel}_$branchFilterId',
                    ),
                    isExpanded: true,
                    initialValue: branches.any((b) => b.id == branchFilterId)
                        ? branchFilterId
                        : null,
                    decoration: const InputDecoration(
                      isDense: true,
                      labelText: 'Şube Filtresi',
                      contentPadding: EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 8,
                      ),
                    ),
                    items: [
                      DropdownMenuItem<int?>(
                        value: null,
                        child: Text(allBranchesLabel),
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
                      final statusColor = attendanceStateColor(item.state);
                      final trailing = trailingBuilder?.call(item);

                      return Material(
                        color: isSelected
                            ? const Color(0xFF0284C7).withValues(alpha: 0.12)
                            : Colors.transparent,
                        borderRadius: BorderRadius.circular(10),
                        child: InkWell(
                          key: ValueKey('${keyPrefix}_tile_${emp.cardNo}'),
                          borderRadius: BorderRadius.circular(10),
                          onTap: () => onSelectEmployee(item),
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
                                if (trailing != null) ...[
                                  const SizedBox(width: 6),
                                  trailing,
                                ],
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

/// Personel Portalı tarzı yapışkan personel geçiş çubuğu (masaüstü prev/next + mobil bottom-sheet seçici).
class EmployeeQuickSwitcherBar extends StatelessWidget {
  final String keyPrefix;
  final EmployeeDailyStatus current;
  final String positionLabel;
  final bool isWideMasterDetail;
  final VoidCallback? onPrev;
  final VoidCallback? onNext;
  final VoidCallback onOpenPicker;

  const EmployeeQuickSwitcherBar({
    super.key,
    this.keyPrefix = 'directory_employee',
    required this.current,
    required this.positionLabel,
    required this.isWideMasterDetail,
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
            const Icon(
              Icons.badge_outlined,
              size: 18,
              color: Color(0xFF0284C7),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                'Seçili Personel: ${emp.fullName} (#${emp.cardNo}) • ${current.department.name}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12.5,
                  fontWeight: FontWeight.w700,
                  color: pal.textPrimary,
                ),
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 4),
              decoration: BoxDecoration(
                color: pal.subtle,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: pal.border),
              ),
              child: Text(
                positionLabel,
                style: TextStyle(
                  fontSize: 11.5,
                  fontWeight: FontWeight.w700,
                  color: pal.textSecondary,
                ),
              ),
            ),
            const SizedBox(width: 6),
            IconButton(
              key: ValueKey('${keyPrefix}_prev_button'),
              visualDensity: VisualDensity.compact,
              tooltip: 'Önceki Personel',
              onPressed: onPrev,
              icon: const Icon(Icons.chevron_left_rounded),
            ),
            IconButton(
              key: ValueKey('${keyPrefix}_next_button'),
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
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: pal.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: pal.border),
      ),
      child: Row(
        children: [
          Expanded(
            child: InkWell(
              key: ValueKey('${keyPrefix}_picker_button'),
              borderRadius: BorderRadius.circular(10),
              onTap: onOpenPicker,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 2),
                child: Row(
                  children: [
                    EmployeeProfileAvatar(
                      employee: emp,
                      size: 36,
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
                    const SizedBox(width: 6),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 9,
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
                              fontSize: 11,
                              fontWeight: FontWeight.w700,
                              color: Color(0xFF0284C7),
                            ),
                          ),
                          SizedBox(width: 2),
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
            key: ValueKey('${keyPrefix}_prev_button'),
            visualDensity: VisualDensity.compact,
            tooltip: 'Önceki Personel',
            onPressed: onPrev,
            icon: const Icon(Icons.chevron_left_rounded),
          ),
          IconButton(
            key: ValueKey('${keyPrefix}_next_button'),
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

/// Dar ve mobil ekranlarda personel seçimi için alt rehber penceresini açar.
Future<void> showEmployeeDirectoryBottomSheet({
  required BuildContext context,
  required String keyPrefix,
  required List<EmployeeDailyStatus> allStatuses,
  required List<Branch> branches,
  required String currentCardNo,
  required List<int> scopedBranchIds,
  required EmployeeDirectoryFilter initialEmploymentFilter,
  required int? initialBranchFilterId,
  required TextEditingController searchController,
  required ValueChanged<EmployeeDirectoryFilter> onEmploymentFilterChanged,
  required ValueChanged<int?> onBranchFilterChanged,
  required ValueChanged<EmployeeDailyStatus> onSelectEmployee,
  Widget? Function(EmployeeDailyStatus item)? trailingBuilder,
}) async {
  var localEmployment = initialEmploymentFilter;
  var localBranchId = initialBranchFilterId;

  await showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
    ),
    builder: (sheetCtx) => StatefulBuilder(
      builder: (ctx, setSheetState) {
        final effectiveBranchFilterId = scopedBranchIds.length == 1
            ? scopedBranchIds.first
            : (localBranchId != null &&
                    (scopedBranchIds.isEmpty ||
                        scopedBranchIds.contains(localBranchId))
                ? localBranchId
                : null);

        final filtered = filterEmployeeDirectory(
          allStatuses,
          employmentFilter: localEmployment,
          branchFilterId: effectiveBranchFilterId,
          query: searchController.text,
        );

        return SizedBox(
          height: MediaQuery.sizeOf(ctx).height * 0.82,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: EmployeeDirectoryPickerPanel(
              keyPrefix: keyPrefix,
              allStatuses: allStatuses,
              filteredStatuses: filtered,
              branches: branches,
              selectedCardNo: currentCardNo,
              employmentFilter: localEmployment,
              branchFilterId: effectiveBranchFilterId,
              allBranchesLabel: scopedBranchIds.isNotEmpty
                  ? 'Yetkili Şubelerim'
                  : 'Tüm Şubeler',
              searchController: searchController,
              onSearchChanged: () => setSheetState(() {}),
              onEmploymentFilterChanged: (f) {
                localEmployment = f;
                onEmploymentFilterChanged(f);
                setSheetState(() {});
              },
              onBranchChanged: (bId) {
                if (scopedBranchIds.length == 1) return;
                if (bId != null &&
                    scopedBranchIds.isNotEmpty &&
                    !scopedBranchIds.contains(bId)) {
                  return;
                }
                localBranchId = bId;
                onBranchFilterChanged(bId);
                setSheetState(() {});
              },
              trailingBuilder: trailingBuilder,
              onSelectEmployee: (item) {
                onSelectEmployee(item);
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
