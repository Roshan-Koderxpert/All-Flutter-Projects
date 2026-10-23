import 'dart:convert';

import 'package:retail_gpt/Network/apis.dart';
import 'package:retail_gpt/Network/constants.dart';
import 'package:retail_gpt/models/utility_model/time_model.dart';
import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:http/http.dart' as http;
import '../../local_storage/shared_preference.dart';

class TimeProvider extends ChangeNotifier {
  List<TimeModel> openingTimeList = [];
  List<TimeModel> closingTimeList = [];

  int selectedOpeningTime = -1;
  int selectedClosingTime = -1;

  void setSelectedOpeningTime(int id) {
    selectedOpeningTime = id;

    notifyListeners();
  }

  void setSelectedClosingTime(int id) {
    selectedClosingTime = id;

    notifyListeners();
  }

  TimeModel getSelectedOpeningTime(int id) {
    return openingTimeList.firstWhere(
      (element) => element.id == id,
    );
  }

  TimeModel getSelectedClosingTime(int id) {
    return closingTimeList.firstWhere(
      (element) => element.id == id,
    );
  }

  void clearTimeList() {
    openingTimeList = [];
    closingTimeList = [];
    selectedOpeningTime = -1;
    selectedClosingTime = -1;
    notifyListeners();
  }

  void setOpeningTimeList(List<TimeModel> list) {
    openingTimeList = list;
    notifyListeners();
  }

  void setClosingTimeList(List<TimeModel> list) {
    closingTimeList = list;
    notifyListeners();
  }

  Future<void> getOpeningTime() async {
    try {
      String token = await SharedPreference.getToken();
      var headers = {
        'Authorization': token,
        'Model': Constants.GET_OPENING_TIME,
        'Content-Type': 'application/json',
      };
      var request = http.Request('POST', Uri.parse(Apis.COMMON_URL));
      request.body = json.encode({"fields": "['name']"});
      request.headers.addAll(headers);

      http.StreamedResponse response = await request.send();
      if (response.statusCode == 500) {
        Get.snackbar(
          'Error',
          "Internal Server Error",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
      String res = await response.stream.bytesToString();
      Map<String, dynamic> jsonResponse = json.decode(res);
      if (response.statusCode == 200) {
        List<TimeModel> tempList = [];
        for (var item in jsonResponse['data']) {
          tempList.add(TimeModel.fromJson(item));
        }
        setOpeningTimeList(tempList);
      } else {
        if (response.statusCode == 409) {
          SharedPreference.logout("Session expired");
          return;
        }
        Get.snackbar(
          'Error',
          jsonResponse['message'] ?? "Something went wrong",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        // print(response.reasonPhrase);
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

  Future<void> getClosingTime() async {
    try {
      String token = await SharedPreference.getToken();
      var headers = {
        'Authorization': token,
        'Model': Constants.GET_CLOSING_TIME,
        'Content-Type': 'application/json',
      };
      var request = http.Request('POST', Uri.parse(Apis.COMMON_URL));
      request.body = json.encode({"fields": "['name']"});
      request.headers.addAll(headers);

      http.StreamedResponse response = await request.send();
      if (response.statusCode == 500) {
        Get.snackbar(
          'Error',
          "Internal Server Error",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        return;
      }
      String res = await response.stream.bytesToString();
      Map<String, dynamic> jsonResponse = json.decode(res);
      if (response.statusCode == 200) {
        List<TimeModel> tempList = [];
        for (var item in jsonResponse['data']) {
          tempList.add(TimeModel.fromJson(item));
        }
        setClosingTimeList(tempList);
      } else {
        if (response.statusCode == 409) {
          SharedPreference.logout("Session expired");
          return;
        }
        Get.snackbar(
          'Error',
          jsonResponse['message'] ?? "Something went wrong",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
        // print(response.reasonPhrase);
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
