// features/location/domain — the send + receive halves of the location
// sub-protocol, one owner for both directions (E09-T03, task file §1/§5).
//
// **Security posture (task file §2, the E06-B04 lesson, ADR-0003) — matches
// `group_membership_service.dart`/`call_signaling.dart` exactly.** A
// [LocationShareFrame] always travels encrypted through the pairwise Double
// Ratchet session (`CryptoService`) before it reaches `TransportService`.
// [handleWireFrame] reads the inbound wire frame's own claimed
// `frame.source` ONLY as a hint for which pairwise session to attempt
// decryption under — the ACTING peer id this file ever trusts is the
// address `CryptoService.decrypt` proves the ciphertext really decrypted
// under, never `frame.source` taken at face value. Decrypt failure (wrong
// session, forged claim, tampered bytes) is a silent drop, never a crash
// and never a store. `LocationShareFrame` carries no separate "claimed
// sender" field to cross-check (unlike `GroupControlFrame.actorDeviceId` /
// `CallSignalingFrame.fromDeviceId`) — there is nothing else in the
// plaintext that could disagree with the verified session address, so the
// session address alone is this file's one and only source of peer
// identity for a location fix.
//
// **The gate is enforced twice, deliberately (task file §2).** [share]
// evaluates `LocationVisibilityPolicy` for the RECIPIENT before it reads
// this device's own position or encrypts anything; [handleWireFrame]
// re-evaluates the SAME policy for the SENDER, independently, before it
// ever writes to `location_fixes`. Neither path trusts the other's gate —
// a receive path that trusted the sender's own send-side check would have
// no gate at all.
//
// **No two-sided relationship-state exchange exists yet
// (`OQ-E09-T02-1`).** `LocationVisibilityPolicy.evaluate` takes a
// `remoteState` parameter for `FR-TRUST-005`'s two-sided connection check,
// but nothing in E02-E08 lets one device learn the peer's own stored
// opinion of it, and `OQ-E09-T02-1`'s accepted answer is that this task —
// the first production caller of that policy — "has nowhere truthful to
// get it either." This device's own locally-recorded `RelationshipState`
// for the peer is the only signal available on either side of a share, so
// both [share] and [handleWireFrame] pass that SAME local value for both
// `localState` and `remoteState` — logged as a Deviation (judgment call
// within an already-accepted limitation), not a new Open Question: it
// changes no signature, and a genuine two-sided exchange is explicitly
// declined: the cross-account half permanently by `ADR-0008`, and the
// own-account half by `E12-B11`/`IMP-002` (which descoped `FR-TRUST-007`).
// Not this task's to build either way (task file §4).
//
// This class does NOT implement a real `LocationSource`, does NOT decide
// staleness, does NOT render anything, and does NOT write
// `RelayDeliveryState.failed` (task file §4, `OQ-E09-T03-2`) — a send that
// cannot be delivered returns [LocationShareOutcome.transportFailed] to its
// own caller instead of ever touching that terminal state.
//
// `prefer_initializing_formals` is intentionally not applied to this file's
// constructor, matching the same documented exclusion already used by
// `call_signaling.dart`/`prekey_exchange.dart`/`relay_engine.dart` — the
// field names are prefixed (`_stack`, `_settings`, ...) while the
// constructor's public named parameters match §5's documented call shape.
// ignore_for_file: prefer_initializing_formals
library;

import 'dart:typed_data';

import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/auth/google_auth_service.dart' show AppFailure;
import 'package:nexora/core/crypto/crypto_failures.dart';
import 'package:nexora/core/messaging/group_control.dart'
    show encodeCiphertextControlBody, decodeCiphertextControlBody;
import 'package:nexora/core/messaging/location_share.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/messaging/relay_packet_frame.dart';
import 'package:nexora/core/routing_engine/relay_engine.dart'
    show RelayDeliveryState, RelayPriority;
import 'package:nexora/core/routing_engine/route_cost_calculator.dart'
    show TrafficProfile;
import 'package:nexora/features/location/data/location_fix_repository.dart';
import 'package:nexora/features/location/data/location_settings_repository.dart';
import 'package:nexora/features/location/domain/location_source.dart';
import 'package:nexora/features/location/domain/location_visibility.dart';
import 'package:nexora/features/location/domain/location_visibility_policy.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

/// Matches `messaging_stack.dart`/`call_signaling.dart`/
/// `group_membership_service.dart`'s own `_remoteSignalDeviceId`/
/// `_localSignalDeviceId` — Dart's privacy model makes literal reuse of a
/// `library`-private constant across files impossible, so it is redeclared
/// here, same value, same reasoning.
const int _remoteSignalDeviceId = 1;

/// The wire TTL stamped on every outbound location-share control frame —
/// mirrors `call_signaling.dart`'s `_controlFrameTtl` reasoning: a one-shot
/// static share (`OQ-E09-T03-1`) that outlives this has no periodic
/// republish to fall back on, so there is nothing worth queuing much longer
/// than an ordinary interactive control frame.
const Duration _controlFrameTtl = Duration(minutes: 2);

/// [LocationShareService.share]'s result. Returns, never throws, for every
/// one of these — a refused share is a normal outcome, not an exception
/// (task file §5).
sealed class LocationShareOutcome {
  const LocationShareOutcome();

  const factory LocationShareOutcome.sent() = LocationShareOutcomeSent;

  const factory LocationShareOutcome.blockedByPolicy(
    LocationUnavailableReason reason,
  ) = LocationShareOutcomeBlockedByPolicy;

  const factory LocationShareOutcome.noFix() = LocationShareOutcomeNoFix;

  const factory LocationShareOutcome.transportFailed() =
      LocationShareOutcomeTransportFailed;
}

/// The frame was encrypted and handed off successfully (task file §5's
/// `_sendFrame` sequence completed with a positive delivery signal).
final class LocationShareOutcomeSent extends LocationShareOutcome {
  const LocationShareOutcomeSent();

  @override
  bool operator ==(Object other) => other is LocationShareOutcomeSent;

  @override
  int get hashCode => (LocationShareOutcomeSent).hashCode;

  @override
  String toString() => 'LocationShareOutcome.sent()';
}

/// `FR-LOC-003`'s gate did not hold for the recipient — nothing was
/// acquired, encrypted or sent (task file §5 step 3).
final class LocationShareOutcomeBlockedByPolicy extends LocationShareOutcome {
  const LocationShareOutcomeBlockedByPolicy(this.reason);

  final LocationUnavailableReason reason;

  @override
  bool operator ==(Object other) =>
      other is LocationShareOutcomeBlockedByPolicy && other.reason == reason;

  @override
  int get hashCode => Object.hash(LocationShareOutcomeBlockedByPolicy, reason);

  @override
  String toString() => 'LocationShareOutcome.blockedByPolicy($reason)';
}

/// The gate held, but either [LocationSource.currentFix] returned `null`
/// (task file §5 step 4), or it returned a fix this device cannot encode —
/// an out-of-range or non-finite coordinate (`E09-B10`). Both collapse to
/// the same outcome: no usable position, nothing sent, no peer/network
/// cause involved (contrast [LocationShareOutcomeTransportFailed]).
final class LocationShareOutcomeNoFix extends LocationShareOutcome {
  const LocationShareOutcomeNoFix();

  @override
  bool operator ==(Object other) => other is LocationShareOutcomeNoFix;

  @override
  int get hashCode => (LocationShareOutcomeNoFix).hashCode;

  @override
  String toString() => 'LocationShareOutcome.noFix()';
}

/// The gate held and a fix was acquired, but the encrypted frame could not
/// be handed off (no session establishable, encrypt failure, or a
/// provably-failed send). Deliberately never
/// `RelayDeliveryState.failed` — `OQ-E09-T03-2`/E04-B02's inherited
/// advisory (task file §4).
final class LocationShareOutcomeTransportFailed extends LocationShareOutcome {
  const LocationShareOutcomeTransportFailed();

  @override
  bool operator ==(Object other) =>
      other is LocationShareOutcomeTransportFailed;

  @override
  int get hashCode => (LocationShareOutcomeTransportFailed).hashCode;

  @override
  String toString() => 'LocationShareOutcome.transportFailed()';
}

/// `FR-LOC-003`'s send-side gate + `FR-LOC-004`'s encryption, and the
/// independent receive-side re-gate, in one place (task file §3/§5).
class LocationShareService {
  LocationShareService({
    required MessagingStack stack,
    required LocationSettingsRepository settings,
    required LocationFixRepository fixes,
    required RelationshipRepository relationships,
    required LocationSource locationSource,
    DateTime Function() clock = DateTime.now,
  }) : _stack = stack,
       _settings = settings,
       _fixes = fixes,
       _relationships = relationships,
       _locationSource = locationSource,
       _clock = clock;

  final MessagingStack _stack;
  final LocationSettingsRepository _settings;
  final LocationFixRepository _fixes;
  final RelationshipRepository _relationships;
  final LocationSource _locationSource;
  final DateTime Function() _clock;

  int _packetIdCounter = 0;
  String _nextPacketId() =>
      'location:${_stack.selfDeviceId}-${_clock().microsecondsSinceEpoch}-${_packetIdCounter++}';

  /// The one place both sides of a gate check are computed identically for
  /// [peerDeviceId] — used by both [share] (gating the recipient) and
  /// [handleWireFrame] (gating the sender), so the two evaluations can never
  /// silently drift into different logic (task file §2: "evaluating the
  /// gate once and reusing it across both paths would ... silently make the
  /// receive side trust the send side" — this helper computes the SAME
  /// logic twice, independently, at each call site; it does not share one
  /// evaluation between the two directions).
  Future<LocationVisibility> _evaluateVisibility(String peerDeviceId) async {
    final relationship = await _relationships.get(peerDeviceId);
    final localState = relationship?.state ?? RelationshipState.unknown;
    final globalEnabled = await _settings.readGlobalEnabled();
    final peerEnabled = await _settings.readPeerEnabled(peerDeviceId);

    return LocationVisibilityPolicy.evaluate(
      localState: localState,
      // See this file's header: no two-sided relationship-state exchange
      // exists yet, so this device's own local state stands in for both
      // sides (OQ-E09-T02-1's accepted limitation for v1).
      remoteState: localState,
      globalEnabled: globalEnabled,
      peerEnabled: peerEnabled,
    );
  }

  /// The send sequence (task file §5), in order. Not visible ->
  /// [LocationShareOutcome.blockedByPolicy] and stops before the device's
  /// position is even read (task file §2: "a refused share must not turn on
  /// the GPS").
  Future<LocationShareOutcome> share(String peerDeviceId) async {
    final visibility = await _evaluateVisibility(peerDeviceId);
    if (!visibility.isVisible) {
      return LocationShareOutcome.blockedByPolicy(visibility.reason!);
    }

    final fix = await _locationSource.currentFix();
    if (fix == null) {
      return const LocationShareOutcome.noFix();
    }

    // E09-B10: a fix this device cannot even encode (out-of-range or
    // non-finite lat/lng -- `.round()` throws `UnsupportedError` on NaN/
    // infinite, `serialize()` throws `AppFailure` on an out-of-range
    // coordinate) is treated as `noFix`, not `transportFailed` -- nothing
    // was sent, and nothing about the network or peer session was even
    // attempted yet, so `transportFailed` (a send-path failure) would
    // misattribute the cause. Kept in its own try, separate from the
    // send-path try below, precisely so this distinction survives rather
    // than collapsing into that try's broad `catch (_)`.
    final Uint8List plaintext;
    try {
      plaintext = LocationShareFrame(
        latitudeE7: (fix.latitude * 1e7).round(),
        longitudeE7: (fix.longitude * 1e7).round(),
        accuracyMmm: fix.accuracyM == null
            ? null
            : (fix.accuracyM! * 1000).round(),
        capturedAtMs: fix.capturedAtMs,
      ).serialize();
    } catch (_) {
      return const LocationShareOutcome.noFix();
    }

    try {
      await _stack.prekeyExchange.ensureSession(peerDeviceId);

      final address = SignalProtocolAddress(
        peerDeviceId,
        _remoteSignalDeviceId,
      );
      final ciphertext = await _stack.cryptoService.encrypt(address, plaintext);
      final body = encodeCiphertextControlBody(ciphertext);
      final framedBody = Uint8List(body.length + 1);
      framedBody[0] = kControlKindLocationShare;
      framedBody.setRange(1, framedBody.length, body);

      final now = _clock();
      final wireFrame = RelayPacketFrame(
        payloadType: PayloadType.control,
        packetId: _nextPacketId(),
        destination: peerDeviceId,
        source: _stack.selfDeviceId,
        priority: RelayPriority.interactive,
        createdAtMs: now.millisecondsSinceEpoch,
        expiresAtMs: now.add(_controlFrameTtl).millisecondsSinceEpoch,
        payload: framedBody,
      );
      final serialized = wireFrame.serialize();

      // `call_signaling.dart`'s own `_sendFrame` sequence (task file §5
      // step 10): multi-hop -> the shared relay queue; direct neighbor or
      // unknown route -> straight to transport.
      final route = _stack.routingEngine.computeRoute(
        peerDeviceId,
        TrafficProfile.interactive,
      );

      final bool delivered;
      if (route != null && route.hops.length > 1) {
        final packetId = await _stack.relayEngine.enqueue(
          peerDeviceId,
          serialized,
          RelayPriority.interactive,
          _controlFrameTtl,
        );
        await _stack.relayEngine.processQueue();
        final state = await _stack.relayEngine.deliveryStateOf(packetId);
        delivered =
            state == RelayDeliveryState.forwarding ||
            state == RelayDeliveryState.delivered;
      } else {
        // `_stack.directSend`, not `_stack.transport.send` directly --
        // E04-B05: must connect before sending, not assume an already-open
        // socket.
        delivered = await _stack.directSend(peerDeviceId, serialized);
      }

      if (!delivered) {
        return const LocationShareOutcome.transportFailed();
      }
      return const LocationShareOutcome.sent();
    } catch (_) {
      // Any failure along the send path (no session establishable, an
      // `ensureSession` timeout, an encrypt failure, ...) collapses to the
      // same honest outcome. `OQ-E09-T03-2`: never writes
      // `RelayDeliveryState.failed` -- this is the enqueue-and-forget path
      // unchanged, reported to the caller instead of recorded as a new
      // terminal state.
      return const LocationShareOutcome.transportFailed();
    }
  }

  /// Registered on `stack.inbound.registerControlHandler
  /// (kControlKindLocationShare, ...)`. The receive sequence (task file
  /// §5), in order. Every rejection is a silent drop — never a thrown
  /// error, never a user-facing surface (task file §2: an undecryptable
  /// location frame must not leak that a peer attempted a share).
  Future<void> handleWireFrame(RelayPacketFrame wireFrame) async {
    final CiphertextMessage ciphertext;
    try {
      ciphertext = decodeCiphertextControlBody(wireFrame.payload);
    } on AppFailure {
      return;
    }

    // `wireFrame.source` is used ONLY to select which pairwise session to
    // attempt decryption under -- see this file's header for why a
    // successful decrypt under this address, not the claim itself, is what
    // this file trusts from here on (E06-B04's lesson).
    final address = SignalProtocolAddress(
      wireFrame.source,
      _remoteSignalDeviceId,
    );

    // E09-B11 (ADR-0003 addendum, 2026-09-04): TOFU's risk is accepted
    // app-wide, not patched per-feature -- this file's own E09-B09 gate
    // (an `isTrustedIdentity`/`getIdentity` check before allowing
    // `SessionBuilder.process` to run) was proven not to close the
    // exploit: four sibling decrypt call sites share the same unguarded
    // identity store, so an attacker can pre-poison an identity slot
    // through any of them before this gate is ever reached. The gate also
    // regressed legitimate first-time location sharing between two
    // already-trusted peers with no prior Signal session. No gate here;
    // see the addendum for the accepted-risk rationale.

    final Uint8List plaintext;
    try {
      plaintext = await _stack.cryptoService.decrypt(address, ciphertext);
    } on CryptoDecryptFailure {
      return;
    } catch (_) {
      // Any other decrypt-path failure collapses to the same silent drop.
      return;
    }

    final LocationShareFrame frame;
    try {
      frame = LocationShareFrame.deserialize(plaintext);
    } on AppFailure {
      return;
    }

    // A future-dated fix is never trusted, never stored (task file §2/§5
    // step 4) -- no skew grace.
    if (frame.capturedAtMs > _clock().millisecondsSinceEpoch) {
      return;
    }

    // The address that decrypted this frame IS the authenticated sender
    // (this file's header) -- never `wireFrame.source` taken as a claim in
    // isolation, even though the two happen to be the same string here:
    // decrypt only succeeds because the session bound to that address
    // actually produced this ciphertext.
    final peerDeviceId = wireFrame.source;

    final visibility = await _evaluateVisibility(peerDeviceId);
    if (!visibility.isVisible) {
      // Independent re-gate for the SENDER (task file §2) -- not visible
      // means drop AND delete any previously stored fix, so a peer that has
      // since been blocked (or had sharing turned off) cannot leave a stale
      // fix behind.
      await _fixes.deleteFix(peerDeviceId);
      return;
    }

    await _fixes.upsertFix(
      peerDeviceId: peerDeviceId,
      latitude: frame.latitudeE7 / 1e7,
      longitude: frame.longitudeE7 / 1e7,
      accuracyM: frame.accuracyMmm == null ? null : frame.accuracyMmm! / 1000,
      capturedAtMs: frame.capturedAtMs,
      receivedAtMs: _clock().millisecondsSinceEpoch,
    );
  }

  /// `E09-B02`'s fix (fix direction (b), `EARS-LOC-5`): [handleWireFrame]'s
  /// delete-on-not-visible branch (above) fires only when a NEW frame
  /// arrives from the peer — but the event that matters most, blocking a
  /// peer (or turning sharing off, or a relationship dropping to
  /// `unknown`), is precisely the event that stops that peer from ever
  /// sending another frame. A fix stored while the relationship still
  /// permitted it would otherwise survive on disk indefinitely.
  ///
  /// This sweeps every row currently in `location_fixes`, re-evaluates the
  /// SAME `LocationVisibilityPolicy` [_evaluateVisibility] already uses for
  /// both send and receive, and deletes the rows that no longer pass —
  /// reusing the one gate rather than re-deriving a second block rule
  /// (bug file, fix direction (b)). Bounded by peer count, the same bound
  /// `LocationSettingsRepository.readAllPeerEnabled` already relies on.
  ///
  /// Deliberately does NOT delete a *stale* fix — only a fix whose policy no
  /// longer holds (`E09-T04` §4's other clause stands: staleness is a
  /// reader-side judgement, not a retention decision).
  ///
  /// **Not wired to any caller by this fix.** The bug file names two
  /// plausible call sites — the composition root's startup path, and
  /// `E09-B01`'s new relationship-state watch stream (`RelationshipRepository`)
  /// once it lands — but both call sites live outside this file, and this
  /// task's `files:` fence is confined to this file and its test (bug file
  /// §Fix direction). Wiring a caller is left as a fast-follow; see this PR's
  /// Open Questions.
  Future<void> pruneFixesForNonVisiblePeers() async {
    final rows = await _stack.db.select(_stack.db.locationFixes).get();
    for (final row in rows) {
      final visibility = await _evaluateVisibility(row.peerDeviceId);
      if (!visibility.isVisible) {
        await _fixes.deleteFix(row.peerDeviceId);
      }
    }
  }
}
