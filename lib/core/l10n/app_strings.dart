// core/l10n — the application's localization resources (E06-T15, FR-UI-005).
//
// `documentation/Design.md` §111 fixes both the rule and the call shape:
//
//     All visible strings must come from localization resources.
//     Do not hard-code user-facing text.
//
//     Text(
//       context.l10n.updateRequired,
//     )
//
// so this is reached as `context.l10n.<key>`, never as a global singleton and
// never through `Get.find` — the lookup is per-`BuildContext` precisely so a
// later locale change re-resolves it through the element tree like any other
// inherited value.
//
// **This file is not a translation layer yet, and must not be read as one.**
// It is one table, in one language. `FR-UI-005` asks that strings come from
// resources and that layout be logical; it asks for no second locale, no
// pluralization and no date or number formatting — which are the only things
// `intl` would add over the SDK. Adding a package here would be a rule-3
// `new_dependency` gate for capability the requirement does not ask for.
// When a second locale is genuinely wanted, [AppStrings] gains a subclass per
// locale and [AppStrings.of] learns to pick one; every call site below is
// already correct at that point, which is the entire purpose of this task.
//
// **Every string here is measured by an approved design contract.** The copy
// was moved verbatim out of the view files, never retyped. `make design-verify`
// treats a copy mismatch as a hard failure, so those gates are this file's
// real test: `settings` and `sign-out-confirm` must both stay at 100%.
import 'package:flutter/widgets.dart';

/// The application's visible strings, in one place.
///
/// One getter per distinct string. A string shown in two places gets **one**
/// getter (`EARS-UI-14`) — two getters returning the same words is how a later
/// copy change updates one of them and silently leaves the other.
class AppStrings {
  const AppStrings();

  /// Resolves the active string table for [context].
  ///
  /// Today there is exactly one table, so this returns a const instance and
  /// never reads [context]. It takes the context anyway because that is the
  /// signature a locale-aware lookup needs, and changing every call site later
  /// is the cost this task exists to avoid paying twice.
  static AppStrings of(BuildContext context) => const AppStrings();

  // ── Brand ──────────────────────────────────────────────────────────────
  /// The wordmark. Kept here rather than exempted: it is a visible string, and
  /// a table with a hole in it invites the next one.
  String get brandName => 'NEXORA';

  // ── Settings hub (design/screens/settings.md) ──────────────────────────
  /// Element 6, and the active bottom-nav label. ONE getter for both uses —
  /// see the class doc.
  String get settings => 'Settings';
  String get settingsSubtitle =>
      'Manage your secure connection preferences and device configurations.';

  String get settingsAccount => 'Account';
  String get settingsAccountDescription =>
      'Profile, identity keys, linked devices';

  String get settingsPrivacy => 'Privacy & Security';
  String get settingsPrivacyDescription =>
      'Encryption protocols, app lock, permissions';

  String get settingsSecurityCenter => 'Security Center';
  String get settingsSecurityCenterDescription =>
      'Threat logs, network audits, certificates';

  String get settingsNetwork => 'Network';
  String get settingsNetworkDescription => 'Data usage, mesh routing, proxy';

  String get settingsStorage => 'Storage';
  String get settingsStorageDescription =>
      'Local cache, message retention, export';

  String get settingsBattery => 'Battery';
  String get settingsBatteryDescription =>
      'Background execution, power saving modes';

  String get settingsNotifications => 'Notifications';
  String get settingsNotificationsDescription =>
      'Alerts, silent modes, LED behaviors';

  String get settingsAbout => 'About / Updates';
  String get settingsAboutDescription =>
      'Version 2.4.1, release notes, diagnostic logs';

  // ── Bottom navigation ──────────────────────────────────────────────────
  // The Settings label is [settings] above, not a fourth getter here.
  String get navDashboard => 'Dashboard';
  String get navConversations => 'Conversations';
  String get navDevices => 'Devices';

  // ── Sign-out confirmation (design/screens/sign-out-confirm.md) ─────────
  String get signOutTitle => 'Sign out and erase this device?';

  String get signOutIntro =>
      'Signing out permanently deletes everything this '
      'app keeps on this device:';

  /// `FR-AUTH-008`. The view's own comment calls this "the line every future
  /// edit of this screen must never drop": without it a person reasonably
  /// assumes signing back in restores what they had. Moving it into a resource
  /// does not weaken that — the string is now harder to delete by accident,
  /// because deleting it breaks a named getter rather than a line in a tree.
  String get signOutIrreversible =>
      'This cannot be undone. Anything encrypted with '
      'these keys can never be read again, on this device '
      'or any other.';

  String get signOutNewIdentity =>
      'Signing back in creates a brand-new identity, as '
      'if the app had just been installed.';

  String get signOutConfirm => 'Sign out and erase';
  String get cancel => 'Cancel';

  /// The loss list, in the design contract's order. A list rather than five
  /// getters because the view renders it as a sequence and the order is part
  /// of the measured copy.
  List<String> get signOutLossList => const [
        'Your device identity and all of its encryption keys',
        'Every message, voice message and call recording, and all history',
        'Every trusted device and every block you have set',
        'Every group this device belongs to',
        'All of your settings',
      ];
}

/// `context.l10n` — the call shape `documentation/Design.md` §111 specifies.
extension BuildContextL10n on BuildContext {
  AppStrings get l10n => AppStrings.of(this);
}
