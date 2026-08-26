// core/transport — genesis structural stub (ADR-0004, Pigeon).
//
// Real Bluetooth/Wi-Fi Direct/Nearby transport is Pigeon-generated
// Dart<->Kotlin bindings, built by a feature epic. Pigeon schemas live in
// `pigeons/` at repo root; generated output goes to
// `lib/core/transport/generated/` — neither exists yet, on purpose, until
// the first transport epic defines a schema.
class TransportService {
  TransportService._();
  static final TransportService instance = TransportService._();

  /// Placeholder — no real Bluetooth/WiFi/Pigeon wiring in genesis.
  Future<void> init() async {}
}
