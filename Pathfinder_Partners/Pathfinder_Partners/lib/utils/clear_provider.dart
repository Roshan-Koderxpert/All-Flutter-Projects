import 'package:flutter/cupertino.dart';
import 'package:provider/provider.dart';
import 'package:retail_gpt/providers/utility_provider/city_list_provider.dart';
import 'package:retail_gpt/providers/utility_provider/country_list_provider.dart';
import 'package:retail_gpt/providers/utility_provider/district_list_provider.dart';
import 'package:retail_gpt/providers/utility_provider/pin_code_list_provider.dart';
import 'package:retail_gpt/providers/utility_provider/retailer_ownership_provider.dart';
import 'package:retail_gpt/providers/utility_provider/state_list_provider.dart';

class ClearProvider {
  static void clearLocationBaseProviders(BuildContext context) {
    CountryListProvider countryListProvider = Provider.of<CountryListProvider>(
      context,
      listen: false,
    );
    countryListProvider.clearCountryList();

    StateListProvider stateListProvider = Provider.of<StateListProvider>(
      context,
      listen: false,
    );
    stateListProvider.clearStateList();

    DistrictListProvider districtListProvider =
        Provider.of<DistrictListProvider>(context, listen: false);
    districtListProvider.clearDistrictList();

    CityListProvider cityListProvider = Provider.of<CityListProvider>(
      context,
      listen: false,
    );
    cityListProvider.clearCityList();

    PinCodeListProvider pinCodeListProvider = Provider.of<PinCodeListProvider>(
      context,
      listen: false,
    );
    pinCodeListProvider.clearPinCodeList();

    RetailerOwnershipProvider retailerOwnershipProvider =
        Provider.of<RetailerOwnershipProvider>(context, listen: false);
    retailerOwnershipProvider.clearRetailerOwnershipList();

  }
}
