// features/groups/presentation — `/groups/:id`'s binding (E07-T18).
//
// Unlike `GroupCreateBinding`, this controller needs the group id from the
// route, so the binding reads `Get.parameters` rather than registering a
// zero-argument constructor.
import 'package:get/get.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/features/groups/data/group_repository.dart';
import 'package:nexora/features/groups/presentation/group_thread_controller.dart';
import 'package:nexora/features/messaging/data/conversation_repository.dart';
import 'package:nexora/features/trust/data/relationship_repository.dart';

class GroupThreadBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<GroupThreadController>(() {
      final stack = Get.find<MessagingStack>();
      return GroupThreadController(
        groupId: Get.parameters['id'] ?? '',
        repo: ConversationRepository(
          stack.db,
          selfDeviceId: stack.selfDeviceId,
        ),
        groups: GroupRepository(stack.db),
        relationships: Get.find<RelationshipRepository>(),
      );
    });
  }
}
