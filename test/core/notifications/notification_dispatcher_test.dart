// NotificationDispatcher + MessageNotificationSource tests (E10-T03,
// EARS-NOTIFY-5/6/7). No separate `message_notification_source_test.dart`
// exists (task file `files:` fence) -- MessageNotificationSource is
// exercised here, wired through the real dispatcher and policy, since that
// is the shape EARS-NOTIFY-5's own test plan describes ("stub service
// records exactly one post; a second message in the same conversation
// reuses the same id").
import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/notifications/generated/notification_api.g.dart'
    show NotificationCategory;
import 'package:nexora/core/notifications/notification_dispatcher.dart';
import 'package:nexora/core/notifications/notification_policy.dart';
import 'package:nexora/core/notifications/notification_settings_repository.dart';
import 'package:nexora/core/notifications/notification_stub.dart';
import 'package:nexora/core/notifications/sources/message_notification_source.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/persistence/notification_tables.dart';
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';
import 'package:nexora/features/messaging/domain/message.dart';

/// A `Message` whose `ciphertext` getter throws if ever read -- the
/// falsifiable proof EARS-NOTIFY-7's test plan asks for ("assert the
/// injected crypto double was never called (proof, not assertion by
/// inspection)"). `Message.ciphertext` is the one field on the type this
/// pipeline could theoretically feed to a decoder/decryptor; overriding its
/// getter to throw means any code path that touches it -- directly, or via
/// `CiphertextCodec.decode`/`CryptoService.decrypt` -- fails this test
/// immediately, rather than merely being unasserted-on.
class _CiphertextReadForbiddenMessage extends Message {
  _CiphertextReadForbiddenMessage(Message base)
      : super(
          id: base.id,
          conversationId: base.conversationId,
          senderDeviceId: base.senderDeviceId,
          sequenceNumber: base.sequenceNumber,
          ciphertext: Uint8List(0),
          createdAt: base.createdAt,
          deliveryState: base.deliveryState,
        );

  @override
  Uint8List get ciphertext =>
      throw StateError('EARS-NOTIFY-7: ciphertext must not be read while building a notification');
}

Message _message({
  String id = 'm1',
  String conversationId = 'device-b',
  String senderDeviceId = 'device-b',
  int sequenceNumber = 1,
}) {
  return Message(
    id: id,
    conversationId: conversationId,
    senderDeviceId: senderDeviceId,
    sequenceNumber: sequenceNumber,
    ciphertext: Uint8List.fromList([1, 2, 3]),
    createdAt: 0,
    deliveryState: DeliveryState.accepted,
  );
}

void main() {
  late AppDatabase db;
  late NotificationSettingsRepository settings;
  late NotificationStub service;
  late NotificationDispatcher dispatcher;
  late StreamController<Message> delivered;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    settings = NotificationSettingsRepository(db: db);
    service = NotificationStub();
    dispatcher = NotificationDispatcher(
      service: service,
      policy: NotificationPolicy(settings: settings),
    );
    delivered = StreamController<Message>.broadcast();
  });

  tearDown(() async {
    await dispatcher.stop();
    await delivered.close();
    await db.close();
  });

  group('EARS-NOTIFY-5', () {
    test(
      'test_EARS_NOTIFY_5_delivered_message_posts_one_notification',
      () async {
        dispatcher.register(
          MessageNotificationSource(delivered.stream, selfDeviceId: 'self'),
        );
        await dispatcher.start();

        delivered.add(_message());
        await Future<void>.delayed(Duration.zero);

        expect(service.posted, hasLength(1));
        expect(service.posted.single.category, NotificationCategory.message);
      },
    );

    test(
      'a second message in the same conversation reuses the same id (replace, not stack)',
      () async {
        dispatcher.register(
          MessageNotificationSource(delivered.stream, selfDeviceId: 'self'),
        );
        await dispatcher.start();

        delivered.add(_message(id: 'm1'));
        delivered.add(_message(id: 'm2'));
        await Future<void>.delayed(Duration.zero);

        expect(service.posted, hasLength(2));
        expect(service.posted[0].id, service.posted[1].id);
      },
    );

    test(
      'start() is idempotent -- a second call does not double-subscribe',
      () async {
        dispatcher.register(
          MessageNotificationSource(delivered.stream, selfDeviceId: 'self'),
        );
        await dispatcher.start();
        await dispatcher.start();

        delivered.add(_message());
        await Future<void>.delayed(Duration.zero);

        expect(service.posted, hasLength(1));
      },
    );

    test('stop() is safe to call twice', () async {
      dispatcher.register(
        MessageNotificationSource(delivered.stream, selfDeviceId: 'self'),
      );
      await dispatcher.start();
      await dispatcher.stop();
      await dispatcher.stop();
    });

    test(
      'a message authored by this device (selfDeviceId) is never notified',
      () async {
        dispatcher.register(
          MessageNotificationSource(delivered.stream, selfDeviceId: 'device-b'),
        );
        await dispatcher.start();

        delivered.add(_message(senderDeviceId: 'device-b'));
        await Future<void>.delayed(Duration.zero);

        expect(service.posted, isEmpty);
      },
    );
  });

  group('EARS-NOTIFY-6', () {
    test(
      'test_EARS_NOTIFY_6_disabled_category_posts_nothing',
      () async {
        await settings.setEnabled(NotificationCategory.message, false);
        dispatcher.register(
          MessageNotificationSource(delivered.stream, selfDeviceId: 'self'),
        );
        await dispatcher.start();

        delivered.add(_message());
        await Future<void>.delayed(Duration.zero);

        expect(service.posted, isEmpty);
      },
    );

    test(
      'a disabled category never throws and does not kill later, enabled deliveries',
      () async {
        await settings.setEnabled(NotificationCategory.message, false);
        dispatcher.register(
          MessageNotificationSource(delivered.stream, selfDeviceId: 'self'),
        );
        await dispatcher.start();

        delivered.add(_message(id: 'm1'));
        await Future<void>.delayed(Duration.zero);
        expect(service.posted, isEmpty);

        await settings.setEnabled(NotificationCategory.message, true);
        delivered.add(_message(id: 'm2'));
        await Future<void>.delayed(Duration.zero);
        expect(service.posted, hasLength(1));
      },
    );
  });

  group('EARS-NOTIFY-7', () {
    test(
      'test_EARS_NOTIFY_7_hidden_privacy_has_no_sender_or_content',
      () async {
        await settings.setPrivacyLevel(NotificationPrivacyLevel.hidden);
        dispatcher.register(
          MessageNotificationSource(delivered.stream, selfDeviceId: 'self'),
        );
        await dispatcher.start();

        // Proof, not assertion by inspection: this Message throws if its
        // ciphertext is ever read. The dispatcher/policy/source path under
        // test must build and post a notification WITHOUT touching it.
        delivered.add(_CiphertextReadForbiddenMessage(_message()));
        await Future<void>.delayed(Duration.zero);

        expect(service.posted, hasLength(1));
        final posted = service.posted.single;
        expect(posted.title, 'NEXORA');
        expect(posted.body, 'New message');
        expect(posted.title, isNot(contains('device-b')));
        expect(posted.body, isNot(contains('device-b')));
      },
    );
  });

  test(
    'a source that throws synchronously does not stop the dispatcher for later events',
    () async {
      final badController = StreamController<Message>();
      addTearDown(badController.close);
      final badSource = _ThrowingSource(badController.stream);

      dispatcher.register(badSource);
      dispatcher.register(
        MessageNotificationSource(delivered.stream, selfDeviceId: 'self'),
      );
      await dispatcher.start();

      badController.addError(StateError('boom'));
      delivered.add(_message());
      await Future<void>.delayed(Duration.zero);

      expect(service.posted, hasLength(1));
    },
  );
}

/// A minimal source whose stream can emit an error, used to prove one
/// source's failure does not kill the dispatcher's other subscriptions
/// (task file §6 risk).
class _ThrowingSource implements NotificationSource {
  _ThrowingSource(this._stream);
  final Stream<Message> _stream;

  @override
  Stream<NotificationFacts> get facts => _stream.map(
        (_) => throw StateError('unreachable'),
      );
}
