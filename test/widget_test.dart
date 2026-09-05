// Walking-skeleton widget test (E00-T05, updated E01-T01, E06-T12): proves
// welcome -> login navigates on "Continue with Google", the sign-in use
// case performs one real Drift write (through a test-doubled
// GoogleAuthService — no real Google/Firebase network calls in this
// suite), and the app lands on the post-login destination able to read that
// row back.
//
// E06-T12: `LoginController` now navigates to `/dashboard`
// (design/screens/dashboard.md), superseding this walking skeleton's
// `/home` placeholder (see that task's own Deviations for why this file —
// outside its `files:` fence — needed this one-line, disclosed update to
// stay green: `/dashboard` requires a full `MessagingStack`/`AppBinding`
// this genesis test deliberately never constructs, so the destination page
// registered here is a minimal stub, not the real `DashboardView` — this
// test's actual assertions are about the login->navigation seam and the
// real Drift write/read-back, both unaffected by which widget the
// destination route renders).
//
// Uses an in-memory Drift database — no real filesystem I/O.
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/app/bindings.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/login/data/device_identity_repository.dart';
import 'package:nexora/features/login/domain/sign_in_use_case.dart';
import 'package:nexora/features/login/presentation/login_controller.dart';
import 'package:nexora/features/login/presentation/login_view.dart';
import 'package:nexora/features/welcome/presentation/welcome_controller.dart';
import 'package:nexora/features/welcome/presentation/welcome_view.dart';

import 'support/fake_google_auth_service.dart';

/// E14-B02's own instrumentation, mirroring
/// `messaging_coordinator_test.dart`'s `_ControlledSendTransport` pattern
/// (a `TransportService` subclass built over the same mocked Pigeon
/// channel, never a from-scratch fake). `InboundPipeline.start()`
/// (`inbound_pipeline.dart:295`) and `MessagingCoordinator.start()`
/// (`messaging_coordinator.dart:287`) are the ONLY two production call
/// sites anywhere in `lib/` that read `.discoveredDevices` before the app
/// navigates to a route that constructs a screen controller (`devices
/// _controller.dart`/`dashboard_controller.dart` also read it, but neither
/// is built by `AppBinding.dependencies()` itself — both are `lazyPut`,
/// resolved only once their own screen is opened, which this test never
/// does). So counting accesses to this one getter during
/// `AppBinding.dependencies()` is a direct, non-fragile proxy for "did the
/// messaging mesh's transport-data intake actually get subscribed" —
/// without needing to drive a full discover -> connect -> incoming-data
/// event sequence through the mocked native channel just to prove a
/// negative. Per `L-feedback`/this project's own lesson on `fail()` inside
/// injected seams (a broad catch in the SUT can swallow it silently), this
/// is a plain counter asserted with `expect(..., 0)`/`expect(..., greaterThan(0))`,
/// never a `fail()` planted inside the seam itself.
class _CountingTransportService extends TransportService {
  _CountingTransportService({
    required super.binaryMessenger,
    required super.messageChannelSuffix,
  });

  int discoveredDevicesAccessCount = 0;

  @override
  Stream<TransportDevice> get discoveredDevices {
    discoveredDevicesAccessCount++;
    return super.discoveredDevices;
  }
}

void main() {
  setUp(() => Get.testMode = true);
  tearDown(Get.reset);

  testWidgets(
    'welcome -> Continue with Google -> login -> Drift write -> dashboard',
    (WidgetTester tester) async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = DeviceIdentityRepository(db);
      final signInUseCase = SignInUseCase(
        repository,
        authService: FakeGoogleAuthService.success('firebase-uid-test'),
      );

      Get.lazyPut(WelcomeController.new);
      Get.lazyPut(() => LoginController(signInUseCase));

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: '/welcome',
          getPages: [
            GetPage<dynamic>(name: '/welcome', page: () => const WelcomeView()),
            GetPage<dynamic>(name: '/login', page: () => const LoginView()),
            // A minimal stub, not the real DashboardView (E06-T12) — this
            // test proves the login->navigation seam and the real Drift
            // write/read-back, not the Dashboard screen's own content
            // (covered by test/features/dashboard/).
            GetPage<dynamic>(
              name: '/dashboard',
              page: () => const Text('dashboard placeholder'),
            ),
          ],
        ),
      );

      // Starts on welcome.
      expect(find.text('Continue with Google'), findsOneWidget);
      expect(await db.latestDeviceIdentity(), isNull);

      // Tap -> navigates to login, showing the transient "signing in" copy.
      await tester.tap(find.text('Continue with Google'));
      await tester.pump(); // process the tap
      await tester.pump(); // process the route transition
      expect(find.text('Signing in with Google...'), findsOneWidget);

      // Let the (50ms) stubbed sign-in delay elapse and the app navigate on.
      await tester.pumpAndSettle();

      // The sign-in use case has run: one real Drift row, written through
      // controller -> use case -> repository -> Drift.
      final identity = await db.latestDeviceIdentity();
      expect(identity, isNotNull);
      expect(identity!.signedIn, isTrue);

      // ... and it navigated onward to /dashboard (E06-T12), not /home.
      expect(find.text('Signing in with Google...'), findsNothing);
      expect(find.text('dashboard placeholder'), findsOneWidget);

      await db.close();
    },
  );

  group('E14-B02 — AppBinding.blockCommunication gates the four starts', () {
    final TestDefaultBinaryMessenger messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    var suffixCounter = 0;
    String nextSuffix() => 'e14-b02-${suffixCounter++}';

    /// Builds a ready `MessagingStack` over a `_CountingTransportService`, so
    /// each test can read `transport.discoveredDevicesAccessCount` after
    /// exercising `AppBinding.dependencies()`.
    Future<MessagingStack> buildStack() async {
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final transport = _CountingTransportService(
        binaryMessenger: messenger,
        messageChannelSuffix: nextSuffix(),
      );
      final stack = await MessagingStack.create(
        db: db,
        selfDeviceId: 'device-b02-test',
        transport: transport,
      );
      expect(
        stack.status,
        const MessagingStackStatus.ready(),
        reason: 'a degraded stack would never start anything either way, '
            'which would make this test pass for the wrong reason',
      );
      return stack;
    }

    tearDown(Get.reset);

    test(
        'test_EARS_VER_1_FR_VER_006_update_required_does_not_start_the_'
        'inbound_pipeline', () async {
      final stack = await buildStack();
      addTearDown(stack.dispose);

      AppBinding(
        db: stack.db,
        messagingStack: stack,
        blockCommunication: true,
      ).dependencies();

      final transport = stack.transport as _CountingTransportService;
      expect(
        transport.discoveredDevicesAccessCount,
        0,
        reason: 'under VersionState.updateRequired, neither '
            'MessagingCoordinator.start() nor InboundPipeline.start() may '
            'ever subscribe to live transport data',
      );
    });

    test(
        'test_up_to_date_and_update_available_still_start_the_inbound_'
        'pipeline_mirror_image', () async {
      // The mirror-image assertion the bug's own regression-test note
      // requires: this proves the fix cannot pass by breaking startup
      // generally -- the default (`blockCommunication: false`, matching
      // both VersionState.upToDate and VersionState.updateAvailable, per
      // `main.dart`'s own `versionState == VersionState.updateRequired`
      // computation) must still start everything, exactly as before this
      // fix.
      final stack = await buildStack();
      addTearDown(stack.dispose);
      addTearDown(stack.coordinator.stop);

      AppBinding(db: stack.db, messagingStack: stack).dependencies();

      final transport = stack.transport as _CountingTransportService;
      expect(
        transport.discoveredDevicesAccessCount,
        greaterThan(0),
        reason: 'under VersionState.upToDate/updateAvailable, the mesh '
            'must keep starting exactly as it always has -- this is what '
            'stops the fix from passing by disabling startup unconditionally',
      );
    });
  });
}
