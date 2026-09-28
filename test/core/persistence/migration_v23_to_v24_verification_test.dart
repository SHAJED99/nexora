// DIRECT v23 -> v24 verification (E02-T04, `Q-FUNC-011`), written at the
// human's explicit instruction not to accept the existing
// `migration_test.dart` as evidence for this specific claim.
//
// `migration_test.dart`'s own "23_to_24" test starts a raw handle at
// `userVersion = 1` and cascades the whole chain. That is a fine test, but
// it is NOT the production upgrade path: an existing install is at exactly
// 23 and runs ONLY the `from < 24` step. This file builds that exact
// situation -- a database that already holds the real, complete v23 schema
// -- and upgrades it.
//
// Constructing a genuine v23 handle without hand-writing 23 versions of DDL:
// open a fresh `AppDatabase` (so `onCreate` builds the real current schema),
// drop the one table `from < 24` is responsible for, stamp `user_version`
// back to 23, and re-open. The second open sees `from == 23, to == 24` and
// runs exactly one step -- the one under test.
import 'dart:io';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  test(
    'a real v23 database upgrades to v24 and receives the default true',
    () async {
      // File-backed so the first handle can be CLOSED before the second is
      // opened. An in-memory handle cannot: closing it destroys the
      // database. Sharing one raw handle across two `AppDatabase`
      // constructions instead would trip drift's own multi-instance race
      // warning ("might corrupt the database") -- flagged in review, and
      // not a pattern worth keeping in the file that is now the cited
      // evidence for a human-approved migration.
      final dir = await Directory.systemTemp.createTemp('nexora_v23_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File(p.join(dir.path, 'app.sqlite'));

      // 1. Build the real, complete current schema via onCreate.
      final seeded = AppDatabase.forTesting(NativeDatabase(file));
      await seeded.customSelect('SELECT 1').get();

      // A row that must survive the upgrade untouched.
      await seeded.customStatement(
        "INSERT INTO device_identities (device_id, signed_in) "
        "VALUES ('v23-install', 1);",
      );

      // 2. Rewind to a genuine v23: remove the table `from < 24` owns, and
      //    stamp the version back. Everything else stays exactly as a real
      //    v23 install would have it.
      await seeded.customStatement('DROP TABLE trust_settings;');
      await seeded.customStatement('PRAGMA user_version = 23;');
      await seeded.close();

      // Read the stamped version back through an independent handle, so the
      // precondition is proved against the file itself rather than against
      // the connection that wrote it.
      final probe = sqlite3.sqlite3.open(file.path);
      expect(probe.userVersion, 23, reason: 'precondition: file is at v23');
      probe.close();

      // 3. Re-open. This is the production upgrade: from == 23, to == 24.
      final upgraded = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(upgraded.close);

      final row = await (upgraded.select(
        upgraded.trustSettings,
      )..where((t) => t.id.equals(1))).getSingle();

      // THE assertion: an existing install keeps accepting new connection
      // requests. A default of `false` here would silently cut off every
      // upgrading user.
      expect(row.allowNewConnectionRequests, isTrue);

      final after = sqlite3.sqlite3.open(file.path);
      expect(after.userVersion, 24, reason: 'upgrade actually ran');
      after.close();

      // Additive only: pre-existing data survived.
      final identity = await upgraded.latestDeviceIdentity();
      expect(identity!.deviceId, 'v23-install');
    },
  );

  test(
    're-opening an already-upgraded v24 database does not clobber a user '
    'value of false',
    () async {
      // File-backed, not in-memory: this test's whole point is that the
      // database SURVIVES a close, and an in-memory handle does not.
      final dir = await Directory.systemTemp.createTemp('nexora_v24_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File(p.join(dir.path, 'app.sqlite'));

      final first = AppDatabase.forTesting(NativeDatabase(file));
      await (first.update(
        first.trustSettings,
      )..where((t) => t.id.equals(1))).write(
        const TrustSettingsCompanion(
          allowNewConnectionRequests: Value(false),
        ),
      );
      await first.close();

      // The part `migration_test.dart`'s own version of this test never
      // actually does: a genuinely fresh open of the same file. If the
      // seeding insert were not `insertOrIgnore`, this is where a user's
      // deliberate `false` would be silently reset to `true`.
      final reopened = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(reopened.close);

      final row = await (reopened.select(
        reopened.trustSettings,
      )..where((t) => t.id.equals(1))).getSingle();
      expect(row.allowNewConnectionRequests, isFalse);
    },
  );
}
