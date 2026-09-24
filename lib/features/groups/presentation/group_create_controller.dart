// features/groups/presentation — the `/groups/new` controller (E07-T15),
// built against design/screens/group-create.md.
//
// The screen's whole job is FR-GROUP-001/FR-GROUP-002's precondition: a group
// has to exist before roles or Owner powers mean anything. Trust is READ here
// and never assigned; whether a blocked peer may be added is `E07-T03`'s
// composition of `GroupPermissions` with `RelationshipRepository`, never a
// rule re-decided in a widget (contract §Notes).
import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:get/get.dart';
import 'package:nexora/core/auth/google_auth_service.dart' show AppFailure;
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/features/conversations/presentation/conversations_controller.dart'
    show initialsOf;
import 'package:nexora/features/trust/data/relationship_repository.dart';
import 'package:nexora/features/trust/domain/relationship.dart';

/// The single backend call `/groups/new` makes — `GroupMembershipService`'s
/// own `createGroup` signature, named so it can be injected.
typedef CreateGroup = Future<String> Function({
  required String name,
  required List<String> memberDeviceIds,
});

/// One selectable member row — contract elements GC8-GC14.
///
/// [displayName] is the device id, and [initials] derives from it, because
/// this schema still has no display-name source (GAP-003, the same absence
/// `conversations_controller.dart` documents and renders the same way). It is
/// the honest stand-in, not a placeholder to be replaced by a fabricated name.
class MemberRow {
  /// The peer's device id — what `createGroup` receives.
  final String deviceId;

  /// GC9, the row title. Equal to [deviceId] pre-E04 display names.
  final String displayName;

  /// GC8's `MS`-style initials.
  final String initials;

  const MemberRow({
    required this.deviceId,
    required this.displayName,
    required this.initials,
  });

  factory MemberRow.fromRelationship(Relationship r) => MemberRow(
        deviceId: r.deviceId,
        displayName: r.deviceId,
        initials: initialsOf(r.deviceId),
      );
}

/// Which of the contract's four §States the view renders.
///
/// `loading` is deliberately *not* a spinner: the design draws no spinner or
/// skeleton anywhere across its contracts, so this state is the frame with an
/// unpopulated list (contract §States 3). `error` leaves the entered name and
/// the selection intact (contract §States 4).
enum GroupCreateState { loading, empty, data, error }

class GroupCreateController extends GetxController {
  GroupCreateController({
    RelationshipRepository? relationships,
    CreateGroup? createGroup,
    Future<void> Function(String groupId)? openThread,
  })  : _relationships = relationships ?? Get.find<RelationshipRepository>(),
        _createGroup = createGroup ?? _defaultCreateGroup,
        _openThread = openThread ?? _defaultOpenThread;

  final RelationshipRepository _relationships;

  /// The one backend call this screen makes, as a narrow seam rather than the
  /// whole service. `GroupMembershipService`'s constructor requires a live
  /// `MessagingStack`, so depending on the class itself would force every
  /// controller test to stand up the entire messaging stack to assert a
  /// button's enabled rule. The default below is the real service, resolved
  /// exactly as a direct dependency would have been.
  final CreateGroup _createGroup;

  /// `GroupMembershipService` is **not** separately registered in Get — it is
  /// owned by `MessagingStack` (`messaging_stack.dart:375`, exposed at :565),
  /// and `bindings.dart:159` is what puts the stack itself. Resolving the
  /// service directly would throw at runtime while compiling perfectly.
  static Future<String> _defaultCreateGroup({
    required String name,
    required List<String> memberDeviceIds,
  }) {
    return Get.find<MessagingStack>().groupMembershipService.createGroup(
          name: name,
          memberDeviceIds: memberDeviceIds,
        );
  }

  /// Navigation is injected so the controller is testable without a
  /// `GetMaterialApp` — the same seam `DeviceEnrollmentController` uses.
  ///
  /// The seam is a convenience, not the contract: `E07-B05` shipped because
  /// every test asserted against an injected spy and nothing ever exercised
  /// [_defaultOpenThread], which is the route a real user takes. The default
  /// now has its own test.
  final Future<void> Function(String groupId) _openThread;

  /// Where a successful create actually lands.
  ///
  /// **Not `/chat/<groupId>`** (`E07-B05`). `ChatController` is built
  /// exclusively for a 1:1 conversation — it treats `conversationId` as a
  /// Signal *peer device id* and runs an X3DH handshake against it, so a
  /// group id there yields undecryptable bubbles in and a non-retryable send
  /// failure out. `E07-B01` measured exactly that, and the human closed that
  /// door at the `bug_priorities` gate on 2026-09-02 (P1, fix direction (a)).
  /// This is the same door, reached from the other side.
  ///
  /// **`/groups/:id` as of `E07-T18`.** When `E07-B05` was fixed the group
  /// thread did not exist (`GAP-020` was gated on `OQ-E07-13`), so the
  /// honest destination was Conversations — the screen that at least showed
  /// the group that had just been created. The human answered `OQ-E07-13` on
  /// 2026-09-25 and the thread now exists, so a successful create lands
  /// where `group-create.md` always said it should: in the new group's own
  /// thread.
  ///
  /// `Get.offNamed`, not `Get.toNamed`: the create screen is *replaced*, so
  /// backing out of the thread does not return the user to a form for a
  /// group they have already made.
  static const successRoute = '/groups/:id';

  /// **Not awaited** (`E07-B05`, second finding). `Get.offNamed` returns a
  /// future that completes when the route it pushes is *popped*, not when the
  /// navigation happens. Awaiting it suspends [create] indefinitely, so its
  /// `finally` never runs and `submitting` never returns to false — the
  /// create button stays disabled for the life of the screen. The shipped
  /// `Get.toNamed` had the same shape; no test noticed, because every test
  /// injected a seam that completed immediately.
  ///
  /// `groupId` is substituted into [successRoute]. It was unused between
  /// `E07-B05` and `E07-T18`, when there was no per-group destination to
  /// carry it to; that day has arrived, and this is where it mattered.
  ///
  /// The error handler is not decoration. `unawaited` on its own discards a
  /// navigation failure entirely; routing it through [FlutterError.reportError]
  /// puts it on the framework's own error channel instead. Be honest about
  /// what that buys: nothing in this app currently forwards
  /// `FlutterError.onError` to `ObservabilityService`, so in release this is
  /// still only a non-silent failure, not a reported one. Wiring that channel
  /// is its own task and is out of this bug's `files:` fence.
  static Future<void> _defaultOpenThread(String groupId) async {
    // `offNamed` returns a NULLABLE future -- GetX hands back null when it
    // declines to navigate at all. That is a third outcome, distinct from
    // success and from a thrown error, and it is silent either way.
    final navigation =
        Get.offNamed<dynamic>(successRoute.replaceFirst(':id', groupId));
    if (navigation == null) {
      return;
    }
    unawaited(
      navigation.catchError((
        Object error,
        StackTrace stack,
      ) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'group_create_controller',
            context: ErrorDescription(
              'navigating to the thread for $groupId after a successful '
              'group create',
            ),
          ),
        );
        return null;
      }),
    );
  }

  /// Every trusted relationship, as selectable rows (GC8-GC14).
  final RxList<MemberRow> members = <MemberRow>[].obs;

  /// The device ids currently ticked. UI state only.
  final RxSet<String> selected = <String>{}.obs;

  /// GC5's field contents.
  final RxString name = ''.obs;

  final Rx<GroupCreateState> state = GroupCreateState.loading.obs;

  /// True while [create] is in flight, so the action cannot be double-fired.
  final RxBool submitting = false.obs;

  /// GC7's enabled/disabled rule, stated by the contract's `default` state:
  /// disabled until a non-empty name AND at least one selected member exist.
  /// `FR-GROUP-002` presupposes a named group with members.
  bool get canCreate =>
      name.value.trim().isNotEmpty && selected.isNotEmpty && !submitting.value;

  @override
  void onInit() {
    super.onInit();
    load();
  }

  /// EARS-GROUP-17 — trusted relationships become member rows; nothing else
  /// does. `allowed`, `unknown` and `blocked` are all excluded: the contract's
  /// row treatment is `devices.md`'s *trusted* state-label pair (GC10/GC11,
  /// copy `Trusted Node`), so rendering a non-trusted peer in it would assert
  /// a trust this side has not given.
  Future<void> load() async {
    state.value = GroupCreateState.loading;
    final all = await _relationships.listAll();
    final trusted = all
        .where((r) => r.state == RelationshipState.trusted)
        .map(MemberRow.fromRelationship)
        .toList();
    members.assignAll(trusted);
    // A selection can outlive a reload only if its peer is still trusted.
    selected.removeWhere((id) => !trusted.any((m) => m.deviceId == id));
    state.value =
        trusted.isEmpty ? GroupCreateState.empty : GroupCreateState.data;
  }

  /// GC13 <-> GC14. Pure UI state.
  void toggle(String deviceId) {
    if (selected.contains(deviceId)) {
      selected.remove(deviceId);
    } else {
      selected.add(deviceId);
    }
  }

  void setName(String value) => name.value = value;

  /// EARS-GROUP-19 / EARS-GROUP-20 — the screen's one action.
  ///
  /// `createGroup` **throws** `AppFailure` rather than returning a nullable
  /// failure like every sibling method on that service
  /// (`group_membership_service.dart:352` documents exactly this, and the
  /// reason: its return type is a bare group id). Writing the usual
  /// `final f = await ...; if (f != null)` here would compile and silently
  /// never catch, which is this task's §6 risk 2.
  Future<void> create() async {
    if (!canCreate) return;
    submitting.value = true;
    try {
      final groupId = await _createGroup(
        name: name.value.trim(),
        memberDeviceIds: selected.toList(),
      );
      await _openThread(groupId);
    } on AppFailure {
      // Contract §States 4: the frame is unchanged, one line renders, and the
      // entered name and the selection are NOT cleared. Nothing below resets
      // `name` or `selected`, and that is the assertion EARS-GROUP-20 makes.
      state.value = GroupCreateState.error;
    } finally {
      submitting.value = false;
    }
  }
}
