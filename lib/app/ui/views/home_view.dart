import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../../controllers/tracking_controller.dart';
import '../../routes/app_routes.dart';
import '../widgets/last_location_card.dart';
import '../widgets/permission_panel.dart';
import '../widgets/tracking_control_card.dart';

class HomeView extends GetView<TrackingController> {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Location Tracker'),
        actions: [
          IconButton(
            tooltip: 'History',
            icon: const Icon(Icons.history),
            onPressed: () => Get.toNamed(Routes.history),
          ),
        ],
      ),

      body: RefreshIndicator(
        onRefresh: controller.loadInitialState,
        child: ListView(
          padding: const EdgeInsets.all(12),
          children: [
            const PermissionPanel(),
            const TrackingControlCard(),
            const LastLocationCard(),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: () => Get.toNamed(Routes.history),
              icon: const Icon(Icons.list_alt),
              label: const Text('View last 50 records'),
            ),
          ],
        ),
      ),
    );
  }
}
