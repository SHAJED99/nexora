// E07-T01 — group data model tables + the 12->13 migration.
//
// Follows the pattern established in
// test/core/persistence/message_migration_test.dart: hand-build the exact
// PRIOR-version (v12) schema with raw SQL, set `userVersion`, open it with
// `AppDatabase`, and assert both that the upgrade creates the new tables in
// a usable shape and that every pre-existing table survived untouched.
import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/persistence/group_tables.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// The full v12 schema -- everything E01-E05 created, in the exact shape
/// each table has as of schema version 12 (the version immediately before
/// this task's `groups`/`group_members`/`group_sender_keys`/`group_events`
/// step). Needed in full (not just a subset) because `AppDatabase`'s
/// `onUpgrade` guards every earlier step with `from < N`, so opening a raw
/// database at `userVersion = 12` skips every step up to and including the
/// `sync_cursors` one (`from < 12`) and runs only the new `from < 13` step.
void _createV12Tables(sqlite3.Database raw) {
  raw.execute('''
    CREATE TABLE device_identities (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      device_id TEXT NOT NULL,
      signed_in INTEGER NOT NULL DEFAULT 0,
      signed_in_at INTEGER NULL,
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now')),
      account_uid TEXT NULL
    );
  ''');
  raw.execute('''
    CREATE TABLE relationships (
      device_id TEXT NOT NULL,
      state TEXT NOT NULL,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (device_id)
    );
  ''');
  raw.execute('''
    CREATE TABLE signal_identity (
      id INTEGER NOT NULL,
      identity_key_pair BLOB NOT NULL,
      registration_id INTEGER NOT NULL,
      PRIMARY KEY (id)
    );
  ''');
  raw.execute('''
    CREATE TABLE signal_signed_prekeys (
      id INTEGER NOT NULL,
      record BLOB NOT NULL,
      PRIMARY KEY (id)
    );
  ''');
  raw.execute('''
    CREATE TABLE signal_one_time_prekeys (
      id INTEGER NOT NULL,
      record BLOB NOT NULL,
      PRIMARY KEY (id)
    );
  ''');
  raw.execute('''
    CREATE TABLE signal_sessions (
      address_name TEXT NOT NULL,
      address_device_id INTEGER NOT NULL,
      record BLOB NOT NULL,
      PRIMARY KEY (address_name, address_device_id)
    );
  ''');
  raw.execute('''
    CREATE TABLE signal_trusted_identities (
      address_name TEXT NOT NULL,
      address_device_id INTEGER NOT NULL,
      identity_key BLOB NOT NULL,
      PRIMARY KEY (address_name, address_device_id)
    );
  ''');
  raw.execute('''
    CREATE TABLE crypto_counters (
      id INTEGER NOT NULL,
      next_one_time_pre_key_id INTEGER NOT NULL DEFAULT 1,
      next_issued_one_time_pre_key_id INTEGER NOT NULL DEFAULT 1,
      PRIMARY KEY (id)
    );
  ''');
  raw.execute('''
    CREATE TABLE routes (
      destination_id TEXT NOT NULL,
      hops TEXT NOT NULL,
      last_cost REAL NOT NULL,
      last_measured_at INTEGER NOT NULL,
      stable_since_tick INTEGER NULL,
      PRIMARY KEY (destination_id, hops)
    );
  ''');
  raw.execute('''
    CREATE TABLE relay_packets (
      id TEXT NOT NULL,
      destination_id TEXT NOT NULL,
      payload BLOB NULL,
      priority INTEGER NOT NULL,
      size_bytes INTEGER NOT NULL,
      created_at INTEGER NOT NULL,
      expires_at INTEGER NOT NULL,
      delivery_state TEXT NOT NULL,
      PRIMARY KEY (id)
    );
  ''');
  raw.execute('''
    CREATE TABLE messages (
      id TEXT NOT NULL,
      conversation_id TEXT NOT NULL,
      sender_device_id TEXT NOT NULL,
      sequence_number INTEGER NOT NULL,
      ciphertext BLOB NOT NULL,
      created_at INTEGER NOT NULL,
      delivery_state TEXT NOT NULL,
      PRIMARY KEY (id)
    );
  ''');
  raw.execute(
    'CREATE INDEX idx_messages_conversation_created_at ON messages '
    '(conversation_id, created_at);',
  );
  raw.execute('''
    CREATE TABLE delivery_states (
      message_id TEXT NOT NULL,
      state TEXT NOT NULL,
      changed_at INTEGER NOT NULL,
      PRIMARY KEY (message_id, state)
    );
  ''');
  raw.execute('''
    CREATE TABLE sync_cursors (
      local_device_id TEXT NOT NULL,
      remote_device_id TEXT NOT NULL,
      conversation_id TEXT NOT NULL,
      last_confirmed_sequence_number INTEGER NOT NULL,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (local_device_id, remote_device_id, conversation_id)
    );
  ''');
}

/// Rows this test set into `sqlite_master` to prove the v12->v13 step
/// touches nothing outside the four new tables.
void _seedV12Data(sqlite3.Database raw) {
  raw.execute(
    "INSERT INTO device_identities (device_id, signed_in) VALUES ('v12-device', 1);",
  );
  raw.execute(
    "INSERT INTO messages "
    "(id, conversation_id, sender_device_id, sequence_number, ciphertext, created_at, delivery_state) "
    "VALUES ('msg-1', 'conv-1', 'device-A', 1, X'0102', 1000, 'queued');",
  );
}

Future<AppDatabase> _openAtV12() async {
  final raw = sqlite3.sqlite3.openInMemory();
  _createV12Tables(raw);
  _seedV12Data(raw);
  raw.userVersion = 12;
  return AppDatabase.forTesting(NativeDatabase.opened(raw));
}

void main() {
  test(
    'test_EARS_GROUP_5_v12_upgrades_to_v13_additively',
    () async {
      // Pre-existing tables the 12->13 step must not alter, rename, or drop
      // a column of (this task's §4). Snapshotted below, from the raw v12
      // handle, before `AppDatabase` -- and therefore the migration -- ever
      // touches it.
      const preExistingTables = [
        'device_identities',
        'relationships',
        'signal_identity',
        'signal_signed_prekeys',
        'signal_one_time_prekeys',
        'signal_sessions',
        'signal_trusted_identities',
        'crypto_counters',
        'routes',
        'relay_packets',
        'messages',
        'delivery_states',
        'sync_cursors',
      ];

      final raw = sqlite3.sqlite3.openInMemory();
      _createV12Tables(raw);
      _seedV12Data(raw);

      // Snapshot each pre-existing table's exact `CREATE TABLE` DDL text
      // from `sqlite_master` while still on the raw v12 handle -- this is
      // what makes the post-migration comparison below prove the DDL is
      // byte-identical, not merely that a same-named table still exists.
      final preMigrationSql = <String, String>{
        for (final tableName in preExistingTables)
          tableName: raw
                  .select(
                    "SELECT sql FROM sqlite_master WHERE type='table' "
                    'AND name = ?',
                    [tableName],
                  )
                  .single['sql']
              as String,
      };

      raw.userVersion = 12;
      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      // The four new tables exist and are usable through the real Dart
      // definitions.
      expect(await db.select(db.groups).get(), isEmpty);
      expect(await db.select(db.groupMembers).get(), isEmpty);
      expect(await db.select(db.groupSenderKeys).get(), isEmpty);
      expect(await db.select(db.groupEvents).get(), isEmpty);

      await db.into(db.groups).insert(
            GroupsCompanion.insert(
              id: 'g:abc',
              name: 'Test group',
              createdAt: 1000,
              createdByDeviceId: 'device-A',
            ),
          );
      final group = await db.select(db.groups).getSingle();
      expect(group.id, 'g:abc');
      expect(group.membershipEpoch, 0);
      expect(group.isDeleted, isFalse);

      // Every declared index exists.
      for (final indexName in [
        'idx_group_members_current',
        'idx_group_single_owner',
        'idx_group_events_group_epoch',
      ]) {
        final rows = await db
            .customSelect(
              "SELECT name FROM sqlite_master WHERE type='index' "
              "AND name='$indexName'",
            )
            .get();
        expect(rows, hasLength(1), reason: '$indexName should exist');
      }

      // Pre-existing tables + their pre-existing rows are untouched by this
      // step.
      final identities = await db.select(db.deviceIdentities).get();
      expect(identities.single.deviceId, 'v12-device');
      final messageRows = await db.select(db.messages).get();
      expect(messageRows, hasLength(1));
      expect(messageRows.single.id, 'msg-1');

      // Byte-identical schema check on every non-group table: the CREATE
      // TABLE SQL captured by sqlite_master for each must be exactly what
      // it was pre-migration (no altered/renamed/dropped column, per this
      // task's §4). Compares the actual DDL text against the pre-migration
      // snapshot taken above -- not just that a same-named table exists.
      for (final tableName in preExistingTables) {
        // `relationships`: E04-B12 (a later schema-bumping task, current
        // `schemaVersion` 21) legitimately adds one nullable column
        // (`remote_self_device_id`) to this pre-existing table -- excluded
        // from the strict byte-identical check here and asserted
        // separately, right after this loop, mirroring the identical
        // documented exception in
        // `test/core/persistence/database_migration_test.dart`'s own
        // `test_EARS_STORE_3_v13_upgrades_to_v14_additively`.
        if (tableName == 'relationships') continue;
        final rows = await db
            .customSelect(
              "SELECT sql FROM sqlite_master WHERE type='table' "
              "AND name='$tableName'",
            )
            .get();
        expect(rows, hasLength(1), reason: '$tableName should still exist');
        expect(
          rows.single.read<String>('sql'),
          preMigrationSql[tableName],
          reason: '$tableName DDL should be byte-identical after migration',
        );
      }

      final relationshipsRows = await db
          .customSelect(
            "SELECT sql FROM sqlite_master WHERE type='table' "
            "AND name='relationships'",
          )
          .get();
      expect(relationshipsRows, hasLength(1));
      expect(
        relationshipsRows.single.read<String>('sql'),
        'CREATE TABLE relationships (\n'
        '      device_id TEXT NOT NULL,\n'
        '      state TEXT NOT NULL,\n'
        '      updated_at INTEGER NOT NULL, "remote_self_device_id" TEXT NULL,\n'
        '      PRIMARY KEY (device_id)\n'
        '    )',
      );
    },
  );

  test(
    'test_EARS_GROUP_3_new_group_has_epoch_zero_and_one_owner',
    () async {
      final db = await _openAtV12();
      addTearDown(db.close);

      const groupId = 'g:new';
      await db.into(db.groups).insert(
            GroupsCompanion.insert(
              id: groupId,
              name: 'Founders',
              createdAt: 1000,
              createdByDeviceId: 'device-owner',
            ),
          );
      await db.into(db.groupMembers).insert(
            GroupMembersCompanion.insert(
              groupId: groupId,
              deviceId: 'device-owner',
              role: GroupRole.owner.name,
              joinedAtEpoch: 0,
            ),
          );

      final group = await (db.select(db.groups)
            ..where((t) => t.id.equals(groupId)))
          .getSingle();
      expect(group.membershipEpoch, 0);

      final owners = await (db.select(db.groupMembers)
            ..where(
              (t) =>
                  t.groupId.equals(groupId) &
                  t.role.equals(GroupRole.owner.name) &
                  t.removedAtEpoch.isNull(),
            ))
          .get();
      expect(owners, hasLength(1));
      expect(owners.single.joinedAtEpoch, 0);
    },
  );

  test(
    'test_EARS_GROUP_4_second_current_owner_is_rejected',
    () async {
      final db = await _openAtV12();
      addTearDown(db.close);

      const groupId = 'g:owners';
      await db.into(db.groups).insert(
            GroupsCompanion.insert(
              id: groupId,
              name: 'Owners test',
              createdAt: 1000,
              createdByDeviceId: 'device-A',
            ),
          );
      await db.into(db.groupMembers).insert(
            GroupMembersCompanion.insert(
              groupId: groupId,
              deviceId: 'device-A',
              role: GroupRole.owner.name,
              joinedAtEpoch: 0,
            ),
          );

      // A second current Owner for the same group must be rejected by the
      // partial unique index -- not merely by application code.
      await expectLater(
        db.into(db.groupMembers).insert(
              GroupMembersCompanion.insert(
                groupId: groupId,
                deviceId: 'device-B',
                role: GroupRole.owner.name,
                joinedAtEpoch: 1,
              ),
            ),
        throwsA(anything),
      );

      // Once the first owner is marked removed (an ownership *transfer*),
      // the same insert must now succeed -- the constraint targets
      // "current" owners only.
      await (db.update(db.groupMembers)
            ..where(
              (t) => t.groupId.equals(groupId) & t.deviceId.equals('device-A'),
            ))
          .write(const GroupMembersCompanion(removedAtEpoch: Value(1)));

      await db.into(db.groupMembers).insert(
            GroupMembersCompanion.insert(
              groupId: groupId,
              deviceId: 'device-B',
              role: GroupRole.owner.name,
              joinedAtEpoch: 1,
            ),
          );

      final currentOwners = await (db.select(db.groupMembers)
            ..where(
              (t) =>
                  t.groupId.equals(groupId) &
                  t.role.equals(GroupRole.owner.name) &
                  t.removedAtEpoch.isNull(),
            ))
          .get();
      expect(currentOwners, hasLength(1));
      expect(currentOwners.single.deviceId, 'device-B');
    },
  );

  test('test_removed_member_row_is_retained_not_deleted', () async {
    final db = await _openAtV12();
    addTearDown(db.close);

    const groupId = 'g:retain';
    await db.into(db.groups).insert(
          GroupsCompanion.insert(
            id: groupId,
            name: 'Retain test',
            createdAt: 1000,
            createdByDeviceId: 'device-A',
          ),
        );
    await db.into(db.groupMembers).insert(
          GroupMembersCompanion.insert(
            groupId: groupId,
            deviceId: 'device-B',
            role: GroupRole.member.name,
            joinedAtEpoch: 0,
          ),
        );

    await (db.update(db.groupMembers)
          ..where(
            (t) => t.groupId.equals(groupId) & t.deviceId.equals('device-B'),
          ))
        .write(const GroupMembersCompanion(removedAtEpoch: Value(3)));

    final rows = await (db.select(db.groupMembers)
          ..where(
            (t) => t.groupId.equals(groupId) & t.deviceId.equals('device-B'),
          ))
        .get();
    expect(rows, hasLength(1));
    expect(rows.single.removedAtEpoch, 3);
  });

  test(
    'test_group_id_is_prefixed_and_never_collides_with_a_device_id',
    () {
      final ids = <String>{};
      for (var i = 0; i < 10000; i++) {
        final id = newGroupId();
        expect(id, startsWith('g:'));
        expect(id.length, 34); // 'g:' + 32 hex chars
        expect(RegExp(r'^g:[0-9a-f]{32}$').hasMatch(id), isTrue);
        ids.add(id);
      }
      expect(ids, hasLength(10000));
    },
  );

  test('group_sender_keys is keyed by (group, sender, epoch)', () async {
    final db = await _openAtV12();
    addTearDown(db.close);

    const groupId = 'g:senderkeys';
    await db.into(db.groups).insert(
          GroupsCompanion.insert(
            id: groupId,
            name: 'Sender keys test',
            createdAt: 1000,
            createdByDeviceId: 'device-A',
          ),
        );

    // Two rows for the same (group, sender) but different epochs must
    // coexist -- this is the whole point of keying by epoch (§2).
    await db.into(db.groupSenderKeys).insert(
          GroupSenderKeysCompanion.insert(
            groupId: groupId,
            senderDeviceId: 'device-A',
            membershipEpoch: 0,
            record: Uint8List.fromList([1, 2, 3]),
            updatedAt: 1000,
          ),
        );
    await db.into(db.groupSenderKeys).insert(
          GroupSenderKeysCompanion.insert(
            groupId: groupId,
            senderDeviceId: 'device-A',
            membershipEpoch: 1,
            record: Uint8List.fromList([4, 5, 6]),
            updatedAt: 2000,
          ),
        );

    final rows = await (db.select(db.groupSenderKeys)
          ..where(
            (t) =>
                t.groupId.equals(groupId) & t.senderDeviceId.equals('device-A'),
          ))
        .get();
    expect(rows, hasLength(2));
  });

  test('group_events records a membership-change log entry', () async {
    final db = await _openAtV12();
    addTearDown(db.close);

    const groupId = 'g:events';
    await db.into(db.groups).insert(
          GroupsCompanion.insert(
            id: groupId,
            name: 'Events test',
            createdAt: 1000,
            createdByDeviceId: 'device-A',
          ),
        );
    await db.into(db.groupEvents).insert(
          GroupEventsCompanion.insert(
            id: 'evt-1',
            groupId: groupId,
            epoch: 0,
            kind: GroupEventKind.created.name,
            actorDeviceId: 'device-A',
            createdAt: 1000,
          ),
        );

    final event = await db.select(db.groupEvents).getSingle();
    expect(event.kind, GroupEventKind.created.name);
    expect(event.subjectDeviceId, isNull);
  });
}
