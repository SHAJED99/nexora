// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database.dart';

// ignore_for_file: type=lint
class $DeviceIdentitiesTable extends DeviceIdentities
    with TableInfo<$DeviceIdentitiesTable, DeviceIdentity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeviceIdentitiesTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _deviceIdMeta = const VerificationMeta(
    'deviceId',
  );
  @override
  late final GeneratedColumn<String> deviceId = GeneratedColumn<String>(
    'device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _signedInMeta = const VerificationMeta(
    'signedIn',
  );
  @override
  late final GeneratedColumn<bool> signedIn = GeneratedColumn<bool>(
    'signed_in',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("signed_in" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _signedInAtMeta = const VerificationMeta(
    'signedInAt',
  );
  @override
  late final GeneratedColumn<DateTime> signedInAt = GeneratedColumn<DateTime>(
    'signed_in_at',
    aliasedName,
    true,
    type: DriftSqlType.dateTime,
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
  static const VerificationMeta _accountUidMeta = const VerificationMeta(
    'accountUid',
  );
  @override
  late final GeneratedColumn<String> accountUid = GeneratedColumn<String>(
    'account_uid',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    deviceId,
    signedIn,
    signedInAt,
    createdAt,
    accountUid,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'device_identities';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeviceIdentity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('signed_in')) {
      context.handle(
        _signedInMeta,
        signedIn.isAcceptableOrUnknown(data['signed_in']!, _signedInMeta),
      );
    }
    if (data.containsKey('signed_in_at')) {
      context.handle(
        _signedInAtMeta,
        signedInAt.isAcceptableOrUnknown(
          data['signed_in_at']!,
          _signedInAtMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    }
    if (data.containsKey('account_uid')) {
      context.handle(
        _accountUidMeta,
        accountUid.isAcceptableOrUnknown(data['account_uid']!, _accountUidMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  DeviceIdentity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeviceIdentity(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      signedIn: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}signed_in'],
      )!,
      signedInAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}signed_in_at'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}created_at'],
      )!,
      accountUid: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}account_uid'],
      ),
    );
  }

  @override
  $DeviceIdentitiesTable createAlias(String alias) {
    return $DeviceIdentitiesTable(attachedDatabase, alias);
  }
}

class DeviceIdentity extends DataClass implements Insertable<DeviceIdentity> {
  final int id;
  final String deviceId;
  final bool signedIn;
  final DateTime? signedInAt;
  final DateTime createdAt;
  final String? accountUid;
  const DeviceIdentity({
    required this.id,
    required this.deviceId,
    required this.signedIn,
    this.signedInAt,
    required this.createdAt,
    this.accountUid,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['device_id'] = Variable<String>(deviceId);
    map['signed_in'] = Variable<bool>(signedIn);
    if (!nullToAbsent || signedInAt != null) {
      map['signed_in_at'] = Variable<DateTime>(signedInAt);
    }
    map['created_at'] = Variable<DateTime>(createdAt);
    if (!nullToAbsent || accountUid != null) {
      map['account_uid'] = Variable<String>(accountUid);
    }
    return map;
  }

  DeviceIdentitiesCompanion toCompanion(bool nullToAbsent) {
    return DeviceIdentitiesCompanion(
      id: Value(id),
      deviceId: Value(deviceId),
      signedIn: Value(signedIn),
      signedInAt: signedInAt == null && nullToAbsent
          ? const Value.absent()
          : Value(signedInAt),
      createdAt: Value(createdAt),
      accountUid: accountUid == null && nullToAbsent
          ? const Value.absent()
          : Value(accountUid),
    );
  }

  factory DeviceIdentity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeviceIdentity(
      id: serializer.fromJson<int>(json['id']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      signedIn: serializer.fromJson<bool>(json['signedIn']),
      signedInAt: serializer.fromJson<DateTime?>(json['signedInAt']),
      createdAt: serializer.fromJson<DateTime>(json['createdAt']),
      accountUid: serializer.fromJson<String?>(json['accountUid']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'deviceId': serializer.toJson<String>(deviceId),
      'signedIn': serializer.toJson<bool>(signedIn),
      'signedInAt': serializer.toJson<DateTime?>(signedInAt),
      'createdAt': serializer.toJson<DateTime>(createdAt),
      'accountUid': serializer.toJson<String?>(accountUid),
    };
  }

  DeviceIdentity copyWith({
    int? id,
    String? deviceId,
    bool? signedIn,
    Value<DateTime?> signedInAt = const Value.absent(),
    DateTime? createdAt,
    Value<String?> accountUid = const Value.absent(),
  }) => DeviceIdentity(
    id: id ?? this.id,
    deviceId: deviceId ?? this.deviceId,
    signedIn: signedIn ?? this.signedIn,
    signedInAt: signedInAt.present ? signedInAt.value : this.signedInAt,
    createdAt: createdAt ?? this.createdAt,
    accountUid: accountUid.present ? accountUid.value : this.accountUid,
  );
  DeviceIdentity copyWithCompanion(DeviceIdentitiesCompanion data) {
    return DeviceIdentity(
      id: data.id.present ? data.id.value : this.id,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      signedIn: data.signedIn.present ? data.signedIn.value : this.signedIn,
      signedInAt: data.signedInAt.present
          ? data.signedInAt.value
          : this.signedInAt,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      accountUid: data.accountUid.present
          ? data.accountUid.value
          : this.accountUid,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeviceIdentity(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('signedIn: $signedIn, ')
          ..write('signedInAt: $signedInAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('accountUid: $accountUid')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, deviceId, signedIn, signedInAt, createdAt, accountUid);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeviceIdentity &&
          other.id == this.id &&
          other.deviceId == this.deviceId &&
          other.signedIn == this.signedIn &&
          other.signedInAt == this.signedInAt &&
          other.createdAt == this.createdAt &&
          other.accountUid == this.accountUid);
}

class DeviceIdentitiesCompanion extends UpdateCompanion<DeviceIdentity> {
  final Value<int> id;
  final Value<String> deviceId;
  final Value<bool> signedIn;
  final Value<DateTime?> signedInAt;
  final Value<DateTime> createdAt;
  final Value<String?> accountUid;
  const DeviceIdentitiesCompanion({
    this.id = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.signedIn = const Value.absent(),
    this.signedInAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.accountUid = const Value.absent(),
  });
  DeviceIdentitiesCompanion.insert({
    this.id = const Value.absent(),
    required String deviceId,
    this.signedIn = const Value.absent(),
    this.signedInAt = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.accountUid = const Value.absent(),
  }) : deviceId = Value(deviceId);
  static Insertable<DeviceIdentity> custom({
    Expression<int>? id,
    Expression<String>? deviceId,
    Expression<bool>? signedIn,
    Expression<DateTime>? signedInAt,
    Expression<DateTime>? createdAt,
    Expression<String>? accountUid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (deviceId != null) 'device_id': deviceId,
      if (signedIn != null) 'signed_in': signedIn,
      if (signedInAt != null) 'signed_in_at': signedInAt,
      if (createdAt != null) 'created_at': createdAt,
      if (accountUid != null) 'account_uid': accountUid,
    });
  }

  DeviceIdentitiesCompanion copyWith({
    Value<int>? id,
    Value<String>? deviceId,
    Value<bool>? signedIn,
    Value<DateTime?>? signedInAt,
    Value<DateTime>? createdAt,
    Value<String?>? accountUid,
  }) {
    return DeviceIdentitiesCompanion(
      id: id ?? this.id,
      deviceId: deviceId ?? this.deviceId,
      signedIn: signedIn ?? this.signedIn,
      signedInAt: signedInAt ?? this.signedInAt,
      createdAt: createdAt ?? this.createdAt,
      accountUid: accountUid ?? this.accountUid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (signedIn.present) {
      map['signed_in'] = Variable<bool>(signedIn.value);
    }
    if (signedInAt.present) {
      map['signed_in_at'] = Variable<DateTime>(signedInAt.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<DateTime>(createdAt.value);
    }
    if (accountUid.present) {
      map['account_uid'] = Variable<String>(accountUid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeviceIdentitiesCompanion(')
          ..write('id: $id, ')
          ..write('deviceId: $deviceId, ')
          ..write('signedIn: $signedIn, ')
          ..write('signedInAt: $signedInAt, ')
          ..write('createdAt: $createdAt, ')
          ..write('accountUid: $accountUid')
          ..write(')'))
        .toString();
  }
}

abstract class _$AppDatabase extends GeneratedDatabase {
  _$AppDatabase(QueryExecutor e) : super(e);
  $AppDatabaseManager get managers => $AppDatabaseManager(this);
  late final $DeviceIdentitiesTable deviceIdentities = $DeviceIdentitiesTable(
    this,
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [deviceIdentities];
}

typedef $$DeviceIdentitiesTableCreateCompanionBuilder =
    DeviceIdentitiesCompanion Function({
      Value<int> id,
      required String deviceId,
      Value<bool> signedIn,
      Value<DateTime?> signedInAt,
      Value<DateTime> createdAt,
      Value<String?> accountUid,
    });
typedef $$DeviceIdentitiesTableUpdateCompanionBuilder =
    DeviceIdentitiesCompanion Function({
      Value<int> id,
      Value<String> deviceId,
      Value<bool> signedIn,
      Value<DateTime?> signedInAt,
      Value<DateTime> createdAt,
      Value<String?> accountUid,
    });

class $$DeviceIdentitiesTableFilterComposer
    extends Composer<_$AppDatabase, $DeviceIdentitiesTable> {
  $$DeviceIdentitiesTableFilterComposer({
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

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get signedIn => $composableBuilder(
    column: $table.signedIn,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get signedInAt => $composableBuilder(
    column: $table.signedInAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get accountUid => $composableBuilder(
    column: $table.accountUid,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeviceIdentitiesTableOrderingComposer
    extends Composer<_$AppDatabase, $DeviceIdentitiesTable> {
  $$DeviceIdentitiesTableOrderingComposer({
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

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get signedIn => $composableBuilder(
    column: $table.signedIn,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get signedInAt => $composableBuilder(
    column: $table.signedInAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get accountUid => $composableBuilder(
    column: $table.accountUid,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeviceIdentitiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeviceIdentitiesTable> {
  $$DeviceIdentitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<bool> get signedIn =>
      $composableBuilder(column: $table.signedIn, builder: (column) => column);

  GeneratedColumn<DateTime> get signedInAt => $composableBuilder(
    column: $table.signedInAt,
    builder: (column) => column,
  );

  GeneratedColumn<DateTime> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get accountUid => $composableBuilder(
    column: $table.accountUid,
    builder: (column) => column,
  );
}

class $$DeviceIdentitiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DeviceIdentitiesTable,
          DeviceIdentity,
          $$DeviceIdentitiesTableFilterComposer,
          $$DeviceIdentitiesTableOrderingComposer,
          $$DeviceIdentitiesTableAnnotationComposer,
          $$DeviceIdentitiesTableCreateCompanionBuilder,
          $$DeviceIdentitiesTableUpdateCompanionBuilder,
          (
            DeviceIdentity,
            BaseReferences<
              _$AppDatabase,
              $DeviceIdentitiesTable,
              DeviceIdentity
            >,
          ),
          DeviceIdentity,
          PrefetchHooks Function()
        > {
  $$DeviceIdentitiesTableTableManager(
    _$AppDatabase db,
    $DeviceIdentitiesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeviceIdentitiesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeviceIdentitiesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeviceIdentitiesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<bool> signedIn = const Value.absent(),
                Value<DateTime?> signedInAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> accountUid = const Value.absent(),
              }) => DeviceIdentitiesCompanion(
                id: id,
                deviceId: deviceId,
                signedIn: signedIn,
                signedInAt: signedInAt,
                createdAt: createdAt,
                accountUid: accountUid,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String deviceId,
                Value<bool> signedIn = const Value.absent(),
                Value<DateTime?> signedInAt = const Value.absent(),
                Value<DateTime> createdAt = const Value.absent(),
                Value<String?> accountUid = const Value.absent(),
              }) => DeviceIdentitiesCompanion.insert(
                id: id,
                deviceId: deviceId,
                signedIn: signedIn,
                signedInAt: signedInAt,
                createdAt: createdAt,
                accountUid: accountUid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeviceIdentitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DeviceIdentitiesTable,
      DeviceIdentity,
      $$DeviceIdentitiesTableFilterComposer,
      $$DeviceIdentitiesTableOrderingComposer,
      $$DeviceIdentitiesTableAnnotationComposer,
      $$DeviceIdentitiesTableCreateCompanionBuilder,
      $$DeviceIdentitiesTableUpdateCompanionBuilder,
      (
        DeviceIdentity,
        BaseReferences<_$AppDatabase, $DeviceIdentitiesTable, DeviceIdentity>,
      ),
      DeviceIdentity,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DeviceIdentitiesTableTableManager get deviceIdentities =>
      $$DeviceIdentitiesTableTableManager(_db, _db.deviceIdentities);
}
