// Tests for CallNotificationSource (E10-T04, EARS-NOTIFY-8/9).
//
// Unit-level: feeds a hand-built `Stream<CallNotice>` rather than a full
// `CallSignaling` -- `call_signaling_test.dart`'s own
// `group('E10-T04: CallSignaling.notices ...')` already proves the emission
// side against the real state machine; this file proves the mapping/cancel
// side in isolation.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/calls/call_signaling.dart'
    show CallNotice, CallNoticeKind;
import 'package:nexora/core/notifications/generated/notification_api.g.dart'
    show NotificationCategory;
import 'package:nexora/core/notifications/notification_policy.dart';
import 'package:nexora/core/notifications/notification_stub.dart';
import 'package:nexora/core/notifications/sources/call_notification_source.dart';

void main() {
  // `CallNotificationSource.facts` is built with `.where().map()` over the
  // underlying broadcast stream, not an `async*` generator -- an earlier
  // `async*` implementation hung on `StreamSubscription.cancel()` and was
  // replaced (see `CallNotificationSource`'s own header). `.where().map()`
  // still only forwards events added AFTER a listener subscribes -- a
  // broadcast stream drops an event with no subscriber at the moment it is
  // added -- so every test below still awaits one microtask after
  // subscribing and before publishing on `controller`, to let the
  // subscription actually attach first.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('test_EARS_NOTIFY_8_invite_posts_incoming_call_notification',
      () async {
    final controller = StreamController<CallNotice>.broadcast();
    final sink = NotificationStub();
    final source = CallNotificationSource(controller.stream, sink: sink);

    final facts = <NotificationFacts>[];
    final subscription = source.facts.listen(facts.add);
    await settle();

    controller.add(
      const CallNotice(
        kind: CallNoticeKind.invite,
        callId: 'call-1',
        peerDeviceId: 'device-x',
      ),
    );
    await settle();

    expect(facts, hasLength(1));
    expect(facts.single.category, NotificationCategory.incomingCall);
    expect(facts.single.conversationId, 'call-1');
    expect(facts.single.peerDeviceId, 'device-x');
    expect(facts.single.stableId, stableNotificationId('call-1'));
    expect(sink.cancelled, isEmpty);

    await subscription.cancel();
    await controller.close();
  });

  test('test_EARS_NOTIFY_9_terminal_kinds_cancel_and_post_nothing',
      () async {
    for (final kind in [
      CallNoticeKind.answered,
      CallNoticeKind.declined,
      CallNoticeKind.timedOut,
      CallNoticeKind.remoteCancelled,
    ]) {
      final controller = StreamController<CallNotice>.broadcast();
      final sink = NotificationStub();
      final source = CallNotificationSource(controller.stream, sink: sink);

      final facts = <NotificationFacts>[];
      final subscription = source.facts.listen(facts.add);
      await settle();

      controller.add(
        CallNotice(
          kind: kind,
          callId: 'call-1',
          peerDeviceId: 'device-x',
        ),
      );
      await settle();

      expect(facts, isEmpty, reason: '$kind must never post');
      expect(
        sink.cancelled,
        [stableNotificationId('call-1')],
        reason: '$kind must withdraw the ring notification',
      );

      await subscription.cancel();
      await controller.close();
    }
  });

  test(
      'the cancelled id matches the id that would be posted for the same '
      'callId', () async {
    final controller = StreamController<CallNotice>.broadcast();
    final sink = NotificationStub();
    final source = CallNotificationSource(controller.stream, sink: sink);

    final facts = <NotificationFacts>[];
    final subscription = source.facts.listen(facts.add);
    await settle();

    controller.add(
      const CallNotice(
        kind: CallNoticeKind.invite,
        callId: 'call-42',
        peerDeviceId: 'device-y',
      ),
    );
    controller.add(
      const CallNotice(
        kind: CallNoticeKind.declined,
        callId: 'call-42',
        peerDeviceId: 'device-y',
      ),
    );
    await settle();

    expect(facts, hasLength(1));
    expect(sink.cancelled, hasLength(1));
    expect(facts.single.stableId, sink.cancelled.single);

    await subscription.cancel();
    await controller.close();
  });

  test('a cancel is issued even when the sink reports the category disabled',
      () async {
    // `sink.cancel` is deliberately never gated on `permissionGranted`
    // (`NotificationStub.cancel` records unconditionally) -- withdrawal is
    // cleanup, not a privacy/enablement decision (this source's own header).
    final controller = StreamController<CallNotice>.broadcast();
    final sink = NotificationStub(permissionGranted: false);
    final source = CallNotificationSource(controller.stream, sink: sink);

    final subscription = source.facts.listen((_) {});
    await settle();

    controller.add(
      const CallNotice(
        kind: CallNoticeKind.timedOut,
        callId: 'call-1',
        peerDeviceId: 'device-x',
      ),
    );
    await settle();

    expect(sink.cancelled, [stableNotificationId('call-1')]);

    await subscription.cancel();
    await controller.close();
  });
}
