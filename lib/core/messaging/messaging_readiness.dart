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
import 'package:nexora/app/bindings.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/transport/transport_service.dart';

/// The stack factory, injected so a test never stands up the real one.
/// `transport` is part of this signature deliberately. The replacement stack
/// MUST be handed the ORIGINAL `TransportService`: `MessagingStack.create`
/// otherwise builds a second one with the same (empty) `messageChannelSuffix`,
/// whose constructor calls `TransportEventsApi.setUp` again and silently
/// steals every native transport-channel handler the first one owns — the
/// exact failure `bindings.dart`'s own E06-B02 note names.
typedef CreateMessagingStack = Future<MessagingStack> Function({
  required AppDatabase db,
  required String selfDeviceId,
  TransportService? transport,
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

    // **NOT `existing.dispose()`.** That is sign-OUT's teardown
    // (`settings_binding.dart:119-121`) and it closes `db` — the single
    // app-wide `AppDatabase` every other feature shares — and disposes the
    // transport. Reusing it here was this fix's first draft and it was
    // wrong: the replacement was then handed an already-closed database
    // ("Bad state: Can't re-open a database after closing it"), which
    // `MessagingStack.create` swallows into an `unavailable` status rather
    // than throwing, so the failure looked like success. Caught in review,
    // reproduced against a real Drift database.
    //
    // A mid-session identity arrival is not a sign-out. Only the old
    // stack's own work is stopped; `db` and `transport` are inherited.
    try {
      await existing.coordinator.stop();
    } catch (e) {
      ObservabilityService.instance.logError(
        'session.stack_coordinator_stop_failed',
        cause: e,
      );
    }
    Get.delete<MessagingStack>(force: true);

    try {
      final replacement = await _createStack(
        db: existing.db,
        selfDeviceId: deviceId,
        transport: existing.transport,
      );
      Get.put<MessagingStack>(replacement, permanent: true);

      // Five of the stack's collaborators capture `selfDeviceId` at
      // construction and `AppBinding` registered them as their own
      // permanent singletons. Replacing only the `MessagingStack`
      // registration would leave `Get.find<SendMessageUseCase>()` still
      // addressed from the empty id — an app that looks fixed and cannot
      // send, which is the outcome option (a) was chosen to avoid.
      // `blockCommunication: false` is correct here, and the reason is an
      // invariant worth writing down rather than leaving to be rediscovered
      // (review round 2, S4). `AppBinding.blockCommunication` is fixed once
      // at launch from `VersionState.updateRequired`; when it is true,
      // `main.dart` routes straight to the mandatory-update screen and
      // `VersionReconnectWatcher` only pushes further INTO it. So
      // `LoginController._signIn` -- the only caller that reaches this code
      // -- can never run while communication is blocked.
      //
      // If a future task ever adds another route to sign-in, this line is
      // the one that has to be revisited: it would start communication on a
      // device the version gate had deliberately silenced.
      registerStackDerivedSingletons(
        replacement,
        blockCommunication: false,
      );

      status.value = replacement.status;
      // Latched ONLY on a genuinely ready stack. A replacement that came
      // back `unavailable` is not a handled transition — the first draft
      // latched regardless, which permanently gave up after a failure it
      // had not noticed.
      _handled = replacement.status.isReady;
      if (!_handled) {
        ObservabilityService.instance.logError(
          'session.stack_recreate_not_ready',
          cause: StateError(replacement.status.toString()),
        );
      }
    } catch (e) {
      ObservabilityService.instance.logError(
        'session.stack_recreate_failed',
        cause: e,
      );
      // Deliberately NOT marked handled: the identity is still there, so a
      // later trigger may retry. `status` is left reporting unavailable —
      // never optimistically ready against a stack that does not exist.
      status.value = const MessagingStackStatus.unavailable(
        'messaging could not be started after sign-in',
      );
    }
  }
}
