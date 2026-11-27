import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/security/hasibu_security_service.dart';
import '../../../../core/utils/turkish_search.dart';
import '../../domain/employee_bulk_import_engine.dart';
import '../../domain/pdks_models.dart';
import '../../domain/pdks_print_builders.dart';
import '../providers/pdks_providers.dart';
import '../widgets/employee_profile_avatar.dart';
import '../widgets/hasibu_theme_palette.dart';
import 'employee_history_dossier_dialog.dart';
import 'hasibu_print_preview_dialog.dart';

enum _EmployeeListFilter { all, active, terminated }

// ============================================================================
// 5. PERSONEL KARTLARI, KİŞİSEL PAROLA, PROFİL FOTOĞRAFI VE YETKİ YÖNETİMİ
// ============================================================================
class EmployeesManagementSettingsView extends ConsumerStatefulWidget {
  const EmployeesManagementSettingsView({super.key});

  @override
  ConsumerState<EmployeesManagementSettingsView> createState() =>
      _EmployeesManagementSettingsViewState();
}

class _EmployeesManagementSettingsViewState
    extends ConsumerState<EmployeesManagementSettingsView> {
  late final TextEditingController _searchCtrl;
  _EmployeeListFilter _statusFilter = _EmployeeListFilter.all;
  bool _bulkSelectionMode = false;
  final Set<int> _selectedEmployeeIds = <int>{};
  bool _revealSensitiveKvkk = false;

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

  Future<void> _showQuickExitDialog(BuildContext context, Employee emp) {
    return showDialog<void>(
      context: context,
      builder: (_) => _EmployeeQuickExitDialog(employee: emp),
    );
  }

  Future<void> _showQuickRehireDialog(
    BuildContext context,
    Employee emp,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: Text('${emp.fullName} — Tekrar Aktif Et'),
        content: Text(
          'Mevcut işten çıkış tarihi (${PdksDashboardNotifier.formatDisplayDate(emp.normalizedExitDate ?? '', includeTodayBadge: false)}) kaldırılıp personel yeniden aktif kadroya alınacak. Onaylıyor musunuz?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(false),
            child: const Text('Vazgeç'),
          ),
          FilledButton.icon(
            onPressed: () => Navigator.of(dialogCtx).pop(true),
            icon: const Icon(Icons.person_add_alt_1_rounded, size: 17),
            label: const Text('Tekrar Aktif Et'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await ref.read(pdksDashboardProvider.notifier).saveEmployee(
            emp.copyWith(
              exitDate: () => null,
              sgkActive: true,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdksDashboardProvider);
    final pal = HasibuPalette.of(context);
    final q = normalizeTurkishSearch(_searchCtrl.text);

    final int totalStaff = state.dailyStatuses.length;
    final int terminatedStaff =
        state.dailyStatuses.where((s) => s.employee.isSeparatedNow).length;
    final int activeStaff = totalStaff - terminatedStaff;

    final filtered = state.dailyStatuses.where((s) {
      final isSeparated = s.employee.isSeparatedNow;
      if (_statusFilter == _EmployeeListFilter.active && isSeparated) {
        return false;
      }
      if (_statusFilter == _EmployeeListFilter.terminated && !isSeparated) {
        return false;
      }
      if (q.isEmpty) return true;
      return matchesTurkishSearch(s.employee.fullName, q) ||
          matchesTurkishSearch(s.employee.cardNo, q) ||
          matchesTurkishSearch(s.department.name, q) ||
          matchesTurkishSearch(s.employee.title, q);
    }).toList(growable: false)
      ..sort((a, b) {
        final sepCmp = (a.employee.isSeparatedNow ? 1 : 0)
            .compareTo(b.employee.isSeparatedNow ? 1 : 0);
        if (sepCmp != 0) return sepCmp;
        return a.employee.fullName.compareTo(b.employee.fullName);
      });

    final statusFilterLabel = switch (_statusFilter) {
      _EmployeeListFilter.all => 'Tüm Kadro',
      _EmployeeListFilter.active => 'Aktif Personel',
      _EmployeeListFilter.terminated => 'İşten Ayrılanlar',
    };

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 12,
          alignment: WrapAlignment.spaceBetween,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            SizedBox(
              width: 360,
              child: TextField(
                key: const ValueKey('employees_search_field'),
                controller: _searchCtrl,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  labelText: 'Personel Adı, Kart No veya Bölüm Ara',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          key: const ValueKey('employees_clear_search_button'),
                          tooltip: 'Aramayı Temizle',
                          icon: const Icon(Icons.clear_rounded, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            setState(() {});
                          },
                        )
                      : null,
                ),
              ),
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('employees_print_list_button'),
                  onPressed: () {
                    final docCounts = <int, int>{
                      for (final item in filtered)
                        item.employee.id:
                            state.documentsForEmployee(item.employee.id).length,
                    };
                    final filterDesc = _searchCtrl.text.trim().isNotEmpty
                        ? '$statusFilterLabel • Arama: "${_searchCtrl.text.trim()}"'
                        : statusFilterLabel;
                    final doc =
                        HasibuPrintBuilders.buildEmployeeDirectoryListDocument(
                      companySettings: state.companySettings,
                      items: filtered,
                      documentCountsByEmployeeId: docCounts,
                      filterDescription: filterDesc,
                    );
                    showHasibuPrintPreviewDialog(context, ref, document: doc);
                  },
                  icon: const Icon(Icons.print_outlined, size: 18),
                  label: const Text('Listeyi Yazdır'),
                ),
                OutlinedButton.icon(
                  onPressed: () => _showAddDepartmentDialog(context),
                  icon: const Icon(Icons.category_rounded, size: 18),
                  label: const Text('Yeni Bölüm Ekle'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('employees_bulk_csv_button'),
                  onPressed: () => _showBulkCsvImportDialog(context),
                  icon: const Icon(Icons.upload_file_rounded, size: 18),
                  label: const Text('Toplu CSV Aktar'),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('employees_bulk_select_toggle'),
                  onPressed: () => setState(() {
                    _bulkSelectionMode = !_bulkSelectionMode;
                    if (!_bulkSelectionMode) _selectedEmployeeIds.clear();
                  }),
                  icon: Icon(
                    _bulkSelectionMode
                        ? Icons.checklist_rtl_rounded
                        : Icons.fact_check_outlined,
                    size: 18,
                  ),
                  label: Text(
                    _bulkSelectionMode ? 'Seçimi Kapat' : 'Toplu Atama',
                  ),
                ),
                FilledButton.icon(
                  onPressed: () => _showEmployeeDialog(context, null),
                  icon: const Icon(Icons.person_add_alt_1_rounded, size: 18),
                  label: const Text('Yeni Personel Ekle'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              key: const ValueKey('employees_filter_all'),
              label: Text('Tümü ($totalStaff)'),
              selected: _statusFilter == _EmployeeListFilter.all,
              onSelected: (_) =>
                  setState(() => _statusFilter = _EmployeeListFilter.all),
            ),
            ChoiceChip(
              key: const ValueKey('employees_filter_active'),
              label: Text('Aktif ($activeStaff)'),
              selected: _statusFilter == _EmployeeListFilter.active,
              onSelected: (_) =>
                  setState(() => _statusFilter = _EmployeeListFilter.active),
            ),
            ChoiceChip(
              key: const ValueKey('employees_filter_terminated'),
              label: Text('İşten Ayrılan ($terminatedStaff)'),
              selected: _statusFilter == _EmployeeListFilter.terminated,
              onSelected: (_) => setState(
                () => _statusFilter = _EmployeeListFilter.terminated,
              ),
            ),
            FilterChip(
              key: const ValueKey('employees_kvkk_reveal_chip'),
              avatar: Icon(
                _revealSensitiveKvkk
                    ? Icons.visibility_rounded
                    : Icons.visibility_off_rounded,
                size: 16,
              ),
              label: Text(
                _revealSensitiveKvkk ? 'KVKK Açık' : 'KVKK Maskeli',
              ),
              selected: _revealSensitiveKvkk,
              onSelected: (v) => setState(() => _revealSensitiveKvkk = v),
            ),
          ],
        ),
        if (_bulkSelectionMode) ...[
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.10),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: const Color(0xFF0284C7).withValues(alpha: 0.35),
              ),
            ),
            child: Wrap(
              spacing: 10,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Text(
                  'Seçili Personel: ${_selectedEmployeeIds.length}',
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    fontSize: 13,
                  ),
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    TextButton(
                      onPressed: () => setState(() {
                        for (final item in filtered) {
                          _selectedEmployeeIds.add(item.employee.id);
                        }
                      }),
                      child: const Text('Tümünü Seç'),
                    ),
                    TextButton(
                      onPressed: () =>
                          setState(() => _selectedEmployeeIds.clear()),
                      child: const Text('Temizle'),
                    ),
                    FilledButton.icon(
                      key: const ValueKey('employees_bulk_assign_apply_button'),
                      onPressed: _selectedEmployeeIds.isEmpty
                          ? null
                          : () => _showBulkAssignDialog(context),
                      icon: const Icon(Icons.swap_horiz_rounded, size: 17),
                      label: const Text('Seçililere Vardiya / Şube Ata'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
        const SizedBox(height: 14),
        if (filtered.isEmpty)
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: pal.border),
            ),
            child: Center(
              child: Text(
                'Seçili filtreye uygun personel kartı bulunamadı.',
                style: TextStyle(fontSize: 13, color: pal.textSecondary),
              ),
            ),
          ),
        for (final item in filtered)
          _EmployeeManagementCard(
            item: item,
            docCount: state.documentsForEmployee(item.employee.id).length,
            revealSensitiveKvkk: _revealSensitiveKvkk,
            bulkSelectionMode: _bulkSelectionMode,
            isSelectedForBulk: _selectedEmployeeIds.contains(item.employee.id),
            onToggleBulkSelect: () => setState(() {
              if (_selectedEmployeeIds.contains(item.employee.id)) {
                _selectedEmployeeIds.remove(item.employee.id);
              } else {
                _selectedEmployeeIds.add(item.employee.id);
              }
            }),
            onOpenDossier: () => showEmployeeHistoryAndDossierDialog(
              context,
              ref,
              item.employee,
              initialTabIndex: 0,
            ),
            onOpenDocuments: () => showEmployeeHistoryAndDossierDialog(
              context,
              ref,
              item.employee,
              initialTabIndex: 1,
            ),
            onPrintCard: () {
              final notifier = ref.read(pdksDashboardProvider.notifier);
              final doc = HasibuPrintBuilders.buildEmployeeCardDocument(
                companySettings: state.companySettings,
                status: item,
                selectedDateKey: state.selectedDate,
                documents: state.documentsForEmployee(item.employee.id),
                historyEntries: notifier.getEmployeeHistory(item.employee),
              );
              showHasibuPrintPreviewDialog(context, ref, document: doc);
            },
            onEdit: () => _showEmployeeDialog(context, item.employee),
            onQuickExit: () => _showQuickExitDialog(context, item.employee),
            onQuickRehire: () => _showQuickRehireDialog(context, item.employee),
            onDelete: () => ref
                .read(pdksDashboardProvider.notifier)
                .deleteEmployee(item.employee.id),
          ),
      ],
    );
  }

  Future<void> _showBulkCsvImportDialog(BuildContext context) async {
    final csvCtrl = TextEditingController(
      text: EmployeeBulkImportEngine.sampleCsvTemplate,
    );
    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => AlertDialog(
        title: const Text('Toplu Personel CSV İçe Aktarım'),
        content: SizedBox(
          width: 560,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Sütunlar: KartNo;AdSoyad;Unvan;Sube;Bolum;Vardiya;IseGiris;Telefon;Eposta',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 8),
              TextField(
                key: const ValueKey('bulk_csv_input_field'),
                controller: csvCtrl,
                maxLines: 9,
                style: const TextStyle(fontFamily: 'monospace', fontSize: 11.5),
                decoration: const InputDecoration(
                  border: OutlineInputBorder(),
                  hintText: 'CSV satırlarını yapıştırın...',
                ),
              ),
              const SizedBox(height: 6),
              TextButton.icon(
                onPressed: () {
                  Clipboard.setData(
                    const ClipboardData(
                      text: EmployeeBulkImportEngine.sampleCsvTemplate,
                    ),
                  );
                },
                icon: const Icon(Icons.copy_rounded, size: 15),
                label: const Text('Örnek Şablonu Kopyala'),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogCtx).pop(),
            child: const Text('İptal'),
          ),
          FilledButton.icon(
            key: const ValueKey('bulk_csv_submit_button'),
            onPressed: () async {
              final res = await ref
                  .read(pdksDashboardProvider.notifier)
                  .importEmployeesFromCsv(csvCtrl.text);
              if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      '${res.validEmployees.length} yeni personel aktarıldı '
                      '(${res.skippedExistingCount} mevcut atlandı, ${res.warnings.length} uyarı).',
                    ),
                  ),
                );
              }
            },
            icon: const Icon(Icons.check_rounded, size: 17),
            label: const Text('İçe Aktar'),
          ),
        ],
      ),
    );
    csvCtrl.dispose();
  }

  Future<void> _showBulkAssignDialog(BuildContext context) async {
    final state = ref.read(pdksDashboardProvider);
    int? shiftId;
    int? branchId;
    int? deptId;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            'Toplu Atama (${_selectedEmployeeIds.length} Personel)',
          ),
          content: SizedBox(
            width: 420,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int?>(
                  isExpanded: true,
                  initialValue: shiftId,
                  decoration: const InputDecoration(
                    labelText: 'Yeni Vardiya (Opsiyonel)',
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Değiştirme'),
                    ),
                    for (final s in state.shifts)
                      DropdownMenuItem<int?>(
                        value: s.id,
                        child: Text('${s.name} (${s.startTime}-${s.endTime})'),
                      ),
                  ],
                  onChanged: (v) => setDialogState(() => shiftId = v),
                ),
                const SizedBox(height: 10),
                if (!state.isSingleBranchScoped) ...[
                  DropdownButtonFormField<int?>(
                    isExpanded: true,
                    initialValue: branchId,
                    decoration: const InputDecoration(
                      labelText: 'Yeni Şube (Opsiyonel)',
                    ),
                    items: [
                      const DropdownMenuItem<int?>(
                        value: null,
                        child: Text('Değiştirme'),
                      ),
                      for (final b in state.branches)
                        DropdownMenuItem<int?>(
                          value: b.id,
                          child: Text(b.name),
                        ),
                    ],
                    onChanged: (v) => setDialogState(() => branchId = v),
                  ),
                  const SizedBox(height: 10),
                ],
                DropdownButtonFormField<int?>(
                  isExpanded: true,
                  initialValue: deptId,
                  decoration: const InputDecoration(
                    labelText: 'Yeni Bölüm (Opsiyonel)',
                  ),
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text('Değiştirme'),
                    ),
                    for (final d in state.departments)
                      DropdownMenuItem<int?>(
                        value: d.id,
                        child: Text(d.name),
                      ),
                  ],
                  onChanged: (v) => setDialogState(() => deptId = v),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () async {
                final count = await ref
                    .read(pdksDashboardProvider.notifier)
                    .bulkAssignEmployees(
                      employeeIds: _selectedEmployeeIds.toList(growable: false),
                      shiftId: shiftId,
                      branchId: branchId,
                      departmentId: deptId,
                    );
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
                if (mounted) {
                  setState(() {
                    _bulkSelectionMode = false;
                    _selectedEmployeeIds.clear();
                  });
                }
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('$count personel güncellendi.')),
                  );
                }
              },
              child: const Text('Uygula'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _showAddDepartmentDialog(BuildContext context) async {
    final state = ref.read(pdksDashboardProvider);
    if (state.branches.isEmpty) return;
    final nameCtrl = TextEditingController();
    int selectedBranchId =
        state.effectiveBranchScopeId ?? state.branches.first.id;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Yeni Üretim Bölümü / Departman Ekle'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                decoration: const InputDecoration(
                  labelText: 'Bölüm Adı (örn. PAKETLEME)',
                ),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<int>(
                key: ValueKey('add_dept_branch_$selectedBranchId'),
                isExpanded: true,
                initialValue:
                    state.branches.any((b) => b.id == selectedBranchId)
                        ? selectedBranchId
                        : state.branches.first.id,
                decoration: const InputDecoration(
                  labelText: 'Bağlı Şube',
                ),
                items: [
                  for (final b in state.branches)
                    DropdownMenuItem(
                      value: b.id,
                      child: Text(b.name, overflow: TextOverflow.ellipsis),
                    ),
                ],
                onChanged: state.isSingleBranchScoped
                    ? null
                    : (v) {
                        if (v != null) {
                          setDialogState(() => selectedBranchId = v);
                        }
                      },
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final nextId = state.departments.isEmpty
                    ? 1
                    : state.departments
                            .map((d) => d.id)
                            .reduce((a, b) => a > b ? a : b) +
                        1;
                await ref.read(pdksDashboardProvider.notifier).saveDepartment(
                      Department(
                        id: nextId,
                        name: nameCtrl.text.trim(),
                        branchId: selectedBranchId,
                      ),
                    );
                if (dialogCtx.mounted) Navigator.of(dialogCtx).pop();
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    nameCtrl.dispose();
  }

  Future<void> _showEmployeeDialog(
    BuildContext context,
    Employee? existing,
  ) {
    return showDialog<void>(
      context: context,
      builder: (_) => _EmployeeEditDialog(existing: existing),
    );
  }
}

class _EmployeeQuickExitDialog extends ConsumerStatefulWidget {
  final Employee employee;

  const _EmployeeQuickExitDialog({required this.employee});

  @override
  ConsumerState<_EmployeeQuickExitDialog> createState() =>
      _EmployeeQuickExitDialogState();
}

class _EmployeeQuickExitDialogState
    extends ConsumerState<_EmployeeQuickExitDialog> {
  late final TextEditingController _exitCtrl;
  bool _deactivateSgk = true;
  String? _errorMsg;

  @override
  void initState() {
    super.initState();
    _exitCtrl = TextEditingController(text: PdksDashboardNotifier.todayDateKey());
  }

  @override
  void dispose() {
    _exitCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final emp = widget.employee;
    return AlertDialog(
      title: Text('${emp.fullName} — İşten Çıkış İşlemi'),
      content: SizedBox(
        width: 400,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'İşe Giriş: ${PdksDashboardNotifier.formatDisplayDate(emp.hireDate, includeTodayBadge: false)}',
              style: const TextStyle(fontSize: 12.5),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _exitCtrl,
              decoration: InputDecoration(
                labelText: 'İşten Çıkış Tarihi (YYYY-AA-GG)',
                suffixIcon: IconButton(
                  tooltip: 'Takvimden Seç',
                  icon: const Icon(Icons.calendar_today_rounded, size: 18),
                  onPressed: () async {
                    final initial =
                        Employee.parseDateKey(_exitCtrl.text) ?? DateTime.now();
                    final picked = await showDatePicker(
                      context: context,
                      initialDate: initial,
                      firstDate: DateTime(1990, 1, 1),
                      lastDate: DateTime(2035, 12, 31),
                      locale: const Locale('tr', 'TR'),
                    );
                    if (picked != null && mounted) {
                      setState(() {
                        _exitCtrl.text =
                            PdksDashboardNotifier.formatDateKey(picked);
                        _errorMsg = null;
                      });
                    }
                  },
                ),
              ),
            ),
            const SizedBox(height: 8),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _deactivateSgk,
              onChanged: (v) => setState(() => _deactivateSgk = v ?? true),
              title: const Text(
                'SGK durumunu pasif yap',
                style: TextStyle(fontSize: 13),
              ),
            ),
            if (_errorMsg != null)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(
                  _errorMsg!,
                  style: const TextStyle(
                    color: Color(0xFFDC2626),
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        FilledButton.icon(
          style: FilledButton.styleFrom(
            backgroundColor: const Color(0xFFDC2626),
          ),
          onPressed: () {
            final exitDt = Employee.parseDateKey(_exitCtrl.text);
            final hireDt = Employee.parseDateKey(emp.hireDate);
            if (exitDt == null) {
              setState(
                () => _errorMsg = 'Geçerli bir YYYY-AA-GG tarihi giriniz.',
              );
              return;
            }
            if (hireDt != null && exitDt.isBefore(hireDt)) {
              setState(
                () => _errorMsg =
                    'Çıkış tarihi işe giriş tarihinden (${emp.hireDate}) önce olamaz.',
              );
              return;
            }
            final normExit = PdksDashboardNotifier.formatDateKey(exitDt);
            final saveFuture =
                ref.read(pdksDashboardProvider.notifier).saveEmployee(
                      emp.copyWith(
                        exitDate: () => normExit,
                        sgkActive: _deactivateSgk ? false : emp.sgkActive,
                      ),
                    );
            unawaited(
              saveFuture.catchError((Object e) {
                debugPrint(
                  'Personel çıkış kaydetme arka plan senkronizasyon uyarısı: $e',
                );
              }),
            );
            Navigator.of(context).pop();
          },
          icon: const Icon(Icons.person_remove_rounded, size: 17),
          label: const Text('Çıkış Kaydet'),
        ),
      ],
    );
  }
}

class _EmployeeEditDialog extends ConsumerStatefulWidget {
  final Employee? existing;

  const _EmployeeEditDialog({required this.existing});

  @override
  ConsumerState<_EmployeeEditDialog> createState() =>
      _EmployeeEditDialogState();
}

class _EmployeeEditDialogState extends ConsumerState<_EmployeeEditDialog> {
  static const Map<int, String> _weekdayNames = {
    1: 'Pazartesi',
    2: 'Salı',
    3: 'Çarşamba',
    4: 'Perşembe',
    5: 'Cuma',
    6: 'Cumartesi',
    7: 'Pazar',
  };

  late final int _nextId;
  late final TextEditingController _cardCtrl;
  late final TextEditingController _nameCtrl;
  late final TextEditingController _titleCtrl;
  late final TextEditingController _hireCtrl;
  late final TextEditingController _exitCtrl;
  late final TextEditingController _passwordCtrl;
  late final TextEditingController _photoPathCtrl;
  late final TextEditingController _leaveEntCtrl;
  late final TextEditingController _leaveUsedCtrl;
  late final TextEditingController _kpiCtrl;
  late final TextEditingController _nationalIdCtrl;
  late final TextEditingController _phoneCtrl;
  late final TextEditingController _emailCtrl;
  late final TextEditingController _ibanCtrl;
  late final TextEditingController _probationCtrl;

  late int _branchId;
  late int _deptId;
  late int _shiftId;
  int? _weeklyOffDay;
  late bool _sgkActive;
  bool _userTouchedSgk = false;
  String? _dateValidationError;
  late HasibuThemeMode _empThemeMode;
  late final Set<HasibuModule> _selectedModules;

  @override
  void initState() {
    super.initState();
    final state = ref.read(pdksDashboardProvider);
    final existing = widget.existing;
    _nextId = existing?.id ??
        (state.dailyStatuses.isEmpty
            ? 3000
            : state.dailyStatuses
                    .map((s) => s.employee.id)
                    .reduce((a, b) => a > b ? a : b) +
                1);

    _cardCtrl = TextEditingController(
      text: existing?.cardNo ?? _nextId.toString().padLeft(5, '0'),
    );
    _nameCtrl = TextEditingController(text: existing?.fullName ?? '');
    _titleCtrl =
        TextEditingController(text: existing?.title ?? 'ÜRETİM PERSONELİ');
    _hireCtrl = TextEditingController(
      text: existing?.hireDate ?? PdksDashboardNotifier.todayDateKey(),
    );
    _exitCtrl = TextEditingController(
      text: existing?.normalizedExitDate ?? '',
    );
    _passwordCtrl = TextEditingController(text: existing?.password ?? '1234');
    _photoPathCtrl = TextEditingController(text: existing?.photoPath ?? '');
    _leaveEntCtrl = TextEditingController(
      text: (existing?.annualLeaveEntitlement ?? 14).toString(),
    );
    _leaveUsedCtrl = TextEditingController(
      text: (existing?.usedAnnualLeave ?? 0).toString(),
    );
    _kpiCtrl = TextEditingController(
      text: (existing?.kpiScore ?? 95.0).toStringAsFixed(0),
    );
    _nationalIdCtrl = TextEditingController(text: existing?.nationalId ?? '');
    _phoneCtrl = TextEditingController(text: existing?.phone ?? '');
    _emailCtrl = TextEditingController(text: existing?.email ?? '');
    _ibanCtrl = TextEditingController(text: existing?.iban ?? '');
    _probationCtrl = TextEditingController(
      text: Employee.normalizeDateKey(existing?.probationEndDate) ?? '',
    );

    _branchId = state.effectiveBranchScopeId ??
        existing?.branchId ??
        (state.branches.isNotEmpty ? state.branches.first.id : 1);
    _deptId = existing?.departmentId ??
        (state.departments.isNotEmpty ? state.departments.first.id : 1);
    _shiftId = existing?.shiftId ??
        (state.shifts.isNotEmpty ? state.shifts.first.id : 1);
    _weeklyOffDay = existing?.weeklyOffDay;
    _sgkActive = existing?.sgkActive ?? true;
    _empThemeMode = existing?.themeMode ?? HasibuThemeMode.light;
    _selectedModules = <HasibuModule>{
      ...(existing?.allowedModules ??
          const <HasibuModule>[HasibuModule.employeePortal]),
    };
  }

  @override
  void dispose() {
    _cardCtrl.dispose();
    _nameCtrl.dispose();
    _titleCtrl.dispose();
    _hireCtrl.dispose();
    _exitCtrl.dispose();
    _passwordCtrl.dispose();
    _photoPathCtrl.dispose();
    _leaveEntCtrl.dispose();
    _leaveUsedCtrl.dispose();
    _kpiCtrl.dispose();
    _nationalIdCtrl.dispose();
    _phoneCtrl.dispose();
    _emailCtrl.dispose();
    _ibanCtrl.dispose();
    _probationCtrl.dispose();
    super.dispose();
  }

  DateTime _clampedPickerDate(String rawText) {
    final raw = Employee.parseDateKey(rawText) ?? DateTime.now();
    if (raw.isBefore(DateTime(1990, 1, 1))) return DateTime(1990, 1, 1);
    if (raw.isAfter(DateTime(2035, 12, 31))) return DateTime(2035, 12, 31);
    return raw;
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdksDashboardProvider);
    final pal = HasibuPalette.of(context);
    final existing = widget.existing;
    final previewEmp = Employee(
      id: _nextId,
      cardNo: _cardCtrl.text,
      fullName:
          _nameCtrl.text.isEmpty ? 'Personel' : _nameCtrl.text.toUpperCase(),
      title: _titleCtrl.text,
      departmentId: _deptId,
      branchId: _branchId,
      hireDate: _hireCtrl.text.trim(),
      exitDate: Employee.normalizeDateKey(_exitCtrl.text),
      photoPath: _photoPathCtrl.text.trim().isEmpty
          ? null
          : _photoPathCtrl.text.trim(),
      themeMode: _empThemeMode,
    );

    return AlertDialog(
      title: Text(
        existing == null
            ? 'Yeni Personel, Parola & Yetki Kaydı'
            : '${existing.fullName} Kartını Güncelle',
      ),
      content: SizedBox(
        width: 560,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. PROFİL FOTOĞRAFI ALANI
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: pal.subtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: pal.border),
                ),
                child: Row(
                  children: [
                    EmployeeProfileAvatar(
                      employee: previewEmp,
                      size: 60,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Profil Fotoğrafı & Avatar',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              OutlinedButton.icon(
                                onPressed: () async {
                                  final picked = await EmployeeProfileAvatar
                                      .pickPhotoFromDevice();
                                  if (picked != null && mounted) {
                                    setState(
                                      () => _photoPathCtrl.text = picked,
                                    );
                                  }
                                },
                                icon: const Icon(
                                  Icons.photo_camera_outlined,
                                  size: 16,
                                ),
                                label: const Text(
                                  'Cihazdan Fotoğraf Seç',
                                ),
                              ),
                              for (int i = 1; i <= 6; i++)
                                InkWell(
                                  onTap: () => setState(
                                    () => _photoPathCtrl.text = 'preset:$i',
                                  ),
                                  borderRadius: BorderRadius.circular(14),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 8,
                                      vertical: 4,
                                    ),
                                    decoration: BoxDecoration(
                                      color: _photoPathCtrl.text == 'preset:$i'
                                          ? const Color(0xFF0284C7)
                                              .withValues(alpha: 0.2)
                                          : pal.card,
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(color: pal.border),
                                    ),
                                    child: Text(
                                      'Stil $i',
                                      style: const TextStyle(fontSize: 11),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _cardCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Kart / Sicil No (örn. 00001)',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    flex: 2,
                    child: TextField(
                      controller: _nameCtrl,
                      onChanged: (_) => setState(() {}),
                      decoration: const InputDecoration(
                        labelText: 'Ad Soyad',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _passwordCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Kişisel Giriş Parolası',
                        helperText: 'Personelin oturum açma parolası',
                        prefixIcon: Icon(Icons.key_rounded, size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _titleCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Görev / Unvan',
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              // 2. PERSONELİN KENDİNE ÖZGÜ TEMA SEÇİMİ
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: pal.subtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: pal.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Personelin Kişisel Tema Tercihi (Oturum Açtığında Uygulanır)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    SegmentedButton<HasibuThemeMode>(
                      segments: [
                        for (final m in HasibuThemeMode.values)
                          ButtonSegment<HasibuThemeMode>(
                            value: m,
                            label: Text(m.label),
                          ),
                      ],
                      selected: {_empThemeMode},
                      onSelectionChanged: (sel) => setState(
                        () => _empThemeMode = sel.first,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 12),
              // 3. PERSONEL YETKİ ALANLARI (MODÜL İZİNLERİ)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: pal.subtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: pal.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Expanded(
                          child: Text(
                            'Personel Yetki Alanları (Girişte Görebileceği Modüller)',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 12.5,
                            ),
                          ),
                        ),
                        TextButton(
                          onPressed: () => setState(() {
                            _selectedModules
                                .addAll(HasibuModule.activePhaseModules);
                          }),
                          child: const Text(
                            'Tüm Yetkileri Ver',
                            style: TextStyle(fontSize: 11.5),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 6),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children: [
                        for (final mod in HasibuModule.activePhaseModules)
                          FilterChip(
                            selected: _selectedModules.contains(mod),
                            label: Text(
                              mod.title,
                              style: const TextStyle(fontSize: 12),
                            ),
                            onSelected: (val) {
                              setState(() {
                                if (val) {
                                  _selectedModules.add(mod);
                                } else if (_selectedModules.length > 1) {
                                  _selectedModules.remove(mod);
                                }
                              });
                            },
                          ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: state.branches.isEmpty
                        ? const InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Şube / Merkez',
                            ),
                            child: Text('Şube bulunamadı'),
                          )
                        : DropdownButtonFormField<int>(
                            key: ValueKey(
                              'emp_branch_${state.effectiveBranchScopeId}_$_branchId',
                            ),
                            isExpanded: true,
                            initialValue: state.branches.any(
                              (b) =>
                                  b.id ==
                                  (state.effectiveBranchScopeId ?? _branchId),
                            )
                                ? (state.effectiveBranchScopeId ?? _branchId)
                                : state.branches.first.id,
                            decoration: const InputDecoration(
                              labelText: 'Şube / Merkez',
                            ),
                            items: [
                              for (final b in state.branches)
                                DropdownMenuItem(
                                  value: b.id,
                                  child: Text(
                                    b.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: state.isSingleBranchScoped
                                ? null
                                : (v) {
                                    if (v != null) {
                                      setState(() => _branchId = v);
                                    }
                                  },
                          ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: state.departments.isEmpty
                        ? const InputDecorator(
                            decoration: InputDecoration(
                              labelText: 'Bölüm / Departman',
                            ),
                            child: Text('Bölüm bulunamadı'),
                          )
                        : DropdownButtonFormField<int>(
                            key: ValueKey('emp_dept_$_deptId'),
                            isExpanded: true,
                            initialValue:
                                state.departments.any((d) => d.id == _deptId)
                                    ? _deptId
                                    : state.departments.first.id,
                            decoration: const InputDecoration(
                              labelText: 'Bölüm / Departman',
                            ),
                            items: [
                              for (final d in state.departments)
                                DropdownMenuItem(
                                  value: d.id,
                                  child: Text(
                                    d.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (v) {
                              if (v != null) setState(() => _deptId = v);
                            },
                          ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              DropdownButtonFormField<int>(
                isExpanded: true,
                initialValue: _shiftId,
                decoration: const InputDecoration(
                  labelText: 'Mesai Saat Aralığı (Vardiya)',
                ),
                items: [
                  for (final s in state.shifts)
                    DropdownMenuItem(
                      value: s.id,
                      child: Text(
                        '${s.name} (${s.startTime}-${s.endTime} • ${s.toleranceMinutes} dk tol.)',
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                ],
                onChanged: (v) {
                  if (v != null) setState(() => _shiftId = v);
                },
              ),
              const SizedBox(height: 10),
              // İSTİHDAM TARİHLERİ (İŞE GİRİŞ & İŞTEN ÇIKIŞ)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: pal.subtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: pal.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Wrap(
                      spacing: 8,
                      runSpacing: 6,
                      alignment: WrapAlignment.spaceBetween,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        const Text(
                          'İstihdam Tarihleri (İşe Giriş & İşten Çıkış)',
                          style: TextStyle(
                            fontWeight: FontWeight.w700,
                            fontSize: 12.5,
                          ),
                        ),
                        ActionChip(
                          visualDensity: VisualDensity.compact,
                          avatar: const Icon(
                            Icons.person_off_outlined,
                            size: 14,
                            color: Color(0xFFDC2626),
                          ),
                          label: const Text(
                            'Bugün Çıkış Ver',
                            style: TextStyle(fontSize: 11),
                          ),
                          onPressed: () => setState(() {
                            _exitCtrl.text =
                                PdksDashboardNotifier.todayDateKey();
                            _dateValidationError = null;
                            if (!_userTouchedSgk) {
                              _sgkActive = false;
                            }
                          }),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    LayoutBuilder(
                      builder: (fieldCtx, constraints) {
                        final hireField = TextField(
                          key: const ValueKey(
                            'employee_dialog_hire_date_field',
                          ),
                          controller: _hireCtrl,
                          onChanged: (_) =>
                              setState(() => _dateValidationError = null),
                          decoration: InputDecoration(
                            labelText: 'İşe Giriş (YYYY-AA-GG)',
                            suffixIcon: IconButton(
                              tooltip: 'Takvimden Seç',
                              icon: const Icon(
                                Icons.calendar_today_rounded,
                                size: 17,
                              ),
                              onPressed: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate:
                                      _clampedPickerDate(_hireCtrl.text),
                                  firstDate: DateTime(1990, 1, 1),
                                  lastDate: DateTime(2035, 12, 31),
                                  locale: const Locale('tr', 'TR'),
                                );
                                if (picked != null && mounted) {
                                  setState(() {
                                    _hireCtrl.text =
                                        PdksDashboardNotifier.formatDateKey(
                                      picked,
                                    );
                                    _dateValidationError = null;
                                  });
                                }
                              },
                            ),
                          ),
                        );
                        final exitField = TextField(
                          key: const ValueKey(
                            'employee_dialog_exit_date_field',
                          ),
                          controller: _exitCtrl,
                          onChanged: (v) => setState(() {
                            _dateValidationError = null;
                            if (!_userTouchedSgk) {
                              _sgkActive = v.trim().isEmpty;
                            }
                          }),
                          decoration: InputDecoration(
                            labelText: 'İşten Çıkış (Opsiyonel)',
                            hintText: 'YYYY-AA-GG',
                            suffixIcon: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                if (_exitCtrl.text.trim().isNotEmpty)
                                  IconButton(
                                    tooltip: 'Çıkış Tarihini Temizle',
                                    icon: const Icon(
                                      Icons.close_rounded,
                                      size: 17,
                                    ),
                                    onPressed: () => setState(() {
                                      _exitCtrl.clear();
                                      _dateValidationError = null;
                                      if (!_userTouchedSgk) {
                                        _sgkActive = true;
                                      }
                                    }),
                                  ),
                                IconButton(
                                  tooltip: 'Takvimden Seç',
                                  icon: const Icon(
                                    Icons.calendar_today_rounded,
                                    size: 17,
                                  ),
                                  onPressed: () async {
                                    final picked = await showDatePicker(
                                      context: context,
                                      initialDate:
                                          _clampedPickerDate(_exitCtrl.text),
                                      firstDate: DateTime(1990, 1, 1),
                                      lastDate: DateTime(2035, 12, 31),
                                      locale: const Locale('tr', 'TR'),
                                    );
                                    if (picked != null && mounted) {
                                      setState(() {
                                        _exitCtrl.text =
                                            PdksDashboardNotifier.formatDateKey(
                                          picked,
                                        );
                                        _dateValidationError = null;
                                        if (!_userTouchedSgk) {
                                          _sgkActive = false;
                                        }
                                      });
                                    }
                                  },
                                ),
                              ],
                            ),
                          ),
                        );
                        if (constraints.maxWidth >= 420) {
                          return Row(
                            children: [
                              Expanded(child: hireField),
                              const SizedBox(width: 8),
                              Expanded(child: exitField),
                            ],
                          );
                        }
                        return Column(
                          children: [
                            hireField,
                            const SizedBox(height: 8),
                            exitField,
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Kıdem: ${previewEmp.tenureSummaryAt()} • 4857 Yasal İzin: ${previewEmp.statutoryAnnualLeaveEntitlement} Gün',
                      style: TextStyle(
                        fontSize: 11.5,
                        fontWeight: FontWeight.w600,
                        color: pal.textSecondary,
                      ),
                    ),
                    if (_exitCtrl.text.trim().isNotEmpty) ...[
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 7,
                        ),
                        decoration: BoxDecoration(
                          color:
                              const Color(0xFFDC2626).withValues(alpha: 0.10),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                            color:
                                const Color(0xFFDC2626).withValues(alpha: 0.30),
                          ),
                        ),
                        child: const Text(
                          'Çıkış tarihinden itibaren devamsız sayılmaz ve portal girişi kapatılır.',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFFDC2626),
                          ),
                        ),
                      ),
                    ],
                    if (_dateValidationError != null) ...[
                      const SizedBox(height: 6),
                      Text(
                        _dateValidationError!,
                        style: const TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              const SizedBox(height: 10),
              // ÖZLÜK İLETİŞİM, BANKA & ÇALIŞMA DETAYLARI (OPSİYONEL)
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: pal.subtle,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: pal.border),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Özlük İletişim, Banka & Çalışma Detayları (Opsiyonel)',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey(
                              'employee_dialog_national_id_field',
                            ),
                            controller: _nationalIdCtrl,
                            keyboardType: TextInputType.number,
                            decoration: const InputDecoration(
                              labelText: 'TC Kimlik No',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            key: const ValueKey('employee_dialog_phone_field'),
                            controller: _phoneCtrl,
                            keyboardType: TextInputType.phone,
                            decoration: const InputDecoration(
                              labelText: 'Telefon',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey('employee_dialog_email_field'),
                            controller: _emailCtrl,
                            keyboardType: TextInputType.emailAddress,
                            decoration: const InputDecoration(
                              labelText: 'E-Posta',
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: TextField(
                            key: const ValueKey('employee_dialog_iban_field'),
                            controller: _ibanCtrl,
                            decoration: const InputDecoration(
                              labelText: 'IBAN',
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            key: const ValueKey(
                              'employee_dialog_probation_field',
                            ),
                            controller: _probationCtrl,
                            decoration: InputDecoration(
                              labelText: 'Deneme Süresi Bitişi',
                              hintText: 'YYYY-AA-GG',
                              suffixIcon: IconButton(
                                tooltip: 'Takvimden Seç',
                                icon: const Icon(
                                  Icons.calendar_today_rounded,
                                  size: 16,
                                ),
                                onPressed: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate:
                                        _clampedPickerDate(_probationCtrl.text),
                                    firstDate: DateTime(2000),
                                    lastDate: DateTime(2035),
                                    locale: const Locale('tr', 'TR'),
                                  );
                                  if (picked != null && mounted) {
                                    setState(() {
                                      _probationCtrl.text =
                                          PdksDashboardNotifier.formatDateKey(
                                        picked,
                                      );
                                    });
                                  }
                                },
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: DropdownButtonFormField<int?>(
                            key: const ValueKey(
                              'employee_dialog_weekly_off_dropdown',
                            ),
                            isExpanded: true,
                            initialValue: _weeklyOffDay,
                            decoration: const InputDecoration(
                              labelText: 'Özel Hafta Tatili',
                            ),
                            items: [
                              const DropdownMenuItem<int?>(
                                value: null,
                                child: Text('Vardiya Varsayılanı'),
                              ),
                              for (final entry in _weekdayNames.entries)
                                DropdownMenuItem<int?>(
                                  value: entry.key,
                                  child: Text(entry.value),
                                ),
                            ],
                            onChanged: (v) =>
                                setState(() => _weeklyOffDay = v),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _leaveEntCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'İzin Hakkı',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _leaveUsedCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'Kullanılan',
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: TextField(
                      controller: _kpiCtrl,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(
                        labelText: 'KPI (%)',
                      ),
                    ),
                  ),
                ],
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('SGK Sigortalılık Durumu Aktif'),
                value: _sgkActive,
                onChanged: (v) => setState(() {
                  _userTouchedSgk = true;
                  _sgkActive = v;
                }),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('İptal'),
        ),
        FilledButton(
          key: const ValueKey('employee_dialog_save_button'),
          onPressed: () {
            if (_nameCtrl.text.trim().isEmpty) return;
            final parsedHire = Employee.parseDateKey(_hireCtrl.text);
            if (parsedHire == null) {
              setState(
                () => _dateValidationError =
                    'Geçerli bir işe giriş tarihi (YYYY-AA-GG) giriniz.',
              );
              return;
            }
            final rawExit = _exitCtrl.text.trim();
            DateTime? parsedExit;
            if (rawExit.isNotEmpty) {
              parsedExit = Employee.parseDateKey(rawExit);
              if (parsedExit == null) {
                setState(
                  () => _dateValidationError =
                      'Geçerli bir işten çıkış tarihi (YYYY-AA-GG) giriniz.',
                );
                return;
              }
              if (parsedExit.isBefore(parsedHire)) {
                setState(
                  () => _dateValidationError =
                      'İşten çıkış tarihi işe giriş tarihinden önce olamaz.',
                );
                return;
              }
            }
            final normalizedProbation =
                Employee.normalizeDateKey(_probationCtrl.text.trim());
            final orderedModules = HasibuModule.activePhaseModules
                .where((m) => _selectedModules.contains(m))
                .toList(growable: false);
            final emp = Employee(
              id: _nextId,
              cardNo: _cardCtrl.text.trim().padLeft(5, '0'),
              fullName: _nameCtrl.text.trim().toUpperCase(),
              title: _titleCtrl.text.trim().toUpperCase(),
              departmentId: state.departments.any((d) => d.id == _deptId)
                  ? _deptId
                  : (state.departments.isNotEmpty
                      ? state.departments.first.id
                      : _deptId),
              branchId: state.effectiveBranchScopeId ?? _branchId,
              shiftId: _shiftId,
              hireDate: PdksDashboardNotifier.formatDateKey(parsedHire),
              exitDate: parsedExit != null
                  ? PdksDashboardNotifier.formatDateKey(parsedExit)
                  : null,
              sgkActive: _sgkActive,
              annualLeaveEntitlement:
                  int.tryParse(_leaveEntCtrl.text.trim()) ?? 14,
              usedAnnualLeave: int.tryParse(_leaveUsedCtrl.text.trim()) ?? 0,
              kpiScore: double.tryParse(_kpiCtrl.text.trim()) ?? 92.0,
              password: _passwordCtrl.text.trim().isEmpty
                  ? '1234'
                  : _passwordCtrl.text.trim(),
              allowedModules: orderedModules.isEmpty
                  ? const <HasibuModule>[HasibuModule.employeePortal]
                  : orderedModules,
              photoPath: _photoPathCtrl.text.trim().isEmpty
                  ? null
                  : _photoPathCtrl.text.trim(),
              themeMode: _empThemeMode,
              nationalId: _nationalIdCtrl.text.trim().isEmpty
                  ? null
                  : _nationalIdCtrl.text.trim(),
              phone: _phoneCtrl.text.trim().isEmpty
                  ? null
                  : _phoneCtrl.text.trim(),
              email: _emailCtrl.text.trim().isEmpty
                  ? null
                  : _emailCtrl.text.trim(),
              iban: _ibanCtrl.text.trim().isEmpty
                  ? null
                  : _ibanCtrl.text.trim(),
              probationEndDate: normalizedProbation,
              weeklyOffDay: _weeklyOffDay,
            );
            final saveFuture =
                ref.read(pdksDashboardProvider.notifier).saveEmployee(emp);
            unawaited(
              saveFuture.catchError((Object e) {
                debugPrint(
                  'Personel kaydetme arka plan senkronizasyon uyarısı: $e',
                );
              }),
            );
            Navigator.of(context).pop();
          },
          child: const Text('Kaydet'),
        ),
      ],
    );
  }
}

class _EmployeeManagementCard extends StatelessWidget {
  final EmployeeDailyStatus item;
  final int docCount;
  final bool revealSensitiveKvkk;
  final bool bulkSelectionMode;
  final bool isSelectedForBulk;
  final VoidCallback onToggleBulkSelect;
  final VoidCallback onOpenDossier;
  final VoidCallback onOpenDocuments;
  final VoidCallback onPrintCard;
  final VoidCallback onEdit;
  final VoidCallback onQuickExit;
  final VoidCallback onQuickRehire;
  final VoidCallback onDelete;

  const _EmployeeManagementCard({
    required this.item,
    required this.docCount,
    this.revealSensitiveKvkk = false,
    this.bulkSelectionMode = false,
    this.isSelectedForBulk = false,
    required this.onToggleBulkSelect,
    required this.onOpenDossier,
    required this.onOpenDocuments,
    required this.onPrintCard,
    required this.onEdit,
    required this.onQuickExit,
    required this.onQuickRehire,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    final emp = item.employee;
    final bool isSeparated = emp.isSeparatedNow;
    final bool hasScheduledExit = emp.hasExitDate && !isSeparated;

    final (Color statusBg, Color statusFg, String statusText) = isSeparated
        ? (
            const Color(0xFFDC2626).withValues(alpha: 0.13),
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
                'AKTİF',
              ));

    final Color sgkColor = emp.sgkActive
        ? const Color(0xFF059669)
        : const Color(0xFF64748B);

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: isSeparated ? pal.subtle : pal.card,
        borderRadius: BorderRadius.circular(12),
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onOpenDossier,
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSeparated
                    ? const Color(0xFFDC2626).withValues(alpha: 0.25)
                    : pal.border,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (bulkSelectionMode) ...[
                      Checkbox(
                        value: isSelectedForBulk,
                        onChanged: (_) => onToggleBulkSelect(),
                      ),
                      const SizedBox(width: 4),
                    ],
                    Opacity(
                      opacity: isSeparated ? 0.72 : 1.0,
                      child: EmployeeProfileAvatar(
                        employee: emp,
                        size: 48,
                        borderColor: isSeparated
                            ? const Color(0xFF64748B).withValues(alpha: 0.5)
                            : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                '${emp.fullName} (#${emp.cardNo})',
                                style: TextStyle(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 14,
                                  color: pal.textPrimary,
                                ),
                              ),
                              _EmpMiniTag(
                                label: statusText,
                                bg: statusBg,
                                fg: statusFg,
                              ),
                              _EmpMiniTag(
                                label: emp.sgkActive
                                    ? 'SGK AKTİF'
                                    : 'SGK PASİF',
                                bg: sgkColor.withValues(alpha: 0.13),
                                fg: sgkColor,
                              ),
                              _EmpMiniTag(
                                label: 'Tema: ${emp.themeMode.label}',
                                bg: pal.chip,
                                fg: pal.textSecondary,
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            '${item.branch.name} • ${item.department.name} • ${emp.title} • '
                            'Mesai: ${item.shift.name} • İzin: ${emp.formattedRemainingAnnualLeave} G • KPI: %${emp.kpiScore.toStringAsFixed(0)}',
                            style: TextStyle(
                              fontSize: 12,
                              color: pal.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            children: [
                              _EmpMiniTag(
                                icon: Icons.login_rounded,
                                label:
                                    'İşe Giriş: ${PdksDashboardNotifier.formatDisplayDate(emp.hireDate, includeTodayBadge: false)}',
                                bg: pal.chip,
                                fg: pal.textPrimary,
                              ),
                              if (emp.hasExitDate)
                                _EmpMiniTag(
                                  icon: Icons.logout_rounded,
                                  label:
                                      'İşten Çıkış: ${PdksDashboardNotifier.formatDisplayDate(emp.normalizedExitDate!, includeTodayBadge: false)}',
                                  bg: const Color(0xFFDC2626)
                                      .withValues(alpha: 0.11),
                                  fg: const Color(0xFFDC2626),
                                ),
                              _EmpMiniTag(
                                icon: Icons.workspace_premium_outlined,
                                label: 'Kıdem: ${emp.tenureSummaryAt()}',
                                bg: const Color(0xFF0284C7)
                                    .withValues(alpha: 0.10),
                                fg: const Color(0xFF0284C7),
                              ),
                              if ((emp.nationalId ?? '').trim().isNotEmpty)
                                _EmpMiniTag(
                                  icon: Icons.badge_outlined,
                                  label:
                                      'TC: ${revealSensitiveKvkk ? emp.nationalId!.trim() : HasibuSecurityService.maskNationalId(emp.nationalId)}',
                                  bg: pal.chip,
                                  fg: pal.textSecondary,
                                ),
                              if ((emp.iban ?? '').trim().isNotEmpty)
                                _EmpMiniTag(
                                  icon: Icons.account_balance_outlined,
                                  label:
                                      'IBAN: ${revealSensitiveKvkk ? emp.iban!.trim() : HasibuSecurityService.maskIban(emp.iban)}',
                                  bg: pal.chip,
                                  fg: pal.textSecondary,
                                ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 4,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              Text(
                                'Yetkiler:',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: pal.textSecondary,
                                ),
                              ),
                              for (final mod in emp.allowedModules)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 7,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF0284C7)
                                        .withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(6),
                                    border: Border.all(
                                      color: const Color(0xFF0284C7)
                                          .withValues(alpha: 0.30),
                                    ),
                                  ),
                                  child: Text(
                                    mod.title,
                                    style: const TextStyle(
                                      fontSize: 10.5,
                                      fontWeight: FontWeight.w600,
                                      color: Color(0xFF0284C7),
                                    ),
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    OutlinedButton.icon(
                      onPressed: onOpenDossier,
                      icon: const Icon(Icons.history_rounded, size: 16),
                      label: const Text('Personel Geçmişi'),
                    ),
                    OutlinedButton.icon(
                      onPressed: onOpenDocuments,
                      icon: const Icon(Icons.folder_shared_rounded, size: 16),
                      label: Text('Özlük Dosyası ($docCount)'),
                    ),
                    if (!emp.hasExitDate)
                      OutlinedButton.icon(
                        key: ValueKey('quick_exit_employee_${emp.cardNo}'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFFDC2626),
                        ),
                        onPressed: onQuickExit,
                        icon: const Icon(Icons.person_off_outlined, size: 16),
                        label: const Text('İşten Çıkış'),
                      )
                    else
                      OutlinedButton.icon(
                        key: ValueKey('quick_rehire_employee_${emp.cardNo}'),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: const Color(0xFF059669),
                        ),
                        onPressed: onQuickRehire,
                        icon: const Icon(Icons.restart_alt_rounded, size: 16),
                        label: const Text('Tekrar Aktif Et'),
                      ),
                    FilledButton.tonalIcon(
                      key: ValueKey('edit_employee_btn_${emp.cardNo}'),
                      onPressed: onEdit,
                      icon: const Icon(Icons.manage_accounts_rounded, size: 16),
                      label: const Text('Kartı Düzenle'),
                    ),
                    OutlinedButton.icon(
                      key: ValueKey('print_employee_card_${emp.cardNo}'),
                      onPressed: onPrintCard,
                      icon: const Icon(Icons.print_outlined, size: 16),
                      label: const Text('Kartı Yazdır'),
                    ),
                    IconButton(
                      color: const Color(0xFFDC2626),
                      tooltip: 'Personeli Sil',
                      onPressed: onDelete,
                      icon: const Icon(Icons.delete_outline_rounded),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _EmpMiniTag extends StatelessWidget {
  final IconData? icon;
  final String label;
  final Color bg;
  final Color fg;

  const _EmpMiniTag({
    this.icon,
    required this.label,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 4),
          ],
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w700,
              color: fg,
            ),
          ),
        ],
      ),
    );
  }
}
