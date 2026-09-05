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
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/observability/observability_service.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/services/version_policy_service.dart';
import 'package:nexora/features/version/domain/evaluate_version_state_use_case.dart';
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
  // discipline this file already documents for `MessagingStack`. Only
  // `.cached()` is consulted here: `.refresh()` has no caller in this task,
  // matching `EvaluateVersionStateUseCase`'s own scope fence ("does NOT
  // call refresh() … deciding when to refresh is E14-T04's own wiring
  // concern") — this task wires the consumer, not a new remote-fetch
  // trigger.
  final versionPolicyService = VersionPolicyService(database: db);
  final evaluateVersionState = EvaluateVersionStateUseCase(
    cachedPolicyProvider: versionPolicyService.cached,
    installedBuildProvider: _readInstalledBuildNumber,
  );
  final versionState = await evaluateVersionState.call();
  final initialRoute = initialRouteFor(versionState);

  runApp(
    NexoraApp(
      db: db,
      messagingStack: messagingStack,
      initialRoute: initialRoute,
    ),
  );
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
Future<int> _readInstalledBuildNumber() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return int.parse(info.buildNumber);
  } catch (e) {
    ObservabilityService.instance.logError(
      'version.installed_build_read_failed',
      cause: e,
    );
    // Fail-open, mirroring `EvaluateVersionStateUseCase`'s own "no cached
    // policy -> upToDate" precedent (FR-VER-008, offline-use framing): an
    // unreadable build number must never itself block app use, so it is
    // treated as satisfying every threshold rather than none.
    return 1 << 62;
  }
}

class NexoraApp extends StatelessWidget {
  const NexoraApp({
    super.key,
    required this.db,
    required this.messagingStack,
    this.initialRoute = Routes.welcome,
  });

  final AppDatabase db;
  final MessagingStack messagingStack;

  /// E14-T04: `Routes.versionUpdateRequired` when the launch-time check in
  /// `main()` above evaluates `VersionState.updateRequired`, else
  /// `Routes.welcome` (the pre-existing default, also this constructor's
  /// own default for any caller — e.g. a widget test — that does not pass
  /// one explicitly).
  final String initialRoute;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'NEXORA',
      debugShowCheckedModeBanner: false,
      initialBinding: AppBinding(db: db, messagingStack: messagingStack),
      initialRoute: initialRoute,
      getPages: appPages,
    );
  }
}
