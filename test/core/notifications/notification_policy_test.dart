// NotificationPolicy tests (E10-T03, EARS-NOTIFY-6/7).
//
// `AppDatabase.forTesting(NativeDatabase.memory())` +
// `NotificationSettingsRepository` -- same precedent
// `notification_settings_repository_test.dart` (E10-T02) already
// established, so this test exercises the real repository rather than a
// hand-rolled fake of it.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/notifications/generated/notification_api.g.dart'
    show NotificationCategory;
import 'package:nexora/core/notifications/notification_policy.dart';
import 'package:nexora/core/notifications/notification_settings_repository.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/persistence/notification_tables.dart';

void main() {
  late AppDatabase db;
  late NotificationSettingsRepository settings;
  late NotificationPolicy policy;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    settings = NotificationSettingsRepository(db: db);
    policy = NotificationPolicy(settings: settings);
  });

  tearDown(() => db.close());

  NotificationFacts messageFacts({String? peerDisplayName = 'device-b'}) {
    return NotificationFacts(
      category: NotificationCategory.message,
      conversationId: 'device-b',
      peerDeviceId: 'device-b',
      peerDisplayName: peerDisplayName,
      stableId: stableNotificationId('device-b'),
    );
  }

  NotificationFacts factsFor(
    NotificationCategory category, {
    String? peerDisplayName = 'device-b',
  }) {
    return NotificationFacts(
      category: category,
      conversationId: 'device-b',
      peerDeviceId: 'device-b',
      peerDisplayName: peerDisplayName,
      stableId: stableNotificationId('device-b'),
    );
  }

  group('EARS-NOTIFY-6', () {
    test(
      'test_EARS_NOTIFY_6_disabled_category_posts_nothing',
      () async {
        await settings.setEnabled(NotificationCategory.message, false);

        final request = await policy.resolve(messageFacts());

        expect(request, isNull);
      },
    );

    test(
      'a disabled category never throws, regardless of privacy level',
      () async {
        await settings.setEnabled(NotificationCategory.message, false);
        await settings.setPrivacyLevel(NotificationPrivacyLevel.full);

        expect(await policy.resolve(messageFacts()), isNull);
      },
    );
  });

  group('EARS-NOTIFY-7', () {
    test(
      'test_EARS_NOTIFY_7_hidden_privacy_has_no_sender_or_content',
      () async {
        await settings.setPrivacyLevel(NotificationPrivacyLevel.hidden);

        final request = await policy.resolve(messageFacts());

        expect(request, isNotNull);
        expect(request!.title, 'NEXORA');
        expect(request.body, 'New message');
        expect(request.title, isNot(contains('device-b')));
        expect(request.body, isNot(contains('device-b')));
      },
    );

    test(
      'senderOnly privacy shows the display name but never the content',
      () async {
        await settings.setPrivacyLevel(NotificationPrivacyLevel.senderOnly);

        final request = await policy.resolve(messageFacts());

        expect(request!.title, 'device-b');
        expect(request.body, 'New message');
      },
    );

    test(
      'senderOnly with no display name falls back to NEXORA, never a raw id leak',
      () async {
        await settings.setPrivacyLevel(NotificationPrivacyLevel.senderOnly);

        final request = await policy.resolve(messageFacts(peerDisplayName: null));

        expect(request!.title, 'NEXORA');
      },
    );

    test(
      'test_EARS_NOTIFY_7_full_downgrades_to_sender_only',
      () async {
        await settings.setPrivacyLevel(NotificationPrivacyLevel.full);

        final request = await policy.resolve(messageFacts());

        // `full` has no supported mechanism (OQ-E10-2) -- the disclosed
        // downgrade renders identically to `senderOnly`, never a preview.
        expect(request!.title, 'device-b');
        expect(request.body, 'New message');
      },
    );
  });

  // Regression coverage for E10-B03: four categories (`incomingCall`,
  // `connectionRequest`, `groupEvent`, `storageWarning`) fell through
  // `_copyFor`'s `default:` and posted generic `NEXORA`/`Notification` copy
  // instead of the copy each owning task contracted in its own §5. Each
  // block below asserts the exact §5 string, verbatim, at both `hidden` and
  // `senderOnly` -- these must fail on pre-fix code (all four returned
  // `NEXORA`/`Notification` regardless of category).
  group('E10-B03 category copy', () {
    group('incomingCall (E10-T04.md:108)', () {
      test(
        'test_E10_B03_incoming_call_hidden_has_no_peer_name',
        () async {
          await settings.setPrivacyLevel(NotificationPrivacyLevel.hidden);

          final request = await policy.resolve(
            factsFor(NotificationCategory.incomingCall),
          );

          expect(request, isNotNull);
          expect(request!.title, 'Incoming call');
          expect(request.body, 'Someone is calling');
        },
      );

      test(
        'test_E10_B03_incoming_call_sender_only_shows_peer_name',
        () async {
          await settings.setPrivacyLevel(NotificationPrivacyLevel.senderOnly);

          final request = await policy.resolve(
            factsFor(NotificationCategory.incomingCall),
          );

          expect(request!.title, 'Incoming call');
          expect(request.body, 'device-b');
        },
      );

      test(
        'test_E10_B03_incoming_call_sender_only_falls_back_to_unknown_device',
        () async {
          await settings.setPrivacyLevel(NotificationPrivacyLevel.senderOnly);

          final request = await policy.resolve(
            factsFor(NotificationCategory.incomingCall, peerDisplayName: null),
          );

          expect(request!.title, 'Incoming call');
          expect(request.body, 'Unknown device');
        },
      );
    });

    group('connectionRequest (E10-T05.md:105)', () {
      test(
        'test_E10_B03_connection_request_hidden',
        () async {
          await settings.setPrivacyLevel(NotificationPrivacyLevel.hidden);

          final request = await policy.resolve(
            factsFor(NotificationCategory.connectionRequest),
          );

          expect(request!.title, 'Connection request');
          expect(request.body, 'An unknown device wants to connect');
        },
      );

      test(
        'test_E10_B03_connection_request_sender_only_reads_the_same',
        () async {
          await settings.setPrivacyLevel(NotificationPrivacyLevel.senderOnly);

          final request = await policy.resolve(
            factsFor(NotificationCategory.connectionRequest),
          );

          expect(request!.title, 'Connection request');
          expect(request.body, 'An unknown device wants to connect');
        },
      );
    });

    group('groupEvent (E10-T06.md:108)', () {
      // `NotificationFacts` carries no group name and no `GroupEventNotice.
      // kind` (E10-T06.md:209) -- only the §5 generic `NEXORA`/`Group
      // activity` string is renderable, at every privacy level.
      test(
        'test_E10_B03_group_event_hidden',
        () async {
          await settings.setPrivacyLevel(NotificationPrivacyLevel.hidden);

          final request = await policy.resolve(
            factsFor(NotificationCategory.groupEvent),
          );

          expect(request!.title, 'NEXORA');
          expect(request.body, 'Group activity');
        },
      );

      test(
        'test_E10_B03_group_event_sender_only_reads_the_same',
        () async {
          await settings.setPrivacyLevel(NotificationPrivacyLevel.senderOnly);

          final request = await policy.resolve(
            factsFor(NotificationCategory.groupEvent),
          );

          expect(request!.title, 'NEXORA');
          expect(request.body, 'Group activity');
        },
      );
    });

    group('storageWarning (E10-T07.md:107)', () {
      test(
        'test_E10_B03_storage_warning_hidden',
        () async {
          await settings.setPrivacyLevel(NotificationPrivacyLevel.hidden);

          final request = await policy.resolve(
            factsFor(NotificationCategory.storageWarning),
          );

          expect(request!.title, 'Storage almost full');
          expect(request.body, 'NEXORA is running low on local storage');
        },
      );

      test(
        'test_E10_B03_storage_warning_sender_only_reads_the_same',
        () async {
          await settings.setPrivacyLevel(NotificationPrivacyLevel.senderOnly);

          final request = await policy.resolve(
            factsFor(NotificationCategory.storageWarning),
          );

          expect(request!.title, 'Storage almost full');
          expect(request.body, 'NEXORA is running low on local storage');
        },
      );
    });

    // The unshipped classes (`voiceMessage`, `ptt`, `trustRequest`,
    // `securityEvent`) must keep falling through to the generic default --
    // this fix does not invent copy for them (OQ-E10-3/6/7).
    test(
      'test_E10_B03_unshipped_categories_still_use_the_generic_default',
      () async {
        await settings.setPrivacyLevel(NotificationPrivacyLevel.senderOnly);

        final request = await policy.resolve(
          factsFor(NotificationCategory.trustRequest),
        );

        expect(request!.title, 'NEXORA');
        expect(request.body, 'Notification');
      },
    );
  });

  // Defect #2 (latent): `resolve()` downgrades `full` to `senderOnly`
  // (notification_policy.dart:91). Before this fix, `_copyFor` had no branch
  // differentiating `full` from `senderOnly`, so deleting the downgrade line
  // left the whole suite green -- the existing
  // `test_EARS_NOTIFY_7_full_downgrades_to_sender_only` above proved nothing.
  // `_copyFor` now asserts it is never called with `full` (resolve() must
  // downgrade first), which makes that assertion -- and this test -- fail
  // for the right reason if the downgrade line is removed. See the bug's
  // run log for the manual falsification (delete the line, confirm red,
  // restore, confirm green).
  test(
    'test_E10_B03_full_privacy_never_reaches_copyFor_undowngraded',
    () async {
      await settings.setPrivacyLevel(NotificationPrivacyLevel.full);

      final request = await policy.resolve(messageFacts());

      // Must render exactly like `senderOnly` -- proof that `resolve()`
      // downgraded `full` before `_copyFor` ever saw it.
      expect(request!.title, 'device-b');
      expect(request.body, 'New message');
    },
  );

  test('the posted request id is the facts stableId, for replace-not-stack', () async {
    final facts = messageFacts();
    final request = await policy.resolve(facts);
    expect(request!.id, facts.stableId);
  });

  test('stableNotificationId is deterministic and non-negative', () {
    final a = stableNotificationId('device-b');
    final b = stableNotificationId('device-b');
    final c = stableNotificationId('device-c');
    expect(a, b);
    expect(a, isNot(c));
    expect(a, greaterThanOrEqualTo(0));
  });
}
