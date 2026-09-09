// test/design/probe_settings_about_test.dart -- E15-T10's own fenced probe
// dump for `design/screens/settings-about.md`
// (`make design-probe` / `make design-verify SCREEN=settings-about`).
//
// Deliberately its OWN file, not `test/design/design_probe_test.dart` --
// that file is `E15-T11`'s alone (task §4; E08's own recorded collision
// warning). `E15-T11` consolidates every sub-screen's own probe into the
// shared runner once all eight land.
//
// Every value fed into `AboutSettingsController` here is FIXED, not read
// from the real `package_info_plus` platform channel (unavailable in this
// test binary, and would make the golden vary with whatever happens to be
// installed on the machine running the suite) and not a wall-clock-relative
// timestamp (`E15-T06`'s own review round F3: a `DateTime.now()`-relative
// "Xd ago" string silently rolls over and breaks the gate on pure copy
// drift with no real regression behind it -- confirmed by that task by
// re-running its gate a day later). Every timestamp below is rendered as
// its own fixed, absolute machine value (`SettingsMachineValue`/
// `SettingsBodyLine` on a literal `int`/ISO-8601 string), so this golden
// stays reproducible on every future run.
import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Value;
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/services/version_policy_service.dart';
import 'package:nexora/features/settings/about/presentation/about_settings_controller.dart';
import 'package:nexora/features/settings/about/presentation/about_settings_view.dart';

import 'flutter_probe_dumper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('screen probe — settings-about (make design-probe)', () {
    late AppDatabase db;
    late VersionPolicyService policyService;
    late AboutSettingsController controller;

    setUp(() async {
      Get.testMode = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      policyService = VersionPolicyService(database: db);
      // A cached policy row, so AB11/AB12 render real row content, not
      // AB13's empty line -- the same "seed one row so the golden reflects
      // a real row layout" instruction `probe_settings_security_center_test.dart`
      // already followed for its own sections. Every value is a fixed
      // literal (task briefing: "seed a FIXED/mocked version value, not
      // the actual package_info_plus runtime value").
      await db
          .into(db.versionPolicyCache)
          .insertOnConflictUpdate(
            VersionPolicyCacheCompanion.insert(
              id: const Value(1),
              minimumSupportedBuild: 100,
              currentBuild: 250,
              updateAvailableBuild: 200,
              signature: 'probe-signature',
              updatedAt: 1700000000000,
            ),
          );
      controller = AboutSettingsController(
        versionPolicyService: policyService,
        // Fixed version/build -- never the real platform channel (see
        // this file's own header comment).
        versionProvider: () async => '9.9.9',
        buildNumberProvider: () async => 250,
        // One fixed diagnostic entry, so AB16's own row shape is captured
        // for real, not just AB17's empty line -- the same reasoning
        // `probe_settings_security_center_test.dart` already applied
        // ("author the golden from real dumper output... a fixture never
        // widened is a fixture the design-fidelity skill's own rule 6
        // warns about").
        logEntriesProvider: () async => [
          DiagnosticEntry(
            code: 'version.installed_build_read_failed',
            timestamp: DateTime.utc(2026, 1, 1),
          ),
        ],
      );
      Get.put<AboutSettingsController>(controller);
    });

    // `db.close()`/`Get.reset()` run here, NOT inside `testWidgets` below --
    // a real dart:io/native async completion awaited directly inside a
    // pumped test's own body hangs forever under
    // `AutomatedTestWidgetsFlutterBinding` (`flutter_probe_dumper.dart`'s
    // own documented gotcha, the same reason
    // `probe_settings_security_center_test.dart` closes its own `db` here).
    tearDown(() {
      Get.reset();
      return db.close();
    });

    testWidgets('settings-about', (tester) async {
      // Drain the three one-shot reads through `runAsync` BEFORE
      // `dumpScreenProbe` mounts and walks the tree -- the same real
      // dart:io/native async completion `flutter_probe_dumper.dart`'s own
      // header warns never resolves from a plain `pump()`/`pumpAndSettle()`
      // inside `AutomatedTestWidgetsFlutterBinding`.
      await tester.runAsync(() async {
        while (controller.version.value == null ||
            !controller.policyLoaded.value ||
            !controller.logEntriesLoaded.value) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });

      await dumpScreenProbe(
        tester,
        screenId: 'settings-about',
        screen: const GetMaterialApp(home: AboutSettingsView()),
      );

      // E12-B05, F4: a real dart:io read, through `runAsync` -- without
      // this, a future regression that silently brings back
      // `renderError: true` would still say "All tests passed" here.
      final raw = await tester.runAsync(
        () => File('build/design-probe/settings-about.json').readAsString(),
      );
      final dump = jsonDecode(raw!) as Map<String, dynamic>;
      expect(dump['renderError'], isNull);
    });
  });
}
