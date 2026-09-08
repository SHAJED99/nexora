// test/design/probe_settings_security_center_test.dart -- E15-T06's own
// fenced probe dump for `design/screens/settings-security-center.md`
// (`make design-probe` / `make design-verify SCREEN=settings-security-center`).
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
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/features/settings/security_center/data/security_records_repository.dart';
import 'package:nexora/features/settings/security_center/presentation/security_center_controller.dart';
import 'package:nexora/features/settings/security_center/presentation/security_center_view.dart';

import 'flutter_probe_dumper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('screen probe — settings-security-center (make design-probe)', () {
    late AppDatabase db;
    late SecurityRecordsRepository repository;
    late SecurityCenterController controller;

    setUp(() async {
      Get.testMode = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      // A single revoked-device row so the golden probe reflects a real
      // row layout (device id + state label + "when"), not only the four
      // empty lines -- the same "author the golden from real dumper
      // output" instruction this task carries forward from T03/T04's own
      // reviews (F1).
      await db
          .into(db.deviceRevocations)
          .insert(
            DeviceRevocationsCompanion.insert(
              deviceId: 'probe-device',
              revokedAt: DateTime(2026, 1, 1),
              source: 'local',
            ),
          );
      repository = SecurityRecordsRepository(db: db);
      controller = SecurityCenterController(repository: repository);
      Get.put<SecurityCenterController>(controller);
    });

    // `db.close()`/`Get.reset()` run here, NOT inside `testWidgets` below --
    // a real dart:io/native async completion awaited directly inside a
    // pumped test's own body hangs forever under
    // `AutomatedTestWidgetsFlutterBinding` (`flutter_probe_dumper.dart`'s
    // own documented gotcha, the same reason
    // `probe_settings_notifications_test.dart` closes its own `db` here).
    tearDown(() {
      Get.reset();
      return db.close();
    });

    testWidgets('settings-security-center', (tester) async {
      // `SecurityCenterController.onInit` (fired by `Get.put` in `setUp`
      // above) kicks off four one-shot `Future`-based repository reads
      // over the real `NativeDatabase` -- the same genuine dart:io/native
      // async completion `flutter_probe_dumper.dart`'s own header warns
      // never resolves from a plain `tester.pump()`/`pumpAndSettle()`
      // inside `AutomatedTestWidgetsFlutterBinding`. Draining them here,
      // through `runAsync`, BEFORE `dumpScreenProbe` mounts and walks the
      // tree, is what makes the golden capture the real row (not four
      // headings-only cards) -- verified directly: without this drain the
      // dump was missing every row/empty-line element under every
      // section, only headings/cards/glyph/the nav link came through.
      await tester.runAsync(() async {
        while (controller.revocations.value == null ||
            controller.trustedIdentities.value == null ||
            controller.blockedPeers.value == null ||
            controller.rateLimitDenials.value == null) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });

      await dumpScreenProbe(
        tester,
        screenId: 'settings-security-center',
        screen: const GetMaterialApp(home: SecurityCenterView()),
      );

      // E12-B05, F4: a real dart:io read, through `runAsync` -- without
      // this, a future regression that silently brings back
      // `renderError: true` would still say "All tests passed" here.
      final raw = await tester.runAsync(
        () => File(
          'build/design-probe/settings-security-center.json',
        ).readAsString(),
      );
      final dump = jsonDecode(raw!) as Map<String, dynamic>;
      expect(dump['renderError'], isNull);
    });
  });
}
