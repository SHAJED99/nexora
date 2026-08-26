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
}
