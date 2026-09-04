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
