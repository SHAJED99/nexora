// app/bindings — E13-T07 review round-2 fix (F3, non-blocking but folded
// into this round since it's the exact construction site
// `OQ-E13-T02-1` originally missed: `AppBinding.dependencies()`'s own
// `DeviceIdentityRepository` singleton had zero test coverage of its own
// wiring — reverting `bindings.dart` back to
// `DeviceIdentityRepository(Get.find<AppDatabase>())` (dropping the
// `RateLimiter` param) still passed the entire suite before this file
// existed. This test resolves the REAL singleton through `AppBinding` +
// the GetX container (never a hand-built `DeviceIdentityRepository`) and
// falsifies that the rate limiter is actually wired: repeated registrations
// through the resolved instance must trip the gate.
//
// Building a full `MessagingStack` (required by `AppBinding`'s
// constructor) mirrors `messaging_coordinator_test.dart`'s own
// `AppBinding(db: ..., messagingStack: ...).dependencies()` pattern —
// this suite exists to prove `DeviceIdentityRepository`'s wiring, not to
// re-prove `MessagingStack.create`'s own composition (already covered by
// `messaging_stack_test.dart`).
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/app/bindings.dart';
import 'package:nexora/core/auth/google_auth_service.dart' show AppFailure;
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/login/data/device_identity_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var suffixCounter = 0;

  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  Future<MessagingStack> newStack() async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final stack = await MessagingStack.create(
      db: db,
      selfDeviceId: 'self-device',
      transport: TransportService(
        binaryMessenger: messenger,
        messageChannelSuffix: 'bindings-test-${suffixCounter++}',
      ),
    );
    expect(stack.status, const MessagingStackStatus.ready());
    return stack;
  }

  test(
    'test_EARS_ABUSE_5_app_binding_wires_a_real_rate_limiter_into_device_identity_repository',
    () async {
      // F3: this is the exact defect a silent revert of `bindings.dart`'s
      // `rateLimiter:` argument would produce — a `DeviceIdentityRepository`
      // resolved through the real composition root that never denies,
      // no matter how many devices one account registers.
      final stack = await newStack();
      addTearDown(stack.dispose);
      addTearDown(stack.coordinator.stop);

      AppBinding(db: stack.db, messagingStack: stack).dependencies();

      final repository = Get.find<DeviceIdentityRepository>();
      const accountUid = 'firebase-uid-bindings-wiring-check';

      // 5 registrations under one account uid must all succeed...
      for (var i = 0; i < 5; i++) {
        await repository.createDeviceIdentity(
          'bindings-device-$i',
          accountUid: accountUid,
        );
      }

      // ...and the 6th, through the SAME resolved singleton, must be
      // denied — proving the `RateLimiter` `AppBinding` constructs really
      // is the one wired into the instance the rest of the app resolves
      // via `Get.find<DeviceIdentityRepository>()`.
      await expectLater(
        repository.createDeviceIdentity(
          'bindings-device-6',
          accountUid: accountUid,
        ),
        throwsA(
          isA<AppFailure>().having(
            (f) => f.code,
            'code',
            'device.registration_rate_limited',
          ),
        ),
      );
    },
  );
}
