import 'package:get/get.dart';

import '../bindings/history_binding.dart';
import '../bindings/home_binding.dart';
import '../ui/views/history_view.dart';
import '../ui/views/home_view.dart';
import 'app_routes.dart';

abstract final class AppPages {
  static const initial = Routes.home;

  static final routes = <GetPage<dynamic>>[
    GetPage(name: Routes.home, page: () => const HomeView(), binding: HomeBinding()),
    GetPage(
      name: Routes.history,
      page: () => const HistoryView(),
      binding: HistoryBinding(),
      transition: Transition.rightToLeft,
    ),
  ];
}
