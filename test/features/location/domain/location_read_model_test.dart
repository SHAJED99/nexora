// Tests for LocationReadModel (E09-T04, task file §8).
//
// `FR-LOC-005`'s SHALL NOT ("never represent stale location as live") is
// discharged by `LocationReading`'s own shape (`freshness` required,
// `capturedAt` present on every `LocationAvailable`) -- these tests prove
// the read path computes that shape correctly, not merely that it compiles.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/features/location/data/location_fix_repository.dart';
import 'package:nexora/features/location/data/location_settings_repository.dart';
import 'package:nexora/features/location/domain/location_read_model.dart';
import 'package:nexora/features/location/domain/location_visibility.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

void main() {
  late AppDatabase db;
  late LocationFixRepository fixes;
  late LocationSettingsRepository settings;
  late RelationshipRepository relationships;

  const peer = 'peer-1';
  final fixedNow = DateTime.utc(2026, 1, 1, 12, 0, 0);

  LocationReadModel buildModel({DateTime? now, Duration? liveWindow}) {
    return LocationReadModel(
      fixes: fixes,
      settings: settings,
      relationships: relationships,
      liveWindow: liveWindow ?? kLocationLiveWindow,
      clock: () => now ?? fixedNow,
    );
  }

  Future<void> allowPeer() async {
    await relationships.upsert(peer, RelationshipState.trusted);
    await settings.writeGlobalEnabled(true);
    await settings.writePeerEnabled(peer, true);
  }

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    fixes = LocationFixRepository(db: db);
    settings = LocationSettingsRepository(db: db);
    relationships = RelationshipRepository(db);
  });

  tearDown(() => db.close());

  test(
      'test_EARS_LOC_2_last_known_reading_always_carries_captured_at',
      () async {
    await allowPeer();
    final capturedAt = fixedNow.subtract(const Duration(minutes: 30));
    await fixes.upsertFix(
      peerDeviceId: peer,
      latitude: 1.0,
      longitude: 2.0,
      capturedAtMs: capturedAt.millisecondsSinceEpoch,
      receivedAtMs: fixedNow.millisecondsSinceEpoch,
    );

    final reading = await buildModel().read(peer);

    expect(reading, isA<LocationAvailable>());
    final available = reading as LocationAvailable;
    expect(available.freshness, LocationFreshness.lastKnown);
    expect(
      available.capturedAt.millisecondsSinceEpoch,
      capturedAt.millisecondsSinceEpoch,
    );
  });

  test(
      'test_EARS_LOC_2_no_stored_fix_reports_unavailable_with_null_reason',
      () async {
    await allowPeer();

    final reading = await buildModel().read(peer);

    expect(reading, isA<LocationUnavailable>());
    expect((reading as LocationUnavailable).reason, isNull);
  });

  test('test_EARS_LOC_13_fix_within_live_window_reports_live', () async {
    await allowPeer();
    final capturedAt = fixedNow.subtract(const Duration(minutes: 1));
    await fixes.upsertFix(
      peerDeviceId: peer,
      latitude: 1.0,
      longitude: 2.0,
      capturedAtMs: capturedAt.millisecondsSinceEpoch,
      receivedAtMs: fixedNow.millisecondsSinceEpoch,
    );

    final reading = await buildModel().read(peer) as LocationAvailable;

    expect(reading.freshness, LocationFreshness.live);
    expect(
      reading.staleAt.millisecondsSinceEpoch,
      capturedAt.add(kLocationLiveWindow).millisecondsSinceEpoch,
    );
  });

  test('test_EARS_LOC_13_fix_older_than_live_window_reports_last_known',
      () async {
    await allowPeer();
    final capturedAt = fixedNow.subtract(const Duration(minutes: 10));
    await fixes.upsertFix(
      peerDeviceId: peer,
      latitude: 1.0,
      longitude: 2.0,
      capturedAtMs: capturedAt.millisecondsSinceEpoch,
      receivedAtMs: fixedNow.millisecondsSinceEpoch,
    );

    final reading = await buildModel().read(peer) as LocationAvailable;

    expect(reading.freshness, LocationFreshness.lastKnown);
  });

  test(
      'test_EARS_LOC_13_fix_exactly_at_live_window_boundary_reports_live',
      () async {
    await allowPeer();
    final capturedAt = fixedNow.subtract(kLocationLiveWindow);
    await fixes.upsertFix(
      peerDeviceId: peer,
      latitude: 1.0,
      longitude: 2.0,
      capturedAtMs: capturedAt.millisecondsSinceEpoch,
      receivedAtMs: fixedNow.millisecondsSinceEpoch,
    );

    final reading = await buildModel().read(peer) as LocationAvailable;

    expect(reading.freshness, LocationFreshness.live);
  });

  test('test_EARS_LOC_13_fix_one_ms_past_boundary_reports_last_known',
      () async {
    await allowPeer();
    final capturedAt =
        fixedNow.subtract(kLocationLiveWindow + const Duration(milliseconds: 1));
    await fixes.upsertFix(
      peerDeviceId: peer,
      latitude: 1.0,
      longitude: 2.0,
      capturedAtMs: capturedAt.millisecondsSinceEpoch,
      receivedAtMs: fixedNow.millisecondsSinceEpoch,
    );

    final reading = await buildModel().read(peer) as LocationAvailable;

    expect(reading.freshness, LocationFreshness.lastKnown);
  });

  test(
      'test_EARS_LOC_13_freshness_uses_captured_at_not_received_at',
      () async {
    await allowPeer();
    // capturedAt is 30 minutes stale; receivedAt is "now" -- an
    // implementation that (wrongly) measured against receivedAt would
    // report `live`. Falsification: swap `capturedAt` for `receivedAt` in
    // the implementation and confirm only this test fails.
    final capturedAt = fixedNow.subtract(const Duration(minutes: 30));
    await fixes.upsertFix(
      peerDeviceId: peer,
      latitude: 1.0,
      longitude: 2.0,
      capturedAtMs: capturedAt.millisecondsSinceEpoch,
      receivedAtMs: fixedNow.millisecondsSinceEpoch,
    );

    final reading = await buildModel().read(peer) as LocationAvailable;

    expect(reading.freshness, LocationFreshness.lastKnown);
  });

  test(
      'test_EARS_LOC_14_blocked_peer_with_stored_fix_reports_unavailable_blocked',
      () async {
    await relationships.upsert(peer, RelationshipState.blocked);
    await settings.writeGlobalEnabled(true);
    await settings.writePeerEnabled(peer, true);
    await fixes.upsertFix(
      peerDeviceId: peer,
      latitude: 1.0,
      longitude: 2.0,
      capturedAtMs: fixedNow.millisecondsSinceEpoch,
      receivedAtMs: fixedNow.millisecondsSinceEpoch,
    );

    final reading = await buildModel().read(peer);

    expect(reading, isA<LocationUnavailable>());
    expect(
      (reading as LocationUnavailable).reason,
      LocationUnavailableReason.blocked,
    );
  });

  test(
      'test_EARS_LOC_14_global_off_with_fresh_fix_reports_unavailable_global_off',
      () async {
    await relationships.upsert(peer, RelationshipState.trusted);
    await settings.writeGlobalEnabled(false);
    await settings.writePeerEnabled(peer, true);
    await fixes.upsertFix(
      peerDeviceId: peer,
      latitude: 1.0,
      longitude: 2.0,
      capturedAtMs: fixedNow.millisecondsSinceEpoch,
      receivedAtMs: fixedNow.millisecondsSinceEpoch,
    );

    final reading = await buildModel().read(peer);

    expect(reading, isA<LocationUnavailable>());
    expect(
      (reading as LocationUnavailable).reason,
      LocationUnavailableReason.globalOff,
    );
  });

  test('watch emits the current reading immediately on listen', () async {
    await allowPeer();
    final capturedAt = fixedNow.subtract(const Duration(minutes: 1));
    await fixes.upsertFix(
      peerDeviceId: peer,
      latitude: 1.0,
      longitude: 2.0,
      capturedAtMs: capturedAt.millisecondsSinceEpoch,
      receivedAtMs: fixedNow.millisecondsSinceEpoch,
    );

    final reading = await buildModel().watch(peer).first;

    expect(reading, isA<LocationAvailable>());
    expect((reading as LocationAvailable).freshness, LocationFreshness.live);
  });

  test('watch emits a new reading after a fix is upserted', () async {
    await allowPeer();
    final model = buildModel();

    final events = <LocationReading>[];
    final sub = model.watch(peer).listen(events.add);
    await Future<void>.delayed(Duration.zero);
    expect(events, hasLength(1));
    expect(events.first, isA<LocationUnavailable>());

    await fixes.upsertFix(
      peerDeviceId: peer,
      latitude: 1.0,
      longitude: 2.0,
      capturedAtMs: fixedNow.millisecondsSinceEpoch,
      receivedAtMs: fixedNow.millisecondsSinceEpoch,
    );
    await Future<void>.delayed(Duration.zero);

    expect(events.length, greaterThanOrEqualTo(2));
    expect(events.last, isA<LocationAvailable>());

    await sub.cancel();
  });

  test('watch reflects a policy change (global switch turned off)', () async {
    await allowPeer();
    final model = buildModel();
    await fixes.upsertFix(
      peerDeviceId: peer,
      latitude: 1.0,
      longitude: 2.0,
      capturedAtMs: fixedNow.millisecondsSinceEpoch,
      receivedAtMs: fixedNow.millisecondsSinceEpoch,
    );

    final events = <LocationReading>[];
    final sub = model.watch(peer).listen(events.add);
    await Future<void>.delayed(Duration.zero);
    expect(events.first, isA<LocationAvailable>());

    await settings.writeGlobalEnabled(false);
    await Future<void>.delayed(Duration.zero);

    expect(events.last, isA<LocationUnavailable>());
    expect(
      (events.last as LocationUnavailable).reason,
      LocationUnavailableReason.globalOff,
    );

    await sub.cancel();
  });

  test(
      'test_watch_cancel_then_relisten_does_not_throw',
      () async {
    // Regression for PR #41 round-2 (Opus review, S2): a shared mutable
    // subscription list across onListen/onCancel on one broadcast
    // controller made this sequence throw ConcurrentModificationError and
    // orphan the second listener's Drift subscriptions. Reproduced 3/3 by
    // the reviewer; falsification: swap the fix back to a single
    // `StreamController.broadcast()` with a shared `subscriptions` list and
    // this test throws.
    await allowPeer();
    final model = buildModel();
    // The SAME stream instance, reused across cancel/re-listen cycles --
    // this is what a widget holding onto `watch(peer)` across rebuilds (or
    // a GetX controller caching the stream field) actually does. Calling
    // `model.watch(peer)` fresh each iteration would build a brand-new
    // controller every time and never touch the shared-state bug at all.
    final stream = model.watch(peer);

    for (var i = 0; i < 3; i++) {
      final events = <LocationReading>[];
      final sub = stream.listen(events.add);
      await Future<void>.delayed(Duration.zero);
      expect(events, isNotEmpty);
      await sub.cancel();
    }
  });

  test(
      'test_watch_second_independent_listener_gets_immediate_emit',
      () async {
    // Regression for PR #41 round-2 (Opus review, S3): a second listener on
    // the old shared-broadcast-controller implementation never received an
    // emit-on-listen at all (the reviewer's probe: subscriber A got 1
    // event, subscriber B got []), contradicting this method's own §5
    // contract that emit-on-listen applies to every listener.
    await allowPeer();
    final capturedAt = fixedNow.subtract(const Duration(minutes: 1));
    await fixes.upsertFix(
      peerDeviceId: peer,
      latitude: 1.0,
      longitude: 2.0,
      capturedAtMs: capturedAt.millisecondsSinceEpoch,
      receivedAtMs: fixedNow.millisecondsSinceEpoch,
    );
    final model = buildModel();
    final stream = model.watch(peer);

    final eventsA = <LocationReading>[];
    final subA = stream.listen(eventsA.add);
    await Future<void>.delayed(Duration.zero);

    final eventsB = <LocationReading>[];
    final subB = stream.listen(eventsB.add);
    await Future<void>.delayed(Duration.zero);

    expect(eventsA, isNotEmpty);
    expect(
      eventsB,
      isNotEmpty,
      reason: 'a second, independent listener must also get an immediate '
          'emit on listen, per this method\'s own doc contract',
    );
    expect(eventsB.first, isA<LocationAvailable>());

    await subA.cancel();
    await subB.cancel();
  });

  test(
      'test_EARS_LOC_13_read_respects_injected_live_window_not_default',
      () async {
    // OQ-E09-T04-2 / task file §5: liveWindow is "injectable so tests pin
    // the boundary" -- but every other test in this file passes the
    // default `kLocationLiveWindow`, so a bug that hardcoded the constant
    // inside `read()`/`watch()` instead of using `this.liveWindow` would
    // leave the whole suite green. This test pins a non-default window
    // (30s) and proves the boundary actually moves.
    await allowPeer();
    const customWindow = Duration(seconds: 30);
    final capturedAt = fixedNow.subtract(const Duration(seconds: 45));
    await fixes.upsertFix(
      peerDeviceId: peer,
      latitude: 1.0,
      longitude: 2.0,
      capturedAtMs: capturedAt.millisecondsSinceEpoch,
      receivedAtMs: fixedNow.millisecondsSinceEpoch,
    );

    // 45s stale is within the 2-minute default -- would report `live` if
    // the implementation ignored the injected window.
    final defaultReading =
        await buildModel().read(peer) as LocationAvailable;
    expect(defaultReading.freshness, LocationFreshness.live);

    // Same fix, 30s custom window: 45s old is now past the boundary.
    final customReading =
        await buildModel(liveWindow: customWindow).read(peer)
            as LocationAvailable;
    expect(customReading.freshness, LocationFreshness.lastKnown);
    expect(
      customReading.staleAt.millisecondsSinceEpoch,
      capturedAt.add(customWindow).millisecondsSinceEpoch,
    );
  });
}
