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
// Does NOT implement group/conference calling (`OQ-E07-11`), mid-call route
// migration (E07-T11), call UI, a route, a notification, or call-history
// persistence (task file §4).
//
// **E07-T10 update (FR-CALL-002 — calls outrank non-real-time sync).**
// [_sendFrame] now marks every outgoing signaling frame at
// [RelayPriority.realtime] and calls `routingEngine.computeRoute` under
// [TrafficProfile.realtime]. The direct-neighbor send this file's own
// original reasoning describes (a signaling frame that outlives a queue
// wait has already lost its race against the 45s ring timeout, so there is
// nothing worth queuing for later delivery) is preserved as the fast path
// for a directly-reachable peer or an unknown route — this device's own
// `RoutingEngine` never has graph knowledge of a peer it has not
// discovered links to/through, so this is also the ONLY path exercised by
// this file's own pre-existing test suite. When `computeRoute` DOES know a
// multi-hop path (this device is not the peer's direct neighbor), the frame
// is handed to `relayEngine.enqueue` at [RelayPriority.realtime] instead —
// the same shared queue every other packet uses (task file §4: "one queue,
// ordered") — with an immediate `processQueue()` call so the attempt is not
// left to the periodic coordinator tick (60s default, longer than the 45s
// ring timeout this file's own reasoning already worries about).
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
import '../routing_engine/relay_engine.dart'
    show RelayDeliveryState, RelayPriority;
import '../routing_engine/route_cost_calculator.dart' show TrafficProfile;
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
  // E07-T11 (FR-CALL-003): the make-before-break validation probe/echo.
  // New tags, appended -- never reusing 1-7 (task file's own contract: the
  // wire value must survive `CallSignalKind`'s declaration being reordered).
  CallSignalKind.pathProbe: 8,
  CallSignalKind.pathProbeEcho: 9,
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

/// One observable call-lifecycle event on [CallSignaling.notices] (E10-T04,
/// task file §3) -- the only new public surface this task adds to this
/// E07-owned class, and observation only: nothing that reads this stream can
/// influence [CallSignaling]'s own state machine. Carries nothing beyond
/// identification -- no display name, no wire bytes, no [CallSession]
/// reference -- a listener (`CallNotificationSource`) reads only what it
/// needs to post/cancel a notification.
class CallNotice {
  const CallNotice({
    required this.kind,
    required this.callId,
    required this.peerDeviceId,
  });

  final CallNoticeKind kind;
  final String callId;
  final String peerDeviceId;
}

/// Closed set (task file §5: "a new kind is a new decision, not an
/// implementation detail"). Maps exactly onto the four ways a
/// [CallState.incomingRinging] session can leave that state --
/// [CallSession.onEvent]'s own transition table only allows `accept`,
/// `decline`, `cancel`, or the internal ring timer's own `endLocally(timeout)`
/// call from `incomingRinging` -- plus [invite], the moment a ring
/// notification first becomes warranted. Every other [CallEndReason]
/// (`busy`/`hangup`/`failed`/`unreachable`) either never applies to an
/// `incomingRinging` session at all (`busy` only ever ends an outgoing
/// session; `hangup` only ever ends an `active` one) or arrives strictly
/// after [answered] already withdrew the ring notification (`failed` is
/// always a post-`active` media failure) -- see [CallSignaling]'s own
/// emission sites (`_track`/`_emitTerminalNotice`) for the exhaustive
/// enumeration task file §6's risk asks for ("verify by enumerating the
/// exits, not by testing the happy one").
enum CallNoticeKind { invite, answered, declined, timedOut, remoteCancelled }

/// The health of the active call's media path — the seam
/// [CallMediaTransport.health] exposes. [NullCallMediaTransport] only ever
/// produces [unavailable] (task file §3): there is no real transport yet,
/// so there is nothing to report beyond that.
///
/// [live] is appended by E07-T11 (FR-CALL-003) — appended, not inserted,
/// matching `CallSignalKind`'s own reordering discipline in this file.
/// `CallMigrationController` waits for exactly this value on
/// [CallMediaTransport.health] after [CallMediaTransport.attach] succeeds,
/// before it will detach the old route (task file §5's ordered sequence:
/// "`media.attach(new) -> health live -> media.detach(old)`").
enum CallMediaHealth { unavailable, live }

/// The seam the (undecided) real-time media transport plugs into once
/// `OQ-E07-3` is answered — task file §3/§5. Exactly one implementation
/// exists in this task: [NullCallMediaTransport].
///
/// **[attach] itself never ends the [CallSession] it is given** (E07-T11
/// correction — see [NullCallMediaTransport]'s own doc comment for why):
/// it only reports success/failure. A caller that treats *any* attach
/// failure as fatal to the whole call (`CallSignaling._track`, on the
/// call's first activation) may end the session itself; a caller using this
/// seam for an *optional* mid-call migration (`CallMigrationController`)
/// must not, and does not.
abstract class CallMediaTransport {
  /// Called once a [CallSession] reaches [CallState.active] on this device
  /// (the initial attach), or again by `CallMigrationController` for a
  /// migration candidate route. Returns an [AppFailure] if media could not
  /// be established; `null` on success. Never itself decides whether a
  /// failure ends the call — see this class's own doc comment.
  Future<AppFailure?> attach(CallSession session);

  Future<void> detach();

  Stream<CallMediaHealth> get health;
}

/// The honest v1 behaviour while `OQ-E07-3` is open (task file §2/§3): a
/// call that rings, is answered, and then truthfully reports that it
/// cannot carry audio — never a call that pretends to connect. [attach]
/// always returns `AppFailure('call.no_media_transport')` and always
/// reports [CallMediaHealth.unavailable] — it never produces
/// [CallMediaHealth.live], so a `CallMigrationController` waiting on that
/// value for a migration candidate will correctly time out and stay on the
/// existing route rather than migrate blind (task file §2, §8
/// EARS-CALL-10).
///
/// **E07-T11 correction:** [attach] used to call
/// [CallSession.endLocally] itself, which was correct for [CallSignaling]'s
/// own use (the *initial* attach on [CallState.active] — a call this device
/// genuinely cannot carry audio for is honestly a failed call,
/// EARS-CALL-5) but is wrong for `CallMigrationController`'s use of this
/// exact same seam for an *optional* migration attempt on an
/// already-established call — EARS-CALL-10 requires a media-attach failure
/// mid-call to leave the call `active`, never to end it. Ending the call is
/// now [CallSignaling._track]'s own reaction to a failed *initial* attach
/// (see that method), not this class's; `CallMigrationController` reacts to
/// the same failure by abandoning the migration and staying on the current
/// route instead. This is a pure relocation of one line, not a change to
/// what EARS-CALL-5 proves: the accept-then-media-fails integration inside
/// `test_EARS_CALL_2_invite_accept_reaches_active_on_both_ends`
/// (`call_signaling_test.dart`) still passes unmodified, since the net
/// effect through [CallSignaling] is identical.
class NullCallMediaTransport implements CallMediaTransport {
  final StreamController<CallMediaHealth> _healthController =
      StreamController<CallMediaHealth>.broadcast();

  @override
  Future<AppFailure?> attach(CallSession session) async {
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

  /// E10-T04's own observation seam (task file §3) -- broadcast so a
  /// notification producer registering after this device already has calls
  /// in flight, or a second listener (a future call UI), never steals events
  /// from the other. Closed by [dispose].
  final StreamController<CallNotice> _notices =
      StreamController<CallNotice>.broadcast();

  /// Broadcast stream of call-lifecycle events for a notification producer
  /// to observe (E10-T04, task file §3) -- observation only, never control.
  /// See [CallNoticeKind] for the closed set of values ever emitted here.
  Stream<CallNotice> get notices => _notices.stream;

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
    // E07-T11 (FR-CALL-003): `pathProbe`/`pathProbeEcho` never touch
    // `CallSession.onEvent` -- neither is in that method's transition table
    // (`call_session.dart`'s own doc comment), so routing them through
    // `_applyToCurrentOrDrop` below would throw `StateError` on every single
    // probe. They validate a candidate route without changing call state at
    // all, so they get their own dispatch branches instead.
    if (signal.kind == CallSignalKind.pathProbe) {
      await _handlePathProbe(sourceDeviceId, signal);
      return;
    }
    if (signal.kind == CallSignalKind.pathProbeEcho) {
      _handlePathProbeEcho(sourceDeviceId, signal);
      return;
    }
    _applyToCurrentOrDrop(sourceDeviceId, signal.callId, signal.kind);
  }

  /// Replies to a validation probe with [CallSignalKind.pathProbeEcho],
  /// iff [signal] names this device's own [_currentSession] exactly (same
  /// callId + peer check as [_applyToCurrentOrDrop] -- task file §6: "reject
  /// any frame whose `callId` names no known session"). Best-effort, same
  /// reasoning as every other reply this file sends: the probe's own
  /// consequence (the sender either sees an echo in time or doesn't) is
  /// entirely the sender's problem, not this device's.
  Future<void> _handlePathProbe(
    String sourceDeviceId,
    CallSignalingFrame signal,
  ) async {
    final session = _currentSession;
    if (session == null ||
        session.callId != signal.callId ||
        session.peerDeviceId != sourceDeviceId) {
      counters.callUnauthenticated++;
      return;
    }
    await _sendFrameBestEffort(
      sourceDeviceId,
      CallSignalKind.pathProbeEcho,
      signal.callId,
    );
  }

  /// Publishes [signal]'s `callId` on [pathProbeEchoes], iff it names this
  /// device's own [_currentSession] exactly -- same authentication shape as
  /// every other inbound handler in this file (never trusts a stray/forged
  /// echo for a call this device isn't actually in).
  void _handlePathProbeEcho(String sourceDeviceId, CallSignalingFrame signal) {
    final session = _currentSession;
    if (session == null ||
        session.callId != signal.callId ||
        session.peerDeviceId != sourceDeviceId) {
      counters.callUnauthenticated++;
      return;
    }
    _pathProbeEchoController.add(signal.callId);
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
    // E10-T04: emitted AFTER `_track` has adopted the session as
    // `_currentSession` and its state transition has already completed --
    // never from inside a lock/critical section (task file §6 risk: a
    // synchronous listener re-entering while this device is still mid-
    // transition). This is the ONLY emission site for [CallNoticeKind.invite]
    // -- an outbound call placed via [invite] above never reaches here and
    // never emits one, since there is nothing to ring a notification for on
    // the caller's own device.
    _emitNotice(CallNoticeKind.invite, session);
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
        unawaited(_attachInitialMedia(session));
        // E10-T04: reached from BOTH `outgoingPending/outgoingRinging` and
        // `incomingRinging` (see `CallSession.onEvent`'s `accept` row) --
        // emitted unconditionally rather than gated on `!session.isOutgoing`
        // to keep this diff to an emission only, no new branching on top of
        // the existing `if` (task file §6 risk: "do not restructure"). The
        // caller's own session never had an [invite] notice posted for it in
        // the first place, so the resulting cancel is a harmless no-op --
        // see `CallNotificationSource`'s own header for why.
        _emitNotice(CallNoticeKind.answered, session);
      } else if (state == CallState.ended) {
        if (session.endReason == CallEndReason.timeout) {
          counters.callTimeout++;
        }
        _emitTerminalNotice(session);
        if (identical(_currentSession, session)) {
          _currentSession = null;
        }
        session.dispose();
      }
    });
  }

  /// Publishes one [CallNotice] on [notices] (E10-T04). A closed controller
  /// (post-[dispose]) silently drops the event rather than throwing --
  /// mirrors [CallSession.recordMigrationEvent]'s own "closed controller ->
  /// no-op" discipline in the sibling file. A run with no notification
  /// producer registered at all (every pre-existing test in this suite)
  /// simply has no listener, which is equally silent -- this task's own
  /// "additive, changes no call behaviour" contract (task file §2) is
  /// satisfied either way.
  void _emitNotice(CallNoticeKind kind, CallSession session) {
    if (_notices.isClosed) return;
    _notices.add(
      CallNotice(
        kind: kind,
        callId: session.callId,
        peerDeviceId: session.peerDeviceId,
      ),
    );
  }

  /// Maps [session]'s [CallSession.endReason] onto [CallNoticeKind] where one
  /// exists (task file §5's closed set) -- see [CallNoticeKind]'s own doc
  /// comment for why `busy`/`hangup`/`failed`/`unreachable` intentionally map
  /// to nothing here.
  void _emitTerminalNotice(CallSession session) {
    final CallNoticeKind? kind = switch (session.endReason) {
      CallEndReason.declined => CallNoticeKind.declined,
      CallEndReason.timeout => CallNoticeKind.timedOut,
      CallEndReason.cancelled => CallNoticeKind.remoteCancelled,
      _ => null,
    };
    if (kind != null) _emitNotice(kind, session);
  }

  /// The *initial* media attach on [CallState.active] (task file §3,
  /// EARS-CALL-5) — the one place a failed [CallMediaTransport.attach] ends
  /// the whole call, since a call this device cannot carry audio for at all
  /// is honestly a failed call. See [CallMediaTransport]'s own doc comment
  /// (E07-T11 correction) for why this reaction now lives here rather than
  /// inside [NullCallMediaTransport.attach] itself: `CallMigrationController`
  /// calls [CallMediaTransport.attach] again for a migration candidate on an
  /// already-active call, and a failure there must NOT end the call
  /// (EARS-CALL-10) — only this, the first attach, is fatal.
  Future<void> _attachInitialMedia(CallSession session) async {
    final failure = await _mediaTransport.attach(session);
    if (failure != null) {
      session.endLocally(CallEndReason.failed);
    }
  }

  /// Sends a [CallSignalKind.pathProbe] frame for [callId]/[peerDeviceId]
  /// (E07-T11, task file §5) — `CallMigrationController`'s validation step:
  /// "send a probe over the candidate, wait for its echo within a bounded
  /// timeout." Returns `true` only if the frame actually left this device
  /// (the same delivery evidence [_sendFrame] already computes for every
  /// other kind — a direct `transport.send` boolean, or a multi-hop
  /// enqueue's real `forwarding`/`delivered` state); `false` on any send
  /// failure, mirroring [_sendFrameBestEffort]'s own "never throw, just
  /// report" shape rather than that method's swallowed-exception one, since
  /// the caller here (the migration controller) needs the boolean to decide
  /// whether to even start waiting for an echo.
  Future<bool> sendPathProbe(String callId, String peerDeviceId) async {
    try {
      await _sendFrame(peerDeviceId, CallSignalKind.pathProbe, callId);
      return true;
    } catch (_) {
      // Mirrors `_sendFrameBestEffort`'s own catch-all shape -- any send
      // failure (unreachable, no session, encrypt error) is reported as
      // `false`, never thrown, so the migration controller can decide
      // deterministically whether to even start waiting for an echo.
      return false;
    }
  }

  /// Broadcasts the `callId` of every validated [CallSignalKind.pathProbeEcho]
  /// this device has received for its own [_currentSession] (E07-T11) --
  /// `CallMigrationController` listens here, bounded by its own injected
  /// `probeTimeout`, and cancels its subscription the moment that bound
  /// expires so a LATE echo (arriving after the controller has already
  /// moved on) is never observed by anything -- task file §6's named risk:
  /// "a probe echo arriving after its timeout must be ignored, not applied
  /// late."
  Stream<String> get pathProbeEchoes => _pathProbeEchoController.stream;

  final StreamController<String> _pathProbeEchoController =
      StreamController<String>.broadcast();

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
      priority: RelayPriority.realtime,
      createdAtMs: now.millisecondsSinceEpoch,
      expiresAtMs: now.add(_controlFrameTtl).millisecondsSinceEpoch,
      payload: framedBody,
    );
    final serialized = wireFrame.serialize();

    // E07-T10 (FR-CALL-002): route selection under the realtime profile --
    // see this file's header. `route` is non-null only when this device's
    // own `RoutingEngine` has multi-hop graph knowledge of `peerDeviceId`
    // (this device is not its direct neighbor); every scenario this file's
    // own pre-existing test suite exercises never populates that graph, so
    // `route` is `null` there and the direct send below (this file's
    // original T09 behaviour, byte-for-byte) is what actually runs.
    final route = _stack.routingEngine.computeRoute(
      peerDeviceId,
      TrafficProfile.realtime,
    );

    final bool delivered;
    if (route != null && route.hops.length > 1) {
      // Multi-hop: this device is not the peer's direct neighbor, so the
      // frame needs relaying. Goes through the SAME shared queue every
      // other packet uses (task file §4: "one queue, ordered"), at
      // `RelayPriority.realtime` so a relaying device's own
      // `processQueue()` drains it ahead of message/sync traffic. An
      // immediate `processQueue()` call attempts delivery now rather than
      // waiting for the periodic coordinator tick (60s default, longer
      // than the 45s ring timeout) -- delivery beyond this device's own
      // next hop is store-and-forward like any other relayed packet, so
      // "handed off" is the most this device can honestly report, matching
      // `RelayEngine`'s own documented `forwarding`/`delivered` semantics
      // (never "the end recipient's app confirmed receipt").
      final packetId = await _stack.relayEngine.enqueue(
        peerDeviceId,
        serialized,
        RelayPriority.realtime,
        _controlFrameTtl,
      );
      await _stack.relayEngine.processQueue();
      // Review finding F4 (round 1): `delivered` used to be set `true`
      // unconditionally right after `enqueue`, so a provably-failed send
      // (both bounded retries in `RelayEngine._attempt` exhausted, row still
      // `queued`) could never actually reach the `call.unreachable` throw
      // below. Read back what this device's own queue actually recorded for
      // THIS packet instead of assuming the enqueue succeeded as a send:
      // `forwarding`/`delivered` are the two states `_attempt` only ever
      // writes on a successful hand-off (to an intermediate hop or the final
      // destination's transport, respectively); `queued` (both attempts
      // failed, or no route was found) means it never actually left this
      // device, which is the honest signal to fail on. `processQueue()` is
      // called unbounded above (no `maxPacketsPerCycle`), so this packet is
      // always among the rows attempted this cycle -- there is no
      // budget-selection ambiguity to account for here.
      final state = await _stack.relayEngine.deliveryStateOf(packetId);
      delivered = state == RelayDeliveryState.forwarding ||
          state == RelayDeliveryState.delivered;
    } else {
      // Direct neighbor, or route unknown -- mirrors
      // `prekey_exchange.dart`'s own `_sendControlFrame` reasoning: a call
      // invite/ring/accept/decline/busy/hangup/cancel that outlives a queue
      // wait has already lost its race against the 45s ring timeout, so
      // there is nothing worth queuing for later delivery when the peer is
      // (or is assumed to be) directly reachable.
      delivered = await _stack.transport.send(peerDeviceId, serialized);
    }
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

  /// Closes [_notices] (E10-T04, task file §7: "controller closed in the
  /// existing dispose/teardown path"). `CallSignaling` had no dispose method
  /// of its own before this task -- `MessagingStack.dispose()`
  /// (`messaging_stack.dart`) is test-only and never calls anything on
  /// `callSignaling` today, and wiring that cross-file call site is outside
  /// this task's own `files:` fence. Mirrors `CallSession.dispose()`'s own
  /// "safe to call more than once" discipline in this file's sibling class,
  /// and `NotificationDispatcher.stop()`'s identical "no composition-root
  /// call site yet" gap already accepted in `bindings.dart` by `E10-T03` --
  /// see this task's own Deviations for the same disclosure.
  Future<void> dispose() async {
    await _notices.close();
  }
}
