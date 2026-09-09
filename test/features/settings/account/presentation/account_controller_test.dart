// features/settings/account/presentation -- AccountController (E15-T07).
// Real in-memory `AppDatabase` + the real `DeviceIdentityRepository`
// throughout -- these tests prove the controller's own binding and its own
// failure isolation, not a mock's promise of either.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/crypto/identity_key_hex.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/services/firebase_metadata_service.dart';
import 'package:nexora/features/login/data/device_identity_repository.dart';
import 'package:nexora/features/settings/account/presentation/account_controller.dart';
import 'package:nexora/features/settings/account/presentation/account_view.dart';
import 'package:nexora/features/settings/account/presentation/sign_out_confirm_controller.dart';
import 'package:nexora/features/settings/account/presentation/sign_out_confirm_view.dart';
import 'package:nexora/features/settings/account/domain/sign_out_use_case.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late DeviceIdentityRepository repository;
  late IdentityKeyPair keyPair;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = DeviceIdentityRepository(db);
    keyPair = generateIdentityKeyPair();
  });

  tearDown(() => db.close());

  AccountController buildController({
    FirebaseMetadataService? firebaseMetadataService,
  }) {
    return AccountController(
      deviceIdentityRepository: repository,
      readIdentityKeyPair: () async => keyPair,
      firebaseMetadataService:
          firebaseMetadataService ?? _EmptyFirebaseMetadataService(),
    );
  }

  test(
    'test_EARS_AUTH_12_account_screen_shows_uid_fingerprint_and_linked_devices',
    () async {
      final id = await db.createDeviceIdentity('device-local');
      await db.markSignedIn(id, accountUid: 'uid-123');

      final controller = buildController(
        firebaseMetadataService: _RespondingFirebaseMetadataService({
          'device-local',
          'device-remote',
        }),
      );
      controller.onInit();
      await pumpEventQueue();

      expect(controller.accountUid.value, 'uid-123');
      expect(controller.accountError.value, isFalse);
      expect(controller.thisDeviceId.value, 'device-local');
      expect(
        controller.deviceFingerprint.value,
        hexEncodeIdentityKey(keyPair.getPublicKey()),
      );
      expect(controller.deviceError.value, isFalse);
      expect(controller.linkedDevicesLoaded.value, isTrue);
      expect(
        controller.linkedDevices,
        containsAll(['device-local', 'device-remote']),
      );
    },
  );

  test(
    'test_no_device_identity_row_renders_the_account_error_line',
    () async {
      // No row ever created -- `latestDeviceIdentity()` returns `null`, so
      // there is no `accountUid` to read at all. Falsified: reverting the
      // controller's `uid == null` guard to instead set
      // `accountUid.value = null` unconditionally without ever flipping
      // `accountError` leaves this assertion failing (`accountError` stays
      // `false`), confirming the guard is what this test actually depends on.
      final controller = buildController();
      controller.onInit();
      await pumpEventQueue();

      expect(controller.accountUid.value, isNull);
      expect(controller.accountError.value, isTrue);
      // AC17 note: a failed account read never touches the linked-devices
      // section, which the design contract says must resolve to its own
      // (loaded, empty) state rather than hang forever.
      expect(controller.linkedDevicesLoaded.value, isTrue);
      expect(controller.linkedDevices, isEmpty);
    },
  );

  test(
    'test_EARS_UI_11_a_throwing_device_identity_repository_sets_account_error_only',
    () async {
      final controller = AccountController(
        deviceIdentityRepository: _ThrowingDeviceIdentityRepository(db),
        readIdentityKeyPair: () async => keyPair,
        firebaseMetadataService: _EmptyFirebaseMetadataService(),
      );
      controller.onInit();
      await pumpEventQueue();

      expect(controller.accountError.value, isTrue);
      expect(controller.accountUid.value, isNull);
      // The device-fingerprint read is untouched by the account read's own
      // failure -- one section's failure never touches another
      // (`EARS-UI-11`).
      expect(controller.deviceError.value, isFalse);
      expect(
        controller.deviceFingerprint.value,
        hexEncodeIdentityKey(keyPair.getPublicKey()),
      );
    },
  );

  test(
    'test_EARS_UI_11_a_throwing_identity_key_reader_sets_device_error_only',
    () async {
      final id = await db.createDeviceIdentity('device-local');
      await db.markSignedIn(id, accountUid: 'uid-123');

      final controller = AccountController(
        deviceIdentityRepository: repository,
        readIdentityKeyPair: () async =>
            throw StateError('simulated read failure'),
        firebaseMetadataService: _EmptyFirebaseMetadataService(),
      );
      controller.onInit();
      await pumpEventQueue();

      expect(controller.deviceError.value, isTrue);
      expect(controller.deviceFingerprint.value, isNull);
      // The account read's own success is untouched by the fingerprint
      // read's own failure.
      expect(controller.accountError.value, isFalse);
      expect(controller.accountUid.value, 'uid-123');
    },
  );

  test(
    'test_linked_devices_read_never_gates_on_a_network_failure',
    () async {
      final id = await db.createDeviceIdentity('device-local');
      await db.markSignedIn(id, accountUid: 'uid-123');

      // Review finding F2: the previous version of this test used
      // `_EmptyFirebaseMetadataService`, which returns `const {}`
      // successfully and never actually throws -- vacuous, proven by
      // deleting the whole try/catch/finally from
      // `AccountController._loadLinkedDevices` and watching the suite still
      // pass. `_ThrowingFirebaseMetadataService` genuinely throws, so this
      // test actually exercises the catch/finally that isolates the
      // linked-devices read's own failure from the rest of the screen.
      // Falsified: removing `_loadLinkedDevices`'s try/catch/finally (so a
      // thrown error is never caught and `linkedDevicesLoaded` is never
      // set) leaves `linkedDevicesLoaded.value` stuck at `false`, failing
      // the first assertion below -- confirmed during implementation, catch
      // block restored verbatim afterward.
      final controller = buildController(
        firebaseMetadataService: _ThrowingFirebaseMetadataService(),
      );
      controller.onInit();
      await pumpEventQueue();

      expect(controller.linkedDevicesLoaded.value, isTrue);
      expect(controller.linkedDevices, isEmpty);
      // The two other sections are entirely unaffected.
      expect(controller.accountUid.value, 'uid-123');
      expect(controller.accountError.value, isFalse);
      expect(controller.deviceFingerprint.value, isNotNull);
      expect(controller.deviceError.value, isFalse);
    },
  );

  group('widget tree', () {
    setUp(() {
      Get.testMode = true;
    });

    tearDown(() => Get.reset());

    testWidgets(
      'test_EARS_AUTH_7_account_row_tap_does_not_sign_out',
      (tester) async {
        // A call-counting `SignOutUseCase` seam (F1 in
        // `feedback_fail_in_injected_seams.md` -- a bare `fail()` inside an
        // injected seam gets swallowed by a broad `catch` in the SUT; a
        // plain call counter cannot be swallowed the same way).
        var calls = 0;
        final signOutUseCase = SignOutUseCase(
          teardown: () async {
            calls++;
          },
        );
        final accountController = buildController();
        final confirmController = SignOutConfirmController(
          signOutUseCase: signOutUseCase,
        );
        Get.put<AccountController>(accountController);
        Get.put<SignOutConfirmController>(confirmController);

        await tester.pumpWidget(
          GetMaterialApp(
            initialRoute: '/settings/account',
            getPages: [
              GetPage(
                name: '/settings/account',
                page: () => const AccountView(),
              ),
              GetPage(
                name: '/settings/sign-out-confirm',
                page: () => const SignOutConfirmView(),
              ),
            ],
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Sign out'));
        await tester.pumpAndSettle();

        // AC14 navigated -- the confirmation screen is now on top -- and
        // performed nothing else: `SignOutUseCase.call()` was never
        // invoked, proven by the teardown seam's own call counter, not by
        // the mere absence of a navigation stack failure.
        expect(find.text('Sign out and erase this device?'), findsOneWidget);
        expect(calls, 0);
      },
    );

    testWidgets(
      'test_EARS_UI_11_linked_device_read_failure_leaves_the_sign_out_row_present',
      (tester) async {
        // AC17's own note, `settings-account.md` §States `error`: "the
        // sign-out row is never hidden by a failed read" -- a user must
        // always be able to reach the confirmation screen, especially
        // when something is wrong. Falsified: wrapping `_SignOutRow` in
        // `if (!controller.accountError.value) ...` during implementation
        // made this assertion fail with `findsNothing`, confirming the
        // test actually depends on the row's unconditional placement.
        final controller = AccountController(
          deviceIdentityRepository: _ThrowingDeviceIdentityRepository(db),
          readIdentityKeyPair: () async =>
              throw StateError('simulated read failure'),
          firebaseMetadataService: _EmptyFirebaseMetadataService(),
        );
        Get.put<AccountController>(controller);

        await tester.pumpWidget(
          const GetMaterialApp(home: AccountView()),
        );
        await tester.pumpAndSettle();

        // Both cards show AC17's failure line -- confirming the failure
        // actually happened, not that this screen renders nothing.
        expect(
          find.text('Account details could not be read.'),
          findsNWidgets(2),
        );
        // The sign-out row and its caption are still there, unconditionally.
        expect(find.text('Sign out'), findsOneWidget);
        expect(
          find.text('Erases everything on this device.'),
          findsOneWidget,
        );
      },
    );
  });
}

/// A repository whose `latestDeviceIdentity()` always throws, for
/// `EARS-UI-11`'s falsification -- a real seam failure, not a mocked
/// promise of one.
class _ThrowingDeviceIdentityRepository extends DeviceIdentityRepository {
  _ThrowingDeviceIdentityRepository(super.db);

  @override
  Future<DeviceIdentity?> latestDeviceIdentity() {
    throw StateError('simulated read failure');
  }
}

/// A `FirebaseMetadataService` double that returns a fixed device-id set
/// without ever touching a real `FirebaseDatabase` -- the same "subclass
/// and override the read" seam
/// `test/core/services/firebase_metadata_service_test.dart` already
/// establishes for this class.
class _RespondingFirebaseMetadataService extends FirebaseMetadataService {
  _RespondingFirebaseMetadataService(this._ids);

  final Set<String> _ids;

  @override
  Future<Set<String>> readOwnDeviceIds(String uid) async => _ids;
}

/// Same seam, always empty -- mirrors `readOwnDeviceIds`'s own documented
/// best-effort "empty on failure" contract without a live platform channel.
class _EmptyFirebaseMetadataService extends FirebaseMetadataService {
  @override
  Future<Set<String>> readOwnDeviceIds(String uid) async => const {};
}

/// A `FirebaseMetadataService` double that genuinely throws, violating
/// `readOwnDeviceIds`'s own documented best-effort contract on purpose --
/// review finding F2. Proves `AccountController._loadLinkedDevices`'s own
/// try/catch/finally, not just the (already-honoured) contract of the real
/// service.
class _ThrowingFirebaseMetadataService extends FirebaseMetadataService {
  @override
  Future<Set<String>> readOwnDeviceIds(String uid) {
    throw StateError('simulated network failure');
  }
}
