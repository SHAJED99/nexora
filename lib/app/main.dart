// app/main.dart — entry point (docs/conventions.md "Project structure").
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nexora/core/observability/observability_service.dart';
import 'bindings.dart';
import 'routes.dart';

Future<void> main() async {
  await ObservabilityService.instance.init();
  // E01-T01: account identity only (ADR-0005) — Google Authentication via
  // Firebase Auth needs the default app initialized before any sign-in
  // attempt. No explicit FirebaseOptions: Android reads them from
  // `android/app/google-services.json` via the Google Services Gradle
  // plugin at build time.
  await Firebase.initializeApp();
  runApp(const NexoraApp());
}

class NexoraApp extends StatelessWidget {
  const NexoraApp({super.key});

  @override
  Widget build(BuildContext context) {
    return GetMaterialApp(
      title: 'NEXORA',
      debugShowCheckedModeBanner: false,
      initialBinding: AppBinding(),
      initialRoute: Routes.welcome,
      getPages: appPages,
    );
  }
}
