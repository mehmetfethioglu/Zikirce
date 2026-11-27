import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/pdks_models.dart';
import '../providers/pdks_providers.dart';
import '../widgets/employee_profile_avatar.dart';
import '../widgets/hasibu_theme_palette.dart';

// ============================================================================
// 3. PERSONEL HAREKETLERİNİ DÜZELTME & TOPLU HAREKET DÜZENLEME MODÜLÜ
// ============================================================================
class AttendanceCorrectionSettingsView extends ConsumerStatefulWidget {
  const AttendanceCorrectionSettingsView({super.key});

  @override
  ConsumerState<AttendanceCorrectionSettingsView> createState() =>
      _AttendanceCorrectionSettingsViewState();
}

class _AttendanceCorrectionSettingsViewState
    extends ConsumerState<AttendanceCorrectionSettingsView> {
  late final TextEditingController _dateCtrl;
  late final TextEditingController _filterCtrl;
  late final TextEditingController _bulkInCtrl;
  late final TextEditingController _bulkOutCtrl;

  final Set<String> _selectedCardNos = <String>{};
  int? _branchFilterId;
  bool _onlyAbsentFilter = false;
  bool _applyIn = true;
  bool _applyOut = true;
  bool _replaceExisting = true;

  @override
  void initState() {
    super.initState();
    final date = ref.read(pdksDashboardProvider).selectedDate;
    _dateCtrl = TextEditingController(text: date);
    _filterCtrl = TextEditingController();
    _bulkInCtrl = TextEditingController(text: '08:00');
    _bulkOutCtrl = TextEditingController(text: '18:00');
  }

  @override
  void dispose() {
    _dateCtrl.dispose();
    _filterCtrl.dispose();
    _bulkInCtrl.dispose();
    _bulkOutCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdksDashboardProvider);
    final pal = HasibuPalette.of(context);
    final int? effectiveBranchFilter = state.isSingleBranchScoped
        ? state.effectiveBranchScopeIds.first
        : (_branchFilterId != null && state.canAccessBranch(_branchFilterId!)
            ? _branchFilterId
            : null);
    final q = _filterCtrl.text.trim().toUpperCase();
    final filtered = state.dailyStatuses.where((s) {
      if (effectiveBranchFilter != null &&
          s.branch.id != effectiveBranchFilter) {
        return false;
      }
      if (_onlyAbsentFilter && s.state != DailyAttendanceState.absent) {
        return false;
      }
      if (q.isEmpty) return true;
      return s.employee.fullName.toUpperCase().contains(q) ||
          s.employee.cardNo.contains(q) ||
          s.department.name.toUpperCase().contains(q);
    }).toList(growable: false);

    return ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (state.tamperedAttendanceLogs.isNotEmpty)
          Container(
            margin: const EdgeInsets.only(bottom: 14),
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFDC2626).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFDC2626), width: 1.5),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.gpp_bad_rounded,
                  color: Color(0xFFDC2626),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'KIRMIZI ALARM • MANİPÜLE EDİLMİŞ KAYIT TESPİT EDİLDİ (HMAC-SHA256)',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 13,
                          color: Color(0xFFDC2626),
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        'Veritabanında ${state.tamperedAttendanceLogs.length} adet giriş/çıkış kaydının saati veya doğrulama yöntemi uygulama dışından elle değiştirilmiş (integrityHash uyumsuzluğu).',
                        style: TextStyle(
                          fontSize: 12,
                          color: pal.textPrimary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        // ÜST PANEL: TOPLU HAREKET DÜZENLEME (ÇOKLU PERSONEL)
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
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: const Color(0xFF0284C7).withValues(alpha: 0.14),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.playlist_add_check_circle_rounded,
                      color: Color(0xFF0284C7),
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Toplu Hareket Düzenleme & Çoklu Giriş/Çıkış Atama',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                            color: pal.textPrimary,
                          ),
                        ),
                        Text(
                          'Aşağıdaki listeden birden fazla personeli seçip tek işlemle toplu giriş ve çıkış saati tanımlayabilirsiniz.',
                          style: TextStyle(
                            fontSize: 12,
                            color: pal.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: _selectedCardNos.isEmpty
                          ? pal.chip
                          : const Color(0xFF0284C7).withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Text(
                      '${_selectedCardNos.length} Personel Seçili',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                        color: _selectedCardNos.isEmpty
                            ? pal.textSecondary
                            : const Color(0xFF0284C7),
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  SizedBox(
                    width: 170,
                    child: TextField(
                      controller: _dateCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Tarih (YYYY-AA-GG)',
                        prefixIcon: Icon(Icons.calendar_today_rounded, size: 18),
                      ),
                    ),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: () {
                      final d = _dateCtrl.text.trim();
                      if (d.length >= 8) {
                        ref
                            .read(pdksDashboardProvider.notifier)
                            .setSelectedDate(d);
                      }
                    },
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Tarihi Yükle'),
                  ),
                  SizedBox(
                    width: 220,
                    child: state.isSingleBranchScoped
                        ? DropdownButtonFormField<int?>(
                            key: ValueKey(
                              'corr_branch_locked_$effectiveBranchFilter',
                            ),
                            isExpanded: true,
                            initialValue: effectiveBranchFilter,
                            decoration: const InputDecoration(
                              labelText: 'Şube Filtresi',
                            ),
                            items: [
                              if (state.branches.any(
                                (b) => b.id == effectiveBranchFilter,
                              ))
                                for (final b in state.branches.where(
                                  (b) => b.id == effectiveBranchFilter,
                                ))
                                  DropdownMenuItem<int?>(
                                    value: b.id,
                                    child: Text(
                                      b.name,
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                  )
                              else
                                DropdownMenuItem<int?>(
                                  value: effectiveBranchFilter,
                                  child: Text(
                                    'Şube #$effectiveBranchFilter',
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: null,
                          )
                        : DropdownButtonFormField<int?>(
                            key: ValueKey(
                              'corr_branch_${state.effectiveBranchScopeIds.join("_")}_$effectiveBranchFilter',
                            ),
                            isExpanded: true,
                            initialValue: state.branches.any(
                              (b) => b.id == effectiveBranchFilter,
                            )
                                ? effectiveBranchFilter
                                : null,
                            decoration: const InputDecoration(
                              labelText: 'Şube Filtresi',
                            ),
                            items: [
                              DropdownMenuItem<int?>(
                                value: null,
                                child: Text(
                                  state.isBranchScoped
                                      ? 'Yetkili Şubelerim (${state.branches.length})'
                                      : 'Tüm Şubeler',
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              for (final b in state.branches)
                                DropdownMenuItem<int?>(
                                  value: b.id,
                                  child: Text(
                                    b.name,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                            onChanged: (v) =>
                                setState(() => _branchFilterId = v),
                          ),
                  ),
                  FilterChip(
                    selected: _onlyAbsentFilter,
                    label: const Text('Sadece Hareketi Olmayanlar'),
                    onSelected: (v) => setState(() => _onlyAbsentFilter = v),
                  ),
                  OutlinedButton.icon(
                    onPressed: () {
                      setState(() {
                        for (final s in filtered) {
                          _selectedCardNos.add(s.employee.cardNo);
                        }
                      });
                    },
                    icon: const Icon(Icons.select_all_rounded, size: 16),
                    label: Text('Listeyi Seç (${filtered.length})'),
                  ),
                  if (_selectedCardNos.isNotEmpty)
                    TextButton.icon(
                      onPressed: () =>
                          setState(() => _selectedCardNos.clear()),
                      icon: const Icon(Icons.deselect_rounded, size: 16),
                      label: const Text('Seçimi Temizle'),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: pal.subtle,
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: pal.border),
                ),
                child: Wrap(
                  spacing: 12,
                  runSpacing: 10,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _applyIn,
                          onChanged: (v) =>
                              setState(() => _applyIn = v ?? true),
                        ),
                        SizedBox(
                          width: 130,
                          child: TextField(
                            controller: _bulkInCtrl,
                            enabled: _applyIn,
                            decoration: const InputDecoration(
                              labelText: 'Toplu Giriş',
                              hintText: '08:00',
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Checkbox(
                          value: _applyOut,
                          onChanged: (v) =>
                              setState(() => _applyOut = v ?? true),
                        ),
                        SizedBox(
                          width: 130,
                          child: TextField(
                            controller: _bulkOutCtrl,
                            enabled: _applyOut,
                            decoration: const InputDecoration(
                              labelText: 'Toplu Çıkış',
                              hintText: '18:00',
                            ),
                          ),
                        ),
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: _replaceExisting,
                          onChanged: (v) =>
                              setState(() => _replaceExisting = v),
                        ),
                        const Text(
                          'Günlük Kayıtları Yenile',
                          style: TextStyle(fontSize: 12),
                        ),
                      ],
                    ),
                    FilledButton.icon(
                      key: const ValueKey('bulk_attendance_apply_button'),
                      onPressed: _selectedCardNos.isEmpty
                          ? null
                          : () async {
                              final selectedEmployees = state.dailyStatuses
                                  .where(
                                    (s) => _selectedCardNos
                                        .contains(s.employee.cardNo),
                                  )
                                  .map((s) => s.employee)
                                  .toList(growable: false);
                              final count = await ref
                                  .read(pdksDashboardProvider.notifier)
                                  .saveBulkManualAttendance(
                                    employees: selectedEmployees,
                                    dateKey: state.selectedDate,
                                    checkInTime: _applyIn
                                        ? _bulkInCtrl.text.trim()
                                        : null,
                                    checkOutTime: _applyOut
                                        ? _bulkOutCtrl.text.trim()
                                        : null,
                                    replaceExistingForDay: _replaceExisting,
                                  );
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      '${selectedEmployees.length} personel için $count toplu hareket uygulandı.',
                                    ),
                                  ),
                                );
                              }
                            },
                      icon: const Icon(Icons.done_all_rounded, size: 18),
                      label: Text(
                        'Seçili ${_selectedCardNos.length} Personele Toplu Uygula',
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 14),
        // ARAMA SATIRI
        TextField(
          controller: _filterCtrl,
          onChanged: (_) => setState(() {}),
          decoration: const InputDecoration(
            labelText: 'Personel Adı, Kart No veya Bölüm Ara',
            prefixIcon: Icon(Icons.search_rounded),
          ),
        ),
        const SizedBox(height: 12),
        for (final item in filtered)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: _selectedCardNos.contains(item.employee.cardNo)
                    ? const Color(0xFF0284C7)
                    : pal.border,
              ),
            ),
            child: Wrap(
              spacing: 12,
              runSpacing: 8,
              alignment: WrapAlignment.spaceBetween,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Checkbox(
                      value: _selectedCardNos.contains(item.employee.cardNo),
                      onChanged: (checked) {
                        setState(() {
                          if (checked == true) {
                            _selectedCardNos.add(item.employee.cardNo);
                          } else {
                            _selectedCardNos.remove(item.employee.cardNo);
                          }
                        });
                      },
                    ),
                    EmployeeProfileAvatar(employee: item.employee, size: 38),
                    const SizedBox(width: 10),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '${item.employee.fullName} (#${item.employee.cardNo})',
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                              color: pal.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            '${item.branch.name} • ${item.department.name} • Vardiya: ${item.shift.startTime}-${item.shift.endTime}',
                            style: TextStyle(
                              fontSize: 11.5,
                              color: pal.textSecondary,
                            ),
                          ),
                          const SizedBox(height: 6),
                          Wrap(
                            spacing: 6,
                            runSpacing: 6,
                            children: [
                              if (item.allLogsOfDay.isEmpty)
                                const Text(
                                  'Kayıt yok',
                                  style: TextStyle(
                                    fontSize: 11.5,
                                    color: Color(0xFFDC2626),
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              for (final log in item.allLogsOfDay)
                                Chip(
                                  visualDensity: VisualDensity.compact,
                                  backgroundColor: !log.isIntegrityValid
                                      ? const Color(0xFFDC2626)
                                          .withValues(alpha: 0.18)
                                      : log.isCheckIn
                                          ? const Color(0xFF059669)
                                              .withValues(alpha: 0.14)
                                          : const Color(0xFFD97706)
                                              .withValues(alpha: 0.14),
                                  label: Text(
                                    !log.isIntegrityValid
                                        ? '⚠️ Manipüle Edilmiş Kayıt (${log.timeFormatted})'
                                        : '${log.isCheckIn ? "GİRİŞ" : "ÇIKIŞ"}: ${log.timeFormatted}',
                                    style: TextStyle(
                                      fontSize: 11.5,
                                      fontWeight: FontWeight.w700,
                                      color: !log.isIntegrityValid
                                          ? const Color(0xFFDC2626)
                                          : log.isCheckIn
                                              ? const Color(0xFF059669)
                                              : const Color(0xFFD97706),
                                    ),
                                  ),
                                  deleteIcon:
                                      const Icon(Icons.close, size: 14),
                                  onDeleted: () => ref
                                      .read(pdksDashboardProvider.notifier)
                                      .deleteAttendanceLog(log.id),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                Wrap(
                  spacing: 6,
                  children: [
                    OutlinedButton.icon(
                      onPressed: () => _showEditAttendanceDialog(
                        context,
                        item.employee,
                        state.selectedDate,
                        existingLog: item.firstCheckIn,
                        defaultIsCheckIn: true,
                      ),
                      icon: const Icon(Icons.login_rounded, size: 15),
                      label: Text(
                        item.firstCheckIn == null
                            ? 'Giriş Ekle'
                            : 'Giriş (${item.firstCheckIn!.timeFormatted})',
                      ),
                    ),
                    OutlinedButton.icon(
                      onPressed: () => _showEditAttendanceDialog(
                        context,
                        item.employee,
                        state.selectedDate,
                        existingLog: item.lastCheckOut,
                        defaultIsCheckIn: false,
                      ),
                      icon: const Icon(Icons.logout_rounded, size: 15),
                      label: Text(
                        item.lastCheckOut == null
                            ? 'Çıkış Ekle'
                            : 'Çıkış (${item.lastCheckOut!.timeFormatted})',
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
      ],
    );
  }

  Future<void> _showEditAttendanceDialog(
    BuildContext context,
    Employee employee,
    String dateKey, {
    AttendanceLog? existingLog,
    required bool defaultIsCheckIn,
  }) async {
    final timeCtrl = TextEditingController(
      text: existingLog?.timeFormatted ?? (defaultIsCheckIn ? '08:00' : '18:00'),
    );
    bool isCheckIn = existingLog?.isCheckIn ?? defaultIsCheckIn;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text('${employee.fullName} Hareket Düzeltme'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Tarih: $dateKey • Kart No: #${employee.cardNo}'),
              const SizedBox(height: 12),
              SegmentedButton<bool>(
                segments: const [
                  ButtonSegment(value: true, label: Text('İşe Giriş')),
                  ButtonSegment(value: false, label: Text('İşten Çıkış')),
                ],
                selected: {isCheckIn},
                onSelectionChanged: (s) =>
                    setDialogState(() => isCheckIn = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: timeCtrl,
                decoration: const InputDecoration(
                  labelText: 'Saat (SS:DD)',
                  hintText: '08:00',
                ),
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
                await ref
                    .read(pdksDashboardProvider.notifier)
                    .saveOrUpdateAttendanceLog(
                      existingLogId: existingLog?.id,
                      employee: employee,
                      dateKey: dateKey,
                      timeHhMm: timeCtrl.text.trim(),
                      isCheckIn: isCheckIn,
                    );
                if (dialogCtx.mounted) {
                  Navigator.of(dialogCtx).pop();
                }
              },
              child: const Text('Kaydet'),
            ),
          ],
        ),
      ),
    );
    timeCtrl.dispose();
  }
}
