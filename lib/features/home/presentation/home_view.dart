// features/home/presentation — genesis placeholder screen, no design
// contract (see home_controller.dart). Later epics replace this with the
// real dashboard (design/screens/dashboard.md).
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'home_controller.dart';

class HomeView extends GetView<HomeController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Obx(() {
          final identity = controller.deviceIdentity.value;
          return Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.check_circle, color: Colors.green, size: 48),
              const SizedBox(height: 16),
              Text(
                identity == null
                    ? 'Signed in'
                    : 'Signed in — device ${identity.deviceId.substring(0, 8)}',
              ),
            ],
          );
        }),
      ),
    );
  }
}
