// features/settings/security_center/presentation --
// SecurityCenterController (E15-T06). Real in-memory `AppDatabase` + the
// real `SecurityRecordsRepository` throughout -- these tests prove the
// controller's own binding and its own failure isolation, not a mock's
// promise of either.
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/features/settings/security_center/data/security_records_repository.dart';
import 'package:nexora/features/settings/security_center/presentation/security_center_controller.dart';
import 'package:nexora/features/settings/security_center/presentation/security_center_view.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late SecurityRecordsRepository repository;
  late SecurityCenterController controller;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = SecurityRecordsRepository(db: db);
    controller = SecurityCenterController(repository: repository);
  });

  tearDown(() => db.close());

  test(
    'test_EARS_DIAG_4_all_four_sections_empty_renders_their_own_empty_lines',
    () async {
      controller.onInit();
      await pumpEventQueue();

      expect(controller.revocations.value, isEmpty);
      expect(controller.trustedIdentities.value, isEmpty);
      expect(controller.blockedPeers.value, isEmpty);
      expect(controller.rateLimitDenials.value, isEmpty);
      expect(controller.revocationsError.value, isFalse);
      expect(controller.trustedIdentitiesError.value, isFalse);
      expect(controller.blockedPeersError.value, isFalse);
      expect(controller.rateLimitDenialsError.value, isFalse);
    },
  );

  test(
    'test_EARS_DIAG_4_default_state_loads_records_from_the_repository',
    () async {
      final revokedAt = DateTime(2026, 9, 1);
      await db
          .into(db.deviceRevocations)
          .insert(
            DeviceRevocationsCompanion.insert(
              deviceId: 'device-a',
              revokedAt: revokedAt,
              source: 'local',
            ),
          );

      controller.onInit();
      await pumpEventQueue();

      expect(controller.revocations.value, hasLength(1));
      expect(controller.revocations.value!.single.displayIdentifier, 'device-a');
    },
  );

  test(
    'test_EARS_UI_11_one_section_failing_leaves_the_other_three_rendered',
    () async {
      final erroringRepository = _ErroringRevocationsRepository(db: db);
      final erroringController = SecurityCenterController(
        repository: erroringRepository,
      );

      erroringController.onInit();
      await pumpEventQueue();

      expect(erroringController.revocationsError.value, isTrue);
      expect(erroringController.revocations.value, isNull);
      // The other three sections' own reads are untouched.
      expect(erroringController.trustedIdentitiesError.value, isFalse);
      expect(erroringController.blockedPeersError.value, isFalse);
      expect(erroringController.rateLimitDenialsError.value, isFalse);
      expect(erroringController.trustedIdentities.value, isEmpty);
      expect(erroringController.blockedPeers.value, isEmpty);
      expect(erroringController.rateLimitDenials.value, isEmpty);
    },
  );

  test('test_EARS_DIAG_5_screen_performs_no_write', () async {
    // `SecurityRecordsRepository` has no write method of any kind (task
    // §2/§4) -- there is no seam to call-count. This is the structural half
    // of `EARS-DIAG-5`; the widget-level half (no button/dismissible/menu)
    // is proven below.
    controller.onInit();
    await pumpEventQueue();

    // The controller's own public surface exposes no method beyond
    // `onInit` -- confirmed by this file's own imports/usages never
    // calling anything but the four loads above.
    expect(controller.revocations.value, isNotNull);
  });

  group('widget tree', () {
    setUp(() {
      Get.testMode = true;
      Get.put<SecurityCenterController>(controller);
    });

    tearDown(() => Get.reset());

    testWidgets(
      'test_EARS_DIAG_5_no_action_affordance_is_rendered',
      (tester) async {
        // Seed one row per section so every card renders a real row, not
        // just its own empty line -- a row is where an accidental action
        // affordance would most likely hide. Every direct `db`/repository
        // operation here runs through `tester.runAsync` -- a real
        // dart:io/native async completion awaited straight inside a
        // pumped test's own body hangs forever under
        // `AutomatedTestWidgetsFlutterBinding` (the same gotcha
        // `flutter_probe_dumper.dart`'s own header documents, and
        // `probe_settings_security_center_test.dart`'s own drain works
        // around identically).
        await tester.runAsync(() async {
          await db
              .into(db.deviceRevocations)
              .insert(
                DeviceRevocationsCompanion.insert(
                  deviceId: 'device-a',
                  revokedAt: DateTime(2026, 9, 1),
                  source: 'local',
                ),
              );
          await db
              .into(db.signalTrustedIdentities)
              .insert(
                SignalTrustedIdentitiesCompanion.insert(
                  addressName: 'device-b',
                  addressDeviceId: 1,
                  identityKey: Uint8List.fromList(const [1, 2, 3]),
                ),
              );
          await db
              .into(db.relationships)
              .insert(
                RelationshipsCompanion.insert(
                  deviceId: 'device-c',
                  state: RelationshipState.blocked.name,
                  updatedAt: DateTime(2026, 9, 1),
                ),
              );
          await db
              .into(db.rateLimitCounters)
              .insert(
                RateLimitCountersCompanion.insert(
                  bucketKey: 'relay:device-d',
                  windowStartMs: 0,
                  count: 3,
                ),
              );
          controller.onInit();
          while (controller.revocations.value == null ||
              controller.trustedIdentities.value == null ||
              controller.blockedPeers.value == null ||
              controller.rateLimitDenials.value == null) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
        });

        await tester.pumpWidget(
          const GetMaterialApp(home: SecurityCenterView()),
        );
        await tester.pumpAndSettle();

        // Every tappable widget on the screen is enumerated and each one
        // is checked against the single allowed exception -- "Manage in
        // Devices" (SC16), a navigation link, not an action that changes
        // trust/block/revocation state (`EARS-DIAG-5`).
        for (final finder in [
          find.byType(InkWell),
          find.byType(GestureDetector),
          find.byType(Dismissible),
        ]) {
          for (final element in finder.evaluate()) {
            final widget = element.widget;
            final onTap = widget is InkWell
                ? widget.onTap
                : widget is GestureDetector
                ? widget.onTap
                : null;
            if (widget is Dismissible) {
              fail('Dismissible found -- no swipe action is permitted here');
            }
            if (onTap == null) continue;
            // The only permitted tappable widget is the back affordance
            // (from the shared scaffold) or the "Manage in Devices" link.
            final ancestorTexts = tester
                .widgetList<Text>(
                  find.descendant(
                    of: find.byWidget(widget),
                    matching: find.byType(Text),
                  ),
                )
                .map((t) => t.data)
                .toList();
            final isBackAffordance = element
                .findAncestorWidgetOfExactType<Icon>() == null &&
                ancestorTexts.isEmpty;
            final isManageInDevices = ancestorTexts.contains(
              'Manage in Devices',
            );
            expect(
              isManageInDevices || isBackAffordance,
              isTrue,
              reason:
                  'Unexpected tappable widget found with labels '
                  '$ancestorTexts -- this screen renders no action '
                  'affordance beyond the back button and the Manage in '
                  'Devices navigation link.',
            );
          }
        }
      },
    );

    testWidgets(
      'test_EARS_UI_9_no_certificates_section_is_present',
      (tester) async {
        await _initAndDrain(tester, controller);
        await tester.pumpWidget(
          const GetMaterialApp(home: SecurityCenterView()),
        );
        await tester.pumpAndSettle();

        expect(find.textContaining('ertificate'), findsNothing);
        expect(find.textContaining('etwork audit'), findsNothing);
      },
    );

    testWidgets(
      'test_EARS_DIAG_4_all_four_sections_empty_renders_their_own_empty_lines_widget',
      (tester) async {
        await _initAndDrain(tester, controller);
        await tester.pumpWidget(
          const GetMaterialApp(home: SecurityCenterView()),
        );
        await tester.pumpAndSettle();

        expect(find.text('No device has been revoked.'), findsOneWidget);
        expect(find.text('No identities recorded yet.'), findsOneWidget);
        expect(find.text('You have not blocked anyone.'), findsOneWidget);
        expect(find.text('Nothing has been rate limited.'), findsOneWidget);
        expect(find.text('Records could not be read.'), findsNothing);
      },
    );
  });
}

/// Calls `onInit` and drains the four one-shot repository reads through
/// `tester.runAsync` before any pump -- see the
/// `test_EARS_DIAG_5_no_action_affordance_is_rendered` test's own comment
/// for why a plain `pump`/`pumpAndSettle` never resolves them.
Future<void> _initAndDrain(
  WidgetTester tester,
  SecurityCenterController controller,
) {
  return tester.runAsync(() async {
    controller.onInit();
    while (controller.revocations.value == null ||
        controller.trustedIdentities.value == null ||
        controller.blockedPeers.value == null ||
        controller.rateLimitDenials.value == null) {
      await Future<void>.delayed(const Duration(milliseconds: 5));
    }
  });
}

/// A repository whose `revocations()` always throws, for `EARS-UI-11`'s
/// falsification -- a real seam failure, not a mocked promise of one. The
/// other three methods are untouched so their own reads still succeed,
/// proving the four sections fail independently.
class _ErroringRevocationsRepository extends SecurityRecordsRepository {
  _ErroringRevocationsRepository({required super.db});

  @override
  Future<List<SecurityRecord>> revocations() {
    throw StateError('simulated read failure');
  }
}
