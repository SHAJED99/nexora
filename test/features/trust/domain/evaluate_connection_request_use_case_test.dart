// EARS-TRUST-1/2 (FR-TRUST-003/004/005, E02-T01).
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/evaluate_connection_request_use_case.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

void main() {
  late AppDatabase db;
  late RelationshipRepository repository;
  late EvaluateConnectionRequestUseCase useCase;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = RelationshipRepository(db);
    useCase = EvaluateConnectionRequestUseCase(repository);
  });

  tearDown(() => db.close());

  test('test_EARS_TRUST_1_trusted_device_auto_accepts', () async {
    // EARS-TRUST-1 (FR-TRUST-004): a request from an already-Trusted
    // device evaluates as Trusted without re-authentication — no flag
    // needs to be set for this to happen.
    await repository.upsert('device-trusted', RelationshipState.trusted);

    final result = await useCase.call('device-trusted');

    expect(result, RelationshipState.trusted);
  });

  test(
    'test_EARS_TRUST_1_unknown_device_never_auto_accepts',
    () async {
      // Sanity counterpart: a device with no stored relationship (or a
      // non-trusted one) must never be silently auto-accepted.
      final result = await useCase.call('device-never-seen');

      expect(result, RelationshipState.unknown);
    },
  );

  test('test_EARS_TRUST_2_evaluation_is_independent_per_side', () async {
    // EARS-TRUST-2 (FR-TRUST-003/005): evaluating device A's request must
    // never read or depend on — or mutate — this side's stored evaluation
    // of a different device B.
    await repository.upsert('device-a', RelationshipState.trusted);
    await repository.upsert('device-b', RelationshipState.blocked);

    final resultA = await useCase.call('device-a');

    expect(resultA, RelationshipState.trusted);
    // device-b's row is untouched by evaluating device-a's request.
    final relationshipB = await repository.get('device-b');
    expect(relationshipB!.state, RelationshipState.blocked);
  });

  test('test_EARS_BLOCK_1_blocked_device_evaluates_as_blocked', () async {
    // Review fix (E02-T01): a stored `blocked` state must be returned
    // as-is, never collapsed to `unknown` — otherwise a future caller
    // reading this evaluation to decide "unknown device, prompt the
    // user?" would prompt for a device that was explicitly blocked,
    // defeating FR-BLOCK-001's enforcement.
    await repository.upsert('device-blocked', RelationshipState.blocked);

    final result = await useCase.call('device-blocked');

    expect(result, RelationshipState.blocked);
  });

  test('test_EARS_TRUST_1_allowed_device_evaluates_as_allowed', () async {
    // An `allowed` device's stored state is likewise returned as-is, not
    // collapsed to unknown.
    await repository.upsert('device-allowed', RelationshipState.allowed);

    final result = await useCase.call('device-allowed');

    expect(result, RelationshipState.allowed);
  });
}
