// EARS-AUTH-4 (FR-AUTH-005) — the welcome screen offers no authentication
// path other than Google Sign-In.
//
// The criterion already existed; nothing tested it. E01's epic.md asserted it
// was "already satisfied by genesis's built welcome screen and unchanged" —
// prose, which the traceability audit correctly does not accept as evidence
// (rule 7: "looks right" is not evidence).
//
// This is a NEGATIVE requirement ("no alternate login path SHALL exist"), so
// asserting the Google button renders would not prove it. What must be proven
// is that nothing ELSE on the screen authenticates. These tests therefore
// assert the absence of alternate affordances and that the single interactive
// route out of the screen is the Google one.
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/features/welcome/presentation/welcome_controller.dart';
import 'package:nexora/features/welcome/presentation/welcome_view.dart';

/// Records where the screen navigated, so the Google path can be proven to be
/// the one that fires without stubbing the controller itself — the real
/// `WelcomeController` runs.
Future<void> _pumpWelcome(WidgetTester tester, List<String> visited) async {
  Get.testMode = true;
  Get.put(WelcomeController());
  await tester.pumpWidget(
    GetMaterialApp(
      initialRoute: '/',
      getPages: <GetPage<dynamic>>[
        GetPage<dynamic>(name: '/', page: () => const WelcomeView()),
        GetPage<dynamic>(
          name: '/login',
          page: () {
            visited.add('/login');
            return const Scaffold(body: Text('login-stub'));
          },
        ),
      ],
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  tearDown(Get.reset);

  group('WelcomeView — sole authentication path', () {
    testWidgets(
      'test_EARS_AUTH_4_welcome_offers_no_authentication_path_other_than_google',
      (WidgetTester tester) async {
        await _pumpWelcome(tester, <String>[]);

        // Every alternate sign-in mechanism the product could plausibly have
        // grown. If one is ever added to this screen without amending
        // FR-AUTH-005, this test is the thing that objects.
        const forbidden = <String>[
          'email',
          'password',
          'phone',
          'sms',
          'otp',
          'apple',
          'facebook',
          'github',
          'sign up',
          'register',
          'create account',
          'guest',
          'skip',
          'continue without',
          'use another',
          'more options',
        ];

        final texts = tester
            .widgetList<Text>(find.byType(Text))
            .map((Text t) => (t.data ?? '').toLowerCase())
            .toList();

        for (final String term in forbidden) {
          expect(
            texts.any((String t) => t.contains(term)),
            isFalse,
            reason: 'FR-AUTH-005: the welcome screen must expose no '
                'authentication path other than Google Sign-In, but found '
                'copy containing "$term"',
          );
        }

        // The Google path itself must be present — a screen with NO auth path
        // would vacuously satisfy the negative assertions above.
        expect(
          texts.any((String t) => t.contains('continue with google')),
          isTrue,
          reason: 'the sole permitted path must actually be offered',
        );
      },
    );

    testWidgets(
      'test_EARS_AUTH_4_the_only_route_out_of_welcome_is_the_google_path',
      (WidgetTester tester) async {
        final visited = <String>[];
        await _pumpWelcome(tester, visited);

        expect(visited, isEmpty, reason: 'nothing navigates before a tap');

        await tester.tap(find.text('Continue with Google'));
        await tester.pumpAndSettle();

        expect(
          visited,
          <String>['/login'],
          reason: 'FR-AUTH-005: the single auth affordance hands off to the '
              'Google sign-in route, and no other route was reachable',
        );
      },
    );
  });
}
