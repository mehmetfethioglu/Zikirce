import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/utils/turkish_search.dart';
import '../../domain/pdks_models.dart';
import '../providers/pdks_providers.dart';
import '../widgets/employee_profile_avatar.dart';
import '../widgets/hasibu_theme_palette.dart';

/// Canlı Yoklama ve Personel Detay ekranlarından tekil giriş/çıkış hareketi
/// ekleme veya mevcut gün hareketlerini düzenleme/silme penceresi.
Future<bool?> showLiveAttendancePunchDialog(
  BuildContext context,
  WidgetRef ref, {
  Employee? initialEmployee,
  String? initialDateKey,
  bool? initialIsCheckIn,
  AttendanceLog? existingLog,
}) {
  return showDialog<bool>(
    context: context,
    builder: (_) => _LiveAttendancePunchDialog(
      initialEmployee: initialEmployee,
      initialDateKey: initialDateKey,
      initialIsCheckIn: initialIsCheckIn,
      existingLog: existingLog,
    ),
  );
}

class _LiveAttendancePunchDialog extends ConsumerStatefulWidget {
  final Employee? initialEmployee;
  final String? initialDateKey;
  final bool? initialIsCheckIn;
  final AttendanceLog? existingLog;

  const _LiveAttendancePunchDialog({
    this.initialEmployee,
    this.initialDateKey,
    this.initialIsCheckIn,
    this.existingLog,
  });

  @override
  ConsumerState<_LiveAttendancePunchDialog> createState() =>
      _LiveAttendancePunchDialogState();
}

class _LiveAttendancePunchDialogState
    extends ConsumerState<_LiveAttendancePunchDialog> {
  late final TextEditingController _employeeSearchCtrl;
  late final TextEditingController _timeCtrl;
  late final TextEditingController _noteCtrl;

  String? _selectedCardNo;
  late String _dateKey;
  late bool _isCheckIn;
  AttendanceLog? _editingLog;
  bool _hasCustomTimeInput = false;
  bool _isSaving = false;
  String? _validationError;

  @override
  void initState() {
    super.initState();
    _employeeSearchCtrl = TextEditingController();
    _timeCtrl = TextEditingController();
    _noteCtrl = TextEditingController();

    final state = ref.read(pdksDashboardProvider);
    _dateKey =
        widget.existingLog?.dateKey ?? widget.initialDateKey ?? state.selectedDate;
    _editingLog = widget.existingLog;

    final candidates = _sortedCandidates(state);
    if (widget.initialEmployee != null) {
      _selectedCardNo = widget.initialEmployee!.cardNo;
    } else if (widget.existingLog != null) {
      _selectedCardNo = widget.existingLog!.cardNo;
    } else if (candidates.isNotEmpty) {
      _selectedCardNo = candidates.first.employee.cardNo;
    }

    final selectedStatus = _findStatusByCard(state, _selectedCardNo);
    _isCheckIn = _resolveDefaultDirection(
      cardNo: _selectedCardNo,
      dateKey: _dateKey,
    );
    _timeCtrl.text = _resolveDefaultTime(
      shift: selectedStatus?.shift,
      isCheckIn: _isCheckIn,
    );
  }

  @override
  void dispose() {
    _employeeSearchCtrl.dispose();
    _timeCtrl.dispose();
    _noteCtrl.dispose();
    super.dispose();
  }

  List<EmployeeDailyStatus> _sortedCandidates(PdksDashboardState state) {
    final activeBranchId = state.effectiveSelectedBranchId;
    final list = List<EmployeeDailyStatus>.from(state.dailyStatuses);
    list.sort((a, b) {
      if (activeBranchId != null) {
        final aInBranch = a.branch.id == activeBranchId ? 0 : 1;
        final bInBranch = b.branch.id == activeBranchId ? 0 : 1;
        if (aInBranch != bInBranch) return aInBranch.compareTo(bInBranch);
      }
      final aSep = a.employee.isSeparatedNow ? 1 : 0;
      final bSep = b.employee.isSeparatedNow ? 1 : 0;
      if (aSep != bSep) return aSep.compareTo(bSep);
      return a.employee.fullName.compareTo(b.employee.fullName);
    });
    return list;
  }

  EmployeeDailyStatus? _findStatusByCard(
    PdksDashboardState state,
    String? cardNo,
  ) {
    if (cardNo == null || cardNo.isEmpty) return null;
    for (final s in state.dailyStatuses) {
      if (s.employee.cardNo == cardNo) return s;
    }
    return null;
  }

  bool _resolveDefaultDirection({
    required String? cardNo,
    required String dateKey,
  }) {
    if (widget.existingLog != null) return widget.existingLog!.isCheckIn;
    if (widget.initialIsCheckIn != null) return widget.initialIsCheckIn!;
    if (cardNo == null || cardNo.isEmpty) return true;

    final logs = ref
        .read(pdksDashboardProvider.notifier)
        .getAttendanceLogsForEmployeeOnDate(cardNo, dateKey);
    if (logs.isEmpty) return true;
    final hasIn = logs.any((l) => l.isCheckIn);
    final hasOut = logs.any((l) => !l.isCheckIn);
    if (hasIn && !hasOut) return false;
    return true;
  }

  String _formatNowHhMm() {
    final now = DateTime.now();
    return '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
  }

  String _resolveDefaultTime({
    required ShiftPlan? shift,
    required bool isCheckIn,
  }) {
    if (_editingLog != null) return _editingLog!.timeFormatted;
    if (_dateKey == PdksDashboardNotifier.todayDateKey()) {
      return _formatNowHhMm();
    }
    if (shift != null) {
      return isCheckIn ? shift.startTime : shift.endTime;
    }
    return isCheckIn ? '08:00' : '18:00';
  }

  void _applyEmployeeSelection(
    PdksDashboardState state,
    EmployeeDailyStatus status,
  ) {
    final nextDir = _resolveDefaultDirection(
      cardNo: status.employee.cardNo,
      dateKey: _dateKey,
    );
    setState(() {
      _selectedCardNo = status.employee.cardNo;
      _editingLog = null;
      _isCheckIn = nextDir;
      _validationError = null;
      if (!_hasCustomTimeInput) {
        _timeCtrl.text = _resolveDefaultTime(
          shift: status.shift,
          isCheckIn: nextDir,
        );
      }
    });
  }

  Future<void> _pickDate(ShiftPlan? shift) async {
    final initial = Employee.parseDateKey(_dateKey) ?? DateTime.now();
    final picked = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime(2035, 12, 31),
      locale: const Locale('tr', 'TR'),
      helpText: 'Hareket Tarihini Seçin',
      cancelText: 'İptal',
      confirmText: 'Seç',
    );
    if (picked == null || !mounted) return;
    final nextKey = PdksDashboardNotifier.formatDateKey(picked);
    final nextDir = _resolveDefaultDirection(
      cardNo: _selectedCardNo,
      dateKey: nextKey,
    );
    setState(() {
      _dateKey = nextKey;
      _editingLog = null;
      _isCheckIn = nextDir;
      _validationError = null;
      if (!_hasCustomTimeInput) {
        _timeCtrl.text = _resolveDefaultTime(
          shift: shift,
          isCheckIn: nextDir,
        );
      }
    });
  }

  Future<void> _pickTime() async {
    final parsed = PdksDashboardNotifier.parseStrictTimeHhMm(_timeCtrl.text);
    final now = TimeOfDay.now();
    final initial = parsed != null
        ? TimeOfDay(hour: parsed.hour, minute: parsed.minute)
        : now;
    final picked = await showTimePicker(
      context: context,
      initialTime: initial,
      helpText: 'Hareket Saatini Seçin',
      cancelText: 'İptal',
      confirmText: 'Seç',
      builder: (ctx, child) {
        final mq = MediaQuery.of(ctx);
        return MediaQuery(
          data: mq.copyWith(alwaysUse24HourFormat: true),
          child: child!,
        );
      },
    );
    if (picked == null || !mounted) return;
    setState(() {
      _hasCustomTimeInput = true;
      _validationError = null;
      _timeCtrl.text =
          '${picked.hour.toString().padLeft(2, '0')}:${picked.minute.toString().padLeft(2, '0')}';
    });
  }

  Future<void> _save(EmployeeDailyStatus? selectedStatus) async {
    if (_isSaving) return;
    final state = ref.read(pdksDashboardProvider);
    if (state.isCommercialWriteLocked) {
      setState(() {
        _validationError =
            'Salt-okunur mod aktif: ${state.licenseStatusMessage}';
      });
      return;
    }
    if (selectedStatus == null) {
      setState(() => _validationError = 'Lütfen bir personel seçin.');
      return;
    }

    final parsedTime =
        PdksDashboardNotifier.parseStrictTimeHhMm(_timeCtrl.text);
    if (parsedTime == null) {
      setState(() {
        _validationError =
            'Geçerli bir saat girin (örn. 08:30 veya 18:00).';
      });
      return;
    }

    final normalizedTime =
        '${parsedTime.hour.toString().padLeft(2, '0')}:${parsedTime.minute.toString().padLeft(2, '0')}';

    setState(() {
      _isSaving = true;
      _validationError = null;
    });

    try {
      final ok = await ref
          .read(pdksDashboardProvider.notifier)
          .saveOrUpdateAttendanceLog(
            existingLogId: _editingLog?.id,
            employee: selectedStatus.employee,
            dateKey: _dateKey,
            timeHhMm: normalizedTime,
            isCheckIn: _isCheckIn,
            source: AttendanceSource.manual,
            verifyMethod: VerifyMethod.manual,
            note: _noteCtrl.text.trim(),
          );
      if (!mounted) return;
      if (ok) {
        Navigator.of(context).pop(true);
      } else {
        setState(() {
          _isSaving = false;
          _validationError =
              'Hareket kaydedilemedi. Tarih, saat veya şube yetkisini kontrol edin.';
        });
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isSaving = false;
        _validationError = 'Kayıt sırasında hata oluştu: $e';
      });
    }
  }

  Future<void> _deleteLog(AttendanceLog log) async {
    try {
      await ref
          .read(pdksDashboardProvider.notifier)
          .deleteAttendanceLog(log.id);
      if (!mounted) return;
      setState(() {
        if (_editingLog?.id == log.id) {
          _editingLog = null;
          _hasCustomTimeInput = false;
        }
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _validationError = 'Kayıt silinemedi: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(pdksDashboardProvider);
    final pal = HasibuPalette.of(context);
    final isLocked = state.isCommercialWriteLocked;

    final candidates = _sortedCandidates(state);
    final selectedStatus = _findStatusByCard(state, _selectedCardNo) ??
        (widget.initialEmployee != null
            ? _findStatusByCard(state, widget.initialEmployee!.cardNo)
            : (candidates.isNotEmpty ? candidates.first : null));

    final query = normalizeTurkishSearch(_employeeSearchCtrl.text);
    final filteredCandidates = candidates.where((s) {
      if (query.isEmpty) return true;
      return matchesTurkishSearch(s.employee.fullName, query) ||
          matchesTurkishSearch(s.employee.cardNo, query) ||
          matchesTurkishSearch(s.department.name, query) ||
          matchesTurkishSearch(s.branch.name, query);
    }).toList(growable: false);

    final dayLogs = selectedStatus == null
        ? const <AttendanceLog>[]
        : ref
            .read(pdksDashboardProvider.notifier)
            .getAttendanceLogsForEmployeeOnDate(
              selectedStatus.employee.cardNo,
              _dateKey,
            );

    final dialogWidth = (MediaQuery.sizeOf(context).width - 40).clamp(
      290.0,
      540.0,
    );
    final shift = selectedStatus?.shift;
    final isTerminatedOnDate =
        selectedStatus?.employee.isTerminatedOn(_dateKey) ?? false;

    return AlertDialog(
      key: const ValueKey('live_attendance_punch_dialog'),
      insetPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 20),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      titlePadding: const EdgeInsets.fromLTRB(20, 18, 14, 8),
      contentPadding: const EdgeInsets.fromLTRB(20, 4, 20, 12),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: const Color(0xFF0284C7).withValues(alpha: 0.14),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(
              Icons.add_alarm_rounded,
              color: Color(0xFF0284C7),
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  _editingLog == null
                      ? 'Giriş / Çıkış Hareketi Ekle'
                      : 'Yoklama Hareketini Düzenle',
                  style: TextStyle(
                    fontSize: 15.5,
                    fontWeight: FontWeight.w800,
                    color: pal.textPrimary,
                  ),
                ),
                Text(
                  'Canlı Yoklama Manuel Kayıt',
                  style: TextStyle(fontSize: 11.5, color: pal.textSecondary),
                ),
              ],
            ),
          ),
          IconButton(
            tooltip: 'Kapat',
            onPressed: () => Navigator.of(context).pop(false),
            icon: const Icon(Icons.close_rounded, size: 20),
          ),
        ],
      ),
      content: SizedBox(
        width: dialogWidth,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (isLocked) ...[
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: const Color(0xFFDC2626).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: const Color(0xFFDC2626).withValues(alpha: 0.35),
                    ),
                  ),
                  child: Text(
                    'Salt-Okunur Mod: ${state.licenseStatusMessage}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      color: Color(0xFFDC2626),
                    ),
                  ),
                ),
                const SizedBox(height: 10),
              ],
              if (widget.initialEmployee != null && selectedStatus != null)
                _SelectedEmployeeSummaryCard(status: selectedStatus)
              else ...[
                TextField(
                  key: const ValueKey('live_punch_employee_search_field'),
                  controller: _employeeSearchCtrl,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                    labelText: 'Personel Ara (Ad, Kart No veya Bölüm)',
                    prefixIcon: const Icon(Icons.search_rounded, size: 18),
                    suffixIcon: _employeeSearchCtrl.text.isNotEmpty
                        ? IconButton(
                            tooltip: 'Aramayı Temizle',
                            icon: const Icon(Icons.clear_rounded, size: 18),
                            onPressed: () {
                              _employeeSearchCtrl.clear();
                              setState(() {});
                            },
                          )
                        : null,
                  ),
                ),
                const SizedBox(height: 8),
                if (filteredCandidates.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 8),
                    child: Text(
                      'Aramaya uygun yetkili personel bulunamadı.',
                      style: TextStyle(fontSize: 12, color: pal.textSecondary),
                    ),
                  )
                else
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Container(
                      constraints: const BoxConstraints(maxHeight: 150),
                      decoration: BoxDecoration(
                        color: pal.subtle,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: pal.border),
                      ),
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: filteredCandidates.length,
                        separatorBuilder: (_, __) =>
                            Divider(height: 1, color: pal.border),
                        itemBuilder: (_, idx) {
                          final cand = filteredCandidates[idx];
                          final isSelected =
                              cand.employee.cardNo == selectedStatus?.employee.cardNo;
                          return InkWell(
                            key: ValueKey(
                              'live_punch_emp_option_${cand.employee.cardNo}',
                            ),
                            onTap: () => _applyEmployeeSelection(state, cand),
                            child: Container(
                              color: isSelected
                                  ? const Color(0xFF0284C7).withValues(alpha: 0.10)
                                  : null,
                              padding: const EdgeInsets.symmetric(
                                horizontal: 10,
                                vertical: 7,
                              ),
                              child: Row(
                                children: [
                                  EmployeeProfileAvatar(
                                    employee: cand.employee,
                                    size: 30,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          '${cand.employee.fullName} (#${cand.employee.cardNo})',
                                          maxLines: 1,
                                          overflow: TextOverflow.ellipsis,
                                          style: TextStyle(
                                            fontSize: 12.5,
                                            fontWeight: FontWeight.w700,
                                            color: pal.textPrimary,
                                          ),
                                        ),
                                        Text(
                                          '${cand.branch.name} • ${cand.department.name}',
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
                                  if (isSelected)
                                    const Icon(
                                      Icons.check_circle_rounded,
                                      size: 18,
                                      color: Color(0xFF0284C7),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
              ],
              if (isTerminatedOnDate) ...[
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 7,
                  ),
                  decoration: BoxDecoration(
                    color: const Color(0xFFD97706).withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Text(
                    'Not: Seçili personel bu tarihte işten ayrılmış görünüyor.',
                    style: TextStyle(
                      fontSize: 11.5,
                      fontWeight: FontWeight.w600,
                      color: Color(0xFFD97706),
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const ValueKey('live_punch_date_picker_button'),
                      onPressed: () => _pickDate(shift),
                      icon: const Icon(
                        Icons.calendar_month_rounded,
                        size: 16,
                      ),
                      label: Text(
                        PdksDashboardNotifier.formatDisplayDate(_dateKey),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SegmentedButton<bool>(
                key: const ValueKey('live_punch_direction_selector'),
                segments: const [
                  ButtonSegment<bool>(
                    value: true,
                    icon: Icon(Icons.login_rounded, size: 16),
                    label: Text('İşe Giriş'),
                  ),
                  ButtonSegment<bool>(
                    value: false,
                    icon: Icon(Icons.logout_rounded, size: 16),
                    label: Text('İşten Çıkış'),
                  ),
                ],
                selected: {_isCheckIn},
                onSelectionChanged: (sel) {
                  final next = sel.first;
                  setState(() {
                    _isCheckIn = next;
                    _validationError = null;
                    if (!_hasCustomTimeInput &&
                        _editingLog == null &&
                        _dateKey != PdksDashboardNotifier.todayDateKey()) {
                      _timeCtrl.text = _resolveDefaultTime(
                        shift: shift,
                        isCheckIn: next,
                      );
                    }
                  });
                },
              ),
              const SizedBox(height: 12),
              TextField(
                key: const ValueKey('live_punch_time_field'),
                controller: _timeCtrl,
                keyboardType: TextInputType.datetime,
                onChanged: (_) {
                  _hasCustomTimeInput = true;
                  if (_validationError != null) {
                    setState(() => _validationError = null);
                  }
                },
                decoration: InputDecoration(
                  labelText: 'Hareket Saati (SS:DD)',
                  hintText: '08:30',
                  errorText: _validationError,
                  prefixIcon: const Icon(Icons.schedule_rounded, size: 18),
                  suffixIcon: IconButton(
                    key: const ValueKey('live_punch_time_picker_button'),
                    tooltip: 'Saati Seç',
                    onPressed: _pickTime,
                    icon: const Icon(Icons.access_time_rounded, size: 18),
                  ),
                ),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 6,
                runSpacing: 6,
                children: [
                  ActionChip(
                    key: const ValueKey('live_punch_quick_now'),
                    visualDensity: VisualDensity.compact,
                    label: Text(
                      'Şimdi (${_formatNowHhMm()})',
                      style: const TextStyle(fontSize: 11.5),
                    ),
                    onPressed: () {
                      setState(() {
                        _hasCustomTimeInput = true;
                        _validationError = null;
                        _timeCtrl.text = _formatNowHhMm();
                      });
                    },
                  ),
                  if (shift != null) ...[
                    ActionChip(
                      key: const ValueKey('live_punch_quick_shift_start'),
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        'Vardiya Başlangıcı (${shift.startTime})',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      onPressed: () {
                        setState(() {
                          _hasCustomTimeInput = true;
                          _validationError = null;
                          _isCheckIn = true;
                          _timeCtrl.text = shift.startTime;
                        });
                      },
                    ),
                    ActionChip(
                      key: const ValueKey('live_punch_quick_shift_end'),
                      visualDensity: VisualDensity.compact,
                      label: Text(
                        'Vardiya Bitişi (${shift.endTime})',
                        style: const TextStyle(fontSize: 11.5),
                      ),
                      onPressed: () {
                        setState(() {
                          _hasCustomTimeInput = true;
                          _validationError = null;
                          _isCheckIn = false;
                          _timeCtrl.text = shift.endTime;
                        });
                      },
                    ),
                  ],
                ],
              ),
              const SizedBox(height: 10),
              TextField(
                key: const ValueKey('live_punch_note_field'),
                controller: _noteCtrl,
                maxLines: 1,
                decoration: const InputDecoration(
                  labelText: 'Açıklama / Neden (Opsiyonel)',
                  hintText: 'Örn. Cihaz okuma hatası / Saha görevi',
                  prefixIcon: Icon(Icons.notes_rounded, size: 18),
                ),
              ),
              if (dayLogs.isNotEmpty) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Seçili Günün Kayıtları (${dayLogs.length})',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                          color: pal.textSecondary,
                        ),
                      ),
                    ),
                    if (_editingLog != null)
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _editingLog = null;
                            _hasCustomTimeInput = false;
                            _validationError = null;
                            _timeCtrl.text = _resolveDefaultTime(
                              shift: shift,
                              isCheckIn: _isCheckIn,
                            );
                          });
                        },
                        child: const Text(
                          'Yeni Kayda Dön',
                          style: TextStyle(fontSize: 11.5),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: [
                    for (final log in dayLogs)
                      InputChip(
                        key: ValueKey('live_punch_existing_log_${log.id}'),
                        visualDensity: VisualDensity.compact,
                        selected: _editingLog?.id == log.id,
                        backgroundColor: log.isCheckIn
                            ? const Color(0xFF059669).withValues(alpha: 0.12)
                            : const Color(0xFFD97706).withValues(alpha: 0.12),
                        label: Text(
                          '${log.isCheckIn ? "GİRİŞ" : "ÇIKIŞ"} ${log.timeFormatted}',
                          style: TextStyle(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w700,
                            color: log.isCheckIn
                                ? const Color(0xFF059669)
                                : const Color(0xFFD97706),
                          ),
                        ),
                        onPressed: () {
                          setState(() {
                            _editingLog = log;
                            _isCheckIn = log.isCheckIn;
                            _hasCustomTimeInput = true;
                            _validationError = null;
                            _timeCtrl.text = log.timeFormatted;
                          });
                        },
                        deleteIcon: const Icon(Icons.close_rounded, size: 14),
                        onDeleted: isLocked ? null : () => _deleteLog(log),
                      ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.of(context).pop(false),
          child: const Text('İptal'),
        ),
        FilledButton.icon(
          key: const ValueKey('live_punch_save_button'),
          onPressed:
              (isLocked || _isSaving) ? null : () => _save(selectedStatus),
          icon: _isSaving
              ? const SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.check_rounded, size: 16),
          label: Text(_editingLog == null ? 'Hareketi Kaydet' : 'Güncelle'),
        ),
      ],
    );
  }
}

class _SelectedEmployeeSummaryCard extends StatelessWidget {
  final EmployeeDailyStatus status;

  const _SelectedEmployeeSummaryCard({required this.status});

  @override
  Widget build(BuildContext context) {
    final pal = HasibuPalette.of(context);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: pal.subtle,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: pal.border),
      ),
      child: Row(
        children: [
          EmployeeProfileAvatar(employee: status.employee, size: 38),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  '${status.employee.fullName} (#${status.employee.cardNo})',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                    fontSize: 13.5,
                    fontWeight: FontWeight.w700,
                    color: pal.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  '${status.branch.name} • ${status.department.name} • Vardiya: ${status.shift.startTime}-${status.shift.endTime}',
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
        ],
      ),
    );
  }
}
