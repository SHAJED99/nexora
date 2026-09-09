// test/design/probe_settings_account_test.dart -- E15-T07's own fenced
// probe dump for `design/screens/settings-account.md`
// (`make design-probe` / `make design-verify SCREEN=settings-account`).
//
// Deliberately its OWN file, not `test/design/design_probe_test.dart` --
// that file is `E15-T11`'s alone (task §4; E08's own recorded collision
// warning). `E15-T11` consolidates every sub-screen's own probe into the
// shared runner once all eight land.
import 'dart:convert';
import 'dart:io';

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

import 'flutter_probe_dumper.dart';

/// A FIXED identity keypair's serialized bytes, hex-encoded -- generated
/// once (`generateIdentityKeyPair().serialize()`) and frozen here, never
/// re-generated. Review finding F1: `generateIdentityKeyPair()` produces a
/// fresh random keypair on every single test run, so the fingerprint AC10
/// renders (and the copy the golden froze) changed on every re-run of
/// `design-verify`, making the gate non-deterministic by construction. A
/// probe golden can only ever match a build whose inputs are themselves
/// deterministic.
const _fixedIdentityKeyPairHex =
    '0a21057070164f491bff2eca7be615843b0a529890157757216fe5a5dabcc6808f52'
    '741220389e9a1c1f7ef0868234225e4bbeaa1d678960ca49e7666f1c9954a6150c5b'
    '57';

IdentityKeyPair _fixedIdentityKeyPair() =>
    IdentityKeyPair.fromSerialized(hexDecodeBytes(_fixedIdentityKeyPairHex));

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('screen probe — settings-account (make design-probe)', () {
    late AppDatabase db;
    late DeviceIdentityRepository repository;
    late AccountController controller;

    setUp(() async {
      Get.testMode = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = DeviceIdentityRepository(db);
      // A real row, seeded through the real repository, so the golden
      // probe reflects a real machine value in AC6 and a real linked
      // device row shape in AC13, not just headings and empty lines --
      // the same "author the golden from real dumper output" instruction
      // this task carries forward from T04/T05/T06's own reviews.
      final id = await db.createDeviceIdentity('probe-device-local');
      await db.markSignedIn(id, accountUid: 'probe-account-uid');

      controller = AccountController(
        deviceIdentityRepository: repository,
        readIdentityKeyPair: () async => _fixedIdentityKeyPair(),
        firebaseMetadataService: _RespondingFirebaseMetadataService({
          'probe-device-local',
          'probe-device-linked',
        }),
      );
      Get.put<AccountController>(controller);
    });

    // `db.close()`/`Get.reset()` run here, NOT inside `testWidgets` below --
    // a real dart:io/native async completion awaited directly inside a
    // pumped test's own body hangs forever under
    // `AutomatedTestWidgetsFlutterBinding`
    // (`flutter_probe_dumper.dart`'s own documented gotcha).
    tearDown(() {
      Get.reset();
      return db.close();
    });

    testWidgets('settings-account', (tester) async {
      // `AccountController.onInit` (fired by `Get.put` in `setUp` above)
      // kicks off two one-shot reads (account identity, device
      // fingerprint) plus a chained third (linked devices) over the real
      // `NativeDatabase` -- the same genuine dart:io/native async
      // completion `flutter_probe_dumper.dart`'s own header warns never
      // resolves from a plain `tester.pump()`/`pumpAndSettle()` inside
      // `AutomatedTestWidgetsFlutterBinding`. Draining them here, through
      // `runAsync`, BEFORE `dumpScreenProbe` mounts and walks the tree, is
      // what makes the golden capture the real rows.
      await tester.runAsync(() async {
        while (controller.accountUid.value == null ||
            controller.deviceFingerprint.value == null ||
            !controller.linkedDevicesLoaded.value) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });

      await dumpScreenProbe(
        tester,
        screenId: 'settings-account',
        screen: const GetMaterialApp(home: AccountView()),
      );

      // E12-B05, F4: a real dart:io read, through `runAsync` -- without
      // this, a future regression that silently brings back
      // `renderError: true` would still say "All tests passed" here.
      final raw = await tester.runAsync(
        () => File(
          'build/design-probe/settings-account.json',
        ).readAsString(),
      );
      final dump = jsonDecode(raw!) as Map<String, dynamic>;
      expect(dump['renderError'], isNull);
    });
  });
}

class _RespondingFirebaseMetadataService extends FirebaseMetadataService {
  _RespondingFirebaseMetadataService(this._ids);

  final Set<String> _ids;

  @override
  Future<Set<String>> readOwnDeviceIds(String uid) async => _ids;
}
