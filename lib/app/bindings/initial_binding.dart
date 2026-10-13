import 'package:get/get.dart';

import '../data/tracker_channel.dart';

/// App-wide dependencies. The channel wrapper is a permanent singleton because both
/// channels are app-scoped and every screen talks to Kotlin through it.
class InitialBinding extends Bindings {
  @override
  void dependencies() {
    Get.put<TrackerChannel>(TrackerChannel(), permanent: true);
  }
}
