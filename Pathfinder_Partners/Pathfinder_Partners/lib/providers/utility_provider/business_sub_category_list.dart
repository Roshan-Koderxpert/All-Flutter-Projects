import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:retail_gpt/models/utility_model/business_sub_category.dart';
import 'package:http/http.dart' as http;
import '../../Network/apis.dart';
import '../../Network/constants.dart';
import '../../local_storage/shared_preference.dart';

class BusinessSubCategoryList extends ChangeNotifier {
  List<BusinessSubCategoryModel> _businessSubCategoryList = [];

  List<BusinessSubCategoryModel> get businessSubCategoryList =>
      _businessSubCategoryList;

  int _selectedBusinessSubCategoryId = -1;

  int get selectedBusinessSubCategoryId => _selectedBusinessSubCategoryId;

  void setSelectedBusinessSubCategoryId(int id) {
    _selectedBusinessSubCategoryId = id;
    notifyListeners();
  }

  void clearBusinessSubCategoryList() {
    _businessSubCategoryList = [];
    notifyListeners();
  }

  BusinessSubCategoryModel getSelectedBusinessSubCategory(int id) {
    return _businessSubCategoryList.firstWhere((element) => element.id == id);
  }

  Future<void> getBusinessSubCategoryList(int retailerCategoryId) async {
    try {
      _businessSubCategoryList =[];
      String token = await SharedPreference.getToken();
      var headers = {
        'Authorization': token,
        'Model': Constants.GET_SUB_BUSINESS_CATEGORY,
        'Content-Type': 'application/json',
      };
      var request = http.Request('POST', Uri.parse(Apis.COMMON_URL));
      request.body = json.encode({
        "fields": "['name','retailer_category_id']",
        "retailer_category_id": retailerCategoryId,
      });
      request.headers.addAll(headers);
      http.StreamedResponse response = await request.send();
      String res = await response.stream.bytesToString();
      // print(res);
      Map<String, dynamic> jsonResponse = json.decode(res);
      if (response.statusCode == 200) {
        List<BusinessSubCategoryModel> businessSubCategoryList = [];
        jsonResponse['data'].forEach((element) {
          businessSubCategoryList.add(
            BusinessSubCategoryModel.fromJson(element),
          );
        });
        _businessSubCategoryList = businessSubCategoryList;
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
