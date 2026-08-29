// E05-T02 — SendMessageUseCase tests (FR-MSG-001/FR-MSG-005, EARS-MSG-1).
//
// Compose -> persist Queued -> encrypt (E03's CryptoService) -> enqueue
// (E04's RelayEngine) -> Sent/Failed. Tests use real `AppDatabase.forTesting`
// (in-memory Drift, per `NativeDatabase.memory()` — matches the pattern in
// `test/core/routing_engine/relay_engine_test.dart` and
// `test/core/crypto/crypto_service_test.dart`) with fake `MessageEncryptFn`/
// `MessageEnqueueFn` seams so this task's own logic (sequencing, state
// transitions, error surfacing) is what's under test — not E03/E04's
// internals, which already have their own test suites.
import 'dart:async';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/auth/google_auth_service.dart' show AppFailure;
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';
import 'package:nexora/features/messaging/domain/send_message_use_case.dart';

Uint8List _plaintext(String s) => Uint8List.fromList(s.codeUnits);

/// A fake `MessageEncryptFn` — this task's own contract only calls one
/// function (`encrypt`), so the fake only needs to honor that shape: either
/// return ciphertext bytes for a "sessioned" recipient, or throw the same
/// failure-shape E03-T03's real `CryptoService.encrypt` throws (`StateError`,
/// "no session") for one that isn't.
MessageEncryptFn _fakeEncryptor({
  Set<String>? sessionedRecipients,
  List<String>? calls,
}) {
  final sessioned = sessionedRecipients ?? {'recipient-with-session'};
  return (recipientDeviceId, plaintext) async {
    calls?.add(recipientDeviceId);
    if (!sessioned.contains(recipientDeviceId)) {
      throw StateError(
        'No session established with $recipientDeviceId. '
        'Call establishSession() first.',
      );
    }
    // A cheap, deterministic stand-in for real ciphertext bytes — never the
    // plaintext itself, so a test asserting "not plaintext" would catch a
    // wiring mistake that skipped encryption entirely.
    return Uint8List.fromList([0xFF, ...plaintext]);
  };
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test('test_EARS_MSG_1_compose_persists_as_queued_immediately', () async {
    // A relay that never resolves until released, so we can inspect the DB
    // row *before* enqueue() settles — proving composition/persistence is
    // synchronous-feeling and does not wait on the network/relay step.
    final gate = Completer<void>();
    var enqueueCalled = false;
    Future<String> slowEnqueue(
      String destination,
      Uint8List payload,
      int priority,
      Duration ttl,
    ) async {
      enqueueCalled = true;
      await gate.future;
      return 'relay-id';
    }

    final useCase = SendMessageUseCase(
      db: db,
      selfDeviceId: 'self',
      encrypt: _fakeEncryptor(),
      enqueue: slowEnqueue,
    );

    final pending = useCase.call(
      'conv-1',
      'recipient-with-session',
      _plaintext('hello'),
    );

    // Give the use case's synchronous-up-to-persist steps a chance to run
    // without waiting for the whole call to finish.
    await Future<void>.delayed(Duration.zero);
    expect(
      enqueueCalled,
      isTrue,
      reason: 'test setup: enqueue should have been reached',
    );

    final rows = await db.select(db.messages).get();
    expect(rows, hasLength(1));
    expect(rows.single.conversationId, 'conv-1');
    expect(rows.single.deliveryState, DeliveryState.queued.name);

    gate.complete();
    final message = await pending;
    expect(message.deliveryState, DeliveryState.sent);
  });

  test('test_EARS_MSG_1_successful_enqueue_transitions_to_sent', () async {
    final enqueuedPayloads = <Uint8List>[];
    Future<String> relay(
      String destination,
      Uint8List payload,
      int priority,
      Duration ttl,
    ) async {
      enqueuedPayloads.add(payload);
      return 'relay-id-${enqueuedPayloads.length}';
    }

    final useCase = SendMessageUseCase(
      db: db,
      selfDeviceId: 'self',
      encrypt: _fakeEncryptor(),
      enqueue: relay,
    );

    final message = await useCase.call(
      'conv-1',
      'recipient-with-session',
      _plaintext('hello'),
    );

    expect(message.deliveryState, DeliveryState.sent);
    expect(enqueuedPayloads, hasLength(1));
    // Never the plaintext bytes.
    expect(
      enqueuedPayloads.single,
      isNot(orderedEquals(_plaintext('hello'))),
    );

    final rows = await db.select(db.messages).get();
    expect(rows.single.deliveryState, DeliveryState.sent.name);
  });

  test('test_EARS_MSG_1_failed_enqueue_transitions_to_failed', () async {
    Future<String> failingRelay(
      String destination,
      Uint8List payload,
      int priority,
      Duration ttl,
    ) async {
      throw StateError('relay enqueue failed');
    }

    final useCase = SendMessageUseCase(
      db: db,
      selfDeviceId: 'self',
      encrypt: _fakeEncryptor(),
      enqueue: failingRelay,
    );

    final message = await useCase.call(
      'conv-1',
      'recipient-with-session',
      _plaintext('hello'),
    );

    expect(message.deliveryState, DeliveryState.failed);

    final rows = await db.select(db.messages).get();
    expect(rows, hasLength(1));
    expect(rows.single.deliveryState, DeliveryState.failed.name);
  });

  test('test_no_session_surfaces_app_failure_not_crash', () async {
    Future<String> relay(
      String destination,
      Uint8List payload,
      int priority,
      Duration ttl,
    ) async =>
        'relay-id';

    final useCase = SendMessageUseCase(
      db: db,
      selfDeviceId: 'self',
      encrypt: _fakeEncryptor(),
      enqueue: relay,
    );

    await expectLater(
      () => useCase.call(
        'conv-1',
        'recipient-without-session',
        _plaintext('hi'),
      ),
      throwsA(
        isA<AppFailure>().having((f) => f.code, 'code', 'messaging.no_session'),
      ),
    );

    // No row should be left dangling in an unresolved state -- either no
    // row was persisted for a session that never existed, or (if persisted)
    // it must not be stuck at Queued.
    final rows = await db.select(db.messages).get();
    for (final row in rows) {
      expect(row.deliveryState, isNot(DeliveryState.queued.name));
    }
  });

  test(
      'test_sequence_numbers_increase_monotonically_per_conversation',
      () async {
    Future<String> relay(
      String destination,
      Uint8List payload,
      int priority,
      Duration ttl,
    ) async =>
        'relay-id';

    final useCase = SendMessageUseCase(
      db: db,
      selfDeviceId: 'self',
      encrypt: _fakeEncryptor(),
      enqueue: relay,
    );

    final m1 = await useCase.call(
        'conv-1', 'recipient-with-session', _plaintext('a'));
    final m2 = await useCase.call(
        'conv-1', 'recipient-with-session', _plaintext('b'));
    final m3 = await useCase.call(
        'conv-1', 'recipient-with-session', _plaintext('c'));

    expect(m2.sequenceNumber, greaterThan(m1.sequenceNumber));
    expect(m3.sequenceNumber, greaterThan(m2.sequenceNumber));
  });

  test(
      'test_sequence_numbers_distinct_under_concurrent_sends_same_conversation',
      () async {
    // The real concurrency proof (L-backend-003 / task §6): two calls fired
    // without awaiting the first before starting the second, in the same
    // conversation. A naive read-then-write (MAX()+1) assignment would let
    // both read the same max and both write the same sequence_number --
    // this must not happen.
    Future<String> relay(
      String destination,
      Uint8List payload,
      int priority,
      Duration ttl,
    ) async =>
        'relay-id';

    final useCase = SendMessageUseCase(
      db: db,
      selfDeviceId: 'self',
      encrypt: _fakeEncryptor(),
      enqueue: relay,
    );

    final results = await Future.wait([
      useCase.call('conv-race', 'recipient-with-session', _plaintext('a')),
      useCase.call('conv-race', 'recipient-with-session', _plaintext('b')),
    ]);

    final sequenceNumbers = results.map((m) => m.sequenceNumber).toSet();
    expect(
      sequenceNumbers,
      hasLength(2),
      reason: 'two concurrent sends in the same conversation must get '
          'distinct sequence numbers, not a duplicate',
    );

    final rows = await (db.select(db.messages)
          ..where((t) => t.conversationId.equals('conv-race')))
        .get();
    expect(rows.map((r) => r.sequenceNumber).toSet(), hasLength(2));
  });

  test('test_sequence_numbers_independent_per_conversation', () async {
    Future<String> relay(
      String destination,
      Uint8List payload,
      int priority,
      Duration ttl,
    ) async =>
        'relay-id';

    final useCase = SendMessageUseCase(
      db: db,
      selfDeviceId: 'self',
      encrypt: _fakeEncryptor(),
      enqueue: relay,
    );

    final a1 = await useCase.call(
        'conv-a', 'recipient-with-session', _plaintext('a'));
    await useCase.call('conv-b', 'recipient-with-session', _plaintext('b'));
    final a2 = await useCase.call(
        'conv-a', 'recipient-with-session', _plaintext('c'));

    // Each conversation's sequence starts independently; conv-b's first
    // message existing must not perturb conv-a's numbering.
    expect(a2.sequenceNumber, greaterThan(a1.sequenceNumber));
  });
}
