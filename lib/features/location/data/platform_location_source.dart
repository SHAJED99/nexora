// features/location/data — the one concrete, real-device [LocationSource]
// (E09-T05, task file §3/§5). `E09-T03` defined the port and injected a
// permanent no-fix placeholder (`_UnavailableLocationSource` in
// `messaging_stack.dart`); this file is the real implementation that
// replaces it in the composition root.
//
// **Every platform seam is injected behind a narrow function type, never
// called as a static `Geolocator.*` global** (task file §5's own contract,
// matching `TransportService`'s `BinaryMessenger?` seam from E04-T03a) — the
// only way this class can be unit-tested without a device or a mocked
// platform channel.
//
// **Sequence (task file §2/§5/§8), in order:**
//   1. `isLocationServiceEnabled()` -- provider off -> `null` immediately,
//      no permission prompt.
//   2. `checkPermission()`; if `denied`, exactly one `requestPermission()`
//      call. `deniedForever`/`unableToDetermine`/still-`denied` -> `null`,
//      never a second request (task file §6: re-prompting a permanently
//      denied permission is a silent no-op that looks like a hang).
//   3. A CURRENT fix under the bounded [timeout] (`OQ-E09-T05-3`'s answer).
//      On timeout, exactly one fallback read of the platform's own
//      last-known position -- if that is also unavailable, `null`. Every
//      OTHER platform exception (not a timeout) resolves to `null` directly,
//      with no fallback attempt: `FR-LOC-005` staleness is measured from
//      `capturedAt`, so a fix this class was not actually asked to relax
//      into "last known" must not silently become one on a different
//      failure ('the timestamp tells the truth either way' -- OQ-E09-T05-3).
//
// Every path returns `null`, never throws (EARS-LOC-16) -- this class is the
// boundary where a platform's own permission/provider chaos becomes the one
// honest shape `LocationShareService` already knows how to handle.
//
// **Never logs a coordinate, or anything else, on any path** (E13
// `EARS-DIAG-1`, task file §2) -- this file has no logging calls at all.
library;

import 'dart:async';

import 'package:geolocator/geolocator.dart';

import '../domain/location_source.dart';

/// Checks whether the device's location provider (GPS/network) is turned on
/// at all -- independent of whether this app holds the runtime permission.
typedef LocationServiceEnabledFn = Future<bool> Function();

/// Reads the app's current location-permission grant without prompting.
typedef LocationPermissionCheckFn = Future<LocationPermission> Function();

/// Shows the OS permission dialog exactly once and returns the outcome.
typedef LocationPermissionRequestFn = Future<LocationPermission> Function();

/// Requests a fresh position reading. [timeout] is passed through so a real
/// implementation can also configure the platform's own timeout (defence in
/// depth alongside this class's own `Future.timeout` wrapper) -- a test seam
/// is free to ignore it.
typedef CurrentPositionFn = Future<Position> Function(Duration timeout);

/// Reads the platform's own cached last-known position, or `null` if it has
/// none.
typedef LastKnownPositionFn = Future<Position?> Function();

/// The one concrete [LocationSource] in production (task file §5's Functions
/// contract). Android only for this task (`OQ-E09-T05-1`).
class PlatformLocationSource implements LocationSource {
  PlatformLocationSource({
    this.timeout = const Duration(seconds: 10),
    LocationServiceEnabledFn? isLocationServiceEnabled,
    LocationPermissionCheckFn? checkPermission,
    LocationPermissionRequestFn? requestPermission,
    CurrentPositionFn? currentPosition,
    LastKnownPositionFn? lastKnownPosition,
  })  : _isLocationServiceEnabled =
            isLocationServiceEnabled ?? Geolocator.isLocationServiceEnabled,
        _checkPermission = checkPermission ?? Geolocator.checkPermission,
        _requestPermission = requestPermission ?? Geolocator.requestPermission,
        _currentPosition = currentPosition ?? _defaultCurrentPosition,
        _lastKnownPosition =
            lastKnownPosition ?? Geolocator.getLastKnownPosition;

  /// Bounded acquisition window (task file §2/§5): `currentFix()` never
  /// waits longer than this for a fresh fix before falling back to the
  /// platform's last-known position.
  final Duration timeout;

  final LocationServiceEnabledFn _isLocationServiceEnabled;
  final LocationPermissionCheckFn _checkPermission;
  final LocationPermissionRequestFn _requestPermission;
  final CurrentPositionFn _currentPosition;
  final LastKnownPositionFn _lastKnownPosition;

  static Future<Position> _defaultCurrentPosition(Duration timeout) {
    return Geolocator.getCurrentPosition(
      locationSettings: LocationSettings(timeLimit: timeout),
    );
  }

  @override
  Future<LocationFix?> currentFix() async {
    try {
      final serviceEnabled = await _isLocationServiceEnabled();
      if (!serviceEnabled) {
        return null;
      }

      var permission = await _checkPermission();
      if (permission == LocationPermission.denied) {
        // Lazy-at-first-approved-use (task file §2): this is the ONLY call
        // site in the app that can ever trigger the OS permission dialog,
        // and it is reached only after `LocationShareService.share` has
        // already evaluated `LocationVisibilityPolicy` in this device's
        // favour (EARS-LOC-17).
        permission = await _requestPermission();
      }
      if (permission != LocationPermission.whileInUse &&
          permission != LocationPermission.always) {
        // `denied` (still, after one request), `deniedForever`, or
        // `unableToDetermine` -- no second request attempted (task file §6).
        return null;
      }

      try {
        final position = await _currentPosition(timeout).timeout(timeout);
        return _toFix(position);
      } on TimeoutException {
        final lastKnown = await _lastKnownPosition();
        return lastKnown == null ? null : _toFix(lastKnown);
      }
    } catch (_) {
      // Any other platform failure (a provider error, a permission race
      // between the checks above and the read itself, ...) collapses to the
      // same honest no-fix outcome (EARS-LOC-16) -- never rethrown, never
      // logged (this file's header).
      return null;
    }
  }

  LocationFix _toFix(Position position) => LocationFix(
        latitude: position.latitude,
        longitude: position.longitude,
        accuracyM: position.accuracy,
        // Explicit epoch-ms conversion (task file §6 risk: a provider's
        // underlying clock value could in principle not be wall-clock epoch
        // on some APIs). `Position.timestamp` is a `DateTime`, converted
        // through `millisecondsSinceEpoch` here -- the one place a
        // `Position` becomes a `LocationFix` -- rather than trusted
        // implicitly at each of this class's several call sites.
        capturedAtMs: position.timestamp.millisecondsSinceEpoch,
      );
}
