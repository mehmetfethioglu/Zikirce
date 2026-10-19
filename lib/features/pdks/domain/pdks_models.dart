import 'package:flutter/foundation.dart';

enum HasibuModule {
  pdksHr('PDKS & İK', 'Personel Devam, Vardiya & İzin'),
  leanProduction('Yalın Üretim & KPI', '27 İstasyon Akışı & Performans'),
  preAccounting('Ön Muhasebe & Puantaj', 'Puantaj, Şube Kasa & Gider'),
  employeePortal('Personel Portalı', 'Özlük, SGK, İzin & KPI Görünümü'),
  systemSettings('Sistem & Ayarlar', 'Şirket, Şube, Cihaz & Yetkiler');

  final String title;
  final String subtitle;
  const HasibuModule(this.title, this.subtitle);

  static List<HasibuModule> parseCsv(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return const <HasibuModule>[HasibuModule.employeePortal];
    }
    final parts = raw
        .split(',')
        .map((e) => e.trim())
        .where((e) => e.isNotEmpty)
        .toSet();
    final matched = HasibuModule.values
        .where((m) => parts.contains(m.name))
        .toList(growable: false);
    return matched.isEmpty
        ? const <HasibuModule>[HasibuModule.employeePortal]
        : matched;
  }

  static String toCsv(List<HasibuModule> modules) {
    if (modules.isEmpty) return HasibuModule.employeePortal.name;
    return modules.map((m) => m.name).join(',');
  }
}

enum UserRole {
  admin('Yönetici / İK'),
  employee('Personel');

  final String label;
  const UserRole(this.label);
}

@immutable
class AuthSession {
  final bool isAuthenticated;
  final String username;
  final String displayName;
  final UserRole role;
  final String? employeeCardNo;
  final List<HasibuModule> allowedModules;
  final String? errorMessage;

  const AuthSession({
    this.isAuthenticated = false,
    this.username = '',
    this.displayName = '',
    this.role = UserRole.admin,
    this.employeeCardNo,
    this.allowedModules = HasibuModule.values,
    this.errorMessage,
  });

  bool canAccess(HasibuModule module) => allowedModules.contains(module);

  AuthSession copyWith({
    bool? isAuthenticated,
    String? username,
    String? displayName,
    UserRole? role,
    String? employeeCardNo,
    List<HasibuModule>? allowedModules,
    String? Function()? errorMessage,
  }) {
    return AuthSession(
      isAuthenticated: isAuthenticated ?? this.isAuthenticated,
      username: username ?? this.username,
      displayName: displayName ?? this.displayName,
      role: role ?? this.role,
      employeeCardNo: employeeCardNo ?? this.employeeCardNo,
      allowedModules: allowedModules ?? this.allowedModules,
      errorMessage: errorMessage != null ? errorMessage() : this.errorMessage,
    );
  }
}

enum AttendanceSource {
  tenfeiD35('Tenfei D35 Terminal'),
  mobileQr('Mobil QR Kod'),
  mobileGps('Mobil GPS Konum'),
  manual('Manuel İK Kaydı');

  final String label;
  const AttendanceSource(this.label);
}

enum VerifyMethod {
  face('Yüz Tanıma'),
  fingerprint('Parmak İzi'),
  card('Kart'),
  password('Şifre'),
  mobileQr('Şube QR'),
  mobileGps('GPS Geofence');

  final String label;
  const VerifyMethod(this.label);
}

enum LeaveType {
  yillikIzin(5, 'Yıllık İzin', true),
  saglikRaporu(6, 'Sağlık Raporu', true),
  ucretliIzin(2, 'Ücretli İzin', true),
  ucretsizIzin(3, 'Ücretsiz İzin', false),
  mazeretIzni(9, 'Mazeret İzni', true),
  disGorev(7, 'Dış Görev İzni', true),
  devamsiz(4, 'Devamsız', false);

  final int code;
  final String label;
  final bool isPaid;
  const LeaveType(this.code, this.label, this.isPaid);

  static LeaveType fromCode(int code) {
    return LeaveType.values.firstWhere(
      (e) => e.code == code,
      orElse: () => LeaveType.ucretsizIzin,
    );
  }
}

enum DailyAttendanceState {
  present('Giriş Yaptı'),
  late('Geç Geldi'),
  onLeave('İzinli'),
  sickReport('Raporlu'),
  absent('Devamsız');

  final String label;
  const DailyAttendanceState(this.label);
}

@immutable
class CompanySettings {
  final String companyName;
  final bool autoPollEnabled;
  final int autoPollMinutes;
  final String adminUsername;
  final String adminPassword;
  final String defaultEmployeePin;
  final String syncGmailAccount;
  final String syncFolderPath;

  const CompanySettings({
    this.companyName = 'HASİBU İŞLETME YÖNETİMİ',
    this.autoPollEnabled = true,
    this.autoPollMinutes = 5,
    this.adminUsername = 'admin',
    this.adminPassword = '123',
    this.defaultEmployeePin = '1234',
    this.syncGmailAccount = '',
    this.syncFolderPath = '',
  });

  CompanySettings copyWith({
    String? companyName,
    bool? autoPollEnabled,
    int? autoPollMinutes,
    String? adminUsername,
    String? adminPassword,
    String? defaultEmployeePin,
    String? syncGmailAccount,
    String? syncFolderPath,
  }) {
    return CompanySettings(
      companyName: companyName ?? this.companyName,
      autoPollEnabled: autoPollEnabled ?? this.autoPollEnabled,
      autoPollMinutes: autoPollMinutes ?? this.autoPollMinutes,
      adminUsername: adminUsername ?? this.adminUsername,
      adminPassword: adminPassword ?? this.adminPassword,
      defaultEmployeePin: defaultEmployeePin ?? this.defaultEmployeePin,
      syncGmailAccount: syncGmailAccount ?? this.syncGmailAccount,
      syncFolderPath: syncFolderPath ?? this.syncFolderPath,
    );
  }

  Map<String, dynamic> toJson() => {
        'companyName': companyName,
        'autoPollEnabled': autoPollEnabled,
        'autoPollMinutes': autoPollMinutes,
        'adminUsername': adminUsername,
        'adminPassword': adminPassword,
        'defaultEmployeePin': defaultEmployeePin,
        'syncGmailAccount': syncGmailAccount,
        'syncFolderPath': syncFolderPath,
      };

  factory CompanySettings.fromJson(Map<String, dynamic> json) =>
      CompanySettings(
        companyName:
            json['companyName'] as String? ?? 'HASİBU İŞLETME YÖNETİMİ',
        autoPollEnabled: json['autoPollEnabled'] as bool? ?? true,
        autoPollMinutes: json['autoPollMinutes'] as int? ?? 5,
        adminUsername: json['adminUsername'] as String? ?? 'admin',
        adminPassword: json['adminPassword'] as String? ?? '123',
        defaultEmployeePin: json['defaultEmployeePin'] as String? ?? '1234',
        syncGmailAccount: json['syncGmailAccount'] as String? ?? '',
        syncFolderPath: json['syncFolderPath'] as String? ?? '',
      );
}

@immutable
class Branch {
  final int id;
  final String code;
  final String name;
  final bool hasTerminal;
  final String? terminalIp;
  final int terminalPort;
  final int machineNo;
  final double latitude;
  final double longitude;
  final double geofenceRadiusMeters;

  const Branch({
    required this.id,
    required this.code,
    required this.name,
    required this.hasTerminal,
    this.terminalIp,
    this.terminalPort = 4370,
    this.machineNo = 1,
    required this.latitude,
    required this.longitude,
    this.geofenceRadiusMeters = 150.0,
  });

  Branch copyWith({
    int? id,
    String? code,
    String? name,
    String? terminalIp,
    int? terminalPort,
    int? machineNo,
    bool? hasTerminal,
    double? latitude,
    double? longitude,
    double? geofenceRadiusMeters,
  }) {
    return Branch(
      id: id ?? this.id,
      code: code ?? this.code,
      name: name ?? this.name,
      hasTerminal: hasTerminal ?? this.hasTerminal,
      terminalIp: terminalIp ?? this.terminalIp,
      terminalPort: terminalPort ?? this.terminalPort,
      machineNo: machineNo ?? this.machineNo,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      geofenceRadiusMeters: geofenceRadiusMeters ?? this.geofenceRadiusMeters,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'code': code,
        'name': name,
        'hasTerminal': hasTerminal,
        'terminalIp': terminalIp,
        'terminalPort': terminalPort,
        'machineNo': machineNo,
        'latitude': latitude,
        'longitude': longitude,
        'geofenceRadiusMeters': geofenceRadiusMeters,
      };

  factory Branch.fromJson(Map<String, dynamic> json) => Branch(
        id: json['id'] as int,
        code: json['code'] as String,
        name: json['name'] as String,
        hasTerminal: json['hasTerminal'] as bool? ?? false,
        terminalIp: json['terminalIp'] as String?,
        terminalPort: json['terminalPort'] as int? ?? 4370,
        machineNo: json['machineNo'] as int? ?? 1,
        latitude: (json['latitude'] as num?)?.toDouble() ?? 37.1674,
        longitude: (json['longitude'] as num?)?.toDouble() ?? 38.7955,
        geofenceRadiusMeters:
            (json['geofenceRadiusMeters'] as num?)?.toDouble() ?? 150.0,
      );
}

@immutable
class Department {
  final int id;
  final String name;
  final int branchId;
  final bool isProductionLine;

  const Department({
    required this.id,
    required this.name,
    required this.branchId,
    this.isProductionLine = true,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'branchId': branchId,
        'isProductionLine': isProductionLine,
      };

  factory Department.fromJson(Map<String, dynamic> json) => Department(
        id: json['id'] as int,
        name: json['name'] as String,
        branchId: json['branchId'] as int,
        isProductionLine: json['isProductionLine'] as bool? ?? true,
      );
}

@immutable
class ShiftPlan {
  final int id;
  final String name;
  final String startTime; // HH:mm
  final String endTime; // HH:mm
  final int toleranceMinutes;

  const ShiftPlan({
    required this.id,
    required this.name,
    required this.startTime,
    required this.endTime,
    this.toleranceMinutes = 15,
  });

  ShiftPlan copyWith({
    int? id,
    String? name,
    String? startTime,
    String? endTime,
    int? toleranceMinutes,
  }) {
    return ShiftPlan(
      id: id ?? this.id,
      name: name ?? this.name,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      toleranceMinutes: toleranceMinutes ?? this.toleranceMinutes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'startTime': startTime,
        'endTime': endTime,
        'toleranceMinutes': toleranceMinutes,
      };

  factory ShiftPlan.fromJson(Map<String, dynamic> json) => ShiftPlan(
        id: json['id'] as int,
        name: json['name'] as String,
        startTime: json['startTime'] as String? ?? '08:00',
        endTime: json['endTime'] as String? ?? '18:00',
        toleranceMinutes: json['toleranceMinutes'] as int? ?? 15,
      );
}

@immutable
class Employee {
  final int id;
  final String cardNo;
  final String fullName;
  final String title;
  final int departmentId;
  final int branchId;
  final int shiftId;
  final String hireDate; // YYYY-MM-DD
  final bool sgkActive;
  final int annualLeaveEntitlement;
  final int usedAnnualLeave;
  final double kpiScore;
  final String password;
  final List<HasibuModule> allowedModules;
  final String? photoPath;

  const Employee({
    required this.id,
    required this.cardNo,
    required this.fullName,
    required this.title,
    required this.departmentId,
    required this.branchId,
    this.shiftId = 1,
    required this.hireDate,
    this.sgkActive = true,
    this.annualLeaveEntitlement = 14,
    this.usedAnnualLeave = 0,
    this.kpiScore = 92.0,
    this.password = '1234',
    this.allowedModules = const <HasibuModule>[HasibuModule.employeePortal],
    this.photoPath,
  });

  int get remainingAnnualLeave =>
      (annualLeaveEntitlement - usedAnnualLeave).clamp(0, 365);

  Employee copyWith({
    int? id,
    String? cardNo,
    String? fullName,
    String? title,
    int? departmentId,
    int? branchId,
    int? shiftId,
    String? hireDate,
    bool? sgkActive,
    int? annualLeaveEntitlement,
    int? usedAnnualLeave,
    double? kpiScore,
    String? password,
    List<HasibuModule>? allowedModules,
    String? Function()? photoPath,
  }) {
    return Employee(
      id: id ?? this.id,
      cardNo: cardNo ?? this.cardNo,
      fullName: fullName ?? this.fullName,
      title: title ?? this.title,
      departmentId: departmentId ?? this.departmentId,
      branchId: branchId ?? this.branchId,
      shiftId: shiftId ?? this.shiftId,
      hireDate: hireDate ?? this.hireDate,
      sgkActive: sgkActive ?? this.sgkActive,
      annualLeaveEntitlement:
          annualLeaveEntitlement ?? this.annualLeaveEntitlement,
      usedAnnualLeave: usedAnnualLeave ?? this.usedAnnualLeave,
      kpiScore: kpiScore ?? this.kpiScore,
      password: password ?? this.password,
      allowedModules: allowedModules ?? this.allowedModules,
      photoPath: photoPath != null ? photoPath() : this.photoPath,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'cardNo': cardNo,
        'fullName': fullName,
        'title': title,
        'departmentId': departmentId,
        'branchId': branchId,
        'shiftId': shiftId,
        'hireDate': hireDate,
        'sgkActive': sgkActive,
        'annualLeaveEntitlement': annualLeaveEntitlement,
        'usedAnnualLeave': usedAnnualLeave,
        'kpiScore': kpiScore,
        'password': password,
        'allowedModules': HasibuModule.toCsv(allowedModules),
        'photoPath': photoPath,
      };

  factory Employee.fromJson(Map<String, dynamic> json) => Employee(
        id: json['id'] as int,
        cardNo: json['cardNo'] as String,
        fullName: json['fullName'] as String,
        title: json['title'] as String? ?? 'Personel',
        departmentId: json['departmentId'] as int,
        branchId: json['branchId'] as int,
        shiftId: json['shiftId'] as int? ?? 1,
        hireDate: json['hireDate'] as String? ?? '2024-01-01',
        sgkActive: json['sgkActive'] as bool? ?? true,
        annualLeaveEntitlement: json['annualLeaveEntitlement'] as int? ?? 14,
        usedAnnualLeave: json['usedAnnualLeave'] as int? ?? 0,
        kpiScore: (json['kpiScore'] as num?)?.toDouble() ?? 90.0,
        password: json['password'] as String? ?? '1234',
        allowedModules:
            HasibuModule.parseCsv(json['allowedModules'] as String?),
        photoPath: json['photoPath'] as String?,
      );
}

@immutable
class AttendanceLog {
  final String id;
  final String cardNo;
  final int branchId;
  final int deviceNo;
  final DateTime timestamp;
  final bool isCheckIn;
  final AttendanceSource source;
  final VerifyMethod verifyMethod;

  const AttendanceLog({
    required this.id,
    required this.cardNo,
    required this.branchId,
    required this.deviceNo,
    required this.timestamp,
    required this.isCheckIn,
    required this.source,
    required this.verifyMethod,
  });

  String get dateKey =>
      '${timestamp.year.toString().padLeft(4, '0')}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';

  String get timeFormatted =>
      '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';

  AttendanceLog copyWith({
    String? id,
    String? cardNo,
    int? branchId,
    int? deviceNo,
    DateTime? timestamp,
    bool? isCheckIn,
    AttendanceSource? source,
    VerifyMethod? verifyMethod,
  }) {
    return AttendanceLog(
      id: id ?? this.id,
      cardNo: cardNo ?? this.cardNo,
      branchId: branchId ?? this.branchId,
      deviceNo: deviceNo ?? this.deviceNo,
      timestamp: timestamp ?? this.timestamp,
      isCheckIn: isCheckIn ?? this.isCheckIn,
      source: source ?? this.source,
      verifyMethod: verifyMethod ?? this.verifyMethod,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'cardNo': cardNo,
        'branchId': branchId,
        'deviceNo': deviceNo,
        'timestamp': timestamp.toIso8601String(),
        'isCheckIn': isCheckIn,
        'source': source.name,
        'verifyMethod': verifyMethod.name,
      };

  factory AttendanceLog.fromJson(Map<String, dynamic> json) => AttendanceLog(
        id: json['id'] as String,
        cardNo: json['cardNo'] as String,
        branchId: json['branchId'] as int? ?? 1,
        deviceNo: json['deviceNo'] as int? ?? 1,
        timestamp: DateTime.parse(json['timestamp'] as String),
        isCheckIn: json['isCheckIn'] as bool? ?? true,
        source: AttendanceSource.values.firstWhere(
          (e) => e.name == json['source'],
          orElse: () => AttendanceSource.tenfeiD35,
        ),
        verifyMethod: VerifyMethod.values.firstWhere(
          (e) => e.name == json['verifyMethod'],
          orElse: () => VerifyMethod.face,
        ),
      );
}

@immutable
class LeaveRecord {
  final String id;
  final int employeeId;
  final String date; // YYYY-MM-DD
  final LeaveType leaveType;
  final String note;

  const LeaveRecord({
    required this.id,
    required this.employeeId,
    required this.date,
    required this.leaveType,
    required this.note,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'date': date,
        'leaveType': leaveType.code,
        'note': note,
      };

  factory LeaveRecord.fromJson(Map<String, dynamic> json) => LeaveRecord(
        id: json['id'] as String,
        employeeId: json['employeeId'] as int,
        date: json['date'] as String,
        leaveType: LeaveType.fromCode(json['leaveType'] as int? ?? 5),
        note: json['note'] as String? ?? '',
      );
}

@immutable
class EmployeeDailyStatus {
  final Employee employee;
  final Department department;
  final Branch branch;
  final ShiftPlan shift;
  final DailyAttendanceState state;
  final AttendanceLog? firstCheckIn;
  final AttendanceLog? lastCheckOut;
  final List<AttendanceLog> allLogsOfDay;
  final LeaveRecord? leaveRecord;
  final int lateMinutes;

  const EmployeeDailyStatus({
    required this.employee,
    required this.department,
    required this.branch,
    required this.shift,
    required this.state,
    this.firstCheckIn,
    this.lastCheckOut,
    this.allLogsOfDay = const <AttendanceLog>[],
    this.leaveRecord,
    this.lateMinutes = 0,
  });
}
