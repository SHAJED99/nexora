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

  test(
    'test_EARS_PLAT_5_ensureReady_repeated_calls_forward_once_each_and_'
    'never_re_request_already_granted_permission',
    () async {
      // F4 (E10-B07): the previous version of this test called itself
      // "channels_created_once_per_category" and asserted
      // `ensureChannelsCallCount == 3` after three `ensureReady()` calls --
      // which is true of ANY host, including one that creates zero
      // channels or ten duplicates per category: it proves a Dart method
      // forwards a call, nothing about "exactly one channel per category,
      // idempotently".
      //
      // Per-category channel creation and true Android-side idempotency
      // (a re-declared channel with an unchanged id is a no-op, importance
      // cannot be raised after creation) are native
      // (`NotificationChannels.kt`) and are UNVERIFIED IN THIS ENVIRONMENT
      // -- no installable device, the standing `E04-T03b` no-mock-Kotlin
      // limitation (this file's own header already disclosed this; the
      // old test's name did not).
      //
      // What IS genuinely Dart-owned in `ensureReady()`
      // (`notification_service.dart:100-101`:
      // `if (await _api.hasPermission()...) return true;`, returning
      // BEFORE `requestPermission()` is ever reached) and is proven here,
      // falsifiably: when permission is already granted, repeated
      // `ensureReady()` calls forward exactly one `ensureChannels` host
      // call each (no accumulation, no skipped calls) and NEVER call
      // `requestPermission` at all -- "repeated calls are safe" means no
      // duplicate permission prompt, not merely "returns true again".
      const String suffix = 'channels';
      final NotificationService service = NotificationService(
        binaryMessenger: messenger,
        messageChannelSuffix: suffix,
      );
      addTearDown(service.dispose);

      int ensureChannelsCallCount = 0;
      int requestPermissionCallCount = 0;
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
      messenger.setMockMessageHandler(
        'dev.flutter.pigeon.nexora.NotificationApi.requestPermission.$suffix',
        (ByteData? message) async {
          requestPermissionCallCount++;
          return NotificationApi.pigeonChannelCodec.encodeMessage(
            <Object?>[null],
          );
        },
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
      // Already-granted permission must never be re-requested -- this is
      // the actual "repeated calls are safe" guarantee the Dart layer owns.
      expect(requestPermissionCallCount, 0);
    },
  );

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
      // E10-B10: with NO mock handler registered for ensureChannels, the
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
      // E10-B10: hasPermission() reports false (not yet granted) and
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
    'test_EARS_PLAT_5_ensureReady_returns_false_and_leaves_no_unhandled_'
    'error_when_requestPermission_itself_fails',
    () async {
      // E10-B10 round 2 (Opus review): a distinct third failure path from
      // the two above -- hasPermission() reports false, then
      // requestPermission() ITSELF throws/times out (no mock handler
      // registered here, so the real Pigeon call throws a
      // PlatformException) while `permissionResults.first`'s Future is
      // still unresolved. Round 1 of this fix applied `.timeout()`
      // directly to that unresolved Future before it was ever awaited --
      // abandoning it mid-flight with its own live timeout Timer still
      // running, which fired as an unhandled asynchronous error ~50ms
      // later with nothing left to catch it. The fix moves `.timeout()`
      // to the actual await site. This test cannot observe the leaked
      // error directly (it would surface as a top-level zone error, not
      // a rethrow here) -- it instead proves ensureReady() itself
      // returns false promptly, and relies on `flutter test`'s own
      // process-wide detection of any unhandled async error to catch a
      // regression (the exact mechanism that caught round 1's defect
      // during review).
      const String suffix = 'requestpermissionfails';
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
      // Deliberately no mock handler for requestPermission -- the real
      // Pigeon call throws PlatformException. Deliberately no
      // onPermissionResult event either.

      final bool result = await service.ensureReady();

      expect(result, isFalse);

      // Outlive the abandoned Future's would-be timeout window (round 1's
      // defect fired here) so a regression has a chance to surface before
      // this test (and its handler) tears down.
      await Future<void>.delayed(const Duration(milliseconds: 150));
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
