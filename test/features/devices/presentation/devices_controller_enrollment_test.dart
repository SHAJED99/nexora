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
      'readOwnDeviceIds is fetched at most once per discovery cycle (E12-B04)',
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
      'test_E12_B04_stale_own_device_cache_does_not_permanently_disable_enrollment_detection',
      () async {
    // Repro from E12-B04: the trusted device's Devices screen is opened
    // (its own-device-id read resolves against the registry as it stood at
    // that moment), THEN a new device registers, and only after that does
    // discovery announce it. Before the fix, the cached Future from the
    // first `discover()` call would still answer with the pre-registration
    // set for the rest of the controller's life, misclassifying the new
    // device as an ordinary stranger forever. The fix: each `discover()`
    // call re-resolves the own-device-id read, so a second Discover tap
    // (the natural next user action -- re-scanning) sees the updated
    // registry.
    const String suffix = 'enrollment-stale-cache';
    final stub = _StubFirebaseMetadataService({'already-known-device'});
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

    // First discovery cycle: some unrelated stranger device is discovered,
    // populating [_ownDeviceIdsFuture] for this cycle (the read is only
    // triggered by a classification, never by `discover()` itself).
    controller.discover();
    await Future<void>.delayed(Duration.zero);
    pushDiscoveredDevice(
      suffix,
      TransportDevice(
        id: 'unrelated-stranger',
        displayName: 'Some Other Phone',
        type: TransportType.bluetooth,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    expect(stub.callCount, 1);

    // The new device registers server-side in between the two cycles --
    // simulated here by mutating the stub's own-device set, exactly as
    // `readOwnDeviceIds` would now return if re-queried.
    stub._ids.add('newly-enrolled-device');

    // Second Discover tap (the natural next step -- the user re-scans
    // after the new device has had a chance to come up): the own-device-id
    // read must be re-resolved, not answered from the stale first-cycle
    // cache.
    controller.discover();
    await Future<void>.delayed(Duration.zero);
    pushDiscoveredDevice(
      suffix,
      TransportDevice(
        id: 'newly-enrolled-device',
        displayName: 'New Phone',
        type: TransportType.bluetooth,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(stub.callCount, 2);
    expect(controller.pendingEnrollments, hasLength(1));
    expect(controller.pendingEnrollments.single.id, 'newly-enrolled-device');
    // NOT rendered as an ordinary unknown-peer row alongside the unrelated
    // stranger from the first cycle.
    expect(
      controller.relationships.any((r) => r.deviceId == 'newly-enrolled-device'),
      isFalse,
    );
  });

  test(
      'test_E12_B04_F1_device_discovered_during_stale_cycle_is_reclassified_on_next_discover',
      () async {
    // The reviewer's exact repro of round 1's gap: the device that SHOULD
    // become a pending enrollment is discovered ONCE, during the stale
    // cycle, and gets classified `normal` -- an ordinary Unknown stranger --
    // added to `relationships` as an in-memory row. Resetting
    // `_ownDeviceIdsFuture` alone (round 1's fix, proven by the test above)
    // does nothing for THIS device from then on: `_onDeviceDiscovered`'s own
    // `alreadyShown` guard short-circuits before `_classifyDiscoveredDevice`
    // is ever reached again for it, so a second Discover call changed
    // nothing under round 1's fix. This test never pushes a SECOND discovery
    // event for the device at all -- unlike the test above, where the
    // misclassified device is discovered for the first time only in the
    // second cycle. Round 2 (F1) explicitly re-evaluates every
    // discovery-tracked `normal` device when `discover()` resets the cache,
    // which is the only way this device can ever be reclassified.
    const String suffix = 'enrollment-stale-cycle-reclassify';
    final stub = _StubFirebaseMetadataService({'already-known-device'});
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

    // First Discover tap: the own-device-id cache is stale -- it does not
    // yet contain the target device's id, which only registers server-side
    // AFTER this cycle's own-device-id read has already resolved.
    controller.discover();
    await Future<void>.delayed(Duration.zero);
    pushDiscoveredDevice(
      suffix,
      TransportDevice(
        id: 'target-device',
        displayName: 'New Phone',
        type: TransportType.bluetooth,
      ),
    );
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    // Misclassified `normal`, exactly as B04's own repro describes -- the
    // registry did not yet contain this id when it was first evaluated.
    expect(stub.callCount, 1);
    expect(controller.pendingEnrollments, isEmpty);
    expect(
      controller.relationships.any((r) => r.deviceId == 'target-device'),
      isTrue,
    );

    // The device registers server-side in between the two Discover taps.
    stub._ids.add('target-device');

    // Second Discover tap -- deliberately NO further discovery event is
    // pushed for this device here. It is already sitting in `relationships`
    // from the first cycle; this is exactly the case round 1's fix left
    // uncovered, since `alreadyShown` would otherwise forever short-circuit
    // `_classifyDiscoveredDevice` for an id already present there.
    controller.discover();
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);
    await Future<void>.delayed(Duration.zero);

    expect(stub.callCount, 2);
    expect(controller.pendingEnrollments, hasLength(1));
    expect(controller.pendingEnrollments.single.id, 'target-device');
    expect(
      controller.relationships.any((r) => r.deviceId == 'target-device'),
      isFalse,
    );
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
    // A defensive snapshot copy -- matching the real
    // `FirebaseMetadataService.readOwnDeviceIds`, which returns a freshly
    // built `Set` from its own Realtime Database read, never a live
    // reference into caller-held state. Returning `_ids` itself here would
    // let a caller mutate `_ids` AFTER this Future has already resolved and
    // silently change what an already-cached `Future<Set<String>>` appears
    // to contain -- masking whether a fix actually re-fetches instead of
    // just re-reading the same resolved Future's now-mutated value.
    return Set<String>.of(_ids);
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
