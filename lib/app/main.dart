// app/main.dart — entry point (docs/conventions.md "Project structure").
//
// E06-T03: the messaging composition root now assembles here, before
// `runApp` — AppDatabase -> the local device identity -> MessagingStack
// .create() (which itself does DriftSignalProtocolStore -> CryptoService
// .init(store) -> IdentityService.ensureLocalIdentity() ->
// ensureSignedPreKey() -> replenishOneTimePreKeys(), task file §3). Every
// step's failure is handled explicitly: `MessagingStack.create` itself never
// throws (a degraded device comes back as `status.unavailable`, never a
// crash — see `messaging_stack.dart`), so nothing here needs its own
// try/catch beyond that already-honest contract.
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nexora/core/messaging/messaging_stack.dart';
import 'package:nexora/core/observability/observability_service.dart';
import 'package:nexora/core/persistence/database.dart';
import 'bindings.dart';
import 'routes.dart';

Future<void> main() async {
  // Required before any platform-channel call (Firebase.initializeApp()
  // included) — without this, `main()` throws
  // "Binding has not yet been initialized" before runApp() ever runs.
  WidgetsFlutterBinding.ensureInitialized();
  await ObservabilityService.instance.init();
  // E01-T01: account identity only (ADR-0005) — Google Authentication via
  // Firebase Auth needs the default app initialized before any sign-in
  // attempt. No explicit FirebaseOptions: Android reads them from
  // `android/app/google-services.json` via the Google Services Gradle
  // plugin at build time.
  await Firebase.initializeApp();

  // The single app-wide AppDatabase (task file §5) — constructed here,
  // never inside `AppBinding`/`MessagingStack.create`, so there is
  // structurally only ever one (task file §2).
  final db = AppDatabase();

  // ADR-0005: device identity is local, independent of the Firebase
  // session above. A fresh install has none yet — it is only created
  // during sign-in (`LoginController._signIn`) — in which case
  // `MessagingStack.create` itself reports `unavailable` rather than this
  // file inventing a placeholder id (see `messaging_stack.dart`'s header,
  // judgment call 3).
  final localIdentity = await db.latestDeviceIdentity();
  final selfDeviceId = localIdentity?.deviceId ?? '';

  final messagingStack = await MessagingStack.create(
    db: db,
    selfDeviceId: selfDeviceId,
  );

  runApp(NexoraApp(db: db, messagingStack: messagingStack));
}

class NexoraApp extends StatelessWidget {
  const NexoraApp({super.key, required this.db, required this.messagingStack});

  final AppDatabase db;
  final MessagingStack messagingStack;

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'NEXORA',
      debugShowCheckedModeBanner: false,
      initialBinding: AppBinding(db: db, messagingStack: messagingStack),
      initialRoute: Routes.welcome,
      getPages: appPages,
    );
  }
}
