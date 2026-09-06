// E14-T06 -- migration-safety regression suite (FR-VER-003, FR-VER-009).
//
// Every per-task migration test file in this directory
// (`database_migration_test.dart` and its siblings) proves its OWN step is
// additive in isolation. This file is additive on top of all of them: it
// walks the FULL `onUpgrade` chain end to end -- from schema v1, and from a
// representative sample of intermediate versions a real paused-mid-upgrade
// install could resume from -- all the way to the CURRENT `schemaVersion`,
// and asserts every seeded row survives byte-identical. It does not
// duplicate any existing per-task file's own narrower table/index/DDL
// assertions (task §4) and it does not change any migration step (test-only
// task -- a destructive step found here would be a NEW bug, filed
// separately, never fixed inside this file).
//
// Fixture-reuse note (task §7 "reuse, do not re-derive the earliest existing
// fixture-building function"): `AppDatabase`'s `onUpgrade` guards every step
// with `from < N`, so a raw database must be built with the EXACT schema
// shape a real device at that version would have -- these shapes are already
// hand-built and reviewed in this directory's own per-task files
// (`database_migration_test.dart`'s `_createV13Tables`,
// `sync_migration_test.dart`'s v7/v8/v10/v11 builders,
// `revocation_migration_test.dart`'s `_createV16Tables`). Dart's leading-`_`
// privacy is per-library (per-file), and this task's `files:` fence creates
// only ONE new file with no `update:` entries, so those functions cannot be
// imported directly -- the fence forbids adding a shared/exported helper
// file to make them public. The functions below are therefore copied
// VERBATIM from those already-reviewed sources (each copy says which file it
// came from) rather than re-derived by hand, which is the actual substance
// of "reuse, do not re-derive": the DDL text is identical to what already
// passed review, not an independently-retyped guess at the same schema.

import 'package:drift/drift.dart' show OrderingTerm;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

/// The exact v1 `device_identities` schema (pre-E01-T01: no `account_uid`
/// column) -- copied verbatim from `database_migration_test.dart`'s own
/// first test ("v1 -> v2 migration adds account_uid without losing existing
/// rows"), the earliest schema-building code in this test directory.
void _createV1DeviceIdentitiesTable(sqlite3.Database raw) {
  raw.execute('''
    CREATE TABLE device_identities (
      id INTEGER NOT NULL PRIMARY KEY AUTOINCREMENT,
      device_id TEXT NOT NULL,
      signed_in INTEGER NOT NULL DEFAULT 0,
      signed_in_at INTEGER NULL,
      created_at INTEGER NOT NULL DEFAULT (strftime('%s', 'now'))
    );
  ''');
}

/// The tables that exist in the v7 schema (everything E01-E03 created) --
/// copied verbatim from `sync_migration_test.dart`'s `_createV7Tables`
/// (itself copied from `message_migration_test.dart`'s own helper).
void _createV7Tables(sqlite3.Database raw) {
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
}

/// The exact v8 `routes` DDL (E04-T02) -- copied verbatim from
/// `sync_migration_test.dart`'s `_createRoutesTable`.
void _createRoutesTable(sqlite3.Database raw) {
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
}

/// The exact v10 `relay_packets` DDL (E04-B02: `payload` nullable) --
/// copied verbatim from `sync_migration_test.dart`'s
/// `_createRelayPacketsTableV10`.
void _createRelayPacketsTableV10(sqlite3.Database raw) {
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
}

/// The exact v9 `relay_packets` DDL (E04-T04) -- `payload` still NOT NULL,
/// pre-dating E04-B02's nullable-payload fix -- copied verbatim from
/// `relay_retention_migration_test.dart`'s `_createRelayPacketsTableV9`
/// (E14-B04: this suite's own representative sample never entered the
/// v9->v10 rebuild until this builder was added -- see `_createV9Tables`
/// and the standalone v9 test below).
void _createRelayPacketsTableV9(sqlite3.Database raw) {
  raw.execute('''
    CREATE TABLE relay_packets (
      id TEXT NOT NULL,
      destination_id TEXT NOT NULL,
      payload BLOB NOT NULL,
      priority INTEGER NOT NULL,
      size_bytes INTEGER NOT NULL,
      created_at INTEGER NOT NULL,
      expires_at INTEGER NOT NULL,
      delivery_state TEXT NOT NULL,
      PRIMARY KEY (id)
    );
  ''');
}

/// The v9 schema -- everything E01-E04-T04 created. `messages` does not
/// exist yet at v9 (it is introduced only by the `from < 11` step further
/// down `onUpgrade`), so this is NOT part of the `representativeVersions`
/// map below (whose shared loop body seeds a `messages` row via
/// `_seedDeviceAndMessageRows`) -- it gets its own standalone test instead,
/// composed from the v7/v8/v9 builders exactly as
/// `relay_retention_migration_test.dart` itself composes its own v9->v10
/// case.
void _createV9Tables(sqlite3.Database raw) {
  _createV7Tables(raw);
  _createRoutesTable(raw);
  _createRelayPacketsTableV9(raw);
}

/// The exact v11 `messages` + `delivery_states` DDL (E05-T01), including the
/// `idx_messages_conversation_created_at` index that step's migration
/// creates explicitly -- copied verbatim from `sync_migration_test.dart`'s
/// `_createMessagesTablesV11`.
void _createMessagesTablesV11(sqlite3.Database raw) {
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
  raw.execute('''
    CREATE TABLE delivery_states (
      message_id TEXT NOT NULL,
      state TEXT NOT NULL,
      changed_at INTEGER NOT NULL,
      PRIMARY KEY (message_id, state)
    );
  ''');
  raw.execute(
    'CREATE INDEX IF NOT EXISTS idx_messages_conversation_created_at '
    'ON messages (conversation_id, created_at);',
  );
}

/// The v11 schema, composed from the four builders above (the same
/// composition `sync_migration_test.dart` itself uses).
void _createV11Tables(sqlite3.Database raw) {
  _createV7Tables(raw);
  _createRoutesTable(raw);
  _createRelayPacketsTableV10(raw);
  _createMessagesTablesV11(raw);
}

/// The full v13 schema -- everything E01-E07 created -- copied verbatim
/// from `database_migration_test.dart`'s `_createV13Tables`.
void _createV13Tables(sqlite3.Database raw) {
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
  raw.execute('''
    CREATE TABLE groups (
      id TEXT NOT NULL,
      name TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      created_by_device_id TEXT NOT NULL,
      membership_epoch INTEGER NOT NULL DEFAULT 0,
      is_deleted INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (id)
    );
  ''');
  raw.execute('''
    CREATE TABLE group_members (
      group_id TEXT NOT NULL,
      device_id TEXT NOT NULL,
      role TEXT NOT NULL,
      joined_at_epoch INTEGER NOT NULL,
      removed_at_epoch INTEGER NULL,
      PRIMARY KEY (group_id, device_id)
    );
  ''');
  raw.execute(
    'CREATE INDEX idx_group_members_current ON group_members '
    '(group_id, removed_at_epoch);',
  );
  raw.execute(
    'CREATE UNIQUE INDEX idx_group_single_owner ON group_members (group_id) '
    "WHERE role = 'owner' AND removed_at_epoch IS NULL;",
  );
  raw.execute('''
    CREATE TABLE group_sender_keys (
      group_id TEXT NOT NULL,
      sender_device_id TEXT NOT NULL,
      membership_epoch INTEGER NOT NULL,
      record BLOB NOT NULL,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (group_id, sender_device_id, membership_epoch)
    );
  ''');
  raw.execute('''
    CREATE TABLE group_events (
      id TEXT NOT NULL,
      group_id TEXT NOT NULL,
      epoch INTEGER NOT NULL,
      kind TEXT NOT NULL,
      actor_device_id TEXT NOT NULL,
      subject_device_id TEXT NULL,
      created_at INTEGER NOT NULL,
      PRIMARY KEY (id)
    );
  ''');
  raw.execute(
    'CREATE INDEX idx_group_events_group_epoch ON group_events '
    '(group_id, epoch);',
  );
}

/// The full v16 schema -- everything E01-E10 created, including the default
/// rows the storage/location/notification upgrade steps each insert --
/// copied verbatim from `revocation_migration_test.dart`'s
/// `_createV16Tables`. This is the fullest representative intermediate
/// schema available (only `device_revocations` and `version_policy_cache`
/// remain to reach the current version).
void _createV16Tables(sqlite3.Database raw) {
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
  raw.execute('''
    CREATE TABLE groups (
      id TEXT NOT NULL,
      name TEXT NOT NULL,
      created_at INTEGER NOT NULL,
      created_by_device_id TEXT NOT NULL,
      membership_epoch INTEGER NOT NULL DEFAULT 0,
      is_deleted INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (id)
    );
  ''');
  raw.execute('''
    CREATE TABLE group_members (
      group_id TEXT NOT NULL,
      device_id TEXT NOT NULL,
      role TEXT NOT NULL,
      joined_at_epoch INTEGER NOT NULL,
      removed_at_epoch INTEGER NULL,
      PRIMARY KEY (group_id, device_id)
    );
  ''');
  raw.execute(
    'CREATE INDEX idx_group_members_current ON group_members '
    '(group_id, removed_at_epoch);',
  );
  raw.execute(
    'CREATE UNIQUE INDEX idx_group_single_owner ON group_members (group_id) '
    "WHERE role = 'owner' AND removed_at_epoch IS NULL;",
  );
  raw.execute('''
    CREATE TABLE group_sender_keys (
      group_id TEXT NOT NULL,
      sender_device_id TEXT NOT NULL,
      membership_epoch INTEGER NOT NULL,
      record BLOB NOT NULL,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (group_id, sender_device_id, membership_epoch)
    );
  ''');
  raw.execute('''
    CREATE TABLE group_events (
      id TEXT NOT NULL,
      group_id TEXT NOT NULL,
      epoch INTEGER NOT NULL,
      kind TEXT NOT NULL,
      actor_device_id TEXT NOT NULL,
      subject_device_id TEXT NULL,
      created_at INTEGER NOT NULL,
      PRIMARY KEY (id)
    );
  ''');
  raw.execute(
    'CREATE INDEX idx_group_events_group_epoch ON group_events '
    '(group_id, epoch);',
  );
  raw.execute('''
    CREATE TABLE storage_item_stats (
      item_kind TEXT NOT NULL,
      item_id TEXT NOT NULL,
      last_accessed_at INTEGER NULL,
      access_count INTEGER NOT NULL DEFAULT 0,
      PRIMARY KEY (item_kind, item_id)
    );
  ''');
  raw.execute(
    'CREATE INDEX idx_storage_item_stats_last_accessed ON storage_item_stats '
    '(last_accessed_at);',
  );
  raw.execute('''
    CREATE TABLE storage_policy_settings (
      id INTEGER NOT NULL,
      mode TEXT NOT NULL,
      older_than_days INTEGER NULL,
      max_bytes INTEGER NULL,
      budget_bytes INTEGER NULL,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (id)
    );
  ''');
  raw.execute('''
    CREATE TABLE storage_decisions (
      id TEXT NOT NULL,
      decided_at INTEGER NOT NULL,
      mode TEXT NOT NULL,
      category_key TEXT NOT NULL,
      item_count INTEGER NOT NULL,
      bytes INTEGER NOT NULL,
      reason_code TEXT NOT NULL,
      reason_detail TEXT NULL,
      outcome TEXT NOT NULL,
      PRIMARY KEY (id)
    );
  ''');
  raw.execute(
    'CREATE INDEX idx_storage_decisions_decided_at ON storage_decisions '
    '(decided_at);',
  );
  raw.execute(
    "INSERT INTO storage_policy_settings (id, mode, updated_at) "
    "VALUES (1, 'smart', 1000);",
  );
  raw.execute('''
    CREATE TABLE location_settings (
      id INTEGER NOT NULL,
      global_enabled INTEGER NOT NULL DEFAULT 0,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (id)
    );
  ''');
  raw.execute('''
    CREATE TABLE location_peer_settings (
      peer_device_id TEXT NOT NULL,
      enabled INTEGER NOT NULL DEFAULT 0,
      updated_at INTEGER NOT NULL,
      PRIMARY KEY (peer_device_id)
    );
  ''');
  raw.execute('''
    CREATE TABLE location_fixes (
      peer_device_id TEXT NOT NULL,
      latitude REAL NOT NULL,
      longitude REAL NOT NULL,
      accuracy_m REAL NULL,
      captured_at INTEGER NOT NULL,
      received_at INTEGER NOT NULL,
      PRIMARY KEY (peer_device_id)
    );
  ''');
  raw.execute(
    'CREATE INDEX idx_location_fixes_captured_at ON location_fixes '
    '(captured_at);',
  );
  raw.execute(
    "INSERT INTO location_settings (id, global_enabled, updated_at) "
    "VALUES (1, 0, 1000);",
  );
  raw.execute('''
    CREATE TABLE notification_category_settings (
      category TEXT NOT NULL,
      enabled INTEGER NOT NULL DEFAULT 1,
      PRIMARY KEY (category)
    );
  ''');
  raw.execute('''
    CREATE TABLE notification_preferences (
      id INTEGER NOT NULL,
      privacy_level TEXT NOT NULL DEFAULT 'hidden',
      PRIMARY KEY (id)
    );
  ''');
  for (final category in const [
    'message',
    'voiceMessage',
    'ptt',
    'incomingCall',
    'connectionRequest',
    'trustRequest',
    'groupEvent',
    'securityEvent',
    'storageWarning',
  ]) {
    raw.execute(
      "INSERT INTO notification_category_settings (category, enabled) "
      "VALUES ('$category', 1);",
    );
  }
  raw.execute(
    "INSERT INTO notification_preferences (id, privacy_level) "
    "VALUES (0, 'hidden');",
  );
}

/// Seeds one `device_identities` row and (when the table already exists at
/// this fixture's version) one `messages` row, tagged so multiple
/// parameterized tests never collide on the same primary key.
void _seedDeviceAndMessageRows(sqlite3.Database raw, {required String tag}) {
  raw.execute(
    "INSERT INTO device_identities (device_id, signed_in) "
    "VALUES ('$tag-device', 1);",
  );
  raw.execute(
    "INSERT INTO messages "
    "(id, conversation_id, sender_device_id, sequence_number, ciphertext, "
    "created_at, delivery_state) "
    "VALUES ('$tag-msg', 'conv-$tag', 'device-A', 7, X'DEADBEEF', 424242, "
    "'delivered');",
  );
}

void main() {
  test(
    'test_EARS_VER_15_v1_to_current_preserves_seeded_rows_byte_identical',
    () async {
      // `messages` does not exist at schema v1 -- it is created by the
      // `from < 11` step (E05-T01, `lib/core/persistence/database.dart`).
      // The only v1 table is `device_identities`, so that is the only table
      // this test can seed at v1; a `messages`-row-survives-the-full-chain
      // proof is covered by the v11 case of
      // `test_EARS_VER_16_intermediate_version_to_current_preserves_rows`
      // below, which is strictly the LONGEST possible chain a seeded
      // `messages` row could ever have to survive (v11 is the earliest
      // version it can exist at). Between the two, every `FR-VER-009`-named
      // table this codebase has (`device_identities`, `messages`) is proven
      // to survive its own longest-possible upgrade path.
      final raw = sqlite3.sqlite3.openInMemory();
      _createV1DeviceIdentitiesTable(raw);
      raw.execute(
        "INSERT INTO device_identities (device_id, signed_in) "
        "VALUES ('v1-device-signed-out', 0);",
      );
      raw.execute(
        "INSERT INTO device_identities (device_id, signed_in) "
        "VALUES ('v1-device-signed-in', 1);",
      );
      raw.userVersion = 1;

      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      // Verify the real current schemaVersion live, not a number hard-coded
      // while writing this task (task §6 risk note) -- opening at
      // `db.schemaVersion` triggers the full onUpgrade(from: 1, to: current)
      // chain.
      expect(db.schemaVersion, greaterThanOrEqualTo(18));

      final rows = await db.select(db.deviceIdentities).get();
      expect(rows, hasLength(2));

      final signedOut = rows.singleWhere(
        (r) => r.deviceId == 'v1-device-signed-out',
      );
      expect(signedOut.signedIn, isFalse);
      expect(signedOut.signedInAt, isNull);
      // No account link existed at v1 -- the v1->v2 step (`from < 2`) only
      // ADDS the column, it never backfills a value (task §4/§8:
      // additive-only migration must not invent data for a pre-existing
      // row).
      expect(signedOut.accountUid, isNull);

      final signedIn = rows.singleWhere(
        (r) => r.deviceId == 'v1-device-signed-in',
      );
      expect(signedIn.signedIn, isTrue);
      expect(signedIn.signedInAt, isNull);
      expect(signedIn.accountUid, isNull);
    },
  );

  // EARS-VER-16 / E14-B04: v9 is the one representative start version below
  // the `representativeVersions` map further down whose migration to
  // current MUST cross the v9->v10 `relay_packets` rebuild
  // (`database.dart:254-315`) -- the only step in the ENTIRE onUpgrade
  // chain that runs a real `DROP TABLE`. Every version in the map below
  // starts at v11 or later, i.e. strictly AFTER that step already ran, so
  // none of them ever enters it -- that drop is otherwise proven only by a
  // different epic's file (`relay_retention_migration_test.dart`, scoped
  // narrowly to v9->v10 alone), never by this suite's own "sample of
  // intermediate versions a real install could resume from" claim
  // (`EARS-VER-16`). This test closes that gap without duplicating that
  // other file: it proves the SAME rebuild survives the FULL v9->current
  // chain, not just the one v9->v10 step.
  //
  // `messages` does not exist at v9 (see `_createV9Tables`), so this case
  // cannot reuse `_seedDeviceAndMessageRows` below -- it seeds
  // `device_identities` and `relay_packets` instead, the two tables that
  // actually exist at v9, with a row in more than one delivery state (as
  // `relay_retention_migration_test.dart` itself does) so the rebuild's
  // row-copy step is proven for more than a single trivial case.
  test(
    'test_EARS_VER_16_intermediate_version_to_current_preserves_rows_v9',
    () async {
      final raw = sqlite3.sqlite3.openInMemory();
      _createV9Tables(raw);
      raw.execute(
        "INSERT INTO device_identities (device_id, signed_in) "
        "VALUES ('v9-device', 1);",
      );
      raw.execute(
        "INSERT INTO relay_packets "
        "(id, destination_id, payload, priority, size_bytes, created_at, "
        "expires_at, delivery_state) "
        "VALUES ('v9-relay-queued', 'D', X'010203', 5, 3, 1000, 9000, "
        "'queued');",
      );
      raw.execute(
        "INSERT INTO relay_packets "
        "(id, destination_id, payload, priority, size_bytes, created_at, "
        "expires_at, delivery_state) "
        "VALUES ('v9-relay-delivered', 'B', X'0405', 0, 1, 1000, 5000, "
        "'delivered');",
      );
      raw.userVersion = 9;

      final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
      addTearDown(db.close);

      // Force the lazy migration to run before reading rows back.
      await db.customSelect('SELECT 1').get();
      expect(db.schemaVersion, greaterThanOrEqualTo(18));

      final identities = await db.select(db.deviceIdentities).get();
      final identity = identities.singleWhere(
        (r) => r.deviceId == 'v9-device',
      );
      expect(identity.signedIn, isTrue);

      // The v9->v10 step is a create-copy-drop-rename rebuild
      // (`database.dart:285-313`): both rows must survive it, and every
      // other step in the chain, byte-identical -- not merely "a
      // `relay_packets` table exists at the end".
      final relayPackets = await (db.select(db.relayPackets)
            ..orderBy([(t) => OrderingTerm.asc(t.id)]))
          .get();
      expect(relayPackets, hasLength(2));

      final queued = relayPackets.singleWhere(
        (r) => r.id == 'v9-relay-queued',
      );
      expect(queued.destinationId, 'D');
      expect(queued.payload, [0x01, 0x02, 0x03]);
      expect(queued.priority, 5);
      expect(queued.sizeBytes, 3);
      expect(queued.createdAt, 1000);
      expect(queued.expiresAt, 9000);
      expect(queued.deliveryState, 'queued');

      final delivered = relayPackets.singleWhere(
        (r) => r.id == 'v9-relay-delivered',
      );
      expect(delivered.destinationId, 'B');
      expect(delivered.payload, [0x04, 0x05]);
      expect(delivered.priority, 0);
      expect(delivered.sizeBytes, 1);
      expect(delivered.createdAt, 1000);
      expect(delivered.expiresAt, 5000);
      expect(delivered.deliveryState, 'delivered');
    },
  );

  // EARS-VER-16: a representative sample of intermediate versions a real
  // install could plausibly resume from, reusing the same
  // "open at vN, migrate to current" pattern every per-task migration test
  // file in this directory already establishes --
  // v11 (the version `messages` is introduced at -- the longest possible
  // chain a seeded message row can be asked to survive), v13 (group data
  // model added), and v16 (the fullest available intermediate schema, only
  // two steps short of current). v9 -- the one version below all of these
  // whose chain crosses the suite's only destructive step -- has its own
  // standalone test just above instead of a map entry, because `messages`
  // does not exist yet at v9 (see that test's own comment).
  final representativeVersions = <int, void Function(sqlite3.Database)>{
    11: _createV11Tables,
    13: _createV13Tables,
    16: _createV16Tables,
  };

  for (final entry in representativeVersions.entries) {
    final version = entry.key;
    final buildSchema = entry.value;
    final tag = 'v$version';

    test(
      'test_EARS_VER_16_intermediate_version_to_current_preserves_rows_$tag',
      () async {
        final raw = sqlite3.sqlite3.openInMemory();
        buildSchema(raw);
        _seedDeviceAndMessageRows(raw, tag: tag);
        raw.userVersion = version;

        final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
        addTearDown(db.close);

        // Force the lazy migration to run before reading rows back.
        await db.customSelect('SELECT 1').get();
        expect(db.schemaVersion, greaterThanOrEqualTo(18));

        final identities = await db.select(db.deviceIdentities).get();
        final identity = identities.singleWhere(
          (r) => r.deviceId == '$tag-device',
        );
        expect(identity.signedIn, isTrue);

        final messages = await db.select(db.messages).get();
        final message = messages.singleWhere((r) => r.id == '$tag-msg');
        expect(message.conversationId, 'conv-$tag');
        expect(message.senderDeviceId, 'device-A');
        expect(message.sequenceNumber, 7);
        expect(message.ciphertext, [0xDE, 0xAD, 0xBE, 0xEF]);
        expect(message.createdAt, 424242);
        expect(message.deliveryState, 'delivered');
      },
    );
  }
}
