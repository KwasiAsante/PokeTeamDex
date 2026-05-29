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
  final DateTime createdAt;
  final DateTime updatedAt;
  const TeamFolder({
    required this.id,
    required this.name,
    this.remoteId,
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
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  TeamFolder copyWith({
    int? id,
    String? name,
    Value<String?> remoteId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TeamFolder(
    id: id ?? this.id,
    name: name ?? this.name,
    remoteId: remoteId.present ? remoteId.value : this.remoteId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  TeamFolder copyWithCompanion(TeamFoldersCompanion data) {
    return TeamFolder(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
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
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, name, remoteId, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TeamFolder &&
          other.id == this.id &&
          other.name == this.name &&
          other.remoteId == this.remoteId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TeamFoldersCompanion extends UpdateCompanion<TeamFolder> {
  final Value<int> id;
  final Value<String> name;
  final Value<String?> remoteId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const TeamFoldersCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  TeamFoldersCompanion.insert({
    this.id = const Value.absent(),
    required String name,
    this.remoteId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<TeamFolder> custom({
    Expression<int>? id,
    Expression<String>? name,
    Expression<String>? remoteId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (remoteId != null) 'remote_id': remoteId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  TeamFoldersCompanion copyWith({
    Value<int>? id,
    Value<String>? name,
    Value<String?>? remoteId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return TeamFoldersCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      remoteId: remoteId ?? this.remoteId,
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
  final DateTime createdAt;
  final DateTime updatedAt;
  const Team({
    required this.id,
    this.folderId,
    required this.name,
    this.remoteId,
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
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  Team copyWith({
    int? id,
    Value<int?> folderId = const Value.absent(),
    String? name,
    Value<String?> remoteId = const Value.absent(),
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => Team(
    id: id ?? this.id,
    folderId: folderId.present ? folderId.value : this.folderId,
    name: name ?? this.name,
    remoteId: remoteId.present ? remoteId.value : this.remoteId,
    createdAt: createdAt ?? this.createdAt,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  Team copyWithCompanion(TeamsCompanion data) {
    return Team(
      id: data.id.present ? data.id.value : this.id,
      folderId: data.folderId.present ? data.folderId.value : this.folderId,
      name: data.name.present ? data.name.value : this.name,
      remoteId: data.remoteId.present ? data.remoteId.value : this.remoteId,
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
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, folderId, name, remoteId, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is Team &&
          other.id == this.id &&
          other.folderId == this.folderId &&
          other.name == this.name &&
          other.remoteId == this.remoteId &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TeamsCompanion extends UpdateCompanion<Team> {
  final Value<int> id;
  final Value<int?> folderId;
  final Value<String> name;
  final Value<String?> remoteId;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const TeamsCompanion({
    this.id = const Value.absent(),
    this.folderId = const Value.absent(),
    this.name = const Value.absent(),
    this.remoteId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  TeamsCompanion.insert({
    this.id = const Value.absent(),
    this.folderId = const Value.absent(),
    required String name,
    this.remoteId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  }) : name = Value(name);
  static Insertable<Team> custom({
    Expression<int>? id,
    Expression<int>? folderId,
    Expression<String>? name,
    Expression<String>? remoteId,
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (folderId != null) 'folder_id': folderId,
      if (name != null) 'name': name,
      if (remoteId != null) 'remote_id': remoteId,
      if (createdAt != null) 'created_at': createdAt,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  TeamsCompanion copyWith({
    Value<int>? id,
    Value<int?>? folderId,
    Value<String>? name,
    Value<String?>? remoteId,
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return TeamsCompanion(
      id: id ?? this.id,
      folderId: folderId ?? this.folderId,
      name: name ?? this.name,
      remoteId: remoteId ?? this.remoteId,
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
  final DateTime createdAt;
  final DateTime updatedAt;
  const TeamSlot({
    required this.id,
    required this.teamId,
    required this.slot,
    required this.pokemonId,
    this.nickname,
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
    DateTime? createdAt,
    DateTime? updatedAt,
  }) => TeamSlot(
    id: id ?? this.id,
    teamId: teamId ?? this.teamId,
    slot: slot ?? this.slot,
    pokemonId: pokemonId ?? this.pokemonId,
    nickname: nickname.present ? nickname.value : this.nickname,
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
          ..write('createdAt: $createdAt, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, teamId, slot, pokemonId, nickname, createdAt, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is TeamSlot &&
          other.id == this.id &&
          other.teamId == this.teamId &&
          other.slot == this.slot &&
          other.pokemonId == this.pokemonId &&
          other.nickname == this.nickname &&
          other.createdAt == this.createdAt &&
          other.updatedAt == this.updatedAt);
}

class TeamSlotsCompanion extends UpdateCompanion<TeamSlot> {
  final Value<int> id;
  final Value<int> teamId;
  final Value<int> slot;
  final Value<int> pokemonId;
  final Value<String?> nickname;
  final Value<DateTime> createdAt;
  final Value<DateTime> updatedAt;
  const TeamSlotsCompanion({
    this.id = const Value.absent(),
    this.teamId = const Value.absent(),
    this.slot = const Value.absent(),
    this.pokemonId = const Value.absent(),
    this.nickname = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  TeamSlotsCompanion.insert({
    this.id = const Value.absent(),
    required int teamId,
    required int slot,
    required int pokemonId,
    this.nickname = const Value.absent(),
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
    Expression<DateTime>? createdAt,
    Expression<DateTime>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (teamId != null) 'team_id': teamId,
      if (slot != null) 'slot': slot,
      if (pokemonId != null) 'pokemon_id': pokemonId,
      if (nickname != null) 'nickname': nickname,
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
    Value<DateTime>? createdAt,
    Value<DateTime>? updatedAt,
  }) {
    return TeamSlotsCompanion(
      id: id ?? this.id,
      teamId: teamId ?? this.teamId,
      slot: slot ?? this.slot,
      pokemonId: pokemonId ?? this.pokemonId,
      nickname: nickname ?? this.nickname,
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
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$TeamFoldersTableUpdateCompanionBuilder =
    TeamFoldersCompanion Function({
      Value<int> id,
      Value<String> name,
      Value<String?> remoteId,
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
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TeamFoldersCompanion(
                id: id,
                name: name,
                remoteId: remoteId,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String name,
                Value<String?> remoteId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TeamFoldersCompanion.insert(
                id: id,
                name: name,
                remoteId: remoteId,
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
      Value<DateTime> createdAt,
      Value<DateTime> updatedAt,
    });
typedef $$TeamsTableUpdateCompanionBuilder =
    TeamsCompanion Function({
      Value<int> id,
      Value<int?> folderId,
      Value<String> name,
      Value<String?> remoteId,
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
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TeamsCompanion(
                id: id,
                folderId: folderId,
                name: name,
                remoteId: remoteId,
                createdAt: createdAt,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int?> folderId = const Value.absent(),
                required String name,
                Value<String?> remoteId = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TeamsCompanion.insert(
                id: id,
                folderId: folderId,
                name: name,
                remoteId: remoteId,
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
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TeamSlotsCompanion(
                id: id,
                teamId: teamId,
                slot: slot,
                pokemonId: pokemonId,
                nickname: nickname,
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
                Value<DateTime> createdAt = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
              }) => TeamSlotsCompanion.insert(
                id: id,
                teamId: teamId,
                slot: slot,
                pokemonId: pokemonId,
                nickname: nickname,
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
