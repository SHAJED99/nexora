// core/messaging — identity-announce protocol (E04-B12, part 1/2 of the
// human-decided Option A fix — see `E04-B13` for part 2/2, the outbound-
// addressing consumer half).
//
// **The bug this exists to fix (task file §2, confirmed live on real
// hardware, not guessed).** This app has two never-reconciled peer-identity
// namespaces: every device's own `selfDeviceId`
// (`lib/features/login/presentation/login_controller.dart`, a random or
// Signal-identity-key-derived string) is what `InboundPipeline`'s `isForUs`
// check and every `RelayPacketFrame.destination`/`.source` field actually
// compare against — but every OUTBOUND call
// (`TransportService.connect`/`.send`, `Relationship.deviceId`, the Devices
// screen) addresses a peer by its raw Bluetooth MAC instead. A message
// addressed by MAC can therefore never match the receiver's real
// `selfDeviceId`, `isForUs` is always false, and `PrekeyExchange
// .ensureSession` times out waiting for a bundle response that could
// structurally never arrive.
//
// **The fix, scoped to this task's own half (task file §2a's
// scope-refinement note).** Keep `Relationship.deviceId` exactly what it
// already is everywhere it's used as a key today (Devices screen, chat
// `conversationId`, transport calls) — zero UI change, zero re-keying. Add
// ONE new nullable column, `relationships.remote_self_device_id`
// (`relationships_table.dart`), and this file: a lightweight, one-way,
// fire-and-forget control frame each side sends the other immediately on
// connect, carrying nothing but its own real `selfDeviceId`. Storing that
// value is THIS task's whole job; actually consuming it to fix outbound
// `RelayPacketFrame` addressing is `E04-B13`.
//
// **Wire body**: just this device's own `selfDeviceId`, UTF-8 encoded —
// no request/response pairing (this is a one-way announcement, sent by BOTH
// sides independently, never a request that expects a reply, task file §3).
//
// **The `isForUs` bypass this control kind needs — and why it is safe
// (task file §3 point 3, the single trickiest part of this task).**
// `InboundPipeline._handleBuffer` normally only looks inside a control
// frame's payload once `frame.destination == selfDeviceId` — but that check
// can NEVER pass for this announce: the whole reason it exists is that
// neither side yet knows the other's real `selfDeviceId`, so there is no
// value either side could put in `destination` that the receiver's
// `isForUs` check could ever match. [InboundPipeline._handleBuffer] carries
// a narrow, explicit bypass for exactly `kControlKindIdentityAnnounce`,
// checked BEFORE `isForUs` is even computed and BEFORE the relay/forward
// branch — see that file's own doc comment for the mechanism.
//
// This bypass is safe, and is NOT the same class of risk as this codebase's
// own already-flagged `frame.source`-is-unauthenticated finding (the TOFU
// exploit shape carried forward from `E09-B09`, see
// `agent/memory/lessons/backend.md`'s `project_frame_source_trust_pattern`
// note): that risk is specifically about a MULTI-HOP RELAYED frame's claimed
// origin being unverifiable — a relay in the middle can forward a frame
// whose `source` byte was set by an attacker several hops away, and nothing
// at the receiving end saw the actual radio connection it originated on.
// This announce is never relayed (point 4 below: it is dropped, never
// forwarded, by the very same bypass that lets it in) and arrives directly
// over `TransportService.incomingData(deviceId)` — a stream keyed
// per-connection since E04-B07, where `deviceId` is the Bluetooth address
// of a link the OS itself already authenticated via bonding before this
// process ever saw a byte on it. A Bluetooth Classic RFCOMM connection is
// inherently point-to-point: ANY frame arriving on THIS device's incoming
// stream for THIS specific bonded address is structurally known to have
// come from that address, regardless of what the frame's own header claims.
// So [IdentityAnnounceService.handleAnnounce] below keys its write by the
// LINK's own device id (the Bluetooth address the frame physically arrived
// on), never by anything the frame's `destination` field claims, and only
// ever reads `frame.source` (the announced value itself) — exactly what a
// direct, OS-authenticated connection can actually vouch for.
//
// **Never relayed (task file §3 point 4).** The bypass in
// `InboundPipeline._handleBuffer` returns immediately after dispatching to
// this file's handler — textually before the `!isForUs` relay branch ever
// runs for this controlKind, so `RelayEngine.enqueue` can never see one of
// these frames.
//
// Does NOT touch `CryptoService`, `DriftSignalProtocolStore`, or any
// identity-key trust logic (task file §4) — this announce carries a plain
// string identifier, not a cryptographic identity claim. Does NOT wire the
// learned value into any OUTBOUND `RelayPacketFrame.destination`/`.source`
// — that is `E04-B13`.
//
// `prefer_initializing_formals` is intentionally not applied to this file's
// constructor, matching the same documented exclusion already used by
// `relay_engine.dart`/`inbound_pipeline.dart`/`prekey_exchange.dart`/
// `messaging_coordinator.dart`: the field is private (`_stack`) while the
// constructor's public named parameter (`stack`) matches every other
// control sub-protocol's own documented contract exactly — an initializing
// formal would rename that named-argument keyword to the private field
// name, breaking the same-shape call site every other sub-protocol shares.
// ignore_for_file: prefer_initializing_formals
import 'dart:convert';

import 'package:drift/drift.dart';

import '../persistence/database.dart';
import '../../features/trust/domain/relationship.dart' show RelationshipState;
import 'messaging_stack.dart';
import 'relay_packet_frame.dart';

/// The `controlKind` byte [InboundPipeline._handleBuffer] bypasses `isForUs`
/// for — see this file's header and that file's own doc comment. Next
/// unused value after `kControlKindLocationShare == 7`
/// (`location_share.dart`).
const int kControlKindIdentityAnnounce = 8;

/// TTL stamped on every outbound announce frame — short-lived on purpose,
/// mirroring `PrekeyExchange._controlFrameTtl`'s own reasoning: an announce
/// that outlives this has already lost its usefulness, and (this exchange's
/// whole premise, like `PrekeyExchange`'s own) it is never queued for later
/// delivery anyway — sent via [MessagingStack.directSend], not
/// `RelayEngine.enqueue`.
const Duration _identityAnnounceFrameTtl = Duration(seconds: 30);

/// So a missing/failed announce has a diagnosable reason (mirrors
/// `PrekeyExchangeCounters`'s own shape) — mutated only by
/// [IdentityAnnounceService] itself.
class IdentityAnnounceCounters {
  /// Outbound announce frames actually sent (`directSend` returned `true`).
  int sent = 0;

  /// Outbound announce attempts whose `directSend` returned `false` (the
  /// peer disconnected, or the connect-then-send failed) — never retried by
  /// this file; a later reconnect fires a fresh attempt (see
  /// `messaging_stack.dart`'s own wiring of [MessagingStack.inbound]'s
  /// `peerConnected` stream).
  int sendFailures = 0;

  /// Inbound announce frames received and processed (task file §3/§6).
  int received = 0;

  /// Inbound announces for a Bluetooth address this side had never recorded
  /// a relationship for at all — a new row is created at
  /// [RelationshipState.unknown], reusing the same state discovery already
  /// uses for a genuinely first-ever contact (task file §3 point 6), never
  /// a second code path.
  int relationshipsCreated = 0;
}

/// Learns and stores a peer's real `selfDeviceId` (see this file's header).
/// Exactly one instance per [MessagingStack] — constructed and registered by
/// `MessagingStack`'s own constructor, the same "needs a fully-constructed
/// `this`" pattern every other control sub-protocol in that file already
/// follows.
class IdentityAnnounceService {
  IdentityAnnounceService({required MessagingStack stack}) : _stack = stack;

  final MessagingStack _stack;

  final IdentityAnnounceCounters counters = IdentityAnnounceCounters();

  /// Sends this device's own [MessagingStack.selfDeviceId] to [peerDeviceId]
  /// — the Bluetooth-address transport id the connection is on, NOT this
  /// device's real self identity being sent TO an address (task file §2a:
  /// "keep Bluetooth MAC only as a transport-layer routing hint"). Direct,
  /// unqueued send via [MessagingStack.directSend] — same reasoning as
  /// `PrekeyExchange._sendControlFrame`: this is a first-contact-shaped
  /// exchange that only ever works with the peer reachable right now.
  ///
  /// Fire-and-forget: no request/response pairing (task file §3), so a
  /// failure is only counted, never retried or surfaced to a caller — the
  /// same "best-effort, never blocks anything else" shape
  /// `MessagingStack.create`'s own location-fix pruning pass already uses
  /// for a non-critical, automatically-fired hook.
  Future<void> sendAnnounce(String peerDeviceId) async {
    final now = DateTime.now();
    final Uint8List bodyBytes =
        Uint8List.fromList(utf8.encode(_stack.selfDeviceId));
    final Uint8List framedBody = Uint8List(bodyBytes.length + 1);
    framedBody[0] = kControlKindIdentityAnnounce;
    framedBody.setRange(1, framedBody.length, bodyBytes);

    final frame = RelayPacketFrame(
      payloadType: PayloadType.control,
      packetId: '${_stack.selfDeviceId}-idann-${now.microsecondsSinceEpoch}',
      // `destination` cannot be the peer's real `selfDeviceId` — this
      // device does not know it yet, which is this whole protocol's reason
      // to exist. The Bluetooth-address transport id is the only value
      // available, and this controlKind is never checked against
      // `isForUs` on the receiving end anyway (this file's header; see
      // `InboundPipeline._handleBuffer`'s own bypass).
      destination: peerDeviceId,
      source: _stack.selfDeviceId,
      priority: 0,
      createdAtMs: now.millisecondsSinceEpoch,
      expiresAtMs: now.add(_identityAnnounceFrameTtl).millisecondsSinceEpoch,
      payload: framedBody,
    );

    final bool sent =
        await _stack.directSend(peerDeviceId, frame.serialize());
    if (sent) {
      counters.sent++;
    } else {
      counters.sendFailures++;
    }
  }

  /// Registered via `InboundPipeline.registerIdentityAnnounceHandler`
  /// (`inbound_pipeline.dart`) — called for a frame that bypassed
  /// `isForUs` entirely, so [frame.destination] must never be trusted or
  /// consulted here (this file's header). [linkDeviceId] is the Bluetooth
  /// address `TransportService.incomingData(deviceId)` delivered this frame
  /// on — the OS-bonded peer this arrived from, independent of anything the
  /// frame's own header claims. [frame.source] is the announced value
  /// itself — the ONLY thing this handler trusts as "the peer's real
  /// `selfDeviceId`", exactly as much authentication as a direct,
  /// point-to-point, OS-authenticated connection can actually provide (this
  /// file's header).
  Future<void> handleAnnounce(
    String linkDeviceId,
    RelayPacketFrame frame,
  ) async {
    counters.received++;
    final String announcedSelfDeviceId = frame.source;

    final db = _stack.db;
    final existing = await (db.select(db.relationships)
          ..where((t) => t.deviceId.equals(linkDeviceId)))
        .getSingleOrNull();

    if (existing == null) {
      // Genuinely first-ever contact with this Bluetooth address — create
      // the row at RelationshipState.unknown, the same state discovery
      // already uses elsewhere for a first-ever contact (task file §3
      // point 6), rather than inventing a second code path for "create a
      // relationship row".
      await db.into(db.relationships).insertOnConflictUpdate(
            RelationshipsCompanion.insert(
              deviceId: linkDeviceId,
              state: RelationshipState.unknown.name,
              updatedAt: DateTime.now(),
              remoteSelfDeviceId: Value(announcedSelfDeviceId),
            ),
          );
      counters.relationshipsCreated++;
    } else {
      // A relationship row already exists for this Bluetooth address —
      // update ONLY `remoteSelfDeviceId` (+`updatedAt`), never `state`:
      // this announce carries no trust information, and must never
      // silently downgrade/upgrade an already-evaluated relationship (task
      // file §2a's scope-refinement note; `EvaluateConnectionRequestUseCase`
      // remains the only writer of `state`).
      await (db.update(db.relationships)
            ..where((t) => t.deviceId.equals(linkDeviceId)))
          .write(
        RelationshipsCompanion(
          remoteSelfDeviceId: Value(announcedSelfDeviceId),
          updatedAt: Value(DateTime.now()),
        ),
      );
    }
  }
}
