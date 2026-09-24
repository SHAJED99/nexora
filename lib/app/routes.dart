// app/routes.dart — named routes, bound to design/screens/*.md ids
// (docs/conventions.md "Naming"). See docs/routes.md for the full table
// including the routes not yet wired (owned by their feature epics).
import 'package:get/get.dart';
import 'package:in_app_update/in_app_update.dart';
import 'package:nexora/features/chat/presentation/chat_binding.dart';
import 'package:nexora/features/chat/presentation/chat_view.dart';
import 'package:nexora/features/conversations/presentation/conversations_binding.dart';
import 'package:nexora/features/conversations/presentation/conversations_view.dart';
import 'package:nexora/features/dashboard/presentation/dashboard_binding.dart';
import 'package:nexora/features/dashboard/presentation/dashboard_view.dart';
import 'package:nexora/features/devices/presentation/devices_binding.dart';
import 'package:nexora/features/devices/presentation/devices_view.dart';
import 'package:nexora/features/groups/presentation/group_create_binding.dart';
import 'package:nexora/features/groups/presentation/group_create_view.dart';
import 'package:nexora/features/groups/presentation/group_thread_binding.dart';
import 'package:nexora/features/groups/presentation/group_thread_view.dart';
import 'package:nexora/features/home/presentation/home_view.dart';
import 'package:nexora/features/login/presentation/login_view.dart';
import 'package:nexora/features/recovery/presentation/device_enrollment_controller.dart';
import 'package:nexora/features/recovery/presentation/device_enrollment_view.dart';
import 'package:nexora/features/settings/about/presentation/about_settings_view.dart';
import 'package:nexora/features/settings/account/presentation/account_view.dart';
import 'package:nexora/features/settings/account/presentation/sign_out_confirm_view.dart';
import 'package:nexora/features/settings/battery/presentation/battery_settings_view.dart';
import 'package:nexora/features/settings/network/presentation/network_settings_view.dart';
import 'package:nexora/features/settings/notifications/presentation/notification_settings_view.dart';
import 'package:nexora/features/settings/presentation/settings_binding.dart';
import 'package:nexora/features/settings/presentation/settings_view.dart';
import 'package:nexora/features/settings/privacy/presentation/privacy_settings_view.dart';
import 'package:nexora/features/settings/security_center/presentation/security_center_view.dart';
import 'package:nexora/features/settings/storage/presentation/storage_settings_view.dart';
import 'package:nexora/features/version/presentation/version_update_controller.dart';
import 'package:nexora/features/version/presentation/version_update_view.dart';
import 'package:nexora/features/welcome/presentation/welcome_view.dart';

abstract final class Routes {
  static const welcome = '/welcome';
  static const login = '/login';

  /// Genesis placeholder only — not a design-contracted screen. Superseded
  /// by `/dashboard` (design/screens/dashboard.md, E06-T12) as the post-login
  /// destination; the route itself stays registered (its own file is not in
  /// this task's `files:` fence to remove).
  static const home = '/home';

  /// design/screens/dashboard.md (E06-T12). The post-login destination,
  /// superseding [home].
  static const dashboard = '/dashboard';

  /// design/screens/devices.md (E02-T02).
  static const devices = '/devices';

  /// design/screens/settings.md (E02-T03).
  static const settings = '/settings';

  /// design/screens/settings-account.md (E15-T07, GAP-035).
  static const settingsAccount = '/settings/account';

  /// design/screens/sign-out-confirm.md (E15-T07, GAP-039). Reached from
  /// `/settings/account`'s own sign-out row, not from a hub row (E15-T11 §3).
  static const settingsSignOutConfirm = '/settings/sign-out-confirm';

  /// design/screens/settings-privacy.md (E15-T05, GAP-033 + GAP-040).
  static const settingsPrivacy = '/settings/privacy';

  /// design/screens/settings-security-center.md (E15-T06, GAP-034).
  static const settingsSecurityCenter = '/settings/security-center';

  /// design/screens/settings-network.md (E15-T08, GAP-036).
  static const settingsNetwork = '/settings/network';

  /// design/screens/settings-storage.md (E15-T09, GAP-024).
  static const settingsStorage = '/settings/storage';

  /// design/screens/settings-battery.md (E15-T08, GAP-037).
  static const settingsBattery = '/settings/battery';

  /// design/screens/settings-notifications.md (E15-T04, GAP-032).
  static const settingsNotifications = '/settings/notifications';

  /// design/screens/settings-about.md (E15-T10, GAP-038).
  static const settingsAbout = '/settings/about';

  /// design/screens/conversations.md (E06-T10).
  static const conversations = '/conversations';

  /// design/screens/chat.md (E06-T11). `id` = `conversationId` =
  /// peer device id (T09 §2).
  static const chat = '/chat/:id';

  /// design/screens/group-create.md (E07-T15, GAP-018). **No screen links
  /// here yet.** The create-group entry point is that contract's Open
  /// section, explicitly awaiting the human and not covered by GAP-018's
  /// clearance, so this route is reachable only by direct navigation until
  /// that decision is taken (E07-T15 section 4).
  static const groupCreate = '/groups/new';

  /// design/screens/chat-group.md (E07-T18, GAP-020). The group thread.
  /// **Deliberately NOT `/chat/:id`**: `ChatController` treats its id as a
  /// Signal peer device id and runs X3DH against it, so a group id there
  /// produces undecryptable bubbles and a non-retryable send failure
  /// (`E07-B01`, measured; human decision 2026-09-02 closed that route to
  /// group ids, and `E07-B05` re-closed a second door into it).
  static const groupThread = '/groups/:id';

  /// design/screens/version-update-required.md (E14-T04, FR-VER-006/007).
  /// Reached at launch when `EvaluateVersionStateUseCase` (E14-T02)
  /// evaluates `updateRequired` — see `main.dart`'s launch-time check,
  /// wired via `GetMaterialApp.initialRoute` (`Q-E14-T04-1`, resolved
  /// 2026-09-05).
  static const versionUpdateRequired = '/version-update-required';

  /// design/screens/device-enrollment.md (E12-T03, GAP-028). Reached from
  /// `/login`'s own sign-in flow only (`LoginController._signIn()`) — never
  /// linked from any existing screen. `uid`/`deviceId` are passed via
  /// `Get.arguments`, not a path parameter, since neither is meant to be a
  /// shareable/bookmarkable URL segment.
  static const deviceEnrollment = '/device-enrollment';
}

/// Starts the platform's Google Play in-app update "Immediate Update" flow
/// (task file §5, `FR-VER-007`, `EARS-VER-12`) via the `in_app_update`
/// package (`Q-E14-T04-1`, human-approved 2026-09-05).
///
/// `InAppUpdate.checkForUpdate()` has to be called first per that API's own
/// contract — it is what tells the caller whether an immediate update is
/// even allowed right now (e.g. it never is on a platform without the Play
/// in-app update API, task file §6 risk 2: this degrades to throwing here,
/// which `VersionUpdateController.startImmediateUpdate()` already
/// catches/logs/swallows — never a crash). `performImmediateUpdate()`
/// itself is "never a direct APK download" (`FR-VER-007`'s own wording) —
/// it hands the whole flow to Google Play's own UI, exactly the API this
/// task is required to use rather than any home-grown download path.
/// A non-`success` result (denied, or failed) is turned into a thrown
/// error so the controller's existing catch/log path handles it uniformly
/// — there is nothing else for this function itself to do differently for
/// either failure mode (task file §5's own "the screen stays" contract).
Future<void> _immediateUpdateLauncher() async {
  final info = await InAppUpdate.checkForUpdate();
  if (!info.immediateUpdateAllowed) {
    throw StateError(
      'in_app_update: immediate update not allowed '
      '(updateAvailability=${info.updateAvailability})',
    );
  }
  final result = await InAppUpdate.performImmediateUpdate();
  if (result != AppUpdateResult.success) {
    throw StateError('in_app_update: immediate update result was $result');
  }
}

final appPages = <GetPage<dynamic>>[
  GetPage<dynamic>(name: Routes.welcome, page: () => const WelcomeView()),
  GetPage<dynamic>(name: Routes.login, page: () => const LoginView()),
  GetPage<dynamic>(name: Routes.home, page: () => const HomeView()),
  GetPage<dynamic>(
    name: Routes.dashboard,
    page: () => const DashboardView(),
    binding: DashboardBinding(),
  ),
  GetPage<dynamic>(
    name: Routes.devices,
    page: () => const DevicesView(),
    binding: DevicesBinding(),
  ),
  GetPage<dynamic>(
    name: Routes.settings,
    page: () => const SettingsView(),
    binding: SettingsBinding(),
  ),
  // The eight sub-screens (E15-T04..T10) + the sign-out confirmation
  // (E15-T07) all share `SettingsBinding` (E15-T11 §3): it lazily registers
  // every one of the nine controllers below, so whichever of these routes is
  // visited first resolves every dependency the same way — never a
  // per-sub-route binding class per screen.
  GetPage<dynamic>(
    name: Routes.settingsAccount,
    page: () => const AccountView(),
    binding: SettingsBinding(),
  ),
  GetPage<dynamic>(
    name: Routes.settingsSignOutConfirm,
    page: () => const SignOutConfirmView(),
    binding: SettingsBinding(),
  ),
  GetPage<dynamic>(
    name: Routes.settingsPrivacy,
    page: () => const PrivacySettingsView(),
    binding: SettingsBinding(),
  ),
  GetPage<dynamic>(
    name: Routes.settingsSecurityCenter,
    page: () => const SecurityCenterView(),
    binding: SettingsBinding(),
  ),
  GetPage<dynamic>(
    name: Routes.settingsNetwork,
    page: () => const NetworkSettingsView(),
    binding: SettingsBinding(),
  ),
  GetPage<dynamic>(
    name: Routes.settingsStorage,
    page: () => const StorageSettingsView(),
    binding: SettingsBinding(),
  ),
  GetPage<dynamic>(
    name: Routes.settingsBattery,
    page: () => const BatterySettingsView(),
    binding: SettingsBinding(),
  ),
  GetPage<dynamic>(
    name: Routes.settingsNotifications,
    page: () => const NotificationSettingsView(),
    binding: SettingsBinding(),
  ),
  GetPage<dynamic>(
    name: Routes.settingsAbout,
    page: () => const AboutSettingsView(),
    binding: SettingsBinding(),
  ),
  GetPage<dynamic>(
    name: Routes.conversations,
    page: () => const ConversationsView(),
    binding: ConversationsBinding(),
  ),
  GetPage<dynamic>(
    name: Routes.chat,
    page: () => const ChatView(),
    binding: ChatBinding(),
  ),
  GetPage<dynamic>(
    name: Routes.groupCreate,
    page: () => const GroupCreateView(),
    binding: GroupCreateBinding(),
  ),
  GetPage<dynamic>(
    name: Routes.groupThread,
    page: () => const GroupThreadView(),
    binding: GroupThreadBinding(),
  ),
  GetPage<dynamic>(
    name: Routes.versionUpdateRequired,
    page: () => const VersionUpdateView(),
    binding: _VersionUpdateBinding(),
  ),
  GetPage<dynamic>(
    name: Routes.deviceEnrollment,
    page: () => const DeviceEnrollmentView(),
    // Inline binding (no separate `DeviceEnrollmentBinding` file — not in
    // this task's `files:` fence): `DeviceEnrollmentController`'s own
    // constructor already defaults every collaborator (Get.find lookups for
    // the app-wide singletons, `Get.arguments` for `uid`/`deviceId`), so
    // there is nothing a dedicated binding class would add here beyond what
    // `BindingsBuilder` already does inline.
    binding: BindingsBuilder(
      () => Get.lazyPut(DeviceEnrollmentController.new),
    ),
  ),
];

/// `VersionUpdateController`'s binding — same shape as
/// `DevicesBinding`/`SettingsBinding`/etc. The launcher is the real
/// `in_app_update`-backed `_immediateUpdateLauncher` above (`Q-E14-T04-1`,
/// resolved 2026-09-05).
class _VersionUpdateBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<VersionUpdateController>(
      () => VersionUpdateController(launcher: _immediateUpdateLauncher),
    );
  }
}
