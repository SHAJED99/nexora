// core/services — DeviceDirectoryService (E11-T06, FR-FB-001, FR-FB-002,
// NFR-PRIV-001, `ADR-0008` option 2).
//
// Publishes and looks up the one cross-account-readable node this project
// has: `directory/$deviceId`, holding a device's public identity key,
// current (public) prekey bundle, and revocation flag. This is the
// mechanism `ADR-0008` authorised, not the consumer -- it does not by
// itself close the `E07` TOFU gap or give `E06-T07` its Firebase fallback,
// it makes both fixable (task §1).
//
// `ADR-0008` is binding here, not advisory (task §2): (a) a read at
// `directory` (the parent) must be denied -- only `directory/$deviceId`
// (an exact, already-known id) may ever be read, by any authenticated
// account; (b) nothing published is anything other than public-by-
// construction material -- a public key, a public prekey bundle, and a
// boolean-shaped revocation timestamp, never a private key, session key,
// or session state (`ADR-0005`). Both properties are enforced structurally
// by `database.rules.json`, proven by `firebase_rules_test.dart`; nothing
// in this file re-derives or second-guesses that enforcement.
//
// `identityPublicKey`/`prekeyBundle` come from `IdentityService`'s own
// `getLocalPreKeyBundle()` -- the same `PreKeyBundle` `PrekeyExchange`
// (E06-T07) already assembles for the mesh, serialized through
// `PreKeyBundleCodec.serialize` verbatim (task §2, "reuses E06-T07's wire
// codec verbatim, does not re-derive the format"). Every accessor this file
// calls on the resulting `PreKeyBundle` (`getIdentityKey`) is one of that
// class's own public-material getters -- there is no private-key accessor
// on it for this file to reach even by mistake, same guarantee
// `PreKeyBundleCodec`'s own header already documents.
//
// Publish is event-triggered only (task §2/§4): `IdentityService.
// ensureSignedPreKey`/`replenishOneTimePreKeys` and
// `DeviceRevocationService.revoke` call `publish` at the point they already
// change what should be published -- this file adds no `Timer`, no polling,
// no second driver (the one-tick invariant `E08-T06`/`E10-T08` established).
//
// `revokedAt` is read directly from `E11-T04`'s local `device_revocations`
// table -- this device's own recorded revocation status for [deviceId], not
// re-derived from a Firebase read (`DeviceRevocationService.isRevoked` only
// returns a bool; this file needs the row's own timestamp, so it queries
// the same table directly rather than adding a method to a file outside
// this task's fence).
//
// Firebase boundary (FR-FB-002, non-negotiable): the Firebase read/write
// methods below mirror `DeviceRevocationService`'s exact pattern (E11-T04)
// -- best-effort, bounded timeout via
// `.timeout()`, catch-and-log via `ObservabilityService`, never throws to
// the caller. Only `identityPublicKey`/`prekeyBundle`/`revokedAt` are ever
// written to the public `directory/$deviceId` node -- never anything
// outside `FirebaseBoundary`'s allow-list for it. `ownerUid` (`E11-B06`
// fix) is written to its own node, `directory_private/$deviceId/ownerUid`,
// in the SAME atomic multi-location update -- never co-located with the
// public entry, so it is never cross-account readable alongside it.
//
// Scope fence (task §4): does NOT touch `DriftSignalProtocolStore.
// isTrustedIdentity` or anything in `E07`; does NOT wire `lookupDevice` into
// `PrekeyExchange` or any `E06` file; does NOT publish a private key,
// session key, or session state; does NOT add polling or a scheduled
// republish; does NOT implement `relationships/$peerDeviceId` (E11-T05,
// already shipped); does NOT add a UI/settings screen; does NOT change
// `PreKeyBundleCodec`'s wire format or version.
import 'dart:convert';

import 'package:firebase_database/firebase_database.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/crypto/identity_key_hex.dart';
import 'package:nexora/core/crypto/identity_service.dart';
import 'package:nexora/core/crypto/prekey_bundle_codec.dart';
import 'package:nexora/core/observability/observability_service.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/services/firebase_boundary.dart';
import 'package:nexora/core/services/firebase_paths.dart';

/// The result of a successful [DeviceDirectoryService.lookupDevice] --
/// exactly the public material `directory/$deviceId` carries, decoded back
/// into domain types. `null` fields are absent-in-Firebase, never a
/// decoding failure (a malformed entry is treated the same as "not found",
/// per [DeviceDirectoryService.lookupDevice]'s own doc comment).
class DirectoryEntry {
  DirectoryEntry({
    required this.identityPublicKey,
    required this.preKeyBundle,
    required this.revokedAt,
  });

  /// This device's public identity key, decoded from the same bytes
  /// [PreKeyBundleCodec] would also carry inside [preKeyBundle] -- kept as
  /// its own field because a caller resolving "is this the identity I
  /// already trust" (`E07`'s own future consumer) needs it without first
  /// deserializing the whole prekey bundle.
  final IdentityKey identityPublicKey;

  /// The device's current prekey bundle, decoded through
  /// [PreKeyBundleCodec.deserialize] -- never re-derived or re-parsed by
  /// this file's own logic.
  final PreKeyBundle preKeyBundle;

  /// This device's own recorded revocation timestamp, or `null` if it has
  /// never been revoked.
  final DateTime? revokedAt;
}

class DeviceDirectoryService {
  DeviceDirectoryService({
    required IdentityService identityService,
    required AppDatabase database,
    FirebaseDatabase? firebaseDatabase,
    Duration? timeout,
  })  : // Named params (`identityService`/`database`) are public API; the
        // private fields below can't share those names, so
        // `prefer_initializing_formals` doesn't apply here -- same
        // reasoning as `DeviceRevocationService`.
        _identityService = identityService, // ignore: prefer_initializing_formals
        _database = database, // ignore: prefer_initializing_formals
        _firebaseDatabaseOverride = firebaseDatabase,
        // Same reasoning as DeviceRevocationService._timeout:
        // a Realtime Database write/read
        // queued offline never completes at all, so this bounds it -- a
        // timeout is just another failure mode, caught below like any
        // other Realtime Database error.
        _timeout = timeout ?? const Duration(seconds: 10);

  final IdentityService _identityService;
  final AppDatabase _database;
  final FirebaseDatabase? _firebaseDatabaseOverride;
  final Duration _timeout;

  // Resolved lazily, mirroring DeviceRevocationService._firebaseDatabase --
  // so constructing a DeviceDirectoryService with no override never touches
  // a live Realtime Database instance until a read/write is actually
  // attempted.
  FirebaseDatabase get _firebaseDatabase =>
      _firebaseDatabaseOverride ?? FirebaseDatabase.instance;

  /// Assembles this device's public identity key, current prekey bundle,
  /// and own-recorded revocation timestamp, and best-effort publishes them
  /// to `directory/$deviceId` (EARS-FB-17). Called from
  /// `IdentityService.ensureSignedPreKey`/`replenishOneTimePreKeys` and
  /// `DeviceRevocationService.revoke` -- the three existing events that
  /// change what should be published (task §2/§3) -- never from a Timer or
  /// any other polling driver.
  ///
  /// [uid] is written into `directory_private/$deviceId/ownerUid` on every
  /// call, including the first (`E11-B06` fix) -- `database.rules.json`
  /// makes that field immutable after the node's first write, so every
  /// subsequent call from the true owner must (and does) keep passing the
  /// same value, and any other caller's write is rejected server-side
  /// regardless of what this method sends.
  ///
  /// Never throws: any failure -- including
  /// `IdentityService.getLocalPreKeyBundle()` throwing `StateError` because
  /// identity/prekey bootstrap hasn't finished yet -- is caught and logged
  /// via `ObservabilityService`, exactly like every other best-effort
  /// Firebase writer in this codebase (`DeviceRevocationService.revoke`).
  Future<void> publish(String uid, String deviceId) async {
    try {
      await _publish(uid, deviceId).timeout(_timeout);
    } catch (e) {
      ObservabilityService.instance.logError(
        'firebase.device_directory_publish_failed',
        cause: e,
      );
    }
  }

  Future<void> _publish(String uid, String deviceId) async {
    final bundle = await _identityService.getLocalPreKeyBundle();
    final serializedBundle = base64Encode(PreKeyBundleCodec.serialize(bundle));
    // E11-B06 finding 1: hex, not base64 -- this value doubles as `deviceId`
    // for a device's very first publish (`LoginController`'s own
    // derivation), and a standard-base64 string can contain `/`, which the
    // Firebase SDK's `.child(path)` always treats as a path separator. See
    // `identity_key_hex.dart`'s own header for the full reasoning.
    final identityPublicKey = hexEncodeIdentityKey(bundle.getIdentityKey());

    final revocationRow = await (_database.select(_database.deviceRevocations)
          ..where((t) => t.deviceId.equals(deviceId)))
        .getSingleOrNull();

    final data = <String, Object?>{
      'identityPublicKey': identityPublicKey,
      'prekeyBundle': serializedBundle,
      if (revocationRow != null)
        'revokedAt': revocationRow.revokedAt.millisecondsSinceEpoch,
    };
    // EARS-FB-17/task §6 Risks: the guard runs *before* the write below --
    // a boundary violation is a programming error and must propagate, not
    // get caught and logged as "just another Firebase error" (same
    // reasoning as DeviceRevocationService.revoke).
    FirebaseBoundary.assertAllowedFields(FirebaseNodeKind.directory, data);
    // `ownerUid` (`E11-B06` fix) is boundary-checked separately against its
    // own, narrower allow-list -- it is never part of the public payload
    // above.
    FirebaseBoundary.assertAllowedFields(
      FirebaseNodeKind.directoryPrivate,
      {'ownerUid': uid},
    );
    await writeDirectoryData(deviceId, uid, data);
  }

  /// Performs the actual Realtime Database write. Split out from [publish]
  /// deliberately -- `FirebaseDatabase`/`DatabaseReference` need a live
  /// platform-channel test harness to construct in tests, so tests seam
  /// here instead (mirrors `DeviceRevocationService.writeRevocationData`).
  ///
  /// Writes [data] to [FirebasePaths.directoryEntry] (the public entry) and
  /// [uid] to [FirebasePaths.directoryPrivateOwnerUid] (the write-ownership
  /// marker, `E11-B06` fix) as ONE atomic multi-location update -- not
  /// merely for crash-safety, but because it is REQUIRED for correctness:
  /// `directory/$deviceId`'s own `.write` rule authorizes against
  /// `newData.parent().parent().child('directory_private')...` -- the
  /// Realtime Database idiom for reading a sibling path written in the
  /// SAME multi-location update. A rule evaluating `root.child(...)`
  /// instead (an earlier, broken draft of this fix, caught by review and
  /// verified against a real `@firebase/rules-unit-testing` emulator)
  /// sees only the PRE-write snapshot even inside a multi-location update,
  /// which would permanently deny every new device's first publish -- the
  /// private node would never exist yet, and no caller's uid could ever
  /// match a value that isn't there. Two separate `.set()` calls would
  /// break this rule's ability to see the private write at all, not just
  /// weaken crash-safety.
  Future<void> writeDirectoryData(
    String deviceId,
    String uid,
    Map<String, dynamic> data,
  ) {
    return _firebaseDatabase.ref().update({
      FirebasePaths.directoryEntry(deviceId): data,
      FirebasePaths.directoryPrivateOwnerUid(deviceId): uid,
    });
  }

  /// Reads `directory/$deviceId` for one already-known, exact [deviceId]
  /// and decodes it back into a [DirectoryEntry] (EARS-FB-18). Returns
  /// `null` if the entry is absent, malformed, or the read fails/times out
  /// -- never throws, and never falls back to any listing or query (task
  /// §2: "that distinction is not a style preference; it is the entire
  /// privacy argument `ADR-0008` makes for option 2").
  Future<DirectoryEntry?> lookupDevice(String deviceId) async {
    final Object? raw;
    try {
      raw = await readDirectoryData(deviceId).timeout(_timeout);
    } catch (e) {
      ObservabilityService.instance.logError(
        'firebase.device_directory_lookup_failed',
        cause: e,
      );
      return null;
    }

    if (raw is! Map) return null;
    final identityPublicKeyRaw = raw['identityPublicKey'];
    final prekeyBundleRaw = raw['prekeyBundle'];
    if (identityPublicKeyRaw is! String || prekeyBundleRaw is! String) {
      return null;
    }

    try {
      final preKeyBundle =
          PreKeyBundleCodec.deserialize(base64Decode(prekeyBundleRaw));
      final identityPublicKey = hexDecodeIdentityKey(identityPublicKeyRaw);

      // E11-B02: `identityPublicKey` and the identity key embedded inside
      // `prekeyBundle` are written from the SAME bundle by `publish`, so an
      // honest entry is always self-consistent. This node is cross-account
      // readable AND writable by design (`ADR-0008` option 2), so a forged
      // entry could otherwise assert two different identities to this
      // file's two different future consumers (E07's TOFU check would read
      // `identityPublicKey`; E06-T07's fallback would read `preKeyBundle`).
      // Treat a mismatch exactly like a malformed entry -- log and return
      // null. Constant-time comparison is not required: both values are
      // public.
      if (!_bytesEqual(
        identityPublicKey.serialize(),
        preKeyBundle.getIdentityKey().serialize(),
      )) {
        // E13-B02: never interpolate `deviceId` (or any other identifier)
        // into this message -- it reaches `Sentry.captureException`
        // verbatim via `ObservabilityService`, and FR-DIAG-002 forbids
        // shipping an identifier to a third-party vendor. The stable
        // `code` argument above already says which failure this is; a
        // reader of the privacy-scoped error report needs the KIND of
        // mismatch, not which device triggered it.
        ObservabilityService.instance.logError(
          'firebase.device_directory_lookup_identity_mismatch',
          cause: StateError(
            'directory entry: identityPublicKey field disagrees with the '
            'identity key embedded in prekeyBundle',
          ),
        );
        return null;
      }

      final revokedAtRaw = raw['revokedAt'];
      final revokedAt = revokedAtRaw is int
          ? DateTime.fromMillisecondsSinceEpoch(revokedAtRaw)
          : null;
      return DirectoryEntry(
        identityPublicKey: identityPublicKey,
        preKeyBundle: preKeyBundle,
        revokedAt: revokedAt,
      );
    } catch (e) {
      // A malformed entry (bad base64/hex, undecodable codec bytes) is
      // treated as "not found", not as a crash -- the caller cannot do
      // anything more useful with a half-decoded entry than with a
      // missing one.
      ObservabilityService.instance.logError(
        'firebase.device_directory_lookup_malformed',
        cause: e,
      );
      return null;
    }
  }

  /// Performs the actual Realtime Database read of exactly
  /// `directory/$deviceId` -- never `directory` itself. Split out from
  /// [lookupDevice] for the same test-seam reason as [writeDirectoryData].
  Future<Object?> readDirectoryData(String deviceId) async {
    final snapshot =
        await _firebaseDatabase.ref(FirebasePaths.directoryEntry(deviceId)).get();
    return snapshot.value;
  }
}

/// Byte-for-byte comparison used by [DeviceDirectoryService.lookupDevice]'s
/// E11-B02 identity-binding check. Mirrors
/// `lib/features/messaging/domain/message.dart`'s own `_listEquals` --
/// both values compared here are public key material, so constant-time
/// comparison is unnecessary.
bool _bytesEqual(List<int> a, List<int> b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}
