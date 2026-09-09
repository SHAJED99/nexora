// features/settings/privacy/presentation --
// PrivacySettingsController (E15-T05).
//
// Real in-memory `AppDatabase` + the real `LocationSettingsRepository` /
// `NotificationSettingsRepository` throughout -- these tests prove the
// controller's *binding* to both repositories, not a mock's promise that it
// would. `_CountingLocationRepository` / `_ErroringPeerReadRepository` below
// are the seams the task's own risk list calls for: a call counter and a
// read that fails -- never `fail()` inside an injected seam (a broad catch
// in the SUT would swallow it, L-testing).
import 'dart:async';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/core/notifications/notification_settings_repository.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/persistence/notification_tables.dart'
    show NotificationPrivacyLevel;
import 'package:nexora/features/location/data/location_settings_repository.dart';
import 'package:nexora/features/settings/privacy/presentation/privacy_settings_controller.dart';
import 'package:nexora/features/settings/privacy/presentation/privacy_settings_view.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late LocationSettingsRepository locationRepository;
  late NotificationSettingsRepository notificationRepository;
  late PrivacySettingsController controller;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    locationRepository = LocationSettingsRepository(db: db);
    notificationRepository = NotificationSettingsRepository(db: db);
    controller = PrivacySettingsController(
      locationRepository: locationRepository,
      notificationRepository: notificationRepository,
    );
  });

  tearDown(() async {
    controller.onClose();
    await db.close();
  });

  test(
    'test_EARS_SEC_4_global_switch_persists_through_the_repository',
    () async {
      controller.onInit();
      await pumpEventQueue();
      expect(controller.globalLocationEnabled.value, isFalse);

      await controller.setGlobalLocation(true);
      await pumpEventQueue();

      expect(controller.globalLocationEnabled.value, isTrue);
      expect(await locationRepository.readGlobalEnabled(), isTrue);
    },
  );

  test(
    'test_EARS_SEC_4_global_set_before_first_emission_performs_no_write',
    () async {
      // Falsifies the same re-derived-default shape T04's F1 finding
      // fixed: calling `setGlobalLocation` before `watchGlobalEnabled()`'s
      // first emission has landed must not write, because the controller
      // does not yet know the real stored value and this screen holds no
      // defaulting rule of its own (task §2).
      final countingRepository = _CountingLocationRepository(db: db);
      final countingController = PrivacySettingsController(
        locationRepository: countingRepository,
        notificationRepository: notificationRepository,
      );
      countingController.onInit();

      expect(countingController.globalLocationEnabled.value, isNull);

      await countingController.setGlobalLocation(true);

      expect(countingRepository.writeGlobalEnabledCalls, 0);

      countingController.onClose();
    },
  );

  test(
    'test_EARS_SEC_4_peer_set_before_first_load_performs_no_write',
    () async {
      // Same guard, the per-peer side: `readAllPeerEnabled()` is a
      // one-shot Future, not a stream, so the "unknown state never writes"
      // window is the gap between `onInit` and that Future's completion.
      final countingRepository = _CountingLocationRepository(db: db);
      final countingController = PrivacySettingsController(
        locationRepository: countingRepository,
        notificationRepository: notificationRepository,
      );
      countingController.onInit();

      expect(countingController.peerLocationEnabled.value, isNull);

      await countingController.setPeerLocation('peer-1', true);

      expect(countingRepository.writePeerEnabledCalls, 0);

      countingController.onClose();
    },
  );

  test(
    'test_EARS_SEC_4_global_off_overrides_peer_on',
    () async {
      // FR-LOC-003's AND: a peer with location on, global off. The screen
      // must state unavailability rather than implying the peer's own "on"
      // is honoured -- this test asserts the two independent facts the
      // view's PV17 copy depends on: the global switch really is off, and
      // that peer really is on, at the same time.
      await locationRepository.writeGlobalEnabled(false);
      await locationRepository.writePeerEnabled('peer-1', true);

      controller.onInit();
      await pumpEventQueue();

      expect(controller.globalLocationEnabled.value, isFalse);
      expect(controller.peerLocationEnabled.value, {'peer-1': true});
    },
  );

  test(
    'test_EARS_SEC_4_peer_write_re_reads_the_whole_map_not_a_local_copy',
    () async {
      // Task §6 risk note: "readAllPeerEnabled() returns a map, not a
      // stream. Re-read after any per-peer write; do not maintain a
      // parallel local map." Falsified by writing a SECOND peer directly
      // through the repository (never through the controller) in between
      // two controller-driven writes -- if the controller maintained a
      // local map instead of re-reading, it would never see peer-2.
      controller.onInit();
      await pumpEventQueue();
      expect(controller.peerLocationEnabled.value, isEmpty);

      await controller.setPeerLocation('peer-1', true);
      await pumpEventQueue();
      expect(controller.peerLocationEnabled.value, {'peer-1': true});

      // Written directly through the repository, bypassing the controller.
      await locationRepository.writePeerEnabled('peer-2', true);

      await controller.setPeerLocation('peer-1', false);
      await pumpEventQueue();

      expect(
        controller.peerLocationEnabled.value,
        {'peer-1': false, 'peer-2': true},
      );
    },
  );

  testWidgets('test_EARS_SEC_5_privacy_level_is_read_only', (tester) async {
    // Review round 2, F2: the label-equality assertion this test used to
    // make (`notificationPrivacyLabel.value == 'Sender only'`) is real but
    // insufficient -- the task's own §8 test plan specifies a CALL COUNTER
    // on `setPrivacyLevel`, `expect(calls, 0)`, after interacting with
    // PV11/PV12. That is the assertion that actually falsifies a write
    // path; a label match alone would pass even if the view secretly wrote
    // through to the repository on every tap.
    final countingRepository = _CountingNotificationRepository(db: db);
    await countingRepository.setPrivacyLevel(
      NotificationPrivacyLevel.senderOnly,
    );
    countingRepository.setPrivacyLevelCalls = 0; // reset after the seed write above

    Get.testMode = true;
    final countingController = PrivacySettingsController(
      locationRepository: locationRepository,
      notificationRepository: countingRepository,
    );
    Get.put<PrivacySettingsController>(countingController);
    // No `pumpEventQueue()` here -- inside a `testWidgets` body the test
    // runs in a fake-async zone, where `pumpEventQueue`'s
    // `Future.delayed(Duration.zero)` chain does not reliably resolve on
    // its own (unlike inside a plain `test()`, where the other tests in
    // this file use it successfully). `pumpWidget` + the bounded
    // `pumpAndSettle` below give the controller's `onInit` futures the
    // real pump cycles they need instead.

    await tester.pumpWidget(
      GetMaterialApp(
        initialRoute: '/settings/privacy',
        getPages: [
          GetPage(
            name: '/settings/privacy',
            page: () => const PrivacySettingsView(),
            // `noTransition` -- this test only needs the tap to land and
            // the counter to stay at 0, not a settled page-transition
            // animation. A real transition's `AnimationController` can
            // leave a Timer pending past the widget tree's disposal at
            // test end ("A Timer is still pending"), which is an artifact
            // of testing navigation this way, not something EARS-SEC-5
            // makes a claim about.
            transition: Transition.noTransition,
          ),
          GetPage(
            name: '/settings/notifications',
            page: () => const Text('NOTIFICATIONS'),
            transition: Transition.noTransition,
          ),
        ],
      ),
    );
    // Bounded settle -- `flutter_probe_dumper.dart`'s own documented
    // gotcha (docs/design-gate-flutter.md §6): this screen can leave the
    // tree never settling under a plain unbounded `pumpAndSettle()`, which
    // hangs the whole suite rather than failing. Same bound the probe
    // dumper uses.
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );

    expect(find.text('Sender only'), findsOneWidget);

    // PV11's own text row -- reading it must not write.
    await tester.tap(find.text('Sender only'));
    await tester.pump();

    // PV12's link row -- navigating away must not write either.
    await tester.tap(find.text('Change in Notifications'));
    // Bounded settle -- `flutter_probe_dumper.dart`'s own documented
    // gotcha (docs/design-gate-flutter.md §6): this screen can leave the
    // tree never settling under a plain unbounded `pumpAndSettle()`, which
    // hangs the whole suite rather than failing. Same bound the probe
    // dumper uses.
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 5),
    );

    expect(
      countingRepository.setPrivacyLevelCalls,
      0,
      reason: 'EARS-SEC-5: this screen must never call setPrivacyLevel, '
          'from any row',
    );

    countingController.onClose();
    // `onClose` cancels the global-location stream subscription, and
    // drift's own `QueryStream._onCancelOrPause` schedules a zero-duration
    // cleanup Timer (`StreamQueryStore.markAsClosed`) as a result -- one
    // more pump lets it fire before the test ends, or
    // `AutomatedTestWidgetsFlutterBinding._verifyInvariants` fails with "A
    // Timer is still pending" (a drift-internal artifact, nothing to do
    // with this test's own claim).
    await tester.pumpAndSettle(
      const Duration(milliseconds: 100),
      EnginePhase.sendSemanticsUpdate,
      const Duration(seconds: 2),
    );
    Get.reset();
  });

  testWidgets(
    'test_EARS_UI_9_rendered_text_is_exactly_the_contract_allowlist',
    (tester) async {
      // Review round 3, F3: a DENYLIST of forbidden words is falsifiable
      // by any control that uses different, equally natural vocabulary --
      // the round-2 reviewer proved this by building a fully working
      // "App passcode" toggle plus a "Camera access" permissions list and
      // watching the old denylist test (and the whole 10/10 suite) stay
      // green, because neither string matched
      // `lock|pin|biometric|permission|fingerprint|face id|touch id`.
      //
      // An ALLOWLIST closes that hole structurally: it does not care what
      // a hypothetical control is *called* -- only whether its rendered
      // text is IN the closed set this screen's own design contract
      // specifies (`design/screens/settings-privacy.md` §Copy). Read from
      // the contract file itself, not retyped by hand, so a future
      // contract edit and this test cannot silently drift apart. Anything
      // rendered that is NOT in that set -- any vocabulary, any wording --
      // fails, which is the whole point: this is now a closed-set
      // membership check, not a keyword scan.
      //
      // The check below is `renderedTexts` ⊆ `allowedTexts` (an EXTRA
      // string fails), not full two-way set equality: the contract's
      // closed set spans every state this screen can be in (`default`,
      // `loading`, `empty`, `error`, and PV11's three possible labels),
      // while a single pumped render only ever shows one state's subset
      // of it. Requiring every contract string to appear in one render
      // would make this test fail for reasons that have nothing to do
      // with EARS-UI-9 (e.g. PV21's error copy never appearing outside a
      // read failure). Subset-of-the-closed-set is the property that
      // actually falsifies the reviewer's evasion, and does so
      // regardless of which state is rendered.
      Get.testMode = true;
      final controller = PrivacySettingsController(
        locationRepository: locationRepository,
        notificationRepository: notificationRepository,
      );
      Get.put<PrivacySettingsController>(controller);
      // No `pumpEventQueue()` here -- see the F2 test above for why (a
      // fake-async zone, unlike this file's plain `test()` bodies).

      await tester.pumpWidget(
        const GetMaterialApp(home: PrivacySettingsView()),
      );
      // Bounded settle -- `flutter_probe_dumper.dart`'s own documented
      // gotcha (docs/design-gate-flutter.md §6): this screen can leave the
      // tree never settling under a plain unbounded `pumpAndSettle()`,
      // which hangs the whole suite rather than failing. Same bound the
      // probe dumper uses.
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );

      // Review round 3, F4 (item 3): a positive render assertion, the
      // same shape `test_EARS_SEC_5_privacy_level_is_read_only` already
      // makes with `find.text('Sender only')` -- if the widget tree ever
      // fails to build, THIS fails loudly instead of the allowlist check
      // below passing vacuously over an empty tree.
      expect(find.text('Privacy & Security'), findsOneWidget);

      final contractFile = File('design/screens/settings-privacy.md');
      final contractSource = contractFile.readAsStringSync();
      final copySection = contractSource
          .split('## Copy — verbatim')[1]
          .split('\n## ')[0];
      final backtickPattern = RegExp('`([^`]+)`');
      final allowedTexts = <String>{
        for (final line in copySection.split('\n'))
          if (line.trim().startsWith('-'))
            for (final match in backtickPattern.allMatches(line))
              match.group(1)!,
        // PV11's dynamic value is enumerated in the contract's Elements
        // table, not the Copy section (it is not a single static
        // string): "current level, one of `Hidden` / `Sender only` /
        // `Full`". All three are this row's own closed set.
        'Hidden',
        'Sender only',
        'Full',
      };

      final renderedTexts = <String>{};
      for (final widget in tester.widgetList<Text>(find.byType(Text))) {
        final data =
            (widget.data ?? widget.textSpan?.toPlainText() ?? '').trim();
        if (data.isNotEmpty) renderedTexts.add(data);
      }
      for (final widget
          in tester.widgetList<Semantics>(find.byType(Semantics))) {
        final label = (widget.properties.label ?? '').trim();
        if (label.isNotEmpty) renderedTexts.add(label);
      }

      final notAllowed = renderedTexts.difference(allowedTexts);
      expect(
        notAllowed,
        isEmpty,
        reason: 'EARS-UI-9: rendered text outside settings-privacy.md\'s '
            'closed §Copy set -- a hypothetical app-lock/permissions '
            'control using unlisted vocabulary (e.g. "App passcode", '
            '"Camera access") would be caught here regardless of '
            'wording: $notAllowed',
      );

      controller.onClose();
      // Same drift-internal cleanup Timer as the F2 test above -- a
      // bounded settle (not a single `pump()`) lets it actually fire
      // before the test ends.
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 2),
      );
      Get.reset();
    },
  );

  testWidgets(
    'test_EARS_UI_9_the_absence_statement_actually_renders',
    (tester) async {
      // GAP-040 (human, 2026-09-09): EARS-UI-9 has TWO clauses -- (a) SHALL
      // NOT present a control (the allowlist test above), and (b) SHALL
      // STATE the absence. This proves clause (b): PV22 actually renders,
      // not merely that the contract/task file claims it does.
      Get.testMode = true;
      final controller = PrivacySettingsController(
        locationRepository: locationRepository,
        notificationRepository: notificationRepository,
      );
      Get.put<PrivacySettingsController>(controller);

      await tester.pumpWidget(
        const GetMaterialApp(home: PrivacySettingsView()),
      );
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 5),
      );

      expect(
        find.text(
          'App lock and a permissions manager are not available in this '
          'version.',
        ),
        findsOneWidget,
      );

      controller.onClose();
      await tester.pumpAndSettle(
        const Duration(milliseconds: 100),
        EnginePhase.sendSemanticsUpdate,
        const Duration(seconds: 2),
      );
      Get.reset();
    },
  );

  test(
    'test_EARS_UI_9_no_app_lock_or_permissions_identifier_in_source',
    () {
      // The companion structural half: even if no row is ever rendered
      // today, neither the controller NOR the view CLASS may carry the
      // surface. Review round 2's F4 found this only ever scanned the
      // controller -- a control living entirely in
      // `privacy_settings_view.dart` (a `bool` field on a
      // `StatefulWidget`'s state, say) was invisible to it. Both source
      // files are scanned the same way now. This is a reasonable
      // SECONDARY check on identifier shape; the PRIMARY defence against
      // vocabulary evasion is the rendered-text allowlist above, which
      // does not care about wording at all. Mirrors
      // `group_key_rotation_service_test.dart`'s own "no CODE line names
      // a forbidden identifier" source check (comments excluded; this
      // very file's header prose and both files' own doc comments
      // necessarily discuss "lock"/"PIN" at length while explaining why
      // neither exists).
      final forbidden = RegExp(
        r'[Ll]ock|[Bb]iometric|[Pp]ermission|[Pp]in(?=[A-Z_]|$)|PIN',
      );
      for (final path in [
        'lib/features/settings/privacy/presentation/privacy_settings_controller.dart',
        'lib/features/settings/privacy/presentation/privacy_settings_view.dart',
      ]) {
        final source = File(path).readAsStringSync();
        final codeOnly = source
            .split('\n')
            .where(
              (line) =>
                  !line.trim().startsWith('//') &&
                  // GAP-040's PV22 disclosure string literal necessarily
                  // NAMES "app lock" and "permissions manager" in prose --
                  // that is the whole point of the line (EARS-UI-9's
                  // "SHALL state the absence" clause). This scan's job is
                  // to catch a FIELD or METHOD implementing either
                  // capability, not a sentence disclosing that neither
                  // exists, so this one known literal is excluded the
                  // same way a comment line already is.
                  !line.contains('not available in this'),
            )
            .join('\n');
        expect(
          forbidden.hasMatch(codeOnly),
          isFalse,
          reason: 'no app-lock/PIN/biometric/permissions field or method '
              'may exist in $path (task §4, GAP-033, OQ-E15-T05-1)',
        );
      }
    },
  );

  test(
    'test_EARS_UI_11_peer_read_failure_leaves_the_global_switch_intact',
    () async {
      await locationRepository.writeGlobalEnabled(true);
      final erroringRepository = _ErroringPeerReadRepository(db: db);
      final erroringController = PrivacySettingsController(
        locationRepository: erroringRepository,
        notificationRepository: notificationRepository,
      );

      erroringController.onInit();
      await pumpEventQueue();

      expect(erroringController.peerLocationError.value, isTrue);
      expect(erroringController.globalLocationError.value, isFalse);
      expect(erroringController.globalLocationEnabled.value, isTrue);

      erroringController.onClose();
    },
  );

  test(
    'test_EARS_UI_11_global_read_failure_leaves_notification_privacy_intact',
    () async {
      await notificationRepository.setPrivacyLevel(
        NotificationPrivacyLevel.full,
      );
      final erroringRepository = _ErroringGlobalWatchRepository(db: db);
      final erroringController = PrivacySettingsController(
        locationRepository: erroringRepository,
        notificationRepository: notificationRepository,
      );

      erroringController.onInit();
      await pumpEventQueue();

      expect(erroringController.globalLocationError.value, isTrue);
      expect(erroringController.globalLocationEnabled.value, isNull);
      expect(erroringController.notificationPrivacyError.value, isFalse);
      expect(erroringController.notificationPrivacyLabel.value, 'Full');

      erroringController.onClose();
    },
  );
}

/// Counts `writeGlobalEnabled`/`writePeerEnabled` calls -- the call-counter
/// seam the loading-window falsifications need, instead of `fail()` inside
/// the seam (a broad catch in the controller would swallow it, L-testing).
class _CountingLocationRepository extends LocationSettingsRepository {
  _CountingLocationRepository({required super.db});

  int writeGlobalEnabledCalls = 0;
  int writePeerEnabledCalls = 0;

  @override
  Future<void> writeGlobalEnabled(bool enabled) async {
    writeGlobalEnabledCalls++;
    await super.writeGlobalEnabled(enabled);
  }

  @override
  Future<void> writePeerEnabled(String peerDeviceId, bool enabled) async {
    writePeerEnabledCalls++;
    await super.writePeerEnabled(peerDeviceId, enabled);
  }
}

/// A repository whose `readAllPeerEnabled` always throws, for
/// `EARS-UI-11`'s falsification -- a real seam failure, not a mocked
/// promise of one. `watchGlobalEnabled` is untouched so the global switch's
/// own read still succeeds, proving the two sections fail independently.
class _ErroringPeerReadRepository extends LocationSettingsRepository {
  _ErroringPeerReadRepository({required super.db});

  @override
  Future<Map<String, bool>> readAllPeerEnabled() {
    throw StateError('simulated read failure');
  }
}

/// A repository whose `watchGlobalEnabled` always errors, for the
/// symmetric `EARS-UI-11` falsification -- the global switch's own read
/// fails while the notification-privacy card's independent read (a
/// different repository entirely) still succeeds.
class _ErroringGlobalWatchRepository extends LocationSettingsRepository {
  _ErroringGlobalWatchRepository({required super.db});

  @override
  Stream<bool> watchGlobalEnabled() {
    return Stream<bool>.error(StateError('simulated read failure'));
  }
}

/// Counts `setPrivacyLevel` calls -- review round 2, F2's contracted
/// call-counter seam (task §8: "a CALL COUNTER on `setPrivacyLevel`,
/// `expect(calls, 0)`"), the same shape
/// `notification_settings_controller_test.dart`'s own `_CountingRepository`
/// uses for `EARS-NOTIFY-17`. A call counter, never `fail()` inside the
/// seam (a broad catch in the SUT would swallow it, L-testing).
class _CountingNotificationRepository extends NotificationSettingsRepository {
  _CountingNotificationRepository({required super.db});

  int setPrivacyLevelCalls = 0;

  @override
  Future<void> setPrivacyLevel(NotificationPrivacyLevel level) async {
    setPrivacyLevelCalls++;
    await super.setPrivacyLevel(level);
  }
}
