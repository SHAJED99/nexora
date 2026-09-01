// core/calls — call-invite/ring/accept/decline/hangup signaling over the
// pairwise Signal-session control-frame channel (E07-T09).
//
// **Security posture (task file §2, the E06-B04 lesson).** Every existing
// CLEARTEXT `PayloadType.control` sub-protocol (`PrekeyExchange` kind 1,
// `DeliveryAck` kind 2) trusts the outer relay frame's claimed originating
// device id at face value — a field any mesh node can set to anything
// (E06-B04's own finding: "any node participating in the mesh ... can
// construct and inject a ... frame with [that field] set to the real
// recipient's device id, and the ownership check ... will accept it as
// genuine"). An unauthenticated call invite would let any device on the
// mesh ring any other device, so this sub-protocol never repeats that
// mistake: [CallSignaling] follows `group_control.dart`'s pattern instead
// (kind 3) — a serialized [CallSignalingFrame] is always encrypted through
// the *pairwise* Double Ratchet session with the peer (the same
// `CryptoService` E03-T03/E06-T07 already established) before it reaches
// `TransportService`, and an inbound frame's claimed sender is trusted ONLY
// once `CryptoService.decrypt` has cryptographically proven which session
// produced it. [handleWireFrame] reads the raw wire frame's own claimed
// source exactly once, purely as *which session to attempt decryption
// under* (libsignal offers no way to decrypt without naming a candidate
// address first) — never as a trusted identity claim; [handleControlFrame]
// takes the already-decrypted plaintext and an already-verified
// `sourceDeviceId` and is the only place this file trusts an actor
// identity. [encodeCiphertextControlBody]/[decodeCiphertextControlBody] are
// reused from `group_control.dart` UNCHANGED — the same generic ciphertext-
// nesting codec, not re-implemented here.
//
// **One active call per device (task file §2).** [CallSignaling] holds at
// most one [CallSession] at a time in [_currentSession] — there is no
// roster, no per-peer map, because a second concurrent call is not queued,
// it is answered with `busy` (EARS-CALL-4) and never reaches a
// [CallSession] of its own.
//
// **Glare (task file §6).** Two devices inviting each other at
// (approximately) the same moment is resolved deterministically by
// `callId` — the lower one wins, the other side's invite becomes `busy` —
// so the mesh never ends up with two half-connected calls between the same
// pair. See [_handleInvite].
//
// **Ring timeout is entirely [CallSession]'s own concern** (task file §2)
// — this file only supplies the injected [_ringTimeout] duration at
// construction and reacts to a session reaching [CallState.ended] with
// [CallEndReason.timeout] to bump [CallSignalingCounters.callTimeout]; see
// [_track].
//
// **Media is out of scope on purpose** (task file §1/§4). [CallMediaTransport]
// is an abstract seam; [NullCallMediaTransport] is its one implementation,
// and it honestly fails every call the moment both ends reach
// [CallState.active] — see that class's own doc comment.
//
// Does NOT modify `InboundPipeline`, `PrekeyExchange`, `DeliveryAckService`,
// `group_control.dart` or anything under `lib/features/groups/` (task file
// §4) — [encodeCiphertextControlBody]/[decodeCiphertextControlBody] are
// imported and used exactly as `group_control.dart` already defines them.
// Does NOT implement group/conference calling (`OQ-E07-11`), call-routing
// priority (E07-T10), mid-call route migration (E07-T11), call UI, a route,
// a notification, or call-history persistence (task file §4).
//
// `prefer_initializing_formals` is intentionally not applied to this file's
// constructor, matching the same documented exclusion already used by
// `call_session.dart`/`prekey_exchange.dart`/`relay_engine.dart` — the
// field names are prefixed (`_clock`, `_ringTimeout`) while the constructor
// parameters are not.
// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import '../auth/google_auth_service.dart' show AppFailure;
import '../../features/trust/data/relationship_repository.dart';
import '../messaging/group_control.dart'
    show encodeCiphertextControlBody, decodeCiphertextControlBody;
import '../messaging/messaging_stack.dart';
import '../messaging/relay_packet_frame.dart';
import 'call_session.dart';

/// Matches `messaging_stack.dart`/`prekey_exchange.dart`/
/// `group_membership_service.dart`'s own `_remoteSignalDeviceId`/
/// `_localSignalDeviceId` constant — Dart's privacy model makes literal
/// reuse of a `library`-private constant across files impossible (see
/// `messaging_stack.dart`'s header, judgment call 1), so it is redeclared
/// here, same value, same reasoning.
const int _remoteSignalDeviceId = 1;

/// The `controlKind` byte `InboundPipeline` dispatches on
/// (`inbound_pipeline.dart`'s keyed `Map<int, ControlHandler>`) — `1` is
/// `PrekeyExchange`'s, `2` is `DeliveryAckService`'s, `3` is
/// `GroupMembershipService`'s, `4` is `GroupCryptoService`'s (all E06/E07);
/// this task's call-signaling sub-protocol takes the next unused value.
/// Registered in `messaging_stack.dart` against
/// [CallSignaling.handleWireFrame].
const int kControlKindCallSignaling = 5;

/// The wire TTL stamped on every control frame this file sends. Short-lived
/// on purpose, mirroring `prekey_exchange.dart`'s own `_controlFrameTtl`
/// reasoning: a call-signaling frame that outlives this has already lost
/// its race against the 45s ring timeout, and — like a prekey-bundle
/// request — is never queued for later delivery anyway (see
/// [_sendFrame]'s own use of `transport.send`, not `relayEngine.enqueue`).
const Duration _controlFrameTtl = Duration(seconds: 30);

/// Explicit, stable wire tags for [CallSignalKind] — deliberately NOT the
/// enum's declaration-order index, matching `group_control.dart`'s own
/// `_kindTags` discipline for [GroupEventKind] and `PayloadType`'s own
/// `tag` field: the wire value must survive this declaration being
/// reordered.
const Map<CallSignalKind, int> _kindTags = {
  CallSignalKind.invite: 1,
  CallSignalKind.ringing: 2,
  CallSignalKind.accept: 3,
  CallSignalKind.decline: 4,
  CallSignalKind.busy: 5,
  CallSignalKind.hangup: 6,
  CallSignalKind.cancel: 7,
};

CallSignalKind _kindFromTag(int tag) {
  for (final entry in _kindTags.entries) {
    if (entry.value == tag) return entry.key;
  }
  throw const AppFailure('call.malformed_signal');
}

/// The serialized signaling payload for every call-control action (task
/// file §3). Deterministic binary encoding, length-prefixed strings — the
/// same idiom `group_control.dart`/`relay_packet_frame.dart` already
/// establish; never JSON.
///
/// Wire layout (task file §5, big-endian, matching `GroupControlFrame`'s
/// own discipline — every length prefix bounds-checked against the
/// *remaining* buffer before it is used to slice):
///
///   [u8  version]
///   [u8  kind]                                    // explicit tag, see [_kindTags]
///   [u32 callIdLen][callId bytes]
///   [u32 fromDeviceIdLen][fromDeviceId bytes]
///   [u64 createdAtMs]
///   [u8  hasMediaOffer][u32 mediaOfferLen][mediaOffer bytes]  // only if hasMediaOffer
class CallSignalingFrame {
  const CallSignalingFrame({
    required this.kind,
    required this.callId,
    required this.fromDeviceId,
    required this.createdAtMs,
    this.version = callSignalingFrameVersion,
    this.mediaOffer,
  });

  final int version;
  final CallSignalKind kind;
  final String callId;
  final String fromDeviceId;
  final int createdAtMs;

  /// Opaque, optional byte blob the (undecided) real-time media transport
  /// fills in later (`OQ-E07-3`) — present on the wire now so adding media
  /// does not re-version this frame. Empty and unread by this task (task
  /// file §3).
  final Uint8List? mediaOffer;

  Uint8List serialize() {
    final callIdBytes = _utf8(callId);
    final fromDeviceIdBytes = _utf8(fromDeviceId);
    final offer = mediaOffer;

    final totalLength = 1 + // version
        1 + // kind
        4 + callIdBytes.length +
        4 + fromDeviceIdBytes.length +
        8 + // createdAtMs
        1 + // hasMediaOffer
        (offer == null ? 0 : 4 + offer.length);

    final buffer = ByteData(totalLength);
    final bytes = buffer.buffer.asUint8List();
    var offset = 0;

    buffer.setUint8(offset, version);
    offset += 1;

    buffer.setUint8(offset, _kindTags[kind]!);
    offset += 1;

    offset = _putLengthPrefixed(buffer, bytes, offset, callIdBytes);
    offset = _putLengthPrefixed(buffer, bytes, offset, fromDeviceIdBytes);

    buffer.setUint64(offset, createdAtMs);
    offset += 8;

    buffer.setUint8(offset, offer == null ? 0 : 1);
    offset += 1;
    if (offer != null) {
      offset = _putLengthPrefixed(buffer, bytes, offset, offer);
    }

    return bytes;
  }

  /// Decodes bytes produced by [serialize]. Throws
  /// `AppFailure('call.malformed_signal')` on any length/version/trailing-
  /// byte violation — never returns a partially-built frame.
  static CallSignalingFrame deserialize(Uint8List bytes) {
    try {
      if (bytes.isEmpty) {
        throw const AppFailure('call.malformed_signal');
      }
      final view = ByteData.sublistView(bytes);
      var offset = 0;

      final version = view.getUint8(offset);
      if (version != callSignalingFrameVersion) {
        throw const AppFailure('call.malformed_signal');
      }
      offset += 1;

      _requireRemaining(bytes, offset, 1);
      final kind = _kindFromTag(view.getUint8(offset));
      offset += 1;

      final callIdRead = _readLengthPrefixedString(view, bytes, offset);
      final callId = callIdRead.$1;
      offset = callIdRead.$2;

      final fromRead = _readLengthPrefixedString(view, bytes, offset);
      final fromDeviceId = fromRead.$1;
      offset = fromRead.$2;

      _requireRemaining(bytes, offset, 8);
      final createdAtMs = view.getUint64(offset);
      offset += 8;

      _requireRemaining(bytes, offset, 1);
      final hasMediaOffer = view.getUint8(offset);
      offset += 1;
      Uint8List? mediaOffer;
      if (hasMediaOffer == 1) {
        _requireRemaining(bytes, offset, 4);
        final len = view.getUint32(offset);
        offset += 4;
        _requireRemaining(bytes, offset, len);
        mediaOffer = Uint8List.fromList(bytes.sublist(offset, offset + len));
        offset += len;
      } else if (hasMediaOffer != 0) {
        throw const AppFailure('call.malformed_signal');
      }

      if (offset != bytes.length) {
        throw const AppFailure('call.malformed_signal');
      }

      return CallSignalingFrame(
        version: version,
        kind: kind,
        callId: callId,
        fromDeviceId: fromDeviceId,
        createdAtMs: createdAtMs,
        mediaOffer: mediaOffer,
      );
    } on AppFailure {
      rethrow;
    } catch (_) {
      throw const AppFailure('call.malformed_signal');
    }
  }

  static Uint8List _utf8(String s) => Uint8List.fromList(utf8.encode(s));

  static int _putLengthPrefixed(
    ByteData buffer,
    Uint8List bytes,
    int offset,
    Uint8List value,
  ) {
    buffer.setUint32(offset, value.length);
    offset += 4;
    bytes.setRange(offset, offset + value.length, value);
    return offset + value.length;
  }

  static void _requireRemaining(Uint8List bytes, int offset, int needed) {
    if (bytes.length < offset + needed) {
      throw const AppFailure('call.malformed_signal');
    }
  }

  static (String, int) _readLengthPrefixedString(
    ByteData view,
    Uint8List bytes,
    int offset,
  ) {
    _requireRemaining(bytes, offset, 4);
    final length = view.getUint32(offset);
    offset += 4;
    _requireRemaining(bytes, offset, length);
    final value = utf8.decode(bytes.sublist(offset, offset + length));
    return (value, offset + length);
  }
}

/// Current, and so far only, [CallSignalingFrame] wire layout version.
const int callSignalingFrameVersion = 1;

/// The health of the active call's media path — the seam
/// [CallMediaTransport.health] exposes. [NullCallMediaTransport] only ever
/// produces [unavailable] (task file §3): there is no real transport yet,
/// so there is nothing to report beyond that.
enum CallMediaHealth { unavailable }

/// The seam the (undecided) real-time media transport plugs into once
/// `OQ-E07-3` is answered — task file §3/§5. Exactly one implementation
/// exists in this task: [NullCallMediaTransport].
abstract class CallMediaTransport {
  /// Called once a [CallSession] reaches [CallState.active] on this device.
  /// Returns an [AppFailure] if media could not be established; `null` on
  /// success.
  Future<AppFailure?> attach(CallSession session);

  Future<void> detach();

  Stream<CallMediaHealth> get health;
}

/// The honest v1 behaviour while `OQ-E07-3` is open (task file §2/§3): a
/// call that rings, is answered, and then truthfully reports that it
/// cannot carry audio — never a call that pretends to connect.
/// [attach] both returns `AppFailure('call.no_media_transport')` AND drives
/// [session] straight to `ended(failed)` via [CallSession.endLocally] — the
/// caller does not have to separately notice the failure and end the call
/// itself; this transport ends it as part of honestly reporting it cannot
/// serve it. Every manual call attempt against this transport WILL end
/// this way; task file §6 says so explicitly: "that is correct and will
/// look broken."
class NullCallMediaTransport implements CallMediaTransport {
  final StreamController<CallMediaHealth> _healthController =
      StreamController<CallMediaHealth>.broadcast();

  @override
  Future<AppFailure?> attach(CallSession session) async {
    session.endLocally(CallEndReason.failed);
    _healthController.add(CallMediaHealth.unavailable);
    return const AppFailure('call.no_media_transport');
  }

  @override
  Future<void> detach() async {}

  @override
  Stream<CallMediaHealth> get health => _healthController.stream;
}

/// So a dropped/refused call has a diagnosable reason (task file §3),
/// mirroring `GroupMembershipCounters`/`PrekeyExchangeCounters`'s own
/// discipline — mutated only by [CallSignaling] itself.
class CallSignalingCounters {
  /// Inbound invites from a blocked peer — dropped silently, never even a
  /// `busy` reply (FR-BLOCK-001, task file §2: "a decline confirms the
  /// device exists").
  int callInviteFromBlocked = 0;

  /// Inbound invites refused with `busy` — either genuine one-active-call-
  /// per-device contention, or the losing side of a glare (task file §6).
  int callInviteWhileBusy = 0;

  /// Any control frame whose claimed actor disagreed with the session that
  /// decrypted it, or whose `callId` names no known session (task file §6:
  /// "reject any frame whose `callId` names no known session"). Also
  /// bumped when a wire-valid frame arrives for a known session in a state
  /// that no longer accepts it (a race/out-of-order frame) — see
  /// [CallSignaling._applyToCurrentOrDrop].
  int callUnauthenticated = 0;

  /// [CallSession]s (either side) this device's own instance watched reach
  /// `ended(timeout)`.
  int callTimeout = 0;
}

/// Call-invite/ring/accept/decline/hangup/busy/cancel signaling for a
/// single [MessagingStack] (task file §1/§3/§5). Exactly one instance per
/// stack — [MessagingStack.create] constructs it and registers
/// [handleWireFrame] on `stack.inbound` itself, mirroring
/// `PrekeyExchange`/`GroupMembershipService`'s own "exactly one instance"
/// contract.
class CallSignaling {
  CallSignaling({
    required MessagingStack stack,
    RelationshipRepository? relationshipRepository,
    DateTime Function() clock = DateTime.now,
    Duration ringTimeout = defaultRingTimeout,
    CallMediaTransport? mediaTransport,
  })  : _stack = stack,
        _relationshipRepository =
            relationshipRepository ?? RelationshipRepository(stack.db),
        _clock = clock,
        _ringTimeout = ringTimeout,
        _mediaTransport = mediaTransport ?? NullCallMediaTransport();

  final MessagingStack _stack;
  final RelationshipRepository _relationshipRepository;
  final DateTime Function() _clock;
  final Duration _ringTimeout;
  final CallMediaTransport _mediaTransport;

  final CallSignalingCounters counters = CallSignalingCounters();

  /// At most one call at a time (task file §2: "one active call per
  /// device") — there is no roster, no per-peer map.
  CallSession? _currentSession;

  /// The session this device currently has, if any — read-only for a
  /// caller (a call UI, a test) that wants to observe the live call without
  /// going through [invite]/[accept]/[decline]/[hangup].
  CallSession? get currentSession => _currentSession;

  int _packetIdCounter = 0;
  String _nextPacketId() =>
      'call:${_stack.selfDeviceId}-${_clock().microsecondsSinceEpoch}-${_packetIdCounter++}';

  int _callIdCounter = 0;
  String _mintCallId() {
    _callIdCounter += 1;
    return '${_stack.selfDeviceId}-call-${_clock().microsecondsSinceEpoch}-$_callIdCounter';
  }

  // --- Local actions -------------------------------------------------

  /// Places a call to [peerDeviceId] (task file §5). Throws [AppFailure]
  /// with:
  ///   - `call.busy` if this device already has a call ([_currentSession]
  ///     non-null);
  ///   - `call.blocked` if [peerDeviceId] is [RelationshipState.blocked]
  ///     (FR-BLOCK-001);
  ///   - `messaging.no_session` if no pairwise Signal session with
  ///     [peerDeviceId] exists yet — this method never establishes one on
  ///     demand (mirrors `CryptoService.encrypt`'s own documented contract:
  ///     "this task never auto-establishes on demand").
  /// On success, returns a [CallSession] already in
  /// [CallState.outgoingPending]. If the invite frame itself cannot be
  /// sent afterwards (a genuine send failure, distinct from "no session at
  /// all"), the returned session is ended locally with
  /// [CallEndReason.unreachable] rather than this method throwing — the
  /// session object already exists and is already being tracked by the
  /// time a send is attempted, so that failure surfaces through
  /// [CallSession.states]/[CallSession.endReason], not as an exception
  /// from a call that, from this device's perspective, was placed.
  Future<CallSession> invite(String peerDeviceId) async {
    if (_currentSession != null) {
      throw const AppFailure('call.busy');
    }
    if (await _relationshipRepository.isBlocked(peerDeviceId)) {
      throw const AppFailure('call.blocked');
    }
    final address = SignalProtocolAddress(peerDeviceId, _remoteSignalDeviceId);
    if (!await _stack.signalStore.containsSession(address)) {
      throw const AppFailure('messaging.no_session');
    }

    final callId = _mintCallId();
    final session = CallSession(
      callId: callId,
      peerDeviceId: peerDeviceId,
      isOutgoing: true,
      clock: _clock,
      ringTimeout: _ringTimeout,
    );
    session.onEvent(CallSignalKind.invite);
    _track(session);
    try {
      await _sendFrame(peerDeviceId, CallSignalKind.invite, callId);
    } catch (_) {
      session.endLocally(CallEndReason.unreachable);
    }
    return session;
  }

  /// Accepts the current incoming call. `null` on success; an [AppFailure]
  /// (`call.not_found` / `call.invalid_state`) if [callId] does not match
  /// [_currentSession] or that session is not [CallState.incomingRinging].
  Future<AppFailure?> accept(String callId) async {
    final session = _currentSession;
    if (session == null || session.callId != callId) {
      return const AppFailure('call.not_found');
    }
    if (session.state != CallState.incomingRinging) {
      return const AppFailure('call.invalid_state');
    }
    session.onEvent(CallSignalKind.accept);
    await _sendFrameBestEffort(session.peerDeviceId, CallSignalKind.accept, callId);
    return null;
  }

  /// Declines the current incoming call. Same failure shape as [accept].
  Future<AppFailure?> decline(String callId) async {
    final session = _currentSession;
    if (session == null || session.callId != callId) {
      return const AppFailure('call.not_found');
    }
    if (session.state != CallState.incomingRinging) {
      return const AppFailure('call.invalid_state');
    }
    session.onEvent(CallSignalKind.decline);
    await _sendFrameBestEffort(session.peerDeviceId, CallSignalKind.decline, callId);
    return null;
  }

  /// Ends the current call from either the caller's or an active
  /// participant's side. Sends `cancel` if the call has not been answered
  /// yet ([CallState.outgoingPending]/[CallState.outgoingRinging]) or
  /// `hangup` if it is [CallState.active]. A still-[CallState.incomingRinging]
  /// call must be ended with [decline], not this method — returns
  /// `call.invalid_state` for that case.
  Future<AppFailure?> hangup(String callId) async {
    final session = _currentSession;
    if (session == null || session.callId != callId) {
      return const AppFailure('call.not_found');
    }
    final CallSignalKind kind;
    if (session.state == CallState.outgoingPending ||
        session.state == CallState.outgoingRinging) {
      kind = CallSignalKind.cancel;
    } else if (session.state == CallState.active) {
      kind = CallSignalKind.hangup;
    } else {
      return const AppFailure('call.invalid_state');
    }
    session.onEvent(kind);
    await _sendFrameBestEffort(session.peerDeviceId, kind, callId);
    return null;
  }

  // --- Receive side ----------------------------------------------------

  /// Registered on `stack.inbound.registerControlHandler(kControlKindCallSignaling, ...)`.
  /// The wire frame's own claimed source is used ONLY to select which
  /// pairwise session to attempt decryption under — see this file's header
  /// for why that is not the same thing as trusting it.
  Future<void> handleWireFrame(RelayPacketFrame wireFrame) async {
    final CiphertextMessage ciphertext;
    try {
      ciphertext = decodeCiphertextControlBody(wireFrame.payload);
    } on AppFailure {
      return;
    }

    final address = SignalProtocolAddress(wireFrame.source, _remoteSignalDeviceId);
    final Uint8List plaintext;
    try {
      plaintext = await _stack.cryptoService.decrypt(address, ciphertext);
    } catch (_) {
      // No session, wrong session, tampered ciphertext, replay -- all
      // collapse to the same "not authenticated" outcome from this file's
      // perspective.
      counters.callUnauthenticated++;
      return;
    }

    await handleControlFrame(wireFrame.source, plaintext);
  }

  /// The receive half's business logic (task file §5's contract), separated
  /// from [handleWireFrame]'s decrypt step so it is directly testable
  /// against already-decrypted bytes and an already-verified
  /// [sourceDeviceId] — mirrors `group_membership_service.dart`'s own
  /// `handleControlFrame`/`handleWireFrame` split.
  ///
  /// [sourceDeviceId] MUST be the address of the Signal session [plaintext]
  /// decrypted under — never the wire frame's own unauthenticated claim.
  Future<void> handleControlFrame(
    String sourceDeviceId,
    Uint8List plaintext,
  ) async {
    final CallSignalingFrame signal;
    try {
      signal = CallSignalingFrame.deserialize(plaintext);
    } on AppFailure {
      return;
    }

    if (signal.fromDeviceId != sourceDeviceId) {
      // E06-B04's lesson: the plaintext's own claimed sender is exactly as
      // forgeable as the wire frame's unauthenticated header field ever
      // was -- only the session address that actually decrypted this
      // payload is trustworthy.
      counters.callUnauthenticated++;
      return;
    }

    if (signal.kind == CallSignalKind.invite) {
      await _handleInvite(sourceDeviceId, signal);
      return;
    }
    _applyToCurrentOrDrop(sourceDeviceId, signal.callId, signal.kind);
  }

  Future<void> _handleInvite(
    String sourceDeviceId,
    CallSignalingFrame signal,
  ) async {
    if (await _relationshipRepository.isBlocked(sourceDeviceId)) {
      // FR-BLOCK-001 -- silence, not a `busy`/decline reply: a reply would
      // confirm to a blocked peer that this device exists and is reachable
      // (task file §2).
      counters.callInviteFromBlocked++;
      return;
    }

    final current = _currentSession;
    if (current != null) {
      final isLosingGlareCandidate = current.isOutgoing &&
          current.peerDeviceId == sourceDeviceId &&
          (current.state == CallState.outgoingPending ||
              current.state == CallState.outgoingRinging);
      if (isLosingGlareCandidate &&
          signal.callId.compareTo(current.callId) < 0) {
        // Glare (task file §6): both devices invited each other at
        // (approximately) the same moment. The lower callId wins -- the
        // incoming one is lower, so THIS device's own outgoing attempt is
        // cancelled locally and the incoming invite proceeds exactly like
        // an ordinary one below.
        current.onEvent(CallSignalKind.cancel);
      } else {
        // Either a genuine one-active-call-per-device conflict (a
        // different peer, or an existing call not eligible for glare), or
        // this device wins the glare (its own callId is lower) -- either
        // way: `busy`, never queued (EARS-CALL-4).
        counters.callInviteWhileBusy++;
        await _sendFrameBestEffort(
          sourceDeviceId,
          CallSignalKind.busy,
          signal.callId,
        );
        return;
      }
    }

    final session = CallSession(
      callId: signal.callId,
      peerDeviceId: sourceDeviceId,
      isOutgoing: false,
      clock: _clock,
      ringTimeout: _ringTimeout,
    );
    session.onEvent(CallSignalKind.invite);
    _track(session);
    await _sendFrameBestEffort(sourceDeviceId, CallSignalKind.ringing, signal.callId);
  }

  /// Applies [kind] to [_currentSession] iff it matches both [callId] and
  /// [sourceDeviceId] — task file §6: "reject any frame whose `callId`
  /// names no known session ... never create a session on receipt of a
  /// stray `accept`." A [StateError] from an out-of-order/racing frame
  /// (e.g. a stray `ringing` after the call already went active) is caught
  /// and counted rather than propagated -- a hostile or merely late frame
  /// must never crash this device's own call.
  void _applyToCurrentOrDrop(
    String sourceDeviceId,
    String callId,
    CallSignalKind kind,
  ) {
    final session = _currentSession;
    if (session == null ||
        session.callId != callId ||
        session.peerDeviceId != sourceDeviceId) {
      counters.callUnauthenticated++;
      return;
    }
    try {
      session.onEvent(kind);
    } on StateError {
      counters.callUnauthenticated++;
    }
  }

  // --- Shared bookkeeping ------------------------------------------------

  /// Adopts [session] as [_currentSession] and wires the bookkeeping every
  /// session needs regardless of which side created it or how it was
  /// created: attach media once [CallState.active] is reached, release
  /// [_currentSession] and count a timeout once [CallState.ended] is
  /// reached (from ANY cause -- signal-driven, ring timeout, or media
  /// failure), and dispose the session's own resources.
  void _track(CallSession session) {
    _currentSession = session;
    session.states.listen((state) {
      if (state == CallState.active) {
        unawaited(_mediaTransport.attach(session));
      } else if (state == CallState.ended) {
        if (session.endReason == CallEndReason.timeout) {
          counters.callTimeout++;
        }
        if (identical(_currentSession, session)) {
          _currentSession = null;
        }
        session.dispose();
      }
    });
  }

  Future<void> _sendFrame(
    String peerDeviceId,
    CallSignalKind kind,
    String callId,
  ) async {
    final now = _clock();
    final plaintext = CallSignalingFrame(
      kind: kind,
      callId: callId,
      fromDeviceId: _stack.selfDeviceId,
      createdAtMs: now.millisecondsSinceEpoch,
    ).serialize();

    final address = SignalProtocolAddress(peerDeviceId, _remoteSignalDeviceId);
    final ciphertext = await _stack.cryptoService.encrypt(address, plaintext);
    final body = encodeCiphertextControlBody(ciphertext);
    final framedBody = Uint8List(body.length + 1);
    framedBody[0] = kControlKindCallSignaling;
    framedBody.setRange(1, framedBody.length, body);

    final wireFrame = RelayPacketFrame(
      payloadType: PayloadType.control,
      packetId: _nextPacketId(),
      destination: peerDeviceId,
      source: _stack.selfDeviceId,
      priority: 0,
      createdAtMs: now.millisecondsSinceEpoch,
      expiresAtMs: now.add(_controlFrameTtl).millisecondsSinceEpoch,
      payload: framedBody,
    );
    // Direct transport send -- NOT `relayEngine.enqueue` -- mirrors
    // `prekey_exchange.dart`'s own `_sendControlFrame` reasoning: a call
    // invite/ring/accept/decline/busy/hangup/cancel that outlives a queue
    // wait has already lost its race against the 45s ring timeout, so
    // there is nothing worth queuing for later delivery.
    final delivered = await _stack.transport.send(peerDeviceId, wireFrame.serialize());
    if (!delivered) {
      throw const AppFailure('call.unreachable');
    }
  }

  /// [_sendFrame], but swallowing failure -- for the reply/ack frames
  /// (`ringing`, `busy`, and every reply sent from [accept]/[decline]/
  /// [hangup]) whose own local state change has already committed
  /// regardless of whether the peer ever receives the frame, mirroring
  /// `group_membership_service.dart`'s own `_sendOne` "best-effort, never
  /// rolls back the local change" discipline. [invite] is the one caller
  /// that does NOT use this -- its own send failure has a specific local
  /// consequence (`CallEndReason.unreachable`), handled at that call site
  /// instead.
  Future<void> _sendFrameBestEffort(
    String peerDeviceId,
    CallSignalKind kind,
    String callId,
  ) async {
    try {
      await _sendFrame(peerDeviceId, kind, callId);
    } catch (_) {
      // Best-effort -- see this method's own doc comment.
    }
  }
}
