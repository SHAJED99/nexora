// Tests for InboundPipeline's E13-T03 relay-flooding admission gate
// (EARS-ABUSE-6/7), resolving `Q-E13-T03-1`: the gate lives in this file's
// forward branch (`!isForUs`), keyed by the wire frame's claimed
// `frame.source`, checked via `RateLimiter.allow` BEFORE
// `RelayEngine.enqueue` is ever called -- not inside `RelayEngine` itself,
// which has no sender-identity parameter or column to gate on (see the task
// file's Open Questions for why).
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/messaging/inbound_pipeline.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/messaging/relay_packet_frame.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/transport/generated/transport_api.g.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:flutter/services.dart';

/// Pushes a simulated inbound wire buffer directly, bypassing discovery --
/// mirrors `inbound_pipeline_test.dart`'s own native-boundary pattern for
/// the parts of that harness this test file also needs.
void _pushDiscovered(
  TestDefaultBinaryMessenger messenger,
  String suffix,
  String deviceId,
) {
  final device = TransportDevice(
    id: deviceId,
    displayName: deviceId,
    type: TransportType.bluetooth,
  );
  final ByteData message =
      TransportEventsApi.pigeonChannelCodec.encodeMessage(<Object?>[device])!;
  messenger.handlePlatformMessage(
    'dev.flutter.pigeon.nexora.TransportEventsApi.onDeviceDiscovered.$suffix',
    message,
    (ByteData? _) {},
  );
}

void _pushConnectionState(
  TestDefaultBinaryMessenger messenger,
  String suffix,
  String deviceId,
  ConnectionState state,
) {
  final ByteData message = TransportEventsApi.pigeonChannelCodec
      .encodeMessage(<Object?>[deviceId, state])!;
  messenger.handlePlatformMessage(
    'dev.flutter.pigeon.nexora.TransportEventsApi.onConnectionStateChanged.$suffix',
    message,
    (ByteData? _) {},
  );
}

void _pushIncomingData(
  TestDefaultBinaryMessenger messenger,
  String suffix,
  String deviceId,
  Uint8List bytes,
) {
  final ByteData message = TransportEventsApi.pigeonChannelCodec
      .encodeMessage(<Object?>[deviceId, bytes])!;
  messenger.handlePlatformMessage(
    'dev.flutter.pigeon.nexora.TransportEventsApi.onDataReceived.$suffix',
    message,
    (ByteData? _) {},
  );
}

Future<void> _settle() async {
  await Future<void>.delayed(const Duration(milliseconds: 5));
}

Future<void> _connectPeer(
  TestDefaultBinaryMessenger messenger,
  String suffix,
  String deviceId,
) async {
  _pushDiscovered(messenger, suffix, deviceId);
  await _settle();
  _pushConnectionState(messenger, suffix, deviceId, ConnectionState.connected);
  await _settle();
}

RelayPacketFrame _foreignFrame({
  required String packetId,
  required String source,
  required String destination,
}) {
  final now = DateTime.now().millisecondsSinceEpoch;
  return RelayPacketFrame(
    payloadType: PayloadType.signalMessage,
    packetId: packetId,
    destination: destination,
    source: source,
    priority: 5,
    createdAtMs: now,
    expiresAtMs: now + 60000,
    payload: Uint8List.fromList(<int>[0x40, 0, 0, 0]),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  var suffixCounter = 0;
  String nextSuffix() => 'inbound-pipeline-ratelimit-${suffixCounter++}';

  Future<MessagingStack> newStack(String selfDeviceId, String suffix) async {
    final db = AppDatabase.forTesting(NativeDatabase.memory());
    final stack = await MessagingStack.create(
      db: db,
      selfDeviceId: selfDeviceId,
      transport: TransportService(
        binaryMessenger: messenger,
        messageChannelSuffix: suffix,
      ),
    );
    expect(stack.status, const MessagingStackStatus.ready());
    return stack;
  }

  test(
    'test_EARS_ABUSE_6_sender_over_relay_limit_is_denied_enqueue',
    () async {
      final suffix = nextSuffix();
      final receiver = await newStack('device-b', suffix);
      addTearDown(receiver.dispose);

      final pipeline = InboundPipeline(stack: receiver);
      addTearDown(pipeline.stop);
      pipeline.start();
      await _connectPeer(messenger, suffix, 'device-a');

      // Pre-seed the bucket AT the pipeline's own configured maxCount (60,
      // this task's chosen limit -- see inbound_pipeline.dart's
      // `_relayRateLimitMaxCount`) so the very next real admission check
      // this test triggers denies. Written directly against the shared
      // `rate_limit_counters` table rather than through `RateLimiter.allow`
      // with a different `maxCount`, since the stored row has no memory of
      // which `maxCount` was used to write it -- only `count`/`windowStartMs`
      // persist, and the pipeline's own call always passes 60.
      await receiver.db
          .into(receiver.db.rateLimitCounters)
          .insert(
            RateLimitCountersCompanion.insert(
              bucketKey: 'relay:device-a',
              windowStartMs: DateTime.now().millisecondsSinceEpoch,
              count: 60,
            ),
          );

      final frame = _foreignFrame(
        packetId: 'pkt-flood-1',
        source: 'device-a',
        destination: 'device-c',
      );
      _pushIncomingData(messenger, suffix, 'device-a', frame.serialize());
      await _settle();
      await _settle();

      final relayRows =
          await receiver.db.select(receiver.db.relayPackets).get();
      expect(
        relayRows,
        isEmpty,
        reason: 'a rate-limited sender must never reach the relay queue',
      );
      expect(pipeline.counters.forwarded, 0);
      expect(pipeline.counters.rateLimited, 1);
    },
  );

  test(
    'test_EARS_ABUSE_7_sender_under_limit_enqueues_normally',
    () async {
      final suffix = nextSuffix();
      final receiver = await newStack('device-b', suffix);
      addTearDown(receiver.dispose);

      final pipeline = InboundPipeline(stack: receiver);
      addTearDown(pipeline.stop);
      pipeline.start();
      await _connectPeer(messenger, suffix, 'device-a');

      final frame = _foreignFrame(
        packetId: 'pkt-normal-1',
        source: 'device-a',
        destination: 'device-c',
      );
      _pushIncomingData(messenger, suffix, 'device-a', frame.serialize());
      await _settle();
      await _settle();

      final relayRows =
          await receiver.db.select(receiver.db.relayPackets).get();
      expect(relayRows, hasLength(1));
      expect(relayRows.single.destinationId, 'device-c');
      expect(pipeline.counters.forwarded, 1);
      expect(pipeline.counters.rateLimited, 0);
    },
  );

  test(
    'test_relay_rate_limit_is_independent_per_sender',
    () async {
      final suffix = nextSuffix();
      final receiver = await newStack('device-b', suffix);
      addTearDown(receiver.dispose);

      final pipeline = InboundPipeline(stack: receiver);
      addTearDown(pipeline.stop);
      pipeline.start();
      await _connectPeer(messenger, suffix, 'device-a');
      await _connectPeer(messenger, suffix, 'device-x');

      // device-a is already over its own limit (same seeding technique as
      // the EARS-ABUSE-6 test above) ...
      await receiver.db
          .into(receiver.db.rateLimitCounters)
          .insert(
            RateLimitCountersCompanion.insert(
              bucketKey: 'relay:device-a',
              windowStartMs: DateTime.now().millisecondsSinceEpoch,
              count: 60,
            ),
          );
      final overLimitFrame = _foreignFrame(
        packetId: 'pkt-a-1',
        source: 'device-a',
        destination: 'device-c',
      );
      _pushIncomingData(
        messenger,
        suffix,
        'device-a',
        overLimitFrame.serialize(),
      );
      await _settle();
      await _settle();

      // ... but a DIFFERENT claimed sender, device-x, must be unaffected --
      // one global bucket per sender identity, not a single shared bucket.
      final otherSenderFrame = _foreignFrame(
        packetId: 'pkt-x-1',
        source: 'device-x',
        destination: 'device-c',
      );
      _pushIncomingData(
        messenger,
        suffix,
        'device-x',
        otherSenderFrame.serialize(),
      );
      await _settle();
      await _settle();

      final relayRows =
          await receiver.db.select(receiver.db.relayPackets).get();
      expect(relayRows, hasLength(1));
      expect(relayRows.single.payload, otherSenderFrame.serialize());
      expect(pipeline.counters.forwarded, 1);
      expect(pipeline.counters.rateLimited, 1);
    },
  );
}
