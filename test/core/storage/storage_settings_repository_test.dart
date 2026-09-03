// test/core/storage — E08-T05, StorageSettingsRepository.
//
// The only reader/writer of `storage_policy_settings` (E08-T01's single-row
// table). Tests run over a real in-memory `AppDatabase` so the fresh-install
// default row (inserted by T01's migration/onCreate) and drift's own
// Companion/watch semantics are exercised for real, not mocked.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/storage/storage_settings_repository.dart';

void main() {
  late AppDatabase db;
  late StorageSettingsRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = StorageSettingsRepository(db: db);
  });

  tearDown(() async {
    await db.close();
  });

  group('EARS-STORE-11 — mode choice persisted, defaults to Smart Mode', () {
    test('test_EARS_STORE_11_default_mode_is_smart', () async {
      final settings = await repository.read();
      expect(settings.mode, StorageMode.smart.name);
      expect(settings.olderThanDays, isNull);
      expect(settings.maxBytes, isNull);
      expect(settings.budgetBytes, isNull);
    });

    test('test_EARS_STORE_11_mode_choice_round_trips', () async {
      await repository.setMode(StorageMode.olderThanDays, olderThanDays: 45);

      final reopened = await repository.read();
      expect(reopened.mode, StorageMode.olderThanDays.name);
      expect(reopened.olderThanDays, 45);
      expect(reopened.maxBytes, isNull);

      // Switching mode again clears the previous mode's own parameter back
      // to NULL rather than leaving it stale (L-backend-001: explicit
      // Value(null), not Value.absent()).
      await repository.setMode(
        StorageMode.overSizeMb,
        maxBytes: 5 * 1024 * 1024,
      );
      final switched = await repository.read();
      expect(switched.mode, StorageMode.overSizeMb.name);
      expect(switched.maxBytes, 5 * 1024 * 1024);
      expect(
        switched.olderThanDays,
        isNull,
        reason: 'the previous mode\'s parameter must be cleared, not stale',
      );

      await repository.setMode(StorageMode.smart);
      final backToSmart = await repository.read();
      expect(backToSmart.mode, StorageMode.smart.name);
      expect(backToSmart.olderThanDays, isNull);
      expect(backToSmart.maxBytes, isNull);
    });

    test('test_EARS_STORE_11_watch_emits_current_value_on_listen', () async {
      await repository.setMode(StorageMode.olderThanDays, olderThanDays: 10);

      final first = await repository.watch().first;
      expect(
        first.mode,
        StorageMode.olderThanDays.name,
        reason: 'a broadcast stream that does not emit its current value on '
            'listen makes the settings screen render empty on first frame '
            '(task §6 risk note)',
      );

      // A second, independent listener must also see the current value on
      // listen -- not just the first ever subscriber.
      final second = await repository.watch().first;
      expect(second.mode, StorageMode.olderThanDays.name);
    });

    test('watch emits again after a subsequent write', () async {
      final emissions = <String>[];
      final subscription = repository.watch().listen((row) {
        emissions.add(row.mode);
      });
      addTearDown(subscription.cancel);

      // Let the initial emission land.
      await Future<void>.delayed(Duration.zero);
      expect(emissions, [StorageMode.smart.name]);

      await repository.setMode(StorageMode.overSizeMb, maxBytes: 1024 * 1024);
      await Future<void>.delayed(Duration.zero);

      expect(emissions, [StorageMode.smart.name, StorageMode.overSizeMb.name]);
    });
  });

  group('EARS-STORE-12 — invalid parameters are rejected loudly', () {
    test('test_EARS_STORE_12_invalid_parameters_throw', () async {
      // zero days
      expect(
        () => repository.setMode(StorageMode.olderThanDays, olderThanDays: 0),
        throwsArgumentError,
      );
      // negative days
      expect(
        () =>
            repository.setMode(StorageMode.olderThanDays, olderThanDays: -1),
        throwsArgumentError,
      );
      // missing required parameter for the mode
      expect(
        () => repository.setMode(StorageMode.olderThanDays),
        throwsArgumentError,
      );
      // sub-1-MiB maxBytes
      expect(
        () => repository.setMode(StorageMode.overSizeMb, maxBytes: 1024),
        throwsArgumentError,
      );
      // negative bytes
      expect(
        () => repository.setMode(StorageMode.overSizeMb, maxBytes: -1),
        throwsArgumentError,
      );
      // missing required parameter for the mode
      expect(
        () => repository.setMode(StorageMode.overSizeMb),
        throwsArgumentError,
      );
      // parameter set for the wrong mode
      expect(
        () => repository.setMode(StorageMode.olderThanDays,
            olderThanDays: 10, maxBytes: 1024 * 1024),
        throwsArgumentError,
      );
      expect(
        () => repository.setMode(StorageMode.overSizeMb,
            maxBytes: 1024 * 1024, olderThanDays: 10),
        throwsArgumentError,
      );
      // any parameter set for smart mode
      expect(
        () => repository.setMode(StorageMode.smart, olderThanDays: 10),
        throwsArgumentError,
      );
      expect(
        () => repository.setMode(StorageMode.smart, maxBytes: 1024 * 1024),
        throwsArgumentError,
      );

      // None of the rejected writes should have mutated the row -- rejected
      // loudly, never coerced (task §2).
      final settings = await repository.read();
      expect(settings.mode, StorageMode.smart.name);
    });

    test('exactly 1 MiB is accepted (the boundary is inclusive)', () async {
      await repository.setMode(
        StorageMode.overSizeMb,
        maxBytes: StorageSettingsRepository.minMaxBytes,
      );
      final settings = await repository.read();
      expect(settings.maxBytes, StorageSettingsRepository.minMaxBytes);
    });

    test('exactly 1 day is accepted (the boundary is inclusive)', () async {
      await repository.setMode(StorageMode.olderThanDays, olderThanDays: 1);
      final settings = await repository.read();
      expect(settings.olderThanDays, 1);
    });
  });

  group('setBudgetBytes — OQ-E08-1\'s eventual home, left NULL by this task', () {
    test('stays NULL until explicitly set, and clears back to NULL', () async {
      var settings = await repository.read();
      expect(settings.budgetBytes, isNull);

      await repository.setBudgetBytes(10 * 1024 * 1024 * 1024);
      settings = await repository.read();
      expect(settings.budgetBytes, 10 * 1024 * 1024 * 1024);

      await repository.setBudgetBytes(null);
      settings = await repository.read();
      expect(settings.budgetBytes, isNull);
    });

    test('does not disturb the active mode or its own parameter', () async {
      await repository.setMode(StorageMode.olderThanDays, olderThanDays: 30);
      await repository.setBudgetBytes(1024);

      final settings = await repository.read();
      expect(settings.mode, StorageMode.olderThanDays.name);
      expect(settings.olderThanDays, 30);
      expect(settings.budgetBytes, 1024);
    });
  });
}
