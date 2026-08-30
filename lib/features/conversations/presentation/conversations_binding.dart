// features/conversations/presentation — per-route GetX binding (E06-T10).
//
// `MessagingStack` is already registered as a permanent singleton by
// `app/bindings.dart` (E06-T03) — this task's `files:` fence deliberately
// does NOT include that file (task §4: "does NOT touch lib/app/bindings.dart
// ... leaving that file alone is what lets this task run in parallel with
// the backend chain"). `ConversationRepository` has no shared singleton of
// its own (E06-T09 never registered one), so it is constructed here, once
// per route visit, from the stack's already-registered `AppDatabase` and
// `selfDeviceId` — never a second `AppDatabase` (task file §2 of E06-T03/T09
// both name this as the exact defect class to avoid).
import 'package:get/get.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/features/conversations/presentation/conversations_controller.dart';
import 'package:nexora/features/messaging/data/conversation_repository.dart';

class ConversationsBinding extends Bindings {
  @override
  void dependencies() {
    final stack = Get.find<MessagingStack>();
    Get.lazyPut(
      () => ConversationsController(
        repo: ConversationRepository(stack.db, selfDeviceId: stack.selfDeviceId),
        crypto: stack.cryptoService,
        stack: stack,
      ),
    );
  }
}
