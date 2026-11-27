import '../../../core/utils/turkish_search.dart';
import 'pdks_models.dart';

/// Toplu CSV personel içe aktarım sonucu (Katman 1 — Pure Domain).
class EmployeeCsvImportResult {
  final List<Employee> validEmployees;
  final List<String> warnings;
  final int skippedExistingCount;
  final int totalRowsRead;

  const EmployeeCsvImportResult({
    required this.validEmployees,
    required this.warnings,
    required this.skippedExistingCount,
    required this.totalRowsRead,
  });
}

/// Excel / CSV metninden toplu personel kartı ayrıştırıcı ve şablon üretici.
class EmployeeBulkImportEngine {
  EmployeeBulkImportEngine._();

  static const String sampleCsvTemplate =
      'KartNo;AdSoyad;Unvan;Sube;Bolum;Vardiya;IseGiris;Telefon;Eposta\n'
      '01501;AYSE YILMAZ;OPERATOR;Merkez;URETIM;08:00;2026-11-01;05320001122;ayse@firma.com\n'
      '01502;MEHMET KAYA;TEKNISYEN;Merkez;BAKIM;08:00;2026-11-01;05330002233;mehmet@firma.com';

  static List<String> _splitCsvLine(String line, String sep) {
    final out = <String>[];
    final buf = StringBuffer();
    bool inQuotes = false;
    for (int i = 0; i < line.length; i++) {
      final ch = line[i];
      if (ch == '"') {
        if (inQuotes && i + 1 < line.length && line[i + 1] == '"') {
          buf.write('"');
          i++;
        } else {
          inQuotes = !inQuotes;
        }
      } else if (ch == sep && !inQuotes) {
        out.add(buf.toString().trim());
        buf.clear();
      } else {
        buf.write(ch);
      }
    }
    out.add(buf.toString().trim());
    return out;
  }

  static EmployeeCsvImportResult parseEmployeeCsv(
    String rawCsv, {
    required List<Branch> branches,
    required List<Department> departments,
    required List<ShiftPlan> shifts,
    required List<Employee> existingEmployees,
    String defaultHireDate = '2026-01-01',
  }) {
    final cleaned = rawCsv.replaceFirst('\uFEFF', '').trim();
    if (cleaned.isEmpty) {
      return const EmployeeCsvImportResult(
        validEmployees: <Employee>[],
        warnings: <String>['CSV içeriği boş.'],
        skippedExistingCount: 0,
        totalRowsRead: 0,
      );
    }

    final lines = cleaned
        .split(RegExp(r'\r?\n'))
        .map((l) => l.trim())
        .where((l) => l.isNotEmpty)
        .toList(growable: false);
    if (lines.isEmpty) {
      return const EmployeeCsvImportResult(
        validEmployees: <Employee>[],
        warnings: <String>['Geçerli CSV satırı bulunamadı.'],
        skippedExistingCount: 0,
        totalRowsRead: 0,
      );
    }

    final firstLine = lines.first;
    final sep = ';'.allMatches(firstLine).length >= ','.allMatches(firstLine).length
        ? ';'
        : ',';

    final existingCards = <String>{
      for (final e in existingEmployees) e.cardNo.trim().padLeft(5, '0'),
    };
    int nextId = existingEmployees.isEmpty
        ? 1
        : existingEmployees.map((e) => e.id).reduce((a, b) => a > b ? a : b) + 1;

    final fallbackBranch = branches.isNotEmpty
        ? branches.first
        : const Branch(
            id: 1,
            code: 'MERKEZ',
            name: 'Merkez',
            hasTerminal: false,
            latitude: 0.0,
            longitude: 0.0,
          );
    final fallbackDept = departments.isNotEmpty
        ? departments.first
        : Department(id: 1, name: 'GENEL', branchId: fallbackBranch.id);
    final fallbackShift = shifts.isNotEmpty
        ? shifts.first
        : const ShiftPlan(id: 1, name: 'Standart', startTime: '08:00', endTime: '18:00');

    final valid = <Employee>[];
    final warnings = <String>[];
    int skippedExisting = 0;
    int totalRowsRead = 0;

    for (int idx = 0; idx < lines.length; idx++) {
      final cols = _splitCsvLine(lines[idx], sep);
      if (idx == 0 && cols.isNotEmpty) {
        final h0 = normalizeTurkishSearch(cols[0]);
        final h1 = cols.length > 1 ? normalizeTurkishSearch(cols[1]) : '';
        if (h0.contains('kart') || h0.contains('card') || h1.contains('ad')) {
          continue;
        }
      }
      totalRowsRead++;
      if (cols.length < 2) {
        warnings.add('Satır ${idx + 1}: En az Kart No ve Ad Soyad gerekli.');
        continue;
      }

      final rawCard = cols[0].replaceAll(RegExp(r'\s+'), '');
      final fullName = cols[1].trim();
      if (rawCard.isEmpty || fullName.isEmpty) {
        warnings.add('Satır ${idx + 1}: Kart No veya Ad Soyad boş.');
        continue;
      }
      final cardNo = rawCard.padLeft(5, '0');
      if (existingCards.contains(cardNo)) {
        skippedExisting++;
        continue;
      }

      final title = cols.length > 2 && cols[2].isNotEmpty ? cols[2] : 'PERSONEL';
      final branchRaw = cols.length > 3 ? cols[3] : '';
      final deptRaw = cols.length > 4 ? cols[4] : '';
      final shiftRaw = cols.length > 5 ? cols[5] : '';
      final hireRaw = cols.length > 6 ? cols[6] : '';
      final phone = cols.length > 7 && cols[7].isNotEmpty ? cols[7] : null;
      final email = cols.length > 8 && cols[8].isNotEmpty ? cols[8] : null;

      final branch = _matchBranch(branchRaw, branches) ?? fallbackBranch;
      final dept = _matchDepartment(deptRaw, departments, branch.id) ?? fallbackDept;
      final shift = _matchShift(shiftRaw, shifts) ?? fallbackShift;
      final hireDate = Employee.normalizeDateKey(hireRaw) ?? defaultHireDate;

      existingCards.add(cardNo);
      valid.add(
        Employee(
          id: nextId++,
          cardNo: cardNo,
          fullName: fullName.toUpperCase(),
          title: title.toUpperCase(),
          departmentId: dept.id,
          branchId: branch.id,
          shiftId: shift.id,
          hireDate: hireDate,
          phone: phone,
          email: email,
        ),
      );
    }

    return EmployeeCsvImportResult(
      validEmployees: List<Employee>.unmodifiable(valid),
      warnings: List<String>.unmodifiable(warnings),
      skippedExistingCount: skippedExisting,
      totalRowsRead: totalRowsRead,
    );
  }

  static Branch? _matchBranch(String raw, List<Branch> branches) {
    final q = normalizeTurkishSearch(raw);
    if (q.isEmpty || branches.isEmpty) return null;
    for (final b in branches) {
      if (b.id.toString() == q ||
          normalizeTurkishSearch(b.code) == q ||
          matchesTurkishSearch(b.name, q)) {
        return b;
      }
    }
    return null;
  }

  static Department? _matchDepartment(
    String raw,
    List<Department> depts,
    int branchId,
  ) {
    final q = normalizeTurkishSearch(raw);
    if (q.isEmpty || depts.isEmpty) return null;
    for (final d in depts) {
      if (d.branchId == branchId &&
          (d.id.toString() == q || matchesTurkishSearch(d.name, q))) {
        return d;
      }
    }
    for (final d in depts) {
      if (d.id.toString() == q || matchesTurkishSearch(d.name, q)) {
        return d;
      }
    }
    return null;
  }

  static ShiftPlan? _matchShift(String raw, List<ShiftPlan> shifts) {
    final q = normalizeTurkishSearch(raw);
    if (q.isEmpty || shifts.isEmpty) return null;
    for (final s in shifts) {
      if (s.id.toString() == q ||
          s.startTime == raw.trim() ||
          matchesTurkishSearch(s.name, q)) {
        return s;
      }
    }
    return null;
  }
}
