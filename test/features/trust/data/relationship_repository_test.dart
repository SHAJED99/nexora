// RelationshipRepository — Drift wrapper (E02-T01).
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

void main() {
  late AppDatabase db;
  late RelationshipRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = RelationshipRepository(db);
  });

  tearDown(() => db.close());

  test('get returns null for a device with no stored relationship',
      () async {
    final relationship = await repository.get('unknown-device');
    expect(relationship, isNull);
  });

  // EARS-TRUST-4 (FR-TRUST-001): the write reaches the Drift table and a
  // separate read returns it, so the relationship is persisted rather than
  // held in memory by the repository.
  test('test_EARS_TRUST_4_an_established_relationship_is_persisted_and_read_back',
      () async {
    await repository.upsert('device-1', RelationshipState.allowed);

    final relationship = await repository.get('device-1');

    expect(relationship, isNotNull);
    expect(relationship!.deviceId, 'device-1');
    expect(relationship.state, RelationshipState.allowed);
  });

  // EARS-TRUST-4 (FR-TRUST-001): covers the `trusted` case the requirement
  // names, and the `rather than add a second` half of the criterion.
  test(
      'test_EARS_TRUST_4b_re_establishing_as_trusted_updates_the_stored_row_'
      'not_a_second',
      () async {
    await repository.upsert('device-1', RelationshipState.unknown);
    await repository.upsert('device-1', RelationshipState.trusted);

    final relationship = await repository.get('device-1');
    expect(relationship!.state, RelationshipState.trusted);
  });

  test('watchState emits unknown immediately when no row exists', () async {
    final state = await repository.watchState('never-seen').first;
    expect(state, RelationshipState.unknown);
  });

  test('watchState emits the current stored state immediately on listen',
      () async {
    await repository.upsert('device-1', RelationshipState.trusted);

    final state = await repository.watchState('device-1').first;
    expect(state, RelationshipState.trusted);
  });

  test('watchState re-emits after upsert changes the stored state',
      () async {
    // E09-B01: this is the stream LocationReadModel.watch() subscribes to
    // as its fourth input, so it must actually fire on a relationship
    // change -- not merely on first listen.
    await repository.upsert('device-1', RelationshipState.trusted);

    final states = <RelationshipState>[];
    final sub = repository.watchState('device-1').listen(states.add);
    await Future<void>.delayed(Duration.zero);
    expect(states.last, RelationshipState.trusted);

    await repository.upsert('device-1', RelationshipState.blocked);
    await Future<void>.delayed(Duration.zero);

    expect(states.last, RelationshipState.blocked);
    await sub.cancel();
  });

  test(
      'listAll orders rows with an identical updatedAt deterministically '
      'by deviceId ascending (E12-B14 regression)', () async {
    // Regression for E12-B14: `listAll`'s query previously sorted only by
    // `updatedAt desc`, with no secondary key. Rows sharing the exact same
    // `updatedAt` (e.g. seeded in one tick, as the devices design-verify
    // probe fixture does) then had an unspecified tie-break order from
    // SQLite -- this seeds four rows with one identical `updatedAt` value
    // (bypassing `upsert`, which always stamps `DateTime.now()`, so the tie
    // is under this test's control) and asserts the result is always
    // ordered by `deviceId` ascending among the tied rows, across repeated
    // reads.
    final tiedUpdatedAt = DateTime.utc(2026, 1, 1, 12);
    for (final deviceId in ['device-c', 'device-a', 'device-d', 'device-b']) {
      await db.into(db.relationships).insert(
            RelationshipsCompanion.insert(
              deviceId: deviceId,
              state: RelationshipState.allowed.name,
              updatedAt: tiedUpdatedAt,
            ),
          );
    }

    final expectedOrder = ['device-a', 'device-b', 'device-c', 'device-d'];

    // Query twice: a non-deterministic tie-break could still coincidentally
    // match `expectedOrder` on a single read, so this repeats the read and
    // requires the same deviceId-ascending order every time.
    for (var i = 0; i < 2; i++) {
      final rows = await repository.listAll();
      expect(
        rows.map((r) => r.deviceId).toList(),
        expectedOrder,
        reason: 'listAll must break updatedAt ties by deviceId ascending '
            '(read #$i)',
      );
    }
  });
}
