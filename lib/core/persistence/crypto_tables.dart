// core/persistence — Signal protocol store tables (ADR-0003, E03-T01).
//
// Storage seam only: these tables hold the library's own `.serialize()`
// bytes for identity/prekey/session state so `DriftSignalProtocolStore`
// (lib/core/crypto/drift_signal_store.dart) has somewhere durable to keep
// them. No key generation and no encrypt/decrypt logic lives here — that's
// E03-T02/T03. Session/ratchet state is local-only, never synced to
// Firebase (`FR-FB-002`, epic.md "Data model").
import 'package:drift/drift.dart';

/// Singleton row (fixed `id = 0`, enforced in code, never autoincrement) —
/// this device's own Signal identity keypair + registration id. A second
/// row must never be written; regenerating the identity would orphan every
/// session a peer has with this device (epic.md §2).
class SignalIdentity extends Table {
  @override
  String get tableName => 'signal_identity';

  IntColumn get id => integer()();
  BlobColumn get identityKeyPair => blob()();
  IntColumn get registrationId => integer()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One row per signed prekey, keyed by the library's own prekey id (not
/// autoincrement).
class SignalSignedPrekeys extends Table {
  @override
  String get tableName => 'signal_signed_prekeys';

  IntColumn get id => integer()();
  BlobColumn get record => blob()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One row per one-time prekey, keyed by the library's own prekey id (not
/// autoincrement). Consumed (removed) exactly once per X3DH.
class SignalOneTimePrekeys extends Table {
  @override
  String get tableName => 'signal_one_time_prekeys';

  IntColumn get id => integer()();
  BlobColumn get record => blob()();

  @override
  Set<Column> get primaryKey => {id};
}

/// One row per remote device session, keyed by the library's
/// `SignalProtocolAddress` (`name` + `deviceId`).
class SignalSessions extends Table {
  @override
  String get tableName => 'signal_sessions';

  TextColumn get addressName => text()();
  IntColumn get addressDeviceId => integer()();
  BlobColumn get record => blob()();

  @override
  Set<Column> get primaryKey => {addressName, addressDeviceId};
}

/// One row per remote peer whose identity key this device has trusted,
/// keyed by the library's `SignalProtocolAddress` (`name` + `deviceId`).
/// E03-T01b: closes OQ-E03-T01-1 — this state must survive a process
/// restart so a changed remote identity key (MITM/safety-number-change
/// signal) is still detected in a later app session, not just within the
/// process that first observed it (FR-SEC-003, FR-SEC-004).
class SignalTrustedIdentities extends Table {
  @override
  String get tableName => 'signal_trusted_identities';

  TextColumn get addressName => text()();
  IntColumn get addressDeviceId => integer()();
  BlobColumn get identityKey => blob()();

  @override
  Set<Column> get primaryKey => {addressName, addressDeviceId};
}
