// test/design/probe_settings_notifications_test.dart -- E15-T04's own
// fenced probe dump for `design/screens/settings-notifications.md`
// (`make design-probe` / `make design-verify SCREEN=settings-notifications`).
//
// Deliberately its OWN file, not `test/design/design_probe_test.dart` --
// that file is `E15-T11`'s alone (task §4; E08's own recorded collision
// warning: "T09 must not be given the probe fixture… T08 now owns that
// file"). `E15-T11` consolidates every sub-screen's own probe into the
// shared runner once all eight land.
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/core/notifications/notification_settings_repository.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/features/settings/notifications/presentation/notification_settings_controller.dart';
import 'package:nexora/features/settings/notifications/presentation/notification_settings_view.dart';

import 'flutter_probe_dumper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('screen probe — settings-notifications (make design-probe)', () {
    late AppDatabase db;
    late NotificationSettingsRepository repository;
    late NotificationSettingsController controller;

    setUp(() {
      Get.testMode = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = NotificationSettingsRepository(db: db);
      controller = NotificationSettingsController(repository: repository);
      Get.put<NotificationSettingsController>(controller);
    });

    // `db.close()`/`Get.reset()` run here, NOT inside `testWidgets` below --
    // a real dart:io/native async completion awaited directly inside a
    // pumped test's own body hangs forever under
    // `AutomatedTestWidgetsFlutterBinding` (`flutter_probe_dumper.dart`'s own
    // documented gotcha for `File`/`Directory` ops, the same reason
    // `design_probe_test.dart`'s `devices`/`device-enrollment-approval`
    // groups close their own `db` here and not in the test body).
    tearDown(() {
      controller.onClose();
      Get.reset();
      return db.close();
    });

    testWidgets('settings-notifications', (tester) async {
      await dumpScreenProbe(
        tester,
        screenId: 'settings-notifications',
        screen: const GetMaterialApp(home: NotificationSettingsView()),
      );

      // E12-B05, F4: a real dart:io read, through `runAsync` -- without
      // this, a future regression that silently brings back
      // `renderError: true` would still say "All tests passed" here.
      final raw = await tester.runAsync(
        () => File(
          'build/design-probe/settings-notifications.json',
        ).readAsString(),
      );
      final dump = jsonDecode(raw!) as Map<String, dynamic>;
      expect(dump['renderError'], isNull);
    });
  });
}
