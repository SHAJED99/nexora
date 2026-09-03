// core/notifications — the composition point every notification class
// (T03-T07) shares (E10-T03, task file §3): "One dispatcher, one seam" —
// every later source constructs a `NotificationFacts` and hands it to the
// same `NotificationPolicy`, and the registry below is the extension point
// those tasks use instead of editing this file's logic.
import 'dart:async';

import 'notification_policy.dart';
import 'notification_service.dart';

/// The extension point every notification producer implements: a stream of
/// [NotificationFacts], one per event the source recognises. `register()`ed
/// sources are the ONLY way a later task adds a notification class — this
/// dispatcher's own dispatch logic is never edited to add one.
abstract class NotificationSource {
  Stream<NotificationFacts> get facts;
}

/// Owns the [NotificationSink], the [NotificationPolicy], and the registry
/// of [NotificationSource]s (task file §3). `start()`/`stop()` are the
/// composition root's own calls (`bindings.dart`); `register()` is what
/// T04-T07 use to add a class without touching this file.
class NotificationDispatcher {
  NotificationDispatcher({
    required this.service,
    required this.policy,
  });

  final NotificationSink service;
  final NotificationPolicy policy;

  final List<StreamSubscription<NotificationFacts>> _subscriptions =
      <StreamSubscription<NotificationFacts>>[];

  bool _started = false;

  /// Adds [source] to the registry. Safe to call before or after [start] —
  /// a source registered before start is subscribed when start() runs; one
  /// registered afterward (a later task's composition-root edit landing
  /// after this dispatcher is already running) is subscribed immediately,
  /// so registration order relative to `start()` never silently drops a
  /// source.
  void register(NotificationSource source) {
    if (_started) {
      _subscribe(source);
    } else {
      _pending.add(source);
    }
  }

  final List<NotificationSource> _pending = <NotificationSource>[];

  /// Ensures the notification host is ready, then subscribes to every
  /// source registered so far. Idempotent — a second call is a no-op, so a
  /// hot restart or a doubled composition-root call never yields duplicate
  /// subscriptions per source (task file §6 risk).
  Future<void> start() async {
    if (_started) return;
    _started = true;

    await service.ensureReady();

    for (final source in _pending) {
      _subscribe(source);
    }
    _pending.clear();
  }

  void _subscribe(NotificationSource source) {
    _subscriptions.add(
      source.facts.listen(
        (facts) => unawaited(_handle(facts)),
        // A source's own stream erroring must not kill this subscription or
        // any other source's (task file §6 risk) — a broadcast stream's
        // subscription already survives an error event by default; this
        // handler exists only to swallow it rather than let it become an
        // unhandled async error, and it logs nothing (the event itself may
        // be a source-specific error type carrying no guaranteed-safe
        // fields to log).
        onError: (Object _, StackTrace _) {},
      ),
    );
  }

  /// Cancels every subscription. Safe to call twice (task file §5 contract).
  Future<void> stop() async {
    _started = false;
    for (final subscription in _subscriptions) {
      await subscription.cancel();
    }
    _subscriptions.clear();
  }

  /// Resolves and posts one event. Guarded per-event (task file §6 risk):
  /// an exception building or posting one notification must not stop every
  /// future notification from the same or any other source. Nothing derived
  /// from [facts] is logged — facts never carry plaintext to begin with.
  Future<void> _handle(NotificationFacts facts) async {
    try {
      final request = await policy.resolve(facts);
      if (request == null) return;
      await service.post(request);
    } catch (_) {
      // Swallowed by design — see method doc.
    }
  }
}
