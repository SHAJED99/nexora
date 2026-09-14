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
// **E07-T06 addition: group text messages.** A fifth `controlKind`
// (`kControlKindGroupMessage == 6` — originally `5`, renumbered after
// E07-T09's `kControlKindCallSignaling` claimed `5` first; see
// `group_message_envelope.dart`'s header) is
// dispatched exactly like `PrekeyExchange`(1)/`DeliveryAckService`(2)/
// `GroupMembershipService`(3)/`GroupCryptoService`(4) before it — via this
// pipeline's own `registerControlHandler` seam — EXCEPT the registration
// call site lives HERE, inside this class's own constructor, rather than in
// `messaging_stack.dart`: this task's `files:` fence updates this file
// directly and does not touch `messaging_stack.dart` at all, so there is no
// external composition-root call site available the way T07/T08/T03/T04
// each had one. The registered handler is a closure, not an eager tear-off,
// so it never dereferences `_stack.groupCryptoService` at CONSTRUCTION time
// (which would throw `LateInitializationError`, exactly the ordering hazard
// `group_membership_service.dart`'s own header already documents for the
// identical reason) — only when a group-message frame actually arrives,
// well after `MessagingStack`'s constructor has finished.
//
// **Receive-side identity (E06-B04, task file §5).** `RelayPacketFrame.
// source` (`frameSourceDeviceId`) is used ONLY as the candidate
// `senderDeviceId` `GroupCryptoService.decryptFromGroup` needs to select
// which sender's chain to attempt — exactly how `GroupMembershipService.
// handleWireFrame` already treats `frame.source` for its own pairwise
// decrypt. The AUTHORITATIVE sender, used for the membership check and for
// every persisted field, is always `GroupMessageEnvelope.senderDeviceId`,
// recovered only after decrypt succeeds — never `frame.source`.
//
// **Ordering deviation from this task's §3 prose, logged here.** §3 lists
// "membership check -> decrypt -> dedupe -> persist". Read literally that
// would require a membership check BEFORE decrypt, but the only identity
// available pre-decrypt is `frame.source` — not the authoritative
// `envelope.senderDeviceId` §5's own contract insists the membership check
// must use ("regardless of what the envelope claims"). Doing the
// authoritative check against an unauthenticated candidate would defeat the
// exact property that instruction protects. This file instead: (1) checks
// the CLEAR routing header's `(groupId, epoch)` against this device's own
// known `groups.membershipEpoch` purely as a cheap, identity-free
// pre-decrypt diagnostic (`groupEpochUnknown` — no crypto needed, nothing to
// authenticate yet); (2) decrypts, candidate-keyed by `frame.source`; (3)
// performs the REAL, authoritative membership check against
// `envelope.senderDeviceId` post-decrypt; (4) dedupes by `messageId`; (5)
// persists. This satisfies every EARS criterion this task names and the
// more specific, safety-critical "never frameSourceDeviceId" rule takes
// precedence over the prose's literal step order.
//
// `prefer_initializing_formals` is intentionally not applied to this file's
// constructor: the fields are private (`_stack`, `_clock`) while the
// constructor's public named parameters (`stack`, `clock`) match the task
// file's documented contract exactly — an initializing formal would rename
// those named-argument keywords to the private field names, breaking every
// call site (relay_engine.dart's header already documents this same
// deliberate exclusion for the identical reason).
//
// **E13-T03 addition: per-claimed-sender relay rate limiting.** `Q-E13-T03-1`
// (this task file's own Open Questions) found that `RelayEngine.enqueue` has
// no sender-identity parameter or column to gate on at all — the human's
// resolution (recorded there) moves the gate to THIS file's forward branch
// instead, the one caller that actually has an identity in scope:
// `frame.source`. `frame.source` is unverified/attacker-claimed (same class
// of issue as the TOFU finding in E09-B09) — this still stops a naive
// flooder using one claimed identity, which is most of the realistic threat
// model; an attacker rotating claimed source ids per frame evades it, which
// is a known, accepted limitation, not a defect this task solves. No schema
// migration: `E13-T01`'s `RateLimiter` keeps its own `rate_limit_counters`
// table, keyed by an arbitrary string bucket key — nothing about
// `relay_packets` changes.
//
// **E13-T05 addition: byte-volume admission control.** This task's own
// task-sharding-time §3 assumed its check belonged inside
// `RelayEngine.enqueue`, mirroring the identical assumption `E13-T03`'s own
// task file made and had to correct (`Q-E13-T03-1`) for the exact same
// reason: `RelayEngine.enqueue` has no sender-identity parameter or column
// to gate on at all. Confirmed at execution time (this task's own
// `OQ-E13-T05-1`, now resolved): the real call site is the SAME one T03
// already gates — this file's forward branch, immediately after T03's own
// count check. This task adds a SECOND, independent `RateLimiter.allow`
// call there — `increment: bytes.length` (the byte-volume of the ORIGINAL
// wire buffer, not `frame.payload.length`) against a distinct
// `storage_volume:` bucket key, still keyed by `frame.source` for
// consistency with T03's own `relay:` bucket. Neither check substitutes for
// the other: a sender could send few-but-huge packets (fails this check,
// passes T03's count check) or many small ones (passes this check, fails
// T03's count check) — either denying is enough to reject the forward. No
// schema migration: reuses the exact same `rate_limit_counters` table T03's
// own gate already uses, merely a different `bucketKey` prefix.
// ignore_for_file: prefer_initializing_formals
import 'dart:async';
import 'dart:typed_data';

import 'package:drift/drift.dart';

import '../abuse/rate_limiter.dart';
import '../auth/google_auth_service.dart' show AppFailure;
import '../crypto/crypto_failures.dart';
import '../persistence/database.dart';
import '../transport/transport_service.dart';
import '../../features/groups/data/group_repository.dart';
import '../../features/groups/domain/group_message_envelope.dart';
import '../../features/messaging/domain/delivery_state_machine.dart';
import '../../features/messaging/domain/message.dart';
import '../../features/trust/data/relationship_repository.dart';
import '../../features/trust/domain/relationship.dart' show RelationshipState;
import 'ciphertext_codec.dart';
import 'identity_announce.dart' show kControlKindIdentityAnnounce;
import 'messaging_stack.dart';
import 'prekey_exchange.dart' show kControlKindPrekeyExchange;
import 'relay_packet_frame.dart';

/// The declared extension point for non-ciphertext (`PayloadType.control`)
/// frames addressed to this device — T07 (prekey bundles) and T08 (acks)
/// register their own handler here instead of editing this file (task file
/// §3). This task defines the seam and registers nothing.
///
/// **E06-T08 retrofit (`OQ-E06-T08-2`).** The frame this handler receives
/// has already had its leading `controlKind` byte read AND stripped by
/// [InboundPipeline._handleBuffer] — `frame.payload` here is exactly the
/// registering sub-protocol's own body, with no foreign byte prepended.
/// This typedef's signature is otherwise unchanged from E06-T05/T07: only
/// the dispatch mechanism above it changed, not what a handler is handed.
typedef ControlHandler = Future<void> Function(RelayPacketFrame frame);

/// E04-B12: the identity-announce handler's own signature — deliberately
/// NOT [ControlHandler], because this handler needs [linkDeviceId] (the
/// Bluetooth address `TransportService.incomingData(deviceId)` delivered
/// the frame on) that no other control handler needs, since this is the
/// one controlKind whose frame bypasses the normal `isForUs`-gated
/// dispatch entirely (see [InboundPipeline._handleBuffer] and
/// `identity_announce.dart`'s header for the full justification).
typedef IdentityAnnounceHandler = Future<void> Function(
  String linkDeviceId,
  RelayPacketFrame frame,
);

/// E04-B14: the prekey-exchange handler's own signature — deliberately NOT
/// [ControlHandler], mirroring [IdentityAnnounceHandler]'s already-
/// established precedent immediately above. `PrekeyExchange
/// ._takeMatchingCompleter`'s own bundle-response provenance check needs
/// [linkDeviceId] (the physical link this frame arrived on, independently
/// known to this device regardless of what the frame's `source` claims) to
/// bind acceptance to more than an unauthenticated claimed identity plus a
/// `requestId` — see that file's own header, "Response provenance", for the
/// full reasoning this task closes.
///
/// Unlike [IdentityAnnounceHandler], this controlKind is NOT a bypass of
/// `isForUs` — a prekey-exchange frame must still be correctly addressed to
/// this device; only the ADDITIONAL link-binding check is new.
typedef PrekeyExchangeHandler = Future<void> Function(
  String linkDeviceId,
  RelayPacketFrame frame,
);

/// Per-claimed-sender relay admission limit (`FR-ABUSE-001`, E13-T03's own
/// decision — see the task's Run log). 60 forwarded packets per claimed
/// `frame.source` per rolling minute is ~1/second sustained: generous enough
/// that a busy group chat's own relay traffic through this device is never
/// mistaken for flooding (E13-T02's sibling task documents the same
/// "realistic legitimate traffic" reasoning for its own bucket choices), while
/// still bounding what a naive single-identity flooder can force this device
/// to do (queue writes, wake radios) before being denied.
const int _relayRateLimitMaxCount = 60;
const Duration _relayRateLimitWindow = Duration(minutes: 1);

/// Per-claimed-sender byte-volume admission limit (`FR-ABUSE-001`, E13-T05's
/// own decision — see the task's Run log). Independent of, and checked
/// alongside, [_relayRateLimitMaxCount] above: a sender could send few but
/// huge packets (fails this check, passes the count check) or many small
/// ones (passes this check, fails the count check) — neither substitutes
/// for the other (task file §3).
///
/// 5 MiB per claimed `frame.source` per rolling minute — five times
/// `StorageSettingsRepository.minMaxBytes` (1 MiB, `storage_settings_
/// repository.dart`), the smallest total local-storage quota this app lets a
/// user configure for its ENTIRE store across every conversation. Budgeting
/// five times that floor to ONE claimed sender's inbound relay traffic in
/// ONE minute is already generous for legitimate mesh traffic (occasional
/// media forwarding through this device, not just short text messages)
/// while still bounding what a single claimed identity can force this
/// device to write toward local storage before being denied — an
/// unthrottled flooder at this rate would already exceed the smallest
/// configurable device-wide quota in well under a minute.
const int _storageVolumeRateLimitMaxBytes = 5 * 1024 * 1024;
const Duration _storageVolumeRateLimitWindow = Duration(minutes: 1);

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

  /// E04-B27: a fire-and-forget startup task (`_seedKnownDevices` or
  /// `_reconcileOrphanedMessagesByIdentity`) threw. Counted rather than left
  /// as an unhandled async error; both self-heal on the next `start()`.
  int startupTaskFailed = 0;

  /// `ReceiveMessageUseCase.call` returned `null` — FR-MSG-003's documented
  /// duplicate signal, not an error.
  int duplicate = 0;

  /// Handed to `RelayEngine.enqueue` for another destination (FR-ROUTE-002).
  int forwarded = 0;

  /// Newly persisted by `ReceiveMessageUseCase` and emitted on [InboundPipeline.delivered].
  int delivered = 0;

  /// Addressed to this device, `payloadType == control`, and either no
  /// handler is registered for the frame's leading `controlKind` byte, or
  /// the frame's control payload was empty (no `controlKind` byte to read
  /// at all) — dropped and counted, never guessed at (task file §3;
  /// `OQ-E06-T08-2`'s retrofit folds the second case into the same counter
  /// rather than inventing a new one for what is still, at heart, "nobody
  /// registered to handle this").
  int unhandledControl = 0;

  // --- E07-T06: group text messages ------------------------------------

  /// A group-message frame's AUTHORITATIVE sender (`GroupMessageEnvelope.
  /// senderDeviceId`, post-decrypt) is not a current member of that group —
  /// dropped and never stored, regardless of what the envelope claims
  /// (task file §2/§5).
  int groupNotAMember = 0;

  /// `GroupCryptoService.decryptFromGroup` threw `AppFailure('group.
  /// no_chain')` — this device recognizes the group/epoch but holds no
  /// chain for that sender at that epoch yet (task file §6: the honest,
  /// diagnosable "distribution has not landed" state, never a silent
  /// fallback to another epoch).
  int groupNoChain = 0;

  /// The wire frame's clear `(groupId, epoch)` routing header names a group
  /// this device has never heard of, or an epoch strictly ahead of this
  /// device's own `groups.membershipEpoch` — checked BEFORE any decrypt
  /// attempt (no identity to authenticate yet, so no crypto call is wasted
  /// on it), and distinct from [groupNoChain] (task file §6: "make the
  /// counter and the failure code distinct enough that it is diagnosable").
  int groupEpochUnknown = 0;

  // --- E13-T03: relay-flooding admission control -----------------------

  /// The forward branch's claimed sender (`frame.source`) was over its
  /// relay rate limit (`FR-ABUSE-001`, `Q-E13-T03-1`'s resolution) — the
  /// packet is denied `enqueue` entirely: never queued, never counted
  /// toward [forwarded].
  ///
  /// Also incremented by E13-T05's own, independent byte-volume admission
  /// check (`EARS-ABUSE-10/11`) — the two checks share this single counter
  /// (either denying looks the same from the outside: never queued, never
  /// forwarded) rather than each getting its own, since nothing downstream
  /// of this counter (the bug sweep, the Dashboard) needs to distinguish
  /// WHICH gate denied a given packet, only that admission was denied.
  int rateLimited = 0;
}

/// The receive half of the messaging wedge (see this file's header).
/// Constructed once (E06-T06 owns lifecycle) against the whole
/// [MessagingStack], since it needs transport, the relay engine, the receive
/// use case and `selfDeviceId` all at once.
class InboundPipeline {
  InboundPipeline({
    required MessagingStack stack,
    DateTime Function() clock = DateTime.now,
    // E13-T03: constructor-injected, defaulting to a fresh `RateLimiter`
    // bound to this same stack's own `db` — matches this codebase's
    // established "optional named param with a real default, overridable
    // for tests" DI pattern (mirrors `MessagingStack.create`'s own
    // `transport`/`store`/`cryptoService` params) rather than requiring
    // every existing call site to thread one through by hand.
    RateLimiter? rateLimiter,
  })  : _stack = stack,
        _clock = clock,
        _rateLimiter = rateLimiter ?? RateLimiter(stack.db) {
    // E07-T06: self-registered rather than externally wired from
    // `messaging_stack.dart` — see this file's header for why. The closure
    // (not a bare tear-off) defers every `_stack.*` read to invocation time,
    // well after `MessagingStack`'s own constructor has finished.
    registerControlHandler(
      kControlKindGroupMessage,
      (frame) => _handleGroupMessageWireFrame(frame),
    );
  }

  final MessagingStack _stack;
  final DateTime Function() _clock;

  /// E13-T03: the per-claimed-sender relay-flooding admission gate, checked
  /// at the top of the forward branch in [_handleBuffer], before
  /// `RelayEngine.enqueue` is ever called.
  final RateLimiter _rateLimiter;

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

  /// Test-only seam (E04-B07): lets a test confirm `_seedKnownDevices`
  /// genuinely does NOT pre-subscribe a device with no relationship row
  /// (or a non-`trusted`/`allowed` one) — never read by production code.
  /// Deliberately a plain public getter rather than `@visibleForTesting`
  /// (mirrors `call_session.dart`'s own established reasoning: adding a
  /// `package:meta` import to this file for one annotation isn't worth it).
  int get debugConnectionSubscriptionCountForTest =>
      _connectionSubscriptions.length;

  /// `OQ-E06-T08-2` retrofit: one named slot per `controlKind` byte instead
  /// of one named slot total — `PrekeyExchange` (T07, `controlKind == 1`)
  /// and `DeliveryAckService` (T08, `controlKind == 2`) each get their own
  /// key rather than fighting over the single slot this field used to be.
  final Map<int, ControlHandler> _controlHandlers = <int, ControlHandler>{};

  /// E04-B12: the ONE handler slot for [kControlKindIdentityAnnounce] — a
  /// dedicated field, not a slot in [_controlHandlers], because this is the
  /// one controlKind whose dispatch bypasses `isForUs` and needs the link's
  /// own device id (see [IdentityAnnounceHandler]'s own doc comment).
  IdentityAnnounceHandler? _identityAnnounceHandler;

  /// E04-B14: the ONE handler slot for [kControlKindPrekeyExchange] — a
  /// dedicated field, not a slot in [_controlHandlers], mirroring
  /// [_identityAnnounceHandler]'s own reasoning immediately above: this
  /// handler needs the physical link's own device id, which [ControlHandler]
  /// does not carry. Unlike [_identityAnnounceHandler], dispatch to this
  /// handler still happens INSIDE the normal `isForUs`-gated branch (see
  /// [_handleBuffer]) — only the extra [linkDeviceId] argument is new.
  PrekeyExchangeHandler? _prekeyExchangeHandler;

  final InboundCounters counters = InboundCounters();

  final StreamController<Message> _deliveredController =
      StreamController<Message>.broadcast();

  /// One event per message newly persisted by `ReceiveMessageUseCase` — never
  /// for a duplicate. Broadcast: a live update signal for T09's read model
  /// and T11's chat screen, not a buffer that holds this pipeline open when
  /// nothing listens.
  Stream<Message> get delivered => _deliveredController.stream;

  /// E04-B12: one event per Bluetooth-address device id that reaches
  /// `ConnectionState.connected` (emitted from [_onConnectionStateChanged],
  /// same moment an `incomingData` subscription opens for it) — the seam
  /// `messaging_stack.dart` listens on to fire an identity-announce
  /// automatically, mirroring exactly how [deliveryAckService] already
  /// listens on [delivered] there. Broadcast, and — like [delivered] —
  /// produces nothing until [start] actually runs, so merely subscribing to
  /// it (as `messaging_stack.dart`'s constructor does) starts nothing by
  /// itself, keeping this file's own "does NOT start anything" contract
  /// (`messaging_stack.dart`'s header) intact.
  Stream<String> get peerConnected => _peerConnectedController.stream;

  final StreamController<String> _peerConnectedController =
      StreamController<String>.broadcast();

  /// The declared extension point for `PayloadType.control` frames (task
  /// file §3/§5), keyed by [controlKind] since `OQ-E06-T08-2`'s retrofit.
  /// Throws [StateError] if a handler is already registered for THAT
  /// [controlKind] — still one named registration slot per control
  /// sub-protocol, just no longer only one slot total. `[controlKind]`'s
  /// values are owned by whichever sub-protocol registers them
  /// (`PrekeyExchange` uses `1`, `DeliveryAckService` uses `2` — see each
  /// file's own declared constant); this method does not police the
  /// numbering itself, matching E06-T05's original "the seam, not the
  /// policy" scope.
  void registerControlHandler(int controlKind, ControlHandler handler) {
    if (_controlHandlers.containsKey(controlKind)) {
      throw StateError(
        'InboundPipeline.registerControlHandler: a control handler is '
        'already registered for controlKind $controlKind',
      );
    }
    _controlHandlers[controlKind] = handler;
  }

  /// E04-B12: the ONE registration slot for [kControlKindIdentityAnnounce]
  /// — separate from [registerControlHandler] because this handler's own
  /// signature ([IdentityAnnounceHandler]) carries the link's device id, not
  /// just the frame (see that typedef's own doc comment). Throws
  /// [StateError] on a second call, mirroring [registerControlHandler]'s
  /// own guard.
  void registerIdentityAnnounceHandler(IdentityAnnounceHandler handler) {
    if (_identityAnnounceHandler != null) {
      throw StateError(
        'InboundPipeline.registerIdentityAnnounceHandler: a handler is '
        'already registered',
      );
    }
    _identityAnnounceHandler = handler;
  }

  /// E04-B14: the ONE registration slot for [kControlKindPrekeyExchange] —
  /// separate from [registerControlHandler] because this handler's own
  /// signature ([PrekeyExchangeHandler]) carries the physical link's device
  /// id, not just the frame (see that typedef's own doc comment). Throws
  /// [StateError] on a second call, mirroring [registerControlHandler]'s and
  /// [registerIdentityAnnounceHandler]'s own guards.
  ///
  /// `PrekeyExchange` is constructed AFTER [MessagingStack.inbound] itself
  /// (`messaging_stack.dart`'s own constructor order: `inbound = ...` runs
  /// before `prekeyExchange = PrekeyExchange(stack: this, ...)`), so it
  /// self-registers here from inside its own constructor rather than relying
  /// on an external call site in `messaging_stack.dart` — this task's own
  /// `files:` fence does not include that file (mirrors E07-T06's own,
  /// already-established "no external composition-root call site available"
  /// reasoning, this file's header). `messaging_stack.dart`'s pre-existing
  /// `inbound.registerControlHandler(kControlKindPrekeyExchange,
  /// prekeyExchange.handleControlFrame)` call still runs unmodified (out of
  /// this task's fence) but is now provably dead in production: see
  /// [_handleBuffer]'s own dispatch, which routes [kControlKindPrekeyExchange]
  /// through this dedicated slot BEFORE the generic [_controlHandlers] map is
  /// ever consulted — disclosed as a Deviation in this task's own file.
  void registerPrekeyExchangeHandler(PrekeyExchangeHandler handler) {
    if (_prekeyExchangeHandler != null) {
      throw StateError(
        'InboundPipeline.registerPrekeyExchangeHandler: a handler is '
        'already registered',
      );
    }
    _prekeyExchangeHandler = handler;
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
    // E04-B27: both startup tasks stay fire-and-forget (start() is
    // synchronous by contract), but a failure is counted instead of vanishing
    // as an unhandled async error. Both self-heal on the next start().
    unawaited(
      _seedKnownDevices().catchError((Object _) {
        counters.startupTaskFailed++;
      }),
    );
    unawaited(
      _reconcileOrphanedMessagesByIdentity().catchError((Object _) {
        counters.startupTaskFailed++;
      }),
    );
  }

  /// E04-B07: [_onDeviceDiscovered] alone only ever learns about a device
  /// id THIS process's own discovery scan happened to find. An inbound
  /// connection ACCEPTED from an already-trusted peer (`E04-B06`'s own
  /// accept loop) that this process never happened to (re)discover has no
  /// [_connectionSubscriptions] entry at all, so its `CONNECTED` event —
  /// and every byte the peer ever sends over that very-really-open socket —
  /// lands on a broadcast stream with no replay and is gone forever
  /// (this file's header, "Peer subscription lifecycle", already disclosed
  /// the narrower "already connected before `start()`" version of this gap;
  /// this is the same root cause reached a second way).
  ///
  /// Seeds a `connectionState` subscription for every already-known
  /// `trusted`/`allowed` device up front, independent of live discovery —
  /// so a connection reaching either device by ANY means (this device
  /// dialling out, or a peer dialling in) is never missed purely because
  /// discovery didn't happen to run first. Does NOT call `connect()` for
  /// any of them — no eager/proactive connection, matching `E04-B05`'s own
  /// established "lazy, on-demand" reasoning (`ADR-0004`); this only
  /// listens for a connection that might already be settling, or settle
  /// later, dialled by either side. `unknown`/`blocked` relationships are
  /// deliberately excluded — first contact with an `unknown` peer still
  /// goes through the existing discovery-triggered path unchanged, and a
  /// `blocked` peer gets no new way to reach this device (`E06-T14`'s own
  /// `GAP-030` fence states the identical reasoning for the Message
  /// button — see this task's own Open Questions for why this scope was
  /// chosen over subscribing every relationship state).
  Future<void> _seedKnownDevices() async {
    final relationships = await RelationshipRepository(_stack.db).listAll();
    // Review finding, E04-B07: `stop()` may run while the `await` above is
    // still in flight (this is fire-and-forget from `start()`) — without
    // this guard, the loop below would repopulate `_connectionSubscriptions`
    // with live subscriptions against an already-stopped pipeline, and a
    // frame arriving on one of them would hit the already-closed
    // `_deliveredController` with an uncaught `StateError`.
    if (!_started) return;
    for (final relationship in relationships) {
      if (relationship.state != RelationshipState.trusted &&
          relationship.state != RelationshipState.allowed) {
        continue;
      }
      _onDeviceDiscovered(
        TransportDevice(
          id: relationship.deviceId,
          displayName: relationship.deviceId,
          type: TransportType.bluetooth,
        ),
      );
    }
  }

  /// E04-B24: a conversation can end up permanently "orphaned" -- messages
  /// stored under a `conversation_id` that has NO `relationships` row of its
  /// own at all (not merely a stale one `_reconcileStaleRelationship` above
  /// already handles) -- when an ACCEPTED connection's remote address was
  /// mis-resolved at the moment those messages first arrived (the exact
  /// defect class `E04-B21`/`E04-B22` fixed for NEW accept events going
  /// forward; see those tasks for the full mechanism). Those code fixes
  /// cannot retroactively repair data that was already written under the
  /// wrong id before they existed -- confirmed live, 2026-09-14: a real
  /// conversation kept accumulating new incoming messages from a genuinely
  /// trusted peer under an id that turned out to be THIS DEVICE'S OWN
  /// Bluetooth address, permanently undialable for a reply (Android refuses
  /// a connection to a device's own address).
  ///
  /// This device has no reliable, permission-free way to ask "is this id
  /// literally my own address" (`BluetoothAdapter.getAddress()` returns an
  /// OS-hardened placeholder for an unprivileged app -- E04-B21's own round-1
  /// review finding). It does NOT need one: an orphaned conversation's
  /// received messages carry a `senderDeviceId` claim, and a `relationships`
  /// row's own `remoteSelfDeviceId` (learned via `IdentityAnnounceService`,
  /// E04-B12) may already record that same claimed identity for an existing,
  /// independently-trusted peer -- so a conversation with no relationship row
  /// of its own, whose received messages' `senderDeviceId` matches an
  /// existing `trusted`/`allowed` relationship's `remoteSelfDeviceId`, is
  /// migrated there.
  ///
  /// SECURITY NOTE (review round 1, F2/F3, 2026-09-14): `senderDeviceId` is
  /// NOT itself a verified cryptographic identity here -- it is
  /// `RelayPacketFrame.source`, an unauthenticated claim carried in the
  /// frame header (`_onDataReceived` -> `receiveMessage.call(frame.source,
  /// ...)` below), and `remoteSelfDeviceId` is likewise unauthenticated,
  /// peer-asserted, and freely rewritable by any device in range
  /// (`IdentityAnnounceService`, E04-B12's own documented precondition). This
  /// function therefore performs the exact reverse lookup (claimed identity
  /// -> relationship row) that E04-B12's review flagged as unsafe in
  /// general -- it is deliberately narrowed to be safe here by requiring the
  /// TARGET relationship to already be `trusted`/`allowed` (mirroring
  /// `_seedKnownDevices`'s own gate below): the worst a spoofed match can do
  /// is misfile an orphan's messages into an ALREADY-trusted conversation,
  /// never grant trust to, or enable dialing, an `unknown`/`blocked` device.
  /// A round-1 review probe confirmed the pre-fix version (matching against
  /// ANY relationship state) let an orphan's messages migrate into a
  /// `blocked` or `unknown` peer's conversation -- closed by the state
  /// filter below.
  ///
  /// Deliberately conservative, mirroring `_reconcileStaleRelationship`'s
  /// own posture: only migrates when EXACTLY ONE `trusted`/`allowed`,
  /// identity-announced relationship's `remoteSelfDeviceId` matches (an
  /// orphaned conversation whose received messages disagree on sender
  /// identity, or match zero or more than one such relationship, is left
  /// alone rather than guessed at -- this never invents a new trust
  /// decision, only ever corrects the KEY a message is filed under for a
  /// peer already independently trusted elsewhere). Never touches a
  /// conversation that already has its own relationship row (an ordinary,
  /// correctly-resolved conversation) -- ANY row, of ANY state, with ANY
  /// (including null) `remoteSelfDeviceId`, per the F5 fix below: whether a
  /// conversation counts as "orphaned" is a completely different question
  /// from whether a relationship is an eligible migration TARGET, and
  /// conflating the two sets (an earlier revision reused the same,
  /// state-filtered list for both) let a `blocked`/`unknown` relationship's
  /// OWN conversation, or a `trusted`/`allowed` one that has simply never
  /// announced an identity yet (the default state of every relationship
  /// until `IdentityAnnounceService` runs at least once), get wrongly
  /// treated as orphaned and merged into an unrelated trusted contact's
  /// thread by a spoofed `senderDeviceId` claim -- a review round-2 finding
  /// (F5), independently falsified by the reviewer and fixed same round.
  /// Also never touches a group conversation (`groups.id` is a distinct id
  /// space from a Bluetooth address/relationship `device_id` and is
  /// excluded explicitly below).
  ///
  /// KNOWN LIMITATION, disclosed (review F4): this pass runs once per
  /// `start()` call, not per-message -- a message written to an orphaned
  /// conversation_id AFTER this pass has already completed stays split
  /// until the next app launch/`start()` call. Self-heals on next launch;
  /// not fixed here (would require running this per-message, a materially
  /// different design left for a follow-up if it proves to matter live).
  Future<void> _reconcileOrphanedMessagesByIdentity() async {
    final db = _stack.db;
    // Every relationship row, regardless of state or `remoteSelfDeviceId` --
    // used ONLY to decide whether a conversation is "orphaned" (has NO
    // relationship row of its own). Review round-2 finding F5: narrowing
    // THIS set to trusted/allowed-with-an-identity (as an earlier revision
    // did, reusing the migration-TARGET candidate list for both purposes)
    // made a conversation with a `blocked`/`unknown` relationship, or a
    // `trusted`/`allowed` one that has simply never announced an identity
    // yet (the default state of every relationship until `IdentityAnnounceService`
    // runs at least once, per `relationships_table.dart`), look "orphaned"
    // even though it already has its own row -- letting an attacker's
    // `senderDeviceId` claim (unauthenticated, see the Security note above)
    // redirect that conversation's messages into a DIFFERENT, unrelated
    // trusted contact's thread. The orphan test and the migration-target
    // test are two different questions and must use two different sets.
    final allRelationships = await db.select(db.relationships).get();
    if (!_started) return;

    // The migration TARGET candidates: only a relationship this device
    // already independently trusts, that has actually announced an
    // identity -- see this function's own doc comment above for why this
    // narrowing (not the orphan test above) is where the state filter
    // belongs.
    final targetRelationships = allRelationships
        .where(
          (r) =>
              r.remoteSelfDeviceId != null &&
              (r.state == 'trusted' || r.state == 'allowed'),
        )
        .toList();
    if (targetRelationships.isEmpty) return;

    final knownConversationIds = <String>{
      for (final r in allRelationships) r.deviceId,
    };
    final groupIds = (await db.select(db.groups).get())
        .map((g) => g.id)
        .toSet();
    if (!_started) return;

    final distinctConversationRows = await db
        .customSelect(
          'SELECT DISTINCT conversation_id FROM messages',
        )
        .get();
    if (!_started) return;

    for (final row in distinctConversationRows) {
      final conversationId = row.read<String>('conversation_id');
      if (knownConversationIds.contains(conversationId)) continue;
      if (groupIds.contains(conversationId)) continue;

      final receivedSenderIds = await (db.select(db.messages)
            ..where(
              (t) =>
                  t.conversationId.equals(conversationId) &
                  t.senderDeviceId.equals(_stack.selfDeviceId).not(),
            ))
          .map((m) => m.senderDeviceId)
          .get();
      if (!_started) return;
      final distinctSenderIds = receivedSenderIds.toSet();
      if (distinctSenderIds.length != 1) continue; // none, or ambiguous.

      final senderId = distinctSenderIds.single;
      final matches = targetRelationships
          .where((r) => r.remoteSelfDeviceId == senderId)
          .toList();
      if (matches.length != 1) continue; // no known peer, or ambiguous.

      final correctConversationId = matches.single.deviceId;
      await (db.update(db.messages)
            ..where((t) => t.conversationId.equals(conversationId)))
          .write(MessagesCompanion(conversationId: Value(correctConversationId)));
      if (!_started) return;
    }
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
    await _peerConnectedController.close();
  }

  void _onDeviceDiscovered(TransportDevice device) {
    // Already tracking this id's connection state -- nothing to do. Real
    // Bluetooth discovery re-announces the same device across scan cycles
    // (mirrors devices_controller.dart's own dedup reasoning).
    if (_connectionSubscriptions.containsKey(device.id)) return;
    // E04-B17: the subscription below MUST be created synchronously, in
    // this same call, before any `await` -- a native `connected`/data event
    // for [device.id] can arrive on Dart's very next event-loop turn (this
    // was observed live: making this method `async` and awaiting
    // reconciliation BEFORE subscribing reintroduced the exact same
    // "event broadcast to a deviceId nothing is listening for yet" race
    // this whole task exists to close, just one layer up). Reconciliation
    // itself has natural slack: it only needs to finish before
    // `PrekeyExchange`'s own trust check runs, which is a full network
    // round trip later, so firing it here as fire-and-forget is safe --
    // see `_reconcileStaleRelationship`'s own doc comment.
    _connectionSubscriptions[device.id] = _stack.transport
        .connectionState(device.id)
        .listen((ConnectionState state) => _onConnectionStateChanged(device.id, state));
    // E04-B17 (review round 1, F1): gated on `device.bonded` -- this method
    // is the handler for EVERY discovered device, including an ordinary
    // passing stranger's headphones from a routine scan, not only an
    // accepted connection. Reconciliation must never run for a device this
    // side has no OS-level authentication for at all (see
    // `_reconcileStaleRelationship`'s own doc comment for the full
    // reasoning) -- `bonded` is real Bluetooth OS pairing, the one signal
    // in this event that a Bluetooth-visible NAME alone (attacker-settable)
    // is not.
    if (device.bonded) {
      unawaited(_reconcileStaleRelationship(device.id, device.displayName));
    }
  }

  /// E04-B17: [deviceId] might be a peer this side already trusts under a
  /// DIFFERENT, now-stale address -- confirmed live: an OS/OEM Bluetooth
  /// stack can present a different real, currently-bonded address than
  /// whatever address a relationship was originally keyed under (e.g. from
  /// an earlier discovery scan, before the peer was OS-bonded — the same
  /// address-instability class `E04-B08`'s own `resolveDeviceId` already
  /// found and fixed for the discovery path, but with no mechanism to ever
  /// correct an ALREADY-stored relationship once its address goes stale).
  /// Without this, a message to/from an already-trusted peer that
  /// reconnects under a new address fails forever -- no relationship row
  /// exists for the new address, so it is either never subscribed to at
  /// all (the accept-path gap this task's own root-causing found) or
  /// treated as a brand-new `unknown` contact requiring manual
  /// re-verification.
  ///
  /// **Gated on `bonded` at the ONE call site (E04-B17 review round 1,
  /// F1/F2)** -- this method itself trusts that its caller only ever
  /// invokes it for a device this side has REAL OS-level Bluetooth pairing
  /// with (`TransportDevice.bonded`, populated by the native layer from
  /// `BluetoothAdapter.bondedDevices`, never by anything a peer's own
  /// broadcast claims). Never call this for an unbonded device: a
  /// Bluetooth-visible NAME is attacker-settable and carries zero
  /// authentication on its own -- confirmed live by an adversarial review
  /// probe that had an unbonded "stranger" device inherit a `trusted` row
  /// via a routine discovery scan before this gate existed. A real bond
  /// requires the OS's own pairing exchange (a user-visible confirmation
  /// on both ends), which is what makes the name match below a reasonable
  /// "probably the same peer, reconnecting" signal rather than a spoofable
  /// one -- it is still not a cryptographic identity check (that is
  /// `remote_self_device_id`'s job, once the identity-announce protocol
  /// completes), so this only ever copies an ALREADY-evaluated decision
  /// forward, never invents a new one, and remains a narrower, secondary
  /// signal.
  ///
  /// Deliberately narrow beyond the `bonded` gate too: only reconciles
  /// when [deviceId] has no relationship row of its own yet AND exactly
  /// ONE other stored relationship's `peerName` matches -- an ambiguous
  /// match (two different bonded, stored peers happen to share a
  /// Bluetooth-visible name) is left alone rather than guessed at, so
  /// [deviceId] is treated as a genuinely new, `unknown` contact through
  /// the normal discovery/trust flow instead (a false negative here costs
  /// a re-verification; a false positive would silently hand a new
  /// address someone else's trust decision). Deliberately does NOT fall
  /// back to matching on an absent (`NULL`) `peerName` for a
  /// pre-this-column relationship -- review round 1 found that fallback
  /// never actually healed (it only ever populated the NEW row, leaving
  /// the stale row permanently `NULL` and the fallback permanently armed)
  /// and could pick the wrong one among several such rows. A relationship
  /// that predates this column simply needs one ordinary re-verification
  /// the first time its peer reconnects under a different address --
  /// accepted here as the safer trade-off.
  Future<void> _reconcileStaleRelationship(
    String deviceId,
    String peerName,
  ) async {
    if (peerName.isEmpty) return; // review round 2 (N1): an empty name is
    // still a valid SQL correlator (unlike NULL) and matches nothing real.
    final db = _stack.db;
    final existing = await (db.select(db.relationships)
          ..where((t) => t.deviceId.equals(deviceId)))
        .getSingleOrNull();
    if (existing != null) return; // already has its own row -- nothing to do.

    final candidates = await (db.select(db.relationships)
          ..where(
            (t) =>
                t.peerName.equals(peerName) & t.deviceId.equals(deviceId).not(),
          ))
        .get();
    if (candidates.length != 1) return; // none, or ambiguous -- leave as new.

    final stale = candidates.single;
    await db.into(db.relationships).insertOnConflictUpdate(
          RelationshipsCompanion.insert(
            deviceId: deviceId,
            state: stale.state,
            updatedAt: DateTime.now(),
            peerName: Value(peerName),
          ),
        );
  }

  void _onConnectionStateChanged(String deviceId, ConnectionState state) {
    if (state == ConnectionState.connected) {
      // Idempotent: a repeated `connected` event for an id already
      // subscribed must not open a second incomingData listener (the same
      // double-delivery hazard `start()`'s own idempotency guards against),
      // and must not re-emit `peerConnected` for a connection that never
      // actually dropped. `putIfAbsent`'s callback only runs the first time
      // a given id transitions to connected since its last disconnect
      // (`_dataSubscriptions.remove` below removes the key on
      // disconnect/failure), so a genuine reconnect DOES re-emit — correct,
      // since E04-B12's identity-announce should fire again on every fresh
      // connection.
      if (!_dataSubscriptions.containsKey(deviceId)) {
        // E04-B12: emitted at the same moment the incoming-data
        // subscription opens, before this method returns — the seam
        // `messaging_stack.dart` fires an identity-announce off (see
        // [peerConnected]'s own doc comment).
        if (!_peerConnectedController.isClosed) {
          _peerConnectedController.add(deviceId);
        }
      }
      _dataSubscriptions.putIfAbsent(
        deviceId,
        () => _stack.transport
            .incomingData(deviceId)
            .listen((Uint8List bytes) => _handleBuffer(deviceId, bytes)),
      );
    } else {
      // connecting / disconnected / failed -- no active link, no reason to
      // keep an incomingData subscription open for it (§6 risk: a
      // subscription per peer that is never cancelled leaks).
      unawaited(_dataSubscriptions.remove(deviceId)?.cancel());
    }
  }

  Future<void> _handleBuffer(String linkDeviceId, Uint8List bytes) async {
    final RelayPacketFrame frame;
    try {
      frame = RelayPacketFrame.deserialize(bytes);
    } on FormatException {
      counters.malformed++;
      return;
    }

    final int nowMs = _clock().millisecondsSinceEpoch;

    // FR-ROUTE-004: a past-TTL packet is dropped, not forwarded, regardless
    // of destination -- it is not worth relaying or decrypting either way.
    // Checked before the E04-B12 bypass below too: an expired announce is
    // no more worth processing than an expired anything else.
    if (frame.expiresAtMs <= nowMs) {
      counters.expired++;
      return;
    }

    // **E04-B12: the identity-announce bypass — narrowly scoped to exactly
    // one `controlKind`, checked BEFORE `isForUs` is even computed and
    // BEFORE the `!isForUs` relay/forward branch below, so that branch can
    // never see one of these frames (task file §3 point 4: "must never be
    // relayed"). See `identity_announce.dart`'s header for the full
    // justification of why bypassing `isForUs` is safe for this one
    // controlKind and not a general precedent: a Bluetooth Classic RFCOMM
    // connection is point-to-point and already OS-authenticated via
    // bonding, so ANY frame arriving on `linkDeviceId`'s own incoming-data
    // stream is structurally known to have come from that bonded address,
    // independent of what `frame.destination`/`frame.source` claim. This
    // check reads only `frame.payloadType`/`frame.payload[0]` — never
    // `frame.destination` — so it can only ever match a frame whose FIRST
    // control byte is literally `kControlKindIdentityAnnounce`; every other
    // control frame (including one with a wrong/absent destination) falls
    // through unchanged to the normal `isForUs`/relay logic below.**
    if (frame.payloadType == PayloadType.control &&
        frame.payload.isNotEmpty &&
        frame.payload[0] == kControlKindIdentityAnnounce) {
      final IdentityAnnounceHandler? handler = _identityAnnounceHandler;
      if (handler == null) {
        counters.unhandledControl++;
        return;
      }
      final RelayPacketFrame innerFrame = RelayPacketFrame(
        payloadType: frame.payloadType,
        packetId: frame.packetId,
        destination: frame.destination,
        source: frame.source,
        priority: frame.priority,
        createdAtMs: frame.createdAtMs,
        expiresAtMs: frame.expiresAtMs,
        payload: frame.payload.sublist(1),
      );
      try {
        await handler(linkDeviceId, innerFrame);
      } catch (_) {
        // Same "a bad packet/handler failure never kills the loop" policy
        // as every other control handler below.
      }
      return;
    }

    // FR-ROUTE-003 (task file §6): the destination decision is made HERE,
    // before `frame.payload` is read anywhere else in this method. Every
    // other read of `frame.payload` below is textually inside the
    // `isForUs` branch, after the `!isForUs` branch has already returned.
    final bool isForUs = frame.destination == _stack.selfDeviceId;

    if (!isForUs) {
      // Forward branch (FR-ROUTE-002/FR-ROUTE-003). `bytes` -- the ORIGINAL
      // wire bytes this device received off the transport, not
      // `frame.payload` and not a re-serialized frame -- is the only thing
      // handed onward, so a relay forwards exactly what it did not read.
      // Nothing past this point in this branch touches `frame.payload`,
      // calls `CiphertextCodec.decode`, calls `decrypt`, or constructs a
      // `Message`.
      // E13-T03 (`Q-E13-T03-1`'s resolution): admission-gate BEFORE
      // `enqueue`, keyed by the claimed sender (`frame.source`) — a denied
      // packet is dropped here, never queued, never counted as forwarded.
      final bool relayAllowed = await _rateLimiter.allow(
        'relay:${frame.source}',
        maxCount: _relayRateLimitMaxCount,
        window: _relayRateLimitWindow,
      );
      if (!relayAllowed) {
        counters.rateLimited++;
        return;
      }

      // E13-T05: a SECOND, independent admission gate at this same call
      // site — byte-volume, not count — keyed the same way (`frame.source`)
      // for consistency with the count gate directly above. `bytes.length`
      // is the size of the ORIGINAL wire buffer this device received (the
      // same value that ends up written to `relay_packets.size_bytes` a few
      // lines below via `RelayEngine.enqueue`), never `frame.payload.length`
      // — the whole packet is what would be persisted, not just its opaque
      // payload. Either gate denying is enough to reject the forward
      // (task file §3); this check never substitutes for the count check
      // above, and is never itself substituted for by it.
      // Fail-open fix (post-merge cross-model review, CHANGES verdict):
      // RateLimiter.allow inserts a fresh/rolled-over bucket with
      // count: increment and returns true unconditionally on that branch --
      // it never compares increment itself against maxCount. So a single
      // packet larger than the entire per-minute budget was admitted on
      // the first hit of every rolling window. This explicit pre-check
      // catches an oversized single packet regardless of the rate
      // limiter's current bucket state, independent of allow's rollover
      // behaviour.
      if (bytes.length > _storageVolumeRateLimitMaxBytes) {
        counters.rateLimited++;
        return;
      }
      final bool volumeAllowed = await _rateLimiter.allow(
        'storage_volume:${frame.source}',
        maxCount: _storageVolumeRateLimitMaxBytes,
        window: _storageVolumeRateLimitWindow,
        increment: bytes.length,
      );
      if (!volumeAllowed) {
        counters.rateLimited++;
        return;
      }

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
      // `OQ-E06-T08-2` retrofit: the leading byte of a control payload is
      // now which sub-protocol owns the rest of it -- read and STRIP it
      // here, once, so every registered handler keeps seeing exactly its
      // own body (this file's `ControlHandler` typedef doc).
      if (frame.payload.isEmpty) {
        counters.unhandledControl++;
        return;
      }
      final int controlKind = frame.payload[0];
      final RelayPacketFrame innerFrame = RelayPacketFrame(
        payloadType: frame.payloadType,
        packetId: frame.packetId,
        destination: frame.destination,
        source: frame.source,
        priority: frame.priority,
        createdAtMs: frame.createdAtMs,
        expiresAtMs: frame.expiresAtMs,
        payload: frame.payload.sublist(1),
      );

      // E04-B14: `kControlKindPrekeyExchange` gets its OWN dedicated,
      // link-bound dispatch — checked BEFORE the generic [_controlHandlers]
      // map below, so a still-registered legacy generic handler for this
      // same controlKind (`messaging_stack.dart`'s own pre-existing
      // `registerControlHandler` call, out of this task's fence, left
      // unmodified) can never fire: this branch always intercepts it first.
      if (controlKind == kControlKindPrekeyExchange) {
        final PrekeyExchangeHandler? prekeyHandler = _prekeyExchangeHandler;
        if (prekeyHandler == null) {
          counters.unhandledControl++;
          return;
        }
        try {
          await prekeyHandler(linkDeviceId, innerFrame);
        } catch (_) {
          // Same "a bad packet/handler failure never kills the loop" policy
          // as every other control handler in this method.
        }
        return;
      }

      final ControlHandler? handler = _controlHandlers[controlKind];
      if (handler == null) {
        // Dropped and counted, never guessed at (task file §3).
        counters.unhandledControl++;
        return;
      }
      try {
        await handler(innerFrame);
      } catch (_) {
        // A registered control handler's own failure (T07/T08) must not
        // take this pipeline down either -- same "a bad packet never kills
        // the loop" policy as the ciphertext branch below.
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
        if (!_deliveredController.isClosed) _deliveredController.add(message);
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
      // E04-B27: a re-delivered PreKeySignalMessage fails one step earlier,
      // at the already-consumed one-time prekey, but it is the same
      // duplicate-packet outcome and is counted as one.
      if (failure.reason == CryptoDecryptFailureReason.duplicateMessage ||
          failure.reason ==
              CryptoDecryptFailureReason.consumedOneTimePreKey) {
        counters.duplicate++;
      } else {
        counters.undecryptable++;
      }
    }
  }

  // --- E07-T06: group text messages --------------------------------------

  /// The `ControlHandler` registered on [kControlKindGroupMessage] (this
  /// file's own constructor). [frame.payload] has already had its leading
  /// `controlKind` byte read and stripped by [_handleBuffer]'s generic
  /// control dispatch -- exactly [GroupMessageRoutingHeader.serialize]'s
  /// output.
  ///
  /// This is where the CLEAR `(groupId, epoch)` routing header is parsed and
  /// the actual decrypt happens -- see this file's header for why the
  /// epoch-recognition check runs BEFORE decrypt (identity-free, cheap) and
  /// the AUTHORITATIVE membership check runs AFTER it, inside
  /// [handleGroupMessage].
  Future<void> _handleGroupMessageWireFrame(RelayPacketFrame frame) async {
    final GroupMessageRoutingHeader header;
    try {
      header = GroupMessageRoutingHeader.deserialize(frame.payload);
    } on AppFailure {
      counters.malformed++;
      return;
    }

    final groups = GroupRepository(_stack.db);
    final group = await groups.groupRow(header.groupId);
    if (group == null || header.epoch > group.membershipEpoch) {
      // Unknown group, or an epoch this device has never reached yet --
      // nothing to authenticate here at all, so no decrypt is attempted
      // (task file §6: distinct from `groupNoChain`, which means the
      // group/epoch IS recognized but the specific sender's chain isn't
      // held).
      counters.groupEpochUnknown++;
      return;
    }

    final Uint8List plaintext;
    try {
      plaintext = await _stack.groupCryptoService.decryptFromGroup(
        groupId: header.groupId,
        epoch: header.epoch,
        // Candidate only -- selects which sender's chain to attempt.
        // Authenticated by decrypt succeeding under that specific chain,
        // never trusted as the stored/checked identity on its own
        // (E06-B04; this file's header).
        senderDeviceId: frame.source,
        bytes: header.ciphertext,
      );
    } on AppFailure catch (e) {
      if (e.code == 'group.no_chain') {
        counters.groupNoChain++;
      } else {
        counters.undecryptable++;
      }
      return;
    } catch (e) {
      // `GroupCipher.decrypt` (E07-T04) discards a message key once used,
      // exactly like the pairwise Double Ratchet -- the SAME wire ciphertext
      // genuinely arriving twice (task file §6: multi-hop relaying can
      // deliver one message down two paths) fails decrypt a second time
      // with the library's `DuplicateMessageException`, not a
      // `group.no_chain` `AppFailure` (`GroupCryptoService.decryptFromGroup`
      // does not, and per this task's `files:` fence must not, map this
      // case itself). Matched by `runtimeType` name, mirroring
      // `crypto_failures.dart`'s own `mapSignalException` discipline for the
      // identical reason (the type is not exported from
      // `libsignal_protocol_dart`'s public barrel) -- counted the same way
      // FR-MSG-003's own 1:1 dedup signal already is, never as
      // `undecryptable` (EARS-COMM-32).
      if (e.runtimeType.toString() == 'DuplicateMessageException') {
        counters.duplicate++;
      } else {
        counters.undecryptable++;
      }
      return;
    }

    final GroupMessageEnvelope envelope;
    try {
      envelope = GroupMessageEnvelope.deserialize(plaintext);
    } on AppFailure {
      counters.malformed++;
      return;
    }

    await handleGroupMessage(frame.source, envelope, header.ciphertext);
  }

  /// The receive half's business logic (task file §5's contract): membership
  /// check (against the AUTHORITATIVE [envelope.senderDeviceId], never
  /// [frameSourceDeviceId] -- see this file's header) -> dedupe by
  /// `envelope.messageId` (never `(sender, sequenceNumber)`, task file §6:
  /// a group message can legitimately arrive more than once over different
  /// relay routes) -> persist -> emit on the existing [delivered] stream
  /// unchanged, so `DeliveryAckService` and the read model need no changes.
  ///
  /// [frameSourceDeviceId] is accepted for exactly the shape this task's own
  /// §5 contract documents -- transport metadata only, never consulted for
  /// the membership check or for any persisted field.
  Future<void> handleGroupMessage(
    String frameSourceDeviceId,
    GroupMessageEnvelope envelope,
    Uint8List senderKeyMessageBytes,
  ) async {
    final groups = GroupRepository(_stack.db);
    final role = await groups.roleOf(envelope.groupId, envelope.senderDeviceId);
    if (role == null) {
      // Not a current member of this group, regardless of what the
      // envelope claims (task file §2/§5) -- dropped, never stored.
      counters.groupNotAMember++;
      return;
    }

    final db = _stack.db;
    final Message? message = await db.transaction(() async {
      final existing = await (db.select(db.messages)
            ..where((t) => t.id.equals(envelope.messageId)))
          .getSingleOrNull();
      if (existing != null) {
        // Duplicate delivery (task file §6/EARS-COMM-32): no second row.
        return null;
      }

      final createdAt = _clock().millisecondsSinceEpoch;
      await db.into(db.messages).insert(
            MessagesCompanion.insert(
              id: envelope.messageId,
              conversationId: envelope.groupId,
              senderDeviceId: envelope.senderDeviceId,
              sequenceNumber: envelope.sequenceNumber,
              ciphertext: senderKeyMessageBytes,
              createdAt: createdAt,
              // Received and decrypted successfully -- the group-message
              // equivalent of `ReceiveMessageUseCase`'s own `Accepted`
              // (task file §2: same `delivery_state` machine, no
              // per-recipient state for groups).
              deliveryState: DeliveryState.accepted.name,
            ),
          );

      return Message(
        id: envelope.messageId,
        conversationId: envelope.groupId,
        senderDeviceId: envelope.senderDeviceId,
        sequenceNumber: envelope.sequenceNumber,
        ciphertext: senderKeyMessageBytes,
        createdAt: createdAt,
        deliveryState: DeliveryState.accepted,
      );
    });

    if (message == null) {
      counters.duplicate++;
    } else {
      counters.delivered++;
      if (!_deliveredController.isClosed) _deliveredController.add(message);
    }
  }
}
