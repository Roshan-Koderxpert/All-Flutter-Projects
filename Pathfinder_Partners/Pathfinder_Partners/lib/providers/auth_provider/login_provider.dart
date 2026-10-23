import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:retail_gpt/Network/apis.dart';
import 'package:retail_gpt/local_storage/shared_preference.dart';
import 'package:retail_gpt/navigation/getx_navigation.dart';
import 'package:retail_gpt/screens/home_screen/home_screen.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../utility_provider/country_list_provider.dart';

class LoginProvider extends ChangeNotifier {
  bool _isLoading = false;

  bool get isLoading => _isLoading;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> login(String email, String password) async {
    try {


      setLoading(true);

      var headers = {'Content-Type': 'application/json'};
      var request = http.Request('POST', Uri.parse(Apis.LOGIN));
      request.body = json.encode({"login": email, "password": password});
      request.headers.addAll(headers);



      http.StreamedResponse response = await request.send();
      String res = await response.stream.bytesToString();

      print("📩 Status Code: ${response.statusCode}");
      print("📨 Response Body: $res");

      if (response.statusCode == 500) {
        Get.snackbar(
          'Error',
          'Internal Server Error',
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }

      Map<String, dynamic> jsonResponse = json.decode(res);

      if (response.statusCode == 200) {


        SharedPreference.setToken(jsonResponse['token']);
        SharedPreference.setUserId(jsonResponse['user_id']);
        SharedPreference.setUserName(jsonResponse['user_name']);
        SharedPreference.setCompanyName(jsonResponse['company_name']);

        CountryListProvider countryListProvider =
        Provider.of<CountryListProvider>(Get.context!, listen: false);
        await countryListProvider.getCountryList();

        GetxNavigation().navigateToNextAndRemovePreviousAll(
          HomeScreen.routeName,
        );
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
      Get.snackbar(
        'Error',
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setLoading(false);
    }
  }
}
