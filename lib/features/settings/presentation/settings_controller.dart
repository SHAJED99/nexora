// features/settings/presentation — SettingsController (E02-T03, rewired
// E15-T11).
//
// Settings is a pure navigation hub. All eight menu rows (elements
// 8/13/18/23/28/33/38/43 in design/screens/settings.md) now have a built
// sub-screen (E15-T04..T10) — `openRow` navigates to each, replacing the
// `Get.snackbar(title, 'Coming soon')` acknowledgement E02-T03 wrote when
// none of them existed yet (task §2, `FR-UI-006`, `EARS-UI-8`).
//
// Routing is on [SettingsRow], a closed enum — never the row's own display
// title. A title-string switch breaks silently the moment `settings.md`'s
// copy changes (a design gate concern, not a code concern) and, worse, a
// missing branch on a string switch is a runtime no-op; a missing branch on
// an enum switch is a compile error. There is deliberately no `default`
// branch anywhere below (task §4: "does NOT keep a 'Coming soon' fallback
// for an unmapped row") — every [SettingsRow] value must resolve to a real
// route or this file fails to compile.
import 'package:get/get.dart';
import 'package:nexora/app/routes.dart';

/// Closed row identity — one value per measured row in
/// `design/screens/settings.md`, in that contract's own top-to-bottom order.
/// See [SettingsController.openRow].
enum SettingsRow {
  account,
  privacy,
  securityCenter,
  network,
  storage,
  battery,
  notifications,
  about,
}

class SettingsController extends GetxController {
  /// Row tap handler shared by all eight rows. `FR-UI-006`/`EARS-UI-8`: every
  /// row navigates to its own sub-screen; none shows a non-navigating
  /// acknowledgement of any kind (no snackbar, no dialog, no toast).
  void openRow(SettingsRow row) {
    switch (row) {
      case SettingsRow.account:
        Get.toNamed(Routes.settingsAccount);
      case SettingsRow.privacy:
        Get.toNamed(Routes.settingsPrivacy);
      case SettingsRow.securityCenter:
        Get.toNamed(Routes.settingsSecurityCenter);
      case SettingsRow.network:
        Get.toNamed(Routes.settingsNetwork);
      case SettingsRow.storage:
        Get.toNamed(Routes.settingsStorage);
      case SettingsRow.battery:
        Get.toNamed(Routes.settingsBattery);
      case SettingsRow.notifications:
        Get.toNamed(Routes.settingsNotifications);
      case SettingsRow.about:
        Get.toNamed(Routes.settingsAbout);
    }
  }
}
