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
import 'package:nexora/features/login/presentation/login_controller.dart';
import 'package:nexora/features/welcome/presentation/welcome_controller.dart';
import 'package:nexora/features/home/presentation/home_controller.dart';

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

  // Real-hardware regression (found on a physical Pixel 8 Pro): welcome ->
  // login -> dashboard, then back to welcome and sign in a second time in
  // the same process crashed with "LoginController not found". Root cause:
  // `AppBinding.dependencies()` is the app's `initialBinding` -- it runs
  // exactly ONCE per process, not per route visit like a page-scoped
  // `Bindings` would. `Get.lazyPut` without `fenix: true` consumes its
  // factory the first time the controller is deleted (GetX's smart
  // management disposes it once its route is popped), so any SECOND visit
  // to that route has no factory left to rebuild it. `fenix: true` keeps
  // the factory alive for the lifetime of the process, letting GetX
  // recreate the controller on demand every time. Same shape applies to
  // `WelcomeController` and `HomeController` -- both are visited more than
  // once whenever a user backgrounds/returns or (once E15 ships) logs out.
  group('E15 real-hardware regression -- lazyPut controllers survive a '
      'second visit after GetX disposes the first', () {
    Future<MessagingStack> newStack() async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final stack = await MessagingStack.create(
        db: db,
        selfDeviceId: 'self-device',
        transport: TransportService(
          binaryMessenger: messenger,
          messageChannelSuffix: 'bindings-fenix-test-${suffixCounter++}',
        ),
      );
      expect(stack.status, const MessagingStackStatus.ready());
      return stack;
    }

    test(
      'test_E15_lazyPut_login_controller_survives_a_second_find_after_delete',
      () async {
        final stack = await newStack();
        addTearDown(stack.dispose);
        addTearDown(stack.coordinator.stop);
        AppBinding(db: stack.db, messagingStack: stack).dependencies();

        // First visit: normal.
        expect(Get.find<LoginController>(), isNotNull);

        // GetX's own smart management disposing the controller once its
        // route is popped -- forced here to isolate the disposal effect
        // from real navigation.
        await Get.delete<LoginController>(force: true);

        // Second visit -- the actual repro. Without `fenix: true` this
        // throws `"LoginController" not found`.
        expect(Get.find<LoginController>(), isNotNull);
      },
    );

    test(
      'test_E15_lazyPut_welcome_controller_survives_a_second_find_after_delete',
      () async {
        final stack = await newStack();
        addTearDown(stack.dispose);
        addTearDown(stack.coordinator.stop);
        AppBinding(db: stack.db, messagingStack: stack).dependencies();

        expect(Get.find<WelcomeController>(), isNotNull);
        await Get.delete<WelcomeController>(force: true);
        expect(Get.find<WelcomeController>(), isNotNull);
      },
    );

    test(
      'test_E15_lazyPut_home_controller_survives_a_second_find_after_delete',
      () async {
        final stack = await newStack();
        addTearDown(stack.dispose);
        addTearDown(stack.coordinator.stop);
        AppBinding(db: stack.db, messagingStack: stack).dependencies();

        expect(Get.find<HomeController>(), isNotNull);
        await Get.delete<HomeController>(force: true);
        expect(Get.find<HomeController>(), isNotNull);
      },
    );
  });
}
