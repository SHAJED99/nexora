// app/main.dart — entry point (docs/conventions.md "Project structure").
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:nexora/core/observability/observability_service.dart';
import 'bindings.dart';
import 'routes.dart';

Future<void> main() async {
  await ObservabilityService.instance.init();
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
