// import 'dart:io';
//
// import 'package:dotted_border/dotted_border.dart';
// import 'package:flutter/foundation.dart';
// import 'package:flutter/material.dart';
// import 'package:flutter_svg/svg.dart';
// import 'package:get/get.dart';
// import 'package:google_fonts/google_fonts.dart';
// import 'package:provider/provider.dart';
// import 'package:retail_gpt/Icons/SVG/svg_icons.dart';
// import 'package:retail_gpt/helper/helper.dart';
// import 'package:retail_gpt/models/utility_model/document_model.dart';
// import 'package:retail_gpt/utils/app_colors.dart';
// import 'package:retail_gpt/widgets/background_widget.dart';
//
// import '../../providers/create_new_outlet_screens/create_outlet_provider.dart';
//
// class KycDetailsScreen extends StatefulWidget {
//   static const routeName = "/kyc-details-screen";
//
//   const KycDetailsScreen({super.key});
//
//   @override
//   State<KycDetailsScreen> createState() => _KycDetailsScreenState();
// }
//
// class _KycDetailsScreenState extends State<KycDetailsScreen> {
//   Map<String, dynamic> arguments = {};
//   Map<String, String> uploadedImages = {};
//
//   void _showBottomSheet(
//     BuildContext context,
//     void Function()? onTapGallery,
//     void Function()? onTapCamera,
//   ) {
//     showModalBottomSheet(
//       context: context,
//       useSafeArea: true,
//       builder: (BuildContext context) {
//         return SizedBox(
//           height: MediaQuery.of(context).size.height * 0.15,
//           child: Column(
//             children: [
//               ListTile(
//                 leading: Icon(Icons.camera_alt),
//                 title: Text('Camera'),
//                 onTap: onTapGallery,
//                 //     () async {
//                 //   String? filePath = await Helper().captureImage(context);
//                 //   setState(() {
//                 //     _storeLogo = filePath!;
//                 //   });
//                 //   print(filePath);
//                 // },
//               ),
//               ListTile(
//                 leading: Icon(Icons.image),
//                 title: Text('Gallery'),
//                 onTap: onTapCamera,
//                 // () async {
//                 //   String? filePath = await Helper().pickImage(context);
//                 //   setState(() {
//                 //     _storeLogo = filePath!;
//                 //   });
//                 //   print(filePath);
//                 // },
//               ),
//             ],
//           ),
//         );
//       },
//     );
//   }
//
//   List<DocumentModel> _documentList = [];
//   Map<String,dynamic> body = {};
//   @override
//   void initState() {
//     // TODO: implement initState
//     arguments = Get.arguments as Map<String, dynamic>;
//     print("KYC DOC : ${arguments['kyc']}");
//     body = arguments['body'];
//
//     body['kyc_detail_ids']=[];
//     _documentList = arguments["kyc"];
//     for (var element in _documentList) {
//      print(element.documentName);
//     }
//
//     uploadedImages = { for (var e in _documentList) e.documentName : "" };
//
//     super.initState();
//   }
//
//   @override
//   Widget build(BuildContext context) {
//     return BackgroundWidget(
//       headerWidget: Container(
//         padding: const EdgeInsets.only(left: 16, right: 16),
//         child: Row(
//           mainAxisAlignment: MainAxisAlignment.spaceBetween,
//           children: [
//             InkWell(
//               onTap: () {
//                 Navigator.of(context).pop();
//               },
//               child: SvgPicture.string(
//                 SvgIcons.navigationBackIcon,
//                 key: const Key('navigationBackIcon'),
//               ),
//             ),
//             Text(
//               'Upload Documents',
//               style: GoogleFonts.poppins(
//                 fontSize: 24,
//                 fontWeight: FontWeight.w600,
//                 color: AppColors.white,
//               ),
//             ),
//             Text(
//               'Reset',
//               style: GoogleFonts.poppins(
//                 fontSize: 16,
//                 fontWeight: FontWeight.w500,
//                 color: Colors.transparent,
//               ),
//             ),
//           ],
//         ),
//       ),
//       bottomSheetWidget: Container(
//         padding: const EdgeInsets.only(top: 20),
//         child: Column(
//           children: [
//             Text(
//               "List of KYC documents required for the Payment Gateway Services in India",
//               textAlign: TextAlign.center,
//               style: GoogleFonts.poppins(
//                 fontSize: 16,
//                 fontFeatures: [FontFeature.tabularFigures()],
//                 fontWeight: FontWeight.w500,
//                 color: AppColors.headingColor,
//               ),
//             ),
//             Expanded(
//               child: ListView.builder(
//                 itemCount: _documentList.length,
//                 itemBuilder: (context, index) {
//                   String documentName = _documentList[index].documentName;
//                   int documentId = _documentList[index].id;
//                   return Column(
//                     mainAxisAlignment: MainAxisAlignment.start,
//                     crossAxisAlignment: CrossAxisAlignment.start,
//                     children: [
//                       SizedBox(height: 10),
//                       Text(
//                         documentName,
//                         style: GoogleFonts.poppins(
//                           fontSize: 16,
//                           fontFeatures: [FontFeature.tabularFigures()],
//                           fontWeight: FontWeight.w500,
//                           color: AppColors.headingColor,
//                         ),
//                       ),
//                       DottedBorder(
//                         color: AppColors.paragraph,
//                         borderType: BorderType.RRect,
//                         radius: Radius.circular(10),
//                         strokeWidth: 1,
//                         child: SizedBox(
//                           width: double.infinity,
//                           child: Padding(
//                             padding: const EdgeInsets.all(8.0),
//                             child: Stack(
//                               children: [
//                                 uploadedImages[documentName]!.isEmpty
//                                     ? InkWell(
//                                       onTap: () async {
//                                         if (kIsWeb || kIsWasm) {
//                                           Get.snackbar(
//                                             "Error",
//                                             "This feature is not supported in web",
//                                             backgroundColor: Colors.red,
//                                             colorText: Colors.white,
//                                             snackPosition: SnackPosition.TOP,
//                                             titleText: Text(
//                                               "Error",
//                                               style: TextStyle(
//                                                 color: Colors.white,
//                                                 fontWeight: FontWeight.bold,
//                                               ),
//                                             ),
//                                           );
//                                           return;
//                                         }
//                                         _showBottomSheet(
//                                           context,
//                                           () async {
//                                             String? filePath = await Helper()
//                                                 .captureImage(context);
//                                             if(filePath!.isNotEmpty){
//                                               String base64Image = await Helper.imageToBase64(filePath);
//                                               // body["${documentName}_base64"] = base64Image;
//                                               // [0, 0, {"document_id": 1, "image": "base64 string"}]
//                                               List<dynamic> document = [0,0];
//                                               document.add({
//                                                 "document_id": documentId,
//                                                 // "image": base64Image
//                                               });
//                                               body['kyc_detail_ids'].add(document);
//                                               setState(() {
//                                                 uploadedImages[documentName] = filePath;
//                                               });
//                                             }
//                                           },
//                                           () async {
//                                             String? filePath = await Helper()
//                                                 .pickImage(context);
//                                             if(filePath!.isNotEmpty){
//                                               String base64Image = await Helper.imageToBase64(filePath);
//                                               // body["${documentName}_base64"] = base64Image;
//                                               // [0,0, {"document_id": 1, "doc_file": "base64 string","doc_file_name":""}]
//                                               List<dynamic> document = [0,0];
//                                               document.add({
//                                                 "document_id": documentId,
//                                                 // "image": base64Image,
//                                               });
//                                               body['kyc_detail_ids'].add(document);
//                                               setState(() {
//                                                 uploadedImages[documentName] = filePath;
//                                               });
//                                             }
//                                           },
//                                         );
//                                       },
//                                       child: Center(
//                                         child: Column(
//                                           mainAxisAlignment:
//                                               MainAxisAlignment.center,
//                                           children: [
//                                             Image.asset(
//                                               "assets/images/image_icon.png",
//                                               height: 60,
//                                               opacity: AlwaysStoppedAnimation(
//                                                 0.5,
//                                               ),
//                                             ),
//                                             Text(
//                                               documentName,
//                                               textAlign: TextAlign.center,
//                                               style: GoogleFonts.poppins(
//                                                 fontSize: 14,
//                                                 fontWeight: FontWeight.w500,
//                                                 color: AppColors.black,
//                                               ),
//                                             ),
//                                             Text(
//                                               'Support: JPG, JPEG, PNG, HEIC',
//                                               style: GoogleFonts.poppins(
//                                                 fontSize: 10,
//                                                 fontWeight: FontWeight.w500,
//                                                 color: AppColors.paragraph,
//                                               ),
//                                             ),
//                                             SizedBox(height: 5),
//                                           ],
//                                         ),
//                                       ),
//                                     )
//                                     : Center(
//                                       child: Image.file(
//                                         File(uploadedImages[documentName]!),
//                                         height: 100,
//                                         width: 100,
//                                         fit: BoxFit.contain,
//                                       ),
//                                     ),
//                                 uploadedImages[documentName]!.isEmpty
//                                     ? Container()
//                                     : Align(
//                                       alignment: Alignment.topRight,
//                                       child: IconButton(
//                                         onPressed: () {
//                                           setState(() {
//                                             uploadedImages[documentName] = "";
//                                           });
//                                         },
//                                         icon: SvgPicture.string(SvgIcons.deleteIcon),
//                                       ),
//                                     ),
//                               ],
//                             ),
//                           ),
//                         ),
//                       ),
//                       uploadedImages[documentName]!.isNotEmpty ? Container(): Text(
//                         "Please upload the document",
//                         style: GoogleFonts.poppins(
//                           fontSize: 14,
//                           fontWeight: FontWeight.w500,
//                           color: AppColors.paragraph,
//                         ),
//                       ),
//                     ],
//                   );
//                 },
//               ),
//             ),
//             ElevatedButton(
//               onPressed: () {
//                 // varify all images are selected or not
//                 bool isAllImagesUploaded = true;
//                 for (var doc in uploadedImages.values) {
//                   if (doc.isEmpty) {
//                     isAllImagesUploaded = false;
//                     break;
//                   }
//                 }
//                 print(isAllImagesUploaded);
//                 if (!isAllImagesUploaded) {
//                   Get.snackbar(
//                     "Error",
//                     "Please upload all the documents",
//                     backgroundColor: Colors.red,
//                     colorText: Colors.white,
//                     snackPosition: SnackPosition.TOP,
//                     titleText: Text(
//                       "Error",
//                       style: TextStyle(
//                         color: Colors.white,
//                         fontWeight: FontWeight.bold,
//                       ),
//                     ),
//                   );
//                   return;
//                 }
//                 CreateOutletProvider
//                 createOutletProvider =
//                 Provider.of<CreateOutletProvider>(
//                   context,
//                   listen: false,
//                 );
//
//                 createOutletProvider.updateOutletForSubscription(body);
//               },
//               style: ElevatedButton.styleFrom(
//                 foregroundColor: Colors.white,
//                 backgroundColor: AppColors.primaryColor,
//                 shape: RoundedRectangleBorder(
//                   borderRadius: BorderRadius.circular(30),
//                 ),
//                 minimumSize: Size(double.infinity, 50),
//               ),
//               child: Text(
//                 "Save",
//                 style: Theme.of(context).textTheme.titleMedium!.copyWith(
//                   fontWeight: FontWeight.bold,
//                   color: Colors.white,
//                 ),
//               ),
//             ),
//             SizedBox(height: 20,)
//           ],
//         ),
//       ),
//     );
//   }
// }
