// features/settings/about/presentation -- AboutSettingsController
// (E15-T10, FR-VER-012). Reads three already-shipped `E14` sources --
// installed version/build (`package_info_plus`), the cached version policy
// (`VersionPolicyService.cached`) and the evaluated `VersionState`
// (`EvaluateVersionStateUseCase`) -- plus a fourth, structurally-safe
// diagnostics seam, and renders nothing this screen computes itself
// (task §2 -- "without inventing a second version story").
//
// Each card's read fails independently, exactly the same "one card's
// failure never touches another" shape `NotificationSettingsController`
// (E15-T04) and `SecurityCenterController` (E15-T06) already established
// for this Settings sub-screen family (task §5, `EARS-UI-11`).
//
// Scope fence (task §4): this controller does NOT call
// `VersionPolicyService.refresh()` -- `main.dart` owns that call (`E14-B01`);
// reading `cached()` is this screen's whole job. It does NOT add a
// "check for updates" trigger, an update action, or any button of any kind.
//
// **Disclosed gap (Open Questions -- OQ-E15-T10-2):** `ObservabilityService`
// (`lib/core/observability/observability_service.dart`) sends every event
// straight to Sentry and keeps NO locally-readable copy of its own -- it has
// no read method at all, only `init()`/`log()`/`logError()`. FR-VER-012 and
// this task's own §5 contract both describe "the local diagnostic log" as
// something this screen reads, but no such readable local store exists
// anywhere in the shipped codebase, and building one (a new persistence
// mechanism threaded through every existing `logError` call site, or a new
// Drift table -- either a 🧍 `db_schema_migration` gate or a cross-cutting
// change to a file outside this task's `files:` fence) is far outside an
// `S`-sized screen task. Per the builder-ui rule this task was briefed
// with ("silently drop a field... keep the field, wire it to local state,
// log the gap"): the Diagnostics card stays -- AB14-AB18 are fully built and
// wired to a real injectable seam ([DiagnosticLogProvider]) -- but its
// production default ([_readDiagnosticLog] below) honestly returns an empty
// list, rendering AB17 (`Nothing has been logged.`), one of
// `settings-about.md`'s own two explicitly-"ordinary" empty states, rather
// than fabricating an entry `ObservabilityService` never actually recorded
// (rule 1). A future task that adds a real, locally-readable diagnostic log
// store supplies its own `logEntriesProvider` here; nothing in this file
// needs to change for that to happen.
library;

import 'dart:async';

import 'package:get/get.dart';
import 'package:nexora/app/main.dart' show readInstalledBuildNumber;
import 'package:nexora/core/observability/observability_service.dart';
import 'package:nexora/core/services/version_policy_service.dart';
import 'package:nexora/features/version/domain/evaluate_version_state_use_case.dart';
import 'package:nexora/features/version/domain/version_state.dart';
import 'package:package_info_plus/package_info_plus.dart';

/// AB16/AB17's own data shape. **FR-DIAG-002-safe by construction**: `code`
/// and `timestamp` are the ONLY two fields this class may ever declare --
/// there is no third field anywhere in this body that could hold a `cause`
/// object, a stack trace, or any other content `ObservabilityService`'s own
/// `cause` parameter might carry (task §5/§6, the same structural guard
/// `SecurityRecord` (`E15-T06`) already established for this reason).
class DiagnosticEntry {
  const DiagnosticEntry({required this.code, required this.timestamp});

  /// One of `ObservabilityService`'s own log codes (e.g.
  /// `version.installed_build_read_failed`) -- never the extra detail
  /// object passed alongside it at the real call site.
  final String code;

  final DateTime timestamp;
}

/// [AboutSettingsController.logEntries]'s own injectable seam -- see this
/// file's header comment (OQ-E15-T10-2) for why the production default
/// ([_readDiagnosticLog]) can only honestly return an empty list today.
typedef DiagnosticLogProvider = Future<List<DiagnosticEntry>> Function();

/// AB1-AB18 (`design/screens/settings-about.md`, `GAP-038`). Three
/// independent reads; a failure in one never clears another's already
/// -rendered card (`EARS-UI-11`).
class AboutSettingsController extends GetxController {
  AboutSettingsController({
    required this.versionPolicyService,
    Future<String?> Function()? versionProvider,
    Future<int?> Function()? buildNumberProvider,
    DiagnosticLogProvider? logEntriesProvider,
  }) : _versionProvider = versionProvider ?? _readInstalledVersion,
       _buildNumberProvider = buildNumberProvider ?? readInstalledBuildNumber,
       _logEntriesProvider = logEntriesProvider ?? _readDiagnosticLog,
       _versionStateUseCase = EvaluateVersionStateUseCase(
         cachedPolicyProvider: versionPolicyService.cached,
         installedBuildProvider:
             buildNumberProvider ?? readInstalledBuildNumber,
       );

  /// `E14-T01`'s cache wrapper. [refresh] is never called here (task §4) --
  /// only [VersionPolicyService.cached] is ever read.
  final VersionPolicyService versionPolicyService;

  final Future<String?> Function() _versionProvider;
  final Future<int?> Function() _buildNumberProvider;
  final DiagnosticLogProvider _logEntriesProvider;
  final EvaluateVersionStateUseCase _versionStateUseCase;

  /// AB6. `null` while loading; once [buildInfoError] is `true` the value
  /// here is stale and must not be rendered (task §5 contract).
  final Rx<String?> version = Rx<String?>(null);

  /// AB7. `null` while loading, OR — per this field's own contract doc
  /// ("Null renders AB18, never a 0 and never a sentinel", `E14-B03`) — a
  /// genuinely unreadable/non-numeric installed build. [buildInfoError]
  /// disambiguates the two: this field alone is never enough.
  final Rx<int?> buildNumber = Rx<int?>(null);

  /// AB8, one of `VersionState`'s three fixed strings (rendered by the
  /// view, never here — this screen holds no copy of its own).
  final Rx<VersionState?> versionState = Rx<VersionState?>(null);

  /// `true` once the version/build/state read has failed outright, OR
  /// resolved with an unreadable build number (task §6 Risks: a `null`
  /// build number renders AB18, the whole card, never a lone "0" row).
  final RxBool buildInfoError = false.obs;

  /// AB11/AB12. `null` is a real, legitimate outcome — "nothing has ever
  /// been cached" (AB13, `EARS-VER-9`'s fail-open default) — never confused
  /// with `loading` because [policyLoaded] disambiguates the two.
  final Rx<VersionPolicy?> cachedPolicy = Rx<VersionPolicy?>(null);

  /// `true` once the [versionPolicyService.cached] read has completed,
  /// successfully or not — the only way the view can tell "a `null` policy
  /// because nothing has loaded yet" apart from "a `null` policy because
  /// none is cached" (AB13).
  final RxBool policyLoaded = false.obs;

  final RxBool policyError = false.obs;

  /// AB16/AB17. Empty is this screen's own honest default — see this
  /// file's header comment (OQ-E15-T10-2) — and is one of
  /// `settings-about.md`'s own two explicitly-"ordinary" empty states, not
  /// an error.
  final RxList<DiagnosticEntry> logEntries = <DiagnosticEntry>[].obs;

  final RxBool logEntriesLoaded = false.obs;

  final RxBool logEntriesError = false.obs;

  @override
  void onInit() {
    super.onInit();
    unawaited(_loadBuildInfo());
    unawaited(_loadPolicy());
    unawaited(_loadDiagnostics());
  }

  Future<void> _loadBuildInfo() async {
    try {
      final readVersion = await _versionProvider();
      final readBuildNumber = await _buildNumberProvider();
      if (readVersion == null || readBuildNumber == null) {
        // Task §6 Risks: a null build number (or version) renders AB18 --
        // the whole card -- never a lone "0"/blank row alongside otherwise
        // -populated values.
        buildInfoError.value = true;
        return;
      }
      version.value = readVersion;
      buildNumber.value = readBuildNumber;
      try {
        versionState.value = await _versionStateUseCase.call();
      } catch (_) {
        // `EvaluateVersionStateUseCase.call()` reads the SAME cached
        // policy `_loadPolicy`/`policyError` already reports on — a
        // failure here is the Version Policy card's own failure
        // (`EARS-UI-11`), not this card's. Version/Build already resolved
        // above and stay rendered; only the Status row is left unset.
      }
    } catch (_) {
      buildInfoError.value = true;
    }
  }

  Future<void> _loadPolicy() async {
    try {
      cachedPolicy.value = await versionPolicyService.cached();
    } catch (_) {
      policyError.value = true;
    } finally {
      policyLoaded.value = true;
    }
  }

  Future<void> _loadDiagnostics() async {
    try {
      logEntries.assignAll(await _logEntriesProvider());
    } catch (_) {
      logEntriesError.value = true;
    } finally {
      logEntriesLoaded.value = true;
    }
  }
}

/// [AboutSettingsController._versionProvider]'s production default. Mirrors
/// `readInstalledBuildNumber`'s own shape (`lib/app/main.dart`, E14-T04):
/// never throws to the caller, logs and returns `null` on failure so the
/// view renders AB18 rather than a stale or fabricated version string.
/// `package_info_plus` is already a dependency (task §5 "External services
/// & flags") -- nothing new is added to read this.
Future<String?> _readInstalledVersion() async {
  try {
    final info = await PackageInfo.fromPlatform();
    return info.version;
  } catch (e) {
    ObservabilityService.instance.logError(
      'version.installed_version_read_failed',
      cause: e,
    );
    return null;
  }
}

/// [AboutSettingsController._logEntriesProvider]'s production default —
/// see this file's header comment (OQ-E15-T10-2) for why an empty list is
/// the only honest answer today.
Future<List<DiagnosticEntry>> _readDiagnosticLog() async =>
    const <DiagnosticEntry>[];
