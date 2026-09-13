// features/messaging/domain — Message entity (E05-T01).
//
// Immutable value object mirroring `messages` (lib/core/persistence
// /message_tables.dart) in domain terms. This task only defines the shape
// and the delivery-state machine that governs `deliveryState`'s legal
// transitions — no send/receive/transport/crypto wiring (that's T02/T03).
//
// `ciphertext` is opaque, already-encrypted bytes (E03 owns encryption) —
// per docs/conventions.md and this epic's own scope, this layer never
// decrypts or inspects it.
import 'dart:typed_data';

import 'delivery_state_machine.dart';

/// One message, in domain terms. Field-for-field mirror of the `messages`
/// Drift table (per epic.md's Data model / this task's §3):
/// - [id]: client-generated, stable, unique — FR-MSG-003/EARS-MSG-2 — lets a
///   duplicate packet be recognized and dropped by whoever receives it
///   (T03's job; this entity just carries the id).
/// - [sequenceNumber]: strictly increasing per `(conversationId,
///   senderDeviceId)`, assigned at compose time — offline, no live
///   transport required (FR-MSG-004/EARS-MSG-3, this task's §6 risk note).
///   Wall-clock time is NOT a substitute (clock drift across devices).
class Message {
  const Message({
    required this.id,
    required this.conversationId,
    required this.senderDeviceId,
    required this.sequenceNumber,
    required this.ciphertext,
    required this.createdAt,
    required this.deliveryState,
    this.plaintextPayload,
  });

  /// Client-generated, globally unique. Never server-assigned — this app
  /// has no server (ADR-0005).
  final String id;

  final String conversationId;

  final String senderDeviceId;

  /// Monotonic per `(conversationId, senderDeviceId)`. Assignable offline;
  /// the assignment algorithm itself is T02's job, not this entity's.
  final int sequenceNumber;

  /// Opaque, already-encrypted bytes. Never decrypted or inspected here.
  final Uint8List ciphertext;

  /// Epoch-ms wall-clock creation time. Used for keyset pagination
  /// (`WHERE created_at < :cursor ORDER BY created_at DESC LIMIT :n`, per
  /// docs/conventions.md) — never for logical ordering, which is
  /// [sequenceNumber]'s job.
  final int createdAt;

  final DeliveryState deliveryState;

  /// E04-B18: this message's already-decrypted `MessageEnvelope.payload`
  /// bytes, when known -- see `message_tables.dart`'s own doc comment for
  /// the full root-cause/security reasoning. `null` for a pre-fix row, or
  /// any row this entity was constructed for without that context (e.g. a
  /// group message, out of this fix's scope).
  final Uint8List? plaintextPayload;

  /// Returns a copy of this message with [deliveryState] replaced by
  /// [next], if [next] is a legal transition from the current state per
  /// [DeliveryStateMachine]. Throws [StateError] otherwise — this is the
  /// domain-level call site; nothing in `features/messaging` should set
  /// `deliveryState` any other way (this task's §3 contract).
  Message withDeliveryState(DeliveryState next) {
    final applied = DeliveryStateMachine.transition(deliveryState, next);
    return Message(
      id: id,
      conversationId: conversationId,
      senderDeviceId: senderDeviceId,
      sequenceNumber: sequenceNumber,
      ciphertext: ciphertext,
      createdAt: createdAt,
      deliveryState: applied,
      plaintextPayload: plaintextPayload,
    );
  }

  @override
  bool operator ==(Object other) =>
      other is Message &&
      other.id == id &&
      other.conversationId == conversationId &&
      other.senderDeviceId == senderDeviceId &&
      other.sequenceNumber == sequenceNumber &&
      _listEquals(other.ciphertext, ciphertext) &&
      other.createdAt == createdAt &&
      other.deliveryState == deliveryState &&
      _nullableListEquals(other.plaintextPayload, plaintextPayload);

  @override
  int get hashCode => Object.hash(
        id,
        conversationId,
        senderDeviceId,
        sequenceNumber,
        createdAt,
        deliveryState,
      );

  @override
  String toString() =>
      'Message(id: $id, conversationId: $conversationId, '
      'senderDeviceId: $senderDeviceId, sequenceNumber: $sequenceNumber, '
      'createdAt: $createdAt, deliveryState: $deliveryState)';
}

bool _listEquals(Uint8List a, Uint8List b) {
  if (identical(a, b)) return true;
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i] != b[i]) return false;
  }
  return true;
}

bool _nullableListEquals(Uint8List? a, Uint8List? b) {
  if (a == null || b == null) return a == b;
  return _listEquals(a, b);
}
