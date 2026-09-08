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
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/features/settings/security_center/data/security_records_repository.dart';
import 'package:nexora/features/settings/security_center/presentation/security_center_controller.dart';
import 'package:nexora/features/settings/security_center/presentation/security_center_view.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

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
      // One row per section so the golden probe reflects a real row
      // layout for EVERY section (device id + state label + "when",
      // device id + state label, device id + state label, limit name +
      // count) -- the same "author the golden from real dumper output"
      // instruction this task carries forward from T03/T04's own reviews
      // (F1), widened by F5 (review round on this PR): the original
      // fixture seeded only `DeviceRevocations`, leaving the golden
      // structurally blind to SC10/SC14/SC19's own row shapes -- the
      // `design-fidelity` skill's own rule 6 ("a task that widens a
      // design-contracted screen's displayed data shape must update the
      // shared probe fixture") applied in reverse here: the fixture was
      // never widened to cover shapes the contract already specified.
      // Seeding mirrors `security_center_controller_test.dart`'s own
      // `test_EARS_DIAG_5_no_action_affordance_is_rendered` shape.
      //
      // F3 (review round on this PR): `revokedAt` is seeded RELATIVE to
      // `DateTime.now()`, not a fixed absolute date. The view renders
      // this via `DateTime.now().difference(revokedAt)` as "Xd ago" --
      // a fixed `DateTime(2026, 1, 1)` produced a golden literally
      // containing "251d ago" that would silently roll over to "252d
      // ago" (then "253d ago", ...) on every later day this gate runs,
      // failing on a pure copy mismatch with no real regression behind
      // it (confirmed: re-running the gate against a probe dumped one
      // day later failed with exactly that diff). `Duration(hours: 2)`
      // renders as a stable "2h ago" that cannot roll over within any
      // plausible CI run.
      await db
          .into(db.deviceRevocations)
          .insert(
            DeviceRevocationsCompanion.insert(
              deviceId: 'probe-device',
              revokedAt: DateTime.now().subtract(const Duration(hours: 2)),
              source: 'local',
            ),
          );
      await db
          .into(db.signalTrustedIdentities)
          .insert(
            SignalTrustedIdentitiesCompanion.insert(
              addressName: 'probe-trusted-device',
              addressDeviceId: 1,
              identityKey: Uint8List.fromList(const [1, 2, 3]),
            ),
          );
      await db
          .into(db.relationships)
          .insert(
            RelationshipsCompanion.insert(
              deviceId: 'probe-blocked-device',
              state: RelationshipState.blocked.name,
              updatedAt: DateTime.now(),
            ),
          );
      await db
          .into(db.rateLimitCounters)
          .insert(
            RateLimitCountersCompanion.insert(
              bucketKey: 'relay:probe-rate-limited-device',
              windowStartMs: 0,
              count: 3,
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
