import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:retail_gpt/Network/apis.dart';
import 'package:retail_gpt/Network/constants.dart';
import 'package:http/http.dart' as http;
import 'package:retail_gpt/models/utility_model/pin_code_model.dart';

import '../../local_storage/shared_preference.dart';
class PinCodeListProvider extends ChangeNotifier {
  List<PinCodeModel> _pinCodeList = [];

  List<PinCodeModel> get pinCodeList => _pinCodeList;

  int _selectedPinCodeId = -1;

  int get selectedPinCodeId => _selectedPinCodeId;

  void setSelectedPinCodeId(int id) {
    _selectedPinCodeId = id;
    // print(_selectedPinCodeId);
    notifyListeners();
  }


  void clearPinCodeList() {
    _pinCodeList = [];
    _selectedPinCodeId = -1;
    notifyListeners();
  }

  PinCodeModel getSelectedPinCode(int id) {
    return _pinCodeList.firstWhere((element) => element.id == id);
  }


  Future<void> getPinCode(int cityId) async {
    try {
      String token = await SharedPreference.getToken();
      var headers = {
        'Authorization': token,
        'Model': Constants.GET_POSTAL_CODE,
        'Content-Type': 'application/json',
      };
      var request = http.Request('POST', Uri.parse(Apis.COMMON_URL));
      request.body = json.encode({
        "fields": "['name','city_id' ]",
        "city_id": cityId,
      });
      request.headers.addAll(headers);

      http.StreamedResponse response = await request.send();

      String res = await response.stream.bytesToString();
      // // print(res);
      Map<String, dynamic> jsonResponse = json.decode(res);
      if (response.statusCode == 200) {
        List<PinCodeModel> pinCodeList = [];
        jsonResponse['data'].forEach((element) {
          pinCodeList.add(PinCodeModel.fromJson(element));
        });
        _pinCodeList = pinCodeList;
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