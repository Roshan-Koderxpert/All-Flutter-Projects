import 'dart:convert';

import 'package:flutter/cupertino.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:retail_gpt/Network/apis.dart';
import 'package:http/http.dart' as http;

import '../../local_storage/shared_preference.dart';
import '../utility_provider/local_data_provider.dart';

class HomeScreenProvider extends ChangeNotifier {
  // final List<HomeScreenModel> _homeScreenData = [];
  //
  // List<HomeScreenModel> get homeScreenData => _homeScreenData;
  bool _isLoading = true;

  int _monthlyFreeListingTarget = 0;
  int _yearlyFreeListingTarget = 0;

  int get monthlyFreeListingTarget => _monthlyFreeListingTarget;

  int get yearlyFreeListingTarget => _yearlyFreeListingTarget;

  int _achievedFreeListingMonthlyTarget = 0;
  int _achievedFreeListingYearlyTarget = 0;

  int get achievedFreeListingMonthlyTarget => _achievedFreeListingMonthlyTarget;

  int get achievedFreeListingYearlyTarget => _achievedFreeListingYearlyTarget;

  int _declineFreeListingMonthlyTarget = 0;
  int _declineFreeListingYearlyTarget = 0;

  int get declineFreeListingMonthlyTarget => _declineFreeListingMonthlyTarget;

  int get declineFreeListingYearlyTarget => _declineFreeListingYearlyTarget;

  int _monthlySubscriptionTarget = 0;
  int _yearlySubscriptionTarget = 0;

  int get monthlySubscriptionTarget => _monthlySubscriptionTarget;

  int get yearlySubscriptionTarget => _yearlySubscriptionTarget;

  int _achievedSubscriptionMonthlyTarget = 0;
  int _achievedSubscriptionYearlyTarget = 0;

  int get achievedSubscriptionMonthlyTarget =>
      _achievedSubscriptionMonthlyTarget;

  int get achievedSubscriptionYearlyTarget => _achievedSubscriptionYearlyTarget;

  int _declineSubscriptionMonthlyTarget = 0;
  int _declineSubscriptionYearlyTarget = 0;

  int get declineSubscriptionMonthlyTarget => _declineSubscriptionMonthlyTarget;

  int get declineSubscriptionYearlyTarget => _declineSubscriptionYearlyTarget;

  bool get isLoading => _isLoading;

  int _toggleValue = 0;

  int get toggleValue => _toggleValue;

  void setLoading(bool value) {
    _isLoading = value;
    notifyListeners();
  }

  Future<void> getData() async {
    // _homeScreenData.clear();
    // await Future.delayed(Duration(seconds: 2));
    await getMonthlyData();
    await getYearlyData();
    // _data['data'].map((e) {
    //   _homeScreenData.add(HomeScreenModel.fromJson(e));
    // }).toList();
  }

  Future<void> getMonthlyData() async {
    try {
      LocalDataProvider localDataProvider = Provider.of<LocalDataProvider>(
        Get.context!,
        listen: false,
      );
      var headers = {
        'Authorization': localDataProvider.token,
        'Content-Type': 'application/json',
      };
      var request = http.Request('POST', Uri.parse(Apis.DASHBOARD_URL));
      request.body = json.encode({
        "fields":
            "['monthly_free_listing_target','achieved_free_listing_monthly_target','decline_free_listing_monthly_target','monthly_subscription_target','achieved_subscription_monthly_target','decline_subscription_monthly_target']",
      });
      request.headers.addAll(headers);

      http.StreamedResponse response = await request.send();
      String responseString = await response.stream.bytesToString();
      Map<String, dynamic> data = json.decode(responseString);
      bool status = data['success'];
      if (status) {
        Map<String, dynamic> monthlyData = data['data'][0];
        // print(monthlyData);
        _monthlyFreeListingTarget = monthlyData['monthly_free_listing_target'];
        _achievedFreeListingMonthlyTarget =
            monthlyData['achieved_free_listing_monthly_target'];
        _declineFreeListingMonthlyTarget =
            monthlyData['decline_free_listing_monthly_target'];
        _monthlySubscriptionTarget = monthlyData['monthly_subscription_target'];
        _achievedSubscriptionMonthlyTarget =
            monthlyData['achieved_subscription_monthly_target'];
        _declineSubscriptionMonthlyTarget =
            monthlyData['decline_subscription_monthly_target'];
      } else {
        if (data['message'] == 'Invalid or expired token') {
          SharedPreference.logout(data['message']);
        }
      }
    } catch (e) {
      // print(e);
    } finally {
      setLoading(false);
      notifyListeners();
    }
  }

  Future<void> getYearlyData() async {
    try {
      LocalDataProvider localDataProvider = Provider.of<LocalDataProvider>(
        Get.context!,
        listen: false,
      );
      var headers = {
        'Authorization': localDataProvider.token,
        'Content-Type': 'application/json',
      };
      var request = http.Request('POST', Uri.parse(Apis.DASHBOARD_URL));
      request.body = json.encode({
        "fields":
            "['total_free_listing_target', 'total_subscription_target', 'achieved_free_listing_total_target', 'achieved_subscription_total_target', 'decline_free_listing_total_target', 'decline_subscription_total_target']",
      });
      request.headers.addAll(headers);

      http.StreamedResponse response = await request.send();
      String responseString = await response.stream.bytesToString();
      Map<String, dynamic> data = json.decode(responseString);
      bool status = data['success'];
      if (status) {
        Map<String, dynamic> yearlyData = data['data'][0];
        // print(yearlyData);
        _yearlyFreeListingTarget = yearlyData['total_free_listing_target'];
        _achievedFreeListingYearlyTarget =
            yearlyData['achieved_free_listing_total_target'];
        _declineFreeListingYearlyTarget =
            yearlyData['decline_free_listing_total_target'];
        _yearlySubscriptionTarget = yearlyData['total_subscription_target'];
        _achievedSubscriptionYearlyTarget =
            yearlyData['achieved_subscription_total_target'];
        _declineSubscriptionYearlyTarget =
            yearlyData['decline_subscription_total_target'];
      } else {
        if (data['message'] == 'Invalid or expired token') {
          SharedPreference.logout(data['message']);
        }
      }
    } catch (e) {
      // print(e);
    } finally {
      setLoading(false);
      notifyListeners();
    }
  }

  void onToggle(int index) {
    _toggleValue = index;
    notifyListeners();
  }
}
