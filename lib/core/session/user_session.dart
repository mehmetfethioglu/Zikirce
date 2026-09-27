import 'dart:convert';

/// Zikirce Kullanıcı Oturumu Modeli
class UserSession {
  final String id;
  final String displayName;
  final String avatar;
  final bool isCloud;
  final String? email;
  final bool hasPin;
  final String? pinHash;
  final String dbFileName;
  final DateTime createdAt;
  final DateTime lastActiveAt;

  const UserSession({
    required this.id,
    required this.displayName,
    this.avatar = 'assets/images/avatar_male_1.png',
    this.isCloud = false,
    this.email,
    this.hasPin = false,
    this.pinHash,
    required this.dbFileName,
    required this.createdAt,
    required this.lastActiveAt,
  });

  /// Varsayılan ana oturum ID'si
  static const String defaultSessionId = 'default_user';
  static const String defaultDbName = 'zikirce_app.sqlite';

  /// Varsayılan ilk ana oturum
  factory UserSession.defaultSession({
    String displayName = 'Ana Profil',
    String avatar = 'assets/images/avatar_male_1.png',
    String? email,
    bool isCloud = false,
  }) {
    final now = DateTime.now();
    return UserSession(
      id: defaultSessionId,
      displayName: displayName,
      avatar: avatar,
      isCloud: isCloud,
      email: email,
      hasPin: false,
      pinHash: null,
      dbFileName: defaultDbName,
      createdAt: now,
      lastActiveAt: now,
    );
  }

  UserSession copyWith({
    String? id,
    String? displayName,
    String? avatar,
    bool? isCloud,
    String? email,
    bool clearEmail = false,
    bool? hasPin,
    String? pinHash,
    bool clearPinHash = false,
    String? dbFileName,
    DateTime? createdAt,
    DateTime? lastActiveAt,
  }) {
    return UserSession(
      id: id ?? this.id,
      displayName: displayName ?? this.displayName,
      avatar: avatar ?? this.avatar,
      isCloud: isCloud ?? this.isCloud,
      email: clearEmail ? null : (email ?? this.email),
      hasPin: hasPin ?? this.hasPin,
      pinHash: clearPinHash ? null : (pinHash ?? this.pinHash),
      dbFileName: dbFileName ?? this.dbFileName,
      createdAt: createdAt ?? this.createdAt,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'displayName': displayName,
      'avatar': avatar,
      'isCloud': isCloud,
      'email': email,
      'hasPin': hasPin,
      'pinHash': pinHash,
      'dbFileName': dbFileName,
      'createdAt': createdAt.toIso8601String(),
      'lastActiveAt': lastActiveAt.toIso8601String(),
    };
  }

  factory UserSession.fromMap(Map<String, dynamic> map) {
    return UserSession(
      id: map['id']?.toString() ?? defaultSessionId,
      displayName: map['displayName']?.toString() ?? 'Zâkir',
      avatar: map['avatar']?.toString() ?? 'assets/images/avatar_male_1.png',
      isCloud: map['isCloud'] == true,
      email: map['email']?.toString(),
      hasPin: map['hasPin'] == true,
      pinHash: map['pinHash']?.toString(),
      dbFileName: map['dbFileName']?.toString() ?? defaultDbName,
      createdAt: map['createdAt'] != null
          ? DateTime.tryParse(map['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
      lastActiveAt: map['lastActiveAt'] != null
          ? DateTime.tryParse(map['lastActiveAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  String toJson() => jsonEncode(toMap());

  factory UserSession.fromJson(String source) =>
      UserSession.fromMap(jsonDecode(source) as Map<String, dynamic>);

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is UserSession &&
          runtimeType == other.runtimeType &&
          id == other.id;

  @override
  int get hashCode => id.hashCode;
}
