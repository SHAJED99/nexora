// core/messaging — the one place the app re-creates its `MessagingStack`
// when a local device identity arrives mid-session (E01-B01, findings 2+3;
// human decision 2026-09-25, option (a)).
//
// WHY A RE-CREATE AND NOT A MUTABLE `selfDeviceId`:
// `MessagingStack.create` captures `selfDeviceId` into eight collaborators
// at construction -- `RoutingEngine`, `RelayEngine`, the inbound pipeline
// (twice), and four repositories/services. None of them re-reads it. Making
// that id observable would reach into the crypto/routing core, which is a
// rule-3 architecture change and was explicitly excluded by the human's
// 2026-09-25 decision: "Do not make `selfDeviceId` mutable/observable
// throughout RoutingEngine, RelayEngine, inbound processing, repositories,
// or crypto/routing core."
//
// WHY THE STATUS IS OBSERVED SEPARATELY FROM THE STACK:
// `MessagingStackStatus` is a sealed immutable value and the stack is
// registered `permanent: true`, so nothing could ever notice it change.
// That is the whole of findings 2+3: `main.dart` reads the identity ONCE at
// launch, a fresh sign-in writes it moments later, and the screens keep the
// error they computed in `onInit` until a force-stop. [status] below is the
// observable the screens bind to instead.
//
// THE INVARIANT THIS FILE EXISTS TO HOLD:
// [status] must NEVER report ready while the registered stack still carries
// the empty identity. Every write to it below comes from a stack that was
// just constructed with a real device id -- never from the old one, and
// never optimistically ahead of a successful re-create.
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/observability/observability_service.dart';
import 'package:nexora/core/persistence/database.dart';

/// The stack factory, injected so a test never stands up the real one.
typedef CreateMessagingStack = Future<MessagingStack> Function({
  required AppDatabase db,
  required String selfDeviceId,
});

class MessagingReadiness {
  MessagingReadiness({
    required MessagingStackStatus initialStatus,
    CreateMessagingStack? createStack,
  })  : status = initialStatus.obs,
        _createStack = createStack ?? MessagingStack.create;

  /// What the screens bind to. Seeded from the launch-time stack.
  final Rx<MessagingStackStatus> status;

  final CreateMessagingStack _createStack;

  /// True once the unavailable -> available transition has been handled.
  /// The transition happens at most once per process: a device either had
  /// an identity at launch (nothing to do) or acquires one exactly once,
  /// when it first signs in.
  bool _handled = false;

  @visibleForTesting
  bool get handled => _handled;

  /// Guards against a second concurrent call while the first is still
  /// awaiting `create` -- `_handled` alone is set too late for that.
  Future<void>? _inFlight;

  /// Called when a local device identity has just been persisted.
  ///
  /// Idempotent and single-shot by construction: a second call, a
  /// concurrent call, an empty [deviceId], or a stack that already carries
  /// [deviceId] all return without creating anything.
  Future<void> onLocalIdentityProvisioned(String deviceId) {
    final inFlight = _inFlight;
    if (inFlight != null) {
      return inFlight;
    }
    final future = _handle(deviceId);
    _inFlight = future;
    return future.whenComplete(() => _inFlight = null);
  }

  Future<void> _handle(String deviceId) async {
    if (_handled || deviceId.isEmpty) {
      return;
    }
    final existing = Get.isRegistered<MessagingStack>()
        ? Get.find<MessagingStack>()
        : null;
    if (existing == null) {
      return;
    }
    if (existing.selfDeviceId == deviceId) {
      // Already correct -- this device had its identity at launch. Publish
      // the stack's real status and stop; re-creating a correct stack would
      // tear down live subscriptions for nothing.
      _handled = true;
      status.value = existing.status;
      return;
    }

    // The precedent, unchanged: `settings_binding.dart` disposes the stack
    // and force-deletes the registration before anything replaces it.
    try {
      await existing.dispose();
    } catch (e) {
      // A failed dispose must not strand the app on the old stack; it is
      // logged and the replacement proceeds.
      ObservabilityService.instance.logError(
        'session.stack_dispose_failed',
        cause: e,
      );
    }
    Get.delete<MessagingStack>(force: true);

    try {
      final replacement = await _createStack(
        db: existing.db,
        selfDeviceId: deviceId,
      );
      Get.put<MessagingStack>(replacement, permanent: true);
      // The ONLY write that can publish `ready`, and it reads the status of
      // the stack that was just built with the real id.
      status.value = replacement.status;
      _handled = true;
    } catch (e) {
      ObservabilityService.instance.logError(
        'session.stack_recreate_failed',
        cause: e,
      );
      // Deliberately NOT marked handled: the identity is still there, so a
      // later trigger may retry. `status` is left reporting unavailable --
      // never optimistically ready against a stack that does not exist.
      status.value = const MessagingStackStatus.unavailable(
        'messaging could not be started after sign-in',
      );
    }
  }
}
