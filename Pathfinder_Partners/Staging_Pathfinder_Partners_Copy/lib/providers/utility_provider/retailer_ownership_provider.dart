import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:retail_gpt/models/utility_model/retailer_ownership_model.dart';
import 'package:http/http.dart' as http;
import '../../Network/apis.dart';
import '../../Network/constants.dart';
import '../../local_storage/shared_preference.dart';

class RetailerOwnershipProvider extends ChangeNotifier {
  List<RetailerOwnershipModel> _retailerOwnershipList = [];

  List<RetailerOwnershipModel> get retailerOwnershipList =>
      _retailerOwnershipList;

  int _selectedRetailerOwnershipId = -1;

  int get selectedRetailerOwnershipId => _selectedRetailerOwnershipId;

  void setSelectedRetailerOwnershipId(int id) {
    _selectedRetailerOwnershipId = id;
    notifyListeners();
  }

  void clearRetailerOwnershipList() {
    _retailerOwnershipList = [];
    _selectedRetailerOwnershipId = -1;
    notifyListeners();
  }

  RetailerOwnershipModel getSelectedRetailerOwnership(int id) {
    return _retailerOwnershipList.firstWhere((element) => element.id == id);
  }

  Map<String, dynamic> reformatData(Map<String, dynamic> data) {
    Map<String, dynamic> reformatedData = {
      "id": data['id'],
      "name": data['name'],
      "document_type_id": data['document_type_ids'][0],
    };
    return reformatedData;
  }

  Future<void> getRetailerOwnershipList(int countryId) async {
    try {
      String token = await SharedPreference.getToken();
      var headers = {
        'Authorization': token,
        'Model': Constants.GET_RETAILER_OWNERSHIP,
        'Content-Type': 'application/json',
      };
      var request = http.Request('POST', Uri.parse(Apis.COMMON_URL));
      request.body = json.encode({
        "fields": "['name','document_type_ids','country_id']",
        "country_id": countryId,
      });
      request.headers.addAll(headers);

      http.StreamedResponse response = await request.send();
      String res = await response.stream.bytesToString();
      Map<String, dynamic> jsonResponse = json.decode(res);
      bool responseStatus = jsonResponse['success'];
      // // print(res);
      if (responseStatus) {
        List<RetailerOwnershipModel> retailerOwnershipList = [];
        jsonResponse['data'].forEach((element) {
          retailerOwnershipList.add(
            RetailerOwnershipModel.fromJson(element),
          );
        });
        _retailerOwnershipList = retailerOwnershipList;
      } else {
        if (jsonResponse['message'] == 'Invalid or expired token') {
          SharedPreference.logout(jsonResponse['message']);
          return;
        }
        Get.snackbar(
          'Error',
          jsonResponse['message'],
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    }
    catch (e) {
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
