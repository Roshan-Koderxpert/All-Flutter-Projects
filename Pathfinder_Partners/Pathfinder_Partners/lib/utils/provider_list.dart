import 'package:retail_gpt/providers/utility_provider/time_provider.dart';
import 'package:provider/provider.dart';
import 'package:provider/single_child_widget.dart';
import 'package:retail_gpt/providers/auth_provider/login_provider.dart';
import 'package:retail_gpt/providers/auth_provider/splash_screen_provider.dart';
import 'package:retail_gpt/providers/create_new_outlet_screens/create_outlet_provider.dart';
import 'package:retail_gpt/providers/create_new_outlet_screens/outlet_description_provider.dart';
import 'package:retail_gpt/providers/home_screen/home_screen_provider.dart';
import 'package:retail_gpt/providers/outlet_kyc_document/outlet_kyc_document_list_provider.dart';
import 'package:retail_gpt/providers/retail_list_screen/retail_list_screen_provider.dart';
import 'package:retail_gpt/providers/create_new_outlet_screens/route_path_screen_provider.dart';
import 'package:retail_gpt/providers/utility_provider/business_category_list_provider.dart';
import 'package:retail_gpt/providers/utility_provider/business_sub_category_list.dart';
import 'package:retail_gpt/providers/utility_provider/channel_type_provider.dart';
import 'package:retail_gpt/providers/utility_provider/city_list_provider.dart';
import 'package:retail_gpt/providers/utility_provider/country_list_provider.dart';
import 'package:retail_gpt/providers/utility_provider/district_list_provider.dart';
import 'package:retail_gpt/providers/utility_provider/local_data_provider.dart';
import 'package:retail_gpt/providers/utility_provider/pin_code_list_provider.dart';
import 'package:retail_gpt/providers/utility_provider/retailer_ownership_provider.dart';
import 'package:retail_gpt/providers/utility_provider/state_list_provider.dart';
class ProviderList {
 static List<SingleChildWidget> providers = [
     ChangeNotifierProvider(create: (context) => SplashScreenProvider()),
     ChangeNotifierProvider(create: (context) => LoginProvider()),
     ChangeNotifierProvider(create: (context) => HomeScreenProvider()),
     ChangeNotifierProvider(create: (context) => RetailListScreenProvider()),
     ChangeNotifierProvider(create: (context) => RoutePlanScreenProvider()),
     ChangeNotifierProvider(create: (context) => CountryListProvider()),
     ChangeNotifierProvider(create: (context) => StateListProvider()),
     ChangeNotifierProvider(create: (context) => DistrictListProvider()),
     ChangeNotifierProvider(create: (context) => CityListProvider()),
     ChangeNotifierProvider(create: (context) => PinCodeListProvider()),
     ChangeNotifierProvider(create: (context) => CreateOutletProvider()),
     ChangeNotifierProvider(create: (context) => RetailerOwnershipProvider()),
     ChangeNotifierProvider(create: (context) => ChannelTypeProvider()),
     ChangeNotifierProvider(create: (context) => BusinessCategoryListProvider()),
     ChangeNotifierProvider(create: (context) => BusinessSubCategoryList()),
     ChangeNotifierProvider(create: (context) => LocalDataProvider()),
     ChangeNotifierProvider(create: (context) => OutletDescriptionProvider()),
     ChangeNotifierProvider(create: (context) => OutletKycDocumentListProvider()),
     ChangeNotifierProvider(create: (context) => TimeProvider()),
  ];
}