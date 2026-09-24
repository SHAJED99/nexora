// features/groups/presentation — `/groups/new`'s binding (E07-T15).
//
// `GroupCreateController` defaults every collaborator in its own constructor
// (the `RelationshipRepository` from Get, the create call from
// `MessagingStack.groupMembershipService`), so this binding only has to
// register the controller itself — the same shape `DevicesBinding` and
// `SettingsBinding` use.
import 'package:get/get.dart';

import 'group_create_controller.dart';

class GroupCreateBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<GroupCreateController>(GroupCreateController.new);
  }
}
