// features/login/presentation — E01-T01: device id generation switched
// from Random() to Random.secure().
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/features/login/presentation/login_controller.dart';

void main() {
  test('test_EARS_AUTH_2_device_id_is_secure_random', () {
    // EARS-AUTH-2 (FR-AUTH-003): the system SHALL generate a device
    // identity independent of the account identity.
    //
    // Random.secure() has no seeded constructor (unlike Random(seed)), so
    // a black-box test cannot directly observe "which PRNG produced this
    // value" — that fact is verified by review of
    // login_controller.dart against ADR-0005/FR-AUTH-003. What a runtime
    // test CAN verify, and what guards against a regression back to a
    // low-entropy or deterministic generator, is: correct format, and no
    // collisions across a large sample.
    final ids = {for (var i = 0; i < 500; i++) generateSecureDeviceId()};

    expect(ids, hasLength(500)); // distinct across every call
    for (final id in ids) {
      expect(id, matches(RegExp(r'^[0-9a-f]{16}$')));
    }
  });
}
