// features/location/domain — this device's own position, and the port that
// produces it (E09-T03, task file §3).
//
// [LocationFix] is distinct from `LocationFixRow` (E09-T01's Drift row,
// which is a *peer's* stored fix) on purpose: this one has no
// `peerDeviceId` and no `receivedAt`, because neither exists until the fix
// is sent and received.
//
// [LocationSource] is the abstract port a real device implementation plugs
// into. **This task defines the port and injects it; it does not implement
// a real one** (task file §4) — acquiring a real fix needs a new dependency
// (`geolocator` or similar) and a new runtime permission, both rule-3 human
// calls that belong to `E09-T05`. The only concrete implementation in this
// task is a test fake.
library;

/// This device's own measured position at the moment [LocationSource
/// .currentFix] was called.
class LocationFix {
  const LocationFix({
    required this.latitude,
    required this.longitude,
    required this.capturedAtMs,
    this.accuracyM,
  });

  /// Decimal degrees, WGS84.
  final double latitude;

  /// Decimal degrees, WGS84.
  final double longitude;

  /// Metres; `null` = the provider reported none — never `0` (task file
  /// §5).
  final double? accuracyM;

  /// The provider's own measurement time, epoch ms.
  final int capturedAtMs;
}

/// The port `E09-T05` implements against a real device location provider.
/// Here, only a test fake implements it.
abstract class LocationSource {
  /// Returns this device's current position, or `null` when no fix is
  /// available (permission denied, no provider, timeout). Never throws for
  /// the ordinary no-fix case.
  Future<LocationFix?> currentFix();
}
