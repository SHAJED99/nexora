// Tests for LocationShareFrame (E09-T03, task file §5/§8). Pure codec round
// trip, no I/O, no database, no crypto -- mirrors
// `group_control_test.dart`/`call_signaling_test.dart`'s own "malformed
// input, never a partial frame" scrutiny for a hand-rolled binary decoder.
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/auth/google_auth_service.dart' show AppFailure;
import 'package:nexora/core/messaging/location_share.dart';

void main() {
  LocationShareFrame frame({
    int latitudeE7 = 407128000, // ~40.7128 (NYC)
    int longitudeE7 = -740060000, // ~-74.0060
    int? accuracyMmm,
    int capturedAtMs = 1_700_000_000_000,
  }) =>
      LocationShareFrame(
        latitudeE7: latitudeE7,
        longitudeE7: longitudeE7,
        accuracyMmm: accuracyMmm,
        capturedAtMs: capturedAtMs,
      );

  group('round trip', () {
    test('round trip preserves every field, including accuracy', () {
      final original = frame(accuracyMmm: 5123);
      final decoded = LocationShareFrame.deserialize(original.serialize());

      expect(decoded.version, locationShareFrameVersion);
      expect(decoded.kind, LocationShareKind.share);
      expect(decoded.latitudeE7, original.latitudeE7);
      expect(decoded.longitudeE7, original.longitudeE7);
      expect(decoded.accuracyMmm, 5123);
      expect(decoded.capturedAtMs, original.capturedAtMs);
    });

    test(
        'test_accuracy_sentinel_0xFFFFFFFF_decodes_to_null_never_zero',
        () {
      final original = frame(accuracyMmm: null);
      final decoded = LocationShareFrame.deserialize(original.serialize());

      expect(decoded.accuracyMmm, isNull);
      expect(decoded.accuracyMmm, isNot(0));
    });

    test('boundary coordinates round-trip exactly (max positive)', () {
      final original = frame(latitudeE7: 900000000, longitudeE7: 1800000000);
      final decoded = LocationShareFrame.deserialize(original.serialize());
      expect(decoded.latitudeE7, 900000000);
      expect(decoded.longitudeE7, 1800000000);
    });

    test('boundary coordinates round-trip exactly (max negative)', () {
      final original =
          frame(latitudeE7: -900000000, longitudeE7: -1800000000);
      final decoded = LocationShareFrame.deserialize(original.serialize());
      expect(decoded.latitudeE7, -900000000);
      expect(decoded.longitudeE7, -1800000000);
    });
  });

  group('malformed rejection', () {
    test('short buffer is rejected', () {
      expect(
        () => LocationShareFrame.deserialize(Uint8List(5)),
        throwsA(isA<AppFailure>()),
      );
    });

    test('empty buffer is rejected', () {
      expect(
        () => LocationShareFrame.deserialize(Uint8List(0)),
        throwsA(isA<AppFailure>()),
      );
    });

    test('wrong version is rejected', () {
      final bytes = frame().serialize();
      bytes[0] = locationShareFrameVersion + 1;
      expect(
        () => LocationShareFrame.deserialize(bytes),
        throwsA(isA<AppFailure>()),
      );
    });

    test('unknown kind tag is rejected', () {
      final bytes = frame().serialize();
      bytes[1] = 99;
      expect(
        () => LocationShareFrame.deserialize(bytes),
        throwsA(isA<AppFailure>()),
      );
    });

    test('out-of-range latitude is rejected', () {
      final buffer = frame().serialize();
      ByteData.sublistView(buffer).setInt32(2, 900000001); // just past +90
      expect(
        () => LocationShareFrame.deserialize(buffer),
        throwsA(isA<AppFailure>()),
      );
    });

    test('out-of-range longitude is rejected', () {
      final buffer = frame().serialize();
      final view = ByteData.sublistView(buffer);
      view.setInt32(6, -1800000001); // just past -180 degrees
      expect(
        () => LocationShareFrame.deserialize(buffer),
        throwsA(isA<AppFailure>()),
      );
    });

    test('trailing bytes are rejected', () {
      final original = frame().serialize();
      final withTrailing = Uint8List(original.length + 1)
        ..setRange(0, original.length, original);
      expect(
        () => LocationShareFrame.deserialize(withTrailing),
        throwsA(isA<AppFailure>()),
      );
    });
  });
}
