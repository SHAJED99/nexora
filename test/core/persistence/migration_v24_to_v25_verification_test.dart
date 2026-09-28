// DIRECT v24 -> v25 verification (E05-T06, ADR-0009) — the same discipline
// `migration_v23_to_v24_verification_test.dart` establishes, and for the same
// reason: a test that starts at `userVersion = 1` and cascades the whole
// chain is a fine test, but it is NOT the production upgrade path. An
// existing install is at exactly 24 and runs ONLY the `from < 25` step.
//
// Constructing a genuine v24 handle without hand-writing 24 versions of DDL:
// open a fresh `AppDatabase` (so `onCreate` builds the real current schema),
// drop the one column `from < 25` is responsible for, stamp `user_version`
// back to 24, and re-open. The second open sees `from == 24, to == 25` and
// runs exactly one step — the one under test.
//
// File-backed, not in-memory, so the first handle can be CLOSED before the
// second is opened: an in-memory handle cannot (closing it destroys the
// database), and sharing one raw handle across two `AppDatabase`
// constructions trips drift's own multi-instance race warning.
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:path/path.dart' as p;
import 'package:sqlite3/sqlite3.dart' as sqlite3;

void main() {
  test(
    'a real v24 database upgrades to v25 and gains a nullable messages.kind',
    () async {
      final dir = await Directory.systemTemp.createTemp('nexora_v24_');
      addTearDown(() => dir.delete(recursive: true));
      final file = File(p.join(dir.path, 'app.sqlite'));

      // 1. Build the real, complete current schema via onCreate.
      final seeded = AppDatabase.forTesting(NativeDatabase(file));
      await seeded.customSelect('SELECT 1').get();

      // A row that must survive the upgrade untouched — and whose `kind`
      // must come out `null`, which is what "null means text" rests on.
      await seeded.customStatement(
        "INSERT INTO messages (id, conversation_id, sender_device_id, "
        "sequence_number, ciphertext, created_at, delivery_state) "
        "VALUES ('v24-msg', 'c-1', 'd-1', 1, x'00', 1000, 'Queued');",
      );

      // 2. Rewind to a genuine v24: remove the column `from < 25` owns, and
      //    stamp the version back. SQLite has supported DROP COLUMN since
      //    3.35; if the bundled version ever predates that, this test fails
      //    loudly rather than silently testing nothing.
      await seeded.customStatement('ALTER TABLE messages DROP COLUMN kind;');
      await seeded.customStatement('PRAGMA user_version = 24;');
      await seeded.close();

      // Prove the precondition against the FILE, through an independent
      // handle, rather than against the connection that wrote it.
      final probe = sqlite3.sqlite3.open(file.path);
      expect(probe.userVersion, 24, reason: 'precondition: file is at v24');
      final v24Columns = probe
          .select('PRAGMA table_info(messages);')
          .map((r) => r['name'] as String)
          .toList();
      expect(
        v24Columns,
        isNot(contains('kind')),
        reason: 'precondition: v24 has no kind column',
      );
      probe.close();

      // 3. Re-open. This is the production upgrade: from == 24, to == 25.
      final upgraded = AppDatabase.forTesting(NativeDatabase(file));
      addTearDown(upgraded.close);

      final row = await (upgraded.select(
        upgraded.messages,
      )..where((t) => t.id.equals('v24-msg'))).getSingle();

      // THE assertion: the pre-existing row survived, and its kind is null —
      // which MEANS text. A non-null default here would assert a content
      // kind the original sender never sent.
      expect(row.kind, isNull);
      expect(row.conversationId, 'c-1');
      expect(row.senderDeviceId, 'd-1');
      expect(row.sequenceNumber, 1);
      expect(row.deliveryState, 'Queued');

      final after = sqlite3.sqlite3.open(file.path);
      expect(after.userVersion, 25, reason: 'upgrade actually ran');
      final v25Columns = after
          .select('PRAGMA table_info(messages);')
          .map((r) => r['name'] as String)
          .toList();
      expect(v25Columns, contains('kind'));
      after.close();

      // And the column is genuinely writable and nullable, not merely
      // present — a new row can carry an explicit kind.
      await upgraded.into(upgraded.messages).insert(
            MessagesCompanion.insert(
              id: 'v25-msg',
              conversationId: 'c-1',
              senderDeviceId: 'd-1',
              sequenceNumber: 2,
              ciphertext: Uint8List.fromList(<int>[0]),
              createdAt: 2000,
              deliveryState: 'Queued',
              kind: const Value(4),
            ),
          );
      final withKind = await (upgraded.select(
        upgraded.messages,
      )..where((t) => t.id.equals('v25-msg'))).getSingle();
      expect(withKind.kind, 4);
    },
  );
}
