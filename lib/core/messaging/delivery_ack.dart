// core/messaging — delivery acknowledgements (E06-T08).
//
// `DeliveryState` has seven states (`delivery_state_machine.dart:13`).
// E05-T02 writes `queued`/`sent`/`failed`; E05-T03 writes `accepted` on the
// RECEIVING device. Nothing has ever told the SENDER what happened after
// that — `delivered` and `read` have had no producer anywhere, on any
// device (task file §2). This file is where that stops: the receiving
// device tells the sender `accepted`/`delivered` back over the mesh, and the
// sender advances its own row through `DeliveryStateMachine` on receipt.
//
// **The ack control sub-protocol**, nested inside a `RelayPacketFrame`'s
// opaque `payload` field when `payloadType == PayloadType.control` — the
// SAME reserved tag `PrekeyExchange` (E06-T07) already uses. Layout,
// mirroring `PrekeyExchange`'s own `_ControlBody` framing idiom
// (`prekey_exchange.dart`'s header):
//
//   [u8  stateTag]                       // 1=accepted, 2=delivered, 3=read
//   [u32 messageIdLen][messageId bytes]
//   [u64 observedAtMs]
//
// **`OQ-E06-T08-2`'s retrofit — why this file never sees a leading
// "controlKind" byte.** `InboundPipeline`'s single control-handler slot
// (E06-T05) was already occupied by `PrekeyExchange` (E06-T07) before this
// task started; two independent control sub-protocols cannot share one
// named slot without a way to tell them apart. Resolved (task file's own
// `OQ-E06-T08-2`, option (a)) by giving `InboundPipeline` a
// `Map<int, ControlHandler>` keyed by a one-byte `controlKind` that
// `InboundPipeline._handleBuffer` reads and STRIPS off the front of
// `frame.payload` BEFORE calling whichever handler is registered for that
// key (`inbound_pipeline.dart`). By the time [DeliveryAckService
// .handleControlFrame] ever sees a frame, its `payload` is already this
// file's own ack body, with no foreign byte prepended — exactly mirroring
// what `PrekeyExchange.handleControlFrame` already expected before this
// retrofit (that file's own `_sendControlFrame` prepends
// [kControlKindPrekeyExchange] the same way [_sendAck] below prepends
// [kControlKindDeliveryAck]). Splitting the concern this way means this
// file's own codec never has to know the other sub-protocol exists, and
// `PrekeyExchange`'s own `_ControlBody` tag scheme is untouched.
//
// **`accepted` and `delivered` collapse into one moment on this app (task
// file §3).** There is no separate "handed to the UI layer" event -- both
// are emitted from the same call, back-to-back, the instant
// `ReceiveMessageUseCase` persists a new (non-duplicate) message. Inventing
// an artificial delay between them to justify two distinct wire moments
// would be fiction, so this file states plainly here that it does not do
// that.
//
// **Producing acks is driven by `InboundPipeline.delivered`, not a new call
// site inside `_handleBuffer`.** `inbound_pipeline.dart`'s own `delivered`
// stream already fires exactly once per newly-persisted, non-duplicate
// inbound message (never for a duplicate — `ReceiveMessageUseCase` returning
// `null` short-circuits before that stream is touched at all). Subscribing
// to that existing signal, from [MessagingStack]'s own composition root
// (`messaging_stack.dart`, the same place `MessagingCoordinator` itself
// subscribes to the identical stream for `recordStored`), gives this
// service "never for a duplicate" for free, with zero changes to
// `inbound_pipeline.dart`'s `_handleBuffer` method and zero changes to
// `MessagingCoordinator` (task file §4/§5 — this task does not modify
// `ReceiveMessageUseCase` and its `files:` fence does not include
// `messaging_coordinator.dart`).
//
// **Consuming acks — ownership.** `messages.senderDeviceId` is always "who
// authored this row" (mirrors `ReceiveMessageUseCase`'s and
// `SendMessageUseCase`'s own convention), and for the one conversation
// shape this schema supports today, `conversationId == peerDeviceId`
// (`conversation_repository.dart`'s own established E06-T09 convention,
// confirmed against that file directly rather than assumed). An inbound
// ack is therefore accepted only when the referenced message row (a) exists
// locally, (b) was authored by THIS device (`senderDeviceId ==
// stack.selfDeviceId`), and (c) was sent to the SAME peer the ack claims to
// be from (`conversationId == frame.source`) — task file §3/§6, EARS-MSG-8.
// An ack failing (a) is counted `rejectedUnknownMessage`; failing (b) or (c)
// is counted `rejectedForeign`. Neither ever reaches
// `DeliveryStateMachine`.
//
// **Consuming acks — monotonicity (EARS-MSG-9).** `DeliveryStateMachine
// .canTransition` is checked BEFORE `Message.withDeliveryState` is ever
// called, so a late/out-of-order/backward ack is a silent, counted no-op
// (`staleIgnored`) rather than a thrown `StateError` that would otherwise
// kill whatever awaits this handler — the exact same "a bad control frame
// never takes the pipeline down" contract `InboundPipeline` already
// enforces around every registered handler (`inbound_pipeline.dart`'s own
// `try { await handler(frame); } catch (_) {}`), reinforced here at the
// point most likely to throw for a REAL, expected reason (a stale ack
// arriving after a fresher one already landed) rather than an actual bug.
//
// **The write path — `messages.delivery_state` AND `delivery_states`, never
// only one.** `messages.delivery_state` is written directly here (via
// `Message.withDeliveryState`, never a raw string), because this file's own
// contract is the one place SendMessageUseCase's `Sent` row ever advances
// past it — unlike `MessagingCoordinator.recordStored`, which deliberately
// never writes that column (its own header explains why: every OTHER
// writer already validated the transition before `recordStored` ever sees
// the message). `MessagingCoordinator.recordStored` is then called with the
// already-updated `Message` purely to append the `delivery_states` row and
// advance the sync cursor, through its existing, unmodified public contract
// (task file §3: "append the delivery_states row through
// MessagingCoordinator.recordStored's existing path") — this file does not
// touch that method's internals, and `messaging_coordinator.dart` is not in
// this task's `files:` fence.
//
// **`read` is a mechanism, not yet a decision (`OQ-E06-T08-1`).**
// [kReadReceiptsEnabled] is the single named constant [markRead] gates on —
// disabled here means [markRead] returns before touching `_clock`, before
// building a [DeliveryAck], and before any byte reaches
// [MessagingStack.transport]. A disabled feature that still puts frames on
// the wire would leak exactly the information it is supposed to withhold
// (task file §6 risk) — proven at the transport level by this task's own
// test, not merely by reading this file's `if`.
//
// Does NOT modify `DeliveryStateMachine`, `ReceiveMessageUseCase`,
// `SendMessageUseCase`, or the `messages`/`delivery_states` schema (task
// file §4). Does NOT retry, re-request or reconcile a lost ack — if one
// never arrives, the message simply stays at its last known state
// (OQ-E06-T06-2, owned by E11). Does NOT write `RelayDeliveryState.failed`
// or introduce any delivery timeout.
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:drift/drift.dart';

import '../persistence/database.dart';
import '../../features/messaging/domain/delivery_state_machine.dart';
import '../../features/messaging/domain/message.dart';
import 'messaging_stack.dart';
import 'relay_packet_frame.dart';

/// The `controlKind` byte [InboundPipeline] dispatches on
/// (`inbound_pipeline.dart`, `OQ-E06-T08-2`) — registered in
/// `messaging_stack.dart` against [DeliveryAckService.handleControlFrame].
/// `1` is [PrekeyExchange]'s own reserved value (`prekey_exchange.dart`);
/// this is the next one, never reused for anything else.
const int kControlKindDeliveryAck = 2;

/// Whether [DeliveryAckService.markRead] actually puts a `read` ack on the
/// wire. Disabled pending `OQ-E06-T08-1` — a single named constant, checked
/// once, rather than scattered `if`s (task file §3).
const bool kReadReceiptsEnabled = false;

/// How long this file's control frames live on the wire before expiring —
/// mirrors `PrekeyExchange`'s own `_controlFrameTtl` reasoning: an ack that
/// has not arrived within this window has already lost its usefulness, and
/// (per task file §4) nothing here retries it anyway.
const Duration _controlFrameTtl = Duration(seconds: 30);

/// The three states this app ever actually sends an ack FOR. Serialized as
/// an explicit [tag] — never Dart's enum index — matching every other wire
/// enum in this codebase (`PayloadType`, `PrekeyExchange`'s
/// `_ControlSubType`).
enum DeliveryAckState {
  accepted(1),
  delivered(2),
  read(3);

  const DeliveryAckState(this.tag);

  final int tag;

  /// Reverse lookup by wire tag. Throws [FormatException] naming the
  /// unrecognised value — never coerced to a nearby state (task file §5).
  static DeliveryAckState fromTag(int tag) {
    for (final state in DeliveryAckState.values) {
      if (state.tag == tag) return state;
    }
    throw FormatException('DeliveryAck: unknown state tag $tag');
  }

  /// The [DeliveryState] this ack state advances the SENDER's row to.
  DeliveryState toDeliveryState() => switch (this) {
        DeliveryAckState.accepted => DeliveryState.accepted,
        DeliveryAckState.delivered => DeliveryState.delivered,
        DeliveryAckState.read => DeliveryState.read,
      };
}

/// One `{messageId, state, observedAtMs}` ack (task file §5's contract).
/// Pure codec, no I/O — mirrors `RelayPacketFrame`/`PreKeyBundleCodec`'s own
/// discipline: every length prefix is bounds-checked against the remaining
/// buffer before it is used to slice.
class DeliveryAck {
  const DeliveryAck({
    required this.messageId,
    required this.state,
    required this.observedAtMs,
  });

  final String messageId;
  final DeliveryAckState state;
  final int observedAtMs;

  /// `{messageId, state, observedAtMs}` as a control-frame body (task file
  /// §5) — same big-endian, length-prefixed framing idiom as the rest of
  /// this codebase's wire codecs.
  Uint8List serialize() {
    final messageIdBytes = Uint8List.fromList(utf8.encode(messageId));

    final totalLength = 1 + // stateTag
        4 + messageIdBytes.length + // messageIdLen + messageId
        8; // observedAtMs

    final buffer = ByteData(totalLength);
    var offset = 0;

    buffer.setUint8(offset, state.tag);
    offset += 1;

    buffer.setUint32(offset, messageIdBytes.length);
    offset += 4;
    buffer.buffer
        .asUint8List()
        .setRange(offset, offset + messageIdBytes.length, messageIdBytes);
    offset += messageIdBytes.length;

    buffer.setUint64(offset, observedAtMs);
    offset += 8;

    return buffer.buffer.asUint8List();
  }

  /// Decodes bytes produced by [serialize]. Throws [FormatException] naming
  /// the failing field on an empty buffer, a truncated field, an unknown
  /// [DeliveryAckState] tag, or trailing/missing bytes — never returns a
  /// partially-built [DeliveryAck] (task file §5).
  static DeliveryAck deserialize(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const FormatException(
        'DeliveryAck: empty buffer, missing state byte',
      );
    }
    final view = ByteData.sublistView(bytes);
    var offset = 0;

    final state = DeliveryAckState.fromTag(view.getUint8(offset));
    offset += 1;

    _requireRemaining(bytes, offset, 4, 'messageIdLength');
    final messageIdLen = view.getUint32(offset);
    offset += 4;
    _requireRemaining(bytes, offset, messageIdLen, 'messageId');
    final messageId =
        utf8.decode(bytes.sublist(offset, offset + messageIdLen));
    offset += messageIdLen;

    _requireRemaining(bytes, offset, 8, 'observedAtMs');
    final observedAtMs = view.getUint64(offset);
    offset += 8;

    if (offset != bytes.length) {
      throw const FormatException(
        'DeliveryAck: declared fields do not account for the buffer '
        'exactly (trailing or missing bytes)',
      );
    }

    return DeliveryAck(
      messageId: messageId,
      state: state,
      observedAtMs: observedAtMs,
    );
  }

  static void _requireRemaining(
    Uint8List bytes,
    int offset,
    int needed,
    String field,
  ) {
    if (bytes.length < offset + needed) {
      throw FormatException(
        'DeliveryAck: truncated, missing $field '
        '(need $needed byte(s) at offset $offset, only '
        '${bytes.length - offset} remain)',
      );
    }
  }
}

/// So "why is this message still on one tick?" is answerable (task file
/// §5) — mutated only by [DeliveryAckService] itself.
class DeliveryAckCounters {
  /// Outbound ack frames actually sent (one per [DeliveryAckService
  /// .onMessageStored] call, per state — normally 2: accepted + delivered).
  int sent = 0;

  /// Inbound acks that passed ownership + monotonicity and advanced a
  /// message's `deliveryState`.
  int accepted = 0;

  /// Inbound acks referencing a real, locally-known message this device did
  /// NOT send, or did not send to the peer the ack claims to be from
  /// (EARS-MSG-8).
  int rejectedForeign = 0;

  /// Inbound acks referencing a message id this device has no row for at
  /// all.
  int rejectedUnknownMessage = 0;

  /// Inbound acks that were legitimately this device's own message, from
  /// the right peer, but whose transition was illegal from the message's
  /// CURRENT state (out-of-order/duplicate/backward — EARS-MSG-9). Never an
  /// exception, always counted.
  int staleIgnored = 0;
}

/// Delivery acknowledgements — the producer half (receiving device tells the
/// sender) and the consumer half (sending device advances its own row) of
/// the same sub-protocol (see this file's header). Exactly one instance per
/// [MessagingStack] — [MessagingStack] constructs it and both registers
/// [handleControlFrame] on `stack.inbound`'s control seam AND subscribes it
/// to `stack.inbound.delivered` itself; nothing else should construct a
/// second instance against the same stack.
///
/// `prefer_initializing_formals` is intentionally not applied to this
/// file's constructor, matching the same documented exclusion already used
/// by `inbound_pipeline.dart`/`prekey_exchange.dart`/
/// `messaging_coordinator.dart`.
// ignore_for_file: prefer_initializing_formals
class DeliveryAckService {
  DeliveryAckService({
    required MessagingStack stack,
    DateTime Function() clock = DateTime.now,
  })  : _stack = stack,
        _clock = clock;

  final MessagingStack _stack;
  final DateTime Function() _clock;

  final DeliveryAckCounters counters = DeliveryAckCounters();

  int _packetCounter = 0;

  String _nextPacketId() {
    _packetCounter += 1;
    return '${_stack.selfDeviceId}-ack-$_packetCounter';
  }

  /// Receiving side (task file §5): emits `accepted` then `delivered` acks
  /// back to [senderDeviceId] for [message]. Called exactly once per
  /// newly-persisted, non-duplicate inbound message — see this file's
  /// header for why that guarantee needs no dedup logic of its own here.
  /// `accepted` and `delivered` collapse into the same moment on this app
  /// (this file's header) — both are always sent, back-to-back.
  Future<void> onMessageStored(Message message, String senderDeviceId) async {
    await _sendAck(senderDeviceId, message.id, DeliveryAckState.accepted);
    await _sendAck(senderDeviceId, message.id, DeliveryAckState.delivered);
  }

  /// Emits a `read` ack for [messageId] IF read receipts are enabled — a
  /// no-op while `OQ-E06-T08-1` is open (this file's header/[kReadReceiptsEnabled]).
  /// Called by T11 when a message is displayed (task file §5).
  Future<void> markRead(String messageId) async {
    if (!kReadReceiptsEnabled) return;

    final row = await (_stack.db.select(_stack.db.messages)
          ..where((t) => t.id.equals(messageId)))
        .getSingleOrNull();
    if (row == null) return;

    // The peer to notify is whoever sent this device the message in the
    // first place — `messages.senderDeviceId`, the same field
    // `ReceiveMessageUseCase` populates with `frame.source` (this file's
    // header).
    await _sendAck(row.senderDeviceId, messageId, DeliveryAckState.read);
  }

  /// Sending side (task file §5): registered on
  /// `stack.inbound.registerControlHandler(kControlKindDeliveryAck, ...)`
  /// (E06-T05's seam, retrofitted for multiple sub-protocols by
  /// `OQ-E06-T08-2`). Validates ownership, then advances state through
  /// [DeliveryStateMachine] — see this file's header for the full
  /// ownership/monotonicity contract. A malformed ack body is dropped
  /// silently (`InboundPipeline._handleBuffer`'s own `catch (_)` around
  /// every registered handler already guarantees a throw here cannot take
  /// the receive loop down; this method also never lets one escape as an
  /// uncaught exception itself).
  Future<void> handleControlFrame(RelayPacketFrame frame) async {
    final DeliveryAck ack;
    try {
      ack = DeliveryAck.deserialize(frame.payload);
    } on FormatException {
      return;
    }

    final row = await (_stack.db.select(_stack.db.messages)
          ..where((t) => t.id.equals(ack.messageId)))
        .getSingleOrNull();

    if (row == null) {
      counters.rejectedUnknownMessage++;
      return;
    }

    // Ownership (EARS-MSG-8): this device must have authored the message,
    // AND authored it for the peer this ack claims to be from. See this
    // file's header for why `conversationId == frame.source` is the right
    // check for the only conversation shape this schema supports today.
    if (row.senderDeviceId != _stack.selfDeviceId ||
        row.conversationId != frame.source) {
      counters.rejectedForeign++;
      return;
    }

    final DeliveryState current = DeliveryState.values.byName(
      row.deliveryState,
    );
    final DeliveryState target = ack.state.toDeliveryState();

    // Monotonicity (EARS-MSG-9): never move backwards, and never treat a
    // legitimate MULTI-step forward jump as illegal. `accepted` and
    // `delivered` are sent back-to-back from the receiving side (this
    // file's header) but can arrive at the sender in EITHER order over a
    // mesh — task file §3: "both are sent; the sender records the higher
    // one." A single `DeliveryStateMachine.canTransition(current, target)`
    // check would incorrectly reject a `delivered` ack that overtakes its
    // own `accepted` sibling (current == `sent`, target == `delivered` is
    // two hops, not one). Instead: a target at or behind the current state
    // is a no-op (EARS-MSG-9's actual concern); a target strictly ahead is
    // walked one legal `DeliveryStateMachine`-validated hop at a time along
    // `DeliveryState`'s own declared (and `_happyPath`-matching) order,
    // never via a raw enum write.
    if (target.index <= current.index) {
      counters.staleIgnored++;
      return;
    }

    var message = Message(
      id: row.id,
      conversationId: row.conversationId,
      senderDeviceId: row.senderDeviceId,
      sequenceNumber: row.sequenceNumber,
      ciphertext: row.ciphertext,
      createdAt: row.createdAt,
      deliveryState: current,
    );
    for (var index = current.index; index < target.index; index++) {
      final DeliveryState next = DeliveryState.values[index + 1];
      if (!DeliveryStateMachine.canTransition(message.deliveryState, next)) {
        // Defensive only: `DeliveryState`'s declared order matches
        // `DeliveryStateMachine`'s private `_happyPath` exactly (both
        // `queued, sent, accepted, delivered, stored, read`, `failed`
        // trailing outside it), so every adjacent hop from a pre-terminal
        // state is legal by construction. This can only fire if that
        // invariant is ever broken elsewhere — treated as a stale/no-op,
        // never an exception that would take this control handler down
        // (task file §6).
        counters.staleIgnored++;
        return;
      }
      // Never a raw enum write (task file §3/§9) — `withDeliveryState`
      // itself calls `DeliveryStateMachine.transition`.
      message = message.withDeliveryState(next);
    }

    await (_stack.db.update(_stack.db.messages)
          ..where((t) => t.id.equals(row.id)))
        .write(MessagesCompanion(deliveryState: Value(message.deliveryState.name)));

    // Appends the `delivery_states` row (and advances the sync cursor)
    // through the coordinator's existing, unmodified public contract (task
    // file §3) — this file never writes `delivery_states` directly and
    // never reaches into `MessagingCoordinator`'s private state.
    await _stack.coordinator.recordStored(message);

    counters.accepted++;
  }

  /// Direct transport send — NOT `relayEngine.enqueue` — mirroring
  /// `PrekeyExchange._sendControlFrame`'s own reasoning: an ack is only
  /// useful to a peer that is reachable right now, and (task file §4)
  /// nothing here queues one for later delivery or retries a lost one.
  /// Prepends [kControlKindDeliveryAck] so `InboundPipeline` can dispatch
  /// this sub-protocol's frames to [handleControlFrame] rather than
  /// `PrekeyExchange`'s (`OQ-E06-T08-2`, this file's header).
  ///
  /// **Never throws.** This is called fire-and-forget from
  /// `MessagingStack`'s own `inbound.delivered` subscription (that file's
  /// constructor, wrapped in `unawaited(...)`) — an unhandled exception
  /// from an `unawaited` future surfaces as an uncaught async zone error,
  /// not a normal return-value failure a caller could catch, so a
  /// transport-level send failure (an unreachable peer, or simply no
  /// platform channel handler in a test that never needed one before this
  /// service existed) must never escape this method. Exactly the same
  /// "an ack is best-effort, a lost one is not an error" contract task file
  /// §4 already states in prose ("does NOT retry, re-request or reconcile
  /// missing acks … if an ack is lost, the message simply stays at its
  /// last known state") — a failed *send* is one more way an ack can be
  /// lost, not a new failure mode this file needs to surface.
  Future<void> _sendAck(
    String peerDeviceId,
    String messageId,
    DeliveryAckState state,
  ) async {
    final now = _clock();
    final ack = DeliveryAck(
      messageId: messageId,
      state: state,
      observedAtMs: now.millisecondsSinceEpoch,
    );
    final body = ack.serialize();

    final framedBody = Uint8List(body.length + 1);
    framedBody[0] = kControlKindDeliveryAck;
    framedBody.setRange(1, framedBody.length, body);

    try {
      // E04-B15: resolve the peer's real, learned `selfDeviceId` for the
      // frame's own `destination` field -- same forward-only pattern
      // E04-B13 established (`resolveOutboundDestination`'s own doc
      // comment in `messaging_stack.dart`), reused rather than re-derived.
      // `directSend` below keeps using the raw `peerDeviceId` (Bluetooth
      // MAC) unchanged -- only the wire frame's own `destination` field is
      // resolved. Deliberately INSIDE this try block (review finding,
      // E04-B15): this method is called fire-and-forget, unawaited, from
      // `MessagingStack`'s own `inbound.delivered` subscription -- a DB
      // query that throws (e.g. a disposed/closed database, observed in a
      // real test race) must be caught here exactly like every other
      // failure this method already swallows, never allowed to escape as
      // an unhandled async-zone error.
      final destination = await resolveOutboundDestination(
        _stack.db,
        peerDeviceId,
      );
      final frame = RelayPacketFrame(
        payloadType: PayloadType.control,
        packetId: _nextPacketId(),
        destination: destination,
        source: _stack.selfDeviceId,
        priority: 0,
        createdAtMs: now.millisecondsSinceEpoch,
        expiresAtMs: now.add(_controlFrameTtl).millisecondsSinceEpoch,
        payload: framedBody,
      );
      // `_stack.directSend`, not `_stack.transport.send` directly -- E04-B05:
      // must connect before sending, not assume an already-open socket.
      await _stack.directSend(peerDeviceId, frame.serialize());
      counters.sent++;
    } catch (_) {
      // Best-effort, never surfaced -- see this method's own doc comment.
    }
  }
}
