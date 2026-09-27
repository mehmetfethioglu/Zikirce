// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $ZikirsTable extends Zikirs with TableInfo<$ZikirsTable, Zikir> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ZikirsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
      'name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _arabicMeta = const VerificationMeta('arabic');
  @override
  late final GeneratedColumn<String> arabic = GeneratedColumn<String>(
      'arabic', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _targetMeta = const VerificationMeta('target');
  @override
  late final GeneratedColumn<int> target = GeneratedColumn<int>(
      'target', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(33));
  static const VerificationMeta _currentCountMeta =
      const VerificationMeta('currentCount');
  @override
  late final GeneratedColumn<int> currentCount = GeneratedColumn<int>(
      'current_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _totalCountMeta =
      const VerificationMeta('totalCount');
  @override
  late final GeneratedColumn<int> totalCount = GeneratedColumn<int>(
      'total_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lapMeta = const VerificationMeta('lap');
  @override
  late final GeneratedColumn<int> lap = GeneratedColumn<int>(
      'lap', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _isFavoriteMeta =
      const VerificationMeta('isFavorite');
  @override
  late final GeneratedColumn<bool> isFavorite = GeneratedColumn<bool>(
      'is_favorite', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_favorite" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('Genel'));
  static const VerificationMeta _soundEffectMeta =
      const VerificationMeta('soundEffect');
  @override
  late final GeneratedColumn<String> soundEffect = GeneratedColumn<String>(
      'sound_effect', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('bulbul'));
  static const VerificationMeta _vibrationEnabledMeta =
      const VerificationMeta('vibrationEnabled');
  @override
  late final GeneratedColumn<bool> vibrationEnabled = GeneratedColumn<bool>(
      'vibration_enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("vibration_enabled" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _lastPracticedMeta =
      const VerificationMeta('lastPracticed');
  @override
  late final GeneratedColumn<DateTime> lastPracticed =
      GeneratedColumn<DateTime>('last_practiced', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        name,
        arabic,
        target,
        currentCount,
        totalCount,
        lap,
        isFavorite,
        category,
        soundEffect,
        vibrationEnabled,
        createdAt,
        lastPracticed
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'zikirs';
  @override
  VerificationContext validateIntegrity(Insertable<Zikir> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
          _nameMeta, name.isAcceptableOrUnknown(data['name']!, _nameMeta));
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('arabic')) {
      context.handle(_arabicMeta,
          arabic.isAcceptableOrUnknown(data['arabic']!, _arabicMeta));
    }
    if (data.containsKey('target')) {
      context.handle(_targetMeta,
          target.isAcceptableOrUnknown(data['target']!, _targetMeta));
    }
    if (data.containsKey('current_count')) {
      context.handle(
          _currentCountMeta,
          currentCount.isAcceptableOrUnknown(
              data['current_count']!, _currentCountMeta));
    }
    if (data.containsKey('total_count')) {
      context.handle(
          _totalCountMeta,
          totalCount.isAcceptableOrUnknown(
              data['total_count']!, _totalCountMeta));
    }
    if (data.containsKey('lap')) {
      context.handle(
          _lapMeta, lap.isAcceptableOrUnknown(data['lap']!, _lapMeta));
    }
    if (data.containsKey('is_favorite')) {
      context.handle(
          _isFavoriteMeta,
          isFavorite.isAcceptableOrUnknown(
              data['is_favorite']!, _isFavoriteMeta));
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    if (data.containsKey('sound_effect')) {
      context.handle(
          _soundEffectMeta,
          soundEffect.isAcceptableOrUnknown(
              data['sound_effect']!, _soundEffectMeta));
    }
    if (data.containsKey('vibration_enabled')) {
      context.handle(
          _vibrationEnabledMeta,
          vibrationEnabled.isAcceptableOrUnknown(
              data['vibration_enabled']!, _vibrationEnabledMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    if (data.containsKey('last_practiced')) {
      context.handle(
          _lastPracticedMeta,
          lastPracticed.isAcceptableOrUnknown(
              data['last_practiced']!, _lastPracticedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Zikir map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Zikir(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      name: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}name'])!,
      arabic: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}arabic']),
      target: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}target'])!,
      currentCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}current_count'])!,
      totalCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_count'])!,
      lap: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}lap'])!,
      isFavorite: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_favorite'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
      soundEffect: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sound_effect'])!,
      vibrationEnabled: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}vibration_enabled'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
      lastPracticed: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_practiced']),
    );
  }

  @override
  $ZikirsTable createAlias(String alias) {
    return $ZikirsTable(attachedDatabase, alias);
  }
}

class Zikir extends DataClass implements Insertable<Zikir> {
  final int id;
  final String name;
  final String? arabic;
  final int target;
  final int currentCount;
  final int totalCount;
  final int lap;
  final bool isFavorite;
  final String category;
  final String soundEffect;
  final bool vibrationEnabled;
  final DateTime createdAt;
  final DateTime? lastPracticed;
  const Zikir(
      {required this.id,
      required this.name,
      this.arabic,
      required this.target,
      required this.currentCount,
      required this.totalCount,
      required this.lap,
      required this.isFavorite,
      required this.category,
      required this.soundEffect,
      required this.vibrationEnabled,
      required this.createdAt,
      this.lastPracticed});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || arabic != null) {
      map['arabic'] = Variable<String>(arabic);
    }
    map['target'] = Variable<int>(target);
    map['current_count'] = Variable<int>(currentCount);
    map['total_count'] = Variable<int>(totalCount);
    map['lap'] = Variable<int>(lap);
    map['is_favorite'] = Variable<bool>(isFavorite);
    map['category'] = Variable<String>(category);
    map['sound_effect'] = Variable<String>(soundEffect);
    map['vibration_enabled'] = Variable<bool>(vibrationEnabled);
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || lastPracticed != null) {
      map['last_practiced'] = Variable<DateTime>(lastPracticed);
    }
    return map;
  }

  ZikirsCompanion toCompanion(bool nullToAbsent) {
    return ZikirsCompanion(
      id: Value(id),
      name: Value(name),
      arabic:
          arabic == null && nullToAbsent ? const Value.absent() : Value(arabic),
      target: Value(target),
      currentCount: Value(currentCount),
      totalCount: Value(totalCount),
      lap: Value(lap),
      isFavorite: Value(isFavorite),
      category: Value(category),
      soundEffect: Value(soundEffect),
      vibrationEnabled: Value(vibrationEnabled),
      createdAt: Value(createdAt),
      lastPracticed: lastPracticed == null && nullToAbsent
          ? const Value.absent()
          : Value(lastPracticed),
    );
  }

  factory Zikir.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Zikir(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      arabic: serializer.fromJson<String?>(json['arabic']),
      target: serializer.fromJson<int>(json['target']),
      currentCount: serializer.fromJson<int>(json['currentCount']),
      totalCount: serializer.fromJson<int>(json['totalCount']),
      lap: serializer.fromJson<int>(json['lap']),
      isFavorite: serializer.fromJson<bool>(json['isFavorite']),
      category: serializer.fromJson<String>(json['category']),
      soundEffect: serializer.fromJson<String>(json['soundEffect']),
      vibrationEnabled: serializer.fromJson<bool>(json['vibrationEnabled']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      lastPracticed: serializer.fromJson<DateTime?>(json['lastPracticed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'arabic': serializer.toJson<String?>(arabic),
      'target': serializer.toJson<int>(target),
      'currentCount': serializer.toJson<int>(currentCount),
      'totalCount': serializer.toJson<int>(totalCount),
      'lap': serializer.toJson<int>(lap),
      'isFavorite': serializer.toJson<bool>(isFavorite),
      'category': serializer.toJson<String>(category),
      'soundEffect': serializer.toJson<String>(soundEffect),
      'vibrationEnabled': serializer.toJson<bool>(vibrationEnabled),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'lastPracticed': serializer.toJson<DateTime?>(lastPracticed),
    };
  }

  Zikir copyWith(
          {int? id,
          String? name,
          Value<String?> arabic = const Value.absent(),
          int? target,
          int? currentCount,
          int? totalCount,
          int? lap,
          bool? isFavorite,
          String? category,
          String? soundEffect,
          bool? vibrationEnabled,
          DateTime? createdAt,
          Value<DateTime?> lastPracticed = const Value.absent()}) =>
      Zikir(
        id: id ?? this.id,
        name: name ?? this.name,
        arabic: arabic.present ? arabic.value : this.arabic,
        target: target ?? this.target,
        currentCount: currentCount ?? this.currentCount,
        totalCount: totalCount ?? this.totalCount,
        lap: lap ?? this.lap,
        isFavorite: isFavorite ?? this.isFavorite,
        category: category ?? this.category,
        soundEffect: soundEffect ?? this.soundEffect,
        vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
        createdAt: createdAt ?? this.createdAt,
        lastPracticed:
            lastPracticed.present ? lastPracticed.value : this.lastPracticed,
      );
  Zikir copyWithCompanion(ZikirsCompanion data) {
    return Zikir(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      arabic: data.arabic.present ? data.arabic.value : this.arabic,
      target: data.target.present ? data.target.value : this.target,
      currentCount: data.currentCount.present
          ? data.currentCount.value
          : this.currentCount,
      totalCount:
          data.totalCount.present ? data.totalCount.value : this.totalCount,
      lap: data.lap.present ? data.lap.value : this.lap,
      isFavorite:
          data.isFavorite.present ? data.isFavorite.value : this.isFavorite,
      category: data.category.present ? data.category.value : this.category,
      soundEffect:
          data.soundEffect.present ? data.soundEffect.value : this.soundEffect,
      vibrationEnabled: data.vibrationEnabled.present
          ? data.vibrationEnabled.value
          : this.vibrationEnabled,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      lastPracticed: data.lastPracticed.present
          ? data.lastPracticed.value
          : this.lastPracticed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Zikir(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('arabic: $arabic, ')
          ..write('target: $target, ')
          ..write('currentCount: $currentCount, ')
          ..write('totalCount: $totalCount, ')
          ..write('lap: $lap, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('category: $category, ')
          ..write('soundEffect: $soundEffect, ')
          ..write('vibrationEnabled: $vibrationEnabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastPracticed: $lastPracticed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id,
      name,
      arabic,
      target,
      currentCount,
      totalCount,
      lap,
      isFavorite,
      category,
      soundEffect,
      vibrationEnabled,
      createdAt,
      lastPracticed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Zikir &&
          other.id == this.id &&
          other.name == this.name &&
          other.arabic == this.arabic &&
          other.target == this.target &&
          other.currentCount == this.currentCount &&
          other.totalCount == this.totalCount &&
          other.lap == this.lap &&
          other.isFavorite == this.isFavorite &&
          other.category == this.category &&
          other.soundEffect == this.soundEffect &&
          other.vibrationEnabled == this.vibrationEnabled &&
          other.createdAt == this.createdAt &&
          other.lastPracticed == this.lastPracticed);
}

class ZikirsCompanion extends UpdateCompanion<Zikir> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> arabic;
  final Value<int> target;
  final Value<int> currentCount;
  final Value<int> totalCount;
  final Value<int> lap;
  final Value<bool> isFavorite;
  final Value<String> category;
  final Value<String> soundEffect;
  final Value<bool> vibrationEnabled;
  final Value<DateTime> createdAt;
  final Value<DateTime?> lastPracticed;
  const ZikirsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.arabic = const Value.absent(),
    this.target = const Value.absent(),
    this.currentCount = const Value.absent(),
    this.totalCount = const Value.absent(),
    this.lap = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.category = const Value.absent(),
    this.soundEffect = const Value.absent(),
    this.vibrationEnabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastPracticed = const Value.absent(),
  });
  ZikirsCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.arabic = const Value.absent(),
    this.target = const Value.absent(),
    this.currentCount = const Value.absent(),
    this.totalCount = const Value.absent(),
    this.lap = const Value.absent(),
    this.isFavorite = const Value.absent(),
    this.category = const Value.absent(),
    this.soundEffect = const Value.absent(),
    this.vibrationEnabled = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.lastPracticed = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Zikir> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? arabic,
    Expression<int>? target,
    Expression<int>? currentCount,
    Expression<int>? totalCount,
    Expression<int>? lap,
    Expression<bool>? isFavorite,
    Expression<String>? category,
    Expression<String>? soundEffect,
    Expression<bool>? vibrationEnabled,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? lastPracticed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (arabic != null) 'arabic': arabic,
      if (target != null) 'target': target,
      if (currentCount != null) 'current_count': currentCount,
      if (totalCount != null) 'total_count': totalCount,
      if (lap != null) 'lap': lap,
      if (isFavorite != null) 'is_favorite': isFavorite,
      if (category != null) 'category': category,
      if (soundEffect != null) 'sound_effect': soundEffect,
      if (vibrationEnabled != null) 'vibration_enabled': vibrationEnabled,
      if (createdAt != null) 'created_at': createdAt,
      if (lastPracticed != null) 'last_practiced': lastPracticed,
    });
  }

  ZikirsCompanion copyWith(
      {Value<int>? id,
      Value<String>? name,
      Value<String?>? arabic,
      Value<int>? target,
      Value<int>? currentCount,
      Value<int>? totalCount,
      Value<int>? lap,
      Value<bool>? isFavorite,
      Value<String>? category,
      Value<String>? soundEffect,
      Value<bool>? vibrationEnabled,
      Value<DateTime>? createdAt,
      Value<DateTime?>? lastPracticed}) {
    return ZikirsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      arabic: arabic ?? this.arabic,
      target: target ?? this.target,
      currentCount: currentCount ?? this.currentCount,
      totalCount: totalCount ?? this.totalCount,
      lap: lap ?? this.lap,
      isFavorite: isFavorite ?? this.isFavorite,
      category: category ?? this.category,
      soundEffect: soundEffect ?? this.soundEffect,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
      createdAt: createdAt ?? this.createdAt,
      lastPracticed: lastPracticed ?? this.lastPracticed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (arabic.present) {
      map['arabic'] = Variable<String>(arabic.value);
    }
    if (target.present) {
      map['target'] = Variable<int>(target.value);
    }
    if (currentCount.present) {
      map['current_count'] = Variable<int>(currentCount.value);
    }
    if (totalCount.present) {
      map['total_count'] = Variable<int>(totalCount.value);
    }
    if (lap.present) {
      map['lap'] = Variable<int>(lap.value);
    }
    if (isFavorite.present) {
      map['is_favorite'] = Variable<bool>(isFavorite.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (soundEffect.present) {
      map['sound_effect'] = Variable<String>(soundEffect.value);
    }
    if (vibrationEnabled.present) {
      map['vibration_enabled'] = Variable<bool>(vibrationEnabled.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (lastPracticed.present) {
      map['last_practiced'] = Variable<DateTime>(lastPracticed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ZikirsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('arabic: $arabic, ')
          ..write('target: $target, ')
          ..write('currentCount: $currentCount, ')
          ..write('totalCount: $totalCount, ')
          ..write('lap: $lap, ')
          ..write('isFavorite: $isFavorite, ')
          ..write('category: $category, ')
          ..write('soundEffect: $soundEffect, ')
          ..write('vibrationEnabled: $vibrationEnabled, ')
          ..write('createdAt: $createdAt, ')
          ..write('lastPracticed: $lastPracticed')
          ..write(')'))
        .toString();
  }
}

class $ZikirLogsTable extends ZikirLogs
    with TableInfo<$ZikirLogsTable, ZikirLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $ZikirLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _zikirIdMeta =
      const VerificationMeta('zikirId');
  @override
  late final GeneratedColumn<int> zikirId = GeneratedColumn<int>(
      'zikir_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
      'count', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _dateStrMeta =
      const VerificationMeta('dateStr');
  @override
  late final GeneratedColumn<String> dateStr = GeneratedColumn<String>(
      'date_str', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns =>
      [id, zikirId, count, dateStr, timestamp];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'zikir_logs';
  @override
  VerificationContext validateIntegrity(Insertable<ZikirLog> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('zikir_id')) {
      context.handle(_zikirIdMeta,
          zikirId.isAcceptableOrUnknown(data['zikir_id']!, _zikirIdMeta));
    } else if (isInserting) {
      context.missing(_zikirIdMeta);
    }
    if (data.containsKey('count')) {
      context.handle(
          _countMeta, count.isAcceptableOrUnknown(data['count']!, _countMeta));
    } else if (isInserting) {
      context.missing(_countMeta);
    }
    if (data.containsKey('date_str')) {
      context.handle(_dateStrMeta,
          dateStr.isAcceptableOrUnknown(data['date_str']!, _dateStrMeta));
    } else if (isInserting) {
      context.missing(_dateStrMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  ZikirLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return ZikirLog(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      zikirId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}zikir_id'])!,
      count: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}count'])!,
      dateStr: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}date_str'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
    );
  }

  @override
  $ZikirLogsTable createAlias(String alias) {
    return $ZikirLogsTable(attachedDatabase, alias);
  }
}

class ZikirLog extends DataClass implements Insertable<ZikirLog> {
  final int id;
  final int zikirId;
  final int count;
  final String dateStr;
  final DateTime timestamp;
  const ZikirLog(
      {required this.id,
      required this.zikirId,
      required this.count,
      required this.dateStr,
      required this.timestamp});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['zikir_id'] = Variable<int>(zikirId);
    map['count'] = Variable<int>(count);
    map['date_str'] = Variable<String>(dateStr);
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  ZikirLogsCompanion toCompanion(bool nullToAbsent) {
    return ZikirLogsCompanion(
      id: Value(id),
      zikirId: Value(zikirId),
      count: Value(count),
      dateStr: Value(dateStr),
      timestamp: Value(timestamp),
    );
  }

  factory ZikirLog.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return ZikirLog(
      id: serializer.fromJson<int>(json['id']),
      zikirId: serializer.fromJson<int>(json['zikirId']),
      count: serializer.fromJson<int>(json['count']),
      dateStr: serializer.fromJson<String>(json['dateStr']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'zikirId': serializer.toJson<int>(zikirId),
      'count': serializer.toJson<int>(count),
      'dateStr': serializer.toJson<String>(dateStr),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  ZikirLog copyWith(
          {int? id,
          int? zikirId,
          int? count,
          String? dateStr,
          DateTime? timestamp}) =>
      ZikirLog(
        id: id ?? this.id,
        zikirId: zikirId ?? this.zikirId,
        count: count ?? this.count,
        dateStr: dateStr ?? this.dateStr,
        timestamp: timestamp ?? this.timestamp,
      );
  ZikirLog copyWithCompanion(ZikirLogsCompanion data) {
    return ZikirLog(
      id: data.id.present ? data.id.value : this.id,
      zikirId: data.zikirId.present ? data.zikirId.value : this.zikirId,
      count: data.count.present ? data.count.value : this.count,
      dateStr: data.dateStr.present ? data.dateStr.value : this.dateStr,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('ZikirLog(')
          ..write('id: $id, ')
          ..write('zikirId: $zikirId, ')
          ..write('count: $count, ')
          ..write('dateStr: $dateStr, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, zikirId, count, dateStr, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is ZikirLog &&
          other.id == this.id &&
          other.zikirId == this.zikirId &&
          other.count == this.count &&
          other.dateStr == this.dateStr &&
          other.timestamp == this.timestamp);
}

class ZikirLogsCompanion extends UpdateCompanion<ZikirLog> {
  final Value<int> id;
  final Value<int> zikirId;
  final Value<int> count;
  final Value<String> dateStr;
  final Value<DateTime> timestamp;
  const ZikirLogsCompanion({
    this.id = const Value.absent(),
    this.zikirId = const Value.absent(),
    this.count = const Value.absent(),
    this.dateStr = const Value.absent(),
    this.timestamp = const Value.absent(),
  });
  ZikirLogsCompanion.insert({
    this.id = const Value.absent(),
    required int zikirId,
    required int count,
    required String dateStr,
    this.timestamp = const Value.absent(),
  })  : zikirId = Value(zikirId),
        count = Value(count),
        dateStr = Value(dateStr);
  static Insertable<ZikirLog> custom({
    Expression<int>? id,
    Expression<int>? zikirId,
    Expression<int>? count,
    Expression<String>? dateStr,
    Expression<DateTime>? timestamp,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (zikirId != null) 'zikir_id': zikirId,
      if (count != null) 'count': count,
      if (dateStr != null) 'date_str': dateStr,
      if (timestamp != null) 'timestamp': timestamp,
    });
  }

  ZikirLogsCompanion copyWith(
      {Value<int>? id,
      Value<int>? zikirId,
      Value<int>? count,
      Value<String>? dateStr,
      Value<DateTime>? timestamp}) {
    return ZikirLogsCompanion(
      id: id ?? this.id,
      zikirId: zikirId ?? this.zikirId,
      count: count ?? this.count,
      dateStr: dateStr ?? this.dateStr,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (zikirId.present) {
      map['zikir_id'] = Variable<int>(zikirId.value);
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (dateStr.present) {
      map['date_str'] = Variable<String>(dateStr.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('ZikirLogsCompanion(')
          ..write('id: $id, ')
          ..write('zikirId: $zikirId, ')
          ..write('count: $count, ')
          ..write('dateStr: $dateStr, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }
}

class $UserStreaksTable extends UserStreaks
    with TableInfo<$UserStreaksTable, UserStreak> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserStreaksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _currentStreakMeta =
      const VerificationMeta('currentStreak');
  @override
  late final GeneratedColumn<int> currentStreak = GeneratedColumn<int>(
      'current_streak', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _bestStreakMeta =
      const VerificationMeta('bestStreak');
  @override
  late final GeneratedColumn<int> bestStreak = GeneratedColumn<int>(
      'best_streak', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _totalDaysMeta =
      const VerificationMeta('totalDays');
  @override
  late final GeneratedColumn<int> totalDays = GeneratedColumn<int>(
      'total_days', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _lastDateMeta =
      const VerificationMeta('lastDate');
  @override
  late final GeneratedColumn<String> lastDate = GeneratedColumn<String>(
      'last_date', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _freezeCountMeta =
      const VerificationMeta('freezeCount');
  @override
  late final GeneratedColumn<int> freezeCount = GeneratedColumn<int>(
      'freeze_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(2));
  static const VerificationMeta _lastFreezeDateMeta =
      const VerificationMeta('lastFreezeDate');
  @override
  late final GeneratedColumn<String> lastFreezeDate = GeneratedColumn<String>(
      'last_freeze_date', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _multiplierMeta =
      const VerificationMeta('multiplier');
  @override
  late final GeneratedColumn<double> multiplier = GeneratedColumn<double>(
      'multiplier', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(1.0));
  static const VerificationMeta _xpMeta = const VerificationMeta('xp');
  @override
  late final GeneratedColumn<int> xp = GeneratedColumn<int>(
      'xp', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _rankMeta = const VerificationMeta('rank');
  @override
  late final GeneratedColumn<String> rank = GeneratedColumn<String>(
      'rank', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('Mübtedi'));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        currentStreak,
        bestStreak,
        totalDays,
        lastDate,
        freezeCount,
        lastFreezeDate,
        multiplier,
        xp,
        rank
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_streaks';
  @override
  VerificationContext validateIntegrity(Insertable<UserStreak> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('current_streak')) {
      context.handle(
          _currentStreakMeta,
          currentStreak.isAcceptableOrUnknown(
              data['current_streak']!, _currentStreakMeta));
    }
    if (data.containsKey('best_streak')) {
      context.handle(
          _bestStreakMeta,
          bestStreak.isAcceptableOrUnknown(
              data['best_streak']!, _bestStreakMeta));
    }
    if (data.containsKey('total_days')) {
      context.handle(_totalDaysMeta,
          totalDays.isAcceptableOrUnknown(data['total_days']!, _totalDaysMeta));
    }
    if (data.containsKey('last_date')) {
      context.handle(_lastDateMeta,
          lastDate.isAcceptableOrUnknown(data['last_date']!, _lastDateMeta));
    }
    if (data.containsKey('freeze_count')) {
      context.handle(
          _freezeCountMeta,
          freezeCount.isAcceptableOrUnknown(
              data['freeze_count']!, _freezeCountMeta));
    }
    if (data.containsKey('last_freeze_date')) {
      context.handle(
          _lastFreezeDateMeta,
          lastFreezeDate.isAcceptableOrUnknown(
              data['last_freeze_date']!, _lastFreezeDateMeta));
    }
    if (data.containsKey('multiplier')) {
      context.handle(
          _multiplierMeta,
          multiplier.isAcceptableOrUnknown(
              data['multiplier']!, _multiplierMeta));
    }
    if (data.containsKey('xp')) {
      context.handle(_xpMeta, xp.isAcceptableOrUnknown(data['xp']!, _xpMeta));
    }
    if (data.containsKey('rank')) {
      context.handle(
          _rankMeta, rank.isAcceptableOrUnknown(data['rank']!, _rankMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserStreak map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserStreak(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      currentStreak: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}current_streak'])!,
      bestStreak: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}best_streak'])!,
      totalDays: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_days'])!,
      lastDate: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}last_date']),
      freezeCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}freeze_count'])!,
      lastFreezeDate: attachedDatabase.typeMapping.read(
          DriftSqlType.string, data['${effectivePrefix}last_freeze_date']),
      multiplier: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}multiplier'])!,
      xp: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}xp'])!,
      rank: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}rank'])!,
    );
  }

  @override
  $UserStreaksTable createAlias(String alias) {
    return $UserStreaksTable(attachedDatabase, alias);
  }
}

class UserStreak extends DataClass implements Insertable<UserStreak> {
  final int id;
  final int currentStreak;
  final int bestStreak;
  final int totalDays;
  final String? lastDate;
  final int freezeCount;
  final String? lastFreezeDate;
  final double multiplier;
  final int xp;
  final String rank;
  const UserStreak(
      {required this.id,
      required this.currentStreak,
      required this.bestStreak,
      required this.totalDays,
      this.lastDate,
      required this.freezeCount,
      this.lastFreezeDate,
      required this.multiplier,
      required this.xp,
      required this.rank});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['current_streak'] = Variable<int>(currentStreak);
    map['best_streak'] = Variable<int>(bestStreak);
    map['total_days'] = Variable<int>(totalDays);
    if (!nullToAbsent || lastDate != null) {
      map['last_date'] = Variable<String>(lastDate);
    }
    map['freeze_count'] = Variable<int>(freezeCount);
    if (!nullToAbsent || lastFreezeDate != null) {
      map['last_freeze_date'] = Variable<String>(lastFreezeDate);
    }
    map['multiplier'] = Variable<double>(multiplier);
    map['xp'] = Variable<int>(xp);
    map['rank'] = Variable<String>(rank);
    return map;
  }

  UserStreaksCompanion toCompanion(bool nullToAbsent) {
    return UserStreaksCompanion(
      id: Value(id),
      currentStreak: Value(currentStreak),
      bestStreak: Value(bestStreak),
      totalDays: Value(totalDays),
      lastDate: lastDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastDate),
      freezeCount: Value(freezeCount),
      lastFreezeDate: lastFreezeDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastFreezeDate),
      multiplier: Value(multiplier),
      xp: Value(xp),
      rank: Value(rank),
    );
  }

  factory UserStreak.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserStreak(
      id: serializer.fromJson<int>(json['id']),
      currentStreak: serializer.fromJson<int>(json['currentStreak']),
      bestStreak: serializer.fromJson<int>(json['bestStreak']),
      totalDays: serializer.fromJson<int>(json['totalDays']),
      lastDate: serializer.fromJson<String?>(json['lastDate']),
      freezeCount: serializer.fromJson<int>(json['freezeCount']),
      lastFreezeDate: serializer.fromJson<String?>(json['lastFreezeDate']),
      multiplier: serializer.fromJson<double>(json['multiplier']),
      xp: serializer.fromJson<int>(json['xp']),
      rank: serializer.fromJson<String>(json['rank']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'currentStreak': serializer.toJson<int>(currentStreak),
      'bestStreak': serializer.toJson<int>(bestStreak),
      'totalDays': serializer.toJson<int>(totalDays),
      'lastDate': serializer.toJson<String?>(lastDate),
      'freezeCount': serializer.toJson<int>(freezeCount),
      'lastFreezeDate': serializer.toJson<String?>(lastFreezeDate),
      'multiplier': serializer.toJson<double>(multiplier),
      'xp': serializer.toJson<int>(xp),
      'rank': serializer.toJson<String>(rank),
    };
  }

  UserStreak copyWith(
          {int? id,
          int? currentStreak,
          int? bestStreak,
          int? totalDays,
          Value<String?> lastDate = const Value.absent(),
          int? freezeCount,
          Value<String?> lastFreezeDate = const Value.absent(),
          double? multiplier,
          int? xp,
          String? rank}) =>
      UserStreak(
        id: id ?? this.id,
        currentStreak: currentStreak ?? this.currentStreak,
        bestStreak: bestStreak ?? this.bestStreak,
        totalDays: totalDays ?? this.totalDays,
        lastDate: lastDate.present ? lastDate.value : this.lastDate,
        freezeCount: freezeCount ?? this.freezeCount,
        lastFreezeDate:
            lastFreezeDate.present ? lastFreezeDate.value : this.lastFreezeDate,
        multiplier: multiplier ?? this.multiplier,
        xp: xp ?? this.xp,
        rank: rank ?? this.rank,
      );
  UserStreak copyWithCompanion(UserStreaksCompanion data) {
    return UserStreak(
      id: data.id.present ? data.id.value : this.id,
      currentStreak: data.currentStreak.present
          ? data.currentStreak.value
          : this.currentStreak,
      bestStreak:
          data.bestStreak.present ? data.bestStreak.value : this.bestStreak,
      totalDays: data.totalDays.present ? data.totalDays.value : this.totalDays,
      lastDate: data.lastDate.present ? data.lastDate.value : this.lastDate,
      freezeCount:
          data.freezeCount.present ? data.freezeCount.value : this.freezeCount,
      lastFreezeDate: data.lastFreezeDate.present
          ? data.lastFreezeDate.value
          : this.lastFreezeDate,
      multiplier:
          data.multiplier.present ? data.multiplier.value : this.multiplier,
      xp: data.xp.present ? data.xp.value : this.xp,
      rank: data.rank.present ? data.rank.value : this.rank,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserStreak(')
          ..write('id: $id, ')
          ..write('currentStreak: $currentStreak, ')
          ..write('bestStreak: $bestStreak, ')
          ..write('totalDays: $totalDays, ')
          ..write('lastDate: $lastDate, ')
          ..write('freezeCount: $freezeCount, ')
          ..write('lastFreezeDate: $lastFreezeDate, ')
          ..write('multiplier: $multiplier, ')
          ..write('xp: $xp, ')
          ..write('rank: $rank')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, currentStreak, bestStreak, totalDays,
      lastDate, freezeCount, lastFreezeDate, multiplier, xp, rank);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserStreak &&
          other.id == this.id &&
          other.currentStreak == this.currentStreak &&
          other.bestStreak == this.bestStreak &&
          other.totalDays == this.totalDays &&
          other.lastDate == this.lastDate &&
          other.freezeCount == this.freezeCount &&
          other.lastFreezeDate == this.lastFreezeDate &&
          other.multiplier == this.multiplier &&
          other.xp == this.xp &&
          other.rank == this.rank);
}

class UserStreaksCompanion extends UpdateCompanion<UserStreak> {
  final Value<int> id;
  final Value<int> currentStreak;
  final Value<int> bestStreak;
  final Value<int> totalDays;
  final Value<String?> lastDate;
  final Value<int> freezeCount;
  final Value<String?> lastFreezeDate;
  final Value<double> multiplier;
  final Value<int> xp;
  final Value<String> rank;
  const UserStreaksCompanion({
    this.id = const Value.absent(),
    this.currentStreak = const Value.absent(),
    this.bestStreak = const Value.absent(),
    this.totalDays = const Value.absent(),
    this.lastDate = const Value.absent(),
    this.freezeCount = const Value.absent(),
    this.lastFreezeDate = const Value.absent(),
    this.multiplier = const Value.absent(),
    this.xp = const Value.absent(),
    this.rank = const Value.absent(),
  });
  UserStreaksCompanion.insert({
    this.id = const Value.absent(),
    this.currentStreak = const Value.absent(),
    this.bestStreak = const Value.absent(),
    this.totalDays = const Value.absent(),
    this.lastDate = const Value.absent(),
    this.freezeCount = const Value.absent(),
    this.lastFreezeDate = const Value.absent(),
    this.multiplier = const Value.absent(),
    this.xp = const Value.absent(),
    this.rank = const Value.absent(),
  });
  static Insertable<UserStreak> custom({
    Expression<int>? id,
    Expression<int>? currentStreak,
    Expression<int>? bestStreak,
    Expression<int>? totalDays,
    Expression<String>? lastDate,
    Expression<int>? freezeCount,
    Expression<String>? lastFreezeDate,
    Expression<double>? multiplier,
    Expression<int>? xp,
    Expression<String>? rank,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (currentStreak != null) 'current_streak': currentStreak,
      if (bestStreak != null) 'best_streak': bestStreak,
      if (totalDays != null) 'total_days': totalDays,
      if (lastDate != null) 'last_date': lastDate,
      if (freezeCount != null) 'freeze_count': freezeCount,
      if (lastFreezeDate != null) 'last_freeze_date': lastFreezeDate,
      if (multiplier != null) 'multiplier': multiplier,
      if (xp != null) 'xp': xp,
      if (rank != null) 'rank': rank,
    });
  }

  UserStreaksCompanion copyWith(
      {Value<int>? id,
      Value<int>? currentStreak,
      Value<int>? bestStreak,
      Value<int>? totalDays,
      Value<String?>? lastDate,
      Value<int>? freezeCount,
      Value<String?>? lastFreezeDate,
      Value<double>? multiplier,
      Value<int>? xp,
      Value<String>? rank}) {
    return UserStreaksCompanion(
      id: id ?? this.id,
      currentStreak: currentStreak ?? this.currentStreak,
      bestStreak: bestStreak ?? this.bestStreak,
      totalDays: totalDays ?? this.totalDays,
      lastDate: lastDate ?? this.lastDate,
      freezeCount: freezeCount ?? this.freezeCount,
      lastFreezeDate: lastFreezeDate ?? this.lastFreezeDate,
      multiplier: multiplier ?? this.multiplier,
      xp: xp ?? this.xp,
      rank: rank ?? this.rank,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (currentStreak.present) {
      map['current_streak'] = Variable<int>(currentStreak.value);
    }
    if (bestStreak.present) {
      map['best_streak'] = Variable<int>(bestStreak.value);
    }
    if (totalDays.present) {
      map['total_days'] = Variable<int>(totalDays.value);
    }
    if (lastDate.present) {
      map['last_date'] = Variable<String>(lastDate.value);
    }
    if (freezeCount.present) {
      map['freeze_count'] = Variable<int>(freezeCount.value);
    }
    if (lastFreezeDate.present) {
      map['last_freeze_date'] = Variable<String>(lastFreezeDate.value);
    }
    if (multiplier.present) {
      map['multiplier'] = Variable<double>(multiplier.value);
    }
    if (xp.present) {
      map['xp'] = Variable<int>(xp.value);
    }
    if (rank.present) {
      map['rank'] = Variable<String>(rank.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserStreaksCompanion(')
          ..write('id: $id, ')
          ..write('currentStreak: $currentStreak, ')
          ..write('bestStreak: $bestStreak, ')
          ..write('totalDays: $totalDays, ')
          ..write('lastDate: $lastDate, ')
          ..write('freezeCount: $freezeCount, ')
          ..write('lastFreezeDate: $lastFreezeDate, ')
          ..write('multiplier: $multiplier, ')
          ..write('xp: $xp, ')
          ..write('rank: $rank')
          ..write(')'))
        .toString();
  }
}

class $UserStreakHistoriesTable extends UserStreakHistories
    with TableInfo<$UserStreakHistoriesTable, UserStreakHistory> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserStreakHistoriesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _dateStrMeta =
      const VerificationMeta('dateStr');
  @override
  late final GeneratedColumn<String> dateStr = GeneratedColumn<String>(
      'date_str', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _actionTypeMeta =
      const VerificationMeta('actionType');
  @override
  late final GeneratedColumn<String> actionType = GeneratedColumn<String>(
      'action_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _xpGainedMeta =
      const VerificationMeta('xpGained');
  @override
  late final GeneratedColumn<int> xpGained = GeneratedColumn<int>(
      'xp_gained', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  @override
  List<GeneratedColumn> get $columns => [id, dateStr, actionType, xpGained];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_streak_histories';
  @override
  VerificationContext validateIntegrity(Insertable<UserStreakHistory> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('date_str')) {
      context.handle(_dateStrMeta,
          dateStr.isAcceptableOrUnknown(data['date_str']!, _dateStrMeta));
    } else if (isInserting) {
      context.missing(_dateStrMeta);
    }
    if (data.containsKey('action_type')) {
      context.handle(
          _actionTypeMeta,
          actionType.isAcceptableOrUnknown(
              data['action_type']!, _actionTypeMeta));
    } else if (isInserting) {
      context.missing(_actionTypeMeta);
    }
    if (data.containsKey('xp_gained')) {
      context.handle(_xpGainedMeta,
          xpGained.isAcceptableOrUnknown(data['xp_gained']!, _xpGainedMeta));
    } else if (isInserting) {
      context.missing(_xpGainedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserStreakHistory map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserStreakHistory(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      dateStr: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}date_str'])!,
      actionType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}action_type'])!,
      xpGained: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}xp_gained'])!,
    );
  }

  @override
  $UserStreakHistoriesTable createAlias(String alias) {
    return $UserStreakHistoriesTable(attachedDatabase, alias);
  }
}

class UserStreakHistory extends DataClass
    implements Insertable<UserStreakHistory> {
  final int id;
  final String dateStr;
  final String actionType;
  final int xpGained;
  const UserStreakHistory(
      {required this.id,
      required this.dateStr,
      required this.actionType,
      required this.xpGained});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['date_str'] = Variable<String>(dateStr);
    map['action_type'] = Variable<String>(actionType);
    map['xp_gained'] = Variable<int>(xpGained);
    return map;
  }

  UserStreakHistoriesCompanion toCompanion(bool nullToAbsent) {
    return UserStreakHistoriesCompanion(
      id: Value(id),
      dateStr: Value(dateStr),
      actionType: Value(actionType),
      xpGained: Value(xpGained),
    );
  }

  factory UserStreakHistory.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserStreakHistory(
      id: serializer.fromJson<int>(json['id']),
      dateStr: serializer.fromJson<String>(json['dateStr']),
      actionType: serializer.fromJson<String>(json['actionType']),
      xpGained: serializer.fromJson<int>(json['xpGained']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'dateStr': serializer.toJson<String>(dateStr),
      'actionType': serializer.toJson<String>(actionType),
      'xpGained': serializer.toJson<int>(xpGained),
    };
  }

  UserStreakHistory copyWith(
          {int? id, String? dateStr, String? actionType, int? xpGained}) =>
      UserStreakHistory(
        id: id ?? this.id,
        dateStr: dateStr ?? this.dateStr,
        actionType: actionType ?? this.actionType,
        xpGained: xpGained ?? this.xpGained,
      );
  UserStreakHistory copyWithCompanion(UserStreakHistoriesCompanion data) {
    return UserStreakHistory(
      id: data.id.present ? data.id.value : this.id,
      dateStr: data.dateStr.present ? data.dateStr.value : this.dateStr,
      actionType:
          data.actionType.present ? data.actionType.value : this.actionType,
      xpGained: data.xpGained.present ? data.xpGained.value : this.xpGained,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserStreakHistory(')
          ..write('id: $id, ')
          ..write('dateStr: $dateStr, ')
          ..write('actionType: $actionType, ')
          ..write('xpGained: $xpGained')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, dateStr, actionType, xpGained);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserStreakHistory &&
          other.id == this.id &&
          other.dateStr == this.dateStr &&
          other.actionType == this.actionType &&
          other.xpGained == this.xpGained);
}

class UserStreakHistoriesCompanion extends UpdateCompanion<UserStreakHistory> {
  final Value<int> id;
  final Value<String> dateStr;
  final Value<String> actionType;
  final Value<int> xpGained;
  const UserStreakHistoriesCompanion({
    this.id = const Value.absent(),
    this.dateStr = const Value.absent(),
    this.actionType = const Value.absent(),
    this.xpGained = const Value.absent(),
  });
  UserStreakHistoriesCompanion.insert({
    this.id = const Value.absent(),
    required String dateStr,
    required String actionType,
    required int xpGained,
  })  : dateStr = Value(dateStr),
        actionType = Value(actionType),
        xpGained = Value(xpGained);
  static Insertable<UserStreakHistory> custom({
    Expression<int>? id,
    Expression<String>? dateStr,
    Expression<String>? actionType,
    Expression<int>? xpGained,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (dateStr != null) 'date_str': dateStr,
      if (actionType != null) 'action_type': actionType,
      if (xpGained != null) 'xp_gained': xpGained,
    });
  }

  UserStreakHistoriesCompanion copyWith(
      {Value<int>? id,
      Value<String>? dateStr,
      Value<String>? actionType,
      Value<int>? xpGained}) {
    return UserStreakHistoriesCompanion(
      id: id ?? this.id,
      dateStr: dateStr ?? this.dateStr,
      actionType: actionType ?? this.actionType,
      xpGained: xpGained ?? this.xpGained,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (dateStr.present) {
      map['date_str'] = Variable<String>(dateStr.value);
    }
    if (actionType.present) {
      map['action_type'] = Variable<String>(actionType.value);
    }
    if (xpGained.present) {
      map['xp_gained'] = Variable<int>(xpGained.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserStreakHistoriesCompanion(')
          ..write('id: $id, ')
          ..write('dateStr: $dateStr, ')
          ..write('actionType: $actionType, ')
          ..write('xpGained: $xpGained')
          ..write(')'))
        .toString();
  }
}

class $StreakGapDaysTable extends StreakGapDays
    with TableInfo<$StreakGapDaysTable, StreakGapDay> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StreakGapDaysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateStrMeta =
      const VerificationMeta('dateStr');
  @override
  late final GeneratedColumn<String> dateStr = GeneratedColumn<String>(
      'date_str', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isRepairedMeta =
      const VerificationMeta('isRepaired');
  @override
  late final GeneratedColumn<bool> isRepaired = GeneratedColumn<bool>(
      'is_repaired', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_repaired" IN (0, 1))'),
      defaultValue: const Constant(false));
  @override
  List<GeneratedColumn> get $columns => [dateStr, isRepaired];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'streak_gap_days';
  @override
  VerificationContext validateIntegrity(Insertable<StreakGapDay> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date_str')) {
      context.handle(_dateStrMeta,
          dateStr.isAcceptableOrUnknown(data['date_str']!, _dateStrMeta));
    } else if (isInserting) {
      context.missing(_dateStrMeta);
    }
    if (data.containsKey('is_repaired')) {
      context.handle(
          _isRepairedMeta,
          isRepaired.isAcceptableOrUnknown(
              data['is_repaired']!, _isRepairedMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {dateStr};
  @override
  StreakGapDay map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StreakGapDay(
      dateStr: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}date_str'])!,
      isRepaired: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_repaired'])!,
    );
  }

  @override
  $StreakGapDaysTable createAlias(String alias) {
    return $StreakGapDaysTable(attachedDatabase, alias);
  }
}

class StreakGapDay extends DataClass implements Insertable<StreakGapDay> {
  final String dateStr;
  final bool isRepaired;
  const StreakGapDay({required this.dateStr, required this.isRepaired});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date_str'] = Variable<String>(dateStr);
    map['is_repaired'] = Variable<bool>(isRepaired);
    return map;
  }

  StreakGapDaysCompanion toCompanion(bool nullToAbsent) {
    return StreakGapDaysCompanion(
      dateStr: Value(dateStr),
      isRepaired: Value(isRepaired),
    );
  }

  factory StreakGapDay.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StreakGapDay(
      dateStr: serializer.fromJson<String>(json['dateStr']),
      isRepaired: serializer.fromJson<bool>(json['isRepaired']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dateStr': serializer.toJson<String>(dateStr),
      'isRepaired': serializer.toJson<bool>(isRepaired),
    };
  }

  StreakGapDay copyWith({String? dateStr, bool? isRepaired}) => StreakGapDay(
        dateStr: dateStr ?? this.dateStr,
        isRepaired: isRepaired ?? this.isRepaired,
      );
  StreakGapDay copyWithCompanion(StreakGapDaysCompanion data) {
    return StreakGapDay(
      dateStr: data.dateStr.present ? data.dateStr.value : this.dateStr,
      isRepaired:
          data.isRepaired.present ? data.isRepaired.value : this.isRepaired,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StreakGapDay(')
          ..write('dateStr: $dateStr, ')
          ..write('isRepaired: $isRepaired')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(dateStr, isRepaired);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StreakGapDay &&
          other.dateStr == this.dateStr &&
          other.isRepaired == this.isRepaired);
}

class StreakGapDaysCompanion extends UpdateCompanion<StreakGapDay> {
  final Value<String> dateStr;
  final Value<bool> isRepaired;
  final Value<int> rowid;
  const StreakGapDaysCompanion({
    this.dateStr = const Value.absent(),
    this.isRepaired = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StreakGapDaysCompanion.insert({
    required String dateStr,
    this.isRepaired = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : dateStr = Value(dateStr);
  static Insertable<StreakGapDay> custom({
    Expression<String>? dateStr,
    Expression<bool>? isRepaired,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (dateStr != null) 'date_str': dateStr,
      if (isRepaired != null) 'is_repaired': isRepaired,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StreakGapDaysCompanion copyWith(
      {Value<String>? dateStr, Value<bool>? isRepaired, Value<int>? rowid}) {
    return StreakGapDaysCompanion(
      dateStr: dateStr ?? this.dateStr,
      isRepaired: isRepaired ?? this.isRepaired,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dateStr.present) {
      map['date_str'] = Variable<String>(dateStr.value);
    }
    if (isRepaired.present) {
      map['is_repaired'] = Variable<bool>(isRepaired.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StreakGapDaysCompanion(')
          ..write('dateStr: $dateStr, ')
          ..write('isRepaired: $isRepaired, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UnlockedBadgesTable extends UnlockedBadges
    with TableInfo<$UnlockedBadgesTable, UnlockedBadge> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UnlockedBadgesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _badgeIdMeta =
      const VerificationMeta('badgeId');
  @override
  late final GeneratedColumn<String> badgeId = GeneratedColumn<String>(
      'badge_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _unlockedAtMeta =
      const VerificationMeta('unlockedAt');
  @override
  late final GeneratedColumn<DateTime> unlockedAt = GeneratedColumn<DateTime>(
      'unlocked_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  static const VerificationMeta _categoryMeta =
      const VerificationMeta('category');
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
      'category', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('General'));
  @override
  List<GeneratedColumn> get $columns => [badgeId, unlockedAt, category];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'unlocked_badges';
  @override
  VerificationContext validateIntegrity(Insertable<UnlockedBadge> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('badge_id')) {
      context.handle(_badgeIdMeta,
          badgeId.isAcceptableOrUnknown(data['badge_id']!, _badgeIdMeta));
    } else if (isInserting) {
      context.missing(_badgeIdMeta);
    }
    if (data.containsKey('unlocked_at')) {
      context.handle(
          _unlockedAtMeta,
          unlockedAt.isAcceptableOrUnknown(
              data['unlocked_at']!, _unlockedAtMeta));
    }
    if (data.containsKey('category')) {
      context.handle(_categoryMeta,
          category.isAcceptableOrUnknown(data['category']!, _categoryMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {badgeId};
  @override
  UnlockedBadge map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UnlockedBadge(
      badgeId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}badge_id'])!,
      unlockedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}unlocked_at'])!,
      category: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}category'])!,
    );
  }

  @override
  $UnlockedBadgesTable createAlias(String alias) {
    return $UnlockedBadgesTable(attachedDatabase, alias);
  }
}

class UnlockedBadge extends DataClass implements Insertable<UnlockedBadge> {
  final String badgeId;
  final DateTime unlockedAt;
  final String category;
  const UnlockedBadge(
      {required this.badgeId,
      required this.unlockedAt,
      required this.category});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['badge_id'] = Variable<String>(badgeId);
    map['unlocked_at'] = Variable<DateTime>(unlockedAt);
    map['category'] = Variable<String>(category);
    return map;
  }

  UnlockedBadgesCompanion toCompanion(bool nullToAbsent) {
    return UnlockedBadgesCompanion(
      badgeId: Value(badgeId),
      unlockedAt: Value(unlockedAt),
      category: Value(category),
    );
  }

  factory UnlockedBadge.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UnlockedBadge(
      badgeId: serializer.fromJson<String>(json['badgeId']),
      unlockedAt: serializer.fromJson<DateTime>(json['unlockedAt']),
      category: serializer.fromJson<String>(json['category']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'badgeId': serializer.toJson<String>(badgeId),
      'unlockedAt': serializer.toJson<DateTime>(unlockedAt),
      'category': serializer.toJson<String>(category),
    };
  }

  UnlockedBadge copyWith(
          {String? badgeId, DateTime? unlockedAt, String? category}) =>
      UnlockedBadge(
        badgeId: badgeId ?? this.badgeId,
        unlockedAt: unlockedAt ?? this.unlockedAt,
        category: category ?? this.category,
      );
  UnlockedBadge copyWithCompanion(UnlockedBadgesCompanion data) {
    return UnlockedBadge(
      badgeId: data.badgeId.present ? data.badgeId.value : this.badgeId,
      unlockedAt:
          data.unlockedAt.present ? data.unlockedAt.value : this.unlockedAt,
      category: data.category.present ? data.category.value : this.category,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UnlockedBadge(')
          ..write('badgeId: $badgeId, ')
          ..write('unlockedAt: $unlockedAt, ')
          ..write('category: $category')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(badgeId, unlockedAt, category);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UnlockedBadge &&
          other.badgeId == this.badgeId &&
          other.unlockedAt == this.unlockedAt &&
          other.category == this.category);
}

class UnlockedBadgesCompanion extends UpdateCompanion<UnlockedBadge> {
  final Value<String> badgeId;
  final Value<DateTime> unlockedAt;
  final Value<String> category;
  final Value<int> rowid;
  const UnlockedBadgesCompanion({
    this.badgeId = const Value.absent(),
    this.unlockedAt = const Value.absent(),
    this.category = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  UnlockedBadgesCompanion.insert({
    required String badgeId,
    this.unlockedAt = const Value.absent(),
    this.category = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : badgeId = Value(badgeId);
  static Insertable<UnlockedBadge> custom({
    Expression<String>? badgeId,
    Expression<DateTime>? unlockedAt,
    Expression<String>? category,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (badgeId != null) 'badge_id': badgeId,
      if (unlockedAt != null) 'unlocked_at': unlockedAt,
      if (category != null) 'category': category,
      if (rowid != null) 'rowid': rowid,
    });
  }

  UnlockedBadgesCompanion copyWith(
      {Value<String>? badgeId,
      Value<DateTime>? unlockedAt,
      Value<String>? category,
      Value<int>? rowid}) {
    return UnlockedBadgesCompanion(
      badgeId: badgeId ?? this.badgeId,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      category: category ?? this.category,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (badgeId.present) {
      map['badge_id'] = Variable<String>(badgeId.value);
    }
    if (unlockedAt.present) {
      map['unlocked_at'] = Variable<DateTime>(unlockedAt.value);
    }
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UnlockedBadgesCompanion(')
          ..write('badgeId: $badgeId, ')
          ..write('unlockedAt: $unlockedAt, ')
          ..write('category: $category, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $UserProfilesTable extends UserProfiles
    with TableInfo<$UserProfilesTable, UserProfile> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $UserProfilesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _userNameMeta =
      const VerificationMeta('userName');
  @override
  late final GeneratedColumn<String> userName = GeneratedColumn<String>(
      'user_name', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('Zâkir'));
  static const VerificationMeta _avatarMeta = const VerificationMeta('avatar');
  @override
  late final GeneratedColumn<String> avatar = GeneratedColumn<String>(
      'avatar', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('avatar_male_1'));
  static const VerificationMeta _dailyGoalMinutesMeta =
      const VerificationMeta('dailyGoalMinutes');
  @override
  late final GeneratedColumn<int> dailyGoalMinutes = GeneratedColumn<int>(
      'daily_goal_minutes', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(15));
  static const VerificationMeta _dailyZikirTargetMeta =
      const VerificationMeta('dailyZikirTarget');
  @override
  late final GeneratedColumn<int> dailyZikirTarget = GeneratedColumn<int>(
      'daily_zikir_target', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(100));
  static const VerificationMeta _themeModeMeta =
      const VerificationMeta('themeMode');
  @override
  late final GeneratedColumn<String> themeMode = GeneratedColumn<String>(
      'theme_mode', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('midnightGold'));
  static const VerificationMeta _soundVolumeMeta =
      const VerificationMeta('soundVolume');
  @override
  late final GeneratedColumn<double> soundVolume = GeneratedColumn<double>(
      'sound_volume', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(1.0));
  static const VerificationMeta _hapticEnabledMeta =
      const VerificationMeta('hapticEnabled');
  @override
  late final GeneratedColumn<bool> hapticEnabled = GeneratedColumn<bool>(
      'haptic_enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("haptic_enabled" IN (0, 1))'),
      defaultValue: const Constant(true));
  @override
  List<GeneratedColumn> get $columns => [
        id,
        userName,
        avatar,
        dailyGoalMinutes,
        dailyZikirTarget,
        themeMode,
        soundVolume,
        hapticEnabled
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'user_profiles';
  @override
  VerificationContext validateIntegrity(Insertable<UserProfile> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('user_name')) {
      context.handle(_userNameMeta,
          userName.isAcceptableOrUnknown(data['user_name']!, _userNameMeta));
    }
    if (data.containsKey('avatar')) {
      context.handle(_avatarMeta,
          avatar.isAcceptableOrUnknown(data['avatar']!, _avatarMeta));
    }
    if (data.containsKey('daily_goal_minutes')) {
      context.handle(
          _dailyGoalMinutesMeta,
          dailyGoalMinutes.isAcceptableOrUnknown(
              data['daily_goal_minutes']!, _dailyGoalMinutesMeta));
    }
    if (data.containsKey('daily_zikir_target')) {
      context.handle(
          _dailyZikirTargetMeta,
          dailyZikirTarget.isAcceptableOrUnknown(
              data['daily_zikir_target']!, _dailyZikirTargetMeta));
    }
    if (data.containsKey('theme_mode')) {
      context.handle(_themeModeMeta,
          themeMode.isAcceptableOrUnknown(data['theme_mode']!, _themeModeMeta));
    }
    if (data.containsKey('sound_volume')) {
      context.handle(
          _soundVolumeMeta,
          soundVolume.isAcceptableOrUnknown(
              data['sound_volume']!, _soundVolumeMeta));
    }
    if (data.containsKey('haptic_enabled')) {
      context.handle(
          _hapticEnabledMeta,
          hapticEnabled.isAcceptableOrUnknown(
              data['haptic_enabled']!, _hapticEnabledMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  UserProfile map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return UserProfile(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      userName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}user_name'])!,
      avatar: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}avatar'])!,
      dailyGoalMinutes: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}daily_goal_minutes'])!,
      dailyZikirTarget: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}daily_zikir_target'])!,
      themeMode: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}theme_mode'])!,
      soundVolume: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}sound_volume'])!,
      hapticEnabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}haptic_enabled'])!,
    );
  }

  @override
  $UserProfilesTable createAlias(String alias) {
    return $UserProfilesTable(attachedDatabase, alias);
  }
}

class UserProfile extends DataClass implements Insertable<UserProfile> {
  final int id;
  final String userName;
  final String avatar;
  final int dailyGoalMinutes;
  final int dailyZikirTarget;
  final String themeMode;
  final double soundVolume;
  final bool hapticEnabled;
  const UserProfile(
      {required this.id,
      required this.userName,
      required this.avatar,
      required this.dailyGoalMinutes,
      required this.dailyZikirTarget,
      required this.themeMode,
      required this.soundVolume,
      required this.hapticEnabled});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['user_name'] = Variable<String>(userName);
    map['avatar'] = Variable<String>(avatar);
    map['daily_goal_minutes'] = Variable<int>(dailyGoalMinutes);
    map['daily_zikir_target'] = Variable<int>(dailyZikirTarget);
    map['theme_mode'] = Variable<String>(themeMode);
    map['sound_volume'] = Variable<double>(soundVolume);
    map['haptic_enabled'] = Variable<bool>(hapticEnabled);
    return map;
  }

  UserProfilesCompanion toCompanion(bool nullToAbsent) {
    return UserProfilesCompanion(
      id: Value(id),
      userName: Value(userName),
      avatar: Value(avatar),
      dailyGoalMinutes: Value(dailyGoalMinutes),
      dailyZikirTarget: Value(dailyZikirTarget),
      themeMode: Value(themeMode),
      soundVolume: Value(soundVolume),
      hapticEnabled: Value(hapticEnabled),
    );
  }

  factory UserProfile.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return UserProfile(
      id: serializer.fromJson<int>(json['id']),
      userName: serializer.fromJson<String>(json['userName']),
      avatar: serializer.fromJson<String>(json['avatar']),
      dailyGoalMinutes: serializer.fromJson<int>(json['dailyGoalMinutes']),
      dailyZikirTarget: serializer.fromJson<int>(json['dailyZikirTarget']),
      themeMode: serializer.fromJson<String>(json['themeMode']),
      soundVolume: serializer.fromJson<double>(json['soundVolume']),
      hapticEnabled: serializer.fromJson<bool>(json['hapticEnabled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'userName': serializer.toJson<String>(userName),
      'avatar': serializer.toJson<String>(avatar),
      'dailyGoalMinutes': serializer.toJson<int>(dailyGoalMinutes),
      'dailyZikirTarget': serializer.toJson<int>(dailyZikirTarget),
      'themeMode': serializer.toJson<String>(themeMode),
      'soundVolume': serializer.toJson<double>(soundVolume),
      'hapticEnabled': serializer.toJson<bool>(hapticEnabled),
    };
  }

  UserProfile copyWith(
          {int? id,
          String? userName,
          String? avatar,
          int? dailyGoalMinutes,
          int? dailyZikirTarget,
          String? themeMode,
          double? soundVolume,
          bool? hapticEnabled}) =>
      UserProfile(
        id: id ?? this.id,
        userName: userName ?? this.userName,
        avatar: avatar ?? this.avatar,
        dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
        dailyZikirTarget: dailyZikirTarget ?? this.dailyZikirTarget,
        themeMode: themeMode ?? this.themeMode,
        soundVolume: soundVolume ?? this.soundVolume,
        hapticEnabled: hapticEnabled ?? this.hapticEnabled,
      );
  UserProfile copyWithCompanion(UserProfilesCompanion data) {
    return UserProfile(
      id: data.id.present ? data.id.value : this.id,
      userName: data.userName.present ? data.userName.value : this.userName,
      avatar: data.avatar.present ? data.avatar.value : this.avatar,
      dailyGoalMinutes: data.dailyGoalMinutes.present
          ? data.dailyGoalMinutes.value
          : this.dailyGoalMinutes,
      dailyZikirTarget: data.dailyZikirTarget.present
          ? data.dailyZikirTarget.value
          : this.dailyZikirTarget,
      themeMode: data.themeMode.present ? data.themeMode.value : this.themeMode,
      soundVolume:
          data.soundVolume.present ? data.soundVolume.value : this.soundVolume,
      hapticEnabled: data.hapticEnabled.present
          ? data.hapticEnabled.value
          : this.hapticEnabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('UserProfile(')
          ..write('id: $id, ')
          ..write('userName: $userName, ')
          ..write('avatar: $avatar, ')
          ..write('dailyGoalMinutes: $dailyGoalMinutes, ')
          ..write('dailyZikirTarget: $dailyZikirTarget, ')
          ..write('themeMode: $themeMode, ')
          ..write('soundVolume: $soundVolume, ')
          ..write('hapticEnabled: $hapticEnabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, userName, avatar, dailyGoalMinutes,
      dailyZikirTarget, themeMode, soundVolume, hapticEnabled);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is UserProfile &&
          other.id == this.id &&
          other.userName == this.userName &&
          other.avatar == this.avatar &&
          other.dailyGoalMinutes == this.dailyGoalMinutes &&
          other.dailyZikirTarget == this.dailyZikirTarget &&
          other.themeMode == this.themeMode &&
          other.soundVolume == this.soundVolume &&
          other.hapticEnabled == this.hapticEnabled);
}

class UserProfilesCompanion extends UpdateCompanion<UserProfile> {
  final Value<int> id;
  final Value<String> userName;
  final Value<String> avatar;
  final Value<int> dailyGoalMinutes;
  final Value<int> dailyZikirTarget;
  final Value<String> themeMode;
  final Value<double> soundVolume;
  final Value<bool> hapticEnabled;
  const UserProfilesCompanion({
    this.id = const Value.absent(),
    this.userName = const Value.absent(),
    this.avatar = const Value.absent(),
    this.dailyGoalMinutes = const Value.absent(),
    this.dailyZikirTarget = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.soundVolume = const Value.absent(),
    this.hapticEnabled = const Value.absent(),
  });
  UserProfilesCompanion.insert({
    this.id = const Value.absent(),
    this.userName = const Value.absent(),
    this.avatar = const Value.absent(),
    this.dailyGoalMinutes = const Value.absent(),
    this.dailyZikirTarget = const Value.absent(),
    this.themeMode = const Value.absent(),
    this.soundVolume = const Value.absent(),
    this.hapticEnabled = const Value.absent(),
  });
  static Insertable<UserProfile> custom({
    Expression<int>? id,
    Expression<String>? userName,
    Expression<String>? avatar,
    Expression<int>? dailyGoalMinutes,
    Expression<int>? dailyZikirTarget,
    Expression<String>? themeMode,
    Expression<double>? soundVolume,
    Expression<bool>? hapticEnabled,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userName != null) 'user_name': userName,
      if (avatar != null) 'avatar': avatar,
      if (dailyGoalMinutes != null) 'daily_goal_minutes': dailyGoalMinutes,
      if (dailyZikirTarget != null) 'daily_zikir_target': dailyZikirTarget,
      if (themeMode != null) 'theme_mode': themeMode,
      if (soundVolume != null) 'sound_volume': soundVolume,
      if (hapticEnabled != null) 'haptic_enabled': hapticEnabled,
    });
  }

  UserProfilesCompanion copyWith(
      {Value<int>? id,
      Value<String>? userName,
      Value<String>? avatar,
      Value<int>? dailyGoalMinutes,
      Value<int>? dailyZikirTarget,
      Value<String>? themeMode,
      Value<double>? soundVolume,
      Value<bool>? hapticEnabled}) {
    return UserProfilesCompanion(
      id: id ?? this.id,
      userName: userName ?? this.userName,
      avatar: avatar ?? this.avatar,
      dailyGoalMinutes: dailyGoalMinutes ?? this.dailyGoalMinutes,
      dailyZikirTarget: dailyZikirTarget ?? this.dailyZikirTarget,
      themeMode: themeMode ?? this.themeMode,
      soundVolume: soundVolume ?? this.soundVolume,
      hapticEnabled: hapticEnabled ?? this.hapticEnabled,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (userName.present) {
      map['user_name'] = Variable<String>(userName.value);
    }
    if (avatar.present) {
      map['avatar'] = Variable<String>(avatar.value);
    }
    if (dailyGoalMinutes.present) {
      map['daily_goal_minutes'] = Variable<int>(dailyGoalMinutes.value);
    }
    if (dailyZikirTarget.present) {
      map['daily_zikir_target'] = Variable<int>(dailyZikirTarget.value);
    }
    if (themeMode.present) {
      map['theme_mode'] = Variable<String>(themeMode.value);
    }
    if (soundVolume.present) {
      map['sound_volume'] = Variable<double>(soundVolume.value);
    }
    if (hapticEnabled.present) {
      map['haptic_enabled'] = Variable<bool>(hapticEnabled.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('UserProfilesCompanion(')
          ..write('id: $id, ')
          ..write('userName: $userName, ')
          ..write('avatar: $avatar, ')
          ..write('dailyGoalMinutes: $dailyGoalMinutes, ')
          ..write('dailyZikirTarget: $dailyZikirTarget, ')
          ..write('themeMode: $themeMode, ')
          ..write('soundVolume: $soundVolume, ')
          ..write('hapticEnabled: $hapticEnabled')
          ..write(')'))
        .toString();
  }
}

class $MemorizationPlansTable extends MemorizationPlans
    with TableInfo<$MemorizationPlansTable, MemorizationPlan> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MemorizationPlansTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _pageIdMeta = const VerificationMeta('pageId');
  @override
  late final GeneratedColumn<int> pageId = GeneratedColumn<int>(
      'page_id', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _surahIdMeta =
      const VerificationMeta('surahId');
  @override
  late final GeneratedColumn<int> surahId = GeneratedColumn<int>(
      'surah_id', aliasedName, true,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _scheduledReviewDateMeta =
      const VerificationMeta('scheduledReviewDate');
  @override
  late final GeneratedColumn<DateTime> scheduledReviewDate =
      GeneratedColumn<DateTime>('scheduled_review_date', aliasedName, false,
          type: DriftSqlType.dateTime, requiredDuringInsert: true);
  static const VerificationMeta _lastReviewedDateMeta =
      const VerificationMeta('lastReviewedDate');
  @override
  late final GeneratedColumn<DateTime> lastReviewedDate =
      GeneratedColumn<DateTime>('last_reviewed_date', aliasedName, true,
          type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<int> state = GeneratedColumn<int>(
      'state', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _timesReviewedMeta =
      const VerificationMeta('timesReviewed');
  @override
  late final GeneratedColumn<int> timesReviewed = GeneratedColumn<int>(
      'times_reviewed', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _easeFactorMeta =
      const VerificationMeta('easeFactor');
  @override
  late final GeneratedColumn<double> easeFactor = GeneratedColumn<double>(
      'ease_factor', aliasedName, false,
      type: DriftSqlType.double,
      requiredDuringInsert: false,
      defaultValue: const Constant(2.5));
  static const VerificationMeta _intervalDaysMeta =
      const VerificationMeta('intervalDays');
  @override
  late final GeneratedColumn<int> intervalDays = GeneratedColumn<int>(
      'interval_days', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  @override
  List<GeneratedColumn> get $columns => [
        pageId,
        surahId,
        scheduledReviewDate,
        lastReviewedDate,
        state,
        timesReviewed,
        easeFactor,
        intervalDays
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'memorization_plans';
  @override
  VerificationContext validateIntegrity(Insertable<MemorizationPlan> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('page_id')) {
      context.handle(_pageIdMeta,
          pageId.isAcceptableOrUnknown(data['page_id']!, _pageIdMeta));
    }
    if (data.containsKey('surah_id')) {
      context.handle(_surahIdMeta,
          surahId.isAcceptableOrUnknown(data['surah_id']!, _surahIdMeta));
    }
    if (data.containsKey('scheduled_review_date')) {
      context.handle(
          _scheduledReviewDateMeta,
          scheduledReviewDate.isAcceptableOrUnknown(
              data['scheduled_review_date']!, _scheduledReviewDateMeta));
    } else if (isInserting) {
      context.missing(_scheduledReviewDateMeta);
    }
    if (data.containsKey('last_reviewed_date')) {
      context.handle(
          _lastReviewedDateMeta,
          lastReviewedDate.isAcceptableOrUnknown(
              data['last_reviewed_date']!, _lastReviewedDateMeta));
    }
    if (data.containsKey('state')) {
      context.handle(
          _stateMeta, state.isAcceptableOrUnknown(data['state']!, _stateMeta));
    }
    if (data.containsKey('times_reviewed')) {
      context.handle(
          _timesReviewedMeta,
          timesReviewed.isAcceptableOrUnknown(
              data['times_reviewed']!, _timesReviewedMeta));
    }
    if (data.containsKey('ease_factor')) {
      context.handle(
          _easeFactorMeta,
          easeFactor.isAcceptableOrUnknown(
              data['ease_factor']!, _easeFactorMeta));
    }
    if (data.containsKey('interval_days')) {
      context.handle(
          _intervalDaysMeta,
          intervalDays.isAcceptableOrUnknown(
              data['interval_days']!, _intervalDaysMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {pageId};
  @override
  MemorizationPlan map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MemorizationPlan(
      pageId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}page_id'])!,
      surahId: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}surah_id']),
      scheduledReviewDate: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime,
          data['${effectivePrefix}scheduled_review_date'])!,
      lastReviewedDate: attachedDatabase.typeMapping.read(
          DriftSqlType.dateTime, data['${effectivePrefix}last_reviewed_date']),
      state: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}state'])!,
      timesReviewed: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}times_reviewed'])!,
      easeFactor: attachedDatabase.typeMapping
          .read(DriftSqlType.double, data['${effectivePrefix}ease_factor'])!,
      intervalDays: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}interval_days'])!,
    );
  }

  @override
  $MemorizationPlansTable createAlias(String alias) {
    return $MemorizationPlansTable(attachedDatabase, alias);
  }
}

class MemorizationPlan extends DataClass
    implements Insertable<MemorizationPlan> {
  final int pageId;
  final int? surahId;
  final DateTime scheduledReviewDate;
  final DateTime? lastReviewedDate;
  final int state;
  final int timesReviewed;
  final double easeFactor;
  final int intervalDays;
  const MemorizationPlan(
      {required this.pageId,
      this.surahId,
      required this.scheduledReviewDate,
      this.lastReviewedDate,
      required this.state,
      required this.timesReviewed,
      required this.easeFactor,
      required this.intervalDays});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['page_id'] = Variable<int>(pageId);
    if (!nullToAbsent || surahId != null) {
      map['surah_id'] = Variable<int>(surahId);
    }
    map['scheduled_review_date'] = Variable<DateTime>(scheduledReviewDate);
    if (!nullToAbsent || lastReviewedDate != null) {
      map['last_reviewed_date'] = Variable<DateTime>(lastReviewedDate);
    }
    map['state'] = Variable<int>(state);
    map['times_reviewed'] = Variable<int>(timesReviewed);
    map['ease_factor'] = Variable<double>(easeFactor);
    map['interval_days'] = Variable<int>(intervalDays);
    return map;
  }

  MemorizationPlansCompanion toCompanion(bool nullToAbsent) {
    return MemorizationPlansCompanion(
      pageId: Value(pageId),
      surahId: surahId == null && nullToAbsent
          ? const Value.absent()
          : Value(surahId),
      scheduledReviewDate: Value(scheduledReviewDate),
      lastReviewedDate: lastReviewedDate == null && nullToAbsent
          ? const Value.absent()
          : Value(lastReviewedDate),
      state: Value(state),
      timesReviewed: Value(timesReviewed),
      easeFactor: Value(easeFactor),
      intervalDays: Value(intervalDays),
    );
  }

  factory MemorizationPlan.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MemorizationPlan(
      pageId: serializer.fromJson<int>(json['pageId']),
      surahId: serializer.fromJson<int?>(json['surahId']),
      scheduledReviewDate:
          serializer.fromJson<DateTime>(json['scheduledReviewDate']),
      lastReviewedDate:
          serializer.fromJson<DateTime?>(json['lastReviewedDate']),
      state: serializer.fromJson<int>(json['state']),
      timesReviewed: serializer.fromJson<int>(json['timesReviewed']),
      easeFactor: serializer.fromJson<double>(json['easeFactor']),
      intervalDays: serializer.fromJson<int>(json['intervalDays']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'pageId': serializer.toJson<int>(pageId),
      'surahId': serializer.toJson<int?>(surahId),
      'scheduledReviewDate': serializer.toJson<DateTime>(scheduledReviewDate),
      'lastReviewedDate': serializer.toJson<DateTime?>(lastReviewedDate),
      'state': serializer.toJson<int>(state),
      'timesReviewed': serializer.toJson<int>(timesReviewed),
      'easeFactor': serializer.toJson<double>(easeFactor),
      'intervalDays': serializer.toJson<int>(intervalDays),
    };
  }

  MemorizationPlan copyWith(
          {int? pageId,
          Value<int?> surahId = const Value.absent(),
          DateTime? scheduledReviewDate,
          Value<DateTime?> lastReviewedDate = const Value.absent(),
          int? state,
          int? timesReviewed,
          double? easeFactor,
          int? intervalDays}) =>
      MemorizationPlan(
        pageId: pageId ?? this.pageId,
        surahId: surahId.present ? surahId.value : this.surahId,
        scheduledReviewDate: scheduledReviewDate ?? this.scheduledReviewDate,
        lastReviewedDate: lastReviewedDate.present
            ? lastReviewedDate.value
            : this.lastReviewedDate,
        state: state ?? this.state,
        timesReviewed: timesReviewed ?? this.timesReviewed,
        easeFactor: easeFactor ?? this.easeFactor,
        intervalDays: intervalDays ?? this.intervalDays,
      );
  MemorizationPlan copyWithCompanion(MemorizationPlansCompanion data) {
    return MemorizationPlan(
      pageId: data.pageId.present ? data.pageId.value : this.pageId,
      surahId: data.surahId.present ? data.surahId.value : this.surahId,
      scheduledReviewDate: data.scheduledReviewDate.present
          ? data.scheduledReviewDate.value
          : this.scheduledReviewDate,
      lastReviewedDate: data.lastReviewedDate.present
          ? data.lastReviewedDate.value
          : this.lastReviewedDate,
      state: data.state.present ? data.state.value : this.state,
      timesReviewed: data.timesReviewed.present
          ? data.timesReviewed.value
          : this.timesReviewed,
      easeFactor:
          data.easeFactor.present ? data.easeFactor.value : this.easeFactor,
      intervalDays: data.intervalDays.present
          ? data.intervalDays.value
          : this.intervalDays,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MemorizationPlan(')
          ..write('pageId: $pageId, ')
          ..write('surahId: $surahId, ')
          ..write('scheduledReviewDate: $scheduledReviewDate, ')
          ..write('lastReviewedDate: $lastReviewedDate, ')
          ..write('state: $state, ')
          ..write('timesReviewed: $timesReviewed, ')
          ..write('easeFactor: $easeFactor, ')
          ..write('intervalDays: $intervalDays')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(pageId, surahId, scheduledReviewDate,
      lastReviewedDate, state, timesReviewed, easeFactor, intervalDays);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MemorizationPlan &&
          other.pageId == this.pageId &&
          other.surahId == this.surahId &&
          other.scheduledReviewDate == this.scheduledReviewDate &&
          other.lastReviewedDate == this.lastReviewedDate &&
          other.state == this.state &&
          other.timesReviewed == this.timesReviewed &&
          other.easeFactor == this.easeFactor &&
          other.intervalDays == this.intervalDays);
}

class MemorizationPlansCompanion extends UpdateCompanion<MemorizationPlan> {
  final Value<int> pageId;
  final Value<int?> surahId;
  final Value<DateTime> scheduledReviewDate;
  final Value<DateTime?> lastReviewedDate;
  final Value<int> state;
  final Value<int> timesReviewed;
  final Value<double> easeFactor;
  final Value<int> intervalDays;
  const MemorizationPlansCompanion({
    this.pageId = const Value.absent(),
    this.surahId = const Value.absent(),
    this.scheduledReviewDate = const Value.absent(),
    this.lastReviewedDate = const Value.absent(),
    this.state = const Value.absent(),
    this.timesReviewed = const Value.absent(),
    this.easeFactor = const Value.absent(),
    this.intervalDays = const Value.absent(),
  });
  MemorizationPlansCompanion.insert({
    this.pageId = const Value.absent(),
    this.surahId = const Value.absent(),
    required DateTime scheduledReviewDate,
    this.lastReviewedDate = const Value.absent(),
    this.state = const Value.absent(),
    this.timesReviewed = const Value.absent(),
    this.easeFactor = const Value.absent(),
    this.intervalDays = const Value.absent(),
  }) : scheduledReviewDate = Value(scheduledReviewDate);
  static Insertable<MemorizationPlan> custom({
    Expression<int>? pageId,
    Expression<int>? surahId,
    Expression<DateTime>? scheduledReviewDate,
    Expression<DateTime>? lastReviewedDate,
    Expression<int>? state,
    Expression<int>? timesReviewed,
    Expression<double>? easeFactor,
    Expression<int>? intervalDays,
  }) {
    return RawValuesInsertable({
      if (pageId != null) 'page_id': pageId,
      if (surahId != null) 'surah_id': surahId,
      if (scheduledReviewDate != null)
        'scheduled_review_date': scheduledReviewDate,
      if (lastReviewedDate != null) 'last_reviewed_date': lastReviewedDate,
      if (state != null) 'state': state,
      if (timesReviewed != null) 'times_reviewed': timesReviewed,
      if (easeFactor != null) 'ease_factor': easeFactor,
      if (intervalDays != null) 'interval_days': intervalDays,
    });
  }

  MemorizationPlansCompanion copyWith(
      {Value<int>? pageId,
      Value<int?>? surahId,
      Value<DateTime>? scheduledReviewDate,
      Value<DateTime?>? lastReviewedDate,
      Value<int>? state,
      Value<int>? timesReviewed,
      Value<double>? easeFactor,
      Value<int>? intervalDays}) {
    return MemorizationPlansCompanion(
      pageId: pageId ?? this.pageId,
      surahId: surahId ?? this.surahId,
      scheduledReviewDate: scheduledReviewDate ?? this.scheduledReviewDate,
      lastReviewedDate: lastReviewedDate ?? this.lastReviewedDate,
      state: state ?? this.state,
      timesReviewed: timesReviewed ?? this.timesReviewed,
      easeFactor: easeFactor ?? this.easeFactor,
      intervalDays: intervalDays ?? this.intervalDays,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (pageId.present) {
      map['page_id'] = Variable<int>(pageId.value);
    }
    if (surahId.present) {
      map['surah_id'] = Variable<int>(surahId.value);
    }
    if (scheduledReviewDate.present) {
      map['scheduled_review_date'] =
          Variable<DateTime>(scheduledReviewDate.value);
    }
    if (lastReviewedDate.present) {
      map['last_reviewed_date'] = Variable<DateTime>(lastReviewedDate.value);
    }
    if (state.present) {
      map['state'] = Variable<int>(state.value);
    }
    if (timesReviewed.present) {
      map['times_reviewed'] = Variable<int>(timesReviewed.value);
    }
    if (easeFactor.present) {
      map['ease_factor'] = Variable<double>(easeFactor.value);
    }
    if (intervalDays.present) {
      map['interval_days'] = Variable<int>(intervalDays.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MemorizationPlansCompanion(')
          ..write('pageId: $pageId, ')
          ..write('surahId: $surahId, ')
          ..write('scheduledReviewDate: $scheduledReviewDate, ')
          ..write('lastReviewedDate: $lastReviewedDate, ')
          ..write('state: $state, ')
          ..write('timesReviewed: $timesReviewed, ')
          ..write('easeFactor: $easeFactor, ')
          ..write('intervalDays: $intervalDays')
          ..write(')'))
        .toString();
  }
}

class $HafizlikDailyLogsTable extends HafizlikDailyLogs
    with TableInfo<$HafizlikDailyLogsTable, HafizlikDailyLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HafizlikDailyLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _dateStrMeta =
      const VerificationMeta('dateStr');
  @override
  late final GeneratedColumn<String> dateStr = GeneratedColumn<String>(
      'date_str', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isHamDoneMeta =
      const VerificationMeta('isHamDone');
  @override
  late final GeneratedColumn<bool> isHamDone = GeneratedColumn<bool>(
      'is_ham_done', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_ham_done" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isPismisDoneMeta =
      const VerificationMeta('isPismisDone');
  @override
  late final GeneratedColumn<bool> isPismisDone = GeneratedColumn<bool>(
      'is_pismis_done', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_pismis_done" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isHasDoneMeta =
      const VerificationMeta('isHasDone');
  @override
  late final GeneratedColumn<bool> isHasDone = GeneratedColumn<bool>(
      'is_has_done', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_has_done" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _streakShieldsUsedMeta =
      const VerificationMeta('streakShieldsUsed');
  @override
  late final GeneratedColumn<int> streakShieldsUsed = GeneratedColumn<int>(
      'streak_shields_used', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _isAsgariVirdDoneMeta =
      const VerificationMeta('isAsgariVirdDone');
  @override
  late final GeneratedColumn<bool> isAsgariVirdDone = GeneratedColumn<bool>(
      'is_asgari_vird_done', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_asgari_vird_done" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _asgariVirdRepeatsMeta =
      const VerificationMeta('asgariVirdRepeats');
  @override
  late final GeneratedColumn<int> asgariVirdRepeats = GeneratedColumn<int>(
      'asgari_vird_repeats', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns => [
        dateStr,
        isHamDone,
        isPismisDone,
        isHasDone,
        streakShieldsUsed,
        isAsgariVirdDone,
        asgariVirdRepeats
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'hafizlik_daily_logs';
  @override
  VerificationContext validateIntegrity(Insertable<HafizlikDailyLog> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('date_str')) {
      context.handle(_dateStrMeta,
          dateStr.isAcceptableOrUnknown(data['date_str']!, _dateStrMeta));
    } else if (isInserting) {
      context.missing(_dateStrMeta);
    }
    if (data.containsKey('is_ham_done')) {
      context.handle(
          _isHamDoneMeta,
          isHamDone.isAcceptableOrUnknown(
              data['is_ham_done']!, _isHamDoneMeta));
    }
    if (data.containsKey('is_pismis_done')) {
      context.handle(
          _isPismisDoneMeta,
          isPismisDone.isAcceptableOrUnknown(
              data['is_pismis_done']!, _isPismisDoneMeta));
    }
    if (data.containsKey('is_has_done')) {
      context.handle(
          _isHasDoneMeta,
          isHasDone.isAcceptableOrUnknown(
              data['is_has_done']!, _isHasDoneMeta));
    }
    if (data.containsKey('streak_shields_used')) {
      context.handle(
          _streakShieldsUsedMeta,
          streakShieldsUsed.isAcceptableOrUnknown(
              data['streak_shields_used']!, _streakShieldsUsedMeta));
    }
    if (data.containsKey('is_asgari_vird_done')) {
      context.handle(
          _isAsgariVirdDoneMeta,
          isAsgariVirdDone.isAcceptableOrUnknown(
              data['is_asgari_vird_done']!, _isAsgariVirdDoneMeta));
    }
    if (data.containsKey('asgari_vird_repeats')) {
      context.handle(
          _asgariVirdRepeatsMeta,
          asgariVirdRepeats.isAcceptableOrUnknown(
              data['asgari_vird_repeats']!, _asgariVirdRepeatsMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {dateStr};
  @override
  HafizlikDailyLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HafizlikDailyLog(
      dateStr: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}date_str'])!,
      isHamDone: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_ham_done'])!,
      isPismisDone: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_pismis_done'])!,
      isHasDone: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_has_done'])!,
      streakShieldsUsed: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}streak_shields_used'])!,
      isAsgariVirdDone: attachedDatabase.typeMapping.read(
          DriftSqlType.bool, data['${effectivePrefix}is_asgari_vird_done'])!,
      asgariVirdRepeats: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}asgari_vird_repeats'])!,
    );
  }

  @override
  $HafizlikDailyLogsTable createAlias(String alias) {
    return $HafizlikDailyLogsTable(attachedDatabase, alias);
  }
}

class HafizlikDailyLog extends DataClass
    implements Insertable<HafizlikDailyLog> {
  final String dateStr;
  final bool isHamDone;
  final bool isPismisDone;
  final bool isHasDone;
  final int streakShieldsUsed;
  final bool isAsgariVirdDone;
  final int asgariVirdRepeats;
  const HafizlikDailyLog(
      {required this.dateStr,
      required this.isHamDone,
      required this.isPismisDone,
      required this.isHasDone,
      required this.streakShieldsUsed,
      required this.isAsgariVirdDone,
      required this.asgariVirdRepeats});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['date_str'] = Variable<String>(dateStr);
    map['is_ham_done'] = Variable<bool>(isHamDone);
    map['is_pismis_done'] = Variable<bool>(isPismisDone);
    map['is_has_done'] = Variable<bool>(isHasDone);
    map['streak_shields_used'] = Variable<int>(streakShieldsUsed);
    map['is_asgari_vird_done'] = Variable<bool>(isAsgariVirdDone);
    map['asgari_vird_repeats'] = Variable<int>(asgariVirdRepeats);
    return map;
  }

  HafizlikDailyLogsCompanion toCompanion(bool nullToAbsent) {
    return HafizlikDailyLogsCompanion(
      dateStr: Value(dateStr),
      isHamDone: Value(isHamDone),
      isPismisDone: Value(isPismisDone),
      isHasDone: Value(isHasDone),
      streakShieldsUsed: Value(streakShieldsUsed),
      isAsgariVirdDone: Value(isAsgariVirdDone),
      asgariVirdRepeats: Value(asgariVirdRepeats),
    );
  }

  factory HafizlikDailyLog.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HafizlikDailyLog(
      dateStr: serializer.fromJson<String>(json['dateStr']),
      isHamDone: serializer.fromJson<bool>(json['isHamDone']),
      isPismisDone: serializer.fromJson<bool>(json['isPismisDone']),
      isHasDone: serializer.fromJson<bool>(json['isHasDone']),
      streakShieldsUsed: serializer.fromJson<int>(json['streakShieldsUsed']),
      isAsgariVirdDone: serializer.fromJson<bool>(json['isAsgariVirdDone']),
      asgariVirdRepeats: serializer.fromJson<int>(json['asgariVirdRepeats']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'dateStr': serializer.toJson<String>(dateStr),
      'isHamDone': serializer.toJson<bool>(isHamDone),
      'isPismisDone': serializer.toJson<bool>(isPismisDone),
      'isHasDone': serializer.toJson<bool>(isHasDone),
      'streakShieldsUsed': serializer.toJson<int>(streakShieldsUsed),
      'isAsgariVirdDone': serializer.toJson<bool>(isAsgariVirdDone),
      'asgariVirdRepeats': serializer.toJson<int>(asgariVirdRepeats),
    };
  }

  HafizlikDailyLog copyWith(
          {String? dateStr,
          bool? isHamDone,
          bool? isPismisDone,
          bool? isHasDone,
          int? streakShieldsUsed,
          bool? isAsgariVirdDone,
          int? asgariVirdRepeats}) =>
      HafizlikDailyLog(
        dateStr: dateStr ?? this.dateStr,
        isHamDone: isHamDone ?? this.isHamDone,
        isPismisDone: isPismisDone ?? this.isPismisDone,
        isHasDone: isHasDone ?? this.isHasDone,
        streakShieldsUsed: streakShieldsUsed ?? this.streakShieldsUsed,
        isAsgariVirdDone: isAsgariVirdDone ?? this.isAsgariVirdDone,
        asgariVirdRepeats: asgariVirdRepeats ?? this.asgariVirdRepeats,
      );
  HafizlikDailyLog copyWithCompanion(HafizlikDailyLogsCompanion data) {
    return HafizlikDailyLog(
      dateStr: data.dateStr.present ? data.dateStr.value : this.dateStr,
      isHamDone: data.isHamDone.present ? data.isHamDone.value : this.isHamDone,
      isPismisDone: data.isPismisDone.present
          ? data.isPismisDone.value
          : this.isPismisDone,
      isHasDone: data.isHasDone.present ? data.isHasDone.value : this.isHasDone,
      streakShieldsUsed: data.streakShieldsUsed.present
          ? data.streakShieldsUsed.value
          : this.streakShieldsUsed,
      isAsgariVirdDone: data.isAsgariVirdDone.present
          ? data.isAsgariVirdDone.value
          : this.isAsgariVirdDone,
      asgariVirdRepeats: data.asgariVirdRepeats.present
          ? data.asgariVirdRepeats.value
          : this.asgariVirdRepeats,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HafizlikDailyLog(')
          ..write('dateStr: $dateStr, ')
          ..write('isHamDone: $isHamDone, ')
          ..write('isPismisDone: $isPismisDone, ')
          ..write('isHasDone: $isHasDone, ')
          ..write('streakShieldsUsed: $streakShieldsUsed, ')
          ..write('isAsgariVirdDone: $isAsgariVirdDone, ')
          ..write('asgariVirdRepeats: $asgariVirdRepeats')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(dateStr, isHamDone, isPismisDone, isHasDone,
      streakShieldsUsed, isAsgariVirdDone, asgariVirdRepeats);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HafizlikDailyLog &&
          other.dateStr == this.dateStr &&
          other.isHamDone == this.isHamDone &&
          other.isPismisDone == this.isPismisDone &&
          other.isHasDone == this.isHasDone &&
          other.streakShieldsUsed == this.streakShieldsUsed &&
          other.isAsgariVirdDone == this.isAsgariVirdDone &&
          other.asgariVirdRepeats == this.asgariVirdRepeats);
}

class HafizlikDailyLogsCompanion extends UpdateCompanion<HafizlikDailyLog> {
  final Value<String> dateStr;
  final Value<bool> isHamDone;
  final Value<bool> isPismisDone;
  final Value<bool> isHasDone;
  final Value<int> streakShieldsUsed;
  final Value<bool> isAsgariVirdDone;
  final Value<int> asgariVirdRepeats;
  final Value<int> rowid;
  const HafizlikDailyLogsCompanion({
    this.dateStr = const Value.absent(),
    this.isHamDone = const Value.absent(),
    this.isPismisDone = const Value.absent(),
    this.isHasDone = const Value.absent(),
    this.streakShieldsUsed = const Value.absent(),
    this.isAsgariVirdDone = const Value.absent(),
    this.asgariVirdRepeats = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HafizlikDailyLogsCompanion.insert({
    required String dateStr,
    this.isHamDone = const Value.absent(),
    this.isPismisDone = const Value.absent(),
    this.isHasDone = const Value.absent(),
    this.streakShieldsUsed = const Value.absent(),
    this.isAsgariVirdDone = const Value.absent(),
    this.asgariVirdRepeats = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : dateStr = Value(dateStr);
  static Insertable<HafizlikDailyLog> custom({
    Expression<String>? dateStr,
    Expression<bool>? isHamDone,
    Expression<bool>? isPismisDone,
    Expression<bool>? isHasDone,
    Expression<int>? streakShieldsUsed,
    Expression<bool>? isAsgariVirdDone,
    Expression<int>? asgariVirdRepeats,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (dateStr != null) 'date_str': dateStr,
      if (isHamDone != null) 'is_ham_done': isHamDone,
      if (isPismisDone != null) 'is_pismis_done': isPismisDone,
      if (isHasDone != null) 'is_has_done': isHasDone,
      if (streakShieldsUsed != null) 'streak_shields_used': streakShieldsUsed,
      if (isAsgariVirdDone != null) 'is_asgari_vird_done': isAsgariVirdDone,
      if (asgariVirdRepeats != null) 'asgari_vird_repeats': asgariVirdRepeats,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HafizlikDailyLogsCompanion copyWith(
      {Value<String>? dateStr,
      Value<bool>? isHamDone,
      Value<bool>? isPismisDone,
      Value<bool>? isHasDone,
      Value<int>? streakShieldsUsed,
      Value<bool>? isAsgariVirdDone,
      Value<int>? asgariVirdRepeats,
      Value<int>? rowid}) {
    return HafizlikDailyLogsCompanion(
      dateStr: dateStr ?? this.dateStr,
      isHamDone: isHamDone ?? this.isHamDone,
      isPismisDone: isPismisDone ?? this.isPismisDone,
      isHasDone: isHasDone ?? this.isHasDone,
      streakShieldsUsed: streakShieldsUsed ?? this.streakShieldsUsed,
      isAsgariVirdDone: isAsgariVirdDone ?? this.isAsgariVirdDone,
      asgariVirdRepeats: asgariVirdRepeats ?? this.asgariVirdRepeats,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (dateStr.present) {
      map['date_str'] = Variable<String>(dateStr.value);
    }
    if (isHamDone.present) {
      map['is_ham_done'] = Variable<bool>(isHamDone.value);
    }
    if (isPismisDone.present) {
      map['is_pismis_done'] = Variable<bool>(isPismisDone.value);
    }
    if (isHasDone.present) {
      map['is_has_done'] = Variable<bool>(isHasDone.value);
    }
    if (streakShieldsUsed.present) {
      map['streak_shields_used'] = Variable<int>(streakShieldsUsed.value);
    }
    if (isAsgariVirdDone.present) {
      map['is_asgari_vird_done'] = Variable<bool>(isAsgariVirdDone.value);
    }
    if (asgariVirdRepeats.present) {
      map['asgari_vird_repeats'] = Variable<int>(asgariVirdRepeats.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HafizlikDailyLogsCompanion(')
          ..write('dateStr: $dateStr, ')
          ..write('isHamDone: $isHamDone, ')
          ..write('isPismisDone: $isPismisDone, ')
          ..write('isHasDone: $isHasDone, ')
          ..write('streakShieldsUsed: $streakShieldsUsed, ')
          ..write('isAsgariVirdDone: $isAsgariVirdDone, ')
          ..write('asgariVirdRepeats: $asgariVirdRepeats, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $KazaPrayersTable extends KazaPrayers
    with TableInfo<$KazaPrayersTable, KazaPrayer> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KazaPrayersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _prayerTypeMeta =
      const VerificationMeta('prayerType');
  @override
  late final GeneratedColumn<String> prayerType = GeneratedColumn<String>(
      'prayer_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _totalCountMeta =
      const VerificationMeta('totalCount');
  @override
  late final GeneratedColumn<int> totalCount = GeneratedColumn<int>(
      'total_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _completedCountMeta =
      const VerificationMeta('completedCount');
  @override
  late final GeneratedColumn<int> completedCount = GeneratedColumn<int>(
      'completed_count', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  @override
  List<GeneratedColumn> get $columns =>
      [id, prayerType, totalCount, completedCount];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kaza_prayers';
  @override
  VerificationContext validateIntegrity(Insertable<KazaPrayer> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('prayer_type')) {
      context.handle(
          _prayerTypeMeta,
          prayerType.isAcceptableOrUnknown(
              data['prayer_type']!, _prayerTypeMeta));
    } else if (isInserting) {
      context.missing(_prayerTypeMeta);
    }
    if (data.containsKey('total_count')) {
      context.handle(
          _totalCountMeta,
          totalCount.isAcceptableOrUnknown(
              data['total_count']!, _totalCountMeta));
    }
    if (data.containsKey('completed_count')) {
      context.handle(
          _completedCountMeta,
          completedCount.isAcceptableOrUnknown(
              data['completed_count']!, _completedCountMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  KazaPrayer map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KazaPrayer(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      prayerType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}prayer_type'])!,
      totalCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_count'])!,
      completedCount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}completed_count'])!,
    );
  }

  @override
  $KazaPrayersTable createAlias(String alias) {
    return $KazaPrayersTable(attachedDatabase, alias);
  }
}

class KazaPrayer extends DataClass implements Insertable<KazaPrayer> {
  final int id;
  final String prayerType;
  final int totalCount;
  final int completedCount;
  const KazaPrayer(
      {required this.id,
      required this.prayerType,
      required this.totalCount,
      required this.completedCount});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['prayer_type'] = Variable<String>(prayerType);
    map['total_count'] = Variable<int>(totalCount);
    map['completed_count'] = Variable<int>(completedCount);
    return map;
  }

  KazaPrayersCompanion toCompanion(bool nullToAbsent) {
    return KazaPrayersCompanion(
      id: Value(id),
      prayerType: Value(prayerType),
      totalCount: Value(totalCount),
      completedCount: Value(completedCount),
    );
  }

  factory KazaPrayer.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KazaPrayer(
      id: serializer.fromJson<int>(json['id']),
      prayerType: serializer.fromJson<String>(json['prayerType']),
      totalCount: serializer.fromJson<int>(json['totalCount']),
      completedCount: serializer.fromJson<int>(json['completedCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'prayerType': serializer.toJson<String>(prayerType),
      'totalCount': serializer.toJson<int>(totalCount),
      'completedCount': serializer.toJson<int>(completedCount),
    };
  }

  KazaPrayer copyWith(
          {int? id,
          String? prayerType,
          int? totalCount,
          int? completedCount}) =>
      KazaPrayer(
        id: id ?? this.id,
        prayerType: prayerType ?? this.prayerType,
        totalCount: totalCount ?? this.totalCount,
        completedCount: completedCount ?? this.completedCount,
      );
  KazaPrayer copyWithCompanion(KazaPrayersCompanion data) {
    return KazaPrayer(
      id: data.id.present ? data.id.value : this.id,
      prayerType:
          data.prayerType.present ? data.prayerType.value : this.prayerType,
      totalCount:
          data.totalCount.present ? data.totalCount.value : this.totalCount,
      completedCount: data.completedCount.present
          ? data.completedCount.value
          : this.completedCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KazaPrayer(')
          ..write('id: $id, ')
          ..write('prayerType: $prayerType, ')
          ..write('totalCount: $totalCount, ')
          ..write('completedCount: $completedCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, prayerType, totalCount, completedCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KazaPrayer &&
          other.id == this.id &&
          other.prayerType == this.prayerType &&
          other.totalCount == this.totalCount &&
          other.completedCount == this.completedCount);
}

class KazaPrayersCompanion extends UpdateCompanion<KazaPrayer> {
  final Value<int> id;
  final Value<String> prayerType;
  final Value<int> totalCount;
  final Value<int> completedCount;
  const KazaPrayersCompanion({
    this.id = const Value.absent(),
    this.prayerType = const Value.absent(),
    this.totalCount = const Value.absent(),
    this.completedCount = const Value.absent(),
  });
  KazaPrayersCompanion.insert({
    this.id = const Value.absent(),
    required String prayerType,
    this.totalCount = const Value.absent(),
    this.completedCount = const Value.absent(),
  }) : prayerType = Value(prayerType);
  static Insertable<KazaPrayer> custom({
    Expression<int>? id,
    Expression<String>? prayerType,
    Expression<int>? totalCount,
    Expression<int>? completedCount,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (prayerType != null) 'prayer_type': prayerType,
      if (totalCount != null) 'total_count': totalCount,
      if (completedCount != null) 'completed_count': completedCount,
    });
  }

  KazaPrayersCompanion copyWith(
      {Value<int>? id,
      Value<String>? prayerType,
      Value<int>? totalCount,
      Value<int>? completedCount}) {
    return KazaPrayersCompanion(
      id: id ?? this.id,
      prayerType: prayerType ?? this.prayerType,
      totalCount: totalCount ?? this.totalCount,
      completedCount: completedCount ?? this.completedCount,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (prayerType.present) {
      map['prayer_type'] = Variable<String>(prayerType.value);
    }
    if (totalCount.present) {
      map['total_count'] = Variable<int>(totalCount.value);
    }
    if (completedCount.present) {
      map['completed_count'] = Variable<int>(completedCount.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KazaPrayersCompanion(')
          ..write('id: $id, ')
          ..write('prayerType: $prayerType, ')
          ..write('totalCount: $totalCount, ')
          ..write('completedCount: $completedCount')
          ..write(')'))
        .toString();
  }
}

class $PrayerAnswerLogsTable extends PrayerAnswerLogs
    with TableInfo<$PrayerAnswerLogsTable, PrayerAnswerLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PrayerAnswerLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _prayerTypeMeta =
      const VerificationMeta('prayerType');
  @override
  late final GeneratedColumn<String> prayerType = GeneratedColumn<String>(
      'prayer_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _dateStrMeta =
      const VerificationMeta('dateStr');
  @override
  late final GeneratedColumn<String> dateStr = GeneratedColumn<String>(
      'date_str', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _isPerformedMeta =
      const VerificationMeta('isPerformed');
  @override
  late final GeneratedColumn<bool> isPerformed = GeneratedColumn<bool>(
      'is_performed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: true,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_performed" IN (0, 1))'));
  @override
  List<GeneratedColumn> get $columns => [id, prayerType, dateStr, isPerformed];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'prayer_answer_logs';
  @override
  VerificationContext validateIntegrity(Insertable<PrayerAnswerLog> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('prayer_type')) {
      context.handle(
          _prayerTypeMeta,
          prayerType.isAcceptableOrUnknown(
              data['prayer_type']!, _prayerTypeMeta));
    } else if (isInserting) {
      context.missing(_prayerTypeMeta);
    }
    if (data.containsKey('date_str')) {
      context.handle(_dateStrMeta,
          dateStr.isAcceptableOrUnknown(data['date_str']!, _dateStrMeta));
    } else if (isInserting) {
      context.missing(_dateStrMeta);
    }
    if (data.containsKey('is_performed')) {
      context.handle(
          _isPerformedMeta,
          isPerformed.isAcceptableOrUnknown(
              data['is_performed']!, _isPerformedMeta));
    } else if (isInserting) {
      context.missing(_isPerformedMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PrayerAnswerLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PrayerAnswerLog(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      prayerType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}prayer_type'])!,
      dateStr: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}date_str'])!,
      isPerformed: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_performed'])!,
    );
  }

  @override
  $PrayerAnswerLogsTable createAlias(String alias) {
    return $PrayerAnswerLogsTable(attachedDatabase, alias);
  }
}

class PrayerAnswerLog extends DataClass implements Insertable<PrayerAnswerLog> {
  final int id;
  final String prayerType;
  final String dateStr;
  final bool isPerformed;
  const PrayerAnswerLog(
      {required this.id,
      required this.prayerType,
      required this.dateStr,
      required this.isPerformed});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['prayer_type'] = Variable<String>(prayerType);
    map['date_str'] = Variable<String>(dateStr);
    map['is_performed'] = Variable<bool>(isPerformed);
    return map;
  }

  PrayerAnswerLogsCompanion toCompanion(bool nullToAbsent) {
    return PrayerAnswerLogsCompanion(
      id: Value(id),
      prayerType: Value(prayerType),
      dateStr: Value(dateStr),
      isPerformed: Value(isPerformed),
    );
  }

  factory PrayerAnswerLog.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PrayerAnswerLog(
      id: serializer.fromJson<int>(json['id']),
      prayerType: serializer.fromJson<String>(json['prayerType']),
      dateStr: serializer.fromJson<String>(json['dateStr']),
      isPerformed: serializer.fromJson<bool>(json['isPerformed']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'prayerType': serializer.toJson<String>(prayerType),
      'dateStr': serializer.toJson<String>(dateStr),
      'isPerformed': serializer.toJson<bool>(isPerformed),
    };
  }

  PrayerAnswerLog copyWith(
          {int? id, String? prayerType, String? dateStr, bool? isPerformed}) =>
      PrayerAnswerLog(
        id: id ?? this.id,
        prayerType: prayerType ?? this.prayerType,
        dateStr: dateStr ?? this.dateStr,
        isPerformed: isPerformed ?? this.isPerformed,
      );
  PrayerAnswerLog copyWithCompanion(PrayerAnswerLogsCompanion data) {
    return PrayerAnswerLog(
      id: data.id.present ? data.id.value : this.id,
      prayerType:
          data.prayerType.present ? data.prayerType.value : this.prayerType,
      dateStr: data.dateStr.present ? data.dateStr.value : this.dateStr,
      isPerformed:
          data.isPerformed.present ? data.isPerformed.value : this.isPerformed,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PrayerAnswerLog(')
          ..write('id: $id, ')
          ..write('prayerType: $prayerType, ')
          ..write('dateStr: $dateStr, ')
          ..write('isPerformed: $isPerformed')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, prayerType, dateStr, isPerformed);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PrayerAnswerLog &&
          other.id == this.id &&
          other.prayerType == this.prayerType &&
          other.dateStr == this.dateStr &&
          other.isPerformed == this.isPerformed);
}

class PrayerAnswerLogsCompanion extends UpdateCompanion<PrayerAnswerLog> {
  final Value<int> id;
  final Value<String> prayerType;
  final Value<String> dateStr;
  final Value<bool> isPerformed;
  const PrayerAnswerLogsCompanion({
    this.id = const Value.absent(),
    this.prayerType = const Value.absent(),
    this.dateStr = const Value.absent(),
    this.isPerformed = const Value.absent(),
  });
  PrayerAnswerLogsCompanion.insert({
    this.id = const Value.absent(),
    required String prayerType,
    required String dateStr,
    required bool isPerformed,
  })  : prayerType = Value(prayerType),
        dateStr = Value(dateStr),
        isPerformed = Value(isPerformed);
  static Insertable<PrayerAnswerLog> custom({
    Expression<int>? id,
    Expression<String>? prayerType,
    Expression<String>? dateStr,
    Expression<bool>? isPerformed,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (prayerType != null) 'prayer_type': prayerType,
      if (dateStr != null) 'date_str': dateStr,
      if (isPerformed != null) 'is_performed': isPerformed,
    });
  }

  PrayerAnswerLogsCompanion copyWith(
      {Value<int>? id,
      Value<String>? prayerType,
      Value<String>? dateStr,
      Value<bool>? isPerformed}) {
    return PrayerAnswerLogsCompanion(
      id: id ?? this.id,
      prayerType: prayerType ?? this.prayerType,
      dateStr: dateStr ?? this.dateStr,
      isPerformed: isPerformed ?? this.isPerformed,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (prayerType.present) {
      map['prayer_type'] = Variable<String>(prayerType.value);
    }
    if (dateStr.present) {
      map['date_str'] = Variable<String>(dateStr.value);
    }
    if (isPerformed.present) {
      map['is_performed'] = Variable<bool>(isPerformed.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PrayerAnswerLogsCompanion(')
          ..write('id: $id, ')
          ..write('prayerType: $prayerType, ')
          ..write('dateStr: $dateStr, ')
          ..write('isPerformed: $isPerformed')
          ..write(')'))
        .toString();
  }
}

class $KazaMeltLogsTable extends KazaMeltLogs
    with TableInfo<$KazaMeltLogsTable, KazaMeltLog> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $KazaMeltLogsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _prayerTypeMeta =
      const VerificationMeta('prayerType');
  @override
  late final GeneratedColumn<String> prayerType = GeneratedColumn<String>(
      'prayer_type', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _meltAmountMeta =
      const VerificationMeta('meltAmount');
  @override
  late final GeneratedColumn<int> meltAmount = GeneratedColumn<int>(
      'melt_amount', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _timestampMeta =
      const VerificationMeta('timestamp');
  @override
  late final GeneratedColumn<DateTime> timestamp = GeneratedColumn<DateTime>(
      'timestamp', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [id, prayerType, meltAmount, timestamp];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'kaza_melt_logs';
  @override
  VerificationContext validateIntegrity(Insertable<KazaMeltLog> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('prayer_type')) {
      context.handle(
          _prayerTypeMeta,
          prayerType.isAcceptableOrUnknown(
              data['prayer_type']!, _prayerTypeMeta));
    } else if (isInserting) {
      context.missing(_prayerTypeMeta);
    }
    if (data.containsKey('melt_amount')) {
      context.handle(
          _meltAmountMeta,
          meltAmount.isAcceptableOrUnknown(
              data['melt_amount']!, _meltAmountMeta));
    } else if (isInserting) {
      context.missing(_meltAmountMeta);
    }
    if (data.containsKey('timestamp')) {
      context.handle(_timestampMeta,
          timestamp.isAcceptableOrUnknown(data['timestamp']!, _timestampMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  KazaMeltLog map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return KazaMeltLog(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      prayerType: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}prayer_type'])!,
      meltAmount: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}melt_amount'])!,
      timestamp: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}timestamp'])!,
    );
  }

  @override
  $KazaMeltLogsTable createAlias(String alias) {
    return $KazaMeltLogsTable(attachedDatabase, alias);
  }
}

class KazaMeltLog extends DataClass implements Insertable<KazaMeltLog> {
  final int id;
  final String prayerType;
  final int meltAmount;
  final DateTime timestamp;
  const KazaMeltLog(
      {required this.id,
      required this.prayerType,
      required this.meltAmount,
      required this.timestamp});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['prayer_type'] = Variable<String>(prayerType);
    map['melt_amount'] = Variable<int>(meltAmount);
    map['timestamp'] = Variable<DateTime>(timestamp);
    return map;
  }

  KazaMeltLogsCompanion toCompanion(bool nullToAbsent) {
    return KazaMeltLogsCompanion(
      id: Value(id),
      prayerType: Value(prayerType),
      meltAmount: Value(meltAmount),
      timestamp: Value(timestamp),
    );
  }

  factory KazaMeltLog.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return KazaMeltLog(
      id: serializer.fromJson<int>(json['id']),
      prayerType: serializer.fromJson<String>(json['prayerType']),
      meltAmount: serializer.fromJson<int>(json['meltAmount']),
      timestamp: serializer.fromJson<DateTime>(json['timestamp']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'prayerType': serializer.toJson<String>(prayerType),
      'meltAmount': serializer.toJson<int>(meltAmount),
      'timestamp': serializer.toJson<DateTime>(timestamp),
    };
  }

  KazaMeltLog copyWith(
          {int? id,
          String? prayerType,
          int? meltAmount,
          DateTime? timestamp}) =>
      KazaMeltLog(
        id: id ?? this.id,
        prayerType: prayerType ?? this.prayerType,
        meltAmount: meltAmount ?? this.meltAmount,
        timestamp: timestamp ?? this.timestamp,
      );
  KazaMeltLog copyWithCompanion(KazaMeltLogsCompanion data) {
    return KazaMeltLog(
      id: data.id.present ? data.id.value : this.id,
      prayerType:
          data.prayerType.present ? data.prayerType.value : this.prayerType,
      meltAmount:
          data.meltAmount.present ? data.meltAmount.value : this.meltAmount,
      timestamp: data.timestamp.present ? data.timestamp.value : this.timestamp,
    );
  }

  @override
  String toString() {
    return (StringBuffer('KazaMeltLog(')
          ..write('id: $id, ')
          ..write('prayerType: $prayerType, ')
          ..write('meltAmount: $meltAmount, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, prayerType, meltAmount, timestamp);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is KazaMeltLog &&
          other.id == this.id &&
          other.prayerType == this.prayerType &&
          other.meltAmount == this.meltAmount &&
          other.timestamp == this.timestamp);
}

class KazaMeltLogsCompanion extends UpdateCompanion<KazaMeltLog> {
  final Value<int> id;
  final Value<String> prayerType;
  final Value<int> meltAmount;
  final Value<DateTime> timestamp;
  const KazaMeltLogsCompanion({
    this.id = const Value.absent(),
    this.prayerType = const Value.absent(),
    this.meltAmount = const Value.absent(),
    this.timestamp = const Value.absent(),
  });
  KazaMeltLogsCompanion.insert({
    this.id = const Value.absent(),
    required String prayerType,
    required int meltAmount,
    this.timestamp = const Value.absent(),
  })  : prayerType = Value(prayerType),
        meltAmount = Value(meltAmount);
  static Insertable<KazaMeltLog> custom({
    Expression<int>? id,
    Expression<String>? prayerType,
    Expression<int>? meltAmount,
    Expression<DateTime>? timestamp,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (prayerType != null) 'prayer_type': prayerType,
      if (meltAmount != null) 'melt_amount': meltAmount,
      if (timestamp != null) 'timestamp': timestamp,
    });
  }

  KazaMeltLogsCompanion copyWith(
      {Value<int>? id,
      Value<String>? prayerType,
      Value<int>? meltAmount,
      Value<DateTime>? timestamp}) {
    return KazaMeltLogsCompanion(
      id: id ?? this.id,
      prayerType: prayerType ?? this.prayerType,
      meltAmount: meltAmount ?? this.meltAmount,
      timestamp: timestamp ?? this.timestamp,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (prayerType.present) {
      map['prayer_type'] = Variable<String>(prayerType.value);
    }
    if (meltAmount.present) {
      map['melt_amount'] = Variable<int>(meltAmount.value);
    }
    if (timestamp.present) {
      map['timestamp'] = Variable<DateTime>(timestamp.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('KazaMeltLogsCompanion(')
          ..write('id: $id, ')
          ..write('prayerType: $prayerType, ')
          ..write('meltAmount: $meltAmount, ')
          ..write('timestamp: $timestamp')
          ..write(')'))
        .toString();
  }
}

class $HatimsTable extends Hatims with TableInfo<$HatimsTable, Hatim> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HatimsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
      'id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _titleMeta = const VerificationMeta('title');
  @override
  late final GeneratedColumn<String> title = GeneratedColumn<String>(
      'title', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _targetDateMeta =
      const VerificationMeta('targetDate');
  @override
  late final GeneratedColumn<DateTime> targetDate = GeneratedColumn<DateTime>(
      'target_date', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  static const VerificationMeta _totalPagesMeta =
      const VerificationMeta('totalPages');
  @override
  late final GeneratedColumn<int> totalPages = GeneratedColumn<int>(
      'total_pages', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(604));
  static const VerificationMeta _completedPagesMeta =
      const VerificationMeta('completedPages');
  @override
  late final GeneratedColumn<int> completedPages = GeneratedColumn<int>(
      'completed_pages', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(0));
  static const VerificationMeta _isCompletedMeta =
      const VerificationMeta('isCompleted');
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
      'is_completed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_completed" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _isGroupMeta =
      const VerificationMeta('isGroup');
  @override
  late final GeneratedColumn<bool> isGroup = GeneratedColumn<bool>(
      'is_group', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_group" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _createdAtMeta =
      const VerificationMeta('createdAt');
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
      'created_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [
        id,
        title,
        targetDate,
        totalPages,
        completedPages,
        isCompleted,
        isGroup,
        createdAt
      ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'hatims';
  @override
  VerificationContext validateIntegrity(Insertable<Hatim> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('title')) {
      context.handle(
          _titleMeta, title.isAcceptableOrUnknown(data['title']!, _titleMeta));
    } else if (isInserting) {
      context.missing(_titleMeta);
    }
    if (data.containsKey('target_date')) {
      context.handle(
          _targetDateMeta,
          targetDate.isAcceptableOrUnknown(
              data['target_date']!, _targetDateMeta));
    }
    if (data.containsKey('total_pages')) {
      context.handle(
          _totalPagesMeta,
          totalPages.isAcceptableOrUnknown(
              data['total_pages']!, _totalPagesMeta));
    }
    if (data.containsKey('completed_pages')) {
      context.handle(
          _completedPagesMeta,
          completedPages.isAcceptableOrUnknown(
              data['completed_pages']!, _completedPagesMeta));
    }
    if (data.containsKey('is_completed')) {
      context.handle(
          _isCompletedMeta,
          isCompleted.isAcceptableOrUnknown(
              data['is_completed']!, _isCompletedMeta));
    }
    if (data.containsKey('is_group')) {
      context.handle(_isGroupMeta,
          isGroup.isAcceptableOrUnknown(data['is_group']!, _isGroupMeta));
    }
    if (data.containsKey('created_at')) {
      context.handle(_createdAtMeta,
          createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  Hatim map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Hatim(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}id'])!,
      title: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}title'])!,
      targetDate: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}target_date']),
      totalPages: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}total_pages'])!,
      completedPages: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}completed_pages'])!,
      isCompleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_completed'])!,
      isGroup: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_group'])!,
      createdAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}created_at'])!,
    );
  }

  @override
  $HatimsTable createAlias(String alias) {
    return $HatimsTable(attachedDatabase, alias);
  }
}

class Hatim extends DataClass implements Insertable<Hatim> {
  final String id;
  final String title;
  final DateTime? targetDate;
  final int totalPages;
  final int completedPages;
  final bool isCompleted;
  final bool isGroup;
  final DateTime createdAt;
  const Hatim(
      {required this.id,
      required this.title,
      this.targetDate,
      required this.totalPages,
      required this.completedPages,
      required this.isCompleted,
      required this.isGroup,
      required this.createdAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['title'] = Variable<String>(title);
    if (!nullToAbsent || targetDate != null) {
      map['target_date'] = Variable<DateTime>(targetDate);
    }
    map['total_pages'] = Variable<int>(totalPages);
    map['completed_pages'] = Variable<int>(completedPages);
    map['is_completed'] = Variable<bool>(isCompleted);
    map['is_group'] = Variable<bool>(isGroup);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  HatimsCompanion toCompanion(bool nullToAbsent) {
    return HatimsCompanion(
      id: Value(id),
      title: Value(title),
      targetDate: targetDate == null && nullToAbsent
          ? const Value.absent()
          : Value(targetDate),
      totalPages: Value(totalPages),
      completedPages: Value(completedPages),
      isCompleted: Value(isCompleted),
      isGroup: Value(isGroup),
      createdAt: Value(createdAt),
    );
  }

  factory Hatim.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Hatim(
      id: serializer.fromJson<String>(json['id']),
      title: serializer.fromJson<String>(json['title']),
      targetDate: serializer.fromJson<DateTime?>(json['targetDate']),
      totalPages: serializer.fromJson<int>(json['totalPages']),
      completedPages: serializer.fromJson<int>(json['completedPages']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
      isGroup: serializer.fromJson<bool>(json['isGroup']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'title': serializer.toJson<String>(title),
      'targetDate': serializer.toJson<DateTime?>(targetDate),
      'totalPages': serializer.toJson<int>(totalPages),
      'completedPages': serializer.toJson<int>(completedPages),
      'isCompleted': serializer.toJson<bool>(isCompleted),
      'isGroup': serializer.toJson<bool>(isGroup),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  Hatim copyWith(
          {String? id,
          String? title,
          Value<DateTime?> targetDate = const Value.absent(),
          int? totalPages,
          int? completedPages,
          bool? isCompleted,
          bool? isGroup,
          DateTime? createdAt}) =>
      Hatim(
        id: id ?? this.id,
        title: title ?? this.title,
        targetDate: targetDate.present ? targetDate.value : this.targetDate,
        totalPages: totalPages ?? this.totalPages,
        completedPages: completedPages ?? this.completedPages,
        isCompleted: isCompleted ?? this.isCompleted,
        isGroup: isGroup ?? this.isGroup,
        createdAt: createdAt ?? this.createdAt,
      );
  Hatim copyWithCompanion(HatimsCompanion data) {
    return Hatim(
      id: data.id.present ? data.id.value : this.id,
      title: data.title.present ? data.title.value : this.title,
      targetDate:
          data.targetDate.present ? data.targetDate.value : this.targetDate,
      totalPages:
          data.totalPages.present ? data.totalPages.value : this.totalPages,
      completedPages: data.completedPages.present
          ? data.completedPages.value
          : this.completedPages,
      isCompleted:
          data.isCompleted.present ? data.isCompleted.value : this.isCompleted,
      isGroup: data.isGroup.present ? data.isGroup.value : this.isGroup,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Hatim(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('targetDate: $targetDate, ')
          ..write('totalPages: $totalPages, ')
          ..write('completedPages: $completedPages, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('isGroup: $isGroup, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, title, targetDate, totalPages,
      completedPages, isCompleted, isGroup, createdAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Hatim &&
          other.id == this.id &&
          other.title == this.title &&
          other.targetDate == this.targetDate &&
          other.totalPages == this.totalPages &&
          other.completedPages == this.completedPages &&
          other.isCompleted == this.isCompleted &&
          other.isGroup == this.isGroup &&
          other.createdAt == this.createdAt);
}

class HatimsCompanion extends UpdateCompanion<Hatim> {
  final Value<String> id;
  final Value<String> title;
  final Value<DateTime?> targetDate;
  final Value<int> totalPages;
  final Value<int> completedPages;
  final Value<bool> isCompleted;
  final Value<bool> isGroup;
  final Value<DateTime> createdAt;
  final Value<int> rowid;
  const HatimsCompanion({
    this.id = const Value.absent(),
    this.title = const Value.absent(),
    this.targetDate = const Value.absent(),
    this.totalPages = const Value.absent(),
    this.completedPages = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.isGroup = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  HatimsCompanion.insert({
    required String id,
    required String title,
    this.targetDate = const Value.absent(),
    this.totalPages = const Value.absent(),
    this.completedPages = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.isGroup = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  })  : id = Value(id),
        title = Value(title);
  static Insertable<Hatim> custom({
    Expression<String>? id,
    Expression<String>? title,
    Expression<DateTime>? targetDate,
    Expression<int>? totalPages,
    Expression<int>? completedPages,
    Expression<bool>? isCompleted,
    Expression<bool>? isGroup,
    Expression<DateTime>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (title != null) 'title': title,
      if (targetDate != null) 'target_date': targetDate,
      if (totalPages != null) 'total_pages': totalPages,
      if (completedPages != null) 'completed_pages': completedPages,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (isGroup != null) 'is_group': isGroup,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  HatimsCompanion copyWith(
      {Value<String>? id,
      Value<String>? title,
      Value<DateTime?>? targetDate,
      Value<int>? totalPages,
      Value<int>? completedPages,
      Value<bool>? isCompleted,
      Value<bool>? isGroup,
      Value<DateTime>? createdAt,
      Value<int>? rowid}) {
    return HatimsCompanion(
      id: id ?? this.id,
      title: title ?? this.title,
      targetDate: targetDate ?? this.targetDate,
      totalPages: totalPages ?? this.totalPages,
      completedPages: completedPages ?? this.completedPages,
      isCompleted: isCompleted ?? this.isCompleted,
      isGroup: isGroup ?? this.isGroup,
      createdAt: createdAt ?? this.createdAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (title.present) {
      map['title'] = Variable<String>(title.value);
    }
    if (targetDate.present) {
      map['target_date'] = Variable<DateTime>(targetDate.value);
    }
    if (totalPages.present) {
      map['total_pages'] = Variable<int>(totalPages.value);
    }
    if (completedPages.present) {
      map['completed_pages'] = Variable<int>(completedPages.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (isGroup.present) {
      map['is_group'] = Variable<bool>(isGroup.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HatimsCompanion(')
          ..write('id: $id, ')
          ..write('title: $title, ')
          ..write('targetDate: $targetDate, ')
          ..write('totalPages: $totalPages, ')
          ..write('completedPages: $completedPages, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('isGroup: $isGroup, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $HatimCuzProgressesTable extends HatimCuzProgresses
    with TableInfo<$HatimCuzProgressesTable, HatimCuzProgressesData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $HatimCuzProgressesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _hatimIdMeta =
      const VerificationMeta('hatimId');
  @override
  late final GeneratedColumn<String> hatimId = GeneratedColumn<String>(
      'hatim_id', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _juzNoMeta = const VerificationMeta('juzNo');
  @override
  late final GeneratedColumn<int> juzNo = GeneratedColumn<int>(
      'juz_no', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: true);
  static const VerificationMeta _isCompletedMeta =
      const VerificationMeta('isCompleted');
  @override
  late final GeneratedColumn<bool> isCompleted = GeneratedColumn<bool>(
      'is_completed', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints: GeneratedColumn.constraintIsAlways(
          'CHECK ("is_completed" IN (0, 1))'),
      defaultValue: const Constant(false));
  static const VerificationMeta _readerNameMeta =
      const VerificationMeta('readerName');
  @override
  late final GeneratedColumn<String> readerName = GeneratedColumn<String>(
      'reader_name', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _readerPhoneMeta =
      const VerificationMeta('readerPhone');
  @override
  late final GeneratedColumn<String> readerPhone = GeneratedColumn<String>(
      'reader_phone', aliasedName, true,
      type: DriftSqlType.string, requiredDuringInsert: false);
  static const VerificationMeta _completedAtMeta =
      const VerificationMeta('completedAt');
  @override
  late final GeneratedColumn<DateTime> completedAt = GeneratedColumn<DateTime>(
      'completed_at', aliasedName, true,
      type: DriftSqlType.dateTime, requiredDuringInsert: false);
  @override
  List<GeneratedColumn> get $columns =>
      [id, hatimId, juzNo, isCompleted, readerName, readerPhone, completedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'hatim_cuz_progresses';
  @override
  VerificationContext validateIntegrity(
      Insertable<HatimCuzProgressesData> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('hatim_id')) {
      context.handle(_hatimIdMeta,
          hatimId.isAcceptableOrUnknown(data['hatim_id']!, _hatimIdMeta));
    } else if (isInserting) {
      context.missing(_hatimIdMeta);
    }
    if (data.containsKey('juz_no')) {
      context.handle(
          _juzNoMeta, juzNo.isAcceptableOrUnknown(data['juz_no']!, _juzNoMeta));
    } else if (isInserting) {
      context.missing(_juzNoMeta);
    }
    if (data.containsKey('is_completed')) {
      context.handle(
          _isCompletedMeta,
          isCompleted.isAcceptableOrUnknown(
              data['is_completed']!, _isCompletedMeta));
    }
    if (data.containsKey('reader_name')) {
      context.handle(
          _readerNameMeta,
          readerName.isAcceptableOrUnknown(
              data['reader_name']!, _readerNameMeta));
    }
    if (data.containsKey('reader_phone')) {
      context.handle(
          _readerPhoneMeta,
          readerPhone.isAcceptableOrUnknown(
              data['reader_phone']!, _readerPhoneMeta));
    }
    if (data.containsKey('completed_at')) {
      context.handle(
          _completedAtMeta,
          completedAt.isAcceptableOrUnknown(
              data['completed_at']!, _completedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  HatimCuzProgressesData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return HatimCuzProgressesData(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      hatimId: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}hatim_id'])!,
      juzNo: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}juz_no'])!,
      isCompleted: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_completed'])!,
      readerName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reader_name']),
      readerPhone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}reader_phone']),
      completedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}completed_at']),
    );
  }

  @override
  $HatimCuzProgressesTable createAlias(String alias) {
    return $HatimCuzProgressesTable(attachedDatabase, alias);
  }
}

class HatimCuzProgressesData extends DataClass
    implements Insertable<HatimCuzProgressesData> {
  final int id;
  final String hatimId;
  final int juzNo;
  final bool isCompleted;
  final String? readerName;
  final String? readerPhone;
  final DateTime? completedAt;
  const HatimCuzProgressesData(
      {required this.id,
      required this.hatimId,
      required this.juzNo,
      required this.isCompleted,
      this.readerName,
      this.readerPhone,
      this.completedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['hatim_id'] = Variable<String>(hatimId);
    map['juz_no'] = Variable<int>(juzNo);
    map['is_completed'] = Variable<bool>(isCompleted);
    if (!nullToAbsent || readerName != null) {
      map['reader_name'] = Variable<String>(readerName);
    }
    if (!nullToAbsent || readerPhone != null) {
      map['reader_phone'] = Variable<String>(readerPhone);
    }
    if (!nullToAbsent || completedAt != null) {
      map['completed_at'] = Variable<DateTime>(completedAt);
    }
    return map;
  }

  HatimCuzProgressesCompanion toCompanion(bool nullToAbsent) {
    return HatimCuzProgressesCompanion(
      id: Value(id),
      hatimId: Value(hatimId),
      juzNo: Value(juzNo),
      isCompleted: Value(isCompleted),
      readerName: readerName == null && nullToAbsent
          ? const Value.absent()
          : Value(readerName),
      readerPhone: readerPhone == null && nullToAbsent
          ? const Value.absent()
          : Value(readerPhone),
      completedAt: completedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(completedAt),
    );
  }

  factory HatimCuzProgressesData.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return HatimCuzProgressesData(
      id: serializer.fromJson<int>(json['id']),
      hatimId: serializer.fromJson<String>(json['hatimId']),
      juzNo: serializer.fromJson<int>(json['juzNo']),
      isCompleted: serializer.fromJson<bool>(json['isCompleted']),
      readerName: serializer.fromJson<String?>(json['readerName']),
      readerPhone: serializer.fromJson<String?>(json['readerPhone']),
      completedAt: serializer.fromJson<DateTime?>(json['completedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'hatimId': serializer.toJson<String>(hatimId),
      'juzNo': serializer.toJson<int>(juzNo),
      'isCompleted': serializer.toJson<bool>(isCompleted),
      'readerName': serializer.toJson<String?>(readerName),
      'readerPhone': serializer.toJson<String?>(readerPhone),
      'completedAt': serializer.toJson<DateTime?>(completedAt),
    };
  }

  HatimCuzProgressesData copyWith(
          {int? id,
          String? hatimId,
          int? juzNo,
          bool? isCompleted,
          Value<String?> readerName = const Value.absent(),
          Value<String?> readerPhone = const Value.absent(),
          Value<DateTime?> completedAt = const Value.absent()}) =>
      HatimCuzProgressesData(
        id: id ?? this.id,
        hatimId: hatimId ?? this.hatimId,
        juzNo: juzNo ?? this.juzNo,
        isCompleted: isCompleted ?? this.isCompleted,
        readerName: readerName.present ? readerName.value : this.readerName,
        readerPhone: readerPhone.present ? readerPhone.value : this.readerPhone,
        completedAt: completedAt.present ? completedAt.value : this.completedAt,
      );
  HatimCuzProgressesData copyWithCompanion(HatimCuzProgressesCompanion data) {
    return HatimCuzProgressesData(
      id: data.id.present ? data.id.value : this.id,
      hatimId: data.hatimId.present ? data.hatimId.value : this.hatimId,
      juzNo: data.juzNo.present ? data.juzNo.value : this.juzNo,
      isCompleted:
          data.isCompleted.present ? data.isCompleted.value : this.isCompleted,
      readerName:
          data.readerName.present ? data.readerName.value : this.readerName,
      readerPhone:
          data.readerPhone.present ? data.readerPhone.value : this.readerPhone,
      completedAt:
          data.completedAt.present ? data.completedAt.value : this.completedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('HatimCuzProgressesData(')
          ..write('id: $id, ')
          ..write('hatimId: $hatimId, ')
          ..write('juzNo: $juzNo, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('readerName: $readerName, ')
          ..write('readerPhone: $readerPhone, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
      id, hatimId, juzNo, isCompleted, readerName, readerPhone, completedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is HatimCuzProgressesData &&
          other.id == this.id &&
          other.hatimId == this.hatimId &&
          other.juzNo == this.juzNo &&
          other.isCompleted == this.isCompleted &&
          other.readerName == this.readerName &&
          other.readerPhone == this.readerPhone &&
          other.completedAt == this.completedAt);
}

class HatimCuzProgressesCompanion
    extends UpdateCompanion<HatimCuzProgressesData> {
  final Value<int> id;
  final Value<String> hatimId;
  final Value<int> juzNo;
  final Value<bool> isCompleted;
  final Value<String?> readerName;
  final Value<String?> readerPhone;
  final Value<DateTime?> completedAt;
  const HatimCuzProgressesCompanion({
    this.id = const Value.absent(),
    this.hatimId = const Value.absent(),
    this.juzNo = const Value.absent(),
    this.isCompleted = const Value.absent(),
    this.readerName = const Value.absent(),
    this.readerPhone = const Value.absent(),
    this.completedAt = const Value.absent(),
  });
  HatimCuzProgressesCompanion.insert({
    this.id = const Value.absent(),
    required String hatimId,
    required int juzNo,
    this.isCompleted = const Value.absent(),
    this.readerName = const Value.absent(),
    this.readerPhone = const Value.absent(),
    this.completedAt = const Value.absent(),
  })  : hatimId = Value(hatimId),
        juzNo = Value(juzNo);
  static Insertable<HatimCuzProgressesData> custom({
    Expression<int>? id,
    Expression<String>? hatimId,
    Expression<int>? juzNo,
    Expression<bool>? isCompleted,
    Expression<String>? readerName,
    Expression<String>? readerPhone,
    Expression<DateTime>? completedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (hatimId != null) 'hatim_id': hatimId,
      if (juzNo != null) 'juz_no': juzNo,
      if (isCompleted != null) 'is_completed': isCompleted,
      if (readerName != null) 'reader_name': readerName,
      if (readerPhone != null) 'reader_phone': readerPhone,
      if (completedAt != null) 'completed_at': completedAt,
    });
  }

  HatimCuzProgressesCompanion copyWith(
      {Value<int>? id,
      Value<String>? hatimId,
      Value<int>? juzNo,
      Value<bool>? isCompleted,
      Value<String?>? readerName,
      Value<String?>? readerPhone,
      Value<DateTime?>? completedAt}) {
    return HatimCuzProgressesCompanion(
      id: id ?? this.id,
      hatimId: hatimId ?? this.hatimId,
      juzNo: juzNo ?? this.juzNo,
      isCompleted: isCompleted ?? this.isCompleted,
      readerName: readerName ?? this.readerName,
      readerPhone: readerPhone ?? this.readerPhone,
      completedAt: completedAt ?? this.completedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (hatimId.present) {
      map['hatim_id'] = Variable<String>(hatimId.value);
    }
    if (juzNo.present) {
      map['juz_no'] = Variable<int>(juzNo.value);
    }
    if (isCompleted.present) {
      map['is_completed'] = Variable<bool>(isCompleted.value);
    }
    if (readerName.present) {
      map['reader_name'] = Variable<String>(readerName.value);
    }
    if (readerPhone.present) {
      map['reader_phone'] = Variable<String>(readerPhone.value);
    }
    if (completedAt.present) {
      map['completed_at'] = Variable<DateTime>(completedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('HatimCuzProgressesCompanion(')
          ..write('id: $id, ')
          ..write('hatimId: $hatimId, ')
          ..write('juzNo: $juzNo, ')
          ..write('isCompleted: $isCompleted, ')
          ..write('readerName: $readerName, ')
          ..write('readerPhone: $readerPhone, ')
          ..write('completedAt: $completedAt')
          ..write(')'))
        .toString();
  }
}

class $JuzBookmarksTable extends JuzBookmarks
    with TableInfo<$JuzBookmarksTable, JuzBookmark> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $JuzBookmarksTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _juzNoMeta = const VerificationMeta('juzNo');
  @override
  late final GeneratedColumn<int> juzNo = GeneratedColumn<int>(
      'juz_no', aliasedName, false,
      type: DriftSqlType.int, requiredDuringInsert: false);
  static const VerificationMeta _lastPageMeta =
      const VerificationMeta('lastPage');
  @override
  late final GeneratedColumn<int> lastPage = GeneratedColumn<int>(
      'last_page', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(1));
  static const VerificationMeta _updatedAtMeta =
      const VerificationMeta('updatedAt');
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
      'updated_at', aliasedName, false,
      type: DriftSqlType.dateTime,
      requiredDuringInsert: false,
      defaultValue: currentDateAndTime);
  @override
  List<GeneratedColumn> get $columns => [juzNo, lastPage, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'juz_bookmarks';
  @override
  VerificationContext validateIntegrity(Insertable<JuzBookmark> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('juz_no')) {
      context.handle(
          _juzNoMeta, juzNo.isAcceptableOrUnknown(data['juz_no']!, _juzNoMeta));
    }
    if (data.containsKey('last_page')) {
      context.handle(_lastPageMeta,
          lastPage.isAcceptableOrUnknown(data['last_page']!, _lastPageMeta));
    }
    if (data.containsKey('updated_at')) {
      context.handle(_updatedAtMeta,
          updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {juzNo};
  @override
  JuzBookmark map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return JuzBookmark(
      juzNo: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}juz_no'])!,
      lastPage: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}last_page'])!,
      updatedAt: attachedDatabase.typeMapping
          .read(DriftSqlType.dateTime, data['${effectivePrefix}updated_at'])!,
    );
  }

  @override
  $JuzBookmarksTable createAlias(String alias) {
    return $JuzBookmarksTable(attachedDatabase, alias);
  }
}

class JuzBookmark extends DataClass implements Insertable<JuzBookmark> {
  final int juzNo;
  final int lastPage;
  final DateTime updatedAt;
  const JuzBookmark(
      {required this.juzNo, required this.lastPage, required this.updatedAt});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['juz_no'] = Variable<int>(juzNo);
    map['last_page'] = Variable<int>(lastPage);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  JuzBookmarksCompanion toCompanion(bool nullToAbsent) {
    return JuzBookmarksCompanion(
      juzNo: Value(juzNo),
      lastPage: Value(lastPage),
      updatedAt: Value(updatedAt),
    );
  }

  factory JuzBookmark.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return JuzBookmark(
      juzNo: serializer.fromJson<int>(json['juzNo']),
      lastPage: serializer.fromJson<int>(json['lastPage']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'juzNo': serializer.toJson<int>(juzNo),
      'lastPage': serializer.toJson<int>(lastPage),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  JuzBookmark copyWith({int? juzNo, int? lastPage, DateTime? updatedAt}) =>
      JuzBookmark(
        juzNo: juzNo ?? this.juzNo,
        lastPage: lastPage ?? this.lastPage,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  JuzBookmark copyWithCompanion(JuzBookmarksCompanion data) {
    return JuzBookmark(
      juzNo: data.juzNo.present ? data.juzNo.value : this.juzNo,
      lastPage: data.lastPage.present ? data.lastPage.value : this.lastPage,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('JuzBookmark(')
          ..write('juzNo: $juzNo, ')
          ..write('lastPage: $lastPage, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(juzNo, lastPage, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is JuzBookmark &&
          other.juzNo == this.juzNo &&
          other.lastPage == this.lastPage &&
          other.updatedAt == this.updatedAt);
}

class JuzBookmarksCompanion extends UpdateCompanion<JuzBookmark> {
  final Value<int> juzNo;
  final Value<int> lastPage;
  final Value<DateTime> updatedAt;
  const JuzBookmarksCompanion({
    this.juzNo = const Value.absent(),
    this.lastPage = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  JuzBookmarksCompanion.insert({
    this.juzNo = const Value.absent(),
    this.lastPage = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  static Insertable<JuzBookmark> custom({
    Expression<int>? juzNo,
    Expression<int>? lastPage,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (juzNo != null) 'juz_no': juzNo,
      if (lastPage != null) 'last_page': lastPage,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  JuzBookmarksCompanion copyWith(
      {Value<int>? juzNo, Value<int>? lastPage, Value<DateTime>? updatedAt}) {
    return JuzBookmarksCompanion(
      juzNo: juzNo ?? this.juzNo,
      lastPage: lastPage ?? this.lastPage,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (juzNo.present) {
      map['juz_no'] = Variable<int>(juzNo.value);
    }
    if (lastPage.present) {
      map['last_page'] = Variable<int>(lastPage.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('JuzBookmarksCompanion(')
          ..write('juzNo: $juzNo, ')
          ..write('lastPage: $lastPage, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $FardRemindersTable extends FardReminders
    with TableInfo<$FardRemindersTable, FardReminder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $FardRemindersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
      'id', aliasedName, false,
      hasAutoIncrement: true,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('PRIMARY KEY AUTOINCREMENT'));
  static const VerificationMeta _prayerNameMeta =
      const VerificationMeta('prayerName');
  @override
  late final GeneratedColumn<String> prayerName = GeneratedColumn<String>(
      'prayer_name', aliasedName, false,
      type: DriftSqlType.string, requiredDuringInsert: true);
  static const VerificationMeta _reminderMinutesBeforeMeta =
      const VerificationMeta('reminderMinutesBefore');
  @override
  late final GeneratedColumn<int> reminderMinutesBefore = GeneratedColumn<int>(
      'reminder_minutes_before', aliasedName, false,
      type: DriftSqlType.int,
      requiredDuringInsert: false,
      defaultValue: const Constant(15));
  static const VerificationMeta _isEnabledMeta =
      const VerificationMeta('isEnabled');
  @override
  late final GeneratedColumn<bool> isEnabled = GeneratedColumn<bool>(
      'is_enabled', aliasedName, false,
      type: DriftSqlType.bool,
      requiredDuringInsert: false,
      defaultConstraints:
          GeneratedColumn.constraintIsAlways('CHECK ("is_enabled" IN (0, 1))'),
      defaultValue: const Constant(true));
  static const VerificationMeta _soundToneMeta =
      const VerificationMeta('soundTone');
  @override
  late final GeneratedColumn<String> soundTone = GeneratedColumn<String>(
      'sound_tone', aliasedName, false,
      type: DriftSqlType.string,
      requiredDuringInsert: false,
      defaultValue: const Constant('bulbul'));
  @override
  List<GeneratedColumn> get $columns =>
      [id, prayerName, reminderMinutesBefore, isEnabled, soundTone];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'fard_reminders';
  @override
  VerificationContext validateIntegrity(Insertable<FardReminder> instance,
      {bool isInserting = false}) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('prayer_name')) {
      context.handle(
          _prayerNameMeta,
          prayerName.isAcceptableOrUnknown(
              data['prayer_name']!, _prayerNameMeta));
    } else if (isInserting) {
      context.missing(_prayerNameMeta);
    }
    if (data.containsKey('reminder_minutes_before')) {
      context.handle(
          _reminderMinutesBeforeMeta,
          reminderMinutesBefore.isAcceptableOrUnknown(
              data['reminder_minutes_before']!, _reminderMinutesBeforeMeta));
    }
    if (data.containsKey('is_enabled')) {
      context.handle(_isEnabledMeta,
          isEnabled.isAcceptableOrUnknown(data['is_enabled']!, _isEnabledMeta));
    }
    if (data.containsKey('sound_tone')) {
      context.handle(_soundToneMeta,
          soundTone.isAcceptableOrUnknown(data['sound_tone']!, _soundToneMeta));
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  FardReminder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return FardReminder(
      id: attachedDatabase.typeMapping
          .read(DriftSqlType.int, data['${effectivePrefix}id'])!,
      prayerName: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}prayer_name'])!,
      reminderMinutesBefore: attachedDatabase.typeMapping.read(
          DriftSqlType.int, data['${effectivePrefix}reminder_minutes_before'])!,
      isEnabled: attachedDatabase.typeMapping
          .read(DriftSqlType.bool, data['${effectivePrefix}is_enabled'])!,
      soundTone: attachedDatabase.typeMapping
          .read(DriftSqlType.string, data['${effectivePrefix}sound_tone'])!,
    );
  }

  @override
  $FardRemindersTable createAlias(String alias) {
    return $FardRemindersTable(attachedDatabase, alias);
  }
}

class FardReminder extends DataClass implements Insertable<FardReminder> {
  final int id;
  final String prayerName;
  final int reminderMinutesBefore;
  final bool isEnabled;
  final String soundTone;
  const FardReminder(
      {required this.id,
      required this.prayerName,
      required this.reminderMinutesBefore,
      required this.isEnabled,
      required this.soundTone});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['prayer_name'] = Variable<String>(prayerName);
    map['reminder_minutes_before'] = Variable<int>(reminderMinutesBefore);
    map['is_enabled'] = Variable<bool>(isEnabled);
    map['sound_tone'] = Variable<String>(soundTone);
    return map;
  }

  FardRemindersCompanion toCompanion(bool nullToAbsent) {
    return FardRemindersCompanion(
      id: Value(id),
      prayerName: Value(prayerName),
      reminderMinutesBefore: Value(reminderMinutesBefore),
      isEnabled: Value(isEnabled),
      soundTone: Value(soundTone),
    );
  }

  factory FardReminder.fromJson(Map<String, dynamic> json,
      {ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return FardReminder(
      id: serializer.fromJson<int>(json['id']),
      prayerName: serializer.fromJson<String>(json['prayerName']),
      reminderMinutesBefore:
          serializer.fromJson<int>(json['reminderMinutesBefore']),
      isEnabled: serializer.fromJson<bool>(json['isEnabled']),
      soundTone: serializer.fromJson<String>(json['soundTone']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'prayerName': serializer.toJson<String>(prayerName),
      'reminderMinutesBefore': serializer.toJson<int>(reminderMinutesBefore),
      'isEnabled': serializer.toJson<bool>(isEnabled),
      'soundTone': serializer.toJson<String>(soundTone),
    };
  }

  FardReminder copyWith(
          {int? id,
          String? prayerName,
          int? reminderMinutesBefore,
          bool? isEnabled,
          String? soundTone}) =>
      FardReminder(
        id: id ?? this.id,
        prayerName: prayerName ?? this.prayerName,
        reminderMinutesBefore:
            reminderMinutesBefore ?? this.reminderMinutesBefore,
        isEnabled: isEnabled ?? this.isEnabled,
        soundTone: soundTone ?? this.soundTone,
      );
  FardReminder copyWithCompanion(FardRemindersCompanion data) {
    return FardReminder(
      id: data.id.present ? data.id.value : this.id,
      prayerName:
          data.prayerName.present ? data.prayerName.value : this.prayerName,
      reminderMinutesBefore: data.reminderMinutesBefore.present
          ? data.reminderMinutesBefore.value
          : this.reminderMinutesBefore,
      isEnabled: data.isEnabled.present ? data.isEnabled.value : this.isEnabled,
      soundTone: data.soundTone.present ? data.soundTone.value : this.soundTone,
    );
  }

  @override
  String toString() {
    return (StringBuffer('FardReminder(')
          ..write('id: $id, ')
          ..write('prayerName: $prayerName, ')
          ..write('reminderMinutesBefore: $reminderMinutesBefore, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('soundTone: $soundTone')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, prayerName, reminderMinutesBefore, isEnabled, soundTone);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is FardReminder &&
          other.id == this.id &&
          other.prayerName == this.prayerName &&
          other.reminderMinutesBefore == this.reminderMinutesBefore &&
          other.isEnabled == this.isEnabled &&
          other.soundTone == this.soundTone);
}

class FardRemindersCompanion extends UpdateCompanion<FardReminder> {
  final Value<int> id;
  final Value<String> prayerName;
  final Value<int> reminderMinutesBefore;
  final Value<bool> isEnabled;
  final Value<String> soundTone;
  const FardRemindersCompanion({
    this.id = const Value.absent(),
    this.prayerName = const Value.absent(),
    this.reminderMinutesBefore = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.soundTone = const Value.absent(),
  });
  FardRemindersCompanion.insert({
    this.id = const Value.absent(),
    required String prayerName,
    this.reminderMinutesBefore = const Value.absent(),
    this.isEnabled = const Value.absent(),
    this.soundTone = const Value.absent(),
  }) : prayerName = Value(prayerName);
  static Insertable<FardReminder> custom({
    Expression<int>? id,
    Expression<String>? prayerName,
    Expression<int>? reminderMinutesBefore,
    Expression<bool>? isEnabled,
    Expression<String>? soundTone,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (prayerName != null) 'prayer_name': prayerName,
      if (reminderMinutesBefore != null)
        'reminder_minutes_before': reminderMinutesBefore,
      if (isEnabled != null) 'is_enabled': isEnabled,
      if (soundTone != null) 'sound_tone': soundTone,
    });
  }

  FardRemindersCompanion copyWith(
      {Value<int>? id,
      Value<String>? prayerName,
      Value<int>? reminderMinutesBefore,
      Value<bool>? isEnabled,
      Value<String>? soundTone}) {
    return FardRemindersCompanion(
      id: id ?? this.id,
      prayerName: prayerName ?? this.prayerName,
      reminderMinutesBefore:
          reminderMinutesBefore ?? this.reminderMinutesBefore,
      isEnabled: isEnabled ?? this.isEnabled,
      soundTone: soundTone ?? this.soundTone,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (prayerName.present) {
      map['prayer_name'] = Variable<String>(prayerName.value);
    }
    if (reminderMinutesBefore.present) {
      map['reminder_minutes_before'] =
          Variable<int>(reminderMinutesBefore.value);
    }
    if (isEnabled.present) {
      map['is_enabled'] = Variable<bool>(isEnabled.value);
    }
    if (soundTone.present) {
      map['sound_tone'] = Variable<String>(soundTone.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('FardRemindersCompanion(')
          ..write('id: $id, ')
          ..write('prayerName: $prayerName, ')
          ..write('reminderMinutesBefore: $reminderMinutesBefore, ')
          ..write('isEnabled: $isEnabled, ')
          ..write('soundTone: $soundTone')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $ZikirsTable zikirs = $ZikirsTable(this);
  late final $ZikirLogsTable zikirLogs = $ZikirLogsTable(this);
  late final $UserStreaksTable userStreaks = $UserStreaksTable(this);
  late final $UserStreakHistoriesTable userStreakHistories =
      $UserStreakHistoriesTable(this);
  late final $StreakGapDaysTable streakGapDays = $StreakGapDaysTable(this);
  late final $UnlockedBadgesTable unlockedBadges = $UnlockedBadgesTable(this);
  late final $UserProfilesTable userProfiles = $UserProfilesTable(this);
  late final $MemorizationPlansTable memorizationPlans =
      $MemorizationPlansTable(this);
  late final $HafizlikDailyLogsTable hafizlikDailyLogs =
      $HafizlikDailyLogsTable(this);
  late final $KazaPrayersTable kazaPrayers = $KazaPrayersTable(this);
  late final $PrayerAnswerLogsTable prayerAnswerLogs =
      $PrayerAnswerLogsTable(this);
  late final $KazaMeltLogsTable kazaMeltLogs = $KazaMeltLogsTable(this);
  late final $HatimsTable hatims = $HatimsTable(this);
  late final $HatimCuzProgressesTable hatimCuzProgresses =
      $HatimCuzProgressesTable(this);
  late final $JuzBookmarksTable juzBookmarks = $JuzBookmarksTable(this);
  late final $FardRemindersTable fardReminders = $FardRemindersTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
        zikirs,
        zikirLogs,
        userStreaks,
        userStreakHistories,
        streakGapDays,
        unlockedBadges,
        userProfiles,
        memorizationPlans,
        hafizlikDailyLogs,
        kazaPrayers,
        prayerAnswerLogs,
        kazaMeltLogs,
        hatims,
        hatimCuzProgresses,
        juzBookmarks,
        fardReminders
      ];
}

typedef $$ZikirsTableCreateCompanionBuilder = ZikirsCompanion Function({
  Value<int> id,
  required String name,
  Value<String?> arabic,
  Value<int> target,
  Value<int> currentCount,
  Value<int> totalCount,
  Value<int> lap,
  Value<bool> isFavorite,
  Value<String> category,
  Value<String> soundEffect,
  Value<bool> vibrationEnabled,
  Value<DateTime> createdAt,
  Value<DateTime?> lastPracticed,
});
typedef $$ZikirsTableUpdateCompanionBuilder = ZikirsCompanion Function({
  Value<int> id,
  Value<String> name,
  Value<String?> arabic,
  Value<int> target,
  Value<int> currentCount,
  Value<int> totalCount,
  Value<int> lap,
  Value<bool> isFavorite,
  Value<String> category,
  Value<String> soundEffect,
  Value<bool> vibrationEnabled,
  Value<DateTime> createdAt,
  Value<DateTime?> lastPracticed,
});

class $$ZikirsTableFilterComposer
    extends Composer<_$AppDatabase, $ZikirsTable> {
  $$ZikirsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get arabic => $composableBuilder(
      column: $table.arabic, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get target => $composableBuilder(
      column: $table.target, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get currentCount => $composableBuilder(
      column: $table.currentCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalCount => $composableBuilder(
      column: $table.totalCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lap => $composableBuilder(
      column: $table.lap, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get soundEffect => $composableBuilder(
      column: $table.soundEffect, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get vibrationEnabled => $composableBuilder(
      column: $table.vibrationEnabled,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastPracticed => $composableBuilder(
      column: $table.lastPracticed, builder: (column) => ColumnFilters(column));
}

class $$ZikirsTableOrderingComposer
    extends Composer<_$AppDatabase, $ZikirsTable> {
  $$ZikirsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get name => $composableBuilder(
      column: $table.name, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get arabic => $composableBuilder(
      column: $table.arabic, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get target => $composableBuilder(
      column: $table.target, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get currentCount => $composableBuilder(
      column: $table.currentCount,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalCount => $composableBuilder(
      column: $table.totalCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lap => $composableBuilder(
      column: $table.lap, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get soundEffect => $composableBuilder(
      column: $table.soundEffect, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get vibrationEnabled => $composableBuilder(
      column: $table.vibrationEnabled,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastPracticed => $composableBuilder(
      column: $table.lastPracticed,
      builder: (column) => ColumnOrderings(column));
}

class $$ZikirsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ZikirsTable> {
  $$ZikirsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get arabic =>
      $composableBuilder(column: $table.arabic, builder: (column) => column);

  GeneratedColumn<int> get target =>
      $composableBuilder(column: $table.target, builder: (column) => column);

  GeneratedColumn<int> get currentCount => $composableBuilder(
      column: $table.currentCount, builder: (column) => column);

  GeneratedColumn<int> get totalCount => $composableBuilder(
      column: $table.totalCount, builder: (column) => column);

  GeneratedColumn<int> get lap =>
      $composableBuilder(column: $table.lap, builder: (column) => column);

  GeneratedColumn<bool> get isFavorite => $composableBuilder(
      column: $table.isFavorite, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<String> get soundEffect => $composableBuilder(
      column: $table.soundEffect, builder: (column) => column);

  GeneratedColumn<bool> get vibrationEnabled => $composableBuilder(
      column: $table.vibrationEnabled, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get lastPracticed => $composableBuilder(
      column: $table.lastPracticed, builder: (column) => column);
}

class $$ZikirsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ZikirsTable,
    Zikir,
    $$ZikirsTableFilterComposer,
    $$ZikirsTableOrderingComposer,
    $$ZikirsTableAnnotationComposer,
    $$ZikirsTableCreateCompanionBuilder,
    $$ZikirsTableUpdateCompanionBuilder,
    (Zikir, BaseReferences<_$AppDatabase, $ZikirsTable, Zikir>),
    Zikir,
    PrefetchHooks Function()> {
  $$ZikirsTableTableManager(_$AppDatabase db, $ZikirsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ZikirsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ZikirsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ZikirsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> name = const Value.absent(),
            Value<String?> arabic = const Value.absent(),
            Value<int> target = const Value.absent(),
            Value<int> currentCount = const Value.absent(),
            Value<int> totalCount = const Value.absent(),
            Value<int> lap = const Value.absent(),
            Value<bool> isFavorite = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<String> soundEffect = const Value.absent(),
            Value<bool> vibrationEnabled = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> lastPracticed = const Value.absent(),
          }) =>
              ZikirsCompanion(
            id: id,
            name: name,
            arabic: arabic,
            target: target,
            currentCount: currentCount,
            totalCount: totalCount,
            lap: lap,
            isFavorite: isFavorite,
            category: category,
            soundEffect: soundEffect,
            vibrationEnabled: vibrationEnabled,
            createdAt: createdAt,
            lastPracticed: lastPracticed,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String name,
            Value<String?> arabic = const Value.absent(),
            Value<int> target = const Value.absent(),
            Value<int> currentCount = const Value.absent(),
            Value<int> totalCount = const Value.absent(),
            Value<int> lap = const Value.absent(),
            Value<bool> isFavorite = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<String> soundEffect = const Value.absent(),
            Value<bool> vibrationEnabled = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<DateTime?> lastPracticed = const Value.absent(),
          }) =>
              ZikirsCompanion.insert(
            id: id,
            name: name,
            arabic: arabic,
            target: target,
            currentCount: currentCount,
            totalCount: totalCount,
            lap: lap,
            isFavorite: isFavorite,
            category: category,
            soundEffect: soundEffect,
            vibrationEnabled: vibrationEnabled,
            createdAt: createdAt,
            lastPracticed: lastPracticed,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ZikirsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ZikirsTable,
    Zikir,
    $$ZikirsTableFilterComposer,
    $$ZikirsTableOrderingComposer,
    $$ZikirsTableAnnotationComposer,
    $$ZikirsTableCreateCompanionBuilder,
    $$ZikirsTableUpdateCompanionBuilder,
    (Zikir, BaseReferences<_$AppDatabase, $ZikirsTable, Zikir>),
    Zikir,
    PrefetchHooks Function()>;
typedef $$ZikirLogsTableCreateCompanionBuilder = ZikirLogsCompanion Function({
  Value<int> id,
  required int zikirId,
  required int count,
  required String dateStr,
  Value<DateTime> timestamp,
});
typedef $$ZikirLogsTableUpdateCompanionBuilder = ZikirLogsCompanion Function({
  Value<int> id,
  Value<int> zikirId,
  Value<int> count,
  Value<String> dateStr,
  Value<DateTime> timestamp,
});

class $$ZikirLogsTableFilterComposer
    extends Composer<_$AppDatabase, $ZikirLogsTable> {
  $$ZikirLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get zikirId => $composableBuilder(
      column: $table.zikirId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get count => $composableBuilder(
      column: $table.count, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dateStr => $composableBuilder(
      column: $table.dateStr, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));
}

class $$ZikirLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $ZikirLogsTable> {
  $$ZikirLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get zikirId => $composableBuilder(
      column: $table.zikirId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get count => $composableBuilder(
      column: $table.count, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dateStr => $composableBuilder(
      column: $table.dateStr, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));
}

class $$ZikirLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $ZikirLogsTable> {
  $$ZikirLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get zikirId =>
      $composableBuilder(column: $table.zikirId, builder: (column) => column);

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);

  GeneratedColumn<String> get dateStr =>
      $composableBuilder(column: $table.dateStr, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);
}

class $$ZikirLogsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $ZikirLogsTable,
    ZikirLog,
    $$ZikirLogsTableFilterComposer,
    $$ZikirLogsTableOrderingComposer,
    $$ZikirLogsTableAnnotationComposer,
    $$ZikirLogsTableCreateCompanionBuilder,
    $$ZikirLogsTableUpdateCompanionBuilder,
    (ZikirLog, BaseReferences<_$AppDatabase, $ZikirLogsTable, ZikirLog>),
    ZikirLog,
    PrefetchHooks Function()> {
  $$ZikirLogsTableTableManager(_$AppDatabase db, $ZikirLogsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$ZikirLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$ZikirLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$ZikirLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> zikirId = const Value.absent(),
            Value<int> count = const Value.absent(),
            Value<String> dateStr = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
          }) =>
              ZikirLogsCompanion(
            id: id,
            zikirId: zikirId,
            count: count,
            dateStr: dateStr,
            timestamp: timestamp,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required int zikirId,
            required int count,
            required String dateStr,
            Value<DateTime> timestamp = const Value.absent(),
          }) =>
              ZikirLogsCompanion.insert(
            id: id,
            zikirId: zikirId,
            count: count,
            dateStr: dateStr,
            timestamp: timestamp,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$ZikirLogsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $ZikirLogsTable,
    ZikirLog,
    $$ZikirLogsTableFilterComposer,
    $$ZikirLogsTableOrderingComposer,
    $$ZikirLogsTableAnnotationComposer,
    $$ZikirLogsTableCreateCompanionBuilder,
    $$ZikirLogsTableUpdateCompanionBuilder,
    (ZikirLog, BaseReferences<_$AppDatabase, $ZikirLogsTable, ZikirLog>),
    ZikirLog,
    PrefetchHooks Function()>;
typedef $$UserStreaksTableCreateCompanionBuilder = UserStreaksCompanion
    Function({
  Value<int> id,
  Value<int> currentStreak,
  Value<int> bestStreak,
  Value<int> totalDays,
  Value<String?> lastDate,
  Value<int> freezeCount,
  Value<String?> lastFreezeDate,
  Value<double> multiplier,
  Value<int> xp,
  Value<String> rank,
});
typedef $$UserStreaksTableUpdateCompanionBuilder = UserStreaksCompanion
    Function({
  Value<int> id,
  Value<int> currentStreak,
  Value<int> bestStreak,
  Value<int> totalDays,
  Value<String?> lastDate,
  Value<int> freezeCount,
  Value<String?> lastFreezeDate,
  Value<double> multiplier,
  Value<int> xp,
  Value<String> rank,
});

class $$UserStreaksTableFilterComposer
    extends Composer<_$AppDatabase, $UserStreaksTable> {
  $$UserStreaksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get currentStreak => $composableBuilder(
      column: $table.currentStreak, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get bestStreak => $composableBuilder(
      column: $table.bestStreak, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalDays => $composableBuilder(
      column: $table.totalDays, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastDate => $composableBuilder(
      column: $table.lastDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get freezeCount => $composableBuilder(
      column: $table.freezeCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get lastFreezeDate => $composableBuilder(
      column: $table.lastFreezeDate,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get multiplier => $composableBuilder(
      column: $table.multiplier, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get xp => $composableBuilder(
      column: $table.xp, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get rank => $composableBuilder(
      column: $table.rank, builder: (column) => ColumnFilters(column));
}

class $$UserStreaksTableOrderingComposer
    extends Composer<_$AppDatabase, $UserStreaksTable> {
  $$UserStreaksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get currentStreak => $composableBuilder(
      column: $table.currentStreak,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get bestStreak => $composableBuilder(
      column: $table.bestStreak, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalDays => $composableBuilder(
      column: $table.totalDays, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastDate => $composableBuilder(
      column: $table.lastDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get freezeCount => $composableBuilder(
      column: $table.freezeCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get lastFreezeDate => $composableBuilder(
      column: $table.lastFreezeDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get multiplier => $composableBuilder(
      column: $table.multiplier, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get xp => $composableBuilder(
      column: $table.xp, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get rank => $composableBuilder(
      column: $table.rank, builder: (column) => ColumnOrderings(column));
}

class $$UserStreaksTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserStreaksTable> {
  $$UserStreaksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get currentStreak => $composableBuilder(
      column: $table.currentStreak, builder: (column) => column);

  GeneratedColumn<int> get bestStreak => $composableBuilder(
      column: $table.bestStreak, builder: (column) => column);

  GeneratedColumn<int> get totalDays =>
      $composableBuilder(column: $table.totalDays, builder: (column) => column);

  GeneratedColumn<String> get lastDate =>
      $composableBuilder(column: $table.lastDate, builder: (column) => column);

  GeneratedColumn<int> get freezeCount => $composableBuilder(
      column: $table.freezeCount, builder: (column) => column);

  GeneratedColumn<String> get lastFreezeDate => $composableBuilder(
      column: $table.lastFreezeDate, builder: (column) => column);

  GeneratedColumn<double> get multiplier => $composableBuilder(
      column: $table.multiplier, builder: (column) => column);

  GeneratedColumn<int> get xp =>
      $composableBuilder(column: $table.xp, builder: (column) => column);

  GeneratedColumn<String> get rank =>
      $composableBuilder(column: $table.rank, builder: (column) => column);
}

class $$UserStreaksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UserStreaksTable,
    UserStreak,
    $$UserStreaksTableFilterComposer,
    $$UserStreaksTableOrderingComposer,
    $$UserStreaksTableAnnotationComposer,
    $$UserStreaksTableCreateCompanionBuilder,
    $$UserStreaksTableUpdateCompanionBuilder,
    (UserStreak, BaseReferences<_$AppDatabase, $UserStreaksTable, UserStreak>),
    UserStreak,
    PrefetchHooks Function()> {
  $$UserStreaksTableTableManager(_$AppDatabase db, $UserStreaksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserStreaksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserStreaksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserStreaksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> currentStreak = const Value.absent(),
            Value<int> bestStreak = const Value.absent(),
            Value<int> totalDays = const Value.absent(),
            Value<String?> lastDate = const Value.absent(),
            Value<int> freezeCount = const Value.absent(),
            Value<String?> lastFreezeDate = const Value.absent(),
            Value<double> multiplier = const Value.absent(),
            Value<int> xp = const Value.absent(),
            Value<String> rank = const Value.absent(),
          }) =>
              UserStreaksCompanion(
            id: id,
            currentStreak: currentStreak,
            bestStreak: bestStreak,
            totalDays: totalDays,
            lastDate: lastDate,
            freezeCount: freezeCount,
            lastFreezeDate: lastFreezeDate,
            multiplier: multiplier,
            xp: xp,
            rank: rank,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<int> currentStreak = const Value.absent(),
            Value<int> bestStreak = const Value.absent(),
            Value<int> totalDays = const Value.absent(),
            Value<String?> lastDate = const Value.absent(),
            Value<int> freezeCount = const Value.absent(),
            Value<String?> lastFreezeDate = const Value.absent(),
            Value<double> multiplier = const Value.absent(),
            Value<int> xp = const Value.absent(),
            Value<String> rank = const Value.absent(),
          }) =>
              UserStreaksCompanion.insert(
            id: id,
            currentStreak: currentStreak,
            bestStreak: bestStreak,
            totalDays: totalDays,
            lastDate: lastDate,
            freezeCount: freezeCount,
            lastFreezeDate: lastFreezeDate,
            multiplier: multiplier,
            xp: xp,
            rank: rank,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$UserStreaksTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UserStreaksTable,
    UserStreak,
    $$UserStreaksTableFilterComposer,
    $$UserStreaksTableOrderingComposer,
    $$UserStreaksTableAnnotationComposer,
    $$UserStreaksTableCreateCompanionBuilder,
    $$UserStreaksTableUpdateCompanionBuilder,
    (UserStreak, BaseReferences<_$AppDatabase, $UserStreaksTable, UserStreak>),
    UserStreak,
    PrefetchHooks Function()>;
typedef $$UserStreakHistoriesTableCreateCompanionBuilder
    = UserStreakHistoriesCompanion Function({
  Value<int> id,
  required String dateStr,
  required String actionType,
  required int xpGained,
});
typedef $$UserStreakHistoriesTableUpdateCompanionBuilder
    = UserStreakHistoriesCompanion Function({
  Value<int> id,
  Value<String> dateStr,
  Value<String> actionType,
  Value<int> xpGained,
});

class $$UserStreakHistoriesTableFilterComposer
    extends Composer<_$AppDatabase, $UserStreakHistoriesTable> {
  $$UserStreakHistoriesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dateStr => $composableBuilder(
      column: $table.dateStr, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get actionType => $composableBuilder(
      column: $table.actionType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get xpGained => $composableBuilder(
      column: $table.xpGained, builder: (column) => ColumnFilters(column));
}

class $$UserStreakHistoriesTableOrderingComposer
    extends Composer<_$AppDatabase, $UserStreakHistoriesTable> {
  $$UserStreakHistoriesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dateStr => $composableBuilder(
      column: $table.dateStr, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get actionType => $composableBuilder(
      column: $table.actionType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get xpGained => $composableBuilder(
      column: $table.xpGained, builder: (column) => ColumnOrderings(column));
}

class $$UserStreakHistoriesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserStreakHistoriesTable> {
  $$UserStreakHistoriesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get dateStr =>
      $composableBuilder(column: $table.dateStr, builder: (column) => column);

  GeneratedColumn<String> get actionType => $composableBuilder(
      column: $table.actionType, builder: (column) => column);

  GeneratedColumn<int> get xpGained =>
      $composableBuilder(column: $table.xpGained, builder: (column) => column);
}

class $$UserStreakHistoriesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UserStreakHistoriesTable,
    UserStreakHistory,
    $$UserStreakHistoriesTableFilterComposer,
    $$UserStreakHistoriesTableOrderingComposer,
    $$UserStreakHistoriesTableAnnotationComposer,
    $$UserStreakHistoriesTableCreateCompanionBuilder,
    $$UserStreakHistoriesTableUpdateCompanionBuilder,
    (
      UserStreakHistory,
      BaseReferences<_$AppDatabase, $UserStreakHistoriesTable,
          UserStreakHistory>
    ),
    UserStreakHistory,
    PrefetchHooks Function()> {
  $$UserStreakHistoriesTableTableManager(
      _$AppDatabase db, $UserStreakHistoriesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserStreakHistoriesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserStreakHistoriesTableOrderingComposer(
                  $db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserStreakHistoriesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> dateStr = const Value.absent(),
            Value<String> actionType = const Value.absent(),
            Value<int> xpGained = const Value.absent(),
          }) =>
              UserStreakHistoriesCompanion(
            id: id,
            dateStr: dateStr,
            actionType: actionType,
            xpGained: xpGained,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String dateStr,
            required String actionType,
            required int xpGained,
          }) =>
              UserStreakHistoriesCompanion.insert(
            id: id,
            dateStr: dateStr,
            actionType: actionType,
            xpGained: xpGained,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$UserStreakHistoriesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UserStreakHistoriesTable,
    UserStreakHistory,
    $$UserStreakHistoriesTableFilterComposer,
    $$UserStreakHistoriesTableOrderingComposer,
    $$UserStreakHistoriesTableAnnotationComposer,
    $$UserStreakHistoriesTableCreateCompanionBuilder,
    $$UserStreakHistoriesTableUpdateCompanionBuilder,
    (
      UserStreakHistory,
      BaseReferences<_$AppDatabase, $UserStreakHistoriesTable,
          UserStreakHistory>
    ),
    UserStreakHistory,
    PrefetchHooks Function()>;
typedef $$StreakGapDaysTableCreateCompanionBuilder = StreakGapDaysCompanion
    Function({
  required String dateStr,
  Value<bool> isRepaired,
  Value<int> rowid,
});
typedef $$StreakGapDaysTableUpdateCompanionBuilder = StreakGapDaysCompanion
    Function({
  Value<String> dateStr,
  Value<bool> isRepaired,
  Value<int> rowid,
});

class $$StreakGapDaysTableFilterComposer
    extends Composer<_$AppDatabase, $StreakGapDaysTable> {
  $$StreakGapDaysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get dateStr => $composableBuilder(
      column: $table.dateStr, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isRepaired => $composableBuilder(
      column: $table.isRepaired, builder: (column) => ColumnFilters(column));
}

class $$StreakGapDaysTableOrderingComposer
    extends Composer<_$AppDatabase, $StreakGapDaysTable> {
  $$StreakGapDaysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get dateStr => $composableBuilder(
      column: $table.dateStr, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isRepaired => $composableBuilder(
      column: $table.isRepaired, builder: (column) => ColumnOrderings(column));
}

class $$StreakGapDaysTableAnnotationComposer
    extends Composer<_$AppDatabase, $StreakGapDaysTable> {
  $$StreakGapDaysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get dateStr =>
      $composableBuilder(column: $table.dateStr, builder: (column) => column);

  GeneratedColumn<bool> get isRepaired => $composableBuilder(
      column: $table.isRepaired, builder: (column) => column);
}

class $$StreakGapDaysTableTableManager extends RootTableManager<
    _$AppDatabase,
    $StreakGapDaysTable,
    StreakGapDay,
    $$StreakGapDaysTableFilterComposer,
    $$StreakGapDaysTableOrderingComposer,
    $$StreakGapDaysTableAnnotationComposer,
    $$StreakGapDaysTableCreateCompanionBuilder,
    $$StreakGapDaysTableUpdateCompanionBuilder,
    (
      StreakGapDay,
      BaseReferences<_$AppDatabase, $StreakGapDaysTable, StreakGapDay>
    ),
    StreakGapDay,
    PrefetchHooks Function()> {
  $$StreakGapDaysTableTableManager(_$AppDatabase db, $StreakGapDaysTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StreakGapDaysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StreakGapDaysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StreakGapDaysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> dateStr = const Value.absent(),
            Value<bool> isRepaired = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              StreakGapDaysCompanion(
            dateStr: dateStr,
            isRepaired: isRepaired,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String dateStr,
            Value<bool> isRepaired = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              StreakGapDaysCompanion.insert(
            dateStr: dateStr,
            isRepaired: isRepaired,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$StreakGapDaysTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $StreakGapDaysTable,
    StreakGapDay,
    $$StreakGapDaysTableFilterComposer,
    $$StreakGapDaysTableOrderingComposer,
    $$StreakGapDaysTableAnnotationComposer,
    $$StreakGapDaysTableCreateCompanionBuilder,
    $$StreakGapDaysTableUpdateCompanionBuilder,
    (
      StreakGapDay,
      BaseReferences<_$AppDatabase, $StreakGapDaysTable, StreakGapDay>
    ),
    StreakGapDay,
    PrefetchHooks Function()>;
typedef $$UnlockedBadgesTableCreateCompanionBuilder = UnlockedBadgesCompanion
    Function({
  required String badgeId,
  Value<DateTime> unlockedAt,
  Value<String> category,
  Value<int> rowid,
});
typedef $$UnlockedBadgesTableUpdateCompanionBuilder = UnlockedBadgesCompanion
    Function({
  Value<String> badgeId,
  Value<DateTime> unlockedAt,
  Value<String> category,
  Value<int> rowid,
});

class $$UnlockedBadgesTableFilterComposer
    extends Composer<_$AppDatabase, $UnlockedBadgesTable> {
  $$UnlockedBadgesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get badgeId => $composableBuilder(
      column: $table.badgeId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get unlockedAt => $composableBuilder(
      column: $table.unlockedAt, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnFilters(column));
}

class $$UnlockedBadgesTableOrderingComposer
    extends Composer<_$AppDatabase, $UnlockedBadgesTable> {
  $$UnlockedBadgesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get badgeId => $composableBuilder(
      column: $table.badgeId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get unlockedAt => $composableBuilder(
      column: $table.unlockedAt, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get category => $composableBuilder(
      column: $table.category, builder: (column) => ColumnOrderings(column));
}

class $$UnlockedBadgesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UnlockedBadgesTable> {
  $$UnlockedBadgesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get badgeId =>
      $composableBuilder(column: $table.badgeId, builder: (column) => column);

  GeneratedColumn<DateTime> get unlockedAt => $composableBuilder(
      column: $table.unlockedAt, builder: (column) => column);

  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);
}

class $$UnlockedBadgesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UnlockedBadgesTable,
    UnlockedBadge,
    $$UnlockedBadgesTableFilterComposer,
    $$UnlockedBadgesTableOrderingComposer,
    $$UnlockedBadgesTableAnnotationComposer,
    $$UnlockedBadgesTableCreateCompanionBuilder,
    $$UnlockedBadgesTableUpdateCompanionBuilder,
    (
      UnlockedBadge,
      BaseReferences<_$AppDatabase, $UnlockedBadgesTable, UnlockedBadge>
    ),
    UnlockedBadge,
    PrefetchHooks Function()> {
  $$UnlockedBadgesTableTableManager(
      _$AppDatabase db, $UnlockedBadgesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UnlockedBadgesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UnlockedBadgesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UnlockedBadgesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> badgeId = const Value.absent(),
            Value<DateTime> unlockedAt = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UnlockedBadgesCompanion(
            badgeId: badgeId,
            unlockedAt: unlockedAt,
            category: category,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String badgeId,
            Value<DateTime> unlockedAt = const Value.absent(),
            Value<String> category = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              UnlockedBadgesCompanion.insert(
            badgeId: badgeId,
            unlockedAt: unlockedAt,
            category: category,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$UnlockedBadgesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UnlockedBadgesTable,
    UnlockedBadge,
    $$UnlockedBadgesTableFilterComposer,
    $$UnlockedBadgesTableOrderingComposer,
    $$UnlockedBadgesTableAnnotationComposer,
    $$UnlockedBadgesTableCreateCompanionBuilder,
    $$UnlockedBadgesTableUpdateCompanionBuilder,
    (
      UnlockedBadge,
      BaseReferences<_$AppDatabase, $UnlockedBadgesTable, UnlockedBadge>
    ),
    UnlockedBadge,
    PrefetchHooks Function()>;
typedef $$UserProfilesTableCreateCompanionBuilder = UserProfilesCompanion
    Function({
  Value<int> id,
  Value<String> userName,
  Value<String> avatar,
  Value<int> dailyGoalMinutes,
  Value<int> dailyZikirTarget,
  Value<String> themeMode,
  Value<double> soundVolume,
  Value<bool> hapticEnabled,
});
typedef $$UserProfilesTableUpdateCompanionBuilder = UserProfilesCompanion
    Function({
  Value<int> id,
  Value<String> userName,
  Value<String> avatar,
  Value<int> dailyGoalMinutes,
  Value<int> dailyZikirTarget,
  Value<String> themeMode,
  Value<double> soundVolume,
  Value<bool> hapticEnabled,
});

class $$UserProfilesTableFilterComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get userName => $composableBuilder(
      column: $table.userName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get avatar => $composableBuilder(
      column: $table.avatar, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get dailyGoalMinutes => $composableBuilder(
      column: $table.dailyGoalMinutes,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get dailyZikirTarget => $composableBuilder(
      column: $table.dailyZikirTarget,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get themeMode => $composableBuilder(
      column: $table.themeMode, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get soundVolume => $composableBuilder(
      column: $table.soundVolume, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get hapticEnabled => $composableBuilder(
      column: $table.hapticEnabled, builder: (column) => ColumnFilters(column));
}

class $$UserProfilesTableOrderingComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get userName => $composableBuilder(
      column: $table.userName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get avatar => $composableBuilder(
      column: $table.avatar, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get dailyGoalMinutes => $composableBuilder(
      column: $table.dailyGoalMinutes,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get dailyZikirTarget => $composableBuilder(
      column: $table.dailyZikirTarget,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get themeMode => $composableBuilder(
      column: $table.themeMode, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get soundVolume => $composableBuilder(
      column: $table.soundVolume, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get hapticEnabled => $composableBuilder(
      column: $table.hapticEnabled,
      builder: (column) => ColumnOrderings(column));
}

class $$UserProfilesTableAnnotationComposer
    extends Composer<_$AppDatabase, $UserProfilesTable> {
  $$UserProfilesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userName =>
      $composableBuilder(column: $table.userName, builder: (column) => column);

  GeneratedColumn<String> get avatar =>
      $composableBuilder(column: $table.avatar, builder: (column) => column);

  GeneratedColumn<int> get dailyGoalMinutes => $composableBuilder(
      column: $table.dailyGoalMinutes, builder: (column) => column);

  GeneratedColumn<int> get dailyZikirTarget => $composableBuilder(
      column: $table.dailyZikirTarget, builder: (column) => column);

  GeneratedColumn<String> get themeMode =>
      $composableBuilder(column: $table.themeMode, builder: (column) => column);

  GeneratedColumn<double> get soundVolume => $composableBuilder(
      column: $table.soundVolume, builder: (column) => column);

  GeneratedColumn<bool> get hapticEnabled => $composableBuilder(
      column: $table.hapticEnabled, builder: (column) => column);
}

class $$UserProfilesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $UserProfilesTable,
    UserProfile,
    $$UserProfilesTableFilterComposer,
    $$UserProfilesTableOrderingComposer,
    $$UserProfilesTableAnnotationComposer,
    $$UserProfilesTableCreateCompanionBuilder,
    $$UserProfilesTableUpdateCompanionBuilder,
    (
      UserProfile,
      BaseReferences<_$AppDatabase, $UserProfilesTable, UserProfile>
    ),
    UserProfile,
    PrefetchHooks Function()> {
  $$UserProfilesTableTableManager(_$AppDatabase db, $UserProfilesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$UserProfilesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$UserProfilesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$UserProfilesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> userName = const Value.absent(),
            Value<String> avatar = const Value.absent(),
            Value<int> dailyGoalMinutes = const Value.absent(),
            Value<int> dailyZikirTarget = const Value.absent(),
            Value<String> themeMode = const Value.absent(),
            Value<double> soundVolume = const Value.absent(),
            Value<bool> hapticEnabled = const Value.absent(),
          }) =>
              UserProfilesCompanion(
            id: id,
            userName: userName,
            avatar: avatar,
            dailyGoalMinutes: dailyGoalMinutes,
            dailyZikirTarget: dailyZikirTarget,
            themeMode: themeMode,
            soundVolume: soundVolume,
            hapticEnabled: hapticEnabled,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> userName = const Value.absent(),
            Value<String> avatar = const Value.absent(),
            Value<int> dailyGoalMinutes = const Value.absent(),
            Value<int> dailyZikirTarget = const Value.absent(),
            Value<String> themeMode = const Value.absent(),
            Value<double> soundVolume = const Value.absent(),
            Value<bool> hapticEnabled = const Value.absent(),
          }) =>
              UserProfilesCompanion.insert(
            id: id,
            userName: userName,
            avatar: avatar,
            dailyGoalMinutes: dailyGoalMinutes,
            dailyZikirTarget: dailyZikirTarget,
            themeMode: themeMode,
            soundVolume: soundVolume,
            hapticEnabled: hapticEnabled,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$UserProfilesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $UserProfilesTable,
    UserProfile,
    $$UserProfilesTableFilterComposer,
    $$UserProfilesTableOrderingComposer,
    $$UserProfilesTableAnnotationComposer,
    $$UserProfilesTableCreateCompanionBuilder,
    $$UserProfilesTableUpdateCompanionBuilder,
    (
      UserProfile,
      BaseReferences<_$AppDatabase, $UserProfilesTable, UserProfile>
    ),
    UserProfile,
    PrefetchHooks Function()>;
typedef $$MemorizationPlansTableCreateCompanionBuilder
    = MemorizationPlansCompanion Function({
  Value<int> pageId,
  Value<int?> surahId,
  required DateTime scheduledReviewDate,
  Value<DateTime?> lastReviewedDate,
  Value<int> state,
  Value<int> timesReviewed,
  Value<double> easeFactor,
  Value<int> intervalDays,
});
typedef $$MemorizationPlansTableUpdateCompanionBuilder
    = MemorizationPlansCompanion Function({
  Value<int> pageId,
  Value<int?> surahId,
  Value<DateTime> scheduledReviewDate,
  Value<DateTime?> lastReviewedDate,
  Value<int> state,
  Value<int> timesReviewed,
  Value<double> easeFactor,
  Value<int> intervalDays,
});

class $$MemorizationPlansTableFilterComposer
    extends Composer<_$AppDatabase, $MemorizationPlansTable> {
  $$MemorizationPlansTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get pageId => $composableBuilder(
      column: $table.pageId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get surahId => $composableBuilder(
      column: $table.surahId, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get scheduledReviewDate => $composableBuilder(
      column: $table.scheduledReviewDate,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get lastReviewedDate => $composableBuilder(
      column: $table.lastReviewedDate,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get timesReviewed => $composableBuilder(
      column: $table.timesReviewed, builder: (column) => ColumnFilters(column));

  ColumnFilters<double> get easeFactor => $composableBuilder(
      column: $table.easeFactor, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get intervalDays => $composableBuilder(
      column: $table.intervalDays, builder: (column) => ColumnFilters(column));
}

class $$MemorizationPlansTableOrderingComposer
    extends Composer<_$AppDatabase, $MemorizationPlansTable> {
  $$MemorizationPlansTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get pageId => $composableBuilder(
      column: $table.pageId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get surahId => $composableBuilder(
      column: $table.surahId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get scheduledReviewDate => $composableBuilder(
      column: $table.scheduledReviewDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get lastReviewedDate => $composableBuilder(
      column: $table.lastReviewedDate,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get state => $composableBuilder(
      column: $table.state, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get timesReviewed => $composableBuilder(
      column: $table.timesReviewed,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<double> get easeFactor => $composableBuilder(
      column: $table.easeFactor, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get intervalDays => $composableBuilder(
      column: $table.intervalDays,
      builder: (column) => ColumnOrderings(column));
}

class $$MemorizationPlansTableAnnotationComposer
    extends Composer<_$AppDatabase, $MemorizationPlansTable> {
  $$MemorizationPlansTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get pageId =>
      $composableBuilder(column: $table.pageId, builder: (column) => column);

  GeneratedColumn<int> get surahId =>
      $composableBuilder(column: $table.surahId, builder: (column) => column);

  GeneratedColumn<DateTime> get scheduledReviewDate => $composableBuilder(
      column: $table.scheduledReviewDate, builder: (column) => column);

  GeneratedColumn<DateTime> get lastReviewedDate => $composableBuilder(
      column: $table.lastReviewedDate, builder: (column) => column);

  GeneratedColumn<int> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get timesReviewed => $composableBuilder(
      column: $table.timesReviewed, builder: (column) => column);

  GeneratedColumn<double> get easeFactor => $composableBuilder(
      column: $table.easeFactor, builder: (column) => column);

  GeneratedColumn<int> get intervalDays => $composableBuilder(
      column: $table.intervalDays, builder: (column) => column);
}

class $$MemorizationPlansTableTableManager extends RootTableManager<
    _$AppDatabase,
    $MemorizationPlansTable,
    MemorizationPlan,
    $$MemorizationPlansTableFilterComposer,
    $$MemorizationPlansTableOrderingComposer,
    $$MemorizationPlansTableAnnotationComposer,
    $$MemorizationPlansTableCreateCompanionBuilder,
    $$MemorizationPlansTableUpdateCompanionBuilder,
    (
      MemorizationPlan,
      BaseReferences<_$AppDatabase, $MemorizationPlansTable, MemorizationPlan>
    ),
    MemorizationPlan,
    PrefetchHooks Function()> {
  $$MemorizationPlansTableTableManager(
      _$AppDatabase db, $MemorizationPlansTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MemorizationPlansTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MemorizationPlansTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MemorizationPlansTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> pageId = const Value.absent(),
            Value<int?> surahId = const Value.absent(),
            Value<DateTime> scheduledReviewDate = const Value.absent(),
            Value<DateTime?> lastReviewedDate = const Value.absent(),
            Value<int> state = const Value.absent(),
            Value<int> timesReviewed = const Value.absent(),
            Value<double> easeFactor = const Value.absent(),
            Value<int> intervalDays = const Value.absent(),
          }) =>
              MemorizationPlansCompanion(
            pageId: pageId,
            surahId: surahId,
            scheduledReviewDate: scheduledReviewDate,
            lastReviewedDate: lastReviewedDate,
            state: state,
            timesReviewed: timesReviewed,
            easeFactor: easeFactor,
            intervalDays: intervalDays,
          ),
          createCompanionCallback: ({
            Value<int> pageId = const Value.absent(),
            Value<int?> surahId = const Value.absent(),
            required DateTime scheduledReviewDate,
            Value<DateTime?> lastReviewedDate = const Value.absent(),
            Value<int> state = const Value.absent(),
            Value<int> timesReviewed = const Value.absent(),
            Value<double> easeFactor = const Value.absent(),
            Value<int> intervalDays = const Value.absent(),
          }) =>
              MemorizationPlansCompanion.insert(
            pageId: pageId,
            surahId: surahId,
            scheduledReviewDate: scheduledReviewDate,
            lastReviewedDate: lastReviewedDate,
            state: state,
            timesReviewed: timesReviewed,
            easeFactor: easeFactor,
            intervalDays: intervalDays,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$MemorizationPlansTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $MemorizationPlansTable,
    MemorizationPlan,
    $$MemorizationPlansTableFilterComposer,
    $$MemorizationPlansTableOrderingComposer,
    $$MemorizationPlansTableAnnotationComposer,
    $$MemorizationPlansTableCreateCompanionBuilder,
    $$MemorizationPlansTableUpdateCompanionBuilder,
    (
      MemorizationPlan,
      BaseReferences<_$AppDatabase, $MemorizationPlansTable, MemorizationPlan>
    ),
    MemorizationPlan,
    PrefetchHooks Function()>;
typedef $$HafizlikDailyLogsTableCreateCompanionBuilder
    = HafizlikDailyLogsCompanion Function({
  required String dateStr,
  Value<bool> isHamDone,
  Value<bool> isPismisDone,
  Value<bool> isHasDone,
  Value<int> streakShieldsUsed,
  Value<bool> isAsgariVirdDone,
  Value<int> asgariVirdRepeats,
  Value<int> rowid,
});
typedef $$HafizlikDailyLogsTableUpdateCompanionBuilder
    = HafizlikDailyLogsCompanion Function({
  Value<String> dateStr,
  Value<bool> isHamDone,
  Value<bool> isPismisDone,
  Value<bool> isHasDone,
  Value<int> streakShieldsUsed,
  Value<bool> isAsgariVirdDone,
  Value<int> asgariVirdRepeats,
  Value<int> rowid,
});

class $$HafizlikDailyLogsTableFilterComposer
    extends Composer<_$AppDatabase, $HafizlikDailyLogsTable> {
  $$HafizlikDailyLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get dateStr => $composableBuilder(
      column: $table.dateStr, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isHamDone => $composableBuilder(
      column: $table.isHamDone, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isPismisDone => $composableBuilder(
      column: $table.isPismisDone, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isHasDone => $composableBuilder(
      column: $table.isHasDone, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get streakShieldsUsed => $composableBuilder(
      column: $table.streakShieldsUsed,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isAsgariVirdDone => $composableBuilder(
      column: $table.isAsgariVirdDone,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get asgariVirdRepeats => $composableBuilder(
      column: $table.asgariVirdRepeats,
      builder: (column) => ColumnFilters(column));
}

class $$HafizlikDailyLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $HafizlikDailyLogsTable> {
  $$HafizlikDailyLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get dateStr => $composableBuilder(
      column: $table.dateStr, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isHamDone => $composableBuilder(
      column: $table.isHamDone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isPismisDone => $composableBuilder(
      column: $table.isPismisDone,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isHasDone => $composableBuilder(
      column: $table.isHasDone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get streakShieldsUsed => $composableBuilder(
      column: $table.streakShieldsUsed,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isAsgariVirdDone => $composableBuilder(
      column: $table.isAsgariVirdDone,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get asgariVirdRepeats => $composableBuilder(
      column: $table.asgariVirdRepeats,
      builder: (column) => ColumnOrderings(column));
}

class $$HafizlikDailyLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HafizlikDailyLogsTable> {
  $$HafizlikDailyLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get dateStr =>
      $composableBuilder(column: $table.dateStr, builder: (column) => column);

  GeneratedColumn<bool> get isHamDone =>
      $composableBuilder(column: $table.isHamDone, builder: (column) => column);

  GeneratedColumn<bool> get isPismisDone => $composableBuilder(
      column: $table.isPismisDone, builder: (column) => column);

  GeneratedColumn<bool> get isHasDone =>
      $composableBuilder(column: $table.isHasDone, builder: (column) => column);

  GeneratedColumn<int> get streakShieldsUsed => $composableBuilder(
      column: $table.streakShieldsUsed, builder: (column) => column);

  GeneratedColumn<bool> get isAsgariVirdDone => $composableBuilder(
      column: $table.isAsgariVirdDone, builder: (column) => column);

  GeneratedColumn<int> get asgariVirdRepeats => $composableBuilder(
      column: $table.asgariVirdRepeats, builder: (column) => column);
}

class $$HafizlikDailyLogsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $HafizlikDailyLogsTable,
    HafizlikDailyLog,
    $$HafizlikDailyLogsTableFilterComposer,
    $$HafizlikDailyLogsTableOrderingComposer,
    $$HafizlikDailyLogsTableAnnotationComposer,
    $$HafizlikDailyLogsTableCreateCompanionBuilder,
    $$HafizlikDailyLogsTableUpdateCompanionBuilder,
    (
      HafizlikDailyLog,
      BaseReferences<_$AppDatabase, $HafizlikDailyLogsTable, HafizlikDailyLog>
    ),
    HafizlikDailyLog,
    PrefetchHooks Function()> {
  $$HafizlikDailyLogsTableTableManager(
      _$AppDatabase db, $HafizlikDailyLogsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HafizlikDailyLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HafizlikDailyLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HafizlikDailyLogsTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> dateStr = const Value.absent(),
            Value<bool> isHamDone = const Value.absent(),
            Value<bool> isPismisDone = const Value.absent(),
            Value<bool> isHasDone = const Value.absent(),
            Value<int> streakShieldsUsed = const Value.absent(),
            Value<bool> isAsgariVirdDone = const Value.absent(),
            Value<int> asgariVirdRepeats = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              HafizlikDailyLogsCompanion(
            dateStr: dateStr,
            isHamDone: isHamDone,
            isPismisDone: isPismisDone,
            isHasDone: isHasDone,
            streakShieldsUsed: streakShieldsUsed,
            isAsgariVirdDone: isAsgariVirdDone,
            asgariVirdRepeats: asgariVirdRepeats,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String dateStr,
            Value<bool> isHamDone = const Value.absent(),
            Value<bool> isPismisDone = const Value.absent(),
            Value<bool> isHasDone = const Value.absent(),
            Value<int> streakShieldsUsed = const Value.absent(),
            Value<bool> isAsgariVirdDone = const Value.absent(),
            Value<int> asgariVirdRepeats = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              HafizlikDailyLogsCompanion.insert(
            dateStr: dateStr,
            isHamDone: isHamDone,
            isPismisDone: isPismisDone,
            isHasDone: isHasDone,
            streakShieldsUsed: streakShieldsUsed,
            isAsgariVirdDone: isAsgariVirdDone,
            asgariVirdRepeats: asgariVirdRepeats,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$HafizlikDailyLogsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $HafizlikDailyLogsTable,
    HafizlikDailyLog,
    $$HafizlikDailyLogsTableFilterComposer,
    $$HafizlikDailyLogsTableOrderingComposer,
    $$HafizlikDailyLogsTableAnnotationComposer,
    $$HafizlikDailyLogsTableCreateCompanionBuilder,
    $$HafizlikDailyLogsTableUpdateCompanionBuilder,
    (
      HafizlikDailyLog,
      BaseReferences<_$AppDatabase, $HafizlikDailyLogsTable, HafizlikDailyLog>
    ),
    HafizlikDailyLog,
    PrefetchHooks Function()>;
typedef $$KazaPrayersTableCreateCompanionBuilder = KazaPrayersCompanion
    Function({
  Value<int> id,
  required String prayerType,
  Value<int> totalCount,
  Value<int> completedCount,
});
typedef $$KazaPrayersTableUpdateCompanionBuilder = KazaPrayersCompanion
    Function({
  Value<int> id,
  Value<String> prayerType,
  Value<int> totalCount,
  Value<int> completedCount,
});

class $$KazaPrayersTableFilterComposer
    extends Composer<_$AppDatabase, $KazaPrayersTable> {
  $$KazaPrayersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get prayerType => $composableBuilder(
      column: $table.prayerType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalCount => $composableBuilder(
      column: $table.totalCount, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get completedCount => $composableBuilder(
      column: $table.completedCount,
      builder: (column) => ColumnFilters(column));
}

class $$KazaPrayersTableOrderingComposer
    extends Composer<_$AppDatabase, $KazaPrayersTable> {
  $$KazaPrayersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get prayerType => $composableBuilder(
      column: $table.prayerType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalCount => $composableBuilder(
      column: $table.totalCount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get completedCount => $composableBuilder(
      column: $table.completedCount,
      builder: (column) => ColumnOrderings(column));
}

class $$KazaPrayersTableAnnotationComposer
    extends Composer<_$AppDatabase, $KazaPrayersTable> {
  $$KazaPrayersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get prayerType => $composableBuilder(
      column: $table.prayerType, builder: (column) => column);

  GeneratedColumn<int> get totalCount => $composableBuilder(
      column: $table.totalCount, builder: (column) => column);

  GeneratedColumn<int> get completedCount => $composableBuilder(
      column: $table.completedCount, builder: (column) => column);
}

class $$KazaPrayersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $KazaPrayersTable,
    KazaPrayer,
    $$KazaPrayersTableFilterComposer,
    $$KazaPrayersTableOrderingComposer,
    $$KazaPrayersTableAnnotationComposer,
    $$KazaPrayersTableCreateCompanionBuilder,
    $$KazaPrayersTableUpdateCompanionBuilder,
    (KazaPrayer, BaseReferences<_$AppDatabase, $KazaPrayersTable, KazaPrayer>),
    KazaPrayer,
    PrefetchHooks Function()> {
  $$KazaPrayersTableTableManager(_$AppDatabase db, $KazaPrayersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KazaPrayersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KazaPrayersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KazaPrayersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> prayerType = const Value.absent(),
            Value<int> totalCount = const Value.absent(),
            Value<int> completedCount = const Value.absent(),
          }) =>
              KazaPrayersCompanion(
            id: id,
            prayerType: prayerType,
            totalCount: totalCount,
            completedCount: completedCount,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String prayerType,
            Value<int> totalCount = const Value.absent(),
            Value<int> completedCount = const Value.absent(),
          }) =>
              KazaPrayersCompanion.insert(
            id: id,
            prayerType: prayerType,
            totalCount: totalCount,
            completedCount: completedCount,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$KazaPrayersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $KazaPrayersTable,
    KazaPrayer,
    $$KazaPrayersTableFilterComposer,
    $$KazaPrayersTableOrderingComposer,
    $$KazaPrayersTableAnnotationComposer,
    $$KazaPrayersTableCreateCompanionBuilder,
    $$KazaPrayersTableUpdateCompanionBuilder,
    (KazaPrayer, BaseReferences<_$AppDatabase, $KazaPrayersTable, KazaPrayer>),
    KazaPrayer,
    PrefetchHooks Function()>;
typedef $$PrayerAnswerLogsTableCreateCompanionBuilder
    = PrayerAnswerLogsCompanion Function({
  Value<int> id,
  required String prayerType,
  required String dateStr,
  required bool isPerformed,
});
typedef $$PrayerAnswerLogsTableUpdateCompanionBuilder
    = PrayerAnswerLogsCompanion Function({
  Value<int> id,
  Value<String> prayerType,
  Value<String> dateStr,
  Value<bool> isPerformed,
});

class $$PrayerAnswerLogsTableFilterComposer
    extends Composer<_$AppDatabase, $PrayerAnswerLogsTable> {
  $$PrayerAnswerLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get prayerType => $composableBuilder(
      column: $table.prayerType, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get dateStr => $composableBuilder(
      column: $table.dateStr, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isPerformed => $composableBuilder(
      column: $table.isPerformed, builder: (column) => ColumnFilters(column));
}

class $$PrayerAnswerLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $PrayerAnswerLogsTable> {
  $$PrayerAnswerLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get prayerType => $composableBuilder(
      column: $table.prayerType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get dateStr => $composableBuilder(
      column: $table.dateStr, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isPerformed => $composableBuilder(
      column: $table.isPerformed, builder: (column) => ColumnOrderings(column));
}

class $$PrayerAnswerLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PrayerAnswerLogsTable> {
  $$PrayerAnswerLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get prayerType => $composableBuilder(
      column: $table.prayerType, builder: (column) => column);

  GeneratedColumn<String> get dateStr =>
      $composableBuilder(column: $table.dateStr, builder: (column) => column);

  GeneratedColumn<bool> get isPerformed => $composableBuilder(
      column: $table.isPerformed, builder: (column) => column);
}

class $$PrayerAnswerLogsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $PrayerAnswerLogsTable,
    PrayerAnswerLog,
    $$PrayerAnswerLogsTableFilterComposer,
    $$PrayerAnswerLogsTableOrderingComposer,
    $$PrayerAnswerLogsTableAnnotationComposer,
    $$PrayerAnswerLogsTableCreateCompanionBuilder,
    $$PrayerAnswerLogsTableUpdateCompanionBuilder,
    (
      PrayerAnswerLog,
      BaseReferences<_$AppDatabase, $PrayerAnswerLogsTable, PrayerAnswerLog>
    ),
    PrayerAnswerLog,
    PrefetchHooks Function()> {
  $$PrayerAnswerLogsTableTableManager(
      _$AppDatabase db, $PrayerAnswerLogsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PrayerAnswerLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PrayerAnswerLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PrayerAnswerLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> prayerType = const Value.absent(),
            Value<String> dateStr = const Value.absent(),
            Value<bool> isPerformed = const Value.absent(),
          }) =>
              PrayerAnswerLogsCompanion(
            id: id,
            prayerType: prayerType,
            dateStr: dateStr,
            isPerformed: isPerformed,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String prayerType,
            required String dateStr,
            required bool isPerformed,
          }) =>
              PrayerAnswerLogsCompanion.insert(
            id: id,
            prayerType: prayerType,
            dateStr: dateStr,
            isPerformed: isPerformed,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$PrayerAnswerLogsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $PrayerAnswerLogsTable,
    PrayerAnswerLog,
    $$PrayerAnswerLogsTableFilterComposer,
    $$PrayerAnswerLogsTableOrderingComposer,
    $$PrayerAnswerLogsTableAnnotationComposer,
    $$PrayerAnswerLogsTableCreateCompanionBuilder,
    $$PrayerAnswerLogsTableUpdateCompanionBuilder,
    (
      PrayerAnswerLog,
      BaseReferences<_$AppDatabase, $PrayerAnswerLogsTable, PrayerAnswerLog>
    ),
    PrayerAnswerLog,
    PrefetchHooks Function()>;
typedef $$KazaMeltLogsTableCreateCompanionBuilder = KazaMeltLogsCompanion
    Function({
  Value<int> id,
  required String prayerType,
  required int meltAmount,
  Value<DateTime> timestamp,
});
typedef $$KazaMeltLogsTableUpdateCompanionBuilder = KazaMeltLogsCompanion
    Function({
  Value<int> id,
  Value<String> prayerType,
  Value<int> meltAmount,
  Value<DateTime> timestamp,
});

class $$KazaMeltLogsTableFilterComposer
    extends Composer<_$AppDatabase, $KazaMeltLogsTable> {
  $$KazaMeltLogsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get prayerType => $composableBuilder(
      column: $table.prayerType, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get meltAmount => $composableBuilder(
      column: $table.meltAmount, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnFilters(column));
}

class $$KazaMeltLogsTableOrderingComposer
    extends Composer<_$AppDatabase, $KazaMeltLogsTable> {
  $$KazaMeltLogsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get prayerType => $composableBuilder(
      column: $table.prayerType, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get meltAmount => $composableBuilder(
      column: $table.meltAmount, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get timestamp => $composableBuilder(
      column: $table.timestamp, builder: (column) => ColumnOrderings(column));
}

class $$KazaMeltLogsTableAnnotationComposer
    extends Composer<_$AppDatabase, $KazaMeltLogsTable> {
  $$KazaMeltLogsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get prayerType => $composableBuilder(
      column: $table.prayerType, builder: (column) => column);

  GeneratedColumn<int> get meltAmount => $composableBuilder(
      column: $table.meltAmount, builder: (column) => column);

  GeneratedColumn<DateTime> get timestamp =>
      $composableBuilder(column: $table.timestamp, builder: (column) => column);
}

class $$KazaMeltLogsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $KazaMeltLogsTable,
    KazaMeltLog,
    $$KazaMeltLogsTableFilterComposer,
    $$KazaMeltLogsTableOrderingComposer,
    $$KazaMeltLogsTableAnnotationComposer,
    $$KazaMeltLogsTableCreateCompanionBuilder,
    $$KazaMeltLogsTableUpdateCompanionBuilder,
    (
      KazaMeltLog,
      BaseReferences<_$AppDatabase, $KazaMeltLogsTable, KazaMeltLog>
    ),
    KazaMeltLog,
    PrefetchHooks Function()> {
  $$KazaMeltLogsTableTableManager(_$AppDatabase db, $KazaMeltLogsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$KazaMeltLogsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$KazaMeltLogsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$KazaMeltLogsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> prayerType = const Value.absent(),
            Value<int> meltAmount = const Value.absent(),
            Value<DateTime> timestamp = const Value.absent(),
          }) =>
              KazaMeltLogsCompanion(
            id: id,
            prayerType: prayerType,
            meltAmount: meltAmount,
            timestamp: timestamp,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String prayerType,
            required int meltAmount,
            Value<DateTime> timestamp = const Value.absent(),
          }) =>
              KazaMeltLogsCompanion.insert(
            id: id,
            prayerType: prayerType,
            meltAmount: meltAmount,
            timestamp: timestamp,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$KazaMeltLogsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $KazaMeltLogsTable,
    KazaMeltLog,
    $$KazaMeltLogsTableFilterComposer,
    $$KazaMeltLogsTableOrderingComposer,
    $$KazaMeltLogsTableAnnotationComposer,
    $$KazaMeltLogsTableCreateCompanionBuilder,
    $$KazaMeltLogsTableUpdateCompanionBuilder,
    (
      KazaMeltLog,
      BaseReferences<_$AppDatabase, $KazaMeltLogsTable, KazaMeltLog>
    ),
    KazaMeltLog,
    PrefetchHooks Function()>;
typedef $$HatimsTableCreateCompanionBuilder = HatimsCompanion Function({
  required String id,
  required String title,
  Value<DateTime?> targetDate,
  Value<int> totalPages,
  Value<int> completedPages,
  Value<bool> isCompleted,
  Value<bool> isGroup,
  Value<DateTime> createdAt,
  Value<int> rowid,
});
typedef $$HatimsTableUpdateCompanionBuilder = HatimsCompanion Function({
  Value<String> id,
  Value<String> title,
  Value<DateTime?> targetDate,
  Value<int> totalPages,
  Value<int> completedPages,
  Value<bool> isCompleted,
  Value<bool> isGroup,
  Value<DateTime> createdAt,
  Value<int> rowid,
});

class $$HatimsTableFilterComposer
    extends Composer<_$AppDatabase, $HatimsTable> {
  $$HatimsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get targetDate => $composableBuilder(
      column: $table.targetDate, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get totalPages => $composableBuilder(
      column: $table.totalPages, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get completedPages => $composableBuilder(
      column: $table.completedPages,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isCompleted => $composableBuilder(
      column: $table.isCompleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isGroup => $composableBuilder(
      column: $table.isGroup, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnFilters(column));
}

class $$HatimsTableOrderingComposer
    extends Composer<_$AppDatabase, $HatimsTable> {
  $$HatimsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get title => $composableBuilder(
      column: $table.title, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get targetDate => $composableBuilder(
      column: $table.targetDate, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get totalPages => $composableBuilder(
      column: $table.totalPages, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get completedPages => $composableBuilder(
      column: $table.completedPages,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
      column: $table.isCompleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isGroup => $composableBuilder(
      column: $table.isGroup, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
      column: $table.createdAt, builder: (column) => ColumnOrderings(column));
}

class $$HatimsTableAnnotationComposer
    extends Composer<_$AppDatabase, $HatimsTable> {
  $$HatimsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get title =>
      $composableBuilder(column: $table.title, builder: (column) => column);

  GeneratedColumn<DateTime> get targetDate => $composableBuilder(
      column: $table.targetDate, builder: (column) => column);

  GeneratedColumn<int> get totalPages => $composableBuilder(
      column: $table.totalPages, builder: (column) => column);

  GeneratedColumn<int> get completedPages => $composableBuilder(
      column: $table.completedPages, builder: (column) => column);

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
      column: $table.isCompleted, builder: (column) => column);

  GeneratedColumn<bool> get isGroup =>
      $composableBuilder(column: $table.isGroup, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$HatimsTableTableManager extends RootTableManager<
    _$AppDatabase,
    $HatimsTable,
    Hatim,
    $$HatimsTableFilterComposer,
    $$HatimsTableOrderingComposer,
    $$HatimsTableAnnotationComposer,
    $$HatimsTableCreateCompanionBuilder,
    $$HatimsTableUpdateCompanionBuilder,
    (Hatim, BaseReferences<_$AppDatabase, $HatimsTable, Hatim>),
    Hatim,
    PrefetchHooks Function()> {
  $$HatimsTableTableManager(_$AppDatabase db, $HatimsTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HatimsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HatimsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HatimsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<String> id = const Value.absent(),
            Value<String> title = const Value.absent(),
            Value<DateTime?> targetDate = const Value.absent(),
            Value<int> totalPages = const Value.absent(),
            Value<int> completedPages = const Value.absent(),
            Value<bool> isCompleted = const Value.absent(),
            Value<bool> isGroup = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              HatimsCompanion(
            id: id,
            title: title,
            targetDate: targetDate,
            totalPages: totalPages,
            completedPages: completedPages,
            isCompleted: isCompleted,
            isGroup: isGroup,
            createdAt: createdAt,
            rowid: rowid,
          ),
          createCompanionCallback: ({
            required String id,
            required String title,
            Value<DateTime?> targetDate = const Value.absent(),
            Value<int> totalPages = const Value.absent(),
            Value<int> completedPages = const Value.absent(),
            Value<bool> isCompleted = const Value.absent(),
            Value<bool> isGroup = const Value.absent(),
            Value<DateTime> createdAt = const Value.absent(),
            Value<int> rowid = const Value.absent(),
          }) =>
              HatimsCompanion.insert(
            id: id,
            title: title,
            targetDate: targetDate,
            totalPages: totalPages,
            completedPages: completedPages,
            isCompleted: isCompleted,
            isGroup: isGroup,
            createdAt: createdAt,
            rowid: rowid,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$HatimsTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $HatimsTable,
    Hatim,
    $$HatimsTableFilterComposer,
    $$HatimsTableOrderingComposer,
    $$HatimsTableAnnotationComposer,
    $$HatimsTableCreateCompanionBuilder,
    $$HatimsTableUpdateCompanionBuilder,
    (Hatim, BaseReferences<_$AppDatabase, $HatimsTable, Hatim>),
    Hatim,
    PrefetchHooks Function()>;
typedef $$HatimCuzProgressesTableCreateCompanionBuilder
    = HatimCuzProgressesCompanion Function({
  Value<int> id,
  required String hatimId,
  required int juzNo,
  Value<bool> isCompleted,
  Value<String?> readerName,
  Value<String?> readerPhone,
  Value<DateTime?> completedAt,
});
typedef $$HatimCuzProgressesTableUpdateCompanionBuilder
    = HatimCuzProgressesCompanion Function({
  Value<int> id,
  Value<String> hatimId,
  Value<int> juzNo,
  Value<bool> isCompleted,
  Value<String?> readerName,
  Value<String?> readerPhone,
  Value<DateTime?> completedAt,
});

class $$HatimCuzProgressesTableFilterComposer
    extends Composer<_$AppDatabase, $HatimCuzProgressesTable> {
  $$HatimCuzProgressesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get hatimId => $composableBuilder(
      column: $table.hatimId, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get juzNo => $composableBuilder(
      column: $table.juzNo, builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isCompleted => $composableBuilder(
      column: $table.isCompleted, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get readerName => $composableBuilder(
      column: $table.readerName, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get readerPhone => $composableBuilder(
      column: $table.readerPhone, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnFilters(column));
}

class $$HatimCuzProgressesTableOrderingComposer
    extends Composer<_$AppDatabase, $HatimCuzProgressesTable> {
  $$HatimCuzProgressesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get hatimId => $composableBuilder(
      column: $table.hatimId, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get juzNo => $composableBuilder(
      column: $table.juzNo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isCompleted => $composableBuilder(
      column: $table.isCompleted, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get readerName => $composableBuilder(
      column: $table.readerName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get readerPhone => $composableBuilder(
      column: $table.readerPhone, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => ColumnOrderings(column));
}

class $$HatimCuzProgressesTableAnnotationComposer
    extends Composer<_$AppDatabase, $HatimCuzProgressesTable> {
  $$HatimCuzProgressesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get hatimId =>
      $composableBuilder(column: $table.hatimId, builder: (column) => column);

  GeneratedColumn<int> get juzNo =>
      $composableBuilder(column: $table.juzNo, builder: (column) => column);

  GeneratedColumn<bool> get isCompleted => $composableBuilder(
      column: $table.isCompleted, builder: (column) => column);

  GeneratedColumn<String> get readerName => $composableBuilder(
      column: $table.readerName, builder: (column) => column);

  GeneratedColumn<String> get readerPhone => $composableBuilder(
      column: $table.readerPhone, builder: (column) => column);

  GeneratedColumn<DateTime> get completedAt => $composableBuilder(
      column: $table.completedAt, builder: (column) => column);
}

class $$HatimCuzProgressesTableTableManager extends RootTableManager<
    _$AppDatabase,
    $HatimCuzProgressesTable,
    HatimCuzProgressesData,
    $$HatimCuzProgressesTableFilterComposer,
    $$HatimCuzProgressesTableOrderingComposer,
    $$HatimCuzProgressesTableAnnotationComposer,
    $$HatimCuzProgressesTableCreateCompanionBuilder,
    $$HatimCuzProgressesTableUpdateCompanionBuilder,
    (
      HatimCuzProgressesData,
      BaseReferences<_$AppDatabase, $HatimCuzProgressesTable,
          HatimCuzProgressesData>
    ),
    HatimCuzProgressesData,
    PrefetchHooks Function()> {
  $$HatimCuzProgressesTableTableManager(
      _$AppDatabase db, $HatimCuzProgressesTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$HatimCuzProgressesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$HatimCuzProgressesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$HatimCuzProgressesTableAnnotationComposer(
                  $db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> hatimId = const Value.absent(),
            Value<int> juzNo = const Value.absent(),
            Value<bool> isCompleted = const Value.absent(),
            Value<String?> readerName = const Value.absent(),
            Value<String?> readerPhone = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
          }) =>
              HatimCuzProgressesCompanion(
            id: id,
            hatimId: hatimId,
            juzNo: juzNo,
            isCompleted: isCompleted,
            readerName: readerName,
            readerPhone: readerPhone,
            completedAt: completedAt,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String hatimId,
            required int juzNo,
            Value<bool> isCompleted = const Value.absent(),
            Value<String?> readerName = const Value.absent(),
            Value<String?> readerPhone = const Value.absent(),
            Value<DateTime?> completedAt = const Value.absent(),
          }) =>
              HatimCuzProgressesCompanion.insert(
            id: id,
            hatimId: hatimId,
            juzNo: juzNo,
            isCompleted: isCompleted,
            readerName: readerName,
            readerPhone: readerPhone,
            completedAt: completedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$HatimCuzProgressesTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $HatimCuzProgressesTable,
    HatimCuzProgressesData,
    $$HatimCuzProgressesTableFilterComposer,
    $$HatimCuzProgressesTableOrderingComposer,
    $$HatimCuzProgressesTableAnnotationComposer,
    $$HatimCuzProgressesTableCreateCompanionBuilder,
    $$HatimCuzProgressesTableUpdateCompanionBuilder,
    (
      HatimCuzProgressesData,
      BaseReferences<_$AppDatabase, $HatimCuzProgressesTable,
          HatimCuzProgressesData>
    ),
    HatimCuzProgressesData,
    PrefetchHooks Function()>;
typedef $$JuzBookmarksTableCreateCompanionBuilder = JuzBookmarksCompanion
    Function({
  Value<int> juzNo,
  Value<int> lastPage,
  Value<DateTime> updatedAt,
});
typedef $$JuzBookmarksTableUpdateCompanionBuilder = JuzBookmarksCompanion
    Function({
  Value<int> juzNo,
  Value<int> lastPage,
  Value<DateTime> updatedAt,
});

class $$JuzBookmarksTableFilterComposer
    extends Composer<_$AppDatabase, $JuzBookmarksTable> {
  $$JuzBookmarksTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get juzNo => $composableBuilder(
      column: $table.juzNo, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get lastPage => $composableBuilder(
      column: $table.lastPage, builder: (column) => ColumnFilters(column));

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnFilters(column));
}

class $$JuzBookmarksTableOrderingComposer
    extends Composer<_$AppDatabase, $JuzBookmarksTable> {
  $$JuzBookmarksTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get juzNo => $composableBuilder(
      column: $table.juzNo, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get lastPage => $composableBuilder(
      column: $table.lastPage, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
      column: $table.updatedAt, builder: (column) => ColumnOrderings(column));
}

class $$JuzBookmarksTableAnnotationComposer
    extends Composer<_$AppDatabase, $JuzBookmarksTable> {
  $$JuzBookmarksTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get juzNo =>
      $composableBuilder(column: $table.juzNo, builder: (column) => column);

  GeneratedColumn<int> get lastPage =>
      $composableBuilder(column: $table.lastPage, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$JuzBookmarksTableTableManager extends RootTableManager<
    _$AppDatabase,
    $JuzBookmarksTable,
    JuzBookmark,
    $$JuzBookmarksTableFilterComposer,
    $$JuzBookmarksTableOrderingComposer,
    $$JuzBookmarksTableAnnotationComposer,
    $$JuzBookmarksTableCreateCompanionBuilder,
    $$JuzBookmarksTableUpdateCompanionBuilder,
    (
      JuzBookmark,
      BaseReferences<_$AppDatabase, $JuzBookmarksTable, JuzBookmark>
    ),
    JuzBookmark,
    PrefetchHooks Function()> {
  $$JuzBookmarksTableTableManager(_$AppDatabase db, $JuzBookmarksTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$JuzBookmarksTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$JuzBookmarksTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$JuzBookmarksTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> juzNo = const Value.absent(),
            Value<int> lastPage = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              JuzBookmarksCompanion(
            juzNo: juzNo,
            lastPage: lastPage,
            updatedAt: updatedAt,
          ),
          createCompanionCallback: ({
            Value<int> juzNo = const Value.absent(),
            Value<int> lastPage = const Value.absent(),
            Value<DateTime> updatedAt = const Value.absent(),
          }) =>
              JuzBookmarksCompanion.insert(
            juzNo: juzNo,
            lastPage: lastPage,
            updatedAt: updatedAt,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$JuzBookmarksTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $JuzBookmarksTable,
    JuzBookmark,
    $$JuzBookmarksTableFilterComposer,
    $$JuzBookmarksTableOrderingComposer,
    $$JuzBookmarksTableAnnotationComposer,
    $$JuzBookmarksTableCreateCompanionBuilder,
    $$JuzBookmarksTableUpdateCompanionBuilder,
    (
      JuzBookmark,
      BaseReferences<_$AppDatabase, $JuzBookmarksTable, JuzBookmark>
    ),
    JuzBookmark,
    PrefetchHooks Function()>;
typedef $$FardRemindersTableCreateCompanionBuilder = FardRemindersCompanion
    Function({
  Value<int> id,
  required String prayerName,
  Value<int> reminderMinutesBefore,
  Value<bool> isEnabled,
  Value<String> soundTone,
});
typedef $$FardRemindersTableUpdateCompanionBuilder = FardRemindersCompanion
    Function({
  Value<int> id,
  Value<String> prayerName,
  Value<int> reminderMinutesBefore,
  Value<bool> isEnabled,
  Value<String> soundTone,
});

class $$FardRemindersTableFilterComposer
    extends Composer<_$AppDatabase, $FardRemindersTable> {
  $$FardRemindersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get prayerName => $composableBuilder(
      column: $table.prayerName, builder: (column) => ColumnFilters(column));

  ColumnFilters<int> get reminderMinutesBefore => $composableBuilder(
      column: $table.reminderMinutesBefore,
      builder: (column) => ColumnFilters(column));

  ColumnFilters<bool> get isEnabled => $composableBuilder(
      column: $table.isEnabled, builder: (column) => ColumnFilters(column));

  ColumnFilters<String> get soundTone => $composableBuilder(
      column: $table.soundTone, builder: (column) => ColumnFilters(column));
}

class $$FardRemindersTableOrderingComposer
    extends Composer<_$AppDatabase, $FardRemindersTable> {
  $$FardRemindersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
      column: $table.id, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get prayerName => $composableBuilder(
      column: $table.prayerName, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<int> get reminderMinutesBefore => $composableBuilder(
      column: $table.reminderMinutesBefore,
      builder: (column) => ColumnOrderings(column));

  ColumnOrderings<bool> get isEnabled => $composableBuilder(
      column: $table.isEnabled, builder: (column) => ColumnOrderings(column));

  ColumnOrderings<String> get soundTone => $composableBuilder(
      column: $table.soundTone, builder: (column) => ColumnOrderings(column));
}

class $$FardRemindersTableAnnotationComposer
    extends Composer<_$AppDatabase, $FardRemindersTable> {
  $$FardRemindersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get prayerName => $composableBuilder(
      column: $table.prayerName, builder: (column) => column);

  GeneratedColumn<int> get reminderMinutesBefore => $composableBuilder(
      column: $table.reminderMinutesBefore, builder: (column) => column);

  GeneratedColumn<bool> get isEnabled =>
      $composableBuilder(column: $table.isEnabled, builder: (column) => column);

  GeneratedColumn<String> get soundTone =>
      $composableBuilder(column: $table.soundTone, builder: (column) => column);
}

class $$FardRemindersTableTableManager extends RootTableManager<
    _$AppDatabase,
    $FardRemindersTable,
    FardReminder,
    $$FardRemindersTableFilterComposer,
    $$FardRemindersTableOrderingComposer,
    $$FardRemindersTableAnnotationComposer,
    $$FardRemindersTableCreateCompanionBuilder,
    $$FardRemindersTableUpdateCompanionBuilder,
    (
      FardReminder,
      BaseReferences<_$AppDatabase, $FardRemindersTable, FardReminder>
    ),
    FardReminder,
    PrefetchHooks Function()> {
  $$FardRemindersTableTableManager(_$AppDatabase db, $FardRemindersTable table)
      : super(TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$FardRemindersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$FardRemindersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$FardRemindersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback: ({
            Value<int> id = const Value.absent(),
            Value<String> prayerName = const Value.absent(),
            Value<int> reminderMinutesBefore = const Value.absent(),
            Value<bool> isEnabled = const Value.absent(),
            Value<String> soundTone = const Value.absent(),
          }) =>
              FardRemindersCompanion(
            id: id,
            prayerName: prayerName,
            reminderMinutesBefore: reminderMinutesBefore,
            isEnabled: isEnabled,
            soundTone: soundTone,
          ),
          createCompanionCallback: ({
            Value<int> id = const Value.absent(),
            required String prayerName,
            Value<int> reminderMinutesBefore = const Value.absent(),
            Value<bool> isEnabled = const Value.absent(),
            Value<String> soundTone = const Value.absent(),
          }) =>
              FardRemindersCompanion.insert(
            id: id,
            prayerName: prayerName,
            reminderMinutesBefore: reminderMinutesBefore,
            isEnabled: isEnabled,
            soundTone: soundTone,
          ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ));
}

typedef $$FardRemindersTableProcessedTableManager = ProcessedTableManager<
    _$AppDatabase,
    $FardRemindersTable,
    FardReminder,
    $$FardRemindersTableFilterComposer,
    $$FardRemindersTableOrderingComposer,
    $$FardRemindersTableAnnotationComposer,
    $$FardRemindersTableCreateCompanionBuilder,
    $$FardRemindersTableUpdateCompanionBuilder,
    (
      FardReminder,
      BaseReferences<_$AppDatabase, $FardRemindersTable, FardReminder>
    ),
    FardReminder,
    PrefetchHooks Function()>;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$ZikirsTableTableManager get zikirs =>
      $$ZikirsTableTableManager(_db, _db.zikirs);
  $$ZikirLogsTableTableManager get zikirLogs =>
      $$ZikirLogsTableTableManager(_db, _db.zikirLogs);
  $$UserStreaksTableTableManager get userStreaks =>
      $$UserStreaksTableTableManager(_db, _db.userStreaks);
  $$UserStreakHistoriesTableTableManager get userStreakHistories =>
      $$UserStreakHistoriesTableTableManager(_db, _db.userStreakHistories);
  $$StreakGapDaysTableTableManager get streakGapDays =>
      $$StreakGapDaysTableTableManager(_db, _db.streakGapDays);
  $$UnlockedBadgesTableTableManager get unlockedBadges =>
      $$UnlockedBadgesTableTableManager(_db, _db.unlockedBadges);
  $$UserProfilesTableTableManager get userProfiles =>
      $$UserProfilesTableTableManager(_db, _db.userProfiles);
  $$MemorizationPlansTableTableManager get memorizationPlans =>
      $$MemorizationPlansTableTableManager(_db, _db.memorizationPlans);
  $$HafizlikDailyLogsTableTableManager get hafizlikDailyLogs =>
      $$HafizlikDailyLogsTableTableManager(_db, _db.hafizlikDailyLogs);
  $$KazaPrayersTableTableManager get kazaPrayers =>
      $$KazaPrayersTableTableManager(_db, _db.kazaPrayers);
  $$PrayerAnswerLogsTableTableManager get prayerAnswerLogs =>
      $$PrayerAnswerLogsTableTableManager(_db, _db.prayerAnswerLogs);
  $$KazaMeltLogsTableTableManager get kazaMeltLogs =>
      $$KazaMeltLogsTableTableManager(_db, _db.kazaMeltLogs);
  $$HatimsTableTableManager get hatims =>
      $$HatimsTableTableManager(_db, _db.hatims);
  $$HatimCuzProgressesTableTableManager get hatimCuzProgresses =>
      $$HatimCuzProgressesTableTableManager(_db, _db.hatimCuzProgresses);
  $$JuzBookmarksTableTableManager get juzBookmarks =>
      $$JuzBookmarksTableTableManager(_db, _db.juzBookmarks);
  $$FardRemindersTableTableManager get fardReminders =>
      $$FardRemindersTableTableManager(_db, _db.fardReminders);
}
