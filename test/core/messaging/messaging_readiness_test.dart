// core/messaging — E01-B01 findings 2+3: the mid-session identity arrival.
//
// The invariant these tests exist for, stated once: `MessagingReadiness`
// must NEVER publish `ready` while the registered `MessagingStack` still
// carries the empty identity. Every other assertion here supports that one.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/core/messaging/messaging_readiness.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/messaging/domain/send_message_use_case.dart';

const _realDeviceId = 'device-after-sign-in';

void main() {
  // `MessagingStack.create` builds a `TransportService`, which registers a
  // Pigeon message handler -- so the test binding must exist, and each
  // stack needs its own channel suffix or the second registration clobbers
  // the first. Same setup `test/app/bindings_test.dart` already uses.
  TestWidgetsFlutterBinding.ensureInitialized();
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
  var suffixCounter = 0;

  TransportService newTransport() => TransportService(
        binaryMessenger: messenger,
        messageChannelSuffix: 'readiness-test-${suffixCounter++}',
      );

  late AppDatabase db;
  late MessagingStack launchStack;

  setUp(() async {
    Get.testMode = true;
    db = AppDatabase.forTesting(NativeDatabase.memory());
    // Exactly the launch-time shape E01-B01 describes: `main.dart` read no
    // identity, so the stack is built with an EMPTY `selfDeviceId` and
    // reports unavailable.
    launchStack = await MessagingStack.create(
      db: db,
      selfDeviceId: '',
      transport: newTransport(),
    );
    Get.put<MessagingStack>(launchStack, permanent: true);
  });

  tearDown(() async {
    Get.reset();
    await db.close();
  });

  MessagingReadiness build({
    CreateMessagingStack? createStack,
    List<String>? createdWith,
  }) =>
      MessagingReadiness(
        initialStatus: launchStack.status,
        createStack: createStack ??
            ({required db, required selfDeviceId, transport}) async {
              createdWith?.add(selfDeviceId);
              return MessagingStack.create(
                db: db,
                selfDeviceId: selfDeviceId,
                transport: newTransport(),
              );
            },
      );

  test('test_E01_B01_the_launch_stack_really_is_the_broken_one', () {
    // Guards the premise. If this ever fails, every test below is testing
    // a situation the app no longer gets into.
    expect(launchStack.selfDeviceId, isEmpty);
    expect(launchStack.status.isReady, isFalse);
    expect(
      (launchStack.status as MessagingStackStatusUnavailable).reason,
      contains('no local device identity'),
    );
  });

  test('test_E01_B01_identity_arrival_recreates_the_stack_with_the_real_id',
      () async {
    final createdWith = <String>[];
    final readiness = build(createdWith: createdWith);

    expect(readiness.status.value.isReady, isFalse);

    await readiness.onLocalIdentityProvisioned(_realDeviceId);

    expect(createdWith, [_realDeviceId]);
    // The REGISTERED stack -- not a local variable -- is the one that
    // matters: every route binding resolves it by `Get.find`.
    expect(Get.find<MessagingStack>().selfDeviceId, _realDeviceId);
    expect(
      identical(Get.find<MessagingStack>(), launchStack),
      isFalse,
      reason: 'the empty-identity stack must not still be the registered one',
    );
  });

  test('test_E01_B01_status_is_never_ready_while_the_stack_has_no_identity',
      () async {
    late MessagingStackStatus statusAtCreateTime;
    late String registeredIdAtCreateTime;

    final readiness = build(
      createStack: ({required db, required selfDeviceId, transport}) async {
        // Sampled at the one instant the old stack has been deleted and the
        // new one does not exist yet. If `status` had been flipped to ready
        // optimistically -- ahead of a successful re-create -- this is where
        // it would show.
        statusAtCreateTime = Get.find<MessagingReadiness>().status.value;
        registeredIdAtCreateTime = Get.isRegistered<MessagingStack>()
            ? Get.find<MessagingStack>().selfDeviceId
            : '<none>';
        return MessagingStack.create(
                db: db,
                selfDeviceId: selfDeviceId,
                transport: newTransport(),
              );
      },
    );
    Get.put<MessagingReadiness>(readiness);

    await readiness.onLocalIdentityProvisioned(_realDeviceId);

    expect(
      statusAtCreateTime.isReady,
      isFalse,
      reason: 'THE invariant: readiness must not report ready before a stack '
          'with the real identity exists',
    );
    expect(registeredIdAtCreateTime, '<none>');
    // And afterwards it reports the REPLACEMENT's status, not a guess.
    expect(readiness.status.value, Get.find<MessagingStack>().status);
  });

  test('test_E01_B01_a_failed_recreate_leaves_status_unavailable', () async {
    final readiness = build(
      createStack: ({required db, required selfDeviceId, transport}) async =>
          throw StateError('boom'),
    );

    await readiness.onLocalIdentityProvisioned(_realDeviceId);

    expect(
      readiness.status.value.isReady,
      isFalse,
      reason: 'a stack that could not be built must never read as ready',
    );
    expect(
      readiness.handled,
      isFalse,
      reason: 'a failure is not a handled transition -- a later trigger may '
          'legitimately retry',
    );
  });

  group('once only — no duplicate stacks, no leaked listeners', () {
    test('test_E01_B01_recreate_happens_exactly_once_for_the_transition',
        () async {
      final createdWith = <String>[];
      final readiness = build(createdWith: createdWith);

      await readiness.onLocalIdentityProvisioned(_realDeviceId);
      await readiness.onLocalIdentityProvisioned(_realDeviceId);
      await readiness.onLocalIdentityProvisioned(_realDeviceId);

      // A call counter, not `fail()` inside the seam: a `fail()` there is
      // swallowed by the caller's broad catch.
      expect(createdWith, [_realDeviceId]);
      expect(readiness.handled, isTrue);

      // Honest note on this test's strength, found by falsifying it:
      // deleting the `_handled` guard does NOT make it fail, because the
      // second call then hits the "stack already has this identity" branch
      // and returns without creating. Two independent guards protect the
      // sequential case. The guard that only the CONCURRENT test can catch
      // is `_inFlight` -- see the next test, which does fail without it
      // (three stacks instead of one).
    });

    test('test_E01_B01_concurrent_calls_do_not_build_two_stacks', () async {
      final createdWith = <String>[];
      final readiness = build(
        createStack: ({required db, required selfDeviceId, transport}) async {
          createdWith.add(selfDeviceId);
          // A real `create` is asynchronous; the second caller must land
          // while the first is still inside it. `_handled` alone is set too
          // late to stop that, which is why the in-flight future exists.
          await Future<void>.delayed(const Duration(milliseconds: 20));
          return MessagingStack.create(
                db: db,
                selfDeviceId: selfDeviceId,
                transport: newTransport(),
              );
        },
      );

      await Future.wait([
        readiness.onLocalIdentityProvisioned(_realDeviceId),
        readiness.onLocalIdentityProvisioned(_realDeviceId),
        readiness.onLocalIdentityProvisioned(_realDeviceId),
      ]);

      expect(
        createdWith,
        [_realDeviceId],
        reason: 'three concurrent notifications, one stack',
      );
    });

    test('test_E01_B01_the_previous_stack_is_deregistered_not_leaked',
        () async {
      // Renamed from "..._is_disposed_...": the fix deliberately does NOT
      // call `dispose()`. That is sign-OUT's teardown and it closes the
      // shared `AppDatabase` and the transport, both of which the
      // replacement inherits. What must be true is narrower and is what
      // this asserts: the old stack is unreachable, and the shared
      // resources survive.
      final readiness = build();
      await readiness.onLocalIdentityProvisioned(_realDeviceId);

      expect(
        identical(Get.find<MessagingStack>(), launchStack),
        isFalse,
        reason: 'nothing may resolve the empty-identity stack any more',
      );
      await expectLater(
        db.latestDeviceIdentity(),
        completes,
        reason: 'the shared database must NOT have been closed',
      );
    });

    test('test_E01_B01_a_stack_that_already_has_the_identity_is_left_alone',
        () async {
      // The common case: a returning device had its identity at launch.
      // Tearing down a correct, live stack would drop its subscriptions
      // for nothing.
      await Get.find<MessagingStack>().dispose();
      Get.delete<MessagingStack>(force: true);
      final good = await MessagingStack.create(
        db: db,
        selfDeviceId: _realDeviceId,
        transport: newTransport(),
      );
      Get.put<MessagingStack>(good, permanent: true);

      final createdWith = <String>[];
      final readiness = MessagingReadiness(
        initialStatus: good.status,
        createStack: ({required db, required selfDeviceId, transport}) async {
          createdWith.add(selfDeviceId);
          return MessagingStack.create(
                db: db,
                selfDeviceId: selfDeviceId,
                transport: newTransport(),
              );
        },
      );

      await readiness.onLocalIdentityProvisioned(_realDeviceId);

      expect(createdWith, isEmpty);
      expect(identical(Get.find<MessagingStack>(), good), isTrue);
      expect(readiness.status.value, good.status);
    });

    test('test_E01_B01_an_empty_device_id_is_a_no_op', () async {
      final createdWith = <String>[];
      final readiness = build(createdWith: createdWith);

      await readiness.onLocalIdentityProvisioned('');

      expect(createdWith, isEmpty);
      expect(readiness.handled, isFalse);
      expect(identical(Get.find<MessagingStack>(), launchStack), isTrue);
    });
  });

  group('the REAL default factory — no injected createStack', () {
    // Review finding, and the reason this group exists: every other test in
    // this file injects `createStack`, so none of them ever ran the code
    // path `lib/app/main.dart` actually constructs. The first draft of this
    // fix called `existing.dispose()`, which closes the single app-wide
    // `AppDatabase`, and then handed that closed database to the
    // replacement. `MessagingStack.create` swallows the resulting failure
    // into an `unavailable` status instead of throwing, so the bug looked
    // like a success. Nine green tests did not see it.

    test('test_E01_B01_the_real_factory_leaves_the_shared_database_usable',
        () async {
      final readiness = MessagingReadiness(initialStatus: launchStack.status);

      await readiness.onLocalIdentityProvisioned(_realDeviceId);

      // The assertion the first draft would have failed on: the shared
      // database must still be open and usable by every other feature.
      await expectLater(db.latestDeviceIdentity(), completes);

      final registered = Get.find<MessagingStack>();
      expect(registered.selfDeviceId, _realDeviceId);
      expect(
        identical(registered.db, db),
        isTrue,
        reason: 'the replacement must inherit the ONE shared AppDatabase, '
            'never open a second',
      );
      expect(
        identical(registered.transport, launchStack.transport),
        isTrue,
        reason: 'a second TransportService on the same channel suffix '
            'silently steals the native handlers (bindings.dart, E06-B02)',
      );
    });

    test('test_E01_B01_the_real_factory_rewires_the_identity_capturing_uses',
        () async {
      // `SendMessageUseCase` captures `selfDeviceId` at construction and is
      // registered by `AppBinding` as its own permanent singleton. If the
      // re-create replaced only the `MessagingStack` registration, this
      // would still be the empty-identity instance -- an app that looks
      // fixed and cannot send.
      Get.put<SendMessageUseCase>(launchStack.sendMessage, permanent: true);
      final before = Get.find<SendMessageUseCase>();

      final readiness = MessagingReadiness(initialStatus: launchStack.status);
      await readiness.onLocalIdentityProvisioned(_realDeviceId);

      expect(
        identical(Get.find<SendMessageUseCase>(), before),
        isFalse,
        reason: 'the send path must be rebuilt from the real device id',
      );
      expect(
        identical(
          Get.find<SendMessageUseCase>(),
          Get.find<MessagingStack>().sendMessage,
        ),
        isTrue,
      );
    });

    test('test_E01_B01_a_replacement_that_is_not_ready_does_not_latch',
        () async {
      // Latching on a non-ready replacement is what made the first draft
      // give up permanently after a failure it had not noticed.
      final readiness = MessagingReadiness(
        initialStatus: launchStack.status,
        createStack: ({required db, required selfDeviceId, transport}) async =>
            MessagingStack.create(
          db: db,
          // An empty id is the one input that reliably yields `unavailable`
          // without any error being thrown.
          selfDeviceId: '',
          transport: transport,
        ),
      );

      await readiness.onLocalIdentityProvisioned(_realDeviceId);

      expect(readiness.status.value.isReady, isFalse);
      expect(
        readiness.handled,
        isFalse,
        reason: 'an unavailable replacement is not a handled transition',
      );
    });
  });
}
