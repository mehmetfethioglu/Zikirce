import '../../../core/utils/turkish_search.dart';
import 'attendance_evaluation_engine.dart';
import 'pdks_models.dart';

/// Saf PDKS dönem raporu, 31 günlük aylık puantaj matrisi, CSV dışa aktarım ve
/// 4857 uyum/proaktif uyarı motoru (Katman 1 — Pure Domain).
class AttendanceReportEngine {
  AttendanceReportEngine._();

  /// Excel formül enjeksiyonuna (`=`, `+`, `-`, `@`, `\t`, `\r`) ve `;` / `"` / `\n`
  /// taşmalarına karşı RFC-4180 uyumlu CSV hücre koruması uygular.
  static String sanitizeCsvCell(String raw) {
    var val = raw.replaceAll('\r\n', ' ').replaceAll('\n', ' ').replaceAll('\r', ' ');
    if (val.isNotEmpty) {
      final first = val[0];
      if (first == '=' ||
          first == '+' ||
          first == '-' ||
          first == '@' ||
          first == '\t') {
        val = "'$val";
      }
    }
    if (val.contains(';') || val.contains('"')) {
      final escaped = val.replaceAll('"', '""');
      return '"$escaped"';
    }
    return val;
  }

  static List<EmployeeAttendancePeriodSummary> buildAttendancePeriodReport({
    required String startDateKey,
    required String endDateKey,
    required List<Employee> employees,
    required Map<int, Branch> branchMap,
    required Map<int, Department> deptMap,
    required Map<int, ShiftPlan> shiftMap,
    required Branch fallbackBranch,
    required ShiftPlan fallbackShift,
    required List<AttendanceLog> logsWithBoundaryDays,
    required List<LeaveRecord> leaves,
    required Map<String, PublicHoliday> holidayByDate,
    List<ShiftAssignment> shiftAssignments = const <ShiftAssignment>[],
    int? filterBranchId,
    int? departmentId,
    String searchQuery = '',
    bool onlyWithAbsences = false,
    bool onlyWithLates = false,
    bool excludeSundays = false,
  }) {
    final parsedStart = DateTime.tryParse(startDateKey) ?? DateTime.now();
    final parsedEnd = DateTime.tryParse(endDateKey) ?? parsedStart;
    var rangeStart =
        DateTime(parsedStart.year, parsedStart.month, parsedStart.day);
    var rangeEnd = DateTime(parsedEnd.year, parsedEnd.month, parsedEnd.day);
    if (rangeStart.isAfter(rangeEnd)) {
      final tmp = rangeStart;
      rangeStart = rangeEnd;
      rangeEnd = tmp;
    }
    if (rangeEnd.difference(rangeStart).inDays > 365) {
      rangeStart = rangeEnd.subtract(const Duration(days: 365));
    }

    final logsByCardDate = <String, List<AttendanceLog>>{};
    for (final log in logsWithBoundaryDays) {
      final key = '${log.cardNo}|${log.dateKey}';
      logsByCardDate.putIfAbsent(key, () => <AttendanceLog>[]).add(log);
    }

    final leavesByEmpDate = <String, LeaveRecord>{};
    for (final leave in leaves) {
      leavesByEmpDate['${leave.employeeId}|${leave.date}'] = leave;
    }

    final assignmentsByEmp = <int, List<ShiftAssignment>>{};
    for (final a in shiftAssignments) {
      assignmentsByEmp
          .putIfAbsent(a.employeeId, () => <ShiftAssignment>[])
          .add(a);
    }

    final dayKeys = <({DateTime date, String key})>[];
    for (var cursor = rangeStart;
        !cursor.isAfter(rangeEnd);
        cursor = cursor.add(const Duration(days: 1))) {
      dayKeys.add((
        date: cursor,
        key: AttendanceEvaluationEngine.formatDateKey(cursor),
      ));
    }

    final q = normalizeTurkishSearch(searchQuery);
    final results = <EmployeeAttendancePeriodSummary>[];

    for (final emp in employees) {
      if (filterBranchId != null && emp.branchId != filterBranchId) {
        continue;
      }
      if (departmentId != null && emp.departmentId != departmentId) continue;

      final branch = branchMap[emp.branchId] ?? fallbackBranch;
      final dept = deptMap[emp.departmentId] ??
          const Department(id: 1, name: 'GENEL', branchId: 1);
      final empAssignments = assignmentsByEmp[emp.id] ?? const <ShiftAssignment>[];
      final defaultShift = shiftMap[emp.shiftId] ?? fallbackShift;

      if (q.isNotEmpty) {
        final matched = matchesTurkishSearch(emp.fullName, q) ||
            matchesTurkishSearch(emp.cardNo, q) ||
            matchesTurkishSearch(dept.name, q);
        if (!matched) continue;
      }

      int totalDays = 0;
      int presentDays = 0;
      int onTimeDays = 0;
      int lateDays = 0;
      int totalLateMinutes = 0;
      int absentDays = 0;
      int onLeaveDays = 0;
      int sickReportDays = 0;
      int missingCheckOutDays = 0;
      int totalWorkedMinutes = 0;
      int totalOvertimeMinutes = 0;
      int totalEarlyLeaveMinutes = 0;
      final absentDateKeys = <String>[];

      for (final day in dayKeys) {
        final empLogs = logsByCardDate['${emp.cardNo}|${day.key}'] ??
            const <AttendanceLog>[];
        final prevLogs = logsByCardDate[
                '${emp.cardNo}|${AttendanceEvaluationEngine.previousDateKey(day.key)}'] ??
            const <AttendanceLog>[];
        final nextLogs = logsByCardDate[
                '${emp.cardNo}|${AttendanceEvaluationEngine.nextDateKey(day.key)}'] ??
            const <AttendanceLog>[];
        final leave = leavesByEmpDate['${emp.id}|${day.key}'];
        final holiday = holidayByDate[day.key];

        if (excludeSundays &&
            day.date.weekday == DateTime.sunday &&
            empLogs.isEmpty &&
            leave == null) {
          continue;
        }

        final dayShift = AttendanceEvaluationEngine.resolveShiftForDate(
          employee: emp,
          dateKey: day.key,
          shiftMap: shiftMap,
          fallbackShift: defaultShift,
          shiftAssignments: empAssignments,
        );

        final eval = AttendanceEvaluationEngine.evaluateDay(
          rawDayLogs: empLogs,
          previousDayLogs: prevLogs,
          nextDayLogs: nextLogs,
          shift: dayShift,
          leave: leave,
          publicHoliday: holiday,
          employee: emp,
          dateKey: day.key,
        );

        if (eval.state.isNonActiveEmployment) {
          continue;
        }

        totalDays++;

        switch (eval.state) {
          case DailyAttendanceState.present:
            presentDays++;
            onTimeDays++;
          case DailyAttendanceState.late:
            presentDays++;
            lateDays++;
          case DailyAttendanceState.absent:
            absentDays++;
            absentDateKeys.add(day.key);
          case DailyAttendanceState.onLeave:
            onLeaveDays++;
          case DailyAttendanceState.sickReport:
            sickReportDays++;
          case DailyAttendanceState.publicHoliday:
          case DailyAttendanceState.weeklyOff:
          case DailyAttendanceState.terminated:
          case DailyAttendanceState.notYetHired:
            break;
        }

        totalLateMinutes += eval.lateMinutes;
        totalWorkedMinutes += eval.workedMinutes;
        totalOvertimeMinutes += eval.overtimeMinutes;
        totalEarlyLeaveMinutes += eval.earlyLeaveMinutes;
        if (eval.hasMissingCheckOut) {
          missingCheckOutDays++;
        }
      }

      if (totalDays == 0) continue;
      if (onlyWithAbsences && absentDays <= 0) continue;
      if (onlyWithLates && lateDays <= 0) continue;

      final anchorShift = AttendanceEvaluationEngine.resolveShiftForDate(
        employee: emp,
        dateKey: endDateKey,
        shiftMap: shiftMap,
        fallbackShift: defaultShift,
        shiftAssignments: empAssignments,
      );

      results.add(
        EmployeeAttendancePeriodSummary(
          employee: emp,
          department: dept,
          branch: branch,
          shift: anchorShift,
          totalDays: totalDays,
          presentDays: presentDays,
          onTimeDays: onTimeDays,
          lateDays: lateDays,
          totalLateMinutes: totalLateMinutes,
          absentDays: absentDays,
          onLeaveDays: onLeaveDays,
          sickReportDays: sickReportDays,
          missingCheckOutDays: missingCheckOutDays,
          totalWorkedMinutes: totalWorkedMinutes,
          totalOvertimeMinutes: totalOvertimeMinutes,
          totalEarlyLeaveMinutes: totalEarlyLeaveMinutes,
          absentDateKeys: List<String>.unmodifiable(absentDateKeys),
        ),
      );
    }

    results.sort((a, b) {
      final absCmp = b.absentDays.compareTo(a.absentDays);
      if (absCmp != 0) return absCmp;
      final lateCmp = b.lateDays.compareTo(a.lateDays);
      if (lateCmp != 0) return lateCmp;
      return a.employee.fullName.compareTo(b.employee.fullName);
    });
    return results;
  }

  static String generateDailyPuantajCsv({
    required String selectedDate,
    required List<EmployeeDailyStatus> rows,
  }) {
    final buf = StringBuffer();
    buf.writeln(
      'Tarih;Kart No;Ad Soyad;Şube;Bölüm;Vardiya;İlk Giriş;Son Çıkış;Net Çalışma (Dk);Gecikme (Dk);Fazla Mesai (Dk);Erken Çıkış (Dk);Eksik Çıkış;Durum;Doğrulama',
    );
    for (final item in rows) {
      final inStr = item.firstCheckIn?.timeFormatted ?? '-';
      final outStr = item.lastCheckOut?.timeFormatted ?? '-';
      final verifyStr = item.firstCheckIn?.verifyMethod.label ??
          (item.leaveRecord?.leaveType.label ??
              item.publicHoliday?.name ??
              '-');
      buf.writeln(
        '${sanitizeCsvCell(selectedDate)};'
        '${sanitizeCsvCell(item.employee.cardNo)};'
        '${sanitizeCsvCell(item.employee.fullName)};'
        '${sanitizeCsvCell(item.branch.name)};'
        '${sanitizeCsvCell(item.department.name)};'
        '${sanitizeCsvCell("${item.shift.startTime}-${item.shift.endTime}")};'
        '${sanitizeCsvCell(inStr)};'
        '${sanitizeCsvCell(outStr)};'
        '${item.workedMinutes};'
        '${item.lateMinutes};'
        '${item.overtimeMinutes};'
        '${item.earlyLeaveMinutes};'
        '${item.hasMissingCheckOut ? "EVET" : "HAYIR"};'
        '${sanitizeCsvCell(item.state.label)};'
        '${sanitizeCsvCell(verifyStr)}',
      );
    }
    return buf.toString();
  }

  static String generatePeriodAttendanceReportCsv({
    required String startDateKey,
    required String endDateKey,
    required List<EmployeeAttendancePeriodSummary> summaries,
  }) {
    final buf = StringBuffer();
    buf.writeln(
      'Başlangıç;Bitiş;Kart No;Ad Soyad;Şube;Bölüm;Vardiya;Toplam Gün;Devam Edilen;Zamanında;Geç Gelme (Gün);Toplam Gecikme (Dk);Devamsız (Gün);İzinli (Gün);Raporlu (Gün);Eksik Çıkış (Gün);Net Çalışma (Dk);Fazla Mesai (Dk);Erken Çıkış (Dk);Devam Oranı (%)',
    );
    for (final s in summaries) {
      buf.writeln(
        '${sanitizeCsvCell(startDateKey)};'
        '${sanitizeCsvCell(endDateKey)};'
        '${sanitizeCsvCell(s.employee.cardNo)};'
        '${sanitizeCsvCell(s.employee.fullName)};'
        '${sanitizeCsvCell(s.branch.name)};'
        '${sanitizeCsvCell(s.department.name)};'
        '${sanitizeCsvCell("${s.shift.startTime}-${s.shift.endTime}")};'
        '${s.totalDays};'
        '${s.presentDays};'
        '${s.onTimeDays};'
        '${s.lateDays};'
        '${s.totalLateMinutes};'
        '${s.absentDays};'
        '${s.onLeaveDays};'
        '${s.sickReportDays};'
        '${s.missingCheckOutDays};'
        '${s.totalWorkedMinutes};'
        '${s.totalOvertimeMinutes};'
        '${s.totalEarlyLeaveMinutes};'
        '${s.attendanceRatePercent.toStringAsFixed(1)}',
      );
    }
    return buf.toString();
  }

  /// 1–31 gün aylık puantaj matrisi (`X`, `G`, `FM`, `HT`, `BM`, `İ`, `R`, `T`, `B`, `D`, `-`).
  static List<MonthlyPuantajRow> buildMonthlyPuantajMatrix({
    required int year,
    required int month,
    required List<Employee> employees,
    required Map<int, Branch> branchMap,
    required Map<int, Department> deptMap,
    required Map<int, ShiftPlan> shiftMap,
    required Branch fallbackBranch,
    required ShiftPlan fallbackShift,
    required List<AttendanceLog> logsWithBoundaryDays,
    required List<LeaveRecord> leaves,
    required Map<String, PublicHoliday> holidayByDate,
    List<ShiftAssignment> shiftAssignments = const <ShiftAssignment>[],
    int? filterBranchId,
    int? departmentId,
    String searchQuery = '',
  }) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final logsByCardDate = <String, List<AttendanceLog>>{};
    for (final log in logsWithBoundaryDays) {
      logsByCardDate
          .putIfAbsent('${log.cardNo}|${log.dateKey}', () => <AttendanceLog>[])
          .add(log);
    }
    final leavesByEmpDate = <String, LeaveRecord>{
      for (final lv in leaves) '${lv.employeeId}|${lv.date}': lv,
    };
    final assignmentsByEmp = <int, List<ShiftAssignment>>{};
    for (final a in shiftAssignments) {
      assignmentsByEmp
          .putIfAbsent(a.employeeId, () => <ShiftAssignment>[])
          .add(a);
    }

    final q = normalizeTurkishSearch(searchQuery);
    final rows = <MonthlyPuantajRow>[];

    for (final emp in employees) {
      if (filterBranchId != null && emp.branchId != filterBranchId) continue;
      if (departmentId != null && emp.departmentId != departmentId) continue;

      final branch = branchMap[emp.branchId] ?? fallbackBranch;
      final dept = deptMap[emp.departmentId] ??
          const Department(id: 1, name: 'GENEL', branchId: 1);
      final empAssignments = assignmentsByEmp[emp.id] ?? const <ShiftAssignment>[];
      final defaultShift = shiftMap[emp.shiftId] ?? fallbackShift;

      if (q.isNotEmpty) {
        final matched = matchesTurkishSearch(emp.fullName, q) ||
            matchesTurkishSearch(emp.cardNo, q) ||
            matchesTurkishSearch(dept.name, q);
        if (!matched) continue;
      }

      final cells = <MonthlyPuantajDayCell>[];
      int workedDays = 0;
      int lateDays = 0;
      int absentDays = 0;
      int leaveDays = 0;
      int sickDays = 0;
      int offAndHolidayDays = 0;
      int totalWorkedMinutes = 0;
      int totalLateMinutes = 0;
      int totalOvertimeMinutes = 0;
      bool anyActiveDay = false;

      for (int day = 1; day <= daysInMonth; day++) {
        final dt = DateTime(year, month, day);
        final dateKey = AttendanceEvaluationEngine.formatDateKey(dt);
        final empLogs = logsByCardDate['${emp.cardNo}|$dateKey'] ??
            const <AttendanceLog>[];
        final prevLogs = logsByCardDate[
                '${emp.cardNo}|${AttendanceEvaluationEngine.previousDateKey(dateKey)}'] ??
            const <AttendanceLog>[];
        final nextLogs = logsByCardDate[
                '${emp.cardNo}|${AttendanceEvaluationEngine.nextDateKey(dateKey)}'] ??
            const <AttendanceLog>[];
        final leave = leavesByEmpDate['${emp.id}|$dateKey'];
        final holiday = holidayByDate[dateKey];

        final dayShift = AttendanceEvaluationEngine.resolveShiftForDate(
          employee: emp,
          dateKey: dateKey,
          shiftMap: shiftMap,
          fallbackShift: defaultShift,
          shiftAssignments: empAssignments,
        );

        final eval = AttendanceEvaluationEngine.evaluateDay(
          rawDayLogs: empLogs,
          previousDayLogs: prevLogs,
          nextDayLogs: nextLogs,
          shift: dayShift,
          leave: leave,
          publicHoliday: holiday,
          employee: emp,
          dateKey: dateKey,
        );

        if (!eval.state.isNonActiveEmployment) {
          anyActiveDay = true;
        }

        final String code;
        switch (eval.state) {
          case DailyAttendanceState.present:
            workedDays++;
            if (eval.isHolidayWork) {
              code = 'BM';
            } else if (eval.isWeeklyOffWork) {
              code = 'HT';
            } else {
              code = eval.overtimeMinutes > 0 ? 'FM' : 'X';
            }
          case DailyAttendanceState.late:
            workedDays++;
            lateDays++;
            code = 'G';
          case DailyAttendanceState.onLeave:
            leaveDays++;
            code = 'İ';
          case DailyAttendanceState.sickReport:
            sickDays++;
            code = 'R';
          case DailyAttendanceState.publicHoliday:
            offAndHolidayDays++;
            code = 'B';
          case DailyAttendanceState.weeklyOff:
            offAndHolidayDays++;
            code = 'T';
          case DailyAttendanceState.absent:
            absentDays++;
            code = 'D';
          case DailyAttendanceState.terminated:
          case DailyAttendanceState.notYetHired:
            code = '-';
        }

        totalWorkedMinutes += eval.workedMinutes;
        totalLateMinutes += eval.lateMinutes;
        totalOvertimeMinutes += eval.overtimeMinutes;

        cells.add(
          MonthlyPuantajDayCell(
            day: day,
            dateKey: dateKey,
            code: code,
            state: eval.state,
            workedMinutes: eval.workedMinutes,
            lateMinutes: eval.lateMinutes,
            overtimeMinutes: eval.overtimeMinutes,
            isHolidayWork: eval.isHolidayWork,
            isWeeklyOffWork: eval.isWeeklyOffWork,
          ),
        );
      }

      if (!anyActiveDay) continue;

      final anchorShift = AttendanceEvaluationEngine.resolveShiftForDate(
        employee: emp,
        dateKey: AttendanceEvaluationEngine.formatDateKey(
          DateTime(year, month, daysInMonth),
        ),
        shiftMap: shiftMap,
        fallbackShift: defaultShift,
        shiftAssignments: empAssignments,
      );

      rows.add(
        MonthlyPuantajRow(
          employee: emp,
          branch: branch,
          department: dept,
          shift: anchorShift,
          year: year,
          month: month,
          cells: List<MonthlyPuantajDayCell>.unmodifiable(cells),
          workedDays: workedDays,
          lateDays: lateDays,
          absentDays: absentDays,
          leaveDays: leaveDays,
          sickDays: sickDays,
          offAndHolidayDays: offAndHolidayDays,
          totalWorkedMinutes: totalWorkedMinutes,
          totalLateMinutes: totalLateMinutes,
          totalOvertimeMinutes: totalOvertimeMinutes,
        ),
      );
    }

    rows.sort((a, b) => a.employee.fullName.compareTo(b.employee.fullName));
    return rows;
  }

  static String generateMonthlyPuantajCsv(
    List<MonthlyPuantajRow> rows, {
    required int year,
    required int month,
  }) {
    final daysInMonth = DateTime(year, month + 1, 0).day;
    final dayHeaders =
        List<String>.generate(daysInMonth, (i) => '${i + 1}').join(';');
    final buf = StringBuffer()
      ..writeln(
        'Dönem;Kart No;Ad Soyad;Şube;Bölüm;$dayHeaders;Çalışılan Gün;Geç Gün;İzin;Rapor;Tatil/UBGT;Devamsız;Net Çalışma (Dk);Fazla Mesai (Dk);Gecikme (Dk)',
      );
    final periodLabel = '$year-${month.toString().padLeft(2, '0')}';
    for (final r in rows) {
      final cellStr = r.cells.map((c) => c.code).join(';');
      buf.writeln(
        '${sanitizeCsvCell(periodLabel)};'
        '${sanitizeCsvCell(r.employee.cardNo)};'
        '${sanitizeCsvCell(r.employee.fullName)};'
        '${sanitizeCsvCell(r.branch.name)};'
        '${sanitizeCsvCell(r.department.name)};'
        '$cellStr;'
        '${r.workedDays};${r.lateDays};${r.leaveDays};${r.sickDays};${r.offAndHolidayDays};${r.absentDays};'
        '${r.totalWorkedMinutes};${r.totalOvertimeMinutes};${r.totalLateMinutes}',
      );
    }
    return buf.toString();
  }

  /// Proaktif İK & 4857 Uyum Uyarıları (Ardışık devamsızlık, evrak bitişi, deneme süresi,
  /// eksik çıkış, gece 7,5 saat sınırı ve haftalık 45 saat sınırı).
  static List<PdksProactiveAlert> buildProactiveAlerts({
    required String anchorDateKey,
    required List<EmployeeDailyStatus> todayStatuses,
    required List<Employee> employees,
    required List<AttendanceLog> recentLogs,
    required List<LeaveRecord> recentLeaves,
    required Map<String, PublicHoliday> holidays,
    required List<PersonnelDocument> documents,
    required Map<int, ShiftPlan> shiftMap,
    required ShiftPlan fallbackShift,
    List<ShiftAssignment> shiftAssignments = const <ShiftAssignment>[],
  }) {
    final alerts = <PdksProactiveAlert>[];
    final anchorDate = Employee.parseDateKey(anchorDateKey) ?? DateTime.now();

    final logsByCardDate = <String, List<AttendanceLog>>{};
    for (final l in recentLogs) {
      logsByCardDate
          .putIfAbsent('${l.cardNo}|${l.dateKey}', () => <AttendanceLog>[])
          .add(l);
    }
    final leavesByEmpDate = <String, LeaveRecord>{
      for (final lv in recentLeaves) '${lv.employeeId}|${lv.date}': lv,
    };
    final assignmentsByEmp = <int, List<ShiftAssignment>>{};
    for (final a in shiftAssignments) {
      assignmentsByEmp
          .putIfAbsent(a.employeeId, () => <ShiftAssignment>[])
          .add(a);
    }

    // 1. Ardışık 2+ gün mazeretsiz devamsızlık & haftalık 45 saat / gece 7,5 saat denetimi
    for (final emp in employees) {
      if (emp.isTerminatedOn(anchorDateKey) ||
          emp.isBeforeHireDate(anchorDateKey)) {
        continue;
      }
      final empAssignments = assignmentsByEmp[emp.id] ?? const <ShiftAssignment>[];
      final defaultShift = shiftMap[emp.shiftId] ?? fallbackShift;
      int streak = 0;
      bool streakClosed = false;
      int weeklyWorkedMinutes = 0;

      for (int offset = 0; offset < 7; offset++) {
        final dKey = AttendanceEvaluationEngine.formatDateKey(
          anchorDate.subtract(Duration(days: offset)),
        );
        final dayShift = AttendanceEvaluationEngine.resolveShiftForDate(
          employee: emp,
          dateKey: dKey,
          shiftMap: shiftMap,
          fallbackShift: defaultShift,
          shiftAssignments: empAssignments,
        );
        final eval = AttendanceEvaluationEngine.evaluateDay(
          rawDayLogs:
              logsByCardDate['${emp.cardNo}|$dKey'] ?? const <AttendanceLog>[],
          previousDayLogs: logsByCardDate[
                  '${emp.cardNo}|${AttendanceEvaluationEngine.previousDateKey(dKey)}'] ??
              const <AttendanceLog>[],
          nextDayLogs: logsByCardDate[
                  '${emp.cardNo}|${AttendanceEvaluationEngine.nextDateKey(dKey)}'] ??
              const <AttendanceLog>[],
          shift: dayShift,
          leave: leavesByEmpDate['${emp.id}|$dKey'],
          publicHoliday: holidays[dKey],
          employee: emp,
          dateKey: dKey,
        );
        weeklyWorkedMinutes += eval.workedMinutes;

        if (offset < 5 && !streakClosed) {
          if (eval.state == DailyAttendanceState.absent) {
            streak++;
          } else if (eval.state.isScheduledOffDay) {
            // Devamsızlık zinciri tatilde bölünmez
          } else {
            streakClosed = true;
          }
        }
      }

      if (streak >= 2) {
        alerts.add(
          PdksProactiveAlert(
            id: 'consec_abs_${emp.id}_$anchorDateKey',
            category: PdksAlertCategory.consecutiveAbsence,
            severity: PdksAlertSeverity.critical,
            employeeId: emp.id,
            employeeCardNo: emp.cardNo,
            employeeName: emp.fullName,
            title: '${emp.fullName}: $streak Gün Ardışık Devamsızlık',
            detail:
                '4857 Md. 25/II-g kapsamında tutanak / savunma isteme değerlendirmesi önerilir.',
            dateKey: anchorDateKey,
          ),
        );
      }

      if (weeklyWorkedMinutes > 2700) {
        final totalHours = (weeklyWorkedMinutes / 60.0).toStringAsFixed(1);
        final excessHours =
            ((weeklyWorkedMinutes - 2700) / 60.0).toStringAsFixed(1);
        alerts.add(
          PdksProactiveAlert(
            id: 'weekly_45h_${emp.id}_$anchorDateKey',
            category: PdksAlertCategory.weeklyOvertimeLimit,
            severity: PdksAlertSeverity.warning,
            employeeId: emp.id,
            employeeCardNo: emp.cardNo,
            employeeName: emp.fullName,
            title: '${emp.fullName}: Haftalık 45 Saat Aşımı ($totalHours sa)',
            detail:
                'Son 7 günlük net çalışma 45 saati aşıyor (+$excessHours sa fazla çalışma / 4857 Md. 41).',
            dateKey: anchorDateKey,
          ),
        );
      }

      // 2. Deneme süresi bitiş uyarısı (<= 14 gün kaldı)
      final probDate = Employee.parseDateKey(emp.probationEndDate);
      if (probDate != null) {
        final daysLeft = probDate.difference(anchorDate).inDays;
        if (daysLeft >= 0 && daysLeft <= 14) {
          alerts.add(
            PdksProactiveAlert(
              id: 'probation_${emp.id}_${emp.probationEndDate}',
              category: PdksAlertCategory.probationEnding,
              severity: daysLeft <= 3
                  ? PdksAlertSeverity.critical
                  : PdksAlertSeverity.warning,
              employeeId: emp.id,
              employeeCardNo: emp.cardNo,
              employeeName: emp.fullName,
              title: '${emp.fullName}: Deneme Süresi ($daysLeft gün)',
              detail: 'Deneme süresi bitiş tarihi: ${emp.probationEndDate}',
              dateKey: emp.probationEndDate!,
            ),
          );
        }
      }
    }

    // 3. Süreli evrak bitiş/geçerlilik uyarıları (İSG, Sağlık Raporu vb.)
    final empById = {for (final e in employees) e.id: e};
    for (final doc in documents) {
      final emp = empById[doc.employeeId];
      if (emp == null || emp.isTerminatedOn(anchorDateKey)) continue;
      final daysLeft = doc.daysUntilExpiryAt(anchorDate);
      if (daysLeft == null) continue;
      if (daysLeft < 0) {
        alerts.add(
          PdksProactiveAlert(
            id: 'doc_exp_${doc.id}',
            category: PdksAlertCategory.documentExpiry,
            severity: PdksAlertSeverity.critical,
            employeeId: emp.id,
            employeeCardNo: emp.cardNo,
            employeeName: emp.fullName,
            title: '${emp.fullName}: Süresi Dolmuş Evrak',
            detail: '${doc.title} (${-daysLeft} gün önce doldu: ${doc.normalizedExpiryDate})',
            dateKey: doc.normalizedExpiryDate ?? anchorDateKey,
          ),
        );
      } else if (daysLeft <= 30) {
        alerts.add(
          PdksProactiveAlert(
            id: 'doc_soon_${doc.id}',
            category: PdksAlertCategory.documentExpiry,
            severity: PdksAlertSeverity.warning,
            employeeId: emp.id,
            employeeCardNo: emp.cardNo,
            employeeName: emp.fullName,
            title: '${emp.fullName}: Evrak Yenileme ($daysLeft gün)',
            detail: '${doc.title} bitiş tarihi: ${doc.normalizedExpiryDate}',
            dateKey: doc.normalizedExpiryDate ?? anchorDateKey,
          ),
        );
      }
    }

    // 4. Seçili günde eksik çıkış & gece vardiyası 7,5 saat sınırı uyarısı
    for (final st in todayStatuses) {
      if (st.hasMissingCheckOut) {
        alerts.add(
          PdksProactiveAlert(
            id: 'missing_out_${st.employee.id}_$anchorDateKey',
            category: PdksAlertCategory.missingCheckOut,
            severity: PdksAlertSeverity.info,
            employeeId: st.employee.id,
            employeeCardNo: st.employee.cardNo,
            employeeName: st.employee.fullName,
            title: '${st.employee.fullName}: Eksik Çıkış Kaydı',
            detail:
                'Giriş: ${st.firstCheckIn?.timeFormatted ?? "-"} • Vardiya bitişi: ${st.shift.endTime}',
            dateKey: anchorDateKey,
          ),
        );
      }
      if (st.shift.isNightShift && st.workedMinutes > 450) {
        final hrs = (st.workedMinutes / 60.0).toStringAsFixed(1);
        alerts.add(
          PdksProactiveAlert(
            id: 'night_limit_${st.employee.id}_$anchorDateKey',
            category: PdksAlertCategory.nightShiftLimitExceeded,
            severity: PdksAlertSeverity.warning,
            employeeId: st.employee.id,
            employeeCardNo: st.employee.cardNo,
            employeeName: st.employee.fullName,
            title: '${st.employee.fullName}: Gece 7,5 Saat Aşımı ($hrs sa)',
            detail:
                '4857 Md. 69 uyarınca gece çalışması 7,5 saati (450 dk) geçmemelidir (Gerçekleşen: ${st.workedMinutes} dk).',
            dateKey: anchorDateKey,
          ),
        );
      }
    }

    alerts.sort((a, b) => a.severity.index.compareTo(b.severity.index));
    return List<PdksProactiveAlert>.unmodifiable(alerts);
  }
}
