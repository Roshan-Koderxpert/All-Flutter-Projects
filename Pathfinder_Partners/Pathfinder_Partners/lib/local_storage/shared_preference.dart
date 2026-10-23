import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:retail_gpt/navigation/getx_navigation.dart';
import 'package:retail_gpt/providers/utility_provider/local_data_provider.dart';
import 'package:retail_gpt/screens/auth_screens/login_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

class SharedPreference {
  static void setToken(String token) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    LocalDataProvider localDataProvider = Provider.of<LocalDataProvider>(
      Get.context!,
      listen: false,
    );
    localDataProvider.setToken(token);
    prefs.setString('token', token);
  }

  static Future<String> getToken() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String token = prefs.getString('token') ?? "";
    LocalDataProvider localDataProvider = Provider.of<LocalDataProvider>(
      Get.context!,
      listen: false,
    );
    localDataProvider.setToken(token);
    return token;
  }

  static void setUserId(int id) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    LocalDataProvider localDataProvider = Provider.of<LocalDataProvider>(
      Get.context!,
      listen: false,
    );
    localDataProvider.setUserId(id);
    prefs.setInt('userId', id);
  }

  static Future<int> getUserId() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int userId = prefs.getInt('userId') ?? -1;
    LocalDataProvider localDataProvider = Provider.of<LocalDataProvider>(
      Get.context!,
      listen: false,
    );
    localDataProvider.setUserId(userId);
    return userId;
  }

  static void setUserName(String name) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    LocalDataProvider localDataProvider = Provider.of<LocalDataProvider>(
      Get.context!,
      listen: false,
    );
    localDataProvider.setUserName(name);
    prefs.setString('userName', name);
  }

  static Future<String> getUserName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String userName = prefs.getString('userName') ?? "";
    LocalDataProvider localDataProvider = Provider.of<LocalDataProvider>(
      Get.context!,
      listen: false,
    );
    localDataProvider.setUserName(userName);
    return userName;
  }

  static void setCompanyName(String name) async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    LocalDataProvider localDataProvider = Provider.of<LocalDataProvider>(
      Get.context!,
      listen: false,
    );
    localDataProvider.setCompanyName(name);
    prefs.setString('companyName', name);
  }

  static Future<String> getCompanyName() async {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    String companyName = prefs.getString('companyName') ?? "";
    LocalDataProvider localDataProvider = Provider.of<LocalDataProvider>(
      Get.context!,
      listen: false,
    );
    localDataProvider.setCompanyName(companyName);
    return companyName;
  }

  static Future<void> logout(String message) async {

    SharedPreferences prefs = await SharedPreferences.getInstance();
    LocalDataProvider localDataProvider = Provider.of<LocalDataProvider>(
      Get.context!,
      listen: false,
    );
    String token = prefs.getString('token') ?? "";
    if(token.isEmpty || localDataProvider.token.isEmpty) {
      return;
    }

    localDataProvider.clearData();
    prefs.clear();
    if(message.isNotEmpty) {
      Get.snackbar(
        'Error',
        message,
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    }
    GetxNavigation().navigateToNextAndRemovePreviousAll(LoginScreen.routeName);
  }
}
