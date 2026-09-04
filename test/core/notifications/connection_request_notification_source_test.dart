// Tests for ConnectionRequestNotificationSource (E10-T05,
// EARS-NOTIFY-10/11).
//
// Unit-level: feeds a hand-built `Stream<ConnectionRequestNotice>` rather
// than a real `PrekeyExchange` -- `prekey_exchange_test.dart`'s own
// `E10-T05` group already proves the emission side (both evaluation sites)
// against the real control-frame path; this file proves the
// filter/de-dup/mapping side in isolation, mirroring
// `call_notification_source_test.dart`'s own split.
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/messaging/prekey_exchange.dart'
    show ConnectionRequestNotice;
import 'package:nexora/core/notifications/generated/notification_api.g.dart'
    show NotificationCategory;
import 'package:nexora/core/notifications/notification_policy.dart';
import 'package:nexora/core/notifications/sources/connection_request_notification_source.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

void main() {
  // `.where().map()` over the underlying broadcast stream, not `async*` --
  // `CallNotificationSource`'s own header documents why an `async*`
  // implementation was tried and abandoned (hung on
  // `StreamSubscription.cancel()`); this source deliberately reuses the same
  // idiom rather than repeating that mistake. A broadcast stream drops an
  // event added with no subscriber yet, so every test below awaits one
  // microtask after subscribing and before publishing on `controller`.
  Future<void> settle() => Future<void>.delayed(Duration.zero);

  test('test_EARS_NOTIFY_10_unknown_peer_posts_one_notification', () async {
    final controller = StreamController<ConnectionRequestNotice>.broadcast();
    final source = ConnectionRequestNotificationSource(controller.stream);

    final facts = <NotificationFacts>[];
    final subscription = source.facts.listen(facts.add);
    await settle();

    controller.add(
      const ConnectionRequestNotice(
        peerDeviceId: 'device-x',
        state: RelationshipState.unknown,
      ),
    );
    await settle();

    expect(facts, hasLength(1));
    expect(facts.single.category, NotificationCategory.connectionRequest);
    expect(facts.single.peerDeviceId, 'device-x');
    expect(facts.single.stableId, stableNotificationId('device-x'));

    await subscription.cancel();
    await controller.close();
  });

  test(
    'test_EARS_NOTIFY_10_repeated_requests_from_same_peer_post_once',
    () async {
      final controller =
          StreamController<ConnectionRequestNotice>.broadcast();
      final source = ConnectionRequestNotificationSource(controller.stream);

      final facts = <NotificationFacts>[];
      final subscription = source.facts.listen(facts.add);
      await settle();

      // A retrying peer -- the same `peerDeviceId`, evaluated `unknown`
      // again on a second/third attempt -- must not re-notify (task file
      // §6 risk: "a peer retrying a handshake can emit many times per
      // minute").
      for (var i = 0; i < 3; i++) {
        controller.add(
          const ConnectionRequestNotice(
            peerDeviceId: 'device-x',
            state: RelationshipState.unknown,
          ),
        );
      }
      await settle();

      expect(facts, hasLength(1));
      expect(facts.single.peerDeviceId, 'device-x');

      await subscription.cancel();
      await controller.close();
    },
  );

  test('test_EARS_NOTIFY_11_blocked_peer_posts_nothing', () async {
    // The one that matters most (task file, security-relevant): a blocked
    // peer must never notify, under any circumstance.
    final controller = StreamController<ConnectionRequestNotice>.broadcast();
    final source = ConnectionRequestNotificationSource(controller.stream);

    final facts = <NotificationFacts>[];
    final subscription = source.facts.listen(facts.add);
    await settle();

    controller.add(
      const ConnectionRequestNotice(
        peerDeviceId: 'device-blocked',
        state: RelationshipState.blocked,
      ),
    );
    await settle();

    expect(facts, isEmpty);

    await subscription.cancel();
    await controller.close();
  });

  test('test_EARS_NOTIFY_11_trusted_and_allowed_post_nothing', () async {
    final controller = StreamController<ConnectionRequestNotice>.broadcast();
    final source = ConnectionRequestNotificationSource(controller.stream);

    final facts = <NotificationFacts>[];
    final subscription = source.facts.listen(facts.add);
    await settle();

    controller.add(
      const ConnectionRequestNotice(
        peerDeviceId: 'device-trusted',
        state: RelationshipState.trusted,
      ),
    );
    controller.add(
      const ConnectionRequestNotice(
        peerDeviceId: 'device-allowed',
        state: RelationshipState.allowed,
      ),
    );
    await settle();

    expect(facts, isEmpty);

    await subscription.cancel();
    await controller.close();
  });

  test(
    'a peer that later resolves unknown after an earlier non-unknown event '
    'still posts (de-dup keys only on already-notified unknown peers)',
    () async {
      final controller =
          StreamController<ConnectionRequestNotice>.broadcast();
      final source = ConnectionRequestNotificationSource(controller.stream);

      final facts = <NotificationFacts>[];
      final subscription = source.facts.listen(facts.add);
      await settle();

      controller.add(
        const ConnectionRequestNotice(
          peerDeviceId: 'device-y',
          state: RelationshipState.trusted,
        ),
      );
      controller.add(
        const ConnectionRequestNotice(
          peerDeviceId: 'device-y',
          state: RelationshipState.unknown,
        ),
      );
      await settle();

      expect(facts, hasLength(1));
      expect(facts.single.peerDeviceId, 'device-y');

      await subscription.cancel();
      await controller.close();
    },
  );
}
