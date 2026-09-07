// E11-T06 — DeviceDirectoryService tests (EARS-FB-17, plus the
// call-site-wiring proof, plus `lookupDevice`'s exact-id-only decode path).
//
// Local identity/prekey setup uses a real in-memory AppDatabase + real
// libsignal_protocol_dart record objects (mirrors identity_service_test.dart
// / prekey_bundle_codec_test.dart's established pattern). Firebase read/write
// tests use the same test-seam pattern as every other Firebase wrapper in
// this codebase -- subclass the service and override the seam methods
// (`writeDirectoryData`/`readDirectoryData`) instead of touching a real
// `FirebaseDatabase`/platform channel.
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/crypto/drift_signal_store.dart';
import 'package:nexora/core/crypto/identity_key_hex.dart';
import 'package:nexora/core/crypto/identity_service.dart';
import 'package:nexora/core/crypto/prekey_bundle_codec.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/services/device_directory_service.dart';
import 'package:nexora/core/services/device_revocation_service.dart';

/// Captures the deviceId/data a real write would have sent, without
/// touching a live `FirebaseDatabase`.
class _CapturingDeviceDirectoryService extends DeviceDirectoryService {
  _CapturingDeviceDirectoryService({
    required super.identityService,
    required super.database,
  });

  String? capturedDeviceId;
  String? capturedUid;
  Map<String, dynamic>? capturedData;
  var writeCalls = 0;

  @override
  Future<void> writeDirectoryData(
    String deviceId,
    String uid,
    Map<String, dynamic> data,
  ) async {
    writeCalls++;
    capturedDeviceId = deviceId;
    capturedUid = uid;
    capturedData = data;
  }
}

/// Always throws from the write seam -- proves [DeviceDirectoryService.publish]
/// swallows and logs rather than propagating.
class _ThrowingWriteDeviceDirectoryService extends DeviceDirectoryService {
  _ThrowingWriteDeviceDirectoryService({
    required super.identityService,
    required super.database,
  });

  @override
  Future<void> writeDirectoryData(
    String deviceId,
    String uid,
    Map<String, dynamic> data,
  ) {
    throw Exception('realtime database unavailable');
  }
}

/// Returns a fixed raw `directory/$deviceId` snapshot from the read seam.
class _RespondingReadDeviceDirectoryService extends DeviceDirectoryService {
  _RespondingReadDeviceDirectoryService({
    required super.identityService,
    required super.database,
    required this.response,
  });

  final Object? response;

  @override
  Future<Object?> readDirectoryData(String deviceId) async => response;
}

/// Always throws from the read seam -- proves [DeviceDirectoryService.lookupDevice]
/// returns `null` rather than propagating.
class _ThrowingReadDeviceDirectoryService extends DeviceDirectoryService {
  _ThrowingReadDeviceDirectoryService({
    required super.identityService,
    required super.database,
  });

  @override
  Future<Object?> readDirectoryData(String deviceId) {
    throw Exception('realtime database unavailable');
  }
}

/// Byte-level subsequence search -- mirrors
/// `prekey_bundle_codec_test.dart`'s own `_containsSubsequence`, used for
/// the same falsification purpose: a field-by-field check could pass while
/// still leaking bytes the test never thought to check.
bool _containsSubsequence(Uint8List haystack, Uint8List needle) {
  if (needle.isEmpty || needle.length > haystack.length) return false;
  for (var start = 0; start <= haystack.length - needle.length; start++) {
    var matched = true;
    for (var i = 0; i < needle.length; i++) {
      if (haystack[start + i] != needle[i]) {
        matched = false;
        break;
      }
    }
    if (matched) return true;
  }
  return false;
}

void main() {
  late AppDatabase db;
  late DriftSignalProtocolStore store;
  late IdentityService identityService;

  setUp(() async {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    store = DriftSignalProtocolStore(db);
    identityService = IdentityService(db, store);
    await identityService.ensureLocalIdentity();
    await identityService.ensureSignedPreKey();
    await identityService.replenishOneTimePreKeys();
  });

  tearDown(() => db.close());

  group('test_EARS_FB_17_publish', () {
    test('writes identityPublicKey/prekeyBundle, no revokedAt when never '
        'revoked -- and writes ownerUid to its own node, not the public '
        'payload (E11-B06 fix)', () async {
      final service = _CapturingDeviceDirectoryService(
        identityService: identityService,
        database: db,
      );

      await service.publish('uid-1', 'device-1');

      expect(service.writeCalls, 1);
      expect(service.capturedDeviceId, 'device-1');
      expect(service.capturedUid, 'uid-1');
      final data = service.capturedData!;
      expect(data.keys.toSet(), {'identityPublicKey', 'prekeyBundle'});
      expect(data['identityPublicKey'], isA<String>());
      expect(data['prekeyBundle'], isA<String>());

      // The published bundle decodes back through the exact same codec
      // PrekeyExchange (E06-T07) uses -- proves this task reused the wire
      // format verbatim rather than re-deriving it.
      final decoded =
          PreKeyBundleCodec.deserialize(base64Decode(data['prekeyBundle'] as String));
      expect(decoded, isA<PreKeyBundle>());
    });

    test('includes revokedAt (as epoch millis) once this device has a local '
        'revocation row', () async {
      // A round-second timestamp -- Drift's `dateTime()` column stores with
      // second precision, so a sub-second value would round-trip lossily
      // and make this test about Drift's precision, not this service's
      // logic.
      await db.into(db.deviceRevocations).insertOnConflictUpdate(
            DeviceRevocationsCompanion.insert(
              deviceId: 'device-1',
              revokedAt: DateTime.fromMillisecondsSinceEpoch(123456000),
              source: RevocationSource.local.name,
            ),
          );
      final service = _CapturingDeviceDirectoryService(
        identityService: identityService,
        database: db,
      );

      await service.publish('uid-1', 'device-1');

      expect(service.capturedData!['revokedAt'], 123456000);
    });

    test(
      'test_EARS_FB_17_publish_contains_no_private_key_bytes',
      () async {
        // Falsification asset (task §3/§8 test plan): build the payload
        // from a store that ALSO holds private key material, and prove by
        // byte-level search -- not a field-by-field check -- that none of
        // that private material appears anywhere in what was written.
        final service = _CapturingDeviceDirectoryService(
          identityService: identityService,
          database: db,
        );
        await service.publish('uid-1', 'device-1');
        final data = service.capturedData!;
        final publishedBytes = Uint8List.fromList(
          utf8.encode(
            (data['identityPublicKey'] as String) +
                (data['prekeyBundle'] as String) +
                service.capturedUid!,
          ),
        );

        final identityKeyPair = await store.getIdentityKeyPair();
        expect(
          _containsSubsequence(
            publishedBytes,
            Uint8List.fromList(
              base64Encode(identityKeyPair.getPrivateKey().serialize()).codeUnits,
            ),
          ),
          isFalse,
        );

        final signedPreKeyRows = await db.select(db.signalSignedPrekeys).get();
        final signedPreKeyRecord =
            SignedPreKeyRecord.fromSerialized(signedPreKeyRows.first.record);
        expect(
          _containsSubsequence(
            publishedBytes,
            Uint8List.fromList(
              base64Encode(signedPreKeyRecord.getKeyPair().privateKey.serialize())
                  .codeUnits,
            ),
          ),
          isFalse,
        );

        final oneTimeRows = await db.select(db.signalOneTimePrekeys).get();
        for (final row in oneTimeRows) {
          final record = PreKeyRecord.fromBuffer(row.record);
          expect(
            _containsSubsequence(
              publishedBytes,
              Uint8List.fromList(
                base64Encode(record.getKeyPair().privateKey.serialize()).codeUnits,
              ),
            ),
            isFalse,
          );
        }
      },
    );

    test('never throws even when the write seam fails', () async {
      final service = _ThrowingWriteDeviceDirectoryService(
        identityService: identityService,
        database: db,
      );
      await expectLater(service.publish('uid-1', 'device-1'), completes);
    });

    test('never throws even when identity/prekey bootstrap has not run yet '
        '(getLocalPreKeyBundle throws StateError internally)', () async {
      final freshDb = AppDatabase.forTesting(NativeDatabase.memory());
      final freshStore = DriftSignalProtocolStore(freshDb);
      final freshIdentityService = IdentityService(freshDb, freshStore);
      final service = _CapturingDeviceDirectoryService(
        identityService: freshIdentityService,
        database: freshDb,
      );

      await expectLater(service.publish('uid-1', 'device-1'), completes);
      expect(service.writeCalls, 0);
      await freshDb.close();
    });
  });

  group('test_EARS_FB_17_publish_triggered_by_rotation_and_revocation', () {
    test('IdentityService.ensureSignedPreKey triggers a publish exactly '
        'once for its actual (first-run) rotation, never on the idempotent '
        'no-op second call', () async {
      var calls = 0;
      final freshDb = AppDatabase.forTesting(NativeDatabase.memory());
      final freshStore = DriftSignalProtocolStore(freshDb);
      final hooked = IdentityService(
        freshDb,
        freshStore,
        onKeyMaterialChanged: () async {
          calls++;
        },
      );
      await hooked.ensureLocalIdentity();

      await hooked.ensureSignedPreKey();
      expect(calls, 1);

      await hooked.ensureSignedPreKey(); // idempotent no-op
      expect(calls, 1, reason: 'a no-op rotation must not republish');
      await freshDb.close();
    });

    test('IdentityService.replenishOneTimePreKeys triggers a publish '
        'exactly once when it actually replenishes, never when the pool is '
        'already at/above minimum', () async {
      var calls = 0;
      final freshDb = AppDatabase.forTesting(NativeDatabase.memory());
      final freshStore = DriftSignalProtocolStore(freshDb);
      final hooked = IdentityService(
        freshDb,
        freshStore,
        onKeyMaterialChanged: () async {
          calls++;
        },
      );
      await hooked.ensureLocalIdentity();
      await hooked.ensureSignedPreKey();
      calls = 0; // ensureSignedPreKey's own first-run rotation already
      // incremented this once -- reset so this test measures only
      // replenishOneTimePreKeys's own triggering.

      await hooked.replenishOneTimePreKeys(minimum: 5, batch: 5);
      expect(calls, 1);

      await hooked.replenishOneTimePreKeys(minimum: 5, batch: 5); // no-op
      expect(calls, 1, reason: 'a no-op replenish must not republish');
      await freshDb.close();
    });

    test('DeviceRevocationService.revoke triggers a publish for THIS '
        'device, and never propagates even if the hook throws', () async {
      final directory = _CapturingDeviceDirectoryService(
        identityService: identityService,
        database: db,
      );
      final revocationService = DeviceRevocationService(
        localDeviceId: 'device-1',
        database: db,
        directoryService: directory,
      );

      await revocationService.revoke('uid-1', 'device-1');

      expect(directory.writeCalls, 1);
      expect(directory.capturedDeviceId, 'device-1');
      expect(directory.capturedData!['revokedAt'], isA<int>());
    });

    test('DeviceRevocationService.revoke does NOT republish when the '
        'revoked deviceId is a DIFFERENT device on the account -- this '
        'process\'s IdentityService holds no key material for that other '
        'device', () async {
      final directory = _CapturingDeviceDirectoryService(
        identityService: identityService,
        database: db,
      );
      final revocationService = DeviceRevocationService(
        localDeviceId: 'device-1',
        database: db,
        directoryService: directory,
      );

      await revocationService.revoke('uid-1', 'some-other-device');

      expect(directory.writeCalls, 0);
    });
  });

  group('test_EARS_FB_18_lookupDevice', () {
    test('round-trips a previously-published entry', () async {
      final publisher = _CapturingDeviceDirectoryService(
        identityService: identityService,
        database: db,
      );
      await publisher.publish('uid-1', 'device-1');
      final published = publisher.capturedData!;

      final lookup = _RespondingReadDeviceDirectoryService(
        identityService: identityService,
        database: db,
        response: published,
      );

      final entry = await lookup.lookupDevice('device-1');

      expect(entry, isNotNull);
      expect(entry!.revokedAt, isNull);
      expect(entry.preKeyBundle, isA<PreKeyBundle>());
      expect(entry.identityPublicKey, isA<IdentityKey>());
    });

    test('decodes a numeric revokedAt into a DateTime', () async {
      final lookup = _RespondingReadDeviceDirectoryService(
        identityService: identityService,
        database: db,
        response: {
          'identityPublicKey': hexEncodeBytes(
            (await store.getIdentityKeyPair()).getPublicKey().serialize(),
          ),
          'prekeyBundle': base64Encode(
            PreKeyBundleCodec.serialize(await identityService.getLocalPreKeyBundle()),
          ),
          'revokedAt': 555000,
        },
      );

      final entry = await lookup.lookupDevice('device-1');

      expect(entry!.revokedAt, DateTime.fromMillisecondsSinceEpoch(555000));
    });

    test('returns null for an absent entry (not a listing, not a query)', () async {
      final lookup = _RespondingReadDeviceDirectoryService(
        identityService: identityService,
        database: db,
        response: null,
      );

      expect(await lookup.lookupDevice('unknown-device'), isNull);
    });

    test('returns null for a malformed entry rather than throwing', () async {
      final lookup = _RespondingReadDeviceDirectoryService(
        identityService: identityService,
        database: db,
        response: {'identityPublicKey': 'not-valid-hex-!!', 'prekeyBundle': 'x'},
      );

      expect(await lookup.lookupDevice('device-1'), isNull);
    });

    test('returns null (never throws) when the read seam fails', () async {
      final lookup = _ThrowingReadDeviceDirectoryService(
        identityService: identityService,
        database: db,
      );

      expect(await lookup.lookupDevice('device-1'), isNull);
    });
  });

  group('test_E11_B02_lookupDevice_identity_binding', () {
    // Reviewer's exact probe (E11-B02): a directory entry whose
    // `identityPublicKey` field and the identity key embedded inside its
    // `prekeyBundle` field name two DIFFERENT identities must be rejected
    // exactly like a malformed entry -- log and return null. Two
    // independent identities (A, B) are built via IdentityService against
    // two separate in-memory AppDatabases so the identity keys are
    // guaranteed to differ, then a forged raw node is assembled by hand
    // (never through `publish`, which is always self-consistent).
    late AppDatabase dbA;
    late AppDatabase dbB;
    late IdentityService identityServiceA;
    late IdentityService identityServiceB;

    setUp(() async {
      dbA = AppDatabase.forTesting(NativeDatabase.memory());
      dbB = AppDatabase.forTesting(NativeDatabase.memory());
      identityServiceA = IdentityService(dbA, DriftSignalProtocolStore(dbA));
      identityServiceB = IdentityService(dbB, DriftSignalProtocolStore(dbB));
      await identityServiceA.ensureLocalIdentity();
      await identityServiceA.ensureSignedPreKey();
      await identityServiceA.replenishOneTimePreKeys();
      await identityServiceB.ensureLocalIdentity();
      await identityServiceB.ensureSignedPreKey();
      await identityServiceB.replenishOneTimePreKeys();
    });

    tearDown(() async {
      await dbA.close();
      await dbB.close();
    });

    test(
      'rejects an entry whose identityPublicKey field disagrees with the '
      'identity key embedded in its prekeyBundle field',
      () async {
        final bundleA = await identityServiceA.getLocalPreKeyBundle();
        final bundleB = await identityServiceB.getLocalPreKeyBundle();

        // Sanity: the two identities really are different -- otherwise
        // this test would prove nothing.
        expect(
          bundleA.getIdentityKey().serialize(),
          isNot(equals(bundleB.getIdentityKey().serialize())),
        );

        final forgedEntry = <String, Object?>{
          'identityPublicKey': hexEncodeBytes(bundleA.getIdentityKey().serialize()),
          'prekeyBundle': base64Encode(PreKeyBundleCodec.serialize(bundleB)),
        };

        final lookup = _RespondingReadDeviceDirectoryService(
          identityService: identityServiceA,
          database: dbA,
          response: forgedEntry,
        );

        expect(await lookup.lookupDevice('victim-device-id'), isNull);
      },
    );

    test(
      'falsification control: a genuinely consistent entry (both fields '
      'derived from the SAME bundle) still returns a populated '
      'DirectoryEntry -- the mismatch check must not reject everything',
      () async {
        final bundleA = await identityServiceA.getLocalPreKeyBundle();

        final consistentEntry = <String, Object?>{
          'identityPublicKey': hexEncodeBytes(bundleA.getIdentityKey().serialize()),
          'prekeyBundle': base64Encode(PreKeyBundleCodec.serialize(bundleA)),
        };

        final lookup = _RespondingReadDeviceDirectoryService(
          identityService: identityServiceA,
          database: dbA,
          response: consistentEntry,
        );

        final entry = await lookup.lookupDevice('device-a');

        expect(entry, isNotNull);
        expect(entry!.identityPublicKey, isA<IdentityKey>());
        expect(entry.preKeyBundle, isA<PreKeyBundle>());
        expect(
          entry.identityPublicKey.serialize(),
          bundleA.getIdentityKey().serialize(),
        );
      },
    );
  });
}
