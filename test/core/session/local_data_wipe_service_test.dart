// E15-T01 -- LocalDataWipeService: file-level erase only (no in-memory
// singleton teardown -- that's SignOutUseCase's own step, see
// sign_out_use_case_test.dart). `AppDatabase.forTesting(NativeDatabase
// .memory())` has no file at all (task §6 Risks), so every test here uses a
// real temp directory and a file-backed `NativeDatabase`, injected through
// [LocalDataWipeService]'s own `databaseFile` seam.
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/auth/google_auth_service.dart' show AppFailure;
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/session/local_data_wipe_service.dart';
import 'package:path/path.dart' as p;

void main() {
  late Directory tempDir;
  late File dbFile;

  setUp(() {
    tempDir = Directory.systemTemp.createTempSync('nexora_wipe_test_');
    dbFile = File(p.join(tempDir.path, 'nexora.sqlite'));
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  test(
    'test_EARS_AUTH_5_wipe_deletes_database_file_and_sidecars',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase(dbFile));
      await db.createDeviceIdentity('device-1');
      await db.close();
      // Sidecars: simulated directly rather than depending on the sqlite3
      // native build actually leaving WAL/SHM files behind on this test
      // runner -- the service's own job is "delete these three paths if
      // present," proven independently of whether real WAL mode produced
      // them here.
      final walFile = File('${dbFile.path}-wal')..writeAsBytesSync([1, 2, 3]);
      final shmFile = File('${dbFile.path}-shm')..writeAsBytesSync([1, 2, 3]);
      expect(dbFile.existsSync(), isTrue);

      final service = LocalDataWipeService(databaseFile: () async => dbFile);
      await service.wipe();

      expect(dbFile.existsSync(), isFalse);
      expect(walFile.existsSync(), isFalse);
      expect(shmFile.existsSync(), isFalse);
    },
  );

  test(
    'test_EARS_AUTH_6_sentinel_present_after_interrupted_wipe',
    () async {
      dbFile.writeAsBytesSync([0]);
      final service = LocalDataWipeService(
        databaseFile: () async => dbFile,
        deleteFile: (file) async => throw Exception('locked'),
      );

      await expectLater(service.wipe(), throwsA(isA<AppFailure>()));

      expect(await service.isWipePending(), isTrue);
      expect(File('${dbFile.path}.wipe_pending').existsSync(), isTrue);
      // The interrupted delete never got to run to completion -- the file
      // this fake seam refused to delete is still there.
      expect(dbFile.existsSync(), isTrue);
    },
  );

  test(
    'test_EARS_AUTH_6_complete_pending_wipe_finishes_the_erase',
    () async {
      dbFile.writeAsBytesSync([0]);
      final interruptedService = LocalDataWipeService(
        databaseFile: () async => dbFile,
        deleteFile: (file) async => throw Exception('locked'),
      );
      await expectLater(
        interruptedService.wipe(),
        throwsA(isA<AppFailure>()),
      );
      expect(await interruptedService.isWipePending(), isTrue);

      // A fresh service (e.g. next launch) with a working delete seam.
      final resumedService = LocalDataWipeService(
        databaseFile: () async => dbFile,
      );
      await resumedService.completePendingWipe();

      expect(dbFile.existsSync(), isFalse);
      expect(await resumedService.isWipePending(), isFalse);
    },
  );

  test(
    'test_EARS_AUTH_6_complete_pending_wipe_is_a_noop_without_a_sentinel',
    () async {
      var deleteCalls = 0;
      final service = LocalDataWipeService(
        databaseFile: () async => dbFile,
        deleteFile: (file) async {
          deleteCalls++;
        },
      );

      expect(await service.isWipePending(), isFalse);
      await service.completePendingWipe();

      expect(deleteCalls, 0);
      expect(await service.isWipePending(), isFalse);
    },
  );

  test(
    'test_EARS_AUTH_11_fresh_database_after_wipe_has_no_device_identity',
    () async {
      final db = AppDatabase.forTesting(NativeDatabase(dbFile));
      await db.createDeviceIdentity('device-1');
      expect(await db.latestDeviceIdentity(), isNotNull);
      await db.close();

      final service = LocalDataWipeService(databaseFile: () async => dbFile);
      await service.wipe();
      expect(dbFile.existsSync(), isFalse);

      final freshDb = AppDatabase.forTesting(NativeDatabase(dbFile));
      addTearDown(freshDb.close);

      expect(await freshDb.latestDeviceIdentity(), isNull);
      // A fresh `onCreate` (not a survivor of the deleted file) leaves
      // `PRAGMA user_version` at the database's own current schema version.
      final versionRow =
          await freshDb.customSelect('PRAGMA user_version;').getSingle();
      expect(versionRow.data['user_version'], freshDb.schemaVersion);
    },
  );
}
