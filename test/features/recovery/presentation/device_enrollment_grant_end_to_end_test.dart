// features/recovery/presentation + features/devices/presentation —
// E12-B02/E12-B03 end-to-end regression proof.
//
// The bug sweep found two INDEPENDENT S1 defects that together made the
// whole enrollment-approval journey non-functional, even though each half's
// own task suite was green (each mocked the other side):
//   - E12-B02: the approving device's `DevicesController.verify()` never
//     reached Firebase at all -- `RelationshipSyncService.push` had zero
//     production callers.
//   - E12-B03: even with a write, `DeviceEnrollmentController.checkApproval`
//     went through `RelationshipSyncService.pull`/`ConflictResolver
//     .resolveTrust`, which can never RAISE trust for a device with no
//     local relationship row -- the approval was silently discarded.
//
// This test composes the REAL `DevicesController.verify()` (the write
// side) and the REAL `DeviceEnrollmentController.checkApproval()` (the
// read side) over one shared, in-memory stand-in for the dedicated
// `users/$uid/device_enrollment_grants/$newDeviceId` node -- proving the
// approval actually crosses from one device's controller to the other's,
// which neither task's own isolated test suite could ever observe.
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/services/firebase_metadata_service.dart';
import 'package:nexora/core/transport/generated/transport_api.g.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/devices/presentation/devices_controller.dart';
import 'package:nexora/features/recovery/presentation/device_enrollment_controller.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/block_use_case.dart';
import 'package:nexora/features/trust/domain/evaluate_connection_request_use_case.dart';

/// A shared, in-memory stand-in for Firebase's
/// `users/$uid/device_enrollment_grants/*` subtree -- the ONE thing this
/// test lets the approving device's write side and the enrolling device's
/// read side actually communicate through, exactly as the real Realtime
/// Database node would. Both controllers below are built with their OWN
/// instance of this class, both pointed at the SAME [store] map, mirroring
/// two physically different devices reading/writing the same account's
/// Firebase subtree.
class _SharedEnrollmentGrantStore {
  final Map<String, Map<String, dynamic>> store = {};
}

class _FakeFirebaseMetadataService extends FirebaseMetadataService {
  _FakeFirebaseMetadataService(this._shared);

  final _SharedEnrollmentGrantStore _shared;

  @override
  Future<void> writeEnrollmentGrantData(
    String uid,
    String newDeviceId,
    Map<String, dynamic> data,
  ) async {
    _shared.store['$uid/$newDeviceId'] = data;
  }

  @override
  Future<Object?> readEnrollmentGrantData(String uid, String newDeviceId) async {
    return _shared.store['$uid/$newDeviceId'];
  }

  /// `E12-B09`: mirrors a real Realtime Database `.remove()` against the
  /// same shared store -- proves `DevicesController.block()`'s delete
  /// actually reaches the exact node the enrolling device reads.
  @override
  Future<void> deleteEnrollmentGrantData(String uid, String newDeviceId) async {
    _shared.store.remove('$uid/$newDeviceId');
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  test(
    'test_E12_B02_B03_end_to_end_an_approval_written_by_the_trusted_device '
    'is read as approved by the enrolling device',
    () async {
      const String suffix = 'e2e-approved';
      const String uid = 'account-uid';
      const String newDeviceId = 'new-device';
      const String approvingDeviceId = 'trusted-device';

      final shared = _SharedEnrollmentGrantStore();

      // --- The approving (already-trusted) device's own controller. ---
      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = RelationshipRepository(db);
      final blockUseCase = BlockUseCase(repository);
      messenger.setMockMessageHandler(
        'dev.flutter.pigeon.nexora.TransportApi.startDiscovery.$suffix',
        (ByteData? message) async =>
            TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[null]),
      );
      messenger.setMockMessageHandler(
        'dev.flutter.pigeon.nexora.TransportApi.stopDiscovery.$suffix',
        (ByteData? message) async =>
            TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[null]),
      );
      final transportService = TransportService(
        binaryMessenger: messenger,
        messageChannelSuffix: suffix,
      );
      addTearDown(transportService.dispose);
      final devicesController = DevicesController(
        repository,
        blockUseCase,
        transportService: transportService,
        evaluateConnectionRequestUseCase:
            EvaluateConnectionRequestUseCase(repository),
        currentAccountUid: () async => uid,
        thisDeviceId: () async => approvingDeviceId,
        firebaseMetadataService: _FakeFirebaseMetadataService(shared),
      );

      // Discover the enrolling device, classified as a pending enrollment
      // (own-device-id set contains it, no local relationship yet).
      final discoverySub = devicesController
          // Reach the classification via the same discovery path a real
          // Bluetooth/mesh scan would use -- exercised indirectly via
          // discover()/onDeviceDiscovered below through the transport
          // stream, so this test proves the REAL `verify()` call path.
          .pendingEnrollments;
      expect(discoverySub, isEmpty); // sanity: nothing classified yet.

      // Simulate the classification having already happened (this test's
      // focus is B02/B03's write->read channel, not T02's own discovery
      // classification, which its own suite already covers) by directly
      // adding the pending row the same way `_onDeviceDiscovered` would.
      devicesController.pendingEnrollments.add(
        TransportDevice(
          id: newDeviceId,
          displayName: 'New Phone',
          type: TransportType.bluetooth,
        ),
      );

      // --- The enrolling (new) device's own controller, BEFORE approval.
      final enrollingController = DeviceEnrollmentController(
        accountUid: uid,
        thisDeviceId: newDeviceId,
        firebaseMetadataService: _FakeFirebaseMetadataService(shared),
      );
      addTearDown(enrollingController.onClose);

      // (c) genuinely unapproved case: no grant has been written yet.
      expect(await enrollingController.checkApproval(), isFalse);

      // (a) the approving device's real verify() call...
      await devicesController.verify(newDeviceId);

      // ...results in a real write to the shared store (proves B02).
      expect(shared.store.containsKey('$uid/$newDeviceId'), isTrue);
      expect(
        shared.store['$uid/$newDeviceId']!['approvedByDeviceId'],
        approvingDeviceId,
      );

      // (b) the enrolling device's real checkApproval() now reads that
      // grant directly and returns true (proves B03 -- no
      // ConflictResolver/pull merge involved on this path at all).
      expect(await enrollingController.checkApproval(), isTrue);
    },
  );

  test(
    'a device that was never approved (no grant ever written) keeps '
    'reading as not approved',
    () async {
      final shared = _SharedEnrollmentGrantStore();
      final controller = DeviceEnrollmentController(
        accountUid: 'account-uid',
        thisDeviceId: 'never-approved-device',
        firebaseMetadataService: _FakeFirebaseMetadataService(shared),
      );
      addTearDown(controller.onClose);

      expect(await controller.checkApproval(), isFalse);
    },
  );

  test(
    'test_E12_B09_a_grant_revoked_by_a_later_block_no_longer_reads_as_'
    'approved',
    () async {
      // E12-B09 regression: approve `dev-X`, then call `block('dev-X')` on
      // the approving device (the SAME handler `Deny` uses) -- the
      // enrolling device's `checkApproval()` must now return `false`,
      // instead of still reading the stale grant (reviewer's own probe,
      // `E12-B09.md`).
      const String suffix = 'e2e-approved-then-blocked';
      const String uid = 'account-uid';
      const String newDeviceId = 'dev-X';
      const String approvingDeviceId = 'trusted-device';

      final shared = _SharedEnrollmentGrantStore();

      final db = AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(db.close);
      final repository = RelationshipRepository(db);
      final blockUseCase = BlockUseCase(repository);
      messenger.setMockMessageHandler(
        'dev.flutter.pigeon.nexora.TransportApi.startDiscovery.$suffix',
        (ByteData? message) async =>
            TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[null]),
      );
      messenger.setMockMessageHandler(
        'dev.flutter.pigeon.nexora.TransportApi.stopDiscovery.$suffix',
        (ByteData? message) async =>
            TransportApi.pigeonChannelCodec.encodeMessage(<Object?>[null]),
      );
      final transportService = TransportService(
        binaryMessenger: messenger,
        messageChannelSuffix: suffix,
      );
      addTearDown(transportService.dispose);
      final devicesController = DevicesController(
        repository,
        blockUseCase,
        transportService: transportService,
        evaluateConnectionRequestUseCase:
            EvaluateConnectionRequestUseCase(repository),
        currentAccountUid: () async => uid,
        thisDeviceId: () async => approvingDeviceId,
        firebaseMetadataService: _FakeFirebaseMetadataService(shared),
      );
      devicesController.pendingEnrollments.add(
        TransportDevice(
          id: newDeviceId,
          displayName: 'New Phone',
          type: TransportType.bluetooth,
        ),
      );

      final enrollingController = DeviceEnrollmentController(
        accountUid: uid,
        thisDeviceId: newDeviceId,
        firebaseMetadataService: _FakeFirebaseMetadataService(shared),
      );
      addTearDown(enrollingController.onClose);

      // Approve -- the enrolling device sees it (happy path, still works).
      await devicesController.verify(newDeviceId);
      expect(await enrollingController.checkApproval(), isTrue);

      // The approving device changes its mind: `block('dev-X')` (the SAME
      // handler `Deny` uses, per EARS-RECOVER-7).
      await devicesController.block(newDeviceId);

      // The grant node itself is gone from the shared store...
      expect(shared.store.containsKey('$uid/$newDeviceId'), isFalse);
      // ...so the enrolling device's own checkApproval() now correctly
      // returns false instead of still trusting the stale grant.
      expect(await enrollingController.checkApproval(), isFalse);
    },
  );
}
