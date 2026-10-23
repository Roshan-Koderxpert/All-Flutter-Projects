import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:retail_gpt/Network/apis.dart';
import 'package:retail_gpt/Network/constants.dart';
import 'package:http/http.dart' as http;
import 'package:retail_gpt/models/utility_model/city_model.dart';
import 'package:retail_gpt/providers/utility_provider/pin_code_list_provider.dart';

import '../../local_storage/shared_preference.dart';

class CityListProvider extends ChangeNotifier {
  List<CityModel> _cityList = [];

  List<CityModel> get cityList => _cityList;

  int _selectedCityId = -1;

  int get selectedCityId => _selectedCityId;

  void setSelectedCityId(int id) {
    _selectedCityId = id;
    // print(_selectedCityId);
    PinCodeListProvider pinCodeListProvider =
        Provider.of<PinCodeListProvider>(Get.context!, listen: false);
    pinCodeListProvider.getPinCode(id);
    notifyListeners();
  }

  void clearCityList() {
    _cityList = [];
    _selectedCityId = -1;
    notifyListeners();
  }

  CityModel getSelectedCity(int id) {
    return _cityList.firstWhere((element) => element.id == id);
  }

  Future<void> getCityList(int districtId) async {
    try {
      String token = await SharedPreference.getToken();
      var headers = {
        'Authorization': token,
        'Model': Constants.GET_CITY,
        'Content-Type': 'application/json',
      };
      var request = http.Request('POST', Uri.parse(Apis.COMMON_URL));
      request.body = json.encode({
        "fields": "['name','district_id' ]",
        "district_id": districtId,
      });
      request.headers.addAll(headers);

      http.StreamedResponse response = await request.send();

      String res = await response.stream.bytesToString();
      // // print(res);
      Map<String, dynamic> jsonResponse = json.decode(res);
      if (response.statusCode == 200) {
        List<CityModel> cityList = [];
        jsonResponse['data'].forEach((element) {
          cityList.add(CityModel.fromJson(element));
        });
        _cityList = cityList;
        // // print(jsonResponse['data']);
      } else if (response.statusCode == 409) {
        SharedPreference.logout(jsonResponse['message']);
      } else {
        Get.snackbar(
          'Error',
          jsonResponse['message'],
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
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
      notifyListeners();
    }
  }
}
