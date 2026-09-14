// core/crypto — the decrypt/session-establishment exception taxonomy
// (E03-B03, closed here per E06-T02 — see that bug file's §Fix direction
// Option 1, and E06-T02.md §2's "E03-B03" bullet for why this task is where
// it lands).
//
// `crypto_stub.dart` is the only file allowed to import
// `package:libsignal_protocol_dart` exception types directly (it already
// does, to catch them). Every other caller in this codebase — and every
// future one in E06's T05 receive pipeline — matches on the types declared
// here instead, so the "does the caller need a safety-number warning or can
// it stay silent" decision is made once, in the taxonomy, rather than
// re-improvised at each `catch` site with a runtime-type-name string
// comparison (the workaround E03-B03 documented as already in
// `crypto_service_test.dart`).
//
// This file does NOT import `libsignal_protocol_dart` — [mapSignalException]
// takes `Object` precisely so it can match
// `InvalidMessageException` by its `runtimeType` name, since
// `libsignal_protocol_dart` 0.8.2's public barrel does not export
// `src/invalid_message_exception.dart` (E03-B03's repro) and importing the
// unexported path directly would be an `implementation_imports` lint
// violation. `NoSessionException`/`DuplicateMessageException`/
// `UntrustedIdentityException` ARE exported by the barrel, but this file
// still avoids importing the package at all, so `crypto_stub.dart` remains
// the single, reviewed seam where the library's exception surface is
// touched (E03-B03's stated goal).
library;

/// Why a decrypt or session-establishment call failed, translated from
/// whichever `libsignal_protocol_dart` exception (or, for [unknown], failure
/// of any other kind) actually occurred. Named `CryptoDecryptFailure`
/// per E06-T02.md §3/§5's contract even though `establishSession` also
/// throws it — both are "this crypto operation on this session failed"
/// failures, and giving them one type/one reason-enum keeps the taxonomy a
/// single seam rather than two nearly-identical ones.
enum CryptoDecryptFailureReason {
  /// The library reached the ratchet, derived a message key, and MAC
  /// verification failed — "the crypto ran and the key was wrong" (the
  /// commonest decrypt failure, and the one E03-B03 is about: the library's
  /// own `InvalidMessageException` is not exported from its public barrel,
  /// so this is the only way a caller can name this failure by type).
  invalidMessage,

  /// No Double Ratchet session exists yet for the given address —
  /// `NoSessionException` from the library, or `encrypt()`/`decrypt()`'s own
  /// precondition (still surfaced as a raw `StateError` from `encrypt()` —
  /// see `crypto_stub.dart`'s dartdoc — but as this reason from `decrypt()`
  /// and `establishSession()`).
  noSession,

  /// The remote party's identity key contradicts a previously-trusted one
  /// for this address — `UntrustedIdentityException`. This is the one
  /// reason a UI-facing caller MUST surface (a safety-number change), never
  /// swallow silently.
  untrustedIdentity,

  /// The message's ratchet counter has already been consumed — a replay,
  /// or (E03-T03's post-compromise-recovery tests) a message whose key
  /// material has already been used and discarded. `DuplicateMessageException`
  /// from the library.
  duplicateMessage,

  /// E04-B27: a `PreKeySignalMessage` names a one-time prekey this device no
  /// longer holds (`InvalidKeyIdException` from
  /// `DriftSignalProtocolStore.loadPreKey`). Each one-time prekey id is issued
  /// once (E03-B01/B02) and deleted when the first PreKey message using it is
  /// processed, so in practice this is the SAME session-establishing message
  /// re-delivered over another mesh path. A missing SIGNED prekey is a
  /// different fault and stays [unknown].
  consumedOneTimePreKey,

  /// Every other failure this seam can produce (e.g. the library's
  /// `InvalidKeyException`/`LegacyMessageException`, a missing signed
  /// prekey's `InvalidKeyIdException`,
  /// or anything not recognised at all). Never swallowed — [cause] always
  /// carries the original so a caller that needs more detail than the
  /// closed reason set still has it.
  unknown,
}

/// The one exception type every caller of `CryptoService.decrypt()` /
/// `CryptoService.establishSession()` needs to catch, distinguishing failure
/// modes **by type** (this class + [reason]) rather than by a
/// runtime-type-name string comparison against a library-internal class.
class CryptoDecryptFailure implements Exception {
  const CryptoDecryptFailure(this.reason, this.message, {this.cause});

  /// Which of the documented failure modes this is.
  final CryptoDecryptFailureReason reason;

  /// A greppable, non-secret description — never plaintext, key material or
  /// message content (`docs/conventions.md` "Error handling" /
  /// "Logging" — FR-DIAG-002).
  final String message;

  /// The original `libsignal_protocol_dart` exception (or any other
  /// original error), preserved so nothing is swallowed — never logged
  /// itself (it may carry the library's own detail message), only its type,
  /// per `docs/conventions.md`'s "Diagnostics ... log `code` + `cause`
  /// type — never message content".
  final Object? cause;

  @override
  String toString() =>
      'CryptoDecryptFailure(${reason.name}): $message'
      '${cause != null ? ' (cause: ${cause.runtimeType})' : ''}';
}

/// Translates whatever `libsignal_protocol_dart` (or anything else) threw
/// into a [CryptoDecryptFailure] with the right [CryptoDecryptFailureReason].
/// The one place this codebase matches the library's exception surface
/// (E03-B03) — every other `catch` site matches on [CryptoDecryptFailure]
/// instead.
///
/// Matches `NoSessionException`/`DuplicateMessageException`/
/// `UntrustedIdentityException` by `runtimeType` name (not `is`, since this
/// file deliberately does not import `libsignal_protocol_dart` — see the
/// file header) and `InvalidMessageException` the same way, since that one
/// is not even importable without an `implementation_imports` violation
/// (E03-B03's repro). Anything unrecognised maps to [CryptoDecryptFailureReason.unknown]
/// with [error] attached as `cause` — never swallowed.
CryptoDecryptFailure mapSignalException(Object error) {
  final typeName = error.runtimeType.toString();
  switch (typeName) {
    case 'InvalidMessageException':
      return CryptoDecryptFailure(
        CryptoDecryptFailureReason.invalidMessage,
        'message key failed MAC verification',
        cause: error,
      );
    case 'NoSessionException':
      return CryptoDecryptFailure(
        CryptoDecryptFailureReason.noSession,
        'no session established for this address',
        cause: error,
      );
    case 'DuplicateMessageException':
      return CryptoDecryptFailure(
        CryptoDecryptFailureReason.duplicateMessage,
        'message key already consumed (replay or already-decrypted message)',
        cause: error,
      );
    case 'UntrustedIdentityException':
      return CryptoDecryptFailure(
        CryptoDecryptFailureReason.untrustedIdentity,
        'remote identity key does not match the previously trusted one',
        cause: error,
      );
    // E04-B27: only the ONE-TIME prekey variant. The message text is written
    // by this codebase's own `DriftSignalProtocolStore.loadPreKey`
    // ("No such one-time prekey: <id>"); `loadSignedPreKey` throws the same
    // type with "No such signed prekey", which is a real fault and falls
    // through to `unknown`.
    case 'InvalidKeyIdException'
        when error.toString().contains('one-time prekey'):
      return CryptoDecryptFailure(
        CryptoDecryptFailureReason.consumedOneTimePreKey,
        'one-time prekey already consumed (a re-delivered session-establishing message)',
        cause: error,
      );
    default:
      return CryptoDecryptFailure(
        CryptoDecryptFailureReason.unknown,
        'unrecognised failure: $typeName',
        cause: error,
      );
  }
}
