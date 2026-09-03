// core/notifications — Dart-idiomatic facade over the Pigeon-generated
// NotificationApi/NotificationEventsApi boundary (ADR-0004, FR-PLAT-003,
// FR-NOTIFY-001).
//
// This is what T03-T08's notification sources call; nobody outside this
// file talks to `generated/notification_api.g.dart` directly. Mirrors
// `core/transport/transport_service.dart`'s shape deliberately (same
// native-behind-Pigeon pattern, E04-T03a).
//
// Does NOT decide *when* anything is notified, does NOT read/write user
// preferences, and does NOT wire into any use case — see the task's own §4.
import 'dart:async';

import 'package:flutter/services.dart';

import 'generated/notification_api.g.dart';

export 'generated/notification_api.g.dart'
    show NotificationCategory, NotificationRequest;

/// The shape every E10 notification source (T03-T08) depends on — shared by
/// the real [NotificationService] and the in-memory [NotificationStub]
/// (`notification_stub.dart`) so downstream code can be built and tested
/// against the stub without any Pigeon/platform-channel wiring, then run
/// unchanged against the real service.
abstract class NotificationSink {
  Future<bool> ensureReady();
  Future<bool> post(NotificationRequest request);
  Future<void> cancel(int id);
}

/// Dart-idiomatic facade over the generated `NotificationApi` (host calls)
/// and `NotificationEventsApi` (native -> Dart events).
class NotificationService implements NotificationSink {
  /// [binaryMessenger] and [messageChannelSuffix] exist to let tests run
  /// multiple independent instances against mocked platform channels
  /// without one instance's registered handler clobbering another's — same
  /// pattern as `TransportService`.
  NotificationService({
    BinaryMessenger? binaryMessenger,
    String messageChannelSuffix = '',
  })  : _api = NotificationApi(
          binaryMessenger: binaryMessenger,
          messageChannelSuffix: messageChannelSuffix,
        ) {
    NotificationEventsApi.setUp(
      _EventsHandler(this),
      binaryMessenger: binaryMessenger,
      messageChannelSuffix: messageChannelSuffix,
    );
  }

  final NotificationApi _api;

  final StreamController<bool> _permissionResultController =
      StreamController<bool>.broadcast();
  final StreamController<_NotificationTappedEvent> _tappedController =
      StreamController<_NotificationTappedEvent>.broadcast();

  /// Fired once the runtime permission prompt resolves.
  Stream<bool> get permissionResults => _permissionResultController.stream;

  /// Fired when the user taps a posted notification. Delivered and
  /// otherwise unconsumed as of E10-T01 (`OQ-E10-T01-1`).
  Stream<int> get notificationTapped =>
      _tappedController.stream.map((_NotificationTappedEvent e) => e.id);

  /// One call a composition root can await before the first post: ensures
  /// the notification channels exist, and — if permission is not already
  /// granted — requests it and awaits the result. Returns true when channels
  /// exist and permission is granted; false when denied. EARS-PLAT-5,
  /// EARS-PLAT-6.
  @override
  Future<bool> ensureReady() async {
    await _api.ensureChannels();
    if (await _api.hasPermission()) return true;

    final Future<bool> resultFuture = permissionResults.first;
    await _api.requestPermission();
    return resultFuture;
  }

  /// The single seam every notification source in E10 posts through.
  /// Returns false — never throws — when the host refused (no permission).
  @override
  Future<bool> post(NotificationRequest request) => _api.post(request);

  /// Withdraws a posted notification (used by T04's call notice and T08's
  /// service notice).
  @override
  Future<void> cancel(int id) => _api.cancel(id);

  void _handlePermissionResult(bool granted) =>
      _permissionResultController.add(granted);

  void _handleNotificationTapped(int id, NotificationCategory category) =>
      _tappedController.add(_NotificationTappedEvent(id, category));

  /// Releases the stream controllers. Does not tear down the Pigeon
  /// `NotificationEventsApi` handler registration — same caveat as
  /// `TransportService.dispose`: callers that create throwaway instances
  /// (e.g. tests) should pass a distinct `messageChannelSuffix` per instance.
  Future<void> dispose() async {
    await _permissionResultController.close();
    await _tappedController.close();
  }
}

class _NotificationTappedEvent {
  _NotificationTappedEvent(this.id, this.category);
  final int id;
  final NotificationCategory category;
}

class _EventsHandler extends NotificationEventsApi {
  _EventsHandler(this._service);
  final NotificationService _service;

  @override
  void onPermissionResult(bool granted) =>
      _service._handlePermissionResult(granted);

  @override
  void onNotificationTapped(int id, NotificationCategory category) =>
      _service._handleNotificationTapped(id, category);
}
