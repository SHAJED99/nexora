// features/location/domain — the single read path for a peer's location
// (E09-T04, task file §1/§3).
//
// `FR-LOC-005` has two clauses and only one is optional: the system MAY show
// a last known location with a visible timestamp, and it SHALL NEVER
// represent stale location as live. This file discharges the SHALL NOT
// structurally — [LocationAvailable.freshness] is a required, non-null
// field of the value itself, never a flag a caller might forget to read,
// and [LocationAvailable.capturedAt] is present on BOTH freshness cases, so
// no downstream reader can treat "no timestamp" as "now" (task file §5's
// data section).
//
// Freshness is measured against `capturedAt` (the sender's measurement
// time) — never `receivedAt` — because a fix that arrived a moment ago but
// was measured half an hour earlier is stale (task file §2).
//
// The policy still gates the read: a fix may be stored while the peer has
// since been blocked or turned sharing off, and a stored row is never
// evidence of permission (`chat-location.md`). [read] re-evaluates
// `LocationVisibilityPolicy` first, before the row is even fetched, so
// `unavailable` always beats `lastKnown` (task file §2's last risk note).
//
// This file does NOT render anything and does NOT format a timestamp — no
// `intl`, no `h:mm a` pattern. It returns structured values and a
// `DateTime`; the copy and the format are `design/screens/chat-location.md`
// and `E06-T18`'s (task file §4).
//
// `prefer_initializing_formals` is intentionally not applied to
// `LocationReadModel`'s constructor, matching the same documented exclusion
// already used by `location_share_service.dart`/`call_signaling.dart`/
// `prekey_exchange.dart`/`relay_engine.dart` — the field names are
// prefixed (`_fixes`, `_settings`, ...) while the constructor's public
// named parameters match §5's documented call shape.
// ignore_for_file: prefer_initializing_formals
library;

import 'dart:async';

import 'package:nexora/features/location/data/location_fix_repository.dart';
import 'package:nexora/features/location/data/location_settings_repository.dart';
import 'package:nexora/features/location/domain/location_visibility.dart';
import 'package:nexora/features/location/domain/location_visibility_policy.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

/// Whether a reported [LocationAvailable] is within the live window or
/// merely the last one on record. Never a third "unknown" value — a
/// [LocationReading] that cannot say is [LocationUnavailable] instead.
enum LocationFreshness { live, lastKnown }

/// `FR-LOC-005`'s read-side result: exactly the three cases
/// `design/screens/chat-location.md` renders (task file §2).
sealed class LocationReading {
  const LocationReading();
}

/// A stored fix, gated by [LocationVisibilityPolicy] holding for the peer.
///
/// [capturedAt] is required on both freshness values, not only on
/// `lastKnown` — a `live` reading that cannot say when it was captured
/// cannot be re-checked by anything downstream, and the asymmetric shape is
/// what tempts a caller into treating "no timestamp" as "now" (task file
/// §5).
final class LocationAvailable extends LocationReading {
  const LocationAvailable({
    required this.latitude,
    required this.longitude,
    this.accuracyM,
    required this.capturedAt,
    required this.freshness,
    required this.staleAt,
  });

  final double latitude;
  final double longitude;

  /// `null` = the sender reported no accuracy, never `0`.
  final double? accuracyM;

  /// The sender's measurement time — what freshness is measured against,
  /// never `receivedAt` (task file §2).
  final DateTime capturedAt;

  /// Non-null, required — `FR-LOC-005`'s guard against a default-to-live
  /// bug (task file §6 risk note).
  final LocationFreshness freshness;

  /// `capturedAt + liveWindow` — `OQ-E09-T04-2`'s accepted answer: lets a
  /// long-lived subscriber (`E06-T18`) schedule its own rebuild instead of
  /// holding a `live` reading that silently ages into stale between
  /// `watch()` emissions.
  final DateTime staleAt;

  @override
  bool operator ==(Object other) =>
      other is LocationAvailable &&
      other.latitude == latitude &&
      other.longitude == longitude &&
      other.accuracyM == accuracyM &&
      other.capturedAt == capturedAt &&
      other.freshness == freshness &&
      other.staleAt == staleAt;

  @override
  int get hashCode => Object.hash(
        latitude,
        longitude,
        accuracyM,
        capturedAt,
        freshness,
        staleAt,
      );

  @override
  String toString() =>
      'LocationAvailable(freshness: $freshness, capturedAt: $capturedAt, staleAt: $staleAt)';
}

/// No location can be shown for the peer right now.
///
/// [reason] is `null` when the policy holds but no fix has ever been
/// received; it carries a [LocationUnavailableReason] when the policy
/// itself fails — and the policy failing always wins over a stored fix's
/// age (task file §2).
final class LocationUnavailable extends LocationReading {
  const LocationUnavailable([this.reason]);

  final LocationUnavailableReason? reason;

  @override
  bool operator ==(Object other) =>
      other is LocationUnavailable && other.reason == reason;

  @override
  int get hashCode => Object.hash(LocationUnavailable, reason);

  @override
  String toString() => 'LocationUnavailable(reason: $reason)';
}

/// The default live/stale boundary (`OQ-E09-T04-1`): a defensible default,
/// not a specified one — `spec/` names no threshold and
/// `chat-location.md` explicitly hands update frequency to E09. Named so
/// the threshold is greppable and changeable in one place.
const Duration kLocationLiveWindow = Duration(minutes: 2);

/// `FR-LOC-005` in one place, with the `FR-LOC-003` re-check built in (task
/// file §3).
class LocationReadModel {
  LocationReadModel({
    required LocationFixRepository fixes,
    required LocationSettingsRepository settings,
    required RelationshipRepository relationships,
    this.liveWindow = kLocationLiveWindow,
    DateTime Function() clock = DateTime.now,
  })  : _fixes = fixes,
        _settings = settings,
        _relationships = relationships,
        _clock = clock;

  final LocationFixRepository _fixes;
  final LocationSettingsRepository _settings;
  final RelationshipRepository _relationships;

  /// Injectable so tests pin the boundary instead of sleeping through a
  /// two-minute window (task file §5).
  final Duration liveWindow;

  final DateTime Function() _clock;

  /// Same shape as `LocationShareService._evaluateVisibility` (E09-T03):
  /// no two-sided relationship-state exchange exists yet (`OQ-E09-T02-1`),
  /// so this device's own locally-recorded state stands in for both
  /// `localState` and `remoteState`.
  Future<LocationVisibility> _evaluateVisibility(String peerDeviceId) async {
    final relationship = await _relationships.get(peerDeviceId);
    final localState = relationship?.state ?? RelationshipState.unknown;
    final globalEnabled = await _settings.readGlobalEnabled();
    final peerEnabled = await _settings.readPeerEnabled(peerDeviceId);

    return LocationVisibilityPolicy.evaluate(
      localState: localState,
      remoteState: localState,
      globalEnabled: globalEnabled,
      peerEnabled: peerEnabled,
    );
  }

  /// The one function a UI surface calls (task file §5). Never throws for
  /// any outcome named below — they are all normal results:
  /// - [LocationUnavailable] with the policy's reason when the visibility
  ///   policy fails — checked FIRST, before the row is even fetched, so a
  ///   stored fix's age can never leak through a failed policy (task file
  ///   §2's last risk note).
  /// - [LocationUnavailable] with a `null` reason when the policy holds but
  ///   no fix is stored.
  /// - [LocationAvailable] with [LocationFreshness.live] when
  ///   `clock() - capturedAt <= liveWindow`.
  /// - [LocationAvailable] with [LocationFreshness.lastKnown] otherwise.
  Future<LocationReading> read(String peerDeviceId) async {
    final visibility = await _evaluateVisibility(peerDeviceId);
    if (!visibility.isVisible) {
      return LocationUnavailable(visibility.reason);
    }

    final row = await _fixes.readFix(peerDeviceId);
    if (row == null) {
      return const LocationUnavailable();
    }

    final capturedAt = DateTime.fromMillisecondsSinceEpoch(row.capturedAt);
    final staleAt = capturedAt.add(liveWindow);
    final age = _clock().difference(capturedAt);
    final freshness =
        age <= liveWindow ? LocationFreshness.live : LocationFreshness.lastKnown;

    return LocationAvailable(
      latitude: row.latitude,
      longitude: row.longitude,
      accuracyM: row.accuracyM,
      capturedAt: capturedAt,
      freshness: freshness,
      staleAt: staleAt,
    );
  }

  /// Emits the current reading immediately on listen, then on every
  /// stored-fix or settings change (task file §5).
  ///
  /// A `watch` stream does NOT re-evaluate freshness on the passage of
  /// time — it emits on data change, so a `live` reading can silently age
  /// into staleness without a new event. That is a real limitation, stated
  /// rather than papered over with a timer (`OQ-E09-T04-2`): the caller
  /// re-reads when it renders (using [LocationAvailable.staleAt] to
  /// schedule that rebuild), and [read] is always authoritative.
  ///
  /// Built on [Stream.multi] rather than a single shared
  /// `StreamController.broadcast()`: a broadcast controller has exactly one
  /// `onListen`/`onCancel` pair for the whole stream, so every prior attempt
  /// at this method shared one mutable `subscriptions` list across ALL
  /// listeners. That shape has two independent failure modes, both found in
  /// PR #41 review (round 2, cross-model): (1) cancel-then-re-listen races
  /// `onCancel`'s `subscriptions.clear()` against the new listener's
  /// `onListen` appending to the same list — `ConcurrentModificationError`,
  /// deterministic, plus the orphaned first listener's Drift subscriptions
  /// never got cancelled; (2) a second listener joining a `broadcast()`
  /// stream that has already fired its one-time `onListen` never gets a
  /// fresh emit-on-listen at all, silently breaking this method's own "emits
  /// immediately on listen" contract for every listener but the first.
  /// `Stream.multi(..., isBroadcast: true)` runs its callback once PER
  /// listener, each with its own local `subscriptions` list and its own
  /// emit-on-listen call — independent state, so neither failure mode has
  /// anything shared left to race or skip.
  Stream<LocationReading> watch(String peerDeviceId) {
    return Stream<LocationReading>.multi((controller) {
      final subscriptions = <StreamSubscription<void>>[];

      Future<void> emitCurrent() async {
        if (controller.isClosed) return;
        controller.add(await read(peerDeviceId));
      }

      // Emits the current reading immediately on listen (task file §5) --
      // for THIS listener, independent of any other listener already
      // attached to this stream.
      unawaited(emitCurrent());

      // Each underlying stream already emits-on-listen (the same
      // established shape); `skip(1)` drops that redundant first event so
      // only real subsequent changes trigger a recompute.
      subscriptions
        ..add(
          _fixes.watchFix(peerDeviceId).skip(1).listen((_) {
            unawaited(emitCurrent());
          }),
        )
        ..add(
          _settings.watchGlobalEnabled().skip(1).listen((_) {
            unawaited(emitCurrent());
          }),
        )
        ..add(
          _settings.watchPeerEnabled(peerDeviceId).skip(1).listen((_) {
            unawaited(emitCurrent());
          }),
        );

      controller.onCancel = () async {
        for (final subscription in subscriptions) {
          await subscription.cancel();
        }
        subscriptions.clear();
      };
    }, isBroadcast: true);
  }
}
