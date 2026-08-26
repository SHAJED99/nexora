// features/settings/presentation — SettingsController (E02-T03).
//
// Settings is a pure navigation hub — none of its eight menu rows have a
// built (or even designed) sub-screen yet. Per task §3/§4, tapping a row
// acknowledges the tap with a SnackBar rather than navigating to a
// fabricated screen.
import 'package:get/get.dart';

class SettingsController extends GetxController {
  /// Row tap handler shared by all eight rows (elements 8/13/18/23/28/33/
  /// 38/43 in design/screens/settings.md) — none of them have a built
  /// sub-screen, so every row shows the same acknowledgement.
  void openRow(String title) {
    Get.snackbar(
      title,
      'Coming soon',
      snackPosition: SnackPosition.BOTTOM,
    );
  }
}
