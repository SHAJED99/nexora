// features/settings/about/presentation -- AboutSettingsController
// (E15-T10). Real in-memory `AppDatabase` + the real
// `VersionPolicyService`/`EvaluateVersionStateUseCase` throughout for the
// "This build"/"Version policy" cards -- these tests prove the
// controller's own binding and its own failure isolation, not a mock's
// promise of either. `version`/`buildNumber`/`logEntries` are read through
// this controller's own injectable seams (task §5) rather than the real
// `package_info_plus` platform channel, which is unavailable in a plain
// `flutter test` run and would make every assertion depend on whatever
// happens to be installed on the machine running the suite -- exactly the
// non-reproducibility this task's own briefing warned against for the
// design-probe golden, and just as true for a plain unit test.
import 'dart:io';

import 'package:drift/drift.dart' hide isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Value;
import 'package:nexora/core/observability/observability_service.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/services/version_policy_service.dart';
import 'package:nexora/features/settings/about/presentation/about_settings_controller.dart';
import 'package:nexora/features/settings/about/presentation/about_settings_view.dart';
import 'package:nexora/features/settings/presentation/widgets/settings_sub_screen_scaffold.dart'
    show SettingsSectionCard;
import 'package:nexora/features/version/domain/version_state.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late VersionPolicyService policyService;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    policyService = VersionPolicyService(database: db);
  });

  tearDown(() => db.close());

  Future<void> seedPolicy({
    required int minimumSupportedBuild,
    required int updateAvailableBuild,
    int updatedAt = 1700000000000,
  }) => db
      .into(db.versionPolicyCache)
      .insertOnConflictUpdate(
        VersionPolicyCacheCompanion.insert(
          id: const Value(1),
          minimumSupportedBuild: minimumSupportedBuild,
          currentBuild: 1000,
          updateAvailableBuild: updateAvailableBuild,
          signature: 'sig',
          updatedAt: updatedAt,
        ),
      );

  group('AboutSettingsController', () {
    test(
      'test_EARS_VER_18_version_build_and_state_are_rendered',
      () async {
        await seedPolicy(minimumSupportedBuild: 100, updateAvailableBuild: 200);
        final controller = AboutSettingsController(
          versionPolicyService: policyService,
          versionProvider: () async => '9.9.9',
          buildNumberProvider: () async => 999,
        );

        controller.onInit();
        await pumpEventQueue();

        expect(controller.buildInfoError.value, isFalse);
        expect(controller.version.value, '9.9.9');
        expect(controller.buildNumber.value, 999);
        expect(controller.versionState.value, VersionState.upToDate);
        expect(controller.policyLoaded.value, isTrue);
        expect(controller.cachedPolicy.value?.minimumSupportedBuild, 100);
      },
    );

    // `test_EARS_VER_18_null_build_number_renders_the_failure_line_not_zero`
    // and `test_EARS_VER_18_absent_policy_renders_the_fail_open_statement`
    // moved to the `AboutSettingsView` group below (F3/F4, review round 1):
    // asserting only controller state proved nothing about what the
    // screen actually renders -- the reviewer showed both AB18's `'0'`
    // and AB13's mutated copy could ship undetected. They now pump the
    // real view and assert on `find.text(...)`.

    test(
      'test_EARS_UI_11_policy_read_failure_leaves_the_build_card_rendered',
      () async {
        final erroringPolicyService = _ThrowingCachedPolicyService(
          database: db,
        );
        final controller = AboutSettingsController(
          versionPolicyService: erroringPolicyService,
          versionProvider: () async => '9.9.9',
          buildNumberProvider: () async => 999,
        );

        controller.onInit();
        await pumpEventQueue();

        // Version/Build come from `package_info_plus`, not the policy
        // read -- they must still resolve.
        expect(controller.buildInfoError.value, isFalse);
        expect(controller.version.value, '9.9.9');
        expect(controller.buildNumber.value, 999);
        // Status depends on the SAME failed policy read and is left
        // unresolved -- never a fabricated state.
        expect(controller.versionState.value, isNull);
        // The Version Policy card's own failure is reported independently.
        expect(controller.policyError.value, isTrue);
        expect(controller.policyLoaded.value, isTrue);
      },
    );

    test(
      'test_EARS_VER_19_diagnostic_entry_model_has_no_cause_field',
      () {
        // A structural assertion on `DiagnosticEntry` (task §8), the same
        // idiomatic pattern `SecurityRecord`'s own equivalent test already
        // uses (`security_records_repository_test.dart`,
        // `test_EARS_DIAG_4_record_model_has_no_key_field`) -- reflection
        // is unavailable in Flutter, so this reads the class's own source
        // and asserts, at the text level, that no field capable of
        // holding a cause/stack trace is declared anywhere in the class
        // body. A construction-only check only proves the two fields that
        // *are* named behave as expected; it says nothing about whether a
        // third, unexercised field exists.
        final source = File(
          'lib/features/settings/about/presentation/about_settings_controller.dart',
        ).readAsStringSync();
        final classBody = _extractClassBody(source, 'DiagnosticEntry');

        // F2 (review round 1): a denylist over banned tokens fails on an
        // innocuous doc comment and passes straight through an undetected
        // field named e.g. `detail`/`payload`/`message`/`trace`/`context`/
        // `extra` (the reviewer proved this by adding
        // `final String? detail = null;` -- the old denylist test still
        // passed). Invert it: strip comments, then count the class's own
        // `final`-declared instance fields and assert the set is EXACTLY
        // `{code, timestamp}` -- no more, no fewer, whatever they're named.
        final withoutComments = classBody
            .replaceAll(RegExp(r'///[^\n]*'), '')
            .replaceAll(RegExp(r'//[^\n]*'), '');
        final fieldPattern = RegExp(
          r'final\s+[\w<>,\?\s]+?\s+(\w+)\s*(?:=[^;]+)?;',
        );
        final declaredFields = fieldPattern
            .allMatches(withoutComments)
            .map((m) => m.group(1)!)
            .toList();
        expect(
          declaredFields.toSet(),
          {'code', 'timestamp'},
          reason:
              '`DiagnosticEntry` must declare EXACTLY the field set '
              '{code, timestamp} -- found: $declaredFields\n$classBody',
        );
        expect(
          declaredFields.length,
          2,
          reason:
              '`DiagnosticEntry` must declare exactly two `final` fields '
              '-- found ${declaredFields.length}: $declaredFields\n$classBody',
        );

        final entry = DiagnosticEntry(code: 'x', timestamp: DateTime(2026));
        expect(entry.code, 'x');
        expect(entry.timestamp, DateTime(2026));
      },
    );
  });

  group('AboutSettingsView', () {
    setUp(() => Get.testMode = true);
    tearDown(() => Get.reset());

    testWidgets(
      'test_EARS_VER_19_log_entry_never_renders_a_cause_or_stack_trace',
      (tester) async {
        const suspiciousCause = 'RECOGNISABLE_CAUSE_MARKER_7f3a';
        final controller = AboutSettingsController(
          versionPolicyService: policyService,
          versionProvider: () async => '9.9.9',
          buildNumberProvider: () async => 999,
          logEntriesProvider: () async => [
            DiagnosticEntry(
              code: 'version.installed_build_read_failed',
              timestamp: DateTime.utc(2026, 1, 1),
            ),
          ],
        );
        Get.put<AboutSettingsController>(controller);

        await tester.runAsync(() async {
          while (controller.version.value == null ||
              controller.policyLoaded.value == false ||
              controller.logEntries.isEmpty) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
        });

        await tester.pumpWidget(
          const GetMaterialApp(home: AboutSettingsView()),
        );
        await tester.pumpAndSettle();

        // Sanity check: the seeded entry's own (safe) code IS rendered --
        // otherwise this test would trivially pass by rendering nothing.
        expect(
          find.text('version.installed_build_read_failed'),
          findsOneWidget,
        );

        // F1 (review round 1): the POSITIVE invariant. A denylist over one
        // marker string can only ever pass if that specific string never
        // gets rendered -- it says nothing about a DIFFERENT extra line
        // (e.g. a real stack trace) added anywhere under this card. The
        // reviewer proved exactly this: adding
        // `const SettingsBodyLine('StateError #0 main (file:///secret.dart:42)')`
        // under every diagnostics row left the old denylist-only test
        // green. Instead: assert every `Text` rendered under the
        // Diagnostics card (the third `SettingsSectionCard`, in this
        // screen's own fixed card order) is EXACTLY the card's own
        // heading, or one seeded entry's own `code`/`timestamp` -- an
        // allowlist over the whole card, not a denylist for one string.
        final diagnosticsCard = find.byType(SettingsSectionCard).at(2);
        const seededEntryCode = 'version.installed_build_read_failed';
        final seededEntryTimestamp = DateTime.utc(
          2026,
          1,
          1,
        ).toIso8601String();
        final allowedDiagnosticsText = <String>{
          'Diagnostics',
          seededEntryCode,
          seededEntryTimestamp,
        };
        final diagnosticsTexts = tester
            .widgetList<Text>(
              find.descendant(of: diagnosticsCard, matching: find.byType(Text)),
            )
            .map((t) => t.data ?? '')
            .toList();
        expect(diagnosticsTexts, isNotEmpty);
        for (final text in diagnosticsTexts) {
          expect(
            allowedDiagnosticsText.contains(text),
            isTrue,
            reason:
                'Unexpected text rendered under the Diagnostics card: '
                '"$text" (allowlist: $allowedDiagnosticsText). Falsify this '
                'by adding an extra line under a log row and confirming '
                'this assertion fails.',
          );
        }

        // The real production call site this screen's own controller
        // uses (`_readInstalledVersion`'s catch block) reports failures
        // through the app's real `ObservabilityService.instance.logError`
        // -- prove that even when a real error carrying this exact,
        // recognisable cause travels through that REAL call site, nothing
        // about it reaches this screen's rendered tree. `logEntries` has
        // no code path connecting `ObservabilityService`'s send side to
        // this screen's read side (see this controller's own header
        // comment, OQ-E15-T10-2) -- there is structurally nothing for a
        // future edit to leak through here without changing this file.
        final recordingClient = _RecordingClient();
        final restore = ObservabilityService.debugOverrideInstanceClientForTesting(
          recordingClient,
        );
        ObservabilityService.instance.logError(
          'version.installed_version_read_failed',
          cause: suspiciousCause,
        );
        restore();
        expect(recordingClient.captured.single.$3, suspiciousCause);

        await tester.pump();

        final allTexts = tester
            .widgetList<Text>(find.byType(Text))
            .map((t) => t.data ?? '')
            .toList();
        expect(allTexts, isNotEmpty);
        for (final text in allTexts) {
          expect(
            text.contains(suspiciousCause),
            isFalse,
            reason:
                'A rendered Text widget carries the cause marker: "$text"',
          );
        }
      },
    );

    testWidgets(
      'test_EARS_UI_9_no_release_notes_and_no_update_button_are_present',
      (tester) async {
        final controller = AboutSettingsController(
          versionPolicyService: policyService,
          versionProvider: () async => '9.9.9',
          buildNumberProvider: () async => 999,
          // A seeded entry, not an empty log (F5, review round 1): an
          // empty diagnostics list never builds a `_LogEntryRow` at all,
          // so the interactive-control scoping check below would exercise
          // nothing if the log stayed empty here.
          logEntriesProvider: () async => [
            DiagnosticEntry(
              code: 'version.installed_build_read_failed',
              timestamp: DateTime.utc(2026, 1, 1),
            ),
          ],
        );
        Get.put<AboutSettingsController>(controller);

        await tester.runAsync(() async {
          while (controller.version.value == null ||
              controller.policyLoaded.value == false ||
              controller.logEntries.isEmpty) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
        });

        await tester.pumpWidget(
          const GetMaterialApp(home: AboutSettingsView()),
        );
        await tester.pumpAndSettle();

        // No release notes, no Play Store link, no "check for updates" or
        // update-action affordance of any kind (task §4).
        expect(find.textContaining('release notes'), findsNothing);
        expect(find.textContaining('Check for updates'), findsNothing);
        expect(find.textContaining('Update now'), findsNothing);
        // No button widget of any kind anywhere on this screen -- the
        // back affordance (inherited from the shared scaffold) is a
        // plain `InkWell`, not a button.
        expect(find.byType(ElevatedButton), findsNothing);
        expect(find.byType(TextButton), findsNothing);
        expect(find.byType(OutlinedButton), findsNothing);
        expect(find.byType(IconButton), findsNothing);

        // F5 (review round 1): checking only for Material BUTTON types
        // let a tap-to-expand affordance through undetected -- the
        // reviewer proved this by wrapping a log row in
        // `InkWell(onTap: () {})` (exactly the "expand an entry into its
        // cause" control task §4 prohibits); all four assertions above
        // still passed. Widen it to any gesture-catching widget
        // (`InkWell`/`GestureDetector`/`Listener`), but scope the search
        // to below this screen's own three content cards -- excluding the
        // shared shell's own legitimate back-affordance `InkWell`
        // (`_BackRow`, `settings_sub_screen_scaffold.dart`), which this
        // task did not build and must not flag.
        final interactiveInsideCards = find.descendant(
          of: find.byType(SettingsSectionCard),
          matching: find.byWidgetPredicate(
            (w) => w is InkWell || w is GestureDetector || w is Listener,
          ),
        );
        expect(
          interactiveInsideCards,
          findsNothing,
          reason:
              'A gesture-catching widget (InkWell/GestureDetector/Listener) '
              'was found inside one of this screen\'s own content cards -- '
              'this screen has no control of any kind. Falsify this by '
              'wrapping a log row in `InkWell(onTap: () {})` and confirming '
              'this assertion fails.',
        );
      },
    );

    testWidgets(
      'test_EARS_VER_18_null_build_number_renders_the_failure_line_not_zero',
      (tester) async {
        final controller = AboutSettingsController(
          versionPolicyService: policyService,
          versionProvider: () async => '9.9.9',
          buildNumberProvider: () async => null,
        );
        Get.put<AboutSettingsController>(controller);

        await tester.runAsync(() async {
          while (controller.buildInfoError.value == false) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          while (controller.policyLoaded.value == false ||
              controller.logEntriesLoaded.value == false) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
        });

        await tester.pumpWidget(
          const GetMaterialApp(home: AboutSettingsView()),
        );
        await tester.pumpAndSettle();

        expect(controller.buildInfoError.value, isTrue);
        // The risk this checklist item names directly (task §6/§7): a
        // null build number must never render as a bare "0".
        expect(controller.buildNumber.value, isNot(0));
        expect(controller.buildNumber.value, isNull);

        // F3 (review round 1): the OLD version of this test only checked
        // controller state and never pumped a widget at all -- the
        // reviewer proved this by changing the view's AB18 branch to
        // `return const SettingsMachineValue('0');` and every assertion
        // still passed. Assert what is actually RENDERED.
        expect(
          find.text('Version information could not be read.'),
          findsOneWidget,
        );
        expect(find.text('0'), findsNothing);
      },
    );

    testWidgets(
      'test_EARS_VER_18_absent_policy_renders_the_fail_open_statement',
      (tester) async {
        // No row inserted -- `cached()` legitimately returns null.
        final controller = AboutSettingsController(
          versionPolicyService: policyService,
          versionProvider: () async => '9.9.9',
          buildNumberProvider: () async => 999,
        );
        Get.put<AboutSettingsController>(controller);

        await tester.runAsync(() async {
          while (controller.version.value == null ||
              controller.policyLoaded.value == false ||
              controller.logEntriesLoaded.value == false) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
        });

        await tester.pumpWidget(
          const GetMaterialApp(home: AboutSettingsView()),
        );
        await tester.pumpAndSettle();

        expect(controller.policyLoaded.value, isTrue);
        expect(controller.policyError.value, isFalse);
        expect(controller.cachedPolicy.value, isNull);
        // AB13's fail-open default (EARS-VER-9): no cached policy at all
        // evaluates to upToDate, never updateRequired.
        expect(controller.versionState.value, VersionState.upToDate);

        // F4 (review round 1): the OLD version of this test only checked
        // controller state -- the reviewer proved this by mutating AB13's
        // copy in the view to `'MUTATED-NO-FAIL-OPEN-TEXT'` and every
        // assertion still passed (the design gate didn't catch it either,
        // since the only golden seeds a policy row). Assert the exact
        // verbatim AB13 copy (`settings-about.md`'s §Copy) is rendered.
        expect(
          find.text(
            'No policy has been fetched yet. This build is treated as '
            'supported until one is.',
          ),
          findsOneWidget,
        );
      },
    );
  });
}

/// `VersionPolicyService.cached()` throws, for `EARS-UI-11`'s
/// falsification -- a real seam failure, not a mocked promise of one.
/// `refresh()` is untouched and never called by this task's own controller
/// (task §4).
class _ThrowingCachedPolicyService extends VersionPolicyService {
  _ThrowingCachedPolicyService({required super.database});

  @override
  Future<VersionPolicy?> cached() {
    throw StateError('simulated read failure');
  }
}

class _RecordingClient implements ObservabilityClient {
  final List<(LogLevel, String, Object?)> captured = [];

  @override
  Future<void> init() async {}

  @override
  void capture(LogLevel level, String code, {Object? cause}) {
    captured.add((level, code, cause));
  }
}

/// Extracts the `{ ... }` body of the first `class <name> {` declaration in
/// [source] (brace-depth counting) -- the same idiomatic shape
/// `security_records_repository_test.dart`'s own `_extractClassBody`
/// already uses for an equivalent "this class cannot structurally hold X"
/// claim.
String _extractClassBody(String source, String className) {
  final match = RegExp('class $className\\b').firstMatch(source);
  if (match == null) {
    fail('No `class $className` declaration found in the given source.');
  }
  final classIndex = match.start;
  final openBrace = source.indexOf('{', classIndex);
  var depth = 0;
  for (var i = openBrace; i < source.length; i++) {
    if (source[i] == '{') depth++;
    if (source[i] == '}') {
      depth--;
      if (depth == 0) return source.substring(openBrace, i + 1);
    }
  }
  fail('Unbalanced braces while extracting `class $className` body.');
}
