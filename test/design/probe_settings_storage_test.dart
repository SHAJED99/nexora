// test/design/probe_settings_storage_test.dart -- E15-T09's own fenced
// probe dump for `design/screens/settings-storage.md`
// (`make design-probe` / `make design-verify SCREEN=settings-storage`).
//
// Deliberately its OWN file, not `test/design/design_probe_test.dart` --
// that file is `E15-T11`'s alone (task §4; E08's own recorded collision
// warning: "T09 must not be given the probe fixture when it is sharded,
// since T08 now owns that file"). `E15-T11` consolidates every sub-screen's
// own probe into the shared runner once all eight land.
import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/storage/storage_decision_log.dart';
import 'package:nexora/core/storage/storage_inventory.dart';
import 'package:nexora/core/storage/storage_settings_repository.dart';
import 'package:nexora/features/settings/storage/presentation/storage_settings_controller.dart';
import 'package:nexora/features/settings/storage/presentation/storage_settings_view.dart';

import 'flutter_probe_dumper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('screen probe — settings-storage (make design-probe)', () {
    late AppDatabase db;
    late StorageSettingsController controller;

    setUp(() {
      Get.testMode = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      controller = StorageSettingsController(
        settings: StorageSettingsRepository(db: db),
        log: StorageDecisionLog(db: db),
        inventory: StorageInventory(db: db, databaseFileBytes: () async => 0),
      );
      Get.put<StorageSettingsController>(controller);
    });

    // `db.close()`/`Get.reset()` run here, NOT inside `testWidgets` below --
    // a real dart:io/native async completion awaited directly inside a
    // pumped test's own body hangs forever under
    // `AutomatedTestWidgetsFlutterBinding` (`flutter_probe_dumper.dart`'s
    // own documented gotcha, and `probe_settings_notifications_test.dart`'s
    // own precedent for this exact fix).
    tearDown(() {
      controller.onClose();
      Get.reset();
      return db.close();
    });

    testWidgets('settings-storage', (tester) async {
      // The default (`smart`) install: the mode selector loads immediately,
      // no candidates are scheduled (`empty`, the expected reading on a
      // default install), and the usage summary reads real zero totals --
      // the golden this build's own default state.
      await dumpScreenProbe(
        tester,
        screenId: 'settings-storage',
        screen: const GetMaterialApp(home: StorageSettingsView()),
      );

      // E12-B05, F4: a real dart:io read, through `runAsync` -- without
      // this, a future regression that silently brings back
      // `renderError: true` would still say "All tests passed" here.
      final raw = await tester.runAsync(
        () => File('build/design-probe/settings-storage.json').readAsString(),
      );
      final dump = jsonDecode(raw!) as Map<String, dynamic>;
      expect(dump['renderError'], isNull);
    });
  });
}
