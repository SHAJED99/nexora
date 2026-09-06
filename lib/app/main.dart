// app/main.dart — entry point (docs/conventions.md "Project structure").
//
// E06-T03: the messaging composition root now assembles here, before
// `runApp` — AppDatabase -> the local device identity -> MessagingStack
// .create() (which itself does DriftSignalProtocolStore -> CryptoService
// .init(store) -> IdentityService.ensureLocalIdentity() ->
// ensureSignedPreKey() -> replenishOneTimePreKeys(), task file §3). Every
// step's failure is handled explicitly: `MessagingStack.create` itself never
// throws (a degraded device comes back as `status.unavailable`, never a
// crash — see `messaging_stack.dart`), so nothing here needs its own
// try/catch beyond that already-honest contract.
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_database/firebase_database.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/observability/observability_service.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/services/firebase_paths.dart';
import 'package:nexora/core/services/version_policy_service.dart';
import 'package:nexora/features/version/domain/evaluate_version_state_use_case.dart';
import 'package:nexora/features/version/domain/version_reconnect_watcher.dart';
import 'package:nexora/features/version/domain/version_state.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'bindings.dart';
import 'routes.dart';

Future<void> main() async {
  // Required before any platform-channel call (Firebase.initializeApp()
  // included) — without this, `main()` throws
  // "Binding has not yet been initialized" before runApp() ever runs.
  WidgetsFlutterBinding.ensureInitialized();
  await ObservabilityService.instance.init();
  // E01-T01: account identity only (ADR-0005) — Google Authentication via
  // Firebase Auth needs the default app initialized before any sign-in
  // attempt. No explicit FirebaseOptions: Android reads them from
  // `android/app/google-services.json` via the Google Services Gradle
  // plugin at build time.
  await Firebase.initializeApp();

  // The single app-wide AppDatabase (task file §5) — constructed here,
  // never inside `AppBinding`/`MessagingStack.create`, so there is
  // structurally only ever one (task file §2).
  final db = AppDatabase();

  // ADR-0005: device identity is local, independent of the Firebase
  // session above. A fresh install has none yet — it is only created
  // during sign-in (`LoginController._signIn`) — in which case
  // `MessagingStack.create` itself reports `unavailable` rather than this
  // file inventing a placeholder id (see `messaging_stack.dart`'s header,
  // judgment call 3).
  final localIdentity = await db.latestDeviceIdentity();
  final selfDeviceId = localIdentity?.deviceId ?? '';

  final messagingStack = await MessagingStack.create(
    db: db,
    selfDeviceId: selfDeviceId,
  );

  // E14-T04 (FR-VER-006/FR-VER-007, EARS-VER-10): a launch-time-only check
  // (task file §4 — no mid-session re-check, that is a deliberately
  // separate follow-up) against `E14-T01`'s already-cached version policy.
  // `VersionPolicyService(database: db)` reads the SAME `db` instance
  // constructed above — never a second `AppDatabase`, same "exactly one"
  // discipline this file already documents for `MessagingStack`.
  final versionPolicyService = VersionPolicyService(database: db);
  final versionState = await evaluateVersionStateAtLaunch(
    versionPolicyService,
    readInstalledBuildNumber,
  );
  final initialRoute = initialRouteFor(versionState);

  runApp(
    NexoraApp(
      db: db,
      messagingStack: messagingStack,
      initialRoute: initialRoute,
      // E14-B02 (FR-VER-006's "block application communication" clause):
      // the same already-evaluated `versionState` also decides whether
      // `AppBinding` may start the mesh -- see `bindings.dart`'s own
      // `blockCommunication` doc comment for exactly what this gates.
      blockCommunication: versionState == VersionState.updateRequired,
    ),
  );

  // E14-B06 (FR-VER-008's own second half): a genuine reconnect, observed
  // any time AFTER this launch-time evaluation already ran, re-fetches and
  // re-evaluates the version policy, re-routing to the mandatory-update
  // screen if it now comes back `updateRequired`. Started after `runApp`
  // (never before -- `Get.offNamed` below needs `GetMaterialApp` already
  // built), and reuses the SAME `versionPolicyService`/
  // `readInstalledBuildNumber` this function already constructed above --
  // never a second `VersionPolicyService`, same "exactly one" discipline
  // this file already documents for `AppDatabase`/`MessagingStack`.
  VersionReconnectWatcher(
    connectivityStream: FirebaseDatabase.instance
        .ref(FirebasePaths.infoConnected())
        .onValue
        .map((event) => event.snapshot.value == true),
    versionPolicyService: versionPolicyService,
    installedBuildProvider: readInstalledBuildNumber,
    // Mirrors `LoginController._signIn`'s own forced-navigation shape
    // (`Get.offNamed`, `login_controller.dart:58`) -- the established
    // pattern in this codebase for "this session's state changed, replace
    // the current screen" rather than pushing on top of it.
    //
    // E14-B06 round 2 (F5): guarded so a flapping connection producing
    // repeated reconnect events while the mandatory-update screen is
    // already showing doesn't keep tearing it down and rebuilding it.
    onUpdateRequired: () {
      if (Get.currentRoute != Routes.versionUpdateRequired) {
        Get.offNamed(Routes.versionUpdateRequired);
      }
    },
  ).start();
}

/// E14-B01: the exact launch-time composition `main()` runs to decide
/// [VersionState] — pulled out to a named, top-level function (same reason
/// `initialRouteFor` below already is one) so
/// `test/features/version/presentation/version_update_controller_test.dart`
/// (this bug's own fenced test file) can call THIS SAME function, not a
/// re-implementation of it, and so a regression that removes the
/// `.refresh()` call below fails that test rather than silently passing.
///
/// `refresh()` had zero production callers anywhere in `lib/` before this
/// fix — `E14-T01`/`E14-T02`/`E14-T04` each fenced the call site out to one
/// of the other two, and the sum was that `.cached()` below always read an
/// empty table (`VersionState.upToDate` always won by fail-open default).
/// Launch-time only (no polling timer, no periodic refresh — matches
/// `E14-T04`'s own fence): `refresh()` is already best-effort, timeout
/// -bounded and never-throwing (`EARS-VER-4`), so awaiting it here degrades
/// a no-network launch to exactly the previous (broken-but-safe) fail-open
/// behaviour, never a hang or a crash.
Future<VersionState> evaluateVersionStateAtLaunch(
  VersionPolicyService versionPolicyService,
  Future<int?> Function() installedBuildProvider,
) async {
  await versionPolicyService.refresh();
  final evaluateVersionState = EvaluateVersionStateUseCase(
    cachedPolicyProvider: versionPolicyService.cached,
    installedBuildProvider: installedBuildProvider,
  );
  return evaluateVersionState.call();
}

/// `EARS-VER-10` (FR-VER-006): the launch-time routing decision itself, as
/// a pure, independently-testable function of [VersionState] — pulled out
/// of `main()`'s body so `test_EARS_VER_10_update_required_routes_to_mandatory_screen`
/// (`test/features/version/presentation/version_update_controller_test.dart`,
/// this task's own fenced test file) can assert the mapping directly,
/// without booting Firebase/`AppDatabase`/`MessagingStack` the way a full
/// `main()` run would require.
///
/// `GetMaterialApp.initialRoute` is itself already non-poppable-behind
/// (there is nothing before it), so returning this value satisfies task
/// file §3's "stack-replacing navigation" requirement without
/// `Get.offAll`/`Get.offAllNamed` — there is no prior route for either of
/// those to replace.
String initialRouteFor(VersionState state) => state == VersionState.updateRequired
    ? Routes.versionUpdateRequired
    : Routes.welcome;

/// Real `InstalledBuildProvider` (`EvaluateVersionStateUseCase`'s own
/// injected seam, E14-T02) backed by `package_info_plus`
/// (`Q-E14-T04-1`, human-approved 2026-09-05). `PackageInfo.buildNumber` is
/// a `String` (Android's own `versionCode` rendered as text) — parsed to
/// `int` here, since the use case's own comparison is explicitly numeric,
/// never lexicographic (that file's own header comment).
///
/// Not private (pulled out of `main()`'s body the same way
/// `evaluateVersionStateAtLaunch`/`initialRouteFor` already are) so
/// `test/features/version/presentation/version_update_controller_test.dart`
/// (this bug's own fenced test file) can call THIS SAME function against a
/// mocked `PackageInfo`, rather than re-implementing it.
///
/// `E14-B03` (`OQ-E14-B03-1`, resolved 2026-09-06): returns `null` — never
/// a sentinel smuggled through a normal-looking `int` (the bug's own
/// finding about the old `1 << 62` value) — on EITHER failure mode this
/// used to conflate: a `PackageInfo.fromPlatform()` failure (platform
/// -channel error, plugin-registration failure) or a non-numeric
/// `buildNumber` (`int.tryParse` returning `null` instead of `int.parse`
/// throwing `FormatException`). `EvaluateVersionStateUseCase.call()` is the
/// one place that decides what `null` means (fail CLOSED when a policy is
/// cached) — this function's only job is reporting "could not read/parse",
/// honestly, in the type.
Future<int?> readInstalledBuildNumber() async {
  try {
    final info = await PackageInfo.fromPlatform();
    final buildNumber = int.tryParse(info.buildNumber);
    if (buildNumber == null) {
      ObservabilityService.instance.logError(
        'version.installed_build_read_failed',
        cause: FormatException(
          'PackageInfo.buildNumber is not numeric: "${info.buildNumber}"',
        ),
      );
    }
    return buildNumber;
  } catch (e) {
    ObservabilityService.instance.logError(
      'version.installed_build_read_failed',
      cause: e,
    );
    return null;
  }
}

class NexoraApp extends StatelessWidget {
  const NexoraApp({
    super.key,
    required this.db,
    required this.messagingStack,
    this.initialRoute = Routes.welcome,
    this.blockCommunication = false,
  });

  final AppDatabase db;
  final MessagingStack messagingStack;

  /// E14-T04: `Routes.versionUpdateRequired` when the launch-time check in
  /// `main()` above evaluates `VersionState.updateRequired`, else
  /// `Routes.welcome` (the pre-existing default, also this constructor's
  /// own default for any caller — e.g. a widget test — that does not pass
  /// one explicitly).
  final String initialRoute;

  /// E14-B02 (FR-VER-006): `true` exactly when `main()`'s own
  /// `versionState == VersionState.updateRequired` — threaded straight
  /// into `AppBinding.blockCommunication`, see that field's own doc
  /// comment for what it gates. Defaults `false` (the pre-existing
  /// behaviour) for any caller — e.g. a widget test — that does not pass
  /// one explicitly.
  final bool blockCommunication;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'NEXORA',
      debugShowCheckedModeBanner: false,
      initialBinding: AppBinding(
        db: db,
        messagingStack: messagingStack,
        blockCommunication: blockCommunication,
      ),
      initialRoute: initialRoute,
      getPages: appPages,
    );
  }
}
