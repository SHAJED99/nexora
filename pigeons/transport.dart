// Pigeon schema — Dart<->Kotlin transport boundary (ADR-0004, FR-PLAT-003).
//
// This file is the source of truth for the generated bindings; never hand-
// edit `lib/core/transport/generated/transport_api.g.dart` or the generated
// Kotlin output — regenerate from here instead, same convention as Drift's
// `.g.dart` files (docs/conventions.md).
//
// Regenerate with:
//   dart run pigeon \
//     --input pigeons/transport.dart \
//     --dart_out lib/core/transport/generated/transport_api.g.dart \
//     --kotlin_out android/app/src/main/kotlin/com/nexora/nexora/transport/TransportApi.g.kt \
//     --kotlin_package com.nexora.nexora.transport
import 'package:pigeon/pigeon.dart';

@ConfigurePigeon(
  PigeonOptions(
    dartOut: 'lib/core/transport/generated/transport_api.g.dart',
    dartPackageName: 'nexora',
    kotlinOut:
        'android/app/src/main/kotlin/com/nexora/nexora/transport/TransportApi.g.kt',
    kotlinOptions: KotlinOptions(package: 'com.nexora.nexora.transport'),
  ),
)

/// The physical/logical carrier a `TransportDevice` was discovered or
/// connected over. Bluetooth is the only carrier a real implementation
/// exists for (T03b/T03c); `wifiDirect`/`internet` are named here because
/// they are part of the shape every future transport must fit (ADR-0004),
/// not because either is implemented.
enum TransportType {
  bluetooth,
  wifiDirect,
  internet,
}

/// A device/peer as seen by the native transport layer, before any app-level
/// identity/session concept is layered on top (that's `core/auth`,
/// ADR-0005 — out of scope here).
class TransportDevice {
  TransportDevice({
    required this.id,
    required this.displayName,
    required this.type,
  });

  final String id;
  final String displayName;
  final TransportType type;
}

/// Lifecycle state of a connection to a given device id.
enum ConnectionState {
  connecting,
  connected,
  disconnected,
  failed,
}

/// Host-side API: Dart calls into native Kotlin.
@HostApi()
abstract class TransportApi {
  void startDiscovery();

  void stopDiscovery();

  bool connect(String deviceId);

  void disconnect(String deviceId);

  bool send(String deviceId, Uint8List bytes);
}

/// Flutter-side API: native Kotlin calls into Dart.
@FlutterApi()
abstract class TransportEventsApi {
  void onDeviceDiscovered(TransportDevice device);

  void onDeviceLost(String deviceId);

  void onConnectionStateChanged(String deviceId, ConnectionState state);

  void onDataReceived(String deviceId, Uint8List bytes);
}
