import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';
import 'package:retail_gpt/Network/apis.dart';
import 'package:retail_gpt/Network/constants.dart';
import 'package:retail_gpt/local_storage/shared_preference.dart';
import 'package:retail_gpt/models/utility_model/country_model.dart';
import 'package:retail_gpt/providers/utility_provider/state_list_provider.dart';

class CountryListProvider extends ChangeNotifier {
  List<CountryModel> _countryList = [];

  List<CountryModel> get countryList => _countryList;

  int _selectedCountryId = -1;

  int get selectedCountryId => _selectedCountryId;

  void setSelectedCountryId(int id) {
    _selectedCountryId = id;
    StateListProvider stateListProvider = Provider.of<StateListProvider>(
      Get.context!,
      listen: false,
    );
    stateListProvider.getStateList(id);
    notifyListeners();
  }

  void clearCountryList() {
    _countryList = [];
    _selectedCountryId = -1;
    notifyListeners();
  }

  void clearSelectedCountry() {
    _selectedCountryId = -1;
    // print("clear list");
    notifyListeners();
  }

  CountryModel getSelectedCountry(int id) {
    // // print(id);
    return _countryList.firstWhere((element) => element.id == id);
  }

  Future<void> getCountryList() async {
    try {
      String token = await SharedPreference.getToken();
      var headers = {
        'Authorization': token,
        'Model': Constants.GET_COUNTRY,
        'Content-Type': 'application/json',
      };
      var request = http.Request('POST', Uri.parse(Apis.COMMON_URL));
      request.body = json.encode({"fields": "['name','code']"});
      request.headers.addAll(headers);

      http.StreamedResponse response = await request.send();
      String res = await response.stream.bytesToString();
      Map<String, dynamic> jsonResponse = json.decode(res);
      bool responseStatus = jsonResponse['success'];
      if (responseStatus) {
        List<CountryModel> countryList = [];
        jsonResponse['data'].forEach((element) {
          countryList.add(CountryModel.fromJson(element));
        });
        _countryList = countryList;
        // await stateListProvider.getStateList();
      } else {
        if (jsonResponse['message'] == 'Invalid or expired token') {
          SharedPreference.logout(jsonResponse['message']);
        }
      }
    } catch (e) {
      print(e);
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
