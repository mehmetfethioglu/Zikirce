import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../domain/pdks_models.dart';
import '../providers/pdks_providers.dart';
import '../widgets/hasibu_theme_palette.dart';

// ============================================================================
// 2. MESAİ SAAT ARALIKLARI (VARDİYALAR), TOLERANSLAR & RESMİ TATİL (UBGT)
// ============================================================================
class ShiftAndLateToleranceSettingsView extends ConsumerWidget {
  const ShiftAndLateToleranceSettingsView({super.key});

  static const Map<int, String> _weekdayLabels = {
    1: 'Pzt',
    2: 'Sal',
    3: 'Çar',
    4: 'Per',
    5: 'Cum',
    6: 'Cmt',
    7: 'Paz',
  };

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final shifts = ref.watch(pdksDashboardProvider.select((s) => s.shifts));
    final assignments =
        ref.watch(pdksDashboardProvider.select((s) => s.shiftAssignments));
    final statuses =
        ref.watch(pdksDashboardProvider.select((s) => s.dailyStatuses));
    final holidays =
        ref.watch(pdksDashboardProvider.select((s) => s.publicHolidays));
    final pal = HasibuPalette.of(context);
    final shiftById = {for (final s in shifts) s.id: s};
    final empById = {for (final st in statuses) st.employee.id: st.employee};

    return ListView(
      padding: const EdgeInsets.all(20),
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
                  'Mesai Saat Aralıkları, Mola & Fazla Mesai Kuralları',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: pal.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Vardiya saatleri (gece vardiyası dahil), mola düşümü, geç kalma toleransı, FM eşiği, yuvarlama ve hafta tatili günlerini tanımlayın.',
                  style: TextStyle(fontSize: 12, color: pal.textSecondary),
                ),
              ],
            ),
            FilledButton.icon(
              onPressed: () => _showShiftDialog(context, ref, null),
              icon: const Icon(Icons.add_alarm_rounded, size: 18),
              label: const Text('Yeni Mesai Saat Aralığı Ekle'),
            ),
          ],
        ),
        const SizedBox(height: 14),
        for (final shift in shifts)
          Container(
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: pal.border),
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
                    Container(
                      width: 40,
                      height: 40,
                      decoration: BoxDecoration(
                        color: const Color(0xFFD97706).withValues(alpha: 0.14),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        shift.isNightShift
                            ? Icons.nights_stay_rounded
                            : Icons.access_time_filled_rounded,
                        color: const Color(0xFFD97706),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Flexible(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            shift.name,
                            style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 14,
                              color: pal.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 3),
                          Text(
                            'Saat: ${shift.startTime} - ${shift.endTime}'
                            '${shift.isNightShift ? " (Gece)" : ""}'
                            '  •  Tolerans: ${shift.toleranceMinutes} dk'
                            '${shift.breakMinutes > 0 ? "  •  Mola: ${shift.breakMinutes} dk" : ""}'
                            '  •  FM Eşiği: ${shift.overtimeThresholdMinutes} dk'
                            '${shift.roundingMinutes > 0 ? "  •  Yuvarlama: ${shift.roundingMinutes} dk" : ""}'
                            '${shift.weeklyOffDays.isNotEmpty ? "  •  Hafta Tatili: ${shift.weeklyOffDays.map((d) => _weekdayLabels[d] ?? d.toString()).join(", ")}" : ""}',
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
                Wrap(
                  spacing: 8,
                  children: [
                    FilledButton.tonalIcon(
                      key: ValueKey('edit_shift_btn_${shift.id}'),
                      onPressed: () => _showShiftDialog(context, ref, shift),
                      icon: const Icon(Icons.edit_rounded, size: 16),
                      label: const Text('Saat & Toleransı Düzenle'),
                    ),
                    if (shift.id != 1)
                      IconButton(
                        color: const Color(0xFFDC2626),
                        onPressed: () => ref
                            .read(pdksDashboardProvider.notifier)
                            .deleteShiftPlan(shift.id),
                        icon: const Icon(Icons.delete_outline_rounded),
                      ),
                  ],
                ),
              ],
            ),
          ),
        const SizedBox(height: 20),
        Divider(height: 1, color: pal.border),
        const SizedBox(height: 18),
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
                  'Tarih Bazlı Vardiya Atamaları & Rotasyon (${assignments.length} Kayıt)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: pal.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Haftalık/aylık vardiya değişimlerinde geçmiş puantajın bozulmaması için tarih aralıklı vardiya ataması tanımlayın.',
                  style: TextStyle(fontSize: 12, color: pal.textSecondary),
                ),
              ],
            ),
            FilledButton.tonalIcon(
              key: const ValueKey('add_shift_assignment_button'),
              onPressed: statuses.isEmpty || shifts.isEmpty
                  ? null
                  : () => _showShiftAssignmentDialog(context, ref),
              icon: const Icon(Icons.swap_horiz_rounded, size: 17),
              label: const Text('Yeni Vardiya Rotasyonu Ekle'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (assignments.isEmpty)
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: pal.border),
            ),
            child: Text(
              'Henüz tarih bazlı vardiya rotasyonu kaydı bulunmuyor. Personel kartından vardiya değiştirildiğinde otomatik olarak buraya da geçmiş kaydı eklenir.',
              style: TextStyle(fontSize: 12, color: pal.textSecondary),
            ),
          ),
        for (final a in assignments.take(25))
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: pal.border),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    const Color(0xFF0284C7).withValues(alpha: 0.14),
                child: const Icon(
                  Icons.event_repeat_rounded,
                  color: Color(0xFF0284C7),
                  size: 18,
                ),
              ),
              title: Text(
                '${empById[a.employeeId]?.fullName ?? "Personel #${a.employeeId}"} → ${shiftById[a.shiftId]?.name ?? "Vardiya #${a.shiftId}"}',
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: pal.textPrimary,
                ),
              ),
              subtitle: Text(
                'Geçerlilik: ${a.validFrom} — ${a.validTo ?? "Devam Ediyor"}${a.note.isNotEmpty ? " • ${a.note}" : ""}',
                style: TextStyle(fontSize: 12, color: pal.textSecondary),
              ),
              trailing: IconButton(
                tooltip: 'Rotasyon Kaydını Sil',
                color: const Color(0xFFDC2626),
                onPressed: () => ref
                    .read(pdksDashboardProvider.notifier)
                    .deleteShiftAssignment(a.id),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ),
          ),
        const SizedBox(height: 20),
        Divider(height: 1, color: pal.border),
        const SizedBox(height: 18),
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
                  'Resmi Tatil (UBGT) Takvimi (${holidays.length} Kayıt)',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w700,
                    color: pal.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Ulusal bayram ve resmi tatil günlerinde personeller devamsız yazılmaz; çoklu izin aralıklarında otomatik hariç tutulur.',
                  style: TextStyle(fontSize: 12, color: pal.textSecondary),
                ),
              ],
            ),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('seed_tr_holidays_button'),
                  onPressed: () async {
                    final year = DateTime.now().year;
                    final count = await ref
                        .read(pdksDashboardProvider.notifier)
                        .seedTurkeyOfficialHolidays(year);
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text(
                            '$year yılı Türkiye resmi tatilleri takvime eklendi ($count gün).',
                          ),
                        ),
                      );
                    }
                  },
                  icon: const Icon(Icons.auto_awesome_rounded, size: 16),
                  label: Text('TR Resmi Tatilleri Yükle (${DateTime.now().year})'),
                ),
                FilledButton.icon(
                  key: const ValueKey('add_public_holiday_button'),
                  onPressed: () => _showAddHolidayDialog(context, ref),
                  icon: const Icon(Icons.event_available_rounded, size: 16),
                  label: const Text('Yeni Tatil Ekle'),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 12),
        if (holidays.isEmpty)
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: pal.border),
            ),
            child: Text(
              'Kayıtlı resmi tatil bulunmuyor. "TR Resmi Tatilleri Yükle" ile tek tıkla doldurabilirsiniz.',
              style: TextStyle(fontSize: 12.5, color: pal.textSecondary),
            ),
          ),
        for (final holiday in holidays)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: pal.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: pal.border),
            ),
            child: ListTile(
              leading: CircleAvatar(
                backgroundColor:
                    const Color(0xFF2563EB).withValues(alpha: 0.14),
                child: const Icon(
                  Icons.celebration_rounded,
                  color: Color(0xFF2563EB),
                  size: 18,
                ),
              ),
              title: Text(
                holiday.name,
                style: TextStyle(
                  fontWeight: FontWeight.w700,
                  fontSize: 13.5,
                  color: pal.textPrimary,
                ),
              ),
              subtitle: Text(
                '${PdksDashboardNotifier.formatDisplayDate(holiday.dateKey, includeTodayBadge: false)} • ${holiday.isHalfDay ? "Yarım Gün (Arefe)" : "Tam Gün Resmi Tatil"}',
                style: TextStyle(fontSize: 12, color: pal.textSecondary),
              ),
              trailing: IconButton(
                key: ValueKey('delete_public_holiday_${holiday.id}'),
                tooltip: 'Tatili Sil',
                color: const Color(0xFFDC2626),
                onPressed: () => ref
                    .read(pdksDashboardProvider.notifier)
                    .deletePublicHoliday(holiday.id),
                icon: const Icon(Icons.delete_outline_rounded),
              ),
            ),
          ),
      ],
    );
  }

  Future<void> _showShiftDialog(
    BuildContext context,
    WidgetRef ref,
    ShiftPlan? existing,
  ) async {
    final shifts = ref.read(pdksDashboardProvider).shifts;
    final nextId = existing?.id ??
        (shifts.isEmpty
            ? 1
            : shifts.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1);

    final nameCtrl = TextEditingController(text: existing?.name ?? '');
    final startCtrl =
        TextEditingController(text: existing?.startTime ?? '08:00');
    final endCtrl = TextEditingController(text: existing?.endTime ?? '18:00');
    final tolCtrl = TextEditingController(
      text: (existing?.toleranceMinutes ?? 15).toString(),
    );
    final breakCtrl = TextEditingController(
      text: (existing?.breakMinutes ?? 0).toString(),
    );
    final otCtrl = TextEditingController(
      text: (existing?.overtimeThresholdMinutes ?? 15).toString(),
    );
    int roundingMinutes = existing?.roundingMinutes ?? 0;
    final selectedOffDays = <int>{...(existing?.weeklyOffDays ?? const <int>[])};

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: Text(
            existing == null
                ? 'Yeni Mesai Saat Aralığı Tanımla'
                : 'Mesai Saatlerini & Parametreleri Düzenle',
          ),
          content: SizedBox(
            width: 470,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  TextField(
                    controller: nameCtrl,
                    decoration: const InputDecoration(
                      labelText: 'Vardiya / Grup Adı (örn. Üretim Sabah / Gece)',
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: startCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Giriş Saati (SS:DD)',
                            hintText: '08:00',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          controller: endCtrl,
                          decoration: const InputDecoration(
                            labelText: 'Çıkış Saati (SS:DD)',
                            hintText: '18:00',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          controller: tolCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Geç Kalma Toleransı (dk)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: TextField(
                          key: const ValueKey('shift_break_minutes_field'),
                          controller: breakCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Zorunlu Mola Düşümü (dk)',
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: TextField(
                          key: const ValueKey('shift_overtime_threshold_field'),
                          controller: otCtrl,
                          keyboardType: TextInputType.number,
                          decoration: const InputDecoration(
                            labelText: 'Fazla Mesai Eşiği (dk)',
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: DropdownButtonFormField<int>(
                          key: const ValueKey('shift_rounding_minutes_dropdown'),
                          initialValue:
                              [0, 5, 15].contains(roundingMinutes)
                                  ? roundingMinutes
                                  : 0,
                          decoration: const InputDecoration(
                            labelText: 'FM Yuvarlama',
                          ),
                          items: const [
                            DropdownMenuItem(value: 0, child: Text('Yok (1 dk)')),
                            DropdownMenuItem(value: 5, child: Text('5 dk katı')),
                            DropdownMenuItem(value: 15, child: Text('15 dk katı')),
                          ],
                          onChanged: (v) {
                            if (v != null) {
                              setDialogState(() => roundingMinutes = v);
                            }
                          },
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  const Text(
                    'Hafta Tatili Günleri (Opsiyonel)',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700),
                  ),
                  const SizedBox(height: 6),
                  Wrap(
                    spacing: 6,
                    runSpacing: 6,
                    children: [
                      for (final entry in _weekdayLabels.entries)
                        FilterChip(
                          key: ValueKey('shift_weekly_off_day_${entry.key}'),
                          label: Text(entry.value),
                          selected: selectedOffDays.contains(entry.key),
                          onSelected: (checked) {
                            setDialogState(() {
                              if (checked) {
                                selectedOffDays.add(entry.key);
                              } else {
                                selectedOffDays.remove(entry.key);
                              }
                            });
                          },
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogCtx).pop(),
              child: const Text('İptal'),
            ),
            FilledButton(
              onPressed: () async {
                if (nameCtrl.text.trim().isEmpty) return;
                final sortedDays = selectedOffDays.toList()..sort();
                final shift = ShiftPlan(
                  id: nextId,
                  name: nameCtrl.text.trim(),
                  startTime: startCtrl.text.trim(),
                  endTime: endCtrl.text.trim(),
                  toleranceMinutes:
                      (int.tryParse(tolCtrl.text.trim()) ?? 15).clamp(0, 180),
                  breakMinutes:
                      (int.tryParse(breakCtrl.text.trim()) ?? 0).clamp(0, 240),
                  overtimeThresholdMinutes:
                      (int.tryParse(otCtrl.text.trim()) ?? 15).clamp(0, 240),
                  roundingMinutes: roundingMinutes,
                  weeklyOffDays: sortedDays,
                );
                await ref
                    .read(pdksDashboardProvider.notifier)
                    .saveShiftPlan(shift);
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

    nameCtrl.dispose();
    startCtrl.dispose();
    endCtrl.dispose();
    tolCtrl.dispose();
    breakCtrl.dispose();
    otCtrl.dispose();
  }

  Future<void> _showAddHolidayDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final dateCtrl =
        TextEditingController(text: PdksDashboardNotifier.todayDateKey());
    final nameCtrl = TextEditingController();
    bool isHalfDay = false;

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Resmi Tatil (UBGT) Ekle'),
          content: SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(
                  key: const ValueKey('public_holiday_date_field'),
                  controller: dateCtrl,
                  decoration: InputDecoration(
                    labelText: 'Tarih (YYYY-AA-GG)',
                    suffixIcon: IconButton(
                      icon: const Icon(Icons.calendar_today_rounded, size: 18),
                      onPressed: () async {
                        final initDt = Employee.parseDateKey(dateCtrl.text) ??
                            DateTime.now();
                        final picked = await showDatePicker(
                          context: ctx,
                          initialDate: initDt,
                          firstDate: DateTime(2020),
                          lastDate: DateTime(2035),
                        );
                        if (picked != null) {
                          setDialogState(() {
                            dateCtrl.text =
                                PdksDashboardNotifier.formatDateKey(picked);
                          });
                        }
                      },
                    ),
                  ),
                ),
                const SizedBox(height: 10),
                TextField(
                  key: const ValueKey('public_holiday_name_field'),
                  controller: nameCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Tatil Adı (örn. Cumhuriyet Bayramı)',
                  ),
                ),
                const SizedBox(height: 8),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  value: isHalfDay,
                  onChanged: (v) => setDialogState(() => isHalfDay = v),
                  title: const Text('Yarım Gün (Arefe)'),
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
              key: const ValueKey('public_holiday_save_button'),
              onPressed: () async {
                final normalized = Employee.normalizeDateKey(dateCtrl.text);
                final cleanName = nameCtrl.text.trim();
                if (normalized == null || cleanName.isEmpty) return;
                final holiday = PublicHoliday(
                  id: 'hol_${normalized.replaceAll('-', '')}',
                  dateKey: normalized,
                  name: cleanName,
                  isHalfDay: isHalfDay,
                );
                await ref
                    .read(pdksDashboardProvider.notifier)
                    .savePublicHoliday(holiday);
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

    dateCtrl.dispose();
    nameCtrl.dispose();
  }

  Future<void> _showShiftAssignmentDialog(
    BuildContext context,
    WidgetRef ref,
  ) async {
    final state = ref.read(pdksDashboardProvider);
    final employees = state.dailyStatuses
        .where((s) => !s.employee.isSeparatedNow)
        .map((s) => s.employee)
        .toList(growable: false);
    if (employees.isEmpty || state.shifts.isEmpty) return;

    int selectedEmpId = employees.first.id;
    int selectedShiftId = state.shifts.first.id;
    final fromCtrl = TextEditingController(text: state.selectedDate);
    final toCtrl = TextEditingController();
    final noteCtrl = TextEditingController();

    await showDialog<void>(
      context: context,
      builder: (dialogCtx) => StatefulBuilder(
        builder: (ctx, setDialogState) => AlertDialog(
          title: const Text('Tarih Bazlı Vardiya Ataması / Rotasyon'),
          content: SizedBox(
            width: 440,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: selectedEmpId,
                  decoration: const InputDecoration(labelText: 'Personel'),
                  items: [
                    for (final e in employees)
                      DropdownMenuItem(
                        value: e.id,
                        child: Text('${e.fullName} (#${e.cardNo})'),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedEmpId = v);
                  },
                ),
                const SizedBox(height: 10),
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: selectedShiftId,
                  decoration: const InputDecoration(labelText: 'Vardiya'),
                  items: [
                    for (final s in state.shifts)
                      DropdownMenuItem(
                        value: s.id,
                        child: Text('${s.name} (${s.startTime}-${s.endTime})'),
                      ),
                  ],
                  onChanged: (v) {
                    if (v != null) setDialogState(() => selectedShiftId = v);
                  },
                ),
                const SizedBox(height: 10),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: fromCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Başlangıç (YYYY-AA-GG)',
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: TextField(
                        controller: toCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Bitiş (Opsiyonel)',
                          hintText: 'Boş = Süresiz',
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
                TextField(
                  controller: noteCtrl,
                  decoration: const InputDecoration(
                    labelText: 'Açıklama (Opsiyonel)',
                  ),
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
                final fromNorm = Employee.normalizeDateKey(fromCtrl.text);
                if (fromNorm == null) return;
                final toNorm = Employee.normalizeDateKey(toCtrl.text);
                await ref
                    .read(pdksDashboardProvider.notifier)
                    .saveShiftAssignment(
                      ShiftAssignment(
                        id: 'sa_${selectedEmpId}_${fromNorm}_${selectedShiftId}_${DateTime.now().millisecondsSinceEpoch}',
                        employeeId: selectedEmpId,
                        shiftId: selectedShiftId,
                        validFrom: fromNorm,
                        validTo: toNorm,
                        note: noteCtrl.text.trim(),
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
    fromCtrl.dispose();
    toCtrl.dispose();
    noteCtrl.dispose();
  }
}
