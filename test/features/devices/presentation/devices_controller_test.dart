// features/devices/presentation — DevicesController (E02-T02).
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/features/devices/presentation/devices_controller.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/block_use_case.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

void main() {
  late AppDatabase db;
  late RelationshipRepository repository;
  late BlockUseCase blockUseCase;
  late DevicesController controller;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = RelationshipRepository(db);
    blockUseCase = BlockUseCase(repository);
    controller = DevicesController(repository, blockUseCase);
  });

  tearDown(() => db.close());

  test('test_EARS_DEV_2_block_action_updates_state', () async {
    await repository.upsert('device-1', RelationshipState.unknown);
    await controller.load();
    expect(controller.relationships.single.state, RelationshipState.unknown);

    await controller.block('device-1');

    expect(controller.relationships, hasLength(1));
    expect(controller.relationships.single.deviceId, 'device-1');
    expect(controller.relationships.single.state, RelationshipState.blocked);

    // Persisted, not just held in memory — a re-read confirms the write.
    final persisted = await repository.get('device-1');
    expect(persisted!.state, RelationshipState.blocked);
  });

  test('verify promotes an Unknown relationship to Allowed', () async {
    await repository.upsert('device-2', RelationshipState.unknown);
    await controller.load();

    await controller.verify('device-2');

    expect(controller.relationships.single.state, RelationshipState.allowed);
  });

  test('refresh loads an empty list when no relationships are stored',
      () async {
    await controller.load();
    expect(controller.relationships, isEmpty);
  });
}
