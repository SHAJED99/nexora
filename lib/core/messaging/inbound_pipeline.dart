// core/messaging — the receive half of the wedge (E06-T05).
//
// `TransportService.incomingData(deviceId)` (`transport_service.dart:125`)
// yields raw `Uint8List` and, until this file, nothing subscribes to it.
// `ReceiveMessageUseCase.call(senderDeviceId, CiphertextMessage)`
// (`receive_message_use_case.dart:102`) has had no caller anywhere in
// `lib/` since the epic that built it landed. This file is where both of
// those stop being true.
//
// Every inbound buffer gets exactly one of two dispositions, decided by the
// wire frame's header alone (E06-T02's `RelayPacketFrame`):
//   - `frame.destination == selfDeviceId` -> decode the ciphertext by its
//     `payloadType` tag (`CiphertextCodec`, E06-T02), decrypt and persist it
//     (`ReceiveMessageUseCase`, E05-T03).
//   - otherwise -> FR-ROUTE-002 store-and-forward: hand the packet to
//     `RelayEngine.enqueue` and never look inside.
//
// **FR-ROUTE-003 is absolute on the second branch: a relay must never gain
// access to plaintext.** The forward branch below never reads
// `frame.payload`, never calls `CiphertextCodec.decode`, never calls
// `decrypt`, and never constructs a `Message` — the destination check
// (`isForUs`, computed immediately after `RelayPacketFrame.deserialize`)
// happens before `frame.payload` is bound to a local variable anywhere in
// this file, and the `return` at the end of the `!isForUs` block is
// textually BEFORE the only line in this file that reads `frame.payload`
// (self-review evidence: `grep -n "decode\|decrypt\|payload"` on this file
// shows every hit lives after that `return`, inside the addressed-to-us
// branch only). The forward branch re-enqueues the ORIGINAL bytes this
// device received off the wire — not `frame.payload`, not a re-serialized
// frame — so a forward is byte-preserving and a relay cannot alter what it
// did not read (task file §3).
//
// **The catch E03-B03 was deferred to.** E03's retro deferred the decrypt
// exception taxonomy "to whichever of E05/E06 first wraps a `catch` around
// `decrypt()`" — this is that `catch`. It matches E06-T02's
// `CryptoDecryptFailure` taxonomy: a bad packet (malformed frame,
// undecryptable ciphertext, unknown control sub-type) is logged as metadata
// (a counter, never plaintext/key material) and dropped; the subscription
// survives. A single malformed packet that kills the receive loop would be a
// trivial remote denial-of-service.
//
// **`ReceiveMessageUseCase` returning `null` is not an error** — it is the
// documented duplicate signal (FR-MSG-003) and will be the common case in a
// mesh that forwards the same packet down two paths. This pipeline treats it
// as a normal outcome (`counters.duplicate`), never as a failure.
//
// **Peer subscription lifecycle.** `TransportService` exposes no single
// "list of connected peers" — device ids are learned from
// `discoveredDevices`, and whether a given id is actually reachable is
// `connectionState(id)`'s job. This pipeline chains the two: a newly
// discovered id gets its own `connectionState` listener, and only a
// transition to `ConnectionState.connected` opens (idempotently) an
// `incomingData` subscription for that id; anything else closes it, so a
// peer that disconnects does not leak a subscription (§6 risk). A peer
// already connected before `start()` is called is necessarily missed — both
// `discoveredDevices` and `connectionState` are broadcast streams with no
// replay — which is why E06-T06 (not this task, per its own §4) owns when in
// the app's lifecycle `start()` is actually invoked.
//
// **Does NOT call `start()` itself** — E06-T06 owns that (task file §3/§5,
// this file's own `functions:` contract). Does NOT decide when
// `processQueue()`/`sweepExpired()`/`reclaimPayloads()` run — also T06. Does
// NOT modify `ReceiveMessageUseCase`, `RelayEngine`, `CryptoService`,
// `MessageEnvelope`, or `messaging_stack.dart`/`bindings.dart` (task file
// §4) — every dependency below is used exactly as its own epic left it.
//
// `prefer_initializing_formals` is intentionally not applied to this file's
// constructor: the fields are private (`_stack`, `_clock`) while the
// constructor's public named parameters (`stack`, `clock`) match the task
// file's documented contract exactly — an initializing formal would rename
// those named-argument keywords to the private field names, breaking every
// call site (relay_engine.dart's header already documents this same
// deliberate exclusion for the identical reason).
// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:typed_data';

import '../crypto/crypto_failures.dart';
import '../transport/transport_service.dart';
import '../../features/messaging/domain/message.dart';
import 'ciphertext_codec.dart';
import 'messaging_stack.dart';
import 'relay_packet_frame.dart';

/// The declared extension point for non-ciphertext (`PayloadType.control`)
/// frames addressed to this device — T07 (prekey bundles) and T08 (acks)
/// register their own handler here instead of editing this file (task file
/// §3). This task defines the seam and registers nothing.
typedef ControlHandler = Future<void> Function(RelayPacketFrame frame);

/// Silent-drop counters (task file §5) — the bug sweep's and the Dashboard's
/// only handle on this loop, since a bad packet is dropped, not surfaced.
/// Mutated only by [InboundPipeline] itself; exposed read-only in spirit
/// (nothing outside this file has a reason to write to it) but not made
/// immutable, since a live, cheaply-read counter object is more useful to a
/// caller than a snapshot that goes stale the instant it is taken.
class InboundCounters {
  /// `RelayPacketFrame.deserialize` threw `FormatException`.
  int malformed = 0;

  /// `frame.expiresAtMs` was already in the past (FR-ROUTE-004) — dropped,
  /// not forwarded, regardless of destination.
  int expired = 0;

  /// Addressed to this device but `CiphertextCodec.decode`/`decrypt` threw a
  /// typed `CryptoDecryptFailure` (E03-B03).
  int undecryptable = 0;

  /// `ReceiveMessageUseCase.call` returned `null` — FR-MSG-003's documented
  /// duplicate signal, not an error.
  int duplicate = 0;

  /// Handed to `RelayEngine.enqueue` for another destination (FR-ROUTE-002).
  int forwarded = 0;

  /// Newly persisted by `ReceiveMessageUseCase` and emitted on [InboundPipeline.delivered].
  int delivered = 0;

  /// Addressed to this device, `payloadType == control`, and no handler is
  /// registered — dropped and counted, never guessed at (task file §3).
  int unhandledControl = 0;
}

/// The receive half of the messaging wedge (see this file's header).
/// Constructed once (E06-T06 owns lifecycle) against the whole
/// [MessagingStack], since it needs transport, the relay engine, the receive
/// use case and `selfDeviceId` all at once.
class InboundPipeline {
  InboundPipeline({
    required MessagingStack stack,
    DateTime Function() clock = DateTime.now,
  })  : _stack = stack,
        _clock = clock;

  final MessagingStack _stack;
  final DateTime Function() _clock;

  bool _started = false;

  StreamSubscription<TransportDevice>? _discoverySubscription;

  /// One `connectionState(id)` subscription per device id ever discovered
  /// while running, so a lost/failed peer's incoming-data subscription can
  /// be torn down instead of leaking (§6 risk).
  final Map<String, StreamSubscription<ConnectionState>>
      _connectionSubscriptions = <String, StreamSubscription<ConnectionState>>{};

  /// One `incomingData(id)` subscription per currently-connected device id.
  /// Present only while that id is `ConnectionState.connected`.
  final Map<String, StreamSubscription<Uint8List>> _dataSubscriptions =
      <String, StreamSubscription<Uint8List>>{};

  ControlHandler? _controlHandler;

  final InboundCounters counters = InboundCounters();

  final StreamController<Message> _deliveredController =
      StreamController<Message>.broadcast();

  /// One event per message newly persisted by `ReceiveMessageUseCase` — never
  /// for a duplicate. Broadcast: a live update signal for T09's read model
  /// and T11's chat screen, not a buffer that holds this pipeline open when
  /// nothing listens.
  Stream<Message> get delivered => _deliveredController.stream;

  /// The declared extension point for `PayloadType.control` frames (task
  /// file §3/§5). Throws [StateError] if a handler is already registered —
  /// this task defines one named registration slot; nobody registers into it
  /// here.
  void registerControlHandler(ControlHandler handler) {
    if (_controlHandler != null) {
      throw StateError(
        'InboundPipeline.registerControlHandler: a control handler is '
        'already registered',
      );
    }
    _controlHandler = handler;
  }

  /// Begins consuming `TransportService.incomingData` for every connected
  /// peer, and for peers that connect afterward. Idempotent: a second call
  /// is a no-op rather than a second `discoveredDevices` subscription, which
  /// would otherwise deliver every packet twice (task file §6 risk — T06 may
  /// call this from a lifecycle callback that fires more than once).
  void start() {
    if (_started) return;
    _started = true;
    _discoverySubscription =
        _stack.transport.discoveredDevices.listen(_onDeviceDiscovered);
  }

  /// Cancels every subscription this pipeline holds. Required for test
  /// isolation (task file §5); the production app process never calls this.
  Future<void> stop() async {
    _started = false;

    await _discoverySubscription?.cancel();
    _discoverySubscription = null;

    for (final subscription in _connectionSubscriptions.values) {
      await subscription.cancel();
    }
    _connectionSubscriptions.clear();

    for (final subscription in _dataSubscriptions.values) {
      await subscription.cancel();
    }
    _dataSubscriptions.clear();

    await _deliveredController.close();
  }

  void _onDeviceDiscovered(TransportDevice device) {
    // Already tracking this id's connection state -- nothing to do. Real
    // Bluetooth discovery re-announces the same device across scan cycles
    // (mirrors devices_controller.dart's own dedup reasoning).
    if (_connectionSubscriptions.containsKey(device.id)) return;
    _connectionSubscriptions[device.id] = _stack.transport
        .connectionState(device.id)
        .listen((ConnectionState state) => _onConnectionStateChanged(device.id, state));
  }

  void _onConnectionStateChanged(String deviceId, ConnectionState state) {
    if (state == ConnectionState.connected) {
      // Idempotent: a repeated `connected` event for an id already
      // subscribed must not open a second incomingData listener (the same
      // double-delivery hazard `start()`'s own idempotency guards against).
      _dataSubscriptions.putIfAbsent(
        deviceId,
        () => _stack.transport
            .incomingData(deviceId)
            .listen((Uint8List bytes) => _handleBuffer(bytes)),
      );
    } else {
      // connecting / disconnected / failed -- no active link, no reason to
      // keep an incomingData subscription open for it (§6 risk: a
      // subscription per peer that is never cancelled leaks).
      unawaited(_dataSubscriptions.remove(deviceId)?.cancel());
    }
  }

  Future<void> _handleBuffer(Uint8List bytes) async {
    final RelayPacketFrame frame;
    try {
      frame = RelayPacketFrame.deserialize(bytes);
    } on FormatException {
      counters.malformed++;
      return;
    }

    // FR-ROUTE-003 (task file §6): the destination decision is made HERE,
    // immediately after parsing, before `frame.payload` is read anywhere in
    // this method. Every read of `frame.payload` below is textually inside
    // the `isForUs` branch, after the `!isForUs` branch has already
    // returned.
    final bool isForUs = frame.destination == _stack.selfDeviceId;
    final int nowMs = _clock().millisecondsSinceEpoch;

    // FR-ROUTE-004: a past-TTL packet is dropped, not forwarded, regardless
    // of destination -- it is not worth relaying or decrypting either way.
    if (frame.expiresAtMs <= nowMs) {
      counters.expired++;
      return;
    }

    if (!isForUs) {
      // Forward branch (FR-ROUTE-002/FR-ROUTE-003). `bytes` -- the ORIGINAL
      // wire bytes this device received off the transport, not
      // `frame.payload` and not a re-serialized frame -- is the only thing
      // handed onward, so a relay forwards exactly what it did not read.
      // Nothing past this point in this branch touches `frame.payload`,
      // calls `CiphertextCodec.decode`, calls `decrypt`, or constructs a
      // `Message`.
      final Duration remainingTtl =
          Duration(milliseconds: frame.expiresAtMs - nowMs);
      await _stack.relayEngine.enqueue(
        frame.destination,
        bytes,
        frame.priority,
        remainingTtl,
      );
      counters.forwarded++;
      return;
    }

    // Everything below is addressed to this device.
    if (frame.payloadType == PayloadType.control) {
      final ControlHandler? handler = _controlHandler;
      if (handler == null) {
        // Dropped and counted, never guessed at (task file §3).
        counters.unhandledControl++;
        return;
      }
      try {
        await handler(frame);
      } catch (_) {
        // A future control handler's own failure (T07/T08) must not take
        // this pipeline down either -- same "a bad packet never kills the
        // loop" policy as the ciphertext branch below.
      }
      return;
    }

    try {
      final ciphertextMessage =
          CiphertextCodec.decode(frame.payloadType, frame.payload);
      final Message? message =
          await _stack.receiveMessage.call(frame.source, ciphertextMessage);
      if (message == null) {
        // FR-MSG-003's documented app-level duplicate signal (same envelope
        // id already persisted) -- a normal outcome in a mesh that can
        // forward the same packet down two paths, never an error (task file
        // §6 risk).
        counters.duplicate++;
      } else {
        counters.delivered++;
        _deliveredController.add(message);
      }
    } on CryptoDecryptFailure catch (failure) {
      // E03-B03's catch. Judgment call, logged in the task's Run log: the
      // SAME wire bytes re-arriving (the common mesh case, not merely the
      // same plaintext re-encrypted) fails at the Double Ratchet itself --
      // `CryptoDecryptFailureReason.duplicateMessage`, the exact reason
      // `crypto_failures.dart` documents for "a replay, or a message whose
      // key material has already been used and discarded" -- BEFORE
      // `ReceiveMessageUseCase`'s own envelope-id dedup ever runs. That is
      // still a duplicate-packet outcome, not an undecryptable one, so it is
      // counted the same way FR-MSG-003's own dedup signal is. Every other
      // typed failure (invalidMessage/noSession/untrustedIdentity/unknown)
      // is metadata-only (never plaintext/key material) and drops the
      // packet without taking the pipeline down.
      if (failure.reason == CryptoDecryptFailureReason.duplicateMessage) {
        counters.duplicate++;
      } else {
        counters.undecryptable++;
      }
    }
  }
}
