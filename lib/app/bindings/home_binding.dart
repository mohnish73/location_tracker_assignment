import 'package:get/get.dart';

import '../controllers/permission_controller.dart';
import '../controllers/tracking_controller.dart';

/// Lazily created when the home route is first built; lives as long as the home route.
class HomeBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<PermissionController>(() => PermissionController(Get.find()));
    Get.lazyPut<TrackingController>(() => TrackingController(Get.find(), Get.find()));
  }
}
