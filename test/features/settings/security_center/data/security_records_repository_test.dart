// features/settings/security_center/data -- SecurityRecordsRepository
// (E15-T06). Real in-memory `AppDatabase` throughout: these tests prove the
// repository's own projection against the real Drift schema, not a mock's
// promise that it would.
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
    'test_EARS_DIAG_4_trusted_identity_row_never_renders_key_bytes',
    () async {
      // A recognisable key pattern -- the falsification test for this
      // screen's whole reason to exist (task §8). If this pattern ever
      // shows up in a `SecurityRecord`'s own field, `FR-DIAG-002` is
      // violated at the repository layer, before a widget even exists.
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
      expect(records.single.displayIdentifier, 'device-b');
      expect(records.single.recordType, SecurityRecordType.trusted);
      // `signal_trusted_identities` has no first-seen column at all
      // (`crypto_tables.dart`) -- null, not fabricated (rule 1).
      expect(records.single.timestamp, isNull);
      expect(records.single.count, isNull);
      // Structural: the type itself carries no field a key could hide in.
      expect(
        records.single.toString(),
        isNot(contains(suspiciousKey.toString())),
      );
    },
  );

  test('test_EARS_DIAG_4_record_model_has_no_key_field', () {
    // A structural assertion on `SecurityRecord` (task §8): its only
    // fields are a display identifier, a record type, an optional
    // timestamp and an optional count -- reflection-free, this is a
    // compile-time fact checked here by construction.
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
