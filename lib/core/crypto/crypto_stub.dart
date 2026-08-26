// core/crypto — genesis structural stub (ADR-0003, Signal Protocol).
//
// Real X3DH/Double-Ratchet session and Sender-Keys group crypto are a
// feature epic's job. This exists only so the folder has an obvious,
// minimal seam for that work — "UI never touches plaintext directly"
// (ADR-0002 consequence) starts here.
class CryptoService {
  CryptoService._();
  static final CryptoService instance = CryptoService._();

  /// Placeholder — real session/ratchet setup lands in the crypto epic.
  Future<void> init() async {}
}
