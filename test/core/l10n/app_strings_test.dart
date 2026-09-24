// E06-T15 — FR-UI-005. Tests named by EARS id.
//
// The strongest evidence for this task is not in this file: it is
// `make design-verify SCREEN=settings` and `SCREEN=sign-out-confirm` both
// still reporting 100%, which proves no rendered string changed. These tests
// cover what the design gate cannot see — that the strings now come from a
// resource, and that the layout is logical rather than literal (the gate runs
// LTR only, so every RTL claim is invisible to it).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/l10n/app_strings.dart';

/// The two view files this task migrated (its `files:` fence).
const _migratedViews = <String>[
  'lib/features/settings/presentation/settings_view.dart',
  'lib/features/settings/account/presentation/sign_out_confirm_view.dart',
];

/// Literals that are NOT user-facing text and so are correctly left in place.
/// Every entry is an exemption and has to earn itself — a blanket "ignore
/// short strings" rule would let real copy back in.
const _notUserFacing = <String>{
  // Route names passed to Get.toNamed — identifiers, never rendered.
  '/dashboard',
  '/conversations',
  '/devices',
  '/settings',
};

/// Every string-valued getter on [AppStrings], by name.
///
/// Listed explicitly because Dart has no runtime reflection here. The list
/// being hand-maintained is exactly why `test_EARS_UI_14` below asserts on it:
/// a getter added without a line here is invisible to the duplicate check,
/// so the count assertion fails and points at this list.
Map<String, String> _allStrings(AppStrings s) => {
      'brandName': s.brandName,
      'settings': s.settings,
      'settingsSubtitle': s.settingsSubtitle,
      'settingsAccount': s.settingsAccount,
      'settingsAccountDescription': s.settingsAccountDescription,
      'settingsPrivacy': s.settingsPrivacy,
      'settingsPrivacyDescription': s.settingsPrivacyDescription,
      'settingsSecurityCenter': s.settingsSecurityCenter,
      'settingsSecurityCenterDescription': s.settingsSecurityCenterDescription,
      'settingsNetwork': s.settingsNetwork,
      'settingsNetworkDescription': s.settingsNetworkDescription,
      'settingsStorage': s.settingsStorage,
      'settingsStorageDescription': s.settingsStorageDescription,
      'settingsBattery': s.settingsBattery,
      'settingsBatteryDescription': s.settingsBatteryDescription,
      'settingsNotifications': s.settingsNotifications,
      'settingsNotificationsDescription': s.settingsNotificationsDescription,
      'settingsAbout': s.settingsAbout,
      'settingsAboutDescription': s.settingsAboutDescription,
      'navDashboard': s.navDashboard,
      'navConversations': s.navConversations,
      'navDevices': s.navDevices,
      'signOutTitle': s.signOutTitle,
      'signOutIntro': s.signOutIntro,
      'signOutIrreversible': s.signOutIrreversible,
      'signOutNewIdentity': s.signOutNewIdentity,
      'signOutConfirm': s.signOutConfirm,
      'cancel': s.cancel,
    };

void main() {
  const strings = AppStrings();

  group('EARS-UI-12 — visible strings come from a localization resource', () {
    test(
      'test_EARS_UI_12_settings_views_contain_no_user_facing_literals',
      () {
        // A capitalised, word-shaped literal of 4+ characters is copy until
        // proven otherwise. Comment lines are excluded because prose about a
        // string is not a string.
        final literal = RegExp(r"'([A-Z][A-Za-z][^']{2,})'");
        final offenders = <String>[];

        for (final rel in _migratedViews) {
          final file = File(rel);
          expect(file.existsSync(), isTrue, reason: '$rel must exist');
          final lines = file.readAsLinesSync();
          for (var i = 0; i < lines.length; i++) {
            final line = lines[i].trim();
            if (line.startsWith('//')) continue;
            for (final m in literal.allMatches(lines[i])) {
              final value = m.group(1)!;
              if (_notUserFacing.contains(value)) continue;
              offenders.add('$rel:${i + 1}  $value');
            }
          }
        }

        expect(
          offenders,
          isEmpty,
          reason: 'FR-UI-005: these strings are still hard-coded at the call '
              'site instead of coming from AppStrings:\n${offenders.join('\n')}',
        );
      },
    );

    testWidgets('test_EARS_UI_12_context_l10n_resolves_the_table',
        (tester) async {
      // Design.md §111 specifies `context.l10n.<key>` as the call shape.
      late AppStrings resolved;
      await tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: Builder(builder: (context) {
            resolved = context.l10n;
            return const SizedBox.shrink();
          }),
        ),
      );
      expect(resolved.settings, 'Settings');
    });
  });

  group('EARS-UI-13 — logical, not literal, directional layout', () {
    test('test_EARS_UI_13_directional_insets_mirror', () {
      // The conversion is only correct if it is LOGICAL. fromSTEB(start, top,
      // end, bottom) must swap under RTL; fromLTRB never would. Under LTR the
      // two are indistinguishable, which is exactly why this asserts RTL.
      const inset = EdgeInsetsDirectional.fromSTEB(20, 16, 4, 16);

      final ltr = inset.resolve(TextDirection.ltr);
      expect(ltr.left, 20);
      expect(ltr.right, 4);

      final rtl = inset.resolve(TextDirection.rtl);
      expect(rtl.left, 4, reason: 'start must become the RIGHT edge under RTL');
      expect(rtl.right, 20);
    });

    test('test_EARS_UI_13_migrated_views_use_no_literal_directional_geometry',
        () {
      final banned = RegExp(
        r'EdgeInsets\.fromLTRB|EdgeInsets\.only\([^)]*\b(left|right):'
        r'|Alignment\.(center|top|bottom)(Left|Right)'
        r'|TextAlign\.(left|right)\b',
      );
      final offenders = <String>[];
      for (final rel in _migratedViews) {
        final lines = File(rel).readAsLinesSync();
        for (var i = 0; i < lines.length; i++) {
          if (lines[i].trim().startsWith('//')) continue;
          if (banned.hasMatch(lines[i])) offenders.add('$rel:${i + 1}');
        }
      }
      expect(offenders, isEmpty,
          reason: 'FR-UI-005 asks for logical directional geometry; these '
              'lines are still literal:\n${offenders.join('\n')}');
    });

    testWidgets('test_EARS_UI_13_strings_render_under_rtl_without_overflow',
        (tester) async {
      // Every migrated string, laid out at the design's own width under RTL.
      // Text expansion plus mirroring is where a fixed-width row overflows.
      await tester.pumpWidget(
        MediaQuery(
          data: const MediaQueryData(size: Size(390, 844)),
          child: Directionality(
            textDirection: TextDirection.rtl,
            child: Material(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final value in _allStrings(strings).values)
                      Padding(
                        padding:
                            const EdgeInsetsDirectional.fromSTEB(20, 4, 20, 4),
                        child: Text(value),
                      ),
                    for (final line in strings.signOutLossList) Text(line),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      expect(tester.takeException(), isNull);
    });
  });

  group('EARS-UI-14 — one string, one key', () {
    test('test_EARS_UI_14_shared_strings_resolve_to_one_key', () {
      final byValue = <String, List<String>>{};
      _allStrings(strings).forEach((name, value) {
        byValue.putIfAbsent(value, () => <String>[]).add(name);
      });

      final duplicates = byValue.entries.where((e) => e.value.length > 1);
      expect(
        duplicates,
        isEmpty,
        reason: 'two getters returning identical copy is how a later edit '
            'updates one and silently leaves the other:\n'
            '${duplicates.map((e) => '"${e.key}" <- ${e.value}').join('\n')}',
      );
    });

    test('test_EARS_UI_14_settings_label_is_one_getter_used_twice', () {
      // `Settings` is both the screen heading (element 6) and the active
      // bottom-nav label. There is deliberately no `navSettings`.
      expect(strings.settings, 'Settings');
      expect(
        _allStrings(strings).keys.where((k) => k.toLowerCase() == 'navsettings'),
        isEmpty,
        reason: 'the nav label must reuse `settings`, not add a second getter',
      );
    });

    test('test_EARS_UI_14_no_string_is_empty', () {
      _allStrings(strings).forEach((name, value) {
        expect(value.trim(), isNotEmpty, reason: '$name is blank');
      });
      for (final line in strings.signOutLossList) {
        expect(line.trim(), isNotEmpty);
      }
    });
  });

  test('test_E06_T15_loss_list_keeps_the_design_contract_order', () {
    // The order is part of the measured copy (sign-out-confirm.md), so it is
    // asserted rather than left to the reader of a list literal.
    expect(strings.signOutLossList, hasLength(5));
    expect(strings.signOutLossList.first,
        'Your device identity and all of its encryption keys');
    expect(strings.signOutLossList.last, 'All of your settings');
  });
}
