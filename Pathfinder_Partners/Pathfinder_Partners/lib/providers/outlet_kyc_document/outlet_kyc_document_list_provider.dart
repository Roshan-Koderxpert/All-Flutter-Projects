import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:retail_gpt/models/outlet_kyc_document/outlet_kyc_document_model.dart';
import 'package:http/http.dart' as http;
import '../../Network/apis.dart';
import '../../Network/constants.dart';
import '../../local_storage/shared_preference.dart';
import '../../navigation/getx_navigation.dart';
import '../../screens/outlet_screens/kyc_description_screen.dart';

class OutletKycDocumentListProvider extends ChangeNotifier {
  List<OutletKycDocumentModel> kycDocumentList = [];

  List<OutletKycDocumentModel> get getKycDocumentList => kycDocumentList;

  Future<void> fetchAndMergeKycDocuments(int retailerOwnershipId,
      int leadId,{bool isNavigate = false}) async {
    try {
      await getKycDocumentListByRetailerOwnershipId(retailerOwnershipId);
      List<OutletKycDocumentModel> uploadedDocuments =
      await getUploadedDocuments(leadId);

      // Create a Map for quick lookup of uploaded documents
      Map<int, OutletKycDocumentModel> uploadedDocMap = {
        for (var doc in uploadedDocuments) doc.documentId: doc,
      };

      // Merge both lists
      for (var doc in kycDocumentList) {
        if (uploadedDocMap.containsKey(doc.documentId)) {
          doc.base64File = uploadedDocMap[doc.documentId]!.base64File;
          doc.docFileName = uploadedDocMap[doc.documentId]!.docFileName;
        }
      }
      if(isNavigate) {
        GetxNavigation().next(
          KycDescriptionScreen.routeName,
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
      notifyListeners();
    }
  }

  /// 1. Get all documents without images
  Future<void> getKycDocumentListByRetailerOwnershipId(
      int retailerOwnershipId,) async
  {
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
        "id": retailerOwnershipId,
      });
      request.headers.addAll(headers);

      http.StreamedResponse response = await request.send();
      String res = await response.stream.bytesToString();
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
      Map<String, dynamic> jsonResponse = json.decode(res);
      // print(res);
      if (response.statusCode == 200) {
        kycDocumentList =
            jsonResponse['data'][0]['document_type_ids']
                .map<OutletKycDocumentModel>(
                  (element) => OutletKycDocumentModel.fromJson(element),
            )
                .toList();
        // GetxNavigation().next(
        //   KycDescriptionScreen.routeName,
        // );
      } else {
        if (response.statusCode == 409) {
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

  /// 2. Get all documents with images by lead id
  Future<List<OutletKycDocumentModel>> getUploadedDocuments(int leadId) async {
    List<OutletKycDocumentModel> uploadedDocuments = [];
    try {
    String token = await SharedPreference.getToken();
    var headers = {
      'Authorization': token,
      'Model': Constants.GET_KYC_DETAILS,
      'Content-Type': 'application/json',
    };
    var request = http.Request('POST', Uri.parse(Apis.COMMON_URL));
    request.body = json.encode({
      "fields": "['document_id', 'doc_file','is_document','doc_file_name']",
      "crm_lead_id": leadId,
    });
    request.headers.addAll(headers);

    http.StreamedResponse response = await request.send();
    String res = await response.stream.bytesToString();
    if (response.statusCode == 500) {
      // print("Internal server error");
      return [];
    }
    Map<String, dynamic> jsonResponse = json.decode(res);
    // print(jsonResponse);
    if (response.statusCode == 200) {
      uploadedDocuments =
          jsonResponse['data']
              .map<OutletKycDocumentModel>(
                (element) => OutletKycDocumentModel.fromJson(changeJson(element)),
          )
              .toList();
    } else {
      if (response.statusCode == 409) {
        SharedPreference.logout(jsonResponse['message']);
        return [];
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
      // print("KYC $e");
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
    return uploadedDocuments;
  }

  Map<String,dynamic> changeJson(Map<String,dynamic> data){
    int id = data['document_id'][0];
    String name = data['document_id'][1];
    String image = data['doc_file'] is List ? "" : data['doc_file'];
    String docFileName = data['doc_file_name'] is List ? "" : data['doc_file_name'];
    return {
      'id': id,
      'name': name,
      'doc_file': image,
      'doc_file_name': docFileName,
    };
  }
}
