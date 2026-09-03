// core/messaging — the encrypted location-share wire protocol, control kind
// 7 (E09-T03).
//
// **Security posture (task file §2, the E06-B04 lesson, ADR-0003).** Every
// existing CLEARTEXT `PayloadType.control` sub-protocol (`PrekeyExchange`
// kind 1, `DeliveryAck` kind 2) trusts the outer relay frame's claimed
// originating device id at face value — a field any mesh node can set to
// anything (`RelayPacketFrame.source`, E06-B04's own finding). A location
// fix is exactly the kind of payload a forged sender identity could abuse —
// either to plant a fabricated position for a peer, or to make an
// unauthorized device's location fix look like it came from someone this
// device already trusts — so this sub-protocol follows `group_control.dart`
// (kind 3) / `call_signaling.dart` (kind 5)'s own pattern instead of
// `PrekeyExchange`/`DeliveryAck`'s cleartext one: a serialized
// [LocationShareFrame] always travels encrypted through the *pairwise*
// Double Ratchet session with the recipient (`CryptoService`, ADR-0003)
// before it ever reaches `TransportService`, and an inbound frame's claimed
// sender is trusted ONLY once `CryptoService.decrypt` has cryptographically
// proven which session produced it — never `RelayPacketFrame.source`
// directly (`location_share_service.dart`'s own header carries the receive-
// side half of this design).
//
// [encodeCiphertextControlBody]/[decodeCiphertextControlBody]
// (`group_control.dart`) are reused UNCHANGED — the same generic
// ciphertext-nesting codec, not re-implemented here (task file §4).
//
// This file does NOT decrypt, encrypt, evaluate the visibility gate, or
// touch the database — pure codec, no I/O (task file §4/§5), mirroring
// `relay_packet_frame.dart`/`group_control.dart`/`call_signaling.dart`'s own
// discipline: [LocationShareFrame] only serializes/deserializes bytes.
//
// Wire layout (task file §5, big-endian) — every field is fixed-width, so
// (unlike `GroupControlFrame`/`CallSignalingFrame`) there is no length
// prefix to bounds-check; the buffer's exact total length is the one thing
// [deserialize] verifies:
//
//   [u8  version]
//   [u8  kind]                 // explicit tag, see [_kindTags]; 1 = share
//   [i32 latitudeE7]           // decimal degrees x 1e7, signed
//   [i32 longitudeE7]          // decimal degrees x 1e7, signed
//   [u32 accuracyMmm]          // millimetres; 0xFFFFFFFF = "not reported" -> null
//   [u64 capturedAtMs]         // the SENDER's measurement time
//
// `E7` integer coordinates, not doubles, on purpose (task file §5): two
// devices must decode byte-identical positions, and an integer wire type
// negotiates no float-encoding ambiguity — the same "explicit tag, no
// heuristic" posture `CiphertextCodec`/`RelayPacketFrame` already hold.
import 'dart:typed_data';

import '../auth/google_auth_service.dart' show AppFailure;

/// The `controlKind` byte `InboundPipeline` dispatches on
/// (`inbound_pipeline.dart`'s keyed `Map<int, ControlHandler>`) — `1` is
/// `PrekeyExchange`'s, `2` is `DeliveryAckService`'s, `3` is
/// `GroupMembershipService`'s, `4` is `GroupCryptoService`'s, `5` is
/// `CallSignaling`'s, `6` is `SendGroupMessageUseCase`'s
/// (`kControlKindGroupMessage`, `group_message_envelope.dart`) — this task's
/// location-share sub-protocol takes the next unused value. Grepped against
/// every existing `kControlKind*` constant before being chosen (task file
/// §6 risk note); registered in `messaging_stack.dart` against
/// `LocationShareService.handleWireFrame`.
const int kControlKindLocationShare = 7;

/// Current, and so far only, [LocationShareFrame] wire layout version.
const int locationShareFrameVersion = 1;

/// Valid `latitudeE7` range: ±90 decimal degrees x 1e7 (task file §5).
const int _maxLatitudeE7 = 900000000;

/// Valid `longitudeE7` range: ±180 decimal degrees x 1e7 (task file §5).
const int _maxLongitudeE7 = 1800000000;

/// The explicit "accuracy not reported" sentinel — never `0`, which is a
/// genuine (if implausible) reported accuracy (task file §5).
const int _accuracyNotReportedSentinel = 0xFFFFFFFF;

/// The one kind this sub-protocol carries today. A closed enum (rather than
/// a bare `1`) so a second kind can be added later without renumbering —
/// matches `GroupEventKind`/`CallSignalKind`'s own "explicit tag map, never
/// declaration-order index" discipline.
enum LocationShareKind { share }

/// Explicit, stable wire tags for [LocationShareKind] — deliberately NOT the
/// enum's declaration-order index, matching `group_control.dart`'s /
/// `call_signaling.dart`'s own `_kindTags` discipline: the wire value must
/// survive this declaration being reordered.
const Map<LocationShareKind, int> _kindTags = {
  LocationShareKind.share: 1,
};

LocationShareKind _kindFromTag(int tag) {
  for (final entry in _kindTags.entries) {
    if (entry.value == tag) return entry.key;
  }
  throw const AppFailure('location.malformed_share');
}

/// The serialized location-share payload (task file §3/§5). Deterministic
/// fixed-width binary encoding — never JSON, matching every other control
/// sub-protocol in this codebase.
class LocationShareFrame {
  const LocationShareFrame({
    required this.latitudeE7,
    required this.longitudeE7,
    required this.capturedAtMs,
    this.accuracyMmm,
    this.kind = LocationShareKind.share,
    this.version = locationShareFrameVersion,
  });

  final int version;
  final LocationShareKind kind;

  /// Decimal degrees x 1e7. Valid range ±900 000 000 (task file §5).
  final int latitudeE7;

  /// Decimal degrees x 1e7. Valid range ±1 800 000 000 (task file §5).
  final int longitudeE7;

  /// Millimetres; `null` = the sender's [LocationSource] reported no
  /// accuracy — never encoded/decoded as `0` (task file §5).
  final int? accuracyMmm;

  /// The SENDER's measurement time, epoch ms (task file §2: "captured_at
  /// comes from the sender's frame").
  final int capturedAtMs;

  /// Fixed total length: version(1) + kind(1) + latitudeE7(4) +
  /// longitudeE7(4) + accuracyMmm(4) + capturedAtMs(8).
  static const int _frameLength = 1 + 1 + 4 + 4 + 4 + 8;

  /// Encodes this frame per the layout documented above. Round-trips
  /// exactly through [deserialize].
  Uint8List serialize() {
    _requireInRange(latitudeE7, _maxLatitudeE7, 'latitudeE7');
    _requireInRange(longitudeE7, _maxLongitudeE7, 'longitudeE7');

    final buffer = ByteData(_frameLength);
    var offset = 0;

    buffer.setUint8(offset, version);
    offset += 1;

    buffer.setUint8(offset, _kindTags[kind]!);
    offset += 1;

    buffer.setInt32(offset, latitudeE7);
    offset += 4;

    buffer.setInt32(offset, longitudeE7);
    offset += 4;

    buffer.setUint32(offset, accuracyMmm ?? _accuracyNotReportedSentinel);
    offset += 4;

    buffer.setUint64(offset, capturedAtMs);
    offset += 8;

    return buffer.buffer.asUint8List();
  }

  /// Decodes bytes produced by [serialize]. Throws
  /// `AppFailure('location.malformed_share')` on: a short buffer, a wrong
  /// version, an unknown kind tag, an out-of-range coordinate, or trailing
  /// bytes (task file §5). Never returns a partially-built frame.
  static LocationShareFrame deserialize(Uint8List bytes) {
    try {
      if (bytes.length != _frameLength) {
        // Every field here is fixed-width, so a buffer of the wrong total
        // length is malformed outright — this single check covers both
        // "too short" and "trailing bytes" (task file §5).
        throw const AppFailure('location.malformed_share');
      }
      final view = ByteData.sublistView(bytes);
      var offset = 0;

      final version = view.getUint8(offset);
      if (version != locationShareFrameVersion) {
        throw const AppFailure('location.malformed_share');
      }
      offset += 1;

      final kind = _kindFromTag(view.getUint8(offset));
      offset += 1;

      final latitudeE7 = view.getInt32(offset);
      offset += 4;
      _requireInRange(latitudeE7, _maxLatitudeE7, 'latitudeE7');

      final longitudeE7 = view.getInt32(offset);
      offset += 4;
      _requireInRange(longitudeE7, _maxLongitudeE7, 'longitudeE7');

      final rawAccuracy = view.getUint32(offset);
      offset += 4;
      final accuracyMmm =
          rawAccuracy == _accuracyNotReportedSentinel ? null : rawAccuracy;

      final capturedAtMs = view.getUint64(offset);
      offset += 8;

      return LocationShareFrame(
        version: version,
        kind: kind,
        latitudeE7: latitudeE7,
        longitudeE7: longitudeE7,
        accuracyMmm: accuracyMmm,
        capturedAtMs: capturedAtMs,
      );
    } on AppFailure {
      rethrow;
    } catch (_) {
      // Any other slicing/range failure collapses to the same typed
      // failure — never an uncaught RangeError escaping this codec.
      throw const AppFailure('location.malformed_share');
    }
  }

  static void _requireInRange(int value, int max, String field) {
    if (value < -max || value > max) {
      throw const AppFailure('location.malformed_share');
    }
  }
}
