// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_database.dart';

// ignore_for_file: type=lint
class $TeamFoldersTable extends TeamFolders
    with TableInfo<$TeamFoldersTable, TeamFolder> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TeamFoldersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
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
  static const VerificationMeta _remoteIdMeta = const VerificationMeta(
    'remoteId',
  );
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
    'remote_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    defaultValue: const Constant('synced'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    remoteId,
    sortOrder,
    isDeleted,
    syncStatus,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'team_folders';
  @override
  VerificationContext validateIntegrity(
    Insertable<TeamFolder> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
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
  TeamFolder map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TeamFolder(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_id'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TeamFoldersTable createAlias(String alias) {
    return $TeamFoldersTable(attachedDatabase, alias);
  }
}

class TeamFolder extends DataClass implements Insertable<TeamFolder> {
  final int id;
  final String name;
  final String? remoteId;
  final int sortOrder;
  final bool isDeleted;
  final String syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  const TeamFolder({
    required this.id,
    required this.name,
    this.remoteId,
    required this.sortOrder,
    required this.isDeleted,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<String>(remoteId);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['sync_status'] = Variable<String>(syncStatus);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TeamFoldersCompanion toCompanion(bool nullToAbsent) {
    return TeamFoldersCompanion(
      id: Value(id),
      name: Value(name),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      sortOrder: Value(sortOrder),
      isDeleted: Value(isDeleted),
      syncStatus: Value(syncStatus),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TeamFolder.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TeamFolder(
      id: serializer.fromJson<int>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'name': serializer.toJson<String>(name),
      'remoteId': serializer.toJson<String?>(remoteId),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TeamFolder copyWith({
    int? id,
    String? name,
    Value<String?> remoteId = const Value.absent(),
    int? sortOrder,
    bool? isDeleted,
    String? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TeamFolder(
    id: id ?? this.id,
    name: name ?? this.name,
    remoteId: remoteId.present ? remoteId.value : this.remoteId,
    sortOrder: sortOrder ?? this.sortOrder,
    isDeleted: isDeleted ?? this.isDeleted,
    syncStatus: syncStatus ?? this.syncStatus,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TeamFolder copyWithCompanion(TeamFoldersCompanion data) {
    return TeamFolder(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TeamFolder(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('remoteId: $remoteId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    remoteId,
    sortOrder,
    isDeleted,
    syncStatus,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TeamFolder &&
          other.id == this.id &&
          other.name == this.name &&
          other.remoteId == this.remoteId &&
          other.sortOrder == this.sortOrder &&
          other.isDeleted == this.isDeleted &&
          other.syncStatus == this.syncStatus &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TeamFoldersCompanion extends UpdateCompanion<TeamFolder> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> remoteId;
  final Value<int> sortOrder;
  final Value<bool> isDeleted;
  final Value<String> syncStatus;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const TeamFoldersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  TeamFoldersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.remoteId = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<TeamFolder> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? remoteId,
    Expression<int>? sortOrder,
    Expression<bool>? isDeleted,
    Expression<String>? syncStatus,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (remoteId != null) 'remote_id': remoteId,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  TeamFoldersCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? remoteId,
    Value<int>? sortOrder,
    Value<bool>? isDeleted,
    Value<String>? syncStatus,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return TeamFoldersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      remoteId: remoteId ?? this.remoteId,
      sortOrder: sortOrder ?? this.sortOrder,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
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
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TeamFoldersCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('remoteId: $remoteId, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $TeamsTable extends Teams with TableInfo<$TeamsTable, Team> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TeamsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _folderIdMeta = const VerificationMeta(
    'folderId',
  );
  @override
  late final GeneratedColumn<int> folderId = GeneratedColumn<int>(
    'folder_id',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES team_folders (id)',
    ),
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
  static const VerificationMeta _remoteIdMeta = const VerificationMeta(
    'remoteId',
  );
  @override
  late final GeneratedColumn<String> remoteId = GeneratedColumn<String>(
    'remote_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _formatLabelMeta = const VerificationMeta(
    'formatLabel',
  );
  @override
  late final GeneratedColumn<String> formatLabel = GeneratedColumn<String>(
    'format_label',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _sortOrderMeta = const VerificationMeta(
    'sortOrder',
  );
  @override
  late final GeneratedColumn<int> sortOrder = GeneratedColumn<int>(
    'sort_order',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    defaultValue: const Constant('synced'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    folderId,
    name,
    remoteId,
    formatLabel,
    sortOrder,
    isDeleted,
    syncStatus,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'teams';
  @override
  VerificationContext validateIntegrity(
    Insertable<Team> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('folder_id')) {
      context.handle(
        _folderIdMeta,
        folderId.isAcceptableOrUnknown(data['folder_id']!, _folderIdMeta),
      );
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('remote_id')) {
      context.handle(
        _remoteIdMeta,
        remoteId.isAcceptableOrUnknown(data['remote_id']!, _remoteIdMeta),
      );
    }
    if (data.containsKey('format_label')) {
      context.handle(
        _formatLabelMeta,
        formatLabel.isAcceptableOrUnknown(
          data['format_label']!,
          _formatLabelMeta,
        ),
      );
    }
    if (data.containsKey('sort_order')) {
      context.handle(
        _sortOrderMeta,
        sortOrder.isAcceptableOrUnknown(data['sort_order']!, _sortOrderMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
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
  Team map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return Team(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      folderId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}folder_id'],
      ),
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      remoteId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_id'],
      ),
      formatLabel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}format_label'],
      ),
      sortOrder: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sort_order'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TeamsTable createAlias(String alias) {
    return $TeamsTable(attachedDatabase, alias);
  }
}

class Team extends DataClass implements Insertable<Team> {
  final int id;
  final int? folderId;
  final String name;
  final String? remoteId;
  final String? formatLabel;
  final int sortOrder;
  final bool isDeleted;
  final String syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  const Team({
    required this.id,
    this.folderId,
    required this.name,
    this.remoteId,
    this.formatLabel,
    required this.sortOrder,
    required this.isDeleted,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    if (!nullToAbsent || folderId != null) {
      map['folder_id'] = Variable<int>(folderId);
    }
    map['name'] = Variable<String>(name);
    if (!nullToAbsent || remoteId != null) {
      map['remote_id'] = Variable<String>(remoteId);
    }
    if (!nullToAbsent || formatLabel != null) {
      map['format_label'] = Variable<String>(formatLabel);
    }
    map['sort_order'] = Variable<int>(sortOrder);
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['sync_status'] = Variable<String>(syncStatus);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TeamsCompanion toCompanion(bool nullToAbsent) {
    return TeamsCompanion(
      id: Value(id),
      folderId: folderId == null && nullToAbsent
          ? const Value.absent()
          : Value(folderId),
      name: Value(name),
      remoteId: remoteId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteId),
      formatLabel: formatLabel == null && nullToAbsent
          ? const Value.absent()
          : Value(formatLabel),
      sortOrder: Value(sortOrder),
      isDeleted: Value(isDeleted),
      syncStatus: Value(syncStatus),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory Team.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return Team(
      id: serializer.fromJson<int>(json['id']),
      folderId: serializer.fromJson<int?>(json['folderId']),
      name: serializer.fromJson<String>(json['name']),
      remoteId: serializer.fromJson<String?>(json['remoteId']),
      formatLabel: serializer.fromJson<String?>(json['formatLabel']),
      sortOrder: serializer.fromJson<int>(json['sortOrder']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'folderId': serializer.toJson<int?>(folderId),
      'name': serializer.toJson<String>(name),
      'remoteId': serializer.toJson<String?>(remoteId),
      'formatLabel': serializer.toJson<String?>(formatLabel),
      'sortOrder': serializer.toJson<int>(sortOrder),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Team copyWith({
    int? id,
    Value<int?> folderId = const Value.absent(),
    String? name,
    Value<String?> remoteId = const Value.absent(),
    Value<String?> formatLabel = const Value.absent(),
    int? sortOrder,
    bool? isDeleted,
    String? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Team(
    id: id ?? this.id,
    folderId: folderId.present ? folderId.value : this.folderId,
    name: name ?? this.name,
    remoteId: remoteId.present ? remoteId.value : this.remoteId,
    formatLabel: formatLabel.present ? formatLabel.value : this.formatLabel,
    sortOrder: sortOrder ?? this.sortOrder,
    isDeleted: isDeleted ?? this.isDeleted,
    syncStatus: syncStatus ?? this.syncStatus,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Team copyWithCompanion(TeamsCompanion data) {
    return Team(
      id: data.id.present ? data.id.value : this.id,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      name: data.name.present ? data.name.value : this.name,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
      formatLabel: data.formatLabel.present
          ? data.formatLabel.value
          : this.formatLabel,
      sortOrder: data.sortOrder.present ? data.sortOrder.value : this.sortOrder,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('Team(')
          ..write('id: $id, ')
          ..write('folderId: $folderId, ')
          ..write('name: $name, ')
          ..write('remoteId: $remoteId, ')
          ..write('formatLabel: $formatLabel, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    folderId,
    name,
    remoteId,
    formatLabel,
    sortOrder,
    isDeleted,
    syncStatus,
    createdAt,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Team &&
          other.id == this.id &&
          other.folderId == this.folderId &&
          other.name == this.name &&
          other.remoteId == this.remoteId &&
          other.formatLabel == this.formatLabel &&
          other.sortOrder == this.sortOrder &&
          other.isDeleted == this.isDeleted &&
          other.syncStatus == this.syncStatus &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TeamsCompanion extends UpdateCompanion<Team> {
  final Value<int> id;
  final Value<int?> folderId;
  final Value<String> name;
  final Value<String?> remoteId;
  final Value<String?> formatLabel;
  final Value<int> sortOrder;
  final Value<bool> isDeleted;
  final Value<String> syncStatus;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const TeamsCompanion({
    this.id = const Value.absent(),
    this.folderId = const Value.absent(),
    this.name = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.formatLabel = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  TeamsCompanion.insert({
    this.id = const Value.absent(),
    this.folderId = const Value.absent(),
    required String name,
    this.remoteId = const Value.absent(),
    this.formatLabel = const Value.absent(),
    this.sortOrder = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Team> custom({
    Expression<int>? id,
    Expression<int>? folderId,
    Expression<String>? name,
    Expression<String>? remoteId,
    Expression<String>? formatLabel,
    Expression<int>? sortOrder,
    Expression<bool>? isDeleted,
    Expression<String>? syncStatus,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (folderId != null) 'folder_id': folderId,
      if (name != null) 'name': name,
      if (remoteId != null) 'remote_id': remoteId,
      if (formatLabel != null) 'format_label': formatLabel,
      if (sortOrder != null) 'sort_order': sortOrder,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  TeamsCompanion copyWith({
    Value<int>? id,
    Value<int?>? folderId,
    Value<String>? name,
    Value<String?>? remoteId,
    Value<String?>? formatLabel,
    Value<int>? sortOrder,
    Value<bool>? isDeleted,
    Value<String>? syncStatus,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return TeamsCompanion(
      id: id ?? this.id,
      folderId: folderId ?? this.folderId,
      name: name ?? this.name,
      remoteId: remoteId ?? this.remoteId,
      formatLabel: formatLabel ?? this.formatLabel,
      sortOrder: sortOrder ?? this.sortOrder,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (folderId.present) {
      map['folder_id'] = Variable<int>(folderId.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (remoteId.present) {
      map['remote_id'] = Variable<String>(remoteId.value);
    }
    if (formatLabel.present) {
      map['format_label'] = Variable<String>(formatLabel.value);
    }
    if (sortOrder.present) {
      map['sort_order'] = Variable<int>(sortOrder.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TeamsCompanion(')
          ..write('id: $id, ')
          ..write('folderId: $folderId, ')
          ..write('name: $name, ')
          ..write('remoteId: $remoteId, ')
          ..write('formatLabel: $formatLabel, ')
          ..write('sortOrder: $sortOrder, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $TeamSlotsTable extends TeamSlots
    with TableInfo<$TeamSlotsTable, TeamSlot> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $TeamSlotsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _teamIdMeta = const VerificationMeta('teamId');
  @override
  late final GeneratedColumn<int> teamId = GeneratedColumn<int>(
    'team_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'REFERENCES teams (id)',
    ),
  );
  static const VerificationMeta _slotMeta = const VerificationMeta('slot');
  @override
  late final GeneratedColumn<int> slot = GeneratedColumn<int>(
    'slot',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _pokemonIdMeta = const VerificationMeta(
    'pokemonId',
  );
  @override
  late final GeneratedColumn<int> pokemonId = GeneratedColumn<int>(
    'pokemon_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _nicknameMeta = const VerificationMeta(
    'nickname',
  );
  @override
  late final GeneratedColumn<String> nickname = GeneratedColumn<String>(
    'nickname',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _formNameMeta = const VerificationMeta(
    'formName',
  );
  @override
  late final GeneratedColumn<String> formName = GeneratedColumn<String>(
    'form_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _levelMeta = const VerificationMeta('level');
  @override
  late final GeneratedColumn<int> level = GeneratedColumn<int>(
    'level',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _genderMeta = const VerificationMeta('gender');
  @override
  late final GeneratedColumn<String> gender = GeneratedColumn<String>(
    'gender',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isShinyMeta = const VerificationMeta(
    'isShiny',
  );
  @override
  late final GeneratedColumn<bool> isShiny = GeneratedColumn<bool>(
    'is_shiny',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_shiny" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _friendshipMeta = const VerificationMeta(
    'friendship',
  );
  @override
  late final GeneratedColumn<int> friendship = GeneratedColumn<int>(
    'friendship',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _abilityNameMeta = const VerificationMeta(
    'abilityName',
  );
  @override
  late final GeneratedColumn<String> abilityName = GeneratedColumn<String>(
    'ability_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _natureNameMeta = const VerificationMeta(
    'natureName',
  );
  @override
  late final GeneratedColumn<String> natureName = GeneratedColumn<String>(
    'nature_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _heldItemNameMeta = const VerificationMeta(
    'heldItemName',
  );
  @override
  late final GeneratedColumn<String> heldItemName = GeneratedColumn<String>(
    'held_item_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _move1Meta = const VerificationMeta('move1');
  @override
  late final GeneratedColumn<String> move1 = GeneratedColumn<String>(
    'move1',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _move2Meta = const VerificationMeta('move2');
  @override
  late final GeneratedColumn<String> move2 = GeneratedColumn<String>(
    'move2',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _move3Meta = const VerificationMeta('move3');
  @override
  late final GeneratedColumn<String> move3 = GeneratedColumn<String>(
    'move3',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _move4Meta = const VerificationMeta('move4');
  @override
  late final GeneratedColumn<String> move4 = GeneratedColumn<String>(
    'move4',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _evHpMeta = const VerificationMeta('evHp');
  @override
  late final GeneratedColumn<int> evHp = GeneratedColumn<int>(
    'ev_hp',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _evAtkMeta = const VerificationMeta('evAtk');
  @override
  late final GeneratedColumn<int> evAtk = GeneratedColumn<int>(
    'ev_atk',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _evDefMeta = const VerificationMeta('evDef');
  @override
  late final GeneratedColumn<int> evDef = GeneratedColumn<int>(
    'ev_def',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _evSpaMeta = const VerificationMeta('evSpa');
  @override
  late final GeneratedColumn<int> evSpa = GeneratedColumn<int>(
    'ev_spa',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _evSpdMeta = const VerificationMeta('evSpd');
  @override
  late final GeneratedColumn<int> evSpd = GeneratedColumn<int>(
    'ev_spd',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _evSpeMeta = const VerificationMeta('evSpe');
  @override
  late final GeneratedColumn<int> evSpe = GeneratedColumn<int>(
    'ev_spe',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ivHpMeta = const VerificationMeta('ivHp');
  @override
  late final GeneratedColumn<int> ivHp = GeneratedColumn<int>(
    'iv_hp',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ivAtkMeta = const VerificationMeta('ivAtk');
  @override
  late final GeneratedColumn<int> ivAtk = GeneratedColumn<int>(
    'iv_atk',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ivDefMeta = const VerificationMeta('ivDef');
  @override
  late final GeneratedColumn<int> ivDef = GeneratedColumn<int>(
    'iv_def',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ivSpaMeta = const VerificationMeta('ivSpa');
  @override
  late final GeneratedColumn<int> ivSpa = GeneratedColumn<int>(
    'iv_spa',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ivSpdMeta = const VerificationMeta('ivSpd');
  @override
  late final GeneratedColumn<int> ivSpd = GeneratedColumn<int>(
    'iv_spd',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _ivSpeMeta = const VerificationMeta('ivSpe');
  @override
  late final GeneratedColumn<int> ivSpe = GeneratedColumn<int>(
    'iv_spe',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _isDeletedMeta = const VerificationMeta(
    'isDeleted',
  );
  @override
  late final GeneratedColumn<bool> isDeleted = GeneratedColumn<bool>(
    'is_deleted',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("is_deleted" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
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
    defaultValue: const Constant('synced'),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    teamId,
    slot,
    pokemonId,
    nickname,
    formName,
    level,
    gender,
    isShiny,
    friendship,
    abilityName,
    natureName,
    heldItemName,
    move1,
    move2,
    move3,
    move4,
    evHp,
    evAtk,
    evDef,
    evSpa,
    evSpd,
    evSpe,
    ivHp,
    ivAtk,
    ivDef,
    ivSpa,
    ivSpd,
    ivSpe,
    isDeleted,
    syncStatus,
    createdAt,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'team_slots';
  @override
  VerificationContext validateIntegrity(
    Insertable<TeamSlot> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('team_id')) {
      context.handle(
        _teamIdMeta,
        teamId.isAcceptableOrUnknown(data['team_id']!, _teamIdMeta),
      );
    } else if (isInserting) {
      context.missing(_teamIdMeta);
    }
    if (data.containsKey('slot')) {
      context.handle(
        _slotMeta,
        slot.isAcceptableOrUnknown(data['slot']!, _slotMeta),
      );
    } else if (isInserting) {
      context.missing(_slotMeta);
    }
    if (data.containsKey('pokemon_id')) {
      context.handle(
        _pokemonIdMeta,
        pokemonId.isAcceptableOrUnknown(data['pokemon_id']!, _pokemonIdMeta),
      );
    } else if (isInserting) {
      context.missing(_pokemonIdMeta);
    }
    if (data.containsKey('nickname')) {
      context.handle(
        _nicknameMeta,
        nickname.isAcceptableOrUnknown(data['nickname']!, _nicknameMeta),
      );
    }
    if (data.containsKey('form_name')) {
      context.handle(
        _formNameMeta,
        formName.isAcceptableOrUnknown(data['form_name']!, _formNameMeta),
      );
    }
    if (data.containsKey('level')) {
      context.handle(
        _levelMeta,
        level.isAcceptableOrUnknown(data['level']!, _levelMeta),
      );
    }
    if (data.containsKey('gender')) {
      context.handle(
        _genderMeta,
        gender.isAcceptableOrUnknown(data['gender']!, _genderMeta),
      );
    }
    if (data.containsKey('is_shiny')) {
      context.handle(
        _isShinyMeta,
        isShiny.isAcceptableOrUnknown(data['is_shiny']!, _isShinyMeta),
      );
    }
    if (data.containsKey('friendship')) {
      context.handle(
        _friendshipMeta,
        friendship.isAcceptableOrUnknown(data['friendship']!, _friendshipMeta),
      );
    }
    if (data.containsKey('ability_name')) {
      context.handle(
        _abilityNameMeta,
        abilityName.isAcceptableOrUnknown(
          data['ability_name']!,
          _abilityNameMeta,
        ),
      );
    }
    if (data.containsKey('nature_name')) {
      context.handle(
        _natureNameMeta,
        natureName.isAcceptableOrUnknown(data['nature_name']!, _natureNameMeta),
      );
    }
    if (data.containsKey('held_item_name')) {
      context.handle(
        _heldItemNameMeta,
        heldItemName.isAcceptableOrUnknown(
          data['held_item_name']!,
          _heldItemNameMeta,
        ),
      );
    }
    if (data.containsKey('move1')) {
      context.handle(
        _move1Meta,
        move1.isAcceptableOrUnknown(data['move1']!, _move1Meta),
      );
    }
    if (data.containsKey('move2')) {
      context.handle(
        _move2Meta,
        move2.isAcceptableOrUnknown(data['move2']!, _move2Meta),
      );
    }
    if (data.containsKey('move3')) {
      context.handle(
        _move3Meta,
        move3.isAcceptableOrUnknown(data['move3']!, _move3Meta),
      );
    }
    if (data.containsKey('move4')) {
      context.handle(
        _move4Meta,
        move4.isAcceptableOrUnknown(data['move4']!, _move4Meta),
      );
    }
    if (data.containsKey('ev_hp')) {
      context.handle(
        _evHpMeta,
        evHp.isAcceptableOrUnknown(data['ev_hp']!, _evHpMeta),
      );
    }
    if (data.containsKey('ev_atk')) {
      context.handle(
        _evAtkMeta,
        evAtk.isAcceptableOrUnknown(data['ev_atk']!, _evAtkMeta),
      );
    }
    if (data.containsKey('ev_def')) {
      context.handle(
        _evDefMeta,
        evDef.isAcceptableOrUnknown(data['ev_def']!, _evDefMeta),
      );
    }
    if (data.containsKey('ev_spa')) {
      context.handle(
        _evSpaMeta,
        evSpa.isAcceptableOrUnknown(data['ev_spa']!, _evSpaMeta),
      );
    }
    if (data.containsKey('ev_spd')) {
      context.handle(
        _evSpdMeta,
        evSpd.isAcceptableOrUnknown(data['ev_spd']!, _evSpdMeta),
      );
    }
    if (data.containsKey('ev_spe')) {
      context.handle(
        _evSpeMeta,
        evSpe.isAcceptableOrUnknown(data['ev_spe']!, _evSpeMeta),
      );
    }
    if (data.containsKey('iv_hp')) {
      context.handle(
        _ivHpMeta,
        ivHp.isAcceptableOrUnknown(data['iv_hp']!, _ivHpMeta),
      );
    }
    if (data.containsKey('iv_atk')) {
      context.handle(
        _ivAtkMeta,
        ivAtk.isAcceptableOrUnknown(data['iv_atk']!, _ivAtkMeta),
      );
    }
    if (data.containsKey('iv_def')) {
      context.handle(
        _ivDefMeta,
        ivDef.isAcceptableOrUnknown(data['iv_def']!, _ivDefMeta),
      );
    }
    if (data.containsKey('iv_spa')) {
      context.handle(
        _ivSpaMeta,
        ivSpa.isAcceptableOrUnknown(data['iv_spa']!, _ivSpaMeta),
      );
    }
    if (data.containsKey('iv_spd')) {
      context.handle(
        _ivSpdMeta,
        ivSpd.isAcceptableOrUnknown(data['iv_spd']!, _ivSpdMeta),
      );
    }
    if (data.containsKey('iv_spe')) {
      context.handle(
        _ivSpeMeta,
        ivSpe.isAcceptableOrUnknown(data['iv_spe']!, _ivSpeMeta),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    if (data.containsKey('sync_status')) {
      context.handle(
        _syncStatusMeta,
        syncStatus.isAcceptableOrUnknown(data['sync_status']!, _syncStatusMeta),
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
  TeamSlot map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return TeamSlot(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      teamId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}team_id'],
      )!,
      slot: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}slot'],
      )!,
      pokemonId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}pokemon_id'],
      )!,
      nickname: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nickname'],
      ),
      formName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}form_name'],
      ),
      level: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}level'],
      ),
      gender: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}gender'],
      ),
      isShiny: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_shiny'],
      )!,
      friendship: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}friendship'],
      ),
      abilityName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}ability_name'],
      ),
      natureName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}nature_name'],
      ),
      heldItemName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}held_item_name'],
      ),
      move1: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}move1'],
      ),
      move2: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}move2'],
      ),
      move3: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}move3'],
      ),
      move4: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}move4'],
      ),
      evHp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ev_hp'],
      ),
      evAtk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ev_atk'],
      ),
      evDef: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ev_def'],
      ),
      evSpa: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ev_spa'],
      ),
      evSpd: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ev_spd'],
      ),
      evSpe: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}ev_spe'],
      ),
      ivHp: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}iv_hp'],
      ),
      ivAtk: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}iv_atk'],
      ),
      ivDef: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}iv_def'],
      ),
      ivSpa: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}iv_spa'],
      ),
      ivSpd: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}iv_spd'],
      ),
      ivSpe: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}iv_spe'],
      ),
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
      syncStatus: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sync_status'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $TeamSlotsTable createAlias(String alias) {
    return $TeamSlotsTable(attachedDatabase, alias);
  }
}

class TeamSlot extends DataClass implements Insertable<TeamSlot> {
  final int id;
  final int teamId;
  final int slot;
  final int pokemonId;
  final String? nickname;
  final String? formName;
  final int? level;
  final String? gender;
  final bool isShiny;
  final int? friendship;
  final String? abilityName;
  final String? natureName;
  final String? heldItemName;
  final String? move1;
  final String? move2;
  final String? move3;
  final String? move4;
  final int? evHp;
  final int? evAtk;
  final int? evDef;
  final int? evSpa;
  final int? evSpd;
  final int? evSpe;
  final int? ivHp;
  final int? ivAtk;
  final int? ivDef;
  final int? ivSpa;
  final int? ivSpd;
  final int? ivSpe;
  final bool isDeleted;
  final String syncStatus;
  final DateTime createdAt;
  final DateTime updatedAt;
  const TeamSlot({
    required this.id,
    required this.teamId,
    required this.slot,
    required this.pokemonId,
    this.nickname,
    this.formName,
    this.level,
    this.gender,
    required this.isShiny,
    this.friendship,
    this.abilityName,
    this.natureName,
    this.heldItemName,
    this.move1,
    this.move2,
    this.move3,
    this.move4,
    this.evHp,
    this.evAtk,
    this.evDef,
    this.evSpa,
    this.evSpd,
    this.evSpe,
    this.ivHp,
    this.ivAtk,
    this.ivDef,
    this.ivSpa,
    this.ivSpd,
    this.ivSpe,
    required this.isDeleted,
    required this.syncStatus,
    required this.createdAt,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['team_id'] = Variable<int>(teamId);
    map['slot'] = Variable<int>(slot);
    map['pokemon_id'] = Variable<int>(pokemonId);
    if (!nullToAbsent || nickname != null) {
      map['nickname'] = Variable<String>(nickname);
    }
    if (!nullToAbsent || formName != null) {
      map['form_name'] = Variable<String>(formName);
    }
    if (!nullToAbsent || level != null) {
      map['level'] = Variable<int>(level);
    }
    if (!nullToAbsent || gender != null) {
      map['gender'] = Variable<String>(gender);
    }
    map['is_shiny'] = Variable<bool>(isShiny);
    if (!nullToAbsent || friendship != null) {
      map['friendship'] = Variable<int>(friendship);
    }
    if (!nullToAbsent || abilityName != null) {
      map['ability_name'] = Variable<String>(abilityName);
    }
    if (!nullToAbsent || natureName != null) {
      map['nature_name'] = Variable<String>(natureName);
    }
    if (!nullToAbsent || heldItemName != null) {
      map['held_item_name'] = Variable<String>(heldItemName);
    }
    if (!nullToAbsent || move1 != null) {
      map['move1'] = Variable<String>(move1);
    }
    if (!nullToAbsent || move2 != null) {
      map['move2'] = Variable<String>(move2);
    }
    if (!nullToAbsent || move3 != null) {
      map['move3'] = Variable<String>(move3);
    }
    if (!nullToAbsent || move4 != null) {
      map['move4'] = Variable<String>(move4);
    }
    if (!nullToAbsent || evHp != null) {
      map['ev_hp'] = Variable<int>(evHp);
    }
    if (!nullToAbsent || evAtk != null) {
      map['ev_atk'] = Variable<int>(evAtk);
    }
    if (!nullToAbsent || evDef != null) {
      map['ev_def'] = Variable<int>(evDef);
    }
    if (!nullToAbsent || evSpa != null) {
      map['ev_spa'] = Variable<int>(evSpa);
    }
    if (!nullToAbsent || evSpd != null) {
      map['ev_spd'] = Variable<int>(evSpd);
    }
    if (!nullToAbsent || evSpe != null) {
      map['ev_spe'] = Variable<int>(evSpe);
    }
    if (!nullToAbsent || ivHp != null) {
      map['iv_hp'] = Variable<int>(ivHp);
    }
    if (!nullToAbsent || ivAtk != null) {
      map['iv_atk'] = Variable<int>(ivAtk);
    }
    if (!nullToAbsent || ivDef != null) {
      map['iv_def'] = Variable<int>(ivDef);
    }
    if (!nullToAbsent || ivSpa != null) {
      map['iv_spa'] = Variable<int>(ivSpa);
    }
    if (!nullToAbsent || ivSpd != null) {
      map['iv_spd'] = Variable<int>(ivSpd);
    }
    if (!nullToAbsent || ivSpe != null) {
      map['iv_spe'] = Variable<int>(ivSpe);
    }
    map['is_deleted'] = Variable<bool>(isDeleted);
    map['sync_status'] = Variable<String>(syncStatus);
    map['created_at'] = Variable<DateTime>(createdAt);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  TeamSlotsCompanion toCompanion(bool nullToAbsent) {
    return TeamSlotsCompanion(
      id: Value(id),
      teamId: Value(teamId),
      slot: Value(slot),
      pokemonId: Value(pokemonId),
      nickname: nickname == null && nullToAbsent
          ? const Value.absent()
          : Value(nickname),
      formName: formName == null && nullToAbsent
          ? const Value.absent()
          : Value(formName),
      level: level == null && nullToAbsent
          ? const Value.absent()
          : Value(level),
      gender: gender == null && nullToAbsent
          ? const Value.absent()
          : Value(gender),
      isShiny: Value(isShiny),
      friendship: friendship == null && nullToAbsent
          ? const Value.absent()
          : Value(friendship),
      abilityName: abilityName == null && nullToAbsent
          ? const Value.absent()
          : Value(abilityName),
      natureName: natureName == null && nullToAbsent
          ? const Value.absent()
          : Value(natureName),
      heldItemName: heldItemName == null && nullToAbsent
          ? const Value.absent()
          : Value(heldItemName),
      move1: move1 == null && nullToAbsent
          ? const Value.absent()
          : Value(move1),
      move2: move2 == null && nullToAbsent
          ? const Value.absent()
          : Value(move2),
      move3: move3 == null && nullToAbsent
          ? const Value.absent()
          : Value(move3),
      move4: move4 == null && nullToAbsent
          ? const Value.absent()
          : Value(move4),
      evHp: evHp == null && nullToAbsent ? const Value.absent() : Value(evHp),
      evAtk: evAtk == null && nullToAbsent
          ? const Value.absent()
          : Value(evAtk),
      evDef: evDef == null && nullToAbsent
          ? const Value.absent()
          : Value(evDef),
      evSpa: evSpa == null && nullToAbsent
          ? const Value.absent()
          : Value(evSpa),
      evSpd: evSpd == null && nullToAbsent
          ? const Value.absent()
          : Value(evSpd),
      evSpe: evSpe == null && nullToAbsent
          ? const Value.absent()
          : Value(evSpe),
      ivHp: ivHp == null && nullToAbsent ? const Value.absent() : Value(ivHp),
      ivAtk: ivAtk == null && nullToAbsent
          ? const Value.absent()
          : Value(ivAtk),
      ivDef: ivDef == null && nullToAbsent
          ? const Value.absent()
          : Value(ivDef),
      ivSpa: ivSpa == null && nullToAbsent
          ? const Value.absent()
          : Value(ivSpa),
      ivSpd: ivSpd == null && nullToAbsent
          ? const Value.absent()
          : Value(ivSpd),
      ivSpe: ivSpe == null && nullToAbsent
          ? const Value.absent()
          : Value(ivSpe),
      isDeleted: Value(isDeleted),
      syncStatus: Value(syncStatus),
      createdAt: Value(createdAt),
      updatedAt: Value(updatedAt),
    );
  }

  factory TeamSlot.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return TeamSlot(
      id: serializer.fromJson<int>(json['id']),
      teamId: serializer.fromJson<int>(json['teamId']),
      slot: serializer.fromJson<int>(json['slot']),
      pokemonId: serializer.fromJson<int>(json['pokemonId']),
      nickname: serializer.fromJson<String?>(json['nickname']),
      formName: serializer.fromJson<String?>(json['formName']),
      level: serializer.fromJson<int?>(json['level']),
      gender: serializer.fromJson<String?>(json['gender']),
      isShiny: serializer.fromJson<bool>(json['isShiny']),
      friendship: serializer.fromJson<int?>(json['friendship']),
      abilityName: serializer.fromJson<String?>(json['abilityName']),
      natureName: serializer.fromJson<String?>(json['natureName']),
      heldItemName: serializer.fromJson<String?>(json['heldItemName']),
      move1: serializer.fromJson<String?>(json['move1']),
      move2: serializer.fromJson<String?>(json['move2']),
      move3: serializer.fromJson<String?>(json['move3']),
      move4: serializer.fromJson<String?>(json['move4']),
      evHp: serializer.fromJson<int?>(json['evHp']),
      evAtk: serializer.fromJson<int?>(json['evAtk']),
      evDef: serializer.fromJson<int?>(json['evDef']),
      evSpa: serializer.fromJson<int?>(json['evSpa']),
      evSpd: serializer.fromJson<int?>(json['evSpd']),
      evSpe: serializer.fromJson<int?>(json['evSpe']),
      ivHp: serializer.fromJson<int?>(json['ivHp']),
      ivAtk: serializer.fromJson<int?>(json['ivAtk']),
      ivDef: serializer.fromJson<int?>(json['ivDef']),
      ivSpa: serializer.fromJson<int?>(json['ivSpa']),
      ivSpd: serializer.fromJson<int?>(json['ivSpd']),
      ivSpe: serializer.fromJson<int?>(json['ivSpe']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
      syncStatus: serializer.fromJson<String>(json['syncStatus']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'teamId': serializer.toJson<int>(teamId),
      'slot': serializer.toJson<int>(slot),
      'pokemonId': serializer.toJson<int>(pokemonId),
      'nickname': serializer.toJson<String?>(nickname),
      'formName': serializer.toJson<String?>(formName),
      'level': serializer.toJson<int?>(level),
      'gender': serializer.toJson<String?>(gender),
      'isShiny': serializer.toJson<bool>(isShiny),
      'friendship': serializer.toJson<int?>(friendship),
      'abilityName': serializer.toJson<String?>(abilityName),
      'natureName': serializer.toJson<String?>(natureName),
      'heldItemName': serializer.toJson<String?>(heldItemName),
      'move1': serializer.toJson<String?>(move1),
      'move2': serializer.toJson<String?>(move2),
      'move3': serializer.toJson<String?>(move3),
      'move4': serializer.toJson<String?>(move4),
      'evHp': serializer.toJson<int?>(evHp),
      'evAtk': serializer.toJson<int?>(evAtk),
      'evDef': serializer.toJson<int?>(evDef),
      'evSpa': serializer.toJson<int?>(evSpa),
      'evSpd': serializer.toJson<int?>(evSpd),
      'evSpe': serializer.toJson<int?>(evSpe),
      'ivHp': serializer.toJson<int?>(ivHp),
      'ivAtk': serializer.toJson<int?>(ivAtk),
      'ivDef': serializer.toJson<int?>(ivDef),
      'ivSpa': serializer.toJson<int?>(ivSpa),
      'ivSpd': serializer.toJson<int?>(ivSpd),
      'ivSpe': serializer.toJson<int?>(ivSpe),
      'isDeleted': serializer.toJson<bool>(isDeleted),
      'syncStatus': serializer.toJson<String>(syncStatus),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TeamSlot copyWith({
    int? id,
    int? teamId,
    int? slot,
    int? pokemonId,
    Value<String?> nickname = const Value.absent(),
    Value<String?> formName = const Value.absent(),
    Value<int?> level = const Value.absent(),
    Value<String?> gender = const Value.absent(),
    bool? isShiny,
    Value<int?> friendship = const Value.absent(),
    Value<String?> abilityName = const Value.absent(),
    Value<String?> natureName = const Value.absent(),
    Value<String?> heldItemName = const Value.absent(),
    Value<String?> move1 = const Value.absent(),
    Value<String?> move2 = const Value.absent(),
    Value<String?> move3 = const Value.absent(),
    Value<String?> move4 = const Value.absent(),
    Value<int?> evHp = const Value.absent(),
    Value<int?> evAtk = const Value.absent(),
    Value<int?> evDef = const Value.absent(),
    Value<int?> evSpa = const Value.absent(),
    Value<int?> evSpd = const Value.absent(),
    Value<int?> evSpe = const Value.absent(),
    Value<int?> ivHp = const Value.absent(),
    Value<int?> ivAtk = const Value.absent(),
    Value<int?> ivDef = const Value.absent(),
    Value<int?> ivSpa = const Value.absent(),
    Value<int?> ivSpd = const Value.absent(),
    Value<int?> ivSpe = const Value.absent(),
    bool? isDeleted,
    String? syncStatus,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TeamSlot(
    id: id ?? this.id,
    teamId: teamId ?? this.teamId,
    slot: slot ?? this.slot,
    pokemonId: pokemonId ?? this.pokemonId,
    nickname: nickname.present ? nickname.value : this.nickname,
    formName: formName.present ? formName.value : this.formName,
    level: level.present ? level.value : this.level,
    gender: gender.present ? gender.value : this.gender,
    isShiny: isShiny ?? this.isShiny,
    friendship: friendship.present ? friendship.value : this.friendship,
    abilityName: abilityName.present ? abilityName.value : this.abilityName,
    natureName: natureName.present ? natureName.value : this.natureName,
    heldItemName: heldItemName.present ? heldItemName.value : this.heldItemName,
    move1: move1.present ? move1.value : this.move1,
    move2: move2.present ? move2.value : this.move2,
    move3: move3.present ? move3.value : this.move3,
    move4: move4.present ? move4.value : this.move4,
    evHp: evHp.present ? evHp.value : this.evHp,
    evAtk: evAtk.present ? evAtk.value : this.evAtk,
    evDef: evDef.present ? evDef.value : this.evDef,
    evSpa: evSpa.present ? evSpa.value : this.evSpa,
    evSpd: evSpd.present ? evSpd.value : this.evSpd,
    evSpe: evSpe.present ? evSpe.value : this.evSpe,
    ivHp: ivHp.present ? ivHp.value : this.ivHp,
    ivAtk: ivAtk.present ? ivAtk.value : this.ivAtk,
    ivDef: ivDef.present ? ivDef.value : this.ivDef,
    ivSpa: ivSpa.present ? ivSpa.value : this.ivSpa,
    ivSpd: ivSpd.present ? ivSpd.value : this.ivSpd,
    ivSpe: ivSpe.present ? ivSpe.value : this.ivSpe,
    isDeleted: isDeleted ?? this.isDeleted,
    syncStatus: syncStatus ?? this.syncStatus,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TeamSlot copyWithCompanion(TeamSlotsCompanion data) {
    return TeamSlot(
      id: data.id.present ? data.id.value : this.id,
      teamId: data.teamId.present ? data.teamId.value : this.teamId,
      slot: data.slot.present ? data.slot.value : this.slot,
      pokemonId: data.pokemonId.present ? data.pokemonId.value : this.pokemonId,
      nickname: data.nickname.present ? data.nickname.value : this.nickname,
      formName: data.formName.present ? data.formName.value : this.formName,
      level: data.level.present ? data.level.value : this.level,
      gender: data.gender.present ? data.gender.value : this.gender,
      isShiny: data.isShiny.present ? data.isShiny.value : this.isShiny,
      friendship: data.friendship.present
          ? data.friendship.value
          : this.friendship,
      abilityName: data.abilityName.present
          ? data.abilityName.value
          : this.abilityName,
      natureName: data.natureName.present
          ? data.natureName.value
          : this.natureName,
      heldItemName: data.heldItemName.present
          ? data.heldItemName.value
          : this.heldItemName,
      move1: data.move1.present ? data.move1.value : this.move1,
      move2: data.move2.present ? data.move2.value : this.move2,
      move3: data.move3.present ? data.move3.value : this.move3,
      move4: data.move4.present ? data.move4.value : this.move4,
      evHp: data.evHp.present ? data.evHp.value : this.evHp,
      evAtk: data.evAtk.present ? data.evAtk.value : this.evAtk,
      evDef: data.evDef.present ? data.evDef.value : this.evDef,
      evSpa: data.evSpa.present ? data.evSpa.value : this.evSpa,
      evSpd: data.evSpd.present ? data.evSpd.value : this.evSpd,
      evSpe: data.evSpe.present ? data.evSpe.value : this.evSpe,
      ivHp: data.ivHp.present ? data.ivHp.value : this.ivHp,
      ivAtk: data.ivAtk.present ? data.ivAtk.value : this.ivAtk,
      ivDef: data.ivDef.present ? data.ivDef.value : this.ivDef,
      ivSpa: data.ivSpa.present ? data.ivSpa.value : this.ivSpa,
      ivSpd: data.ivSpd.present ? data.ivSpd.value : this.ivSpd,
      ivSpe: data.ivSpe.present ? data.ivSpe.value : this.ivSpe,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
      syncStatus: data.syncStatus.present
          ? data.syncStatus.value
          : this.syncStatus,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('TeamSlot(')
          ..write('id: $id, ')
          ..write('teamId: $teamId, ')
          ..write('slot: $slot, ')
          ..write('pokemonId: $pokemonId, ')
          ..write('nickname: $nickname, ')
          ..write('formName: $formName, ')
          ..write('level: $level, ')
          ..write('gender: $gender, ')
          ..write('isShiny: $isShiny, ')
          ..write('friendship: $friendship, ')
          ..write('abilityName: $abilityName, ')
          ..write('natureName: $natureName, ')
          ..write('heldItemName: $heldItemName, ')
          ..write('move1: $move1, ')
          ..write('move2: $move2, ')
          ..write('move3: $move3, ')
          ..write('move4: $move4, ')
          ..write('evHp: $evHp, ')
          ..write('evAtk: $evAtk, ')
          ..write('evDef: $evDef, ')
          ..write('evSpa: $evSpa, ')
          ..write('evSpd: $evSpd, ')
          ..write('evSpe: $evSpe, ')
          ..write('ivHp: $ivHp, ')
          ..write('ivAtk: $ivAtk, ')
          ..write('ivDef: $ivDef, ')
          ..write('ivSpa: $ivSpa, ')
          ..write('ivSpd: $ivSpd, ')
          ..write('ivSpe: $ivSpe, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hashAll([
    id,
    teamId,
    slot,
    pokemonId,
    nickname,
    formName,
    level,
    gender,
    isShiny,
    friendship,
    abilityName,
    natureName,
    heldItemName,
    move1,
    move2,
    move3,
    move4,
    evHp,
    evAtk,
    evDef,
    evSpa,
    evSpd,
    evSpe,
    ivHp,
    ivAtk,
    ivDef,
    ivSpa,
    ivSpd,
    ivSpe,
    isDeleted,
    syncStatus,
    createdAt,
    updatedAt,
  ]);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TeamSlot &&
          other.id == this.id &&
          other.teamId == this.teamId &&
          other.slot == this.slot &&
          other.pokemonId == this.pokemonId &&
          other.nickname == this.nickname &&
          other.formName == this.formName &&
          other.level == this.level &&
          other.gender == this.gender &&
          other.isShiny == this.isShiny &&
          other.friendship == this.friendship &&
          other.abilityName == this.abilityName &&
          other.natureName == this.natureName &&
          other.heldItemName == this.heldItemName &&
          other.move1 == this.move1 &&
          other.move2 == this.move2 &&
          other.move3 == this.move3 &&
          other.move4 == this.move4 &&
          other.evHp == this.evHp &&
          other.evAtk == this.evAtk &&
          other.evDef == this.evDef &&
          other.evSpa == this.evSpa &&
          other.evSpd == this.evSpd &&
          other.evSpe == this.evSpe &&
          other.ivHp == this.ivHp &&
          other.ivAtk == this.ivAtk &&
          other.ivDef == this.ivDef &&
          other.ivSpa == this.ivSpa &&
          other.ivSpd == this.ivSpd &&
          other.ivSpe == this.ivSpe &&
          other.isDeleted == this.isDeleted &&
          other.syncStatus == this.syncStatus &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TeamSlotsCompanion extends UpdateCompanion<TeamSlot> {
  final Value<int> id;
  final Value<int> teamId;
  final Value<int> slot;
  final Value<int> pokemonId;
  final Value<String?> nickname;
  final Value<String?> formName;
  final Value<int?> level;
  final Value<String?> gender;
  final Value<bool> isShiny;
  final Value<int?> friendship;
  final Value<String?> abilityName;
  final Value<String?> natureName;
  final Value<String?> heldItemName;
  final Value<String?> move1;
  final Value<String?> move2;
  final Value<String?> move3;
  final Value<String?> move4;
  final Value<int?> evHp;
  final Value<int?> evAtk;
  final Value<int?> evDef;
  final Value<int?> evSpa;
  final Value<int?> evSpd;
  final Value<int?> evSpe;
  final Value<int?> ivHp;
  final Value<int?> ivAtk;
  final Value<int?> ivDef;
  final Value<int?> ivSpa;
  final Value<int?> ivSpd;
  final Value<int?> ivSpe;
  final Value<bool> isDeleted;
  final Value<String> syncStatus;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const TeamSlotsCompanion({
    this.id = const Value.absent(),
    this.teamId = const Value.absent(),
    this.slot = const Value.absent(),
    this.pokemonId = const Value.absent(),
    this.nickname = const Value.absent(),
    this.formName = const Value.absent(),
    this.level = const Value.absent(),
    this.gender = const Value.absent(),
    this.isShiny = const Value.absent(),
    this.friendship = const Value.absent(),
    this.abilityName = const Value.absent(),
    this.natureName = const Value.absent(),
    this.heldItemName = const Value.absent(),
    this.move1 = const Value.absent(),
    this.move2 = const Value.absent(),
    this.move3 = const Value.absent(),
    this.move4 = const Value.absent(),
    this.evHp = const Value.absent(),
    this.evAtk = const Value.absent(),
    this.evDef = const Value.absent(),
    this.evSpa = const Value.absent(),
    this.evSpd = const Value.absent(),
    this.evSpe = const Value.absent(),
    this.ivHp = const Value.absent(),
    this.ivAtk = const Value.absent(),
    this.ivDef = const Value.absent(),
    this.ivSpa = const Value.absent(),
    this.ivSpd = const Value.absent(),
    this.ivSpe = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  TeamSlotsCompanion.insert({
    this.id = const Value.absent(),
    required int teamId,
    required int slot,
    required int pokemonId,
    this.nickname = const Value.absent(),
    this.formName = const Value.absent(),
    this.level = const Value.absent(),
    this.gender = const Value.absent(),
    this.isShiny = const Value.absent(),
    this.friendship = const Value.absent(),
    this.abilityName = const Value.absent(),
    this.natureName = const Value.absent(),
    this.heldItemName = const Value.absent(),
    this.move1 = const Value.absent(),
    this.move2 = const Value.absent(),
    this.move3 = const Value.absent(),
    this.move4 = const Value.absent(),
    this.evHp = const Value.absent(),
    this.evAtk = const Value.absent(),
    this.evDef = const Value.absent(),
    this.evSpa = const Value.absent(),
    this.evSpd = const Value.absent(),
    this.evSpe = const Value.absent(),
    this.ivHp = const Value.absent(),
    this.ivAtk = const Value.absent(),
    this.ivDef = const Value.absent(),
    this.ivSpa = const Value.absent(),
    this.ivSpd = const Value.absent(),
    this.ivSpe = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.syncStatus = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : teamId = Value(teamId),
       slot = Value(slot),
       pokemonId = Value(pokemonId);
  static Insertable<TeamSlot> custom({
    Expression<int>? id,
    Expression<int>? teamId,
    Expression<int>? slot,
    Expression<int>? pokemonId,
    Expression<String>? nickname,
    Expression<String>? formName,
    Expression<int>? level,
    Expression<String>? gender,
    Expression<bool>? isShiny,
    Expression<int>? friendship,
    Expression<String>? abilityName,
    Expression<String>? natureName,
    Expression<String>? heldItemName,
    Expression<String>? move1,
    Expression<String>? move2,
    Expression<String>? move3,
    Expression<String>? move4,
    Expression<int>? evHp,
    Expression<int>? evAtk,
    Expression<int>? evDef,
    Expression<int>? evSpa,
    Expression<int>? evSpd,
    Expression<int>? evSpe,
    Expression<int>? ivHp,
    Expression<int>? ivAtk,
    Expression<int>? ivDef,
    Expression<int>? ivSpa,
    Expression<int>? ivSpd,
    Expression<int>? ivSpe,
    Expression<bool>? isDeleted,
    Expression<String>? syncStatus,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (teamId != null) 'team_id': teamId,
      if (slot != null) 'slot': slot,
      if (pokemonId != null) 'pokemon_id': pokemonId,
      if (nickname != null) 'nickname': nickname,
      if (formName != null) 'form_name': formName,
      if (level != null) 'level': level,
      if (gender != null) 'gender': gender,
      if (isShiny != null) 'is_shiny': isShiny,
      if (friendship != null) 'friendship': friendship,
      if (abilityName != null) 'ability_name': abilityName,
      if (natureName != null) 'nature_name': natureName,
      if (heldItemName != null) 'held_item_name': heldItemName,
      if (move1 != null) 'move1': move1,
      if (move2 != null) 'move2': move2,
      if (move3 != null) 'move3': move3,
      if (move4 != null) 'move4': move4,
      if (evHp != null) 'ev_hp': evHp,
      if (evAtk != null) 'ev_atk': evAtk,
      if (evDef != null) 'ev_def': evDef,
      if (evSpa != null) 'ev_spa': evSpa,
      if (evSpd != null) 'ev_spd': evSpd,
      if (evSpe != null) 'ev_spe': evSpe,
      if (ivHp != null) 'iv_hp': ivHp,
      if (ivAtk != null) 'iv_atk': ivAtk,
      if (ivDef != null) 'iv_def': ivDef,
      if (ivSpa != null) 'iv_spa': ivSpa,
      if (ivSpd != null) 'iv_spd': ivSpd,
      if (ivSpe != null) 'iv_spe': ivSpe,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (syncStatus != null) 'sync_status': syncStatus,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  TeamSlotsCompanion copyWith({
    Value<int>? id,
    Value<int>? teamId,
    Value<int>? slot,
    Value<int>? pokemonId,
    Value<String?>? nickname,
    Value<String?>? formName,
    Value<int?>? level,
    Value<String?>? gender,
    Value<bool>? isShiny,
    Value<int?>? friendship,
    Value<String?>? abilityName,
    Value<String?>? natureName,
    Value<String?>? heldItemName,
    Value<String?>? move1,
    Value<String?>? move2,
    Value<String?>? move3,
    Value<String?>? move4,
    Value<int?>? evHp,
    Value<int?>? evAtk,
    Value<int?>? evDef,
    Value<int?>? evSpa,
    Value<int?>? evSpd,
    Value<int?>? evSpe,
    Value<int?>? ivHp,
    Value<int?>? ivAtk,
    Value<int?>? ivDef,
    Value<int?>? ivSpa,
    Value<int?>? ivSpd,
    Value<int?>? ivSpe,
    Value<bool>? isDeleted,
    Value<String>? syncStatus,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return TeamSlotsCompanion(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      slot: slot ?? this.slot,
      pokemonId: pokemonId ?? this.pokemonId,
      nickname: nickname ?? this.nickname,
      formName: formName ?? this.formName,
      level: level ?? this.level,
      gender: gender ?? this.gender,
      isShiny: isShiny ?? this.isShiny,
      friendship: friendship ?? this.friendship,
      abilityName: abilityName ?? this.abilityName,
      natureName: natureName ?? this.natureName,
      heldItemName: heldItemName ?? this.heldItemName,
      move1: move1 ?? this.move1,
      move2: move2 ?? this.move2,
      move3: move3 ?? this.move3,
      move4: move4 ?? this.move4,
      evHp: evHp ?? this.evHp,
      evAtk: evAtk ?? this.evAtk,
      evDef: evDef ?? this.evDef,
      evSpa: evSpa ?? this.evSpa,
      evSpd: evSpd ?? this.evSpd,
      evSpe: evSpe ?? this.evSpe,
      ivHp: ivHp ?? this.ivHp,
      ivAtk: ivAtk ?? this.ivAtk,
      ivDef: ivDef ?? this.ivDef,
      ivSpa: ivSpa ?? this.ivSpa,
      ivSpd: ivSpd ?? this.ivSpd,
      ivSpe: ivSpe ?? this.ivSpe,
      isDeleted: isDeleted ?? this.isDeleted,
      syncStatus: syncStatus ?? this.syncStatus,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (teamId.present) {
      map['team_id'] = Variable<int>(teamId.value);
    }
    if (slot.present) {
      map['slot'] = Variable<int>(slot.value);
    }
    if (pokemonId.present) {
      map['pokemon_id'] = Variable<int>(pokemonId.value);
    }
    if (nickname.present) {
      map['nickname'] = Variable<String>(nickname.value);
    }
    if (formName.present) {
      map['form_name'] = Variable<String>(formName.value);
    }
    if (level.present) {
      map['level'] = Variable<int>(level.value);
    }
    if (gender.present) {
      map['gender'] = Variable<String>(gender.value);
    }
    if (isShiny.present) {
      map['is_shiny'] = Variable<bool>(isShiny.value);
    }
    if (friendship.present) {
      map['friendship'] = Variable<int>(friendship.value);
    }
    if (abilityName.present) {
      map['ability_name'] = Variable<String>(abilityName.value);
    }
    if (natureName.present) {
      map['nature_name'] = Variable<String>(natureName.value);
    }
    if (heldItemName.present) {
      map['held_item_name'] = Variable<String>(heldItemName.value);
    }
    if (move1.present) {
      map['move1'] = Variable<String>(move1.value);
    }
    if (move2.present) {
      map['move2'] = Variable<String>(move2.value);
    }
    if (move3.present) {
      map['move3'] = Variable<String>(move3.value);
    }
    if (move4.present) {
      map['move4'] = Variable<String>(move4.value);
    }
    if (evHp.present) {
      map['ev_hp'] = Variable<int>(evHp.value);
    }
    if (evAtk.present) {
      map['ev_atk'] = Variable<int>(evAtk.value);
    }
    if (evDef.present) {
      map['ev_def'] = Variable<int>(evDef.value);
    }
    if (evSpa.present) {
      map['ev_spa'] = Variable<int>(evSpa.value);
    }
    if (evSpd.present) {
      map['ev_spd'] = Variable<int>(evSpd.value);
    }
    if (evSpe.present) {
      map['ev_spe'] = Variable<int>(evSpe.value);
    }
    if (ivHp.present) {
      map['iv_hp'] = Variable<int>(ivHp.value);
    }
    if (ivAtk.present) {
      map['iv_atk'] = Variable<int>(ivAtk.value);
    }
    if (ivDef.present) {
      map['iv_def'] = Variable<int>(ivDef.value);
    }
    if (ivSpa.present) {
      map['iv_spa'] = Variable<int>(ivSpa.value);
    }
    if (ivSpd.present) {
      map['iv_spd'] = Variable<int>(ivSpd.value);
    }
    if (ivSpe.present) {
      map['iv_spe'] = Variable<int>(ivSpe.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (syncStatus.present) {
      map['sync_status'] = Variable<String>(syncStatus.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('TeamSlotsCompanion(')
          ..write('id: $id, ')
          ..write('teamId: $teamId, ')
          ..write('slot: $slot, ')
          ..write('pokemonId: $pokemonId, ')
          ..write('nickname: $nickname, ')
          ..write('formName: $formName, ')
          ..write('level: $level, ')
          ..write('gender: $gender, ')
          ..write('isShiny: $isShiny, ')
          ..write('friendship: $friendship, ')
          ..write('abilityName: $abilityName, ')
          ..write('natureName: $natureName, ')
          ..write('heldItemName: $heldItemName, ')
          ..write('move1: $move1, ')
          ..write('move2: $move2, ')
          ..write('move3: $move3, ')
          ..write('move4: $move4, ')
          ..write('evHp: $evHp, ')
          ..write('evAtk: $evAtk, ')
          ..write('evDef: $evDef, ')
          ..write('evSpa: $evSpa, ')
          ..write('evSpd: $evSpd, ')
          ..write('evSpe: $evSpe, ')
          ..write('ivHp: $ivHp, ')
          ..write('ivAtk: $ivAtk, ')
          ..write('ivDef: $ivDef, ')
          ..write('ivSpa: $ivSpa, ')
          ..write('ivSpd: $ivSpd, ')
          ..write('ivSpe: $ivSpe, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('syncStatus: $syncStatus, ')
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $PendingSyncOpsTable extends PendingSyncOps
    with TableInfo<$PendingSyncOpsTable, PendingSyncOp> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $PendingSyncOpsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    hasAutoIncrement: true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'PRIMARY KEY AUTOINCREMENT',
    ),
  );
  static const VerificationMeta _operationMeta = const VerificationMeta(
    'operation',
  );
  @override
  late final GeneratedColumn<String> operation = GeneratedColumn<String>(
    'operation',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityTypeMeta = const VerificationMeta(
    'entityType',
  );
  @override
  late final GeneratedColumn<String> entityType = GeneratedColumn<String>(
    'entity_type',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _entityIdMeta = const VerificationMeta(
    'entityId',
  );
  @override
  late final GeneratedColumn<int> entityId = GeneratedColumn<int>(
    'entity_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<String> payload = GeneratedColumn<String>(
    'payload',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('{}'),
  );
  static const VerificationMeta _attemptsMeta = const VerificationMeta(
    'attempts',
  );
  @override
  late final GeneratedColumn<int> attempts = GeneratedColumn<int>(
    'attempts',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<DateTime> createdAt = GeneratedColumn<DateTime>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    operation,
    entityType,
    entityId,
    payload,
    attempts,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'pending_sync_ops';
  @override
  VerificationContext validateIntegrity(
    Insertable<PendingSyncOp> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('operation')) {
      context.handle(
        _operationMeta,
        operation.isAcceptableOrUnknown(data['operation']!, _operationMeta),
      );
    } else if (isInserting) {
      context.missing(_operationMeta);
    }
    if (data.containsKey('entity_type')) {
      context.handle(
        _entityTypeMeta,
        entityType.isAcceptableOrUnknown(data['entity_type']!, _entityTypeMeta),
      );
    } else if (isInserting) {
      context.missing(_entityTypeMeta);
    }
    if (data.containsKey('entity_id')) {
      context.handle(
        _entityIdMeta,
        entityId.isAcceptableOrUnknown(data['entity_id']!, _entityIdMeta),
      );
    } else if (isInserting) {
      context.missing(_entityIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    if (data.containsKey('attempts')) {
      context.handle(
        _attemptsMeta,
        attempts.isAcceptableOrUnknown(data['attempts']!, _attemptsMeta),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  PendingSyncOp map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return PendingSyncOp(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      operation: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}operation'],
      )!,
      entityType: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}entity_type'],
      )!,
      entityId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}entity_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}payload'],
      )!,
      attempts: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}attempts'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $PendingSyncOpsTable createAlias(String alias) {
    return $PendingSyncOpsTable(attachedDatabase, alias);
  }
}

class PendingSyncOp extends DataClass implements Insertable<PendingSyncOp> {
  final int id;

  /// 'create' | 'update' | 'delete'
  final String operation;

  /// 'team_folder' | 'team' | 'team_slot'
  final String entityType;
  final int entityId;

  /// JSON payload for create/update operations.
  final String payload;
  final int attempts;
  final DateTime createdAt;
  const PendingSyncOp({
    required this.id,
    required this.operation,
    required this.entityType,
    required this.entityId,
    required this.payload,
    required this.attempts,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['operation'] = Variable<String>(operation);
    map['entity_type'] = Variable<String>(entityType);
    map['entity_id'] = Variable<int>(entityId);
    map['payload'] = Variable<String>(payload);
    map['attempts'] = Variable<int>(attempts);
    map['created_at'] = Variable<DateTime>(createdAt);
    return map;
  }

  PendingSyncOpsCompanion toCompanion(bool nullToAbsent) {
    return PendingSyncOpsCompanion(
      id: Value(id),
      operation: Value(operation),
      entityType: Value(entityType),
      entityId: Value(entityId),
      payload: Value(payload),
      attempts: Value(attempts),
      createdAt: Value(createdAt),
    );
  }

  factory PendingSyncOp.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return PendingSyncOp(
      id: serializer.fromJson<int>(json['id']),
      operation: serializer.fromJson<String>(json['operation']),
      entityType: serializer.fromJson<String>(json['entityType']),
      entityId: serializer.fromJson<int>(json['entityId']),
      payload: serializer.fromJson<String>(json['payload']),
      attempts: serializer.fromJson<int>(json['attempts']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'operation': serializer.toJson<String>(operation),
      'entityType': serializer.toJson<String>(entityType),
      'entityId': serializer.toJson<int>(entityId),
      'payload': serializer.toJson<String>(payload),
      'attempts': serializer.toJson<int>(attempts),
      'createdAt': serializer.toJson<DateTime>(createdAt),
    };
  }

  PendingSyncOp copyWith({
    int? id,
    String? operation,
    String? entityType,
    int? entityId,
    String? payload,
    int? attempts,
    DateTime? createdAt,
  }) => PendingSyncOp(
    id: id ?? this.id,
    operation: operation ?? this.operation,
    entityType: entityType ?? this.entityType,
    entityId: entityId ?? this.entityId,
    payload: payload ?? this.payload,
    attempts: attempts ?? this.attempts,
    createdAt: createdAt ?? this.createdAt,
  );
  PendingSyncOp copyWithCompanion(PendingSyncOpsCompanion data) {
    return PendingSyncOp(
      id: data.id.present ? data.id.value : this.id,
      operation: data.operation.present ? data.operation.value : this.operation,
      entityType: data.entityType.present
          ? data.entityType.value
          : this.entityType,
      entityId: data.entityId.present ? data.entityId.value : this.entityId,
      payload: data.payload.present ? data.payload.value : this.payload,
      attempts: data.attempts.present ? data.attempts.value : this.attempts,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('PendingSyncOp(')
          ..write('id: $id, ')
          ..write('operation: $operation, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('payload: $payload, ')
          ..write('attempts: $attempts, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    operation,
    entityType,
    entityId,
    payload,
    attempts,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is PendingSyncOp &&
          other.id == this.id &&
          other.operation == this.operation &&
          other.entityType == this.entityType &&
          other.entityId == this.entityId &&
          other.payload == this.payload &&
          other.attempts == this.attempts &&
          other.createdAt == this.createdAt);
}

class PendingSyncOpsCompanion extends UpdateCompanion<PendingSyncOp> {
  final Value<int> id;
  final Value<String> operation;
  final Value<String> entityType;
  final Value<int> entityId;
  final Value<String> payload;
  final Value<int> attempts;
  final Value<DateTime> createdAt;
  const PendingSyncOpsCompanion({
    this.id = const Value.absent(),
    this.operation = const Value.absent(),
    this.entityType = const Value.absent(),
    this.entityId = const Value.absent(),
    this.payload = const Value.absent(),
    this.attempts = const Value.absent(),
    this.createdAt = const Value.absent(),
  });
  PendingSyncOpsCompanion.insert({
    this.id = const Value.absent(),
    required String operation,
    required String entityType,
    required int entityId,
    this.payload = const Value.absent(),
    this.attempts = const Value.absent(),
    this.createdAt = const Value.absent(),
  }) : operation = Value(operation),
       entityType = Value(entityType),
       entityId = Value(entityId);
  static Insertable<PendingSyncOp> custom({
    Expression<int>? id,
    Expression<String>? operation,
    Expression<String>? entityType,
    Expression<int>? entityId,
    Expression<String>? payload,
    Expression<int>? attempts,
    Expression<DateTime>? createdAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (operation != null) 'operation': operation,
      if (entityType != null) 'entity_type': entityType,
      if (entityId != null) 'entity_id': entityId,
      if (payload != null) 'payload': payload,
      if (attempts != null) 'attempts': attempts,
      if (createdAt != null) 'created_at': createdAt,
    });
  }

  PendingSyncOpsCompanion copyWith({
    Value<int>? id,
    Value<String>? operation,
    Value<String>? entityType,
    Value<int>? entityId,
    Value<String>? payload,
    Value<int>? attempts,
    Value<DateTime>? createdAt,
  }) {
    return PendingSyncOpsCompanion(
      id: id ?? this.id,
      operation: operation ?? this.operation,
      entityType: entityType ?? this.entityType,
      entityId: entityId ?? this.entityId,
      payload: payload ?? this.payload,
      attempts: attempts ?? this.attempts,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (operation.present) {
      map['operation'] = Variable<String>(operation.value);
    }
    if (entityType.present) {
      map['entity_type'] = Variable<String>(entityType.value);
    }
    if (entityId.present) {
      map['entity_id'] = Variable<int>(entityId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<String>(payload.value);
    }
    if (attempts.present) {
      map['attempts'] = Variable<int>(attempts.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('PendingSyncOpsCompanion(')
          ..write('id: $id, ')
          ..write('operation: $operation, ')
          ..write('entityType: $entityType, ')
          ..write('entityId: $entityId, ')
          ..write('payload: $payload, ')
          ..write('attempts: $attempts, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }
}

class $MetaTable extends Meta with TableInfo<$MetaTable, MetaData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MetaTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'meta';
  @override
  VerificationContext validateIntegrity(
    Insertable<MetaData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  MetaData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MetaData(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
    );
  }

  @override
  $MetaTable createAlias(String alias) {
    return $MetaTable(attachedDatabase, alias);
  }
}

class MetaData extends DataClass implements Insertable<MetaData> {
  final String key;
  final String value;
  const MetaData({required this.key, required this.value});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    return map;
  }

  MetaCompanion toCompanion(bool nullToAbsent) {
    return MetaCompanion(key: Value(key), value: Value(value));
  }

  factory MetaData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MetaData(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
    };
  }

  MetaData copyWith({String? key, String? value}) =>
      MetaData(key: key ?? this.key, value: value ?? this.value);
  MetaData copyWithCompanion(MetaCompanion data) {
    return MetaData(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MetaData(')
          ..write('key: $key, ')
          ..write('value: $value')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MetaData && other.key == this.key && other.value == this.value);
}

class MetaCompanion extends UpdateCompanion<MetaData> {
  final Value<String> key;
  final Value<String> value;
  final Value<int> rowid;
  const MetaCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MetaCompanion.insert({
    required String key,
    required String value,
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<MetaData> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MetaCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<int>? rowid,
  }) {
    return MetaCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MetaCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $AppConfigsTable extends AppConfigs
    with TableInfo<$AppConfigsTable, AppConfig> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $AppConfigsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _keyMeta = const VerificationMeta('key');
  @override
  late final GeneratedColumn<String> key = GeneratedColumn<String>(
    'key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _valueMeta = const VerificationMeta('value');
  @override
  late final GeneratedColumn<String> value = GeneratedColumn<String>(
    'value',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<DateTime> updatedAt = GeneratedColumn<DateTime>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: false,
    defaultValue: currentDateAndTime,
  );
  @override
  List<GeneratedColumn> get $columns => [key, value, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'app_configs';
  @override
  VerificationContext validateIntegrity(
    Insertable<AppConfig> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('key')) {
      context.handle(
        _keyMeta,
        key.isAcceptableOrUnknown(data['key']!, _keyMeta),
      );
    } else if (isInserting) {
      context.missing(_keyMeta);
    }
    if (data.containsKey('value')) {
      context.handle(
        _valueMeta,
        value.isAcceptableOrUnknown(data['value']!, _valueMeta),
      );
    } else if (isInserting) {
      context.missing(_valueMeta);
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
  Set<GeneratedColumn> get $primaryKey => {key};
  @override
  AppConfig map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return AppConfig(
      key: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}key'],
      )!,
      value: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}value'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $AppConfigsTable createAlias(String alias) {
    return $AppConfigsTable(attachedDatabase, alias);
  }
}

class AppConfig extends DataClass implements Insertable<AppConfig> {
  final String key;
  final String value;
  final DateTime updatedAt;
  const AppConfig({
    required this.key,
    required this.value,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['key'] = Variable<String>(key);
    map['value'] = Variable<String>(value);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  AppConfigsCompanion toCompanion(bool nullToAbsent) {
    return AppConfigsCompanion(
      key: Value(key),
      value: Value(value),
      updatedAt: Value(updatedAt),
    );
  }

  factory AppConfig.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return AppConfig(
      key: serializer.fromJson<String>(json['key']),
      value: serializer.fromJson<String>(json['value']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'key': serializer.toJson<String>(key),
      'value': serializer.toJson<String>(value),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  AppConfig copyWith({String? key, String? value, DateTime? updatedAt}) =>
      AppConfig(
        key: key ?? this.key,
        value: value ?? this.value,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  AppConfig copyWithCompanion(AppConfigsCompanion data) {
    return AppConfig(
      key: data.key.present ? data.key.value : this.key,
      value: data.value.present ? data.value.value : this.value,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('AppConfig(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(key, value, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is AppConfig &&
          other.key == this.key &&
          other.value == this.value &&
          other.updatedAt == this.updatedAt);
}

class AppConfigsCompanion extends UpdateCompanion<AppConfig> {
  final Value<String> key;
  final Value<String> value;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const AppConfigsCompanion({
    this.key = const Value.absent(),
    this.value = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  AppConfigsCompanion.insert({
    required String key,
    required String value,
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : key = Value(key),
       value = Value(value);
  static Insertable<AppConfig> custom({
    Expression<String>? key,
    Expression<String>? value,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (key != null) 'key': key,
      if (value != null) 'value': value,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  AppConfigsCompanion copyWith({
    Value<String>? key,
    Value<String>? value,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return AppConfigsCompanion(
      key: key ?? this.key,
      value: value ?? this.value,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (key.present) {
      map['key'] = Variable<String>(key.value);
    }
    if (value.present) {
      map['value'] = Variable<String>(value.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<DateTime>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('AppConfigsCompanion(')
          ..write('key: $key, ')
          ..write('value: $value, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $TeamFoldersTable teamFolders = $TeamFoldersTable(this);
  late final $TeamsTable teams = $TeamsTable(this);
  late final $TeamSlotsTable teamSlots = $TeamSlotsTable(this);
  late final $PendingSyncOpsTable pendingSyncOps = $PendingSyncOpsTable(this);
  late final $MetaTable meta = $MetaTable(this);
  late final $AppConfigsTable appConfigs = $AppConfigsTable(this);
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    teamFolders,
    teams,
    teamSlots,
    pendingSyncOps,
    meta,
    appConfigs,
  ];
}

typedef $$TeamFoldersTableCreateCompanionBuilder =
    TeamFoldersCompanion Function({
      Value<int> id,
      required String name,
      Value<String?> remoteId,
      Value<int> sortOrder,
      Value<bool> isDeleted,
      Value<String> syncStatus,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$TeamFoldersTableUpdateCompanionBuilder =
    TeamFoldersCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> remoteId,
      Value<int> sortOrder,
      Value<bool> isDeleted,
      Value<String> syncStatus,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$TeamFoldersTableReferences
    extends BaseReferences<_$AppDatabase, $TeamFoldersTable, TeamFolder> {
  $$TeamFoldersTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static MultiTypedResultKey<$TeamsTable, List<Team>> _teamsRefsTable(
    _$AppDatabase db,
  ) => MultiTypedResultKey.fromTable(
    db.teams,
    aliasName: $_aliasNameGenerator(db.teamFolders.id, db.teams.folderId),
  );

  $$TeamsTableProcessedTableManager get teamsRefs {
    final manager = $$TeamsTableTableManager(
      $_db,
      $_db.teams,
    ).filter((f) => f.folderId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_teamsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TeamFoldersTableFilterComposer
    extends Composer<_$AppDatabase, $TeamFoldersTable> {
  $$TeamFoldersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  Expression<bool> teamsRefs(
    Expression<bool> Function($$TeamsTableFilterComposer f) f,
  ) {
    final $$TeamsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableFilterComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TeamFoldersTableOrderingComposer
    extends Composer<_$AppDatabase, $TeamFoldersTable> {
  $$TeamFoldersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$TeamFoldersTableAnnotationComposer
    extends Composer<_$AppDatabase, $TeamFoldersTable> {
  $$TeamFoldersTableAnnotationComposer({
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

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  Expression<T> teamsRefs<T extends Object>(
    Expression<T> Function($$TeamsTableAnnotationComposer a) f,
  ) {
    final $$TeamsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.folderId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableAnnotationComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TeamFoldersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TeamFoldersTable,
          TeamFolder,
          $$TeamFoldersTableFilterComposer,
          $$TeamFoldersTableOrderingComposer,
          $$TeamFoldersTableAnnotationComposer,
          $$TeamFoldersTableCreateCompanionBuilder,
          $$TeamFoldersTableUpdateCompanionBuilder,
          (TeamFolder, $$TeamFoldersTableReferences),
          TeamFolder,
          PrefetchHooks Function({bool teamsRefs})
        > {
  $$TeamFoldersTableTableManager(_$AppDatabase db, $TeamFoldersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TeamFoldersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TeamFoldersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TeamFoldersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> remoteId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TeamFoldersCompanion(
                id: id,
                name: name,
                remoteId: remoteId,
                sortOrder: sortOrder,
                isDeleted: isDeleted,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> remoteId = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TeamFoldersCompanion.insert(
                id: id,
                name: name,
                remoteId: remoteId,
                sortOrder: sortOrder,
                isDeleted: isDeleted,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TeamFoldersTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({teamsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (teamsRefs) db.teams],
              addJoins: null,
              getPrefetchedDataCallback: (items) async {
                return [
                  if (teamsRefs)
                    await $_getPrefetchedData<
                      TeamFolder,
                      $TeamFoldersTable,
                      Team
                    >(
                      currentTable: table,
                      referencedTable: $$TeamFoldersTableReferences
                          ._teamsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TeamFoldersTableReferences(db, table, p0).teamsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.folderId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TeamFoldersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TeamFoldersTable,
      TeamFolder,
      $$TeamFoldersTableFilterComposer,
      $$TeamFoldersTableOrderingComposer,
      $$TeamFoldersTableAnnotationComposer,
      $$TeamFoldersTableCreateCompanionBuilder,
      $$TeamFoldersTableUpdateCompanionBuilder,
      (TeamFolder, $$TeamFoldersTableReferences),
      TeamFolder,
      PrefetchHooks Function({bool teamsRefs})
    >;
typedef $$TeamsTableCreateCompanionBuilder =
    TeamsCompanion Function({
      Value<int> id,
      Value<int?> folderId,
      required String name,
      Value<String?> remoteId,
      Value<String?> formatLabel,
      Value<int> sortOrder,
      Value<bool> isDeleted,
      Value<String> syncStatus,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$TeamsTableUpdateCompanionBuilder =
    TeamsCompanion Function({
      Value<int> id,
      Value<int?> folderId,
      Value<String> name,
      Value<String?> remoteId,
      Value<String?> formatLabel,
      Value<int> sortOrder,
      Value<bool> isDeleted,
      Value<String> syncStatus,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$TeamsTableReferences
    extends BaseReferences<_$AppDatabase, $TeamsTable, Team> {
  $$TeamsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TeamFoldersTable _folderIdTable(_$AppDatabase db) => db.teamFolders
      .createAlias($_aliasNameGenerator(db.teams.folderId, db.teamFolders.id));

  $$TeamFoldersTableProcessedTableManager? get folderId {
    final $_column = $_itemColumn<int>('folder_id');
    if ($_column == null) return null;
    final manager = $$TeamFoldersTableTableManager(
      $_db,
      $_db.teamFolders,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_folderIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }

  static MultiTypedResultKey<$TeamSlotsTable, List<TeamSlot>>
  _teamSlotsRefsTable(_$AppDatabase db) => MultiTypedResultKey.fromTable(
    db.teamSlots,
    aliasName: $_aliasNameGenerator(db.teams.id, db.teamSlots.teamId),
  );

  $$TeamSlotsTableProcessedTableManager get teamSlotsRefs {
    final manager = $$TeamSlotsTableTableManager(
      $_db,
      $_db.teamSlots,
    ).filter((f) => f.teamId.id.sqlEquals($_itemColumn<int>('id')!));

    final cache = $_typedResult.readTableOrNull(_teamSlotsRefsTable($_db));
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: cache),
    );
  }
}

class $$TeamsTableFilterComposer extends Composer<_$AppDatabase, $TeamsTable> {
  $$TeamsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get formatLabel => $composableBuilder(
    column: $table.formatLabel,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TeamFoldersTableFilterComposer get folderId {
    final $$TeamFoldersTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.teamFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamFoldersTableFilterComposer(
            $db: $db,
            $table: $db.teamFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<bool> teamSlotsRefs(
    Expression<bool> Function($$TeamSlotsTableFilterComposer f) f,
  ) {
    final $$TeamSlotsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.teamSlots,
      getReferencedColumn: (t) => t.teamId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamSlotsTableFilterComposer(
            $db: $db,
            $table: $db.teamSlots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TeamsTableOrderingComposer
    extends Composer<_$AppDatabase, $TeamsTable> {
  $$TeamsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteId => $composableBuilder(
    column: $table.remoteId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get formatLabel => $composableBuilder(
    column: $table.formatLabel,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sortOrder => $composableBuilder(
    column: $table.sortOrder,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TeamFoldersTableOrderingComposer get folderId {
    final $$TeamFoldersTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.teamFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamFoldersTableOrderingComposer(
            $db: $db,
            $table: $db.teamFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TeamsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TeamsTable> {
  $$TeamsTableAnnotationComposer({
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

  GeneratedColumn<String> get remoteId =>
      $composableBuilder(column: $table.remoteId, builder: (column) => column);

  GeneratedColumn<String> get formatLabel => $composableBuilder(
    column: $table.formatLabel,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sortOrder =>
      $composableBuilder(column: $table.sortOrder, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$TeamFoldersTableAnnotationComposer get folderId {
    final $$TeamFoldersTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.folderId,
      referencedTable: $db.teamFolders,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamFoldersTableAnnotationComposer(
            $db: $db,
            $table: $db.teamFolders,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }

  Expression<T> teamSlotsRefs<T extends Object>(
    Expression<T> Function($$TeamSlotsTableAnnotationComposer a) f,
  ) {
    final $$TeamSlotsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.id,
      referencedTable: $db.teamSlots,
      getReferencedColumn: (t) => t.teamId,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamSlotsTableAnnotationComposer(
            $db: $db,
            $table: $db.teamSlots,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return f(composer);
  }
}

class $$TeamsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TeamsTable,
          Team,
          $$TeamsTableFilterComposer,
          $$TeamsTableOrderingComposer,
          $$TeamsTableAnnotationComposer,
          $$TeamsTableCreateCompanionBuilder,
          $$TeamsTableUpdateCompanionBuilder,
          (Team, $$TeamsTableReferences),
          Team,
          PrefetchHooks Function({bool folderId, bool teamSlotsRefs})
        > {
  $$TeamsTableTableManager(_$AppDatabase db, $TeamsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TeamsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TeamsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TeamsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> folderId = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<String?> remoteId = const Value.absent(),
                Value<String?> formatLabel = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TeamsCompanion(
                id: id,
                folderId: folderId,
                name: name,
                remoteId: remoteId,
                formatLabel: formatLabel,
                sortOrder: sortOrder,
                isDeleted: isDeleted,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> folderId = const Value.absent(),
                required String name,
                Value<String?> remoteId = const Value.absent(),
                Value<String?> formatLabel = const Value.absent(),
                Value<int> sortOrder = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TeamsCompanion.insert(
                id: id,
                folderId: folderId,
                name: name,
                remoteId: remoteId,
                formatLabel: formatLabel,
                sortOrder: sortOrder,
                isDeleted: isDeleted,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) =>
                    (e.readTable(table), $$TeamsTableReferences(db, table, e)),
              )
              .toList(),
          prefetchHooksCallback: ({folderId = false, teamSlotsRefs = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [if (teamSlotsRefs) db.teamSlots],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (folderId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.folderId,
                                referencedTable: $$TeamsTableReferences
                                    ._folderIdTable(db),
                                referencedColumn: $$TeamsTableReferences
                                    ._folderIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [
                  if (teamSlotsRefs)
                    await $_getPrefetchedData<Team, $TeamsTable, TeamSlot>(
                      currentTable: table,
                      referencedTable: $$TeamsTableReferences
                          ._teamSlotsRefsTable(db),
                      managerFromTypedResult: (p0) =>
                          $$TeamsTableReferences(db, table, p0).teamSlotsRefs,
                      referencedItemsForCurrentItem: (item, referencedItems) =>
                          referencedItems.where((e) => e.teamId == item.id),
                      typedResults: items,
                    ),
                ];
              },
            );
          },
        ),
      );
}

typedef $$TeamsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TeamsTable,
      Team,
      $$TeamsTableFilterComposer,
      $$TeamsTableOrderingComposer,
      $$TeamsTableAnnotationComposer,
      $$TeamsTableCreateCompanionBuilder,
      $$TeamsTableUpdateCompanionBuilder,
      (Team, $$TeamsTableReferences),
      Team,
      PrefetchHooks Function({bool folderId, bool teamSlotsRefs})
    >;
typedef $$TeamSlotsTableCreateCompanionBuilder =
    TeamSlotsCompanion Function({
      Value<int> id,
      required int teamId,
      required int slot,
      required int pokemonId,
      Value<String?> nickname,
      Value<String?> formName,
      Value<int?> level,
      Value<String?> gender,
      Value<bool> isShiny,
      Value<int?> friendship,
      Value<String?> abilityName,
      Value<String?> natureName,
      Value<String?> heldItemName,
      Value<String?> move1,
      Value<String?> move2,
      Value<String?> move3,
      Value<String?> move4,
      Value<int?> evHp,
      Value<int?> evAtk,
      Value<int?> evDef,
      Value<int?> evSpa,
      Value<int?> evSpd,
      Value<int?> evSpe,
      Value<int?> ivHp,
      Value<int?> ivAtk,
      Value<int?> ivDef,
      Value<int?> ivSpa,
      Value<int?> ivSpd,
      Value<int?> ivSpe,
      Value<bool> isDeleted,
      Value<String> syncStatus,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$TeamSlotsTableUpdateCompanionBuilder =
    TeamSlotsCompanion Function({
      Value<int> id,
      Value<int> teamId,
      Value<int> slot,
      Value<int> pokemonId,
      Value<String?> nickname,
      Value<String?> formName,
      Value<int?> level,
      Value<String?> gender,
      Value<bool> isShiny,
      Value<int?> friendship,
      Value<String?> abilityName,
      Value<String?> natureName,
      Value<String?> heldItemName,
      Value<String?> move1,
      Value<String?> move2,
      Value<String?> move3,
      Value<String?> move4,
      Value<int?> evHp,
      Value<int?> evAtk,
      Value<int?> evDef,
      Value<int?> evSpa,
      Value<int?> evSpd,
      Value<int?> evSpe,
      Value<int?> ivHp,
      Value<int?> ivAtk,
      Value<int?> ivDef,
      Value<int?> ivSpa,
      Value<int?> ivSpd,
      Value<int?> ivSpe,
      Value<bool> isDeleted,
      Value<String> syncStatus,
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });

final class $$TeamSlotsTableReferences
    extends BaseReferences<_$AppDatabase, $TeamSlotsTable, TeamSlot> {
  $$TeamSlotsTableReferences(super.$_db, super.$_table, super.$_typedResult);

  static $TeamsTable _teamIdTable(_$AppDatabase db) => db.teams.createAlias(
    $_aliasNameGenerator(db.teamSlots.teamId, db.teams.id),
  );

  $$TeamsTableProcessedTableManager get teamId {
    final $_column = $_itemColumn<int>('team_id')!;

    final manager = $$TeamsTableTableManager(
      $_db,
      $_db.teams,
    ).filter((f) => f.id.sqlEquals($_column));
    final item = $_typedResult.readTableOrNull(_teamIdTable($_db));
    if (item == null) return manager;
    return ProcessedTableManager(
      manager.$state.copyWith(prefetchedData: [item]),
    );
  }
}

class $$TeamSlotsTableFilterComposer
    extends Composer<_$AppDatabase, $TeamSlotsTable> {
  $$TeamSlotsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get pokemonId => $composableBuilder(
    column: $table.pokemonId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get formName => $composableBuilder(
    column: $table.formName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get gender => $composableBuilder(
    column: $table.gender,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isShiny => $composableBuilder(
    column: $table.isShiny,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get friendship => $composableBuilder(
    column: $table.friendship,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get abilityName => $composableBuilder(
    column: $table.abilityName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get natureName => $composableBuilder(
    column: $table.natureName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get heldItemName => $composableBuilder(
    column: $table.heldItemName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get move1 => $composableBuilder(
    column: $table.move1,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get move2 => $composableBuilder(
    column: $table.move2,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get move3 => $composableBuilder(
    column: $table.move3,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get move4 => $composableBuilder(
    column: $table.move4,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get evHp => $composableBuilder(
    column: $table.evHp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get evAtk => $composableBuilder(
    column: $table.evAtk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get evDef => $composableBuilder(
    column: $table.evDef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get evSpa => $composableBuilder(
    column: $table.evSpa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get evSpd => $composableBuilder(
    column: $table.evSpd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get evSpe => $composableBuilder(
    column: $table.evSpe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ivHp => $composableBuilder(
    column: $table.ivHp,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ivAtk => $composableBuilder(
    column: $table.ivAtk,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ivDef => $composableBuilder(
    column: $table.ivDef,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ivSpa => $composableBuilder(
    column: $table.ivSpa,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ivSpd => $composableBuilder(
    column: $table.ivSpd,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get ivSpe => $composableBuilder(
    column: $table.ivSpe,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );

  $$TeamsTableFilterComposer get teamId {
    final $$TeamsTableFilterComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.teamId,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableFilterComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TeamSlotsTableOrderingComposer
    extends Composer<_$AppDatabase, $TeamSlotsTable> {
  $$TeamSlotsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get slot => $composableBuilder(
    column: $table.slot,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get pokemonId => $composableBuilder(
    column: $table.pokemonId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get nickname => $composableBuilder(
    column: $table.nickname,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get formName => $composableBuilder(
    column: $table.formName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get level => $composableBuilder(
    column: $table.level,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get gender => $composableBuilder(
    column: $table.gender,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isShiny => $composableBuilder(
    column: $table.isShiny,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get friendship => $composableBuilder(
    column: $table.friendship,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get abilityName => $composableBuilder(
    column: $table.abilityName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get natureName => $composableBuilder(
    column: $table.natureName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get heldItemName => $composableBuilder(
    column: $table.heldItemName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get move1 => $composableBuilder(
    column: $table.move1,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get move2 => $composableBuilder(
    column: $table.move2,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get move3 => $composableBuilder(
    column: $table.move3,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get move4 => $composableBuilder(
    column: $table.move4,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get evHp => $composableBuilder(
    column: $table.evHp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get evAtk => $composableBuilder(
    column: $table.evAtk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get evDef => $composableBuilder(
    column: $table.evDef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get evSpa => $composableBuilder(
    column: $table.evSpa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get evSpd => $composableBuilder(
    column: $table.evSpd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get evSpe => $composableBuilder(
    column: $table.evSpe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ivHp => $composableBuilder(
    column: $table.ivHp,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ivAtk => $composableBuilder(
    column: $table.ivAtk,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ivDef => $composableBuilder(
    column: $table.ivDef,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ivSpa => $composableBuilder(
    column: $table.ivSpa,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ivSpd => $composableBuilder(
    column: $table.ivSpd,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get ivSpe => $composableBuilder(
    column: $table.ivSpe,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );

  $$TeamsTableOrderingComposer get teamId {
    final $$TeamsTableOrderingComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.teamId,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableOrderingComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TeamSlotsTableAnnotationComposer
    extends Composer<_$AppDatabase, $TeamSlotsTable> {
  $$TeamSlotsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get slot =>
      $composableBuilder(column: $table.slot, builder: (column) => column);

  GeneratedColumn<int> get pokemonId =>
      $composableBuilder(column: $table.pokemonId, builder: (column) => column);

  GeneratedColumn<String> get nickname =>
      $composableBuilder(column: $table.nickname, builder: (column) => column);

  GeneratedColumn<String> get formName =>
      $composableBuilder(column: $table.formName, builder: (column) => column);

  GeneratedColumn<int> get level =>
      $composableBuilder(column: $table.level, builder: (column) => column);

  GeneratedColumn<String> get gender =>
      $composableBuilder(column: $table.gender, builder: (column) => column);

  GeneratedColumn<bool> get isShiny =>
      $composableBuilder(column: $table.isShiny, builder: (column) => column);

  GeneratedColumn<int> get friendship => $composableBuilder(
    column: $table.friendship,
    builder: (column) => column,
  );

  GeneratedColumn<String> get abilityName => $composableBuilder(
    column: $table.abilityName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get natureName => $composableBuilder(
    column: $table.natureName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get heldItemName => $composableBuilder(
    column: $table.heldItemName,
    builder: (column) => column,
  );

  GeneratedColumn<String> get move1 =>
      $composableBuilder(column: $table.move1, builder: (column) => column);

  GeneratedColumn<String> get move2 =>
      $composableBuilder(column: $table.move2, builder: (column) => column);

  GeneratedColumn<String> get move3 =>
      $composableBuilder(column: $table.move3, builder: (column) => column);

  GeneratedColumn<String> get move4 =>
      $composableBuilder(column: $table.move4, builder: (column) => column);

  GeneratedColumn<int> get evHp =>
      $composableBuilder(column: $table.evHp, builder: (column) => column);

  GeneratedColumn<int> get evAtk =>
      $composableBuilder(column: $table.evAtk, builder: (column) => column);

  GeneratedColumn<int> get evDef =>
      $composableBuilder(column: $table.evDef, builder: (column) => column);

  GeneratedColumn<int> get evSpa =>
      $composableBuilder(column: $table.evSpa, builder: (column) => column);

  GeneratedColumn<int> get evSpd =>
      $composableBuilder(column: $table.evSpd, builder: (column) => column);

  GeneratedColumn<int> get evSpe =>
      $composableBuilder(column: $table.evSpe, builder: (column) => column);

  GeneratedColumn<int> get ivHp =>
      $composableBuilder(column: $table.ivHp, builder: (column) => column);

  GeneratedColumn<int> get ivAtk =>
      $composableBuilder(column: $table.ivAtk, builder: (column) => column);

  GeneratedColumn<int> get ivDef =>
      $composableBuilder(column: $table.ivDef, builder: (column) => column);

  GeneratedColumn<int> get ivSpa =>
      $composableBuilder(column: $table.ivSpa, builder: (column) => column);

  GeneratedColumn<int> get ivSpd =>
      $composableBuilder(column: $table.ivSpd, builder: (column) => column);

  GeneratedColumn<int> get ivSpe =>
      $composableBuilder(column: $table.ivSpe, builder: (column) => column);

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);

  GeneratedColumn<String> get syncStatus => $composableBuilder(
    column: $table.syncStatus,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);

  $$TeamsTableAnnotationComposer get teamId {
    final $$TeamsTableAnnotationComposer composer = $composerBuilder(
      composer: this,
      getCurrentColumn: (t) => t.teamId,
      referencedTable: $db.teams,
      getReferencedColumn: (t) => t.id,
      builder:
          (
            joinBuilder, {
            $addJoinBuilderToRootComposer,
            $removeJoinBuilderFromRootComposer,
          }) => $$TeamsTableAnnotationComposer(
            $db: $db,
            $table: $db.teams,
            $addJoinBuilderToRootComposer: $addJoinBuilderToRootComposer,
            joinBuilder: joinBuilder,
            $removeJoinBuilderFromRootComposer:
                $removeJoinBuilderFromRootComposer,
          ),
    );
    return composer;
  }
}

class $$TeamSlotsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $TeamSlotsTable,
          TeamSlot,
          $$TeamSlotsTableFilterComposer,
          $$TeamSlotsTableOrderingComposer,
          $$TeamSlotsTableAnnotationComposer,
          $$TeamSlotsTableCreateCompanionBuilder,
          $$TeamSlotsTableUpdateCompanionBuilder,
          (TeamSlot, $$TeamSlotsTableReferences),
          TeamSlot,
          PrefetchHooks Function({bool teamId})
        > {
  $$TeamSlotsTableTableManager(_$AppDatabase db, $TeamSlotsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$TeamSlotsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$TeamSlotsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$TeamSlotsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> teamId = const Value.absent(),
                Value<int> slot = const Value.absent(),
                Value<int> pokemonId = const Value.absent(),
                Value<String?> nickname = const Value.absent(),
                Value<String?> formName = const Value.absent(),
                Value<int?> level = const Value.absent(),
                Value<String?> gender = const Value.absent(),
                Value<bool> isShiny = const Value.absent(),
                Value<int?> friendship = const Value.absent(),
                Value<String?> abilityName = const Value.absent(),
                Value<String?> natureName = const Value.absent(),
                Value<String?> heldItemName = const Value.absent(),
                Value<String?> move1 = const Value.absent(),
                Value<String?> move2 = const Value.absent(),
                Value<String?> move3 = const Value.absent(),
                Value<String?> move4 = const Value.absent(),
                Value<int?> evHp = const Value.absent(),
                Value<int?> evAtk = const Value.absent(),
                Value<int?> evDef = const Value.absent(),
                Value<int?> evSpa = const Value.absent(),
                Value<int?> evSpd = const Value.absent(),
                Value<int?> evSpe = const Value.absent(),
                Value<int?> ivHp = const Value.absent(),
                Value<int?> ivAtk = const Value.absent(),
                Value<int?> ivDef = const Value.absent(),
                Value<int?> ivSpa = const Value.absent(),
                Value<int?> ivSpd = const Value.absent(),
                Value<int?> ivSpe = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TeamSlotsCompanion(
                id: id,
                teamId: teamId,
                slot: slot,
                pokemonId: pokemonId,
                nickname: nickname,
                formName: formName,
                level: level,
                gender: gender,
                isShiny: isShiny,
                friendship: friendship,
                abilityName: abilityName,
                natureName: natureName,
                heldItemName: heldItemName,
                move1: move1,
                move2: move2,
                move3: move3,
                move4: move4,
                evHp: evHp,
                evAtk: evAtk,
                evDef: evDef,
                evSpa: evSpa,
                evSpd: evSpd,
                evSpe: evSpe,
                ivHp: ivHp,
                ivAtk: ivAtk,
                ivDef: ivDef,
                ivSpa: ivSpa,
                ivSpd: ivSpd,
                ivSpe: ivSpe,
                isDeleted: isDeleted,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int teamId,
                required int slot,
                required int pokemonId,
                Value<String?> nickname = const Value.absent(),
                Value<String?> formName = const Value.absent(),
                Value<int?> level = const Value.absent(),
                Value<String?> gender = const Value.absent(),
                Value<bool> isShiny = const Value.absent(),
                Value<int?> friendship = const Value.absent(),
                Value<String?> abilityName = const Value.absent(),
                Value<String?> natureName = const Value.absent(),
                Value<String?> heldItemName = const Value.absent(),
                Value<String?> move1 = const Value.absent(),
                Value<String?> move2 = const Value.absent(),
                Value<String?> move3 = const Value.absent(),
                Value<String?> move4 = const Value.absent(),
                Value<int?> evHp = const Value.absent(),
                Value<int?> evAtk = const Value.absent(),
                Value<int?> evDef = const Value.absent(),
                Value<int?> evSpa = const Value.absent(),
                Value<int?> evSpd = const Value.absent(),
                Value<int?> evSpe = const Value.absent(),
                Value<int?> ivHp = const Value.absent(),
                Value<int?> ivAtk = const Value.absent(),
                Value<int?> ivDef = const Value.absent(),
                Value<int?> ivSpa = const Value.absent(),
                Value<int?> ivSpd = const Value.absent(),
                Value<int?> ivSpe = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<String> syncStatus = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TeamSlotsCompanion.insert(
                id: id,
                teamId: teamId,
                slot: slot,
                pokemonId: pokemonId,
                nickname: nickname,
                formName: formName,
                level: level,
                gender: gender,
                isShiny: isShiny,
                friendship: friendship,
                abilityName: abilityName,
                natureName: natureName,
                heldItemName: heldItemName,
                move1: move1,
                move2: move2,
                move3: move3,
                move4: move4,
                evHp: evHp,
                evAtk: evAtk,
                evDef: evDef,
                evSpa: evSpa,
                evSpd: evSpd,
                evSpe: evSpe,
                ivHp: ivHp,
                ivAtk: ivAtk,
                ivDef: ivDef,
                ivSpa: ivSpa,
                ivSpd: ivSpd,
                ivSpe: ivSpe,
                isDeleted: isDeleted,
                syncStatus: syncStatus,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map(
                (e) => (
                  e.readTable(table),
                  $$TeamSlotsTableReferences(db, table, e),
                ),
              )
              .toList(),
          prefetchHooksCallback: ({teamId = false}) {
            return PrefetchHooks(
              db: db,
              explicitlyWatchedTables: [],
              addJoins:
                  <
                    T extends TableManagerState<
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic,
                      dynamic
                    >
                  >(state) {
                    if (teamId) {
                      state =
                          state.withJoin(
                                currentTable: table,
                                currentColumn: table.teamId,
                                referencedTable: $$TeamSlotsTableReferences
                                    ._teamIdTable(db),
                                referencedColumn: $$TeamSlotsTableReferences
                                    ._teamIdTable(db)
                                    .id,
                              )
                              as T;
                    }

                    return state;
                  },
              getPrefetchedDataCallback: (items) async {
                return [];
              },
            );
          },
        ),
      );
}

typedef $$TeamSlotsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $TeamSlotsTable,
      TeamSlot,
      $$TeamSlotsTableFilterComposer,
      $$TeamSlotsTableOrderingComposer,
      $$TeamSlotsTableAnnotationComposer,
      $$TeamSlotsTableCreateCompanionBuilder,
      $$TeamSlotsTableUpdateCompanionBuilder,
      (TeamSlot, $$TeamSlotsTableReferences),
      TeamSlot,
      PrefetchHooks Function({bool teamId})
    >;
typedef $$PendingSyncOpsTableCreateCompanionBuilder =
    PendingSyncOpsCompanion Function({
      Value<int> id,
      required String operation,
      required String entityType,
      required int entityId,
      Value<String> payload,
      Value<int> attempts,
      Value<DateTime> createdAt,
    });
typedef $$PendingSyncOpsTableUpdateCompanionBuilder =
    PendingSyncOpsCompanion Function({
      Value<int> id,
      Value<String> operation,
      Value<String> entityType,
      Value<int> entityId,
      Value<String> payload,
      Value<int> attempts,
      Value<DateTime> createdAt,
    });

class $$PendingSyncOpsTableFilterComposer
    extends Composer<_$AppDatabase, $PendingSyncOpsTable> {
  $$PendingSyncOpsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$PendingSyncOpsTableOrderingComposer
    extends Composer<_$AppDatabase, $PendingSyncOpsTable> {
  $$PendingSyncOpsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<int> get id => $composableBuilder(
    column: $table.id,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get operation => $composableBuilder(
    column: $table.operation,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get entityId => $composableBuilder(
    column: $table.entityId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get attempts => $composableBuilder(
    column: $table.attempts,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$PendingSyncOpsTableAnnotationComposer
    extends Composer<_$AppDatabase, $PendingSyncOpsTable> {
  $$PendingSyncOpsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get operation =>
      $composableBuilder(column: $table.operation, builder: (column) => column);

  GeneratedColumn<String> get entityType => $composableBuilder(
    column: $table.entityType,
    builder: (column) => column,
  );

  GeneratedColumn<int> get entityId =>
      $composableBuilder(column: $table.entityId, builder: (column) => column);

  GeneratedColumn<String> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get attempts =>
      $composableBuilder(column: $table.attempts, builder: (column) => column);

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$PendingSyncOpsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $PendingSyncOpsTable,
          PendingSyncOp,
          $$PendingSyncOpsTableFilterComposer,
          $$PendingSyncOpsTableOrderingComposer,
          $$PendingSyncOpsTableAnnotationComposer,
          $$PendingSyncOpsTableCreateCompanionBuilder,
          $$PendingSyncOpsTableUpdateCompanionBuilder,
          (
            PendingSyncOp,
            BaseReferences<_$AppDatabase, $PendingSyncOpsTable, PendingSyncOp>,
          ),
          PendingSyncOp,
          PrefetchHooks Function()
        > {
  $$PendingSyncOpsTableTableManager(
    _$AppDatabase db,
    $PendingSyncOpsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$PendingSyncOpsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$PendingSyncOpsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$PendingSyncOpsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> operation = const Value.absent(),
                Value<String> entityType = const Value.absent(),
                Value<int> entityId = const Value.absent(),
                Value<String> payload = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PendingSyncOpsCompanion(
                id: id,
                operation: operation,
                entityType: entityType,
                entityId: entityId,
                payload: payload,
                attempts: attempts,
                createdAt: createdAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String operation,
                required String entityType,
                required int entityId,
                Value<String> payload = const Value.absent(),
                Value<int> attempts = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
              }) => PendingSyncOpsCompanion.insert(
                id: id,
                operation: operation,
                entityType: entityType,
                entityId: entityId,
                payload: payload,
                attempts: attempts,
                createdAt: createdAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$PendingSyncOpsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $PendingSyncOpsTable,
      PendingSyncOp,
      $$PendingSyncOpsTableFilterComposer,
      $$PendingSyncOpsTableOrderingComposer,
      $$PendingSyncOpsTableAnnotationComposer,
      $$PendingSyncOpsTableCreateCompanionBuilder,
      $$PendingSyncOpsTableUpdateCompanionBuilder,
      (
        PendingSyncOp,
        BaseReferences<_$AppDatabase, $PendingSyncOpsTable, PendingSyncOp>,
      ),
      PendingSyncOp,
      PrefetchHooks Function()
    >;
typedef $$MetaTableCreateCompanionBuilder =
    MetaCompanion Function({
      required String key,
      required String value,
      Value<int> rowid,
    });
typedef $$MetaTableUpdateCompanionBuilder =
    MetaCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<int> rowid,
    });

class $$MetaTableFilterComposer extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MetaTableOrderingComposer extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MetaTableAnnotationComposer
    extends Composer<_$AppDatabase, $MetaTable> {
  $$MetaTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);
}

class $$MetaTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MetaTable,
          MetaData,
          $$MetaTableFilterComposer,
          $$MetaTableOrderingComposer,
          $$MetaTableAnnotationComposer,
          $$MetaTableCreateCompanionBuilder,
          $$MetaTableUpdateCompanionBuilder,
          (MetaData, BaseReferences<_$AppDatabase, $MetaTable, MetaData>),
          MetaData,
          PrefetchHooks Function()
        > {
  $$MetaTableTableManager(_$AppDatabase db, $MetaTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MetaTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MetaTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MetaTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MetaCompanion(key: key, value: value, rowid: rowid),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<int> rowid = const Value.absent(),
              }) => MetaCompanion.insert(key: key, value: value, rowid: rowid),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MetaTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MetaTable,
      MetaData,
      $$MetaTableFilterComposer,
      $$MetaTableOrderingComposer,
      $$MetaTableAnnotationComposer,
      $$MetaTableCreateCompanionBuilder,
      $$MetaTableUpdateCompanionBuilder,
      (MetaData, BaseReferences<_$AppDatabase, $MetaTable, MetaData>),
      MetaData,
      PrefetchHooks Function()
    >;
typedef $$AppConfigsTableCreateCompanionBuilder =
    AppConfigsCompanion Function({
      required String key,
      required String value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });
typedef $$AppConfigsTableUpdateCompanionBuilder =
    AppConfigsCompanion Function({
      Value<String> key,
      Value<String> value,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$AppConfigsTableFilterComposer
    extends Composer<_$AppDatabase, $AppConfigsTable> {
  $$AppConfigsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$AppConfigsTableOrderingComposer
    extends Composer<_$AppDatabase, $AppConfigsTable> {
  $$AppConfigsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get key => $composableBuilder(
    column: $table.key,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get value => $composableBuilder(
    column: $table.value,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$AppConfigsTableAnnotationComposer
    extends Composer<_$AppDatabase, $AppConfigsTable> {
  $$AppConfigsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get key =>
      $composableBuilder(column: $table.key, builder: (column) => column);

  GeneratedColumn<String> get value =>
      $composableBuilder(column: $table.value, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$AppConfigsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $AppConfigsTable,
          AppConfig,
          $$AppConfigsTableFilterComposer,
          $$AppConfigsTableOrderingComposer,
          $$AppConfigsTableAnnotationComposer,
          $$AppConfigsTableCreateCompanionBuilder,
          $$AppConfigsTableUpdateCompanionBuilder,
          (
            AppConfig,
            BaseReferences<_$AppDatabase, $AppConfigsTable, AppConfig>,
          ),
          AppConfig,
          PrefetchHooks Function()
        > {
  $$AppConfigsTableTableManager(_$AppDatabase db, $AppConfigsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$AppConfigsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$AppConfigsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$AppConfigsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> key = const Value.absent(),
                Value<String> value = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppConfigsCompanion(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String key,
                required String value,
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => AppConfigsCompanion.insert(
                key: key,
                value: value,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$AppConfigsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $AppConfigsTable,
      AppConfig,
      $$AppConfigsTableFilterComposer,
      $$AppConfigsTableOrderingComposer,
      $$AppConfigsTableAnnotationComposer,
      $$AppConfigsTableCreateCompanionBuilder,
      $$AppConfigsTableUpdateCompanionBuilder,
      (AppConfig, BaseReferences<_$AppDatabase, $AppConfigsTable, AppConfig>),
      AppConfig,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$TeamFoldersTableTableManager get teamFolders =>
      $$TeamFoldersTableTableManager(_db, _db.teamFolders);
  $$TeamsTableTableManager get teams =>
      $$TeamsTableTableManager(_db, _db.teams);
  $$TeamSlotsTableTableManager get teamSlots =>
      $$TeamSlotsTableTableManager(_db, _db.teamSlots);
  $$PendingSyncOpsTableTableManager get pendingSyncOps =>
      $$PendingSyncOpsTableTableManager(_db, _db.pendingSyncOps);
  $$MetaTableTableManager get meta => $$MetaTableTableManager(_db, _db.meta);
  $$AppConfigsTableTableManager get appConfigs =>
      $$AppConfigsTableTableManager(_db, _db.appConfigs);
}
