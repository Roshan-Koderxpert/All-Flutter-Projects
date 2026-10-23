import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:retail_gpt/Network/apis.dart';
import 'package:retail_gpt/Network/constants.dart';
import 'package:retail_gpt/local_storage/shared_preference.dart';
import 'package:retail_gpt/providers/retail_list_screen/retail_list_screen_provider.dart';

import '../../navigation/getx_navigation.dart';
import '../../screens/outlet_screens/registration_completed_screen.dart';

class CreateOutletProvider extends ChangeNotifier {
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> createOutletForFreeListing(Map<String, dynamic> body) async {
    // print(body['logo']);
    try {
      setLoading(true);
      String token = await SharedPreference.getToken();
      var headers = {
        'Authorization': token,
        'Content-Type': 'application/json',
      };
      var request = http.Request('POST', Uri.parse(Apis.ADD_OUTLET));
      request.body = json.encode(body);
      request.headers.addAll(headers);

      http.StreamedResponse response = await request.send();
      String responseString = await response.stream.bytesToString();
      Map<String, dynamic> responseJson = json.decode(responseString);
      // print(responseJson);
      bool status = responseJson['success'];
      if (response.statusCode == 500) {
        Get.snackbar(
          'Error',
          "Internal Server Error",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        setLoading(false);
        return;
      }
      if (status) {
        // print("success");
        RetailListScreenProvider retailListScreenProvider =
            Provider.of<RetailListScreenProvider>(Get.context!, listen: false);
        retailListScreenProvider.getRetailList();
        setLoading(false);
        GetxNavigation().goBack();
        GetxNavigation().goBack();
        GetxNavigation().next(RegistrationCompletedScreen.routeName);
      } else {
        setLoading(false);
        if (responseJson['message'] == 'Invalid or expired token') {
          SharedPreference.logout(responseJson['message']);
          return;
        }
        print(responseJson['message']);
        Get.snackbar(
          'Error',
          responseJson['message'],
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      setLoading(false);
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

  Future<void> createOutletForDeclineSubscription(
    Map<String, dynamic> body,
  ) async
  {
    try {
      setLoading(true);
      String token = await SharedPreference.getToken();
      var headers = {
        'Authorization': token,
        'Content-Type': 'application/json',
      };
      var request = http.Request('POST', Uri.parse(Apis.ADD_OUTLET));
      request.body = json.encode(body);
      request.headers.addAll(headers);

      http.StreamedResponse response = await request.send();
      String responseString = await response.stream.bytesToString();
      Map<String, dynamic> responseJson = json.decode(responseString);
      // print(responseJson);
      bool status = responseJson['success'];
      if (response.statusCode == 500) {
        Get.snackbar(
          'Error',
          "Internal Server Error",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        setLoading(false);
        return;
      }
      if (status) {
        // print("success");
        RetailListScreenProvider retailListScreenProvider =
            Provider.of<RetailListScreenProvider>(Get.context!, listen: false);
        retailListScreenProvider.getRetailList();
        setLoading(false);
        GetxNavigation().goBack();
        GetxNavigation().goBack();
        GetxNavigation().next(RegistrationCompletedScreen.routeName);
      } else {
        setLoading(false);
        if (responseJson['message'] == 'Invalid or expired token') {
          SharedPreference.logout(responseJson['message']);
          return;
        }
        Get.snackbar(
          'Error',
          responseJson['message'],
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      setLoading(false);
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

  Future<void> createOutletForSubscription(Map<String, dynamic> body) async {
    try {
      // Map<String,dynamic> demoBody = body;
      // demoBody['logo']="";
      // demoBody['image1']="";
      // demoBody['image2']="";
      // demoBody['image3']="";
      // demoBody['kyc_detail_ids']=[];
      //
      // // print(jsonEncode(demoBody));
      // return;

      setLoading(true);
      String token = await SharedPreference.getToken();
      var headers = {
        'Authorization': token,
        'Content-Type': 'application/json',
      };
      var request = http.Request('POST', Uri.parse(Apis.ADD_OUTLET));
      request.body = json.encode(body);
      request.headers.addAll(headers);

      http.StreamedResponse response = await request.send();
      String responseString = await response.stream.bytesToString();
      Map<String, dynamic> responseJson = json.decode(responseString);
      print("Change to subscription : $responseJson");
      bool status = responseJson['success'];
      if (response.statusCode == 500) {
        Get.snackbar(
          'Error',
          "Internal Server Error",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        setLoading(false);
        return;
      }
      if (status) {
        // print("success");
        RetailListScreenProvider retailListScreenProvider =
            Provider.of<RetailListScreenProvider>(Get.context!, listen: false);
        retailListScreenProvider.getRetailList();
        await updateOutletForSubscription({
          "id": responseJson['record_id'],
          "stage_id": 4,
        });
        setLoading(false);
        GetxNavigation().goBack();
        GetxNavigation().goBack();
        GetxNavigation().goBack();
        GetxNavigation().next(RegistrationCompletedScreen.routeName);
      } else {
        setLoading(false);
        if (responseJson['message'] == 'Invalid or expired token') {
          SharedPreference.logout(responseJson['message']);
          return;
        }
        Get.snackbar(
          'Error',
          responseJson['message'],
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      setLoading(false);
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

  Future<void> updateOutletForSubscription(Map<String, dynamic> body) async {
    try {
      // Map<String,dynamic> demoBody = body;
      // demoBody['logo']="";
      // demoBody['image1']="";
      // demoBody['image2']="";
      // demoBody['image3']="";
      // demoBody['kyc_detail_ids']=[];
      //
      print(jsonEncode(body));
      // return;

      setLoading(true);
      String token = await SharedPreference.getToken();
      var headers = {
        'Authorization': token,
        'Content-Type': 'application/json',
        'Model':'crm.lead'
      };
      var request = http.Request('POST', Uri.parse(Apis.ADD_OUTLET));
      request.body = json.encode(body);
      request.headers.addAll(headers);

      http.StreamedResponse response = await request.send();
      String responseString = await response.stream.bytesToString();
      Map<String, dynamic> responseJson = json.decode(responseString);
      // print(responseJson);
      bool status = responseJson['success'];
      if (response.statusCode == 500) {
        Get.snackbar(
          'Error',
          "Internal Server Error",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        setLoading(false);
        return;
      }
      if (status) {
        // print("success");
        RetailListScreenProvider retailListScreenProvider =
            Provider.of<RetailListScreenProvider>(Get.context!, listen: false);
        retailListScreenProvider.getRetailList();
        setLoading(false);
        GetxNavigation().goBack();
        GetxNavigation().goBack();
        GetxNavigation().goBack();
        GetxNavigation().next(RegistrationCompletedScreen.routeName);
      } else {
        setLoading(false);
        if (responseJson['message'] == 'Invalid or expired token') {
          SharedPreference.logout(responseJson['message']);
          return;
        }
        Get.snackbar(
          'Error',
          responseJson['message'],
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      setLoading(false);
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

  Future<void> createOutletForDecline(Map<String, dynamic> body) async {
    try {
      setLoading(true);
      String token = await SharedPreference.getToken();
      var headers = {
        'Authorization': token,
        'Content-Type': 'application/json',
      };
      var request = http.Request('POST', Uri.parse(Apis.ADD_OUTLET));
      request.body = json.encode(body);
      request.headers.addAll(headers);

      http.StreamedResponse response = await request.send();
      String responseString = await response.stream.bytesToString();
      Map<String, dynamic> responseJson = json.decode(responseString);
      print("Response : $responseJson");
      bool status = responseJson['success'];
      if (response.statusCode == 500) {
        Get.snackbar(
          'Error',
          "Internal Server Error",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        setLoading(false);
        return;
      }
      if (status) {
        // print("success");
        RetailListScreenProvider retailListScreenProvider =
            Provider.of<RetailListScreenProvider>(Get.context!, listen: false);
        retailListScreenProvider.getRetailList();
        setLoading(false);
        GetxNavigation().goBack();
        GetxNavigation().goBack();
        GetxNavigation().next(RegistrationCompletedScreen.routeName);
      } else {
        setLoading(false);
        if (responseJson['message'] == 'Invalid or expired token') {
          SharedPreference.logout(responseJson['message']);
          return;
        }
        Get.snackbar(
          'Error',
          responseJson['message'],
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      setLoading(false);
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

  Future<bool> checkFieldExists(String fieldName, String fieldValue) async {
    print('============ CHECK $fieldName START ============');
    print('📧 Checking $fieldName: $fieldValue');

    try {
      String token = await SharedPreference.getToken();
      var headers = {
        'Authorization': token,
        'Model': Constants.GET_CRM,
        'Content-Type': 'application/json',
      };

      var url = Uri.parse(Apis.COMMON_URL);

      var requestBody = {
        fieldName: fieldValue,
        "fields": "['id']"
      };
      print('📦 Request Body: ${json.encode(requestBody)}');

      var request = http.Request('POST', url);
      request.body = json.encode(requestBody);
      request.headers.addAll(headers);

      http.StreamedResponse response = await request.send();
      String responseString = await response.stream.bytesToString();

      if (response.statusCode == 409 || response.statusCode == 500 || response.statusCode == 400) {
        print('❌ Error ${response.statusCode}');
        return false;
      }

      Map<String, dynamic> responseJson = json.decode(responseString);

      if (response.statusCode == 200) {
        bool status = responseJson['success'] ?? false;
        if (status) {
          var data = responseJson['data'];
          bool exists = false;
          if (data != null) {
            if (data is List) {
              exists = data.isNotEmpty;
            } else if (data is Map) {
              exists = true;
            } else if (data is int) {
              exists = data > 0;
            }
          }
          print('🎯 $fieldName exists: $exists');
          return exists;
        }
      }
      return false;
    } catch (e, stackTrace) {
      print('💥 ERROR: $e');
      return false;
    }
  }

}
