// Tests for E13-T05's byte-volume admission gate (EARS-ABUSE-10/11).
//
// This task's own §3 originally assumed the check belonged inside
// `RelayEngine.enqueue`, but `E13-T03` already discovered (and this task's
// header/Run log records) that `RelayEngine.enqueue` has no sender-identity
// parameter to key a per-sender check on at all. The real admission call
// site both tasks share is `InboundPipeline._handleBuffer`'s forward branch
// (`!isForUs`), keyed by the wire frame's claimed `frame.source` -- exactly
// where `E13-T03`'s own count-based gate already lives
// (`inbound_pipeline_rate_limit_test.dart`). This file adds a SECOND,
// independent `RateLimiter.allow` check there (byte-volume, not count),
// proving it is denied/admitted independently of T03's own count gate.
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
  int payloadLen = 4,
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
    payload: Uint8List.fromList(List<int>.filled(payloadLen, 0x40)),
  );
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  var suffixCounter = 0;
  String nextSuffix() => 'storage-admission-ratelimit-${suffixCounter++}';

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
    'test_EARS_ABUSE_10_oversized_inbound_volume_denied_independent_of_count',
    () async {
      final suffix = nextSuffix();
      final receiver = await newStack('device-b', suffix);
      addTearDown(receiver.dispose);

      final pipeline = InboundPipeline(stack: receiver);
      addTearDown(pipeline.stop);
      pipeline.start();
      await _connectPeer(messenger, suffix, 'device-a');

      // Pre-seed the byte-volume bucket AT this task's own configured
      // maxCount (see inbound_pipeline.dart's `_storageVolumeRateLimitMaxBytes`)
      // so the very next real admission check this test triggers denies --
      // same seeding technique `inbound_pipeline_rate_limit_test.dart` uses
      // for T03's own count bucket, applied to the DISTINCT
      // `storage_volume:` bucket key this task adds.
      await receiver.db
          .into(receiver.db.rateLimitCounters)
          .insert(
            RateLimitCountersCompanion.insert(
              bucketKey: 'storage_volume:device-a',
              windowStartMs: DateTime.now().millisecondsSinceEpoch,
              count: 5 * 1024 * 1024, // 5 MiB, this task's chosen budget
            ),
          );

      // Well under T03's own count limit (60/min) -- a single frame -- so a
      // denial here can only be this task's own byte-volume gate, not T03's.
      final frame = _foreignFrame(
        packetId: 'pkt-oversized-1',
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
        reason:
            'a sender over its byte-volume budget must never reach the '
            'relay queue, even with a single small packet',
      );
      expect(pipeline.counters.forwarded, 0);
      expect(pipeline.counters.rateLimited, 1);
    },
  );

  test('test_EARS_ABUSE_11_under_byte_limit_behaves_unchanged', () async {
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

    final relayRows = await receiver.db.select(receiver.db.relayPackets).get();
    expect(relayRows, hasLength(1));
    expect(relayRows.single.destinationId, 'device-c');
    expect(pipeline.counters.forwarded, 1);
    expect(pipeline.counters.rateLimited, 0);
  });

  test('test_storage_volume_limit_independent_of_relay_count_limit', () async {
    final suffix = nextSuffix();
    final receiver = await newStack('device-b', suffix);
    addTearDown(receiver.dispose);

    final pipeline = InboundPipeline(stack: receiver);
    addTearDown(pipeline.stop);
    pipeline.start();
    await _connectPeer(messenger, suffix, 'device-a');

    // device-a is already at T03's own count limit (60) but nowhere near
    // this task's byte-volume budget -- a single small frame passes the
    // byte-volume gate but must still be DENIED by T03's count gate, proving
    // the two gates are independent and ANY one denying is enough to reject
    // the forward.
    await receiver.db
        .into(receiver.db.rateLimitCounters)
        .insert(
          RateLimitCountersCompanion.insert(
            bucketKey: 'relay:device-a',
            windowStartMs: DateTime.now().millisecondsSinceEpoch,
            count: 60,
          ),
        );

    final countLimitedFrame = _foreignFrame(
      packetId: 'pkt-count-limited-1',
      source: 'device-a',
      destination: 'device-c',
      payloadLen: 4,
    );
    _pushIncomingData(
      messenger,
      suffix,
      'device-a',
      countLimitedFrame.serialize(),
    );
    await _settle();
    await _settle();

    expect(
      pipeline.counters.forwarded,
      0,
      reason:
          'passes this task\'s own byte-volume check but must still be '
          'denied by T03\'s independent count check -- neither gate '
          'substitutes for the other',
    );
    expect(pipeline.counters.rateLimited, 1);

    // A DIFFERENT claimed sender, device-x, is nowhere near EITHER limit --
    // proves this task's own bucket key is per-sender, like T03's.
    await _connectPeer(messenger, suffix, 'device-x');
    final okFrame = _foreignFrame(
      packetId: 'pkt-x-1',
      source: 'device-x',
      destination: 'device-c',
    );
    _pushIncomingData(messenger, suffix, 'device-x', okFrame.serialize());
    await _settle();
    await _settle();

    final relayRows = await receiver.db.select(receiver.db.relayPackets).get();
    expect(relayRows, hasLength(1));
    expect(relayRows.single.destinationId, 'device-c');
    expect(pipeline.counters.forwarded, 1);
  });

  test(
    'test_EARS_ABUSE_10_single_oversized_packet_denied_on_fresh_window',
    () async {
      // Regression for the fail-open gap a cross-model review found:
      // `RateLimiter.allow`'s rollover branch (no existing bucket row, or the
      // window has just elapsed) inserts `count: increment` and returns
      // `true` UNCONDITIONALLY, without ever comparing `increment` itself
      // against `maxCount`. A single packet far larger than the whole
      // per-minute budget was therefore admitted on the very first hit of
      // every rolling window. Unlike the other tests in this file, this one
      // does NOT pre-seed `storage_volume:device-a` -- the bucket is
      // genuinely fresh, which is exactly the state that let the bug through.
      final suffix = nextSuffix();
      final receiver = await newStack('device-b', suffix);
      addTearDown(receiver.dispose);

      final pipeline = InboundPipeline(stack: receiver);
      addTearDown(pipeline.stop);
      pipeline.start();
      await _connectPeer(messenger, suffix, 'device-a');

      // 6 MiB: bigger than the entire 5 MiB/minute budget, sent as a single
      // packet on a brand-new bucket.
      final frame = _foreignFrame(
        packetId: 'pkt-fresh-oversized-1',
        source: 'device-a',
        destination: 'device-c',
        payloadLen: 6 * 1024 * 1024,
      );
      _pushIncomingData(messenger, suffix, 'device-a', frame.serialize());
      await _settle();
      await _settle();

      final relayRows =
          await receiver.db.select(receiver.db.relayPackets).get();
      expect(
        relayRows,
        isEmpty,
        reason:
            'a single packet larger than the whole byte-volume budget must '
            'never be admitted, even on a fresh/rolled-over bucket',
      );
      expect(pipeline.counters.forwarded, 0);
      expect(pipeline.counters.rateLimited, 1);
    },
  );
}
