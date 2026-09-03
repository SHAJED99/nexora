// core/notifications — in-memory NotificationService double (E10-T01).
//
// This is what every downstream notification task (T03-T08) tests against;
// without it those tasks would be as unrunnable-without-hardware as
// E04-T03b/c. Implements the same `NotificationSink` shape as the real
// `NotificationService` (`notification_service.dart`) so a caller built
// against this stub runs unchanged against the real Pigeon-backed service.
import 'notification_service.dart';

/// An in-memory [NotificationSink] that records every accepted `post()`
/// call and never touches a platform channel. Configure [permissionGranted]
/// to simulate a denied `POST_NOTIFICATIONS` permission (EARS-PLAT-6): while
/// false, `post()` resolves `false` and records nothing, mirroring the real
/// host's contract of never throwing for a denial.
class NotificationStub implements NotificationSink {
  NotificationStub({this.permissionGranted = true});

  /// Whether the simulated permission state allows posting. Mutable so a
  /// single test can flip it mid-run (e.g. simulate the user granting
  /// permission after an initial denial).
  bool permissionGranted;

  /// Every request accepted by [post], in call order. Test doubles'
  /// recording surface — downstream tasks assert against this rather than
  /// against any native side effect.
  final List<NotificationRequest> posted = <NotificationRequest>[];

  /// Ids withdrawn via [cancel], in call order.
  final List<int> cancelled = <int>[];

  /// Count of [ensureReady] calls — lets a test assert channel setup
  /// happened exactly once per attach without a native channel to inspect.
  int ensureReadyCallCount = 0;

  @override
  Future<bool> ensureReady() async {
    ensureReadyCallCount++;
    return permissionGranted;
  }

  @override
  Future<bool> post(NotificationRequest request) async {
    if (!permissionGranted) return false;
    posted.add(request);
    return true;
  }

  @override
  Future<void> cancel(int id) async {
    cancelled.add(id);
  }
}
