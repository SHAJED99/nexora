// app/routes.dart — named routes, bound to design/screens/*.md ids
// (docs/conventions.md "Naming"). See docs/routes.md for the full table
// including the routes not yet wired (owned by their feature epics).
import 'package:get/get.dart';
import 'package:nexora/features/chat/presentation/chat_binding.dart';
import 'package:nexora/features/chat/presentation/chat_view.dart';
import 'package:nexora/features/conversations/presentation/conversations_binding.dart';
import 'package:nexora/features/conversations/presentation/conversations_view.dart';
import 'package:nexora/features/devices/presentation/devices_binding.dart';
import 'package:nexora/features/devices/presentation/devices_view.dart';
import 'package:nexora/features/home/presentation/home_view.dart';
import 'package:nexora/features/login/presentation/login_view.dart';
import 'package:nexora/features/settings/presentation/settings_binding.dart';
import 'package:nexora/features/settings/presentation/settings_view.dart';
import 'package:nexora/features/welcome/presentation/welcome_view.dart';

abstract final class Routes {
  static const welcome = '/welcome';
  static const login = '/login';

  /// Genesis placeholder only — not a design-contracted screen. Superseded
  /// by `/dashboard` (design/screens/dashboard.md) in a feature epic.
  static const home = '/home';

  /// design/screens/devices.md (E02-T02).
  static const devices = '/devices';

  /// design/screens/settings.md (E02-T03).
  static const settings = '/settings';

  /// design/screens/conversations.md (E06-T10).
  static const conversations = '/conversations';

  /// design/screens/chat.md (E06-T11). `id` = `conversationId` =
  /// peer device id (T09 §2).
  static const chat = '/chat/:id';
}

final appPages = <GetPage<dynamic>>[
  GetPage<dynamic>(name: Routes.welcome, page: () => const WelcomeView()),
  GetPage<dynamic>(name: Routes.login, page: () => const LoginView()),
  GetPage<dynamic>(name: Routes.home, page: () => const HomeView()),
  GetPage<dynamic>(
    name: Routes.devices,
    page: () => const DevicesView(),
    binding: DevicesBinding(),
  ),
  GetPage<dynamic>(
    name: Routes.settings,
    page: () => const SettingsView(),
    binding: SettingsBinding(),
  ),
  GetPage<dynamic>(
    name: Routes.conversations,
    page: () => const ConversationsView(),
    binding: ConversationsBinding(),
  ),
  GetPage<dynamic>(
    name: Routes.chat,
    page: () => const ChatView(),
    binding: ChatBinding(),
  ),
];
