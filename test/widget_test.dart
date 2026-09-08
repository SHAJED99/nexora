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
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/app/bindings.dart';
import 'package:nexora/core/abuse/rate_limiter.dart';
import 'package:nexora/core/background/background_service.dart';
import 'package:nexora/core/background/background_stub.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/notifications/generated/notification_api.g.dart'
    show NotificationApi;
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/login/data/device_identity_repository.dart';
import 'package:nexora/features/login/domain/sign_in_use_case.dart';
import 'package:nexora/features/login/presentation/login_controller.dart';
import 'package:nexora/features/login/presentation/login_view.dart';
import 'package:nexora/features/settings/account/domain/resolve_initial_route_use_case.dart';
import 'package:nexora/features/version/domain/version_state.dart';
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

  /// Same reasoning, for the second of the four gated subsystems:
  /// `LinkQualityFeed.start()` (`link_quality_feed.dart:48`) is the ONLY
  /// production call site that subscribes to `TransportService.linkQuality`
  /// -- counting accesses to this getter is a direct, non-fragile proxy for
  /// "did the link-quality feed actually get subscribed" under
  /// `AppBinding.dependencies()`.
  int linkQualityAccessCount = 0;

  @override
  Stream<LinkQuality> get linkQuality {
    linkQualityAccessCount++;
    return super.linkQuality;
  }
}

/// The third gated subsystem's own counting seam, mirroring
/// `_CountingTransportService` above exactly: `BackgroundLifecycleObserver
/// .start()` (`bindings.dart`) is the ONLY production call site that
/// subscribes to `BackgroundControl.state`/`.powerStates` -- counting
/// accesses to those two getters is a direct proxy for "did the background
/// observer actually attach its listeners" under
/// `AppBinding.dependencies()`, without a `fail()` planted inside either
/// stream (this project's own lesson on `fail()` in injected seams: a broad
/// catch in the SUT can swallow it silently).
class _CountingBackgroundControl extends BackgroundStub {
  int stateAccessCount = 0;
  int powerStatesAccessCount = 0;

  @override
  Stream<ServiceState> get state {
    stateAccessCount++;
    return super.state;
  }

  @override
  Stream<PowerState> get powerStates {
    powerStatesAccessCount++;
    return super.powerStates;
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

    // E14-B02 (round 2, coverage gap fix): `notificationDispatcher.start()`
    // is the fourth gated subsystem. `bindings.dart` always constructs its
    // `NotificationService()` with the default, empty `messageChannelSuffix`
    // -- there is exactly one Pigeon channel name for `ensureChannels()` for
    // every test in this group, so mocking that ONE channel and counting
    // invocations is a direct, non-fragile proxy for "did
    // `NotificationDispatcher.start()` -- and therefore every
    // `_subscribe(source)` call inside it -- ever run", without reaching
    // into that class's private `_subscriptions` list. `ensureReady()`
    // (`notification_service.dart`) calls `ensureChannels()` as its very
    // first platform call, before anything else, so this is reached (or
    // not) exactly when `start()` itself is (or isn't).
    const String ensureChannelsChannel =
        'dev.flutter.pigeon.nexora.NotificationApi.ensureChannels';
    final BasicMessageChannel<Object?> ensureChannelsChannelHandle =
        BasicMessageChannel<Object?>(
      ensureChannelsChannel,
      NotificationApi.pigeonChannelCodec,
      binaryMessenger: messenger,
    );
    var ensureChannelsCallCount = 0;

    setUp(() {
      ensureChannelsCallCount = 0;
      // `setMockMessageHandler` (raw bytes) is deprecated in favour of this
      // decoded form -- same effect, no new analyzer info.
      messenger.setMockDecodedMessageHandler<Object?>(
        ensureChannelsChannelHandle,
        (Object? message) async {
          ensureChannelsCallCount++;
          return <Object?>[null];
        },
      );
    });

    tearDown(
      () => messenger.setMockDecodedMessageHandler<Object?>(
        ensureChannelsChannelHandle,
        null,
      ),
    );
    tearDown(Get.reset);

    test(
        'test_EARS_VER_1_FR_VER_006_update_required_does_not_start_the_'
        'inbound_pipeline', () async {
      final stack = await buildStack();
      addTearDown(stack.dispose);
      final backgroundControl = _CountingBackgroundControl();
      addTearDown(backgroundControl.dispose);

      AppBinding(
        db: stack.db,
        messagingStack: stack,
        blockCommunication: true,
        backgroundControl: backgroundControl,
      ).dependencies();

      final transport = stack.transport as _CountingTransportService;
      expect(
        transport.discoveredDevicesAccessCount,
        0,
        reason: 'under VersionState.updateRequired, neither '
            'MessagingCoordinator.start() nor InboundPipeline.start() may '
            'ever subscribe to live transport data',
      );
      expect(
        transport.linkQualityAccessCount,
        0,
        reason: 'under VersionState.updateRequired, '
            'LinkQualityFeed.start() may never subscribe to live '
            'link-quality events either',
      );
      expect(
        backgroundControl.stateAccessCount,
        0,
        reason: 'under VersionState.updateRequired, '
            'BackgroundLifecycleObserver.start() may never subscribe to '
            'the background service state stream',
      );
      expect(
        backgroundControl.powerStatesAccessCount,
        0,
        reason: 'under VersionState.updateRequired, '
            'BackgroundLifecycleObserver.start() may never subscribe to '
            'the power-state stream either',
      );

      // `notificationDispatcher.start()` is fire-and-forget
      // (`unawaited(...)` in `bindings.dart`) -- let any pending
      // microtask run before asserting its absence, or this assertion
      // would pass even on unfixed code purely because nothing has had a
      // chance to run yet.
      await Future<void>.delayed(Duration.zero);
      expect(
        ensureChannelsCallCount,
        0,
        reason: 'under VersionState.updateRequired, '
            'NotificationDispatcher.start() may never run either -- so it '
            'must never reach NotificationService.ensureReady()',
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
      final backgroundControl = _CountingBackgroundControl();
      addTearDown(backgroundControl.dispose);

      AppBinding(
        db: stack.db,
        messagingStack: stack,
        backgroundControl: backgroundControl,
      ).dependencies();

      final transport = stack.transport as _CountingTransportService;
      expect(
        transport.discoveredDevicesAccessCount,
        greaterThan(0),
        reason: 'under VersionState.upToDate/updateAvailable, the mesh '
            'must keep starting exactly as it always has -- this is what '
            'stops the fix from passing by disabling startup unconditionally',
      );
      expect(
        transport.linkQualityAccessCount,
        greaterThan(0),
        reason: 'under VersionState.upToDate/updateAvailable, '
            'LinkQualityFeed.start() must keep subscribing exactly as it '
            'always has',
      );
      expect(
        backgroundControl.stateAccessCount,
        greaterThan(0),
        reason: 'under VersionState.upToDate/updateAvailable, '
            'BackgroundLifecycleObserver.start() must keep subscribing to '
            'the background service state stream exactly as it always has',
      );
      expect(
        backgroundControl.powerStatesAccessCount,
        greaterThan(0),
        reason: 'under VersionState.upToDate/updateAvailable, '
            'BackgroundLifecycleObserver.start() must keep subscribing to '
            'the power-state stream exactly as it always has',
      );

      await Future<void>.delayed(Duration.zero);
      expect(
        ensureChannelsCallCount,
        greaterThan(0),
        reason: 'under VersionState.upToDate/updateAvailable, '
            'NotificationDispatcher.start() must keep running exactly as '
            'it always has, reaching NotificationService.ensureReady()',
      );
    });
  });

  testWidgets(
    'F1 regression (E13-T07 review round 2, S1/S2; route updated by '
    'E15-T02): a returning device (one that already has a local identity, '
    'e.g. relaunch #6+ of the app) reaches the dashboard DIRECTLY at '
    'launch — no welcome screen, no login tap — never denied by the '
    'per-account registration rate limiter',
    (WidgetTester tester) async {
      // Before E13-T07's fix, `LoginController._signIn` minted a brand-new
      // random device id on EVERY launch and always went through
      // `SignInUseCase`'s registration path, gated by
      // `DeviceIdentityRepository`'s per-account rate limit
      // (5 registrations / 24h, E13-T02) — so a device that already had a
      // local identity (i.e. every relaunch past the very first) would
      // still count against that same limit and could be denied. A real
      // `RateLimiter` is used here, pre-loaded (via direct repository
      // writes, no UI) with 5 PRIOR registrations under the SAME account —
      // exactly at the cap — kept exactly as E13-T07 left it, unchanged by
      // this task.
      //
      // E15-T02 (FR-AUTH-010): the SUBJECT this test proves — "a returning
      // device is never denied by the rate limiter" — does not change; only
      // the NAVIGATION PATH does. A returning device's local identity now
      // means `resolveInitialRoute` sends the launch straight to
      // `/dashboard`, so this device never even reaches `LoginController`
      // (and therefore never re-registers, never touches the rate limiter
      // at all) — a strictly stronger proof than routing it back through
      // login and trusting `SignInUseCase` to reuse the existing row.
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = DeviceIdentityRepository(
        db,
        rateLimiter: RateLimiter(db),
      );
      const accountUid = 'firebase-uid-returning-widget';

      // 5 OTHER devices already registered under this account — the cap
      // (`_maxDeviceRegistrationsPerWindow` = 5) is already exhausted.
      // Written directly through `db` (bypassing the repository's own
      // gate) purely to seed test history — these are meant to represent
      // registrations that already happened in the past, not attempts this
      // test itself is making.
      for (var i = 0; i < 5; i++) {
        final id = await db.createDeviceIdentity('other-device-$i');
        await db.markSignedIn(id, accountUid: accountUid);
      }
      // THIS device's own existing local identity — the one
      // `resolveInitialRoute`'s `hasLocalIdentity` must be computed from
      // (via `db.latestDeviceIdentity()`, the same read `main()` performs),
      // never re-derived or re-registered.
      final ownId = await db.createDeviceIdentity('this-devices-own-id');
      await db.markSignedIn(ownId, accountUid: accountUid);

      // `SignInUseCase`/`LoginController` are unused by this test's own
      // navigation now (E15-T02 §4: this task does not touch
      // `LoginController`) — kept only as evidence that, even though both
      // are registered exactly as before, a returning device's launch
      // never calls into them.
      final signInUseCase = SignInUseCase(
        repository,
        authService: FakeGoogleAuthService.success(accountUid),
      );

      Get.lazyPut(WelcomeController.new);
      Get.lazyPut(() => LoginController(signInUseCase));

      // The exact decision `main()` makes at launch (`resolveInitialRoute`,
      // fed by the SAME `db.latestDeviceIdentity()` read main() performs)
      // — not a hard-coded `/dashboard`, so this test would fail the same
      // way main() would if that function's precedence ever regressed.
      final hasLocalIdentity = await db.latestDeviceIdentity() != null;
      final initialRoute = resolveInitialRoute(
        versionState: VersionState.upToDate,
        hasLocalIdentity: hasLocalIdentity,
      );

      await tester.pumpWidget(
        GetMaterialApp(
          initialRoute: initialRoute,
          getPages: [
            GetPage<dynamic>(name: '/welcome', page: () => const WelcomeView()),
            GetPage<dynamic>(name: '/login', page: () => const LoginView()),
            GetPage<dynamic>(
              name: '/dashboard',
              page: () => const Text('dashboard placeholder'),
            ),
          ],
        ),
      );
      await tester.pumpAndSettle();

      // Lands on the dashboard WITHOUT ever showing welcome or login — the
      // whole point of E15-T02, and a strictly stronger version of F1's
      // original "not stuck on Signing in..." proof.
      expect(find.text('Continue with Google'), findsNothing);
      expect(find.text('Signing in with Google...'), findsNothing);
      expect(
        find.text('dashboard placeholder'),
        findsOneWidget,
        reason: 'a returning device must launch straight to /dashboard — a '
            'rate-limit denial on a login round-trip is no longer even '
            'possible once the launch never routes through login at all',
      );

      // Still exactly 6 rows total (5 other devices + this one) — nothing
      // about this launch wrote a 7th row; `resolveInitialRoute` only
      // READS whether an identity exists, it never registers one.
      final rows = await db.select(db.deviceIdentities).get();
      expect(rows, hasLength(6));

      await db.close();
    },
  );
}
