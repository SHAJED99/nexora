// Tests for E09-T02 — LocationSettingsRepository, the sole reader/writer of
// `location_settings` and `location_peer_settings`. Tests run over a real
// in-memory `AppDatabase` (E09-T01's migration/onCreate) so the
// fresh-install default row and drift's own Companion/watch semantics are
// exercised for real, not mocked -- same shape as
// `storage_settings_repository_test.dart` (E08-T05).
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/features/location/data/location_settings_repository.dart';

void main() {
  late AppDatabase db;
  late LocationSettingsRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = LocationSettingsRepository(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('FR-LOC-001 -- global sharing switch', () {
    test('test_global_default_is_off_on_fresh_install', () async {
      // E09-T01's migration inserts globalEnabled == false on both
      // onCreate and onUpgrade -- absent evidence of opt-in, the honest
      // default for a privacy control is off.
      expect(await repository.readGlobalEnabled(), isFalse);
    });

    test('test_global_write_read_round_trip', () async {
      await repository.writeGlobalEnabled(true);
      expect(await repository.readGlobalEnabled(), isTrue);

      await repository.writeGlobalEnabled(false);
      expect(await repository.readGlobalEnabled(), isFalse);
    });

    test('test_global_watch_emits_current_value_on_listen', () async {
      await repository.writeGlobalEnabled(true);

      final first = await repository.watchGlobalEnabled().first;
      expect(
        first,
        isTrue,
        reason: 'a stream that does not emit its current value on listen '
            'makes a settings surface render empty on first frame',
      );

      // A second, independent listener must also see the current value.
      final second = await repository.watchGlobalEnabled().first;
      expect(second, isTrue);
    });

    test('test_global_watch_emits_on_change', () async {
      final values = <bool>[];
      final sub = repository.watchGlobalEnabled().listen(values.add);

      await Future<void>.delayed(Duration.zero);
      await repository.writeGlobalEnabled(true);
      await Future<void>.delayed(Duration.zero);

      await sub.cancel();

      expect(values, [false, true]);
    });
  });

  group('FR-LOC-002 / EARS-LOC-7 -- per-user sharing switch', () {
    test('test_EARS_LOC_7_absent_peer_row_reads_false', () async {
      // The whole bug (task §6 risk note): a careless `?? true` here makes
      // every unconfigured peer shareable by default.
      expect(await repository.readPeerEnabled('peer-never-configured'), isFalse);
    });

    test('test_peer_watch_emits_false_on_listen_with_no_row', () async {
      final first =
          await repository.watchPeerEnabled('peer-never-configured').first;
      expect(first, isFalse);
    });

    test('test_peer_write_read_round_trip', () async {
      await repository.writePeerEnabled('peer-1', true);
      expect(await repository.readPeerEnabled('peer-1'), isTrue);

      await repository.writePeerEnabled('peer-1', false);
      expect(await repository.readPeerEnabled('peer-1'), isFalse);
    });

    test('test_peer_upsert_replaces_rather_than_duplicates', () async {
      await repository.writePeerEnabled('peer-1', true);
      await repository.writePeerEnabled('peer-1', false);
      await repository.writePeerEnabled('peer-1', true);

      final all = await repository.readAllPeerEnabled();
      expect(all.length, 1);
      expect(all['peer-1'], isTrue);
    });

    test('test_peer_watch_emits_current_value_then_on_change', () async {
      final values = <bool>[];
      final sub = repository.watchPeerEnabled('peer-1').listen(values.add);

      await Future<void>.delayed(Duration.zero);
      await repository.writePeerEnabled('peer-1', true);
      await Future<void>.delayed(Duration.zero);

      await sub.cancel();

      expect(values, [false, true]);
    });

    test(
        'test_EARS_LOC_7_absent_peer_row_absent_from_read_all',
        () async {
      await repository.writePeerEnabled('peer-configured', false);

      final all = await repository.readAllPeerEnabled();

      expect(
        all.containsKey('peer-configured'),
        isTrue,
        reason: 'explicitly-off peers ARE present in the map, with false',
      );
      expect(all['peer-configured'], isFalse);
      expect(
        all.containsKey('peer-never-configured'),
        isFalse,
        reason: 'a peer with no row must be absent from the map entirely, '
            'not present-with-false -- readAllPeerEnabled is the one place '
            'that distinguishes "never configured" from "explicitly off"',
      );
    });

    test('test_peer_updated_at_is_stamped', () async {
      final before = DateTime.now().millisecondsSinceEpoch;
      await repository.writePeerEnabled('peer-1', true);
      final after = DateTime.now().millisecondsSinceEpoch;

      final row = await (db.select(db.locationPeerSettings)
            ..where((t) => t.peerDeviceId.equals('peer-1')))
          .getSingle();

      expect(row.updatedAt, greaterThanOrEqualTo(before));
      expect(row.updatedAt, lessThanOrEqualTo(after));
    });

    test('test_global_updated_at_is_stamped', () async {
      final before = DateTime.now().millisecondsSinceEpoch;
      await repository.writeGlobalEnabled(true);
      final after = DateTime.now().millisecondsSinceEpoch;

      final row = await (db.select(db.locationSettings)
            ..where((t) => t.id.equals(1)))
          .getSingle();

      expect(row.updatedAt, greaterThanOrEqualTo(before));
      expect(row.updatedAt, lessThanOrEqualTo(after));
    });
  });

  group('readAllPeerEnabled -- the one bulk read', () {
    test('test_read_all_returns_every_configured_peer', () async {
      await repository.writePeerEnabled('peer-a', true);
      await repository.writePeerEnabled('peer-b', false);
      await repository.writePeerEnabled('peer-c', true);

      final all = await repository.readAllPeerEnabled();

      expect(all, {'peer-a': true, 'peer-b': false, 'peer-c': true});
    });

    test('test_read_all_empty_when_no_peer_configured', () async {
      expect(await repository.readAllPeerEnabled(), isEmpty);
    });
  });
}
