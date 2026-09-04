// core/notifications — E10-T01: proves NotificationService's facade against
// the real generated Pigeon channels (encode/decode included), not an
// in-Dart fake, plus NotificationStub's in-memory recording contract.
// Mirrors `test/core/transport/transport_service_test.dart`'s shape
// deliberately (E04-T03a).
//
// Per-category channel creation and true Android-side idempotency (a
// re-declared channel with an unchanged id is a no-op, importance cannot be
// raised after creation) are native (`NotificationChannels.kt`) and are
// proven by `flutter build apk --debug` compiling plus the manual step
// (task §8) — not by a Robolectric/mock-Kotlin test that would pass
// regardless of correctness (E04-T03b's standing rule, task §8). What this
// suite proves on the Dart side: the facade issues exactly one
// `ensureChannels` host call per `ensureReady()` call, repeated calls never
// throw or accumulate extra side effects observable from Dart, and `post()`
// resolves `false` without throwing when permission is denied.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/notifications/generated/notification_api.g.dart';
import 'package:nexora/core/notifications/notification_service.dart';
import 'package:nexora/core/notifications/notification_stub.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test('test_EARS_PLAT_5_channels_created_once_per_category', () async {
    // EARS-PLAT-5 (FR-NOTIFY-001, FR-PLAT-003): WHEN the notification host
    // attaches, the system SHALL create exactly one Android notification
    // channel per NotificationCategory, idempotently. The per-category /
    // native-idempotency half is proven natively (see file header); this
    // test proves the Dart-side contract every caller of ensureReady()
    // depends on: one `ensureChannels` host call is issued per call, and
    // repeated calls settle cleanly every time — no accumulating state, no
    // exception, no duplicated permission requests.
    const String suffix = 'channels';
    final NotificationService service = NotificationService(
      binaryMessenger: messenger,
      messageChannelSuffix: suffix,
    );
    addTearDown(service.dispose);

    int ensureChannelsCallCount = 0;
    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.nexora.NotificationApi.ensureChannels.$suffix',
      (ByteData? message) async {
        ensureChannelsCallCount++;
        return NotificationApi.pigeonChannelCodec.encodeMessage(
          <Object?>[null],
        );
      },
    );
    messenger.setMockMessageHandler(
      'dev.flutter.pigeon.nexora.NotificationApi.hasPermission.$suffix',
      (ByteData? message) async =>
          NotificationApi.pigeonChannelCodec.encodeMessage(<Object?>[true]),
    );

    final bool first = await service.ensureReady();
    final bool second = await service.ensureReady();
    final bool third = await service.ensureReady();

    expect(first, isTrue);
    expect(second, isTrue);
    expect(third, isTrue);
    // One ensureChannels effect requested per ensureReady() call; nothing
    // extra accumulated by calling it repeatedly.
    expect(ensureChannelsCallCount, 3);
  });

  test('test_EARS_PLAT_6_post_returns_false_when_denied', () async {
    // EARS-PLAT-6 (FR-PLAT-003): IF POST_NOTIFICATIONS is not granted on
    // API 33+, THEN post() SHALL return false and SHALL NOT throw.
    // NotificationStub is what every downstream task (T03-T08) tests
    // against (task §3), so this proves the double's own contract directly.
    final NotificationStub stub = NotificationStub(permissionGranted: false);

    final NotificationRequest request = NotificationRequest(
      id: 1,
      category: NotificationCategory.message,
      title: 'title',
      body: 'body',
      ongoing: false,
    );

    final bool result = await stub.post(request);

    expect(result, isFalse);
    expect(stub.posted, isEmpty);
  });

  test(
    'test_notification_service_post_returns_false_when_native_refuses',
    () async {
      // Same EARS-PLAT-6 contract, proven through the real generated Pigeon
      // codec against NotificationService (not the stub) — the native host
      // reports refusal (no permission / notifications disabled) by
      // returning false, never by throwing across the boundary.
      const String suffix = 'postdenied';
      final NotificationService service = NotificationService(
        binaryMessenger: messenger,
        messageChannelSuffix: suffix,
      );
      addTearDown(service.dispose);

      messenger.setMockMessageHandler(
        'dev.flutter.pigeon.nexora.NotificationApi.post.$suffix',
        (ByteData? message) async =>
            NotificationApi.pigeonChannelCodec.encodeMessage(<Object?>[false]),
      );

      final NotificationRequest request = NotificationRequest(
        id: 2,
        category: NotificationCategory.message,
        title: 'title',
        body: 'body',
        ongoing: false,
      );

      final bool result = await service.post(request);

      expect(result, isFalse);
    },
  );

  test('test_notification_stub_records_accepted_posts', () async {
    // NotificationStub's own recording surface — downstream tasks assert
    // against this rather than any native side effect (task §5).
    final NotificationStub stub = NotificationStub();

    final NotificationRequest request = NotificationRequest(
      id: 42,
      category: NotificationCategory.incomingCall,
      title: 'Incoming call',
      body: 'Someone is calling',
      ongoing: false,
    );

    final bool result = await stub.post(request);

    expect(result, isTrue);
    expect(stub.posted, <NotificationRequest>[request]);

    await stub.cancel(42);
    expect(stub.cancelled, <int>[42]);
  });

  test(
    'test_EARS_PLAT_5_ensureReady_returns_false_not_throws_when_the_host_'
    'channel_is_unavailable',
    () async {
      // E10-B08: with NO mock handler registered for ensureChannels, the
      // real Pigeon codec throws a PlatformException/MissingPluginException
      // rather than returning -- confirmed reachable in production the
      // instant this host isn't attached yet. ensureReady()'s own doc
      // comment promises Future<bool>, never a throw; before this fix it
      // propagated the exception uncaught.
      const String suffix = 'nohostchannel';
      final NotificationService service = NotificationService(
        binaryMessenger: messenger,
        messageChannelSuffix: suffix,
      );
      addTearDown(service.dispose);

      final bool result = await service.ensureReady();

      expect(result, isFalse);
    },
  );

  test(
    'test_EARS_PLAT_5_ensureReady_returns_false_rather_than_hanging_when_'
    'the_permission_result_never_arrives',
    () async {
      // E10-B08: hasPermission() reports false (not yet granted) and
      // requestPermission() completes normally, but the OS never delivers
      // onPermissionResult -- reachable in production when the host
      // Activity is destroyed between the request and the callback
      // (NotificationApiHost.requestPermission against a destroyed
      // Activity while ForegroundMeshService keeps the engine alive, the
      // same shape E10-B05 already found on the neighboring
      // service-notification path). Before this fix, permissionResults
      // .first had no bound and hung forever.
      const String suffix = 'neverresolves';
      final NotificationService service = NotificationService(
        binaryMessenger: messenger,
        messageChannelSuffix: suffix,
        readyTimeout: const Duration(milliseconds: 50),
      );
      addTearDown(service.dispose);

      messenger.setMockMessageHandler(
        'dev.flutter.pigeon.nexora.NotificationApi.ensureChannels.$suffix',
        (ByteData? message) async =>
            NotificationApi.pigeonChannelCodec.encodeMessage(<Object?>[null]),
      );
      messenger.setMockMessageHandler(
        'dev.flutter.pigeon.nexora.NotificationApi.hasPermission.$suffix',
        (ByteData? message) async =>
            NotificationApi.pigeonChannelCodec.encodeMessage(<Object?>[false]),
      );
      messenger.setMockMessageHandler(
        'dev.flutter.pigeon.nexora.NotificationApi.requestPermission.$suffix',
        (ByteData? message) async =>
            NotificationApi.pigeonChannelCodec.encodeMessage(<Object?>[null]),
      );
      // Deliberately no onPermissionResult event ever sent.

      final bool result = await service.ensureReady();

      expect(result, isFalse);
    },
  );

  test(
    'test_notification_service_permission_result_stream_emits_native_event',
    () async {
      // Proves the events half of the boundary: a native
      // onPermissionResult push reaches NotificationService.permissionResults
      // through the real generated codec.
      const String suffix = 'permresult';
      final NotificationService service = NotificationService(
        binaryMessenger: messenger,
        messageChannelSuffix: suffix,
      );
      addTearDown(service.dispose);

      final Future<bool> resultFuture = service.permissionResults.first;

      final ByteData eventMessage =
          NotificationEventsApi.pigeonChannelCodec.encodeMessage(
            <Object?>[false],
          )!;
      messenger.handlePlatformMessage(
        'dev.flutter.pigeon.nexora.NotificationEventsApi.onPermissionResult.$suffix',
        eventMessage,
        (ByteData? _) {},
      );

      expect(await resultFuture, isFalse);
    },
  );
}
