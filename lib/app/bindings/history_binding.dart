import 'package:get/get.dart';

import '../controllers/history_controller.dart';

/// Created when the history route opens and disposed when it closes, so the
/// list is always re-read from SQLite on entry.
class HistoryBinding extends Bindings {
  @override
  void dependencies() {
    Get.lazyPut<HistoryController>(() => HistoryController(Get.find(), Get.find()));
  }
}
