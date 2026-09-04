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

  test('upsert then get round-trips deviceId and state', () async {
    await repository.upsert('device-1', RelationshipState.allowed);

    final relationship = await repository.get('device-1');

    expect(relationship, isNotNull);
    expect(relationship!.deviceId, 'device-1');
    expect(relationship.state, RelationshipState.allowed);
  });

  test('upsert on an existing deviceId updates state, not a second row',
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
}
