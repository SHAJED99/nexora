// features/settings/security_center/data -- SecurityRecordsRepository
// (E15-T06). Real in-memory `AppDatabase` throughout: these tests prove the
// repository's own projection against the real Drift schema, not a mock's
// promise that it would.
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/features/settings/security_center/data/security_records_repository.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SecurityRecordsRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = SecurityRecordsRepository(db: db);
  });

  tearDown(() => db.close());

  test('test_EARS_DIAG_4_all_four_sections_empty_returns_empty_lists', () async {
    expect(await repository.revocations(), isEmpty);
    expect(await repository.trustedIdentities(), isEmpty);
    expect(await repository.blockedPeers(), isEmpty);
    expect(await repository.rateLimitDenials(), isEmpty);
  });

  test('test_EARS_DIAG_4_revocations_render_device_id_type_and_when', () async {
    final revokedAt = DateTime(2026, 9, 1, 12);
    await db
        .into(db.deviceRevocations)
        .insert(
          DeviceRevocationsCompanion.insert(
            deviceId: 'device-a',
            revokedAt: revokedAt,
            source: 'local',
          ),
        );

    final records = await repository.revocations();

    expect(records, hasLength(1));
    expect(records.single.displayIdentifier, 'device-a');
    expect(records.single.recordType, SecurityRecordType.revoked);
    expect(records.single.timestamp, revokedAt);
    expect(records.single.count, isNull);
  });

  test(
    'test_EARS_DIAG_4_trusted_identity_repository_projects_address_name_not_key_bytes',
    () async {
      // A recognisable key pattern -- proves the *repository's own query*
      // never reads `identityKey` off the row in the first place (the
      // `selectOnly` projection in `trustedIdentities()`), independent of
      // whatever a widget later does with the returned model. The
      // widget-tree half of this falsification --  that the same pattern
      // never reaches a rendered `Text` anywhere on screen -- is proven
      // separately by
      // `test_EARS_DIAG_4_trusted_identity_row_never_renders_key_bytes` in
      // `security_center_controller_test.dart` (F1, review round on this
      // PR): a plain `SecurityRecord.toString()` comparison here can never
      // fail (the class has no `toString` override, so it always compares
      // `"Instance of 'SecurityRecord'"`) and proved nothing on its own.
      final suspiciousKey = Uint8List.fromList(
        List<int>.generate(32, (i) => 0xAB),
      );
      await db
          .into(db.signalTrustedIdentities)
          .insert(
            SignalTrustedIdentitiesCompanion.insert(
              addressName: 'device-b',
              addressDeviceId: 1,
              identityKey: suspiciousKey,
            ),
          );

      final records = await repository.trustedIdentities();

      expect(records, hasLength(1));
      // The ONLY string the returned record may carry is the device id --
      // never the key bytes, hex, or any substring of the key's own
      // `toString()`/`toRadixString()` representations.
      expect(records.single.displayIdentifier, 'device-b');
      expect(
        records.single.displayIdentifier,
        isNot(contains(suspiciousKey.toString())),
      );
      expect(records.single.recordType, SecurityRecordType.trusted);
      // `signal_trusted_identities` has no first-seen column at all
      // (`crypto_tables.dart`) -- null, not fabricated (rule 1).
      expect(records.single.timestamp, isNull);
      expect(records.single.count, isNull);
    },
  );

  test('test_EARS_DIAG_4_record_model_has_no_key_field', () {
    // A structural assertion on `SecurityRecord` (task §8): reflection is
    // unavailable in Flutter (no `dart:mirrors`), so -- the same idiomatic
    // pattern this codebase already uses for a "structurally cannot leak
    // X" claim (`test/core/storage/storage_inventory_test.dart`'s
    // `test_EARS_STORE_6_inventory_never_decrypts`) -- this reads the
    // class's own source and asserts, at the text level, that no field
    // capable of holding key/session/plaintext/location material is
    // declared anywhere in the class body. A construction-only check (the
    // previous version of this test) only proves the four fields that
    // *are* named behave as expected; it says nothing about whether a
    // fifth, unexercised field exists -- exactly the gap the reviewer's
    // reverted-`selectOnly` experiment (F1) walked through by adding one.
    final source = File(
      'lib/features/settings/security_center/data/security_records_repository.dart',
    ).readAsStringSync();
    final classBody = _extractClassBody(source, 'SecurityRecord');

    // Forbidden field/type tokens -- any of these inside the class body
    // would be a place key/session/plaintext/location material could hide.
    const forbiddenTokens = [
      'identityKey',
      'sessionKey',
      'session',
      'plaintext',
      'messageContent',
      'location',
      'latitude',
      'longitude',
      'Uint8List',
      'ByteData',
      'ByteBuffer',
    ];
    for (final token in forbiddenTokens) {
      expect(
        classBody.contains(token),
        isFalse,
        reason:
            '`SecurityRecord` must not declare a field capable of holding '
            'key/session/plaintext/location material, but its class body '
            'contains "$token":\n$classBody',
      );
    }
    // The four fields the contract actually allows, positively confirmed
    // present so this test cannot pass on an empty/gutted class either.
    for (final expectedField in [
      'displayIdentifier',
      'recordType',
      'timestamp',
      'count',
    ]) {
      expect(
        classBody.contains(expectedField),
        isTrue,
        reason: '`SecurityRecord` is missing its own "$expectedField" field.',
      );
    }

    const record = SecurityRecord(
      displayIdentifier: 'x',
      recordType: SecurityRecordType.trusted,
    );
    expect(record.displayIdentifier, 'x');
    expect(record.timestamp, isNull);
    expect(record.count, isNull);
  });

  test('test_EARS_DIAG_4_blocked_peers_render_device_id_and_type_only', () async {
    await db
        .into(db.relationships)
        .insert(
          RelationshipsCompanion.insert(
            deviceId: 'device-c',
            state: RelationshipState.blocked.name,
            updatedAt: DateTime(2026, 9, 1),
          ),
        );
    await db
        .into(db.relationships)
        .insert(
          RelationshipsCompanion.insert(
            deviceId: 'device-d',
            state: RelationshipState.trusted.name,
            updatedAt: DateTime(2026, 9, 1),
          ),
        );

    final records = await repository.blockedPeers();

    expect(records, hasLength(1));
    expect(records.single.displayIdentifier, 'device-c');
    expect(records.single.recordType, SecurityRecordType.blocked);
    expect(records.single.timestamp, isNull);
  });

  test(
    'test_EARS_DIAG_4_rate_limit_denials_render_limit_name_and_count_not_the_subject',
    () async {
      await db
          .into(db.rateLimitCounters)
          .insert(
            RateLimitCountersCompanion.insert(
              bucketKey: 'connection_request:device-e',
              windowStartMs: 1000,
              count: 7,
            ),
          );

      final records = await repository.rateLimitDenials();

      expect(records, hasLength(1));
      expect(records.single.displayIdentifier, 'Connection requests');
      expect(records.single.displayIdentifier, isNot(contains('device-e')));
      expect(records.single.recordType, SecurityRecordType.rateLimited);
      expect(records.single.count, 7);
      expect(records.single.timestamp, isNull);
    },
  );

  test(
    'test_EARS_DIAG_4_unrecognised_bucket_prefix_falls_back_to_the_raw_prefix',
    () async {
      await db
          .into(db.rateLimitCounters)
          .insert(
            RateLimitCountersCompanion.insert(
              bucketKey: 'future_limit:device-f',
              windowStartMs: 1000,
              count: 2,
            ),
          );

      final records = await repository.rateLimitDenials();

      expect(records.single.displayIdentifier, 'future_limit');
    },
  );
}

/// Extracts the `{ ... }` body of the first `class <name> {` declaration in
/// [source] (brace-depth counting -- good enough for this file's own single,
/// non-nested class; not a general Dart parser). Used by
/// `test_EARS_DIAG_4_record_model_has_no_key_field` to make a "this class
/// cannot structurally hold X" claim against the class's own text rather
/// than against a handful of constructed instances (the same idiomatic
/// shape `storage_inventory_test.dart`'s `test_EARS_STORE_6_inventory_never_decrypts`
/// already uses for an equivalent claim).
String _extractClassBody(String source, String className) {
  // Word-boundary match on the class name -- `class SecurityRecord` would
  // otherwise also match the start of `class SecurityRecordsRepository`.
  final match = RegExp('class $className\\b').firstMatch(source);
  if (match == null) {
    fail('No `class $className` declaration found in the given source.');
  }
  final classIndex = match.start;
  final openBrace = source.indexOf('{', classIndex);
  var depth = 0;
  for (var i = openBrace; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) return source.substring(openBrace, i + 1);
    }
  }
  fail('Unterminated `class $className` body in the given source.');
}
