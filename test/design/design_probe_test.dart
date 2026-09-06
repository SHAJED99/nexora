// test/design/design_probe_test.dart — the Flutter-capable design-fidelity
// gate's runner (E06-T01, closes OQ-E00-3).
//
// Two jobs, both here per the task contract:
//   1. Register every screen this gate can dump. `make design-probe` runs
//      this file; each registered screen is pumped via `dumpScreenProbe` and
//      written to build/design-probe/<screenId>.json for `make design-verify
//      SCREEN=<id> IMPL=flutter` to read (see design/tools/verify.mjs).
//      `devices` is the proving screen for this task (E02-T02, already built
//      and hand-checked) — T10/T11/T12 add their own screens here, in their
//      own files: fence, following the one-block pattern below.
//   2. The EARS falsification tests (EARS-UI-1/2). These use a small fixture
//      widget, NOT `devices` — fast, deterministic, and isolated from that
//      screen's real complexity (§8 of the task file). They reuse
//      design/tools/lib/compare.mjs and flutter_probe.mjs UNCHANGED by
//      shelling out to `node` — this is the same comparison engine
//      `make design-verify` runs, not a reimplementation of it.
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/transport/transport_service.dart';
import 'package:nexora/features/chat/presentation/chat_controller.dart';
import 'package:nexora/features/chat/presentation/chat_view.dart';
import 'package:nexora/features/conversations/presentation/conversations_binding.dart';
import 'package:nexora/features/conversations/presentation/conversations_view.dart';
import 'package:nexora/features/dashboard/presentation/dashboard_binding.dart';
import 'package:nexora/features/dashboard/presentation/dashboard_view.dart';
import 'package:nexora/core/routing_engine/link_quality_feed.dart';
import 'package:nexora/core/storage/retention_executor.dart';
import 'package:nexora/core/storage/retention_plan.dart' show SmartModeThresholds;
import 'package:nexora/core/storage/smart_mode_policy.dart';
import 'package:nexora/core/storage/storage_decision_log.dart';
import 'package:nexora/core/storage/storage_inventory.dart';
import 'package:nexora/core/storage/storage_manager.dart';
import 'package:nexora/core/storage/storage_settings_repository.dart';
import 'package:nexora/core/services/firebase_metadata_service.dart';
import 'package:nexora/features/devices/presentation/devices_binding.dart';
import 'package:nexora/features/devices/presentation/devices_controller.dart';
import 'package:nexora/features/devices/presentation/devices_view.dart';
import 'package:nexora/features/messaging/data/conversation_repository.dart';
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';
import 'package:nexora/features/recovery/presentation/device_enrollment_controller.dart';
import 'package:nexora/features/recovery/presentation/device_enrollment_view.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/block_use_case.dart';
import 'package:nexora/features/trust/domain/relationship.dart';
import 'package:on_process_button_widget/on_process_button_widget.dart';
import 'package:path/path.dart' as p;

import 'flutter_probe_dumper.dart';

/// A plain `StorageManager` over [db] — real settings/inventory/executor,
/// mirroring `dashboard_controller_test.dart`'s own `_newStorageManager`
/// (E08-T08). Used only by the `dashboard` probe below, so its own
/// `DashboardBinding` has a real singleton to `Get.find`, exactly as
/// `app/bindings.dart` registers one in production.
StorageManager _newStorageManager(AppDatabase db) {
  final log = StorageDecisionLog(db: db);
  return StorageManager(
    settings: StorageSettingsRepository(db: db),
    inventory: StorageInventory(db: db, databaseFileBytes: () async => 0),
    smart: SmartModePolicy(thresholds: SmartModeThresholds.defaults()),
    executor: RetentionExecutor(db: db, log: log),
    log: log,
  );
}

/// Seeds a group conversation (E07-T01's tables), mirroring
/// `dashboard_controller_test.dart`'s/`conversations_groups_test.dart`'s own
/// `_insertGroup` helper — so a group row reaches the `conversations` probe
/// below through E07-T07's widened read model (`L-design-002`'s carried-
/// forward closure: this fixture seeded zero group conversations before
/// E08-T08).
Future<void> _insertGroup(
  AppDatabase db, {
  required String id,
  required String name,
}) async {
  await db.into(db.groups).insert(
        GroupsCompanion.insert(
          id: id,
          name: name,
          createdAt: 0,
          createdByDeviceId: 'self-probe-device',
        ),
      );
}

Future<void> _insertMember(
  AppDatabase db, {
  required String groupId,
  required String deviceId,
}) async {
  await db.into(db.groupMembers).insert(
        GroupMembersCompanion.insert(
          groupId: groupId,
          deviceId: deviceId,
          role: 'member',
          joinedAtEpoch: 0,
        ),
      );
}

/// A `FirebaseMetadataService` test double for the `device-enrollment` probe
/// below -- never touches a real `FirebaseDatabase`/platform channel, always
/// reports "not yet approved, not revoked" (same seam-stubbing pattern
/// `device_enrollment_controller_test.dart`'s own
/// `_StubFirebaseMetadataService` uses, reimplemented here since that class
/// is private to its own file).
class _NeverGrantsFirebaseMetadataService extends FirebaseMetadataService {
  @override
  Future<Object?> readEnrollmentGrantData(String uid, String newDeviceId) async =>
      null;

  @override
  Future<Object?> readDeviceMetadata(String uid, String deviceId) async => null;
}

void main() {
  // ── 1. Screens dumped for `make design-probe` ───────────────────────────
  group('screen probes (make design-probe)', () {
    late AppDatabase db;
    late TransportService transportService;

    setUp(() async {
      Get.testMode = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = RelationshipRepository(db);
      // One of each RelationshipState, per design/screens/devices.md's four
      // example rows (§2). Real device names/timestamps won't literally
      // match the design's copy ("Ahmed's Laptop" etc.) — that's a real,
      // expected finding (design/gaps.md GAP-003), not something faked here
      // to dodge it (E06-T01 §4/§Run log).
      await repository.upsert('device-trusted', RelationshipState.trusted);
      await repository.upsert('device-allowed', RelationshipState.allowed);
      await repository.upsert('device-unknown', RelationshipState.unknown);
      await repository.upsert('device-blocked', RelationshipState.blocked);
      Get.put<RelationshipRepository>(repository, permanent: true);
      Get.put<BlockUseCase>(BlockUseCase(repository), permanent: true);
      // E12-B05: `DevicesBinding().dependencies()` resolves
      // `Get.find<TransportService>()` (see its own doc comment — it must
      // never let `DevicesController` fall back to constructing its own
      // instance), so this probe needs one registered too, same
      // real-`TransportService`-over-a-mocked-native-side pattern the
      // `conversations`/`chat` probes below already use for their own
      // `MessagingStack`. Fetched here inside `setUp`, not at group-body
      // scope: this is the FIRST group in the file, so
      // `TestWidgetsFlutterBinding` is not yet initialized when the group
      // body itself runs (that only happens once this group's own
      // `testWidgets` call is declared, further down) -- `setUp` bodies run
      // later, at actual test-run time, well after that.
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      transportService = TransportService(
        binaryMessenger: messenger,
        messageChannelSuffix: 'devices-probe',
      );
      Get.put<TransportService>(transportService, permanent: true);
      DevicesBinding().dependencies();
    });

    tearDown(() async {
      await db.close();
      await transportService.dispose();
      Get.reset();
    });

    testWidgets('devices', (tester) async {
      await dumpScreenProbe(
        tester,
        screenId: 'devices',
        screen: GetMaterialApp(home: const DevicesView()),
      );
      // E12-B05, F4: without this, a future regression that silently brings
      // back `renderError: true` (e.g. a missing dependency in this `setUp`
      // again) would still say "All tests passed" here -- this test would
      // pass whether or not the probe actually walked anything. Real
      // dart:io read -- must go through `runAsync` for the same reason
      // `dumpScreenProbe`'s own file write does (see
      // flutter_probe_dumper.dart).
      final raw = await tester.runAsync(
        () => File('build/design-probe/devices.json').readAsString(),
      );
      final dump = jsonDecode(raw!) as Map<String, dynamic>;
      expect(dump['renderError'], isNull);
    });
  });

  // ── E06-T10: `conversations` ─────────────────────────────────────────────
  group('screen probes — conversations (make design-probe)', () {
    late AppDatabase db;
    late MessagingStack stack;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    setUp(() async {
      Get.testMode = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = RelationshipRepository(db);
      // Two trusted peers with a real message each, per
      // design/screens/conversations.md's two example Personal rows. Real
      // device ids/timestamps and (since no session is ever established
      // here) a non-decryptable preview won't literally match the design's
      // copy ("Ahmed"/"Sounds good, see you then!") — that is a real,
      // expected finding (design/gaps.md GAP-003, this task's own §2 on
      // graceful preview-decrypt failure), not something faked here to
      // dodge it, matching E06-T01's own precedent for `devices`.
      await repository.upsert('device-trusted', RelationshipState.trusted);
      await db.into(db.messages).insert(
            MessagesCompanion.insert(
              id: 'probe-message-1',
              conversationId: 'device-trusted',
              senderDeviceId: 'device-trusted',
              sequenceNumber: 1,
              ciphertext: Uint8List.fromList(List<int>.filled(32, 7)),
              createdAt: DateTime.now().millisecondsSinceEpoch,
              deliveryState: DeliveryState.accepted.name,
            ),
          );
      await repository.upsert('device-allowed', RelationshipState.allowed);
      await db.into(db.messages).insert(
            MessagesCompanion.insert(
              id: 'probe-message-2',
              conversationId: 'device-allowed',
              senderDeviceId: 'device-allowed',
              sequenceNumber: 1,
              ciphertext: Uint8List.fromList(List<int>.filled(32, 9)),
              createdAt: DateTime.now()
                  .subtract(const Duration(days: 1))
                  .millisecondsSinceEpoch,
              deliveryState: DeliveryState.accepted.name,
            ),
          );
      // `L-design-002`'s carried-forward closure (E08-T08, narrowly scoped
      // to exactly this one seed): this fixture seeded zero group
      // conversations across two prior tasks (E07-T08, E07-B01), leaving the
      // design gate structurally blind to `design/screens/conversations.md`'s
      // own `Groups` section (`GAP-006`). One group, one member, one
      // message — mirroring the two Personal rows above, real device
      // ids/timestamps and (no session established here) an undecryptable
      // preview stay a real, expected finding (`GAP-003`), same precedent as
      // the Personal rows.
      await _insertGroup(db, id: 'g:probe-group', name: 'Family');
      await _insertMember(db, groupId: 'g:probe-group', deviceId: 'self-probe-device');
      await _insertMember(db, groupId: 'g:probe-group', deviceId: 'device-trusted');
      await db.into(db.messages).insert(
            MessagesCompanion.insert(
              id: 'probe-group-message-1',
              conversationId: 'g:probe-group',
              senderDeviceId: 'device-trusted',
              sequenceNumber: 1,
              ciphertext: Uint8List.fromList(List<int>.filled(32, 11)),
              createdAt: DateTime.now()
                  .subtract(const Duration(hours: 2))
                  .millisecondsSinceEpoch,
              deliveryState: DeliveryState.accepted.name,
            ),
          );

      stack = await MessagingStack.create(
        db: db,
        selfDeviceId: 'self-probe-device',
        transport: TransportService(
          binaryMessenger: messenger,
          messageChannelSuffix: 'conversations-probe',
        ),
      );
      Get.put<MessagingStack>(stack, permanent: true);
      ConversationsBinding().dependencies();
    });

    tearDown(() async {
      await stack.dispose();
      Get.reset();
    });

    testWidgets('conversations', (tester) async {
      await dumpScreenProbe(
        tester,
        screenId: 'conversations',
        screen: GetMaterialApp(home: const ConversationsView()),
      );
    });
  });

  // ── E06-T11: `chat` ───────────────────────────────────────────────────────
  group('screen probes — chat (make design-probe)', () {
    late AppDatabase db;
    late MessagingStack stack;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    setUp(() async {
      Get.testMode = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = RelationshipRepository(db);
      // A trusted peer with a five-message thread — the same COUNT and
      // rough incoming/outgoing shape as design/screens/chat.md's populated
      // thread (elements 10-25), so the probe's overall layout height is
      // comparable to the golden capture's. Real device ids/timestamps and
      // (since no session is ever established here) an undecryptable body
      // won't literally match the design's copy ("Ahmed"/"Are you
      // free..."/etc.) — that is a real, expected finding
      // (design/gaps.md GAP-003), not something faked here to dodge it,
      // matching E06-T01/T10's own precedent.
      await repository.upsert('device-trusted', RelationshipState.trusted);
      final now = DateTime.now().millisecondsSinceEpoch;
      const senders = [
        'device-trusted', // incoming — mirrors element 10
        'self-probe-device', // outgoing — mirrors element 12
        'device-trusted', // incoming — mirrors element 15
        'self-probe-device', // outgoing — mirrors element 20
        'self-probe-device', // outgoing — mirrors element 23
      ];
      for (var i = 0; i < senders.length; i++) {
        await db.into(db.messages).insert(
              MessagesCompanion.insert(
                id: 'probe-chat-message-$i',
                conversationId: 'device-trusted',
                senderDeviceId: senders[i],
                sequenceNumber: i,
                ciphertext: Uint8List.fromList(List<int>.filled(32, 7 + i)),
                createdAt: now + i * 60000,
                deliveryState: DeliveryState.accepted.name,
              ),
            );
      }

      stack = await MessagingStack.create(
        db: db,
        selfDeviceId: 'self-probe-device',
        transport: TransportService(
          binaryMessenger: messenger,
          messageChannelSuffix: 'chat-probe',
        ),
      );
      Get.put<MessagingStack>(stack, permanent: true);
      // `ChatController` is deliberately NOT constructed here in `setUp` --
      // found directly: `Get.put<ChatController>` from inside `setUp`'s own
      // async function left the built widget with only the header/composer
      // (15 elements, no message-list content at all) even though the
      // controller's own `messages`/`loading` state was correct by the time
      // `testWidgets` ran. Constructing it in the `testWidgets` body itself
      // (immediately before `dumpScreenProbe`, same as this file's
      // `devices`/`conversations` probes already do for THEIR controllers)
      // reliably produces the full 35-element dump instead. Not fully
      // root-caused (an Obx/GetX zone interaction across the setUp/test
      // boundary is the leading suspect); logged here rather than left
      // silent, and reported in this task's Run log for anyone chasing the
      // same symptom on a later screen.
    });

    tearDown(() async {
      await stack.dispose();
      Get.reset();
    });

    testWidgets('chat', (tester) async {
      // Direct construction rather than `ChatBinding().dependencies()` --
      // that binding reads `Get.parameters['id']` from the router, which
      // this probe (built via `GetMaterialApp(home: ...)`, no route push)
      // never populates. Every dependency below is the SAME already-
      // constructed stack member `ChatBinding` itself would have used.
      Get.put<ChatController>(
        ChatController(
          conversationId: 'device-trusted',
          repo: ConversationRepository(db, selfDeviceId: stack.selfDeviceId),
          send: stack.sendMessage,
          sessions: stack.prekeyExchange,
          crypto: stack.cryptoService,
          acks: stack.deliveryAckService,
        ),
      );
      await dumpScreenProbe(
        tester,
        screenId: 'chat',
        screen: GetMaterialApp(home: const ChatView()),
      );
    });
  });

  // ── E06-T12: `dashboard` ─────────────────────────────────────────────────
  group('screen probes — dashboard (make design-probe)', () {
    late AppDatabase db;
    late MessagingStack stack;
    final messenger = TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

    setUp(() async {
      Get.testMode = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = RelationshipRepository(db);
      // Three trusted peers, mirroring design/screens/dashboard.md's three
      // Recent Conversations example rows (elements 20-34) — one read
      // (green tick), one delivered (grey tick), one still queued (this
      // device's own, unsent message — element 33-34's real state, per this
      // task's own §2). Real device ids/timestamps and an undecryptable
      // preview (no session established here) won't literally match the
      // design's copy ("Family"/"See you at 7pm!") — a real, expected
      // finding (design/gaps.md GAP-003), same precedent T10/T11 already
      // established, not something faked here to dodge it.
      await repository.upsert('device-read', RelationshipState.trusted);
      await db.into(db.messages).insert(
            MessagesCompanion.insert(
              id: 'probe-dash-message-read',
              conversationId: 'device-read',
              senderDeviceId: 'device-read',
              sequenceNumber: 1,
              ciphertext: Uint8List.fromList(List<int>.filled(32, 3)),
              createdAt: DateTime.now().millisecondsSinceEpoch,
              deliveryState: DeliveryState.read.name,
            ),
          );
      await repository.upsert('device-delivered', RelationshipState.allowed);
      await db.into(db.messages).insert(
            MessagesCompanion.insert(
              id: 'probe-dash-message-delivered',
              conversationId: 'device-delivered',
              senderDeviceId: 'self-probe-device',
              sequenceNumber: 1,
              ciphertext: Uint8List.fromList(List<int>.filled(32, 5)),
              createdAt: DateTime.now()
                  .subtract(const Duration(days: 1))
                  .millisecondsSinceEpoch,
              deliveryState: DeliveryState.delivered.name,
            ),
          );
      await repository.upsert('device-queued', RelationshipState.trusted);
      await db.into(db.messages).insert(
            MessagesCompanion.insert(
              id: 'probe-dash-message-queued',
              conversationId: 'device-queued',
              senderDeviceId: 'self-probe-device',
              sequenceNumber: 1,
              ciphertext: Uint8List.fromList(List<int>.filled(32, 7)),
              createdAt: DateTime.now()
                  .subtract(const Duration(days: 3))
                  .millisecondsSinceEpoch,
              deliveryState: DeliveryState.queued.name,
            ),
          );

      stack = await MessagingStack.create(
        db: db,
        selfDeviceId: 'self-probe-device',
        transport: TransportService(
          binaryMessenger: messenger,
          messageChannelSuffix: 'dashboard-probe',
        ),
      );
      Get.put<MessagingStack>(stack, permanent: true);
      Get.put<LinkQualityFeed>(
        LinkQualityFeed(transport: stack.transport, routing: stack.routingEngine),
        permanent: true,
      );
      // `L-design-002` (E08-T08): this screen's displayed data shape widened
      // to include real storage figures, so the fixture seeds a real
      // `StorageManager` and runs one plan-only pass -- otherwise the gate
      // stays structurally blind to the Local Storage card's new content,
      // exactly the failure this rule exists to prevent. `app/bindings.dart`
      // registers this same permanent singleton in production; this probe
      // does the same so `DashboardBinding`'s own `Get.find<StorageManager>()`
      // resolves.
      final storage = _newStorageManager(db);
      // Default Smart Mode (`storage_policy_settings`'s own migration
      // default) -- the real, shipped default state, not a contrived one.
      await storage.runPass(
        nowEpochMs: DateTime.now().millisecondsSinceEpoch,
        apply: false,
      );
      Get.put<StorageManager>(storage, permanent: true);
      DashboardBinding().dependencies();
    });

    tearDown(() async {
      await stack.dispose();
      Get.reset();
    });

    testWidgets('dashboard', (tester) async {
      await dumpScreenProbe(
        tester,
        screenId: 'dashboard',
        screen: GetMaterialApp(home: const DashboardView()),
      );
    });
  });

  // ── E12-B06: `device-enrollment` ───────────────────────────────────────
  // Registers `design/screens/device-enrollment.md` (GAP-028, `source:
  // derived`) with `design/sources.yaml`/`make design-probe`, closing the
  // gap this bug describes: a derived contract with no probe block could
  // never be gated. Captures the `waiting` state (the route's own first
  // frame, `EnrollmentState.waiting` — `DeviceEnrollmentController`'s
  // default) as the screen's single registered state, mirroring every
  // other screen in this file (one `default` state each).
  group('screen probes — device-enrollment (make design-probe)', () {
    tearDown(() {
      // Disposes the controller `Get.put` below registered -- this is what
      // actually stops `DeviceEnrollmentController`'s `Timer.periodic`
      // before the test ends (same pattern
      // `device_enrollment_controller_test.dart` documents for its own
      // `Get.reset()` teardown).
      Get.reset();
    });

    testWidgets('device-enrollment', (tester) async {
      // `pollInterval` long enough that no poll tick can fire during this
      // probe's bounded pumps (`flutter_probe_dumper.dart` never calls an
      // unbounded `pumpAndSettle`) -- same technique
      // `device_enrollment_controller_test.dart`'s own
      // `test_E12_B07_button_present_and_tappable_on_first_frame_in_waiting`
      // uses to freeze the controller on its very first frame.
      final controller = DeviceEnrollmentController(
        accountUid: 'uid-probe',
        thisDeviceId: 'device-probe',
        firebaseMetadataService: _NeverGrantsFirebaseMetadataService(),
        pollInterval: const Duration(seconds: 30),
        maxPolls: 1000,
      );
      Get.put<DeviceEnrollmentController>(controller);

      await dumpScreenProbe(
        tester,
        screenId: 'device-enrollment',
        screen: GetMaterialApp(home: const DeviceEnrollmentView()),
      );

      // Cancels the `Timer.periodic` `onInit` started -- must happen before
      // this test body returns, or flutter_test's own end-of-test
      // pending-timer check fails it (`addTearDown`/the outer `tearDown()`
      // above both run too late for this specific assertion).
      controller.onClose();
    });
  });

  // ── E12-B06: `device-enrollment-approval` ──────────────────────────────
  // Registers `design/screens/device-enrollment-approval.md` (GAP-028,
  // `source: derived`) -- per that contract, this is a row prepended to
  // `/devices`'s own list (`DevicesController.pendingEnrollments`), not a
  // separate route/view. This is a SEPARATE setUp/db from the `devices`
  // group above (E12-B05's own fixture is out of this bug's scope, per its
  // own "What this fix does NOT do") -- relationships stay empty here so
  // the dump captures ONLY the pending-enrollment row's own elements
  // (DEA1-DEA9), same isolation principle the EARS fixture group below
  // already uses for its own purpose.
  group('screen probes — device-enrollment-approval (make design-probe)', () {
    late AppDatabase db;
    late TransportService transportService;

    setUp(() async {
      Get.testMode = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = RelationshipRepository(db);
      Get.put<RelationshipRepository>(repository, permanent: true);
      Get.put<BlockUseCase>(BlockUseCase(repository), permanent: true);
      final messenger =
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
      transportService = TransportService(
        binaryMessenger: messenger,
        messageChannelSuffix: 'device-enrollment-approval-probe',
      );
      Get.put<TransportService>(transportService, permanent: true);
      DevicesBinding().dependencies();
      // One pending enrollment request (DEA1-DEA9) -- no relationship row
      // for this device id, matching `device-enrollment-approval.md`'s own
      // "disjoint from an established relationship" note.
      Get.find<DevicesController>().pendingEnrollments.add(
            TransportDevice(
              id: 'device-pending-1',
              displayName: 'New Phone',
              type: TransportType.bluetooth,
            ),
          );
    });

    tearDown(() async {
      await transportService.dispose();
      await db.close();
      Get.reset();
    });

    testWidgets('device-enrollment-approval', (tester) async {
      await dumpScreenProbe(
        tester,
        screenId: 'device-enrollment-approval',
        screen: GetMaterialApp(home: const DevicesView()),
      );
    });
  });

  // ── 2. EARS falsification — a fixture, not `devices` ─────────────────────
  group('EARS-UI-1/2 — fixture falsification', () {
    testWidgets(
        'test_EARS_UI_1_flutter_probe_dumps_every_visible_element',
        (tester) async {
      await dumpScreenProbe(
        tester,
        screenId: '_fixture_faithful_a',
        screen: _fixture(),
      );
      // Real dart:io read — must go through runAsync for the same reason
      // dumpScreenProbe's own file write does (see flutter_probe_dumper.dart).
      final raw = await tester.runAsync(
        () => File('build/design-probe/_fixture_faithful_a.json').readAsString(),
      );
      final dump = jsonDecode(raw!) as Map<String, dynamic>;
      final elements = (dump['elements'] as List).cast<Map<String, dynamic>>();
      expect(elements, isNotEmpty);

      final title = elements.singleWhere((e) => e['text'] == 'Fixture Title');
      // E12-B13: 24px/w600 is heading-scale (`_headingRole`'s threshold),
      // and it's the first such style this fixture dump sees, so `heading:1`
      // — this fixture's own doc comment already calls it "a heading-ish
      // Text", this just makes the dumper agree.
      expect(title['role'], 'heading:1');
      // Resolved via DefaultTextStyle.merge, never the widget's own (null)
      // color — proving this dumps RESOLVED styles, not source constants.
      expect(title['style']['color'], 'rgb(0, 0, 255)');
      expect(title['style']['fontSize'], '24px');
      expect(title['style']['fontWeight'], '600');

      final button = elements.singleWhere((e) => e['role'] == 'button' && e['text'] == 'Go');
      expect(button['text'], 'Go');

      final panel = elements.singleWhere(
        (e) => e['role'] == 'generic' && e['style']['background'] == 'rgb(20, 40, 60)',
      );
      expect(panel['style']['background'], 'rgb(20, 40, 60)');
      expect(panel['style']['radius'], '8px');

      // E12-B13 round 2 (a): an `OnProcessButtonWidget` carrying a styled
      // `Text` label — the review's own falsification found the previous
      // suite's ONLY button assertion (`button['text']` above, on the
      // `GestureDetector`/plain-`Container` "Go" button) never exercises
      // `_firstLabelStyle`/`_isInteractiveBoundary`/the `borderRadius` read
      // at all, since that button has no `InkWell`/`OnProcessButtonWidget`
      // internals to swallow its label in the first place. Reverting issue
      // 2 (interactive-boundary swallowing) or issue 3 (button style
      // capture) in `flutter_probe_dumper.dart` must fail exactly this
      // block, and was verified to (see Run log).
      final submit = elements.singleWhere(
        (e) => e['role'] == 'button' && e['text'] == 'Submit',
      );
      expect(submit['text'], isNotEmpty);
      expect(submit['style']['color'], 'rgb(255, 0, 255)');
      expect(submit['style']['fontSize'], '16px');
      expect(submit['style']['fontWeight'], '500');
      // Non-zero and matches the widget's own `borderRadius: BorderRadius.
      // circular(6)` — not the pre-fix always-0px fallback.
      expect(submit['style']['radius'], '6px');

      // E12-B13 round 2 (b): an `Icon(..., size: N)` — reverting issue 4
      // (icon font-metadata capture) must fail this block.
      final icon = elements.singleWhere((e) => e['text'] == 'search');
      expect(icon['style']['fontSize'], '22px');
      expect(icon['style']['fontFamily'], isNotEmpty);

      // E12-B13 round 2 (c): a `Border(bottom: ...)`-only container (no top
      // border) — reverting issue 7 (border.bottom reading) must fail this
      // block: the pre-fix dumper only ever read `border.top`, which is
      // zero-width here, so it reported `borderWidth: '0px'`/the default
      // empty `borderColor` regardless of the real bottom border.
      final bottomBorderBox = elements.singleWhere(
        (e) => e['role'] == 'generic' && e['style']['borderColor'] == 'rgb(0, 170, 0)',
      );
      expect(bottomBorderBox['style']['borderWidth'], '3px');
      expect(bottomBorderBox['style']['borderColor'], 'rgb(0, 170, 0)');
    });

    testWidgets(
        'test_EARS_UI_2_faithful_fixture_passes_the_gate',
        (tester) async {
      await dumpScreenProbe(tester, screenId: '_fixture_faithful_b1', screen: _fixture());
      await dumpScreenProbe(tester, screenId: '_fixture_faithful_b2', screen: _fixture());

      final r = await _compare(tester, '_fixture_faithful_b1', '_fixture_faithful_b2');
      expect(r['missing'], 0, reason: 'unmutated fixture reported missing elements');
      expect(r['copy'], 0, reason: 'unmutated fixture reported copy drift');
      expect(r['style'], 0, reason: 'unmutated fixture reported style drift');
      expect(r['matched'], greaterThan(0));
    });

    testWidgets(
        'test_EARS_UI_2_drifted_fixture_fails_the_gate — delete an element',
        (tester) async {
      await dumpScreenProbe(tester, screenId: '_fixture_golden_del', screen: _fixture());
      await dumpScreenProbe(
        tester,
        screenId: '_fixture_mutated_del',
        screen: _fixture(hideButton: true),
      );
      final r = await _compare(tester, '_fixture_golden_del', '_fixture_mutated_del');
      expect(r['missing'], greaterThan(0),
          reason: 'deleting the button element must be a HARD "missing" finding');
    });

    testWidgets(
        'test_EARS_UI_2_drifted_fixture_fails_the_gate — one-character copy change',
        (tester) async {
      await dumpScreenProbe(tester, screenId: '_fixture_golden_text', screen: _fixture());
      await dumpScreenProbe(
        tester,
        screenId: '_fixture_mutated_text',
        screen: _fixture(labelSuffix: 'X'),
      );
      final r = await _compare(tester, '_fixture_golden_text', '_fixture_mutated_text');
      expect(r['copy'], greaterThan(0),
          reason: 'a one-character copy change must be a HARD copy-mismatch finding');
    });

    testWidgets(
        'test_EARS_UI_2_drifted_fixture_fails_the_gate — one colour channel',
        (tester) async {
      await dumpScreenProbe(tester, screenId: '_fixture_golden_color', screen: _fixture());
      await dumpScreenProbe(
        tester,
        screenId: '_fixture_mutated_color',
        screen: _fixture(colorChannelDelta: 40),
      );
      final r = await _compare(tester, '_fixture_golden_color', '_fixture_mutated_color');
      expect(r['style'], greaterThan(0),
          reason: 'a single colour-channel change must be a HARD style-delta finding');
    });

    testWidgets(
        'test_EARS_UI_2_drifted_fixture_fails_the_gate — radius +4px',
        (tester) async {
      await dumpScreenProbe(tester, screenId: '_fixture_golden_radius', screen: _fixture());
      await dumpScreenProbe(
        tester,
        screenId: '_fixture_mutated_radius',
        screen: _fixture(radiusDelta: 4),
      );
      final r = await _compare(tester, '_fixture_golden_radius', '_fixture_mutated_radius');
      expect(r['style'], greaterThan(0),
          reason: 'a 4px radius change must be a HARD style-delta finding');
    });
  });
}

/// The falsification fixture — deliberately tiny: a heading-ish `Text` under
/// a `DefaultTextStyle` (proves style RESOLUTION), a decorated `Container`
/// (a surface), and a `GestureDetector` button (an interactive element).
/// Mutation flags each isolate exactly one of the four EARS-UI-2 drifts.
Widget _fixture({
  bool hideButton = false,
  String labelSuffix = '',
  int colorChannelDelta = 0,
  double radiusDelta = 0,
}) {
  final panelColor = Color.fromARGB(255, 20 + colorChannelDelta, 40, 60);
  return MaterialApp(
    home: Scaffold(
      body: DefaultTextStyle(
        style: const TextStyle(color: Color(0xFF0000FF), fontFamily: 'Roboto'),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Fixture Title$labelSuffix',
              style: const TextStyle(fontSize: 24, fontWeight: FontWeight.w600),
            ),
            Container(
              width: 100,
              height: 40,
              decoration: BoxDecoration(
                color: panelColor,
                borderRadius: BorderRadius.circular(8 + radiusDelta),
              ),
            ),
            if (!hideButton)
              GestureDetector(
                onTap: () {},
                child: Container(
                  width: 80,
                  height: 32,
                  color: Colors.green,
                  child: const Center(child: Text('Go')),
                ),
              ),
            // E12-B13 round 2 (a): a real `OnProcessButtonWidget` — the
            // pre-fix dumper never read `OnProcessButtonWidget.borderRadius`
            // and its internal `InkWell` swallowed the label entirely, so
            // this button's own style/text were previously unrecoverable.
            SizedBox(
              width: 100,
              height: 36,
              child: OnProcessButtonWidget(
                backgroundColor: Colors.blueGrey,
                fontColor: const Color(0xFFFF00FF),
                iconColor: const Color(0xFFFF00FF),
                borderRadius: BorderRadius.circular(6),
                onTap: () async => null,
                child: const Text(
                  'Submit',
                  style: TextStyle(
                    color: Color(0xFFFF00FF),
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ),
            // E12-B13 round 2 (b): a standalone `Icon` — the pre-fix dumper
            // never read `Icon.size`/`IconData.fontFamily` at all.
            const Icon(Icons.search, size: 22),
            // E12-B13 round 2 (c): a `Border(bottom: ...)`-only container (no
            // top border) — the pre-fix dumper only ever read `border.top`,
            // which is zero-width here, so it reported the box as borderless.
            Container(
              width: 100,
              height: 20,
              decoration: const BoxDecoration(
                border: Border(
                  bottom: BorderSide(color: Color(0xFF00AA00), width: 3),
                ),
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Runs `design/tools/lib/compare.mjs` + `flutter_probe.mjs` (via `node`,
/// UNCHANGED) over two probe dumps and returns hard-finding counts. This is
/// the same comparison engine `design/tools/verify.mjs` runs — reused, not
/// reimplemented — so this test proves what the real gate would report.
Future<Map<String, dynamic>> _compare(
    WidgetTester tester, String goldenScreenId, String implScreenId) async {
  final root = Directory.current.path;
  final comparePath = p.join(root, 'design', 'tools', 'lib', 'compare.mjs');
  final flutterProbePath = p.join(root, 'design', 'tools', 'lib', 'flutter_probe.mjs');
  final goldenPath = p.join(root, 'build', 'design-probe', '$goldenScreenId.json');
  final implPath = p.join(root, 'build', 'design-probe', '$implScreenId.json');
  // Mirrors design/thresholds.yaml's current numeric values for this
  // self-contained fixture test — not read from that file (no YAML parser
  // dependency is added for it); the real gate always reads the real file.
  const tolerance = {
    'color': 'exact', 'font_size_px': 0.5, 'font_weight': 0,
    'radius_px': 1.0, 'spacing_px': 2.0,
  };

  const script = r'''
const { pathToFileURL } = require("node:url");
(async () => {
  // `node -e <script> arg1 arg2 ...` does NOT reserve argv[1] for a script
  // path the way `node file.js arg1 arg2 ...` does -- argv[0] is the node
  // binary and the passed args start immediately at argv[1] (verified
  // directly against this environment's Node v24; confirmed as the actual
  // cause of `_compare`'s "undefined is not valid JSON" failure, a
  // pre-existing off-by-one that only surfaced once the runAsync fix let
  // this script actually execute instead of hanging beforehand).
  const comparePath = process.argv[1];
  const flutterProbePath = process.argv[2];
  const goldenPath = process.argv[3];
  const implPath = process.argv[4];
  const tol = JSON.parse(process.argv[5]);
  const { matchElements, copyDiff, styleDeltas, tokenDiff } = await import(pathToFileURL(comparePath).href);
  const { loadFlutterProbe } = await import(pathToFileURL(flutterProbePath).href);
  const golden = loadFlutterProbe(goldenPath);
  const impl = loadFlutterProbe(implPath);
  const { pairs, missing } = matchElements(golden.elements, impl.elements);
  const copy = copyDiff(pairs, golden.elements, impl.elements, []);
  const style = styleDeltas(pairs, tol);
  const tokens = tokenDiff(golden.tokens, impl.tokens, tol);
  process.stdout.write(JSON.stringify({
    missing: missing.length, copy: copy.length, style: style.length,
    tokens: tokens.length, matched: pairs.length,
  }));
})();
''';

  // Process.run is real dart:io async I/O too — same runAsync requirement.
  final result = await tester.runAsync(() => Process.run('node', [
        '-e', script,
        comparePath, flutterProbePath, goldenPath, implPath, jsonEncode(tolerance),
      ]));
  if (result!.exitCode != 0) {
    fail('node comparison script failed: ${result.stderr}');
  }
  return jsonDecode(result.stdout as String) as Map<String, dynamic>;
}
