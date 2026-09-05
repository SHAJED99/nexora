// NotificationSettingsRepository tests (E10-T02, EARS-NOTIFY-3/4).
//
// Every test uses `AppDatabase.forTesting(NativeDatabase.memory())`, which
// always takes the `onCreate` path -- the v15->v16 upgrade path itself is
// proven separately in
// `test/core/persistence/notification_migration_test.dart` (task §6 risk
// note: a fresh-create database proves nothing about upgrades).
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/notifications/generated/notification_api.g.dart'
    show NotificationCategory;
import 'package:nexora/core/notifications/notification_settings_repository.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/persistence/notification_tables.dart';

void main() {
  late AppDatabase db;
  late NotificationSettingsRepository repo;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repo = NotificationSettingsRepository(db: db);
  });

  tearDown(() => db.close());

  group('isEnabled / setEnabled', () {
    test(
      'test_EARS_NOTIFY_3_set_then_read_roundtrip',
      () async {
        expect(await repo.isEnabled(NotificationCategory.message), isTrue);

        await repo.setEnabled(NotificationCategory.message, false);
        expect(await repo.isEnabled(NotificationCategory.message), isFalse);

        await repo.setEnabled(NotificationCategory.message, true);
        expect(await repo.isEnabled(NotificationCategory.message), isTrue);
      },
    );

    test(
      'isEnabled fails open for a category with no row',
      () async {
        // The migration never seeds a `backgroundService` row (task §2) --
        // this is exactly the "category added after this migration ran"
        // shape the fail-open contract exists for (task §5).
        expect(
          await repo.isEnabled(NotificationCategory.backgroundService),
          isTrue,
        );
      },
    );

    test(
      'setEnabled upserts a category with no existing row',
      () async {
        await repo.setEnabled(NotificationCategory.backgroundService, false);
        expect(
          await repo.isEnabled(NotificationCategory.backgroundService),
          isFalse,
        );
      },
    );
  });

  group('privacyLevel / setPrivacyLevel', () {
    test(
      'test_EARS_NOTIFY_3_privacy_set_then_read_roundtrip',
      () async {
        expect(await repo.privacyLevel(), NotificationPrivacyLevel.hidden);

        await repo.setPrivacyLevel(NotificationPrivacyLevel.senderOnly);
        expect(
          await repo.privacyLevel(),
          NotificationPrivacyLevel.senderOnly,
        );

        await repo.setPrivacyLevel(NotificationPrivacyLevel.full);
        expect(await repo.privacyLevel(), NotificationPrivacyLevel.full);

        await repo.setPrivacyLevel(NotificationPrivacyLevel.hidden);
        expect(await repo.privacyLevel(), NotificationPrivacyLevel.hidden);
      },
    );

    test(
      'test_EARS_NOTIFY_4_unknown_privacy_level_resolves_hidden',
      () async {
        // Write an unrecognised string directly (bypassing the repository's
        // own enum-typed setter), the way a stale/corrupted install might
        // end up with one.
        await db
            .into(db.notificationPreferences)
            .insertOnConflictUpdate(
              NotificationPreferencesCompanion.insert(
                id: const Value(0),
                privacyLevel: const Value('wide-open'),
              ),
            );

        expect(await repo.privacyLevel(), NotificationPrivacyLevel.hidden);
      },
    );

    test(
      'privacyLevel resolves hidden when the singleton row is missing',
      () async {
        await db.delete(db.notificationPreferences).go();
        expect(await repo.privacyLevel(), NotificationPrivacyLevel.hidden);
      },
    );
  });

  group('watchEnabled', () {
    test(
      'watchEnabled emits the current value on listen and on change',
      () async {
        final stream = repo.watchEnabled(NotificationCategory.message);

        final emissions = <bool>[];
        final sub = stream.listen(emissions.add);
        addTearDown(sub.cancel);

        // Let the initial emission land.
        await Future<void>.delayed(Duration.zero);
        expect(emissions, [true]);

        await repo.setEnabled(NotificationCategory.message, false);
        await Future<void>.delayed(Duration.zero);
        expect(emissions, [true, false]);
      },
    );

    test(
      'watchEnabled fails open for a category with no row',
      () async {
        final value =
            await repo.watchEnabled(NotificationCategory.backgroundService).first;
        expect(value, isTrue);
      },
    );
  });
}
