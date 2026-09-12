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
  static const VerificationMeta _remoteSelfDeviceIdMeta =
      const VerificationMeta('remoteSelfDeviceId');
  @override
  late final GeneratedColumn<String> remoteSelfDeviceId =
      GeneratedColumn<String>(
        'remote_self_device_id',
        aliasedName,
        true,
        type: DriftSqlType.string,
        requiredDuringInsert: false,
      );
  static const VerificationMeta _peerNameMeta = const VerificationMeta(
    'peerName',
  );
  @override
  late final GeneratedColumn<String> peerName = GeneratedColumn<String>(
    'peer_name',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    deviceId,
    state,
    updatedAt,
    remoteSelfDeviceId,
    peerName,
  ];
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
    if (data.containsKey('remote_self_device_id')) {
      context.handle(
        _remoteSelfDeviceIdMeta,
        remoteSelfDeviceId.isAcceptableOrUnknown(
          data['remote_self_device_id']!,
          _remoteSelfDeviceIdMeta,
        ),
      );
    }
    if (data.containsKey('peer_name')) {
      context.handle(
        _peerNameMeta,
        peerName.isAcceptableOrUnknown(data['peer_name']!, _peerNameMeta),
      );
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
      remoteSelfDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_self_device_id'],
      ),
      peerName: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_name'],
      ),
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

  /// E04-B12 (Option A, part 1/2 — see `identity_announce.dart`): the
  /// peer's own real `selfDeviceId`, learned once via the identity-announce
  /// control protocol and stored keyed by [deviceId] above, which stays
  /// exactly what it always was — the Bluetooth-address transport id this
  /// relationship row was first created under. This column does NOT
  /// replace [deviceId] as the row's key (task file §2a's scope-refinement
  /// note: zero re-keying of existing relationship rows, zero Devices-
  /// screen/UI change). `null` until a peer has announced at least once;
  /// additive migration (schema v20 -> v21), no backfill for existing rows
  /// (they simply have not announced yet).
  final String? remoteSelfDeviceId;

  /// E04-B17: the peer's Bluetooth-visible name at the time this
  /// relationship was created or last reconciled — the only correlator
  /// available to recognize "this is the same already-trusted peer,
  /// reconnecting under a different address" when [deviceId] itself has
  /// gone stale (confirmed live: an OS/OEM Bluetooth stack can present a
  /// DIFFERENT real, currently-bonded address than whatever address a
  /// relationship was originally keyed under, e.g. from an earlier
  /// discovery scan — same root cause class `E04-B08`'s own
  /// `resolveDeviceId` already fixed for the discovery path, found here to
  /// also silently break inbound delivery on the accept path with no
  /// mechanism to ever recover). `null` for a relationship created before
  /// this column existed, or one whose peer has never been seen with a
  /// resolvable name — reconciliation simply cannot run for those, the
  /// same "additive, no backfill" shape `remoteSelfDeviceId` above already
  /// established. Never used for trust decisions itself (a name is not an
  /// authentication factor) — only to locate the CANDIDATE existing
  /// relationship whose already-evaluated trust state should carry over to
  /// a newly-seen address for the same peer; see
  /// `InboundPipeline._reconcileStaleRelationship` for where this is read.
  final String? peerName;
  const RelationshipRow({
    required this.deviceId,
    required this.state,
    required this.updatedAt,
    this.remoteSelfDeviceId,
    this.peerName,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['device_id'] = Variable<String>(deviceId);
    map['state'] = Variable<String>(state);
    map['updated_at'] = Variable<DateTime>(updatedAt);
    if (!nullToAbsent || remoteSelfDeviceId != null) {
      map['remote_self_device_id'] = Variable<String>(remoteSelfDeviceId);
    }
    if (!nullToAbsent || peerName != null) {
      map['peer_name'] = Variable<String>(peerName);
    }
    return map;
  }

  RelationshipsCompanion toCompanion(bool nullToAbsent) {
    return RelationshipsCompanion(
      deviceId: Value(deviceId),
      state: Value(state),
      updatedAt: Value(updatedAt),
      remoteSelfDeviceId: remoteSelfDeviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(remoteSelfDeviceId),
      peerName: peerName == null && nullToAbsent
          ? const Value.absent()
          : Value(peerName),
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
      remoteSelfDeviceId: serializer.fromJson<String?>(
        json['remoteSelfDeviceId'],
      ),
      peerName: serializer.fromJson<String?>(json['peerName']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deviceId': serializer.toJson<String>(deviceId),
      'state': serializer.toJson<String>(state),
      'updatedAt': serializer.toJson<DateTime>(updatedAt),
      'remoteSelfDeviceId': serializer.toJson<String?>(remoteSelfDeviceId),
      'peerName': serializer.toJson<String?>(peerName),
    };
  }

  RelationshipRow copyWith({
    String? deviceId,
    String? state,
    DateTime? updatedAt,
    Value<String?> remoteSelfDeviceId = const Value.absent(),
    Value<String?> peerName = const Value.absent(),
  }) => RelationshipRow(
    deviceId: deviceId ?? this.deviceId,
    state: state ?? this.state,
    updatedAt: updatedAt ?? this.updatedAt,
    remoteSelfDeviceId: remoteSelfDeviceId.present
        ? remoteSelfDeviceId.value
        : this.remoteSelfDeviceId,
    peerName: peerName.present ? peerName.value : this.peerName,
  );
  RelationshipRow copyWithCompanion(RelationshipsCompanion data) {
    return RelationshipRow(
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      state: data.state.present ? data.state.value : this.state,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
      remoteSelfDeviceId: data.remoteSelfDeviceId.present
          ? data.remoteSelfDeviceId.value
          : this.remoteSelfDeviceId,
      peerName: data.peerName.present ? data.peerName.value : this.peerName,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RelationshipRow(')
          ..write('deviceId: $deviceId, ')
          ..write('state: $state, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('remoteSelfDeviceId: $remoteSelfDeviceId, ')
          ..write('peerName: $peerName')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(deviceId, state, updatedAt, remoteSelfDeviceId, peerName);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RelationshipRow &&
          other.deviceId == this.deviceId &&
          other.state == this.state &&
          other.updatedAt == this.updatedAt &&
          other.remoteSelfDeviceId == this.remoteSelfDeviceId &&
          other.peerName == this.peerName);
}

class RelationshipsCompanion extends UpdateCompanion<RelationshipRow> {
  final Value<String> deviceId;
  final Value<String> state;
  final Value<DateTime> updatedAt;
  final Value<String?> remoteSelfDeviceId;
  final Value<String?> peerName;
  final Value<int> rowid;
  const RelationshipsCompanion({
    this.deviceId = const Value.absent(),
    this.state = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.remoteSelfDeviceId = const Value.absent(),
    this.peerName = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RelationshipsCompanion.insert({
    required String deviceId,
    required String state,
    required DateTime updatedAt,
    this.remoteSelfDeviceId = const Value.absent(),
    this.peerName = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : deviceId = Value(deviceId),
       state = Value(state),
       updatedAt = Value(updatedAt);
  static Insertable<RelationshipRow> custom({
    Expression<String>? deviceId,
    Expression<String>? state,
    Expression<DateTime>? updatedAt,
    Expression<String>? remoteSelfDeviceId,
    Expression<String>? peerName,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deviceId != null) 'device_id': deviceId,
      if (state != null) 'state': state,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (remoteSelfDeviceId != null)
        'remote_self_device_id': remoteSelfDeviceId,
      if (peerName != null) 'peer_name': peerName,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RelationshipsCompanion copyWith({
    Value<String>? deviceId,
    Value<String>? state,
    Value<DateTime>? updatedAt,
    Value<String?>? remoteSelfDeviceId,
    Value<String?>? peerName,
    Value<int>? rowid,
  }) {
    return RelationshipsCompanion(
      deviceId: deviceId ?? this.deviceId,
      state: state ?? this.state,
      updatedAt: updatedAt ?? this.updatedAt,
      remoteSelfDeviceId: remoteSelfDeviceId ?? this.remoteSelfDeviceId,
      peerName: peerName ?? this.peerName,
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
    if (remoteSelfDeviceId.present) {
      map['remote_self_device_id'] = Variable<String>(remoteSelfDeviceId.value);
    }
    if (peerName.present) {
      map['peer_name'] = Variable<String>(peerName.value);
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
          ..write('remoteSelfDeviceId: $remoteSelfDeviceId, ')
          ..write('peerName: $peerName, ')
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

class $SyncCursorsTable extends SyncCursors
    with TableInfo<$SyncCursorsTable, SyncCursorRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $SyncCursorsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _localDeviceIdMeta = const VerificationMeta(
    'localDeviceId',
  );
  @override
  late final GeneratedColumn<String> localDeviceId = GeneratedColumn<String>(
    'local_device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _remoteDeviceIdMeta = const VerificationMeta(
    'remoteDeviceId',
  );
  @override
  late final GeneratedColumn<String> remoteDeviceId = GeneratedColumn<String>(
    'remote_device_id',
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
  static const VerificationMeta _lastConfirmedSequenceNumberMeta =
      const VerificationMeta('lastConfirmedSequenceNumber');
  @override
  late final GeneratedColumn<int> lastConfirmedSequenceNumber =
      GeneratedColumn<int>(
        'last_confirmed_sequence_number',
        aliasedName,
        false,
        type: DriftSqlType.int,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    localDeviceId,
    remoteDeviceId,
    conversationId,
    lastConfirmedSequenceNumber,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'sync_cursors';
  @override
  VerificationContext validateIntegrity(
    Insertable<SyncCursorRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('local_device_id')) {
      context.handle(
        _localDeviceIdMeta,
        localDeviceId.isAcceptableOrUnknown(
          data['local_device_id']!,
          _localDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_localDeviceIdMeta);
    }
    if (data.containsKey('remote_device_id')) {
      context.handle(
        _remoteDeviceIdMeta,
        remoteDeviceId.isAcceptableOrUnknown(
          data['remote_device_id']!,
          _remoteDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_remoteDeviceIdMeta);
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
    if (data.containsKey('last_confirmed_sequence_number')) {
      context.handle(
        _lastConfirmedSequenceNumberMeta,
        lastConfirmedSequenceNumber.isAcceptableOrUnknown(
          data['last_confirmed_sequence_number']!,
          _lastConfirmedSequenceNumberMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_lastConfirmedSequenceNumberMeta);
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
  Set<GeneratedColumn> get $primaryKey => {
    localDeviceId,
    remoteDeviceId,
    conversationId,
  };
  @override
  SyncCursorRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return SyncCursorRow(
      localDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}local_device_id'],
      )!,
      remoteDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}remote_device_id'],
      )!,
      conversationId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}conversation_id'],
      )!,
      lastConfirmedSequenceNumber: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_confirmed_sequence_number'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $SyncCursorsTable createAlias(String alias) {
    return $SyncCursorsTable(attachedDatabase, alias);
  }
}

class SyncCursorRow extends DataClass implements Insertable<SyncCursorRow> {
  /// This device's own device id (the "local" side of the pair).
  final String localDeviceId;

  /// The other device (of this user's own devices, per epic.md's
  /// mesh-to-mesh multi-device sync) this cursor tracks progress against.
  final String remoteDeviceId;
  final String conversationId;

  /// Highest `messages.sequence_number` confirmed seen from
  /// `remoteDeviceId` for this conversation. Monotonic -- never written
  /// backward (see `SyncCursorService.recordLocalProgress`).
  final int lastConfirmedSequenceNumber;

  /// Epoch-ms wall-clock time of the last update to this row.
  final int updatedAt;
  const SyncCursorRow({
    required this.localDeviceId,
    required this.remoteDeviceId,
    required this.conversationId,
    required this.lastConfirmedSequenceNumber,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['local_device_id'] = Variable<String>(localDeviceId);
    map['remote_device_id'] = Variable<String>(remoteDeviceId);
    map['conversation_id'] = Variable<String>(conversationId);
    map['last_confirmed_sequence_number'] = Variable<int>(
      lastConfirmedSequenceNumber,
    );
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  SyncCursorsCompanion toCompanion(bool nullToAbsent) {
    return SyncCursorsCompanion(
      localDeviceId: Value(localDeviceId),
      remoteDeviceId: Value(remoteDeviceId),
      conversationId: Value(conversationId),
      lastConfirmedSequenceNumber: Value(lastConfirmedSequenceNumber),
      updatedAt: Value(updatedAt),
    );
  }

  factory SyncCursorRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return SyncCursorRow(
      localDeviceId: serializer.fromJson<String>(json['localDeviceId']),
      remoteDeviceId: serializer.fromJson<String>(json['remoteDeviceId']),
      conversationId: serializer.fromJson<String>(json['conversationId']),
      lastConfirmedSequenceNumber: serializer.fromJson<int>(
        json['lastConfirmedSequenceNumber'],
      ),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'localDeviceId': serializer.toJson<String>(localDeviceId),
      'remoteDeviceId': serializer.toJson<String>(remoteDeviceId),
      'conversationId': serializer.toJson<String>(conversationId),
      'lastConfirmedSequenceNumber': serializer.toJson<int>(
        lastConfirmedSequenceNumber,
      ),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  SyncCursorRow copyWith({
    String? localDeviceId,
    String? remoteDeviceId,
    String? conversationId,
    int? lastConfirmedSequenceNumber,
    int? updatedAt,
  }) => SyncCursorRow(
    localDeviceId: localDeviceId ?? this.localDeviceId,
    remoteDeviceId: remoteDeviceId ?? this.remoteDeviceId,
    conversationId: conversationId ?? this.conversationId,
    lastConfirmedSequenceNumber:
        lastConfirmedSequenceNumber ?? this.lastConfirmedSequenceNumber,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  SyncCursorRow copyWithCompanion(SyncCursorsCompanion data) {
    return SyncCursorRow(
      localDeviceId: data.localDeviceId.present
          ? data.localDeviceId.value
          : this.localDeviceId,
      remoteDeviceId: data.remoteDeviceId.present
          ? data.remoteDeviceId.value
          : this.remoteDeviceId,
      conversationId: data.conversationId.present
          ? data.conversationId.value
          : this.conversationId,
      lastConfirmedSequenceNumber: data.lastConfirmedSequenceNumber.present
          ? data.lastConfirmedSequenceNumber.value
          : this.lastConfirmedSequenceNumber,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorRow(')
          ..write('localDeviceId: $localDeviceId, ')
          ..write('remoteDeviceId: $remoteDeviceId, ')
          ..write('conversationId: $conversationId, ')
          ..write('lastConfirmedSequenceNumber: $lastConfirmedSequenceNumber, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    localDeviceId,
    remoteDeviceId,
    conversationId,
    lastConfirmedSequenceNumber,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is SyncCursorRow &&
          other.localDeviceId == this.localDeviceId &&
          other.remoteDeviceId == this.remoteDeviceId &&
          other.conversationId == this.conversationId &&
          other.lastConfirmedSequenceNumber ==
              this.lastConfirmedSequenceNumber &&
          other.updatedAt == this.updatedAt);
}

class SyncCursorsCompanion extends UpdateCompanion<SyncCursorRow> {
  final Value<String> localDeviceId;
  final Value<String> remoteDeviceId;
  final Value<String> conversationId;
  final Value<int> lastConfirmedSequenceNumber;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const SyncCursorsCompanion({
    this.localDeviceId = const Value.absent(),
    this.remoteDeviceId = const Value.absent(),
    this.conversationId = const Value.absent(),
    this.lastConfirmedSequenceNumber = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  SyncCursorsCompanion.insert({
    required String localDeviceId,
    required String remoteDeviceId,
    required String conversationId,
    required int lastConfirmedSequenceNumber,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : localDeviceId = Value(localDeviceId),
       remoteDeviceId = Value(remoteDeviceId),
       conversationId = Value(conversationId),
       lastConfirmedSequenceNumber = Value(lastConfirmedSequenceNumber),
       updatedAt = Value(updatedAt);
  static Insertable<SyncCursorRow> custom({
    Expression<String>? localDeviceId,
    Expression<String>? remoteDeviceId,
    Expression<String>? conversationId,
    Expression<int>? lastConfirmedSequenceNumber,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (localDeviceId != null) 'local_device_id': localDeviceId,
      if (remoteDeviceId != null) 'remote_device_id': remoteDeviceId,
      if (conversationId != null) 'conversation_id': conversationId,
      if (lastConfirmedSequenceNumber != null)
        'last_confirmed_sequence_number': lastConfirmedSequenceNumber,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  SyncCursorsCompanion copyWith({
    Value<String>? localDeviceId,
    Value<String>? remoteDeviceId,
    Value<String>? conversationId,
    Value<int>? lastConfirmedSequenceNumber,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return SyncCursorsCompanion(
      localDeviceId: localDeviceId ?? this.localDeviceId,
      remoteDeviceId: remoteDeviceId ?? this.remoteDeviceId,
      conversationId: conversationId ?? this.conversationId,
      lastConfirmedSequenceNumber:
          lastConfirmedSequenceNumber ?? this.lastConfirmedSequenceNumber,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (localDeviceId.present) {
      map['local_device_id'] = Variable<String>(localDeviceId.value);
    }
    if (remoteDeviceId.present) {
      map['remote_device_id'] = Variable<String>(remoteDeviceId.value);
    }
    if (conversationId.present) {
      map['conversation_id'] = Variable<String>(conversationId.value);
    }
    if (lastConfirmedSequenceNumber.present) {
      map['last_confirmed_sequence_number'] = Variable<int>(
        lastConfirmedSequenceNumber.value,
      );
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('SyncCursorsCompanion(')
          ..write('localDeviceId: $localDeviceId, ')
          ..write('remoteDeviceId: $remoteDeviceId, ')
          ..write('conversationId: $conversationId, ')
          ..write('lastConfirmedSequenceNumber: $lastConfirmedSequenceNumber, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GroupsTable extends Groups with TableInfo<$GroupsTable, GroupRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
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
  static const VerificationMeta _createdByDeviceIdMeta = const VerificationMeta(
    'createdByDeviceId',
  );
  @override
  late final GeneratedColumn<String> createdByDeviceId =
      GeneratedColumn<String>(
        'created_by_device_id',
        aliasedName,
        false,
        type: DriftSqlType.string,
        requiredDuringInsert: true,
      );
  static const VerificationMeta _membershipEpochMeta = const VerificationMeta(
    'membershipEpoch',
  );
  @override
  late final GeneratedColumn<int> membershipEpoch = GeneratedColumn<int>(
    'membership_epoch',
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    name,
    createdAt,
    createdByDeviceId,
    membershipEpoch,
    isDeleted,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'groups';
  @override
  VerificationContext validateIntegrity(
    Insertable<GroupRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('name')) {
      context.handle(
        _nameMeta,
        name.isAcceptableOrUnknown(data['name']!, _nameMeta),
      );
    } else if (isInserting) {
      context.missing(_nameMeta);
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    if (data.containsKey('created_by_device_id')) {
      context.handle(
        _createdByDeviceIdMeta,
        createdByDeviceId.isAcceptableOrUnknown(
          data['created_by_device_id']!,
          _createdByDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_createdByDeviceIdMeta);
    }
    if (data.containsKey('membership_epoch')) {
      context.handle(
        _membershipEpochMeta,
        membershipEpoch.isAcceptableOrUnknown(
          data['membership_epoch']!,
          _membershipEpochMeta,
        ),
      );
    }
    if (data.containsKey('is_deleted')) {
      context.handle(
        _isDeletedMeta,
        isDeleted.isAcceptableOrUnknown(data['is_deleted']!, _isDeletedMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GroupRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GroupRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      name: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}name'],
      )!,
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
      createdByDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}created_by_device_id'],
      )!,
      membershipEpoch: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}membership_epoch'],
      )!,
      isDeleted: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}is_deleted'],
      )!,
    );
  }

  @override
  $GroupsTable createAlias(String alias) {
    return $GroupsTable(attachedDatabase, alias);
  }
}

class GroupRow extends DataClass implements Insertable<GroupRow> {
  final String id;
  final String name;

  /// Epoch-ms wall-clock creation time.
  final int createdAt;
  final String createdByDeviceId;
  final int membershipEpoch;
  final bool isDeleted;
  const GroupRow({
    required this.id,
    required this.name,
    required this.createdAt,
    required this.createdByDeviceId,
    required this.membershipEpoch,
    required this.isDeleted,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['name'] = Variable<String>(name);
    map['created_at'] = Variable<int>(createdAt);
    map['created_by_device_id'] = Variable<String>(createdByDeviceId);
    map['membership_epoch'] = Variable<int>(membershipEpoch);
    map['is_deleted'] = Variable<bool>(isDeleted);
    return map;
  }

  GroupsCompanion toCompanion(bool nullToAbsent) {
    return GroupsCompanion(
      id: Value(id),
      name: Value(name),
      createdAt: Value(createdAt),
      createdByDeviceId: Value(createdByDeviceId),
      membershipEpoch: Value(membershipEpoch),
      isDeleted: Value(isDeleted),
    );
  }

  factory GroupRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GroupRow(
      id: serializer.fromJson<String>(json['id']),
      name: serializer.fromJson<String>(json['name']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
      createdByDeviceId: serializer.fromJson<String>(json['createdByDeviceId']),
      membershipEpoch: serializer.fromJson<int>(json['membershipEpoch']),
      isDeleted: serializer.fromJson<bool>(json['isDeleted']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'name': serializer.toJson<String>(name),
      'createdAt': serializer.toJson<int>(createdAt),
      'createdByDeviceId': serializer.toJson<String>(createdByDeviceId),
      'membershipEpoch': serializer.toJson<int>(membershipEpoch),
      'isDeleted': serializer.toJson<bool>(isDeleted),
    };
  }

  GroupRow copyWith({
    String? id,
    String? name,
    int? createdAt,
    String? createdByDeviceId,
    int? membershipEpoch,
    bool? isDeleted,
  }) => GroupRow(
    id: id ?? this.id,
    name: name ?? this.name,
    createdAt: createdAt ?? this.createdAt,
    createdByDeviceId: createdByDeviceId ?? this.createdByDeviceId,
    membershipEpoch: membershipEpoch ?? this.membershipEpoch,
    isDeleted: isDeleted ?? this.isDeleted,
  );
  GroupRow copyWithCompanion(GroupsCompanion data) {
    return GroupRow(
      id: data.id.present ? data.id.value : this.id,
      name: data.name.present ? data.name.value : this.name,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
      createdByDeviceId: data.createdByDeviceId.present
          ? data.createdByDeviceId.value
          : this.createdByDeviceId,
      membershipEpoch: data.membershipEpoch.present
          ? data.membershipEpoch.value
          : this.membershipEpoch,
      isDeleted: data.isDeleted.present ? data.isDeleted.value : this.isDeleted,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GroupRow(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('createdByDeviceId: $createdByDeviceId, ')
          ..write('membershipEpoch: $membershipEpoch, ')
          ..write('isDeleted: $isDeleted')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    name,
    createdAt,
    createdByDeviceId,
    membershipEpoch,
    isDeleted,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GroupRow &&
          other.id == this.id &&
          other.name == this.name &&
          other.createdAt == this.createdAt &&
          other.createdByDeviceId == this.createdByDeviceId &&
          other.membershipEpoch == this.membershipEpoch &&
          other.isDeleted == this.isDeleted);
}

class GroupsCompanion extends UpdateCompanion<GroupRow> {
  final Value<String> id;
  final Value<String> name;
  final Value<int> createdAt;
  final Value<String> createdByDeviceId;
  final Value<int> membershipEpoch;
  final Value<bool> isDeleted;
  final Value<int> rowid;
  const GroupsCompanion({
    this.id = const Value.absent(),
    this.name = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.createdByDeviceId = const Value.absent(),
    this.membershipEpoch = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GroupsCompanion.insert({
    required String id,
    required String name,
    required int createdAt,
    required String createdByDeviceId,
    this.membershipEpoch = const Value.absent(),
    this.isDeleted = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       name = Value(name),
       createdAt = Value(createdAt),
       createdByDeviceId = Value(createdByDeviceId);
  static Insertable<GroupRow> custom({
    Expression<String>? id,
    Expression<String>? name,
    Expression<int>? createdAt,
    Expression<String>? createdByDeviceId,
    Expression<int>? membershipEpoch,
    Expression<bool>? isDeleted,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (name != null) 'name': name,
      if (createdAt != null) 'created_at': createdAt,
      if (createdByDeviceId != null) 'created_by_device_id': createdByDeviceId,
      if (membershipEpoch != null) 'membership_epoch': membershipEpoch,
      if (isDeleted != null) 'is_deleted': isDeleted,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GroupsCompanion copyWith({
    Value<String>? id,
    Value<String>? name,
    Value<int>? createdAt,
    Value<String>? createdByDeviceId,
    Value<int>? membershipEpoch,
    Value<bool>? isDeleted,
    Value<int>? rowid,
  }) {
    return GroupsCompanion(
      id: id ?? this.id,
      name: name ?? this.name,
      createdAt: createdAt ?? this.createdAt,
      createdByDeviceId: createdByDeviceId ?? this.createdByDeviceId,
      membershipEpoch: membershipEpoch ?? this.membershipEpoch,
      isDeleted: isDeleted ?? this.isDeleted,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (name.present) {
      map['name'] = Variable<String>(name.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (createdByDeviceId.present) {
      map['created_by_device_id'] = Variable<String>(createdByDeviceId.value);
    }
    if (membershipEpoch.present) {
      map['membership_epoch'] = Variable<int>(membershipEpoch.value);
    }
    if (isDeleted.present) {
      map['is_deleted'] = Variable<bool>(isDeleted.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupsCompanion(')
          ..write('id: $id, ')
          ..write('name: $name, ')
          ..write('createdAt: $createdAt, ')
          ..write('createdByDeviceId: $createdByDeviceId, ')
          ..write('membershipEpoch: $membershipEpoch, ')
          ..write('isDeleted: $isDeleted, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GroupMembersTable extends GroupMembers
    with TableInfo<$GroupMembersTable, GroupMemberRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupMembersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
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
  static const VerificationMeta _roleMeta = const VerificationMeta('role');
  @override
  late final GeneratedColumn<String> role = GeneratedColumn<String>(
    'role',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _joinedAtEpochMeta = const VerificationMeta(
    'joinedAtEpoch',
  );
  @override
  late final GeneratedColumn<int> joinedAtEpoch = GeneratedColumn<int>(
    'joined_at_epoch',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _removedAtEpochMeta = const VerificationMeta(
    'removedAtEpoch',
  );
  @override
  late final GeneratedColumn<int> removedAtEpoch = GeneratedColumn<int>(
    'removed_at_epoch',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  @override
  List<GeneratedColumn> get $columns => [
    groupId,
    deviceId,
    role,
    joinedAtEpoch,
    removedAtEpoch,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'group_members';
  @override
  VerificationContext validateIntegrity(
    Insertable<GroupMemberRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('device_id')) {
      context.handle(
        _deviceIdMeta,
        deviceId.isAcceptableOrUnknown(data['device_id']!, _deviceIdMeta),
      );
    } else if (isInserting) {
      context.missing(_deviceIdMeta);
    }
    if (data.containsKey('role')) {
      context.handle(
        _roleMeta,
        role.isAcceptableOrUnknown(data['role']!, _roleMeta),
      );
    } else if (isInserting) {
      context.missing(_roleMeta);
    }
    if (data.containsKey('joined_at_epoch')) {
      context.handle(
        _joinedAtEpochMeta,
        joinedAtEpoch.isAcceptableOrUnknown(
          data['joined_at_epoch']!,
          _joinedAtEpochMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_joinedAtEpochMeta);
    }
    if (data.containsKey('removed_at_epoch')) {
      context.handle(
        _removedAtEpochMeta,
        removedAtEpoch.isAcceptableOrUnknown(
          data['removed_at_epoch']!,
          _removedAtEpochMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {groupId, deviceId};
  @override
  GroupMemberRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GroupMemberRow(
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      role: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}role'],
      )!,
      joinedAtEpoch: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}joined_at_epoch'],
      )!,
      removedAtEpoch: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}removed_at_epoch'],
      ),
    );
  }

  @override
  $GroupMembersTable createAlias(String alias) {
    return $GroupMembersTable(attachedDatabase, alias);
  }
}

class GroupMemberRow extends DataClass implements Insertable<GroupMemberRow> {
  final String groupId;
  final String deviceId;

  /// A [GroupRole] value's `.name`, never an integer index.
  final String role;

  /// The `groups.membership_epoch` value in effect when this member joined
  /// (§2) — the floor below which this member is never handed a sender-key
  /// record (FR-GROUP-006).
  final int joinedAtEpoch;

  /// NULL = current member. Set (never cleared) once a member is removed —
  /// the row itself is never deleted (§2).
  final int? removedAtEpoch;
  const GroupMemberRow({
    required this.groupId,
    required this.deviceId,
    required this.role,
    required this.joinedAtEpoch,
    this.removedAtEpoch,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['group_id'] = Variable<String>(groupId);
    map['device_id'] = Variable<String>(deviceId);
    map['role'] = Variable<String>(role);
    map['joined_at_epoch'] = Variable<int>(joinedAtEpoch);
    if (!nullToAbsent || removedAtEpoch != null) {
      map['removed_at_epoch'] = Variable<int>(removedAtEpoch);
    }
    return map;
  }

  GroupMembersCompanion toCompanion(bool nullToAbsent) {
    return GroupMembersCompanion(
      groupId: Value(groupId),
      deviceId: Value(deviceId),
      role: Value(role),
      joinedAtEpoch: Value(joinedAtEpoch),
      removedAtEpoch: removedAtEpoch == null && nullToAbsent
          ? const Value.absent()
          : Value(removedAtEpoch),
    );
  }

  factory GroupMemberRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GroupMemberRow(
      groupId: serializer.fromJson<String>(json['groupId']),
      deviceId: serializer.fromJson<String>(json['deviceId']),
      role: serializer.fromJson<String>(json['role']),
      joinedAtEpoch: serializer.fromJson<int>(json['joinedAtEpoch']),
      removedAtEpoch: serializer.fromJson<int?>(json['removedAtEpoch']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<String>(groupId),
      'deviceId': serializer.toJson<String>(deviceId),
      'role': serializer.toJson<String>(role),
      'joinedAtEpoch': serializer.toJson<int>(joinedAtEpoch),
      'removedAtEpoch': serializer.toJson<int?>(removedAtEpoch),
    };
  }

  GroupMemberRow copyWith({
    String? groupId,
    String? deviceId,
    String? role,
    int? joinedAtEpoch,
    Value<int?> removedAtEpoch = const Value.absent(),
  }) => GroupMemberRow(
    groupId: groupId ?? this.groupId,
    deviceId: deviceId ?? this.deviceId,
    role: role ?? this.role,
    joinedAtEpoch: joinedAtEpoch ?? this.joinedAtEpoch,
    removedAtEpoch: removedAtEpoch.present
        ? removedAtEpoch.value
        : this.removedAtEpoch,
  );
  GroupMemberRow copyWithCompanion(GroupMembersCompanion data) {
    return GroupMemberRow(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      role: data.role.present ? data.role.value : this.role,
      joinedAtEpoch: data.joinedAtEpoch.present
          ? data.joinedAtEpoch.value
          : this.joinedAtEpoch,
      removedAtEpoch: data.removedAtEpoch.present
          ? data.removedAtEpoch.value
          : this.removedAtEpoch,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GroupMemberRow(')
          ..write('groupId: $groupId, ')
          ..write('deviceId: $deviceId, ')
          ..write('role: $role, ')
          ..write('joinedAtEpoch: $joinedAtEpoch, ')
          ..write('removedAtEpoch: $removedAtEpoch')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(groupId, deviceId, role, joinedAtEpoch, removedAtEpoch);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GroupMemberRow &&
          other.groupId == this.groupId &&
          other.deviceId == this.deviceId &&
          other.role == this.role &&
          other.joinedAtEpoch == this.joinedAtEpoch &&
          other.removedAtEpoch == this.removedAtEpoch);
}

class GroupMembersCompanion extends UpdateCompanion<GroupMemberRow> {
  final Value<String> groupId;
  final Value<String> deviceId;
  final Value<String> role;
  final Value<int> joinedAtEpoch;
  final Value<int?> removedAtEpoch;
  final Value<int> rowid;
  const GroupMembersCompanion({
    this.groupId = const Value.absent(),
    this.deviceId = const Value.absent(),
    this.role = const Value.absent(),
    this.joinedAtEpoch = const Value.absent(),
    this.removedAtEpoch = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GroupMembersCompanion.insert({
    required String groupId,
    required String deviceId,
    required String role,
    required int joinedAtEpoch,
    this.removedAtEpoch = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : groupId = Value(groupId),
       deviceId = Value(deviceId),
       role = Value(role),
       joinedAtEpoch = Value(joinedAtEpoch);
  static Insertable<GroupMemberRow> custom({
    Expression<String>? groupId,
    Expression<String>? deviceId,
    Expression<String>? role,
    Expression<int>? joinedAtEpoch,
    Expression<int>? removedAtEpoch,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'group_id': groupId,
      if (deviceId != null) 'device_id': deviceId,
      if (role != null) 'role': role,
      if (joinedAtEpoch != null) 'joined_at_epoch': joinedAtEpoch,
      if (removedAtEpoch != null) 'removed_at_epoch': removedAtEpoch,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GroupMembersCompanion copyWith({
    Value<String>? groupId,
    Value<String>? deviceId,
    Value<String>? role,
    Value<int>? joinedAtEpoch,
    Value<int?>? removedAtEpoch,
    Value<int>? rowid,
  }) {
    return GroupMembersCompanion(
      groupId: groupId ?? this.groupId,
      deviceId: deviceId ?? this.deviceId,
      role: role ?? this.role,
      joinedAtEpoch: joinedAtEpoch ?? this.joinedAtEpoch,
      removedAtEpoch: removedAtEpoch ?? this.removedAtEpoch,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (role.present) {
      map['role'] = Variable<String>(role.value);
    }
    if (joinedAtEpoch.present) {
      map['joined_at_epoch'] = Variable<int>(joinedAtEpoch.value);
    }
    if (removedAtEpoch.present) {
      map['removed_at_epoch'] = Variable<int>(removedAtEpoch.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupMembersCompanion(')
          ..write('groupId: $groupId, ')
          ..write('deviceId: $deviceId, ')
          ..write('role: $role, ')
          ..write('joinedAtEpoch: $joinedAtEpoch, ')
          ..write('removedAtEpoch: $removedAtEpoch, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GroupSenderKeysTable extends GroupSenderKeys
    with TableInfo<$GroupSenderKeysTable, GroupSenderKeyRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupSenderKeysTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
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
  static const VerificationMeta _membershipEpochMeta = const VerificationMeta(
    'membershipEpoch',
  );
  @override
  late final GeneratedColumn<int> membershipEpoch = GeneratedColumn<int>(
    'membership_epoch',
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
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    groupId,
    senderDeviceId,
    membershipEpoch,
    record,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'group_sender_keys';
  @override
  VerificationContext validateIntegrity(
    Insertable<GroupSenderKeyRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
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
    if (data.containsKey('membership_epoch')) {
      context.handle(
        _membershipEpochMeta,
        membershipEpoch.isAcceptableOrUnknown(
          data['membership_epoch']!,
          _membershipEpochMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_membershipEpochMeta);
    }
    if (data.containsKey('record')) {
      context.handle(
        _recordMeta,
        record.isAcceptableOrUnknown(data['record']!, _recordMeta),
      );
    } else if (isInserting) {
      context.missing(_recordMeta);
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
  Set<GeneratedColumn> get $primaryKey => {
    groupId,
    senderDeviceId,
    membershipEpoch,
  };
  @override
  GroupSenderKeyRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GroupSenderKeyRow(
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      senderDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}sender_device_id'],
      )!,
      membershipEpoch: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}membership_epoch'],
      )!,
      record: attachedDatabase.typeMapping.read(
        DriftSqlType.blob,
        data['${effectivePrefix}record'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $GroupSenderKeysTable createAlias(String alias) {
    return $GroupSenderKeysTable(attachedDatabase, alias);
  }
}

class GroupSenderKeyRow extends DataClass
    implements Insertable<GroupSenderKeyRow> {
  final String groupId;
  final String senderDeviceId;
  final int membershipEpoch;
  final Uint8List record;

  /// Epoch-ms wall-clock time this row was last written.
  final int updatedAt;
  const GroupSenderKeyRow({
    required this.groupId,
    required this.senderDeviceId,
    required this.membershipEpoch,
    required this.record,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['group_id'] = Variable<String>(groupId);
    map['sender_device_id'] = Variable<String>(senderDeviceId);
    map['membership_epoch'] = Variable<int>(membershipEpoch);
    map['record'] = Variable<Uint8List>(record);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  GroupSenderKeysCompanion toCompanion(bool nullToAbsent) {
    return GroupSenderKeysCompanion(
      groupId: Value(groupId),
      senderDeviceId: Value(senderDeviceId),
      membershipEpoch: Value(membershipEpoch),
      record: Value(record),
      updatedAt: Value(updatedAt),
    );
  }

  factory GroupSenderKeyRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GroupSenderKeyRow(
      groupId: serializer.fromJson<String>(json['groupId']),
      senderDeviceId: serializer.fromJson<String>(json['senderDeviceId']),
      membershipEpoch: serializer.fromJson<int>(json['membershipEpoch']),
      record: serializer.fromJson<Uint8List>(json['record']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'groupId': serializer.toJson<String>(groupId),
      'senderDeviceId': serializer.toJson<String>(senderDeviceId),
      'membershipEpoch': serializer.toJson<int>(membershipEpoch),
      'record': serializer.toJson<Uint8List>(record),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  GroupSenderKeyRow copyWith({
    String? groupId,
    String? senderDeviceId,
    int? membershipEpoch,
    Uint8List? record,
    int? updatedAt,
  }) => GroupSenderKeyRow(
    groupId: groupId ?? this.groupId,
    senderDeviceId: senderDeviceId ?? this.senderDeviceId,
    membershipEpoch: membershipEpoch ?? this.membershipEpoch,
    record: record ?? this.record,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  GroupSenderKeyRow copyWithCompanion(GroupSenderKeysCompanion data) {
    return GroupSenderKeyRow(
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      senderDeviceId: data.senderDeviceId.present
          ? data.senderDeviceId.value
          : this.senderDeviceId,
      membershipEpoch: data.membershipEpoch.present
          ? data.membershipEpoch.value
          : this.membershipEpoch,
      record: data.record.present ? data.record.value : this.record,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GroupSenderKeyRow(')
          ..write('groupId: $groupId, ')
          ..write('senderDeviceId: $senderDeviceId, ')
          ..write('membershipEpoch: $membershipEpoch, ')
          ..write('record: $record, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    groupId,
    senderDeviceId,
    membershipEpoch,
    $driftBlobEquality.hash(record),
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GroupSenderKeyRow &&
          other.groupId == this.groupId &&
          other.senderDeviceId == this.senderDeviceId &&
          other.membershipEpoch == this.membershipEpoch &&
          $driftBlobEquality.equals(other.record, this.record) &&
          other.updatedAt == this.updatedAt);
}

class GroupSenderKeysCompanion extends UpdateCompanion<GroupSenderKeyRow> {
  final Value<String> groupId;
  final Value<String> senderDeviceId;
  final Value<int> membershipEpoch;
  final Value<Uint8List> record;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const GroupSenderKeysCompanion({
    this.groupId = const Value.absent(),
    this.senderDeviceId = const Value.absent(),
    this.membershipEpoch = const Value.absent(),
    this.record = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GroupSenderKeysCompanion.insert({
    required String groupId,
    required String senderDeviceId,
    required int membershipEpoch,
    required Uint8List record,
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : groupId = Value(groupId),
       senderDeviceId = Value(senderDeviceId),
       membershipEpoch = Value(membershipEpoch),
       record = Value(record),
       updatedAt = Value(updatedAt);
  static Insertable<GroupSenderKeyRow> custom({
    Expression<String>? groupId,
    Expression<String>? senderDeviceId,
    Expression<int>? membershipEpoch,
    Expression<Uint8List>? record,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (groupId != null) 'group_id': groupId,
      if (senderDeviceId != null) 'sender_device_id': senderDeviceId,
      if (membershipEpoch != null) 'membership_epoch': membershipEpoch,
      if (record != null) 'record': record,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GroupSenderKeysCompanion copyWith({
    Value<String>? groupId,
    Value<String>? senderDeviceId,
    Value<int>? membershipEpoch,
    Value<Uint8List>? record,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return GroupSenderKeysCompanion(
      groupId: groupId ?? this.groupId,
      senderDeviceId: senderDeviceId ?? this.senderDeviceId,
      membershipEpoch: membershipEpoch ?? this.membershipEpoch,
      record: record ?? this.record,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (senderDeviceId.present) {
      map['sender_device_id'] = Variable<String>(senderDeviceId.value);
    }
    if (membershipEpoch.present) {
      map['membership_epoch'] = Variable<int>(membershipEpoch.value);
    }
    if (record.present) {
      map['record'] = Variable<Uint8List>(record.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupSenderKeysCompanion(')
          ..write('groupId: $groupId, ')
          ..write('senderDeviceId: $senderDeviceId, ')
          ..write('membershipEpoch: $membershipEpoch, ')
          ..write('record: $record, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $GroupEventsTable extends GroupEvents
    with TableInfo<$GroupEventsTable, GroupEventRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $GroupEventsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _groupIdMeta = const VerificationMeta(
    'groupId',
  );
  @override
  late final GeneratedColumn<String> groupId = GeneratedColumn<String>(
    'group_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _epochMeta = const VerificationMeta('epoch');
  @override
  late final GeneratedColumn<int> epoch = GeneratedColumn<int>(
    'epoch',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _kindMeta = const VerificationMeta('kind');
  @override
  late final GeneratedColumn<String> kind = GeneratedColumn<String>(
    'kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _actorDeviceIdMeta = const VerificationMeta(
    'actorDeviceId',
  );
  @override
  late final GeneratedColumn<String> actorDeviceId = GeneratedColumn<String>(
    'actor_device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _subjectDeviceIdMeta = const VerificationMeta(
    'subjectDeviceId',
  );
  @override
  late final GeneratedColumn<String> subjectDeviceId = GeneratedColumn<String>(
    'subject_device_id',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
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
  @override
  List<GeneratedColumn> get $columns => [
    id,
    groupId,
    epoch,
    kind,
    actorDeviceId,
    subjectDeviceId,
    createdAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'group_events';
  @override
  VerificationContext validateIntegrity(
    Insertable<GroupEventRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('group_id')) {
      context.handle(
        _groupIdMeta,
        groupId.isAcceptableOrUnknown(data['group_id']!, _groupIdMeta),
      );
    } else if (isInserting) {
      context.missing(_groupIdMeta);
    }
    if (data.containsKey('epoch')) {
      context.handle(
        _epochMeta,
        epoch.isAcceptableOrUnknown(data['epoch']!, _epochMeta),
      );
    } else if (isInserting) {
      context.missing(_epochMeta);
    }
    if (data.containsKey('kind')) {
      context.handle(
        _kindMeta,
        kind.isAcceptableOrUnknown(data['kind']!, _kindMeta),
      );
    } else if (isInserting) {
      context.missing(_kindMeta);
    }
    if (data.containsKey('actor_device_id')) {
      context.handle(
        _actorDeviceIdMeta,
        actorDeviceId.isAcceptableOrUnknown(
          data['actor_device_id']!,
          _actorDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_actorDeviceIdMeta);
    }
    if (data.containsKey('subject_device_id')) {
      context.handle(
        _subjectDeviceIdMeta,
        subjectDeviceId.isAcceptableOrUnknown(
          data['subject_device_id']!,
          _subjectDeviceIdMeta,
        ),
      );
    }
    if (data.containsKey('created_at')) {
      context.handle(
        _createdAtMeta,
        createdAt.isAcceptableOrUnknown(data['created_at']!, _createdAtMeta),
      );
    } else if (isInserting) {
      context.missing(_createdAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  GroupEventRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return GroupEventRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      groupId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}group_id'],
      )!,
      epoch: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}epoch'],
      )!,
      kind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}kind'],
      )!,
      actorDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}actor_device_id'],
      )!,
      subjectDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}subject_device_id'],
      ),
      createdAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}created_at'],
      )!,
    );
  }

  @override
  $GroupEventsTable createAlias(String alias) {
    return $GroupEventsTable(attachedDatabase, alias);
  }
}

class GroupEventRow extends DataClass implements Insertable<GroupEventRow> {
  final String id;
  final String groupId;

  /// The `groups.membership_epoch` in effect when this event was recorded.
  final int epoch;

  /// A [GroupEventKind] value's `.name`, never an integer index.
  final String kind;
  final String actorDeviceId;

  /// The member the event is about (e.g. who was added/removed), when the
  /// event kind has one. NULL for group-level events like `renamed`.
  final String? subjectDeviceId;

  /// Epoch-ms wall-clock creation time.
  final int createdAt;
  const GroupEventRow({
    required this.id,
    required this.groupId,
    required this.epoch,
    required this.kind,
    required this.actorDeviceId,
    this.subjectDeviceId,
    required this.createdAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['group_id'] = Variable<String>(groupId);
    map['epoch'] = Variable<int>(epoch);
    map['kind'] = Variable<String>(kind);
    map['actor_device_id'] = Variable<String>(actorDeviceId);
    if (!nullToAbsent || subjectDeviceId != null) {
      map['subject_device_id'] = Variable<String>(subjectDeviceId);
    }
    map['created_at'] = Variable<int>(createdAt);
    return map;
  }

  GroupEventsCompanion toCompanion(bool nullToAbsent) {
    return GroupEventsCompanion(
      id: Value(id),
      groupId: Value(groupId),
      epoch: Value(epoch),
      kind: Value(kind),
      actorDeviceId: Value(actorDeviceId),
      subjectDeviceId: subjectDeviceId == null && nullToAbsent
          ? const Value.absent()
          : Value(subjectDeviceId),
      createdAt: Value(createdAt),
    );
  }

  factory GroupEventRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return GroupEventRow(
      id: serializer.fromJson<String>(json['id']),
      groupId: serializer.fromJson<String>(json['groupId']),
      epoch: serializer.fromJson<int>(json['epoch']),
      kind: serializer.fromJson<String>(json['kind']),
      actorDeviceId: serializer.fromJson<String>(json['actorDeviceId']),
      subjectDeviceId: serializer.fromJson<String?>(json['subjectDeviceId']),
      createdAt: serializer.fromJson<int>(json['createdAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'groupId': serializer.toJson<String>(groupId),
      'epoch': serializer.toJson<int>(epoch),
      'kind': serializer.toJson<String>(kind),
      'actorDeviceId': serializer.toJson<String>(actorDeviceId),
      'subjectDeviceId': serializer.toJson<String?>(subjectDeviceId),
      'createdAt': serializer.toJson<int>(createdAt),
    };
  }

  GroupEventRow copyWith({
    String? id,
    String? groupId,
    int? epoch,
    String? kind,
    String? actorDeviceId,
    Value<String?> subjectDeviceId = const Value.absent(),
    int? createdAt,
  }) => GroupEventRow(
    id: id ?? this.id,
    groupId: groupId ?? this.groupId,
    epoch: epoch ?? this.epoch,
    kind: kind ?? this.kind,
    actorDeviceId: actorDeviceId ?? this.actorDeviceId,
    subjectDeviceId: subjectDeviceId.present
        ? subjectDeviceId.value
        : this.subjectDeviceId,
    createdAt: createdAt ?? this.createdAt,
  );
  GroupEventRow copyWithCompanion(GroupEventsCompanion data) {
    return GroupEventRow(
      id: data.id.present ? data.id.value : this.id,
      groupId: data.groupId.present ? data.groupId.value : this.groupId,
      epoch: data.epoch.present ? data.epoch.value : this.epoch,
      kind: data.kind.present ? data.kind.value : this.kind,
      actorDeviceId: data.actorDeviceId.present
          ? data.actorDeviceId.value
          : this.actorDeviceId,
      subjectDeviceId: data.subjectDeviceId.present
          ? data.subjectDeviceId.value
          : this.subjectDeviceId,
      createdAt: data.createdAt.present ? data.createdAt.value : this.createdAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('GroupEventRow(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('epoch: $epoch, ')
          ..write('kind: $kind, ')
          ..write('actorDeviceId: $actorDeviceId, ')
          ..write('subjectDeviceId: $subjectDeviceId, ')
          ..write('createdAt: $createdAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    groupId,
    epoch,
    kind,
    actorDeviceId,
    subjectDeviceId,
    createdAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is GroupEventRow &&
          other.id == this.id &&
          other.groupId == this.groupId &&
          other.epoch == this.epoch &&
          other.kind == this.kind &&
          other.actorDeviceId == this.actorDeviceId &&
          other.subjectDeviceId == this.subjectDeviceId &&
          other.createdAt == this.createdAt);
}

class GroupEventsCompanion extends UpdateCompanion<GroupEventRow> {
  final Value<String> id;
  final Value<String> groupId;
  final Value<int> epoch;
  final Value<String> kind;
  final Value<String> actorDeviceId;
  final Value<String?> subjectDeviceId;
  final Value<int> createdAt;
  final Value<int> rowid;
  const GroupEventsCompanion({
    this.id = const Value.absent(),
    this.groupId = const Value.absent(),
    this.epoch = const Value.absent(),
    this.kind = const Value.absent(),
    this.actorDeviceId = const Value.absent(),
    this.subjectDeviceId = const Value.absent(),
    this.createdAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  GroupEventsCompanion.insert({
    required String id,
    required String groupId,
    required int epoch,
    required String kind,
    required String actorDeviceId,
    this.subjectDeviceId = const Value.absent(),
    required int createdAt,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       groupId = Value(groupId),
       epoch = Value(epoch),
       kind = Value(kind),
       actorDeviceId = Value(actorDeviceId),
       createdAt = Value(createdAt);
  static Insertable<GroupEventRow> custom({
    Expression<String>? id,
    Expression<String>? groupId,
    Expression<int>? epoch,
    Expression<String>? kind,
    Expression<String>? actorDeviceId,
    Expression<String>? subjectDeviceId,
    Expression<int>? createdAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (groupId != null) 'group_id': groupId,
      if (epoch != null) 'epoch': epoch,
      if (kind != null) 'kind': kind,
      if (actorDeviceId != null) 'actor_device_id': actorDeviceId,
      if (subjectDeviceId != null) 'subject_device_id': subjectDeviceId,
      if (createdAt != null) 'created_at': createdAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  GroupEventsCompanion copyWith({
    Value<String>? id,
    Value<String>? groupId,
    Value<int>? epoch,
    Value<String>? kind,
    Value<String>? actorDeviceId,
    Value<String?>? subjectDeviceId,
    Value<int>? createdAt,
    Value<int>? rowid,
  }) {
    return GroupEventsCompanion(
      id: id ?? this.id,
      groupId: groupId ?? this.groupId,
      epoch: epoch ?? this.epoch,
      kind: kind ?? this.kind,
      actorDeviceId: actorDeviceId ?? this.actorDeviceId,
      subjectDeviceId: subjectDeviceId ?? this.subjectDeviceId,
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
    if (groupId.present) {
      map['group_id'] = Variable<String>(groupId.value);
    }
    if (epoch.present) {
      map['epoch'] = Variable<int>(epoch.value);
    }
    if (kind.present) {
      map['kind'] = Variable<String>(kind.value);
    }
    if (actorDeviceId.present) {
      map['actor_device_id'] = Variable<String>(actorDeviceId.value);
    }
    if (subjectDeviceId.present) {
      map['subject_device_id'] = Variable<String>(subjectDeviceId.value);
    }
    if (createdAt.present) {
      map['created_at'] = Variable<int>(createdAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('GroupEventsCompanion(')
          ..write('id: $id, ')
          ..write('groupId: $groupId, ')
          ..write('epoch: $epoch, ')
          ..write('kind: $kind, ')
          ..write('actorDeviceId: $actorDeviceId, ')
          ..write('subjectDeviceId: $subjectDeviceId, ')
          ..write('createdAt: $createdAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StorageItemStatsTable extends StorageItemStats
    with TableInfo<$StorageItemStatsTable, StorageItemStatRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StorageItemStatsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _itemKindMeta = const VerificationMeta(
    'itemKind',
  );
  @override
  late final GeneratedColumn<String> itemKind = GeneratedColumn<String>(
    'item_kind',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemIdMeta = const VerificationMeta('itemId');
  @override
  late final GeneratedColumn<String> itemId = GeneratedColumn<String>(
    'item_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _lastAccessedAtMeta = const VerificationMeta(
    'lastAccessedAt',
  );
  @override
  late final GeneratedColumn<int> lastAccessedAt = GeneratedColumn<int>(
    'last_accessed_at',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _accessCountMeta = const VerificationMeta(
    'accessCount',
  );
  @override
  late final GeneratedColumn<int> accessCount = GeneratedColumn<int>(
    'access_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
    defaultValue: const Constant(0),
  );
  @override
  List<GeneratedColumn> get $columns => [
    itemKind,
    itemId,
    lastAccessedAt,
    accessCount,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'storage_item_stats';
  @override
  VerificationContext validateIntegrity(
    Insertable<StorageItemStatRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('item_kind')) {
      context.handle(
        _itemKindMeta,
        itemKind.isAcceptableOrUnknown(data['item_kind']!, _itemKindMeta),
      );
    } else if (isInserting) {
      context.missing(_itemKindMeta);
    }
    if (data.containsKey('item_id')) {
      context.handle(
        _itemIdMeta,
        itemId.isAcceptableOrUnknown(data['item_id']!, _itemIdMeta),
      );
    } else if (isInserting) {
      context.missing(_itemIdMeta);
    }
    if (data.containsKey('last_accessed_at')) {
      context.handle(
        _lastAccessedAtMeta,
        lastAccessedAt.isAcceptableOrUnknown(
          data['last_accessed_at']!,
          _lastAccessedAtMeta,
        ),
      );
    }
    if (data.containsKey('access_count')) {
      context.handle(
        _accessCountMeta,
        accessCount.isAcceptableOrUnknown(
          data['access_count']!,
          _accessCountMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {itemKind, itemId};
  @override
  StorageItemStatRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StorageItemStatRow(
      itemKind: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_kind'],
      )!,
      itemId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}item_id'],
      )!,
      lastAccessedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}last_accessed_at'],
      ),
      accessCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}access_count'],
      )!,
    );
  }

  @override
  $StorageItemStatsTable createAlias(String alias) {
    return $StorageItemStatsTable(attachedDatabase, alias);
  }
}

class StorageItemStatRow extends DataClass
    implements Insertable<StorageItemStatRow> {
  final String itemKind;
  final String itemId;

  /// Epoch-ms; NULL = never observed, never 0 (task §5).
  final int? lastAccessedAt;
  final int accessCount;
  const StorageItemStatRow({
    required this.itemKind,
    required this.itemId,
    this.lastAccessedAt,
    required this.accessCount,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['item_kind'] = Variable<String>(itemKind);
    map['item_id'] = Variable<String>(itemId);
    if (!nullToAbsent || lastAccessedAt != null) {
      map['last_accessed_at'] = Variable<int>(lastAccessedAt);
    }
    map['access_count'] = Variable<int>(accessCount);
    return map;
  }

  StorageItemStatsCompanion toCompanion(bool nullToAbsent) {
    return StorageItemStatsCompanion(
      itemKind: Value(itemKind),
      itemId: Value(itemId),
      lastAccessedAt: lastAccessedAt == null && nullToAbsent
          ? const Value.absent()
          : Value(lastAccessedAt),
      accessCount: Value(accessCount),
    );
  }

  factory StorageItemStatRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StorageItemStatRow(
      itemKind: serializer.fromJson<String>(json['itemKind']),
      itemId: serializer.fromJson<String>(json['itemId']),
      lastAccessedAt: serializer.fromJson<int?>(json['lastAccessedAt']),
      accessCount: serializer.fromJson<int>(json['accessCount']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'itemKind': serializer.toJson<String>(itemKind),
      'itemId': serializer.toJson<String>(itemId),
      'lastAccessedAt': serializer.toJson<int?>(lastAccessedAt),
      'accessCount': serializer.toJson<int>(accessCount),
    };
  }

  StorageItemStatRow copyWith({
    String? itemKind,
    String? itemId,
    Value<int?> lastAccessedAt = const Value.absent(),
    int? accessCount,
  }) => StorageItemStatRow(
    itemKind: itemKind ?? this.itemKind,
    itemId: itemId ?? this.itemId,
    lastAccessedAt: lastAccessedAt.present
        ? lastAccessedAt.value
        : this.lastAccessedAt,
    accessCount: accessCount ?? this.accessCount,
  );
  StorageItemStatRow copyWithCompanion(StorageItemStatsCompanion data) {
    return StorageItemStatRow(
      itemKind: data.itemKind.present ? data.itemKind.value : this.itemKind,
      itemId: data.itemId.present ? data.itemId.value : this.itemId,
      lastAccessedAt: data.lastAccessedAt.present
          ? data.lastAccessedAt.value
          : this.lastAccessedAt,
      accessCount: data.accessCount.present
          ? data.accessCount.value
          : this.accessCount,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StorageItemStatRow(')
          ..write('itemKind: $itemKind, ')
          ..write('itemId: $itemId, ')
          ..write('lastAccessedAt: $lastAccessedAt, ')
          ..write('accessCount: $accessCount')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(itemKind, itemId, lastAccessedAt, accessCount);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StorageItemStatRow &&
          other.itemKind == this.itemKind &&
          other.itemId == this.itemId &&
          other.lastAccessedAt == this.lastAccessedAt &&
          other.accessCount == this.accessCount);
}

class StorageItemStatsCompanion extends UpdateCompanion<StorageItemStatRow> {
  final Value<String> itemKind;
  final Value<String> itemId;
  final Value<int?> lastAccessedAt;
  final Value<int> accessCount;
  final Value<int> rowid;
  const StorageItemStatsCompanion({
    this.itemKind = const Value.absent(),
    this.itemId = const Value.absent(),
    this.lastAccessedAt = const Value.absent(),
    this.accessCount = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StorageItemStatsCompanion.insert({
    required String itemKind,
    required String itemId,
    this.lastAccessedAt = const Value.absent(),
    this.accessCount = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : itemKind = Value(itemKind),
       itemId = Value(itemId);
  static Insertable<StorageItemStatRow> custom({
    Expression<String>? itemKind,
    Expression<String>? itemId,
    Expression<int>? lastAccessedAt,
    Expression<int>? accessCount,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (itemKind != null) 'item_kind': itemKind,
      if (itemId != null) 'item_id': itemId,
      if (lastAccessedAt != null) 'last_accessed_at': lastAccessedAt,
      if (accessCount != null) 'access_count': accessCount,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StorageItemStatsCompanion copyWith({
    Value<String>? itemKind,
    Value<String>? itemId,
    Value<int?>? lastAccessedAt,
    Value<int>? accessCount,
    Value<int>? rowid,
  }) {
    return StorageItemStatsCompanion(
      itemKind: itemKind ?? this.itemKind,
      itemId: itemId ?? this.itemId,
      lastAccessedAt: lastAccessedAt ?? this.lastAccessedAt,
      accessCount: accessCount ?? this.accessCount,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (itemKind.present) {
      map['item_kind'] = Variable<String>(itemKind.value);
    }
    if (itemId.present) {
      map['item_id'] = Variable<String>(itemId.value);
    }
    if (lastAccessedAt.present) {
      map['last_accessed_at'] = Variable<int>(lastAccessedAt.value);
    }
    if (accessCount.present) {
      map['access_count'] = Variable<int>(accessCount.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StorageItemStatsCompanion(')
          ..write('itemKind: $itemKind, ')
          ..write('itemId: $itemId, ')
          ..write('lastAccessedAt: $lastAccessedAt, ')
          ..write('accessCount: $accessCount, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $StoragePolicySettingsTable extends StoragePolicySettings
    with TableInfo<$StoragePolicySettingsTable, StoragePolicySettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StoragePolicySettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _olderThanDaysMeta = const VerificationMeta(
    'olderThanDays',
  );
  @override
  late final GeneratedColumn<int> olderThanDays = GeneratedColumn<int>(
    'older_than_days',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _maxBytesMeta = const VerificationMeta(
    'maxBytes',
  );
  @override
  late final GeneratedColumn<int> maxBytes = GeneratedColumn<int>(
    'max_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _budgetBytesMeta = const VerificationMeta(
    'budgetBytes',
  );
  @override
  late final GeneratedColumn<int> budgetBytes = GeneratedColumn<int>(
    'budget_bytes',
    aliasedName,
    true,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    mode,
    olderThanDays,
    maxBytes,
    budgetBytes,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'storage_policy_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<StoragePolicySettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('older_than_days')) {
      context.handle(
        _olderThanDaysMeta,
        olderThanDays.isAcceptableOrUnknown(
          data['older_than_days']!,
          _olderThanDaysMeta,
        ),
      );
    }
    if (data.containsKey('max_bytes')) {
      context.handle(
        _maxBytesMeta,
        maxBytes.isAcceptableOrUnknown(data['max_bytes']!, _maxBytesMeta),
      );
    }
    if (data.containsKey('budget_bytes')) {
      context.handle(
        _budgetBytesMeta,
        budgetBytes.isAcceptableOrUnknown(
          data['budget_bytes']!,
          _budgetBytesMeta,
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StoragePolicySettingRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StoragePolicySettingRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      olderThanDays: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}older_than_days'],
      ),
      maxBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}max_bytes'],
      ),
      budgetBytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}budget_bytes'],
      ),
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $StoragePolicySettingsTable createAlias(String alias) {
    return $StoragePolicySettingsTable(attachedDatabase, alias);
  }
}

class StoragePolicySettingRow extends DataClass
    implements Insertable<StoragePolicySettingRow> {
  final int id;

  /// A `StorageMode.name`: `smart` | `olderThanDays` | `overSizeMb`
  /// (docs/conventions.md "Enums" -- never an integer index).
  final String mode;

  /// NULL unless `mode == olderThanDays`.
  final int? olderThanDays;

  /// NULL unless `mode == overSizeMb`.
  final int? maxBytes;

  /// The denominator; stays NULL until `OQ-E08-1` is answered (task §2).
  final int? budgetBytes;
  final int updatedAt;
  const StoragePolicySettingRow({
    required this.id,
    required this.mode,
    this.olderThanDays,
    this.maxBytes,
    this.budgetBytes,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['mode'] = Variable<String>(mode);
    if (!nullToAbsent || olderThanDays != null) {
      map['older_than_days'] = Variable<int>(olderThanDays);
    }
    if (!nullToAbsent || maxBytes != null) {
      map['max_bytes'] = Variable<int>(maxBytes);
    }
    if (!nullToAbsent || budgetBytes != null) {
      map['budget_bytes'] = Variable<int>(budgetBytes);
    }
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  StoragePolicySettingsCompanion toCompanion(bool nullToAbsent) {
    return StoragePolicySettingsCompanion(
      id: Value(id),
      mode: Value(mode),
      olderThanDays: olderThanDays == null && nullToAbsent
          ? const Value.absent()
          : Value(olderThanDays),
      maxBytes: maxBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(maxBytes),
      budgetBytes: budgetBytes == null && nullToAbsent
          ? const Value.absent()
          : Value(budgetBytes),
      updatedAt: Value(updatedAt),
    );
  }

  factory StoragePolicySettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StoragePolicySettingRow(
      id: serializer.fromJson<int>(json['id']),
      mode: serializer.fromJson<String>(json['mode']),
      olderThanDays: serializer.fromJson<int?>(json['olderThanDays']),
      maxBytes: serializer.fromJson<int?>(json['maxBytes']),
      budgetBytes: serializer.fromJson<int?>(json['budgetBytes']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'mode': serializer.toJson<String>(mode),
      'olderThanDays': serializer.toJson<int?>(olderThanDays),
      'maxBytes': serializer.toJson<int?>(maxBytes),
      'budgetBytes': serializer.toJson<int?>(budgetBytes),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  StoragePolicySettingRow copyWith({
    int? id,
    String? mode,
    Value<int?> olderThanDays = const Value.absent(),
    Value<int?> maxBytes = const Value.absent(),
    Value<int?> budgetBytes = const Value.absent(),
    int? updatedAt,
  }) => StoragePolicySettingRow(
    id: id ?? this.id,
    mode: mode ?? this.mode,
    olderThanDays: olderThanDays.present
        ? olderThanDays.value
        : this.olderThanDays,
    maxBytes: maxBytes.present ? maxBytes.value : this.maxBytes,
    budgetBytes: budgetBytes.present ? budgetBytes.value : this.budgetBytes,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  StoragePolicySettingRow copyWithCompanion(
    StoragePolicySettingsCompanion data,
  ) {
    return StoragePolicySettingRow(
      id: data.id.present ? data.id.value : this.id,
      mode: data.mode.present ? data.mode.value : this.mode,
      olderThanDays: data.olderThanDays.present
          ? data.olderThanDays.value
          : this.olderThanDays,
      maxBytes: data.maxBytes.present ? data.maxBytes.value : this.maxBytes,
      budgetBytes: data.budgetBytes.present
          ? data.budgetBytes.value
          : this.budgetBytes,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StoragePolicySettingRow(')
          ..write('id: $id, ')
          ..write('mode: $mode, ')
          ..write('olderThanDays: $olderThanDays, ')
          ..write('maxBytes: $maxBytes, ')
          ..write('budgetBytes: $budgetBytes, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode =>
      Object.hash(id, mode, olderThanDays, maxBytes, budgetBytes, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StoragePolicySettingRow &&
          other.id == this.id &&
          other.mode == this.mode &&
          other.olderThanDays == this.olderThanDays &&
          other.maxBytes == this.maxBytes &&
          other.budgetBytes == this.budgetBytes &&
          other.updatedAt == this.updatedAt);
}

class StoragePolicySettingsCompanion
    extends UpdateCompanion<StoragePolicySettingRow> {
  final Value<int> id;
  final Value<String> mode;
  final Value<int?> olderThanDays;
  final Value<int?> maxBytes;
  final Value<int?> budgetBytes;
  final Value<int> updatedAt;
  const StoragePolicySettingsCompanion({
    this.id = const Value.absent(),
    this.mode = const Value.absent(),
    this.olderThanDays = const Value.absent(),
    this.maxBytes = const Value.absent(),
    this.budgetBytes = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  StoragePolicySettingsCompanion.insert({
    this.id = const Value.absent(),
    required String mode,
    this.olderThanDays = const Value.absent(),
    this.maxBytes = const Value.absent(),
    this.budgetBytes = const Value.absent(),
    required int updatedAt,
  }) : mode = Value(mode),
       updatedAt = Value(updatedAt);
  static Insertable<StoragePolicySettingRow> custom({
    Expression<int>? id,
    Expression<String>? mode,
    Expression<int>? olderThanDays,
    Expression<int>? maxBytes,
    Expression<int>? budgetBytes,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (mode != null) 'mode': mode,
      if (olderThanDays != null) 'older_than_days': olderThanDays,
      if (maxBytes != null) 'max_bytes': maxBytes,
      if (budgetBytes != null) 'budget_bytes': budgetBytes,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  StoragePolicySettingsCompanion copyWith({
    Value<int>? id,
    Value<String>? mode,
    Value<int?>? olderThanDays,
    Value<int?>? maxBytes,
    Value<int?>? budgetBytes,
    Value<int>? updatedAt,
  }) {
    return StoragePolicySettingsCompanion(
      id: id ?? this.id,
      mode: mode ?? this.mode,
      olderThanDays: olderThanDays ?? this.olderThanDays,
      maxBytes: maxBytes ?? this.maxBytes,
      budgetBytes: budgetBytes ?? this.budgetBytes,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (olderThanDays.present) {
      map['older_than_days'] = Variable<int>(olderThanDays.value);
    }
    if (maxBytes.present) {
      map['max_bytes'] = Variable<int>(maxBytes.value);
    }
    if (budgetBytes.present) {
      map['budget_bytes'] = Variable<int>(budgetBytes.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StoragePolicySettingsCompanion(')
          ..write('id: $id, ')
          ..write('mode: $mode, ')
          ..write('olderThanDays: $olderThanDays, ')
          ..write('maxBytes: $maxBytes, ')
          ..write('budgetBytes: $budgetBytes, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $StorageDecisionsTable extends StorageDecisions
    with TableInfo<$StorageDecisionsTable, StorageDecisionRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $StorageDecisionsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<String> id = GeneratedColumn<String>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _decidedAtMeta = const VerificationMeta(
    'decidedAt',
  );
  @override
  late final GeneratedColumn<int> decidedAt = GeneratedColumn<int>(
    'decided_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _modeMeta = const VerificationMeta('mode');
  @override
  late final GeneratedColumn<String> mode = GeneratedColumn<String>(
    'mode',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _categoryKeyMeta = const VerificationMeta(
    'categoryKey',
  );
  @override
  late final GeneratedColumn<String> categoryKey = GeneratedColumn<String>(
    'category_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _itemCountMeta = const VerificationMeta(
    'itemCount',
  );
  @override
  late final GeneratedColumn<int> itemCount = GeneratedColumn<int>(
    'item_count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _bytesMeta = const VerificationMeta('bytes');
  @override
  late final GeneratedColumn<int> bytes = GeneratedColumn<int>(
    'bytes',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonCodeMeta = const VerificationMeta(
    'reasonCode',
  );
  @override
  late final GeneratedColumn<String> reasonCode = GeneratedColumn<String>(
    'reason_code',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _reasonDetailMeta = const VerificationMeta(
    'reasonDetail',
  );
  @override
  late final GeneratedColumn<String> reasonDetail = GeneratedColumn<String>(
    'reason_detail',
    aliasedName,
    true,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _outcomeMeta = const VerificationMeta(
    'outcome',
  );
  @override
  late final GeneratedColumn<String> outcome = GeneratedColumn<String>(
    'outcome',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    decidedAt,
    mode,
    categoryKey,
    itemCount,
    bytes,
    reasonCode,
    reasonDetail,
    outcome,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'storage_decisions';
  @override
  VerificationContext validateIntegrity(
    Insertable<StorageDecisionRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    } else if (isInserting) {
      context.missing(_idMeta);
    }
    if (data.containsKey('decided_at')) {
      context.handle(
        _decidedAtMeta,
        decidedAt.isAcceptableOrUnknown(data['decided_at']!, _decidedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_decidedAtMeta);
    }
    if (data.containsKey('mode')) {
      context.handle(
        _modeMeta,
        mode.isAcceptableOrUnknown(data['mode']!, _modeMeta),
      );
    } else if (isInserting) {
      context.missing(_modeMeta);
    }
    if (data.containsKey('category_key')) {
      context.handle(
        _categoryKeyMeta,
        categoryKey.isAcceptableOrUnknown(
          data['category_key']!,
          _categoryKeyMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_categoryKeyMeta);
    }
    if (data.containsKey('item_count')) {
      context.handle(
        _itemCountMeta,
        itemCount.isAcceptableOrUnknown(data['item_count']!, _itemCountMeta),
      );
    } else if (isInserting) {
      context.missing(_itemCountMeta);
    }
    if (data.containsKey('bytes')) {
      context.handle(
        _bytesMeta,
        bytes.isAcceptableOrUnknown(data['bytes']!, _bytesMeta),
      );
    } else if (isInserting) {
      context.missing(_bytesMeta);
    }
    if (data.containsKey('reason_code')) {
      context.handle(
        _reasonCodeMeta,
        reasonCode.isAcceptableOrUnknown(data['reason_code']!, _reasonCodeMeta),
      );
    } else if (isInserting) {
      context.missing(_reasonCodeMeta);
    }
    if (data.containsKey('reason_detail')) {
      context.handle(
        _reasonDetailMeta,
        reasonDetail.isAcceptableOrUnknown(
          data['reason_detail']!,
          _reasonDetailMeta,
        ),
      );
    }
    if (data.containsKey('outcome')) {
      context.handle(
        _outcomeMeta,
        outcome.isAcceptableOrUnknown(data['outcome']!, _outcomeMeta),
      );
    } else if (isInserting) {
      context.missing(_outcomeMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  StorageDecisionRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return StorageDecisionRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}id'],
      )!,
      decidedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}decided_at'],
      )!,
      mode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}mode'],
      )!,
      categoryKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category_key'],
      )!,
      itemCount: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}item_count'],
      )!,
      bytes: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}bytes'],
      )!,
      reasonCode: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason_code'],
      )!,
      reasonDetail: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}reason_detail'],
      ),
      outcome: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}outcome'],
      )!,
    );
  }

  @override
  $StorageDecisionsTable createAlias(String alias) {
    return $StorageDecisionsTable(attachedDatabase, alias);
  }
}

class StorageDecisionRow extends DataClass
    implements Insertable<StorageDecisionRow> {
  final String id;
  final int decidedAt;

  /// The `StorageMode.name` in force when the decision was made.
  final String mode;

  /// A stable machine key (e.g. `relayCache`, `messages`) -- not display
  /// copy.
  final String categoryKey;
  final int itemCount;

  /// Real measured bytes, never estimated.
  final int bytes;

  /// A `RetentionReason.name` (E08-T04 owns the enum).
  final String reasonCode;

  /// The reason's parameter as text (e.g. `45` for "older than 45 days").
  final String? reasonDetail;

  /// A `DecisionOutcome.name`: `planned` | `applied` | `skipped`.
  final String outcome;
  const StorageDecisionRow({
    required this.id,
    required this.decidedAt,
    required this.mode,
    required this.categoryKey,
    required this.itemCount,
    required this.bytes,
    required this.reasonCode,
    this.reasonDetail,
    required this.outcome,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<String>(id);
    map['decided_at'] = Variable<int>(decidedAt);
    map['mode'] = Variable<String>(mode);
    map['category_key'] = Variable<String>(categoryKey);
    map['item_count'] = Variable<int>(itemCount);
    map['bytes'] = Variable<int>(bytes);
    map['reason_code'] = Variable<String>(reasonCode);
    if (!nullToAbsent || reasonDetail != null) {
      map['reason_detail'] = Variable<String>(reasonDetail);
    }
    map['outcome'] = Variable<String>(outcome);
    return map;
  }

  StorageDecisionsCompanion toCompanion(bool nullToAbsent) {
    return StorageDecisionsCompanion(
      id: Value(id),
      decidedAt: Value(decidedAt),
      mode: Value(mode),
      categoryKey: Value(categoryKey),
      itemCount: Value(itemCount),
      bytes: Value(bytes),
      reasonCode: Value(reasonCode),
      reasonDetail: reasonDetail == null && nullToAbsent
          ? const Value.absent()
          : Value(reasonDetail),
      outcome: Value(outcome),
    );
  }

  factory StorageDecisionRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return StorageDecisionRow(
      id: serializer.fromJson<String>(json['id']),
      decidedAt: serializer.fromJson<int>(json['decidedAt']),
      mode: serializer.fromJson<String>(json['mode']),
      categoryKey: serializer.fromJson<String>(json['categoryKey']),
      itemCount: serializer.fromJson<int>(json['itemCount']),
      bytes: serializer.fromJson<int>(json['bytes']),
      reasonCode: serializer.fromJson<String>(json['reasonCode']),
      reasonDetail: serializer.fromJson<String?>(json['reasonDetail']),
      outcome: serializer.fromJson<String>(json['outcome']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<String>(id),
      'decidedAt': serializer.toJson<int>(decidedAt),
      'mode': serializer.toJson<String>(mode),
      'categoryKey': serializer.toJson<String>(categoryKey),
      'itemCount': serializer.toJson<int>(itemCount),
      'bytes': serializer.toJson<int>(bytes),
      'reasonCode': serializer.toJson<String>(reasonCode),
      'reasonDetail': serializer.toJson<String?>(reasonDetail),
      'outcome': serializer.toJson<String>(outcome),
    };
  }

  StorageDecisionRow copyWith({
    String? id,
    int? decidedAt,
    String? mode,
    String? categoryKey,
    int? itemCount,
    int? bytes,
    String? reasonCode,
    Value<String?> reasonDetail = const Value.absent(),
    String? outcome,
  }) => StorageDecisionRow(
    id: id ?? this.id,
    decidedAt: decidedAt ?? this.decidedAt,
    mode: mode ?? this.mode,
    categoryKey: categoryKey ?? this.categoryKey,
    itemCount: itemCount ?? this.itemCount,
    bytes: bytes ?? this.bytes,
    reasonCode: reasonCode ?? this.reasonCode,
    reasonDetail: reasonDetail.present ? reasonDetail.value : this.reasonDetail,
    outcome: outcome ?? this.outcome,
  );
  StorageDecisionRow copyWithCompanion(StorageDecisionsCompanion data) {
    return StorageDecisionRow(
      id: data.id.present ? data.id.value : this.id,
      decidedAt: data.decidedAt.present ? data.decidedAt.value : this.decidedAt,
      mode: data.mode.present ? data.mode.value : this.mode,
      categoryKey: data.categoryKey.present
          ? data.categoryKey.value
          : this.categoryKey,
      itemCount: data.itemCount.present ? data.itemCount.value : this.itemCount,
      bytes: data.bytes.present ? data.bytes.value : this.bytes,
      reasonCode: data.reasonCode.present
          ? data.reasonCode.value
          : this.reasonCode,
      reasonDetail: data.reasonDetail.present
          ? data.reasonDetail.value
          : this.reasonDetail,
      outcome: data.outcome.present ? data.outcome.value : this.outcome,
    );
  }

  @override
  String toString() {
    return (StringBuffer('StorageDecisionRow(')
          ..write('id: $id, ')
          ..write('decidedAt: $decidedAt, ')
          ..write('mode: $mode, ')
          ..write('categoryKey: $categoryKey, ')
          ..write('itemCount: $itemCount, ')
          ..write('bytes: $bytes, ')
          ..write('reasonCode: $reasonCode, ')
          ..write('reasonDetail: $reasonDetail, ')
          ..write('outcome: $outcome')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    decidedAt,
    mode,
    categoryKey,
    itemCount,
    bytes,
    reasonCode,
    reasonDetail,
    outcome,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is StorageDecisionRow &&
          other.id == this.id &&
          other.decidedAt == this.decidedAt &&
          other.mode == this.mode &&
          other.categoryKey == this.categoryKey &&
          other.itemCount == this.itemCount &&
          other.bytes == this.bytes &&
          other.reasonCode == this.reasonCode &&
          other.reasonDetail == this.reasonDetail &&
          other.outcome == this.outcome);
}

class StorageDecisionsCompanion extends UpdateCompanion<StorageDecisionRow> {
  final Value<String> id;
  final Value<int> decidedAt;
  final Value<String> mode;
  final Value<String> categoryKey;
  final Value<int> itemCount;
  final Value<int> bytes;
  final Value<String> reasonCode;
  final Value<String?> reasonDetail;
  final Value<String> outcome;
  final Value<int> rowid;
  const StorageDecisionsCompanion({
    this.id = const Value.absent(),
    this.decidedAt = const Value.absent(),
    this.mode = const Value.absent(),
    this.categoryKey = const Value.absent(),
    this.itemCount = const Value.absent(),
    this.bytes = const Value.absent(),
    this.reasonCode = const Value.absent(),
    this.reasonDetail = const Value.absent(),
    this.outcome = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  StorageDecisionsCompanion.insert({
    required String id,
    required int decidedAt,
    required String mode,
    required String categoryKey,
    required int itemCount,
    required int bytes,
    required String reasonCode,
    this.reasonDetail = const Value.absent(),
    required String outcome,
    this.rowid = const Value.absent(),
  }) : id = Value(id),
       decidedAt = Value(decidedAt),
       mode = Value(mode),
       categoryKey = Value(categoryKey),
       itemCount = Value(itemCount),
       bytes = Value(bytes),
       reasonCode = Value(reasonCode),
       outcome = Value(outcome);
  static Insertable<StorageDecisionRow> custom({
    Expression<String>? id,
    Expression<int>? decidedAt,
    Expression<String>? mode,
    Expression<String>? categoryKey,
    Expression<int>? itemCount,
    Expression<int>? bytes,
    Expression<String>? reasonCode,
    Expression<String>? reasonDetail,
    Expression<String>? outcome,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (decidedAt != null) 'decided_at': decidedAt,
      if (mode != null) 'mode': mode,
      if (categoryKey != null) 'category_key': categoryKey,
      if (itemCount != null) 'item_count': itemCount,
      if (bytes != null) 'bytes': bytes,
      if (reasonCode != null) 'reason_code': reasonCode,
      if (reasonDetail != null) 'reason_detail': reasonDetail,
      if (outcome != null) 'outcome': outcome,
      if (rowid != null) 'rowid': rowid,
    });
  }

  StorageDecisionsCompanion copyWith({
    Value<String>? id,
    Value<int>? decidedAt,
    Value<String>? mode,
    Value<String>? categoryKey,
    Value<int>? itemCount,
    Value<int>? bytes,
    Value<String>? reasonCode,
    Value<String?>? reasonDetail,
    Value<String>? outcome,
    Value<int>? rowid,
  }) {
    return StorageDecisionsCompanion(
      id: id ?? this.id,
      decidedAt: decidedAt ?? this.decidedAt,
      mode: mode ?? this.mode,
      categoryKey: categoryKey ?? this.categoryKey,
      itemCount: itemCount ?? this.itemCount,
      bytes: bytes ?? this.bytes,
      reasonCode: reasonCode ?? this.reasonCode,
      reasonDetail: reasonDetail ?? this.reasonDetail,
      outcome: outcome ?? this.outcome,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<String>(id.value);
    }
    if (decidedAt.present) {
      map['decided_at'] = Variable<int>(decidedAt.value);
    }
    if (mode.present) {
      map['mode'] = Variable<String>(mode.value);
    }
    if (categoryKey.present) {
      map['category_key'] = Variable<String>(categoryKey.value);
    }
    if (itemCount.present) {
      map['item_count'] = Variable<int>(itemCount.value);
    }
    if (bytes.present) {
      map['bytes'] = Variable<int>(bytes.value);
    }
    if (reasonCode.present) {
      map['reason_code'] = Variable<String>(reasonCode.value);
    }
    if (reasonDetail.present) {
      map['reason_detail'] = Variable<String>(reasonDetail.value);
    }
    if (outcome.present) {
      map['outcome'] = Variable<String>(outcome.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('StorageDecisionsCompanion(')
          ..write('id: $id, ')
          ..write('decidedAt: $decidedAt, ')
          ..write('mode: $mode, ')
          ..write('categoryKey: $categoryKey, ')
          ..write('itemCount: $itemCount, ')
          ..write('bytes: $bytes, ')
          ..write('reasonCode: $reasonCode, ')
          ..write('reasonDetail: $reasonDetail, ')
          ..write('outcome: $outcome, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocationSettingsTable extends LocationSettings
    with TableInfo<$LocationSettingsTable, LocationSettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocationSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _globalEnabledMeta = const VerificationMeta(
    'globalEnabled',
  );
  @override
  late final GeneratedColumn<bool> globalEnabled = GeneratedColumn<bool>(
    'global_enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("global_enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [id, globalEnabled, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'location_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocationSettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('global_enabled')) {
      context.handle(
        _globalEnabledMeta,
        globalEnabled.isAcceptableOrUnknown(
          data['global_enabled']!,
          _globalEnabledMeta,
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  LocationSettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocationSettingRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      globalEnabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}global_enabled'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocationSettingsTable createAlias(String alias) {
    return $LocationSettingsTable(attachedDatabase, alias);
  }
}

class LocationSettingRow extends DataClass
    implements Insertable<LocationSettingRow> {
  final int id;
  final bool globalEnabled;

  /// Epoch-ms.
  final int updatedAt;
  const LocationSettingRow({
    required this.id,
    required this.globalEnabled,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['global_enabled'] = Variable<bool>(globalEnabled);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  LocationSettingsCompanion toCompanion(bool nullToAbsent) {
    return LocationSettingsCompanion(
      id: Value(id),
      globalEnabled: Value(globalEnabled),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocationSettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocationSettingRow(
      id: serializer.fromJson<int>(json['id']),
      globalEnabled: serializer.fromJson<bool>(json['globalEnabled']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'globalEnabled': serializer.toJson<bool>(globalEnabled),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  LocationSettingRow copyWith({int? id, bool? globalEnabled, int? updatedAt}) =>
      LocationSettingRow(
        id: id ?? this.id,
        globalEnabled: globalEnabled ?? this.globalEnabled,
        updatedAt: updatedAt ?? this.updatedAt,
      );
  LocationSettingRow copyWithCompanion(LocationSettingsCompanion data) {
    return LocationSettingRow(
      id: data.id.present ? data.id.value : this.id,
      globalEnabled: data.globalEnabled.present
          ? data.globalEnabled.value
          : this.globalEnabled,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocationSettingRow(')
          ..write('id: $id, ')
          ..write('globalEnabled: $globalEnabled, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, globalEnabled, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocationSettingRow &&
          other.id == this.id &&
          other.globalEnabled == this.globalEnabled &&
          other.updatedAt == this.updatedAt);
}

class LocationSettingsCompanion extends UpdateCompanion<LocationSettingRow> {
  final Value<int> id;
  final Value<bool> globalEnabled;
  final Value<int> updatedAt;
  const LocationSettingsCompanion({
    this.id = const Value.absent(),
    this.globalEnabled = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  LocationSettingsCompanion.insert({
    this.id = const Value.absent(),
    this.globalEnabled = const Value.absent(),
    required int updatedAt,
  }) : updatedAt = Value(updatedAt);
  static Insertable<LocationSettingRow> custom({
    Expression<int>? id,
    Expression<bool>? globalEnabled,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (globalEnabled != null) 'global_enabled': globalEnabled,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  LocationSettingsCompanion copyWith({
    Value<int>? id,
    Value<bool>? globalEnabled,
    Value<int>? updatedAt,
  }) {
    return LocationSettingsCompanion(
      id: id ?? this.id,
      globalEnabled: globalEnabled ?? this.globalEnabled,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (globalEnabled.present) {
      map['global_enabled'] = Variable<bool>(globalEnabled.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocationSettingsCompanion(')
          ..write('id: $id, ')
          ..write('globalEnabled: $globalEnabled, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }
}

class $LocationPeerSettingsTable extends LocationPeerSettings
    with TableInfo<$LocationPeerSettingsTable, LocationPeerSettingRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocationPeerSettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _peerDeviceIdMeta = const VerificationMeta(
    'peerDeviceId',
  );
  @override
  late final GeneratedColumn<String> peerDeviceId = GeneratedColumn<String>(
    'peer_device_id',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(false),
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [peerDeviceId, enabled, updatedAt];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'location_peer_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocationPeerSettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('peer_device_id')) {
      context.handle(
        _peerDeviceIdMeta,
        peerDeviceId.isAcceptableOrUnknown(
          data['peer_device_id']!,
          _peerDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_peerDeviceIdMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
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
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {peerDeviceId};
  @override
  LocationPeerSettingRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocationPeerSettingRow(
      peerDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_device_id'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $LocationPeerSettingsTable createAlias(String alias) {
    return $LocationPeerSettingsTable(attachedDatabase, alias);
  }
}

class LocationPeerSettingRow extends DataClass
    implements Insertable<LocationPeerSettingRow> {
  /// The same device-id string `relationships.deviceId` uses.
  final String peerDeviceId;
  final bool enabled;

  /// Epoch-ms.
  final int updatedAt;
  const LocationPeerSettingRow({
    required this.peerDeviceId,
    required this.enabled,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['peer_device_id'] = Variable<String>(peerDeviceId);
    map['enabled'] = Variable<bool>(enabled);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  LocationPeerSettingsCompanion toCompanion(bool nullToAbsent) {
    return LocationPeerSettingsCompanion(
      peerDeviceId: Value(peerDeviceId),
      enabled: Value(enabled),
      updatedAt: Value(updatedAt),
    );
  }

  factory LocationPeerSettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocationPeerSettingRow(
      peerDeviceId: serializer.fromJson<String>(json['peerDeviceId']),
      enabled: serializer.fromJson<bool>(json['enabled']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'peerDeviceId': serializer.toJson<String>(peerDeviceId),
      'enabled': serializer.toJson<bool>(enabled),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  LocationPeerSettingRow copyWith({
    String? peerDeviceId,
    bool? enabled,
    int? updatedAt,
  }) => LocationPeerSettingRow(
    peerDeviceId: peerDeviceId ?? this.peerDeviceId,
    enabled: enabled ?? this.enabled,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  LocationPeerSettingRow copyWithCompanion(LocationPeerSettingsCompanion data) {
    return LocationPeerSettingRow(
      peerDeviceId: data.peerDeviceId.present
          ? data.peerDeviceId.value
          : this.peerDeviceId,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocationPeerSettingRow(')
          ..write('peerDeviceId: $peerDeviceId, ')
          ..write('enabled: $enabled, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(peerDeviceId, enabled, updatedAt);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocationPeerSettingRow &&
          other.peerDeviceId == this.peerDeviceId &&
          other.enabled == this.enabled &&
          other.updatedAt == this.updatedAt);
}

class LocationPeerSettingsCompanion
    extends UpdateCompanion<LocationPeerSettingRow> {
  final Value<String> peerDeviceId;
  final Value<bool> enabled;
  final Value<int> updatedAt;
  final Value<int> rowid;
  const LocationPeerSettingsCompanion({
    this.peerDeviceId = const Value.absent(),
    this.enabled = const Value.absent(),
    this.updatedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocationPeerSettingsCompanion.insert({
    required String peerDeviceId,
    this.enabled = const Value.absent(),
    required int updatedAt,
    this.rowid = const Value.absent(),
  }) : peerDeviceId = Value(peerDeviceId),
       updatedAt = Value(updatedAt);
  static Insertable<LocationPeerSettingRow> custom({
    Expression<String>? peerDeviceId,
    Expression<bool>? enabled,
    Expression<int>? updatedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (peerDeviceId != null) 'peer_device_id': peerDeviceId,
      if (enabled != null) 'enabled': enabled,
      if (updatedAt != null) 'updated_at': updatedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocationPeerSettingsCompanion copyWith({
    Value<String>? peerDeviceId,
    Value<bool>? enabled,
    Value<int>? updatedAt,
    Value<int>? rowid,
  }) {
    return LocationPeerSettingsCompanion(
      peerDeviceId: peerDeviceId ?? this.peerDeviceId,
      enabled: enabled ?? this.enabled,
      updatedAt: updatedAt ?? this.updatedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (peerDeviceId.present) {
      map['peer_device_id'] = Variable<String>(peerDeviceId.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocationPeerSettingsCompanion(')
          ..write('peerDeviceId: $peerDeviceId, ')
          ..write('enabled: $enabled, ')
          ..write('updatedAt: $updatedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $LocationFixesTable extends LocationFixes
    with TableInfo<$LocationFixesTable, LocationFixRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $LocationFixesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _peerDeviceIdMeta = const VerificationMeta(
    'peerDeviceId',
  );
  @override
  late final GeneratedColumn<String> peerDeviceId = GeneratedColumn<String>(
    'peer_device_id',
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
    requiredDuringInsert: true,
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
    requiredDuringInsert: true,
  );
  static const VerificationMeta _accuracyMMeta = const VerificationMeta(
    'accuracyM',
  );
  @override
  late final GeneratedColumn<double> accuracyM = GeneratedColumn<double>(
    'accuracy_m',
    aliasedName,
    true,
    type: DriftSqlType.double,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _capturedAtMeta = const VerificationMeta(
    'capturedAt',
  );
  @override
  late final GeneratedColumn<int> capturedAt = GeneratedColumn<int>(
    'captured_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _receivedAtMeta = const VerificationMeta(
    'receivedAt',
  );
  @override
  late final GeneratedColumn<int> receivedAt = GeneratedColumn<int>(
    'received_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    peerDeviceId,
    latitude,
    longitude,
    accuracyM,
    capturedAt,
    receivedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'location_fixes';
  @override
  VerificationContext validateIntegrity(
    Insertable<LocationFixRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('peer_device_id')) {
      context.handle(
        _peerDeviceIdMeta,
        peerDeviceId.isAcceptableOrUnknown(
          data['peer_device_id']!,
          _peerDeviceIdMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_peerDeviceIdMeta);
    }
    if (data.containsKey('latitude')) {
      context.handle(
        _latitudeMeta,
        latitude.isAcceptableOrUnknown(data['latitude']!, _latitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_latitudeMeta);
    }
    if (data.containsKey('longitude')) {
      context.handle(
        _longitudeMeta,
        longitude.isAcceptableOrUnknown(data['longitude']!, _longitudeMeta),
      );
    } else if (isInserting) {
      context.missing(_longitudeMeta);
    }
    if (data.containsKey('accuracy_m')) {
      context.handle(
        _accuracyMMeta,
        accuracyM.isAcceptableOrUnknown(data['accuracy_m']!, _accuracyMMeta),
      );
    }
    if (data.containsKey('captured_at')) {
      context.handle(
        _capturedAtMeta,
        capturedAt.isAcceptableOrUnknown(data['captured_at']!, _capturedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_capturedAtMeta);
    }
    if (data.containsKey('received_at')) {
      context.handle(
        _receivedAtMeta,
        receivedAt.isAcceptableOrUnknown(data['received_at']!, _receivedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_receivedAtMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {peerDeviceId};
  @override
  LocationFixRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return LocationFixRow(
      peerDeviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}peer_device_id'],
      )!,
      latitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}latitude'],
      )!,
      longitude: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}longitude'],
      )!,
      accuracyM: attachedDatabase.typeMapping.read(
        DriftSqlType.double,
        data['${effectivePrefix}accuracy_m'],
      ),
      capturedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}captured_at'],
      )!,
      receivedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}received_at'],
      )!,
    );
  }

  @override
  $LocationFixesTable createAlias(String alias) {
    return $LocationFixesTable(attachedDatabase, alias);
  }
}

class LocationFixRow extends DataClass implements Insertable<LocationFixRow> {
  final String peerDeviceId;

  /// Decimal degrees, WGS84.
  final double latitude;

  /// Decimal degrees, WGS84.
  final double longitude;

  /// Metres; NULL = the sender reported none, never 0 (task §5).
  final double? accuracyM;

  /// Epoch-ms, as reported by the sender.
  final int capturedAt;

  /// Epoch-ms, this device's clock, when the fix was accepted.
  final int receivedAt;
  const LocationFixRow({
    required this.peerDeviceId,
    required this.latitude,
    required this.longitude,
    this.accuracyM,
    required this.capturedAt,
    required this.receivedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['peer_device_id'] = Variable<String>(peerDeviceId);
    map['latitude'] = Variable<double>(latitude);
    map['longitude'] = Variable<double>(longitude);
    if (!nullToAbsent || accuracyM != null) {
      map['accuracy_m'] = Variable<double>(accuracyM);
    }
    map['captured_at'] = Variable<int>(capturedAt);
    map['received_at'] = Variable<int>(receivedAt);
    return map;
  }

  LocationFixesCompanion toCompanion(bool nullToAbsent) {
    return LocationFixesCompanion(
      peerDeviceId: Value(peerDeviceId),
      latitude: Value(latitude),
      longitude: Value(longitude),
      accuracyM: accuracyM == null && nullToAbsent
          ? const Value.absent()
          : Value(accuracyM),
      capturedAt: Value(capturedAt),
      receivedAt: Value(receivedAt),
    );
  }

  factory LocationFixRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return LocationFixRow(
      peerDeviceId: serializer.fromJson<String>(json['peerDeviceId']),
      latitude: serializer.fromJson<double>(json['latitude']),
      longitude: serializer.fromJson<double>(json['longitude']),
      accuracyM: serializer.fromJson<double?>(json['accuracyM']),
      capturedAt: serializer.fromJson<int>(json['capturedAt']),
      receivedAt: serializer.fromJson<int>(json['receivedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'peerDeviceId': serializer.toJson<String>(peerDeviceId),
      'latitude': serializer.toJson<double>(latitude),
      'longitude': serializer.toJson<double>(longitude),
      'accuracyM': serializer.toJson<double?>(accuracyM),
      'capturedAt': serializer.toJson<int>(capturedAt),
      'receivedAt': serializer.toJson<int>(receivedAt),
    };
  }

  LocationFixRow copyWith({
    String? peerDeviceId,
    double? latitude,
    double? longitude,
    Value<double?> accuracyM = const Value.absent(),
    int? capturedAt,
    int? receivedAt,
  }) => LocationFixRow(
    peerDeviceId: peerDeviceId ?? this.peerDeviceId,
    latitude: latitude ?? this.latitude,
    longitude: longitude ?? this.longitude,
    accuracyM: accuracyM.present ? accuracyM.value : this.accuracyM,
    capturedAt: capturedAt ?? this.capturedAt,
    receivedAt: receivedAt ?? this.receivedAt,
  );
  LocationFixRow copyWithCompanion(LocationFixesCompanion data) {
    return LocationFixRow(
      peerDeviceId: data.peerDeviceId.present
          ? data.peerDeviceId.value
          : this.peerDeviceId,
      latitude: data.latitude.present ? data.latitude.value : this.latitude,
      longitude: data.longitude.present ? data.longitude.value : this.longitude,
      accuracyM: data.accuracyM.present ? data.accuracyM.value : this.accuracyM,
      capturedAt: data.capturedAt.present
          ? data.capturedAt.value
          : this.capturedAt,
      receivedAt: data.receivedAt.present
          ? data.receivedAt.value
          : this.receivedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('LocationFixRow(')
          ..write('peerDeviceId: $peerDeviceId, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('accuracyM: $accuracyM, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('receivedAt: $receivedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    peerDeviceId,
    latitude,
    longitude,
    accuracyM,
    capturedAt,
    receivedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is LocationFixRow &&
          other.peerDeviceId == this.peerDeviceId &&
          other.latitude == this.latitude &&
          other.longitude == this.longitude &&
          other.accuracyM == this.accuracyM &&
          other.capturedAt == this.capturedAt &&
          other.receivedAt == this.receivedAt);
}

class LocationFixesCompanion extends UpdateCompanion<LocationFixRow> {
  final Value<String> peerDeviceId;
  final Value<double> latitude;
  final Value<double> longitude;
  final Value<double?> accuracyM;
  final Value<int> capturedAt;
  final Value<int> receivedAt;
  final Value<int> rowid;
  const LocationFixesCompanion({
    this.peerDeviceId = const Value.absent(),
    this.latitude = const Value.absent(),
    this.longitude = const Value.absent(),
    this.accuracyM = const Value.absent(),
    this.capturedAt = const Value.absent(),
    this.receivedAt = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  LocationFixesCompanion.insert({
    required String peerDeviceId,
    required double latitude,
    required double longitude,
    this.accuracyM = const Value.absent(),
    required int capturedAt,
    required int receivedAt,
    this.rowid = const Value.absent(),
  }) : peerDeviceId = Value(peerDeviceId),
       latitude = Value(latitude),
       longitude = Value(longitude),
       capturedAt = Value(capturedAt),
       receivedAt = Value(receivedAt);
  static Insertable<LocationFixRow> custom({
    Expression<String>? peerDeviceId,
    Expression<double>? latitude,
    Expression<double>? longitude,
    Expression<double>? accuracyM,
    Expression<int>? capturedAt,
    Expression<int>? receivedAt,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (peerDeviceId != null) 'peer_device_id': peerDeviceId,
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
      if (accuracyM != null) 'accuracy_m': accuracyM,
      if (capturedAt != null) 'captured_at': capturedAt,
      if (receivedAt != null) 'received_at': receivedAt,
      if (rowid != null) 'rowid': rowid,
    });
  }

  LocationFixesCompanion copyWith({
    Value<String>? peerDeviceId,
    Value<double>? latitude,
    Value<double>? longitude,
    Value<double?>? accuracyM,
    Value<int>? capturedAt,
    Value<int>? receivedAt,
    Value<int>? rowid,
  }) {
    return LocationFixesCompanion(
      peerDeviceId: peerDeviceId ?? this.peerDeviceId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      accuracyM: accuracyM ?? this.accuracyM,
      capturedAt: capturedAt ?? this.capturedAt,
      receivedAt: receivedAt ?? this.receivedAt,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (peerDeviceId.present) {
      map['peer_device_id'] = Variable<String>(peerDeviceId.value);
    }
    if (latitude.present) {
      map['latitude'] = Variable<double>(latitude.value);
    }
    if (longitude.present) {
      map['longitude'] = Variable<double>(longitude.value);
    }
    if (accuracyM.present) {
      map['accuracy_m'] = Variable<double>(accuracyM.value);
    }
    if (capturedAt.present) {
      map['captured_at'] = Variable<int>(capturedAt.value);
    }
    if (receivedAt.present) {
      map['received_at'] = Variable<int>(receivedAt.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('LocationFixesCompanion(')
          ..write('peerDeviceId: $peerDeviceId, ')
          ..write('latitude: $latitude, ')
          ..write('longitude: $longitude, ')
          ..write('accuracyM: $accuracyM, ')
          ..write('capturedAt: $capturedAt, ')
          ..write('receivedAt: $receivedAt, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotificationCategorySettingsTable extends NotificationCategorySettings
    with
        TableInfo<
          $NotificationCategorySettingsTable,
          NotificationCategorySettingRow
        > {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationCategorySettingsTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _categoryMeta = const VerificationMeta(
    'category',
  );
  @override
  late final GeneratedColumn<String> category = GeneratedColumn<String>(
    'category',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _enabledMeta = const VerificationMeta(
    'enabled',
  );
  @override
  late final GeneratedColumn<bool> enabled = GeneratedColumn<bool>(
    'enabled',
    aliasedName,
    false,
    type: DriftSqlType.bool,
    requiredDuringInsert: false,
    defaultConstraints: GeneratedColumn.constraintIsAlways(
      'CHECK ("enabled" IN (0, 1))',
    ),
    defaultValue: const Constant(true),
  );
  @override
  List<GeneratedColumn> get $columns => [category, enabled];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notification_category_settings';
  @override
  VerificationContext validateIntegrity(
    Insertable<NotificationCategorySettingRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('category')) {
      context.handle(
        _categoryMeta,
        category.isAcceptableOrUnknown(data['category']!, _categoryMeta),
      );
    } else if (isInserting) {
      context.missing(_categoryMeta);
    }
    if (data.containsKey('enabled')) {
      context.handle(
        _enabledMeta,
        enabled.isAcceptableOrUnknown(data['enabled']!, _enabledMeta),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {category};
  @override
  NotificationCategorySettingRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotificationCategorySettingRow(
      category: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}category'],
      )!,
      enabled: attachedDatabase.typeMapping.read(
        DriftSqlType.bool,
        data['${effectivePrefix}enabled'],
      )!,
    );
  }

  @override
  $NotificationCategorySettingsTable createAlias(String alias) {
    return $NotificationCategorySettingsTable(attachedDatabase, alias);
  }
}

class NotificationCategorySettingRow extends DataClass
    implements Insertable<NotificationCategorySettingRow> {
  /// A `NotificationCategory.name` string. Never `backgroundService` (task
  /// §2) -- that category is not user-switchable and no row is seeded for
  /// it.
  final String category;
  final bool enabled;
  const NotificationCategorySettingRow({
    required this.category,
    required this.enabled,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['category'] = Variable<String>(category);
    map['enabled'] = Variable<bool>(enabled);
    return map;
  }

  NotificationCategorySettingsCompanion toCompanion(bool nullToAbsent) {
    return NotificationCategorySettingsCompanion(
      category: Value(category),
      enabled: Value(enabled),
    );
  }

  factory NotificationCategorySettingRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotificationCategorySettingRow(
      category: serializer.fromJson<String>(json['category']),
      enabled: serializer.fromJson<bool>(json['enabled']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'category': serializer.toJson<String>(category),
      'enabled': serializer.toJson<bool>(enabled),
    };
  }

  NotificationCategorySettingRow copyWith({String? category, bool? enabled}) =>
      NotificationCategorySettingRow(
        category: category ?? this.category,
        enabled: enabled ?? this.enabled,
      );
  NotificationCategorySettingRow copyWithCompanion(
    NotificationCategorySettingsCompanion data,
  ) {
    return NotificationCategorySettingRow(
      category: data.category.present ? data.category.value : this.category,
      enabled: data.enabled.present ? data.enabled.value : this.enabled,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotificationCategorySettingRow(')
          ..write('category: $category, ')
          ..write('enabled: $enabled')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(category, enabled);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationCategorySettingRow &&
          other.category == this.category &&
          other.enabled == this.enabled);
}

class NotificationCategorySettingsCompanion
    extends UpdateCompanion<NotificationCategorySettingRow> {
  final Value<String> category;
  final Value<bool> enabled;
  final Value<int> rowid;
  const NotificationCategorySettingsCompanion({
    this.category = const Value.absent(),
    this.enabled = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  NotificationCategorySettingsCompanion.insert({
    required String category,
    this.enabled = const Value.absent(),
    this.rowid = const Value.absent(),
  }) : category = Value(category);
  static Insertable<NotificationCategorySettingRow> custom({
    Expression<String>? category,
    Expression<bool>? enabled,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (category != null) 'category': category,
      if (enabled != null) 'enabled': enabled,
      if (rowid != null) 'rowid': rowid,
    });
  }

  NotificationCategorySettingsCompanion copyWith({
    Value<String>? category,
    Value<bool>? enabled,
    Value<int>? rowid,
  }) {
    return NotificationCategorySettingsCompanion(
      category: category ?? this.category,
      enabled: enabled ?? this.enabled,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (category.present) {
      map['category'] = Variable<String>(category.value);
    }
    if (enabled.present) {
      map['enabled'] = Variable<bool>(enabled.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationCategorySettingsCompanion(')
          ..write('category: $category, ')
          ..write('enabled: $enabled, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $NotificationPreferencesTable extends NotificationPreferences
    with TableInfo<$NotificationPreferencesTable, NotificationPreferenceRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $NotificationPreferencesTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _privacyLevelMeta = const VerificationMeta(
    'privacyLevel',
  );
  @override
  late final GeneratedColumn<String> privacyLevel = GeneratedColumn<String>(
    'privacy_level',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: false,
    defaultValue: const Constant('hidden'),
  );
  @override
  List<GeneratedColumn> get $columns => [id, privacyLevel];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'notification_preferences';
  @override
  VerificationContext validateIntegrity(
    Insertable<NotificationPreferenceRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('privacy_level')) {
      context.handle(
        _privacyLevelMeta,
        privacyLevel.isAcceptableOrUnknown(
          data['privacy_level']!,
          _privacyLevelMeta,
        ),
      );
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  NotificationPreferenceRow map(
    Map<String, dynamic> data, {
    String? tablePrefix,
  }) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return NotificationPreferenceRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      privacyLevel: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}privacy_level'],
      )!,
    );
  }

  @override
  $NotificationPreferencesTable createAlias(String alias) {
    return $NotificationPreferencesTable(attachedDatabase, alias);
  }
}

class NotificationPreferenceRow extends DataClass
    implements Insertable<NotificationPreferenceRow> {
  final int id;
  final String privacyLevel;
  const NotificationPreferenceRow({
    required this.id,
    required this.privacyLevel,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['privacy_level'] = Variable<String>(privacyLevel);
    return map;
  }

  NotificationPreferencesCompanion toCompanion(bool nullToAbsent) {
    return NotificationPreferencesCompanion(
      id: Value(id),
      privacyLevel: Value(privacyLevel),
    );
  }

  factory NotificationPreferenceRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return NotificationPreferenceRow(
      id: serializer.fromJson<int>(json['id']),
      privacyLevel: serializer.fromJson<String>(json['privacyLevel']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'privacyLevel': serializer.toJson<String>(privacyLevel),
    };
  }

  NotificationPreferenceRow copyWith({int? id, String? privacyLevel}) =>
      NotificationPreferenceRow(
        id: id ?? this.id,
        privacyLevel: privacyLevel ?? this.privacyLevel,
      );
  NotificationPreferenceRow copyWithCompanion(
    NotificationPreferencesCompanion data,
  ) {
    return NotificationPreferenceRow(
      id: data.id.present ? data.id.value : this.id,
      privacyLevel: data.privacyLevel.present
          ? data.privacyLevel.value
          : this.privacyLevel,
    );
  }

  @override
  String toString() {
    return (StringBuffer('NotificationPreferenceRow(')
          ..write('id: $id, ')
          ..write('privacyLevel: $privacyLevel')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(id, privacyLevel);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is NotificationPreferenceRow &&
          other.id == this.id &&
          other.privacyLevel == this.privacyLevel);
}

class NotificationPreferencesCompanion
    extends UpdateCompanion<NotificationPreferenceRow> {
  final Value<int> id;
  final Value<String> privacyLevel;
  const NotificationPreferencesCompanion({
    this.id = const Value.absent(),
    this.privacyLevel = const Value.absent(),
  });
  NotificationPreferencesCompanion.insert({
    this.id = const Value.absent(),
    this.privacyLevel = const Value.absent(),
  });
  static Insertable<NotificationPreferenceRow> custom({
    Expression<int>? id,
    Expression<String>? privacyLevel,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (privacyLevel != null) 'privacy_level': privacyLevel,
    });
  }

  NotificationPreferencesCompanion copyWith({
    Value<int>? id,
    Value<String>? privacyLevel,
  }) {
    return NotificationPreferencesCompanion(
      id: id ?? this.id,
      privacyLevel: privacyLevel ?? this.privacyLevel,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (privacyLevel.present) {
      map['privacy_level'] = Variable<String>(privacyLevel.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('NotificationPreferencesCompanion(')
          ..write('id: $id, ')
          ..write('privacyLevel: $privacyLevel')
          ..write(')'))
        .toString();
  }
}

class $DeviceRevocationsTable extends DeviceRevocations
    with TableInfo<$DeviceRevocationsTable, DeviceRevocationRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $DeviceRevocationsTable(this.attachedDatabase, [this._alias]);
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
  static const VerificationMeta _revokedAtMeta = const VerificationMeta(
    'revokedAt',
  );
  @override
  late final GeneratedColumn<DateTime> revokedAt = GeneratedColumn<DateTime>(
    'revoked_at',
    aliasedName,
    false,
    type: DriftSqlType.dateTime,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _sourceMeta = const VerificationMeta('source');
  @override
  late final GeneratedColumn<String> source = GeneratedColumn<String>(
    'source',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [deviceId, revokedAt, source];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'device_revocations';
  @override
  VerificationContext validateIntegrity(
    Insertable<DeviceRevocationRow> instance, {
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
    if (data.containsKey('revoked_at')) {
      context.handle(
        _revokedAtMeta,
        revokedAt.isAcceptableOrUnknown(data['revoked_at']!, _revokedAtMeta),
      );
    } else if (isInserting) {
      context.missing(_revokedAtMeta);
    }
    if (data.containsKey('source')) {
      context.handle(
        _sourceMeta,
        source.isAcceptableOrUnknown(data['source']!, _sourceMeta),
      );
    } else if (isInserting) {
      context.missing(_sourceMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {deviceId};
  @override
  DeviceRevocationRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return DeviceRevocationRow(
      deviceId: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}device_id'],
      )!,
      revokedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.dateTime,
        data['${effectivePrefix}revoked_at'],
      )!,
      source: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}source'],
      )!,
    );
  }

  @override
  $DeviceRevocationsTable createAlias(String alias) {
    return $DeviceRevocationsTable(attachedDatabase, alias);
  }
}

class DeviceRevocationRow extends DataClass
    implements Insertable<DeviceRevocationRow> {
  /// The device id that was revoked -- may be this device or another of the
  /// account's own devices (FR-AUTH-004: devices on one account are
  /// independent).
  final String deviceId;

  /// When this device recorded the revocation -- not necessarily the same
  /// instant Firebase's `ServerValue.timestamp` recorded it there.
  final DateTime revokedAt;

  /// A `RevocationSource.name` string (`DeviceRevocationService`, E11-T04)
  /// -- `'local'` (this device issued the revocation via `revoke`) or
  /// `'firebase'` (learned via `pullRevocations`), per docs/conventions.md
  /// "Enums" -- never an integer index.
  final String source;
  const DeviceRevocationRow({
    required this.deviceId,
    required this.revokedAt,
    required this.source,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['device_id'] = Variable<String>(deviceId);
    map['revoked_at'] = Variable<DateTime>(revokedAt);
    map['source'] = Variable<String>(source);
    return map;
  }

  DeviceRevocationsCompanion toCompanion(bool nullToAbsent) {
    return DeviceRevocationsCompanion(
      deviceId: Value(deviceId),
      revokedAt: Value(revokedAt),
      source: Value(source),
    );
  }

  factory DeviceRevocationRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return DeviceRevocationRow(
      deviceId: serializer.fromJson<String>(json['deviceId']),
      revokedAt: serializer.fromJson<DateTime>(json['revokedAt']),
      source: serializer.fromJson<String>(json['source']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'deviceId': serializer.toJson<String>(deviceId),
      'revokedAt': serializer.toJson<DateTime>(revokedAt),
      'source': serializer.toJson<String>(source),
    };
  }

  DeviceRevocationRow copyWith({
    String? deviceId,
    DateTime? revokedAt,
    String? source,
  }) => DeviceRevocationRow(
    deviceId: deviceId ?? this.deviceId,
    revokedAt: revokedAt ?? this.revokedAt,
    source: source ?? this.source,
  );
  DeviceRevocationRow copyWithCompanion(DeviceRevocationsCompanion data) {
    return DeviceRevocationRow(
      deviceId: data.deviceId.present ? data.deviceId.value : this.deviceId,
      revokedAt: data.revokedAt.present ? data.revokedAt.value : this.revokedAt,
      source: data.source.present ? data.source.value : this.source,
    );
  }

  @override
  String toString() {
    return (StringBuffer('DeviceRevocationRow(')
          ..write('deviceId: $deviceId, ')
          ..write('revokedAt: $revokedAt, ')
          ..write('source: $source')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(deviceId, revokedAt, source);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is DeviceRevocationRow &&
          other.deviceId == this.deviceId &&
          other.revokedAt == this.revokedAt &&
          other.source == this.source);
}

class DeviceRevocationsCompanion extends UpdateCompanion<DeviceRevocationRow> {
  final Value<String> deviceId;
  final Value<DateTime> revokedAt;
  final Value<String> source;
  final Value<int> rowid;
  const DeviceRevocationsCompanion({
    this.deviceId = const Value.absent(),
    this.revokedAt = const Value.absent(),
    this.source = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  DeviceRevocationsCompanion.insert({
    required String deviceId,
    required DateTime revokedAt,
    required String source,
    this.rowid = const Value.absent(),
  }) : deviceId = Value(deviceId),
       revokedAt = Value(revokedAt),
       source = Value(source);
  static Insertable<DeviceRevocationRow> custom({
    Expression<String>? deviceId,
    Expression<DateTime>? revokedAt,
    Expression<String>? source,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (deviceId != null) 'device_id': deviceId,
      if (revokedAt != null) 'revoked_at': revokedAt,
      if (source != null) 'source': source,
      if (rowid != null) 'rowid': rowid,
    });
  }

  DeviceRevocationsCompanion copyWith({
    Value<String>? deviceId,
    Value<DateTime>? revokedAt,
    Value<String>? source,
    Value<int>? rowid,
  }) {
    return DeviceRevocationsCompanion(
      deviceId: deviceId ?? this.deviceId,
      revokedAt: revokedAt ?? this.revokedAt,
      source: source ?? this.source,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (deviceId.present) {
      map['device_id'] = Variable<String>(deviceId.value);
    }
    if (revokedAt.present) {
      map['revoked_at'] = Variable<DateTime>(revokedAt.value);
    }
    if (source.present) {
      map['source'] = Variable<String>(source.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('DeviceRevocationsCompanion(')
          ..write('deviceId: $deviceId, ')
          ..write('revokedAt: $revokedAt, ')
          ..write('source: $source, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $RateLimitCountersTable extends RateLimitCounters
    with TableInfo<$RateLimitCountersTable, RateLimitCounterRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $RateLimitCountersTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _bucketKeyMeta = const VerificationMeta(
    'bucketKey',
  );
  @override
  late final GeneratedColumn<String> bucketKey = GeneratedColumn<String>(
    'bucket_key',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _windowStartMsMeta = const VerificationMeta(
    'windowStartMs',
  );
  @override
  late final GeneratedColumn<int> windowStartMs = GeneratedColumn<int>(
    'window_start_ms',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _countMeta = const VerificationMeta('count');
  @override
  late final GeneratedColumn<int> count = GeneratedColumn<int>(
    'count',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [bucketKey, windowStartMs, count];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'rate_limit_counters';
  @override
  VerificationContext validateIntegrity(
    Insertable<RateLimitCounterRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('bucket_key')) {
      context.handle(
        _bucketKeyMeta,
        bucketKey.isAcceptableOrUnknown(data['bucket_key']!, _bucketKeyMeta),
      );
    } else if (isInserting) {
      context.missing(_bucketKeyMeta);
    }
    if (data.containsKey('window_start_ms')) {
      context.handle(
        _windowStartMsMeta,
        windowStartMs.isAcceptableOrUnknown(
          data['window_start_ms']!,
          _windowStartMsMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_windowStartMsMeta);
    }
    if (data.containsKey('count')) {
      context.handle(
        _countMeta,
        count.isAcceptableOrUnknown(data['count']!, _countMeta),
      );
    } else if (isInserting) {
      context.missing(_countMeta);
    }
    return context;
  }

  @override
  Set<GeneratedColumn> get $primaryKey => {bucketKey};
  @override
  RateLimitCounterRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return RateLimitCounterRow(
      bucketKey: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}bucket_key'],
      )!,
      windowStartMs: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}window_start_ms'],
      )!,
      count: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}count'],
      )!,
    );
  }

  @override
  $RateLimitCountersTable createAlias(String alias) {
    return $RateLimitCountersTable(attachedDatabase, alias);
  }
}

class RateLimitCounterRow extends DataClass
    implements Insertable<RateLimitCounterRow> {
  final String bucketKey;

  /// Epoch-ms, this device's clock, when the current window started.
  final int windowStartMs;

  /// Cumulative count (or cumulative quantity, e.g. bytes) admitted so far
  /// within the current window.
  final int count;
  const RateLimitCounterRow({
    required this.bucketKey,
    required this.windowStartMs,
    required this.count,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['bucket_key'] = Variable<String>(bucketKey);
    map['window_start_ms'] = Variable<int>(windowStartMs);
    map['count'] = Variable<int>(count);
    return map;
  }

  RateLimitCountersCompanion toCompanion(bool nullToAbsent) {
    return RateLimitCountersCompanion(
      bucketKey: Value(bucketKey),
      windowStartMs: Value(windowStartMs),
      count: Value(count),
    );
  }

  factory RateLimitCounterRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return RateLimitCounterRow(
      bucketKey: serializer.fromJson<String>(json['bucketKey']),
      windowStartMs: serializer.fromJson<int>(json['windowStartMs']),
      count: serializer.fromJson<int>(json['count']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'bucketKey': serializer.toJson<String>(bucketKey),
      'windowStartMs': serializer.toJson<int>(windowStartMs),
      'count': serializer.toJson<int>(count),
    };
  }

  RateLimitCounterRow copyWith({
    String? bucketKey,
    int? windowStartMs,
    int? count,
  }) => RateLimitCounterRow(
    bucketKey: bucketKey ?? this.bucketKey,
    windowStartMs: windowStartMs ?? this.windowStartMs,
    count: count ?? this.count,
  );
  RateLimitCounterRow copyWithCompanion(RateLimitCountersCompanion data) {
    return RateLimitCounterRow(
      bucketKey: data.bucketKey.present ? data.bucketKey.value : this.bucketKey,
      windowStartMs: data.windowStartMs.present
          ? data.windowStartMs.value
          : this.windowStartMs,
      count: data.count.present ? data.count.value : this.count,
    );
  }

  @override
  String toString() {
    return (StringBuffer('RateLimitCounterRow(')
          ..write('bucketKey: $bucketKey, ')
          ..write('windowStartMs: $windowStartMs, ')
          ..write('count: $count')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(bucketKey, windowStartMs, count);
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is RateLimitCounterRow &&
          other.bucketKey == this.bucketKey &&
          other.windowStartMs == this.windowStartMs &&
          other.count == this.count);
}

class RateLimitCountersCompanion extends UpdateCompanion<RateLimitCounterRow> {
  final Value<String> bucketKey;
  final Value<int> windowStartMs;
  final Value<int> count;
  final Value<int> rowid;
  const RateLimitCountersCompanion({
    this.bucketKey = const Value.absent(),
    this.windowStartMs = const Value.absent(),
    this.count = const Value.absent(),
    this.rowid = const Value.absent(),
  });
  RateLimitCountersCompanion.insert({
    required String bucketKey,
    required int windowStartMs,
    required int count,
    this.rowid = const Value.absent(),
  }) : bucketKey = Value(bucketKey),
       windowStartMs = Value(windowStartMs),
       count = Value(count);
  static Insertable<RateLimitCounterRow> custom({
    Expression<String>? bucketKey,
    Expression<int>? windowStartMs,
    Expression<int>? count,
    Expression<int>? rowid,
  }) {
    return RawValuesInsertable({
      if (bucketKey != null) 'bucket_key': bucketKey,
      if (windowStartMs != null) 'window_start_ms': windowStartMs,
      if (count != null) 'count': count,
      if (rowid != null) 'rowid': rowid,
    });
  }

  RateLimitCountersCompanion copyWith({
    Value<String>? bucketKey,
    Value<int>? windowStartMs,
    Value<int>? count,
    Value<int>? rowid,
  }) {
    return RateLimitCountersCompanion(
      bucketKey: bucketKey ?? this.bucketKey,
      windowStartMs: windowStartMs ?? this.windowStartMs,
      count: count ?? this.count,
      rowid: rowid ?? this.rowid,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (bucketKey.present) {
      map['bucket_key'] = Variable<String>(bucketKey.value);
    }
    if (windowStartMs.present) {
      map['window_start_ms'] = Variable<int>(windowStartMs.value);
    }
    if (count.present) {
      map['count'] = Variable<int>(count.value);
    }
    if (rowid.present) {
      map['rowid'] = Variable<int>(rowid.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('RateLimitCountersCompanion(')
          ..write('bucketKey: $bucketKey, ')
          ..write('windowStartMs: $windowStartMs, ')
          ..write('count: $count, ')
          ..write('rowid: $rowid')
          ..write(')'))
        .toString();
  }
}

class $VersionPolicyCacheTable extends VersionPolicyCache
    with TableInfo<$VersionPolicyCacheTable, VersionPolicyCacheRow> {
  @override
  final GeneratedDatabase attachedDatabase;
  final String? _alias;
  $VersionPolicyCacheTable(this.attachedDatabase, [this._alias]);
  static const VerificationMeta _idMeta = const VerificationMeta('id');
  @override
  late final GeneratedColumn<int> id = GeneratedColumn<int>(
    'id',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: false,
  );
  static const VerificationMeta _minimumSupportedBuildMeta =
      const VerificationMeta('minimumSupportedBuild');
  @override
  late final GeneratedColumn<int> minimumSupportedBuild = GeneratedColumn<int>(
    'minimum_supported_build',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _currentBuildMeta = const VerificationMeta(
    'currentBuild',
  );
  @override
  late final GeneratedColumn<int> currentBuild = GeneratedColumn<int>(
    'current_build',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updateAvailableBuildMeta =
      const VerificationMeta('updateAvailableBuild');
  @override
  late final GeneratedColumn<int> updateAvailableBuild = GeneratedColumn<int>(
    'update_available_build',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _signatureMeta = const VerificationMeta(
    'signature',
  );
  @override
  late final GeneratedColumn<String> signature = GeneratedColumn<String>(
    'signature',
    aliasedName,
    false,
    type: DriftSqlType.string,
    requiredDuringInsert: true,
  );
  static const VerificationMeta _updatedAtMeta = const VerificationMeta(
    'updatedAt',
  );
  @override
  late final GeneratedColumn<int> updatedAt = GeneratedColumn<int>(
    'updated_at',
    aliasedName,
    false,
    type: DriftSqlType.int,
    requiredDuringInsert: true,
  );
  @override
  List<GeneratedColumn> get $columns => [
    id,
    minimumSupportedBuild,
    currentBuild,
    updateAvailableBuild,
    signature,
    updatedAt,
  ];
  @override
  String get aliasedName => _alias ?? actualTableName;
  @override
  String get actualTableName => $name;
  static const String $name = 'version_policy_cache';
  @override
  VerificationContext validateIntegrity(
    Insertable<VersionPolicyCacheRow> instance, {
    bool isInserting = false,
  }) {
    final context = VerificationContext();
    final data = instance.toColumns(true);
    if (data.containsKey('id')) {
      context.handle(_idMeta, id.isAcceptableOrUnknown(data['id']!, _idMeta));
    }
    if (data.containsKey('minimum_supported_build')) {
      context.handle(
        _minimumSupportedBuildMeta,
        minimumSupportedBuild.isAcceptableOrUnknown(
          data['minimum_supported_build']!,
          _minimumSupportedBuildMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_minimumSupportedBuildMeta);
    }
    if (data.containsKey('current_build')) {
      context.handle(
        _currentBuildMeta,
        currentBuild.isAcceptableOrUnknown(
          data['current_build']!,
          _currentBuildMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_currentBuildMeta);
    }
    if (data.containsKey('update_available_build')) {
      context.handle(
        _updateAvailableBuildMeta,
        updateAvailableBuild.isAcceptableOrUnknown(
          data['update_available_build']!,
          _updateAvailableBuildMeta,
        ),
      );
    } else if (isInserting) {
      context.missing(_updateAvailableBuildMeta);
    }
    if (data.containsKey('signature')) {
      context.handle(
        _signatureMeta,
        signature.isAcceptableOrUnknown(data['signature']!, _signatureMeta),
      );
    } else if (isInserting) {
      context.missing(_signatureMeta);
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
  Set<GeneratedColumn> get $primaryKey => {id};
  @override
  VersionPolicyCacheRow map(Map<String, dynamic> data, {String? tablePrefix}) {
    final effectivePrefix = tablePrefix != null ? '$tablePrefix.' : '';
    return VersionPolicyCacheRow(
      id: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}id'],
      )!,
      minimumSupportedBuild: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}minimum_supported_build'],
      )!,
      currentBuild: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}current_build'],
      )!,
      updateAvailableBuild: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}update_available_build'],
      )!,
      signature: attachedDatabase.typeMapping.read(
        DriftSqlType.string,
        data['${effectivePrefix}signature'],
      )!,
      updatedAt: attachedDatabase.typeMapping.read(
        DriftSqlType.int,
        data['${effectivePrefix}updated_at'],
      )!,
    );
  }

  @override
  $VersionPolicyCacheTable createAlias(String alias) {
    return $VersionPolicyCacheTable(attachedDatabase, alias);
  }
}

class VersionPolicyCacheRow extends DataClass
    implements Insertable<VersionPolicyCacheRow> {
  final int id;
  final int minimumSupportedBuild;
  final int currentBuild;
  final int updateAvailableBuild;
  final String signature;

  /// Epoch-millis `updatedAt` from the remote policy payload -- the
  /// server/ops-published value, not this device's own fetch time.
  final int updatedAt;
  const VersionPolicyCacheRow({
    required this.id,
    required this.minimumSupportedBuild,
    required this.currentBuild,
    required this.updateAvailableBuild,
    required this.signature,
    required this.updatedAt,
  });
  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    map['id'] = Variable<int>(id);
    map['minimum_supported_build'] = Variable<int>(minimumSupportedBuild);
    map['current_build'] = Variable<int>(currentBuild);
    map['update_available_build'] = Variable<int>(updateAvailableBuild);
    map['signature'] = Variable<String>(signature);
    map['updated_at'] = Variable<int>(updatedAt);
    return map;
  }

  VersionPolicyCacheCompanion toCompanion(bool nullToAbsent) {
    return VersionPolicyCacheCompanion(
      id: Value(id),
      minimumSupportedBuild: Value(minimumSupportedBuild),
      currentBuild: Value(currentBuild),
      updateAvailableBuild: Value(updateAvailableBuild),
      signature: Value(signature),
      updatedAt: Value(updatedAt),
    );
  }

  factory VersionPolicyCacheRow.fromJson(
    Map<String, dynamic> json, {
    ValueSerializer? serializer,
  }) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return VersionPolicyCacheRow(
      id: serializer.fromJson<int>(json['id']),
      minimumSupportedBuild: serializer.fromJson<int>(
        json['minimumSupportedBuild'],
      ),
      currentBuild: serializer.fromJson<int>(json['currentBuild']),
      updateAvailableBuild: serializer.fromJson<int>(
        json['updateAvailableBuild'],
      ),
      signature: serializer.fromJson<String>(json['signature']),
      updatedAt: serializer.fromJson<int>(json['updatedAt']),
    );
  }
  @override
  Map<String, dynamic> toJson({ValueSerializer? serializer}) {
    serializer ??= driftRuntimeOptions.defaultSerializer;
    return <String, dynamic>{
      'id': serializer.toJson<int>(id),
      'minimumSupportedBuild': serializer.toJson<int>(minimumSupportedBuild),
      'currentBuild': serializer.toJson<int>(currentBuild),
      'updateAvailableBuild': serializer.toJson<int>(updateAvailableBuild),
      'signature': serializer.toJson<String>(signature),
      'updatedAt': serializer.toJson<int>(updatedAt),
    };
  }

  VersionPolicyCacheRow copyWith({
    int? id,
    int? minimumSupportedBuild,
    int? currentBuild,
    int? updateAvailableBuild,
    String? signature,
    int? updatedAt,
  }) => VersionPolicyCacheRow(
    id: id ?? this.id,
    minimumSupportedBuild: minimumSupportedBuild ?? this.minimumSupportedBuild,
    currentBuild: currentBuild ?? this.currentBuild,
    updateAvailableBuild: updateAvailableBuild ?? this.updateAvailableBuild,
    signature: signature ?? this.signature,
    updatedAt: updatedAt ?? this.updatedAt,
  );
  VersionPolicyCacheRow copyWithCompanion(VersionPolicyCacheCompanion data) {
    return VersionPolicyCacheRow(
      id: data.id.present ? data.id.value : this.id,
      minimumSupportedBuild: data.minimumSupportedBuild.present
          ? data.minimumSupportedBuild.value
          : this.minimumSupportedBuild,
      currentBuild: data.currentBuild.present
          ? data.currentBuild.value
          : this.currentBuild,
      updateAvailableBuild: data.updateAvailableBuild.present
          ? data.updateAvailableBuild.value
          : this.updateAvailableBuild,
      signature: data.signature.present ? data.signature.value : this.signature,
      updatedAt: data.updatedAt.present ? data.updatedAt.value : this.updatedAt,
    );
  }

  @override
  String toString() {
    return (StringBuffer('VersionPolicyCacheRow(')
          ..write('id: $id, ')
          ..write('minimumSupportedBuild: $minimumSupportedBuild, ')
          ..write('currentBuild: $currentBuild, ')
          ..write('updateAvailableBuild: $updateAvailableBuild, ')
          ..write('signature: $signature, ')
          ..write('updatedAt: $updatedAt')
          ..write(')'))
        .toString();
  }

  @override
  int get hashCode => Object.hash(
    id,
    minimumSupportedBuild,
    currentBuild,
    updateAvailableBuild,
    signature,
    updatedAt,
  );
  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is VersionPolicyCacheRow &&
          other.id == this.id &&
          other.minimumSupportedBuild == this.minimumSupportedBuild &&
          other.currentBuild == this.currentBuild &&
          other.updateAvailableBuild == this.updateAvailableBuild &&
          other.signature == this.signature &&
          other.updatedAt == this.updatedAt);
}

class VersionPolicyCacheCompanion
    extends UpdateCompanion<VersionPolicyCacheRow> {
  final Value<int> id;
  final Value<int> minimumSupportedBuild;
  final Value<int> currentBuild;
  final Value<int> updateAvailableBuild;
  final Value<String> signature;
  final Value<int> updatedAt;
  const VersionPolicyCacheCompanion({
    this.id = const Value.absent(),
    this.minimumSupportedBuild = const Value.absent(),
    this.currentBuild = const Value.absent(),
    this.updateAvailableBuild = const Value.absent(),
    this.signature = const Value.absent(),
    this.updatedAt = const Value.absent(),
  });
  VersionPolicyCacheCompanion.insert({
    this.id = const Value.absent(),
    required int minimumSupportedBuild,
    required int currentBuild,
    required int updateAvailableBuild,
    required String signature,
    required int updatedAt,
  }) : minimumSupportedBuild = Value(minimumSupportedBuild),
       currentBuild = Value(currentBuild),
       updateAvailableBuild = Value(updateAvailableBuild),
       signature = Value(signature),
       updatedAt = Value(updatedAt);
  static Insertable<VersionPolicyCacheRow> custom({
    Expression<int>? id,
    Expression<int>? minimumSupportedBuild,
    Expression<int>? currentBuild,
    Expression<int>? updateAvailableBuild,
    Expression<String>? signature,
    Expression<int>? updatedAt,
  }) {
    return RawValuesInsertable({
      if (id != null) 'id': id,
      if (minimumSupportedBuild != null)
        'minimum_supported_build': minimumSupportedBuild,
      if (currentBuild != null) 'current_build': currentBuild,
      if (updateAvailableBuild != null)
        'update_available_build': updateAvailableBuild,
      if (signature != null) 'signature': signature,
      if (updatedAt != null) 'updated_at': updatedAt,
    });
  }

  VersionPolicyCacheCompanion copyWith({
    Value<int>? id,
    Value<int>? minimumSupportedBuild,
    Value<int>? currentBuild,
    Value<int>? updateAvailableBuild,
    Value<String>? signature,
    Value<int>? updatedAt,
  }) {
    return VersionPolicyCacheCompanion(
      id: id ?? this.id,
      minimumSupportedBuild:
          minimumSupportedBuild ?? this.minimumSupportedBuild,
      currentBuild: currentBuild ?? this.currentBuild,
      updateAvailableBuild: updateAvailableBuild ?? this.updateAvailableBuild,
      signature: signature ?? this.signature,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  @override
  Map<String, Expression> toColumns(bool nullToAbsent) {
    final map = <String, Expression>{};
    if (id.present) {
      map['id'] = Variable<int>(id.value);
    }
    if (minimumSupportedBuild.present) {
      map['minimum_supported_build'] = Variable<int>(
        minimumSupportedBuild.value,
      );
    }
    if (currentBuild.present) {
      map['current_build'] = Variable<int>(currentBuild.value);
    }
    if (updateAvailableBuild.present) {
      map['update_available_build'] = Variable<int>(updateAvailableBuild.value);
    }
    if (signature.present) {
      map['signature'] = Variable<String>(signature.value);
    }
    if (updatedAt.present) {
      map['updated_at'] = Variable<int>(updatedAt.value);
    }
    return map;
  }

  @override
  String toString() {
    return (StringBuffer('VersionPolicyCacheCompanion(')
          ..write('id: $id, ')
          ..write('minimumSupportedBuild: $minimumSupportedBuild, ')
          ..write('currentBuild: $currentBuild, ')
          ..write('updateAvailableBuild: $updateAvailableBuild, ')
          ..write('signature: $signature, ')
          ..write('updatedAt: $updatedAt')
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
  late final $SyncCursorsTable syncCursors = $SyncCursorsTable(this);
  late final $GroupsTable groups = $GroupsTable(this);
  late final $GroupMembersTable groupMembers = $GroupMembersTable(this);
  late final $GroupSenderKeysTable groupSenderKeys = $GroupSenderKeysTable(
    this,
  );
  late final $GroupEventsTable groupEvents = $GroupEventsTable(this);
  late final $StorageItemStatsTable storageItemStats = $StorageItemStatsTable(
    this,
  );
  late final $StoragePolicySettingsTable storagePolicySettings =
      $StoragePolicySettingsTable(this);
  late final $StorageDecisionsTable storageDecisions = $StorageDecisionsTable(
    this,
  );
  late final $LocationSettingsTable locationSettings = $LocationSettingsTable(
    this,
  );
  late final $LocationPeerSettingsTable locationPeerSettings =
      $LocationPeerSettingsTable(this);
  late final $LocationFixesTable locationFixes = $LocationFixesTable(this);
  late final $NotificationCategorySettingsTable notificationCategorySettings =
      $NotificationCategorySettingsTable(this);
  late final $NotificationPreferencesTable notificationPreferences =
      $NotificationPreferencesTable(this);
  late final $DeviceRevocationsTable deviceRevocations =
      $DeviceRevocationsTable(this);
  late final $RateLimitCountersTable rateLimitCounters =
      $RateLimitCountersTable(this);
  late final $VersionPolicyCacheTable versionPolicyCache =
      $VersionPolicyCacheTable(this);
  late final Index idxMessagesConversationCreatedAt = Index(
    'idx_messages_conversation_created_at',
    'CREATE INDEX idx_messages_conversation_created_at ON messages (conversation_id, created_at)',
  );
  late final Index idxGroupMembersCurrent = Index(
    'idx_group_members_current',
    'CREATE INDEX idx_group_members_current ON group_members (group_id, removed_at_epoch)',
  );
  late final Index idxGroupSingleOwner = Index(
    'idx_group_single_owner',
    'CREATE UNIQUE INDEX idx_group_single_owner ON group_members (group_id) WHERE role = \'owner\' AND removed_at_epoch IS NULL',
  );
  late final Index idxGroupEventsGroupEpoch = Index(
    'idx_group_events_group_epoch',
    'CREATE INDEX idx_group_events_group_epoch ON group_events (group_id, epoch)',
  );
  late final Index idxStorageItemStatsLastAccessed = Index(
    'idx_storage_item_stats_last_accessed',
    'CREATE INDEX idx_storage_item_stats_last_accessed ON storage_item_stats (last_accessed_at)',
  );
  late final Index idxStorageDecisionsDecidedAt = Index(
    'idx_storage_decisions_decided_at',
    'CREATE INDEX idx_storage_decisions_decided_at ON storage_decisions (decided_at)',
  );
  late final Index idxLocationFixesCapturedAt = Index(
    'idx_location_fixes_captured_at',
    'CREATE INDEX idx_location_fixes_captured_at ON location_fixes (captured_at)',
  );
  late final Index idxRateLimitCountersWindowStart = Index(
    'idx_rate_limit_counters_window_start',
    'CREATE INDEX idx_rate_limit_counters_window_start ON rate_limit_counters (window_start_ms)',
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
    syncCursors,
    groups,
    groupMembers,
    groupSenderKeys,
    groupEvents,
    storageItemStats,
    storagePolicySettings,
    storageDecisions,
    locationSettings,
    locationPeerSettings,
    locationFixes,
    notificationCategorySettings,
    notificationPreferences,
    deviceRevocations,
    rateLimitCounters,
    versionPolicyCache,
    idxMessagesConversationCreatedAt,
    idxGroupMembersCurrent,
    idxGroupSingleOwner,
    idxGroupEventsGroupEpoch,
    idxStorageItemStatsLastAccessed,
    idxStorageDecisionsDecidedAt,
    idxLocationFixesCapturedAt,
    idxRateLimitCountersWindowStart,
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
      Value<String?> remoteSelfDeviceId,
      Value<String?> peerName,
      Value<int> rowid,
    });
typedef $$RelationshipsTableUpdateCompanionBuilder =
    RelationshipsCompanion Function({
      Value<String> deviceId,
      Value<String> state,
      Value<DateTime> updatedAt,
      Value<String?> remoteSelfDeviceId,
      Value<String?> peerName,
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

  ColumnFilters<String> get remoteSelfDeviceId => $composableBuilder(
    column: $table.remoteSelfDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get peerName => $composableBuilder(
    column: $table.peerName,
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

  ColumnOrderings<String> get remoteSelfDeviceId => $composableBuilder(
    column: $table.remoteSelfDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get peerName => $composableBuilder(
    column: $table.peerName,
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

  GeneratedColumn<String> get remoteSelfDeviceId => $composableBuilder(
    column: $table.remoteSelfDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get peerName =>
      $composableBuilder(column: $table.peerName, builder: (column) => column);
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
                Value<String?> remoteSelfDeviceId = const Value.absent(),
                Value<String?> peerName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RelationshipsCompanion(
                deviceId: deviceId,
                state: state,
                updatedAt: updatedAt,
                remoteSelfDeviceId: remoteSelfDeviceId,
                peerName: peerName,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String deviceId,
                required String state,
                required DateTime updatedAt,
                Value<String?> remoteSelfDeviceId = const Value.absent(),
                Value<String?> peerName = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RelationshipsCompanion.insert(
                deviceId: deviceId,
                state: state,
                updatedAt: updatedAt,
                remoteSelfDeviceId: remoteSelfDeviceId,
                peerName: peerName,
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
typedef $$SyncCursorsTableCreateCompanionBuilder =
    SyncCursorsCompanion Function({
      required String localDeviceId,
      required String remoteDeviceId,
      required String conversationId,
      required int lastConfirmedSequenceNumber,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$SyncCursorsTableUpdateCompanionBuilder =
    SyncCursorsCompanion Function({
      Value<String> localDeviceId,
      Value<String> remoteDeviceId,
      Value<String> conversationId,
      Value<int> lastConfirmedSequenceNumber,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$SyncCursorsTableFilterComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get localDeviceId => $composableBuilder(
    column: $table.localDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get remoteDeviceId => $composableBuilder(
    column: $table.remoteDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastConfirmedSequenceNumber => $composableBuilder(
    column: $table.lastConfirmedSequenceNumber,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$SyncCursorsTableOrderingComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get localDeviceId => $composableBuilder(
    column: $table.localDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get remoteDeviceId => $composableBuilder(
    column: $table.remoteDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastConfirmedSequenceNumber => $composableBuilder(
    column: $table.lastConfirmedSequenceNumber,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$SyncCursorsTableAnnotationComposer
    extends Composer<_$AppDatabase, $SyncCursorsTable> {
  $$SyncCursorsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get localDeviceId => $composableBuilder(
    column: $table.localDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get remoteDeviceId => $composableBuilder(
    column: $table.remoteDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get conversationId => $composableBuilder(
    column: $table.conversationId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get lastConfirmedSequenceNumber => $composableBuilder(
    column: $table.lastConfirmedSequenceNumber,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$SyncCursorsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $SyncCursorsTable,
          SyncCursorRow,
          $$SyncCursorsTableFilterComposer,
          $$SyncCursorsTableOrderingComposer,
          $$SyncCursorsTableAnnotationComposer,
          $$SyncCursorsTableCreateCompanionBuilder,
          $$SyncCursorsTableUpdateCompanionBuilder,
          (
            SyncCursorRow,
            BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursorRow>,
          ),
          SyncCursorRow,
          PrefetchHooks Function()
        > {
  $$SyncCursorsTableTableManager(_$AppDatabase db, $SyncCursorsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$SyncCursorsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$SyncCursorsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$SyncCursorsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> localDeviceId = const Value.absent(),
                Value<String> remoteDeviceId = const Value.absent(),
                Value<String> conversationId = const Value.absent(),
                Value<int> lastConfirmedSequenceNumber = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion(
                localDeviceId: localDeviceId,
                remoteDeviceId: remoteDeviceId,
                conversationId: conversationId,
                lastConfirmedSequenceNumber: lastConfirmedSequenceNumber,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String localDeviceId,
                required String remoteDeviceId,
                required String conversationId,
                required int lastConfirmedSequenceNumber,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => SyncCursorsCompanion.insert(
                localDeviceId: localDeviceId,
                remoteDeviceId: remoteDeviceId,
                conversationId: conversationId,
                lastConfirmedSequenceNumber: lastConfirmedSequenceNumber,
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

typedef $$SyncCursorsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $SyncCursorsTable,
      SyncCursorRow,
      $$SyncCursorsTableFilterComposer,
      $$SyncCursorsTableOrderingComposer,
      $$SyncCursorsTableAnnotationComposer,
      $$SyncCursorsTableCreateCompanionBuilder,
      $$SyncCursorsTableUpdateCompanionBuilder,
      (
        SyncCursorRow,
        BaseReferences<_$AppDatabase, $SyncCursorsTable, SyncCursorRow>,
      ),
      SyncCursorRow,
      PrefetchHooks Function()
    >;
typedef $$GroupsTableCreateCompanionBuilder =
    GroupsCompanion Function({
      required String id,
      required String name,
      required int createdAt,
      required String createdByDeviceId,
      Value<int> membershipEpoch,
      Value<bool> isDeleted,
      Value<int> rowid,
    });
typedef $$GroupsTableUpdateCompanionBuilder =
    GroupsCompanion Function({
      Value<String> id,
      Value<String> name,
      Value<int> createdAt,
      Value<String> createdByDeviceId,
      Value<int> membershipEpoch,
      Value<bool> isDeleted,
      Value<int> rowid,
    });

class $$GroupsTableFilterComposer
    extends Composer<_$AppDatabase, $GroupsTable> {
  $$GroupsTableFilterComposer({
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

  ColumnFilters<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get membershipEpoch => $composableBuilder(
    column: $table.membershipEpoch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GroupsTableOrderingComposer
    extends Composer<_$AppDatabase, $GroupsTable> {
  $$GroupsTableOrderingComposer({
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

  ColumnOrderings<String> get name => $composableBuilder(
    column: $table.name,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get membershipEpoch => $composableBuilder(
    column: $table.membershipEpoch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get isDeleted => $composableBuilder(
    column: $table.isDeleted,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GroupsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GroupsTable> {
  $$GroupsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get name =>
      $composableBuilder(column: $table.name, builder: (column) => column);

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);

  GeneratedColumn<String> get createdByDeviceId => $composableBuilder(
    column: $table.createdByDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get membershipEpoch => $composableBuilder(
    column: $table.membershipEpoch,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get isDeleted =>
      $composableBuilder(column: $table.isDeleted, builder: (column) => column);
}

class $$GroupsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GroupsTable,
          GroupRow,
          $$GroupsTableFilterComposer,
          $$GroupsTableOrderingComposer,
          $$GroupsTableAnnotationComposer,
          $$GroupsTableCreateCompanionBuilder,
          $$GroupsTableUpdateCompanionBuilder,
          (GroupRow, BaseReferences<_$AppDatabase, $GroupsTable, GroupRow>),
          GroupRow,
          PrefetchHooks Function()
        > {
  $$GroupsTableTableManager(_$AppDatabase db, $GroupsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroupsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroupsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> name = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<String> createdByDeviceId = const Value.absent(),
                Value<int> membershipEpoch = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupsCompanion(
                id: id,
                name: name,
                createdAt: createdAt,
                createdByDeviceId: createdByDeviceId,
                membershipEpoch: membershipEpoch,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String name,
                required int createdAt,
                required String createdByDeviceId,
                Value<int> membershipEpoch = const Value.absent(),
                Value<bool> isDeleted = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupsCompanion.insert(
                id: id,
                name: name,
                createdAt: createdAt,
                createdByDeviceId: createdByDeviceId,
                membershipEpoch: membershipEpoch,
                isDeleted: isDeleted,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GroupsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GroupsTable,
      GroupRow,
      $$GroupsTableFilterComposer,
      $$GroupsTableOrderingComposer,
      $$GroupsTableAnnotationComposer,
      $$GroupsTableCreateCompanionBuilder,
      $$GroupsTableUpdateCompanionBuilder,
      (GroupRow, BaseReferences<_$AppDatabase, $GroupsTable, GroupRow>),
      GroupRow,
      PrefetchHooks Function()
    >;
typedef $$GroupMembersTableCreateCompanionBuilder =
    GroupMembersCompanion Function({
      required String groupId,
      required String deviceId,
      required String role,
      required int joinedAtEpoch,
      Value<int?> removedAtEpoch,
      Value<int> rowid,
    });
typedef $$GroupMembersTableUpdateCompanionBuilder =
    GroupMembersCompanion Function({
      Value<String> groupId,
      Value<String> deviceId,
      Value<String> role,
      Value<int> joinedAtEpoch,
      Value<int?> removedAtEpoch,
      Value<int> rowid,
    });

class $$GroupMembersTableFilterComposer
    extends Composer<_$AppDatabase, $GroupMembersTable> {
  $$GroupMembersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get joinedAtEpoch => $composableBuilder(
    column: $table.joinedAtEpoch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get removedAtEpoch => $composableBuilder(
    column: $table.removedAtEpoch,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GroupMembersTableOrderingComposer
    extends Composer<_$AppDatabase, $GroupMembersTable> {
  $$GroupMembersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get deviceId => $composableBuilder(
    column: $table.deviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get role => $composableBuilder(
    column: $table.role,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get joinedAtEpoch => $composableBuilder(
    column: $table.joinedAtEpoch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get removedAtEpoch => $composableBuilder(
    column: $table.removedAtEpoch,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GroupMembersTableAnnotationComposer
    extends Composer<_$AppDatabase, $GroupMembersTable> {
  $$GroupMembersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<String> get role =>
      $composableBuilder(column: $table.role, builder: (column) => column);

  GeneratedColumn<int> get joinedAtEpoch => $composableBuilder(
    column: $table.joinedAtEpoch,
    builder: (column) => column,
  );

  GeneratedColumn<int> get removedAtEpoch => $composableBuilder(
    column: $table.removedAtEpoch,
    builder: (column) => column,
  );
}

class $$GroupMembersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GroupMembersTable,
          GroupMemberRow,
          $$GroupMembersTableFilterComposer,
          $$GroupMembersTableOrderingComposer,
          $$GroupMembersTableAnnotationComposer,
          $$GroupMembersTableCreateCompanionBuilder,
          $$GroupMembersTableUpdateCompanionBuilder,
          (
            GroupMemberRow,
            BaseReferences<_$AppDatabase, $GroupMembersTable, GroupMemberRow>,
          ),
          GroupMemberRow,
          PrefetchHooks Function()
        > {
  $$GroupMembersTableTableManager(_$AppDatabase db, $GroupMembersTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupMembersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroupMembersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroupMembersTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> groupId = const Value.absent(),
                Value<String> deviceId = const Value.absent(),
                Value<String> role = const Value.absent(),
                Value<int> joinedAtEpoch = const Value.absent(),
                Value<int?> removedAtEpoch = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupMembersCompanion(
                groupId: groupId,
                deviceId: deviceId,
                role: role,
                joinedAtEpoch: joinedAtEpoch,
                removedAtEpoch: removedAtEpoch,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String groupId,
                required String deviceId,
                required String role,
                required int joinedAtEpoch,
                Value<int?> removedAtEpoch = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupMembersCompanion.insert(
                groupId: groupId,
                deviceId: deviceId,
                role: role,
                joinedAtEpoch: joinedAtEpoch,
                removedAtEpoch: removedAtEpoch,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GroupMembersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GroupMembersTable,
      GroupMemberRow,
      $$GroupMembersTableFilterComposer,
      $$GroupMembersTableOrderingComposer,
      $$GroupMembersTableAnnotationComposer,
      $$GroupMembersTableCreateCompanionBuilder,
      $$GroupMembersTableUpdateCompanionBuilder,
      (
        GroupMemberRow,
        BaseReferences<_$AppDatabase, $GroupMembersTable, GroupMemberRow>,
      ),
      GroupMemberRow,
      PrefetchHooks Function()
    >;
typedef $$GroupSenderKeysTableCreateCompanionBuilder =
    GroupSenderKeysCompanion Function({
      required String groupId,
      required String senderDeviceId,
      required int membershipEpoch,
      required Uint8List record,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$GroupSenderKeysTableUpdateCompanionBuilder =
    GroupSenderKeysCompanion Function({
      Value<String> groupId,
      Value<String> senderDeviceId,
      Value<int> membershipEpoch,
      Value<Uint8List> record,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$GroupSenderKeysTableFilterComposer
    extends Composer<_$AppDatabase, $GroupSenderKeysTable> {
  $$GroupSenderKeysTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get senderDeviceId => $composableBuilder(
    column: $table.senderDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get membershipEpoch => $composableBuilder(
    column: $table.membershipEpoch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<Uint8List> get record => $composableBuilder(
    column: $table.record,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GroupSenderKeysTableOrderingComposer
    extends Composer<_$AppDatabase, $GroupSenderKeysTable> {
  $$GroupSenderKeysTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get senderDeviceId => $composableBuilder(
    column: $table.senderDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get membershipEpoch => $composableBuilder(
    column: $table.membershipEpoch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<Uint8List> get record => $composableBuilder(
    column: $table.record,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GroupSenderKeysTableAnnotationComposer
    extends Composer<_$AppDatabase, $GroupSenderKeysTable> {
  $$GroupSenderKeysTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<String> get senderDeviceId => $composableBuilder(
    column: $table.senderDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get membershipEpoch => $composableBuilder(
    column: $table.membershipEpoch,
    builder: (column) => column,
  );

  GeneratedColumn<Uint8List> get record =>
      $composableBuilder(column: $table.record, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$GroupSenderKeysTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GroupSenderKeysTable,
          GroupSenderKeyRow,
          $$GroupSenderKeysTableFilterComposer,
          $$GroupSenderKeysTableOrderingComposer,
          $$GroupSenderKeysTableAnnotationComposer,
          $$GroupSenderKeysTableCreateCompanionBuilder,
          $$GroupSenderKeysTableUpdateCompanionBuilder,
          (
            GroupSenderKeyRow,
            BaseReferences<
              _$AppDatabase,
              $GroupSenderKeysTable,
              GroupSenderKeyRow
            >,
          ),
          GroupSenderKeyRow,
          PrefetchHooks Function()
        > {
  $$GroupSenderKeysTableTableManager(
    _$AppDatabase db,
    $GroupSenderKeysTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupSenderKeysTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroupSenderKeysTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroupSenderKeysTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> groupId = const Value.absent(),
                Value<String> senderDeviceId = const Value.absent(),
                Value<int> membershipEpoch = const Value.absent(),
                Value<Uint8List> record = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupSenderKeysCompanion(
                groupId: groupId,
                senderDeviceId: senderDeviceId,
                membershipEpoch: membershipEpoch,
                record: record,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String groupId,
                required String senderDeviceId,
                required int membershipEpoch,
                required Uint8List record,
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => GroupSenderKeysCompanion.insert(
                groupId: groupId,
                senderDeviceId: senderDeviceId,
                membershipEpoch: membershipEpoch,
                record: record,
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

typedef $$GroupSenderKeysTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GroupSenderKeysTable,
      GroupSenderKeyRow,
      $$GroupSenderKeysTableFilterComposer,
      $$GroupSenderKeysTableOrderingComposer,
      $$GroupSenderKeysTableAnnotationComposer,
      $$GroupSenderKeysTableCreateCompanionBuilder,
      $$GroupSenderKeysTableUpdateCompanionBuilder,
      (
        GroupSenderKeyRow,
        BaseReferences<_$AppDatabase, $GroupSenderKeysTable, GroupSenderKeyRow>,
      ),
      GroupSenderKeyRow,
      PrefetchHooks Function()
    >;
typedef $$GroupEventsTableCreateCompanionBuilder =
    GroupEventsCompanion Function({
      required String id,
      required String groupId,
      required int epoch,
      required String kind,
      required String actorDeviceId,
      Value<String?> subjectDeviceId,
      required int createdAt,
      Value<int> rowid,
    });
typedef $$GroupEventsTableUpdateCompanionBuilder =
    GroupEventsCompanion Function({
      Value<String> id,
      Value<String> groupId,
      Value<int> epoch,
      Value<String> kind,
      Value<String> actorDeviceId,
      Value<String?> subjectDeviceId,
      Value<int> createdAt,
      Value<int> rowid,
    });

class $$GroupEventsTableFilterComposer
    extends Composer<_$AppDatabase, $GroupEventsTable> {
  $$GroupEventsTableFilterComposer({
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

  ColumnFilters<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get epoch => $composableBuilder(
    column: $table.epoch,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get actorDeviceId => $composableBuilder(
    column: $table.actorDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get subjectDeviceId => $composableBuilder(
    column: $table.subjectDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$GroupEventsTableOrderingComposer
    extends Composer<_$AppDatabase, $GroupEventsTable> {
  $$GroupEventsTableOrderingComposer({
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

  ColumnOrderings<String> get groupId => $composableBuilder(
    column: $table.groupId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get epoch => $composableBuilder(
    column: $table.epoch,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get kind => $composableBuilder(
    column: $table.kind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get actorDeviceId => $composableBuilder(
    column: $table.actorDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get subjectDeviceId => $composableBuilder(
    column: $table.subjectDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get createdAt => $composableBuilder(
    column: $table.createdAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$GroupEventsTableAnnotationComposer
    extends Composer<_$AppDatabase, $GroupEventsTable> {
  $$GroupEventsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get groupId =>
      $composableBuilder(column: $table.groupId, builder: (column) => column);

  GeneratedColumn<int> get epoch =>
      $composableBuilder(column: $table.epoch, builder: (column) => column);

  GeneratedColumn<String> get kind =>
      $composableBuilder(column: $table.kind, builder: (column) => column);

  GeneratedColumn<String> get actorDeviceId => $composableBuilder(
    column: $table.actorDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<String> get subjectDeviceId => $composableBuilder(
    column: $table.subjectDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<int> get createdAt =>
      $composableBuilder(column: $table.createdAt, builder: (column) => column);
}

class $$GroupEventsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $GroupEventsTable,
          GroupEventRow,
          $$GroupEventsTableFilterComposer,
          $$GroupEventsTableOrderingComposer,
          $$GroupEventsTableAnnotationComposer,
          $$GroupEventsTableCreateCompanionBuilder,
          $$GroupEventsTableUpdateCompanionBuilder,
          (
            GroupEventRow,
            BaseReferences<_$AppDatabase, $GroupEventsTable, GroupEventRow>,
          ),
          GroupEventRow,
          PrefetchHooks Function()
        > {
  $$GroupEventsTableTableManager(_$AppDatabase db, $GroupEventsTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$GroupEventsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$GroupEventsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$GroupEventsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<String> groupId = const Value.absent(),
                Value<int> epoch = const Value.absent(),
                Value<String> kind = const Value.absent(),
                Value<String> actorDeviceId = const Value.absent(),
                Value<String?> subjectDeviceId = const Value.absent(),
                Value<int> createdAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => GroupEventsCompanion(
                id: id,
                groupId: groupId,
                epoch: epoch,
                kind: kind,
                actorDeviceId: actorDeviceId,
                subjectDeviceId: subjectDeviceId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required String groupId,
                required int epoch,
                required String kind,
                required String actorDeviceId,
                Value<String?> subjectDeviceId = const Value.absent(),
                required int createdAt,
                Value<int> rowid = const Value.absent(),
              }) => GroupEventsCompanion.insert(
                id: id,
                groupId: groupId,
                epoch: epoch,
                kind: kind,
                actorDeviceId: actorDeviceId,
                subjectDeviceId: subjectDeviceId,
                createdAt: createdAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$GroupEventsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $GroupEventsTable,
      GroupEventRow,
      $$GroupEventsTableFilterComposer,
      $$GroupEventsTableOrderingComposer,
      $$GroupEventsTableAnnotationComposer,
      $$GroupEventsTableCreateCompanionBuilder,
      $$GroupEventsTableUpdateCompanionBuilder,
      (
        GroupEventRow,
        BaseReferences<_$AppDatabase, $GroupEventsTable, GroupEventRow>,
      ),
      GroupEventRow,
      PrefetchHooks Function()
    >;
typedef $$StorageItemStatsTableCreateCompanionBuilder =
    StorageItemStatsCompanion Function({
      required String itemKind,
      required String itemId,
      Value<int?> lastAccessedAt,
      Value<int> accessCount,
      Value<int> rowid,
    });
typedef $$StorageItemStatsTableUpdateCompanionBuilder =
    StorageItemStatsCompanion Function({
      Value<String> itemKind,
      Value<String> itemId,
      Value<int?> lastAccessedAt,
      Value<int> accessCount,
      Value<int> rowid,
    });

class $$StorageItemStatsTableFilterComposer
    extends Composer<_$AppDatabase, $StorageItemStatsTable> {
  $$StorageItemStatsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get itemKind => $composableBuilder(
    column: $table.itemKind,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get accessCount => $composableBuilder(
    column: $table.accessCount,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StorageItemStatsTableOrderingComposer
    extends Composer<_$AppDatabase, $StorageItemStatsTable> {
  $$StorageItemStatsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get itemKind => $composableBuilder(
    column: $table.itemKind,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get itemId => $composableBuilder(
    column: $table.itemId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get accessCount => $composableBuilder(
    column: $table.accessCount,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StorageItemStatsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StorageItemStatsTable> {
  $$StorageItemStatsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get itemKind =>
      $composableBuilder(column: $table.itemKind, builder: (column) => column);

  GeneratedColumn<String> get itemId =>
      $composableBuilder(column: $table.itemId, builder: (column) => column);

  GeneratedColumn<int> get lastAccessedAt => $composableBuilder(
    column: $table.lastAccessedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get accessCount => $composableBuilder(
    column: $table.accessCount,
    builder: (column) => column,
  );
}

class $$StorageItemStatsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StorageItemStatsTable,
          StorageItemStatRow,
          $$StorageItemStatsTableFilterComposer,
          $$StorageItemStatsTableOrderingComposer,
          $$StorageItemStatsTableAnnotationComposer,
          $$StorageItemStatsTableCreateCompanionBuilder,
          $$StorageItemStatsTableUpdateCompanionBuilder,
          (
            StorageItemStatRow,
            BaseReferences<
              _$AppDatabase,
              $StorageItemStatsTable,
              StorageItemStatRow
            >,
          ),
          StorageItemStatRow,
          PrefetchHooks Function()
        > {
  $$StorageItemStatsTableTableManager(
    _$AppDatabase db,
    $StorageItemStatsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StorageItemStatsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StorageItemStatsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StorageItemStatsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> itemKind = const Value.absent(),
                Value<String> itemId = const Value.absent(),
                Value<int?> lastAccessedAt = const Value.absent(),
                Value<int> accessCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StorageItemStatsCompanion(
                itemKind: itemKind,
                itemId: itemId,
                lastAccessedAt: lastAccessedAt,
                accessCount: accessCount,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String itemKind,
                required String itemId,
                Value<int?> lastAccessedAt = const Value.absent(),
                Value<int> accessCount = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StorageItemStatsCompanion.insert(
                itemKind: itemKind,
                itemId: itemId,
                lastAccessedAt: lastAccessedAt,
                accessCount: accessCount,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StorageItemStatsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StorageItemStatsTable,
      StorageItemStatRow,
      $$StorageItemStatsTableFilterComposer,
      $$StorageItemStatsTableOrderingComposer,
      $$StorageItemStatsTableAnnotationComposer,
      $$StorageItemStatsTableCreateCompanionBuilder,
      $$StorageItemStatsTableUpdateCompanionBuilder,
      (
        StorageItemStatRow,
        BaseReferences<
          _$AppDatabase,
          $StorageItemStatsTable,
          StorageItemStatRow
        >,
      ),
      StorageItemStatRow,
      PrefetchHooks Function()
    >;
typedef $$StoragePolicySettingsTableCreateCompanionBuilder =
    StoragePolicySettingsCompanion Function({
      Value<int> id,
      required String mode,
      Value<int?> olderThanDays,
      Value<int?> maxBytes,
      Value<int?> budgetBytes,
      required int updatedAt,
    });
typedef $$StoragePolicySettingsTableUpdateCompanionBuilder =
    StoragePolicySettingsCompanion Function({
      Value<int> id,
      Value<String> mode,
      Value<int?> olderThanDays,
      Value<int?> maxBytes,
      Value<int?> budgetBytes,
      Value<int> updatedAt,
    });

class $$StoragePolicySettingsTableFilterComposer
    extends Composer<_$AppDatabase, $StoragePolicySettingsTable> {
  $$StoragePolicySettingsTableFilterComposer({
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

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get olderThanDays => $composableBuilder(
    column: $table.olderThanDays,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get maxBytes => $composableBuilder(
    column: $table.maxBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get budgetBytes => $composableBuilder(
    column: $table.budgetBytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StoragePolicySettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $StoragePolicySettingsTable> {
  $$StoragePolicySettingsTableOrderingComposer({
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

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get olderThanDays => $composableBuilder(
    column: $table.olderThanDays,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get maxBytes => $composableBuilder(
    column: $table.maxBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get budgetBytes => $composableBuilder(
    column: $table.budgetBytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StoragePolicySettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StoragePolicySettingsTable> {
  $$StoragePolicySettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<int> get olderThanDays => $composableBuilder(
    column: $table.olderThanDays,
    builder: (column) => column,
  );

  GeneratedColumn<int> get maxBytes =>
      $composableBuilder(column: $table.maxBytes, builder: (column) => column);

  GeneratedColumn<int> get budgetBytes => $composableBuilder(
    column: $table.budgetBytes,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$StoragePolicySettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StoragePolicySettingsTable,
          StoragePolicySettingRow,
          $$StoragePolicySettingsTableFilterComposer,
          $$StoragePolicySettingsTableOrderingComposer,
          $$StoragePolicySettingsTableAnnotationComposer,
          $$StoragePolicySettingsTableCreateCompanionBuilder,
          $$StoragePolicySettingsTableUpdateCompanionBuilder,
          (
            StoragePolicySettingRow,
            BaseReferences<
              _$AppDatabase,
              $StoragePolicySettingsTable,
              StoragePolicySettingRow
            >,
          ),
          StoragePolicySettingRow,
          PrefetchHooks Function()
        > {
  $$StoragePolicySettingsTableTableManager(
    _$AppDatabase db,
    $StoragePolicySettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StoragePolicySettingsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$StoragePolicySettingsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$StoragePolicySettingsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<int?> olderThanDays = const Value.absent(),
                Value<int?> maxBytes = const Value.absent(),
                Value<int?> budgetBytes = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => StoragePolicySettingsCompanion(
                id: id,
                mode: mode,
                olderThanDays: olderThanDays,
                maxBytes: maxBytes,
                budgetBytes: budgetBytes,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required String mode,
                Value<int?> olderThanDays = const Value.absent(),
                Value<int?> maxBytes = const Value.absent(),
                Value<int?> budgetBytes = const Value.absent(),
                required int updatedAt,
              }) => StoragePolicySettingsCompanion.insert(
                id: id,
                mode: mode,
                olderThanDays: olderThanDays,
                maxBytes: maxBytes,
                budgetBytes: budgetBytes,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StoragePolicySettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StoragePolicySettingsTable,
      StoragePolicySettingRow,
      $$StoragePolicySettingsTableFilterComposer,
      $$StoragePolicySettingsTableOrderingComposer,
      $$StoragePolicySettingsTableAnnotationComposer,
      $$StoragePolicySettingsTableCreateCompanionBuilder,
      $$StoragePolicySettingsTableUpdateCompanionBuilder,
      (
        StoragePolicySettingRow,
        BaseReferences<
          _$AppDatabase,
          $StoragePolicySettingsTable,
          StoragePolicySettingRow
        >,
      ),
      StoragePolicySettingRow,
      PrefetchHooks Function()
    >;
typedef $$StorageDecisionsTableCreateCompanionBuilder =
    StorageDecisionsCompanion Function({
      required String id,
      required int decidedAt,
      required String mode,
      required String categoryKey,
      required int itemCount,
      required int bytes,
      required String reasonCode,
      Value<String?> reasonDetail,
      required String outcome,
      Value<int> rowid,
    });
typedef $$StorageDecisionsTableUpdateCompanionBuilder =
    StorageDecisionsCompanion Function({
      Value<String> id,
      Value<int> decidedAt,
      Value<String> mode,
      Value<String> categoryKey,
      Value<int> itemCount,
      Value<int> bytes,
      Value<String> reasonCode,
      Value<String?> reasonDetail,
      Value<String> outcome,
      Value<int> rowid,
    });

class $$StorageDecisionsTableFilterComposer
    extends Composer<_$AppDatabase, $StorageDecisionsTable> {
  $$StorageDecisionsTableFilterComposer({
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

  ColumnFilters<int> get decidedAt => $composableBuilder(
    column: $table.decidedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get categoryKey => $composableBuilder(
    column: $table.categoryKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get itemCount => $composableBuilder(
    column: $table.itemCount,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reasonCode => $composableBuilder(
    column: $table.reasonCode,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get reasonDetail => $composableBuilder(
    column: $table.reasonDetail,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnFilters(column),
  );
}

class $$StorageDecisionsTableOrderingComposer
    extends Composer<_$AppDatabase, $StorageDecisionsTable> {
  $$StorageDecisionsTableOrderingComposer({
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

  ColumnOrderings<int> get decidedAt => $composableBuilder(
    column: $table.decidedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get mode => $composableBuilder(
    column: $table.mode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get categoryKey => $composableBuilder(
    column: $table.categoryKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get itemCount => $composableBuilder(
    column: $table.itemCount,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get bytes => $composableBuilder(
    column: $table.bytes,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reasonCode => $composableBuilder(
    column: $table.reasonCode,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get reasonDetail => $composableBuilder(
    column: $table.reasonDetail,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get outcome => $composableBuilder(
    column: $table.outcome,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$StorageDecisionsTableAnnotationComposer
    extends Composer<_$AppDatabase, $StorageDecisionsTable> {
  $$StorageDecisionsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get decidedAt =>
      $composableBuilder(column: $table.decidedAt, builder: (column) => column);

  GeneratedColumn<String> get mode =>
      $composableBuilder(column: $table.mode, builder: (column) => column);

  GeneratedColumn<String> get categoryKey => $composableBuilder(
    column: $table.categoryKey,
    builder: (column) => column,
  );

  GeneratedColumn<int> get itemCount =>
      $composableBuilder(column: $table.itemCount, builder: (column) => column);

  GeneratedColumn<int> get bytes =>
      $composableBuilder(column: $table.bytes, builder: (column) => column);

  GeneratedColumn<String> get reasonCode => $composableBuilder(
    column: $table.reasonCode,
    builder: (column) => column,
  );

  GeneratedColumn<String> get reasonDetail => $composableBuilder(
    column: $table.reasonDetail,
    builder: (column) => column,
  );

  GeneratedColumn<String> get outcome =>
      $composableBuilder(column: $table.outcome, builder: (column) => column);
}

class $$StorageDecisionsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $StorageDecisionsTable,
          StorageDecisionRow,
          $$StorageDecisionsTableFilterComposer,
          $$StorageDecisionsTableOrderingComposer,
          $$StorageDecisionsTableAnnotationComposer,
          $$StorageDecisionsTableCreateCompanionBuilder,
          $$StorageDecisionsTableUpdateCompanionBuilder,
          (
            StorageDecisionRow,
            BaseReferences<
              _$AppDatabase,
              $StorageDecisionsTable,
              StorageDecisionRow
            >,
          ),
          StorageDecisionRow,
          PrefetchHooks Function()
        > {
  $$StorageDecisionsTableTableManager(
    _$AppDatabase db,
    $StorageDecisionsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$StorageDecisionsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$StorageDecisionsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$StorageDecisionsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> id = const Value.absent(),
                Value<int> decidedAt = const Value.absent(),
                Value<String> mode = const Value.absent(),
                Value<String> categoryKey = const Value.absent(),
                Value<int> itemCount = const Value.absent(),
                Value<int> bytes = const Value.absent(),
                Value<String> reasonCode = const Value.absent(),
                Value<String?> reasonDetail = const Value.absent(),
                Value<String> outcome = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => StorageDecisionsCompanion(
                id: id,
                decidedAt: decidedAt,
                mode: mode,
                categoryKey: categoryKey,
                itemCount: itemCount,
                bytes: bytes,
                reasonCode: reasonCode,
                reasonDetail: reasonDetail,
                outcome: outcome,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String id,
                required int decidedAt,
                required String mode,
                required String categoryKey,
                required int itemCount,
                required int bytes,
                required String reasonCode,
                Value<String?> reasonDetail = const Value.absent(),
                required String outcome,
                Value<int> rowid = const Value.absent(),
              }) => StorageDecisionsCompanion.insert(
                id: id,
                decidedAt: decidedAt,
                mode: mode,
                categoryKey: categoryKey,
                itemCount: itemCount,
                bytes: bytes,
                reasonCode: reasonCode,
                reasonDetail: reasonDetail,
                outcome: outcome,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$StorageDecisionsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $StorageDecisionsTable,
      StorageDecisionRow,
      $$StorageDecisionsTableFilterComposer,
      $$StorageDecisionsTableOrderingComposer,
      $$StorageDecisionsTableAnnotationComposer,
      $$StorageDecisionsTableCreateCompanionBuilder,
      $$StorageDecisionsTableUpdateCompanionBuilder,
      (
        StorageDecisionRow,
        BaseReferences<
          _$AppDatabase,
          $StorageDecisionsTable,
          StorageDecisionRow
        >,
      ),
      StorageDecisionRow,
      PrefetchHooks Function()
    >;
typedef $$LocationSettingsTableCreateCompanionBuilder =
    LocationSettingsCompanion Function({
      Value<int> id,
      Value<bool> globalEnabled,
      required int updatedAt,
    });
typedef $$LocationSettingsTableUpdateCompanionBuilder =
    LocationSettingsCompanion Function({
      Value<int> id,
      Value<bool> globalEnabled,
      Value<int> updatedAt,
    });

class $$LocationSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $LocationSettingsTable> {
  $$LocationSettingsTableFilterComposer({
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

  ColumnFilters<bool> get globalEnabled => $composableBuilder(
    column: $table.globalEnabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocationSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocationSettingsTable> {
  $$LocationSettingsTableOrderingComposer({
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

  ColumnOrderings<bool> get globalEnabled => $composableBuilder(
    column: $table.globalEnabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocationSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocationSettingsTable> {
  $$LocationSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<bool> get globalEnabled => $composableBuilder(
    column: $table.globalEnabled,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocationSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocationSettingsTable,
          LocationSettingRow,
          $$LocationSettingsTableFilterComposer,
          $$LocationSettingsTableOrderingComposer,
          $$LocationSettingsTableAnnotationComposer,
          $$LocationSettingsTableCreateCompanionBuilder,
          $$LocationSettingsTableUpdateCompanionBuilder,
          (
            LocationSettingRow,
            BaseReferences<
              _$AppDatabase,
              $LocationSettingsTable,
              LocationSettingRow
            >,
          ),
          LocationSettingRow,
          PrefetchHooks Function()
        > {
  $$LocationSettingsTableTableManager(
    _$AppDatabase db,
    $LocationSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocationSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocationSettingsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocationSettingsTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> globalEnabled = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => LocationSettingsCompanion(
                id: id,
                globalEnabled: globalEnabled,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<bool> globalEnabled = const Value.absent(),
                required int updatedAt,
              }) => LocationSettingsCompanion.insert(
                id: id,
                globalEnabled: globalEnabled,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocationSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocationSettingsTable,
      LocationSettingRow,
      $$LocationSettingsTableFilterComposer,
      $$LocationSettingsTableOrderingComposer,
      $$LocationSettingsTableAnnotationComposer,
      $$LocationSettingsTableCreateCompanionBuilder,
      $$LocationSettingsTableUpdateCompanionBuilder,
      (
        LocationSettingRow,
        BaseReferences<
          _$AppDatabase,
          $LocationSettingsTable,
          LocationSettingRow
        >,
      ),
      LocationSettingRow,
      PrefetchHooks Function()
    >;
typedef $$LocationPeerSettingsTableCreateCompanionBuilder =
    LocationPeerSettingsCompanion Function({
      required String peerDeviceId,
      Value<bool> enabled,
      required int updatedAt,
      Value<int> rowid,
    });
typedef $$LocationPeerSettingsTableUpdateCompanionBuilder =
    LocationPeerSettingsCompanion Function({
      Value<String> peerDeviceId,
      Value<bool> enabled,
      Value<int> updatedAt,
      Value<int> rowid,
    });

class $$LocationPeerSettingsTableFilterComposer
    extends Composer<_$AppDatabase, $LocationPeerSettingsTable> {
  $$LocationPeerSettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get peerDeviceId => $composableBuilder(
    column: $table.peerDeviceId,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocationPeerSettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $LocationPeerSettingsTable> {
  $$LocationPeerSettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get peerDeviceId => $composableBuilder(
    column: $table.peerDeviceId,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocationPeerSettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocationPeerSettingsTable> {
  $$LocationPeerSettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get peerDeviceId => $composableBuilder(
    column: $table.peerDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$LocationPeerSettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocationPeerSettingsTable,
          LocationPeerSettingRow,
          $$LocationPeerSettingsTableFilterComposer,
          $$LocationPeerSettingsTableOrderingComposer,
          $$LocationPeerSettingsTableAnnotationComposer,
          $$LocationPeerSettingsTableCreateCompanionBuilder,
          $$LocationPeerSettingsTableUpdateCompanionBuilder,
          (
            LocationPeerSettingRow,
            BaseReferences<
              _$AppDatabase,
              $LocationPeerSettingsTable,
              LocationPeerSettingRow
            >,
          ),
          LocationPeerSettingRow,
          PrefetchHooks Function()
        > {
  $$LocationPeerSettingsTableTableManager(
    _$AppDatabase db,
    $LocationPeerSettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocationPeerSettingsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocationPeerSettingsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$LocationPeerSettingsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> peerDeviceId = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocationPeerSettingsCompanion(
                peerDeviceId: peerDeviceId,
                enabled: enabled,
                updatedAt: updatedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String peerDeviceId,
                Value<bool> enabled = const Value.absent(),
                required int updatedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocationPeerSettingsCompanion.insert(
                peerDeviceId: peerDeviceId,
                enabled: enabled,
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

typedef $$LocationPeerSettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocationPeerSettingsTable,
      LocationPeerSettingRow,
      $$LocationPeerSettingsTableFilterComposer,
      $$LocationPeerSettingsTableOrderingComposer,
      $$LocationPeerSettingsTableAnnotationComposer,
      $$LocationPeerSettingsTableCreateCompanionBuilder,
      $$LocationPeerSettingsTableUpdateCompanionBuilder,
      (
        LocationPeerSettingRow,
        BaseReferences<
          _$AppDatabase,
          $LocationPeerSettingsTable,
          LocationPeerSettingRow
        >,
      ),
      LocationPeerSettingRow,
      PrefetchHooks Function()
    >;
typedef $$LocationFixesTableCreateCompanionBuilder =
    LocationFixesCompanion Function({
      required String peerDeviceId,
      required double latitude,
      required double longitude,
      Value<double?> accuracyM,
      required int capturedAt,
      required int receivedAt,
      Value<int> rowid,
    });
typedef $$LocationFixesTableUpdateCompanionBuilder =
    LocationFixesCompanion Function({
      Value<String> peerDeviceId,
      Value<double> latitude,
      Value<double> longitude,
      Value<double?> accuracyM,
      Value<int> capturedAt,
      Value<int> receivedAt,
      Value<int> rowid,
    });

class $$LocationFixesTableFilterComposer
    extends Composer<_$AppDatabase, $LocationFixesTable> {
  $$LocationFixesTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get peerDeviceId => $composableBuilder(
    column: $table.peerDeviceId,
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

  ColumnFilters<double> get accuracyM => $composableBuilder(
    column: $table.accuracyM,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$LocationFixesTableOrderingComposer
    extends Composer<_$AppDatabase, $LocationFixesTable> {
  $$LocationFixesTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get peerDeviceId => $composableBuilder(
    column: $table.peerDeviceId,
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

  ColumnOrderings<double> get accuracyM => $composableBuilder(
    column: $table.accuracyM,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$LocationFixesTableAnnotationComposer
    extends Composer<_$AppDatabase, $LocationFixesTable> {
  $$LocationFixesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get peerDeviceId => $composableBuilder(
    column: $table.peerDeviceId,
    builder: (column) => column,
  );

  GeneratedColumn<double> get latitude =>
      $composableBuilder(column: $table.latitude, builder: (column) => column);

  GeneratedColumn<double> get longitude =>
      $composableBuilder(column: $table.longitude, builder: (column) => column);

  GeneratedColumn<double> get accuracyM =>
      $composableBuilder(column: $table.accuracyM, builder: (column) => column);

  GeneratedColumn<int> get capturedAt => $composableBuilder(
    column: $table.capturedAt,
    builder: (column) => column,
  );

  GeneratedColumn<int> get receivedAt => $composableBuilder(
    column: $table.receivedAt,
    builder: (column) => column,
  );
}

class $$LocationFixesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $LocationFixesTable,
          LocationFixRow,
          $$LocationFixesTableFilterComposer,
          $$LocationFixesTableOrderingComposer,
          $$LocationFixesTableAnnotationComposer,
          $$LocationFixesTableCreateCompanionBuilder,
          $$LocationFixesTableUpdateCompanionBuilder,
          (
            LocationFixRow,
            BaseReferences<_$AppDatabase, $LocationFixesTable, LocationFixRow>,
          ),
          LocationFixRow,
          PrefetchHooks Function()
        > {
  $$LocationFixesTableTableManager(_$AppDatabase db, $LocationFixesTable table)
    : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$LocationFixesTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$LocationFixesTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$LocationFixesTableAnnotationComposer($db: db, $table: table),
          updateCompanionCallback:
              ({
                Value<String> peerDeviceId = const Value.absent(),
                Value<double> latitude = const Value.absent(),
                Value<double> longitude = const Value.absent(),
                Value<double?> accuracyM = const Value.absent(),
                Value<int> capturedAt = const Value.absent(),
                Value<int> receivedAt = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => LocationFixesCompanion(
                peerDeviceId: peerDeviceId,
                latitude: latitude,
                longitude: longitude,
                accuracyM: accuracyM,
                capturedAt: capturedAt,
                receivedAt: receivedAt,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String peerDeviceId,
                required double latitude,
                required double longitude,
                Value<double?> accuracyM = const Value.absent(),
                required int capturedAt,
                required int receivedAt,
                Value<int> rowid = const Value.absent(),
              }) => LocationFixesCompanion.insert(
                peerDeviceId: peerDeviceId,
                latitude: latitude,
                longitude: longitude,
                accuracyM: accuracyM,
                capturedAt: capturedAt,
                receivedAt: receivedAt,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$LocationFixesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $LocationFixesTable,
      LocationFixRow,
      $$LocationFixesTableFilterComposer,
      $$LocationFixesTableOrderingComposer,
      $$LocationFixesTableAnnotationComposer,
      $$LocationFixesTableCreateCompanionBuilder,
      $$LocationFixesTableUpdateCompanionBuilder,
      (
        LocationFixRow,
        BaseReferences<_$AppDatabase, $LocationFixesTable, LocationFixRow>,
      ),
      LocationFixRow,
      PrefetchHooks Function()
    >;
typedef $$NotificationCategorySettingsTableCreateCompanionBuilder =
    NotificationCategorySettingsCompanion Function({
      required String category,
      Value<bool> enabled,
      Value<int> rowid,
    });
typedef $$NotificationCategorySettingsTableUpdateCompanionBuilder =
    NotificationCategorySettingsCompanion Function({
      Value<String> category,
      Value<bool> enabled,
      Value<int> rowid,
    });

class $$NotificationCategorySettingsTableFilterComposer
    extends Composer<_$AppDatabase, $NotificationCategorySettingsTable> {
  $$NotificationCategorySettingsTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotificationCategorySettingsTableOrderingComposer
    extends Composer<_$AppDatabase, $NotificationCategorySettingsTable> {
  $$NotificationCategorySettingsTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get category => $composableBuilder(
    column: $table.category,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<bool> get enabled => $composableBuilder(
    column: $table.enabled,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotificationCategorySettingsTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotificationCategorySettingsTable> {
  $$NotificationCategorySettingsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get category =>
      $composableBuilder(column: $table.category, builder: (column) => column);

  GeneratedColumn<bool> get enabled =>
      $composableBuilder(column: $table.enabled, builder: (column) => column);
}

class $$NotificationCategorySettingsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotificationCategorySettingsTable,
          NotificationCategorySettingRow,
          $$NotificationCategorySettingsTableFilterComposer,
          $$NotificationCategorySettingsTableOrderingComposer,
          $$NotificationCategorySettingsTableAnnotationComposer,
          $$NotificationCategorySettingsTableCreateCompanionBuilder,
          $$NotificationCategorySettingsTableUpdateCompanionBuilder,
          (
            NotificationCategorySettingRow,
            BaseReferences<
              _$AppDatabase,
              $NotificationCategorySettingsTable,
              NotificationCategorySettingRow
            >,
          ),
          NotificationCategorySettingRow,
          PrefetchHooks Function()
        > {
  $$NotificationCategorySettingsTableTableManager(
    _$AppDatabase db,
    $NotificationCategorySettingsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotificationCategorySettingsTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$NotificationCategorySettingsTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$NotificationCategorySettingsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> category = const Value.absent(),
                Value<bool> enabled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotificationCategorySettingsCompanion(
                category: category,
                enabled: enabled,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String category,
                Value<bool> enabled = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => NotificationCategorySettingsCompanion.insert(
                category: category,
                enabled: enabled,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotificationCategorySettingsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotificationCategorySettingsTable,
      NotificationCategorySettingRow,
      $$NotificationCategorySettingsTableFilterComposer,
      $$NotificationCategorySettingsTableOrderingComposer,
      $$NotificationCategorySettingsTableAnnotationComposer,
      $$NotificationCategorySettingsTableCreateCompanionBuilder,
      $$NotificationCategorySettingsTableUpdateCompanionBuilder,
      (
        NotificationCategorySettingRow,
        BaseReferences<
          _$AppDatabase,
          $NotificationCategorySettingsTable,
          NotificationCategorySettingRow
        >,
      ),
      NotificationCategorySettingRow,
      PrefetchHooks Function()
    >;
typedef $$NotificationPreferencesTableCreateCompanionBuilder =
    NotificationPreferencesCompanion Function({
      Value<int> id,
      Value<String> privacyLevel,
    });
typedef $$NotificationPreferencesTableUpdateCompanionBuilder =
    NotificationPreferencesCompanion Function({
      Value<int> id,
      Value<String> privacyLevel,
    });

class $$NotificationPreferencesTableFilterComposer
    extends Composer<_$AppDatabase, $NotificationPreferencesTable> {
  $$NotificationPreferencesTableFilterComposer({
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

  ColumnFilters<String> get privacyLevel => $composableBuilder(
    column: $table.privacyLevel,
    builder: (column) => ColumnFilters(column),
  );
}

class $$NotificationPreferencesTableOrderingComposer
    extends Composer<_$AppDatabase, $NotificationPreferencesTable> {
  $$NotificationPreferencesTableOrderingComposer({
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

  ColumnOrderings<String> get privacyLevel => $composableBuilder(
    column: $table.privacyLevel,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$NotificationPreferencesTableAnnotationComposer
    extends Composer<_$AppDatabase, $NotificationPreferencesTable> {
  $$NotificationPreferencesTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<String> get privacyLevel => $composableBuilder(
    column: $table.privacyLevel,
    builder: (column) => column,
  );
}

class $$NotificationPreferencesTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $NotificationPreferencesTable,
          NotificationPreferenceRow,
          $$NotificationPreferencesTableFilterComposer,
          $$NotificationPreferencesTableOrderingComposer,
          $$NotificationPreferencesTableAnnotationComposer,
          $$NotificationPreferencesTableCreateCompanionBuilder,
          $$NotificationPreferencesTableUpdateCompanionBuilder,
          (
            NotificationPreferenceRow,
            BaseReferences<
              _$AppDatabase,
              $NotificationPreferencesTable,
              NotificationPreferenceRow
            >,
          ),
          NotificationPreferenceRow,
          PrefetchHooks Function()
        > {
  $$NotificationPreferencesTableTableManager(
    _$AppDatabase db,
    $NotificationPreferencesTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$NotificationPreferencesTableFilterComposer(
                $db: db,
                $table: table,
              ),
          createOrderingComposer: () =>
              $$NotificationPreferencesTableOrderingComposer(
                $db: db,
                $table: table,
              ),
          createComputedFieldComposer: () =>
              $$NotificationPreferencesTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> privacyLevel = const Value.absent(),
              }) => NotificationPreferencesCompanion(
                id: id,
                privacyLevel: privacyLevel,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<String> privacyLevel = const Value.absent(),
              }) => NotificationPreferencesCompanion.insert(
                id: id,
                privacyLevel: privacyLevel,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$NotificationPreferencesTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $NotificationPreferencesTable,
      NotificationPreferenceRow,
      $$NotificationPreferencesTableFilterComposer,
      $$NotificationPreferencesTableOrderingComposer,
      $$NotificationPreferencesTableAnnotationComposer,
      $$NotificationPreferencesTableCreateCompanionBuilder,
      $$NotificationPreferencesTableUpdateCompanionBuilder,
      (
        NotificationPreferenceRow,
        BaseReferences<
          _$AppDatabase,
          $NotificationPreferencesTable,
          NotificationPreferenceRow
        >,
      ),
      NotificationPreferenceRow,
      PrefetchHooks Function()
    >;
typedef $$DeviceRevocationsTableCreateCompanionBuilder =
    DeviceRevocationsCompanion Function({
      required String deviceId,
      required DateTime revokedAt,
      required String source,
      Value<int> rowid,
    });
typedef $$DeviceRevocationsTableUpdateCompanionBuilder =
    DeviceRevocationsCompanion Function({
      Value<String> deviceId,
      Value<DateTime> revokedAt,
      Value<String> source,
      Value<int> rowid,
    });

class $$DeviceRevocationsTableFilterComposer
    extends Composer<_$AppDatabase, $DeviceRevocationsTable> {
  $$DeviceRevocationsTableFilterComposer({
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

  ColumnFilters<DateTime> get revokedAt => $composableBuilder(
    column: $table.revokedAt,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnFilters(column),
  );
}

class $$DeviceRevocationsTableOrderingComposer
    extends Composer<_$AppDatabase, $DeviceRevocationsTable> {
  $$DeviceRevocationsTableOrderingComposer({
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

  ColumnOrderings<DateTime> get revokedAt => $composableBuilder(
    column: $table.revokedAt,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get source => $composableBuilder(
    column: $table.source,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$DeviceRevocationsTableAnnotationComposer
    extends Composer<_$AppDatabase, $DeviceRevocationsTable> {
  $$DeviceRevocationsTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get deviceId =>
      $composableBuilder(column: $table.deviceId, builder: (column) => column);

  GeneratedColumn<DateTime> get revokedAt =>
      $composableBuilder(column: $table.revokedAt, builder: (column) => column);

  GeneratedColumn<String> get source =>
      $composableBuilder(column: $table.source, builder: (column) => column);
}

class $$DeviceRevocationsTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $DeviceRevocationsTable,
          DeviceRevocationRow,
          $$DeviceRevocationsTableFilterComposer,
          $$DeviceRevocationsTableOrderingComposer,
          $$DeviceRevocationsTableAnnotationComposer,
          $$DeviceRevocationsTableCreateCompanionBuilder,
          $$DeviceRevocationsTableUpdateCompanionBuilder,
          (
            DeviceRevocationRow,
            BaseReferences<
              _$AppDatabase,
              $DeviceRevocationsTable,
              DeviceRevocationRow
            >,
          ),
          DeviceRevocationRow,
          PrefetchHooks Function()
        > {
  $$DeviceRevocationsTableTableManager(
    _$AppDatabase db,
    $DeviceRevocationsTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$DeviceRevocationsTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$DeviceRevocationsTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$DeviceRevocationsTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> deviceId = const Value.absent(),
                Value<DateTime> revokedAt = const Value.absent(),
                Value<String> source = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => DeviceRevocationsCompanion(
                deviceId: deviceId,
                revokedAt: revokedAt,
                source: source,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String deviceId,
                required DateTime revokedAt,
                required String source,
                Value<int> rowid = const Value.absent(),
              }) => DeviceRevocationsCompanion.insert(
                deviceId: deviceId,
                revokedAt: revokedAt,
                source: source,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$DeviceRevocationsTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $DeviceRevocationsTable,
      DeviceRevocationRow,
      $$DeviceRevocationsTableFilterComposer,
      $$DeviceRevocationsTableOrderingComposer,
      $$DeviceRevocationsTableAnnotationComposer,
      $$DeviceRevocationsTableCreateCompanionBuilder,
      $$DeviceRevocationsTableUpdateCompanionBuilder,
      (
        DeviceRevocationRow,
        BaseReferences<
          _$AppDatabase,
          $DeviceRevocationsTable,
          DeviceRevocationRow
        >,
      ),
      DeviceRevocationRow,
      PrefetchHooks Function()
    >;
typedef $$RateLimitCountersTableCreateCompanionBuilder =
    RateLimitCountersCompanion Function({
      required String bucketKey,
      required int windowStartMs,
      required int count,
      Value<int> rowid,
    });
typedef $$RateLimitCountersTableUpdateCompanionBuilder =
    RateLimitCountersCompanion Function({
      Value<String> bucketKey,
      Value<int> windowStartMs,
      Value<int> count,
      Value<int> rowid,
    });

class $$RateLimitCountersTableFilterComposer
    extends Composer<_$AppDatabase, $RateLimitCountersTable> {
  $$RateLimitCountersTableFilterComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnFilters<String> get bucketKey => $composableBuilder(
    column: $table.bucketKey,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get windowStartMs => $composableBuilder(
    column: $table.windowStartMs,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnFilters(column),
  );
}

class $$RateLimitCountersTableOrderingComposer
    extends Composer<_$AppDatabase, $RateLimitCountersTable> {
  $$RateLimitCountersTableOrderingComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  ColumnOrderings<String> get bucketKey => $composableBuilder(
    column: $table.bucketKey,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get windowStartMs => $composableBuilder(
    column: $table.windowStartMs,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get count => $composableBuilder(
    column: $table.count,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$RateLimitCountersTableAnnotationComposer
    extends Composer<_$AppDatabase, $RateLimitCountersTable> {
  $$RateLimitCountersTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<String> get bucketKey =>
      $composableBuilder(column: $table.bucketKey, builder: (column) => column);

  GeneratedColumn<int> get windowStartMs => $composableBuilder(
    column: $table.windowStartMs,
    builder: (column) => column,
  );

  GeneratedColumn<int> get count =>
      $composableBuilder(column: $table.count, builder: (column) => column);
}

class $$RateLimitCountersTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $RateLimitCountersTable,
          RateLimitCounterRow,
          $$RateLimitCountersTableFilterComposer,
          $$RateLimitCountersTableOrderingComposer,
          $$RateLimitCountersTableAnnotationComposer,
          $$RateLimitCountersTableCreateCompanionBuilder,
          $$RateLimitCountersTableUpdateCompanionBuilder,
          (
            RateLimitCounterRow,
            BaseReferences<
              _$AppDatabase,
              $RateLimitCountersTable,
              RateLimitCounterRow
            >,
          ),
          RateLimitCounterRow,
          PrefetchHooks Function()
        > {
  $$RateLimitCountersTableTableManager(
    _$AppDatabase db,
    $RateLimitCountersTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$RateLimitCountersTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$RateLimitCountersTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$RateLimitCountersTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<String> bucketKey = const Value.absent(),
                Value<int> windowStartMs = const Value.absent(),
                Value<int> count = const Value.absent(),
                Value<int> rowid = const Value.absent(),
              }) => RateLimitCountersCompanion(
                bucketKey: bucketKey,
                windowStartMs: windowStartMs,
                count: count,
                rowid: rowid,
              ),
          createCompanionCallback:
              ({
                required String bucketKey,
                required int windowStartMs,
                required int count,
                Value<int> rowid = const Value.absent(),
              }) => RateLimitCountersCompanion.insert(
                bucketKey: bucketKey,
                windowStartMs: windowStartMs,
                count: count,
                rowid: rowid,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$RateLimitCountersTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $RateLimitCountersTable,
      RateLimitCounterRow,
      $$RateLimitCountersTableFilterComposer,
      $$RateLimitCountersTableOrderingComposer,
      $$RateLimitCountersTableAnnotationComposer,
      $$RateLimitCountersTableCreateCompanionBuilder,
      $$RateLimitCountersTableUpdateCompanionBuilder,
      (
        RateLimitCounterRow,
        BaseReferences<
          _$AppDatabase,
          $RateLimitCountersTable,
          RateLimitCounterRow
        >,
      ),
      RateLimitCounterRow,
      PrefetchHooks Function()
    >;
typedef $$VersionPolicyCacheTableCreateCompanionBuilder =
    VersionPolicyCacheCompanion Function({
      Value<int> id,
      required int minimumSupportedBuild,
      required int currentBuild,
      required int updateAvailableBuild,
      required String signature,
      required int updatedAt,
    });
typedef $$VersionPolicyCacheTableUpdateCompanionBuilder =
    VersionPolicyCacheCompanion Function({
      Value<int> id,
      Value<int> minimumSupportedBuild,
      Value<int> currentBuild,
      Value<int> updateAvailableBuild,
      Value<String> signature,
      Value<int> updatedAt,
    });

class $$VersionPolicyCacheTableFilterComposer
    extends Composer<_$AppDatabase, $VersionPolicyCacheTable> {
  $$VersionPolicyCacheTableFilterComposer({
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

  ColumnFilters<int> get minimumSupportedBuild => $composableBuilder(
    column: $table.minimumSupportedBuild,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get currentBuild => $composableBuilder(
    column: $table.currentBuild,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updateAvailableBuild => $composableBuilder(
    column: $table.updateAvailableBuild,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<String> get signature => $composableBuilder(
    column: $table.signature,
    builder: (column) => ColumnFilters(column),
  );

  ColumnFilters<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnFilters(column),
  );
}

class $$VersionPolicyCacheTableOrderingComposer
    extends Composer<_$AppDatabase, $VersionPolicyCacheTable> {
  $$VersionPolicyCacheTableOrderingComposer({
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

  ColumnOrderings<int> get minimumSupportedBuild => $composableBuilder(
    column: $table.minimumSupportedBuild,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get currentBuild => $composableBuilder(
    column: $table.currentBuild,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updateAvailableBuild => $composableBuilder(
    column: $table.updateAvailableBuild,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<String> get signature => $composableBuilder(
    column: $table.signature,
    builder: (column) => ColumnOrderings(column),
  );

  ColumnOrderings<int> get updatedAt => $composableBuilder(
    column: $table.updatedAt,
    builder: (column) => ColumnOrderings(column),
  );
}

class $$VersionPolicyCacheTableAnnotationComposer
    extends Composer<_$AppDatabase, $VersionPolicyCacheTable> {
  $$VersionPolicyCacheTableAnnotationComposer({
    required super.$db,
    required super.$table,
    super.joinBuilder,
    super.$addJoinBuilderToRootComposer,
    super.$removeJoinBuilderFromRootComposer,
  });
  GeneratedColumn<int> get id =>
      $composableBuilder(column: $table.id, builder: (column) => column);

  GeneratedColumn<int> get minimumSupportedBuild => $composableBuilder(
    column: $table.minimumSupportedBuild,
    builder: (column) => column,
  );

  GeneratedColumn<int> get currentBuild => $composableBuilder(
    column: $table.currentBuild,
    builder: (column) => column,
  );

  GeneratedColumn<int> get updateAvailableBuild => $composableBuilder(
    column: $table.updateAvailableBuild,
    builder: (column) => column,
  );

  GeneratedColumn<String> get signature =>
      $composableBuilder(column: $table.signature, builder: (column) => column);

  GeneratedColumn<int> get updatedAt =>
      $composableBuilder(column: $table.updatedAt, builder: (column) => column);
}

class $$VersionPolicyCacheTableTableManager
    extends
        RootTableManager<
          _$AppDatabase,
          $VersionPolicyCacheTable,
          VersionPolicyCacheRow,
          $$VersionPolicyCacheTableFilterComposer,
          $$VersionPolicyCacheTableOrderingComposer,
          $$VersionPolicyCacheTableAnnotationComposer,
          $$VersionPolicyCacheTableCreateCompanionBuilder,
          $$VersionPolicyCacheTableUpdateCompanionBuilder,
          (
            VersionPolicyCacheRow,
            BaseReferences<
              _$AppDatabase,
              $VersionPolicyCacheTable,
              VersionPolicyCacheRow
            >,
          ),
          VersionPolicyCacheRow,
          PrefetchHooks Function()
        > {
  $$VersionPolicyCacheTableTableManager(
    _$AppDatabase db,
    $VersionPolicyCacheTable table,
  ) : super(
        TableManagerState(
          db: db,
          table: table,
          createFilteringComposer: () =>
              $$VersionPolicyCacheTableFilterComposer($db: db, $table: table),
          createOrderingComposer: () =>
              $$VersionPolicyCacheTableOrderingComposer($db: db, $table: table),
          createComputedFieldComposer: () =>
              $$VersionPolicyCacheTableAnnotationComposer(
                $db: db,
                $table: table,
              ),
          updateCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                Value<int> minimumSupportedBuild = const Value.absent(),
                Value<int> currentBuild = const Value.absent(),
                Value<int> updateAvailableBuild = const Value.absent(),
                Value<String> signature = const Value.absent(),
                Value<int> updatedAt = const Value.absent(),
              }) => VersionPolicyCacheCompanion(
                id: id,
                minimumSupportedBuild: minimumSupportedBuild,
                currentBuild: currentBuild,
                updateAvailableBuild: updateAvailableBuild,
                signature: signature,
                updatedAt: updatedAt,
              ),
          createCompanionCallback:
              ({
                Value<int> id = const Value.absent(),
                required int minimumSupportedBuild,
                required int currentBuild,
                required int updateAvailableBuild,
                required String signature,
                required int updatedAt,
              }) => VersionPolicyCacheCompanion.insert(
                id: id,
                minimumSupportedBuild: minimumSupportedBuild,
                currentBuild: currentBuild,
                updateAvailableBuild: updateAvailableBuild,
                signature: signature,
                updatedAt: updatedAt,
              ),
          withReferenceMapper: (p0) => p0
              .map((e) => (e.readTable(table), BaseReferences(db, table, e)))
              .toList(),
          prefetchHooksCallback: null,
        ),
      );
}

typedef $$VersionPolicyCacheTableProcessedTableManager =
    ProcessedTableManager<
      _$AppDatabase,
      $VersionPolicyCacheTable,
      VersionPolicyCacheRow,
      $$VersionPolicyCacheTableFilterComposer,
      $$VersionPolicyCacheTableOrderingComposer,
      $$VersionPolicyCacheTableAnnotationComposer,
      $$VersionPolicyCacheTableCreateCompanionBuilder,
      $$VersionPolicyCacheTableUpdateCompanionBuilder,
      (
        VersionPolicyCacheRow,
        BaseReferences<
          _$AppDatabase,
          $VersionPolicyCacheTable,
          VersionPolicyCacheRow
        >,
      ),
      VersionPolicyCacheRow,
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
  $$SyncCursorsTableTableManager get syncCursors =>
      $$SyncCursorsTableTableManager(_db, _db.syncCursors);
  $$GroupsTableTableManager get groups =>
      $$GroupsTableTableManager(_db, _db.groups);
  $$GroupMembersTableTableManager get groupMembers =>
      $$GroupMembersTableTableManager(_db, _db.groupMembers);
  $$GroupSenderKeysTableTableManager get groupSenderKeys =>
      $$GroupSenderKeysTableTableManager(_db, _db.groupSenderKeys);
  $$GroupEventsTableTableManager get groupEvents =>
      $$GroupEventsTableTableManager(_db, _db.groupEvents);
  $$StorageItemStatsTableTableManager get storageItemStats =>
      $$StorageItemStatsTableTableManager(_db, _db.storageItemStats);
  $$StoragePolicySettingsTableTableManager get storagePolicySettings =>
      $$StoragePolicySettingsTableTableManager(_db, _db.storagePolicySettings);
  $$StorageDecisionsTableTableManager get storageDecisions =>
      $$StorageDecisionsTableTableManager(_db, _db.storageDecisions);
  $$LocationSettingsTableTableManager get locationSettings =>
      $$LocationSettingsTableTableManager(_db, _db.locationSettings);
  $$LocationPeerSettingsTableTableManager get locationPeerSettings =>
      $$LocationPeerSettingsTableTableManager(_db, _db.locationPeerSettings);
  $$LocationFixesTableTableManager get locationFixes =>
      $$LocationFixesTableTableManager(_db, _db.locationFixes);
  $$NotificationCategorySettingsTableTableManager
  get notificationCategorySettings =>
      $$NotificationCategorySettingsTableTableManager(
        _db,
        _db.notificationCategorySettings,
      );
  $$NotificationPreferencesTableTableManager get notificationPreferences =>
      $$NotificationPreferencesTableTableManager(
        _db,
        _db.notificationPreferences,
      );
  $$DeviceRevocationsTableTableManager get deviceRevocations =>
      $$DeviceRevocationsTableTableManager(_db, _db.deviceRevocations);
  $$RateLimitCountersTableTableManager get rateLimitCounters =>
      $$RateLimitCountersTableTableManager(_db, _db.rateLimitCounters);
  $$VersionPolicyCacheTableTableManager get versionPolicyCache =>
      $$VersionPolicyCacheTableTableManager(_db, _db.versionPolicyCache);
}
