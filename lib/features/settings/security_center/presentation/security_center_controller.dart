// features/settings/security_center/presentation -- SecurityCenterController
// (E15-T06). Loads the four sections from `SecurityRecordsRepository`; holds
// no write method of any kind and mutates no local defaulting rule (task §2
// -- this screen takes no action, `EARS-DIAG-5`).
//
// Each section's read failure is caught independently, exactly the same
// "one card's failure never touches another" shape `NotificationSettingsController`
// (`E15-T04`) already established for this Settings sub-screen family
// (task §5, `EARS-UI-11`).
import 'dart:async';

import 'package:get/get.dart';
import 'package:nexora/features/settings/security_center/data/security_records_repository.dart';

class SecurityCenterController extends GetxController {
  SecurityCenterController({required this.repository});

  final SecurityRecordsRepository repository;

  /// `null` until the first read completes -- the `loading` state (task
  /// §5: "frame and card headings render, lists unpopulated").
  final Rx<List<SecurityRecord>?> revocations = Rx<List<SecurityRecord>?>(
    null,
  );
  final RxBool revocationsError = false.obs;

  final Rx<List<SecurityRecord>?> trustedIdentities =
      Rx<List<SecurityRecord>?>(null);
  final RxBool trustedIdentitiesError = false.obs;

  final Rx<List<SecurityRecord>?> blockedPeers = Rx<List<SecurityRecord>?>(
    null,
  );
  final RxBool blockedPeersError = false.obs;

  final Rx<List<SecurityRecord>?> rateLimitDenials =
      Rx<List<SecurityRecord>?>(null);
  final RxBool rateLimitDenialsError = false.obs;

  @override
  void onInit() {
    super.onInit();
    unawaited(_loadRevocations());
    unawaited(_loadTrustedIdentities());
    unawaited(_loadBlockedPeers());
    unawaited(_loadRateLimitDenials());
  }

  Future<void> _loadRevocations() async {
    try {
      revocations.value = await repository.revocations();
    } catch (_) {
      revocationsError.value = true;
    }
  }

  Future<void> _loadTrustedIdentities() async {
    try {
      trustedIdentities.value = await repository.trustedIdentities();
    } catch (_) {
      trustedIdentitiesError.value = true;
    }
  }

  Future<void> _loadBlockedPeers() async {
    try {
      blockedPeers.value = await repository.blockedPeers();
    } catch (_) {
      blockedPeersError.value = true;
    }
  }

  Future<void> _loadRateLimitDenials() async {
    try {
      rateLimitDenials.value = await repository.rateLimitDenials();
    } catch (_) {
      rateLimitDenialsError.value = true;
    }
  }
}
