import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:provider/provider.dart';
import 'package:retail_gpt/Network/apis.dart';
import 'package:retail_gpt/models/outlet_detail_screen/outlet_model.dart';
import 'package:http/http.dart' as http;
import 'package:retail_gpt/navigation/getx_navigation.dart';

import '../../local_storage/shared_preference.dart';
import '../../screens/outlet_screens/kyc_description_screen.dart';
import '../retail_list_screen/retail_list_screen_provider.dart';

class OutletDescriptionProvider extends ChangeNotifier {
  List<OutletModel> _outletList = [];

  List<OutletModel> get outletList => _outletList;

  int _selectedOutletId = -1;

  int get selectedOutletId => _selectedOutletId;

  bool _isLoading = false;

  bool get isLoading => _isLoading;

  void setSelectedOutletId(int id) {
    _selectedOutletId = id;
    notifyListeners();
  }

  void clearOutletList() {
    _outletList = [];
    notifyListeners();
  }

  OutletModel getSelectedOutlet(int id) {
    return _outletList.firstWhere((element) => element.id == id);
  }

  void addOutlet(OutletModel outlet) {
    _outletList.add(outlet);
    notifyListeners();
  }

  void removeOutlet(int id) {
    _outletList.removeWhere((element) => element.id == id);
    notifyListeners();
  }

  void setLoading(bool loading) {
    _isLoading = loading;
    notifyListeners();
  }


  // Future<void> setLeadWon(int leadId) async {
  //   try {
  //     setLoading(true);
  //
  //     // ✅ Get token from SharedPreferences
  //     String token = await SharedPreference.getToken();
  //
  //     var url = Uri.parse(Apis.Won); // <-- make sure Apis.Won points to your backend endpoint
  //
  //     var headers = {
  //       'Authorization': token,          // ✅ same as getOutlet
  //       'Content-Type': 'application/json',
  //     };
  //
  //     var body = {
  //       "model": "crm.lead",
  //       "method": "action_set_won",
  //       "args": [
  //         [leadId]
  //       ],
  //       "kwargs": {}
  //     };
  //
  //     var request = http.Request('POST', url);
  //     request.headers.addAll(headers);
  //     request.body = jsonEncode(body);
  //
  //     http.StreamedResponse response = await request.send();
  //     String responseString = await response.stream.bytesToString();
  //
  //     print("🔹 setLeadWon response: $responseString");
  //
  //     if (response.statusCode == 200) {
  //       Get.snackbar(
  //         'Success',
  //         "Lead marked as WON",
  //         snackPosition: SnackPosition.BOTTOM,
  //         backgroundColor: Colors.green,
  //         colorText: Colors.white,
  //       );
  //
  //       // Refresh retail list
  //       RetailListScreenProvider retailListScreenProvider =
  //       Provider.of<RetailListScreenProvider>(Get.context!, listen: false);
  //       retailListScreenProvider.getRetailList();
  //
  //     } else if (response.statusCode == 409) {
  //       Map<String, dynamic> jsonResponse = json.decode(responseString);
  //       SharedPreference.logout(jsonResponse['message']);
  //     } else {
  //       Map<String, dynamic> jsonResponse = json.decode(responseString);
  //       Get.snackbar(
  //         'Error',
  //         jsonResponse['message'] ?? "Failed to set lead WON",
  //         snackPosition: SnackPosition.BOTTOM,
  //         backgroundColor: Colors.red,
  //         colorText: Colors.white,
  //       );
  //     }
  //   } catch (e) {
  //     print("⚠️ Exception in setLeadWon: $e");
  //     Get.snackbar(
  //       'Error',
  //       e.toString(),
  //       snackPosition: SnackPosition.BOTTOM,
  //       backgroundColor: Colors.red,
  //       colorText: Colors.white,
  //     );
  //   } finally {
  //     setLoading(false);
  //     notifyListeners();
  //   }
  // }


  Future<void> getOutlet(int outletId) async {
    setLoading(true);
    // try {
    String token = await SharedPreference.getToken();
    var headers = {
      'Model': 'crm.lead',
      'Authorization': token,
      'Content-Type': 'application/json',
    };
    var request = http.Request(
      'POST',
      Uri.parse('${Apis.COMMON_URL}?Model=crm.lead'),
    );
    request.body = json.encode({
      "fields":
          "['name','pos_name','description','pos_no','next_follow_up','brand_name','brand_description','brand_type','contact_name','listing_status','expected_revenue','country_id','state_id','city_id','district_id','latitude','longitude','zip_code_id','contact_name','email','mobile','partner_type','channel_id','class_of_retailer','retailer_ownership_id','business_category_id','business_sub_category_id','street','street2','opening_id','date_deadline','closing_id','type','stage_id','active','is_subscription_declined','logo','image1','image2','image3','probability','partner_id','res_partner_id','team_id','job_position','website','kyc_detail_ids']",
      "id": outletId,
    });
    request.headers.addAll(headers);
    http.StreamedResponse response = await request.send();
    String res = await response.stream.bytesToString();
    print(res);
    if(response.statusCode == 500) {
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
    Map<String, dynamic> jsonResponse = json.decode(res);

    if (response.statusCode == 200) {
      setSelectedOutletId(outletId);
      if (jsonResponse['data'] != null) {
        _outletList =
            (jsonResponse['data'] as List).map((e) {
              return OutletModel.fromJson(e);
            }).toList();
        if (_outletList.isNotEmpty) {
          // getKycDocumentListByIds(_outletList[0].id);
        }
      } else {
        Get.snackbar(
          'Error',
          jsonResponse['message'],
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } else if (response.statusCode == 409) {
      SharedPreference.logout(jsonResponse['message']);
      // setLoading(false);
    } else if (response.statusCode == 409) {
      SharedPreference.logout(jsonResponse['message']);
      // setLoading(false);
    } else {
      // print("Error");
      Get.snackbar(
        'Error',
        jsonResponse['message'],
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
      // setLoading(false);
    }
    // } catch (e) {
    //   // print(e);
    //   // setLoading(false);
    //   Get.snackbar(
    //     'Error',
    //     e.toString(),
    //     snackPosition: SnackPosition.BOTTOM,
    //     backgroundColor: Colors.red,
    //     colorText: Colors.white,
    //   );
    // } finally {
    await Future.delayed(const Duration(milliseconds: 1000));
    setLoading(false);
    // }
  }

  Future<void> updateLead(
    Map<String, dynamic> body, {
    bool isBack = true,
    bool showMessage = false,
  }) async
  {
    // print("Update Lead : ------------------>");
    print(body);
    try {
      setLoading(true);
      String token = await SharedPreference.getToken();
      // print("token $token");
      var headers = {
        'Authorization': token,
        'Content-Type': 'application/json',
      };
      var request = http.Request('POST', Uri.parse(Apis.ADD_OUTLET));
      request.body = json.encode(body);
      request.headers.addAll(headers);

      http.StreamedResponse response = await request.send();
      String responseString = await response.stream.bytesToString();
      print("----------------------------------------");
      print(responseString);
      Map<String, dynamic> responseJson = json.decode(responseString);
      // print(responseJson);
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
      if (response.statusCode == 200) {
        // print("success");
        if (isBack) {
          GetxNavigation().goBack();
        }
        if (showMessage) {
          Get.snackbar(
            'Success',
            "Record Updated Successfully",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
        }

        setLoading(false);
        RetailListScreenProvider retailListScreenProvider =
            Provider.of<RetailListScreenProvider>(Get.context!, listen: false);
        retailListScreenProvider.getRetailList();
      } else {
        setLoading(false);
        if (response.statusCode == 409) {
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

  Future<void> subscribeLead(int leadId, {
    bool isBack = true,
    bool showMessage = true,
  }) async {
    try {
      setLoading(true);
      String token = await SharedPreference.getToken();

      final url = Uri.parse("${Apis.BASE_URL}/lead/create_sale_order");

      final response = await http.post(
        url,
        headers: {
          "Content-Type": "application/json",
          "Authorization": token,
        },
        body: jsonEncode({
          "lead_id": int.parse(leadId.toString()),
          "is_subscribed": true,
        }),
      );

      final data = jsonDecode(response.body);

      if (response.statusCode == 200 && data["success"] == true) {
        if (showMessage) {
          Get.snackbar(
            "Success",
            "Sale order created successfully",
            snackPosition: SnackPosition.BOTTOM,
            backgroundColor: Colors.green,
            colorText: Colors.white,
          );
        }

        if (isBack) {
          GetxNavigation().goBack();
          GetxNavigation().next(KycDescriptionScreen.routeName);
        }

        // 🔄 refresh list after success
        RetailListScreenProvider retailListScreenProvider =
        Provider.of<RetailListScreenProvider>(Get.context!, listen: false);
        retailListScreenProvider.getRetailList();
      } else {
        Get.snackbar(
          "Error",
          data["message"] ?? "Failed to create sale order",
          snackPosition: SnackPosition.BOTTOM,
          backgroundColor: Colors.red,
          colorText: Colors.white,
        );
      }
    } catch (e) {
      Get.snackbar(
        "Error",
        e.toString(),
        snackPosition: SnackPosition.BOTTOM,
        backgroundColor: Colors.red,
        colorText: Colors.white,
      );
    } finally {
      setLoading(false);
      notifyListeners();
    }
  }
}
