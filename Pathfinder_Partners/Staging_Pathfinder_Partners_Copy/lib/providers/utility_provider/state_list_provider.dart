import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:retail_gpt/Network/apis.dart';
import 'package:retail_gpt/Network/constants.dart';
import 'package:retail_gpt/models/utility_model/state_model.dart';
import 'package:http/http.dart' as http;
import 'package:retail_gpt/providers/utility_provider/district_list_provider.dart';

import '../../local_storage/shared_preference.dart';

class StateListProvider extends ChangeNotifier {
  List<StateModel> _stateList = [];

  List<StateModel> get stateList => _stateList;

  int _selectedStateId = -1;

  int get selectedStateId => _selectedStateId;

  void setSelectedStateId(int id) {
    _selectedStateId = id;
    DistrictListProvider districtListProvider =
        Provider.of<DistrictListProvider>(Get.context!, listen: false);
    districtListProvider.getDistrictList(id);
    notifyListeners();
  }

  void clearStateList() {
    _stateList = [];
    _selectedStateId = -1;
    notifyListeners();
  }

  StateModel getSelectedState(int id) {
    return _stateList.firstWhere((element) => element.id == id);
  }

  Future<void> getStateList(int countryId) async {
    try {
      String token = await SharedPreference.getToken();
      var headers = {
        'Authorization': token,
        'Model': Constants.GET_STATE,
        'Content-Type': 'application/json',
      };
      print('🚀 token $token');

      var request = http.Request('POST', Uri.parse(Apis.COMMON_URL));
      request.body = json.encode({
        "fields": "['name','code','country_id' ]",
        "country_id": countryId,
      });
      request.headers.addAll(headers);

      http.StreamedResponse response = await request.send();

      String res = await response.stream.bytesToString();
      Map<String, dynamic> jsonResponse = json.decode(res);
      if (response.statusCode == 200) {
        List<StateModel> stateList = [];
        jsonResponse['data'].forEach((element) {
          stateList.add(StateModel.fromJson(element));
        });
        _stateList = stateList;
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
