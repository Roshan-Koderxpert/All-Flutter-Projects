import 'package:get/get.dart';

import '../pages/home/home_page.dart';
import '../pages/login/login_screen.dart';

class AppRoutes {
  static const login = '/login';
  static const home = '/home';
  static const String addAccount = '/add-account';

  static final pages = [
    GetPage(name: login, page: () => const LoginPage()),
    GetPage(name: home, page: () => const HomePage()),
  ];
}
