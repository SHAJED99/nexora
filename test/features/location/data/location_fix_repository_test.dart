// Tests for LocationFixRepository (E09-T03, task file §5, EARS-LOC-11).
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/features/location/data/location_fix_repository.dart';

void main() {
  late AppDatabase db;
  late LocationFixRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = LocationFixRepository(db: db);
  });

  tearDown(() => db.close());

  test('readFix returns null when no fix is stored', () async {
    expect(await repo.readFix('peer-1'), isNull);
  });

  test('upsertFix stores a fix readable back exactly', () async {
    await repo.upsertFix(
      peerDeviceId: 'peer-1',
      latitude: 40.7128,
      longitude: -74.0060,
      accuracyM: 5.0,
      capturedAtMs: 1000,
      receivedAtMs: 2000,
    );

    final row = await repo.readFix('peer-1');
    expect(row, isNotNull);
    expect(row!.latitude, 40.7128);
    expect(row.longitude, -74.0060);
    expect(row.accuracyM, 5.0);
    expect(row.capturedAt, 1000);
    expect(row.receivedAt, 2000);
  });

  test(
      'test_EARS_LOC_11_second_fix_replaces_first',
      () async {
    await repo.upsertFix(
      peerDeviceId: 'peer-1',
      latitude: 1.0,
      longitude: 1.0,
      accuracyM: 1.0,
      capturedAtMs: 100,
      receivedAtMs: 200,
    );
    await repo.upsertFix(
      peerDeviceId: 'peer-1',
      latitude: 2.0,
      longitude: 2.0,
      accuracyM: null,
      capturedAtMs: 300,
      receivedAtMs: 400,
    );

    final rows = await db.select(db.locationFixes).get();
    expect(rows, hasLength(1));
    final row = rows.single;
    expect(row.latitude, 2.0);
    expect(row.longitude, 2.0);
    // A previous non-null accuracy must not survive a replace that reports
    // none (L-backend-001's Value(null) vs Value.absent() distinction --
    // this is a full replace, so the new null must actually be written).
    expect(row.accuracyM, isNull);
    expect(row.capturedAt, 300);
    expect(row.receivedAt, 400);
  });

  test('deleteFix removes the stored row', () async {
    await repo.upsertFix(
      peerDeviceId: 'peer-1',
      latitude: 1.0,
      longitude: 1.0,
      capturedAtMs: 100,
      receivedAtMs: 200,
    );
    await repo.deleteFix('peer-1');
    expect(await repo.readFix('peer-1'), isNull);
  });

  test('deleteFix on a non-existent row is not an error', () async {
    await repo.deleteFix('never-existed');
    expect(await repo.readFix('never-existed'), isNull);
  });

  test('fixes for different peers do not collide', () async {
    await repo.upsertFix(
      peerDeviceId: 'peer-1',
      latitude: 1.0,
      longitude: 1.0,
      capturedAtMs: 100,
      receivedAtMs: 200,
    );
    await repo.upsertFix(
      peerDeviceId: 'peer-2',
      latitude: 2.0,
      longitude: 2.0,
      capturedAtMs: 300,
      receivedAtMs: 400,
    );

    expect((await repo.readFix('peer-1'))!.latitude, 1.0);
    expect((await repo.readFix('peer-2'))!.latitude, 2.0);

    await repo.deleteFix('peer-1');
    expect(await repo.readFix('peer-1'), isNull);
    expect(await repo.readFix('peer-2'), isNotNull);
  });
}
