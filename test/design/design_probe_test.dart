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

import 'package:drift/drift.dart' hide isNull, Column;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:get/get.dart' hide Value;
import 'package:libsignal_protocol_dart/libsignal_protocol_dart.dart';
import 'package:nexora/core/background/background_stub.dart';
import 'package:nexora/core/background/power_state.dart';
import 'package:nexora/core/crypto/identity_key_hex.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/notifications/notification_settings_repository.dart';
import 'package:nexora/core/persistence/database.dart';
import 'package:nexora/core/persistence/notification_tables.dart'
    show NotificationPrivacyLevel;
import 'package:nexora/core/routing_engine/route_cost_calculator.dart'
    show TrafficProfile;
import 'package:nexora/core/routing_engine/routing_engine.dart';
import 'package:nexora/core/services/version_policy_service.dart';
import 'package:nexora/core/transport/generated/transport_api.g.dart'
    show TransportApi, TransportEventsApi;
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
import 'package:nexora/features/location/data/location_settings_repository.dart';
import 'package:nexora/features/login/data/device_identity_repository.dart';
import 'package:nexora/features/messaging/data/conversation_repository.dart';
import 'package:nexora/features/messaging/domain/delivery_state_machine.dart';
import 'package:nexora/features/recovery/presentation/device_enrollment_controller.dart';
import 'package:nexora/features/recovery/presentation/device_enrollment_view.dart';
import 'package:nexora/features/settings/about/presentation/about_settings_controller.dart';
import 'package:nexora/features/settings/about/presentation/about_settings_view.dart';
import 'package:nexora/features/settings/account/domain/sign_out_use_case.dart';
import 'package:nexora/features/settings/account/presentation/account_controller.dart';
import 'package:nexora/features/settings/account/presentation/account_view.dart';
import 'package:nexora/features/settings/account/presentation/sign_out_confirm_controller.dart';
import 'package:nexora/features/settings/account/presentation/sign_out_confirm_view.dart';
import 'package:nexora/features/settings/battery/presentation/battery_settings_controller.dart';
import 'package:nexora/features/settings/battery/presentation/battery_settings_view.dart';
import 'package:nexora/features/settings/network/presentation/network_settings_controller.dart';
import 'package:nexora/features/settings/network/presentation/network_settings_view.dart';
import 'package:nexora/features/settings/notifications/presentation/notification_settings_controller.dart';
import 'package:nexora/features/settings/notifications/presentation/notification_settings_view.dart';
import 'package:nexora/features/settings/presentation/settings_binding.dart';
import 'package:nexora/features/settings/presentation/settings_view.dart';
import 'package:nexora/features/settings/privacy/presentation/privacy_settings_controller.dart';
import 'package:nexora/features/settings/privacy/presentation/privacy_settings_view.dart';
import 'package:nexora/features/settings/security_center/data/security_records_repository.dart';
import 'package:nexora/features/settings/security_center/presentation/security_center_controller.dart';
import 'package:nexora/features/settings/security_center/presentation/security_center_view.dart';
import 'package:nexora/features/settings/storage/presentation/storage_settings_controller.dart';
import 'package:nexora/features/settings/storage/presentation/storage_settings_view.dart';
import 'package:nexora/features/groups/presentation/group_create_controller.dart';
import 'package:nexora/features/groups/data/group_repository.dart';
import 'package:nexora/core/persistence/group_tables.dart';
import 'package:nexora/features/groups/presentation/group_create_view.dart';
import 'package:nexora/features/groups/presentation/group_thread_controller.dart';
import 'package:nexora/features/groups/presentation/group_thread_view.dart';
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

/// `settings-account`'s own FIXED identity keypair, hex-encoded — see
/// `probe_settings_account_test.dart`'s own header (E15-T07 review finding
/// F1): `generateIdentityKeyPair()` mints a fresh random keypair on every
/// run, which would make AC10's fingerprint (and the golden that froze its
/// copy) non-deterministic. Copied verbatim from that file, not
/// re-derived — a fixture that seeds different data than the screen task
/// used produces a red gate that looks like a regression and is not
/// (`L-design-002`'s exact shape, this task's own §6 risk note).
const _fixedIdentityKeyPairHex =
    '0a21057070164f491bff2eca7be615843b0a529890157757216fe5a5dabcc6808f52'
    '741220389e9a1c1f7ef0868234225e4bbeaa1d678960ca49e7666f1c9954a6150c5b'
    '57';

IdentityKeyPair _fixedIdentityKeyPair() =>
    IdentityKeyPair.fromSerialized(hexDecodeBytes(_fixedIdentityKeyPairHex));

/// `settings-account`'s own `FirebaseMetadataService` test double — copied
/// verbatim from `probe_settings_account_test.dart` (private to that file,
/// reimplemented here under the same name for the same reason
/// `_NeverGrantsFirebaseMetadataService` above already is).
class _RespondingFirebaseMetadataService extends FirebaseMetadataService {
  _RespondingFirebaseMetadataService(this._ids);

  final Set<String> _ids;

  @override
  Future<Set<String>> readOwnDeviceIds(String uid) async => _ids;
}

void main() {
  // ── E15-T11: `settings` (the hub) ────────────────────────────────────────
  // E02-T03 built and gated this screen, but no probe block for it was ever
  // added to this file (E06-T01 wired `devices` as the proving screen and
  // every later screen added its own; `settings` itself was never one of
  // them) -- `make design-probe`/`make design-verify SCREEN=settings` were
  // consequently never runnable for the hub through this mechanism at all.
  // This task's own contract requires exactly that re-run (task §5: "this
  // task changes its behaviour, not its appearance; the gate must be re-run
  // to prove exactly that"), so it is added here, alongside the nine new
  // sub-screen blocks this task also owns.
  group('screen probes — settings (make design-probe)', () {
    setUp(() {
      Get.testMode = true;
      SettingsBinding().dependencies();
    });

    tearDown(() => Get.reset());

    testWidgets('settings', (tester) async {
      await dumpScreenProbe(
        tester,
        screenId: 'settings',
        screen: const GetMaterialApp(home: SettingsView()),
      );

      final raw = await tester.runAsync(
        () => File('build/design-probe/settings.json').readAsString(),
      );
      final dump = jsonDecode(raw!) as Map<String, dynamic>;
      expect(dump['renderError'], isNull);
    });
  });

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
      // E04-B19 (review round 1 finding 2): seed the new own-device-name
      // line this task added, so this shared fixture reflects the screen's
      // real displayed data shape rather than silently omitting it --
      // matches `devices_view_test.dart`'s own mock handler for the same
      // call.
      messenger.setMockMessageHandler(
        'dev.flutter.pigeon.nexora.TransportApi.getLocalDeviceName.devices-probe',
        (ByteData? message) async => TransportApi.pigeonChannelCodec
            .encodeMessage(<Object?>["Ahmed's Phone"]),
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
      // E06-B07: re-examined against design/screens/chat.md's own element
      // table (not just the task's prose framing of "8 messages", which
      // this task found does not survive contact with the actual golden —
      // see this task's Run log). The golden's message area (elements
      // 9-25) contains exactly FIVE buildable message bubbles (10, 12, 15,
      // 20, 23) plus ONE file-transfer bubble (16-19) that is GAP-010's own
      // already-accepted, deliberately-unbuilt content — so five is the
      // correct, honest count; there is no sixth real message to add
      // without either faking GAP-010 or inventing a message the golden
      // doesn't show. What WAS honestly closeable: the golden's three
      // outgoing bubbles (12, 20, 23) show three DIFFERENT delivery states
      // (`done_all` green = Read at 14, `done_all` grey = Delivered at 22,
      // `check` grey = Sent/Accepted/Stored at 25) — this fixture
      // previously seeded every message as `DeliveryState.accepted`,
      // collapsing all three ticks to the same grey `check` and producing
      // a real, closeable style-delta (tick colour) on top of the
      // genuinely-unclosable ones (GAP-003 placeholder copy, GAP-010's
      // bubble, and the probe-tooling gaps below). Real device ids/
      // timestamps and (since no session is ever established here) an
      // undecryptable body still won't literally match the design's copy
      // ("Ahmed"/"Are you free..."/etc.) — that is a real, expected finding
      // (design/gaps.md GAP-003), not something faked here to dodge it,
      // matching E06-T01/T10's own precedent.
      await repository.upsert('device-trusted', RelationshipState.trusted);
      final now = DateTime.now().millisecondsSinceEpoch;
      const senders = [
        'device-trusted', // incoming — mirrors element 10
        'self-probe-device', // outgoing — mirrors element 12 (tick: element 14, `done_all` green/Read)
        'device-trusted', // incoming — mirrors element 15
        'self-probe-device', // outgoing — mirrors element 20 (tick: element 22, `done_all` grey/Delivered)
        'self-probe-device', // outgoing — mirrors element 23 (tick: element 25, `check` grey/Sent)
      ];
      const deliveryStates = [
        DeliveryState.accepted, // incoming — irrelevant, no tick rendered
        DeliveryState.read,
        DeliveryState.accepted, // incoming — irrelevant, no tick rendered
        DeliveryState.delivered,
        DeliveryState.accepted, // "Sent/Accepted/Stored" per GAP-009's own mapping
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
                deliveryState: deliveryStates[i].name,
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

  // ── E15-T07: `settings-account` ──────────────────────────────────────────
  // Fixture seeding copied verbatim from `probe_settings_account_test.dart`
  // (E15-T11 §3 — reuse, never re-derive, `L-design-002`).
  group('screen probes — settings-account (make design-probe)', () {
    late AppDatabase db;
    late DeviceIdentityRepository repository;
    late AccountController controller;

    setUp(() async {
      Get.testMode = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = DeviceIdentityRepository(db);
      final id = await db.createDeviceIdentity('probe-device-local');
      await db.markSignedIn(id, accountUid: 'probe-account-uid');

      controller = AccountController(
        deviceIdentityRepository: repository,
        readIdentityKeyPair: () async => _fixedIdentityKeyPair(),
        firebaseMetadataService: _RespondingFirebaseMetadataService({
          'probe-device-local',
          'probe-device-linked',
        }),
      );
      Get.put<AccountController>(controller);
    });

    tearDown(() {
      Get.reset();
      return db.close();
    });

    testWidgets('settings-account', (tester) async {
      await tester.runAsync(() async {
        while (controller.accountUid.value == null ||
            controller.deviceFingerprint.value == null ||
            !controller.linkedDevicesLoaded.value) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });

      await dumpScreenProbe(
        tester,
        screenId: 'settings-account',
        screen: const GetMaterialApp(home: AccountView()),
      );

      final raw = await tester.runAsync(
        () => File(
          'build/design-probe/settings-account.json',
        ).readAsString(),
      );
      final dump = jsonDecode(raw!) as Map<String, dynamic>;
      expect(dump['renderError'], isNull);
    });
  });

  // ── E15-T07: `sign-out-confirm` ──────────────────────────────────────────
  // Fixture seeding copied verbatim from `probe_sign_out_confirm_test.dart`.
  group('screen probes — sign-out-confirm (make design-probe)', () {
    setUp(() {
      Get.testMode = true;
      Get.put<SignOutConfirmController>(
        SignOutConfirmController(signOutUseCase: SignOutUseCase()),
      );
    });

    tearDown(() => Get.reset());

    testWidgets('sign-out-confirm', (tester) async {
      await dumpScreenProbe(
        tester,
        screenId: 'sign-out-confirm',
        screen: const GetMaterialApp(home: SignOutConfirmView()),
      );

      final raw = await tester.runAsync(
        () => File(
          'build/design-probe/sign-out-confirm.json',
        ).readAsString(),
      );
      final dump = jsonDecode(raw!) as Map<String, dynamic>;
      expect(dump['renderError'], isNull);
    });
  });

  // ── E15-T05: `settings-privacy` ───────────────────────────────────────────
  // Fixture seeding copied verbatim from `probe_settings_privacy_test.dart`.
  group('screen probes — settings-privacy (make design-probe)', () {
    late AppDatabase db;
    late LocationSettingsRepository locationRepository;
    late NotificationSettingsRepository notificationRepository;
    late PrivacySettingsController controller;

    setUp(() async {
      Get.testMode = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      locationRepository = LocationSettingsRepository(db: db);
      notificationRepository = NotificationSettingsRepository(db: db);
      await locationRepository.writeGlobalEnabled(true);
      await locationRepository.writePeerEnabled('peer-nexora-1', true);
      await notificationRepository.setPrivacyLevel(
        NotificationPrivacyLevel.senderOnly,
      );
      controller = PrivacySettingsController(
        locationRepository: locationRepository,
        notificationRepository: notificationRepository,
      );
      Get.put<PrivacySettingsController>(controller);
      await pumpEventQueue();
    });

    tearDown(() {
      Get.reset();
      return db.close();
    });

    testWidgets('settings-privacy', (tester) async {
      await dumpScreenProbe(
        tester,
        screenId: 'settings-privacy',
        screen: const GetMaterialApp(home: PrivacySettingsView()),
      );

      final raw = await tester.runAsync(
        () => File(
          'build/design-probe/settings-privacy.json',
        ).readAsString(),
      );
      final dump = jsonDecode(raw!) as Map<String, dynamic>;
      expect(dump['renderError'], isNull);
    });
  });

  // ── E15-T06: `settings-security-center` ──────────────────────────────────
  // Fixture seeding copied verbatim from
  // `probe_settings_security_center_test.dart`.
  group('screen probes — settings-security-center (make design-probe)', () {
    late AppDatabase db;
    late SecurityRecordsRepository repository;
    late SecurityCenterController controller;

    setUp(() async {
      Get.testMode = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      await db
          .into(db.deviceRevocations)
          .insert(
            DeviceRevocationsCompanion.insert(
              deviceId: 'probe-device',
              revokedAt: DateTime.now().subtract(const Duration(hours: 2)),
              source: 'local',
            ),
          );
      await db
          .into(db.signalTrustedIdentities)
          .insert(
            SignalTrustedIdentitiesCompanion.insert(
              addressName: 'probe-trusted-device',
              addressDeviceId: 1,
              identityKey: Uint8List.fromList(const [1, 2, 3]),
            ),
          );
      await db
          .into(db.relationships)
          .insert(
            RelationshipsCompanion.insert(
              deviceId: 'probe-blocked-device',
              state: RelationshipState.blocked.name,
              updatedAt: DateTime.now(),
            ),
          );
      await db
          .into(db.rateLimitCounters)
          .insert(
            RateLimitCountersCompanion.insert(
              bucketKey: 'relay:probe-rate-limited-device',
              windowStartMs: 0,
              count: 3,
            ),
          );
      repository = SecurityRecordsRepository(db: db);
      controller = SecurityCenterController(repository: repository);
      Get.put<SecurityCenterController>(controller);
    });

    tearDown(() {
      Get.reset();
      return db.close();
    });

    testWidgets('settings-security-center', (tester) async {
      await tester.runAsync(() async {
        while (controller.revocations.value == null ||
            controller.trustedIdentities.value == null ||
            controller.blockedPeers.value == null ||
            controller.rateLimitDenials.value == null) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });

      await dumpScreenProbe(
        tester,
        screenId: 'settings-security-center',
        screen: const GetMaterialApp(home: SecurityCenterView()),
      );

      final raw = await tester.runAsync(
        () => File(
          'build/design-probe/settings-security-center.json',
        ).readAsString(),
      );
      final dump = jsonDecode(raw!) as Map<String, dynamic>;
      expect(dump['renderError'], isNull);
    });
  });

  // ── E15-T08: `settings-network` ───────────────────────────────────────────
  // Fixture seeding copied verbatim from `probe_settings_network_test.dart`.
  group('screen probes — settings-network (make design-probe)', () {
    final networkMessenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    late TransportService transport;
    late RoutingEngine routing;
    late NetworkSettingsController controller;

    setUp(() async {
      Get.testMode = true;
      transport = TransportService(
        binaryMessenger: networkMessenger,
        messageChannelSuffix: 'settings-network-probe',
      );
      routing = RoutingEngine(selfId: 'self-device');
      controller = NetworkSettingsController(transport: transport, routing: routing);
      Get.put<NetworkSettingsController>(controller);

      final device = TransportDevice(
        id: 'neighbor-1',
        displayName: 'neighbor-1',
        type: TransportType.bluetooth,
      );
      networkMessenger.handlePlatformMessage(
        'dev.flutter.pigeon.nexora.TransportEventsApi.onDeviceDiscovered.'
        'settings-network-probe',
        TransportEventsApi.pigeonChannelCodec.encodeMessage(<Object?>[device])!,
        (ByteData? _) {},
      );
      routing.recordLinkMeasurement(
        'neighbor-1',
        latencyMs: 38,
        lossRate: 0.02,
        batteryDrain: 0.0,
      );
      final route =
          routing.computeRoute('neighbor-1', TrafficProfile.interactive)!;
      routing.setActiveRoute(route);
      networkMessenger.handlePlatformMessage(
        'dev.flutter.pigeon.nexora.TransportEventsApi.onLinkQuality.'
        'settings-network-probe',
        TransportEventsApi.pigeonChannelCodec.encodeMessage(
          <Object?>['neighbor-1', 38, 0.02],
        )!,
        (ByteData? _) {},
      );
      await pumpEventQueue();
    });

    tearDown(() {
      Get.reset();
    });

    testWidgets('settings-network', (tester) async {
      await dumpScreenProbe(
        tester,
        screenId: 'settings-network',
        screen: const GetMaterialApp(home: NetworkSettingsView()),
      );

      final raw = await tester.runAsync(
        () => File('build/design-probe/settings-network.json').readAsString(),
      );
      final dump = jsonDecode(raw!) as Map<String, dynamic>;
      expect(dump['renderError'], isNull);
    });
  });

  // ── E15-T08: `settings-battery` ───────────────────────────────────────────
  // Fixture seeding copied verbatim from `probe_settings_battery_test.dart`.
  group('screen probes — settings-battery (make design-probe)', () {
    late BackgroundStub service;
    late BatterySettingsController controller;

    setUp(() async {
      Get.testMode = true;
      service = BackgroundStub();
      await service.start();
      service.emitPowerState(
        PowerState(
          deviceIdle: true,
          powerSaveMode: false,
          backgroundRestricted: false,
          ignoringBatteryOptimizations: true,
          screenLocked: false,
        ),
      );
      controller = BatterySettingsController(service: service);
      Get.put<BatterySettingsController>(controller);
      await pumpEventQueue();
    });

    tearDown(() {
      Get.reset();
    });

    testWidgets('settings-battery', (tester) async {
      await dumpScreenProbe(
        tester,
        screenId: 'settings-battery',
        screen: const GetMaterialApp(home: BatterySettingsView()),
      );

      final raw = await tester.runAsync(
        () => File('build/design-probe/settings-battery.json').readAsString(),
      );
      final dump = jsonDecode(raw!) as Map<String, dynamic>;
      expect(dump['renderError'], isNull);
    });
  });

  // ── E15-T09: `settings-storage` ───────────────────────────────────────────
  // Fixture seeding copied verbatim from `probe_settings_storage_test.dart`.
  group('screen probes — settings-storage (make design-probe)', () {
    late AppDatabase db;
    late StorageSettingsController controller;

    setUp(() {
      Get.testMode = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      controller = StorageSettingsController(
        settings: StorageSettingsRepository(db: db),
        log: StorageDecisionLog(db: db),
        inventory: StorageInventory(db: db, databaseFileBytes: () async => 0),
      );
      Get.put<StorageSettingsController>(controller);
    });

    tearDown(() {
      Get.reset();
      return db.close();
    });

    testWidgets('settings-storage', (tester) async {
      await dumpScreenProbe(
        tester,
        screenId: 'settings-storage',
        screen: const GetMaterialApp(home: StorageSettingsView()),
      );

      final raw = await tester.runAsync(
        () => File('build/design-probe/settings-storage.json').readAsString(),
      );
      final dump = jsonDecode(raw!) as Map<String, dynamic>;
      expect(dump['renderError'], isNull);
    });
  });

  // ── E15-T04: `settings-notifications` ────────────────────────────────────
  // Fixture seeding copied verbatim from
  // `probe_settings_notifications_test.dart`.
  group('screen probes — settings-notifications (make design-probe)', () {
    late AppDatabase db;
    late NotificationSettingsRepository repository;
    late NotificationSettingsController controller;

    setUp(() {
      Get.testMode = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      repository = NotificationSettingsRepository(db: db);
      controller = NotificationSettingsController(repository: repository);
      Get.put<NotificationSettingsController>(controller);
    });

    tearDown(() {
      Get.reset();
      return db.close();
    });

    testWidgets('settings-notifications', (tester) async {
      await dumpScreenProbe(
        tester,
        screenId: 'settings-notifications',
        screen: const GetMaterialApp(home: NotificationSettingsView()),
      );

      final raw = await tester.runAsync(
        () => File(
          'build/design-probe/settings-notifications.json',
        ).readAsString(),
      );
      final dump = jsonDecode(raw!) as Map<String, dynamic>;
      expect(dump['renderError'], isNull);
    });
  });

  // ── E15-T10: `settings-about` ─────────────────────────────────────────────
  // Fixture seeding copied verbatim from `probe_settings_about_test.dart`.
  group('screen probes — settings-about (make design-probe)', () {
    late AppDatabase db;
    late VersionPolicyService policyService;
    late AboutSettingsController controller;

    setUp(() async {
      Get.testMode = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      policyService = VersionPolicyService(database: db);
      await db
          .into(db.versionPolicyCache)
          .insertOnConflictUpdate(
            VersionPolicyCacheCompanion.insert(
              id: const Value(1),
              minimumSupportedBuild: 100,
              currentBuild: 250,
              updateAvailableBuild: 200,
              signature: 'probe-signature',
              updatedAt: 1700000000000,
            ),
          );
      controller = AboutSettingsController(
        versionPolicyService: policyService,
        versionProvider: () async => '9.9.9',
        buildNumberProvider: () async => 250,
        logEntriesProvider: () async => [
          DiagnosticEntry(
            code: 'version.installed_build_read_failed',
            timestamp: DateTime.utc(2026, 1, 1),
          ),
        ],
      );
      Get.put<AboutSettingsController>(controller);
    });

    tearDown(() {
      Get.reset();
      return db.close();
    });

    testWidgets('settings-about', (tester) async {
      await tester.runAsync(() async {
        while (controller.version.value == null ||
            !controller.policyLoaded.value ||
            !controller.logEntriesLoaded.value) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });

      await dumpScreenProbe(
        tester,
        screenId: 'settings-about',
        screen: const GetMaterialApp(home: AboutSettingsView()),
      );

      final raw = await tester.runAsync(
        () => File('build/design-probe/settings-about.json').readAsString(),
      );
      final dump = jsonDecode(raw!) as Map<String, dynamic>;
      expect(dump['renderError'], isNull);
    });
  });

  // ── E07-T15: `group-create` ─────────────────────────────────────
  // Seeded with two TRUSTED relationships so the contract's `default` state
  // renders (a populated member list). The other three relationship states
  // are seeded too, and must NOT appear -- the same filter EARS-GROUP-17
  // asserts in the controller test, re-proved here against the real widget.
  group('screen probes — group-create (make design-probe)', () {
    late AppDatabase db;
    late GroupCreateController controller;

    setUp(() async {
      Get.testMode = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      final repository = RelationshipRepository(db);
      await repository.upsert('MS-device-01', RelationshipState.trusted);
      await repository.upsert('AL-device-02', RelationshipState.trusted);
      await repository.upsert('device-allowed', RelationshipState.allowed);
      await repository.upsert('device-unknown', RelationshipState.unknown);
      await repository.upsert('device-blocked', RelationshipState.blocked);
      controller = GroupCreateController(
        relationships: repository,
        createGroup: ({required name, required memberDeviceIds}) async =>
            'probe-group',
        openThread: (_) async {},
      );
      Get.put<GroupCreateController>(controller);
    });

    tearDown(() {
      Get.reset();
      return db.close();
    });

    testWidgets('group-create', (tester) async {
      await tester.runAsync(() async {
        while (controller.state.value == GroupCreateState.loading) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
      });

      await dumpScreenProbe(
        tester,
        screenId: 'group-create',
        screen: const GetMaterialApp(home: GroupCreateView()),
      );

      final raw = await tester.runAsync(
        () => File('build/design-probe/group-create.json').readAsString(),
      );
      final dump = jsonDecode(raw!) as Map<String, dynamic>;
      expect(dump['renderError'], isNull);
      // The trusted-only filter, proved against the rendered tree rather
      // than only against the controller.
      expect(raw.contains('device-blocked'), isFalse);
      expect(raw.contains('device-allowed'), isFalse);
    });
  });


  // ── E07-T18: `chat-group` ───────────────────────────────────────
  // Seeded so the probe renders four of the contract's five states at once:
  // an attributed incoming bubble (G9), an outgoing bubble with NO
  // attribution, a blocked member's placeholder (G10, GAP-045 option (b)),
  // and a membership event line (G11).
  //
  // The two assertions at the end are the ones that matter: the approved
  // placeholder string IS in the rendered tree, and the blocked sender's
  // real body is NOT. A controller test proves the model withholds it;
  // this proves the widget tree never receives it either.
  group('screen probes — chat-group (make design-probe)', () {
    late AppDatabase db;
    late GroupThreadController controller;

    setUp(() async {
      Get.testMode = true;
      db = AppDatabase.forTesting(NativeDatabase.memory());
      final relationships = RelationshipRepository(db);
      await relationships.upsert('BLOCKED-device', RelationshipState.blocked);
      await db.into(db.groups).insert(
            GroupsCompanion.insert(
              id: 'g:probe',
              name: 'Family',
              createdByDeviceId: 'self-device',
              membershipEpoch: const Value(1),
              createdAt: 1000,
            ),
            mode: InsertMode.insertOrReplace,
          );
      await db.into(db.groupEvents).insert(
            GroupEventsCompanion.insert(
              id: 'e-probe',
              groupId: 'g:probe',
              epoch: 1,
              kind: GroupEventKind.memberAdded.name,
              actorDeviceId: 'MS-device-01',
              subjectDeviceId: const Value('AL-device-02'),
              createdAt: 2500,
            ),
          );
      await _insertProbeMessage(
          db, 'p1', 'MS-device-01', 2000, 'Dinner at 7 tonight');
      await _insertProbeMessage(db, 'p2', 'self-device', 3000, 'On my way');
      await _insertProbeMessage(db, 'p3', 'BLOCKED-device', 3500,
          'PROBE-BLOCKED-BODY-MUST-NOT-RENDER');
      controller = GroupThreadController(
        groupId: 'g:probe',
        repo: ConversationRepository(db, selfDeviceId: 'self-device'),
        groups: GroupRepository(db),
        relationships: relationships,
        send: ({required groupId, required body}) async => null,
      );
      Get.put<GroupThreadController>(controller);
    });

    tearDown(() {
      Get.reset();
      return db.close();
    });

    testWidgets('chat-group', (tester) async {
      // Everything is seeded in `setUp`, BEFORE `Get.put` constructs the
      // controller, so every emission the live subscription makes already
      // carries the full message set. An earlier draft seeded here instead
      // and the probe came back with a single row: the subscription's first
      // (empty) emission finished rendering LAST and overwrote the seeded
      // one. That race is also a real product bug -- fixed separately by
      // `render`'s generation guard -- but a probe should not depend on
      // that fix to be deterministic.
      await tester.runAsync(() async {
        await controller.load();
        while (controller.rows.length < 4) {
          await Future<void>.delayed(const Duration(milliseconds: 10));
        }
      });

      await dumpScreenProbe(
        tester,
        screenId: 'chat-group',
        screen: const GetMaterialApp(home: GroupThreadView()),
      );

      final raw = await tester.runAsync(
        () => File('build/design-probe/chat-group.json').readAsString(),
      );
      final dump = jsonDecode(raw!) as Map<String, dynamic>;
      expect(dump['renderError'], isNull);
      expect(
        raw.contains('Message hidden'),
        isTrue,
        reason: 'GAP-045 option (b), human-approved 2026-09-25',
      );
      expect(
        raw.contains('PROBE-BLOCKED-BODY-MUST-NOT-RENDER'),
        isFalse,
        reason: 'the blocked body must never reach the widget tree',
      );
      expect(
        raw.contains('unable to decrypt'),
        isFalse,
        reason: 'the human forbade implying a cryptographic failure',
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

  // ── E06-B08: dumper regression — icon-only tap targets, icon-name gaps ───
  // Proves both defects this bug fixes, and proves the "no double-emit on a
  // genuinely nested separate target" requirement its own fix must honour.
  // Confirmed failing on the PRE-FIX dumper (reverting the `_walk`/`_iconNames`
  // changes below reproduces the fail) — see this task's Run log for the
  // before/after run transcript.
  group('E06-B08 — icon-only tap targets are their own probe element', () {
    testWidgets(
        'test_E06_B08_icon_only_button_glyph_is_its_own_probe_element',
        (tester) async {
      await dumpScreenProbe(
        tester,
        screenId: '_fixture_icon_only_button',
        screen: _iconOnlyButtonFixture(),
      );
      final raw = await tester.runAsync(
        () => File('build/design-probe/_fixture_icon_only_button.json')
            .readAsString(),
      );
      final dump = jsonDecode(raw!) as Map<String, dynamic>;
      final elements = (dump['elements'] as List).cast<Map<String, dynamic>>();

      // The `InkWell` itself is still captured as ONE button-role element —
      // empty text, since an icon-only target has no `Text` label to derive
      // one from (unchanged behaviour, not this bug's concern).
      final button = elements.singleWhere((e) => e['role'] == 'button');
      expect(button['text'], isEmpty);

      // Defect 1: pre-fix, `more_vert`'s `Icon` is walked (insideInteractive)
      // but the `!insideInteractive` gate drops it — this `where(...)` finds
      // nothing at all pre-fix. Post-fix it must be its own nested element.
      expect(
        elements.where((e) => e['text'] == 'more_vert'),
        hasLength(1),
        reason: 'an icon-only tap target\'s glyph must be its own probe '
            'element, matching the DOM golden\'s nested-span model',
      );

      // Defect 2: pre-fix, `_iconNames` has no entry for `check`/`done_all`,
      // so these (bare `Icon`s, already walked and emitted even pre-fix)
      // dump with empty `text` — this assertion fails pre-fix.
      expect(elements.where((e) => e['text'] == 'check'), hasLength(1));
      expect(elements.where((e) => e['text'] == 'done_all'), hasLength(1));
    });

    testWidgets(
        'test_E06_B08_nested_separate_tap_target_resolves_once_not_double_emitted',
        (tester) async {
      await dumpScreenProbe(
        tester,
        screenId: '_fixture_nested_tap_target',
        screen: _nestedIconButtonFixture(),
      );
      final raw = await tester.runAsync(
        () => File('build/design-probe/_fixture_nested_tap_target.json')
            .readAsString(),
      );
      final dump = jsonDecode(raw!) as Map<String, dynamic>;
      final elements = (dump['elements'] as List).cast<Map<String, dynamic>>();

      // Two genuinely separate tap targets — the outer `InkWell` and the
      // nested `IconButton` — must each resolve to their OWN button-role
      // element (the `_isInteractiveBoundary` relaxation this fix adds to
      // `_walk`'s own interactive gate), not collapse into one.
      final buttons = elements.where((e) => e['role'] == 'button').toList();
      expect(buttons, hasLength(2));

      // The outer button's own direct icon child (`chat`) is captured
      // exactly once, and the inner `IconButton`'s own icon (`close`) is
      // ALSO captured exactly once — never zero (dropped) and never twice
      // (double-emitted once under the outer button's scan and again under
      // the inner one's).
      expect(elements.where((e) => e['text'] == 'chat'), hasLength(1));
      expect(elements.where((e) => e['text'] == 'close'), hasLength(1));
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

/// E06-B08 regression fixture: an icon-only tap target (no `Text` label —
/// the exact shape of `chat_view.dart`'s `_IconTapTarget`/`_RoundIconButton`
/// and every screen's own back-arrow/kebab/add/mic buttons), plus two bare
/// `Icon`s outside any interactive wrapper using the two ligatures
/// `_iconNames` was missing (`check`/`done_all`, `chat_view.dart`'s own
/// delivery-tick glyphs).
Widget _iconOnlyButtonFixture() {
  return MaterialApp(
    home: Scaffold(
      body: Column(
        children: [
          InkWell(
            onTap: () {},
            child: const SizedBox(
              width: 44,
              height: 44,
              child: Icon(Icons.more_vert, size: 24),
            ),
          ),
          const Icon(Icons.check, size: 18),
          const Icon(Icons.done_all, size: 18),
        ],
      ),
    ),
  );
}

/// E06-B08 regression fixture: a genuinely separate, independently-tappable
/// `IconButton` nested two levels inside an outer `InkWell`'s own tap
/// target — proving the fix does not double-emit (or drop) either icon once
/// `_walk`'s `insideInteractive` gate is relaxed for `_isInteractiveBoundary`
/// widgets. No such nesting currently exists in this app's own screens (its
/// own convention is one tap target per row, per `_isInteractiveBoundary`'s
/// doc comment) — this is deliberately synthetic, defensive coverage for the
/// shape the task's own Definition of Done calls out by name.
Widget _nestedIconButtonFixture() {
  return MaterialApp(
    home: Scaffold(
      body: InkWell(
        onTap: () {},
        child: SizedBox(
          width: 120,
          height: 60,
          child: Row(
            children: [
              const Icon(Icons.chat, size: 20),
              IconButton(
                icon: const Icon(Icons.close, size: 18),
                onPressed: () {},
              ),
            ],
          ),
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

/// E07-T18's probe seed. `plaintextPayload` is populated so the controller
/// takes the E04-B20 persisted-body path rather than attempting a real
/// group decrypt inside a probe.
Future<void> _insertProbeMessage(
  AppDatabase db,
  String id,
  String sender,
  int createdAt,
  String body,
) =>
    db.into(db.messages).insert(
          MessagesCompanion.insert(
            id: id,
            conversationId: 'g:probe',
            senderDeviceId: sender,
            sequenceNumber: createdAt,
            ciphertext: Uint8List(0),
            createdAt: createdAt,
            deliveryState: DeliveryState.accepted.name,
            plaintextPayload: Value(Uint8List.fromList(utf8.encode(body))),
          ),
        );
