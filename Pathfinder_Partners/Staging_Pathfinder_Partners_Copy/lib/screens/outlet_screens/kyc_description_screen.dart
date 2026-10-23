import 'dart:convert';

import 'package:retail_gpt/navigation/getx_navigation.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:retail_gpt/local_storage/shared_preference.dart';
import 'package:retail_gpt/providers/create_new_outlet_screens/outlet_description_provider.dart';

import '../../Icons/SVG/svg_icons.dart';
import '../../helper/helper.dart';
import '../../providers/outlet_kyc_document/outlet_kyc_document_list_provider.dart';
import '../../utils/app_colors.dart';
import '../../widgets/background_widget.dart';
import '../home_screen/home_screen.dart';

class KycDescriptionScreen extends StatefulWidget {
  static const routeName = "/kyc-description-screen";

  const KycDescriptionScreen({super.key});

  @override
  State<KycDescriptionScreen> createState() => _KycDescriptionScreenState();
}

class _KycDescriptionScreenState extends State<KycDescriptionScreen> {
  @override
  void initState() {
    // TODO: implement initState
    Future.microtask(() async {
      await getData();
    });
    super.initState();
  }

  Map<String, String> uploadedImages = {};
  Map<String, dynamic> body = {"kyc_detail_ids": []};
  List<int> emptyImageIndex = [];

  Future<void> getData2() async {
    print("getData");
    OutletKycDocumentListProvider outletKycDocumentListProvider =
        Provider.of<OutletKycDocumentListProvider>(context, listen: false);
    OutletDescriptionProvider outletDescriptionProvider =
        Provider.of<OutletDescriptionProvider>(context, listen: false);
    int userId = await SharedPreference.getUserId();
    int leadId = outletDescriptionProvider.selectedOutletId;
    body['id'] = leadId;
    body["user_id"] = userId;
    for (var data in outletKycDocumentListProvider.kycDocumentList) {
      if (data.base64File.isNotEmpty) {
        print("Image found");
        print(data.documentName);
        print("-------------------");
        uploadedImages[data.documentName] = data.docFileName;
        uploadedImages["doc_file_name"] = data.docFileName;
        body["kyc_detail_ids"].add([
          [5, 0, 0],
          [
            0,
            0,
            {
              "document_id": data.documentId,
              "doc_file": data.base64File,
              "doc_file_name": data.docFileName,
            },
          ],
        ]);
      } else {
        print("Image not found");
        print(data.documentName);
        print("-------------------");
        if(data.docFileName.isNotEmpty){
          uploadedImages[data.documentName] =  data.docFileName;
          uploadedImages[data.docFileName] = "";
        }

      }
    }
    setState(() {});

    // print keys of uploadedImages
    print(uploadedImages['Aadhar Card']?.isEmpty);
  }
  Future<void> getData() async {
    print("getData");
    OutletKycDocumentListProvider outletKycDocumentListProvider =
    Provider.of<OutletKycDocumentListProvider>(context, listen: false);
    OutletDescriptionProvider outletDescriptionProvider =
    Provider.of<OutletDescriptionProvider>(context, listen: false);
    int userId = await SharedPreference.getUserId();
    int leadId = outletDescriptionProvider.selectedOutletId;
    body['id'] = leadId;
    body["user_id"] = userId;

    // List of documents with non-empty base64File
    List<dynamic> documentsWithFiles = outletKycDocumentListProvider.kycDocumentList
        .where((data) => data.base64File.isNotEmpty)
        .toList();

    // Initialize the kyc_detail_ids structure only if there are documents
    if (documentsWithFiles.isNotEmpty) {
      body["kyc_detail_ids"] = <List<dynamic>>[
          [5, 0, 0] // Add this just once at the beginning
      ];

      // Add each document
      for (var data in documentsWithFiles) {
        if (data.documentName.isNotEmpty) {
          uploadedImages[data.documentName] = data.docFileName;
        }

        // Add document
        body["kyc_detail_ids"].add([
          0,
          0,
          {
            "document_id": data.documentId.toString(),
            "doc_file": data.base64File,
            "doc_file_name": data.docFileName,
          }
        ]);
      }
    } else {
      body["kyc_detail_ids"] = [];
    }

    // For documents without files, just update uploadedImages
    for (var data in outletKycDocumentListProvider.kycDocumentList) {
      if (data.base64File.isEmpty && data.documentName.isNotEmpty) {
        uploadedImages[data.documentName] = "";
      }
    }

    cleanUploadedImagesMap();
    setState(() {});
  }

// Add this helper method to clean up the map
  void cleanUploadedImagesMap() {
    // Create a new map to store non-empty key-value pairs
    Map<String, String> cleanedMap = {};

    // Only copy entries with non-empty keys
    uploadedImages.forEach((key, value) {
      if (key.isNotEmpty) {
        cleanedMap[key] = value;
      }
    });

    // Replace the original map with the cleaned one
    uploadedImages = cleanedMap;
  }
  void _showBottomSheet(
    BuildContext context,
    void Function()? onTapGallery,
    void Function()? onTapCamera,
  ) {
    showModalBottomSheet(
      context: context,
      useSafeArea: true,
      builder: (BuildContext context) {
        return SizedBox(
          height: MediaQuery.of(context).size.height * 0.15,
          child: Column(
            children: [
              ListTile(
                leading: Icon(Icons.camera_alt),
                title: Text('Camera'),
                onTap: onTapGallery,
                //     () async {
                //   String? filePath = await Helper().captureImage(context);
                //   setState(() {
                //     _storeLogo = filePath!;
                //   });
                //   print(filePath);
                // },
              ),
              ListTile(
                leading: Icon(Icons.image),
                title: Text('Gallery'),
                onTap: onTapCamera,
                // () async {
                //   String? filePath = await Helper().pickImage(context);
                //   setState(() {
                //     _storeLogo = filePath!;
                //   });
                //   print(filePath);
                // },
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    OutletKycDocumentListProvider outletKycDocumentListProvider =
        Provider.of<OutletKycDocumentListProvider>(context, listen: false);
    return BackgroundWidget(
      headerWidget: Container(
        padding: const EdgeInsets.only(left: 16, right: 16),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            InkWell(
              onTap: () {
                GetxNavigation().goBack();
              },
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  color: AppColors.white,
                  borderRadius: BorderRadius.circular(5),
                ),
                child: Icon(Icons.arrow_back, color: Colors.black, size: 20),
              ),
            ),
            Text(
              'Kyc Documents',
              style: GoogleFonts.poppins(
                fontSize: 24,
                fontWeight: FontWeight.w600,
                color: AppColors.white,
              ),
            ),
            Text(
              'Reset',
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontWeight: FontWeight.w500,
                color: Colors.transparent,
              ),
            ),
          ],
        ),
      ),
      bottomSheetWidget: Container(
        padding: const EdgeInsets.only(top: 20),
        child: Column(
          children: [
            Text(
              "List of KYC documents required for the Payment Gateway Services in India",
              textAlign: TextAlign.center,
              style: GoogleFonts.poppins(
                fontSize: 16,
                fontFeatures: [FontFeature.tabularFigures()],
                fontWeight: FontWeight.w500,
                color: AppColors.headingColor,
              ),
            ),
            Expanded(
              child: ListView.builder(
                itemCount: outletKycDocumentListProvider.kycDocumentList.length,
                itemBuilder: (context, index) {
                  String documentName = outletKycDocumentListProvider
                      .kycDocumentList[index]
                      .documentName;
                  int documentId = outletKycDocumentListProvider
                      .kycDocumentList[index]
                      .documentId;
                  // String image = outletKycDocumentListProvider.kycDocumentList[index].image;
                  bool? isImageUploaded = false;
                  if (uploadedImages[documentName] != null) {
                    isImageUploaded = uploadedImages[documentName]!.isNotEmpty;
                  }
                  return Column(
                    mainAxisAlignment: MainAxisAlignment.start,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(height: 10),
                      Text(
                        documentName,
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontFeatures: [FontFeature.tabularFigures()],
                          fontWeight: FontWeight.w500,
                          color:AppColors.headingColor,
                        ),
                      ),
                      DottedBorder(
                        color:emptyImageIndex.contains(index) ?Colors.red: AppColors.selectDocumentCardBorderColor,
                        borderType: BorderType.RRect,
                        radius: Radius.circular(12),
                        strokeWidth: 1,
                        child: Container(
                          color: AppColors.selectDocumentCardBackgroundColor,
                          width: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Stack(
                              children: [
                                !isImageUploaded
                                    ? InkWell(
                                        onTap: () async {
                                          // if (kIsWeb || kIsWasm) {
                                          //   Get.snackbar(
                                          //     "Error",
                                          //     "This feature is not supported in web",
                                          //     backgroundColor: Colors.red,
                                          //     colorText: Colors.white,
                                          //     snackPosition: SnackPosition.TOP,
                                          //     titleText: Text(
                                          //       "Error",
                                          //       style: TextStyle(
                                          //         color: Colors.white,
                                          //         fontWeight: FontWeight.bold,
                                          //       ),
                                          //     ),
                                          //   );
                                          //   return;
                                          // }
                                          // String? filePath = await Helper()
                                          //     .pickPdf1(context);
                                          // if (filePath.isNull) {
                                          //   return;
                                          // }
                                          // if (filePath!.isNotEmpty) {
                                          //   String base64Image =
                                          //       await Helper.imageToBase64(
                                          //         filePath,
                                          //       );
                                          //   // body["${documentName}_base64"] = base64Image;
                                          //   List<dynamic> tuple1 = [5, 0, 0];
                                          //   List<dynamic> tuple2 = [
                                          //     0,
                                          //     0,
                                          //     {
                                          //       "document_id": documentId,
                                          //       "doc_file": "base64Image",
                                          //       "doc_file_name": filePath
                                          //           .split('/')
                                          //           .last,
                                          //     },
                                          //   ];
                                          //
                                          //   // Combine both into one item for `kyc_detail_ids`
                                          //   List<dynamic> document = [
                                          //     // tuple1,
                                          //     tuple2,
                                          //   ];
                                          //
                                          //   // Add to the body
                                          //   body['kyc_detail_ids'].add(
                                          //     tuple2,
                                          //   );
                                          //   setState(() {
                                          //     uploadedImages[documentName] =
                                          //         filePath;
                                          //   });
                                          // }


                                          // from Copilot
                                          if (kIsWeb || kIsWasm) {
                                            Get.snackbar(
                                              "Error",
                                              "This feature is not supported in web",
                                              backgroundColor: Colors.red,
                                              colorText: Colors.white,
                                              snackPosition: SnackPosition.TOP,
                                              titleText: Text(
                                                "Error",
                                                style: TextStyle(
                                                  color: Colors.white,
                                                  fontWeight: FontWeight.bold,
                                                ),
                                              ),
                                            );
                                            return;
                                          }

                                          String? filePath = await Helper().pickPdf1(context);
                                          if (filePath == null || filePath.isEmpty) {
                                            return;
                                          }

                                          String base64Image = await Helper.imageToBase64(filePath);

                                          // Initialize the structure if it doesn't exist
                                          print(body["kyc_detail_ids"]);
                                          List<dynamic> kyc_details_ids_values = body["kyc_detail_ids"];
                                          print(kyc_details_ids_values.length);

                                          if (kyc_details_ids_values.isEmpty) {
                                            setState(() {
                                              body["kyc_detail_ids"].add([
                                                5,
                                                0,
                                                0
                                              ]);
                                            });

                                          }

                                          // Add the document entry directly
                                          List<dynamic> documentIdList = [
                                            0,
                                            0,
                                            {
                                              "document_id": documentId.toString(),
                                              "doc_file": base64Image,
                                              "doc_file_name": filePath.split('/').last,
                                            }
                                          ];
                                          print(body["kyc_detail_ids"]);
                                          body["kyc_detail_ids"].add(documentIdList);

                                          setState(() {
                                            uploadedImages[documentName] = filePath;
                                          });

                                          print(body);

                                          /// PICK IMAGE OR CAPTURE IMAGE
                                          // _showBottomSheet(
                                          //   context,
                                          //   () async {
                                          //     String? filePath = await Helper()
                                          //         .captureImage(context);
                                          //     if (filePath!.isNotEmpty) {
                                          //       String base64Image =
                                          //           await Helper.imageToBase64(
                                          //             filePath,
                                          //           );
                                          //       // body["${documentName}_base64"] = base64Image;
                                          //       // [0, 0, {"document_id": 1, "image": "base64 string"}]
                                          //       List<dynamic> document = [0, 0];
                                          //       document.add({
                                          //         "document_id": documentId,
                                          //         "image": base64Image,
                                          //       });
                                          //       body['kyc_detail_ids'].add(
                                          //         document,
                                          //       );
                                          //       setState(() {
                                          //         uploadedImages[documentName] =
                                          //             base64Image;
                                          //       });
                                          //     }
                                          //   },
                                          //   () async {
                                          //     String? filePath = await Helper()
                                          //         .pickImage(context);
                                          //     if (filePath!.isNotEmpty) {
                                          //       String base64Image =
                                          //           await Helper.imageToBase64(
                                          //             filePath,
                                          //           );
                                          //       // body["${documentName}_base64"] = base64Image;
                                          //       List<dynamic> document = [0, 0];
                                          //       document.add({
                                          //         "document_id": documentId,
                                          //         "image": base64Image,
                                          //       });
                                          //       body['kyc_detail_ids'].add(
                                          //         document,
                                          //       );
                                          //       setState(() {
                                          //         uploadedImages[documentName] =
                                          //             base64Image;
                                          //       });
                                          //     }
                                          //   },
                                          // );
                                        },
                                        child: Center(
                                          child: Column(
                                            mainAxisAlignment:
                                                MainAxisAlignment.center,
                                            children: [
                                              Image.asset(
                                                "assets/images/image_icon.png",
                                                height: 60,
                                                opacity: AlwaysStoppedAnimation(
                                                  0.5,
                                                ),
                                              ),
                                              Text(
                                                documentName,
                                                textAlign: TextAlign.center,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.black,
                                                ),
                                              ),
                                              Text(
                                                'Support: PDF Only',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 10,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.paragraph,
                                                ),
                                              ),
                                              SizedBox(height: 5),
                                            ],
                                          ),
                                        ),
                                      )
                                    : Center(
                                        child: Container(
                                          height: 100,
                                          alignment: Alignment.center,
                                          decoration: BoxDecoration(
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
                                          ),
                                          child: Text(
                                            uploadedImages[documentName]!
                                                .split('/')
                                                .last,
                                            style: GoogleFonts.poppins(
                                              fontSize: 14,
                                              fontWeight: FontWeight.w500,
                                              color: AppColors.black,
                                            ),
                                          ),
                                        ),

                                        // child: Image.memory(
                                        //   base64Decode(
                                        //     uploadedImages[documentName]!,
                                        //   ),
                                        //   height: 100,
                                        //   width: 100,
                                        //   fit: BoxFit.contain,
                                        // ),
                                      ),
                                !isImageUploaded
                                    ? Container()
                                    : Align(
                                        alignment: Alignment.topRight,
                                        child: IconButton(
                                          onPressed: () {
                                            // setState(() {
                                            //   uploadedImages[documentName] = "";
                                            //   body["kyc_detail_ids"].removeWhere(
                                            //     (element) =>
                                            //         element[1][2]['document_id'] ==
                                            //         documentId,
                                            //   );
                                            // });
                                            // // OutletDescriptionProvider outletDescriptionProvider =
                                            // // Provider.of<OutletDescriptionProvider>(context, listen: false);
                                            // print(
                                            //   "---------------------------------------->",
                                            // );
                                            // body['kyc_detail_ids'].forEach((
                                            //   element,
                                            // ) {
                                            //   print(
                                            //     element[1][2]['document_id'],
                                            //   );
                                            // });
                                            // print(
                                            //   body['kyc_detail_ids'].length,
                                            // );

                                            // From Copilot
                                            setState(() {
                                              uploadedImages[documentName] = "";
                                              // Find and remove the document entry
                                              if (body["kyc_detail_ids"].isNotEmpty && body["kyc_detail_ids"].length > 1) {
                                                // Start from index 1 to skip the [5, 0, 0] entry
                                                for (int i = 1; i < body["kyc_detail_ids"].length; i++) {
                                                  if (body["kyc_detail_ids"][i][2]["document_id"] == documentId.toString()) {
                                                    body["kyc_detail_ids"].removeAt(i);
                                                    break;
                                                  }
                                                }

                                                // If this was the last document, also remove the [5, 0, 0] entry
                                                if (body["kyc_detail_ids"].length == 1) {
                                                  body["kyc_detail_ids"] = [];
                                                }
                                              }
                                            });

                                            // outletDescriptionProvider.updateLead(body);
                                          },
                                          icon: SvgPicture.string(
                                            SvgIcons.deleteIcon,
                                          ),
                                        ),
                                      ),
                              ],
                            ),
                          ),
                        ),
                      ),
                      isImageUploaded
                          ? Container()
                          : Text(
                              "Please upload the document",
                              style: GoogleFonts.poppins(
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                                color:emptyImageIndex.contains(index) ?Colors.red: AppColors.paragraph,
                              ),
                            ),
                    ],
                  );
                },
              ),
            ),
            ElevatedButton(
              onPressed: () {
                print(uploadedImages);
                print(body);
                // varify all images are selected or not
                bool isAllImagesUploaded = true;
                for (var doc in uploadedImages.values) {
                  print(doc);
                  // check the document key and value is not empty
                  if (doc.isEmpty) {
                    isAllImagesUploaded = false;
                    break;
                  }
                }

                // find index of empty image
                emptyImageIndex = [];
                for (int i = 0; i < uploadedImages.length; i++) {
                  if (uploadedImages.values.elementAt(i).isEmpty) {
                    setState(() {
                      emptyImageIndex.add(i);
                    });
                  }
                }
                print(emptyImageIndex);
                print(isAllImagesUploaded);
                if (!isAllImagesUploaded) {
                  Get.snackbar(
                    "Error",
                    "Please upload all the documents",
                    backgroundColor: Colors.red,
                    colorText: Colors.white,
                    snackPosition: SnackPosition.TOP,
                    titleText: Text(
                      "Error",
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  );
                  return;
                }

                body["listing_status"] = "subscribed";
                body["is_subscribed"] = true;
                body["is_subscription_declined"] = false;
                body["stage_id"] = 4;
                body["active"] = true;

                OutletDescriptionProvider outletDescriptionProvider =
                    Provider.of<OutletDescriptionProvider>(
                      context,
                      listen: false,
                    );
                print(jsonEncode(body));
                outletDescriptionProvider.updateLead(
                  body,
                  isBack: false,
                  showMessage: true,
                );
                Get.offAllNamed(HomeScreen.routeName);
              },
              style: ElevatedButton.styleFrom(
                foregroundColor: Colors.white,
                backgroundColor: AppColors.primaryColor,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(30),
                ),
                minimumSize: Size(double.infinity, 50),
              ),
              child: Text(
                "Save",
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
            SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
