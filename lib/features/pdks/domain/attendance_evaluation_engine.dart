import 'dart:math' as math;

import 'pdks_models.dart';

/// Tekil gün için PDKS yoklama değerlendirme çıktısı.
class DayAttendanceEvaluation {
  final DailyAttendanceState state;
  final AttendanceLog? firstIn;
  final AttendanceLog? lastOut;
  final int lateMinutes;
  final int workedMinutes;
  final int breakDeductedMinutes;
  final int overtimeMinutes;
  final int earlyLeaveMinutes;
  final bool hasMissingCheckOut;
  final int duplicateScansFiltered;
  final bool isHolidayWork;
  final bool isWeeklyOffWork;

  const DayAttendanceEvaluation({
    required this.state,
    this.firstIn,
    this.lastOut,
    this.lateMinutes = 0,
    this.workedMinutes = 0,
    this.breakDeductedMinutes = 0,
    this.overtimeMinutes = 0,
    this.earlyLeaveMinutes = 0,
    this.hasMissingCheckOut = false,
    this.duplicateScansFiltered = 0,
    this.isHolidayWork = false,
    this.isWeeklyOffWork = false,
  });
}

/// Saf PDKS günlük devam, gece vardiyası çapraz gün eşleştirme, mola düşümü,
/// yarım gün izin/arefe, tatil mesaisi ve tarih bazlı vardiya çözümleme motoru (Katman 1).
class AttendanceEvaluationEngine {
  AttendanceEvaluationEngine._();

  static String formatDateKey(DateTime dt) =>
      '${dt.year.toString().padLeft(4, '0')}-${dt.month.toString().padLeft(2, '0')}-${dt.day.toString().padLeft(2, '0')}';

  static String nextDateKey(String dateKey) {
    final parsed = Employee.parseDateKey(dateKey);
    if (parsed == null) return dateKey;
    return formatDateKey(parsed.add(const Duration(days: 1)));
  }

  static String previousDateKey(String dateKey) {
    final parsed = Employee.parseDateKey(dateKey);
    if (parsed == null) return dateKey;
    return formatDateKey(parsed.subtract(const Duration(days: 1)));
  }

  /// Tarih bazlı vardiya atamalarından (`ShiftAssignment`) ilgili günün vardiyasını çözer;
  /// atama yoksa personelin sabit `emp.shiftId` vardiyasına geri döner.
  static ShiftPlan resolveShiftForDate({
    required Employee employee,
    required String dateKey,
    required Map<int, ShiftPlan> shiftMap,
    required ShiftPlan fallbackShift,
    List<ShiftAssignment> shiftAssignments = const <ShiftAssignment>[],
  }) {
    ShiftAssignment? best;
    for (final a in shiftAssignments) {
      if (a.employeeId != employee.id) continue;
      if (!a.appliesTo(dateKey)) continue;
      if (best == null || a.validFrom.compareTo(best.validFrom) >= 0) {
        best = a;
      }
    }
    final targetId = best?.shiftId ?? employee.shiftId;
    return shiftMap[targetId] ?? shiftMap[employee.shiftId] ?? fallbackShift;
  }

  static ({int hour, int minute}) _parseHhMm(
    String raw, {
    int defaultHour = 8,
    int defaultMinute = 0,
  }) {
    final parts = raw.split(':');
    final h = int.tryParse(parts.isNotEmpty ? parts[0].trim() : '') ??
        defaultHour;
    final m = int.tryParse(parts.length > 1 ? parts[1].trim() : '') ??
        defaultMinute;
    return (hour: h.clamp(0, 23), minute: m.clamp(0, 59));
  }

  /// Gece vardiyasında (`19:00-07:00` gibi) önceki gün akşam giriş yapmış personelin
  /// ertesi sabah vardiya bitiş penceresindeki çıkış kaydını döndürür.
  static AttendanceLog? _findNightShiftSpilloverCheckOut({
    required List<AttendanceLog> nextDayLogs,
    required AttendanceLog firstIn,
    required ShiftPlan shift,
  }) {
    if (!shift.isNightShift || nextDayLogs.isEmpty) return null;
    final endHm = _parseHhMm(shift.endTime, defaultHour: 7);
    final nextDayStart = DateTime(
      firstIn.timestamp.year,
      firstIn.timestamp.month,
      firstIn.timestamp.day,
    ).add(const Duration(days: 1));
    final expectedEnd = DateTime(
      nextDayStart.year,
      nextDayStart.month,
      nextDayStart.day,
      endHm.hour,
      endHm.minute,
    );
    final windowCutoff = expectedEnd.add(const Duration(hours: 4));

    final sortedNext = List<AttendanceLog>.from(nextDayLogs)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    for (final log in sortedNext) {
      if (log.timestamp.isAfter(windowCutoff)) break;
      if (!log.isCheckIn ||
          log.timestamp.difference(firstIn.timestamp).inHours >= 4) {
        return log;
      }
    }
    return null;
  }

  /// Önceki gün gece vardiyasında tüketilen ertesi sabah çıkış kaydını bugünün
  /// ham kayıtlarından süzer; böylece sabah çıkışı bugünün yeni girişi sanılmaz.
  static List<AttendanceLog> filterConsumedNightShiftSpilloverLogs({
    required List<AttendanceLog> currentDayLogs,
    required List<AttendanceLog> previousDayLogs,
    required ShiftPlan shift,
    required String dateKey,
  }) {
    if (!shift.isNightShift ||
        currentDayLogs.isEmpty ||
        previousDayLogs.isEmpty) {
      return currentDayLogs;
    }

    final startHm = _parseHhMm(shift.startTime, defaultHour: 19);
    final prevSorted = List<AttendanceLog>.from(previousDayLogs)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    final prevAnchor = Employee.parseDateKey(previousDateKey(dateKey));
    if (prevAnchor == null) return currentDayLogs;

    final eveningThreshold = DateTime(
      prevAnchor.year,
      prevAnchor.month,
      prevAnchor.day,
      startHm.hour,
      startHm.minute,
    ).subtract(const Duration(hours: 2));

    final prevEveningIn = prevSorted
        .where((l) => !l.timestamp.isBefore(eveningThreshold))
        .toList(growable: false);
    if (prevEveningIn.isEmpty) return currentDayLogs;
    final firstPrevIn = prevEveningIn.first;
    final hasSameDayOutAfter = prevSorted.any(
      (l) => !l.isCheckIn && l.timestamp.isAfter(firstPrevIn.timestamp),
    );
    if (hasSameDayOutAfter) return currentDayLogs;

    final consumedOut = _findNightShiftSpilloverCheckOut(
      nextDayLogs: currentDayLogs,
      firstIn: firstPrevIn,
      shift: shift,
    );
    if (consumedOut == null) return currentDayLogs;

    return currentDayLogs
        .where((l) => l.id != consumedOut.id)
        .toList(growable: false);
  }

  static bool isScheduledWeeklyOffDay({
    required Employee? employee,
    required ShiftPlan shift,
    required String? dateKey,
  }) {
    if (dateKey == null) return false;
    final dt = Employee.parseDateKey(dateKey);
    if (dt == null) return false;
    final personalOff = employee?.weeklyOffDay;
    if (personalOff != null && personalOff >= 1 && personalOff <= 7) {
      return dt.weekday == personalOff;
    }
    return shift.weeklyOffDays.contains(dt.weekday);
  }

  static DayAttendanceEvaluation evaluateDay({
    required List<AttendanceLog> rawDayLogs,
    List<AttendanceLog> nextDayLogs = const <AttendanceLog>[],
    List<AttendanceLog> previousDayLogs = const <AttendanceLog>[],
    required ShiftPlan shift,
    required LeaveRecord? leave,
    PublicHoliday? publicHoliday,
    Employee? employee,
    String? dateKey,
  }) {
    final effectiveDayLogs = dateKey != null
        ? filterConsumedNightShiftSpilloverLogs(
            currentDayLogs: rawDayLogs,
            previousDayLogs: previousDayLogs,
            shift: shift,
            dateKey: dateKey,
          )
        : rawDayLogs;

    if (effectiveDayLogs.isEmpty) {
      final DailyAttendanceState st;
      if (leave != null && leave.leaveType != LeaveType.devamsiz) {
        st = leave.leaveType == LeaveType.saglikRaporu
            ? DailyAttendanceState.sickReport
            : DailyAttendanceState.onLeave;
      } else if (employee != null &&
          dateKey != null &&
          employee.isTerminatedOn(dateKey)) {
        st = DailyAttendanceState.terminated;
      } else if (employee != null &&
          dateKey != null &&
          employee.isBeforeHireDate(dateKey)) {
        st = DailyAttendanceState.notYetHired;
      } else if (publicHoliday != null) {
        st = DailyAttendanceState.publicHoliday;
      } else if (isScheduledWeeklyOffDay(
        employee: employee,
        shift: shift,
        dateKey: dateKey,
      )) {
        st = DailyAttendanceState.weeklyOff;
      } else {
        st = DailyAttendanceState.absent;
      }
      return DayAttendanceEvaluation(state: st);
    }

    final sorted = List<AttendanceLog>.from(effectiveDayLogs)
      ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

    // 15 dakika içerisindeki aynı yönlü mükerrer okumaları filtrele (Anti-Passback Debounce)
    final debounced = <AttendanceLog>[];
    int duplicatesFiltered = 0;
    for (final log in sorted) {
      if (debounced.isEmpty) {
        debounced.add(log);
        continue;
      }
      final prev = debounced.last;
      final diffMins = log.timestamp.difference(prev.timestamp).inMinutes.abs();
      if (diffMins < 15 && log.isCheckIn == prev.isCheckIn) {
        duplicatesFiltered++;
        continue;
      }
      debounced.add(log);
    }

    final explicitIns =
        debounced.where((l) => l.isCheckIn).toList(growable: false);
    final explicitOuts =
        debounced.where((l) => !l.isCheckIn).toList(growable: false);

    final AttendanceLog firstIn =
        explicitIns.isNotEmpty ? explicitIns.first : debounced.first;

    AttendanceLog? lastOut;
    if (explicitOuts.isNotEmpty) {
      final candidate = explicitOuts.last;
      if (candidate.id != firstIn.id &&
          candidate.timestamp.isAfter(firstIn.timestamp)) {
        lastOut = candidate;
      }
    } else if (debounced.length > 1) {
      final candidate = debounced.last;
      if (candidate.id != firstIn.id &&
          candidate.timestamp.difference(firstIn.timestamp).inMinutes >= 30) {
        lastOut = candidate;
      }
    }

    // Gece vardiyası ertesi gün çıkış eşleştirmesi
    if (lastOut == null && shift.isNightShift) {
      lastOut = _findNightShiftSpilloverCheckOut(
        nextDayLogs: nextDayLogs,
        firstIn: firstIn,
        shift: shift,
      );
    }

    final startHm = _parseHhMm(shift.startTime, defaultHour: 8);
    final endHm = _parseHhMm(shift.endTime, defaultHour: 18);
    final DateTime anchorDay = DateTime(
      firstIn.timestamp.year,
      firstIn.timestamp.month,
      firstIn.timestamp.day,
    );
    DateTime effectiveShiftStart = DateTime(
      anchorDay.year,
      anchorDay.month,
      anchorDay.day,
      startHm.hour,
      startHm.minute,
    );
    DateTime effectiveShiftEnd = DateTime(
      anchorDay.year,
      anchorDay.month,
      anchorDay.day,
      endHm.hour,
      endHm.minute,
    );
    if (shift.isNightShift || endHm.hour < startHm.hour) {
      effectiveShiftEnd = effectiveShiftEnd.add(const Duration(days: 1));
    }

    final bool isFullHoliday =
        publicHoliday != null && !publicHoliday.isHalfDay;
    final bool isHalfDayHoliday =
        publicHoliday != null && publicHoliday.isHalfDay;
    final bool isWeeklyOff = isScheduledWeeklyOffDay(
      employee: employee,
      shift: shift,
      dateKey: dateKey,
    );
    final bool isHolidayWork = isFullHoliday;
    final bool isWeeklyOffWork = !isFullHoliday && isWeeklyOff;

    // Arefe yarım gün resmi tatili: gündüz vardiyasında beklenen çıkış en geç 13:00 (veya yarı süre)
    if (isHalfDayHoliday && !shift.isNightShift) {
      final halfDurationEnd = effectiveShiftStart.add(
        Duration(minutes: shift.plannedDurationMinutes ~/ 2),
      );
      final thirteenZero = DateTime(
        anchorDay.year,
        anchorDay.month,
        anchorDay.day,
        13,
        0,
      );
      final candidateEnd =
          thirteenZero.isBefore(halfDurationEnd) ? halfDurationEnd : thirteenZero;
      if (candidateEnd.isAfter(effectiveShiftStart) &&
          candidateEnd.isBefore(effectiveShiftEnd)) {
        effectiveShiftEnd = candidateEnd;
      }
    }

    // Yarım gün veya saatlik izin vardiya penceresini daraltır
    int excusedLeaveMinutes = 0;
    if (leave != null && leave.leaveType != LeaveType.devamsiz) {
      final hasExplicitRange =
          (leave.startTime ?? '').trim().isNotEmpty &&
              (leave.endTime ?? '').trim().isNotEmpty;
      if (hasExplicitRange) {
        final lStartHm = _parseHhMm(leave.startTime!, defaultHour: startHm.hour);
        final lEndHm = _parseHhMm(leave.endTime!, defaultHour: endHm.hour);
        final leaveStart = DateTime(
          anchorDay.year,
          anchorDay.month,
          anchorDay.day,
          lStartHm.hour,
          lStartHm.minute,
        );
        var leaveEnd = DateTime(
          anchorDay.year,
          anchorDay.month,
          anchorDay.day,
          lEndHm.hour,
          lEndHm.minute,
        );
        if (!leaveEnd.isAfter(leaveStart)) {
          leaveEnd = leaveEnd.add(const Duration(days: 1));
        }
        excusedLeaveMinutes =
            leaveEnd.difference(leaveStart).inMinutes.clamp(0, 720);
        if (!leaveStart.isAfter(
              effectiveShiftStart.add(Duration(minutes: shift.toleranceMinutes)),
            ) &&
            leaveEnd.isAfter(effectiveShiftStart) &&
            leaveEnd.isBefore(effectiveShiftEnd)) {
          effectiveShiftStart = leaveEnd;
        } else if (!leaveEnd.isBefore(
              effectiveShiftEnd.subtract(Duration(minutes: shift.toleranceMinutes)),
            ) &&
            leaveStart.isAfter(effectiveShiftStart) &&
            leaveStart.isBefore(effectiveShiftEnd)) {
          effectiveShiftEnd = leaveStart;
        }
      } else if (leave.isHalfDay) {
        final midPoint = effectiveShiftStart.add(
          Duration(minutes: shift.plannedDurationMinutes ~/ 2),
        );
        excusedLeaveMinutes = (shift.plannedDurationMinutes ~/ 2).clamp(0, 720);
        if (!firstIn.timestamp.isBefore(
          midPoint.subtract(const Duration(minutes: 45)),
        )) {
          // Sabah yarım gün izinli -> öğleden sonra mesai başlangıcı
          effectiveShiftStart = midPoint;
        } else if (lastOut != null &&
            !lastOut.timestamp.isAfter(
              midPoint.add(const Duration(minutes: 60)),
            )) {
          // Öğleden sonra yarım gün izinli -> öğlen çıkışı
          effectiveShiftEnd = midPoint;
        }
      } else if (leave.durationHours != null && leave.durationHours! > 0) {
        excusedLeaveMinutes = (leave.durationHours! * 60).round().clamp(0, 720);
      }
    }

    final int lateMins;
    if (isHolidayWork || isWeeklyOffWork) {
      lateMins = 0;
    } else {
      final rawDiff = firstIn.timestamp.difference(effectiveShiftStart).inMinutes;
      lateMins = rawDiff <= shift.toleranceMinutes ? 0 : rawDiff;
    }

    final DailyAttendanceState dailyState =
        lateMins > 0 ? DailyAttendanceState.late : DailyAttendanceState.present;

    int workedMins = 0;
    int breakDeductedMins = 0;
    int overtimeMins = 0;
    int earlyLeaveMins = 0;
    final bool missingOut = lastOut == null;

    if (lastOut != null) {
      final pairedWorkMins = _sumPairedSessionsMinutes(debounced);
      final spanMins =
          lastOut.timestamp.difference(firstIn.timestamp).inMinutes.clamp(0, 1440);

      if (pairedWorkMins != null) {
        workedMins = pairedWorkMins.clamp(0, 1440);
      } else {
        workedMins = spanMins;
        if (shift.breakMinutes > 0 && spanMins > (shift.breakMinutes + 60)) {
          breakDeductedMins = shift.breakMinutes;
          workedMins = (spanMins - breakDeductedMins).clamp(0, 1440);
        }
      }

      final threshold =
          shift.overtimeThresholdMinutes < 0 ? 0 : shift.overtimeThresholdMinutes;

      if (isHolidayWork || isWeeklyOffWork) {
        if (workedMins >= threshold) {
          overtimeMins = _applyRounding(workedMins, shift.roundingMinutes);
        }
      } else {
        final outDiff = lastOut.timestamp.difference(effectiveShiftEnd).inMinutes;
        if (outDiff >= threshold) {
          final int candidateOt;
          if (lateMins > 0) {
            final expectedGross =
                effectiveShiftEnd.difference(effectiveShiftStart).inMinutes;
            final expectedBreak =
                (expectedGross > (shift.breakMinutes + 60) &&
                        !isHalfDayHoliday &&
                        excusedLeaveMinutes == 0)
                    ? shift.breakMinutes
                    : 0;
            final expectedNet = (expectedGross - expectedBreak - excusedLeaveMinutes)
                .clamp(0, 1440);
            candidateOt = math.min(outDiff, workedMins - expectedNet);
          } else {
            candidateOt = outDiff;
          }
          if (candidateOt >= threshold) {
            overtimeMins = _applyRounding(candidateOt, shift.roundingMinutes);
          }
        } else if (outDiff < -shift.toleranceMinutes) {
          earlyLeaveMins = -outDiff;
        }
      }
    }

    return DayAttendanceEvaluation(
      state: dailyState,
      firstIn: firstIn,
      lastOut: lastOut,
      lateMinutes: lateMins,
      workedMinutes: workedMins,
      breakDeductedMinutes: breakDeductedMins,
      overtimeMinutes: overtimeMins,
      earlyLeaveMinutes: earlyLeaveMins,
      hasMissingCheckOut: missingOut,
      duplicateScansFiltered: duplicatesFiltered,
      isHolidayWork: isHolidayWork,
      isWeeklyOffWork: isWeeklyOffWork,
    );
  }

  /// Gün içinde en az 2 açık (Giriş -> Çıkış) çifti varsa toplam net çalışma dakikasını döndürür.
  static int? _sumPairedSessionsMinutes(List<AttendanceLog> debounced) {
    int total = 0;
    int pairCount = 0;
    AttendanceLog? activeIn;
    for (final log in debounced) {
      if (log.isCheckIn) {
        activeIn ??= log;
      } else if (activeIn != null && log.timestamp.isAfter(activeIn.timestamp)) {
        total += log.timestamp.difference(activeIn.timestamp).inMinutes;
        pairCount++;
        activeIn = null;
      }
    }
    return pairCount >= 2 ? total : null;
  }

  static int _applyRounding(int minutes, int roundingMinutes) {
    if (roundingMinutes <= 1) return minutes;
    return (minutes ~/ roundingMinutes) * roundingMinutes;
  }

  static int calculateLateMinutes(
    DateTime checkIn,
    String shiftStartHhMm,
    int toleranceMinutes,
  ) {
    final startHm = _parseHhMm(shiftStartHhMm, defaultHour: 6);
    final shiftStart = DateTime(
      checkIn.year,
      checkIn.month,
      checkIn.day,
      startHm.hour,
      startHm.minute,
    );
    final diff = checkIn.difference(shiftStart).inMinutes;
    if (diff <= toleranceMinutes) return 0;
    return diff;
  }
}
