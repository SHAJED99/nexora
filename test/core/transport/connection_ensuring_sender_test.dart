// core/transport -- ConnectionEnsuringSender tests (E04-B05,
// EARS-TRANSPORT-3).
import 'dart:async';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/transport/connection_ensuring_sender.dart';

void main() {
  group('test_E04_B05_connects_before_sending', () {
    test('a send to a device with no prior connection calls connect() '
        'first, then send()', () async {
      final calls = <String>[];
      final sender = ConnectionEnsuringSender(
        connect: (deviceId) async {
          calls.add('connect:$deviceId');
          return true;
        },
        send: (deviceId, bytes) async {
          calls.add('send:$deviceId');
          return true;
        },
      );

      final result = await sender.ensureConnectedAndSend(
        'peer-1',
        Uint8List.fromList([1, 2, 3]),
      );

      expect(result, isTrue);
      expect(calls, ['connect:peer-1', 'send:peer-1']);
    });

    test('a second send to the SAME already-connected device does not '
        'call connect() again', () async {
      var connectCalls = 0;
      final sender = ConnectionEnsuringSender(
        connect: (deviceId) async {
          connectCalls++;
          return true;
        },
        send: (deviceId, bytes) async => true,
      );

      await sender.ensureConnectedAndSend(
        'peer-1',
        Uint8List.fromList([1]),
      );
      await sender.ensureConnectedAndSend(
        'peer-1',
        Uint8List.fromList([2]),
      );

      expect(connectCalls, 1);
    });

    test('a connect() failure returns false without ever calling send()',
        () async {
      var sendCalled = false;
      final sender = ConnectionEnsuringSender(
        connect: (deviceId) async => false,
        send: (deviceId, bytes) async {
          sendCalled = true;
          return true;
        },
      );

      final result = await sender.ensureConnectedAndSend(
        'peer-1',
        Uint8List.fromList([1]),
      );

      expect(result, isFalse);
      expect(sendCalled, isFalse);
    });

    test(
        'a connect() that throws is treated as a failed connection, never '
        'propagates', () async {
      final sender = ConnectionEnsuringSender(
        connect: (deviceId) async => throw Exception('native channel error'),
        send: (deviceId, bytes) async => true,
      );

      await expectLater(
        sender.ensureConnectedAndSend('peer-1', Uint8List.fromList([1])),
        completion(isFalse),
      );
    });

    test('two concurrent sends to the SAME new device coalesce into one '
        'connect() call, not two', () async {
      var connectCalls = 0;
      final connectCompleter = Completer<bool>();
      final sender = ConnectionEnsuringSender(
        connect: (deviceId) {
          connectCalls++;
          return connectCompleter.future;
        },
        send: (deviceId, bytes) async => true,
      );

      final first = sender.ensureConnectedAndSend(
        'peer-1',
        Uint8List.fromList([1]),
      );
      final second = sender.ensureConnectedAndSend(
        'peer-1',
        Uint8List.fromList([2]),
      );

      // Let both calls reach _ensureConnected before the connect settles.
      await Future<void>.delayed(Duration.zero);
      expect(
        connectCalls,
        1,
        reason: 'the second call must wait on the first in-flight connect, '
            'not start its own',
      );

      connectCompleter.complete(true);
      final results = await Future.wait([first, second]);
      expect(results, [true, true]);
    });

    test('a failed send forgets the connection, so the NEXT send '
        'reconnects rather than repeating the same failure forever',
        () async {
      var connectCalls = 0;
      var sendCalls = 0;
      final sender = ConnectionEnsuringSender(
        connect: (deviceId) async {
          connectCalls++;
          return true;
        },
        send: (deviceId, bytes) async {
          sendCalls++;
          return false; // simulates a dead/closed socket
        },
      );

      await sender.ensureConnectedAndSend('peer-1', Uint8List.fromList([1]));
      await sender.ensureConnectedAndSend('peer-1', Uint8List.fromList([2]));

      expect(sendCalls, 2);
      expect(
        connectCalls,
        2,
        reason: 'a failed send must clear the connected-device bookkeeping '
            'so the next attempt reconnects instead of trusting a dead '
            'socket',
      );
    });

    test('a send() that throws also forgets the connection', () async {
      var connectCalls = 0;
      var throwOnSend = true;
      final sender = ConnectionEnsuringSender(
        connect: (deviceId) async {
          connectCalls++;
          return true;
        },
        send: (deviceId, bytes) async {
          if (throwOnSend) throw Exception('socket write failed');
          return true;
        },
      );

      final firstResult =
          await sender.ensureConnectedAndSend('peer-1', Uint8List.fromList([1]));
      expect(firstResult, isFalse);

      throwOnSend = false;
      final secondResult =
          await sender.ensureConnectedAndSend('peer-1', Uint8List.fromList([2]));
      expect(secondResult, isTrue);
      expect(
        connectCalls,
        2,
        reason: 'the throwing send must also clear connected-device '
            'bookkeeping, same as a send that returns false',
      );
    });

    test('independent devices connect independently — one device\'s '
        'connection state never affects another\'s', () async {
      final connectedTo = <String>[];
      final sender = ConnectionEnsuringSender(
        connect: (deviceId) async {
          connectedTo.add(deviceId);
          return true;
        },
        send: (deviceId, bytes) async => true,
      );

      await sender.ensureConnectedAndSend('peer-1', Uint8List.fromList([1]));
      await sender.ensureConnectedAndSend('peer-2', Uint8List.fromList([1]));
      await sender.ensureConnectedAndSend('peer-1', Uint8List.fromList([2]));

      expect(connectedTo, ['peer-1', 'peer-2']);
    });

    test(
        'a connect() that never settles times out instead of wedging the '
        'coalescing map forever (review finding, E04-B05)', () async {
      var connectCalls = 0;
      final sender = ConnectionEnsuringSender(
        connect: (deviceId) {
          connectCalls++;
          return Completer<bool>().future; // never completes
        },
        send: (deviceId, bytes) async => true,
        connectTimeout: const Duration(milliseconds: 10),
      );

      final result = await sender.ensureConnectedAndSend(
        'peer-1',
        Uint8List.fromList([1]),
      );
      expect(result, isFalse);

      // The timed-out attempt must have cleared its own coalescing entry --
      // a second send to the same device tries again, it isn't wedged
      // waiting on the first (already-timed-out) future forever.
      await sender.ensureConnectedAndSend('peer-1', Uint8List.fromList([2]));
      expect(connectCalls, 2);
    });
  });
}
