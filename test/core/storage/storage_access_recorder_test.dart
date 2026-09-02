// core/storage — StorageAccessRecorder (E08-T03).
//
// EARS-STORE-7/8: recording is best-effort, coalesced, and NULL-honest.
// `test_EARS_STORE_8_recorder_failure_does_not_break_markRead` and
// `test_EARS_STORE_7_opening_a_conversation_records_an_access` (via a real
// `ChatController`) live in `test/features/chat/presentation/
// chat_controller_test.dart` instead — they exercise the controller's own
// call sites, not the recorder in isolation.
import 'dart:io';

import 'package:drift/drift.dart' hide isNull, isNotNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/storage/storage_access_recorder.dart';

Future<StorageItemStatRow?> _statRow(
  AppDatabase db,
  StorageItemKind kind,
  String itemId,
) {
  return (db.select(db.storageItemStats)
        ..where((t) => t.itemKind.equals(kind.name) & t.itemId.equals(itemId)))
      .getSingleOrNull();
}

void main() {
  late AppDatabase db;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() => db.close());

  test('test_EARS_STORE_7_displaying_a_message_records_an_access', () async {
    final recorder = StorageAccessRecorder(db: db);
    addTearDown(recorder.dispose);

    expect(await _statRow(db, StorageItemKind.message, 'm-1'), isNull);

    recorder.recordAccess(StorageItemKind.message, 'm-1');
    await recorder.flush();

    final row = await _statRow(db, StorageItemKind.message, 'm-1');
    expect(row, isNotNull);
    expect(row!.accessCount, 1);
    expect(row.lastAccessedAt, isNotNull);
  });

  test(
    'test_EARS_STORE_7_repeat_accesses_within_the_window_coalesce',
    () async {
      // A short debounce window so the test doesn't wait 5 real seconds —
      // the contract under test is "coalesce within the window", not any
      // particular window length (task §5: `flushInterval` is a
      // constructor parameter for exactly this reason).
      final recorder = StorageAccessRecorder(
        db: db,
        flushInterval: const Duration(milliseconds: 20),
      );
      addTearDown(recorder.dispose);

      // Ten calls, synchronously back to back — all land in the SAME
      // debounce window (task §8: "ten calls, one write, count reflects
      // ten").
      for (var i = 0; i < 10; i++) {
        recorder.recordAccess(StorageItemKind.message, 'm-coalesce');
      }

      // Before the window elapses, nothing is written yet — proves the
      // ten calls did not each fire their own write.
      expect(await _statRow(db, StorageItemKind.message, 'm-coalesce'), isNull);

      await Future<void>.delayed(const Duration(milliseconds: 60));

      final row = await _statRow(db, StorageItemKind.message, 'm-coalesce');
      expect(row, isNotNull);
      expect(row!.accessCount, 10);
    },
  );

  test(
    'test_EARS_STORE_7_accumulates_across_separate_windows_atomically',
    () async {
      // Falsification target for `skills/implement` §6's atomic-counter
      // requirement: the upsert must ADD to the existing `access_count`,
      // never overwrite it. Two separate flush windows against the SAME
      // item must sum, not replace. (Manually falsified during
      // implementation: swapping the fix's `old.accessCount +
      // Constant(count)` for a plain `Value(count)` made this test fail
      // with `Expected: 15 Actual: <5>` — confirming it fails for the
      // right reason — then the fix was restored and this test re-run
      // green; see the task's Run log.)
      final recorder = StorageAccessRecorder(db: db);
      addTearDown(recorder.dispose);

      for (var i = 0; i < 10; i++) {
        recorder.recordAccess(StorageItemKind.message, 'm-cumulative');
      }
      await recorder.flush();
      expect(
        (await _statRow(db, StorageItemKind.message, 'm-cumulative'))!
            .accessCount,
        10,
      );

      for (var i = 0; i < 5; i++) {
        recorder.recordAccess(StorageItemKind.message, 'm-cumulative');
      }
      await recorder.flush();

      final row = await _statRow(db, StorageItemKind.message, 'm-cumulative');
      expect(row!.accessCount, 15);
    },
  );

  test(
    'test_EARS_STORE_8_never_accessed_item_has_null_timestamp',
    () async {
      // No `recordAccess`/`recordConversationOpened` call was ever made for
      // this item — `storage_item_stats` must have no row for it at all
      // (task §2: "NULL means never observed... never 0"), never a row
      // with `lastAccessedAt == 0` or `accessCount == 0` synthesized as if
      // it had been observed.
      expect(
        await _statRow(db, StorageItemKind.message, 'm-never-accessed'),
        isNull,
      );
    },
  );

  test('test_dispose_flushes_pending_accesses', () async {
    // task §6 Risks: "ChatController is disposed on route pop -- an
    // un-flushed debounce window loses the last few accesses unless
    // dispose() flushes."
    final recorder = StorageAccessRecorder(
      db: db,
      flushInterval: const Duration(seconds: 5),
    );

    recorder.recordAccess(StorageItemKind.message, 'm-dispose');
    // Deliberately not awaiting the 5s debounce window -- dispose() alone
    // must be what makes this durable.
    await recorder.dispose();

    final row = await _statRow(db, StorageItemKind.message, 'm-dispose');
    expect(row, isNotNull);
    expect(row!.accessCount, 1);
  });

  test('test_recordAccess_failure_is_swallowed_not_thrown', () async {
    // Best-effort contract (task §2/§5): a failed stat write is not a
    // user-visible error. Forces a REAL write failure (dropping the table
    // out from under the recorder) rather than mocking, matching this
    // codebase's existing "failing write seam" convention
    // (`agent/memory/lessons/backend.md` L-backend-002).
    final recorder = StorageAccessRecorder(db: db);
    await db.customStatement('DROP TABLE storage_item_stats');

    // Must not throw synchronously...
    expect(
      () => recorder.recordAccess(StorageItemKind.message, 'm-fail'),
      returnsNormally,
    );
    // ...and the deferred write's own failure must not surface as an
    // unhandled Future error either.
    await expectLater(recorder.flush(), completes);
  });

  test(
    'test_EARS_STORE_8_no_other_read_path_records_access',
    () async {
      // Grep-style source assertion (the same shape T02's own task file
      // describes for its analogous "never decrypts" check): the ONLY
      // production call site of `recordAccess`/`recordConversationOpened`
      // is `ChatController` (task §4: "Does not add a call site outside
      // ChatController. Not the conversations list, not the dashboard...
      // Every extra call site silently redefines what 'accessed' means.").
      final libDir = Directory('lib');
      final callers = <String>[];
      await for (final entity in libDir.list(recursive: true)) {
        if (entity is! File || !entity.path.endsWith('.dart')) continue;
        // The recorder's own definition site is not a "call".
        if (entity.path.replaceAll('\\', '/').endsWith(
              'lib/core/storage/storage_access_recorder.dart',
            )) {
          continue;
        }
        final content = await entity.readAsString();
        if (content.contains('.recordAccess(') ||
            content.contains('.recordConversationOpened(')) {
          callers.add(entity.path.replaceAll('\\', '/'));
        }
      }

      expect(
        callers,
        everyElement(endsWith('features/chat/presentation/chat_controller.dart')),
        reason: 'recordAccess/recordConversationOpened must be called only '
            'from ChatController; found: $callers',
      );
      expect(callers, isNotEmpty);
    },
  );
}
