// Pigeon schema — Dart<->Kotlin foreground-service boundary (ADR-0004,
// ADR-0007, FR-PLAT-001, FR-PLAT-002, FR-PLAT-003).
//
// This file is the source of truth for the generated bindings; never hand-
// edit `lib/core/background/generated/background_api.g.dart` or the
// generated Kotlin output — regenerate from here instead, same convention
// as Drift's `.g.dart` files (docs/conventions.md).
//
// Regenerate with:
//   dart run pigeon \
//     --input pigeons/background.dart \
//     --dart_out lib/core/background/generated/background_api.g.dart \
//     --kotlin_out android/app/src/main/kotlin/com/nexora/nexora/background/BackgroundApi.g.kt \
//     --kotlin_package com.nexora.nexora.background
//
// E10-T09 extends this same schema (task file §5) — kept extensible rather
// than final: no method here is written to assume it will never gain a
// sibling.
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/core/background/generated/background_api.g.dart',
    dartPackageName: 'nexora',
    kotlinOut:
        'android/app/src/main/kotlin/com/nexora/nexora/background/BackgroundApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.nexora.nexora.background'),
  ),
)

/// Lifecycle state of the Android foreground service that keeps the process
/// (and therefore `MessagingCoordinator`'s existing `Timer.periodic`, task
/// file §2/§4) alive and legal in the background.
enum ServiceState {
  stopped,
  starting,
  running,
  stoppedBySystem,
}

/// Host-side API: Dart calls into native Kotlin.
@HostApi()
abstract class BackgroundApi {
  /// Starts `ForegroundMeshService`. Returns `false` when the platform
  /// refused (missing permission, Android 12+ background-start
  /// restriction) — never throws for a refusal (task §5/§6).
  bool startService();

  /// Stops the service and removes its ongoing notification.
  void stopService();

  bool isServiceRunning();
}

/// Flutter-side API: native Kotlin calls into Dart.
@FlutterApi()
abstract class BackgroundEventsApi {
  void onServiceStateChanged(ServiceState state);
}
