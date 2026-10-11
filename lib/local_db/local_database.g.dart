// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'local_database.dart';

// ignore_for_file: type=lint
class $LocalContactsTableTable extends LocalContactsTable
    with TableInfo<$LocalContactsTableTable, LocalContactsTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalContactsTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nameMeta = const VerificationMeta('name');
  @override
  late final GeneratedColumn<String> name = GeneratedColumn<String>(
    'name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _phoneMeta = const VerificationMeta('phone');
  @override
  late final GeneratedColumn<String> phone = GeneratedColumn<String>(
    'phone',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _relationMeta = const VerificationMeta(
    'relation',
  );
  @override
  late final GeneratedColumn<String> relation = GeneratedColumn<String>(
    'relation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<String> priority = GeneratedColumn<String>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('high'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<String> createdAt = GeneratedColumn<String>(
    'created_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    userId,
    name,
    phone,
    relation,
    priority,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_contacts_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalContactsTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('phone')) {
      context.handle(
        _phoneMeta,
        phone.isAcceptableOrUnknown(data['phone']!, _phoneMeta),
      );
    } else if (isInserting) {
      context.missing(_phoneMeta);
    }
    if (data.containsKey('relation')) {
      context.handle(
        _relationMeta,
        relation.isAcceptableOrUnknown(data['relation']!, _relationMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocalContactsTableData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalContactsTableData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      phone: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}phone'],
      )!,
      relation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}relation'],
      )!,
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}priority'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_at'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      ),
    );
  }

  @override
  $LocalContactsTableTable createAlias(String alias) {
    return $LocalContactsTableTable(attachedDatabase, alias);
  }
}

class LocalContactsTableData extends DataClass
    implements Insertable<LocalContactsTableData> {
  /// Firestore document ID (primary key for deduplication).
  final String id;

  /// UID of the owning user.
  final String userId;

  /// Guardian display name.
  final String name;

  /// Full phone number string.
  final String phone;

  /// Relationship label.
  final String relation;

  /// Priority: 'high' | 'medium' | 'low'
  final String priority;

  /// ISO 8601 timestamp of creation (nullable).
  final String? createdAt;

  /// ISO 8601 timestamp of last local update.
  final String? updatedAt;
  const LocalContactsTableData({
    required this.id,
    required this.userId,
    required this.name,
    required this.phone,
    required this.relation,
    required this.priority,
    this.createdAt,
    this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['user_id'] = Variable<String>(userId);
    map['name'] = Variable<String>(name);
    map['phone'] = Variable<String>(phone);
    map['relation'] = Variable<String>(relation);
    map['priority'] = Variable<String>(priority);
    if (!nullToAbsent || createdAt != null) {
      map['created_at'] = Variable<String>(createdAt);
    }
    if (!nullToAbsent || updatedAt != null) {
      map['updated_at'] = Variable<String>(updatedAt);
    }
    return map;
  }

  LocalContactsTableCompanion toCompanion(bool nullToAbsent) {
    return LocalContactsTableCompanion(
      id: Value(id),
      userId: Value(userId),
      name: Value(name),
      phone: Value(phone),
      relation: Value(relation),
      priority: Value(priority),
      createdAt: createdAt == null && nullToAbsent
          ? const Value.absent()
          : Value(createdAt),
      updatedAt: updatedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(updatedAt),
    );
  }

  factory LocalContactsTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalContactsTableData(
      id: serializer.fromJson<String>(json['id']),
      userId: serializer.fromJson<String>(json['userId']),
      name: serializer.fromJson<String>(json['name']),
      phone: serializer.fromJson<String>(json['phone']),
      relation: serializer.fromJson<String>(json['relation']),
      priority: serializer.fromJson<String>(json['priority']),
      createdAt: serializer.fromJson<String?>(json['createdAt']),
      updatedAt: serializer.fromJson<String?>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'userId': serializer.toJson<String>(userId),
      'name': serializer.toJson<String>(name),
      'phone': serializer.toJson<String>(phone),
      'relation': serializer.toJson<String>(relation),
      'priority': serializer.toJson<String>(priority),
      'createdAt': serializer.toJson<String?>(createdAt),
      'updatedAt': serializer.toJson<String?>(updatedAt),
    };
  }

  LocalContactsTableData copyWith({
    String? id,
    String? userId,
    String? name,
    String? phone,
    String? relation,
    String? priority,
    Value<String?> createdAt = const Value.absent(),
    Value<String?> updatedAt = const Value.absent(),
  }) => LocalContactsTableData(
    id: id ?? this.id,
    userId: userId ?? this.userId,
    name: name ?? this.name,
    phone: phone ?? this.phone,
    relation: relation ?? this.relation,
    priority: priority ?? this.priority,
    createdAt: createdAt.present ? createdAt.value : this.createdAt,
    updatedAt: updatedAt.present ? updatedAt.value : this.updatedAt,
  );
  LocalContactsTableData copyWithCompanion(LocalContactsTableCompanion data) {
    return LocalContactsTableData(
      id: data.id.present ? data.id.value : this.id,
      userId: data.userId.present ? data.userId.value : this.userId,
      name: data.name.present ? data.name.value : this.name,
      phone: data.phone.present ? data.phone.value : this.phone,
      relation: data.relation.present ? data.relation.value : this.relation,
      priority: data.priority.present ? data.priority.value : this.priority,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalContactsTableData(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('relation: $relation, ')
          ..write('priority: $priority, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    userId,
    name,
    phone,
    relation,
    priority,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalContactsTableData &&
          other.id == this.id &&
          other.userId == this.userId &&
          other.name == this.name &&
          other.phone == this.phone &&
          other.relation == this.relation &&
          other.priority == this.priority &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class LocalContactsTableCompanion
    extends UpdateCompanion<LocalContactsTableData> {
  final Value<String> id;
  final Value<String> userId;
  final Value<String> name;
  final Value<String> phone;
  final Value<String> relation;
  final Value<String> priority;
  final Value<String?> createdAt;
  final Value<String?> updatedAt;
  final Value<int> rowid;
  const LocalContactsTableCompanion({
    this.id = const Value.absent(),
    this.userId = const Value.absent(),
    this.name = const Value.absent(),
    this.phone = const Value.absent(),
    this.relation = const Value.absent(),
    this.priority = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalContactsTableCompanion.insert({
    required String id,
    required String userId,
    required String name,
    required String phone,
    this.relation = const Value.absent(),
    this.priority = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       userId = Value(userId),
       name = Value(name),
       phone = Value(phone);
  static Insertable<LocalContactsTableData> custom({
    Expression<String>? id,
    Expression<String>? userId,
    Expression<String>? name,
    Expression<String>? phone,
    Expression<String>? relation,
    Expression<String>? priority,
    Expression<String>? createdAt,
    Expression<String>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (userId != null) 'user_id': userId,
      if (name != null) 'name': name,
      if (phone != null) 'phone': phone,
      if (relation != null) 'relation': relation,
      if (priority != null) 'priority': priority,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalContactsTableCompanion copyWith({
    Value<String>? id,
    Value<String>? userId,
    Value<String>? name,
    Value<String>? phone,
    Value<String>? relation,
    Value<String>? priority,
    Value<String?>? createdAt,
    Value<String?>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocalContactsTableCompanion(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      name: name ?? this.name,
      phone: phone ?? this.phone,
      relation: relation ?? this.relation,
      priority: priority ?? this.priority,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (phone.present) {
      map['phone'] = Variable<String>(phone.value);
    }
    if (relation.present) {
      map['relation'] = Variable<String>(relation.value);
    }
    if (priority.present) {
      map['priority'] = Variable<String>(priority.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<String>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalContactsTableCompanion(')
          ..write('id: $id, ')
          ..write('userId: $userId, ')
          ..write('name: $name, ')
          ..write('phone: $phone, ')
          ..write('relation: $relation, ')
          ..write('priority: $priority, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSosSessionTableTable extends LocalSosSessionTable
    with TableInfo<$LocalSosSessionTableTable, LocalSosSessionTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSosSessionTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _sosDocIdMeta = const VerificationMeta(
    'sosDocId',
  );
  @override
  late final GeneratedColumn<String> sosDocId = GeneratedColumn<String>(
    'sos_doc_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<String> startedAt = GeneratedColumn<String>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentLevelMeta = const VerificationMeta(
    'currentLevel',
  );
  @override
  late final GeneratedColumn<String> currentLevel = GeneratedColumn<String>(
    'current_level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('high'),
  );
  static const VerificationMeta _isResolvedMeta = const VerificationMeta(
    'isResolved',
  );
  @override
  late final GeneratedColumn<bool> isResolved = GeneratedColumn<bool>(
    'is_resolved',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_resolved" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _resolvedAtMeta = const VerificationMeta(
    'resolvedAt',
  );
  @override
  late final GeneratedColumn<String> resolvedAt = GeneratedColumn<String>(
    'resolved_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _alertedPhonesMeta = const VerificationMeta(
    'alertedPhones',
  );
  @override
  late final GeneratedColumn<String> alertedPhones = GeneratedColumn<String>(
    'alerted_phones',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant(''),
  );
  static const VerificationMeta _alertedPrioritiesMeta = const VerificationMeta(
    'alertedPriorities',
  );
  @override
  late final GeneratedColumn<String> alertedPriorities =
      GeneratedColumn<String>(
        'alerted_priorities',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
        defaultValue: const Constant('high'),
      );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<String> updatedAt = GeneratedColumn<String>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  static const VerificationMeta _triggerSourceMeta = const VerificationMeta(
    'triggerSource',
  );
  @override
  late final GeneratedColumn<String> triggerSource = GeneratedColumn<String>(
    'trigger_source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('button'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    sosDocId,
    userId,
    latitude,
    longitude,
    startedAt,
    currentLevel,
    isResolved,
    resolvedAt,
    alertedPhones,
    alertedPriorities,
    updatedAt,
    syncStatus,
    triggerSource,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_sos_session_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalSosSessionTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('sos_doc_id')) {
      context.handle(
        _sosDocIdMeta,
        sosDocId.isAcceptableOrUnknown(data['sos_doc_id']!, _sosDocIdMeta),
      );
    } else if (isInserting) {
      context.missing(_sosDocIdMeta);
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('current_level')) {
      context.handle(
        _currentLevelMeta,
        currentLevel.isAcceptableOrUnknown(
          data['current_level']!,
          _currentLevelMeta,
        ),
      );
    }
    if (data.containsKey('is_resolved')) {
      context.handle(
        _isResolvedMeta,
        isResolved.isAcceptableOrUnknown(data['is_resolved']!, _isResolvedMeta),
      );
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
        _resolvedAtMeta,
        resolvedAt.isAcceptableOrUnknown(data['resolved_at']!, _resolvedAtMeta),
      );
    }
    if (data.containsKey('alerted_phones')) {
      context.handle(
        _alertedPhonesMeta,
        alertedPhones.isAcceptableOrUnknown(
          data['alerted_phones']!,
          _alertedPhonesMeta,
        ),
      );
    }
    if (data.containsKey('alerted_priorities')) {
      context.handle(
        _alertedPrioritiesMeta,
        alertedPriorities.isAcceptableOrUnknown(
          data['alerted_priorities']!,
          _alertedPrioritiesMeta,
        ),
      );
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    if (data.containsKey('trigger_source')) {
      context.handle(
        _triggerSourceMeta,
        triggerSource.isAcceptableOrUnknown(
          data['trigger_source']!,
          _triggerSourceMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {sosDocId};
  @override
  LocalSosSessionTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSosSessionTableData(
      sosDocId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sos_doc_id'],
      )!,
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}started_at'],
      )!,
      currentLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}current_level'],
      )!,
      isResolved: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_resolved'],
      )!,
      resolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resolved_at'],
      ),
      alertedPhones: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alerted_phones'],
      )!,
      alertedPriorities: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}alerted_priorities'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}updated_at'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      triggerSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trigger_source'],
      )!,
    );
  }

  @override
  $LocalSosSessionTableTable createAlias(String alias) {
    return $LocalSosSessionTableTable(attachedDatabase, alias);
  }
}

class LocalSosSessionTableData extends DataClass
    implements Insertable<LocalSosSessionTableData> {
  /// Stable SOS doc ID (used for Firestore sync deduplication).
  final String sosDocId;

  /// UID of the user who triggered the SOS.
  final String userId;

  /// WGS-84 latitude.
  final double latitude;

  /// WGS-84 longitude.
  final double longitude;

  /// ISO 8601 timestamp when SOS was triggered (anchors escalation timing).
  final String startedAt;

  /// Current escalation level: 'high' | 'medium' | 'low'
  final String currentLevel;

  /// Whether the SOS is resolved.
  final bool isResolved;

  /// ISO 8601 timestamp of resolution (nullable).
  final String? resolvedAt;

  /// Comma-separated normalized phone numbers already alerted (deduplication).
  final String alertedPhones;

  /// Comma-separated alerted priorities: 'high,medium,low'
  final String alertedPriorities;

  /// ISO 8601 timestamp of last update.
  final String updatedAt;

  /// Sync status: 'pending' | 'synced'
  final String syncStatus;

  /// How SOS was triggered: 'button' | 'voice' | 'shake'
  final String triggerSource;
  const LocalSosSessionTableData({
    required this.sosDocId,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.startedAt,
    required this.currentLevel,
    required this.isResolved,
    this.resolvedAt,
    required this.alertedPhones,
    required this.alertedPriorities,
    required this.updatedAt,
    required this.syncStatus,
    required this.triggerSource,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['sos_doc_id'] = Variable<String>(sosDocId);
    map['user_id'] = Variable<String>(userId);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    map['started_at'] = Variable<String>(startedAt);
    map['current_level'] = Variable<String>(currentLevel);
    map['is_resolved'] = Variable<bool>(isResolved);
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<String>(resolvedAt);
    }
    map['alerted_phones'] = Variable<String>(alertedPhones);
    map['alerted_priorities'] = Variable<String>(alertedPriorities);
    map['updated_at'] = Variable<String>(updatedAt);
    map['sync_status'] = Variable<String>(syncStatus);
    map['trigger_source'] = Variable<String>(triggerSource);
    return map;
  }

  LocalSosSessionTableCompanion toCompanion(bool nullToAbsent) {
    return LocalSosSessionTableCompanion(
      sosDocId: Value(sosDocId),
      userId: Value(userId),
      latitude: Value(latitude),
      longitude: Value(longitude),
      startedAt: Value(startedAt),
      currentLevel: Value(currentLevel),
      isResolved: Value(isResolved),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
      alertedPhones: Value(alertedPhones),
      alertedPriorities: Value(alertedPriorities),
      updatedAt: Value(updatedAt),
      syncStatus: Value(syncStatus),
      triggerSource: Value(triggerSource),
    );
  }

  factory LocalSosSessionTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSosSessionTableData(
      sosDocId: serializer.fromJson<String>(json['sosDocId']),
      userId: serializer.fromJson<String>(json['userId']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      startedAt: serializer.fromJson<String>(json['startedAt']),
      currentLevel: serializer.fromJson<String>(json['currentLevel']),
      isResolved: serializer.fromJson<bool>(json['isResolved']),
      resolvedAt: serializer.fromJson<String?>(json['resolvedAt']),
      alertedPhones: serializer.fromJson<String>(json['alertedPhones']),
      alertedPriorities: serializer.fromJson<String>(json['alertedPriorities']),
      updatedAt: serializer.fromJson<String>(json['updatedAt']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      triggerSource: serializer.fromJson<String>(json['triggerSource']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'sosDocId': serializer.toJson<String>(sosDocId),
      'userId': serializer.toJson<String>(userId),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'startedAt': serializer.toJson<String>(startedAt),
      'currentLevel': serializer.toJson<String>(currentLevel),
      'isResolved': serializer.toJson<bool>(isResolved),
      'resolvedAt': serializer.toJson<String?>(resolvedAt),
      'alertedPhones': serializer.toJson<String>(alertedPhones),
      'alertedPriorities': serializer.toJson<String>(alertedPriorities),
      'updatedAt': serializer.toJson<String>(updatedAt),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'triggerSource': serializer.toJson<String>(triggerSource),
    };
  }

  LocalSosSessionTableData copyWith({
    String? sosDocId,
    String? userId,
    double? latitude,
    double? longitude,
    String? startedAt,
    String? currentLevel,
    bool? isResolved,
    Value<String?> resolvedAt = const Value.absent(),
    String? alertedPhones,
    String? alertedPriorities,
    String? updatedAt,
    String? syncStatus,
    String? triggerSource,
  }) => LocalSosSessionTableData(
    sosDocId: sosDocId ?? this.sosDocId,
    userId: userId ?? this.userId,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    startedAt: startedAt ?? this.startedAt,
    currentLevel: currentLevel ?? this.currentLevel,
    isResolved: isResolved ?? this.isResolved,
    resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
    alertedPhones: alertedPhones ?? this.alertedPhones,
    alertedPriorities: alertedPriorities ?? this.alertedPriorities,
    updatedAt: updatedAt ?? this.updatedAt,
    syncStatus: syncStatus ?? this.syncStatus,
    triggerSource: triggerSource ?? this.triggerSource,
  );
  LocalSosSessionTableData copyWithCompanion(
    LocalSosSessionTableCompanion data,
  ) {
    return LocalSosSessionTableData(
      sosDocId: data.sosDocId.present ? data.sosDocId.value : this.sosDocId,
      userId: data.userId.present ? data.userId.value : this.userId,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      currentLevel: data.currentLevel.present
          ? data.currentLevel.value
          : this.currentLevel,
      isResolved: data.isResolved.present
          ? data.isResolved.value
          : this.isResolved,
      resolvedAt: data.resolvedAt.present
          ? data.resolvedAt.value
          : this.resolvedAt,
      alertedPhones: data.alertedPhones.present
          ? data.alertedPhones.value
          : this.alertedPhones,
      alertedPriorities: data.alertedPriorities.present
          ? data.alertedPriorities.value
          : this.alertedPriorities,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      triggerSource: data.triggerSource.present
          ? data.triggerSource.value
          : this.triggerSource,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSosSessionTableData(')
          ..write('sosDocId: $sosDocId, ')
          ..write('userId: $userId, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('startedAt: $startedAt, ')
          ..write('currentLevel: $currentLevel, ')
          ..write('isResolved: $isResolved, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('alertedPhones: $alertedPhones, ')
          ..write('alertedPriorities: $alertedPriorities, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('triggerSource: $triggerSource')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    sosDocId,
    userId,
    latitude,
    longitude,
    startedAt,
    currentLevel,
    isResolved,
    resolvedAt,
    alertedPhones,
    alertedPriorities,
    updatedAt,
    syncStatus,
    triggerSource,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSosSessionTableData &&
          other.sosDocId == this.sosDocId &&
          other.userId == this.userId &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.startedAt == this.startedAt &&
          other.currentLevel == this.currentLevel &&
          other.isResolved == this.isResolved &&
          other.resolvedAt == this.resolvedAt &&
          other.alertedPhones == this.alertedPhones &&
          other.alertedPriorities == this.alertedPriorities &&
          other.updatedAt == this.updatedAt &&
          other.syncStatus == this.syncStatus &&
          other.triggerSource == this.triggerSource);
}

class LocalSosSessionTableCompanion
    extends UpdateCompanion<LocalSosSessionTableData> {
  final Value<String> sosDocId;
  final Value<String> userId;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<String> startedAt;
  final Value<String> currentLevel;
  final Value<bool> isResolved;
  final Value<String?> resolvedAt;
  final Value<String> alertedPhones;
  final Value<String> alertedPriorities;
  final Value<String> updatedAt;
  final Value<String> syncStatus;
  final Value<String> triggerSource;
  final Value<int> rowid;
  const LocalSosSessionTableCompanion({
    this.sosDocId = const Value.absent(),
    this.userId = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.currentLevel = const Value.absent(),
    this.isResolved = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.alertedPhones = const Value.absent(),
    this.alertedPriorities = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.triggerSource = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSosSessionTableCompanion.insert({
    required String sosDocId,
    required String userId,
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    required String startedAt,
    this.currentLevel = const Value.absent(),
    this.isResolved = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.alertedPhones = const Value.absent(),
    this.alertedPriorities = const Value.absent(),
    required String updatedAt,
    this.syncStatus = const Value.absent(),
    this.triggerSource = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : sosDocId = Value(sosDocId),
       userId = Value(userId),
       startedAt = Value(startedAt),
       updatedAt = Value(updatedAt);
  static Insertable<LocalSosSessionTableData> custom({
    Expression<String>? sosDocId,
    Expression<String>? userId,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? startedAt,
    Expression<String>? currentLevel,
    Expression<bool>? isResolved,
    Expression<String>? resolvedAt,
    Expression<String>? alertedPhones,
    Expression<String>? alertedPriorities,
    Expression<String>? updatedAt,
    Expression<String>? syncStatus,
    Expression<String>? triggerSource,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (sosDocId != null) 'sos_doc_id': sosDocId,
      if (userId != null) 'user_id': userId,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (startedAt != null) 'started_at': startedAt,
      if (currentLevel != null) 'current_level': currentLevel,
      if (isResolved != null) 'is_resolved': isResolved,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
      if (alertedPhones != null) 'alerted_phones': alertedPhones,
      if (alertedPriorities != null) 'alerted_priorities': alertedPriorities,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (triggerSource != null) 'trigger_source': triggerSource,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSosSessionTableCompanion copyWith({
    Value<String>? sosDocId,
    Value<String>? userId,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<String>? startedAt,
    Value<String>? currentLevel,
    Value<bool>? isResolved,
    Value<String?>? resolvedAt,
    Value<String>? alertedPhones,
    Value<String>? alertedPriorities,
    Value<String>? updatedAt,
    Value<String>? syncStatus,
    Value<String>? triggerSource,
    Value<int>? rowid,
  }) {
    return LocalSosSessionTableCompanion(
      sosDocId: sosDocId ?? this.sosDocId,
      userId: userId ?? this.userId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      startedAt: startedAt ?? this.startedAt,
      currentLevel: currentLevel ?? this.currentLevel,
      isResolved: isResolved ?? this.isResolved,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      alertedPhones: alertedPhones ?? this.alertedPhones,
      alertedPriorities: alertedPriorities ?? this.alertedPriorities,
      updatedAt: updatedAt ?? this.updatedAt,
      syncStatus: syncStatus ?? this.syncStatus,
      triggerSource: triggerSource ?? this.triggerSource,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (sosDocId.present) {
      map['sos_doc_id'] = Variable<String>(sosDocId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<String>(startedAt.value);
    }
    if (currentLevel.present) {
      map['current_level'] = Variable<String>(currentLevel.value);
    }
    if (isResolved.present) {
      map['is_resolved'] = Variable<bool>(isResolved.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<String>(resolvedAt.value);
    }
    if (alertedPhones.present) {
      map['alerted_phones'] = Variable<String>(alertedPhones.value);
    }
    if (alertedPriorities.present) {
      map['alerted_priorities'] = Variable<String>(alertedPriorities.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<String>(updatedAt.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (triggerSource.present) {
      map['trigger_source'] = Variable<String>(triggerSource.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSosSessionTableCompanion(')
          ..write('sosDocId: $sosDocId, ')
          ..write('userId: $userId, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('startedAt: $startedAt, ')
          ..write('currentLevel: $currentLevel, ')
          ..write('isResolved: $isResolved, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('alertedPhones: $alertedPhones, ')
          ..write('alertedPriorities: $alertedPriorities, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('triggerSource: $triggerSource, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocalSosHistoryTableTable extends LocalSosHistoryTable
    with TableInfo<$LocalSosHistoryTableTable, LocalSosHistoryTableData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocalSosHistoryTableTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localIdMeta = const VerificationMeta(
    'localId',
  );
  @override
  late final GeneratedColumn<String> localId = GeneratedColumn<String>(
    'local_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _firestoreDocIdMeta = const VerificationMeta(
    'firestoreDocId',
  );
  @override
  late final GeneratedColumn<String> firestoreDocId = GeneratedColumn<String>(
    'firestore_doc_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _userIdMeta = const VerificationMeta('userId');
  @override
  late final GeneratedColumn<String> userId = GeneratedColumn<String>(
    'user_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _latitudeMeta = const VerificationMeta(
    'latitude',
  );
  @override
  late final GeneratedColumn<double> latitude = GeneratedColumn<double>(
    'latitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _longitudeMeta = const VerificationMeta(
    'longitude',
  );
  @override
  late final GeneratedColumn<double> longitude = GeneratedColumn<double>(
    'longitude',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
    defaultValue: const Constant(0.0),
  );
  static const VerificationMeta _startedAtMeta = const VerificationMeta(
    'startedAt',
  );
  @override
  late final GeneratedColumn<String> startedAt = GeneratedColumn<String>(
    'started_at',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _statusMeta = const VerificationMeta('status');
  @override
  late final GeneratedColumn<String> status = GeneratedColumn<String>(
    'status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('active'),
  );
  static const VerificationMeta _escalationLevelMeta = const VerificationMeta(
    'escalationLevel',
  );
  @override
  late final GeneratedColumn<String> escalationLevel = GeneratedColumn<String>(
    'escalation_level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('high'),
  );
  static const VerificationMeta _resolvedAtMeta = const VerificationMeta(
    'resolvedAt',
  );
  @override
  late final GeneratedColumn<String> resolvedAt = GeneratedColumn<String>(
    'resolved_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _highAlertedAtMeta = const VerificationMeta(
    'highAlertedAt',
  );
  @override
  late final GeneratedColumn<String> highAlertedAt = GeneratedColumn<String>(
    'high_alerted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _mediumAlertedAtMeta = const VerificationMeta(
    'mediumAlertedAt',
  );
  @override
  late final GeneratedColumn<String> mediumAlertedAt = GeneratedColumn<String>(
    'medium_alerted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _lowAlertedAtMeta = const VerificationMeta(
    'lowAlertedAt',
  );
  @override
  late final GeneratedColumn<String> lowAlertedAt = GeneratedColumn<String>(
    'low_alerted_at',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _triggerSourceMeta = const VerificationMeta(
    'triggerSource',
  );
  @override
  late final GeneratedColumn<String> triggerSource = GeneratedColumn<String>(
    'trigger_source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('button'),
  );
  static const VerificationMeta _smsResultsJsonMeta = const VerificationMeta(
    'smsResultsJson',
  );
  @override
  late final GeneratedColumn<String> smsResultsJson = GeneratedColumn<String>(
    'sms_results_json',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _policeCallAuthorizedMeta =
      const VerificationMeta('policeCallAuthorized');
  @override
  late final GeneratedColumn<bool> policeCallAuthorized = GeneratedColumn<bool>(
    'police_call_authorized',
    aliasedName,
    true,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("police_call_authorized" IN (0, 1))',
    ),
  );
  static const VerificationMeta _syncStatusMeta = const VerificationMeta(
    'syncStatus',
  );
  @override
  late final GeneratedColumn<String> syncStatus = GeneratedColumn<String>(
    'sync_status',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('pending'),
  );
  @override
  List<GeneratedColumn> get $columns => [
    localId,
    firestoreDocId,
    userId,
    latitude,
    longitude,
    startedAt,
    status,
    escalationLevel,
    resolvedAt,
    highAlertedAt,
    mediumAlertedAt,
    lowAlertedAt,
    triggerSource,
    smsResultsJson,
    policeCallAuthorized,
    syncStatus,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'local_sos_history_table';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocalSosHistoryTableData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_id')) {
      context.handle(
        _localIdMeta,
        localId.isAcceptableOrUnknown(data['local_id']!, _localIdMeta),
      );
    } else if (isInserting) {
      context.missing(_localIdMeta);
    }
    if (data.containsKey('firestore_doc_id')) {
      context.handle(
        _firestoreDocIdMeta,
        firestoreDocId.isAcceptableOrUnknown(
          data['firestore_doc_id']!,
          _firestoreDocIdMeta,
        ),
      );
    }
    if (data.containsKey('user_id')) {
      context.handle(
        _userIdMeta,
        userId.isAcceptableOrUnknown(data['user_id']!, _userIdMeta),
      );
    } else if (isInserting) {
      context.missing(_userIdMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    }
    if (data.containsKey('started_at')) {
      context.handle(
        _startedAtMeta,
        startedAt.isAcceptableOrUnknown(data['started_at']!, _startedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_startedAtMeta);
    }
    if (data.containsKey('status')) {
      context.handle(
        _statusMeta,
        status.isAcceptableOrUnknown(data['status']!, _statusMeta),
      );
    }
    if (data.containsKey('escalation_level')) {
      context.handle(
        _escalationLevelMeta,
        escalationLevel.isAcceptableOrUnknown(
          data['escalation_level']!,
          _escalationLevelMeta,
        ),
      );
    }
    if (data.containsKey('resolved_at')) {
      context.handle(
        _resolvedAtMeta,
        resolvedAt.isAcceptableOrUnknown(data['resolved_at']!, _resolvedAtMeta),
      );
    }
    if (data.containsKey('high_alerted_at')) {
      context.handle(
        _highAlertedAtMeta,
        highAlertedAt.isAcceptableOrUnknown(
          data['high_alerted_at']!,
          _highAlertedAtMeta,
        ),
      );
    }
    if (data.containsKey('medium_alerted_at')) {
      context.handle(
        _mediumAlertedAtMeta,
        mediumAlertedAt.isAcceptableOrUnknown(
          data['medium_alerted_at']!,
          _mediumAlertedAtMeta,
        ),
      );
    }
    if (data.containsKey('low_alerted_at')) {
      context.handle(
        _lowAlertedAtMeta,
        lowAlertedAt.isAcceptableOrUnknown(
          data['low_alerted_at']!,
          _lowAlertedAtMeta,
        ),
      );
    }
    if (data.containsKey('trigger_source')) {
      context.handle(
        _triggerSourceMeta,
        triggerSource.isAcceptableOrUnknown(
          data['trigger_source']!,
          _triggerSourceMeta,
        ),
      );
    }
    if (data.containsKey('sms_results_json')) {
      context.handle(
        _smsResultsJsonMeta,
        smsResultsJson.isAcceptableOrUnknown(
          data['sms_results_json']!,
          _smsResultsJsonMeta,
        ),
      );
    }
    if (data.containsKey('police_call_authorized')) {
      context.handle(
        _policeCallAuthorizedMeta,
        policeCallAuthorized.isAcceptableOrUnknown(
          data['police_call_authorized']!,
          _policeCallAuthorizedMeta,
        ),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {localId};
  @override
  LocalSosHistoryTableData map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocalSosHistoryTableData(
      localId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_id'],
      )!,
      firestoreDocId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}firestore_doc_id'],
      ),
      userId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}user_id'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      startedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}started_at'],
      )!,
      status: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}status'],
      )!,
      escalationLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}escalation_level'],
      )!,
      resolvedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}resolved_at'],
      ),
      highAlertedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}high_alerted_at'],
      ),
      mediumAlertedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}medium_alerted_at'],
      ),
      lowAlertedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}low_alerted_at'],
      ),
      triggerSource: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}trigger_source'],
      )!,
      smsResultsJson: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sms_results_json'],
      ),
      policeCallAuthorized: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}police_call_authorized'],
      ),
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
    );
  }

  @override
  $LocalSosHistoryTableTable createAlias(String alias) {
    return $LocalSosHistoryTableTable(attachedDatabase, alias);
  }
}

class LocalSosHistoryTableData extends DataClass
    implements Insertable<LocalSosHistoryTableData> {
  /// Stable local ID (UUID generated at SOS time, used as Firestore doc ID).
  final String localId;

  /// Firestore document ID after sync (null until synced).
  final String? firestoreDocId;

  /// UID of the user who triggered the SOS.
  final String userId;

  /// WGS-84 latitude.
  final double latitude;

  /// WGS-84 longitude.
  final double longitude;

  /// ISO 8601 SOS start timestamp.
  final String startedAt;

  /// SOS status: 'active' | 'resolved' | 'cancelled'
  final String status;

  /// Escalation level reached: 'high' | 'medium' | 'low'
  final String escalationLevel;

  /// ISO 8601 timestamp of resolution (nullable).
  final String? resolvedAt;

  /// ISO 8601 timestamp when High contacts were alerted.
  final String? highAlertedAt;

  /// ISO 8601 timestamp when Medium contacts were alerted.
  final String? mediumAlertedAt;

  /// ISO 8601 timestamp when Low contacts were alerted.
  final String? lowAlertedAt;

  /// Trigger source: 'button' | 'voice' | 'shake'
  final String triggerSource;

  /// JSON string of SMS results map: {phone: 'sent'|'failed'|...}
  final String? smsResultsJson;

  /// Whether user authorized calling police (null / true / false).
  final bool? policeCallAuthorized;

  /// Sync status: 'pending' | 'synced'
  final String syncStatus;
  const LocalSosHistoryTableData({
    required this.localId,
    this.firestoreDocId,
    required this.userId,
    required this.latitude,
    required this.longitude,
    required this.startedAt,
    required this.status,
    required this.escalationLevel,
    this.resolvedAt,
    this.highAlertedAt,
    this.mediumAlertedAt,
    this.lowAlertedAt,
    required this.triggerSource,
    this.smsResultsJson,
    this.policeCallAuthorized,
    required this.syncStatus,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_id'] = Variable<String>(localId);
    if (!nullToAbsent || firestoreDocId != null) {
      map['firestore_doc_id'] = Variable<String>(firestoreDocId);
    }
    map['user_id'] = Variable<String>(userId);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    map['started_at'] = Variable<String>(startedAt);
    map['status'] = Variable<String>(status);
    map['escalation_level'] = Variable<String>(escalationLevel);
    if (!nullToAbsent || resolvedAt != null) {
      map['resolved_at'] = Variable<String>(resolvedAt);
    }
    if (!nullToAbsent || highAlertedAt != null) {
      map['high_alerted_at'] = Variable<String>(highAlertedAt);
    }
    if (!nullToAbsent || mediumAlertedAt != null) {
      map['medium_alerted_at'] = Variable<String>(mediumAlertedAt);
    }
    if (!nullToAbsent || lowAlertedAt != null) {
      map['low_alerted_at'] = Variable<String>(lowAlertedAt);
    }
    map['trigger_source'] = Variable<String>(triggerSource);
    if (!nullToAbsent || smsResultsJson != null) {
      map['sms_results_json'] = Variable<String>(smsResultsJson);
    }
    if (!nullToAbsent || policeCallAuthorized != null) {
      map['police_call_authorized'] = Variable<bool>(policeCallAuthorized);
    }
    map['sync_status'] = Variable<String>(syncStatus);
    return map;
  }

  LocalSosHistoryTableCompanion toCompanion(bool nullToAbsent) {
    return LocalSosHistoryTableCompanion(
      localId: Value(localId),
      firestoreDocId: firestoreDocId == null && nullToAbsent
          ? const Value.absent()
          : Value(firestoreDocId),
      userId: Value(userId),
      latitude: Value(latitude),
      longitude: Value(longitude),
      startedAt: Value(startedAt),
      status: Value(status),
      escalationLevel: Value(escalationLevel),
      resolvedAt: resolvedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(resolvedAt),
      highAlertedAt: highAlertedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(highAlertedAt),
      mediumAlertedAt: mediumAlertedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(mediumAlertedAt),
      lowAlertedAt: lowAlertedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lowAlertedAt),
      triggerSource: Value(triggerSource),
      smsResultsJson: smsResultsJson == null && nullToAbsent
          ? const Value.absent()
          : Value(smsResultsJson),
      policeCallAuthorized: policeCallAuthorized == null && nullToAbsent
          ? const Value.absent()
          : Value(policeCallAuthorized),
      syncStatus: Value(syncStatus),
    );
  }

  factory LocalSosHistoryTableData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocalSosHistoryTableData(
      localId: serializer.fromJson<String>(json['localId']),
      firestoreDocId: serializer.fromJson<String?>(json['firestoreDocId']),
      userId: serializer.fromJson<String>(json['userId']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      startedAt: serializer.fromJson<String>(json['startedAt']),
      status: serializer.fromJson<String>(json['status']),
      escalationLevel: serializer.fromJson<String>(json['escalationLevel']),
      resolvedAt: serializer.fromJson<String?>(json['resolvedAt']),
      highAlertedAt: serializer.fromJson<String?>(json['highAlertedAt']),
      mediumAlertedAt: serializer.fromJson<String?>(json['mediumAlertedAt']),
      lowAlertedAt: serializer.fromJson<String?>(json['lowAlertedAt']),
      triggerSource: serializer.fromJson<String>(json['triggerSource']),
      smsResultsJson: serializer.fromJson<String?>(json['smsResultsJson']),
      policeCallAuthorized: serializer.fromJson<bool?>(
        json['policeCallAuthorized'],
      ),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localId': serializer.toJson<String>(localId),
      'firestoreDocId': serializer.toJson<String?>(firestoreDocId),
      'userId': serializer.toJson<String>(userId),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'startedAt': serializer.toJson<String>(startedAt),
      'status': serializer.toJson<String>(status),
      'escalationLevel': serializer.toJson<String>(escalationLevel),
      'resolvedAt': serializer.toJson<String?>(resolvedAt),
      'highAlertedAt': serializer.toJson<String?>(highAlertedAt),
      'mediumAlertedAt': serializer.toJson<String?>(mediumAlertedAt),
      'lowAlertedAt': serializer.toJson<String?>(lowAlertedAt),
      'triggerSource': serializer.toJson<String>(triggerSource),
      'smsResultsJson': serializer.toJson<String?>(smsResultsJson),
      'policeCallAuthorized': serializer.toJson<bool?>(policeCallAuthorized),
      'syncStatus': serializer.toJson<String>(syncStatus),
    };
  }

  LocalSosHistoryTableData copyWith({
    String? localId,
    Value<String?> firestoreDocId = const Value.absent(),
    String? userId,
    double? latitude,
    double? longitude,
    String? startedAt,
    String? status,
    String? escalationLevel,
    Value<String?> resolvedAt = const Value.absent(),
    Value<String?> highAlertedAt = const Value.absent(),
    Value<String?> mediumAlertedAt = const Value.absent(),
    Value<String?> lowAlertedAt = const Value.absent(),
    String? triggerSource,
    Value<String?> smsResultsJson = const Value.absent(),
    Value<bool?> policeCallAuthorized = const Value.absent(),
    String? syncStatus,
  }) => LocalSosHistoryTableData(
    localId: localId ?? this.localId,
    firestoreDocId: firestoreDocId.present
        ? firestoreDocId.value
        : this.firestoreDocId,
    userId: userId ?? this.userId,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    startedAt: startedAt ?? this.startedAt,
    status: status ?? this.status,
    escalationLevel: escalationLevel ?? this.escalationLevel,
    resolvedAt: resolvedAt.present ? resolvedAt.value : this.resolvedAt,
    highAlertedAt: highAlertedAt.present
        ? highAlertedAt.value
        : this.highAlertedAt,
    mediumAlertedAt: mediumAlertedAt.present
        ? mediumAlertedAt.value
        : this.mediumAlertedAt,
    lowAlertedAt: lowAlertedAt.present ? lowAlertedAt.value : this.lowAlertedAt,
    triggerSource: triggerSource ?? this.triggerSource,
    smsResultsJson: smsResultsJson.present
        ? smsResultsJson.value
        : this.smsResultsJson,
    policeCallAuthorized: policeCallAuthorized.present
        ? policeCallAuthorized.value
        : this.policeCallAuthorized,
    syncStatus: syncStatus ?? this.syncStatus,
  );
  LocalSosHistoryTableData copyWithCompanion(
    LocalSosHistoryTableCompanion data,
  ) {
    return LocalSosHistoryTableData(
      localId: data.localId.present ? data.localId.value : this.localId,
      firestoreDocId: data.firestoreDocId.present
          ? data.firestoreDocId.value
          : this.firestoreDocId,
      userId: data.userId.present ? data.userId.value : this.userId,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      startedAt: data.startedAt.present ? data.startedAt.value : this.startedAt,
      status: data.status.present ? data.status.value : this.status,
      escalationLevel: data.escalationLevel.present
          ? data.escalationLevel.value
          : this.escalationLevel,
      resolvedAt: data.resolvedAt.present
          ? data.resolvedAt.value
          : this.resolvedAt,
      highAlertedAt: data.highAlertedAt.present
          ? data.highAlertedAt.value
          : this.highAlertedAt,
      mediumAlertedAt: data.mediumAlertedAt.present
          ? data.mediumAlertedAt.value
          : this.mediumAlertedAt,
      lowAlertedAt: data.lowAlertedAt.present
          ? data.lowAlertedAt.value
          : this.lowAlertedAt,
      triggerSource: data.triggerSource.present
          ? data.triggerSource.value
          : this.triggerSource,
      smsResultsJson: data.smsResultsJson.present
          ? data.smsResultsJson.value
          : this.smsResultsJson,
      policeCallAuthorized: data.policeCallAuthorized.present
          ? data.policeCallAuthorized.value
          : this.policeCallAuthorized,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocalSosHistoryTableData(')
          ..write('localId: $localId, ')
          ..write('firestoreDocId: $firestoreDocId, ')
          ..write('userId: $userId, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('startedAt: $startedAt, ')
          ..write('status: $status, ')
          ..write('escalationLevel: $escalationLevel, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('highAlertedAt: $highAlertedAt, ')
          ..write('mediumAlertedAt: $mediumAlertedAt, ')
          ..write('lowAlertedAt: $lowAlertedAt, ')
          ..write('triggerSource: $triggerSource, ')
          ..write('smsResultsJson: $smsResultsJson, ')
          ..write('policeCallAuthorized: $policeCallAuthorized, ')
          ..write('syncStatus: $syncStatus')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    localId,
    firestoreDocId,
    userId,
    latitude,
    longitude,
    startedAt,
    status,
    escalationLevel,
    resolvedAt,
    highAlertedAt,
    mediumAlertedAt,
    lowAlertedAt,
    triggerSource,
    smsResultsJson,
    policeCallAuthorized,
    syncStatus,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocalSosHistoryTableData &&
          other.localId == this.localId &&
          other.firestoreDocId == this.firestoreDocId &&
          other.userId == this.userId &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.startedAt == this.startedAt &&
          other.status == this.status &&
          other.escalationLevel == this.escalationLevel &&
          other.resolvedAt == this.resolvedAt &&
          other.highAlertedAt == this.highAlertedAt &&
          other.mediumAlertedAt == this.mediumAlertedAt &&
          other.lowAlertedAt == this.lowAlertedAt &&
          other.triggerSource == this.triggerSource &&
          other.smsResultsJson == this.smsResultsJson &&
          other.policeCallAuthorized == this.policeCallAuthorized &&
          other.syncStatus == this.syncStatus);
}

class LocalSosHistoryTableCompanion
    extends UpdateCompanion<LocalSosHistoryTableData> {
  final Value<String> localId;
  final Value<String?> firestoreDocId;
  final Value<String> userId;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<String> startedAt;
  final Value<String> status;
  final Value<String> escalationLevel;
  final Value<String?> resolvedAt;
  final Value<String?> highAlertedAt;
  final Value<String?> mediumAlertedAt;
  final Value<String?> lowAlertedAt;
  final Value<String> triggerSource;
  final Value<String?> smsResultsJson;
  final Value<bool?> policeCallAuthorized;
  final Value<String> syncStatus;
  final Value<int> rowid;
  const LocalSosHistoryTableCompanion({
    this.localId = const Value.absent(),
    this.firestoreDocId = const Value.absent(),
    this.userId = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.startedAt = const Value.absent(),
    this.status = const Value.absent(),
    this.escalationLevel = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.highAlertedAt = const Value.absent(),
    this.mediumAlertedAt = const Value.absent(),
    this.lowAlertedAt = const Value.absent(),
    this.triggerSource = const Value.absent(),
    this.smsResultsJson = const Value.absent(),
    this.policeCallAuthorized = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocalSosHistoryTableCompanion.insert({
    required String localId,
    this.firestoreDocId = const Value.absent(),
    required String userId,
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    required String startedAt,
    this.status = const Value.absent(),
    this.escalationLevel = const Value.absent(),
    this.resolvedAt = const Value.absent(),
    this.highAlertedAt = const Value.absent(),
    this.mediumAlertedAt = const Value.absent(),
    this.lowAlertedAt = const Value.absent(),
    this.triggerSource = const Value.absent(),
    this.smsResultsJson = const Value.absent(),
    this.policeCallAuthorized = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : localId = Value(localId),
       userId = Value(userId),
       startedAt = Value(startedAt);
  static Insertable<LocalSosHistoryTableData> custom({
    Expression<String>? localId,
    Expression<String>? firestoreDocId,
    Expression<String>? userId,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<String>? startedAt,
    Expression<String>? status,
    Expression<String>? escalationLevel,
    Expression<String>? resolvedAt,
    Expression<String>? highAlertedAt,
    Expression<String>? mediumAlertedAt,
    Expression<String>? lowAlertedAt,
    Expression<String>? triggerSource,
    Expression<String>? smsResultsJson,
    Expression<bool>? policeCallAuthorized,
    Expression<String>? syncStatus,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (localId != null) 'local_id': localId,
      if (firestoreDocId != null) 'firestore_doc_id': firestoreDocId,
      if (userId != null) 'user_id': userId,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (startedAt != null) 'started_at': startedAt,
      if (status != null) 'status': status,
      if (escalationLevel != null) 'escalation_level': escalationLevel,
      if (resolvedAt != null) 'resolved_at': resolvedAt,
      if (highAlertedAt != null) 'high_alerted_at': highAlertedAt,
      if (mediumAlertedAt != null) 'medium_alerted_at': mediumAlertedAt,
      if (lowAlertedAt != null) 'low_alerted_at': lowAlertedAt,
      if (triggerSource != null) 'trigger_source': triggerSource,
      if (smsResultsJson != null) 'sms_results_json': smsResultsJson,
      if (policeCallAuthorized != null)
        'police_call_authorized': policeCallAuthorized,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocalSosHistoryTableCompanion copyWith({
    Value<String>? localId,
    Value<String?>? firestoreDocId,
    Value<String>? userId,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<String>? startedAt,
    Value<String>? status,
    Value<String>? escalationLevel,
    Value<String?>? resolvedAt,
    Value<String?>? highAlertedAt,
    Value<String?>? mediumAlertedAt,
    Value<String?>? lowAlertedAt,
    Value<String>? triggerSource,
    Value<String?>? smsResultsJson,
    Value<bool?>? policeCallAuthorized,
    Value<String>? syncStatus,
    Value<int>? rowid,
  }) {
    return LocalSosHistoryTableCompanion(
      localId: localId ?? this.localId,
      firestoreDocId: firestoreDocId ?? this.firestoreDocId,
      userId: userId ?? this.userId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      startedAt: startedAt ?? this.startedAt,
      status: status ?? this.status,
      escalationLevel: escalationLevel ?? this.escalationLevel,
      resolvedAt: resolvedAt ?? this.resolvedAt,
      highAlertedAt: highAlertedAt ?? this.highAlertedAt,
      mediumAlertedAt: mediumAlertedAt ?? this.mediumAlertedAt,
      lowAlertedAt: lowAlertedAt ?? this.lowAlertedAt,
      triggerSource: triggerSource ?? this.triggerSource,
      smsResultsJson: smsResultsJson ?? this.smsResultsJson,
      policeCallAuthorized: policeCallAuthorized ?? this.policeCallAuthorized,
      syncStatus: syncStatus ?? this.syncStatus,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localId.present) {
      map['local_id'] = Variable<String>(localId.value);
    }
    if (firestoreDocId.present) {
      map['firestore_doc_id'] = Variable<String>(firestoreDocId.value);
    }
    if (userId.present) {
      map['user_id'] = Variable<String>(userId.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (startedAt.present) {
      map['started_at'] = Variable<String>(startedAt.value);
    }
    if (status.present) {
      map['status'] = Variable<String>(status.value);
    }
    if (escalationLevel.present) {
      map['escalation_level'] = Variable<String>(escalationLevel.value);
    }
    if (resolvedAt.present) {
      map['resolved_at'] = Variable<String>(resolvedAt.value);
    }
    if (highAlertedAt.present) {
      map['high_alerted_at'] = Variable<String>(highAlertedAt.value);
    }
    if (mediumAlertedAt.present) {
      map['medium_alerted_at'] = Variable<String>(mediumAlertedAt.value);
    }
    if (lowAlertedAt.present) {
      map['low_alerted_at'] = Variable<String>(lowAlertedAt.value);
    }
    if (triggerSource.present) {
      map['trigger_source'] = Variable<String>(triggerSource.value);
    }
    if (smsResultsJson.present) {
      map['sms_results_json'] = Variable<String>(smsResultsJson.value);
    }
    if (policeCallAuthorized.present) {
      map['police_call_authorized'] = Variable<bool>(
        policeCallAuthorized.value,
      );
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocalSosHistoryTableCompanion(')
          ..write('localId: $localId, ')
          ..write('firestoreDocId: $firestoreDocId, ')
          ..write('userId: $userId, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('startedAt: $startedAt, ')
          ..write('status: $status, ')
          ..write('escalationLevel: $escalationLevel, ')
          ..write('resolvedAt: $resolvedAt, ')
          ..write('highAlertedAt: $highAlertedAt, ')
          ..write('mediumAlertedAt: $mediumAlertedAt, ')
          ..write('lowAlertedAt: $lowAlertedAt, ')
          ..write('triggerSource: $triggerSource, ')
          ..write('smsResultsJson: $smsResultsJson, ')
          ..write('policeCallAuthorized: $policeCallAuthorized, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $LocalContactsTableTable localContactsTable =
      $LocalContactsTableTable(this);
  late final $LocalSosSessionTableTable localSosSessionTable =
      $LocalSosSessionTableTable(this);
  late final $LocalSosHistoryTableTable localSosHistoryTable =
      $LocalSosHistoryTableTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    localContactsTable,
    localSosSessionTable,
    localSosHistoryTable,
  ];
}

typedef $$LocalContactsTableTableCreateCompanionBuilder =
    LocalContactsTableCompanion Function({
      required String id,
      required String userId,
      required String name,
      required String phone,
      Value<String> relation,
      Value<String> priority,
      Value<String?> createdAt,
      Value<String?> updatedAt,
      Value<int> rowid,
    });
typedef $$LocalContactsTableTableUpdateCompanionBuilder =
    LocalContactsTableCompanion Function({
      Value<String> id,
      Value<String> userId,
      Value<String> name,
      Value<String> phone,
      Value<String> relation,
      Value<String> priority,
      Value<String?> createdAt,
      Value<String?> updatedAt,
      Value<int> rowid,
    });

class $$LocalContactsTableTableFilterComposer
    extends Composer<_$AppDatabase, $LocalContactsTableTable> {
  $$LocalContactsTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get relation => $composableBuilder(
    column: $table.relation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalContactsTableTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalContactsTableTable> {
  $$LocalContactsTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get phone => $composableBuilder(
    column: $table.phone,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get relation => $composableBuilder(
    column: $table.relation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalContactsTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalContactsTableTable> {
  $$LocalContactsTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<String> get phone =>
      $composableBuilder(column: $table.phone, builder: (column) => column);

  GeneratedColumn<String> get relation =>
      $composableBuilder(column: $table.relation, builder: (column) => column);

  GeneratedColumn<String> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<String> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocalContactsTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalContactsTableTable,
          LocalContactsTableData,
          $$LocalContactsTableTableFilterComposer,
          $$LocalContactsTableTableOrderingComposer,
          $$LocalContactsTableTableAnnotationComposer,
          $$LocalContactsTableTableCreateCompanionBuilder,
          $$LocalContactsTableTableUpdateCompanionBuilder,
          (
            LocalContactsTableData,
            BaseReferences<
              _$AppDatabase,
              $LocalContactsTableTable,
              LocalContactsTableData
            >,
          ),
          LocalContactsTableData,
          PrefetchHooks Function()
        > {
  $$LocalContactsTableTableTableManager(
    _$AppDatabase db,
    $LocalContactsTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalContactsTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalContactsTableTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocalContactsTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String> phone = const Value.absent(),
                Value<String> relation = const Value.absent(),
                Value<String> priority = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalContactsTableCompanion(
                id: id,
                userId: userId,
                name: name,
                phone: phone,
                relation: relation,
                priority: priority,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String userId,
                required String name,
                required String phone,
                Value<String> relation = const Value.absent(),
                Value<String> priority = const Value.absent(),
                Value<String?> createdAt = const Value.absent(),
                Value<String?> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalContactsTableCompanion.insert(
                id: id,
                userId: userId,
                name: name,
                phone: phone,
                relation: relation,
                priority: priority,
                createdAt: createdAt,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<$LocalContactsTableTable, LocalContactsTableData>(
                    table,
                  ),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalContactsTableTable,
                    LocalContactsTableData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalContactsTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalContactsTableTable,
      LocalContactsTableData,
      $$LocalContactsTableTableFilterComposer,
      $$LocalContactsTableTableOrderingComposer,
      $$LocalContactsTableTableAnnotationComposer,
      $$LocalContactsTableTableCreateCompanionBuilder,
      $$LocalContactsTableTableUpdateCompanionBuilder,
      (
        LocalContactsTableData,
        BaseReferences<
          _$AppDatabase,
          $LocalContactsTableTable,
          LocalContactsTableData
        >,
      ),
      LocalContactsTableData,
      PrefetchHooks Function()
    >;
typedef $$LocalSosSessionTableTableCreateCompanionBuilder =
    LocalSosSessionTableCompanion Function({
      required String sosDocId,
      required String userId,
      Value<double> latitude,
      Value<double> longitude,
      required String startedAt,
      Value<String> currentLevel,
      Value<bool> isResolved,
      Value<String?> resolvedAt,
      Value<String> alertedPhones,
      Value<String> alertedPriorities,
      required String updatedAt,
      Value<String> syncStatus,
      Value<String> triggerSource,
      Value<int> rowid,
    });
typedef $$LocalSosSessionTableTableUpdateCompanionBuilder =
    LocalSosSessionTableCompanion Function({
      Value<String> sosDocId,
      Value<String> userId,
      Value<double> latitude,
      Value<double> longitude,
      Value<String> startedAt,
      Value<String> currentLevel,
      Value<bool> isResolved,
      Value<String?> resolvedAt,
      Value<String> alertedPhones,
      Value<String> alertedPriorities,
      Value<String> updatedAt,
      Value<String> syncStatus,
      Value<String> triggerSource,
      Value<int> rowid,
    });

class $$LocalSosSessionTableTableFilterComposer
    extends Composer<_$AppDatabase, $LocalSosSessionTableTable> {
  $$LocalSosSessionTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get sosDocId => $composableBuilder(
    column: $table.sosDocId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get currentLevel => $composableBuilder(
    column: $table.currentLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isResolved => $composableBuilder(
    column: $table.isResolved,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alertedPhones => $composableBuilder(
    column: $table.alertedPhones,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get alertedPriorities => $composableBuilder(
    column: $table.alertedPriorities,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get triggerSource => $composableBuilder(
    column: $table.triggerSource,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalSosSessionTableTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalSosSessionTableTable> {
  $$LocalSosSessionTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get sosDocId => $composableBuilder(
    column: $table.sosDocId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get currentLevel => $composableBuilder(
    column: $table.currentLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isResolved => $composableBuilder(
    column: $table.isResolved,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alertedPhones => $composableBuilder(
    column: $table.alertedPhones,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get alertedPriorities => $composableBuilder(
    column: $table.alertedPriorities,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get triggerSource => $composableBuilder(
    column: $table.triggerSource,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalSosSessionTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalSosSessionTableTable> {
  $$LocalSosSessionTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get sosDocId =>
      $composableBuilder(column: $table.sosDocId, builder: (column) => column);

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<String> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<String> get currentLevel => $composableBuilder(
    column: $table.currentLevel,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isResolved => $composableBuilder(
    column: $table.isResolved,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get alertedPhones => $composableBuilder(
    column: $table.alertedPhones,
    builder: (column) => column,
  );

  GeneratedColumn<String> get alertedPriorities => $composableBuilder(
    column: $table.alertedPriorities,
    builder: (column) => column,
  );

  GeneratedColumn<String> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<String> get triggerSource => $composableBuilder(
    column: $table.triggerSource,
    builder: (column) => column,
  );
}

class $$LocalSosSessionTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalSosSessionTableTable,
          LocalSosSessionTableData,
          $$LocalSosSessionTableTableFilterComposer,
          $$LocalSosSessionTableTableOrderingComposer,
          $$LocalSosSessionTableTableAnnotationComposer,
          $$LocalSosSessionTableTableCreateCompanionBuilder,
          $$LocalSosSessionTableTableUpdateCompanionBuilder,
          (
            LocalSosSessionTableData,
            BaseReferences<
              _$AppDatabase,
              $LocalSosSessionTableTable,
              LocalSosSessionTableData
            >,
          ),
          LocalSosSessionTableData,
          PrefetchHooks Function()
        > {
  $$LocalSosSessionTableTableTableManager(
    _$AppDatabase db,
    $LocalSosSessionTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSosSessionTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSosSessionTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalSosSessionTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> sosDocId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<String> startedAt = const Value.absent(),
                Value<String> currentLevel = const Value.absent(),
                Value<bool> isResolved = const Value.absent(),
                Value<String?> resolvedAt = const Value.absent(),
                Value<String> alertedPhones = const Value.absent(),
                Value<String> alertedPriorities = const Value.absent(),
                Value<String> updatedAt = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<String> triggerSource = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSosSessionTableCompanion(
                sosDocId: sosDocId,
                userId: userId,
                latitude: latitude,
                longitude: longitude,
                startedAt: startedAt,
                currentLevel: currentLevel,
                isResolved: isResolved,
                resolvedAt: resolvedAt,
                alertedPhones: alertedPhones,
                alertedPriorities: alertedPriorities,
                updatedAt: updatedAt,
                syncStatus: syncStatus,
                triggerSource: triggerSource,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String sosDocId,
                required String userId,
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                required String startedAt,
                Value<String> currentLevel = const Value.absent(),
                Value<bool> isResolved = const Value.absent(),
                Value<String?> resolvedAt = const Value.absent(),
                Value<String> alertedPhones = const Value.absent(),
                Value<String> alertedPriorities = const Value.absent(),
                required String updatedAt,
                Value<String> syncStatus = const Value.absent(),
                Value<String> triggerSource = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSosSessionTableCompanion.insert(
                sosDocId: sosDocId,
                userId: userId,
                latitude: latitude,
                longitude: longitude,
                startedAt: startedAt,
                currentLevel: currentLevel,
                isResolved: isResolved,
                resolvedAt: resolvedAt,
                alertedPhones: alertedPhones,
                alertedPriorities: alertedPriorities,
                updatedAt: updatedAt,
                syncStatus: syncStatus,
                triggerSource: triggerSource,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $LocalSosSessionTableTable,
                    LocalSosSessionTableData
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalSosSessionTableTable,
                    LocalSosSessionTableData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalSosSessionTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalSosSessionTableTable,
      LocalSosSessionTableData,
      $$LocalSosSessionTableTableFilterComposer,
      $$LocalSosSessionTableTableOrderingComposer,
      $$LocalSosSessionTableTableAnnotationComposer,
      $$LocalSosSessionTableTableCreateCompanionBuilder,
      $$LocalSosSessionTableTableUpdateCompanionBuilder,
      (
        LocalSosSessionTableData,
        BaseReferences<
          _$AppDatabase,
          $LocalSosSessionTableTable,
          LocalSosSessionTableData
        >,
      ),
      LocalSosSessionTableData,
      PrefetchHooks Function()
    >;
typedef $$LocalSosHistoryTableTableCreateCompanionBuilder =
    LocalSosHistoryTableCompanion Function({
      required String localId,
      Value<String?> firestoreDocId,
      required String userId,
      Value<double> latitude,
      Value<double> longitude,
      required String startedAt,
      Value<String> status,
      Value<String> escalationLevel,
      Value<String?> resolvedAt,
      Value<String?> highAlertedAt,
      Value<String?> mediumAlertedAt,
      Value<String?> lowAlertedAt,
      Value<String> triggerSource,
      Value<String?> smsResultsJson,
      Value<bool?> policeCallAuthorized,
      Value<String> syncStatus,
      Value<int> rowid,
    });
typedef $$LocalSosHistoryTableTableUpdateCompanionBuilder =
    LocalSosHistoryTableCompanion Function({
      Value<String> localId,
      Value<String?> firestoreDocId,
      Value<String> userId,
      Value<double> latitude,
      Value<double> longitude,
      Value<String> startedAt,
      Value<String> status,
      Value<String> escalationLevel,
      Value<String?> resolvedAt,
      Value<String?> highAlertedAt,
      Value<String?> mediumAlertedAt,
      Value<String?> lowAlertedAt,
      Value<String> triggerSource,
      Value<String?> smsResultsJson,
      Value<bool?> policeCallAuthorized,
      Value<String> syncStatus,
      Value<int> rowid,
    });

class $$LocalSosHistoryTableTableFilterComposer
    extends Composer<_$AppDatabase, $LocalSosHistoryTableTable> {
  $$LocalSosHistoryTableTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get firestoreDocId => $composableBuilder(
    column: $table.firestoreDocId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get escalationLevel => $composableBuilder(
    column: $table.escalationLevel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get highAlertedAt => $composableBuilder(
    column: $table.highAlertedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mediumAlertedAt => $composableBuilder(
    column: $table.mediumAlertedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get lowAlertedAt => $composableBuilder(
    column: $table.lowAlertedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get triggerSource => $composableBuilder(
    column: $table.triggerSource,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get smsResultsJson => $composableBuilder(
    column: $table.smsResultsJson,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get policeCallAuthorized => $composableBuilder(
    column: $table.policeCallAuthorized,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocalSosHistoryTableTableOrderingComposer
    extends Composer<_$AppDatabase, $LocalSosHistoryTableTable> {
  $$LocalSosHistoryTableTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get localId => $composableBuilder(
    column: $table.localId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get firestoreDocId => $composableBuilder(
    column: $table.firestoreDocId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get userId => $composableBuilder(
    column: $table.userId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get latitude => $composableBuilder(
    column: $table.latitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get longitude => $composableBuilder(
    column: $table.longitude,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get startedAt => $composableBuilder(
    column: $table.startedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get status => $composableBuilder(
    column: $table.status,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get escalationLevel => $composableBuilder(
    column: $table.escalationLevel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get highAlertedAt => $composableBuilder(
    column: $table.highAlertedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mediumAlertedAt => $composableBuilder(
    column: $table.mediumAlertedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get lowAlertedAt => $composableBuilder(
    column: $table.lowAlertedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get triggerSource => $composableBuilder(
    column: $table.triggerSource,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get smsResultsJson => $composableBuilder(
    column: $table.smsResultsJson,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get policeCallAuthorized => $composableBuilder(
    column: $table.policeCallAuthorized,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocalSosHistoryTableTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocalSosHistoryTableTable> {
  $$LocalSosHistoryTableTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get localId =>
      $composableBuilder(column: $table.localId, builder: (column) => column);

  GeneratedColumn<String> get firestoreDocId => $composableBuilder(
    column: $table.firestoreDocId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get userId =>
      $composableBuilder(column: $table.userId, builder: (column) => column);

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<String> get startedAt =>
      $composableBuilder(column: $table.startedAt, builder: (column) => column);

  GeneratedColumn<String> get status =>
      $composableBuilder(column: $table.status, builder: (column) => column);

  GeneratedColumn<String> get escalationLevel => $composableBuilder(
    column: $table.escalationLevel,
    builder: (column) => column,
  );

  GeneratedColumn<String> get resolvedAt => $composableBuilder(
    column: $table.resolvedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get highAlertedAt => $composableBuilder(
    column: $table.highAlertedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get mediumAlertedAt => $composableBuilder(
    column: $table.mediumAlertedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get lowAlertedAt => $composableBuilder(
    column: $table.lowAlertedAt,
    builder: (column) => column,
  );

  GeneratedColumn<String> get triggerSource => $composableBuilder(
    column: $table.triggerSource,
    builder: (column) => column,
  );

  GeneratedColumn<String> get smsResultsJson => $composableBuilder(
    column: $table.smsResultsJson,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get policeCallAuthorized => $composableBuilder(
    column: $table.policeCallAuthorized,
    builder: (column) => column,
  );

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );
}

class $$LocalSosHistoryTableTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocalSosHistoryTableTable,
          LocalSosHistoryTableData,
          $$LocalSosHistoryTableTableFilterComposer,
          $$LocalSosHistoryTableTableOrderingComposer,
          $$LocalSosHistoryTableTableAnnotationComposer,
          $$LocalSosHistoryTableTableCreateCompanionBuilder,
          $$LocalSosHistoryTableTableUpdateCompanionBuilder,
          (
            LocalSosHistoryTableData,
            BaseReferences<
              _$AppDatabase,
              $LocalSosHistoryTableTable,
              LocalSosHistoryTableData
            >,
          ),
          LocalSosHistoryTableData,
          PrefetchHooks Function()
        > {
  $$LocalSosHistoryTableTableTableManager(
    _$AppDatabase db,
    $LocalSosHistoryTableTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocalSosHistoryTableTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocalSosHistoryTableTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocalSosHistoryTableTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> localId = const Value.absent(),
                Value<String?> firestoreDocId = const Value.absent(),
                Value<String> userId = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<String> startedAt = const Value.absent(),
                Value<String> status = const Value.absent(),
                Value<String> escalationLevel = const Value.absent(),
                Value<String?> resolvedAt = const Value.absent(),
                Value<String?> highAlertedAt = const Value.absent(),
                Value<String?> mediumAlertedAt = const Value.absent(),
                Value<String?> lowAlertedAt = const Value.absent(),
                Value<String> triggerSource = const Value.absent(),
                Value<String?> smsResultsJson = const Value.absent(),
                Value<bool?> policeCallAuthorized = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSosHistoryTableCompanion(
                localId: localId,
                firestoreDocId: firestoreDocId,
                userId: userId,
                latitude: latitude,
                longitude: longitude,
                startedAt: startedAt,
                status: status,
                escalationLevel: escalationLevel,
                resolvedAt: resolvedAt,
                highAlertedAt: highAlertedAt,
                mediumAlertedAt: mediumAlertedAt,
                lowAlertedAt: lowAlertedAt,
                triggerSource: triggerSource,
                smsResultsJson: smsResultsJson,
                policeCallAuthorized: policeCallAuthorized,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String localId,
                Value<String?> firestoreDocId = const Value.absent(),
                required String userId,
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                required String startedAt,
                Value<String> status = const Value.absent(),
                Value<String> escalationLevel = const Value.absent(),
                Value<String?> resolvedAt = const Value.absent(),
                Value<String?> highAlertedAt = const Value.absent(),
                Value<String?> mediumAlertedAt = const Value.absent(),
                Value<String?> lowAlertedAt = const Value.absent(),
                Value<String> triggerSource = const Value.absent(),
                Value<String?> smsResultsJson = const Value.absent(),
                Value<bool?> policeCallAuthorized = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocalSosHistoryTableCompanion.insert(
                localId: localId,
                firestoreDocId: firestoreDocId,
                userId: userId,
                latitude: latitude,
                longitude: longitude,
                startedAt: startedAt,
                status: status,
                escalationLevel: escalationLevel,
                resolvedAt: resolvedAt,
                highAlertedAt: highAlertedAt,
                mediumAlertedAt: mediumAlertedAt,
                lowAlertedAt: lowAlertedAt,
                triggerSource: triggerSource,
                smsResultsJson: smsResultsJson,
                policeCallAuthorized: policeCallAuthorized,
                syncStatus: syncStatus,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable<
                    $LocalSosHistoryTableTable,
                    LocalSosHistoryTableData
                  >(table),
                  BaseReferences<
                    _$AppDatabase,
                    $LocalSosHistoryTableTable,
                    LocalSosHistoryTableData
                  >(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocalSosHistoryTableTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocalSosHistoryTableTable,
      LocalSosHistoryTableData,
      $$LocalSosHistoryTableTableFilterComposer,
      $$LocalSosHistoryTableTableOrderingComposer,
      $$LocalSosHistoryTableTableAnnotationComposer,
      $$LocalSosHistoryTableTableCreateCompanionBuilder,
      $$LocalSosHistoryTableTableUpdateCompanionBuilder,
      (
        LocalSosHistoryTableData,
        BaseReferences<
          _$AppDatabase,
          $LocalSosHistoryTableTable,
          LocalSosHistoryTableData
        >,
      ),
      LocalSosHistoryTableData,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$LocalContactsTableTableTableManager get localContactsTable =>
      $$LocalContactsTableTableTableManager(_db, _db.localContactsTable);
  $$LocalSosSessionTableTableTableManager get localSosSessionTable =>
      $$LocalSosSessionTableTableTableManager(_db, _db.localSosSessionTable);
  $$LocalSosHistoryTableTableTableManager get localSosHistoryTable =>
      $$LocalSosHistoryTableTableTableManager(_db, _db.localSosHistoryTable);
}
