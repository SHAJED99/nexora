// features/devices/presentation — E12-T02 (`FR-RECOVER-001`).
//
// Proves `DevicesController`'s new pending-enrollment classification: a
// discovered device id that is (a) present in this account's own device
// list (`FirebaseMetadataService.readOwnDeviceIds`, E12-T01) and (b) has no
// local `RelationshipRepository` entry yet is a pending enrollment request,
// not the ordinary unknown-peer treatment -- and that its two actions reuse
// the controller's existing `verify()`/`block()`, unchanged.
//
// Same platform-channel harness as `devices_controller_test.dart`: a real
// `TransportService` over a `TestDefaultBinaryMessenger`, mocked only on the
// native side.
import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/services/firebase_metadata_service.dart';
import 'package:nexora/core/transport/generated/transport_api.g.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/devices/presentation/devices_controller.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/block_use_case.dart';
import 'package:nexora/features/trust/domain/evaluate_connection_request_use_case.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  final TestDefaultBinaryMessenger messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  late AppDatabase db;
  late RelationshipRepository repository;
  late BlockUseCase blockUseCase;

  setUp(() {
    db = AppDatabase.forTesting(NativeDatabase.memory());
    repository = RelationshipRepository(db);
    blockUseCase = BlockUseCase(repository);
  });

  tearDown(() => db.close());

  /// Builds a `DevicesController` wired to a real `TransportService` (same
  /// mock-native-side pattern as `devices_controller_test.dart`) with
  /// [ownDeviceIds] injected as the controller's `currentAccountUid`/
  /// `readOwnDeviceIds` hint -- avoids needing a live Firebase platform
  /// channel or a `Get.find<DeviceIdentityRepository>()` registration for
  /// this test's purpose (classification logic only, task §5).
  DevicesController buildController(
    String suffix, {
    required Set<String> ownDeviceIds,
    bool signedIn = true,
    _StubFirebaseMetadataService? firebaseMetadataService,
    String? thisDeviceId,
  }) {
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
    final TransportService transportService = TransportService(
      binaryMessenger: messenger,
      messageChannelSuffix: suffix,
    );
    addTearDown(transportService.dispose);
    return DevicesController(
      repository,
      blockUseCase,
      transportService: transportService,
      evaluateConnectionRequestUseCase:
          EvaluateConnectionRequestUseCase(repository),
      // The real `_defaultCurrentAccountUid`/`FirebaseMetadataService`
      // pairing is exercised in production via the app-wide
      // `DeviceIdentityRepository` singleton (see the controller's own doc
      // comment) -- this override is the same "inject a stub instead of a
      // full DI container" seam `evaluateConnectionRequestUseCase` already
      // uses above.
      currentAccountUid: () async => signedIn ? 'uid-1' : null,
      // `E12-B02`: same injectable-stub seam as `currentAccountUid` above,
      // for the approving device's OWN id (`approvedByDeviceId`).
      thisDeviceId: () async => signedIn ? (thisDeviceId ?? 'approver-device') : null,
      firebaseMetadataService:
          firebaseMetadataService ?? _StubFirebaseMetadataService(ownDeviceIds),
    );
  }

  void pushDiscoveredDevice(String suffix, TransportDevice device) {
    final ByteData eventMessage =
        TransportEventsApi.pigeonChannelCodec.encodeMessage(
      <Object?>[device],
    )!;
    messenger.handlePlatformMessage(
      'dev.flutter.pigeon.nexora.TransportEventsApi.onDeviceDiscovered.$suffix',
      eventMessage,
      (ByteData? _) {},
    );
  }

  test(
      'test_EARS_RECOVER_5_own_account_device_with_no_relationship_is_pending_enrollment',
      () async {
    const String suffix = 'enrollment-pending';
    final controller = buildController(
      suffix,
      ownDeviceIds: {'own-new-device'},
    );

    controller.discover();
    await Future<void>.delayed(Duration.zero);
    pushDiscoveredDevice(
      suffix,
      TransportDevice(
        id: 'own-new-device',
        displayName: 'New Phone',
        type: TransportType.bluetooth,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    // Classification does its own repository read before deciding -- pump
    // one more microtask turn for that async gap to settle.
    await Future<void>.delayed(Duration.zero);

    expect(controller.pendingEnrollments, hasLength(1));
    expect(controller.pendingEnrollments.single.id, 'own-new-device');
    // NOT rendered as an ordinary unknown-peer row.
    expect(controller.relationships, isEmpty);
  });

  test('test_EARS_RECOVER_6_foreign_device_id_unaffected', () async {
    const String suffix = 'enrollment-foreign';
    final controller = buildController(
      suffix,
      // This account's own device list does NOT contain the discovered id.
      ownDeviceIds: {'some-other-own-device'},
    );

    controller.discover();
    await Future<void>.delayed(Duration.zero);
    pushDiscoveredDevice(
      suffix,
      TransportDevice(
        id: 'stranger-device',
        displayName: 'Nearby Phone',
        type: TransportType.bluetooth,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    // Exactly the pre-E12-T02 unknown-peer treatment.
    expect(controller.pendingEnrollments, isEmpty);
    expect(controller.relationships, hasLength(1));
    expect(controller.relationships.single.deviceId, 'stranger-device');
    expect(
      controller.relationships.single.state,
      RelationshipState.unknown,
    );
  });

  test(
      'test_EARS_RECOVER_6b_own_device_id_with_existing_relationship_unaffected',
      () async {
    // The other half of EARS-RECOVER-5's AND: present in the own-device set
    // is not enough on its own -- an existing local relationship entry
    // means this side has already evaluated the device, so it must NOT be
    // reclassified as a pending enrollment.
    const String suffix = 'enrollment-already-known';
    await repository.upsert('already-trusted-own-device',
        RelationshipState.trusted);
    final controller = buildController(
      suffix,
      ownDeviceIds: {'already-trusted-own-device'},
    );
    await controller.load();

    controller.discover();
    await Future<void>.delayed(Duration.zero);
    pushDiscoveredDevice(
      suffix,
      TransportDevice(
        id: 'already-trusted-own-device',
        displayName: 'Ahmed\'s Laptop',
        type: TransportType.wifiDirect,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(controller.pendingEnrollments, isEmpty);
    // Already shown via `load()` as the persisted Trusted row; the
    // discovery event is a no-op (already-shown de-dup).
    expect(controller.relationships, hasLength(1));
    expect(
      controller.relationships.single.state,
      RelationshipState.trusted,
    );
  });

  test('test_EARS_RECOVER_7_approve_calls_verify_deny_calls_block', () async {
    const String suffix = 'enrollment-actions';
    final controller = buildController(
      suffix,
      ownDeviceIds: {'device-a', 'device-b'},
    );

    controller.discover();
    await Future<void>.delayed(Duration.zero);
    pushDiscoveredDevice(
      suffix,
      TransportDevice(
        id: 'device-a',
        displayName: 'Approve Me',
        type: TransportType.bluetooth,
      ),
    );
    pushDiscoveredDevice(
      suffix,
      TransportDevice(
        id: 'device-b',
        displayName: 'Deny Me',
        type: TransportType.bluetooth,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(controller.pendingEnrollments, hasLength(2));

    // "Approve" -> the controller's existing `verify()`.
    await controller.verify('device-a');
    expect(
      controller.pendingEnrollments.any((d) => d.id == 'device-a'),
      isFalse,
    );
    final approved = await repository.get('device-a');
    expect(approved!.state, RelationshipState.allowed);
    expect(
      controller.relationships.any(
        (r) => r.deviceId == 'device-a' && r.state == RelationshipState.allowed,
      ),
      isTrue,
    );

    // "Deny" -> the controller's existing `block()`.
    await controller.block('device-b');
    expect(
      controller.pendingEnrollments.any((d) => d.id == 'device-b'),
      isFalse,
    );
    final denied = await repository.get('device-b');
    expect(denied!.state, RelationshipState.blocked);
  });

  test(
      'test_EARS_RECOVER_7_E12_B02_approving_a_pending_enrollment_writes_a_real_grant',
      () async {
    // E12-B02 regression: before this fix, `verify()` wrote ONLY the local
    // Drift row and nothing ever reached Firebase (`RelationshipSyncService
    // .push` had zero production callers). This proves the dedicated
    // enrollment-grant channel now actually receives a write when
    // `Approve` (== `verify()`) resolves a genuine pending-enrollment row.
    const String suffix = 'enrollment-grant-write';
    final stub = _StubFirebaseMetadataService({'device-a'});
    final controller = buildController(
      suffix,
      ownDeviceIds: {'device-a'},
      firebaseMetadataService: stub,
      thisDeviceId: 'my-approving-device',
    );

    controller.discover();
    await Future<void>.delayed(Duration.zero);
    pushDiscoveredDevice(
      suffix,
      TransportDevice(
        id: 'device-a',
        displayName: 'Approve Me',
        type: TransportType.bluetooth,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(controller.pendingEnrollments, hasLength(1));

    await controller.verify('device-a');

    expect(stub.writeEnrollmentGrantCallCount, 1);
    expect(stub.capturedGrantUid, 'uid-1');
    expect(stub.capturedGrantNewDeviceId, 'device-a');
    expect(
      stub.capturedGrantData!['approvedByDeviceId'],
      'my-approving-device',
    );
  });

  test(
      'an ordinary Verify of a ordinary Unknown stranger (not a pending '
      'enrollment) does NOT write an enrollment grant',
      () async {
    // Control arm for the regression test above: writing a grant record
    // for a peer that was never classified as a pending enrollment would
    // be a category error (there is no enrollment to grant) -- the same
    // shape of mistake E12-B03 diagnoses for ConflictResolver, just on the
    // write side instead of the read side.
    const String suffix = 'enrollment-grant-no-write-for-stranger';
    final stub = _StubFirebaseMetadataService({'some-other-own-device'});
    final controller = buildController(
      suffix,
      ownDeviceIds: {'some-other-own-device'},
      firebaseMetadataService: stub,
    );

    controller.discover();
    await Future<void>.delayed(Duration.zero);
    pushDiscoveredDevice(
      suffix,
      TransportDevice(
        id: 'stranger-device',
        displayName: 'Nearby Phone',
        type: TransportType.bluetooth,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(controller.pendingEnrollments, isEmpty);
    expect(controller.relationships, hasLength(1));

    await controller.verify('stranger-device');

    expect(stub.writeEnrollmentGrantCallCount, 0);
  });

  test(
      'readOwnDeviceIds is fetched at most once per controller lifetime (session cache)',
      () async {
    const String suffix = 'enrollment-cache';
    final stub = _StubFirebaseMetadataService({'own-device'});
    final controller = DevicesController(
      repository,
      blockUseCase,
      transportService: TransportService(
        binaryMessenger: messenger,
        messageChannelSuffix: suffix,
      ),
      evaluateConnectionRequestUseCase:
          EvaluateConnectionRequestUseCase(repository),
      currentAccountUid: () async => 'uid-1',
      firebaseMetadataService: stub,
    );
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

    controller.discover();
    await Future<void>.delayed(Duration.zero);
    pushDiscoveredDevice(
      suffix,
      TransportDevice(
          id: 'peer-1', displayName: 'Peer 1', type: TransportType.bluetooth),
    );
    pushDiscoveredDevice(
      suffix,
      TransportDevice(
          id: 'peer-2', displayName: 'Peer 2', type: TransportType.bluetooth),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(stub.callCount, 1);
  });

  test(
      'a null current-account uid degrades to no pending enrollments, never throws',
      () async {
    const String suffix = 'enrollment-no-uid';
    final controller = buildController(
      suffix,
      ownDeviceIds: {'own-new-device'},
      signedIn: false,
    );

    controller.discover();
    await Future<void>.delayed(Duration.zero);
    pushDiscoveredDevice(
      suffix,
      TransportDevice(
        id: 'own-new-device',
        displayName: 'New Phone',
        type: TransportType.bluetooth,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(controller.pendingEnrollments, isEmpty);
    expect(controller.relationships, hasLength(1));
    expect(
      controller.relationships.single.state,
      RelationshipState.unknown,
    );
  });
}

/// A test double for `FirebaseMetadataService.readOwnDeviceIds` -- no real
/// Realtime Database platform channel is needed for this task's own
/// classification logic (task §5: the function under test is
/// `DevicesController._classifyDiscoveredDevice`, not
/// `FirebaseMetadataService` itself, which E12-T01 already tests).
/// `FirebaseMetadataService`'s constructor never touches a live
/// `FirebaseDatabase` until a read/write is actually attempted (its own
/// doc comment), so extending it with no override is safe to construct in
/// a test with no Firebase platform harness at all -- only
/// [readOwnDeviceIds] is ever exercised here.
class _StubFirebaseMetadataService extends FirebaseMetadataService {
  _StubFirebaseMetadataService(this._ids);

  final Set<String> _ids;
  int callCount = 0;

  /// `E12-B02` regression evidence: captures whether/what `verify()`
  /// actually wrote to the dedicated enrollment-grant channel, instead of
  /// touching a real `FirebaseDatabase`/platform channel.
  int writeEnrollmentGrantCallCount = 0;
  String? capturedGrantUid;
  String? capturedGrantNewDeviceId;
  Map<String, dynamic>? capturedGrantData;

  @override
  Future<Set<String>> readOwnDeviceIds(String uid) async {
    callCount++;
    return _ids;
  }

  @override
  Future<void> writeEnrollmentGrantData(
    String uid,
    String newDeviceId,
    Map<String, dynamic> data,
  ) async {
    writeEnrollmentGrantCallCount++;
    capturedGrantUid = uid;
    capturedGrantNewDeviceId = newDeviceId;
    capturedGrantData = data;
  }
}
