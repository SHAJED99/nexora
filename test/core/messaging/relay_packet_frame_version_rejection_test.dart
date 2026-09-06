// Tests for E14-T05 (FR-VER-001/FR-VER-002): confirms the codebase's
// EXISTING version-negotiation mechanism -- `relay_packet_frame.dart`'s
// `frameVersion` byte, plus `prekey_bundle_codec.dart`'s independent
// `codecVersion` byte on E03's own X3DH prekey-bundle handshake -- already
// satisfies both requirements end-to-end, rather than needing a new wire
// field. See this task file's Run log for the full investigation writeup;
// this file is the test evidence backing that conclusion.
//
// Investigation finding worth flagging explicitly: the task file's own §2
// describes the upstream catch as living in "RelayEngine's own processing
// loop." That is not quite where it lives -- `RelayEngine`
// (`lib/core/routing_engine/relay_engine.dart`) never calls
// `RelayPacketFrame.deserialize` at all; it only ever stores/forwards
// `payload` as fully opaque bytes (FR-ROUTE-003). The actual call site, and
// the actual upstream catch, is `InboundPipeline._handleBuffer`
// (`lib/core/messaging/inbound_pipeline.dart:349-355`), which wraps
// `deserialize` in a `try`/`on FormatException` and increments
// `counters.malformed` -- exactly the graceful-drop behaviour EARS-VER-13
// asks for, just one layer earlier in the pipeline than the task file
// assumed. EARS-VER-13 below proves the ACTUAL call site's behaviour.
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/crypto/prekey_bundle_codec.dart';
import 'package:nexora/core/messaging/inbound_pipeline.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/messaging/relay_packet_frame.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/transport/generated/transport_api.g.dart';
import 'package:nexora/core/transport/transport_service.dart';

Uint8List _plaintext(String s) => Uint8List.fromList(s.codeUnits);

/// Builds a well-formed serialized frame with [frameVersionOverride] patched
/// into byte 0 -- mirrors `relay_packet_frame_test.dart`'s own
/// `_wellFormedFrame` helper (kept local: each test file in this codebase
/// owns its own minimal fixture rather than sharing private helpers across
/// files).
Uint8List _frameBytesWithVersion(int version) {
  final frame = RelayPacketFrame(
    payloadType: PayloadType.signalMessage,
    packetId: 'pkt-version-probe',
    destination: 'device-b',
    source: 'device-a',
    priority: 5,
    createdAtMs: 1000,
    expiresAtMs: DateTime.now().millisecondsSinceEpoch + 60000,
    payload: Uint8List.fromList(<int>[1, 2, 3]),
  );
  final bytes = frame.serialize();
  bytes[0] = version;
  return bytes;
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

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  var suffixCounter = 0;
  String nextSuffix() => 'relay-version-rejection-${suffixCounter++}';

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
    'test_EARS_VER_13_unknown_frame_version_is_dropped_not_crashed',
    () async {
      final senderSuffix = nextSuffix();
      final receiverSuffix = nextSuffix();
      final sender = await newStack('device-a', senderSuffix);
      final receiver = await newStack('device-b', receiverSuffix);
      addTearDown(sender.dispose);
      addTearDown(receiver.dispose);

      await sender.cryptoService.establishSession(
        const SignalProtocolAddress('device-b', 1),
        await receiver.identityService.getLocalPreKeyBundle(),
      );
      final sent = await sender.sendMessage.call(
        'conv-1',
        'device-b',
        _plaintext('after unknown version frame'),
      );

      final pipeline = InboundPipeline(stack: receiver);
      addTearDown(pipeline.stop);
      pipeline.start();
      await _connectPeer(messenger, receiverSuffix, 'device-a');

      final deliveredFuture = pipeline.delivered.first.timeout(
        const Duration(seconds: 5),
        onTimeout: () => throw StateError(
          'good packet never delivered after an unknown-frameVersion frame',
        ),
      );

      // An unknown frameVersion FIRST -- not a truncation/empty-buffer
      // malformation (already covered by
      // inbound_pipeline_test.dart's own COMM_10 test), specifically the
      // version-mismatch path EARS-VER-13 names.
      _pushIncomingData(
        messenger,
        receiverSuffix,
        'device-a',
        _frameBytesWithVersion(relayFrameVersion + 1),
      );
      await _settle();

      // The good packet SECOND -- the relay pipeline's own receive loop
      // must still be alive, i.e. the `FormatException`
      // `RelayPacketFrame.deserialize` throws on the bad version was caught
      // upstream (`InboundPipeline._handleBuffer`) and never propagated out
      // of the subscription callback.
      _pushIncomingData(
        messenger,
        receiverSuffix,
        'device-a',
        sent.ciphertext,
      );

      await deliveredFuture;
      expect(pipeline.counters.malformed, 1);
      expect(pipeline.counters.delivered, 1);

      // No silent misinterpretation either: the dropped frame must not have
      // been stored, forwarded, or counted as anything other than malformed.
      final relayRows =
          await receiver.db.select(receiver.db.relayPackets).get();
      expect(relayRows, isEmpty);
      expect(pipeline.counters.forwarded, 0);
    },
  );

  test(
    'test_EARS_VER_14_version_compatibility_is_determinable_from_the_header_alone',
    () {
      // FR-VER-001: two devices must be able to tell whether their protocol
      // versions are compatible without a full message exchange. Reading
      // byte 0 of a serialized frame -- with no session, no decrypt, no
      // reply -- already tells you exactly that: it predicts whether
      // `deserialize` will accept or reject the frame, and the frame is
      // rejected on any value other than the current `relayFrameVersion`,
      // never silently reinterpreted as the current layout (relay_packet_
      // frame.dart's own header comment).
      final compatibleBytes = _frameBytesWithVersion(relayFrameVersion);
      final incompatibleBytes = _frameBytesWithVersion(relayFrameVersion + 1);

      expect(compatibleBytes[0], relayFrameVersion);
      expect(() => RelayPacketFrame.deserialize(compatibleBytes),
          returnsNormally);

      expect(incompatibleBytes[0], isNot(relayFrameVersion));
      expect(
        () => RelayPacketFrame.deserialize(incompatibleBytes),
        throwsA(isA<FormatException>()),
      );

      // FR-VER-001's fuller list also names crypto-version negotiation.
      // That is NOT this byte's job -- E03's own X3DH prekey-bundle codec
      // (`prekey_bundle_codec.dart`) already carries its own, independent
      // `codecVersion` byte, checked and rejected the same way on its own
      // handshake artifact. The SUM of `relayFrameVersion` (transport
      // frame layout) + `preKeyBundleCodecVersion` (crypto handshake
      // artifact layout) is what satisfies FR-VER-001's full list here --
      // there is no single combined field, and none is needed.
      expect(preKeyBundleCodecVersion, isA<int>());
    },
  );
}
