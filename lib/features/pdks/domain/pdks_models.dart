import 'package:flutter/foundation.dart';
import 'package:hasibu/core/security/hasibu_security_service.dart';

enum HasibuModule {
  pdksHr('Personel & PDKS', 'Yüz Okutma, Devam/Devamsızlık & İzinler'),
  leanProduction('Yalın Üretim & KPI', '27 İstasyon Akışı & Performans'),
  preAccounting('Ön Muhasebe & Puantaj', 'Hasibu ERP, Cari, Fatura & Üretim'),
  branchStore('Şube & Mağaza', 'Hasibu Mağaza POS, Terazi, Gün Sonu & 360° Denetim'),
  employeePortal('Personel Portalı', 'Özlük, İzin & QR/GPS Yoklama'),
  systemSettings('Ayarlar', 'Şirket, Şube, Cihaz, Vardiya & Personel');

  final String title;
  final String subtitle;
  const HasibuModule(this.title, this.subtitle);

  /// Faz 1 (Personel & PDKS Odaklı Kabuk) aktif modül kapısı (OCP Registry).
  /// Ön Muhasebe, ERP, Şube POS, Bordro ve Yalın Üretim modülleri
  /// aşamalı geçiş için korunur ancak aktif fazda kullanıcı arayüzünden gizlidir.
  static const List<HasibuModule> activePhaseModules = <HasibuModule>[
    HasibuModule.pdksHr,
    HasibuModule.employeePortal,
    HasibuModule.systemSettings,
  ];

  bool get isEnabledInCurrentPhase => activePhaseModules.contains(this);

  static List<HasibuModule> filterActive(Iterable<HasibuModule> modules) {
    final filtered =
        modules.where((m) => m.isEnabledInCurrentPhase).toList(growable: false);
    return filtered.isEmpty
        ? const <HasibuModule>[HasibuModule.employeePortal]
        : filtered;
  }

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
    this.allowedModules = HasibuModule.activePhaseModules,
    this.errorMessage,
  });

  bool canAccess(HasibuModule module) =>
      module.isEnabledInCurrentPhase && allowedModules.contains(module);

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
  absent('Devamsız'),
  terminated('İşten Ayrıldı'),
  notYetHired('İşe Başlamadı');

  final String label;
  const DailyAttendanceState(this.label);

  bool get isNonActiveEmployment =>
      this == DailyAttendanceState.terminated ||
      this == DailyAttendanceState.notYetHired;
}

enum HasibuThemeMode {
  light('Açık Tema'),
  dark('Koyu Tema'),
  system('Sistem Teması');

  final String label;
  const HasibuThemeMode(this.label);

  static HasibuThemeMode fromName(String? raw) {
    if (raw == null || raw.trim().isEmpty) return HasibuThemeMode.light;
    final clean = raw.trim().toLowerCase();
    for (final m in HasibuThemeMode.values) {
      if (m.name.toLowerCase() == clean) return m;
    }
    return HasibuThemeMode.light;
  }
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
  final String? logoPath;
  final HasibuThemeMode adminThemeMode;
  final String licenseToken;
  final int lastVerifiedTimestamp;
  final String hardwareFingerprint;

  const CompanySettings({
    this.companyName = 'HASİBU İŞLETME YÖNETİMİ',
    this.autoPollEnabled = true,
    this.autoPollMinutes = 5,
    this.adminUsername = 'admin',
    this.adminPassword = '123',
    this.defaultEmployeePin = '1234',
    this.syncGmailAccount = '',
    this.syncFolderPath = '',
    this.logoPath,
    this.adminThemeMode = HasibuThemeMode.light,
    this.licenseToken = '',
    this.lastVerifiedTimestamp = 0,
    this.hardwareFingerprint = '',
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
    String? Function()? logoPath,
    HasibuThemeMode? adminThemeMode,
    String? licenseToken,
    int? lastVerifiedTimestamp,
    String? hardwareFingerprint,
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
      logoPath: logoPath != null ? logoPath() : this.logoPath,
      adminThemeMode: adminThemeMode ?? this.adminThemeMode,
      licenseToken: licenseToken ?? this.licenseToken,
      lastVerifiedTimestamp:
          lastVerifiedTimestamp ?? this.lastVerifiedTimestamp,
      hardwareFingerprint: hardwareFingerprint ?? this.hardwareFingerprint,
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
        'logoPath': logoPath,
        'adminThemeMode': adminThemeMode.name,
        'licenseToken': licenseToken,
        'lastVerifiedTimestamp': lastVerifiedTimestamp,
        'hardwareFingerprint': hardwareFingerprint,
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
        logoPath: json['logoPath'] as String?,
        adminThemeMode:
            HasibuThemeMode.fromName(json['adminThemeMode'] as String?),
        licenseToken: json['licenseToken'] as String? ?? '',
        lastVerifiedTimestamp:
            (json['lastVerifiedTimestamp'] as num?)?.toInt() ?? 0,
        hardwareFingerprint: json['hardwareFingerprint'] as String? ?? '',
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
  final int terminalCommKey;
  final String qrSecret;
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
    this.terminalCommKey = HasibuSecurityService.defaultTenfeiCommKey,
    this.qrSecret = 'HSB-TOTP-SECRET-2026',
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
    int? terminalCommKey,
    String? qrSecret,
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
      terminalCommKey: terminalCommKey ?? this.terminalCommKey,
      qrSecret: qrSecret ?? this.qrSecret,
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
        'terminalCommKey': terminalCommKey,
        'qrSecret': qrSecret,
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
        terminalCommKey: (json['terminalCommKey'] as num?)?.toInt() ??
            HasibuSecurityService.defaultTenfeiCommKey,
        qrSecret: json['qrSecret'] as String? ?? 'HSB-TOTP-SECRET-2026',
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

  /// Gece vardiyası (örn. 19:00 - 07:00) dahil planlanan vardiya süresi (dakika).
  int get plannedDurationMinutes {
    final sp = startTime.split(':');
    final ep = endTime.split(':');
    final sh = int.tryParse(sp.isNotEmpty ? sp[0] : '8') ?? 8;
    final sm = int.tryParse(sp.length > 1 ? sp[1] : '0') ?? 0;
    final eh = int.tryParse(ep.isNotEmpty ? ep[0] : '18') ?? 18;
    final em = int.tryParse(ep.length > 1 ? ep[1] : '0') ?? 0;
    final startMins = sh * 60 + sm;
    final endMins = eh * 60 + em;
    if (endMins <= startMins) {
      return (24 * 60 - startMins) + endMins;
    }
    return endMins - startMins;
  }

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
  final String? exitDate; // YYYY-MM-DD (null => Aktif personel)
  final bool sgkActive;
  final int annualLeaveEntitlement;
  final int usedAnnualLeave;
  final double kpiScore;
  final String password;
  final List<HasibuModule> allowedModules;
  final String? photoPath;
  final HasibuThemeMode themeMode;

  const Employee({
    required this.id,
    required this.cardNo,
    required this.fullName,
    required this.title,
    required this.departmentId,
    required this.branchId,
    this.shiftId = 1,
    required this.hireDate,
    this.exitDate,
    this.sgkActive = true,
    this.annualLeaveEntitlement = 14,
    this.usedAnnualLeave = 0,
    this.kpiScore = 92.0,
    this.password = '1234',
    this.allowedModules = const <HasibuModule>[HasibuModule.employeePortal],
    this.photoPath,
    this.themeMode = HasibuThemeMode.light,
  });

  static DateTime? parseDateKey(String? raw) {
    if (raw == null) return null;
    final clean = raw.trim();
    if (clean.length < 10 || clean.startsWith('0000-00-00')) return null;
    final parsed = DateTime.tryParse(clean.substring(0, 10));
    if (parsed == null) return null;
    return DateTime(parsed.year, parsed.month, parsed.day);
  }

  static String? normalizeDateKey(String? raw) {
    final dt = parseDateKey(raw);
    if (dt == null) return null;
    return '${dt.year.toString().padLeft(4, '0')}-'
        '${dt.month.toString().padLeft(2, '0')}-'
        '${dt.day.toString().padLeft(2, '0')}';
  }

  String? get normalizedExitDate => normalizeDateKey(exitDate);

  bool get hasExitDate => normalizedExitDate != null;

  bool isBeforeHireDate(String dateKey) {
    final target = parseDateKey(dateKey);
    final hire = parseDateKey(hireDate);
    if (target == null || hire == null) return false;
    return target.isBefore(hire);
  }

  bool isTerminatedOn(String dateKey, {bool inclusiveOfExitDay = true}) {
    final exit = parseDateKey(exitDate);
    if (exit == null) return false;
    final target = parseDateKey(dateKey);
    if (target == null) return true;
    return inclusiveOfExitDay ? !target.isBefore(exit) : target.isAfter(exit);
  }

  bool isSeparatedAt([DateTime? referenceDate]) {
    final exit = parseDateKey(exitDate);
    if (exit == null) return false;
    final rawRef = referenceDate ?? DateTime.now();
    final ref = DateTime(rawRef.year, rawRef.month, rawRef.day);
    return !exit.isAfter(ref);
  }

  bool get isSeparatedNow => isSeparatedAt();

  int get remainingAnnualLeave =>
      (annualLeaveEntitlement - usedAnnualLeave).clamp(0, 365);

  DateTime _cappedReferenceDate([DateTime? referenceDate]) {
    final rawRef = referenceDate ?? DateTime.now();
    final ref = DateTime(rawRef.year, rawRef.month, rawRef.day);
    final exit = parseDateKey(exitDate);
    if (exit != null && exit.isBefore(ref)) {
      return exit;
    }
    return ref;
  }

  /// 4857 sayılı İş Kanunu Md. 53 uyarınca kıdem yılı hesabı.
  int tenureYearsAt([DateTime? referenceDate]) {
    final ref = _cappedReferenceDate(referenceDate);
    final parsed = parseDateKey(hireDate);
    if (parsed == null || parsed.isAfter(ref)) return 0;
    int years = ref.year - parsed.year;
    if (ref.month < parsed.month ||
        (ref.month == parsed.month && ref.day < parsed.day)) {
      years--;
    }
    return years.clamp(0, 60);
  }

  String tenureSummaryAt([DateTime? referenceDate]) {
    final ref = _cappedReferenceDate(referenceDate);
    final hire = parseDateKey(hireDate);
    if (hire == null || hire.isAfter(ref)) return 'Yeni';
    int years = ref.year - hire.year;
    int months = ref.month - hire.month;
    if (ref.day < hire.day) {
      months--;
    }
    if (months < 0) {
      years--;
      months += 12;
    }
    if (years <= 0 && months <= 0) {
      final days = ref.difference(hire).inDays;
      return days <= 0 ? 'Yeni' : '$days Gün';
    }
    if (years <= 0) return '$months Ay';
    if (months <= 0) return '$years Yıl';
    return '$years Yıl $months Ay';
  }

  /// 4857 sayılı İş Kanunu Md. 53 uyarınca kıdeme göre asgari yıllık ücretli izin hakkı:
  /// 1-5 yıl (dahil): 14 gün | 5-15 yıl: 20 gün | 15 yıl ve üzeri: 26 gün.
  int get statutoryAnnualLeaveEntitlement {
    final yrs = tenureYearsAt();
    if (yrs >= 15) return 26;
    if (yrs > 5) return 20;
    return 14;
  }

  bool get hasStatutoryLeaveMismatch =>
      annualLeaveEntitlement < statutoryAnnualLeaveEntitlement;

  Employee copyWith({
    int? id,
    String? cardNo,
    String? fullName,
    String? title,
    int? departmentId,
    int? branchId,
    int? shiftId,
    String? hireDate,
    String? Function()? exitDate,
    bool? sgkActive,
    int? annualLeaveEntitlement,
    int? usedAnnualLeave,
    double? kpiScore,
    String? password,
    List<HasibuModule>? allowedModules,
    String? Function()? photoPath,
    HasibuThemeMode? themeMode,
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
      exitDate: exitDate != null ? exitDate() : this.exitDate,
      sgkActive: sgkActive ?? this.sgkActive,
      annualLeaveEntitlement:
          annualLeaveEntitlement ?? this.annualLeaveEntitlement,
      usedAnnualLeave: usedAnnualLeave ?? this.usedAnnualLeave,
      kpiScore: kpiScore ?? this.kpiScore,
      password: password ?? this.password,
      allowedModules: allowedModules ?? this.allowedModules,
      photoPath: photoPath != null ? photoPath() : this.photoPath,
      themeMode: themeMode ?? this.themeMode,
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
        'exitDate': normalizedExitDate,
        'sgkActive': sgkActive,
        'annualLeaveEntitlement': annualLeaveEntitlement,
        'usedAnnualLeave': usedAnnualLeave,
        'kpiScore': kpiScore,
        'password': password,
        'allowedModules': HasibuModule.toCsv(allowedModules),
        'photoPath': photoPath,
        'themeMode': themeMode.name,
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
        exitDate: normalizeDateKey(json['exitDate'] as String?),
        sgkActive: json['sgkActive'] as bool? ?? true,
        annualLeaveEntitlement: json['annualLeaveEntitlement'] as int? ?? 14,
        usedAnnualLeave: json['usedAnnualLeave'] as int? ?? 0,
        kpiScore: (json['kpiScore'] as num?)?.toDouble() ?? 90.0,
        password: json['password'] as String? ?? '1234',
        allowedModules:
            HasibuModule.parseCsv(json['allowedModules'] as String?),
        photoPath: json['photoPath'] as String?,
        themeMode: HasibuThemeMode.fromName(json['themeMode'] as String?),
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
  final String integrityHash;

  const AttendanceLog({
    required this.id,
    required this.cardNo,
    required this.branchId,
    required this.deviceNo,
    required this.timestamp,
    required this.isCheckIn,
    required this.source,
    required this.verifyMethod,
    this.integrityHash = '',
  });

  String get dateKey =>
      '${timestamp.year.toString().padLeft(4, '0')}-${timestamp.month.toString().padLeft(2, '0')}-${timestamp.day.toString().padLeft(2, '0')}';

  String get timeFormatted =>
      '${timestamp.hour.toString().padLeft(2, '0')}:${timestamp.minute.toString().padLeft(2, '0')}';

  /// [HW-03] Kaydın beklenen HMAC-SHA256 bütünlük özeti
  String get expectedIntegrityHash =>
      HasibuSecurityService.computeAttendanceIntegrityHash(
        cardNo: cardNo,
        timestamp: timestamp,
        isCheckIn: isCheckIn,
        verifyMethod: verifyMethod.name,
      );

  /// [HW-04] Veritabanındaki `integrityHash` ile hesaplanan HMAC-SHA256 eşleşiyor mu?
  bool get isIntegrityValid =>
      integrityHash.isEmpty ||
      HasibuSecurityService.verifyAttendanceIntegrity(
        cardNo: cardNo,
        timestamp: timestamp,
        isCheckIn: isCheckIn,
        verifyMethod: verifyMethod.name,
        storedHash: integrityHash,
      );

  AttendanceLog copyWith({
    String? id,
    String? cardNo,
    int? branchId,
    int? deviceNo,
    DateTime? timestamp,
    bool? isCheckIn,
    AttendanceSource? source,
    VerifyMethod? verifyMethod,
    String? integrityHash,
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
      integrityHash: integrityHash ?? this.integrityHash,
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
        'integrityHash': integrityHash.isEmpty
            ? expectedIntegrityHash
            : integrityHash,
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
        integrityHash: json['integrityHash'] as String? ?? '',
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

enum PdksAnomalyFilter {
  all('Tüm Kadro'),
  missingCheckOut('Eksik Çıkış (Tek Okuma)'),
  overtime('Fazla Mesai (+Mesai)'),
  earlyLeave('Erken Çıkış'),
  missingDocs('Eksik Özlük Evrakı');

  final String label;
  const PdksAnomalyFilter(this.label);
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
  final int workedMinutes;
  final int overtimeMinutes;
  final int earlyLeaveMinutes;
  final bool hasMissingCheckOut;
  final int duplicateScansFiltered;

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
    this.workedMinutes = 0,
    this.overtimeMinutes = 0,
    this.earlyLeaveMinutes = 0,
    this.hasMissingCheckOut = false,
    this.duplicateScansFiltered = 0,
  });

  String get workedDurationFormatted {
    if (workedMinutes <= 0) return '-';
    final h = workedMinutes ~/ 60;
    final m = workedMinutes % 60;
    return m > 0 ? '${h}s ${m}dk' : '${h}s';
  }
}

enum PersonnelDocumentCategory {
  kimlikFotokopisi('Kimlik Fotokopisi / Nüfus Cüzdanı', true),
  sgkIseGirisBildirgesi('SGK İşe Giriş Bildirgesi', true),
  adliSicilKaydi('Adli Sicil / Sabıka Kaydı', true),
  saglikRaporu('İşe Giriş Sağlık Raporu', true),
  ikametgahBelgesi('İkametgah / Yerleşim Yeri Belgesi', true),
  isSozlesmesi('Belirsiz Süreli İş Sözleşmesi & KVKK', true),
  diplomaSertifika('Diploma / Ustalık & Hijyen Belgesi', false),
  digerEvrak('Diğer Resmi Evrak / Tutanak', false);

  final String label;
  final bool isMandatory;
  const PersonnelDocumentCategory(this.label, this.isMandatory);

  static PersonnelDocumentCategory fromName(String? raw) {
    if (raw == null || raw.trim().isEmpty) {
      return PersonnelDocumentCategory.digerEvrak;
    }
    for (final c in PersonnelDocumentCategory.values) {
      if (c.name == raw.trim()) return c;
    }
    return PersonnelDocumentCategory.digerEvrak;
  }
}

@immutable
class PersonnelDocument {
  final String id;
  final int employeeId;
  final PersonnelDocumentCategory category;
  final String title;
  final String filePath; // Dijital kopya dosya yolu (.pdf, .jpg, .png vb.)
  final String uploadDate; // YYYY-MM-DD
  final String notes;

  const PersonnelDocument({
    required this.id,
    required this.employeeId,
    required this.category,
    required this.title,
    required this.filePath,
    required this.uploadDate,
    this.notes = '',
  });

  PersonnelDocument copyWith({
    String? id,
    int? employeeId,
    PersonnelDocumentCategory? category,
    String? title,
    String? filePath,
    String? uploadDate,
    String? notes,
  }) {
    return PersonnelDocument(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      category: category ?? this.category,
      title: title ?? this.title,
      filePath: filePath ?? this.filePath,
      uploadDate: uploadDate ?? this.uploadDate,
      notes: notes ?? this.notes,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'category': category.name,
        'title': title,
        'filePath': filePath,
        'uploadDate': uploadDate,
        'notes': notes,
      };

  factory PersonnelDocument.fromJson(Map<String, dynamic> json) =>
      PersonnelDocument(
        id: json['id'] as String,
        employeeId: json['employeeId'] as int,
        category:
            PersonnelDocumentCategory.fromName(json['category'] as String?),
        title: json['title'] as String? ?? 'Resmi Evrak',
        filePath: json['filePath'] as String? ?? '',
        uploadDate: json['uploadDate'] as String? ?? '2026-10-20',
        notes: json['notes'] as String? ?? '',
      );
}

@immutable
class EmployeeHistoryDayEntry {
  final String dateKey; // YYYY-MM-DD
  final DailyAttendanceState state;
  final AttendanceLog? firstCheckIn;
  final AttendanceLog? lastCheckOut;
  final List<AttendanceLog> allLogs;
  final LeaveRecord? leaveRecord;
  final int lateMinutes;
  final int workedMinutes;
  final int overtimeMinutes;
  final int earlyLeaveMinutes;
  final bool hasMissingCheckOut;

  const EmployeeHistoryDayEntry({
    required this.dateKey,
    required this.state,
    this.firstCheckIn,
    this.lastCheckOut,
    this.allLogs = const <AttendanceLog>[],
    this.leaveRecord,
    this.lateMinutes = 0,
    this.workedMinutes = 0,
    this.overtimeMinutes = 0,
    this.earlyLeaveMinutes = 0,
    this.hasMissingCheckOut = false,
  });

  String get workedDurationFormatted {
    if (workedMinutes <= 0) return '-';
    final h = workedMinutes ~/ 60;
    final m = workedMinutes % 60;
    return m > 0 ? '${h}s ${m}dk' : '${h}s';
  }
}

enum HrRequestType {
  annualLeave('Yıllık / Mazeret İzni Talebi'),
  missingPunchCorrection('Unutulan Giriş/Çıkış Bildirimi'),
  overtimeApproval('Fazla Mesai Onay Talebi'),
  advancePayment('Maaş Avans / Özlük Talebi');

  final String label;
  const HrRequestType(this.label);

  static HrRequestType fromName(String? raw) {
    if (raw == null || raw.trim().isEmpty) return HrRequestType.annualLeave;
    for (final t in HrRequestType.values) {
      if (t.name == raw.trim()) return t;
    }
    return HrRequestType.annualLeave;
  }
}

enum HrRequestStatus {
  pending('Onay Bekliyor'),
  approved('İK Onayladı'),
  rejected('Reddedildi');

  final String label;
  const HrRequestStatus(this.label);

  static HrRequestStatus fromName(String? raw) {
    if (raw == null || raw.trim().isEmpty) return HrRequestStatus.pending;
    for (final s in HrRequestStatus.values) {
      if (s.name == raw.trim()) return s;
    }
    return HrRequestStatus.pending;
  }
}

@immutable
class HrRequest {
  final String id;
  final int employeeId;
  final String employeeCardNo;
  final String employeeName;
  final HrRequestType type;
  final HrRequestStatus status;
  final String targetDate; // YYYY-MM-DD
  final String? endDate; // YYYY-MM-DD (çok günlü izin için)
  final String? requestedTime; // HH:mm (unutulan giriş/çıkış saati)
  final bool isCheckInCorrection;
  final int overtimeMinutes;
  final LeaveType leaveType;
  final String reason;
  final String createdAt; // YYYY-MM-DD HH:mm
  final String? reviewerNote;

  const HrRequest({
    required this.id,
    required this.employeeId,
    required this.employeeCardNo,
    required this.employeeName,
    required this.type,
    this.status = HrRequestStatus.pending,
    required this.targetDate,
    this.endDate,
    this.requestedTime,
    this.isCheckInCorrection = false,
    this.overtimeMinutes = 0,
    this.leaveType = LeaveType.yillikIzin,
    required this.reason,
    required this.createdAt,
    this.reviewerNote,
  });

  HrRequest copyWith({
    String? id,
    int? employeeId,
    String? employeeCardNo,
    String? employeeName,
    HrRequestType? type,
    HrRequestStatus? status,
    String? targetDate,
    String? Function()? endDate,
    String? Function()? requestedTime,
    bool? isCheckInCorrection,
    int? overtimeMinutes,
    LeaveType? leaveType,
    String? reason,
    String? createdAt,
    String? Function()? reviewerNote,
  }) {
    return HrRequest(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeCardNo: employeeCardNo ?? this.employeeCardNo,
      employeeName: employeeName ?? this.employeeName,
      type: type ?? this.type,
      status: status ?? this.status,
      targetDate: targetDate ?? this.targetDate,
      endDate: endDate != null ? endDate() : this.endDate,
      requestedTime:
          requestedTime != null ? requestedTime() : this.requestedTime,
      isCheckInCorrection: isCheckInCorrection ?? this.isCheckInCorrection,
      overtimeMinutes: overtimeMinutes ?? this.overtimeMinutes,
      leaveType: leaveType ?? this.leaveType,
      reason: reason ?? this.reason,
      createdAt: createdAt ?? this.createdAt,
      reviewerNote: reviewerNote != null ? reviewerNote() : this.reviewerNote,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'employeeCardNo': employeeCardNo,
        'employeeName': employeeName,
        'type': type.name,
        'status': status.name,
        'targetDate': targetDate,
        'endDate': endDate,
        'requestedTime': requestedTime,
        'isCheckInCorrection': isCheckInCorrection,
        'overtimeMinutes': overtimeMinutes,
        'leaveTypeCode': leaveType.code,
        'reason': reason,
        'createdAt': createdAt,
        'reviewerNote': reviewerNote,
      };

  factory HrRequest.fromJson(Map<String, dynamic> json) => HrRequest(
        id: json['id'] as String,
        employeeId: json['employeeId'] as int? ?? 0,
        employeeCardNo: json['employeeCardNo'] as String? ?? '00000',
        employeeName: json['employeeName'] as String? ?? 'Personel',
        type: HrRequestType.fromName(json['type'] as String?),
        status: HrRequestStatus.fromName(json['status'] as String?),
        targetDate: json['targetDate'] as String? ?? '2026-10-20',
        endDate: json['endDate'] as String?,
        requestedTime: json['requestedTime'] as String?,
        isCheckInCorrection: json['isCheckInCorrection'] as bool? ?? false,
        overtimeMinutes: json['overtimeMinutes'] as int? ?? 0,
        leaveType: LeaveType.fromCode(json['leaveTypeCode'] as int? ?? 5),
        reason: json['reason'] as String? ?? '',
        createdAt: json['createdAt'] as String? ?? '2026-10-20 08:30',
        reviewerNote: json['reviewerNote'] as String?,
      );
}

/// [AUD-01] Silinemez Denetim İzi (`audit_logs`) Modeli
@immutable
class AuditLogEntry {
  final String id;
  final String actorEmployeeId;
  final String actionType;
  final String targetRecordId;
  final String oldValue;
  final String newValue;
  final DateTime timestamp;
  final String hash;

  const AuditLogEntry({
    required this.id,
    required this.actorEmployeeId,
    required this.actionType,
    required this.targetRecordId,
    required this.oldValue,
    required this.newValue,
    required this.timestamp,
    required this.hash,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'actorEmployeeId': actorEmployeeId,
        'actionType': actionType,
        'targetRecordId': targetRecordId,
        'oldValue': oldValue,
        'newValue': newValue,
        'timestamp': timestamp.toIso8601String(),
        'hash': hash,
      };

  factory AuditLogEntry.fromJson(Map<String, dynamic> json) => AuditLogEntry(
        id: json['id'] as String? ?? '',
        actorEmployeeId: json['actorEmployeeId'] as String? ?? 'admin',
        actionType: json['actionType'] as String? ?? '',
        targetRecordId: json['targetRecordId'] as String? ?? '',
        oldValue: json['oldValue'] as String? ?? '',
        newValue: json['newValue'] as String? ?? '',
        timestamp: DateTime.tryParse(json['timestamp'] as String? ?? '') ??
            DateTime.now(),
        hash: json['hash'] as String? ?? '',
      );
}

/// Çok günlü Devam / Devamsızlık raporu hazır dönem seçenekleri
enum AttendanceReportPreset {
  today('Bugün', 1),
  last7Days('Son 7 Gün', 7),
  thisMonth('Bu Ay', 30),
  custom('Özel Aralık', 0);

  final String label;
  final int days;
  const AttendanceReportPreset(this.label, this.days);
}

/// Tarih aralığı bazında personel devam, geç kalma, izin, rapor ve devamsızlık özeti
@immutable
class EmployeeAttendancePeriodSummary {
  final Employee employee;
  final Department department;
  final Branch branch;
  final ShiftPlan shift;
  final int totalDays;
  final int presentDays;
  final int onTimeDays;
  final int lateDays;
  final int totalLateMinutes;
  final int absentDays;
  final int onLeaveDays;
  final int sickReportDays;
  final int missingCheckOutDays;
  final int totalWorkedMinutes;
  final int totalOvertimeMinutes;
  final int totalEarlyLeaveMinutes;
  final List<String> absentDateKeys;

  const EmployeeAttendancePeriodSummary({
    required this.employee,
    required this.department,
    required this.branch,
    required this.shift,
    required this.totalDays,
    required this.presentDays,
    required this.onTimeDays,
    required this.lateDays,
    required this.totalLateMinutes,
    required this.absentDays,
    required this.onLeaveDays,
    required this.sickReportDays,
    required this.missingCheckOutDays,
    required this.totalWorkedMinutes,
    required this.totalOvertimeMinutes,
    required this.totalEarlyLeaveMinutes,
    required this.absentDateKeys,
  });

  double get attendanceRatePercent => totalDays <= 0
      ? 0.0
      : ((presentDays + onLeaveDays) / totalDays) * 100.0;
}



