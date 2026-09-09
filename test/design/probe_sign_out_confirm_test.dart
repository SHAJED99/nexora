// test/design/probe_sign_out_confirm_test.dart -- E15-T07's own fenced
// probe dump for `design/screens/sign-out-confirm.md`
// (`make design-probe` / `make design-verify SCREEN=sign-out-confirm`).
//
// Deliberately its OWN file, not `test/design/design_probe_test.dart` --
// that file is `E15-T11`'s alone (task §4). This screen has exactly one
// state (`default` -- every string is static, nothing to load, nothing to
// fail), so unlike `probe_settings_account_test.dart` there is no async
// read to drain before dumping.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/features/settings/account/domain/sign_out_use_case.dart';
import 'package:nexora/features/settings/account/presentation/sign_out_confirm_controller.dart';
import 'package:nexora/features/settings/account/presentation/sign_out_confirm_view.dart';

import 'flutter_probe_dumper.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('screen probe — sign-out-confirm (make design-probe)', () {
    setUp(() {
      Get.testMode = true;
      Get.put<SignOutConfirmController>(
        SignOutConfirmController(signOutUseCase: SignOutUseCase()),
      );
    });

    tearDown(() => Get.reset());

    testWidgets('sign-out-confirm', (tester) async {
      await dumpScreenProbe(
        tester,
        screenId: 'sign-out-confirm',
        screen: const GetMaterialApp(home: SignOutConfirmView()),
      );

      final raw = await tester.runAsync(
        () => File(
          'build/design-probe/sign-out-confirm.json',
        ).readAsString(),
      );
      final dump = jsonDecode(raw!) as Map<String, dynamic>;
      expect(dump['renderError'], isNull);
    });
  });
}
