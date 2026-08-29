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

class $RelationshipsTable extends Relationships
    with TableInfo<$RelationshipsTable, RelationshipRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RelationshipsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
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
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [deviceId, state, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'relationships';
  @override
  VerificationContext validateIntegrity(
    Insertable<RelationshipRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('updated_at')) {
      context.handle(
        _updatedAtMeta,
        updatedAt.isAcceptableOrUnknown(data['updated_at']!, _updatedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_updatedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deviceId};
  @override
  RelationshipRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RelationshipRow(
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $RelationshipsTable createAlias(String alias) {
    return $RelationshipsTable(attachedDatabase, alias);
  }
}

class RelationshipRow extends DataClass implements Insertable<RelationshipRow> {
  final String deviceId;
  final String state;
  final DateTime updatedAt;
  const RelationshipRow({
    required this.deviceId,
    required this.state,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['device_id'] = Variable<String>(deviceId);
    map['state'] = Variable<String>(state);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    return map;
  }

  RelationshipsCompanion toCompanion(bool nullToAbsent) {
    return RelationshipsCompanion(
      deviceId: Value(deviceId),
      state: Value(state),
      updatedAt: Value(updatedAt),
    );
  }

  factory RelationshipRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RelationshipRow(
      deviceId: serializer.fromJson<String>(json['deviceId']),
      state: serializer.fromJson<String>(json['state']),
      updatedAt: serializer.fromJson<DateTime>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deviceId': serializer.toJson<String>(deviceId),
      'state': serializer.toJson<String>(state),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
    };
  }

  RelationshipRow copyWith({
    String? deviceId,
    String? state,
    DateTime? updatedAt,
  }) => RelationshipRow(
    deviceId: deviceId ?? this.deviceId,
    state: state ?? this.state,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  RelationshipRow copyWithCompanion(RelationshipsCompanion data) {
    return RelationshipRow(
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      state: data.state.present ? data.state.value : this.state,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RelationshipRow(')
          ..write('deviceId: $deviceId, ')
          ..write('state: $state, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(deviceId, state, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RelationshipRow &&
          other.deviceId == this.deviceId &&
          other.state == this.state &&
          other.updatedAt == this.updatedAt);
}

class RelationshipsCompanion extends UpdateCompanion<RelationshipRow> {
  final Value<String> deviceId;
  final Value<String> state;
  final Value<DateTime> updatedAt;
  final Value<int> rowid;
  const RelationshipsCompanion({
    this.deviceId = const Value.absent(),
    this.state = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RelationshipsCompanion.insert({
    required String deviceId,
    required String state,
    required DateTime updatedAt,
    this.rowid = const Value.absent(),
  }) : deviceId = Value(deviceId),
       state = Value(state),
       updatedAt = Value(updatedAt);
  static Insertable<RelationshipRow> custom({
    Expression<String>? deviceId,
    Expression<String>? state,
    Expression<DateTime>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deviceId != null) 'device_id': deviceId,
      if (state != null) 'state': state,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RelationshipsCompanion copyWith({
    Value<String>? deviceId,
    Value<String>? state,
    Value<DateTime>? updatedAt,
    Value<int>? rowid,
  }) {
    return RelationshipsCompanion(
      deviceId: deviceId ?? this.deviceId,
      state: state ?? this.state,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
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
    return (StringBuffer('RelationshipsCompanion(')
          ..write('deviceId: $deviceId, ')
          ..write('state: $state, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SignalIdentityTable extends SignalIdentity
    with TableInfo<$SignalIdentityTable, SignalIdentityData> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SignalIdentityTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _identityKeyPairMeta = const VerificationMeta(
    'identityKeyPair',
  );
  @override
  late final GeneratedColumn<Uint8List> identityKeyPair =
      GeneratedColumn<Uint8List>(
        'identity_key_pair',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _registrationIdMeta = const VerificationMeta(
    'registrationId',
  );
  @override
  late final GeneratedColumn<int> registrationId = GeneratedColumn<int>(
    'registration_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, identityKeyPair, registrationId];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'signal_identity';
  @override
  VerificationContext validateIntegrity(
    Insertable<SignalIdentityData> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('identity_key_pair')) {
      context.handle(
        _identityKeyPairMeta,
        identityKeyPair.isAcceptableOrUnknown(
          data['identity_key_pair']!,
          _identityKeyPairMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_identityKeyPairMeta);
    }
    if (data.containsKey('registration_id')) {
      context.handle(
        _registrationIdMeta,
        registrationId.isAcceptableOrUnknown(
          data['registration_id']!,
          _registrationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_registrationIdMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SignalIdentityData map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SignalIdentityData(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      identityKeyPair: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}identity_key_pair'],
      )!,
      registrationId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}registration_id'],
      )!,
    );
  }

  @override
  $SignalIdentityTable createAlias(String alias) {
    return $SignalIdentityTable(attachedDatabase, alias);
  }
}

class SignalIdentityData extends DataClass
    implements Insertable<SignalIdentityData> {
  final int id;
  final Uint8List identityKeyPair;
  final int registrationId;
  const SignalIdentityData({
    required this.id,
    required this.identityKeyPair,
    required this.registrationId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['identity_key_pair'] = Variable<Uint8List>(identityKeyPair);
    map['registration_id'] = Variable<int>(registrationId);
    return map;
  }

  SignalIdentityCompanion toCompanion(bool nullToAbsent) {
    return SignalIdentityCompanion(
      id: Value(id),
      identityKeyPair: Value(identityKeyPair),
      registrationId: Value(registrationId),
    );
  }

  factory SignalIdentityData.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SignalIdentityData(
      id: serializer.fromJson<int>(json['id']),
      identityKeyPair: serializer.fromJson<Uint8List>(json['identityKeyPair']),
      registrationId: serializer.fromJson<int>(json['registrationId']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'identityKeyPair': serializer.toJson<Uint8List>(identityKeyPair),
      'registrationId': serializer.toJson<int>(registrationId),
    };
  }

  SignalIdentityData copyWith({
    int? id,
    Uint8List? identityKeyPair,
    int? registrationId,
  }) => SignalIdentityData(
    id: id ?? this.id,
    identityKeyPair: identityKeyPair ?? this.identityKeyPair,
    registrationId: registrationId ?? this.registrationId,
  );
  SignalIdentityData copyWithCompanion(SignalIdentityCompanion data) {
    return SignalIdentityData(
      id: data.id.present ? data.id.value : this.id,
      identityKeyPair: data.identityKeyPair.present
          ? data.identityKeyPair.value
          : this.identityKeyPair,
      registrationId: data.registrationId.present
          ? data.registrationId.value
          : this.registrationId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SignalIdentityData(')
          ..write('id: $id, ')
          ..write('identityKeyPair: $identityKeyPair, ')
          ..write('registrationId: $registrationId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, $driftBlobEquality.hash(identityKeyPair), registrationId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SignalIdentityData &&
          other.id == this.id &&
          $driftBlobEquality.equals(
            other.identityKeyPair,
            this.identityKeyPair,
          ) &&
          other.registrationId == this.registrationId);
}

class SignalIdentityCompanion extends UpdateCompanion<SignalIdentityData> {
  final Value<int> id;
  final Value<Uint8List> identityKeyPair;
  final Value<int> registrationId;
  const SignalIdentityCompanion({
    this.id = const Value.absent(),
    this.identityKeyPair = const Value.absent(),
    this.registrationId = const Value.absent(),
  });
  SignalIdentityCompanion.insert({
    this.id = const Value.absent(),
    required Uint8List identityKeyPair,
    required int registrationId,
  }) : identityKeyPair = Value(identityKeyPair),
       registrationId = Value(registrationId);
  static Insertable<SignalIdentityData> custom({
    Expression<int>? id,
    Expression<Uint8List>? identityKeyPair,
    Expression<int>? registrationId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (identityKeyPair != null) 'identity_key_pair': identityKeyPair,
      if (registrationId != null) 'registration_id': registrationId,
    });
  }

  SignalIdentityCompanion copyWith({
    Value<int>? id,
    Value<Uint8List>? identityKeyPair,
    Value<int>? registrationId,
  }) {
    return SignalIdentityCompanion(
      id: id ?? this.id,
      identityKeyPair: identityKeyPair ?? this.identityKeyPair,
      registrationId: registrationId ?? this.registrationId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (identityKeyPair.present) {
      map['identity_key_pair'] = Variable<Uint8List>(identityKeyPair.value);
    }
    if (registrationId.present) {
      map['registration_id'] = Variable<int>(registrationId.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SignalIdentityCompanion(')
          ..write('id: $id, ')
          ..write('identityKeyPair: $identityKeyPair, ')
          ..write('registrationId: $registrationId')
          ..write(')'))
        .toString();
  }
}

class $SignalSignedPrekeysTable extends SignalSignedPrekeys
    with TableInfo<$SignalSignedPrekeysTable, SignalSignedPrekey> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SignalSignedPrekeysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recordMeta = const VerificationMeta('record');
  @override
  late final GeneratedColumn<Uint8List> record = GeneratedColumn<Uint8List>(
    'record',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, record];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'signal_signed_prekeys';
  @override
  VerificationContext validateIntegrity(
    Insertable<SignalSignedPrekey> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('record')) {
      context.handle(
        _recordMeta,
        record.isAcceptableOrUnknown(data['record']!, _recordMeta),
      );
    } else if (isInserting) {
      context.missing(_recordMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SignalSignedPrekey map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SignalSignedPrekey(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      record: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}record'],
      )!,
    );
  }

  @override
  $SignalSignedPrekeysTable createAlias(String alias) {
    return $SignalSignedPrekeysTable(attachedDatabase, alias);
  }
}

class SignalSignedPrekey extends DataClass
    implements Insertable<SignalSignedPrekey> {
  final int id;
  final Uint8List record;
  const SignalSignedPrekey({required this.id, required this.record});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['record'] = Variable<Uint8List>(record);
    return map;
  }

  SignalSignedPrekeysCompanion toCompanion(bool nullToAbsent) {
    return SignalSignedPrekeysCompanion(id: Value(id), record: Value(record));
  }

  factory SignalSignedPrekey.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SignalSignedPrekey(
      id: serializer.fromJson<int>(json['id']),
      record: serializer.fromJson<Uint8List>(json['record']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'record': serializer.toJson<Uint8List>(record),
    };
  }

  SignalSignedPrekey copyWith({int? id, Uint8List? record}) =>
      SignalSignedPrekey(id: id ?? this.id, record: record ?? this.record);
  SignalSignedPrekey copyWithCompanion(SignalSignedPrekeysCompanion data) {
    return SignalSignedPrekey(
      id: data.id.present ? data.id.value : this.id,
      record: data.record.present ? data.record.value : this.record,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SignalSignedPrekey(')
          ..write('id: $id, ')
          ..write('record: $record')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, $driftBlobEquality.hash(record));
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SignalSignedPrekey &&
          other.id == this.id &&
          $driftBlobEquality.equals(other.record, this.record));
}

class SignalSignedPrekeysCompanion extends UpdateCompanion<SignalSignedPrekey> {
  final Value<int> id;
  final Value<Uint8List> record;
  const SignalSignedPrekeysCompanion({
    this.id = const Value.absent(),
    this.record = const Value.absent(),
  });
  SignalSignedPrekeysCompanion.insert({
    this.id = const Value.absent(),
    required Uint8List record,
  }) : record = Value(record);
  static Insertable<SignalSignedPrekey> custom({
    Expression<int>? id,
    Expression<Uint8List>? record,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (record != null) 'record': record,
    });
  }

  SignalSignedPrekeysCompanion copyWith({
    Value<int>? id,
    Value<Uint8List>? record,
  }) {
    return SignalSignedPrekeysCompanion(
      id: id ?? this.id,
      record: record ?? this.record,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (record.present) {
      map['record'] = Variable<Uint8List>(record.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SignalSignedPrekeysCompanion(')
          ..write('id: $id, ')
          ..write('record: $record')
          ..write(')'))
        .toString();
  }
}

class $SignalOneTimePrekeysTable extends SignalOneTimePrekeys
    with TableInfo<$SignalOneTimePrekeysTable, SignalOneTimePrekey> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SignalOneTimePrekeysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _recordMeta = const VerificationMeta('record');
  @override
  late final GeneratedColumn<Uint8List> record = GeneratedColumn<Uint8List>(
    'record',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, record];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'signal_one_time_prekeys';
  @override
  VerificationContext validateIntegrity(
    Insertable<SignalOneTimePrekey> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('record')) {
      context.handle(
        _recordMeta,
        record.isAcceptableOrUnknown(data['record']!, _recordMeta),
      );
    } else if (isInserting) {
      context.missing(_recordMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  SignalOneTimePrekey map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SignalOneTimePrekey(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      record: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}record'],
      )!,
    );
  }

  @override
  $SignalOneTimePrekeysTable createAlias(String alias) {
    return $SignalOneTimePrekeysTable(attachedDatabase, alias);
  }
}

class SignalOneTimePrekey extends DataClass
    implements Insertable<SignalOneTimePrekey> {
  final int id;
  final Uint8List record;
  const SignalOneTimePrekey({required this.id, required this.record});
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['record'] = Variable<Uint8List>(record);
    return map;
  }

  SignalOneTimePrekeysCompanion toCompanion(bool nullToAbsent) {
    return SignalOneTimePrekeysCompanion(id: Value(id), record: Value(record));
  }

  factory SignalOneTimePrekey.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SignalOneTimePrekey(
      id: serializer.fromJson<int>(json['id']),
      record: serializer.fromJson<Uint8List>(json['record']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'record': serializer.toJson<Uint8List>(record),
    };
  }

  SignalOneTimePrekey copyWith({int? id, Uint8List? record}) =>
      SignalOneTimePrekey(id: id ?? this.id, record: record ?? this.record);
  SignalOneTimePrekey copyWithCompanion(SignalOneTimePrekeysCompanion data) {
    return SignalOneTimePrekey(
      id: data.id.present ? data.id.value : this.id,
      record: data.record.present ? data.record.value : this.record,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SignalOneTimePrekey(')
          ..write('id: $id, ')
          ..write('record: $record')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, $driftBlobEquality.hash(record));
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SignalOneTimePrekey &&
          other.id == this.id &&
          $driftBlobEquality.equals(other.record, this.record));
}

class SignalOneTimePrekeysCompanion
    extends UpdateCompanion<SignalOneTimePrekey> {
  final Value<int> id;
  final Value<Uint8List> record;
  const SignalOneTimePrekeysCompanion({
    this.id = const Value.absent(),
    this.record = const Value.absent(),
  });
  SignalOneTimePrekeysCompanion.insert({
    this.id = const Value.absent(),
    required Uint8List record,
  }) : record = Value(record);
  static Insertable<SignalOneTimePrekey> custom({
    Expression<int>? id,
    Expression<Uint8List>? record,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (record != null) 'record': record,
    });
  }

  SignalOneTimePrekeysCompanion copyWith({
    Value<int>? id,
    Value<Uint8List>? record,
  }) {
    return SignalOneTimePrekeysCompanion(
      id: id ?? this.id,
      record: record ?? this.record,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (record.present) {
      map['record'] = Variable<Uint8List>(record.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SignalOneTimePrekeysCompanion(')
          ..write('id: $id, ')
          ..write('record: $record')
          ..write(')'))
        .toString();
  }
}

class $SignalSessionsTable extends SignalSessions
    with TableInfo<$SignalSessionsTable, SignalSession> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SignalSessionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _addressNameMeta = const VerificationMeta(
    'addressName',
  );
  @override
  late final GeneratedColumn<String> addressName = GeneratedColumn<String>(
    'address_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addressDeviceIdMeta = const VerificationMeta(
    'addressDeviceId',
  );
  @override
  late final GeneratedColumn<int> addressDeviceId = GeneratedColumn<int>(
    'address_device_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _recordMeta = const VerificationMeta('record');
  @override
  late final GeneratedColumn<Uint8List> record = GeneratedColumn<Uint8List>(
    'record',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [addressName, addressDeviceId, record];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'signal_sessions';
  @override
  VerificationContext validateIntegrity(
    Insertable<SignalSession> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('address_name')) {
      context.handle(
        _addressNameMeta,
        addressName.isAcceptableOrUnknown(
          data['address_name']!,
          _addressNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_addressNameMeta);
    }
    if (data.containsKey('address_device_id')) {
      context.handle(
        _addressDeviceIdMeta,
        addressDeviceId.isAcceptableOrUnknown(
          data['address_device_id']!,
          _addressDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_addressDeviceIdMeta);
    }
    if (data.containsKey('record')) {
      context.handle(
        _recordMeta,
        record.isAcceptableOrUnknown(data['record']!, _recordMeta),
      );
    } else if (isInserting) {
      context.missing(_recordMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {addressName, addressDeviceId};
  @override
  SignalSession map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SignalSession(
      addressName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address_name'],
      )!,
      addressDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}address_device_id'],
      )!,
      record: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}record'],
      )!,
    );
  }

  @override
  $SignalSessionsTable createAlias(String alias) {
    return $SignalSessionsTable(attachedDatabase, alias);
  }
}

class SignalSession extends DataClass implements Insertable<SignalSession> {
  final String addressName;
  final int addressDeviceId;
  final Uint8List record;
  const SignalSession({
    required this.addressName,
    required this.addressDeviceId,
    required this.record,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['address_name'] = Variable<String>(addressName);
    map['address_device_id'] = Variable<int>(addressDeviceId);
    map['record'] = Variable<Uint8List>(record);
    return map;
  }

  SignalSessionsCompanion toCompanion(bool nullToAbsent) {
    return SignalSessionsCompanion(
      addressName: Value(addressName),
      addressDeviceId: Value(addressDeviceId),
      record: Value(record),
    );
  }

  factory SignalSession.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SignalSession(
      addressName: serializer.fromJson<String>(json['addressName']),
      addressDeviceId: serializer.fromJson<int>(json['addressDeviceId']),
      record: serializer.fromJson<Uint8List>(json['record']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'addressName': serializer.toJson<String>(addressName),
      'addressDeviceId': serializer.toJson<int>(addressDeviceId),
      'record': serializer.toJson<Uint8List>(record),
    };
  }

  SignalSession copyWith({
    String? addressName,
    int? addressDeviceId,
    Uint8List? record,
  }) => SignalSession(
    addressName: addressName ?? this.addressName,
    addressDeviceId: addressDeviceId ?? this.addressDeviceId,
    record: record ?? this.record,
  );
  SignalSession copyWithCompanion(SignalSessionsCompanion data) {
    return SignalSession(
      addressName: data.addressName.present
          ? data.addressName.value
          : this.addressName,
      addressDeviceId: data.addressDeviceId.present
          ? data.addressDeviceId.value
          : this.addressDeviceId,
      record: data.record.present ? data.record.value : this.record,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SignalSession(')
          ..write('addressName: $addressName, ')
          ..write('addressDeviceId: $addressDeviceId, ')
          ..write('record: $record')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    addressName,
    addressDeviceId,
    $driftBlobEquality.hash(record),
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SignalSession &&
          other.addressName == this.addressName &&
          other.addressDeviceId == this.addressDeviceId &&
          $driftBlobEquality.equals(other.record, this.record));
}

class SignalSessionsCompanion extends UpdateCompanion<SignalSession> {
  final Value<String> addressName;
  final Value<int> addressDeviceId;
  final Value<Uint8List> record;
  final Value<int> rowid;
  const SignalSessionsCompanion({
    this.addressName = const Value.absent(),
    this.addressDeviceId = const Value.absent(),
    this.record = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SignalSessionsCompanion.insert({
    required String addressName,
    required int addressDeviceId,
    required Uint8List record,
    this.rowid = const Value.absent(),
  }) : addressName = Value(addressName),
       addressDeviceId = Value(addressDeviceId),
       record = Value(record);
  static Insertable<SignalSession> custom({
    Expression<String>? addressName,
    Expression<int>? addressDeviceId,
    Expression<Uint8List>? record,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (addressName != null) 'address_name': addressName,
      if (addressDeviceId != null) 'address_device_id': addressDeviceId,
      if (record != null) 'record': record,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SignalSessionsCompanion copyWith({
    Value<String>? addressName,
    Value<int>? addressDeviceId,
    Value<Uint8List>? record,
    Value<int>? rowid,
  }) {
    return SignalSessionsCompanion(
      addressName: addressName ?? this.addressName,
      addressDeviceId: addressDeviceId ?? this.addressDeviceId,
      record: record ?? this.record,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (addressName.present) {
      map['address_name'] = Variable<String>(addressName.value);
    }
    if (addressDeviceId.present) {
      map['address_device_id'] = Variable<int>(addressDeviceId.value);
    }
    if (record.present) {
      map['record'] = Variable<Uint8List>(record.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SignalSessionsCompanion(')
          ..write('addressName: $addressName, ')
          ..write('addressDeviceId: $addressDeviceId, ')
          ..write('record: $record, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $SignalTrustedIdentitiesTable extends SignalTrustedIdentities
    with TableInfo<$SignalTrustedIdentitiesTable, SignalTrustedIdentity> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SignalTrustedIdentitiesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _addressNameMeta = const VerificationMeta(
    'addressName',
  );
  @override
  late final GeneratedColumn<String> addressName = GeneratedColumn<String>(
    'address_name',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _addressDeviceIdMeta = const VerificationMeta(
    'addressDeviceId',
  );
  @override
  late final GeneratedColumn<int> addressDeviceId = GeneratedColumn<int>(
    'address_device_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _identityKeyMeta = const VerificationMeta(
    'identityKey',
  );
  @override
  late final GeneratedColumn<Uint8List> identityKey =
      GeneratedColumn<Uint8List>(
        'identity_key',
        aliasedName,
        false,
        type: DriftSqlType.blob,
        requiredDuringInsert: true,
      );
  @override
  List<GeneratedColumn> get $columns => [
    addressName,
    addressDeviceId,
    identityKey,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'signal_trusted_identities';
  @override
  VerificationContext validateIntegrity(
    Insertable<SignalTrustedIdentity> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('address_name')) {
      context.handle(
        _addressNameMeta,
        addressName.isAcceptableOrUnknown(
          data['address_name']!,
          _addressNameMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_addressNameMeta);
    }
    if (data.containsKey('address_device_id')) {
      context.handle(
        _addressDeviceIdMeta,
        addressDeviceId.isAcceptableOrUnknown(
          data['address_device_id']!,
          _addressDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_addressDeviceIdMeta);
    }
    if (data.containsKey('identity_key')) {
      context.handle(
        _identityKeyMeta,
        identityKey.isAcceptableOrUnknown(
          data['identity_key']!,
          _identityKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_identityKeyMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {addressName, addressDeviceId};
  @override
  SignalTrustedIdentity map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SignalTrustedIdentity(
      addressName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}address_name'],
      )!,
      addressDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}address_device_id'],
      )!,
      identityKey: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}identity_key'],
      )!,
    );
  }

  @override
  $SignalTrustedIdentitiesTable createAlias(String alias) {
    return $SignalTrustedIdentitiesTable(attachedDatabase, alias);
  }
}

class SignalTrustedIdentity extends DataClass
    implements Insertable<SignalTrustedIdentity> {
  final String addressName;
  final int addressDeviceId;
  final Uint8List identityKey;
  const SignalTrustedIdentity({
    required this.addressName,
    required this.addressDeviceId,
    required this.identityKey,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['address_name'] = Variable<String>(addressName);
    map['address_device_id'] = Variable<int>(addressDeviceId);
    map['identity_key'] = Variable<Uint8List>(identityKey);
    return map;
  }

  SignalTrustedIdentitiesCompanion toCompanion(bool nullToAbsent) {
    return SignalTrustedIdentitiesCompanion(
      addressName: Value(addressName),
      addressDeviceId: Value(addressDeviceId),
      identityKey: Value(identityKey),
    );
  }

  factory SignalTrustedIdentity.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SignalTrustedIdentity(
      addressName: serializer.fromJson<String>(json['addressName']),
      addressDeviceId: serializer.fromJson<int>(json['addressDeviceId']),
      identityKey: serializer.fromJson<Uint8List>(json['identityKey']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'addressName': serializer.toJson<String>(addressName),
      'addressDeviceId': serializer.toJson<int>(addressDeviceId),
      'identityKey': serializer.toJson<Uint8List>(identityKey),
    };
  }

  SignalTrustedIdentity copyWith({
    String? addressName,
    int? addressDeviceId,
    Uint8List? identityKey,
  }) => SignalTrustedIdentity(
    addressName: addressName ?? this.addressName,
    addressDeviceId: addressDeviceId ?? this.addressDeviceId,
    identityKey: identityKey ?? this.identityKey,
  );
  SignalTrustedIdentity copyWithCompanion(
    SignalTrustedIdentitiesCompanion data,
  ) {
    return SignalTrustedIdentity(
      addressName: data.addressName.present
          ? data.addressName.value
          : this.addressName,
      addressDeviceId: data.addressDeviceId.present
          ? data.addressDeviceId.value
          : this.addressDeviceId,
      identityKey: data.identityKey.present
          ? data.identityKey.value
          : this.identityKey,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SignalTrustedIdentity(')
          ..write('addressName: $addressName, ')
          ..write('addressDeviceId: $addressDeviceId, ')
          ..write('identityKey: $identityKey')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    addressName,
    addressDeviceId,
    $driftBlobEquality.hash(identityKey),
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SignalTrustedIdentity &&
          other.addressName == this.addressName &&
          other.addressDeviceId == this.addressDeviceId &&
          $driftBlobEquality.equals(other.identityKey, this.identityKey));
}

class SignalTrustedIdentitiesCompanion
    extends UpdateCompanion<SignalTrustedIdentity> {
  final Value<String> addressName;
  final Value<int> addressDeviceId;
  final Value<Uint8List> identityKey;
  final Value<int> rowid;
  const SignalTrustedIdentitiesCompanion({
    this.addressName = const Value.absent(),
    this.addressDeviceId = const Value.absent(),
    this.identityKey = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SignalTrustedIdentitiesCompanion.insert({
    required String addressName,
    required int addressDeviceId,
    required Uint8List identityKey,
    this.rowid = const Value.absent(),
  }) : addressName = Value(addressName),
       addressDeviceId = Value(addressDeviceId),
       identityKey = Value(identityKey);
  static Insertable<SignalTrustedIdentity> custom({
    Expression<String>? addressName,
    Expression<int>? addressDeviceId,
    Expression<Uint8List>? identityKey,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (addressName != null) 'address_name': addressName,
      if (addressDeviceId != null) 'address_device_id': addressDeviceId,
      if (identityKey != null) 'identity_key': identityKey,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SignalTrustedIdentitiesCompanion copyWith({
    Value<String>? addressName,
    Value<int>? addressDeviceId,
    Value<Uint8List>? identityKey,
    Value<int>? rowid,
  }) {
    return SignalTrustedIdentitiesCompanion(
      addressName: addressName ?? this.addressName,
      addressDeviceId: addressDeviceId ?? this.addressDeviceId,
      identityKey: identityKey ?? this.identityKey,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (addressName.present) {
      map['address_name'] = Variable<String>(addressName.value);
    }
    if (addressDeviceId.present) {
      map['address_device_id'] = Variable<int>(addressDeviceId.value);
    }
    if (identityKey.present) {
      map['identity_key'] = Variable<Uint8List>(identityKey.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SignalTrustedIdentitiesCompanion(')
          ..write('addressName: $addressName, ')
          ..write('addressDeviceId: $addressDeviceId, ')
          ..write('identityKey: $identityKey, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $CryptoCountersTable extends CryptoCounters
    with TableInfo<$CryptoCountersTable, CryptoCounter> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $CryptoCountersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _nextOneTimePreKeyIdMeta =
      const VerificationMeta('nextOneTimePreKeyId');
  @override
  late final GeneratedColumn<int> nextOneTimePreKeyId = GeneratedColumn<int>(
    'next_one_time_pre_key_id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(1),
  );
  static const VerificationMeta _nextIssuedOneTimePreKeyIdMeta =
      const VerificationMeta('nextIssuedOneTimePreKeyId');
  @override
  late final GeneratedColumn<int> nextIssuedOneTimePreKeyId =
      GeneratedColumn<int>(
        'next_issued_one_time_pre_key_id',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: false,
        defaultValue: const Constant(1),
      );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    nextOneTimePreKeyId,
    nextIssuedOneTimePreKeyId,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'crypto_counters';
  @override
  VerificationContext validateIntegrity(
    Insertable<CryptoCounter> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('next_one_time_pre_key_id')) {
      context.handle(
        _nextOneTimePreKeyIdMeta,
        nextOneTimePreKeyId.isAcceptableOrUnknown(
          data['next_one_time_pre_key_id']!,
          _nextOneTimePreKeyIdMeta,
        ),
      );
    }
    if (data.containsKey('next_issued_one_time_pre_key_id')) {
      context.handle(
        _nextIssuedOneTimePreKeyIdMeta,
        nextIssuedOneTimePreKeyId.isAcceptableOrUnknown(
          data['next_issued_one_time_pre_key_id']!,
          _nextIssuedOneTimePreKeyIdMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  CryptoCounter map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return CryptoCounter(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      nextOneTimePreKeyId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_one_time_pre_key_id'],
      )!,
      nextIssuedOneTimePreKeyId: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}next_issued_one_time_pre_key_id'],
      )!,
    );
  }

  @override
  $CryptoCountersTable createAlias(String alias) {
    return $CryptoCountersTable(attachedDatabase, alias);
  }
}

class CryptoCounter extends DataClass implements Insertable<CryptoCounter> {
  final int id;
  final int nextOneTimePreKeyId;
  final int nextIssuedOneTimePreKeyId;
  const CryptoCounter({
    required this.id,
    required this.nextOneTimePreKeyId,
    required this.nextIssuedOneTimePreKeyId,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['next_one_time_pre_key_id'] = Variable<int>(nextOneTimePreKeyId);
    map['next_issued_one_time_pre_key_id'] = Variable<int>(
      nextIssuedOneTimePreKeyId,
    );
    return map;
  }

  CryptoCountersCompanion toCompanion(bool nullToAbsent) {
    return CryptoCountersCompanion(
      id: Value(id),
      nextOneTimePreKeyId: Value(nextOneTimePreKeyId),
      nextIssuedOneTimePreKeyId: Value(nextIssuedOneTimePreKeyId),
    );
  }

  factory CryptoCounter.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return CryptoCounter(
      id: serializer.fromJson<int>(json['id']),
      nextOneTimePreKeyId: serializer.fromJson<int>(
        json['nextOneTimePreKeyId'],
      ),
      nextIssuedOneTimePreKeyId: serializer.fromJson<int>(
        json['nextIssuedOneTimePreKeyId'],
      ),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'nextOneTimePreKeyId': serializer.toJson<int>(nextOneTimePreKeyId),
      'nextIssuedOneTimePreKeyId': serializer.toJson<int>(
        nextIssuedOneTimePreKeyId,
      ),
    };
  }

  CryptoCounter copyWith({
    int? id,
    int? nextOneTimePreKeyId,
    int? nextIssuedOneTimePreKeyId,
  }) => CryptoCounter(
    id: id ?? this.id,
    nextOneTimePreKeyId: nextOneTimePreKeyId ?? this.nextOneTimePreKeyId,
    nextIssuedOneTimePreKeyId:
        nextIssuedOneTimePreKeyId ?? this.nextIssuedOneTimePreKeyId,
  );
  CryptoCounter copyWithCompanion(CryptoCountersCompanion data) {
    return CryptoCounter(
      id: data.id.present ? data.id.value : this.id,
      nextOneTimePreKeyId: data.nextOneTimePreKeyId.present
          ? data.nextOneTimePreKeyId.value
          : this.nextOneTimePreKeyId,
      nextIssuedOneTimePreKeyId: data.nextIssuedOneTimePreKeyId.present
          ? data.nextIssuedOneTimePreKeyId.value
          : this.nextIssuedOneTimePreKeyId,
    );
  }

  @override
  String toString() {
    return (StringBuffer('CryptoCounter(')
          ..write('id: $id, ')
          ..write('nextOneTimePreKeyId: $nextOneTimePreKeyId, ')
          ..write('nextIssuedOneTimePreKeyId: $nextIssuedOneTimePreKeyId')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, nextOneTimePreKeyId, nextIssuedOneTimePreKeyId);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CryptoCounter &&
          other.id == this.id &&
          other.nextOneTimePreKeyId == this.nextOneTimePreKeyId &&
          other.nextIssuedOneTimePreKeyId == this.nextIssuedOneTimePreKeyId);
}

class CryptoCountersCompanion extends UpdateCompanion<CryptoCounter> {
  final Value<int> id;
  final Value<int> nextOneTimePreKeyId;
  final Value<int> nextIssuedOneTimePreKeyId;
  const CryptoCountersCompanion({
    this.id = const Value.absent(),
    this.nextOneTimePreKeyId = const Value.absent(),
    this.nextIssuedOneTimePreKeyId = const Value.absent(),
  });
  CryptoCountersCompanion.insert({
    this.id = const Value.absent(),
    this.nextOneTimePreKeyId = const Value.absent(),
    this.nextIssuedOneTimePreKeyId = const Value.absent(),
  });
  static Insertable<CryptoCounter> custom({
    Expression<int>? id,
    Expression<int>? nextOneTimePreKeyId,
    Expression<int>? nextIssuedOneTimePreKeyId,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (nextOneTimePreKeyId != null)
        'next_one_time_pre_key_id': nextOneTimePreKeyId,
      if (nextIssuedOneTimePreKeyId != null)
        'next_issued_one_time_pre_key_id': nextIssuedOneTimePreKeyId,
    });
  }

  CryptoCountersCompanion copyWith({
    Value<int>? id,
    Value<int>? nextOneTimePreKeyId,
    Value<int>? nextIssuedOneTimePreKeyId,
  }) {
    return CryptoCountersCompanion(
      id: id ?? this.id,
      nextOneTimePreKeyId: nextOneTimePreKeyId ?? this.nextOneTimePreKeyId,
      nextIssuedOneTimePreKeyId:
          nextIssuedOneTimePreKeyId ?? this.nextIssuedOneTimePreKeyId,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (nextOneTimePreKeyId.present) {
      map['next_one_time_pre_key_id'] = Variable<int>(
        nextOneTimePreKeyId.value,
      );
    }
    if (nextIssuedOneTimePreKeyId.present) {
      map['next_issued_one_time_pre_key_id'] = Variable<int>(
        nextIssuedOneTimePreKeyId.value,
      );
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('CryptoCountersCompanion(')
          ..write('id: $id, ')
          ..write('nextOneTimePreKeyId: $nextOneTimePreKeyId, ')
          ..write('nextIssuedOneTimePreKeyId: $nextIssuedOneTimePreKeyId')
          ..write(')'))
        .toString();
  }
}

class $RoutesTable extends Routes with TableInfo<$RoutesTable, RouteRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RoutesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _destinationIdMeta = const VerificationMeta(
    'destinationId',
  );
  @override
  late final GeneratedColumn<String> destinationId = GeneratedColumn<String>(
    'destination_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _hopsMeta = const VerificationMeta('hops');
  @override
  late final GeneratedColumn<String> hops = GeneratedColumn<String>(
    'hops',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastCostMeta = const VerificationMeta(
    'lastCost',
  );
  @override
  late final GeneratedColumn<double> lastCost = GeneratedColumn<double>(
    'last_cost',
    aliasedName,
    false,
    type: DriftSqlType.double,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastMeasuredAtMeta = const VerificationMeta(
    'lastMeasuredAt',
  );
  @override
  late final GeneratedColumn<int> lastMeasuredAt = GeneratedColumn<int>(
    'last_measured_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stableSinceTickMeta = const VerificationMeta(
    'stableSinceTick',
  );
  @override
  late final GeneratedColumn<int> stableSinceTick = GeneratedColumn<int>(
    'stable_since_tick',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    destinationId,
    hops,
    lastCost,
    lastMeasuredAt,
    stableSinceTick,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'routes';
  @override
  VerificationContext validateIntegrity(
    Insertable<RouteRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('destination_id')) {
      context.handle(
        _destinationIdMeta,
        destinationId.isAcceptableOrUnknown(
          data['destination_id']!,
          _destinationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_destinationIdMeta);
    }
    if (data.containsKey('hops')) {
      context.handle(
        _hopsMeta,
        hops.isAcceptableOrUnknown(data['hops']!, _hopsMeta),
      );
    } else if (isInserting) {
      context.missing(_hopsMeta);
    }
    if (data.containsKey('last_cost')) {
      context.handle(
        _lastCostMeta,
        lastCost.isAcceptableOrUnknown(data['last_cost']!, _lastCostMeta),
      );
    } else if (isInserting) {
      context.missing(_lastCostMeta);
    }
    if (data.containsKey('last_measured_at')) {
      context.handle(
        _lastMeasuredAtMeta,
        lastMeasuredAt.isAcceptableOrUnknown(
          data['last_measured_at']!,
          _lastMeasuredAtMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastMeasuredAtMeta);
    }
    if (data.containsKey('stable_since_tick')) {
      context.handle(
        _stableSinceTickMeta,
        stableSinceTick.isAcceptableOrUnknown(
          data['stable_since_tick']!,
          _stableSinceTickMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {destinationId, hops};
  @override
  RouteRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RouteRow(
      destinationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}destination_id'],
      )!,
      hops: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}hops'],
      )!,
      lastCost: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}last_cost'],
      )!,
      lastMeasuredAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_measured_at'],
      )!,
      stableSinceTick: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}stable_since_tick'],
      ),
    );
  }

  @override
  $RoutesTable createAlias(String alias) {
    return $RoutesTable(attachedDatabase, alias);
  }
}

class RouteRow extends DataClass implements Insertable<RouteRow> {
  final String destinationId;

  /// Ordered JSON array of hop node ids from this device to
  /// [destinationId], e.g. `'["B","C"]'` for a 2-hop relay via B then C.
  final String hops;

  /// Last-computed cost for this route (lower is better) — a snapshot, not
  /// a time series (task §4: no route-quality-over-time reporting).
  final double lastCost;

  /// Epoch-ms wall-clock timestamp of the last cost measurement — display
  /// bookkeeping only, never used for the migration stability window.
  final int lastMeasuredAt;

  /// The engine's own tick count at which this route first started
  /// holding its current cost advantage (§5's declared schema, OQ-E04-2).
  /// Nullable: a route with no tracked advantage yet.
  ///
  /// NOT the authority for the migration stability window. As implemented
  /// in E04-T02, `RoutingEngine` holds that state in memory as a count of
  /// consecutive `considerMigration` samples — a different quantity from a
  /// tick number — and never reads or writes this column. This column has
  /// no writer and no reader today; it exists because §5 declares the
  /// schema. Whoever wires persistence in (T04) must reconcile the two
  /// representations rather than assume this column is live —
  /// L-backend-003.
  final int? stableSinceTick;
  const RouteRow({
    required this.destinationId,
    required this.hops,
    required this.lastCost,
    required this.lastMeasuredAt,
    this.stableSinceTick,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['destination_id'] = Variable<String>(destinationId);
    map['hops'] = Variable<String>(hops);
    map['last_cost'] = Variable<double>(lastCost);
    map['last_measured_at'] = Variable<int>(lastMeasuredAt);
    if (!nullToAbsent || stableSinceTick != null) {
      map['stable_since_tick'] = Variable<int>(stableSinceTick);
    }
    return map;
  }

  RoutesCompanion toCompanion(bool nullToAbsent) {
    return RoutesCompanion(
      destinationId: Value(destinationId),
      hops: Value(hops),
      lastCost: Value(lastCost),
      lastMeasuredAt: Value(lastMeasuredAt),
      stableSinceTick: stableSinceTick == null && nullToAbsent
          ? const Value.absent()
          : Value(stableSinceTick),
    );
  }

  factory RouteRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RouteRow(
      destinationId: serializer.fromJson<String>(json['destinationId']),
      hops: serializer.fromJson<String>(json['hops']),
      lastCost: serializer.fromJson<double>(json['lastCost']),
      lastMeasuredAt: serializer.fromJson<int>(json['lastMeasuredAt']),
      stableSinceTick: serializer.fromJson<int?>(json['stableSinceTick']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'destinationId': serializer.toJson<String>(destinationId),
      'hops': serializer.toJson<String>(hops),
      'lastCost': serializer.toJson<double>(lastCost),
      'lastMeasuredAt': serializer.toJson<int>(lastMeasuredAt),
      'stableSinceTick': serializer.toJson<int?>(stableSinceTick),
    };
  }

  RouteRow copyWith({
    String? destinationId,
    String? hops,
    double? lastCost,
    int? lastMeasuredAt,
    Value<int?> stableSinceTick = const Value.absent(),
  }) => RouteRow(
    destinationId: destinationId ?? this.destinationId,
    hops: hops ?? this.hops,
    lastCost: lastCost ?? this.lastCost,
    lastMeasuredAt: lastMeasuredAt ?? this.lastMeasuredAt,
    stableSinceTick: stableSinceTick.present
        ? stableSinceTick.value
        : this.stableSinceTick,
  );
  RouteRow copyWithCompanion(RoutesCompanion data) {
    return RouteRow(
      destinationId: data.destinationId.present
          ? data.destinationId.value
          : this.destinationId,
      hops: data.hops.present ? data.hops.value : this.hops,
      lastCost: data.lastCost.present ? data.lastCost.value : this.lastCost,
      lastMeasuredAt: data.lastMeasuredAt.present
          ? data.lastMeasuredAt.value
          : this.lastMeasuredAt,
      stableSinceTick: data.stableSinceTick.present
          ? data.stableSinceTick.value
          : this.stableSinceTick,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RouteRow(')
          ..write('destinationId: $destinationId, ')
          ..write('hops: $hops, ')
          ..write('lastCost: $lastCost, ')
          ..write('lastMeasuredAt: $lastMeasuredAt, ')
          ..write('stableSinceTick: $stableSinceTick')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    destinationId,
    hops,
    lastCost,
    lastMeasuredAt,
    stableSinceTick,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RouteRow &&
          other.destinationId == this.destinationId &&
          other.hops == this.hops &&
          other.lastCost == this.lastCost &&
          other.lastMeasuredAt == this.lastMeasuredAt &&
          other.stableSinceTick == this.stableSinceTick);
}

class RoutesCompanion extends UpdateCompanion<RouteRow> {
  final Value<String> destinationId;
  final Value<String> hops;
  final Value<double> lastCost;
  final Value<int> lastMeasuredAt;
  final Value<int?> stableSinceTick;
  final Value<int> rowid;
  const RoutesCompanion({
    this.destinationId = const Value.absent(),
    this.hops = const Value.absent(),
    this.lastCost = const Value.absent(),
    this.lastMeasuredAt = const Value.absent(),
    this.stableSinceTick = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RoutesCompanion.insert({
    required String destinationId,
    required String hops,
    required double lastCost,
    required int lastMeasuredAt,
    this.stableSinceTick = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : destinationId = Value(destinationId),
       hops = Value(hops),
       lastCost = Value(lastCost),
       lastMeasuredAt = Value(lastMeasuredAt);
  static Insertable<RouteRow> custom({
    Expression<String>? destinationId,
    Expression<String>? hops,
    Expression<double>? lastCost,
    Expression<int>? lastMeasuredAt,
    Expression<int>? stableSinceTick,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (destinationId != null) 'destination_id': destinationId,
      if (hops != null) 'hops': hops,
      if (lastCost != null) 'last_cost': lastCost,
      if (lastMeasuredAt != null) 'last_measured_at': lastMeasuredAt,
      if (stableSinceTick != null) 'stable_since_tick': stableSinceTick,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RoutesCompanion copyWith({
    Value<String>? destinationId,
    Value<String>? hops,
    Value<double>? lastCost,
    Value<int>? lastMeasuredAt,
    Value<int?>? stableSinceTick,
    Value<int>? rowid,
  }) {
    return RoutesCompanion(
      destinationId: destinationId ?? this.destinationId,
      hops: hops ?? this.hops,
      lastCost: lastCost ?? this.lastCost,
      lastMeasuredAt: lastMeasuredAt ?? this.lastMeasuredAt,
      stableSinceTick: stableSinceTick ?? this.stableSinceTick,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (destinationId.present) {
      map['destination_id'] = Variable<String>(destinationId.value);
    }
    if (hops.present) {
      map['hops'] = Variable<String>(hops.value);
    }
    if (lastCost.present) {
      map['last_cost'] = Variable<double>(lastCost.value);
    }
    if (lastMeasuredAt.present) {
      map['last_measured_at'] = Variable<int>(lastMeasuredAt.value);
    }
    if (stableSinceTick.present) {
      map['stable_since_tick'] = Variable<int>(stableSinceTick.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RoutesCompanion(')
          ..write('destinationId: $destinationId, ')
          ..write('hops: $hops, ')
          ..write('lastCost: $lastCost, ')
          ..write('lastMeasuredAt: $lastMeasuredAt, ')
          ..write('stableSinceTick: $stableSinceTick, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RelayPacketsTable extends RelayPackets
    with TableInfo<$RelayPacketsTable, RelayPacketRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RelayPacketsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _destinationIdMeta = const VerificationMeta(
    'destinationId',
  );
  @override
  late final GeneratedColumn<String> destinationId = GeneratedColumn<String>(
    'destination_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _payloadMeta = const VerificationMeta(
    'payload',
  );
  @override
  late final GeneratedColumn<Uint8List> payload = GeneratedColumn<Uint8List>(
    'payload',
    aliasedName,
    true,
    type: DriftSqlType.blob,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _priorityMeta = const VerificationMeta(
    'priority',
  );
  @override
  late final GeneratedColumn<int> priority = GeneratedColumn<int>(
    'priority',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sizeBytesMeta = const VerificationMeta(
    'sizeBytes',
  );
  @override
  late final GeneratedColumn<int> sizeBytes = GeneratedColumn<int>(
    'size_bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _expiresAtMeta = const VerificationMeta(
    'expiresAt',
  );
  @override
  late final GeneratedColumn<int> expiresAt = GeneratedColumn<int>(
    'expires_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deliveryStateMeta = const VerificationMeta(
    'deliveryState',
  );
  @override
  late final GeneratedColumn<String> deliveryState = GeneratedColumn<String>(
    'delivery_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    destinationId,
    payload,
    priority,
    sizeBytes,
    createdAt,
    expiresAt,
    deliveryState,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'relay_packets';
  @override
  VerificationContext validateIntegrity(
    Insertable<RelayPacketRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('destination_id')) {
      context.handle(
        _destinationIdMeta,
        destinationId.isAcceptableOrUnknown(
          data['destination_id']!,
          _destinationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_destinationIdMeta);
    }
    if (data.containsKey('payload')) {
      context.handle(
        _payloadMeta,
        payload.isAcceptableOrUnknown(data['payload']!, _payloadMeta),
      );
    }
    if (data.containsKey('priority')) {
      context.handle(
        _priorityMeta,
        priority.isAcceptableOrUnknown(data['priority']!, _priorityMeta),
      );
    } else if (isInserting) {
      context.missing(_priorityMeta);
    }
    if (data.containsKey('size_bytes')) {
      context.handle(
        _sizeBytesMeta,
        sizeBytes.isAcceptableOrUnknown(data['size_bytes']!, _sizeBytesMeta),
      );
    } else if (isInserting) {
      context.missing(_sizeBytesMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('expires_at')) {
      context.handle(
        _expiresAtMeta,
        expiresAt.isAcceptableOrUnknown(data['expires_at']!, _expiresAtMeta),
      );
    } else if (isInserting) {
      context.missing(_expiresAtMeta);
    }
    if (data.containsKey('delivery_state')) {
      context.handle(
        _deliveryStateMeta,
        deliveryState.isAcceptableOrUnknown(
          data['delivery_state']!,
          _deliveryStateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_deliveryStateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  RelayPacketRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RelayPacketRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      destinationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}destination_id'],
      )!,
      payload: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}payload'],
      ),
      priority: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}priority'],
      )!,
      sizeBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}size_bytes'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      expiresAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}expires_at'],
      )!,
      deliveryState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}delivery_state'],
      )!,
    );
  }

  @override
  $RelayPacketsTable createAlias(String alias) {
    return $RelayPacketsTable(attachedDatabase, alias);
  }
}

class RelayPacketRow extends DataClass implements Insertable<RelayPacketRow> {
  final String id;

  /// The final destination node id this packet is ultimately routed toward
  /// — never this device's own id (a relay packet is, by definition, for
  /// someone else).
  final String destinationId;

  /// Opaque, already-encrypted bytes. Never parsed, inspected or logged by
  /// anything in this table's own file or `relay_engine.dart` (FR-ROUTE-003).
  ///
  /// Nullable as of schema v10 (E04-B02): `RelayEngine.reclaimPayloads()`
  /// nulls this out once a terminal-state row (`forwarding` / `delivered` /
  /// `expired`) passes its own `expires_at` -- the row itself (id,
  /// destination, size, timestamps, state) is kept for diagnostics (E13),
  /// but the ciphertext bytes are not retained past the packet's own TTL.
  /// See `epic.md` §Data model for the exact retention rule.
  final Uint8List? payload;

  /// Higher values are forwarded first within a `processQueue()` pass.
  final int priority;

  /// `payload.length`, stored for diagnostics/UI-adjacent needs (a later
  /// epic) — never derived from parsing the payload itself.
  final int sizeBytes;

  /// Epoch-ms wall-clock timestamp this packet was enqueued.
  final int createdAt;

  /// Epoch-ms wall-clock timestamp after which this packet is no longer
  /// forwarded and is instead swept to `expired` by `sweepExpired()`.
  final int expiresAt;

  /// `RelayDeliveryState.name` — one of queued / forwarding / delivered /
  /// expired / failed.
  final String deliveryState;
  const RelayPacketRow({
    required this.id,
    required this.destinationId,
    this.payload,
    required this.priority,
    required this.sizeBytes,
    required this.createdAt,
    required this.expiresAt,
    required this.deliveryState,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['destination_id'] = Variable<String>(destinationId);
    if (!nullToAbsent || payload != null) {
      map['payload'] = Variable<Uint8List>(payload);
    }
    map['priority'] = Variable<int>(priority);
    map['size_bytes'] = Variable<int>(sizeBytes);
    map['created_at'] = Variable<int>(createdAt);
    map['expires_at'] = Variable<int>(expiresAt);
    map['delivery_state'] = Variable<String>(deliveryState);
    return map;
  }

  RelayPacketsCompanion toCompanion(bool nullToAbsent) {
    return RelayPacketsCompanion(
      id: Value(id),
      destinationId: Value(destinationId),
      payload: payload == null && nullToAbsent
          ? const Value.absent()
          : Value(payload),
      priority: Value(priority),
      sizeBytes: Value(sizeBytes),
      createdAt: Value(createdAt),
      expiresAt: Value(expiresAt),
      deliveryState: Value(deliveryState),
    );
  }

  factory RelayPacketRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RelayPacketRow(
      id: serializer.fromJson<String>(json['id']),
      destinationId: serializer.fromJson<String>(json['destinationId']),
      payload: serializer.fromJson<Uint8List?>(json['payload']),
      priority: serializer.fromJson<int>(json['priority']),
      sizeBytes: serializer.fromJson<int>(json['sizeBytes']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      expiresAt: serializer.fromJson<int>(json['expiresAt']),
      deliveryState: serializer.fromJson<String>(json['deliveryState']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'destinationId': serializer.toJson<String>(destinationId),
      'payload': serializer.toJson<Uint8List?>(payload),
      'priority': serializer.toJson<int>(priority),
      'sizeBytes': serializer.toJson<int>(sizeBytes),
      'createdAt': serializer.toJson<int>(createdAt),
      'expiresAt': serializer.toJson<int>(expiresAt),
      'deliveryState': serializer.toJson<String>(deliveryState),
    };
  }

  RelayPacketRow copyWith({
    String? id,
    String? destinationId,
    Value<Uint8List?> payload = const Value.absent(),
    int? priority,
    int? sizeBytes,
    int? createdAt,
    int? expiresAt,
    String? deliveryState,
  }) => RelayPacketRow(
    id: id ?? this.id,
    destinationId: destinationId ?? this.destinationId,
    payload: payload.present ? payload.value : this.payload,
    priority: priority ?? this.priority,
    sizeBytes: sizeBytes ?? this.sizeBytes,
    createdAt: createdAt ?? this.createdAt,
    expiresAt: expiresAt ?? this.expiresAt,
    deliveryState: deliveryState ?? this.deliveryState,
  );
  RelayPacketRow copyWithCompanion(RelayPacketsCompanion data) {
    return RelayPacketRow(
      id: data.id.present ? data.id.value : this.id,
      destinationId: data.destinationId.present
          ? data.destinationId.value
          : this.destinationId,
      payload: data.payload.present ? data.payload.value : this.payload,
      priority: data.priority.present ? data.priority.value : this.priority,
      sizeBytes: data.sizeBytes.present ? data.sizeBytes.value : this.sizeBytes,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      expiresAt: data.expiresAt.present ? data.expiresAt.value : this.expiresAt,
      deliveryState: data.deliveryState.present
          ? data.deliveryState.value
          : this.deliveryState,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RelayPacketRow(')
          ..write('id: $id, ')
          ..write('destinationId: $destinationId, ')
          ..write('payload: $payload, ')
          ..write('priority: $priority, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('createdAt: $createdAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('deliveryState: $deliveryState')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    destinationId,
    $driftBlobEquality.hash(payload),
    priority,
    sizeBytes,
    createdAt,
    expiresAt,
    deliveryState,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RelayPacketRow &&
          other.id == this.id &&
          other.destinationId == this.destinationId &&
          $driftBlobEquality.equals(other.payload, this.payload) &&
          other.priority == this.priority &&
          other.sizeBytes == this.sizeBytes &&
          other.createdAt == this.createdAt &&
          other.expiresAt == this.expiresAt &&
          other.deliveryState == this.deliveryState);
}

class RelayPacketsCompanion extends UpdateCompanion<RelayPacketRow> {
  final Value<String> id;
  final Value<String> destinationId;
  final Value<Uint8List?> payload;
  final Value<int> priority;
  final Value<int> sizeBytes;
  final Value<int> createdAt;
  final Value<int> expiresAt;
  final Value<String> deliveryState;
  final Value<int> rowid;
  const RelayPacketsCompanion({
    this.id = const Value.absent(),
    this.destinationId = const Value.absent(),
    this.payload = const Value.absent(),
    this.priority = const Value.absent(),
    this.sizeBytes = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.expiresAt = const Value.absent(),
    this.deliveryState = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RelayPacketsCompanion.insert({
    required String id,
    required String destinationId,
    this.payload = const Value.absent(),
    required int priority,
    required int sizeBytes,
    required int createdAt,
    required int expiresAt,
    required String deliveryState,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       destinationId = Value(destinationId),
       priority = Value(priority),
       sizeBytes = Value(sizeBytes),
       createdAt = Value(createdAt),
       expiresAt = Value(expiresAt),
       deliveryState = Value(deliveryState);
  static Insertable<RelayPacketRow> custom({
    Expression<String>? id,
    Expression<String>? destinationId,
    Expression<Uint8List>? payload,
    Expression<int>? priority,
    Expression<int>? sizeBytes,
    Expression<int>? createdAt,
    Expression<int>? expiresAt,
    Expression<String>? deliveryState,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (destinationId != null) 'destination_id': destinationId,
      if (payload != null) 'payload': payload,
      if (priority != null) 'priority': priority,
      if (sizeBytes != null) 'size_bytes': sizeBytes,
      if (createdAt != null) 'created_at': createdAt,
      if (expiresAt != null) 'expires_at': expiresAt,
      if (deliveryState != null) 'delivery_state': deliveryState,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RelayPacketsCompanion copyWith({
    Value<String>? id,
    Value<String>? destinationId,
    Value<Uint8List?>? payload,
    Value<int>? priority,
    Value<int>? sizeBytes,
    Value<int>? createdAt,
    Value<int>? expiresAt,
    Value<String>? deliveryState,
    Value<int>? rowid,
  }) {
    return RelayPacketsCompanion(
      id: id ?? this.id,
      destinationId: destinationId ?? this.destinationId,
      payload: payload ?? this.payload,
      priority: priority ?? this.priority,
      sizeBytes: sizeBytes ?? this.sizeBytes,
      createdAt: createdAt ?? this.createdAt,
      expiresAt: expiresAt ?? this.expiresAt,
      deliveryState: deliveryState ?? this.deliveryState,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (destinationId.present) {
      map['destination_id'] = Variable<String>(destinationId.value);
    }
    if (payload.present) {
      map['payload'] = Variable<Uint8List>(payload.value);
    }
    if (priority.present) {
      map['priority'] = Variable<int>(priority.value);
    }
    if (sizeBytes.present) {
      map['size_bytes'] = Variable<int>(sizeBytes.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (expiresAt.present) {
      map['expires_at'] = Variable<int>(expiresAt.value);
    }
    if (deliveryState.present) {
      map['delivery_state'] = Variable<String>(deliveryState.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RelayPacketsCompanion(')
          ..write('id: $id, ')
          ..write('destinationId: $destinationId, ')
          ..write('payload: $payload, ')
          ..write('priority: $priority, ')
          ..write('sizeBytes: $sizeBytes, ')
          ..write('createdAt: $createdAt, ')
          ..write('expiresAt: $expiresAt, ')
          ..write('deliveryState: $deliveryState, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $MessagesTable extends Messages
    with TableInfo<$MessagesTable, MessageRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $MessagesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _conversationIdMeta = const VerificationMeta(
    'conversationId',
  );
  @override
  late final GeneratedColumn<String> conversationId = GeneratedColumn<String>(
    'conversation_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _senderDeviceIdMeta = const VerificationMeta(
    'senderDeviceId',
  );
  @override
  late final GeneratedColumn<String> senderDeviceId = GeneratedColumn<String>(
    'sender_device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sequenceNumberMeta = const VerificationMeta(
    'sequenceNumber',
  );
  @override
  late final GeneratedColumn<int> sequenceNumber = GeneratedColumn<int>(
    'sequence_number',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _ciphertextMeta = const VerificationMeta(
    'ciphertext',
  );
  @override
  late final GeneratedColumn<Uint8List> ciphertext = GeneratedColumn<Uint8List>(
    'ciphertext',
    aliasedName,
    false,
    type: DriftSqlType.blob,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _createdAtMeta = const VerificationMeta(
    'createdAt',
  );
  @override
  late final GeneratedColumn<int> createdAt = GeneratedColumn<int>(
    'created_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _deliveryStateMeta = const VerificationMeta(
    'deliveryState',
  );
  @override
  late final GeneratedColumn<String> deliveryState = GeneratedColumn<String>(
    'delivery_state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    conversationId,
    senderDeviceId,
    sequenceNumber,
    ciphertext,
    createdAt,
    deliveryState,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'messages';
  @override
  VerificationContext validateIntegrity(
    Insertable<MessageRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('conversation_id')) {
      context.handle(
        _conversationIdMeta,
        conversationId.isAcceptableOrUnknown(
          data['conversation_id']!,
          _conversationIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_conversationIdMeta);
    }
    if (data.containsKey('sender_device_id')) {
      context.handle(
        _senderDeviceIdMeta,
        senderDeviceId.isAcceptableOrUnknown(
          data['sender_device_id']!,
          _senderDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_senderDeviceIdMeta);
    }
    if (data.containsKey('sequence_number')) {
      context.handle(
        _sequenceNumberMeta,
        sequenceNumber.isAcceptableOrUnknown(
          data['sequence_number']!,
          _sequenceNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_sequenceNumberMeta);
    }
    if (data.containsKey('ciphertext')) {
      context.handle(
        _ciphertextMeta,
        ciphertext.isAcceptableOrUnknown(data['ciphertext']!, _ciphertextMeta),
      );
    } else if (isInserting) {
      context.missing(_ciphertextMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('delivery_state')) {
      context.handle(
        _deliveryStateMeta,
        deliveryState.isAcceptableOrUnknown(
          data['delivery_state']!,
          _deliveryStateMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_deliveryStateMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  MessageRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return MessageRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      senderDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_device_id'],
      )!,
      sequenceNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}sequence_number'],
      )!,
      ciphertext: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}ciphertext'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      deliveryState: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}delivery_state'],
      )!,
    );
  }

  @override
  $MessagesTable createAlias(String alias) {
    return $MessagesTable(attachedDatabase, alias);
  }
}

class MessageRow extends DataClass implements Insertable<MessageRow> {
  /// Client-generated, globally unique -- FR-MSG-003/EARS-MSG-2. Never
  /// server-assigned (this app has no server, ADR-0005).
  final String id;
  final String conversationId;
  final String senderDeviceId;

  /// Monotonic per `(conversationId, senderDeviceId)`, assigned at compose
  /// time -- offline, no live transport required (FR-MSG-004/EARS-MSG-3,
  /// this task's §6 risk note). Assignment algorithm itself is T02's job;
  /// this column only needs to be a plain INTEGER a client can set locally.
  final int sequenceNumber;

  /// Opaque, already-encrypted bytes. Never decrypted or inspected by
  /// anything in this table's own file (this task's §4).
  final Uint8List ciphertext;

  /// Epoch-ms wall-clock creation time -- keyset pagination cursor, never
  /// used for logical ordering (that's [sequenceNumber]'s job -- clock
  /// drift across devices makes wall-clock time unfit for that).
  final int createdAt;

  /// A `DeliveryState.name` string (Queued/Sent/Accepted/Delivered/Stored/
  /// Read/Failed, F-032) -- never written directly; always via
  /// `DeliveryStateMachine.transition`.
  final String deliveryState;
  const MessageRow({
    required this.id,
    required this.conversationId,
    required this.senderDeviceId,
    required this.sequenceNumber,
    required this.ciphertext,
    required this.createdAt,
    required this.deliveryState,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['conversation_id'] = Variable<String>(conversationId);
    map['sender_device_id'] = Variable<String>(senderDeviceId);
    map['sequence_number'] = Variable<int>(sequenceNumber);
    map['ciphertext'] = Variable<Uint8List>(ciphertext);
    map['created_at'] = Variable<int>(createdAt);
    map['delivery_state'] = Variable<String>(deliveryState);
    return map;
  }

  MessagesCompanion toCompanion(bool nullToAbsent) {
    return MessagesCompanion(
      id: Value(id),
      conversationId: Value(conversationId),
      senderDeviceId: Value(senderDeviceId),
      sequenceNumber: Value(sequenceNumber),
      ciphertext: Value(ciphertext),
      createdAt: Value(createdAt),
      deliveryState: Value(deliveryState),
    );
  }

  factory MessageRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return MessageRow(
      id: serializer.fromJson<String>(json['id']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      senderDeviceId: serializer.fromJson<String>(json['senderDeviceId']),
      sequenceNumber: serializer.fromJson<int>(json['sequenceNumber']),
      ciphertext: serializer.fromJson<Uint8List>(json['ciphertext']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      deliveryState: serializer.fromJson<String>(json['deliveryState']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'conversationId': serializer.toJson<String>(conversationId),
      'senderDeviceId': serializer.toJson<String>(senderDeviceId),
      'sequenceNumber': serializer.toJson<int>(sequenceNumber),
      'ciphertext': serializer.toJson<Uint8List>(ciphertext),
      'createdAt': serializer.toJson<int>(createdAt),
      'deliveryState': serializer.toJson<String>(deliveryState),
    };
  }

  MessageRow copyWith({
    String? id,
    String? conversationId,
    String? senderDeviceId,
    int? sequenceNumber,
    Uint8List? ciphertext,
    int? createdAt,
    String? deliveryState,
  }) => MessageRow(
    id: id ?? this.id,
    conversationId: conversationId ?? this.conversationId,
    senderDeviceId: senderDeviceId ?? this.senderDeviceId,
    sequenceNumber: sequenceNumber ?? this.sequenceNumber,
    ciphertext: ciphertext ?? this.ciphertext,
    createdAt: createdAt ?? this.createdAt,
    deliveryState: deliveryState ?? this.deliveryState,
  );
  MessageRow copyWithCompanion(MessagesCompanion data) {
    return MessageRow(
      id: data.id.present ? data.id.value : this.id,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      senderDeviceId: data.senderDeviceId.present
          ? data.senderDeviceId.value
          : this.senderDeviceId,
      sequenceNumber: data.sequenceNumber.present
          ? data.sequenceNumber.value
          : this.sequenceNumber,
      ciphertext: data.ciphertext.present
          ? data.ciphertext.value
          : this.ciphertext,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      deliveryState: data.deliveryState.present
          ? data.deliveryState.value
          : this.deliveryState,
    );
  }

  @override
  String toString() {
    return (StringBuffer('MessageRow(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('senderDeviceId: $senderDeviceId, ')
          ..write('sequenceNumber: $sequenceNumber, ')
          ..write('ciphertext: $ciphertext, ')
          ..write('createdAt: $createdAt, ')
          ..write('deliveryState: $deliveryState')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    conversationId,
    senderDeviceId,
    sequenceNumber,
    $driftBlobEquality.hash(ciphertext),
    createdAt,
    deliveryState,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is MessageRow &&
          other.id == this.id &&
          other.conversationId == this.conversationId &&
          other.senderDeviceId == this.senderDeviceId &&
          other.sequenceNumber == this.sequenceNumber &&
          $driftBlobEquality.equals(other.ciphertext, this.ciphertext) &&
          other.createdAt == this.createdAt &&
          other.deliveryState == this.deliveryState);
}

class MessagesCompanion extends UpdateCompanion<MessageRow> {
  final Value<String> id;
  final Value<String> conversationId;
  final Value<String> senderDeviceId;
  final Value<int> sequenceNumber;
  final Value<Uint8List> ciphertext;
  final Value<int> createdAt;
  final Value<String> deliveryState;
  final Value<int> rowid;
  const MessagesCompanion({
    this.id = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.senderDeviceId = const Value.absent(),
    this.sequenceNumber = const Value.absent(),
    this.ciphertext = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.deliveryState = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  MessagesCompanion.insert({
    required String id,
    required String conversationId,
    required String senderDeviceId,
    required int sequenceNumber,
    required Uint8List ciphertext,
    required int createdAt,
    required String deliveryState,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       conversationId = Value(conversationId),
       senderDeviceId = Value(senderDeviceId),
       sequenceNumber = Value(sequenceNumber),
       ciphertext = Value(ciphertext),
       createdAt = Value(createdAt),
       deliveryState = Value(deliveryState);
  static Insertable<MessageRow> custom({
    Expression<String>? id,
    Expression<String>? conversationId,
    Expression<String>? senderDeviceId,
    Expression<int>? sequenceNumber,
    Expression<Uint8List>? ciphertext,
    Expression<int>? createdAt,
    Expression<String>? deliveryState,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (conversationId != null) 'conversation_id': conversationId,
      if (senderDeviceId != null) 'sender_device_id': senderDeviceId,
      if (sequenceNumber != null) 'sequence_number': sequenceNumber,
      if (ciphertext != null) 'ciphertext': ciphertext,
      if (createdAt != null) 'created_at': createdAt,
      if (deliveryState != null) 'delivery_state': deliveryState,
      if (rowid != null) 'rowid': rowid,
    });
  }

  MessagesCompanion copyWith({
    Value<String>? id,
    Value<String>? conversationId,
    Value<String>? senderDeviceId,
    Value<int>? sequenceNumber,
    Value<Uint8List>? ciphertext,
    Value<int>? createdAt,
    Value<String>? deliveryState,
    Value<int>? rowid,
  }) {
    return MessagesCompanion(
      id: id ?? this.id,
      conversationId: conversationId ?? this.conversationId,
      senderDeviceId: senderDeviceId ?? this.senderDeviceId,
      sequenceNumber: sequenceNumber ?? this.sequenceNumber,
      ciphertext: ciphertext ?? this.ciphertext,
      createdAt: createdAt ?? this.createdAt,
      deliveryState: deliveryState ?? this.deliveryState,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (senderDeviceId.present) {
      map['sender_device_id'] = Variable<String>(senderDeviceId.value);
    }
    if (sequenceNumber.present) {
      map['sequence_number'] = Variable<int>(sequenceNumber.value);
    }
    if (ciphertext.present) {
      map['ciphertext'] = Variable<Uint8List>(ciphertext.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (deliveryState.present) {
      map['delivery_state'] = Variable<String>(deliveryState.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('MessagesCompanion(')
          ..write('id: $id, ')
          ..write('conversationId: $conversationId, ')
          ..write('senderDeviceId: $senderDeviceId, ')
          ..write('sequenceNumber: $sequenceNumber, ')
          ..write('ciphertext: $ciphertext, ')
          ..write('createdAt: $createdAt, ')
          ..write('deliveryState: $deliveryState, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $DeliveryStatesTable extends DeliveryStates
    with TableInfo<$DeliveryStatesTable, DeliveryStateRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeliveryStatesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _messageIdMeta = const VerificationMeta(
    'messageId',
  );
  @override
  late final GeneratedColumn<String> messageId = GeneratedColumn<String>(
    'message_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _stateMeta = const VerificationMeta('state');
  @override
  late final GeneratedColumn<String> state = GeneratedColumn<String>(
    'state',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _changedAtMeta = const VerificationMeta(
    'changedAt',
  );
  @override
  late final GeneratedColumn<int> changedAt = GeneratedColumn<int>(
    'changed_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [messageId, state, changedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'delivery_states';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeliveryStateRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('message_id')) {
      context.handle(
        _messageIdMeta,
        messageId.isAcceptableOrUnknown(data['message_id']!, _messageIdMeta),
      );
    } else if (isInserting) {
      context.missing(_messageIdMeta);
    }
    if (data.containsKey('state')) {
      context.handle(
        _stateMeta,
        state.isAcceptableOrUnknown(data['state']!, _stateMeta),
      );
    } else if (isInserting) {
      context.missing(_stateMeta);
    }
    if (data.containsKey('changed_at')) {
      context.handle(
        _changedAtMeta,
        changedAt.isAcceptableOrUnknown(data['changed_at']!, _changedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_changedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {messageId, state};
  @override
  DeliveryStateRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeliveryStateRow(
      messageId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}message_id'],
      )!,
      state: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}state'],
      )!,
      changedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}changed_at'],
      )!,
    );
  }

  @override
  $DeliveryStatesTable createAlias(String alias) {
    return $DeliveryStatesTable(attachedDatabase, alias);
  }
}

class DeliveryStateRow extends DataClass
    implements Insertable<DeliveryStateRow> {
  final String messageId;

  /// A `DeliveryState.name` string, same convention as `messages
  /// .deliveryState`.
  final String state;
  final int changedAt;
  const DeliveryStateRow({
    required this.messageId,
    required this.state,
    required this.changedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['message_id'] = Variable<String>(messageId);
    map['state'] = Variable<String>(state);
    map['changed_at'] = Variable<int>(changedAt);
    return map;
  }

  DeliveryStatesCompanion toCompanion(bool nullToAbsent) {
    return DeliveryStatesCompanion(
      messageId: Value(messageId),
      state: Value(state),
      changedAt: Value(changedAt),
    );
  }

  factory DeliveryStateRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeliveryStateRow(
      messageId: serializer.fromJson<String>(json['messageId']),
      state: serializer.fromJson<String>(json['state']),
      changedAt: serializer.fromJson<int>(json['changedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'messageId': serializer.toJson<String>(messageId),
      'state': serializer.toJson<String>(state),
      'changedAt': serializer.toJson<int>(changedAt),
    };
  }

  DeliveryStateRow copyWith({
    String? messageId,
    String? state,
    int? changedAt,
  }) => DeliveryStateRow(
    messageId: messageId ?? this.messageId,
    state: state ?? this.state,
    changedAt: changedAt ?? this.changedAt,
  );
  DeliveryStateRow copyWithCompanion(DeliveryStatesCompanion data) {
    return DeliveryStateRow(
      messageId: data.messageId.present ? data.messageId.value : this.messageId,
      state: data.state.present ? data.state.value : this.state,
      changedAt: data.changedAt.present ? data.changedAt.value : this.changedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeliveryStateRow(')
          ..write('messageId: $messageId, ')
          ..write('state: $state, ')
          ..write('changedAt: $changedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(messageId, state, changedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeliveryStateRow &&
          other.messageId == this.messageId &&
          other.state == this.state &&
          other.changedAt == this.changedAt);
}

class DeliveryStatesCompanion extends UpdateCompanion<DeliveryStateRow> {
  final Value<String> messageId;
  final Value<String> state;
  final Value<int> changedAt;
  final Value<int> rowid;
  const DeliveryStatesCompanion({
    this.messageId = const Value.absent(),
    this.state = const Value.absent(),
    this.changedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeliveryStatesCompanion.insert({
    required String messageId,
    required String state,
    required int changedAt,
    this.rowid = const Value.absent(),
  }) : messageId = Value(messageId),
       state = Value(state),
       changedAt = Value(changedAt);
  static Insertable<DeliveryStateRow> custom({
    Expression<String>? messageId,
    Expression<String>? state,
    Expression<int>? changedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (messageId != null) 'message_id': messageId,
      if (state != null) 'state': state,
      if (changedAt != null) 'changed_at': changedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeliveryStatesCompanion copyWith({
    Value<String>? messageId,
    Value<String>? state,
    Value<int>? changedAt,
    Value<int>? rowid,
  }) {
    return DeliveryStatesCompanion(
      messageId: messageId ?? this.messageId,
      state: state ?? this.state,
      changedAt: changedAt ?? this.changedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (messageId.present) {
      map['message_id'] = Variable<String>(messageId.value);
    }
    if (state.present) {
      map['state'] = Variable<String>(state.value);
    }
    if (changedAt.present) {
      map['changed_at'] = Variable<int>(changedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeliveryStatesCompanion(')
          ..write('messageId: $messageId, ')
          ..write('state: $state, ')
          ..write('changedAt: $changedAt, ')
          ..write('rowid: $rowid')
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
  late final $RelationshipsTable relationships = $RelationshipsTable(this);
  late final $SignalIdentityTable signalIdentity = $SignalIdentityTable(this);
  late final $SignalSignedPrekeysTable signalSignedPrekeys =
      $SignalSignedPrekeysTable(this);
  late final $SignalOneTimePrekeysTable signalOneTimePrekeys =
      $SignalOneTimePrekeysTable(this);
  late final $SignalSessionsTable signalSessions = $SignalSessionsTable(this);
  late final $SignalTrustedIdentitiesTable signalTrustedIdentities =
      $SignalTrustedIdentitiesTable(this);
  late final $CryptoCountersTable cryptoCounters = $CryptoCountersTable(this);
  late final $RoutesTable routes = $RoutesTable(this);
  late final $RelayPacketsTable relayPackets = $RelayPacketsTable(this);
  late final $MessagesTable messages = $MessagesTable(this);
  late final $DeliveryStatesTable deliveryStates = $DeliveryStatesTable(this);
  late final Index idxMessagesConversationCreatedAt = Index(
    'idx_messages_conversation_created_at',
    'CREATE INDEX idx_messages_conversation_created_at ON messages (conversation_id, created_at)',
  );
  @override
  Iterable<TableInfo<Table, Object?>> get allTables =>
      allSchemaEntities.whereType<TableInfo<Table, Object?>>();
  @override
  List<DatabaseSchemaEntity> get allSchemaEntities => [
    deviceIdentities,
    relationships,
    signalIdentity,
    signalSignedPrekeys,
    signalOneTimePrekeys,
    signalSessions,
    signalTrustedIdentities,
    cryptoCounters,
    routes,
    relayPackets,
    messages,
    deliveryStates,
    idxMessagesConversationCreatedAt,
  ];
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
typedef $$RelationshipsTableCreateCompanionBuilder =
    RelationshipsCompanion Function({
      required String deviceId,
      required String state,
      required DateTime updatedAt,
      Value<int> rowid,
    });
typedef $$RelationshipsTableUpdateCompanionBuilder =
    RelationshipsCompanion Function({
      Value<String> deviceId,
      Value<String> state,
      Value<DateTime> updatedAt,
      Value<int> rowid,
    });

class $$RelationshipsTableFilterComposer
    extends Composer<_$AppDatabase, $RelationshipsTable> {
  $$RelationshipsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RelationshipsTableOrderingComposer
    extends Composer<_$AppDatabase, $RelationshipsTable> {
  $$RelationshipsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<DateTime> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RelationshipsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RelationshipsTable> {
  $$RelationshipsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<DateTime> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$RelationshipsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RelationshipsTable,
          RelationshipRow,
          $$RelationshipsTableFilterComposer,
          $$RelationshipsTableOrderingComposer,
          $$RelationshipsTableAnnotationComposer,
          $$RelationshipsTableCreateCompanionBuilder,
          $$RelationshipsTableUpdateCompanionBuilder,
          (
            RelationshipRow,
            BaseReferences<_$AppDatabase, $RelationshipsTable, RelationshipRow>,
          ),
          RelationshipRow,
          PrefetchHooks Function()
        > {
  $$RelationshipsTableTableManager(_$AppDatabase db, $RelationshipsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RelationshipsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RelationshipsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RelationshipsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> deviceId = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<DateTime> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RelationshipsCompanion(
                deviceId: deviceId,
                state: state,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String deviceId,
                required String state,
                required DateTime updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => RelationshipsCompanion.insert(
                deviceId: deviceId,
                state: state,
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

typedef $$RelationshipsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RelationshipsTable,
      RelationshipRow,
      $$RelationshipsTableFilterComposer,
      $$RelationshipsTableOrderingComposer,
      $$RelationshipsTableAnnotationComposer,
      $$RelationshipsTableCreateCompanionBuilder,
      $$RelationshipsTableUpdateCompanionBuilder,
      (
        RelationshipRow,
        BaseReferences<_$AppDatabase, $RelationshipsTable, RelationshipRow>,
      ),
      RelationshipRow,
      PrefetchHooks Function()
    >;
typedef $$SignalIdentityTableCreateCompanionBuilder =
    SignalIdentityCompanion Function({
      Value<int> id,
      required Uint8List identityKeyPair,
      required int registrationId,
    });
typedef $$SignalIdentityTableUpdateCompanionBuilder =
    SignalIdentityCompanion Function({
      Value<int> id,
      Value<Uint8List> identityKeyPair,
      Value<int> registrationId,
    });

class $$SignalIdentityTableFilterComposer
    extends Composer<_$AppDatabase, $SignalIdentityTable> {
  $$SignalIdentityTableFilterComposer({
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

  ColumnFilters<Uint8List> get identityKeyPair => $composableBuilder(
    column: $table.identityKeyPair,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get registrationId => $composableBuilder(
    column: $table.registrationId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SignalIdentityTableOrderingComposer
    extends Composer<_$AppDatabase, $SignalIdentityTable> {
  $$SignalIdentityTableOrderingComposer({
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

  ColumnOrderings<Uint8List> get identityKeyPair => $composableBuilder(
    column: $table.identityKeyPair,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get registrationId => $composableBuilder(
    column: $table.registrationId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SignalIdentityTableAnnotationComposer
    extends Composer<_$AppDatabase, $SignalIdentityTable> {
  $$SignalIdentityTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<Uint8List> get identityKeyPair => $composableBuilder(
    column: $table.identityKeyPair,
    builder: (column) => column,
  );

  GeneratedColumn<int> get registrationId => $composableBuilder(
    column: $table.registrationId,
    builder: (column) => column,
  );
}

class $$SignalIdentityTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SignalIdentityTable,
          SignalIdentityData,
          $$SignalIdentityTableFilterComposer,
          $$SignalIdentityTableOrderingComposer,
          $$SignalIdentityTableAnnotationComposer,
          $$SignalIdentityTableCreateCompanionBuilder,
          $$SignalIdentityTableUpdateCompanionBuilder,
          (
            SignalIdentityData,
            BaseReferences<
              _$AppDatabase,
              $SignalIdentityTable,
              SignalIdentityData
            >,
          ),
          SignalIdentityData,
          PrefetchHooks Function()
        > {
  $$SignalIdentityTableTableManager(
    _$AppDatabase db,
    $SignalIdentityTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SignalIdentityTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SignalIdentityTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SignalIdentityTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<Uint8List> identityKeyPair = const Value.absent(),
                Value<int> registrationId = const Value.absent(),
              }) => SignalIdentityCompanion(
                id: id,
                identityKeyPair: identityKeyPair,
                registrationId: registrationId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required Uint8List identityKeyPair,
                required int registrationId,
              }) => SignalIdentityCompanion.insert(
                id: id,
                identityKeyPair: identityKeyPair,
                registrationId: registrationId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SignalIdentityTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SignalIdentityTable,
      SignalIdentityData,
      $$SignalIdentityTableFilterComposer,
      $$SignalIdentityTableOrderingComposer,
      $$SignalIdentityTableAnnotationComposer,
      $$SignalIdentityTableCreateCompanionBuilder,
      $$SignalIdentityTableUpdateCompanionBuilder,
      (
        SignalIdentityData,
        BaseReferences<_$AppDatabase, $SignalIdentityTable, SignalIdentityData>,
      ),
      SignalIdentityData,
      PrefetchHooks Function()
    >;
typedef $$SignalSignedPrekeysTableCreateCompanionBuilder =
    SignalSignedPrekeysCompanion Function({
      Value<int> id,
      required Uint8List record,
    });
typedef $$SignalSignedPrekeysTableUpdateCompanionBuilder =
    SignalSignedPrekeysCompanion Function({
      Value<int> id,
      Value<Uint8List> record,
    });

class $$SignalSignedPrekeysTableFilterComposer
    extends Composer<_$AppDatabase, $SignalSignedPrekeysTable> {
  $$SignalSignedPrekeysTableFilterComposer({
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

  ColumnFilters<Uint8List> get record => $composableBuilder(
    column: $table.record,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SignalSignedPrekeysTableOrderingComposer
    extends Composer<_$AppDatabase, $SignalSignedPrekeysTable> {
  $$SignalSignedPrekeysTableOrderingComposer({
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

  ColumnOrderings<Uint8List> get record => $composableBuilder(
    column: $table.record,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SignalSignedPrekeysTableAnnotationComposer
    extends Composer<_$AppDatabase, $SignalSignedPrekeysTable> {
  $$SignalSignedPrekeysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<Uint8List> get record =>
      $composableBuilder(column: $table.record, builder: (column) => column);
}

class $$SignalSignedPrekeysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SignalSignedPrekeysTable,
          SignalSignedPrekey,
          $$SignalSignedPrekeysTableFilterComposer,
          $$SignalSignedPrekeysTableOrderingComposer,
          $$SignalSignedPrekeysTableAnnotationComposer,
          $$SignalSignedPrekeysTableCreateCompanionBuilder,
          $$SignalSignedPrekeysTableUpdateCompanionBuilder,
          (
            SignalSignedPrekey,
            BaseReferences<
              _$AppDatabase,
              $SignalSignedPrekeysTable,
              SignalSignedPrekey
            >,
          ),
          SignalSignedPrekey,
          PrefetchHooks Function()
        > {
  $$SignalSignedPrekeysTableTableManager(
    _$AppDatabase db,
    $SignalSignedPrekeysTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SignalSignedPrekeysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SignalSignedPrekeysTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SignalSignedPrekeysTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<Uint8List> record = const Value.absent(),
              }) => SignalSignedPrekeysCompanion(id: id, record: record),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required Uint8List record,
              }) => SignalSignedPrekeysCompanion.insert(id: id, record: record),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SignalSignedPrekeysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SignalSignedPrekeysTable,
      SignalSignedPrekey,
      $$SignalSignedPrekeysTableFilterComposer,
      $$SignalSignedPrekeysTableOrderingComposer,
      $$SignalSignedPrekeysTableAnnotationComposer,
      $$SignalSignedPrekeysTableCreateCompanionBuilder,
      $$SignalSignedPrekeysTableUpdateCompanionBuilder,
      (
        SignalSignedPrekey,
        BaseReferences<
          _$AppDatabase,
          $SignalSignedPrekeysTable,
          SignalSignedPrekey
        >,
      ),
      SignalSignedPrekey,
      PrefetchHooks Function()
    >;
typedef $$SignalOneTimePrekeysTableCreateCompanionBuilder =
    SignalOneTimePrekeysCompanion Function({
      Value<int> id,
      required Uint8List record,
    });
typedef $$SignalOneTimePrekeysTableUpdateCompanionBuilder =
    SignalOneTimePrekeysCompanion Function({
      Value<int> id,
      Value<Uint8List> record,
    });

class $$SignalOneTimePrekeysTableFilterComposer
    extends Composer<_$AppDatabase, $SignalOneTimePrekeysTable> {
  $$SignalOneTimePrekeysTableFilterComposer({
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

  ColumnFilters<Uint8List> get record => $composableBuilder(
    column: $table.record,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SignalOneTimePrekeysTableOrderingComposer
    extends Composer<_$AppDatabase, $SignalOneTimePrekeysTable> {
  $$SignalOneTimePrekeysTableOrderingComposer({
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

  ColumnOrderings<Uint8List> get record => $composableBuilder(
    column: $table.record,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SignalOneTimePrekeysTableAnnotationComposer
    extends Composer<_$AppDatabase, $SignalOneTimePrekeysTable> {
  $$SignalOneTimePrekeysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<Uint8List> get record =>
      $composableBuilder(column: $table.record, builder: (column) => column);
}

class $$SignalOneTimePrekeysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SignalOneTimePrekeysTable,
          SignalOneTimePrekey,
          $$SignalOneTimePrekeysTableFilterComposer,
          $$SignalOneTimePrekeysTableOrderingComposer,
          $$SignalOneTimePrekeysTableAnnotationComposer,
          $$SignalOneTimePrekeysTableCreateCompanionBuilder,
          $$SignalOneTimePrekeysTableUpdateCompanionBuilder,
          (
            SignalOneTimePrekey,
            BaseReferences<
              _$AppDatabase,
              $SignalOneTimePrekeysTable,
              SignalOneTimePrekey
            >,
          ),
          SignalOneTimePrekey,
          PrefetchHooks Function()
        > {
  $$SignalOneTimePrekeysTableTableManager(
    _$AppDatabase db,
    $SignalOneTimePrekeysTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SignalOneTimePrekeysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SignalOneTimePrekeysTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SignalOneTimePrekeysTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<Uint8List> record = const Value.absent(),
              }) => SignalOneTimePrekeysCompanion(id: id, record: record),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required Uint8List record,
              }) =>
                  SignalOneTimePrekeysCompanion.insert(id: id, record: record),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SignalOneTimePrekeysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SignalOneTimePrekeysTable,
      SignalOneTimePrekey,
      $$SignalOneTimePrekeysTableFilterComposer,
      $$SignalOneTimePrekeysTableOrderingComposer,
      $$SignalOneTimePrekeysTableAnnotationComposer,
      $$SignalOneTimePrekeysTableCreateCompanionBuilder,
      $$SignalOneTimePrekeysTableUpdateCompanionBuilder,
      (
        SignalOneTimePrekey,
        BaseReferences<
          _$AppDatabase,
          $SignalOneTimePrekeysTable,
          SignalOneTimePrekey
        >,
      ),
      SignalOneTimePrekey,
      PrefetchHooks Function()
    >;
typedef $$SignalSessionsTableCreateCompanionBuilder =
    SignalSessionsCompanion Function({
      required String addressName,
      required int addressDeviceId,
      required Uint8List record,
      Value<int> rowid,
    });
typedef $$SignalSessionsTableUpdateCompanionBuilder =
    SignalSessionsCompanion Function({
      Value<String> addressName,
      Value<int> addressDeviceId,
      Value<Uint8List> record,
      Value<int> rowid,
    });

class $$SignalSessionsTableFilterComposer
    extends Composer<_$AppDatabase, $SignalSessionsTable> {
  $$SignalSessionsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get addressName => $composableBuilder(
    column: $table.addressName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addressDeviceId => $composableBuilder(
    column: $table.addressDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get record => $composableBuilder(
    column: $table.record,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SignalSessionsTableOrderingComposer
    extends Composer<_$AppDatabase, $SignalSessionsTable> {
  $$SignalSessionsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get addressName => $composableBuilder(
    column: $table.addressName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addressDeviceId => $composableBuilder(
    column: $table.addressDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get record => $composableBuilder(
    column: $table.record,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SignalSessionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SignalSessionsTable> {
  $$SignalSessionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get addressName => $composableBuilder(
    column: $table.addressName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get addressDeviceId => $composableBuilder(
    column: $table.addressDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get record =>
      $composableBuilder(column: $table.record, builder: (column) => column);
}

class $$SignalSessionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SignalSessionsTable,
          SignalSession,
          $$SignalSessionsTableFilterComposer,
          $$SignalSessionsTableOrderingComposer,
          $$SignalSessionsTableAnnotationComposer,
          $$SignalSessionsTableCreateCompanionBuilder,
          $$SignalSessionsTableUpdateCompanionBuilder,
          (
            SignalSession,
            BaseReferences<_$AppDatabase, $SignalSessionsTable, SignalSession>,
          ),
          SignalSession,
          PrefetchHooks Function()
        > {
  $$SignalSessionsTableTableManager(
    _$AppDatabase db,
    $SignalSessionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SignalSessionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SignalSessionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SignalSessionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> addressName = const Value.absent(),
                Value<int> addressDeviceId = const Value.absent(),
                Value<Uint8List> record = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SignalSessionsCompanion(
                addressName: addressName,
                addressDeviceId: addressDeviceId,
                record: record,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String addressName,
                required int addressDeviceId,
                required Uint8List record,
                Value<int> rowid = const Value.absent(),
              }) => SignalSessionsCompanion.insert(
                addressName: addressName,
                addressDeviceId: addressDeviceId,
                record: record,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SignalSessionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SignalSessionsTable,
      SignalSession,
      $$SignalSessionsTableFilterComposer,
      $$SignalSessionsTableOrderingComposer,
      $$SignalSessionsTableAnnotationComposer,
      $$SignalSessionsTableCreateCompanionBuilder,
      $$SignalSessionsTableUpdateCompanionBuilder,
      (
        SignalSession,
        BaseReferences<_$AppDatabase, $SignalSessionsTable, SignalSession>,
      ),
      SignalSession,
      PrefetchHooks Function()
    >;
typedef $$SignalTrustedIdentitiesTableCreateCompanionBuilder =
    SignalTrustedIdentitiesCompanion Function({
      required String addressName,
      required int addressDeviceId,
      required Uint8List identityKey,
      Value<int> rowid,
    });
typedef $$SignalTrustedIdentitiesTableUpdateCompanionBuilder =
    SignalTrustedIdentitiesCompanion Function({
      Value<String> addressName,
      Value<int> addressDeviceId,
      Value<Uint8List> identityKey,
      Value<int> rowid,
    });

class $$SignalTrustedIdentitiesTableFilterComposer
    extends Composer<_$AppDatabase, $SignalTrustedIdentitiesTable> {
  $$SignalTrustedIdentitiesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get addressName => $composableBuilder(
    column: $table.addressName,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get addressDeviceId => $composableBuilder(
    column: $table.addressDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get identityKey => $composableBuilder(
    column: $table.identityKey,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SignalTrustedIdentitiesTableOrderingComposer
    extends Composer<_$AppDatabase, $SignalTrustedIdentitiesTable> {
  $$SignalTrustedIdentitiesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get addressName => $composableBuilder(
    column: $table.addressName,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get addressDeviceId => $composableBuilder(
    column: $table.addressDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get identityKey => $composableBuilder(
    column: $table.identityKey,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SignalTrustedIdentitiesTableAnnotationComposer
    extends Composer<_$AppDatabase, $SignalTrustedIdentitiesTable> {
  $$SignalTrustedIdentitiesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get addressName => $composableBuilder(
    column: $table.addressName,
    builder: (column) => column,
  );

  GeneratedColumn<int> get addressDeviceId => $composableBuilder(
    column: $table.addressDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get identityKey => $composableBuilder(
    column: $table.identityKey,
    builder: (column) => column,
  );
}

class $$SignalTrustedIdentitiesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SignalTrustedIdentitiesTable,
          SignalTrustedIdentity,
          $$SignalTrustedIdentitiesTableFilterComposer,
          $$SignalTrustedIdentitiesTableOrderingComposer,
          $$SignalTrustedIdentitiesTableAnnotationComposer,
          $$SignalTrustedIdentitiesTableCreateCompanionBuilder,
          $$SignalTrustedIdentitiesTableUpdateCompanionBuilder,
          (
            SignalTrustedIdentity,
            BaseReferences<
              _$AppDatabase,
              $SignalTrustedIdentitiesTable,
              SignalTrustedIdentity
            >,
          ),
          SignalTrustedIdentity,
          PrefetchHooks Function()
        > {
  $$SignalTrustedIdentitiesTableTableManager(
    _$AppDatabase db,
    $SignalTrustedIdentitiesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SignalTrustedIdentitiesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$SignalTrustedIdentitiesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$SignalTrustedIdentitiesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> addressName = const Value.absent(),
                Value<int> addressDeviceId = const Value.absent(),
                Value<Uint8List> identityKey = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SignalTrustedIdentitiesCompanion(
                addressName: addressName,
                addressDeviceId: addressDeviceId,
                identityKey: identityKey,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String addressName,
                required int addressDeviceId,
                required Uint8List identityKey,
                Value<int> rowid = const Value.absent(),
              }) => SignalTrustedIdentitiesCompanion.insert(
                addressName: addressName,
                addressDeviceId: addressDeviceId,
                identityKey: identityKey,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$SignalTrustedIdentitiesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SignalTrustedIdentitiesTable,
      SignalTrustedIdentity,
      $$SignalTrustedIdentitiesTableFilterComposer,
      $$SignalTrustedIdentitiesTableOrderingComposer,
      $$SignalTrustedIdentitiesTableAnnotationComposer,
      $$SignalTrustedIdentitiesTableCreateCompanionBuilder,
      $$SignalTrustedIdentitiesTableUpdateCompanionBuilder,
      (
        SignalTrustedIdentity,
        BaseReferences<
          _$AppDatabase,
          $SignalTrustedIdentitiesTable,
          SignalTrustedIdentity
        >,
      ),
      SignalTrustedIdentity,
      PrefetchHooks Function()
    >;
typedef $$CryptoCountersTableCreateCompanionBuilder =
    CryptoCountersCompanion Function({
      Value<int> id,
      Value<int> nextOneTimePreKeyId,
      Value<int> nextIssuedOneTimePreKeyId,
    });
typedef $$CryptoCountersTableUpdateCompanionBuilder =
    CryptoCountersCompanion Function({
      Value<int> id,
      Value<int> nextOneTimePreKeyId,
      Value<int> nextIssuedOneTimePreKeyId,
    });

class $$CryptoCountersTableFilterComposer
    extends Composer<_$AppDatabase, $CryptoCountersTable> {
  $$CryptoCountersTableFilterComposer({
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

  ColumnFilters<int> get nextOneTimePreKeyId => $composableBuilder(
    column: $table.nextOneTimePreKeyId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get nextIssuedOneTimePreKeyId => $composableBuilder(
    column: $table.nextIssuedOneTimePreKeyId,
    builder: (column) => ColumnFilters(column),
  );
}

class $$CryptoCountersTableOrderingComposer
    extends Composer<_$AppDatabase, $CryptoCountersTable> {
  $$CryptoCountersTableOrderingComposer({
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

  ColumnOrderings<int> get nextOneTimePreKeyId => $composableBuilder(
    column: $table.nextOneTimePreKeyId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get nextIssuedOneTimePreKeyId => $composableBuilder(
    column: $table.nextIssuedOneTimePreKeyId,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$CryptoCountersTableAnnotationComposer
    extends Composer<_$AppDatabase, $CryptoCountersTable> {
  $$CryptoCountersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get nextOneTimePreKeyId => $composableBuilder(
    column: $table.nextOneTimePreKeyId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get nextIssuedOneTimePreKeyId => $composableBuilder(
    column: $table.nextIssuedOneTimePreKeyId,
    builder: (column) => column,
  );
}

class $$CryptoCountersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $CryptoCountersTable,
          CryptoCounter,
          $$CryptoCountersTableFilterComposer,
          $$CryptoCountersTableOrderingComposer,
          $$CryptoCountersTableAnnotationComposer,
          $$CryptoCountersTableCreateCompanionBuilder,
          $$CryptoCountersTableUpdateCompanionBuilder,
          (
            CryptoCounter,
            BaseReferences<_$AppDatabase, $CryptoCountersTable, CryptoCounter>,
          ),
          CryptoCounter,
          PrefetchHooks Function()
        > {
  $$CryptoCountersTableTableManager(
    _$AppDatabase db,
    $CryptoCountersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$CryptoCountersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$CryptoCountersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$CryptoCountersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> nextOneTimePreKeyId = const Value.absent(),
                Value<int> nextIssuedOneTimePreKeyId = const Value.absent(),
              }) => CryptoCountersCompanion(
                id: id,
                nextOneTimePreKeyId: nextOneTimePreKeyId,
                nextIssuedOneTimePreKeyId: nextIssuedOneTimePreKeyId,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> nextOneTimePreKeyId = const Value.absent(),
                Value<int> nextIssuedOneTimePreKeyId = const Value.absent(),
              }) => CryptoCountersCompanion.insert(
                id: id,
                nextOneTimePreKeyId: nextOneTimePreKeyId,
                nextIssuedOneTimePreKeyId: nextIssuedOneTimePreKeyId,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$CryptoCountersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $CryptoCountersTable,
      CryptoCounter,
      $$CryptoCountersTableFilterComposer,
      $$CryptoCountersTableOrderingComposer,
      $$CryptoCountersTableAnnotationComposer,
      $$CryptoCountersTableCreateCompanionBuilder,
      $$CryptoCountersTableUpdateCompanionBuilder,
      (
        CryptoCounter,
        BaseReferences<_$AppDatabase, $CryptoCountersTable, CryptoCounter>,
      ),
      CryptoCounter,
      PrefetchHooks Function()
    >;
typedef $$RoutesTableCreateCompanionBuilder =
    RoutesCompanion Function({
      required String destinationId,
      required String hops,
      required double lastCost,
      required int lastMeasuredAt,
      Value<int?> stableSinceTick,
      Value<int> rowid,
    });
typedef $$RoutesTableUpdateCompanionBuilder =
    RoutesCompanion Function({
      Value<String> destinationId,
      Value<String> hops,
      Value<double> lastCost,
      Value<int> lastMeasuredAt,
      Value<int?> stableSinceTick,
      Value<int> rowid,
    });

class $$RoutesTableFilterComposer
    extends Composer<_$AppDatabase, $RoutesTable> {
  $$RoutesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get destinationId => $composableBuilder(
    column: $table.destinationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get hops => $composableBuilder(
    column: $table.hops,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<double> get lastCost => $composableBuilder(
    column: $table.lastCost,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastMeasuredAt => $composableBuilder(
    column: $table.lastMeasuredAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get stableSinceTick => $composableBuilder(
    column: $table.stableSinceTick,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RoutesTableOrderingComposer
    extends Composer<_$AppDatabase, $RoutesTable> {
  $$RoutesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get destinationId => $composableBuilder(
    column: $table.destinationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get hops => $composableBuilder(
    column: $table.hops,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<double> get lastCost => $composableBuilder(
    column: $table.lastCost,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastMeasuredAt => $composableBuilder(
    column: $table.lastMeasuredAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get stableSinceTick => $composableBuilder(
    column: $table.stableSinceTick,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RoutesTableAnnotationComposer
    extends Composer<_$AppDatabase, $RoutesTable> {
  $$RoutesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get destinationId => $composableBuilder(
    column: $table.destinationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get hops =>
      $composableBuilder(column: $table.hops, builder: (column) => column);

  GeneratedColumn<double> get lastCost =>
      $composableBuilder(column: $table.lastCost, builder: (column) => column);

  GeneratedColumn<int> get lastMeasuredAt => $composableBuilder(
    column: $table.lastMeasuredAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get stableSinceTick => $composableBuilder(
    column: $table.stableSinceTick,
    builder: (column) => column,
  );
}

class $$RoutesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RoutesTable,
          RouteRow,
          $$RoutesTableFilterComposer,
          $$RoutesTableOrderingComposer,
          $$RoutesTableAnnotationComposer,
          $$RoutesTableCreateCompanionBuilder,
          $$RoutesTableUpdateCompanionBuilder,
          (RouteRow, BaseReferences<_$AppDatabase, $RoutesTable, RouteRow>),
          RouteRow,
          PrefetchHooks Function()
        > {
  $$RoutesTableTableManager(_$AppDatabase db, $RoutesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RoutesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RoutesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RoutesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> destinationId = const Value.absent(),
                Value<String> hops = const Value.absent(),
                Value<double> lastCost = const Value.absent(),
                Value<int> lastMeasuredAt = const Value.absent(),
                Value<int?> stableSinceTick = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RoutesCompanion(
                destinationId: destinationId,
                hops: hops,
                lastCost: lastCost,
                lastMeasuredAt: lastMeasuredAt,
                stableSinceTick: stableSinceTick,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String destinationId,
                required String hops,
                required double lastCost,
                required int lastMeasuredAt,
                Value<int?> stableSinceTick = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RoutesCompanion.insert(
                destinationId: destinationId,
                hops: hops,
                lastCost: lastCost,
                lastMeasuredAt: lastMeasuredAt,
                stableSinceTick: stableSinceTick,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RoutesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RoutesTable,
      RouteRow,
      $$RoutesTableFilterComposer,
      $$RoutesTableOrderingComposer,
      $$RoutesTableAnnotationComposer,
      $$RoutesTableCreateCompanionBuilder,
      $$RoutesTableUpdateCompanionBuilder,
      (RouteRow, BaseReferences<_$AppDatabase, $RoutesTable, RouteRow>),
      RouteRow,
      PrefetchHooks Function()
    >;
typedef $$RelayPacketsTableCreateCompanionBuilder =
    RelayPacketsCompanion Function({
      required String id,
      required String destinationId,
      Value<Uint8List?> payload,
      required int priority,
      required int sizeBytes,
      required int createdAt,
      required int expiresAt,
      required String deliveryState,
      Value<int> rowid,
    });
typedef $$RelayPacketsTableUpdateCompanionBuilder =
    RelayPacketsCompanion Function({
      Value<String> id,
      Value<String> destinationId,
      Value<Uint8List?> payload,
      Value<int> priority,
      Value<int> sizeBytes,
      Value<int> createdAt,
      Value<int> expiresAt,
      Value<String> deliveryState,
      Value<int> rowid,
    });

class $$RelayPacketsTableFilterComposer
    extends Composer<_$AppDatabase, $RelayPacketsTable> {
  $$RelayPacketsTableFilterComposer({
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

  ColumnFilters<String> get destinationId => $composableBuilder(
    column: $table.destinationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deliveryState => $composableBuilder(
    column: $table.deliveryState,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RelayPacketsTableOrderingComposer
    extends Composer<_$AppDatabase, $RelayPacketsTable> {
  $$RelayPacketsTableOrderingComposer({
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

  ColumnOrderings<String> get destinationId => $composableBuilder(
    column: $table.destinationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get payload => $composableBuilder(
    column: $table.payload,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get priority => $composableBuilder(
    column: $table.priority,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sizeBytes => $composableBuilder(
    column: $table.sizeBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get expiresAt => $composableBuilder(
    column: $table.expiresAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deliveryState => $composableBuilder(
    column: $table.deliveryState,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RelayPacketsTableAnnotationComposer
    extends Composer<_$AppDatabase, $RelayPacketsTable> {
  $$RelayPacketsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get destinationId => $composableBuilder(
    column: $table.destinationId,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get payload =>
      $composableBuilder(column: $table.payload, builder: (column) => column);

  GeneratedColumn<int> get priority =>
      $composableBuilder(column: $table.priority, builder: (column) => column);

  GeneratedColumn<int> get sizeBytes =>
      $composableBuilder(column: $table.sizeBytes, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<int> get expiresAt =>
      $composableBuilder(column: $table.expiresAt, builder: (column) => column);

  GeneratedColumn<String> get deliveryState => $composableBuilder(
    column: $table.deliveryState,
    builder: (column) => column,
  );
}

class $$RelayPacketsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RelayPacketsTable,
          RelayPacketRow,
          $$RelayPacketsTableFilterComposer,
          $$RelayPacketsTableOrderingComposer,
          $$RelayPacketsTableAnnotationComposer,
          $$RelayPacketsTableCreateCompanionBuilder,
          $$RelayPacketsTableUpdateCompanionBuilder,
          (
            RelayPacketRow,
            BaseReferences<_$AppDatabase, $RelayPacketsTable, RelayPacketRow>,
          ),
          RelayPacketRow,
          PrefetchHooks Function()
        > {
  $$RelayPacketsTableTableManager(_$AppDatabase db, $RelayPacketsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RelayPacketsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RelayPacketsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RelayPacketsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> destinationId = const Value.absent(),
                Value<Uint8List?> payload = const Value.absent(),
                Value<int> priority = const Value.absent(),
                Value<int> sizeBytes = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> expiresAt = const Value.absent(),
                Value<String> deliveryState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RelayPacketsCompanion(
                id: id,
                destinationId: destinationId,
                payload: payload,
                priority: priority,
                sizeBytes: sizeBytes,
                createdAt: createdAt,
                expiresAt: expiresAt,
                deliveryState: deliveryState,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String destinationId,
                Value<Uint8List?> payload = const Value.absent(),
                required int priority,
                required int sizeBytes,
                required int createdAt,
                required int expiresAt,
                required String deliveryState,
                Value<int> rowid = const Value.absent(),
              }) => RelayPacketsCompanion.insert(
                id: id,
                destinationId: destinationId,
                payload: payload,
                priority: priority,
                sizeBytes: sizeBytes,
                createdAt: createdAt,
                expiresAt: expiresAt,
                deliveryState: deliveryState,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RelayPacketsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RelayPacketsTable,
      RelayPacketRow,
      $$RelayPacketsTableFilterComposer,
      $$RelayPacketsTableOrderingComposer,
      $$RelayPacketsTableAnnotationComposer,
      $$RelayPacketsTableCreateCompanionBuilder,
      $$RelayPacketsTableUpdateCompanionBuilder,
      (
        RelayPacketRow,
        BaseReferences<_$AppDatabase, $RelayPacketsTable, RelayPacketRow>,
      ),
      RelayPacketRow,
      PrefetchHooks Function()
    >;
typedef $$MessagesTableCreateCompanionBuilder =
    MessagesCompanion Function({
      required String id,
      required String conversationId,
      required String senderDeviceId,
      required int sequenceNumber,
      required Uint8List ciphertext,
      required int createdAt,
      required String deliveryState,
      Value<int> rowid,
    });
typedef $$MessagesTableUpdateCompanionBuilder =
    MessagesCompanion Function({
      Value<String> id,
      Value<String> conversationId,
      Value<String> senderDeviceId,
      Value<int> sequenceNumber,
      Value<Uint8List> ciphertext,
      Value<int> createdAt,
      Value<String> deliveryState,
      Value<int> rowid,
    });

class $$MessagesTableFilterComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableFilterComposer({
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

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderDeviceId => $composableBuilder(
    column: $table.senderDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get sequenceNumber => $composableBuilder(
    column: $table.sequenceNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get ciphertext => $composableBuilder(
    column: $table.ciphertext,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deliveryState => $composableBuilder(
    column: $table.deliveryState,
    builder: (column) => ColumnFilters(column),
  );
}

class $$MessagesTableOrderingComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableOrderingComposer({
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

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderDeviceId => $composableBuilder(
    column: $table.senderDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get sequenceNumber => $composableBuilder(
    column: $table.sequenceNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get ciphertext => $composableBuilder(
    column: $table.ciphertext,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deliveryState => $composableBuilder(
    column: $table.deliveryState,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$MessagesTableAnnotationComposer
    extends Composer<_$AppDatabase, $MessagesTable> {
  $$MessagesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get senderDeviceId => $composableBuilder(
    column: $table.senderDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get sequenceNumber => $composableBuilder(
    column: $table.sequenceNumber,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get ciphertext => $composableBuilder(
    column: $table.ciphertext,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get deliveryState => $composableBuilder(
    column: $table.deliveryState,
    builder: (column) => column,
  );
}

class $$MessagesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $MessagesTable,
          MessageRow,
          $$MessagesTableFilterComposer,
          $$MessagesTableOrderingComposer,
          $$MessagesTableAnnotationComposer,
          $$MessagesTableCreateCompanionBuilder,
          $$MessagesTableUpdateCompanionBuilder,
          (
            MessageRow,
            BaseReferences<_$AppDatabase, $MessagesTable, MessageRow>,
          ),
          MessageRow,
          PrefetchHooks Function()
        > {
  $$MessagesTableTableManager(_$AppDatabase db, $MessagesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$MessagesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$MessagesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$MessagesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<String> senderDeviceId = const Value.absent(),
                Value<int> sequenceNumber = const Value.absent(),
                Value<Uint8List> ciphertext = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String> deliveryState = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion(
                id: id,
                conversationId: conversationId,
                senderDeviceId: senderDeviceId,
                sequenceNumber: sequenceNumber,
                ciphertext: ciphertext,
                createdAt: createdAt,
                deliveryState: deliveryState,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String conversationId,
                required String senderDeviceId,
                required int sequenceNumber,
                required Uint8List ciphertext,
                required int createdAt,
                required String deliveryState,
                Value<int> rowid = const Value.absent(),
              }) => MessagesCompanion.insert(
                id: id,
                conversationId: conversationId,
                senderDeviceId: senderDeviceId,
                sequenceNumber: sequenceNumber,
                ciphertext: ciphertext,
                createdAt: createdAt,
                deliveryState: deliveryState,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$MessagesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $MessagesTable,
      MessageRow,
      $$MessagesTableFilterComposer,
      $$MessagesTableOrderingComposer,
      $$MessagesTableAnnotationComposer,
      $$MessagesTableCreateCompanionBuilder,
      $$MessagesTableUpdateCompanionBuilder,
      (MessageRow, BaseReferences<_$AppDatabase, $MessagesTable, MessageRow>),
      MessageRow,
      PrefetchHooks Function()
    >;
typedef $$DeliveryStatesTableCreateCompanionBuilder =
    DeliveryStatesCompanion Function({
      required String messageId,
      required String state,
      required int changedAt,
      Value<int> rowid,
    });
typedef $$DeliveryStatesTableUpdateCompanionBuilder =
    DeliveryStatesCompanion Function({
      Value<String> messageId,
      Value<String> state,
      Value<int> changedAt,
      Value<int> rowid,
    });

class $$DeliveryStatesTableFilterComposer
    extends Composer<_$AppDatabase, $DeliveryStatesTable> {
  $$DeliveryStatesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get changedAt => $composableBuilder(
    column: $table.changedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeliveryStatesTableOrderingComposer
    extends Composer<_$AppDatabase, $DeliveryStatesTable> {
  $$DeliveryStatesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get messageId => $composableBuilder(
    column: $table.messageId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get state => $composableBuilder(
    column: $table.state,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get changedAt => $composableBuilder(
    column: $table.changedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeliveryStatesTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeliveryStatesTable> {
  $$DeliveryStatesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get messageId =>
      $composableBuilder(column: $table.messageId, builder: (column) => column);

  GeneratedColumn<String> get state =>
      $composableBuilder(column: $table.state, builder: (column) => column);

  GeneratedColumn<int> get changedAt =>
      $composableBuilder(column: $table.changedAt, builder: (column) => column);
}

class $$DeliveryStatesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DeliveryStatesTable,
          DeliveryStateRow,
          $$DeliveryStatesTableFilterComposer,
          $$DeliveryStatesTableOrderingComposer,
          $$DeliveryStatesTableAnnotationComposer,
          $$DeliveryStatesTableCreateCompanionBuilder,
          $$DeliveryStatesTableUpdateCompanionBuilder,
          (
            DeliveryStateRow,
            BaseReferences<
              _$AppDatabase,
              $DeliveryStatesTable,
              DeliveryStateRow
            >,
          ),
          DeliveryStateRow,
          PrefetchHooks Function()
        > {
  $$DeliveryStatesTableTableManager(
    _$AppDatabase db,
    $DeliveryStatesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeliveryStatesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeliveryStatesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeliveryStatesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> messageId = const Value.absent(),
                Value<String> state = const Value.absent(),
                Value<int> changedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeliveryStatesCompanion(
                messageId: messageId,
                state: state,
                changedAt: changedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String messageId,
                required String state,
                required int changedAt,
                Value<int> rowid = const Value.absent(),
              }) => DeliveryStatesCompanion.insert(
                messageId: messageId,
                state: state,
                changedAt: changedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeliveryStatesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DeliveryStatesTable,
      DeliveryStateRow,
      $$DeliveryStatesTableFilterComposer,
      $$DeliveryStatesTableOrderingComposer,
      $$DeliveryStatesTableAnnotationComposer,
      $$DeliveryStatesTableCreateCompanionBuilder,
      $$DeliveryStatesTableUpdateCompanionBuilder,
      (
        DeliveryStateRow,
        BaseReferences<_$AppDatabase, $DeliveryStatesTable, DeliveryStateRow>,
      ),
      DeliveryStateRow,
      PrefetchHooks Function()
    >;

class $AppDatabaseManager {
  final _$AppDatabase _db;
  $AppDatabaseManager(this._db);
  $$DeviceIdentitiesTableTableManager get deviceIdentities =>
      $$DeviceIdentitiesTableTableManager(_db, _db.deviceIdentities);
  $$RelationshipsTableTableManager get relationships =>
      $$RelationshipsTableTableManager(_db, _db.relationships);
  $$SignalIdentityTableTableManager get signalIdentity =>
      $$SignalIdentityTableTableManager(_db, _db.signalIdentity);
  $$SignalSignedPrekeysTableTableManager get signalSignedPrekeys =>
      $$SignalSignedPrekeysTableTableManager(_db, _db.signalSignedPrekeys);
  $$SignalOneTimePrekeysTableTableManager get signalOneTimePrekeys =>
      $$SignalOneTimePrekeysTableTableManager(_db, _db.signalOneTimePrekeys);
  $$SignalSessionsTableTableManager get signalSessions =>
      $$SignalSessionsTableTableManager(_db, _db.signalSessions);
  $$SignalTrustedIdentitiesTableTableManager get signalTrustedIdentities =>
      $$SignalTrustedIdentitiesTableTableManager(
        _db,
        _db.signalTrustedIdentities,
      );
  $$CryptoCountersTableTableManager get cryptoCounters =>
      $$CryptoCountersTableTableManager(_db, _db.cryptoCounters);
  $$RoutesTableTableManager get routes =>
      $$RoutesTableTableManager(_db, _db.routes);
  $$RelayPacketsTableTableManager get relayPackets =>
      $$RelayPacketsTableTableManager(_db, _db.relayPackets);
  $$MessagesTableTableManager get messages =>
      $$MessagesTableTableManager(_db, _db.messages);
  $$DeliveryStatesTableTableManager get deliveryStates =>
      $$DeliveryStatesTableTableManager(_db, _db.deliveryStates);
}
