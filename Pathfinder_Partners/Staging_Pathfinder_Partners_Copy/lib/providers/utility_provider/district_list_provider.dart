import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:retail_gpt/Network/apis.dart';
import 'package:retail_gpt/Network/constants.dart';
import 'package:retail_gpt/models/utility_model/district_model.dart';
import 'package:http/http.dart' as http;
import 'package:retail_gpt/providers/utility_provider/city_list_provider.dart';

import '../../local_storage/shared_preference.dart';

class DistrictListProvider extends ChangeNotifier{

  List<DistrictModel> _districtList = [];

  List<DistrictModel> get districtList => _districtList;

  int _selectedDistrictId = -1;

  int get selectedDistrictId => _selectedDistrictId;

  void setSelectedDistrictId(int id) {
    _selectedDistrictId = id;
    // print(_selectedDistrictId);
    CityListProvider cityListProvider = Provider.of<CityListProvider>(Get.context!, listen: false);
    cityListProvider.getCityList(id);
    notifyListeners();
  }

  DistrictModel getSelectedDistrict(int id) {
    return _districtList.firstWhere((element) => element.id == id);
  }

  void clearDistrictList() {
    _districtList = [];
    _selectedDistrictId = -1;
    notifyListeners();
  }


  Future<void> getDistrictList(int stateId) async {
    try {
      String token = await SharedPreference.getToken();
      var headers = {
        'Authorization': token,
        'Model': Constants.GET_DISTRICT,
        'Content-Type': 'application/json',
      };
      var request = http.Request('POST', Uri.parse(Apis.COMMON_URL));
      request.body = json.encode({
        "fields": "['name','state_id' ]",
        "state_id": stateId,
      });
      request.headers.addAll(headers);

      http.StreamedResponse response = await request.send();

      String res = await response.stream.bytesToString();
      // // print(res);
      Map<String, dynamic> jsonResponse = json.decode(res);
      if (response.statusCode == 200) {
        List<DistrictModel> districtList = [];
        jsonResponse['data'].forEach((element) {
          districtList.add(DistrictModel.fromJson(element));
        });
        _districtList = districtList;
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