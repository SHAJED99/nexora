// features/dashboard/presentation — per-route GetX binding (E06-T12).
//
// `MessagingStack` and `LinkQualityFeed` are already registered as permanent
// singletons by `app/bindings.dart` (E06-T03/E06-T04) — this task's `files:`
// fence deliberately does NOT include that file (same reasoning
// `conversations_binding.dart`/`chat_binding.dart` already document: leaving
// it alone lets this task run without re-opening the backend composition
// root). `ConversationRepository` has no shared singleton of its own
// (E06-T09 never registered one), so it is constructed here, once per route
// visit, from the stack's already-registered `AppDatabase` and
// `selfDeviceId` — never a second `AppDatabase`.
import 'package:get/get.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/routing_engine/link_quality_feed.dart';
import 'package:nexora/features/dashboard/presentation/dashboard_controller.dart';
import 'package:nexora/features/messaging/data/conversation_repository.dart';

class DashboardBinding extends Bindings {
  @override
  void dependencies() {
    final stack = Get.find<MessagingStack>();
    Get.lazyPut(
      () => DashboardController(
        stack: stack,
        repo: ConversationRepository(stack.db, selfDeviceId: stack.selfDeviceId),
        links: Get.find<LinkQualityFeed>(),
        crypto: stack.cryptoService,
      ),
    );
  }
}
