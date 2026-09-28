// features/trust/data — `TrustSettingsRepository` (E02-T04, `Q-FUNC-011`).
//
// Same shape as `location_settings_repository_test.dart`: real in-memory
// `AppDatabase`, proving read/watch/write round-trip through the real
// `trust_settings` table this task's migration creates.
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/features/trust/data/trust_settings_repository.dart';

void main() {
  late AppDatabase db;
  late TrustSettingsRepository repository;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = TrustSettingsRepository(db: db);
  });

  tearDown(() => db.close());

  test(
    'test_fresh_install_onCreate_has_the_same_default_row',
    () async {
      // A fresh install runs onCreate, not onUpgrade -- the default row
      // must exist there too, with the same value the migration step
      // inserts (task §2 "Default value", §6 risk note).
      expect(await repository.readAllowNewConnectionRequests(), isTrue);
    },
  );

  test(
    'test_read_write_round_trip',
    () async {
      await repository.writeAllowNewConnectionRequests(false);
      expect(await repository.readAllowNewConnectionRequests(), isFalse);

      await repository.writeAllowNewConnectionRequests(true);
      expect(await repository.readAllowNewConnectionRequests(), isTrue);
    },
  );

  test(
    'test_watch_emits_immediately_on_listen',
    () async {
      // Same first-frame reason `LocationSettingsRepository
      // .watchGlobalEnabled()` documents: a settings surface must not
      // render empty on its first frame.
      final first = await repository.watchAllowNewConnectionRequests().first;
      expect(first, isTrue);
    },
  );

  test(
    'test_watch_emits_on_every_change',
    () async {
      final values = <bool>[];
      final subscription = repository
          .watchAllowNewConnectionRequests()
          .listen(values.add);

      await pumpEventQueue();
      await repository.writeAllowNewConnectionRequests(false);
      await pumpEventQueue();
      await repository.writeAllowNewConnectionRequests(true);
      await pumpEventQueue();

      expect(values, [true, false, true]);
      await subscription.cancel();
    },
  );
}
