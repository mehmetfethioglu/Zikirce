import '../../features/pdks/domain/pdks_models.dart';
import 'hasibu_database.dart';

/// Resmi Tatil (UBGT), Dini Bayramlar ve Tarih Bazlı Vardiya Atama DAO'su (Katman 2).
extension HasibuPdksScheduleDao on HasibuDatabase {
  void initPdksScheduleSchema() {
    rawDb.execute('''
      CREATE TABLE IF NOT EXISTS public_holidays (
        id TEXT PRIMARY KEY,
        date_key TEXT NOT NULL UNIQUE,
        name TEXT NOT NULL,
        is_half_day INTEGER NOT NULL DEFAULT 0
      );
      CREATE INDEX IF NOT EXISTS idx_public_holidays_date
        ON public_holidays(date_key);

      CREATE TABLE IF NOT EXISTS employee_shift_assignments (
        id TEXT PRIMARY KEY,
        employee_id INTEGER NOT NULL,
        shift_id INTEGER NOT NULL,
        valid_from TEXT NOT NULL,
        valid_to TEXT,
        note TEXT NOT NULL DEFAULT ''
      );
      CREATE INDEX IF NOT EXISTS idx_shift_assign_emp_from
        ON employee_shift_assignments(employee_id, valid_from);
    ''');
  }

  List<PublicHoliday> getPublicHolidays() {
    final rows = rawDb.select(
      'SELECT * FROM public_holidays ORDER BY date_key ASC',
    );
    return rows
        .map(
          (r) => PublicHoliday(
            id: r['id'] as String,
            dateKey: r['date_key'] as String,
            name: r['name'] as String,
            isHalfDay: (r['is_half_day'] as int? ?? 0) == 1,
          ),
        )
        .toList(growable: false);
  }

  List<PublicHoliday> getPublicHolidaysInDateRange(
    String startDateKey,
    String endDateKey,
  ) {
    final stmt = rawDb.prepare('''
      SELECT * FROM public_holidays
      WHERE date_key >= ? AND date_key <= ?
      ORDER BY date_key ASC
    ''');
    try {
      final rows = stmt.select([startDateKey, endDateKey]);
      return rows
          .map(
            (r) => PublicHoliday(
              id: r['id'] as String,
              dateKey: r['date_key'] as String,
              name: r['name'] as String,
              isHalfDay: (r['is_half_day'] as int? ?? 0) == 1,
            ),
          )
          .toList(growable: false);
    } finally {
      stmt.dispose();
    }
  }

  void upsertPublicHoliday(PublicHoliday holiday) {
    final normalizedDate =
        Employee.normalizeDateKey(holiday.dateKey) ?? holiday.dateKey.trim();
    final id = holiday.id.trim().isEmpty
        ? 'holiday_$normalizedDate'
        : holiday.id.trim();
    final stmt = rawDb.prepare('''
      INSERT OR REPLACE INTO public_holidays
      (id, date_key, name, is_half_day)
      VALUES (?, ?, ?, ?)
    ''');
    try {
      stmt.execute([
        id,
        normalizedDate,
        holiday.name.trim().isEmpty ? 'Resmi Tatil' : holiday.name.trim(),
        holiday.isHalfDay ? 1 : 0,
      ]);
    } finally {
      stmt.dispose();
    }
  }

  void deletePublicHoliday(String id) {
    final stmt = rawDb.prepare('DELETE FROM public_holidays WHERE id = ?');
    try {
      stmt.execute([id]);
    } finally {
      stmt.dispose();
    }
  }

  List<ShiftAssignment> getShiftAssignments({int? employeeId}) {
    final stmt = employeeId == null
        ? rawDb.prepare(
            'SELECT * FROM employee_shift_assignments ORDER BY valid_from DESC, id DESC',
          )
        : rawDb.prepare(
            'SELECT * FROM employee_shift_assignments WHERE employee_id = ? ORDER BY valid_from DESC, id DESC',
          );
    try {
      final rows = employeeId == null ? stmt.select() : stmt.select([employeeId]);
      return rows
          .map(
            (r) => ShiftAssignment(
              id: r['id'] as String,
              employeeId: r['employee_id'] as int,
              shiftId: r['shift_id'] as int,
              validFrom: r['valid_from'] as String,
              validTo: Employee.normalizeDateKey(r['valid_to'] as String?),
              note: r['note'] as String? ?? '',
            ),
          )
          .toList(growable: false);
    } finally {
      stmt.dispose();
    }
  }

  void upsertShiftAssignment(ShiftAssignment assignment) {
    final normFrom = Employee.normalizeDateKey(assignment.validFrom) ??
        assignment.validFrom.trim();
    final normTo = Employee.normalizeDateKey(assignment.validTo);
    final id = assignment.id.trim().isEmpty
        ? 'sa_${assignment.employeeId}_${normFrom}_${assignment.shiftId}'
        : assignment.id.trim();
    final stmt = rawDb.prepare('''
      INSERT OR REPLACE INTO employee_shift_assignments
      (id, employee_id, shift_id, valid_from, valid_to, note)
      VALUES (?, ?, ?, ?, ?, ?)
    ''');
    try {
      stmt.execute([
        id,
        assignment.employeeId,
        assignment.shiftId,
        normFrom,
        normTo,
        assignment.note.trim(),
      ]);
    } finally {
      stmt.dispose();
    }
  }

  void deleteShiftAssignment(String id) {
    final stmt =
        rawDb.prepare('DELETE FROM employee_shift_assignments WHERE id = ?');
    try {
      stmt.execute([id]);
    } finally {
      stmt.dispose();
    }
  }

  /// Belirtilen yılın sabit Türkiye UBGT günleri, 28 Ekim Arifesi ve 2024-2030
  /// Ramazan/Kurban Bayramı (Arefe dahil) resmi tatillerini yükler.
  int seedTurkeyOfficialHolidays(int year) {
    final y = year.toString().padLeft(4, '0');
    final items = <({String dateKey, String name, bool isHalfDay})>[
      (dateKey: '$y-01-01', name: 'Yılbaşı', isHalfDay: false),
      (
        dateKey: '$y-04-23',
        name: '23 Nisan Ulusal Egemenlik ve Çocuk Bayramı',
        isHalfDay: false,
      ),
      (
        dateKey: '$y-05-01',
        name: '1 Mayıs Emek ve Dayanışma Günü',
        isHalfDay: false,
      ),
      (
        dateKey: '$y-05-19',
        name: '19 Mayıs Atatürk\'ü Anma, Gençlik ve Spor Bayramı',
        isHalfDay: false,
      ),
      (
        dateKey: '$y-07-15',
        name: '15 Temmuz Demokrasi ve Millî Birlik Günü',
        isHalfDay: false,
      ),
      (dateKey: '$y-08-30', name: '30 Ağustos Zafer Bayramı', isHalfDay: false),
      (
        dateKey: '$y-10-28',
        name: 'Cumhuriyet Bayramı Arifesi (Yarım Gün)',
        isHalfDay: true,
      ),
      (
        dateKey: '$y-10-29',
        name: '29 Ekim Cumhuriyet Bayramı',
        isHalfDay: false,
      ),
    ];

    final religiousByYear =
        <int, ({String ramazanStart, String kurbanStart})>{
      2024: (ramazanStart: '2024-04-10', kurbanStart: '2024-06-16'),
      2025: (ramazanStart: '2025-03-30', kurbanStart: '2025-06-06'),
      2026: (ramazanStart: '2026-03-20', kurbanStart: '2026-05-27'),
      2027: (ramazanStart: '2027-03-09', kurbanStart: '2027-05-16'),
      2028: (ramazanStart: '2028-02-26', kurbanStart: '2028-05-05'),
      2029: (ramazanStart: '2029-02-14', kurbanStart: '2029-04-24'),
      2030: (ramazanStart: '2030-02-04', kurbanStart: '2030-04-13'),
    };

    final religious = religiousByYear[year];
    if (religious != null) {
      final ramStart = Employee.parseDateKey(religious.ramazanStart);
      if (ramStart != null) {
        final arefe = ramStart.subtract(const Duration(days: 1));
        items.add((
          dateKey: _formatDateKey(arefe),
          name: 'Ramazan Bayramı Arifesi (Yarım Gün)',
          isHalfDay: true,
        ));
        for (int i = 0; i < 3; i++) {
          items.add((
            dateKey: _formatDateKey(ramStart.add(Duration(days: i))),
            name: 'Ramazan Bayramı (${i + 1}. Gün)',
            isHalfDay: false,
          ));
        }
      }
      final kurStart = Employee.parseDateKey(religious.kurbanStart);
      if (kurStart != null) {
        final arefe = kurStart.subtract(const Duration(days: 1));
        items.add((
          dateKey: _formatDateKey(arefe),
          name: 'Kurban Bayramı Arifesi (Yarım Gün)',
          isHalfDay: true,
        ));
        for (int i = 0; i < 4; i++) {
          items.add((
            dateKey: _formatDateKey(kurStart.add(Duration(days: i))),
            name: 'Kurban Bayramı (${i + 1}. Gün)',
            isHalfDay: false,
          ));
        }
      }
    }

    final existingDates = getPublicHolidays().map((h) => h.dateKey).toSet();
    int added = 0;
    for (final item in items) {
      if (existingDates.contains(item.dateKey)) continue;
      upsertPublicHoliday(
        PublicHoliday(
          id: 'tr_${item.dateKey}',
          dateKey: item.dateKey,
          name: item.name,
          isHalfDay: item.isHalfDay,
        ),
      );
      existingDates.add(item.dateKey);
      added++;
    }
    return added;
  }

  static String _formatDateKey(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';
}
