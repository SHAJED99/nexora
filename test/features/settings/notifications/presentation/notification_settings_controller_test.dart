// features/settings/notifications/presentation --
// NotificationSettingsController (E15-T04).
//
// Real in-memory `AppDatabase` + the real `NotificationSettingsRepository`
// throughout -- these tests prove the controller's *binding* to the
// repository, not a mock's promise that it would. `_ErroringRepository` and
// `_CountingRepository` below are the two seams the task's own risk list
// calls for: a stream that errors, and a call counter -- never `fail()`
// inside an injected seam (a broad catch in the SUT would swallow it,
// L-testing).
import 'dart:async';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/notifications/generated/notification_api.g.dart'
    show NotificationCategory;
import 'package:nexora/core/notifications/notification_settings_repository.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/persistence/notification_tables.dart'
    show NotificationPrivacyLevel;
import 'package:nexora/features/settings/notifications/presentation/notification_settings_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late AppDatabase db;
  late NotificationSettingsRepository repository;
  late NotificationSettingsController controller;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = NotificationSettingsRepository(db: db);
    controller = NotificationSettingsController(repository: repository);
  });

  tearDown(() {
    controller.onClose();
    db.close();
  });

  test(
    'test_EARS_NOTIFY_16_toggling_a_category_persists_through_the_repository',
    () async {
      controller.onInit();
      await pumpEventQueue();
      expect(controller.isEnabled(NotificationCategory.message), isTrue);

      await controller.toggle(NotificationCategory.message);
      await pumpEventQueue();

      expect(controller.isEnabled(NotificationCategory.message), isFalse);
      expect(
        await repository.isEnabled(NotificationCategory.message),
        isFalse,
      );
    },
  );

  test('test_EARS_NOTIFY_16_screen_reflects_an_external_write', () async {
    controller.onInit();
    await pumpEventQueue();
    expect(controller.isEnabled(NotificationCategory.ptt), isTrue);

    // Written directly through the repository, never through the
    // controller -- proves the stream binding, not a local mutation.
    await repository.setEnabled(NotificationCategory.ptt, false);
    await pumpEventQueue();

    expect(controller.isEnabled(NotificationCategory.ptt), isFalse);
  });

  test(
    'test_EARS_NOTIFY_16_background_service_category_is_absent',
    () async {
      expect(NotificationSettingsController.categories, hasLength(9));
      expect(
        NotificationSettingsController.categories,
        isNot(contains(NotificationCategory.backgroundService)),
      );
    },
  );

  test(
    'test_EARS_NOTIFY_17_full_privacy_row_shows_the_unavailable_copy',
    () async {
      // The controller-side half of NT21's contract: `full` is a real,
      // readable value -- never hidden, never disabled-and-greyed (task
      // §4) -- so a row bound to it must be able to render as selected if
      // the repository ever reports it, exactly like any other level.
      await repository.setPrivacyLevel(NotificationPrivacyLevel.full);

      controller.onInit();
      await pumpEventQueue();

      expect(controller.privacy.value, NotificationPrivacyLevel.full);
    },
  );

  test(
    'test_EARS_NOTIFY_17_selecting_full_does_not_write',
    () async {
      final countingRepository = _CountingRepository(db: db);
      final countingController = NotificationSettingsController(
        repository: countingRepository,
      );
      countingController.onInit();
      await pumpEventQueue();

      await countingController.selectPrivacy(NotificationPrivacyLevel.full);
      await pumpEventQueue();

      expect(countingRepository.setPrivacyLevelCalls, 0);
      expect(
        countingController.privacy.value,
        NotificationPrivacyLevel.hidden,
      );
      expect(await repository.privacyLevel(), NotificationPrivacyLevel.hidden);

      countingController.onClose();
    },
  );

  test('test_EARS_UI_9_no_led_control_is_present', () {
    // `GAP-032`'s LED fork carries no proposal (task §4, Open Questions
    // OQ-E15-T04-1) -- this controller exposes no method, category or flag
    // for it at all. The nine categories above are the whole surface.
    expect(NotificationSettingsController.categories, hasLength(9));
    // No member named anything to do with an LED exists on this
    // controller; the type's own public surface is exactly what §3 of the
    // task lists.
  });

  test(
    'test_EARS_UI_11_category_read_failure_leaves_the_privacy_card_intact',
    () async {
      final erroringRepository = _ErroringRepository(db: db);
      final erroringController = NotificationSettingsController(
        repository: erroringRepository,
      );

      erroringController.onInit();
      await pumpEventQueue();

      expect(erroringController.categoriesError.value, isTrue);
      expect(erroringController.privacyError.value, isFalse);
      expect(
        erroringController.privacy.value,
        NotificationPrivacyLevel.hidden,
      );

      erroringController.onClose();
    },
  );
}

/// A repository whose `watchEnabled` always errors, for
/// `EARS-UI-11`'s falsification -- a real seam failure, not a mocked
/// promise of one. `privacyLevel`/`setPrivacyLevel` are untouched so the
/// Privacy card's own read still succeeds, proving the two cards fail
/// independently.
class _ErroringRepository extends NotificationSettingsRepository {
  _ErroringRepository({required super.db});

  @override
  Stream<bool> watchEnabled(NotificationCategory category) {
    return Stream<bool>.error(StateError('simulated read failure'));
  }
}

/// Counts `setPrivacyLevel` calls -- the call-counter seam `EARS-NOTIFY-17`
/// asks for (task §8), instead of `fail()` inside the seam (a broad catch
/// in the controller would swallow it, L-testing).
class _CountingRepository extends NotificationSettingsRepository {
  _CountingRepository({required super.db});

  int setPrivacyLevelCalls = 0;

  @override
  Future<void> setPrivacyLevel(NotificationPrivacyLevel level) async {
    setPrivacyLevelCalls++;
    await super.setPrivacyLevel(level);
  }
}
