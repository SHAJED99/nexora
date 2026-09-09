// features/settings/account/presentation -- AccountController (E15-T07,
// `FR-AUTH-013`). Renders AC1-AC17 against `design/screens/settings-account.md`
// (`GAP-035`): the signed-in account identifier, this device's own identity
// fingerprint, and the linked-device list. Holds no write method of any kind
// -- this screen takes no action of its own beyond AC14's navigation (task
// §4, "AC14 navigates. It does not sign out.").
//
// Three independent reads, each with its own failure isolation -- the same
// "one card's failure never touches another" shape `PrivacySettingsController`/
// `SecurityCenterController` already established for this Settings
// sub-screen family (task §5, `EARS-UI-11`):
//
// - [accountUid]/[accountError]: `DeviceIdentityRepository.latestDeviceIdentity()`
//   -- also the source of [thisDeviceId], needed to label AC13's own rows
//   ("This device" vs "Linked") without a second local read.
// - [deviceFingerprint]/[deviceError]: [readIdentityKeyPair] (an injected
//   seam -- production supplies `() => Get.find<MessagingStack>()
//   .signalStore.getIdentityKeyPair()`, the SAME call `login_controller.dart`'s
//   own `_deriveDeviceIdFromLocalIdentity` already uses) encoded through
//   `hexEncodeIdentityKey` (task §5 contract -- "not a second representation").
// - [linkedDevices]/[linkedDevicesLoaded]: `FirebaseMetadataService
//   .readOwnDeviceIds(uid)` -- best-effort by the service's own contract
//   (never throws; collapses any read failure to an empty set), so there is
//   no separate "linked devices failed to read" state to render: AC16
//   ("No other devices are linked to this account.") covers both a
//   genuinely empty list and a failed read alike, exactly as the design
//   contract's own `error` state note says ("the sign-out row is never
//   hidden by a failed read" -- true here even without a distinct error
//   flag, since this section degrades to its own empty state instead).
import 'dart:async';

import 'package:get/get.dart';
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/crypto/identity_key_hex.dart';
import 'package:nexora/core/services/firebase_metadata_service.dart';
import 'package:nexora/features/login/data/device_identity_repository.dart';

class AccountController extends GetxController {
  AccountController({
    required this.deviceIdentityRepository,
    required this.readIdentityKeyPair,
    FirebaseMetadataService? firebaseMetadataService,
  }) : _firebaseMetadataService =
           firebaseMetadataService ?? FirebaseMetadataService();

  final DeviceIdentityRepository deviceIdentityRepository;

  /// Injected seam for this device's own Signal identity keypair -- see
  /// file header. Never touches `AppDatabase`/`MessagingStack` directly from
  /// this class; the caller (this task's own binding, `E15-T11`) decides how
  /// to resolve it.
  final Future<IdentityKeyPair> Function() readIdentityKeyPair;

  final FirebaseMetadataService _firebaseMetadataService;

  /// AC6. `null` until the first read completes (the `loading` state, task
  /// §5: "values unpopulated", never a spinner) OR the read failed --
  /// [accountError] distinguishes the two so the view can tell "still
  /// loading" from "AC17's failure line applies here".
  final Rx<String?> accountUid = Rx<String?>(null);
  final RxBool accountError = false.obs;

  /// This device's own `deviceId` (from the SAME `latestDeviceIdentity()`
  /// row [accountUid] reads) -- needed to label AC13's rows, never rendered
  /// on its own (not part of this task's §5 function contract, but required
  /// to satisfy AC13's own "This device" / "Linked" state label without a
  /// second read).
  final Rx<String?> thisDeviceId = Rx<String?>(null);

  /// AC10. Same `null`-until-loaded-or-failed shape as [accountUid].
  final Rx<String?> deviceFingerprint = Rx<String?>(null);
  final RxBool deviceError = false.obs;

  /// AC13. Best-effort; see file header for why this has no separate error
  /// flag.
  final RxList<String> linkedDevices = <String>[].obs;

  /// `true` once the linked-devices read has completed (successfully or
  /// not) -- distinguishes the `loading` state (nothing rendered yet) from
  /// a genuinely empty, loaded list (AC16).
  final RxBool linkedDevicesLoaded = false.obs;

  @override
  void onInit() {
    super.onInit();
    unawaited(_loadAccount());
    unawaited(_loadDeviceFingerprint());
  }

  Future<void> _loadAccount() async {
    try {
      final identity = await deviceIdentityRepository.latestDeviceIdentity();
      thisDeviceId.value = identity?.deviceId;
      final uid = identity?.accountUid;
      if (uid == null) {
        accountError.value = true;
        linkedDevicesLoaded.value = true;
        return;
      }
      accountUid.value = uid;
      unawaited(_loadLinkedDevices(uid));
    } catch (_) {
      accountError.value = true;
      linkedDevicesLoaded.value = true;
    }
  }

  Future<void> _loadLinkedDevices(String uid) async {
    try {
      final ids = await _firebaseMetadataService.readOwnDeviceIds(uid);
      linkedDevices.assignAll(ids);
    } catch (_) {
      // Defensive only -- `readOwnDeviceIds` is documented never to throw
      // (best-effort, collapses failure to an empty set). A test double
      // that violates that contract still leaves this screen in the
      // ordinary empty state rather than crashing the read chain.
    } finally {
      linkedDevicesLoaded.value = true;
    }
  }

  Future<void> _loadDeviceFingerprint() async {
    try {
      final identityKeyPair = await readIdentityKeyPair();
      deviceFingerprint.value = hexEncodeIdentityKey(
        identityKeyPair.getPublicKey(),
      );
    } catch (_) {
      deviceError.value = true;
    }
  }
}
