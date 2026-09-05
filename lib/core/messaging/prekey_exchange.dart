// core/messaging — prekey-bundle exchange and first-contact session
// establishment (E06-T07, closes OQ-E05-T02-1).
//
// `CryptoService.establishSession` (`crypto_stub.dart:73`) has had zero
// callers anywhere in `lib/` since E03-T03 landed, and nothing has ever
// obtained a peer's `PreKeyBundle` from anywhere but the local
// `IdentityService`. This file is where both of those stop being true:
// this is the first, and this task's own, production caller of
// `establishSession`.
//
// **Channel — `OQ-E06-T07-1`, resolved to option (a): inline over the
// mesh, on first contact.** A device asks its peer directly with a
// `PayloadType.control` frame (E06-T02's reserved tag), carried through
// `InboundPipeline`'s `ControlHandler` seam (E06-T05) on the receiving
// side and sent directly via `TransportService.send` (NOT
// `RelayEngine.enqueue`) on the requesting side — the resolved answer is
// explicit that *both devices must be reachable at the moment of first
// contact*, which is exactly what a direct, unqueued transport send means;
// queuing through the relay would silently promise a guarantee (delivery
// to an offline peer) this exchange does not make. **Bundles are NOT
// cached** across requests, per the same resolved answer: every
// `ensureSession` call that needs one issues a fresh `bundleRequest`.
//
// **The control sub-protocol**, nested inside a `RelayPacketFrame`'s
// opaque `payload` field when `payloadType == PayloadType.control` (this
// is the "non-message envelope" `relay_packet_frame.dart` reserves that
// tag for, and this task's own §3):
//
//   [u8  subType]                      // 1=request, 2=response, 3=unavailable
//   [u32 requestIdLen][requestId bytes] // correlates a response/unavailable
//                                       // back to the request that caused it
//   // subType == response only:
//   [u32 bundleLen][bundle bytes]       // PreKeyBundleCodec.serialize() output
//
// A `bundleRequest` carries no bundle data itself; `bundleUnavailable`
// carries nothing past its own `requestId` — an explicit refusal/exhaustion
// signal so a requester fails fast rather than waiting out the full
// timeout on silence (task file §3).
//
// **Trust gate on inbound `bundleRequest` (EARS-COMM-15, FR-TRUST-003/005).**
// Calls the existing `EvaluateConnectionRequestUseCase` (E02-T01) — never
// reinvents trust evaluation. Only `RelationshipState.blocked` is refused;
// `unknown`/`allowed`/`trusted` are all served, because this exchange's
// entire reason to exist is the FIRST message to a peer, at which point a
// relationship row usually does not exist yet (`unknown` is the ordinary
// first-contact case, not a suspicious one — E02-T01's own
// `evaluate_connection_request_use_case.dart` already documents `unknown`
// as "not yet permitted" only for FR-TRUST-005's bidirectional CONNECTION
// gate, a different question from "may this peer ask for a bundle at
// all"). A blocked peer gets **silence** — no `bundleUnavailable` frame
// either — so blocking is not remotely probeable (task file §5); an
// unblocked peer whose pool happens to be exhausted DOES get an explicit
// `bundleUnavailable`, since that is a real, disclosable operational state,
// not a trust decision.
//
// **The identity-key trust decision is never intercepted here.**
// `CryptoService.establishSession` throws `CryptoDecryptFailure` (reason
// `untrustedIdentity`, `crypto_failures.dart`) when a peer's identity key
// contradicts a previously-trusted one — this file's own [ensureSession]
// has no `on CryptoDecryptFailure` clause at all, so that exception always
// propagates to the caller unchanged. Auto-trusting a changed identity key
// would make the Chat screen's "End-to-end encrypted" label a lie (task
// file §4's single most important prohibition) — the task file's own
// contract sketch names this `CryptoUntrustedIdentityFailure`; the type
// that actually exists, and actually propagates, is `CryptoDecryptFailure`
// with `reason == CryptoDecryptFailureReason.untrustedIdentity` (E06-T02's
// taxonomy) — logged as a Deviation (naming only, not behavior) in this
// task's self-review, the same "sketch vs. real name" judgment call
// `messaging_stack.dart`'s own header already recorded for
// `decryptPreKeyMessage`.
//
// **Coalescing is correctness, not an optimization (task file §6,
// L-backend-003's shape).** [ensureSession] is a plain (non-`async`)
// function: it checks `_inFlightByPeer[peerDeviceId]` and, if absent,
// inserts the newly-started future into that map BEFORE returning —
// synchronously, with no `await` in between the check and the insert.
// Since Dart runs synchronous code to completion before yielding at the
// first `await`, two calls made back-to-back (e.g. inside
// `Future.wait([...])`, which evaluates its list literal's elements
// synchronously in order before combining them) can never both observe an
// empty map: the second call always sees the first call's in-flight
// future and is handed that SAME future, never starting a second request
// or consuming a second one-time prekey
// (`test_EARS_COMM_14_concurrent_ensure_session_uses_one_bundle` is the
// falsification asset).
//
// **`OQ-E06-T08-2` retrofit (E06-T08).** `InboundPipeline`'s control-handler
// seam was a single named slot when this file was first built; E06-T08
// (delivery acks) needed a second control sub-protocol sharing the same
// `PayloadType.control` tag, so `InboundPipeline.registerControlHandler`
// now takes a `controlKind` key (`inbound_pipeline.dart`). This file's own
// `_sendControlFrame` prepends [kControlKindPrekeyExchange] to every
// outbound control frame; `InboundPipeline` reads and strips that byte
// before calling [handleControlFrame], so this file's `_ControlBody` tag
// scheme, trust gate, coalescing and provenance logic below are completely
// unchanged by the retrofit — the only lines that moved are inside
// `_sendControlFrame` itself. `handleControlFrame`'s own body still expects
// exactly the same shape it always did: raw `_ControlBody` bytes, no
// foreign byte prepended.
//
// **Response provenance (EARS-COMM-16's sibling risk).** An inbound
// `bundleResponse`/`bundleUnavailable` is matched against
// `_outstandingRequests[requestId]` and is accepted only if that entry
// exists AND its stored `peerDeviceId` equals `frame.source` — a response
// with an unknown `requestId`, or one whose `requestId` is known but
// arrived from a different device than the one the request was sent to, is
// dropped and counted (`counters.responsesUnsolicited`), and never reaches
// `establishSession` (task file §3/§8).
//
// Does NOT modify `IdentityService`, `DriftSignalProtocolStore`,
// `CryptoService`, `SendMessageUseCase`, `InboundPipeline` or
// `EvaluateConnectionRequestUseCase` (task file §4) — every dependency
// below is called exactly as its own epic left it. Does NOT implement a
// Firebase-hosted bundle directory (deferred to E11 per the resolved
// `OQ-E06-T07-1`). Does NOT implement one-time-prekey pool
// expiry/reclamation (`OQ-E06-T07-2`, deferred). Does NOT implement safety
// numbers, a verification UI, or QR exchange (E02 owns trust surfaces).
// Does NOT retry a timed-out request — the message this unblocks stays
// queued, and the caller is free to call [ensureSession] again later
// (task file §4).
//
// `prefer_initializing_formals` is intentionally not applied to this
// file's constructor, matching the same documented exclusion already used
// by `relay_engine.dart`/`inbound_pipeline.dart`/`messaging_coordinator.dart`.
// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import '../auth/google_auth_service.dart' show AppFailure;
import '../crypto/prekey_bundle_codec.dart';
import '../../features/trust/domain/evaluate_connection_request_use_case.dart';
import '../../features/trust/domain/relationship.dart';
import 'messaging_stack.dart';
import 'relay_packet_frame.dart';

/// Matches `messaging_stack.dart`'s own `_localSignalDeviceId` (that file's
/// header, judgment call 1, explains why a Dart-private constant cannot be
/// imported across files and is independently redeclared per file instead
/// — the same constraint applies here).
const int _remoteSignalDeviceId = 1;

/// The `controlKind` byte [InboundPipeline] dispatches on
/// (`inbound_pipeline.dart`, `OQ-E06-T08-2`) — registered in
/// `messaging_stack.dart` against [PrekeyExchange.handleControlFrame].
/// `2` is `DeliveryAckService`'s own reserved value (`delivery_ack.dart`,
/// E06-T08); this device's own control sub-protocol has held `1` since
/// before that retrofit existed, so it is kept rather than renumbered.
const int kControlKindPrekeyExchange = 1;

/// How long an outbound `bundleRequest` waits for a response before
/// [PrekeyExchange.ensureSession] fails with [TimeoutException] (task file
/// §4: "does NOT retry forever … fails the send honestly").
const Duration _defaultEnsureSessionTimeout = Duration(seconds: 20);

/// The wire TTL stamped on every control frame this file sends. Short-lived
/// on purpose — a `bundleRequest`/`bundleResponse` that outlives this has
/// already lost its race against [ensureSession]'s own timeout, and (per
/// this exchange's whole premise, `OQ-E06-T07-1`) is never queued for later
/// delivery anyway.
const Duration _controlFrameTtl = Duration(seconds: 30);

/// So a failed first message has a diagnosable reason (task file §5) —
/// mutated only by [PrekeyExchange] itself.
class PrekeyExchangeCounters {
  /// Outbound `bundleRequest` frames actually sent.
  int requestsSent = 0;

  /// Inbound `bundleRequest`s this device answered with a real bundle.
  int requestsServed = 0;

  /// Inbound `bundleRequest`s from a [RelationshipState.blocked] peer —
  /// answered with silence, never a frame (task file §5).
  int requestsRefused = 0;

  /// Inbound `bundleResponse`/`bundleUnavailable` frames matched to an
  /// outstanding request this device actually made, from the peer it was
  /// sent to.
  int responsesAccepted = 0;

  /// Inbound `bundleResponse`/`bundleUnavailable` frames with no matching
  /// outstanding request (unknown `requestId`, or a `requestId` known but
  /// from the wrong peer) — dropped, never establishes a session.
  int responsesUnsolicited = 0;

  /// [PrekeyExchange.ensureSession] calls whose outbound request never got
  /// a response within its timeout.
  int timeouts = 0;
}

/// One observable connection-request event on
/// [PrekeyExchange.connectionRequests] (E10-T05, task file §3) -- the only
/// new public surface this task adds to this E06-owned class, and
/// observation only: nothing that reads this stream can influence
/// [PrekeyExchange]'s own evaluation, acceptance or session-establishment
/// logic (no behavioural line moves). Carries nothing beyond the decision
/// [EvaluateConnectionRequestUseCase] already made -- no key material, and
/// no other peer/session detail (task file §6).
///
/// Emitted for EVERY [RelationshipState], including
/// [RelationshipState.blocked], BY DESIGN (task file §6 risk: "emitting
/// before the filter is the design") -- so the "blocked never notifies"
/// rule is asserted by a test on the consuming
/// `ConnectionRequestNotificationSource`, not made invisible because the
/// event never existed. The filter to `unknown`-only lives entirely in that
/// source, never here.
class ConnectionRequestNotice {
  const ConnectionRequestNotice({
    required this.peerDeviceId,
    required this.state,
  });

  final String peerDeviceId;
  final RelationshipState state;
}

/// One outstanding outbound `bundleRequest` this device is waiting on.
/// `completer` resolves with the serialized bundle bytes on
/// `bundleResponse`, or `null` on `bundleUnavailable`.
class _OutstandingRequest {
  _OutstandingRequest(this.peerDeviceId, this.completer);

  final String peerDeviceId;
  final Completer<Uint8List?> completer;
}

/// The kind of control body a [PrekeyExchange] frame carries.
enum _ControlSubType {
  bundleRequest(1),
  bundleResponse(2),
  bundleUnavailable(3);

  const _ControlSubType(this.tag);

  final int tag;

  static _ControlSubType fromTag(int tag) {
    for (final type in _ControlSubType.values) {
      if (type.tag == tag) return type;
    }
    throw FormatException('PrekeyExchange: unknown control subType tag $tag');
  }
}

/// The nested wire body inside a control [RelayPacketFrame]'s `payload`
/// (see this file's header for the exact layout). Pure codec, no I/O —
/// mirrors `RelayPacketFrame`/`PreKeyBundleCodec`'s own discipline: every
/// length prefix is bounds-checked before it is used to slice.
class _ControlBody {
  const _ControlBody(this.subType, this.requestId, this.bundleBytes);

  final _ControlSubType subType;
  final String requestId;

  /// Only non-null for [_ControlSubType.bundleResponse].
  final Uint8List? bundleBytes;

  static _ControlBody request(String requestId) =>
      _ControlBody(_ControlSubType.bundleRequest, requestId, null);

  static _ControlBody response(String requestId, Uint8List bundleBytes) =>
      _ControlBody(_ControlSubType.bundleResponse, requestId, bundleBytes);

  static _ControlBody unavailable(String requestId) =>
      _ControlBody(_ControlSubType.bundleUnavailable, requestId, null);

  Uint8List serialize() {
    final requestIdBytes = Uint8List.fromList(utf8.encode(requestId));
    final bundle = bundleBytes ?? Uint8List(0);

    final totalLength = 1 + // subType
        4 + requestIdBytes.length +
        (subType == _ControlSubType.bundleResponse ? 4 + bundle.length : 0);

    final buffer = ByteData(totalLength);
    var offset = 0;

    buffer.setUint8(offset, subType.tag);
    offset += 1;

    buffer.setUint32(offset, requestIdBytes.length);
    offset += 4;
    buffer.buffer
        .asUint8List()
        .setRange(offset, offset + requestIdBytes.length, requestIdBytes);
    offset += requestIdBytes.length;

    if (subType == _ControlSubType.bundleResponse) {
      buffer.setUint32(offset, bundle.length);
      offset += 4;
      buffer.buffer
          .asUint8List()
          .setRange(offset, offset + bundle.length, bundle);
      offset += bundle.length;
    }

    return buffer.buffer.asUint8List();
  }

  static _ControlBody deserialize(Uint8List bytes) {
    if (bytes.isEmpty) {
      throw const FormatException(
        'PrekeyExchange: empty control body, missing subType byte',
      );
    }
    final view = ByteData.sublistView(bytes);
    var offset = 0;

    final subType = _ControlSubType.fromTag(view.getUint8(offset));
    offset += 1;

    _requireRemaining(bytes, offset, 4, 'requestIdLength');
    final requestIdLen = view.getUint32(offset);
    offset += 4;
    _requireRemaining(bytes, offset, requestIdLen, 'requestId');
    final requestId =
        utf8.decode(bytes.sublist(offset, offset + requestIdLen));
    offset += requestIdLen;

    Uint8List? bundleBytes;
    if (subType == _ControlSubType.bundleResponse) {
      _requireRemaining(bytes, offset, 4, 'bundleLength');
      final bundleLen = view.getUint32(offset);
      offset += 4;
      _requireRemaining(bytes, offset, bundleLen, 'bundle');
      bundleBytes =
          Uint8List.fromList(bytes.sublist(offset, offset + bundleLen));
      offset += bundleLen;
    }

    if (offset != bytes.length) {
      throw const FormatException(
        'PrekeyExchange: control body declared fields do not account for '
        'the buffer exactly (trailing or missing bytes)',
      );
    }

    return _ControlBody(subType, requestId, bundleBytes);
  }

  static void _requireRemaining(
    Uint8List bytes,
    int offset,
    int needed,
    String field,
  ) {
    if (bytes.length < offset + needed) {
      throw FormatException(
        'PrekeyExchange: truncated control body, missing $field '
        '(need $needed byte(s) at offset $offset, only '
        '${bytes.length - offset} remain)',
      );
    }
  }
}

/// First-contact session establishment (see this file's header). Exactly
/// one instance per [MessagingStack] — [MessagingStack.create] constructs
/// it and registers [handleControlFrame] on `stack.inbound` itself; nothing
/// else should construct a second instance against the same stack.
class PrekeyExchange {
  PrekeyExchange({
    required MessagingStack stack,
    required EvaluateConnectionRequestUseCase evaluateConnectionRequest,
    DateTime Function() clock = DateTime.now,
  })  : _stack = stack,
        _evaluateConnectionRequest = evaluateConnectionRequest,
        _clock = clock;

  final MessagingStack _stack;
  final EvaluateConnectionRequestUseCase _evaluateConnectionRequest;
  final DateTime Function() _clock;

  final PrekeyExchangeCounters counters = PrekeyExchangeCounters();

  /// E10-T05's own observation seam (task file §3) — broadcast so a
  /// notification producer registering after this device has already
  /// evaluated requests in flight, or a second listener, never steals
  /// events from the other. Closed by [dispose].
  final StreamController<ConnectionRequestNotice> _connectionRequests =
      StreamController<ConnectionRequestNotice>.broadcast();

  /// Broadcast stream of connection-request evaluation events (E10-T05,
  /// task file §3) — observation only, never control. Emits at BOTH
  /// evaluation sites ([_ensureSessionUncoalesced] and
  /// [_handleBundleRequest]), for every [RelationshipState] — see
  /// [ConnectionRequestNotice]'s own doc comment for why the filter is
  /// deliberately not applied here.
  Stream<ConnectionRequestNotice> get connectionRequests =>
      _connectionRequests.stream;

  /// Publishes one [ConnectionRequestNotice] on [connectionRequests]
  /// (E10-T05). A closed controller (post-[dispose]) silently drops the
  /// event rather than throwing — mirrors `CallSignaling._emitNotice`'s own
  /// "closed controller -> no-op" discipline (E10-T04). A run with no
  /// notification producer registered at all (every pre-existing test in
  /// this suite) simply has no listener, which is equally silent — this
  /// task's own "additive, changes no evaluation/acceptance/session
  /// behaviour" contract (task file §2) is satisfied either way.
  void _emitConnectionRequestNotice(
    String peerDeviceId,
    RelationshipState state,
  ) {
    if (_connectionRequests.isClosed) return;
    _connectionRequests.add(
      ConnectionRequestNotice(peerDeviceId: peerDeviceId, state: state),
    );
  }

  /// One in-flight [ensureSession] future per peer — the coalescing map
  /// this file's header describes. Never awaited-into from inside
  /// [ensureSession] itself before the map write; see that method.
  final Map<String, Future<void>> _inFlightByPeer = <String, Future<void>>{};

  /// One outstanding outbound request per `requestId` — NOT per peer, so a
  /// stale response for a request this device has already timed out and
  /// forgotten cannot be confused with a newer one to the same peer.
  final Map<String, _OutstandingRequest> _outstandingRequests =
      <String, _OutstandingRequest>{};

  int _requestCounter = 0;

  String _nextRequestId() {
    _requestCounter += 1;
    return '${_stack.selfDeviceId}-pkx-$_requestCounter';
  }

  /// Completes when a Signal session exists with [peerDeviceId] — the one
  /// entry point a caller needs before a first send (task file §5).
  /// Concurrent calls for the SAME peer coalesce onto one in-flight request
  /// (this file's header) — deliberately not `async` so the coalescing
  /// check-and-insert below is atomic with respect to any other call made
  /// before this one's first `await`.
  Future<void> ensureSession(
    String peerDeviceId, {
    Duration timeout = _defaultEnsureSessionTimeout,
  }) {
    final inFlight = _inFlightByPeer[peerDeviceId];
    if (inFlight != null) {
      return inFlight;
    }
    final future = _ensureSessionUncoalesced(peerDeviceId, timeout);
    _inFlightByPeer[peerDeviceId] = future;
    return future;
  }

  /// Removes this peer's coalescing entry itself, in its OWN `finally`
  /// block, rather than via a second `.whenComplete()` listener chained
  /// onto the future [ensureSession] hands back to its caller. A second
  /// listener attached to that same future — even one whose `onError`
  /// callback swallows the error, as an earlier version of this method
  /// did — was observed to make `package:test`'s `expectLater(...,
  /// throwsA(...))` report the underlying exception as an UNHANDLED
  /// asynchronous error and fail the test even though the matcher itself
  /// matched correctly (reproduced in isolation before this fix landed).
  /// Doing the cleanup from inside this async function's own `finally`
  /// avoids a second listener on the outer future altogether — there is
  /// only ever the one path (the future [ensureSession] returns) by which
  /// any caller, test or production, observes this call's outcome.
  Future<void> _ensureSessionUncoalesced(
    String peerDeviceId,
    Duration timeout,
  ) async {
    try {
      final address =
          SignalProtocolAddress(peerDeviceId, _remoteSignalDeviceId);
      if (await _stack.signalStore.containsSession(address)) {
        return;
      }

      final relationship = await _evaluateConnectionRequest(peerDeviceId);
      // E10-T05: emitted AFTER the relationship resolves, for every state
      // (task file §3/§6) — see [ConnectionRequestNotice]'s own doc comment
      // for why the filter is not applied here.
      _emitConnectionRequestNotice(peerDeviceId, relationship);
      if (relationship == RelationshipState.blocked) {
        throw const AppFailure('messaging.peer_blocked');
      }

      final requestId = _nextRequestId();
      final completer = Completer<Uint8List?>();
      _outstandingRequests[requestId] =
          _OutstandingRequest(peerDeviceId, completer);

      try {
        await _sendControlFrame(
          peerDeviceId,
          _ControlBody.request(requestId).serialize(),
        );
        counters.requestsSent++;

        final Uint8List? bundleBytes;
        try {
          bundleBytes = await completer.future.timeout(timeout);
        } on TimeoutException {
          counters.timeouts++;
          rethrow;
        }

        if (bundleBytes == null) {
          throw const AppFailure('messaging.bundle_unavailable');
        }

        final bundle = PreKeyBundleCodec.deserialize(bundleBytes);
        // Never caught here -- CryptoDecryptFailure(untrustedIdentity)
        // propagates unchanged (task file §4, this file's header).
        await _stack.cryptoService.establishSession(address, bundle);
      } finally {
        _outstandingRequests.remove(requestId);
      }
    } finally {
      _inFlightByPeer.remove(peerDeviceId);
    }
  }

  /// Registered on `stack.inbound.registerControlHandler` (E06-T05's seam).
  /// Dispatches a `PayloadType.control` frame addressed to this device by
  /// its nested `_ControlBody.subType`. A malformed control body is dropped
  /// silently (`InboundPipeline._handleBuffer`'s own `catch (_)` around
  /// this handler already guarantees a throw here cannot take the receive
  /// loop down; this method also never lets a malformed body escape as an
  /// uncaught exception itself).
  Future<void> handleControlFrame(RelayPacketFrame frame) async {
    final _ControlBody body;
    try {
      body = _ControlBody.deserialize(frame.payload);
    } on FormatException {
      return;
    }

    switch (body.subType) {
      case _ControlSubType.bundleRequest:
        await _handleBundleRequest(frame.source, body.requestId);
      case _ControlSubType.bundleResponse:
        _handleBundleResponse(frame.source, body.requestId, body.bundleBytes!);
      case _ControlSubType.bundleUnavailable:
        _handleBundleUnavailable(frame.source, body.requestId);
    }
  }

  Future<void> _handleBundleRequest(
    String peerDeviceId,
    String requestId,
  ) async {
    final relationship = await _evaluateConnectionRequest(peerDeviceId);
    // E10-T05: emitted AFTER the relationship resolves, for every state
    // (task file §3/§6) — same as the other evaluation site above.
    _emitConnectionRequestNotice(peerDeviceId, relationship);
    if (relationship == RelationshipState.blocked) {
      // Silence, not a refusal frame -- task file §5: blocking must not be
      // remotely probeable.
      counters.requestsRefused++;
      return;
    }

    final PreKeyBundle bundle;
    try {
      bundle = await _stack.identityService.getLocalPreKeyBundle();
    } on StateError {
      // Pool exhaustion (or identity not bootstrapped) -- a real,
      // disclosable operational state, unlike a blocked peer, so the
      // requester gets an explicit `bundleUnavailable` rather than silence
      // (task file §3).
      await _sendControlFrame(
        peerDeviceId,
        _ControlBody.unavailable(requestId).serialize(),
      );
      return;
    }

    counters.requestsServed++;
    final bundleBytes = PreKeyBundleCodec.serialize(bundle);
    await _sendControlFrame(
      peerDeviceId,
      _ControlBody.response(requestId, bundleBytes).serialize(),
    );
  }

  void _handleBundleResponse(
    String peerDeviceId,
    String requestId,
    Uint8List bundleBytes,
  ) {
    final completer = _takeMatchingCompleter(peerDeviceId, requestId);
    if (completer == null) {
      counters.responsesUnsolicited++;
      return;
    }
    counters.responsesAccepted++;
    completer.complete(bundleBytes);
  }

  void _handleBundleUnavailable(String peerDeviceId, String requestId) {
    final completer = _takeMatchingCompleter(peerDeviceId, requestId);
    if (completer == null) {
      counters.responsesUnsolicited++;
      return;
    }
    completer.complete(null);
  }

  /// Only a response/unavailable for a request THIS device actually made,
  /// from the peer it was sent to, is accepted (EARS-COMM-16's sibling
  /// risk, task file §3/§8) -- an unknown `requestId`, a `requestId` known
  /// but from the wrong peer, or a `requestId` already resolved (a
  /// duplicate/late second frame for the same request, the mesh's own
  /// forwarding-duplicate hazard) is treated exactly like an unsolicited
  /// frame: dropped, counted, never touches [ensureSession]'s completer
  /// twice.
  Completer<Uint8List?>? _takeMatchingCompleter(
    String peerDeviceId,
    String requestId,
  ) {
    final outstanding = _outstandingRequests[requestId];
    if (outstanding == null || outstanding.peerDeviceId != peerDeviceId) {
      return null;
    }
    if (outstanding.completer.isCompleted) {
      return null;
    }
    return outstanding.completer;
  }

  Future<void> _sendControlFrame(String peerDeviceId, Uint8List body) async {
    final now = _clock();
    // `OQ-E06-T08-2` retrofit: prepend the `controlKind` byte so
    // `InboundPipeline` can tell this sub-protocol's frames apart from
    // `DeliveryAckService`'s (both use `PayloadType.control`) — stripped
    // back off before [handleControlFrame] ever sees it
    // (`inbound_pipeline.dart`), so this file's own `_ControlBody` framing
    // above is completely unaffected.
    final framedBody = Uint8List(body.length + 1);
    framedBody[0] = kControlKindPrekeyExchange;
    framedBody.setRange(1, framedBody.length, body);
    final frame = RelayPacketFrame(
      payloadType: PayloadType.control,
      packetId: _nextRequestId(),
      destination: peerDeviceId,
      source: _stack.selfDeviceId,
      priority: 0,
      createdAtMs: now.millisecondsSinceEpoch,
      expiresAtMs: now.add(_controlFrameTtl).millisecondsSinceEpoch,
      payload: framedBody,
    );
    // Direct transport send -- NOT `relayEngine.enqueue` -- per the
    // resolved `OQ-E06-T07-1`: this exchange only ever works with both
    // devices reachable right now, so there is nothing to queue for later
    // (this file's header).
    await _stack.transport.send(peerDeviceId, frame.serialize());
  }

  /// Closes [_connectionRequests] (E10-T05, task file §7: "controller
  /// closed in the existing teardown"). `PrekeyExchange` had no dispose
  /// method of its own before this task — mirrors `CallSignaling.dispose()`'s
  /// identical "no composition-root call site yet" gap (E10-T04, that
  /// file's own doc comment): `MessagingStack.dispose()`
  /// (`messaging_stack.dart:605`) never calls anything on `prekeyExchange`
  /// today, and wiring that cross-file call site is outside this task's own
  /// `files:` fence, so it is not wired here — disclosed as a Deviation in
  /// this task's own self-review, same disclosure shape as E10-T04's.
  Future<void> dispose() async {
    await _connectionRequests.close();
  }
}
