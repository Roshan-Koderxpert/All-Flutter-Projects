import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:retail_gpt/models/retail_list_screen/retail_model.dart';
import 'package:retail_gpt/navigation/getx_navigation.dart';
import 'package:retail_gpt/providers/retail_list_screen/trie.dart';
import 'package:retail_gpt/providers/utility_provider/city_list_provider.dart';
import 'package:retail_gpt/providers/utility_provider/country_list_provider.dart';
import 'package:retail_gpt/providers/utility_provider/district_list_provider.dart';
import 'package:retail_gpt/providers/utility_provider/pin_code_list_provider.dart';
import 'package:retail_gpt/providers/utility_provider/state_list_provider.dart';

import '../../Network/apis.dart';
import '../../local_storage/shared_preference.dart';
import 'package:http/http.dart' as http;

class RetailListScreenProvider extends ChangeNotifier {
  List<RetailModel> _retailList = [];
  List<RetailModel> _filteredRetailList = [];
  final Trie _trie = Trie();
  bool _isFiltering = false;

  bool get isFiltering => _isFiltering;
  String _selectedState = '';

  String _selectedCountry = "";

  String get selectedCountry => _selectedCountry;

  String get selectedState => _selectedState;

  String _selectedDistrict = '';

  String get selectedDistrict => _selectedDistrict;

  String _selectedCity = '';

  String get selectedCity => _selectedCity;
  int _subscribeSelectedFilterOption = 1;

  int get subscribeSelectedFilterOption => _subscribeSelectedFilterOption;

  String _pinCode = '';

  String get pinCode => _pinCode;

  String _searchQuery = '';

  String get searchQuery => _searchQuery;
  Timer? _debounce;

  List<RetailModel> get retailList => _retailList;

  List<RetailModel> get filteredRetailList => _filteredRetailList;

  bool _isLoading = true;

  bool get isLoading => _isLoading;

  void clearFilter({bool canGoBack = true}) {
    CountryListProvider countryListProvider = Provider.of<CountryListProvider>(
      Get.context!,
      listen: false,
    );
    StateListProvider stateListProvider = Provider.of<StateListProvider>(
      Get.context!,
      listen: false,
    );
    DistrictListProvider districtListProvider =
        Provider.of<DistrictListProvider>(Get.context!, listen: false);
    CityListProvider cityListProvider = Provider.of<CityListProvider>(
      Get.context!,
      listen: false,
    );
    PinCodeListProvider pinCodeListProvider = Provider.of<PinCodeListProvider>(
      Get.context!,
      listen: false,
    );

    countryListProvider.clearSelectedCountry();
    stateListProvider.clearStateList();
    districtListProvider.clearDistrictList();
    cityListProvider.clearCityList();
    pinCodeListProvider.clearPinCodeList();
    _selectedCountry = "";
    _isFiltering = false;
    _selectedState = '';
    _selectedCity = '';
    _pinCode = '';
    _subscribeSelectedFilterOption = 1;
    if (canGoBack) {
      GetxNavigation().goBack();
    }
    notifyListeners();
  }

  ///id: json['id'],
  //       retailName: json['retailName'],
  //       retailAddress: json['retailAddress'],
  //       retailerPhone: json['retailerPhone'],
  //       retailerEmail: json['retailerEmail'],
  //       state: json['state'],
  //       city: json['city'],
  //       pincode: json['pincode'],
  //       isSubscribed: json['isSubscribed'],
  Map<String, dynamic> jsonResponseData(Map<String, dynamic> data) {
    String street1 =
        data['street'].toString().isEmpty ? '-' : data['street'].toString();
    String street2 =
        data['street2'].toString().isEmpty ? '-' : data['street2'].toString();
    String street = '$street1 $street2';
    List<dynamic> cityList = data['city_id'];
    String city = cityList.isEmpty ? '-' : cityList[1].toString();
    String state =
        data['state_id'].isEmpty ? '-' : data['state_id'][1].toString();
    String pincode =
        data['zip_code_id'].isEmpty ? '-' : data['zip_code_id'][1].toString();
    String country =
        data['country_id'].isEmpty ? '-' : data['country_id'][1].toString();
    // print(state);
    return {
      'id': data['id'].toString(),
      'retailName':
          data['brand_name'].toString().isEmpty
              ? '-'
              : data['brand_name'].toString(),
      'retailAddress': street,
      'state': state,
      'city': city,
      'pincode': "$pincode $country",
      'isSubscribed': false,
      'retailerPhone': data['mobile'].toString(),
      'retailerEmail':
          data['email'].toString().isEmpty ? "-" : data['email'].toString(),
    };
  }

  static List checkIsList(dynamic value) {
    if (value == null) {
      return [];
    }

    if (value is List) {
      return value;
    } else {
      return [];
    }
  }

  Future<void> getRetailList() async {
    _setLoading(true);

    try {
      String token = await SharedPreference.getToken();
      int userId = await SharedPreference.getUserId();
      // print(token);
      var headers = {
        'Model': 'crm.lead',
        'Authorization': token,
        'Content-Type': 'application/json',
      };
      var request = http.Request(
        'POST',
        Uri.parse(
          '${Apis.BASE_URL}/model?Model=crm.lead&Authorization=$token',
        ),
      );
      request.body = json.encode({
        "fields":
            "['name','description','brand_name','description','brand_description','brand_type','email','listing_status','expected_revenue','stage_id','type','active','is_subscribed','is_subscription_declined','mobile','street','street2','city_id','country_id','state_id','district_id','zip_code_id']",
        "user_id": userId,
      });
      request.headers.addAll(headers);

      http.StreamedResponse response = await request.send();
      String responseBody = await response.stream.bytesToString();
      Map<String, dynamic> responseJson = json.decode(responseBody);
      // print("Response: $responseJson");
      if (response.statusCode == 200) {
        List<dynamic> dataList = responseJson['data'];
        List<RetailModel> listData = [];
        for (var data in dataList) {
          print(data['description']);
          listData.add(
            RetailModel(
              id: data['id'],
              brandType: data['brand_type'] is List ? "" : data['brand_type'],
              brandDescription:
                  data['brand_description'] is List
                      ? ""
                      : data['brand_description'],
              leadStatus:
                  data['listing_status'] is List ? "" : data['listing_status'],
              districtId:
                  (data['district_id'] as List<dynamic>).toList().isEmpty
                      ? "-"
                      : data['district_id'][0],
              districtName:
                  (data['district_id'] as List<dynamic>).toList().isEmpty
                      ? "-"
                      : data['district_id'][1],
              name:
                  data['brand_name'] is String
                      ? data['brand_name'].toString().isEmpty
                          ? "-"
                          : data['brand_name']
                      : (data['brand_name'] as List<dynamic>).toList().isEmpty
                      ? "-"
                      : data['brand_name'],
              contactName:
                  data['name'] is String
                      ? data['name'].toString().isEmpty
                          ? "-"
                          : data['name']
                      : (data['name'] as List<dynamic>).toList().isEmpty
                      ? "-"
                      : data['name'],
              email:
                  data['email'] is String
                      ? data['email'].toString().isEmpty
                          ? "-"
                          : data['email']
                      : (data['email'] as List<dynamic>).toList().isEmpty
                      ? ""
                      : data['email'],
              expectedRevenue: data['expected_revenue'],
              stageId:
                  checkIsList(data['stage_id']).isEmpty
                      ? -1
                      : data['stage_id'][0],
              type: data['type'],
              mobile:
                  data['mobile'] is String
                      ? data['mobile'].toString().isEmpty
                          ? "-"
                          : data['mobile']
                      : (data['mobile'] as List<dynamic>).toList().isEmpty
                      ? "-"
                      : data['mobile'],
              street:
                  data['street'] is String
                      ? data['street'].toString().isEmpty
                          ? "-"
                          : data['street']
                      : (data['street'] as List<dynamic>).toList().isEmpty
                      ? "-"
                      : data['street'],
              street2:
                  data['street2'] is String
                      ? data['street2'].toString().isEmpty
                          ? "-"
                          : data['street2']
                      : (data['street2'] as List<dynamic>).toList().isEmpty
                      ? "-"
                      : data['street2'],
              cityId:
                  (data['city_id'] as List<dynamic>).toList().isEmpty
                      ? "-"
                      : data['city_id'][0],
              cityName:
                  (data['city_id'] as List<dynamic>).toList().isEmpty
                      ? "-"
                      : data['city_id'][1],
              stateId:
                  (data['state_id'] as List<dynamic>).toList().isEmpty
                      ? "-"
                      : data['state_id'][0],
              stateName:
                  (data['state_id'] as List<dynamic>).toList().isEmpty
                      ? "-"
                      : data['state_id'][1],
              countryId:
                  (data['country_id'] as List<dynamic>).toList().isEmpty
                      ? "-"
                      : data['country_id'][0],
              countryName:
                  (data['country_id'] as List<dynamic>).toList().isEmpty
                      ? "-"
                      : data['country_id'][1],
              zipId:
                  (data['zip_code_id'] as List<dynamic>).toList().isEmpty
                      ? "-"
                      : data['zip_code_id'][0],
              zipCode:
                  (data['zip_code_id'] as List<dynamic>).toList().isEmpty
                      ? "-"
                      : data['zip_code_id'][1],
              description: data['description'] is String
                  ? data['description'].toString().isEmpty
                      ? "-"
                      : data['description']
                  : (data['description'] as List<dynamic>).toList().isEmpty
                      ? "-"
                      : data['description'],
            ),
          );
        }
        _retailList = listData;
      } else if (response.statusCode == 409) {
        Get.snackbar(
          'Error',
          responseJson['message'],
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        SharedPreference.logout(responseJson['message']);
      } else {
        Get.snackbar(
          'Error',
          responseJson['message'],
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );

        if (responseJson['message'] == 'Invalid or expired token') {
          SharedPreference.logout(responseJson['message']);
        }
      }
    } catch (e) {
      // print(e);
      Get.snackbar(
        'Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      _setLoading(false);
      notifyListeners();
    }

    // await Future.delayed(Duration(seconds: 2));
    //
    // _retailList =
    //     UtilityData.data['data']
    //         .map<RetailModel>((e) => RetailModel.fromJson(e))
    //         .toList();
    //
    // for (var retail in _retailList) {
    //   _trie.insert(retail);
    // }
  }

  void setSelectedCountry(String country) {
    _selectedCountry = country;
    notifyListeners();
  }

  void removeSelectedCountry() {
    CountryListProvider countryListProvider = Provider.of<CountryListProvider>(
      Get.context!,
      listen: false,
    );
    countryListProvider.clearSelectedCountry();
    _selectedCountry = '';
    removeSelectedState();
    // if (_searchQuery.isEmpty &&
    //     _pinCode.isEmpty &&
    //     _selectedState.isEmpty &&
    //     _selectedCity.isEmpty) {
    //   clearFilter(canGoBack: false);
    //   return;
    // }

    /// 27-03-25
    applyFilter(_pinCode, _searchQuery, canGoBack: false);
  }

  void setSelectedState(String state) {
    _selectedState = state;
    _selectedCity = '';
    notifyListeners();
  }

  void removeSelectedState() {
    // print("remove state");
    StateListProvider stateListProvider = Provider.of<StateListProvider>(
      Get.context!,
      listen: false,
    );
    stateListProvider.clearStateList();
    _selectedState = '';
    removeDistrict();
    // if (_searchQuery.isEmpty &&
    //     _pinCode.isEmpty &&
    //     _selectedState.isEmpty &&
    //     _selectedCity.isEmpty) {
    //   clearFilter(canGoBack: false);
    //   return;
    // }

    /// 27-03-25
    applyFilter(_pinCode, _searchQuery, canGoBack: false);
  }

  void setDistrict(String district) {
    _selectedDistrict = district;
    notifyListeners();
  }

  void removeDistrict() {
    DistrictListProvider districtListProvider =
        Provider.of<DistrictListProvider>(Get.context!, listen: false);
    districtListProvider.clearDistrictList();
    _selectedDistrict = '';
    removeSelectedCity();
    // if (_searchQuery.isEmpty &&
    //     _pinCode.isEmpty &&
    //     _selectedState.isEmpty &&
    //     _selectedCity.isEmpty) {
    //   clearFilter(canGoBack: false);
    //   return;
    // }

    /// 27-03-25
    applyFilter(_pinCode, _searchQuery, canGoBack: false);
  }

  void setSelectedCity(String city) {
    _selectedCity = city;
    notifyListeners();
  }

  void removeSelectedCity() {
    CityListProvider cityListProvider = Provider.of<CityListProvider>(
      Get.context!,
      listen: false,
    );
    cityListProvider.clearCityList();

    _selectedCity = '';
    removePinCode();
    // if (_searchQuery.isEmpty &&
    //     _pinCode.isEmpty &&
    //     _selectedState.isEmpty &&
    //     _selectedCity.isEmpty) {
    //   clearFilter(canGoBack: false);
    //   return;
    // }

    /// 27-03-25
    applyFilter(_pinCode, _searchQuery, canGoBack: false);
  }

  void setPinCode(String pinCode) {
    _pinCode = pinCode;
    notifyListeners();
  }

  void removePinCode() {
    PinCodeListProvider pinCodeListProvider = Provider.of<PinCodeListProvider>(
      Get.context!,
      listen: false,
    );
    pinCodeListProvider.clearPinCodeList();
    _pinCode = '';
    // if (_searchQuery.isEmpty &&
    //     _pinCode.isEmpty &&
    //     _selectedState.isEmpty &&
    //     _selectedCity.isEmpty) {
    //   clearFilter(canGoBack: false);
    //   return;
    // }

    /// 27-03-25
    applyFilter(_pinCode, _searchQuery, canGoBack: false);
  }

  void removeSubscribeSelectedFilterOption() {
    if (_searchQuery.isEmpty &&
        _pinCode.isEmpty &&
        _selectedState.isEmpty &&
        _selectedCity.isEmpty) {
      clearFilter(canGoBack: false);
      return;
    }
    _subscribeSelectedFilterOption = 1;

    applyFilter(_pinCode, _searchQuery, canGoBack: false);
  }

  void setSubscribeSelectedFilterOption(int selectedOption) {
    // print(selectedOption);
    _subscribeSelectedFilterOption = selectedOption;
    _isFiltering = true;
    notifyListeners();
  }

  void setFiltering(bool filtering) {
    _isFiltering = filtering;
    notifyListeners();
  }

  /// 27-03-25
  void applyFilter(
    String pinCode,
    String searchQuery, {
    bool canGoBack = true,
  }) {
    _isFiltering = true;
    _pinCode = pinCode;
    _searchQuery =
        searchQuery
            .toLowerCase(); // Convert to lowercase for case-insensitive search
    notifyListeners();

    // print(
    //   "Applying filter with pinCode: $pinCode, state: $_selectedState, city: $_selectedCity, searchQuery: $searchQuery",
    // );

    // Step 1: Apply filtering based on state, city, and pincode
    List<RetailModel> filteredList =
        _retailList.where((element) {
          bool countryMatch =
              _selectedCountry.isEmpty ||
              element.countryName.toLowerCase() ==
                  _selectedCountry.toLowerCase();
          bool stateMatch =
              _selectedState.isEmpty ||
              element.stateName.toLowerCase() == _selectedState.toLowerCase();

          bool districtMatch =
              _selectedDistrict.isEmpty ||
              element.districtName.toLowerCase() ==
                  _selectedDistrict.toLowerCase();

          bool cityMatch =
              _selectedCity.isEmpty ||
              element.cityName.toLowerCase() == _selectedCity.toLowerCase();

          bool pinCodeMatch =
              pinCode.isEmpty ||
              element.zipCode.toString() == pinCode.toString();
          bool statusMatch =
              element.leadStatus == "free_listing" ||
              element.leadStatus == "subscribed" ||
              element.leadStatus == "decline" ||
              element.leadStatus == "decline_listing" ||
              element.leadStatus == "decline_subscription";

          if (_subscribeSelectedFilterOption == 2) {
            // free listing
            statusMatch = element.leadStatus == "free_listing";
          }
          if (_subscribeSelectedFilterOption == 3) {
            // subscription
            statusMatch = element.leadStatus == "subscribed";
          }
          if (_subscribeSelectedFilterOption == 4) {
            // decline
            statusMatch = element.leadStatus == "decline";
          }
          if (_subscribeSelectedFilterOption == 5) {
            // free listing
            statusMatch = element.leadStatus == "decline_listing";
          }
          if (_subscribeSelectedFilterOption == 6) {
            // free listing
            statusMatch = element.leadStatus == "decline_subscription";
          }

          // bool subscriptionMatch =
          //     _subscribeSelectedFilterOption == 1 ||
          //     (_subscribeSelectedFilterOption == 2 && element.isSubscribed) ||
          //     (_subscribeSelectedFilterOption == 3 && !element.isSubscribed);

          return statusMatch &&
              countryMatch &&
              districtMatch &&
              stateMatch &&
              cityMatch &&
              pinCodeMatch; // && subscriptionMatch;
        }).toList();

    // Step 2: Apply search query on filtered results
    if (searchQuery.isNotEmpty) {
      filteredList =
          filteredList.where((element) {
            return element.contactName.toLowerCase().contains(
                  searchQuery.toLowerCase(),
                ) ||
                element.name.toLowerCase().contains(
                  searchQuery.toLowerCase(),
                ) ||
                element.street.toLowerCase().contains(
                  searchQuery.toLowerCase(),
                ) ||
                element.street2.toLowerCase().contains(
                  searchQuery.toLowerCase(),
                ) ||
                element.countryName.toLowerCase().contains(
                  searchQuery.toLowerCase(),
                ) ||
                element.stateName.toLowerCase().contains(
                  searchQuery.toLowerCase(),
                ) ||
                element.cityName.toLowerCase().contains(
                  searchQuery.toLowerCase(),
                ) ||
                element.districtName.toLowerCase().contains(
                  searchQuery.toLowerCase(),
                ) ||
                element.mobile.toLowerCase().contains(
                  searchQuery.toLowerCase(),
                ) ||
                element.email.toLowerCase().contains(searchQuery.toLowerCase());
          }).toList();
    }

    // Update filtered list
    _filteredRetailList = filteredList;

    // print("Final Filtered List Length: ${_filteredRetailList.length}");
    if (canGoBack) {
      GetxNavigation().goBack();
    }

    notifyListeners();
  }

  // void _applyFilter(String pinCode) {
  //   _isFiltering = true;
  //   _pinCode = pinCode;
  //   notifyListeners();
  //   if (_subscribeSelectedFilterOption == 1 ||
  //       _subscribeSelectedFilterOption == 0) {
  //     _filteredRetailList =
  //         _retailList.where((element) {
  //           bool state = false;
  //           bool city = false;
  //           bool boolPinCode = false;
  //
  //           if (_selectedState.isNotEmpty) {
  //             state =
  //                 element.stateName.toLowerCase() == _selectedState.toLowerCase();
  //           }
  //           if (_selectedCity.isNotEmpty) {
  //             city = element.cityName.toLowerCase() == _selectedCity.toLowerCase();
  //           }
  //           if (pinCode.isNotEmpty) {
  //             boolPinCode = element.zipCode.toString() == pinCode.toString();
  //           }
  //           return ((state || city || boolPinCode) ); //&&
  //               // (element.isSubscribed || !element.isSubscribed));
  //         }).toList();
  //     // print("1 or 0");
  //   }
  //   if (_subscribeSelectedFilterOption == 2) {
  //     _filteredRetailList =
  //         _retailList.where((element) {
  //           bool state = false;
  //           bool city = false;
  //           bool boolPinCode = false;
  //
  //           if (_selectedState.isNotEmpty) {
  //             state =
  //                 element.stateName.toLowerCase() == _selectedState.toLowerCase();
  //           }
  //           if (_selectedCity.isNotEmpty) {
  //             city = element.cityName.toLowerCase() == _selectedCity.toLowerCase();
  //           }
  //           if (pinCode.isNotEmpty) {
  //             boolPinCode = element.zipCode.toString() == pinCode.toString();
  //           }
  //
  //           return ((state || city || boolPinCode));//)&& (element.isSubscribed);
  //         }).toList();
  //     // _filteredRetailList = _filteredRetailList.where((element){
  //     //   // print(element.isSubscribed);
  //     //   return element.isSubscribed;
  //     // }).toList();
  //     // print("2");
  //   }
  //   if (_subscribeSelectedFilterOption == 3) {
  //     _filteredRetailList =
  //         _retailList.where((element) {
  //           bool state = false;
  //           bool city = false;
  //           bool boolPinCode = false;
  //
  //           if (_selectedState.isNotEmpty) {
  //             state =
  //                 element.stateName.toLowerCase() == _selectedState.toLowerCase();
  //           }
  //           if (_selectedCity.isNotEmpty) {
  //             city = element.cityName.toLowerCase() == _selectedCity.toLowerCase();
  //           }
  //
  //           if (pinCode.isNotEmpty) {
  //             boolPinCode = element.zipCode.toString() == pinCode.toString();
  //           }
  //
  //           return ((state || city || boolPinCode));// && (!element.isSubscribed));
  //         }).toList();
  //     // print("3");
  //   }
  //   // print(_filteredRetailList.length);
  //   GetxNavigation().goBack();
  //   notifyListeners();
  // }

  void filterRetailList(String pinCode, String searchQuery) {
    if (searchQuery.isEmpty &&
        pinCode.isEmpty &&
        _selectedState.isEmpty &&
        selectedCity.isEmpty) {
      clearFilter(canGoBack: false);
      return;
    }
    setFiltering(true);
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    _debounce = Timer(Duration(milliseconds: 10), () {
      // _filteredRetailList = _trie.search(query);
      // notifyListeners();
      /// 27-03-25
      applyFilter(pinCode, searchQuery, canGoBack: false);
    });
  }

  void _setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  @override
  void dispose() {
    _debounce?.cancel();
    super.dispose();
  }
}
