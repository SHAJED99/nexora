// features/chat/presentation — per-route GetX binding (E06-T11).
//
// Same pattern `ConversationsBinding` (E06-T10) already established:
// `MessagingStack` is already registered as a permanent singleton by
// `app/bindings.dart` (E06-T03) — this task's `files:` fence does NOT touch
// that file beyond the single `coordinator.start()` call named in the task's
// §3 (added at that file's own registration site, not here). Every other
// dependency below is one of the stack's own already-constructed members —
// never a second `AppDatabase`, `PrekeyExchange`, `CryptoService`,
// `SendMessageUseCase` or `DeliveryAckService`.
import 'package:get/get.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/features/chat/presentation/chat_controller.dart';
import 'package:nexora/features/messaging/data/conversation_repository.dart';

class ChatBinding extends Bindings {
  @override
  void dependencies() {
    final stack = Get.find<MessagingStack>();
    final conversationId = Get.parameters['id'] ?? '';
    Get.lazyPut(
      () => ChatController(
        conversationId: conversationId,
        repo: ConversationRepository(stack.db, selfDeviceId: stack.selfDeviceId),
        send: stack.sendMessage,
        sessions: stack.prekeyExchange,
        crypto: stack.cryptoService,
        acks: stack.deliveryAckService,
      ),
    );
  }
}
