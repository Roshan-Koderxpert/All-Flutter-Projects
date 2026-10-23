import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:retail_gpt/models/utility_model/channel_type_model.dart';
import 'package:http/http.dart' as http;
import '../../Network/apis.dart';
import '../../Network/constants.dart';
import '../../local_storage/shared_preference.dart';

class ChannelTypeProvider extends ChangeNotifier {
  List<ChannelTypeModel> _channelTypeList = [];

  List<ChannelTypeModel> get channelTypeList => _channelTypeList;

  int _selectedChannelTypeId = -1;

  int get selectedChannelTypeId => _selectedChannelTypeId;

  void setSelectedChannelTypeId(int id) {
    _selectedChannelTypeId = id;
    notifyListeners();
  }

  void clearChannelTypeList() {
    _channelTypeList = [];
    notifyListeners();
  }

  ChannelTypeModel getSelectedChannelType(int id) {
    return _channelTypeList.firstWhere((element) => element.id == id);
  }

  Future<void> getChannelTypeList() async {
    try {
      String token = await SharedPreference.getToken();
      var headers = {
        'Authorization': token,
        'Model': Constants.GET_CHANNEL_TYPE,
        'Content-Type': 'application/json',
      };
      var request = http.Request('POST', Uri.parse(Apis.COMMON_URL));
      request.body = json.encode({
        "fields": "['name']",
      });
      request.headers.addAll(headers);

      http.StreamedResponse response = await request.send();

      String res = await response.stream.bytesToString();
      // // print(res);
      Map<String, dynamic> jsonResponse = json.decode(res);
      if (response.statusCode == 200) {
        print(jsonResponse);
        List<ChannelTypeModel> channelTypeList = [];
        jsonResponse['data'].forEach((element) {
          channelTypeList.add(ChannelTypeModel.fromJson(element));
        });
        _channelTypeList = channelTypeList;
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
