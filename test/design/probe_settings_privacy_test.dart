// test/design/probe_settings_privacy_test.dart -- E15-T05's own fenced
// probe dump for `design/screens/settings-privacy.md`
// (`make design-probe` / `make design-verify SCREEN=settings-privacy`).
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
import 'package:nexora/core/persistence/notification_tables.dart'
    show NotificationPrivacyLevel;
import 'package:nexora/features/location/data/location_settings_repository.dart';
import 'package:nexora/features/settings/privacy/presentation/privacy_settings_controller.dart';
import 'package:nexora/features/settings/privacy/presentation/privacy_settings_view.dart';

import 'flutter_probe_dumper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('screen probe — settings-privacy (make design-probe)', () {
    late AppDatabase db;
    late LocationSettingsRepository locationRepository;
    late NotificationSettingsRepository notificationRepository;
    late PrivacySettingsController controller;

    setUp(() async {
      Get.testMode = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      locationRepository = LocationSettingsRepository(db: db);
      notificationRepository = NotificationSettingsRepository(db: db);
      // A real, non-empty `default` state: the golden should show at least
      // one peer row and a real privacy level, not the `loading`/`empty`
      // treatment.
      await locationRepository.writeGlobalEnabled(true);
      await locationRepository.writePeerEnabled('peer-nexora-1', true);
      await notificationRepository.setPrivacyLevel(
        NotificationPrivacyLevel.senderOnly,
      );
      controller = PrivacySettingsController(
        locationRepository: locationRepository,
        notificationRepository: notificationRepository,
      );
      Get.put<PrivacySettingsController>(controller);
      // `Get.put` calls `onInit()` synchronously, which starts
      // `readAllPeerEnabled()`/`privacyLevel()` -- both real one-shot
      // `Future`s, not streams. `dumpScreenProbe`'s own bounded
      // `pumpAndSettle` can return as soon as no FRAME is pending, which is
      // not the same as "every outstanding Future has resolved" -- a real
      // race that dropped the per-person list and the notification-privacy
      // label from the first cut of this dump entirely. Draining the event
      // queue here, before the widget is ever pumped, lets both Futures
      // land first so the very first frame already reflects the loaded
      // state (same idiom `privacy_settings_controller_test.dart` uses).
      await pumpEventQueue();
    });

    // `db.close()`/`Get.reset()` run here, NOT inside `testWidgets` below --
    // a real dart:io/native async completion awaited directly inside a
    // pumped test's own body hangs forever under
    // `AutomatedTestWidgetsFlutterBinding` (`flutter_probe_dumper.dart`'s own
    // documented gotcha for `File`/`Directory` ops, the same reason
    // `probe_settings_notifications_test.dart` closes its own `db` here and
    // not in the test body).
    tearDown(() {
      controller.onClose();
      Get.reset();
      return db.close();
    });

    testWidgets('settings-privacy', (tester) async {
      // `dumpScreenProbe` itself pumps the widget and settles (bounded, up
      // to 5s) before walking the tree -- long enough for the global
      // stream's first emission and the two Future-based loads to land, so
      // the dump captures the `default` state, not `loading`.
      await dumpScreenProbe(
        tester,
        screenId: 'settings-privacy',
        screen: const GetMaterialApp(home: PrivacySettingsView()),
      );

      // E12-B05, F4: a real dart:io read, through `runAsync` -- without
      // this, a future regression that silently brings back
      // `renderError: true` would still say "All tests passed" here.
      final raw = await tester.runAsync(
        () => File(
          'build/design-probe/settings-privacy.json',
        ).readAsString(),
      );
      final dump = jsonDecode(raw!) as Map<String, dynamic>;
      expect(dump['renderError'], isNull);
    });
  });
}
