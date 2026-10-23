import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:retail_gpt/models/utility_model/business_category_model.dart';
import 'package:http/http.dart' as http;

import '../../Network/apis.dart';
import '../../Network/constants.dart';
import '../../local_storage/shared_preference.dart';

class BusinessCategoryListProvider extends ChangeNotifier {
  List<BusinessCategoryModel> _businessCategoryList = [];

  List<BusinessCategoryModel> get businessCategoryList => _businessCategoryList;

  int _selectedBusinessCategoryId = -1;

  int get selectedBusinessCategoryId => _selectedBusinessCategoryId;

  void setSelectedBusinessCategoryId(int id) {
    _selectedBusinessCategoryId = id;
    notifyListeners();
  }

  void clearBusinessCategoryList() {
    _businessCategoryList = [];
    notifyListeners();
  }

  BusinessCategoryModel getSelectedBusinessCategory(int id) {
    return _businessCategoryList.firstWhere((element) => element.id == id);
  }

  Future<void> getBusinessCategoryList() async {
    try {
      String token = await SharedPreference.getToken();
      var headers = {
        'Authorization': token,
        'Model': Constants.GET_BUSINESS_CATEGORY,
        'Content-Type': 'application/json',
      };
      var request = http.Request('POST', Uri.parse(Apis.COMMON_URL));
      request.body = json.encode({"fields": "['name']"});
      request.headers.addAll(headers);
      http.StreamedResponse response = await request.send();
      String res = await response.stream.bytesToString();
      // // print(res);
      Map<String, dynamic> jsonResponse = json.decode(res);
      if (response.statusCode == 200) {
        List<BusinessCategoryModel> businessCategoryList = [];
        jsonResponse['data'].forEach((element) {
          businessCategoryList.add(BusinessCategoryModel.fromJson(element));
        });
        _businessCategoryList = businessCategoryList;
        // // print(jsonResponse['data']);
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
