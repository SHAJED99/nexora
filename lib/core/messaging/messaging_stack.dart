// core/messaging — the messaging composition root (E06-T03).
//
// `SendMessageUseCase` (E05-T02), `ReceiveMessageUseCase` (E05-T03),
// `SyncCursorService` (E05-T04), `RelayEngine` (E04-T04) and `RoutingEngine`
// (E04-T02) have had zero construction sites anywhere in `lib/` since the
// epic that built each of them landed — every one of them has only ever been
// instantiated by its own tests. This file is where that stops: exactly one
// `MessagingStack` per process, built by [MessagingStack.create], holding
// exactly one instance of each.
//
// **Single instance is a correctness requirement, not tidiness** (task file
// §2): `SendMessageUseCase._generateId` is unique only *within one instance*
// (send_message_use_case.dart:212), and the sequence-number reservation
// transaction's exclusivity guarantee rests on drift's per-connection lock,
// which does not hold across two `AppDatabase` connections. Two
// `SendMessageUseCase`s sharing one `AppDatabase` — or one `SendMessageUseCase`
// built against two different `AppDatabase`s — both reopen exactly the defect
// E05-T02's review reproduced (`SqliteException(1555): UNIQUE constraint
// failed`). This file exists so that never happens: [MessagingStack.create]
// is called exactly once per process (`lib/app/main.dart`), and every screen
// reaches the same instances back out through GetX (`lib/app/bindings.dart`),
// never by constructing its own.
//
// **The three adapters below are the actual work of this task.** Each is a
// small, named, top-level (or static) function — not a lambda buried inside
// a constructor call — so a reader can find and reason about the seam
// between epics without stepping into `MessagingStack.create`'s body:
//
// - [_encryptAdapter] is [MessageEncryptFn]: `CryptoService.instance.encrypt`
//   (E03-T03) -> `CiphertextCodec.encode` (E06-T02) -> `RelayPacketFrame(...)
//   .serialize()` (E06-T02). This is the producer half of the wire format
//   whose absence was E05-B01/OQ-E05-B01-1 — until this task, nothing in
//   `lib/` ever turned a `CiphertextMessage` into bytes a relay could read a
//   header from.
// - The `enqueue` seam is `relayEngine.enqueue` passed straight through with
//   NO adapter — E05-T02's own review already verified its positional order,
//   arity and return type match `MessageEnqueueFn` exactly
//   (`relay_engine.dart:106-111` vs `send_message_use_case.dart:69-74`), and
//   re-verified again here before wiring it: still an exact match, no drift
//   found on this seam.
// - The `send` seam is `transport.send` passed straight through as
//   `RelaySendFn` with NO adapter — `TransportService.send(String, Uint8List)
//   -> Future<bool>` (`transport_service.dart:120`) already matches
//   `RelaySendFn` exactly.
//
// **Does NOT modify `SendMessageUseCase`, `ReceiveMessageUseCase`,
// `RelayEngine`, `RoutingEngine`, `SyncCursorService` or `CryptoService`**
// (task file §4) — every one of those five is used exactly as its own epic
// left it. **Does NOT start anything**: no `Timer`, no stream subscription,
// no `processQueue()` call, no `transport.incomingData` listener. Everything
// here is construction only — starting the inbound pipeline is T05's job and
// the queue driver is T06's (including T06's own 🧍 trigger-model decision).
//
// **E06-T06 update: `coordinator` is now constructed and exposed here too**,
// same rule as every other member — one instance per process, built once by
// [MessagingStack.create]. `create()` still does NOT call
// `coordinator.start()` itself: that would silently start the mesh's
// heartbeat from inside a pure composition root, which is exactly the
// "does NOT start anything" contract this file has always kept. `main.dart`
// and `bindings.dart` are outside E06-T06's own `files:` fence (its task
// file lists only this file and `sync_cursor_service.dart` for the `update:`
// set), so the actual `coordinator.start()` call site at the app's real
// lifecycle entry point is deliberately NOT wired here — logged as a
// Deviation in that task's own self-review, not silently done or silently
// skipped. `coordinator` is fully constructed and ready for whichever
// component calls `start()` (most likely T11's chat screen, given E06-T06
// blocks both T07 and T11).
// **Does NOT call `establishSession`** — sending stays honestly broken with
// `AppFailure('messaging.no_session')` until T07 lands; see
// `test_no_session_send_fails_honestly` in this task's test file.
//
// --- Judgment calls recorded here rather than left implicit ---
//
// 1. **`_localSignalDeviceId`.** The task file instructs "use the same
//    constant [as `receive_message_use_case.dart:61`'s `_localSignalDeviceId`],
//    do not re-declare it" — but that constant is `library`-private
//    (leading underscore), so Dart's own privacy model makes literal reuse
//    across files impossible; every existing private `_localSignalDeviceId`/
//    `_localDeviceId`/`_generateId` in this codebase is independently
//    declared per file for the same reason (`identity_service.dart:30`,
//    `relay_engine.dart:100`, `send_message_use_case.dart:165`). Re-declared
//    here, value `1`, with this cross-reference, rather than left unexplained
//    — logged as a Deviation, not an Open Question: it is a Dart-language
//    constraint, not a mismatch between what two epics built.
// 2. **The wire frame's `packetId`.** `relay_packet_frame.dart`'s header
//    comment calls this field "RelayEngine's packet id", but
//    [_encryptAdapter] runs and must return a fully-serialized frame BEFORE
//    `SendMessageUseCase` ever calls `relayEngine.enqueue` (which is what
//    mints `RelayEngine`'s own local `relay_packets.id` — see
//    `relay_engine.dart:113`) — so that id provably does not exist yet at the
//    point this adapter needs to write it. Re-reading FR-ROUTE-004 and
//    `relay_engine.dart`'s own header resolves this rather than blocking on
//    it: each hop's `relay_packets.id` is that hop's own local queue-row key
//    (`RelayEngine._generateId`, timestamp+counter, never shared across
//    hops), not a wire-level end-to-end packet identity — nothing in this
//    codebase threads one hop's local id to the next hop's local id. The wire
//    frame's `packetId` is therefore necessarily a *different*, originator-
//    minted identifier. This adapter uses the message's own envelope `id`
//    (`MessageEnvelope.deserialize(envelopeBytes).id` — already unique per
//    `SendMessageUseCase._generateId`, and already available to this adapter
//    as the plaintext it is about to encrypt) rather than inventing a second
//    id-generation scheme. Logged as a Deviation (judgment call within the
//    documented adapter shape), not an Open Question — it changes no
//    signature and blocks nothing.
// 3. **`selfDeviceId` may not exist yet at cold boot.** E01-T01's device
//    identity (`device_identities.device_id`, a random token) is generated
//    and persisted only inside `LoginController._signIn` — NOT at any point
//    before a user's first sign-in (`login_controller.dart:41-58`,
//    `home_controller.dart`). A fresh install therefore has no `selfDeviceId`
//    at all the first time `lib/app/main.dart` runs, before `runApp`. Rather
//    than block this task on that (it is a real, but narrow and forward-
//    looking, gap between E01's identity lifecycle and E06's composition-root
//    timing — see this task's Open Questions for the non-blocking note),
//    [MessagingStack.create] treats an empty `selfDeviceId` as one more
//    reason to report `unavailable` — same shape as a crypto-init failure,
//    not a special case a caller has to know about — so `main.dart` always
//    calls `create()` exactly once, unconditionally, and `create()` always
//    returns a fully-constructed, non-null object either way (task file §5's
//    own contract: "a stack with status unavailable and every member still
//    non-null-safe to reference").
import 'dart:async';
import 'dart:typed_data';

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import '../abuse/rate_limiter.dart';
import '../calls/call_signaling.dart';
import '../crypto/crypto_stub.dart';
import '../crypto/drift_signal_store.dart';
import '../crypto/group_crypto_service.dart';
import '../crypto/identity_service.dart';
import '../persistence/database.dart';
import '../routing_engine/relay_engine.dart';
import '../routing_engine/routing_engine.dart';
import '../transport/connection_ensuring_sender.dart';
import '../transport/transport_service.dart';
import '../../features/groups/data/group_repository.dart';
import '../../features/groups/domain/group_membership_service.dart';
import '../../features/groups/domain/send_group_message_use_case.dart';
import '../../features/location/data/location_fix_repository.dart';
import '../../features/location/data/location_settings_repository.dart';
import '../../features/location/data/platform_location_source.dart';
import '../../features/location/domain/location_share_service.dart';
import '../../features/trust/data/relationship_repository.dart';
import '../../features/trust/domain/evaluate_connection_request_use_case.dart';
import 'ciphertext_codec.dart';
import 'delivery_ack.dart';
import 'group_control.dart';
import 'identity_announce.dart';
import 'inbound_pipeline.dart';
import 'location_share.dart';
import 'messaging_coordinator.dart';
import 'prekey_exchange.dart';
import 'relay_packet_frame.dart';

// `MessageEnvelope` is re-exported by `receive_message_use_case.dart`
// (that file's own header explains why) -- importing it separately here
// would be redundant, so this adapter reaches it through that import.
import '../../features/messaging/domain/receive_message_use_case.dart';
import '../../features/messaging/domain/send_message_use_case.dart';
import '../../features/messaging/domain/sync_cursor_service.dart';

/// Signal device-id half of every `SignalProtocolAddress` this app mints.
/// Matches `receive_message_use_case.dart:61`'s private
/// `_localSignalDeviceId` — see this file's header, judgment call 1, for why
/// it is re-declared here rather than imported.
const int _localSignalDeviceId = 1;

/// Mirrors `SendMessageUseCase`'s own defaults (`send_message_use_case.dart`
/// constructor: `priority = 0`, `ttl = const Duration(days: 3)`) — the wire
/// frame [_encryptAdapter] builds and the `relay_packets` row
/// `relayEngine.enqueue` later inserts for the SAME send must describe the
/// same priority/expiry, and `SendMessageUseCase`'s own defaults are private
/// fields, not reusable constants, so this duplication is deliberate and
/// documented rather than accidental. [MessagingStack.create] never
/// overrides `SendMessageUseCase`'s own default for either, so the two never
/// drift apart silently.
const int _defaultPriority = 0;
const Duration _defaultTtl = Duration(days: 3);

/// `OQ-E06-T06-1`'s resolved answer (option (c)): the `Timer.periodic` floor
/// that guarantees `sweepExpired()`/`reclaimPayloads()` still run on a
/// schedule even with zero mesh traffic. [MessagingStack.create]'s own
/// `coordinatorTickInterval` parameter defaults to this constant but is
/// still an injected value, never a literal baked into
/// `MessagingCoordinator` itself (task file §5's contract: "injected, never
/// hard-coded at a call site") — a test or a future caller can override it.
const Duration _defaultCoordinatorTickInterval = Duration(seconds: 60);

/// `ready`, or `unavailable` with a human-readable (never secret, never
/// device-id- or key-bearing) reason — task file §3/§5. A screen reads this
/// instead of a `MessagingStack` construction throwing, so a degraded device
/// (no crypto identity yet, no local device identity yet) still renders an
/// honest UI state rather than crashing at startup.
sealed class MessagingStackStatus {
  const MessagingStackStatus();

  const factory MessagingStackStatus.ready() = MessagingStackStatusReady;
  const factory MessagingStackStatus.unavailable(String reason) =
      MessagingStackStatusUnavailable;

  bool get isReady => this is MessagingStackStatusReady;
}

final class MessagingStackStatusReady extends MessagingStackStatus {
  const MessagingStackStatusReady();

  @override
  bool operator ==(Object other) => other is MessagingStackStatusReady;

  @override
  int get hashCode => (MessagingStackStatusReady).hashCode;

  @override
  String toString() => 'MessagingStackStatus.ready()';
}

final class MessagingStackStatusUnavailable extends MessagingStackStatus {
  const MessagingStackStatusUnavailable(this.reason);

  /// Greppable, non-secret description of why construction did not reach
  /// `ready` (`docs/conventions.md` "Error handling"/"Logging") — never
  /// plaintext, key material or a device id.
  final String reason;

  @override
  bool operator ==(Object other) =>
      other is MessagingStackStatusUnavailable && other.reason == reason;

  @override
  int get hashCode => Object.hash(MessagingStackStatusUnavailable, reason);

  @override
  String toString() => 'MessagingStackStatus.unavailable($reason)';
}

/// The messaging composition root (task file §1/§3). Exactly one call to
/// [MessagingStack.create] per process — see this file's header for why.
class MessagingStack {
  MessagingStack._({
    required this.db,
    required this.signalStore,
    required this.identityService,
    required this.cryptoService,
    required this.transport,
    required this.directSend,
    required this.routingEngine,
    required this.relayEngine,
    required this.sendMessage,
    required this.receiveMessage,
    required this.syncCursors,
    required this.selfDeviceId,
    required this.status,
    required Duration coordinatorTickInterval,
  }) {
    // E06-T06: `inbound`/`coordinator` need a fully-constructed `this` (both
    // are bound to this exact stack instance), so they are built in the
    // constructor body -- after every other `final` field above is already
    // set by the initializer list -- rather than passed in like the rest.
    // Neither is started here: `create()`'s own contract is "does NOT start
    // anything" (this file's header), unchanged by this task.
    inbound = InboundPipeline(stack: this);
    coordinator = MessagingCoordinator(
      stack: this,
      inbound: inbound,
      tickInterval: coordinatorTickInterval,
    );

    // E06-T07: same "needs a fully-constructed `this`" reasoning --
    // `PrekeyExchange` is bound to this exact stack. Registered onto
    // `inbound`'s single control-handler slot (E06-T05's declared
    // extension point) here, in construction, rather than left for a
    // caller to remember -- `create()` is still the ONLY place this ever
    // happens (task file §3: "registered as a control handler in
    // messaging_stack.dart").
    // E13-T07 (FR-ABUSE-001, EARS-ABUSE-4): the real, only production
    // construction site of `EvaluateConnectionRequestUseCase` now gets a
    // real `RateLimiter` -- before this task, `_rateLimiter` here always
    // defaulted to `null` and the connection-request admission gate that
    // `RelationshipState.blocked` short-circuit relies on could never
    // actually deny anything in the running app (task §2 item 1).
    prekeyExchange = PrekeyExchange(
      stack: this,
      evaluateConnectionRequest: EvaluateConnectionRequestUseCase(
        RelationshipRepository(db),
        rateLimiter: RateLimiter(db),
      ),
    );
    inbound.registerControlHandler(
      kControlKindPrekeyExchange,
      prekeyExchange.handleControlFrame,
    );

    // E06-T08: same "needs a fully-constructed `this`" reasoning as
    // `prekeyExchange` above. Registered onto its OWN `controlKind` slot
    // (`OQ-E06-T08-2`'s retrofit of the single-slot seam T07 occupied
    // first) rather than fighting `prekeyExchange` for the one slot that
    // used to exist. Also subscribed here, unconditionally, to
    // `inbound.delivered` -- a broadcast stream that produces nothing until
    // `coordinator.start()` actually calls `inbound.start()` (this file's
    // own "does NOT start anything" contract, unchanged: subscribing to a
    // dormant stream starts nothing by itself) -- so every newly-persisted,
    // non-duplicate inbound message automatically gets an
    // accepted+delivered ack sent back to its sender with no call site
    // needed outside this composition root (task file §3).
    deliveryAckService = DeliveryAckService(stack: this);
    inbound.registerControlHandler(
      kControlKindDeliveryAck,
      deliveryAckService.handleControlFrame,
    );
    inbound.delivered.listen((message) {
      unawaited(
        deliveryAckService.onMessageStored(message, message.senderDeviceId),
      );
    });

    // E07-T03: same "needs a fully-constructed `this`" reasoning as
    // `prekeyExchange`/`deliveryAckService` above. Registered onto its own
    // `controlKind` slot (`kControlKindGroupControl == 3`, the next unused
    // value after T07's `1` and T08's `2`) -- see `group_control.dart`'s
    // header for why this sub-protocol's payload is ciphertext, not the
    // cleartext body T07/T08 send.
    groupMembershipService = GroupMembershipService(
      stack: this,
      repository: GroupRepository(db),
      relationshipRepository: RelationshipRepository(db),
    );
    inbound.registerControlHandler(
      kControlKindGroupControl,
      groupMembershipService.handleWireFrame,
    );

    // E07-T04: same "needs a fully-constructed `this`" reasoning as
    // `prekeyExchange`/`groupMembershipService` above. Registered onto its
    // own `controlKind` slot (`kControlKindGroupKeyDistribution == 4`, the
    // next unused value after T07's `1`, T08's `2` and T03's `3`) -- see
    // `group_crypto_service.dart`'s header for why a group chain key
    // travels the same pairwise-session route T03's membership frames do.
    groupCryptoService = GroupCryptoService(stack: this);
    inbound.registerControlHandler(
      kControlKindGroupKeyDistribution,
      groupCryptoService.handleWireFrame,
    );

    // E07-T14: FR-COMM-002's send half, made production-reachable
    // (`OQ-E07-T06-2`). Built here, in the constructor BODY, strictly AFTER
    // `groupCryptoService` above -- `SendGroupMessageUseCase` reads
    // `groupCryptoService`, which is itself only assigned a few lines up
    // (also in this body, not the initializer list, for the same
    // fully-constructed-`this` reason -- this file's header). Building this
    // in `create()` instead is impossible for the identical reason and must
    // not be attempted (task file §6): there is no `groupCryptoService` yet
    // at that point in the program's life, and `create()` is called by
    // every existing stack test, so getting this wrong throws a loud
    // `LateInitializationError` immediately.
    //
    // The optional sequence-reservation seam is deliberately left UNBOUND
    // here -- the default binding inside `SendGroupMessageUseCase` itself
    // is `MessageSequenceReserver`, the one shared reservation transaction
    // `SendMessageUseCase` also uses (`OQ-E07-T06-1`). Passing a second
    // reservation function from this composition root would reintroduce the
    // exact two-writers-of-one-counter shape L-backend-003 is about.
    //
    // `enqueue: relayEngine.enqueue` is a tear-off with NO adapter --
    // `GroupMessageEnqueueFn`'s arity/order/return type
    // (`send_group_message_use_case.dart:59-64`) already match
    // `RelayEngine.enqueue` (`relay_engine.dart:106-111`) exactly, verified
    // again here (task file §5); this is the same tear-off `sendMessage`
    // above already uses for the 1:1 send path.
    sendGroupMessage = SendGroupMessageUseCase(
      db: db,
      selfDeviceId: selfDeviceId,
      groups: GroupRepository(db),
      crypto: groupCryptoService,
      enqueue: relayEngine.enqueue,
    );

    // E07-T09: same "needs a fully-constructed `this`" reasoning as
    // `prekeyExchange`/`groupMembershipService`/`groupCryptoService` above.
    // Registered onto its own `controlKind` slot
    // (`kControlKindCallSignaling == 5`, the next unused value after T07's
    // `1`, T08's `2`, T03's `3` and T04's `4`) -- see `call_signaling.dart`'s
    // header for why this sub-protocol's payload is ciphertext through the
    // pairwise session, not the cleartext body T07/T08 send.
    callSignaling = CallSignaling(
      stack: this,
      relationshipRepository: RelationshipRepository(db),
    );
    inbound.registerControlHandler(
      kControlKindCallSignaling,
      callSignaling.handleWireFrame,
    );

    // E09-T03: same "needs a fully-constructed `this`" reasoning as every
    // other control sub-protocol above. Registered onto its own
    // `controlKind` slot (`kControlKindLocationShare == 7`, the next unused
    // value after T07's `1`, T08's `2`, T03's `3`, T04's `4`, T09's `5` and
    // `kControlKindGroupMessage`'s `6`) -- see `location_share.dart`'s
    // header for why this sub-protocol's payload is ciphertext through the
    // pairwise session, matching `group_control.dart`/`call_signaling.dart`
    // rather than `PrekeyExchange`/`DeliveryAck`'s cleartext one.
    // `locationSource` is a real `PlatformLocationSource` as of E09-T05 --
    // constructed exactly once, here, in this composition root (task file
    // §3: "constructed exactly once, replacing whatever no-op/absent source
    // that task left in place"). `E09-T03`'s own placeholder
    // (`_UnavailableLocationSource`) is retired by this same change.
    locationShareService = LocationShareService(
      stack: this,
      settings: LocationSettingsRepository(db: db),
      fixes: LocationFixRepository(db: db),
      relationships: RelationshipRepository(db),
      locationSource: PlatformLocationSource(),
    );
    inbound.registerControlHandler(
      kControlKindLocationShare,
      locationShareService.handleWireFrame,
    );

    // E04-B12 (Option A, part 1/2): same "needs a fully-constructed `this`"
    // reasoning as every other control sub-protocol above. Registered onto
    // its OWN dedicated slot (`InboundPipeline.registerIdentityAnnounceHandler`
    // — deliberately NOT `registerControlHandler`'s `_controlHandlers` map,
    // since this is the one controlKind whose dispatch bypasses `isForUs`
    // entirely; see `inbound_pipeline.dart`'s own `_handleBuffer` and
    // `identity_announce.dart`'s header for the full justification).
    //
    // `inbound.peerConnected.listen(...)` mirrors EXACTLY the shape
    // `inbound.delivered.listen(...)` already uses a few lines above for
    // `deliveryAckService`: a broadcast stream that produces nothing until
    // `coordinator.start()` actually calls `inbound.start()` (this file's
    // own "does NOT start anything" contract, unchanged — subscribing to a
    // dormant stream starts nothing by itself), so every fresh connection
    // automatically fires an identity-announce with no call site needed
    // outside this composition root (task file §3 point 5). Best-effort
    // (`unawaited`): a failed/timed-out announce is only ever counted on
    // `identityAnnounce.counters`, never allowed to affect anything else
    // observing this same connection event.
    identityAnnounce = IdentityAnnounceService(stack: this);
    inbound.registerIdentityAnnounceHandler(identityAnnounce.handleAnnounce);
    inbound.peerConnected.listen((peerDeviceId) {
      unawaited(identityAnnounce.sendAnnounce(peerDeviceId));
    });
  }

  /// The single app-wide `AppDatabase` — passed in, never constructed here
  /// (task file §5: "the single app-wide AppDatabase already registered in
  /// bindings.dart").
  final AppDatabase db;

  /// The same `DriftSignalProtocolStore` instance wired into
  /// [cryptoService]/[identityService] (E06-T07) -- exposed here so
  /// [PrekeyExchange.ensureSession] can check `containsSession` without a
  /// new accessor on `CryptoService` itself (this task's files: fence
  /// forbids modifying that class). Read-only in spirit: nothing outside
  /// this stack's own construction writes through this reference.
  final DriftSignalProtocolStore signalStore;

  final IdentityService identityService;
  final CryptoService cryptoService;
  final TransportService transport;

  /// E04-B05: the SAME connect-then-send path [relayEngine] uses
  /// (`ConnectionEnsuringSender.ensureConnectedAndSend`), exposed here for
  /// the four control sub-protocols that intentionally bypass
  /// `relayEngine.enqueue` for a direct, unqueued send
  /// (`PrekeyExchange`/`DeliveryAckService`/`CallSignaling`/
  /// `LocationShareService` — each already documents its own reason: first
  /// contact, an ack that must not itself trigger another ack, real-time
  /// call signaling, and a live location fix, respectively). Before this
  /// fix, every one of those four called [transport].send directly, which
  /// hits the same never-connected socket this whole task exists to fix —
  /// confirmed live: `PrekeyExchange.ensureSession`'s own bundle-request
  /// send sits upstream of every `RelayEngine` send a real first-contact
  /// message would ever reach, so leaving those four call sites unfixed
  /// would have made this task's own real-hardware repro fail identically
  /// after merge. Callers should use THIS, never [transport].send
  /// directly, for any call that needs the native socket to actually be
  /// open.
  final RelaySendFn directSend;
  final RoutingEngine routingEngine;
  final RelayEngine relayEngine;
  final SendMessageUseCase sendMessage;
  final ReceiveMessageUseCase receiveMessage;
  final SyncCursorService syncCursors;

  /// E06-T06: the receive-side wedge (E06-T05), bound to this exact stack.
  /// Constructed here, never started by [create] (see this file's header)
  /// — `coordinator.start()` is what actually starts it.
  late final InboundPipeline inbound;

  /// E06-T06: the relay-queue/inbound-pipeline/sync-cursor driver — closes
  /// E05-B02. Constructed here, never started by [create]; see this file's
  /// header for exactly why the actual `start()` call site is deliberately
  /// not wired in this file.
  late final MessagingCoordinator coordinator;

  /// E06-T07: prekey-bundle exchange and first-contact session
  /// establishment (closes OQ-E05-T02-1). Constructed here and already
  /// registered as `inbound`'s one control handler by the time [create]
  /// returns -- no separate wiring call needed at any call site.
  late final PrekeyExchange prekeyExchange;

  /// E06-T08: delivery acknowledgements (`accepted`/`delivered`/`read`).
  /// Constructed here, registered on `inbound`'s `controlKind == 2` slot,
  /// and already subscribed to `inbound.delivered` -- see the constructor
  /// body's own comment for why that subscription starts nothing by
  /// itself.
  late final DeliveryAckService deliveryAckService;

  /// E07-T03: group membership control protocol (create/rename/add/remove/
  /// promote/transfer/delete). Constructed here, registered on
  /// `inbound`'s `controlKind == 3` slot.
  late final GroupMembershipService groupMembershipService;

  /// E07-T04: group sender-key store + distribution over pairwise sessions.
  /// Constructed here, registered on `inbound`'s `controlKind == 4` slot.
  late final GroupCryptoService groupCryptoService;

  /// E07-T14: FR-COMM-002's send half, the production instance of
  /// `SendGroupMessageUseCase` (built and tested by E07-T06, but never
  /// constructed anywhere in the app until this task). `late final`,
  /// constructed in this constructor's body **after** [groupCryptoService]
  /// above -- see the constructor body's own comment for why that ordering
  /// is load-bearing, not incidental. Wired to this stack's own [db], a
  /// fresh `GroupRepository(db)` (same pattern as
  /// [groupMembershipService]'s own), the already-assigned
  /// [groupCryptoService], and [relayEngine].enqueue -- with the optional
  /// sequence-reservation seam left unbound so it defaults to the shared
  /// `MessageSequenceReserver` (`OQ-E07-T06-1`).
  late final SendGroupMessageUseCase sendGroupMessage;

  /// E07-T09: 1:1 call invite/ring/accept/decline/hangup/busy/cancel
  /// signaling. Constructed here, registered on `inbound`'s
  /// `controlKind == 5` slot. Does NOT touch audio/media -- see
  /// `call_signaling.dart`'s header.
  late final CallSignaling callSignaling;

  /// E09-T03: encrypted location share (control kind 7) — gated send +
  /// gated receive. Constructed here, registered on `inbound`'s
  /// `controlKind == 7` slot. Built with a real [PlatformLocationSource]
  /// (E09-T05) — this device's own position is read only after
  /// `LocationVisibilityPolicy` has already approved a share (task file §2).
  late final LocationShareService locationShareService;

  /// E04-B12 (Option A, part 1/2): identity-announce protocol — learns and
  /// stores a peer's real `selfDeviceId` (`relationships.remote_self_
  /// device_id`), keyed by the Bluetooth address the announce arrived on.
  /// Constructed here, registered on `inbound`'s own dedicated
  /// identity-announce slot (NOT a `controlKind` in `_controlHandlers` —
  /// see `identity_announce.dart`'s header for why this one bypasses
  /// `isForUs`), and wired to fire automatically on every fresh connection
  /// via `inbound.peerConnected`. Does NOT yet fix outbound
  /// `RelayPacketFrame` addressing — that is `E04-B13`.
  late final IdentityAnnounceService identityAnnounce;

  /// This device's own local identity (ADR-0005: local, not Firebase-
  /// derived) — from `DeviceIdentityRepository`. May be `''` if no local
  /// device identity has been created yet (see this file's header, judgment
  /// call 3) — [status] is `unavailable` whenever that is the case.
  final String selfDeviceId;

  final MessagingStackStatus status;

  /// Assembles the messaging graph. Never throws: any failure along the way
  /// (crypto/identity bootstrap, or no local device identity yet) is
  /// captured in the returned stack's [status] instead — every field is
  /// still non-null and safe to reference either way (task file §5).
  static Future<MessagingStack> create({
    required AppDatabase db,
    required String selfDeviceId,
    TransportService? transport,
    DateTime Function() clock = DateTime.now,
    DriftSignalProtocolStore? store,
    // E06-T07: defaults to the process-wide singleton, unchanged for every
    // existing caller. `CryptoService.instance` is correct in production
    // (task file's own ADR-0005 premise: exactly one Signal identity per
    // process) but a real correctness hazard for a test that constructs
    // TWO `MessagingStack`s in one process to simulate two devices --
    // `crypto_stub.dart`'s own `CryptoService.withStore` factory exists
    // precisely for that case (its own dartdoc), and
    // `messaging_stack_test.dart`'s `_RemoteParty` helper already uses it
    // rather than a second `create()` call. This override lets a
    // two-stacks-in-one-process test (this task's own
    // `prekey_exchange_test.dart`) give each simulated device its own
    // `CryptoService.withStore(store)` bound to that SAME [store], so
    // `PrekeyExchange`'s `signalStore.containsSession` precondition check
    // and `CryptoService.establishSession`'s actual write always agree —
    // both true in production (there is only one instance either way) and
    // in a test that opts in to isolation.
    CryptoService? cryptoService,
    Duration coordinatorTickInterval = _defaultCoordinatorTickInterval,
  }) async {
    final resolvedTransport = transport ?? TransportService();
    final resolvedStore = store ?? DriftSignalProtocolStore(db);
    final identityService = IdentityService(db, resolvedStore);
    final resolvedCryptoService = cryptoService ?? CryptoService.instance;

    MessagingStackStatus status = const MessagingStackStatus.ready();
    try {
      await resolvedCryptoService.init(resolvedStore);
      await identityService.ensureLocalIdentity();
      await identityService.ensureSignedPreKey();
      await identityService.replenishOneTimePreKeys();
    } catch (e) {
      // Never log the exception's own message — only its type
      // (`docs/conventions.md` "Logging": log code + cause type, never
      // message content).
      status = MessagingStackStatus.unavailable(
        'crypto/identity initialization failed (${e.runtimeType})',
      );
    }
    if (status.isReady && selfDeviceId.isEmpty) {
      // See this file's header, judgment call 3: no local device identity
      // exists yet (pre-first-sign-in). Not a crash, not a special case for
      // callers — just one more `unavailable` reason.
      status = const MessagingStackStatus.unavailable(
        'no local device identity yet (sign in required)',
      );
    }

    final routingEngine = RoutingEngine(selfId: selfDeviceId);
    // E04-B05: `resolvedTransport.send` alone can never succeed against a
    // real device -- the native layer requires an already-open socket, and
    // nothing ever called `resolvedTransport.connect` (confirmed live, on
    // two physical devices: a composed message queued locally and never
    // arrived, with zero Bluetooth-tagged log output on either side).
    // `ConnectionEnsuringSender` connects first (once per device, coalesced
    // against concurrent packets to the same destination), then sends --
    // see that file's own header for the full defect and fix reasoning.
    final connectionEnsuringSender = ConnectionEnsuringSender(
      connect: resolvedTransport.connect,
      send: resolvedTransport.send,
    );
    final relayEngine = RelayEngine(
      selfId: selfDeviceId,
      db: db,
      routingEngine: routingEngine,
      send: connectionEnsuringSender.ensureConnectedAndSend,
      clock: clock,
    );

    Future<Uint8List> encryptAdapter(
      String recipientDeviceId,
      Uint8List envelopeBytes,
    ) async {
      // Producer half of OQ-E05-B01-1 (E06-T02's consumer half:
      // CiphertextCodec.decode + RelayPacketFrame.deserialize). Throws
      // whatever `CryptoService.encrypt` throws — in particular a
      // `StateError` when no session exists yet — unchanged, so
      // `SendMessageUseCase`'s own `on StateError` mapping to
      // `AppFailure('messaging.no_session')` still applies untouched.
      final ciphertextMessage = await resolvedCryptoService.encrypt(
        SignalProtocolAddress(recipientDeviceId, _localSignalDeviceId),
        envelopeBytes,
      );
      final (payloadType, payloadBytes) = CiphertextCodec.encode(
        ciphertextMessage,
      );

      // envelopeBytes is the plaintext MessageEnvelope.serialize() output
      // SendMessageUseCase hands to this adapter (see this file's header,
      // judgment call 2) -- deserializing it back here reads only its own
      // plaintext id field, never anything that leaves this device.
      final envelope = MessageEnvelope.deserialize(envelopeBytes);
      final now = clock();
      final frame = RelayPacketFrame(
        payloadType: payloadType,
        packetId: envelope.id,
        destination: recipientDeviceId,
        source: selfDeviceId,
        priority: _defaultPriority,
        createdAtMs: now.millisecondsSinceEpoch,
        expiresAtMs: now.add(_defaultTtl).millisecondsSinceEpoch,
        payload: payloadBytes,
      );
      return frame.serialize();
    }

    final sendMessage = SendMessageUseCase(
      db: db,
      selfDeviceId: selfDeviceId,
      encrypt: encryptAdapter,
      // MessageEnqueueFn tear-off — matches RelayEngine.enqueue exactly, no
      // adapter needed (see this file's header).
      enqueue: relayEngine.enqueue,
      clock: clock,
    );

    final receiveMessage = ReceiveMessageUseCase(database: db);

    final syncCursors = SyncCursorService(
      localDeviceId: selfDeviceId,
      database: db,
      clock: clock,
    );

    final stack = MessagingStack._(
      db: db,
      signalStore: resolvedStore,
      identityService: identityService,
      cryptoService: resolvedCryptoService,
      transport: resolvedTransport,
      directSend: connectionEnsuringSender.ensureConnectedAndSend,
      routingEngine: routingEngine,
      relayEngine: relayEngine,
      sendMessage: sendMessage,
      receiveMessage: receiveMessage,
      syncCursors: syncCursors,
      selfDeviceId: selfDeviceId,
      status: status,
      coordinatorTickInterval: coordinatorTickInterval,
    );

    // E09-B06: `LocationShareService.pruneFixesForNonVisiblePeers()`
    // (E09-B02's fix for FR-LOC-004/EARS-LOC-5) exists and is tested, but
    // had zero call sites anywhere in `lib/` -- a blocked/de-authorized
    // peer's stored `location_fixes` row was written BEFORE the
    // relationship changed stays on disk indefinitely, because
    // `handleWireFrame`'s own delete-on-not-visible branch only fires when
    // a NEW frame arrives, and a blocked peer's frames are exactly the ones
    // that never arrive again. Run once here, at this composition root's
    // own startup, closing the exposure window down to "at most until next
    // launch" for every relationship change that happened while the app was
    // closed (bug file's fix direction (1)). `locationShareService` is
    // unconditionally constructed above regardless of [status] (this
    // file's own "every field still non-null and safe to reference either
    // way" contract), and this sweep only touches this device's own local
    // `location_fixes` table -- nothing here depends on crypto/identity
    // having initialized successfully, so it runs even when [status] is
    // `unavailable`.
    //
    // Deliberately NOT also wired reactively off a table-wide relationship
    // change stream (bug file's fix direction (2)): no such stream exists
    // yet on `RelationshipRepository` (only `E09-B01`'s per-peer
    // `watchState(deviceId)` does), and adding one is out of this bug's
    // `files:` fence, which lists only this file and its test -- tracked as
    // `E09-B07`, not left as an unread note in this closed file.
    //
    // Wrapped in its own try/catch (carried-forward observation, PR #49
    // round-1 review): every other step in this constructor degrades to
    // `unavailable` on failure rather than making the whole stack
    // unconstructible, and a throw here -- e.g. a corrupt row, a transient
    // storage error -- must not be the one exception to that contract. A
    // failed sweep just means the exposure window from `E09-B02` stays
    // open a little longer; it must never mean the app fails to start.
    try {
      await stack.locationShareService.pruneFixesForNonVisiblePeers();
    } catch (_) {
      // Best-effort: the sweep is a privacy hygiene pass, not a
      // correctness-critical step. Never let it block composition.
    }

    return stack;
  }

  /// Closes transport subscriptions and the database. Test-only — the app
  /// process never calls this (task file §5). Also stops [coordinator]
  /// (which stops [inbound] as part of its own `stop()`) so a disposed
  /// stack's timer/subscriptions do not keep firing in a test process after
  /// the stack itself is gone.
  Future<void> dispose() async {
    await coordinator.stop();
    await transport.dispose();
    await db.close();
  }
}
