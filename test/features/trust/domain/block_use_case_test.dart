// EARS-BLOCK-1 (FR-BLOCK-001, E02-T01).
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/block_use_case.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

void main() {
  late AppDatabase db;
  late RelationshipRepository repository;
  late BlockUseCase blockUseCase;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = RelationshipRepository(db);
    blockUseCase = BlockUseCase(repository);
  });

  tearDown(() => db.close());

  test(
    'test_EARS_BLOCK_1_blocked_device_never_permitted',
    () async {
      // EARS-BLOCK-1 (FR-BLOCK-001): once a device is blocked, isBlocked
      // reports true and isConnectionPermitted is false regardless of the
      // other side's evaluation — parameterized over all four remote
      // states.
      await blockUseCase.call('device-blocked');

      final isBlocked = await repository.isBlocked('device-blocked');
      expect(isBlocked, isTrue);

      for (final remoteState in RelationshipState.values) {
        final permitted = isConnectionPermitted(
          RelationshipState.blocked,
          remoteState,
        );
        expect(
          permitted,
          isFalse,
          reason: 'local blocked + remote $remoteState must never permit',
        );
      }
    },
  );

  test(
    'test_EARS_BLOCK_1_remote_blocked_also_never_permitted',
    () async {
      // The gate is symmetric — a blocked remote side must also veto the
      // connection even when the local side would otherwise allow it.
      for (final localState in RelationshipState.values) {
        final permitted = isConnectionPermitted(
          localState,
          RelationshipState.blocked,
        );
        expect(
          permitted,
          isFalse,
          reason: 'local $localState + remote blocked must never permit',
        );
      }
    },
  );

  test('test_EARS_TRUST_2_unblocked_device_isBlocked_is_false', () async {
    final isBlocked = await repository.isBlocked('device-never-blocked');
    expect(isBlocked, isFalse);
  });
}
