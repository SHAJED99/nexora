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
import 'dart:typed_data';

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';

import '../crypto/crypto_stub.dart';
import '../crypto/drift_signal_store.dart';
import '../crypto/identity_service.dart';
import '../persistence/database.dart';
import '../routing_engine/relay_engine.dart';
import '../routing_engine/routing_engine.dart';
import '../transport/transport_service.dart';
import 'ciphertext_codec.dart';
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
    required this.identityService,
    required this.cryptoService,
    required this.transport,
    required this.routingEngine,
    required this.relayEngine,
    required this.sendMessage,
    required this.receiveMessage,
    required this.syncCursors,
    required this.selfDeviceId,
    required this.status,
  });

  /// The single app-wide `AppDatabase` — passed in, never constructed here
  /// (task file §5: "the single app-wide AppDatabase already registered in
  /// bindings.dart").
  final AppDatabase db;

  final IdentityService identityService;
  final CryptoService cryptoService;
  final TransportService transport;
  final RoutingEngine routingEngine;
  final RelayEngine relayEngine;
  final SendMessageUseCase sendMessage;
  final ReceiveMessageUseCase receiveMessage;
  final SyncCursorService syncCursors;

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
  }) async {
    final resolvedTransport = transport ?? TransportService();
    final resolvedStore = store ?? DriftSignalProtocolStore(db);
    final identityService = IdentityService(db, resolvedStore);
    final cryptoService = CryptoService.instance;

    MessagingStackStatus status = const MessagingStackStatus.ready();
    try {
      await cryptoService.init(resolvedStore);
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
    final relayEngine = RelayEngine(
      selfId: selfDeviceId,
      db: db,
      routingEngine: routingEngine,
      // RelaySendFn tear-off — matches TransportService.send exactly, no
      // adapter needed (see this file's header).
      send: resolvedTransport.send,
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
      final ciphertextMessage = await cryptoService.encrypt(
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

    return MessagingStack._(
      db: db,
      identityService: identityService,
      cryptoService: cryptoService,
      transport: resolvedTransport,
      routingEngine: routingEngine,
      relayEngine: relayEngine,
      sendMessage: sendMessage,
      receiveMessage: receiveMessage,
      syncCursors: syncCursors,
      selfDeviceId: selfDeviceId,
      status: status,
    );
  }

  /// Closes transport subscriptions and the database. Test-only — the app
  /// process never calls this (task file §5).
  Future<void> dispose() async {
    await transport.dispose();
    await db.close();
  }
}
