// Trust-persistence tests for DriftSignalProtocolStore (E03-T01b,
// EARS-SEC-3d). Closes OQ-E03-T01-1: the reviewer-found defect where
// remote-peer identity trust lived in an in-memory Map and was forgotten on
// every process restart.
//
// The restart-simulation test (§6 "Risks") deliberately constructs a SECOND
// `DriftSignalProtocolStore` instance over the SAME underlying `AppDatabase`
// connection, not the same instance and not a fresh in-memory DB — reusing
// the same instance would pass even with the old in-memory-Map bug, since
// the Map would still hold the value in that instance.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/crypto/drift_signal_store.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  test('test_EARS_SEC_3d_identity_trust_survives_restart', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);

    final address = SignalProtocolAddress('+15551234567', 1);
    final originalKeyPair = generateIdentityKeyPair();
    final originalIdentity = originalKeyPair.getPublicKey();

    // Session 1: save trust for the peer's original identity key.
    final firstStore = DriftSignalProtocolStore(db);
    await firstStore.saveIdentity(address, originalIdentity);

    // Simulate an app restart: a fresh store *instance* over the same
    // underlying `AppDatabase` connection (not the same instance, not a
    // new in-memory DB).
    final secondStore = DriftSignalProtocolStore(db);

    // The original key is still trusted.
    expect(
      await secondStore.isTrustedIdentity(
        address,
        originalIdentity,
        Direction.receiving,
      ),
      isTrue,
    );

    // A different key for the same address is correctly rejected — this is
    // the exact defect the reviewer found: with the old in-memory Map, a
    // fresh instance would have no record at all and trust-on-first-use
    // would wrongly accept the changed key.
    final differentKeyPair = generateIdentityKeyPair();
    final differentIdentity = differentKeyPair.getPublicKey();
    expect(
      await secondStore.isTrustedIdentity(
        address,
        differentIdentity,
        Direction.receiving,
      ),
      isFalse,
    );

    // getIdentity on the new instance still returns the persisted key.
    final loaded = await secondStore.getIdentity(address);
    expect(loaded, originalIdentity);
  });

  test('test_EARS_SEC_3d_migration_adds_trusted_identities_table', () async {
    final raw = sqlite3.sqlite3.openInMemory();
    // The exact v4 schema (post-E03-T01, pre-E03-T01b): device_identities,
    // relationships, signal_identity, signal_signed_prekeys,
    // signal_one_time_prekeys, signal_sessions — no
    // signal_trusted_identities table yet.
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
        id INTEGER NOT NULL PRIMARY KEY,
        identity_key_pair BLOB NOT NULL,
        registration_id INTEGER NOT NULL
      );
    ''');
    raw.execute('''
      CREATE TABLE signal_signed_prekeys (
        id INTEGER NOT NULL PRIMARY KEY,
        record BLOB NOT NULL
      );
    ''');
    raw.execute('''
      CREATE TABLE signal_one_time_prekeys (
        id INTEGER NOT NULL PRIMARY KEY,
        record BLOB NOT NULL
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
    raw.execute(
      "INSERT INTO device_identities (device_id, signed_in) VALUES ('pre-e03-t01b-device', 0);",
    );
    raw.execute(
      "INSERT INTO signal_sessions (address_name, address_device_id, record) "
      "VALUES ('+15551234567', 1, x'ABCD');",
    );
    raw.userVersion = 4;

    final db = AppDatabase.forTesting(NativeDatabase.opened(raw));
    addTearDown(db.close);

    // Opening at target schemaVersion 5 triggers onUpgrade(from: 4, to: 5).
    final deviceRow = await db.latestDeviceIdentity();
    expect(deviceRow, isNotNull);
    expect(deviceRow!.deviceId, 'pre-e03-t01b-device');

    // T01's four tables and their data are untouched.
    final sessions = await db.select(db.signalSessions).get();
    expect(sessions, hasLength(1));
    expect(sessions.single.addressName, '+15551234567');

    // The new table exists and is usable.
    expect(await db.select(db.signalTrustedIdentities).get(), isEmpty);
  });

  test('test_EARS_SEC_3d_save_identity_return_value_unchanged', () async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    addTearDown(db.close);
    final store = DriftSignalProtocolStore(db);

    final address = SignalProtocolAddress('+15559876543', 1);
    final first = generateIdentityKeyPair().getPublicKey();
    final second = generateIdentityKeyPair().getPublicKey();

    // First save for an address: never a "change".
    expect(await store.saveIdentity(address, first), isFalse);

    // Re-saving the same key: not a change.
    expect(await store.saveIdentity(address, first), isFalse);

    // Saving a genuinely different key: reported as a change.
    expect(await store.saveIdentity(address, second), isTrue);

    // Saving null (removal): the current contract's "changed" definition
    // requires a non-null previous AND a non-null new key, so this is not
    // reported as a change either.
    expect(await store.saveIdentity(address, null), isFalse);
  });
}
