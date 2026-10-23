import 'package:get/get.dart';
import 'package:retail_gpt/screens/auth_screens/forget_password.dart';
import 'package:retail_gpt/screens/outlet_screens/kyc_details_screen.dart';
import 'package:retail_gpt/screens/outlet_screens/outlet_description_screen.dart';
import 'package:retail_gpt/screens/outlet_screens/registration_completed_screen.dart';
import 'package:retail_gpt/screens/auth_screens/login_screen.dart';
import 'package:retail_gpt/screens/auth_screens/splash_screen.dart';
import 'package:retail_gpt/screens/error_screens/error_404_screen.dart';
import 'package:retail_gpt/screens/home_screen/home_screen.dart';
import 'package:retail_gpt/screens/retail_list_screen/retail_list_screen.dart';
import 'package:retail_gpt/screens/outlet_screens/create_new_outlet_screen.dart';
import 'package:retail_gpt/screens/route_plan_screen/route_plan_screen.dart';

import '../screens/outlet_screens/kyc_description_screen.dart';

class ScreenList {
  GetPage<dynamic> unknownRoute = GetPage(
    name: Error404Screen.routeName,
    page: () => Error404Screen(),
  );
  List<GetPage<dynamic>> getPages = [
    GetPage(name: Error404Screen.routeName, page: () => Error404Screen()),
    GetPage(name: SplashScreen.routeName, page: () => SplashScreen()),
    GetPage(name: LoginScreen.routeName, page: () => LoginScreen()),
    GetPage(name: HomeScreen.routeName, page: () => HomeScreen()),
    GetPage(name: RetailListScreen.routeName, page: () => RetailListScreen()),
    GetPage(name: RoutePlanScreen.routeName, page: () => RoutePlanScreen()),
    GetPage(name: CreateNewOutletScreen.routeName, page: () => CreateNewOutletScreen()),
    GetPage(name: OutletDescriptionScreen.routeName, page: () => OutletDescriptionScreen()),
    GetPage(name: RegistrationCompletedScreen.routeName, page: () => RegistrationCompletedScreen()),
    // GetPage(name: KycDetailsScreen.routeName, page: () => KycDetailsScreen()),
    GetPage(name: KycDescriptionScreen.routeName, page: () => KycDescriptionScreen()),
    GetPage(name: ForgetPasswordScreen.routeName, page: () => ForgetPasswordScreen()),
  ];
}
