// E13-T02 (FR-ABUSE-001) -- rate-limiting a connection-request evaluation
// per remote device id. This task's chosen limit (§3): `maxCount: 10`,
// `window: 1 minute`, keyed by the remote deviceId being evaluated
// (`evaluate_connection_request_use_case.dart`'s own comment documents the
// full reasoning). Existing behavior (E02-T01) is covered by
// `evaluate_connection_request_use_case_test.dart`; this file covers only
// the NEW rate-limit gate.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/abuse/rate_limiter.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/evaluate_connection_request_use_case.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

void main() {
  late AppDatabase db;
  late RelationshipRepository repository;
  late RateLimiter limiter;
  late EvaluateConnectionRequestUseCase useCase;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = RelationshipRepository(db);
    limiter = RateLimiter(db);
    useCase = EvaluateConnectionRequestUseCase(repository, rateLimiter: limiter);
  });

  tearDown(() => db.close());

  test(
    'test_EARS_ABUSE_4_connection_request_over_limit_is_denied',
    () async {
      const deviceId = 'device-spammer';
      // Exhaust the configured window (maxCount: 10) with legitimate
      // evaluations of the same never-seen device id.
      for (var i = 0; i < 10; i++) {
        final result = await useCase.call(deviceId);
        expect(result, RelationshipState.unknown);
      }

      // The 11th call within the same window must be denied -- reusing
      // the existing `blocked` shape (task §3), and critically must NOT
      // have consulted `RelationshipRepository` to arrive at it.
      final denied = await useCase.call(deviceId);
      expect(denied, RelationshipState.blocked);

      // Prove EARS-ABUSE-4's "without consulting RelationshipRepository":
      // no relationship row was ever created for this never-seen device,
      // since a bare lookup would also legitimately return `unknown`/null
      // rather than write anything -- the real proof is that a *trusted*
      // device's stored state is ignored once rate-limited (next test).
      final stored = await repository.get(deviceId);
      expect(stored, isNull);
    },
  );

  test(
    'test_EARS_ABUSE_4_connection_request_over_limit_ignores_trusted_state',
    () async {
      // Stronger proof that the rate-limit gate runs BEFORE the repository
      // lookup: even a device already stored as `trusted` must be denied
      // once its bucket is over limit -- if the repository were consulted
      // first, this would incorrectly return `trusted`.
      const deviceId = 'device-trusted-but-spamming';
      await repository.upsert(deviceId, RelationshipState.trusted);

      for (var i = 0; i < 10; i++) {
        final result = await useCase.call(deviceId);
        expect(result, RelationshipState.trusted);
      }

      final denied = await useCase.call(deviceId);
      expect(denied, RelationshipState.blocked);
    },
  );

  test(
    'test_EARS_ABUSE_4_connection_request_under_limit_still_evaluates_normally',
    () async {
      const deviceId = 'device-occasional';
      await repository.upsert(deviceId, RelationshipState.allowed);

      // Well under the configured max (10) -- normal evaluation proceeds
      // untouched by the new gate.
      for (var i = 0; i < 3; i++) {
        final result = await useCase.call(deviceId);
        expect(result, RelationshipState.allowed);
      }
    },
  );

  test(
    'test_evaluate_connection_request_without_rate_limiter_is_unaffected',
    () async {
      // The two out-of-fence production call sites
      // (`MessagingStack.create`, `DevicesController`'s default fallback)
      // construct this use case with NO `rateLimiter` -- confirms that
      // path is entirely unaffected by this task (byte-for-byte the same
      // as before E13-T02), never denies regardless of call volume.
      final bare = EvaluateConnectionRequestUseCase(repository);
      const deviceId = 'device-no-limiter';
      for (var i = 0; i < 20; i++) {
        final result = await bare.call(deviceId);
        expect(result, RelationshipState.unknown);
      }
    },
  );
}
