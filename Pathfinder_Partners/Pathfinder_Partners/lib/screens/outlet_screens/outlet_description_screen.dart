import 'dart:convert';
import 'dart:io';

import 'package:retail_gpt/models/utility_model/business_category_model.dart';
import 'package:retail_gpt/providers/utility_provider/time_provider.dart';
import 'package:dotted_border/dotted_border.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/svg.dart';
import 'package:geolocator/geolocator.dart';
import 'package:get/get.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:retail_gpt/Icons/SVG/svg_icons.dart';
import 'package:retail_gpt/helper/helper.dart';
import 'package:retail_gpt/local_storage/shared_preference.dart';
import 'package:retail_gpt/navigation/getx_navigation.dart';
import 'package:retail_gpt/providers/create_new_outlet_screens/outlet_description_provider.dart';
import 'package:retail_gpt/providers/outlet_kyc_document/outlet_kyc_document_list_provider.dart';
import 'package:retail_gpt/providers/utility_provider/business_sub_category_list.dart';
import 'package:retail_gpt/screens/outlet_screens/kyc_description_screen.dart';
import 'package:retail_gpt/utils/app_colors.dart';
import 'package:retail_gpt/utils/clear_provider.dart';
import 'package:retail_gpt/utils/outlet_creation_body.dart';
import 'package:retail_gpt/utils/utility_data.dart';
import 'package:retail_gpt/widgets/background_widget.dart';

import '../../models/utility_model/business_sub_category.dart';
import '../../providers/utility_provider/business_category_list_provider.dart';
import '../../providers/utility_provider/channel_type_provider.dart';
import '../../providers/utility_provider/city_list_provider.dart';
import '../../providers/utility_provider/country_list_provider.dart';
import '../../providers/utility_provider/district_list_provider.dart';
import '../../providers/utility_provider/local_data_provider.dart';
import '../../providers/utility_provider/pin_code_list_provider.dart';
import '../../providers/utility_provider/retailer_ownership_provider.dart';
import '../../providers/utility_provider/state_list_provider.dart';
import '../../widgets/loading_widget.dart';

class OutletDescriptionScreen extends StatefulWidget {
  static const String routeName = '/outlet-description-screen';

  const OutletDescriptionScreen({super.key});

  @override
  State<OutletDescriptionScreen> createState() =>
      _OutletDescriptionScreenState();
}

class _OutletDescriptionScreenState extends State<OutletDescriptionScreen> {
  Map<String, dynamic> _navigationArgumentData = {};
  final _formKey = GlobalKey<FormState>();
  int leadId = -1;

  //Brand Name
  final _brandNameController = TextEditingController();

  //Brand Description
  final _brandDescriptionController = TextEditingController();

  // Brand Type
  final _brandTypeController = TextEditingController();

  // Brand types
  List<Map<String, dynamic>> brandTypes = [
    {"brandName": "Self Own", "brandValue": "self_own"},
    {"brandName": "Franchise", "brandValue": "franchise"},
  ];
  final ScrollController _scrollController = ScrollController();
  final GlobalKey _brandNameKey = GlobalKey();

  // Retailer Name
  final _retailerNameController = TextEditingController();

  // pos name
  final _posNameController = TextEditingController();

  // pos number
  final _posNumberController = TextEditingController();

  // next follow up date
  final _nextFollowUpDateController = TextEditingController();

  // _descriptionController
  final _descriptionController = TextEditingController();

  //Display Street 1
  final _street1Controller = TextEditingController();

  // Display Street 2
  final _street2Controller = TextEditingController();

  // Country
  final _countryController = TextEditingController();

  // State
  final _stateController = TextEditingController();

  // district
  final _districtController = TextEditingController();

  // City
  final _cityController = TextEditingController();

  // pinCode
  final _pinCodeController = TextEditingController();

  // GPS Location
  final _gpsLocationController = TextEditingController();

  // website
  final _websiteController = TextEditingController();

  // Contact Name
  final _contactNameController = TextEditingController();

  // Mobile Number
  final _mobileNumberController = TextEditingController();

  // Email ID
  final _emailIdController = TextEditingController();

  //Display Address
  final _displayAddressController = TextEditingController();

  // Opening Time
  final _openingTimeController = TextEditingController();

  // Closing Time
  final _closingTimeController = TextEditingController();

  // Daily Avg Revenue
  final _dailyAvgRevenueController = TextEditingController();

  // Class of Retailer (Drop Down)
  final _classOfRetailerController = TextEditingController();

  // Retailer Ownership (Drop Down)
  final _retailerOwnershipController = TextEditingController();

  // Channel type (Drop Down)
  final _channelTypeController = TextEditingController();

  // Business Category (Drop Down)
  final _businessCategoryController = TextEditingController();

  // Business Sub Category (Drop Down)
  final _businessSubCategoryController = TextEditingController();
  int retailerCategoryId = -1;

  bool isEdit = false;

  // store logo
  String _storeLogo = '';
  bool _isStoreLogoSelected = true;

  // store image
  String _storeImage1 = '';
  bool _isStoreImage1Selected = true;
  String _storeImage2 = '';
  bool _isStoreImage2Selected = true;
  String _storeImage3 = '';
  bool _isStoreImage3Selected = true;

  bool isLoading = true;

  final input = DateFormat('dd/MM/yyyy');
  final output = DateFormat('yyyy-MM-dd');

  DateTime formatDate(String date) {
    // Assuming the date is in the format "dd/MM/yyyy"
    // Split the date string into components
    List<String> dateComponents = date.split('/');
    // Create a new DateTime object using the components
    // Note: Month is 0-based in DateTime, so we need to subtract 1 from the month value
    int day = int.parse(dateComponents[0]);
    int month = int.parse(dateComponents[1]);
    int year = int.parse(dateComponents[2]);
    // Create a DateTime object
    // return DateTime(year, month - 1, day);
    // Convert to ISO 8601 format
    String isoDate =
        "$year-${month.toString().padLeft(2, '0')}-${day.toString().padLeft(2, '0')}";
    // Parse the ISO 8601 date string
    return DateTime.parse(isoDate);
    // return DateTime.parse(date);
  }

  InputBorder? border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: Colors.grey.shade300),
  );
  InputBorder? errorBorder = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: Colors.red),
  );
  TextStyle textStyle = GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.black,
  );

  TextStyle labelStyle = GoogleFonts.poppins(
    fontSize: 16,
    fontWeight: FontWeight.w500,
    color: AppColors.paragraph,
  );

  Widget suffixIcon(FocusNode focusNode) {
    return InkWell(
      onTap: () {
        if (focusNode.hasFocus) {
          focusNode.unfocus();
        } else {
          focusNode.requestFocus();
        }
      },
      child: Icon(Icons.arrow_drop_down),
    );
  }

  Widget buildOptionsView(
    Iterable<String> options,
    Function(String) onSelected,
  ) {
    return Align(
      alignment: Alignment.topLeft,
      child: Material(
        elevation: 4.0,
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        child: SizedBox(
          width: MediaQuery.of(context).size.width - 40,
          child: ListView.builder(
            padding: EdgeInsets.zero,
            shrinkWrap: true,
            itemCount: options.length,
            itemBuilder: (context, index) {
              final option = options.elementAt(index);
              return InkWell(
                onTap: () => onSelected(option),
                child: Container(
                  // height: 24,
                  padding: EdgeInsets.symmetric(vertical: 5, horizontal: 8),
                  child: Text(
                    option,
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w400,
                      color: AppColors.homePageCardTextColor,
                    ),
                  ),
                ),
              );
            },
          ),
        ),
      ),
    );
  }

  Color getLeadStatusColor(String status) {
    if (status == "decline_listing") {
      return AppColors.changeToDeclineFreeListingLeadStatusTextColor; // decline
    }
    if (status == "subscribed") {
      return AppColors
          .changeToSubscriptionListingLeadStatusTextColor; // subscription
    }
    if (status == "free_listing") {
      return AppColors.changeToFreeListingLeadStatusTextColor; // Free listing
    }
    if (status == "decline_subscription") {
      return AppColors
          .changeToDeclineSubscriptionListingLeadStatusTextColor; //decline subscription
    }
    return Color(0xFFD1576B); // decline
  }

  Color getLeadStatusBackgroundColor(String status) {
    if (status == "decline_listing") {
      return AppColors.changeToDeclineFreeListingLeadStatusFillColor; // decline
    }
    if (status == "subscribed") {
      return AppColors
          .changeToSubscriptionListingLeadStatusFillColor; // subscription
    }
    if (status == "free_listing") {
      return AppColors.changeToFreeListingLeadStatusFillColor; // Free listing
    }
    if (status == "decline_subscription") {
      return AppColors
          .changeToDeclineSubscriptionListingLeadStatusFillColor; //decline subscription
    }
    return Color(0xFFFFEEF0); // decline
  }

  InputDecoration inputDecoration(String hintText) => InputDecoration(
    hintText: hintText,
    counterText: "",
    hintStyle: TextStyle(color: AppColors.paragraph),
    contentPadding: EdgeInsets.only(left: 10, right: 0, top: 0, bottom: 0),
    border: border,
    disabledBorder: border,
    enabledBorder: border,
    focusedBorder: border,
  );

  InputDecoration dropdownDecoration() => InputDecoration(
    contentPadding: EdgeInsets.only(left: 10, right: 0, top: 0, bottom: 0),
    border: border,
    enabledBorder: border,
    focusedBorder: border,
    errorBorder: errorBorder,
    disabledBorder: border,
    focusedErrorBorder: border,
  );

  void showResetConfirmationDialog(
    BuildContext context,
    VoidCallback onConfirm,
  ) {
    showDialog(
      context: context,
      builder: (BuildContext context) {
        return Theme.of(context).platform == TargetPlatform.iOS
            ? CupertinoAlertDialog(
                title: Text("Confirm Reset"),
                content: Text("Are you sure you want to reset the form?"),
                actions: [
                  CupertinoDialogAction(
                    child: Text("Cancel"),
                    onPressed: () => Navigator.pop(context),
                  ),
                  CupertinoDialogAction(
                    isDestructiveAction: true,
                    child: Text("Reset"),
                    onPressed: () {
                      Navigator.pop(context);
                      onConfirm(); // Call reset function
                    },
                  ),
                ],
              )
            : AlertDialog(
                title: Text("Confirm Reset"),
                content: Text("Are you sure you want to reset the form?"),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: Text("Cancel"),
                  ),
                  TextButton(
                    onPressed: () {
                      Navigator.pop(context);
                      onConfirm(); // Call reset function
                    },
                    child: Text("Reset", style: TextStyle(color: Colors.red)),
                  ),
                ],
              );
      },
    );
  }

  void resetForm() {
    _brandNameController.clear();
    _retailerNameController.clear();
    _brandDescriptionController.clear();
    _brandTypeController.clear();
    _posNameController.clear();
    _posNumberController.clear();
    _nextFollowUpDateController.clear();
    _street1Controller.clear();
    _descriptionController.clear();
    _street2Controller.clear();
    _countryController.clear();
    _stateController.clear();
    _cityController.clear();
    _pinCodeController.clear();
    _gpsLocationController.clear();
    _contactNameController.clear();
    _mobileNumberController.clear();
    _emailIdController.clear();
    _displayAddressController.clear();
    _openingTimeController.clear();
    _closingTimeController.clear();
    _dailyAvgRevenueController.clear();
    _classOfRetailerController.clear();
    _retailerOwnershipController.clear();
    _channelTypeController.clear();
    _businessCategoryController.clear();
    _businessSubCategoryController.clear();
    _websiteController.clear();
    _storeLogo = '';
    _isStoreLogoSelected = true;
    _storeImage1 = '';
    _isStoreImage1Selected = true;
    _storeImage2 = '';
    _isStoreImage2Selected = true;
    _storeImage3 = '';
    _isStoreImage3Selected = true;
    _formKey.currentState!.reset();
    setState(() {});
  }

  // Call this function when you want to show the dialog
  void confirmReset(BuildContext context) {
    showResetConfirmationDialog(context, resetForm);
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

  void setDisplayAddress() {
    List<String> address = List.filled(7, "");
    CountryListProvider countryListProvider = Provider.of<CountryListProvider>(
      context,
      listen: false,
    );
    StateListProvider stateListProvider = Provider.of<StateListProvider>(
      context,
      listen: false,
    );
    DistrictListProvider districtListProvider =
        Provider.of<DistrictListProvider>(context, listen: false);
    CityListProvider cityListProvider = Provider.of<CityListProvider>(
      context,
      listen: false,
    );
    PinCodeListProvider pinCodeListProvider = Provider.of<PinCodeListProvider>(
      context,
      listen: false,
    );

    //print(_countryController.text);

    address[0] = _street1Controller.text;

    address[1] = _street2Controller.text;
    address[2] =
        _districtController.text.isNotEmpty &&
            int.parse(_districtController.text) > 0
        ? districtListProvider
              .getSelectedDistrict(int.parse(_districtController.text))
              .name
        : "";
    address[3] =
        _cityController.text.isNotEmpty && int.parse(_cityController.text) > 0
        ? cityListProvider.getSelectedCity(int.parse(_cityController.text)).name
        : "";
    address[4] =
        _stateController.text.isNotEmpty && int.parse(_stateController.text) > 0
        ? stateListProvider
              .getSelectedState(int.parse(_stateController.text))
              .name
        : "";
    address[5] =
        _countryController.text.isNotEmpty &&
            int.parse(_countryController.text) > 0
        ? countryListProvider
              .getSelectedCountry(int.parse(_countryController.text))
              .name
        : "";
    address[6] =
        _pinCodeController.text.isNotEmpty &&
            int.parse(_pinCodeController.text) > 0
        ? pinCodeListProvider
              .getSelectedPinCode(int.parse(_pinCodeController.text))
              .pinCode
        : "";
    setState(() {
      // Filter out empty values and join with ", "
      _displayAddressController.text = address
          .where((e) => e.isNotEmpty)
          .join(", ");
    });
  }

  Widget freeListing() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.changeToFreeListingLeadStatusFillColor,
        border: Border.all(
          color: AppColors.changeToFreeListingLeadStatusBorderColor,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        spacing: 10,
        children: [
          SvgPicture.string(
            SvgIcons.subscriptionIcon,
            color: AppColors.changeToFreeListingLeadStatusBorderColor,
          ),
          Text(
            "Free Listing",
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.changeToFreeListingLeadStatusTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget declinedSubscription() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.changeToDeclineSubscriptionListingLeadStatusFillColor,
        border: Border.all(
          color:
              AppColors.changeToDeclineSubscriptionListingLeadStatusBorderColor,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        spacing: 10,
        children: [
          SvgPicture.string(
            SvgIcons.subscriptionIcon,
            color: AppColors
                .changeToDeclineSubscriptionListingLeadStatusBorderColor,
          ),
          Text(
            "Declined Subscription",
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors
                  .changeToDeclineSubscriptionListingLeadStatusTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget subscribed() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.changeToSubscriptionListingLeadStatusFillColor,
        border: Border.all(
          color: AppColors.changeToSubscriptionListingLeadStatusBorderColor,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        spacing: 10,
        children: [
          SvgPicture.string(
            SvgIcons.subscriptionIcon,
            color: AppColors.changeToSubscriptionListingLeadStatusBorderColor,
          ),
          Text(
            "Subscribed",
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.changeToSubscriptionListingLeadStatusTextColor,
            ),
          ),
        ],
      ),
    );
  }

  Widget declinedListing() {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.changeToDeclineFreeListingLeadStatusFillColor,
        border: Border.all(
          color: AppColors.changeToDeclineFreeListingLeadStatusBorderColor,
        ),
        borderRadius: BorderRadius.circular(10),
      ),
      padding: EdgeInsets.symmetric(horizontal: 20, vertical: 10),
      child: Row(
        spacing: 10,
        children: [
          SvgPicture.string(
            SvgIcons.subscriptionIcon,
            color: AppColors.changeToDeclineFreeListingLeadStatusBorderColor,
          ),
          Text(
            "Declined",
            style: GoogleFonts.poppins(
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: AppColors.changeToDeclineFreeListingLeadStatusTextColor,
            ),
          ),
        ],
      ),
    );
  }

  @override
  void initState() {
    // TODO: implement initState
    _navigationArgumentData = Get.arguments as Map<String, dynamic>;
    int id = _navigationArgumentData['_id'] as int;
    leadId = id;
    // leadStatus = _navigationArgumentData['status'] as String;

    OutletDescriptionProvider outletDescriptionProvider =
        Provider.of<OutletDescriptionProvider>(context, listen: false);

    Future.microtask(() async {
      // try {
      ClearProvider.clearLocationBaseProviders(context);
      await outletDescriptionProvider.getOutlet(id);
      setData();
      // }catch(e){
      //   print("Error in initState: $e");
      //   setState(() {
      //     isLoading = false;
      //   });
      // }
    });

    super.initState();
  }

  @override
  void dispose() {
    // TODO: implement dispose
    super.dispose();
  }

  Future<void> callProviders() async {
    OutletDescriptionProvider outletDescriptionProvider =
        Provider.of<OutletDescriptionProvider>(context, listen: false);

    // country list provider
    CountryListProvider countryListProvider = Provider.of<CountryListProvider>(
      context,
      listen: false,
    );
    await countryListProvider.getCountryList();
    if (outletDescriptionProvider.outletList[0].countryId > 0) {
      countryListProvider.setSelectedCountryId(
        outletDescriptionProvider.outletList[0].countryId,
      );
    }

    // retailer ownership provider
    RetailerOwnershipProvider retailerOwnershipProvider =
        Provider.of<RetailerOwnershipProvider>(context, listen: false);
    OutletKycDocumentListProvider outletKycDocumentListProvider =
        Provider.of<OutletKycDocumentListProvider>(context, listen: false);
    if (countryListProvider.selectedCountryId > 0) {
      await retailerOwnershipProvider.getRetailerOwnershipList(
        outletDescriptionProvider.outletList[0].countryId,
      );
      if (retailerOwnershipProvider.retailerOwnershipList.isNotEmpty) {
        //print(outletDescriptionProvider.outletList[0].retailerOwnershipId);
        if (outletDescriptionProvider.outletList[0].retailerOwnershipId > 0) {
          retailerOwnershipProvider.setSelectedRetailerOwnershipId(
            outletDescriptionProvider.outletList[0].retailerOwnershipId,
          );
          // await outletDescriptionProvider.getKycDocumentList(
          //   outletDescriptionProvider.outletList[0].retailerOwnershipId,
          // );
          outletKycDocumentListProvider.fetchAndMergeKycDocuments(
            outletDescriptionProvider.outletList[0].retailerOwnershipId,
            outletDescriptionProvider.outletList[0].id,

          );
        }
      }
    }

    // state list provider
    StateListProvider stateListProvider = Provider.of<StateListProvider>(
      context,
      listen: false,
    );
    if (countryListProvider.selectedCountryId > 0) {
      await stateListProvider.getStateList(
        outletDescriptionProvider.outletList[0].countryId,
      );
    }
    if (outletDescriptionProvider.outletList[0].stateId > 0) {
      stateListProvider.setSelectedStateId(
        outletDescriptionProvider.outletList[0].stateId,
      );
    }

    // district list provider
    DistrictListProvider districtListProvider =
        Provider.of<DistrictListProvider>(context, listen: false);
    if (stateListProvider.selectedStateId > 0) {
      await districtListProvider.getDistrictList(
        outletDescriptionProvider.outletList[0].stateId,
      );
    }

    if (outletDescriptionProvider.outletList[0].districtId > 0) {
      districtListProvider.setSelectedDistrictId(
        outletDescriptionProvider.outletList[0].districtId,
      );
    }

    // city list provider
    CityListProvider cityListProvider = Provider.of<CityListProvider>(
      context,
      listen: false,
    );
    if (districtListProvider.selectedDistrictId > 0) {
      await cityListProvider.getCityList(
        outletDescriptionProvider.outletList[0].districtId,
      );
    }
    if (outletDescriptionProvider.outletList[0].cityId > 0) {
      cityListProvider.setSelectedCityId(
        outletDescriptionProvider.outletList[0].cityId,
      );
    }

    // pin code list provider
    PinCodeListProvider pinCodeListProvider = Provider.of<PinCodeListProvider>(
      context,
      listen: false,
    );
    if (cityListProvider.selectedCityId > 0) {
      await pinCodeListProvider.getPinCode(
        outletDescriptionProvider.outletList[0].cityId,
      );
    }
    if (outletDescriptionProvider.outletList[0].pinCodeId > 0) {
      pinCodeListProvider.setSelectedPinCodeId(
        outletDescriptionProvider.outletList[0].pinCodeId,
      );
    }

    // channel type provider
    ChannelTypeProvider channelTypeProvider = Provider.of<ChannelTypeProvider>(
      context,
      listen: false,
    );
    await channelTypeProvider.getChannelTypeList();
    if (outletDescriptionProvider.outletList[0].channelId > 0) {
      channelTypeProvider.setSelectedChannelTypeId(
        outletDescriptionProvider.outletList[0].channelId,
      );
    }

    // business category provider
    BusinessCategoryListProvider businessCategoryListProvider =
        Provider.of<BusinessCategoryListProvider>(context, listen: false);
    await businessCategoryListProvider.getBusinessCategoryList();
    if (outletDescriptionProvider.outletList[0].businessCategoryId > 0) {
      businessCategoryListProvider.setSelectedBusinessCategoryId(
        outletDescriptionProvider.outletList[0].businessCategoryId,
      );
    }
    // business sub category provider
    BusinessSubCategoryList businessSubCategoryListProvider =
        Provider.of<BusinessSubCategoryList>(context, listen: false);

    if (outletDescriptionProvider.outletList[0].businessCategoryId > 0) {
      await businessSubCategoryListProvider.getBusinessSubCategoryList(
        outletDescriptionProvider.outletList[0].businessCategoryId,
      );
    }
    if (outletDescriptionProvider.outletList[0].businessSubCategoryId > 0) {
      businessSubCategoryListProvider.getSelectedBusinessSubCategory(
        outletDescriptionProvider.outletList[0].businessSubCategoryId,
      );
    }
  }

  Future<void> setData() async {
    // try {
    OutletDescriptionProvider outletDescriptionProvider =
        Provider.of<OutletDescriptionProvider>(context, listen: false);
    TimeProvider timeProvider = Provider.of<TimeProvider>(
      context,
      listen: false,
    );
    Future.wait([timeProvider.getOpeningTime(), timeProvider.getClosingTime()]);

    if (outletDescriptionProvider.outletList.isEmpty) {
      return;
    }
    await callProviders();

    setState(() {
      leadStatus = outletDescriptionProvider.outletList[0].leadStatus;
      _brandDescriptionController.text =
          outletDescriptionProvider.outletList[0].brandDescription;
      _posNameController.text =
          outletDescriptionProvider.outletList[0].pos_name;
      _posNumberController.text =
          outletDescriptionProvider.outletList[0].pos_no;
      _nextFollowUpDateController.text =
          outletDescriptionProvider.outletList[0].next_follow_up_date;
      _brandTypeController.text =
          outletDescriptionProvider.outletList[0].brandType;
      //print(outletDescriptionProvider.outletList[0].brandName);
      _brandNameController.text =
          outletDescriptionProvider.outletList[0].brandName;
      _retailerNameController.text =
          outletDescriptionProvider.outletList[0].name;
      _descriptionController.text =
          outletDescriptionProvider.outletList[0].description;
      _street1Controller.text = outletDescriptionProvider.outletList[0].street;
      _street2Controller.text = outletDescriptionProvider.outletList[0].street2;
      _countryController.text = outletDescriptionProvider
          .outletList[0]
          .countryId
          .toString();
      if (int.parse(_countryController.text) > 0) {
        _stateController.text = outletDescriptionProvider.outletList[0].stateId
            .toString();
        _retailerOwnershipController.text = outletDescriptionProvider
            .outletList[0]
            .retailerOwnershipId
            .toString();

        if (int.parse(_stateController.text) > 0) {
          _districtController.text = outletDescriptionProvider
              .outletList[0]
              .districtId
              .toString();
          if (int.parse(_districtController.text) > 0) {
            _cityController.text = outletDescriptionProvider
                .outletList[0]
                .cityId
                .toString();
            if (int.parse(_cityController.text) > 0) {
              _pinCodeController.text = outletDescriptionProvider
                  .outletList[0]
                  .pinCodeId
                  .toString();
            } else {
              _pinCodeController.text = "0";
            }
          } else {
            _cityController.text = "0";
          }
        } else {
          _districtController.text = "0";
        }
      } else {
        _stateController.text = "0";
      }

      _gpsLocationController.text =
          "${outletDescriptionProvider.outletList[0].lattitude} ,${outletDescriptionProvider.outletList[0].longitude}";
      _websiteController.text = outletDescriptionProvider.outletList[0].website;
      _contactNameController.text =
          outletDescriptionProvider.outletList[0].contactName;
      _mobileNumberController.text =
          outletDescriptionProvider.outletList[0].mobile;
      _emailIdController.text = outletDescriptionProvider.outletList[0].email;
      // _displayAddressController.text = "Demo Display Address";
      // _openingTimeController.text = "09:00 AM";
      // _closingTimeController.text = "09:00 PM";
      _dailyAvgRevenueController.text = outletDescriptionProvider
          .outletList[0]
          .expectedRevenue
          .toString();
      _classOfRetailerController.text =
          outletDescriptionProvider.outletList[0].classOfRetailer;

      _channelTypeController.text = outletDescriptionProvider
          .outletList[0]
          .channelId
          .toString();
      _businessCategoryController.text = outletDescriptionProvider
          .outletList[0]
          .businessCategoryId
          .toString();
      _businessSubCategoryController.text = outletDescriptionProvider
          .outletList[0]
          .businessSubCategoryId
          .toString();
      if (outletDescriptionProvider.outletList[0].openingId > 0) {
        _openingTimeController.text = outletDescriptionProvider
            .outletList[0]
            .openingId
            .toString();
      }

      if (outletDescriptionProvider.outletList[0].closingId > 0) {
        _closingTimeController.text = outletDescriptionProvider
            .outletList[0]
            .closingId
            .toString();
      }

      _storeLogo = cleanBase64String(
        outletDescriptionProvider.outletList[0].base64Logo,
      );
      _storeImage1 = cleanBase64String(
        outletDescriptionProvider.outletList[0].base64Image1,
      );
      _storeImage2 = cleanBase64String(
        outletDescriptionProvider.outletList[0].base64Image2,
      );
      _storeImage3 = cleanBase64String(
        outletDescriptionProvider.outletList[0].base64Image3,
      );
      if (outletDescriptionProvider.outletList[0].type == "opportunity" &&
          outletDescriptionProvider.outletList[0].stageId == 1) {
        // leadStatus = "free-listing";
      }

      // if (outletDescriptionProvider.outletList[0].type == "opportunity" &&
      //     outletDescriptionProvider.outletList[0].stageId == 1 ) {
      //   leadStatus = "decline-subscription";
      // }

      if (outletDescriptionProvider.outletList[0].type == "opportunity" &&
          outletDescriptionProvider.outletList[0].stageId == 4) {
        // leadStatus = "subscription";
      }
      // if (outletDescriptionProvider.outletList[0].type == "lead" &&
      //     outletDescriptionProvider.outletList[0].stageId == 1) {
      //   leadStatus = "decline";
      // }
      if (outletDescriptionProvider.outletList[0].type == "lead") {
        // leadStatus = "decline";
      }
      isLoading = false;
    });

    setDisplayAddress();
    // } catch (e) {
    //   print("Error in setData: $e");
    //   // Handle the error as needed
    //   setState(() {
    //     isLoading = false;
    //   });
    // }
  }

  String leadStatus = "";

  Widget statusWidget(String status) {
    Widget statusWidget = Container();
    //print("status of uchiha : $status");
    switch (status) {
      case "free_listing":
        {
          statusWidget = freeListing();
        }
      case "decline_subscription":
        {
          statusWidget = declinedSubscription();
        }
      case "subscribed":
        {
          statusWidget = subscribed();
        }
      case "decline_listing":
        {
          statusWidget = declinedListing();
        }
      default:
        {
          statusWidget = Container();
        }
    }
    return statusWidget;
  }

  String cleanBase64String(String base64String) {
    return base64String;
  }

  @override
  Widget build(BuildContext context) {
    LocalDataProvider localDataProvider = Provider.of<LocalDataProvider>(
      context,
      listen: true,
    );
    DistrictListProvider districtListProvider =
        Provider.of<DistrictListProvider>(context, listen: true);
    CityListProvider cityListProvider = Provider.of<CityListProvider>(
      context,
      listen: true,
    );
    PinCodeListProvider pinCodeListProvider = Provider.of<PinCodeListProvider>(
      context,
      listen: true,
    );
    RetailerOwnershipProvider retailerOwnershipProvider =
        Provider.of<RetailerOwnershipProvider>(context, listen: true);
    OutletDescriptionProvider outletDescriptionProvider =
        Provider.of<OutletDescriptionProvider>(context, listen: true);
    OutletKycDocumentListProvider outletKycDocumentListProvider =
        Provider.of<OutletKycDocumentListProvider>(context, listen: true);
    return Stack(
      children: [
        BackgroundWidget(
          headerWidget: Container(
            padding: const EdgeInsets.only(left: 16, right: 16),
            child: Row(
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
                    child: Icon(
                      Icons.arrow_back,
                      color: Colors.black,
                      size: 20,
                    ),
                  ),
                ),
                Spacer(),
                Text(
                  'Business Information',
                  style: GoogleFonts.poppins(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
                Spacer(),
                Spacer(),
              ],
            ),
          ),
          bottomSheetWidget: Padding(
            padding: EdgeInsets.only(top: 10),
            child: Form(
              key: _formKey,
              child: RefreshIndicator(
                onRefresh: () async {
                  // ClearProvider.clearLocationBaseProviders(context);
                  await outletDescriptionProvider.getOutlet(
                    _navigationArgumentData['_id'],
                  );
                  setData();
                },
                semanticsValue: 'Reset Form',
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // freeListing(),
                    // subscribed(),
                    statusWidget(leadStatus),

                    SizedBox(height: 10),
                    Expanded(
                      child: SingleChildScrollView(
                        controller: _scrollController,
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.start,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            RichText(
                              text: TextSpan(
                                text: 'Retailer Name',
                                style: labelStyle, // Your existing style
                                children: [
                                  TextSpan(
                                    text: ' *',
                                    style: labelStyle.copyWith(color: Colors.red), // Make the asterisk red
                                  ),
                                ],
                              ),
                            ),
                            TextFormField(
                              controller: _retailerNameController,
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.text,
                              keyboardAppearance: Brightness.dark,
                              decoration: inputDecoration("Retailer name"),
                              onFieldSubmitted: (value) {},
                              onChanged: (value) {
                                // retailListProvider.filterRetailList(value);
                              },
                              validator: (value) {
                                if (value!.isEmpty) {
                                  return "Please enter retailer name";
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 10),
                            RichText(
                              text: TextSpan(
                                text: 'Brand Name',
                                style: labelStyle, // Your existing style
                                children: [
                                  TextSpan(
                                    text: ' *',
                                    style: labelStyle.copyWith(color: Colors.red), // Make the asterisk red
                                  ),
                                ],
                              ),
                            ),
                            KeyedSubtree(
                              key: _brandNameKey,
                              child: TextFormField(
                                controller: _brandNameController,
                                enabled: isEdit,
                                textInputAction: TextInputAction.next,
                                keyboardType: TextInputType.text,
                                keyboardAppearance: Brightness.dark,
                                decoration: inputDecoration("Brand name"),
                                onFieldSubmitted: (value) {},
                                onChanged: (value) {
                                  // retailListProvider.filterRetailList(value);
                                },
                                validator: (value) {
                                  if (value!.isEmpty) {
                                    return "Please enter brand name";
                                  }
                                  return null;
                                },
                              ),
                            ),
                            SizedBox(height: 10),
                            Text("Brand Description", style: labelStyle),
                            TextFormField(
                              controller: _brandDescriptionController,
                              enabled: isEdit,
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.text,
                              keyboardAppearance: Brightness.dark,
                              decoration: inputDecoration("Brand Description"),
                              onFieldSubmitted: (value) {},
                              onChanged: (value) {
                                // retailListProvider.filterRetailList(value);
                              },
                              validator: (value) {
                                // if (value!.isEmpty) {
                                //   return "Please enter brand description";
                                // }
                                return null;
                              },
                            ),
                            SizedBox(height: 10),
                            Text("Brand Type", style: labelStyle),
                            DropdownButtonFormField<String>(
                              elevation: 0,
                              borderRadius: BorderRadius.circular(10),
                              style: textStyle,
                              decoration: dropdownDecoration(),
                              dropdownColor: AppColors.white,
                              isExpanded: true,
                              hint: Text(
                                "Select Brand Type",
                                style: labelStyle,
                              ),
                              value: _brandTypeController.text.isNotEmpty
                                  ? _brandTypeController.text
                                  : null,
                              items: brandTypes.map<DropdownMenuItem<String>>((
                                e,
                              ) {
                                return DropdownMenuItem<String>(
                                  value: e['brandValue'],
                                  child: Text(e['brandName']),
                                );
                              }).toList(),
                              onChanged: isEdit
                                  ? (String? newValue) {
                                      if (newValue != null) {
                                        setState(() {
                                          _brandTypeController.text = newValue;
                                        });
                                      }
                                    }
                                  : null,
                            ),
                            SizedBox(height: 10),
                            Text("Pos Name", style: labelStyle),
                            TextFormField(
                              enabled: isEdit,
                              controller: _posNameController,
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.text,
                              keyboardAppearance: Brightness.dark,
                              // Minimum height
                              minLines: 1,
                              // Expands indefinitely
                              maxLines: 4,
                              decoration: inputDecoration("Pos Name"),
                              onFieldSubmitted: (value) {},
                            ),

                            SizedBox(height: 10),
                            Text("Pos No.", style: labelStyle),
                            TextFormField(
                              enabled: isEdit,
                              controller: _posNumberController,
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.text,
                              keyboardAppearance: Brightness.dark,
                              // Minimum height
                              minLines: 1,
                              // Expands indefinitely
                              maxLines: 4,
                              decoration: inputDecoration("Pos No."),
                              onFieldSubmitted: (value) {},
                            ),

                            SizedBox(height: 10),
                            Text("Next followup date", style: labelStyle),
                            TextFormField(
                              controller: _nextFollowUpDateController,
                              textInputAction: TextInputAction.next,
                              enabled: isEdit,
                              keyboardType: TextInputType.text,
                              keyboardAppearance: Brightness.dark,
                              minLines: 1,
                              maxLines: 1,
                              readOnly: isEdit,
                              decoration: inputDecoration(
                                "Click to select date",
                              ),
                              onTap: () {
                                if (Platform.isIOS) {
                                  showCupertinoModalPopup(
                                    context: context,
                                    builder: (_) => GestureDetector(
                                      onTap: () => Navigator.of(context).pop(),
                                      // Dismiss on background tap
                                      child: Container(
                                        color: Colors.black.withOpacity(0.3),
                                        // Dimmed background
                                        child: GestureDetector(
                                          onTap: () {},
                                          // Prevent tap propagation
                                          child: Align(
                                            alignment: Alignment.bottomCenter,
                                            child: Container(
                                              height: 300,
                                              decoration: BoxDecoration(
                                                color: Colors.white,
                                                borderRadius:
                                                    BorderRadius.vertical(
                                                      top: Radius.circular(20),
                                                    ),
                                              ),
                                              child: Column(
                                                children: [
                                                  Padding(
                                                    padding:
                                                        const EdgeInsets.symmetric(
                                                          horizontal: 16.0,
                                                          vertical: 8,
                                                        ),
                                                    child: Row(
                                                      mainAxisAlignment:
                                                          MainAxisAlignment
                                                              .spaceBetween,
                                                      children: [
                                                        CupertinoButton(
                                                          padding:
                                                              EdgeInsets.zero,
                                                          child: Text(
                                                            'Cancel',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.purple,
                                                            ),
                                                          ),
                                                          onPressed: () =>
                                                              Navigator.of(
                                                                context,
                                                              ).pop(),
                                                        ),
                                                        CupertinoButton(
                                                          padding:
                                                              EdgeInsets.zero,
                                                          child: Text(
                                                            'Clear',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.purple,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            setState(() {
                                                              _nextFollowUpDateController
                                                                      .text =
                                                                  "";
                                                            });
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
                                                          },
                                                        ),
                                                        CupertinoButton(
                                                          padding:
                                                              EdgeInsets.zero,
                                                          child: Text(
                                                            'Done',
                                                            style: TextStyle(
                                                              color:
                                                                  Colors.purple,
                                                            ),
                                                          ),
                                                          onPressed: () {
                                                            // setState(() {
                                                            //   _nextFollowUpDateController
                                                            //       .text =
                                                            //   "${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}";
                                                            // });
                                                            Navigator.of(
                                                              context,
                                                            ).pop();
                                                          },
                                                        ),
                                                      ],
                                                    ),
                                                  ),
                                                  Divider(height: 1),
                                                  Expanded(
                                                    child: CupertinoDatePicker(
                                                      backgroundColor:
                                                          Colors.white,
                                                      mode:
                                                          CupertinoDatePickerMode
                                                              .date,
                                                      minimumDate:
                                                          DateTime.now(),
                                                      initialDateTime:
                                                          _nextFollowUpDateController
                                                              .text
                                                              .isNotEmpty
                                                          ? formatDate(
                                                                  _nextFollowUpDateController
                                                                      .text,
                                                                ).isBefore(
                                                                  DateTime.now(),
                                                                )
                                                                ? DateTime.now()
                                                                : formatDate(
                                                                    _nextFollowUpDateController
                                                                        .text,
                                                                  )
                                                          : DateTime.now(),
                                                      onDateTimeChanged:
                                                          (DateTime value) {
                                                            setState(() {
                                                              _nextFollowUpDateController
                                                                      .text =
                                                                  "${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}";
                                                            });
                                                          },
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                } else {
                                  showDatePicker(
                                    context: context,
                                    initialDate:
                                        _nextFollowUpDateController
                                            .text
                                            .isNotEmpty
                                        ? formatDate(
                                                _nextFollowUpDateController
                                                    .text,
                                              ).isBefore(DateTime.now())
                                              ? DateTime.now()
                                              : formatDate(
                                                  _nextFollowUpDateController
                                                      .text,
                                                )
                                        : DateTime.now(),
                                    firstDate: DateTime.now(),
                                    lastDate: DateTime(2100),
                                    builder: (context, child) {
                                      return Theme(
                                        data: Theme.of(context).copyWith(
                                          colorScheme: ColorScheme.light(
                                            primary: AppColors.primaryColor,
                                          ),
                                        ),
                                        child: child!,
                                      );
                                    },
                                  ).then((value) {
                                    if (value != null) {
                                      setState(() {
                                        _nextFollowUpDateController.text =
                                            "${value.day.toString().padLeft(2, '0')}/${value.month.toString().padLeft(2, '0')}/${value.year}";
                                      });
                                    }
                                  });
                                }
                              },
                            ),
                            SizedBox(height: 10),
                            Text("Description", style: labelStyle),
                            TextFormField(
                              controller: _descriptionController,
                              textInputAction: TextInputAction.newline,
                              keyboardType: TextInputType.multiline,
                              keyboardAppearance: Brightness.dark,
                              // Minimum height
                              minLines: 1,
                              // Expands indefinitely
                              maxLines: 4,
                              decoration: inputDecoration("Description"),
                              onFieldSubmitted: (value) {},
                              onChanged: (value) {

                              },

                            ),
                            SizedBox(height: 10),
                            Text("Street 1", style: labelStyle),
                            TextFormField(
                              controller: _street1Controller,
                              textInputAction: TextInputAction.next,
                              enabled: isEdit,
                              keyboardType: TextInputType.text,
                              keyboardAppearance: Brightness.dark,
                              // Minimum height
                              minLines: 1,
                              // Expands indefinitely
                              maxLines: 4,
                              decoration: inputDecoration("Street 1"),
                              onFieldSubmitted: (value) {},
                              onChanged: (value) {
                                setState(() {});
                                setDisplayAddress();
                              },
                              validator: (value) {
                                // if (value!.isEmpty) {
                                //   return "Please enter street 1";
                                // }
                                return null;
                              },
                            ),
                            SizedBox(height: 10),
                            Text("Street 2", style: labelStyle),
                            TextFormField(
                              controller: _street2Controller,
                              enabled: isEdit,
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.text,
                              keyboardAppearance: Brightness.dark,
                              // Minimum height
                              minLines: 1,
                              // Expands indefinitely
                              maxLines: 4,
                              decoration: inputDecoration("Street 2"),
                              onFieldSubmitted: (value) {},
                              onChanged: (value) {
                                setDisplayAddress();
                              },
                              validator: (value) {
                                // if (value!.isEmpty) {
                                //   return "Please enter street 2";
                                // }
                                return null;
                              },
                            ),
                            SizedBox(height: 10),
                            RichText(
                              text: TextSpan(
                                text: 'Country',
                                style: labelStyle, // Your existing style
                                children: [
                                  TextSpan(
                                    text: ' *',
                                    style: labelStyle.copyWith(color: Colors.red), // Make the asterisk red
                                  ),
                                ],
                              ),
                            ),
                            Consumer<CountryListProvider>(
                              builder: (context, value, child) {
                                return Autocomplete<String>(
                                  optionsBuilder: (textEditingValue) {
                                    if (textEditingValue.text.isEmpty) {
                                      return value.countryList.map(
                                        (e) => e.name,
                                      );
                                    }
                                    return value.countryList
                                        .where(
                                          (e) => e.name.toLowerCase().contains(
                                            textEditingValue.text.toLowerCase(),
                                          ),
                                        )
                                        .map((e) => e.name);
                                  },
                                  onSelected: (selected) {
                                    final selectedObj = value.countryList
                                        .firstWhere((e) => e.name == selected);

                                    if (_countryController.text !=
                                        selectedObj.id.toString()) {
                                      _countryController.text = selectedObj.id
                                          .toString();
                                      _stateController.text = '';
                                      _districtController.text = '';
                                      _cityController.text = '';
                                      _pinCodeController.text = '';
                                      _retailerOwnershipController.text = '';
                                      value.setSelectedCountryId(
                                        selectedObj.id,
                                      );
                                      retailerOwnershipProvider
                                          .getRetailerOwnershipList(
                                            selectedObj.id,
                                          );
                                      districtListProvider.clearDistrictList();
                                      cityListProvider.clearCityList();
                                      pinCodeListProvider.clearPinCodeList();
                                      setDisplayAddress();
                                    }
                                  },
                                  fieldViewBuilder:
                                      (
                                        context,
                                        textEditingController,
                                        focusNode,
                                        onFieldSubmitted,
                                      ) {
                                        if (_countryController
                                            .text
                                            .isNotEmpty) {
                                          if (int.parse(
                                                _countryController.text,
                                              ) >
                                              0) {
                                            final countryId =
                                                _countryController.text;
                                            final selectedName =
                                                (countryId.isNotEmpty)
                                                ? value
                                                          .getSelectedCountry(
                                                            int.parse(
                                                              countryId,
                                                            ),
                                                          )
                                                          .name ??
                                                      ''
                                                : '';
                                            textEditingController.text =
                                                selectedName;
                                          }
                                        }
                                        return TextFormField(
                                          controller: textEditingController,
                                          focusNode: focusNode,
                                          enabled:
                                              value.countryList.isNotEmpty &&
                                              isEdit,
                                          decoration: dropdownDecoration()
                                              .copyWith(
                                                hintText: "Select Country",
                                                hintStyle: labelStyle,
                                                suffixIcon: IconButton(
                                                  icon: Icon(
                                                    Icons.arrow_drop_down,
                                                  ),
                                                  onPressed: () =>
                                                      focusNode.requestFocus(),
                                                ),
                                              ),
                                          style: isEdit
                                              ? textStyle
                                              : labelStyle,
                                          validator: (value){
                                            if (value!.isEmpty) {
                                              return "Please select country";
                                            }
                                            return null;
                                          },
                                        );
                                      },
                                  optionsViewBuilder:
                                      (context, onSelected, options) {
                                        return buildOptionsView(
                                          options,
                                          onSelected,
                                        );
                                      },
                                );
                              },
                            ),
                            SizedBox(height: 10),
                            RichText(
                              text: TextSpan(
                                text : 'Emirate/Province/State',
                                style: labelStyle, // Your existing style
                                children: [
                                  TextSpan(
                                    text: ' *',
                                    style: labelStyle.copyWith(color: Colors.red), // Make the asterisk red
                                  ),
                                ],
                              ),
                            ),
                            Consumer<StateListProvider>(
                              builder: (context, value, child) {
                                return Autocomplete<String>(
                                  optionsBuilder: (textEditingValue) {
                                    if (textEditingValue.text.isEmpty) {
                                      return value.stateList.map((e) => e.name);
                                    }
                                    return value.stateList
                                        .where(
                                          (e) => e.name.toLowerCase().contains(
                                            textEditingValue.text.toLowerCase(),
                                          ),
                                        )
                                        .map((e) => e.name);
                                  },
                                  onSelected: (selected) {
                                    final selectedObj = value.stateList
                                        .firstWhere((e) => e.name == selected);
                                    if (_stateController.text !=
                                        selectedObj.id.toString()) {
                                      _stateController.text = selectedObj.id
                                          .toString();
                                      _districtController.text = '';
                                      _cityController.text = '';
                                      _pinCodeController.text = '';
                                      value.setSelectedStateId(selectedObj.id);
                                      cityListProvider.clearCityList();
                                      pinCodeListProvider.clearPinCodeList();
                                      setDisplayAddress();
                                    }
                                  },
                                  fieldViewBuilder:
                                      (
                                        context,
                                        textEditingController,
                                        focusNode,
                                        onFieldSubmitted,
                                      ) {
                                        if (_stateController.text.isNotEmpty) {
                                          if (int.parse(_stateController.text) >
                                              0) {
                                            //print(_stateController.text);
                                            final stateId =
                                                _stateController.text;
                                            final selectedName =
                                                (stateId.isNotEmpty)
                                                ? value
                                                          .getSelectedState(
                                                            int.parse(stateId),
                                                          )
                                                          .name ??
                                                      ''
                                                : '';
                                            textEditingController.text =
                                                selectedName;
                                          }
                                        }
                                        return TextFormField(
                                          controller: textEditingController,
                                          focusNode: focusNode,
                                          enabled:
                                              value.stateList.isNotEmpty &&
                                              isEdit,
                                          decoration: dropdownDecoration()
                                              .copyWith(
                                                hintText: "Select State",
                                                hintStyle: labelStyle,
                                                suffixIcon: IconButton(
                                                  icon: Icon(
                                                    Icons.arrow_drop_down,
                                                  ),
                                                  onPressed: () =>
                                                      focusNode.requestFocus(),
                                                ),
                                              ),
                                          style: isEdit
                                              ? textStyle
                                              : labelStyle,
                                          validator: (value){
                                            if (value!.isEmpty) {
                                              return "Please select state";
                                            }
                                            return null;
                                          },
                                        );
                                      },
                                  optionsViewBuilder:
                                      (context, onSelected, options) {
                                        return buildOptionsView(
                                          options,
                                          onSelected,
                                        );
                                      },
                                );
                              },
                            ),
                            SizedBox(height: 10),
                            RichText(
                              text: TextSpan(
                                text: 'District/Zone',
                                style: labelStyle, // Your existing style
                                children: [
                                  TextSpan(
                                    text: ' *',
                                    style: labelStyle.copyWith(color: Colors.red), // Make the asterisk red
                                  ),
                                ],
                              ),
                            ),
                            Consumer<DistrictListProvider>(
                              builder: (context, value, child) {
                                return Autocomplete<String>(
                                  optionsBuilder: (textEditingValue) {
                                    if (textEditingValue.text.isEmpty) {
                                      return value.districtList.map(
                                        (e) => e.name,
                                      );
                                    }
                                    return value.districtList
                                        .where(
                                          (e) => e.name.toLowerCase().contains(
                                            textEditingValue.text.toLowerCase(),
                                          ),
                                        )
                                        .map((e) => e.name);
                                  },
                                  onSelected: (selected) {
                                    final selectedObj = value.districtList
                                        .firstWhere((e) => e.name == selected);
                                    if (_districtController.text !=
                                        selectedObj.id.toString()) {
                                      _districtController.text = selectedObj.id
                                          .toString();
                                      _cityController.text = '';
                                      _pinCodeController.text = '';
                                      value.setSelectedDistrictId(
                                        selectedObj.id,
                                      );
                                      pinCodeListProvider.clearPinCodeList();
                                      setDisplayAddress();
                                    }
                                  },
                                  fieldViewBuilder:
                                      (
                                        context,
                                        textEditingController,
                                        focusNode,
                                        onFieldSubmitted,
                                      ) {
                                        if (_districtController
                                            .text
                                            .isNotEmpty) {
                                          if (int.parse(
                                                _districtController.text,
                                              ) >
                                              0) {
                                            final districtId =
                                                _districtController.text;
                                            final selectedName =
                                                (districtId.isNotEmpty)
                                                ? value
                                                          .getSelectedDistrict(
                                                            int.parse(
                                                              districtId,
                                                            ),
                                                          )
                                                          .name ??
                                                      ''
                                                : '';
                                            textEditingController.text =
                                                selectedName;
                                          }
                                        }
                                        return TextFormField(
                                          controller: textEditingController,
                                          focusNode: focusNode,
                                          enabled:
                                              value.districtList.isNotEmpty &&
                                              isEdit,
                                          decoration: dropdownDecoration()
                                              .copyWith(
                                                hintText: "Select District",
                                                hintStyle: labelStyle,
                                                suffixIcon: IconButton(
                                                  icon: Icon(
                                                    Icons.arrow_drop_down,
                                                  ),
                                                  onPressed: () =>
                                                      focusNode.requestFocus(),
                                                ),
                                              ),
                                          style: isEdit
                                              ? textStyle
                                              : labelStyle,
                                          validator: (value){
                                            if (value!.isEmpty) {
                                              return "Please select district";
                                            }
                                            return null;
                                          },
                                        );
                                      },
                                  optionsViewBuilder:
                                      (context, onSelected, options) {
                                        return buildOptionsView(
                                          options,
                                          onSelected,
                                        );
                                      },
                                );
                              },
                            ),
                            SizedBox(height: 10),
                            RichText(
                              text: TextSpan(
                                text: 'City/Town',
                                style: labelStyle, // Your existing style
                                children: [
                                  TextSpan(
                                    text: ' *',
                                    style: labelStyle.copyWith(color: Colors.red), // Make the asterisk red
                                  ),
                                ],
                              ),
                            ),
                            Consumer<CityListProvider>(
                              builder: (context, value, child) {
                                return Autocomplete<String>(
                                  optionsBuilder: (textEditingValue) {
                                    if (textEditingValue.text.isEmpty) {
                                      return value.cityList.map((e) => e.name);
                                    }
                                    return value.cityList
                                        .where(
                                          (e) => e.name.toLowerCase().contains(
                                            textEditingValue.text.toLowerCase(),
                                          ),
                                        )
                                        .map((e) => e.name);
                                  },
                                  onSelected: (selected) {
                                    final selectedObj = value.cityList
                                        .firstWhere((e) => e.name == selected);
                                    if (_cityController.text !=
                                        selectedObj.id.toString()) {
                                      _cityController.text = selectedObj.id
                                          .toString();
                                      _pinCodeController.text = '';
                                      value.setSelectedCityId(selectedObj.id);
                                      setDisplayAddress();
                                    }
                                  },
                                  fieldViewBuilder:
                                      (
                                        context,
                                        textEditingController,
                                        focusNode,
                                        onFieldSubmitted,
                                      ) {
                                        //print(_cityController.text);
                                        if (_cityController.text.isNotEmpty) {
                                          if (int.parse(_cityController.text) >
                                              0) {
                                            final cityId = _cityController.text;
                                            final selectedName =
                                                (cityId.isNotEmpty)
                                                ? value
                                                          .getSelectedCity(
                                                            int.parse(cityId),
                                                          )
                                                          .name ??
                                                      ''
                                                : '';
                                            textEditingController.text =
                                                selectedName;
                                          }
                                        }
                                        return TextFormField(
                                          controller: textEditingController,
                                          focusNode: focusNode,
                                          enabled:
                                              value.cityList.isNotEmpty &&
                                              isEdit,
                                          decoration: dropdownDecoration()
                                              .copyWith(
                                                hintText: "Select City",
                                                hintStyle: labelStyle,
                                                suffixIcon: IconButton(
                                                  icon: Icon(
                                                    Icons.arrow_drop_down,
                                                  ),
                                                  onPressed: () =>
                                                      focusNode.requestFocus(),
                                                ),
                                              ),
                                          style: isEdit
                                              ? textStyle
                                              : labelStyle,
                                          validator: (value){
                                            if (value!.isEmpty) {
                                              return "Please select city";
                                            }
                                            return null;
                                          },
                                        );
                                      },
                                  optionsViewBuilder:
                                      (context, onSelected, options) {
                                        return buildOptionsView(
                                          options,
                                          onSelected,
                                        );
                                      },
                                );
                              },
                            ),
                            SizedBox(height: 10),
                            Text("Pin Code/Postal Code", style: labelStyle),
                            Consumer<PinCodeListProvider>(
                              builder: (context, value, child) {
                                return Autocomplete<String>(
                                  optionsBuilder: (textEditingValue) {
                                    if (textEditingValue.text.isEmpty) {
                                      return value.pinCodeList.map(
                                        (e) => e.pinCode,
                                      );
                                    }
                                    return value.pinCodeList
                                        .where(
                                          (e) =>
                                              e.pinCode.toLowerCase().contains(
                                                textEditingValue.text
                                                    .toLowerCase(),
                                              ),
                                        )
                                        .map((e) => e.pinCode);
                                  },
                                  onSelected: (selected) {
                                    final selectedObj = value.pinCodeList
                                        .firstWhere(
                                          (e) => e.pinCode == selected,
                                        );
                                    if (_pinCodeController.text !=
                                        selectedObj.id.toString()) {
                                      _pinCodeController.text = selectedObj.id
                                          .toString();
                                      value.setSelectedPinCodeId(
                                        selectedObj.id,
                                      );
                                      setDisplayAddress();
                                    }
                                  },
                                  fieldViewBuilder:
                                      (
                                        context,
                                        textEditingController,
                                        focusNode,
                                        onFieldSubmitted,
                                      ) {
                                        if (_pinCodeController
                                            .text
                                            .isNotEmpty) {
                                          if (int.parse(
                                                _pinCodeController.text,
                                              ) >
                                              0) {
                                            final pinCodeId =
                                                _pinCodeController.text;
                                            final selectedName =
                                                (pinCodeId.isNotEmpty)
                                                ? value
                                                          .getSelectedPinCode(
                                                            int.parse(
                                                              pinCodeId,
                                                            ),
                                                          )
                                                          .pinCode ??
                                                      ''
                                                : '';
                                            textEditingController.text =
                                                selectedName;
                                          }
                                        }
                                        return TextField(
                                          controller: textEditingController,
                                          focusNode: focusNode,
                                          enabled:
                                              value.pinCodeList.isNotEmpty &&
                                              isEdit,
                                          decoration: dropdownDecoration()
                                              .copyWith(
                                                hintText: "Select Postal Code",
                                                hintStyle: labelStyle,
                                                suffixIcon: IconButton(
                                                  icon: Icon(
                                                    Icons.arrow_drop_down,
                                                  ),
                                                  onPressed: () =>
                                                      focusNode.requestFocus(),
                                                ),
                                              ),
                                          style: isEdit
                                              ? textStyle
                                              : labelStyle,
                                        );
                                      },
                                  optionsViewBuilder:
                                      (context, onSelected, options) {
                                        return buildOptionsView(
                                          options,
                                          onSelected,
                                        );
                                      },
                                );
                              },
                            ),
                            SizedBox(height: 10),
                            Text("GPS Location", style: labelStyle),
                            InkWell(
                              onTap: () async {
                                //print("ssasd");
                                // if IOS
                                if (Platform.isIOS) {
                                  Position position =
                                      await Geolocator.getCurrentPosition(
                                        locationSettings: AppleSettings(
                                          accuracy: LocationAccuracy.high,
                                        ),
                                      );
                                  setState(() {
                                    _gpsLocationController.text =
                                        '${position.latitude}, ${position.longitude}';
                                  });
                                }
                                // if Android
                                if (Platform.isAndroid) {
                                  Position position =
                                      await Geolocator.getCurrentPosition(
                                        locationSettings: AndroidSettings(
                                          accuracy: LocationAccuracy.high,
                                        ),
                                      );
                                  setState(() {
                                    _gpsLocationController.text =
                                        '${position.latitude}, ${position.longitude}';
                                  });
                                }
                                //print("GPS");
                              },
                              child: TextFormField(
                                controller: _gpsLocationController,
                                enabled: false,
                                textInputAction: TextInputAction.next,
                                keyboardType: TextInputType.text,
                                keyboardAppearance: Brightness.dark,
                                decoration: InputDecoration(
                                  hintText: "GPS Location",
                                  counterText: "",
                                  hintStyle: TextStyle(
                                    color: AppColors.paragraph,
                                  ),
                                  contentPadding: EdgeInsets.only(
                                    left: 10,
                                    right: 0,
                                    top: 0,
                                    bottom: 0,
                                  ),
                                  suffixIcon: Container(
                                    width: 90,
                                    decoration: BoxDecoration(
                                      color: Color(0xFFBCBDC0),
                                      borderRadius: BorderRadius.only(
                                        topRight: Radius.circular(10),
                                        bottomRight: Radius.circular(10),
                                      ),
                                    ),
                                    child: Center(
                                      child: Row(
                                        mainAxisAlignment:
                                            MainAxisAlignment.center,
                                        children: [
                                          SvgPicture.string(SvgIcons.gpsIcon),
                                          // Text(
                                          //   'Get Location',
                                          //   style: GoogleFonts.poppins(
                                          //     fontSize: 10,
                                          //     fontWeight: FontWeight.w500,
                                          //     color: AppColors.white,
                                          //   ),
                                          // ),
                                        ],
                                      ),
                                    ),
                                  ),
                                  border: border,
                                  disabledBorder: border,
                                  enabledBorder: border,
                                  focusedBorder: border,
                                ),

                                onFieldSubmitted: (value) {},
                                onChanged: (value) {
                                  // retailListProvider.filterRetailList(value);
                                },
                                validator: (value) {
                                  if (value!.isEmpty) {
                                    return "Please enter GPS location";
                                  }
                                  return null;
                                },
                              ),
                            ),
                            SizedBox(height: 10),
                            Text("Website", style: labelStyle),
                            TextFormField(
                              controller: _websiteController,
                              enabled: isEdit,
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.url,
                              keyboardAppearance: Brightness.dark,
                              decoration: inputDecoration("Website"),
                              onFieldSubmitted: (value) {},
                              onChanged: (value) {
                                // retailListProvider.filterRetailList(value);
                              },
                              // validator: (value) {
                              //   if (value!.isEmpty) {
                              //     return "Please enter contact name";
                              //   }
                              //   return null;
                              // },
                            ),
                            SizedBox(height: 10),
                            Text("Contact Name", style: labelStyle),
                            TextFormField(
                              controller: _contactNameController,
                              textInputAction: TextInputAction.next,
                              enabled: isEdit,
                              keyboardType: TextInputType.text,
                              keyboardAppearance: Brightness.dark,
                              decoration: inputDecoration("Contact name"),
                              onFieldSubmitted: (value) {},
                              onChanged: (value) {
                                // retailListProvider.filterRetailList(value);
                              },
                              validator: (value) {
                                // if (value!.isEmpty) {
                                //   return "Please enter contact name";
                                // }
                                return null;
                              },
                            ),
                            SizedBox(height: 10),
                            Text("Mobile Number", style: labelStyle),
                            TextFormField(
                              controller: _mobileNumberController,
                              textInputAction: TextInputAction.next,
                              enabled: isEdit,
                              keyboardType: TextInputType.phone,
                              inputFormatters: [
                                FilteringTextInputFormatter.digitsOnly,
                                LengthLimitingTextInputFormatter(10),
                              ],
                              keyboardAppearance: Brightness.dark,
                              maxLength: 10,
                              decoration: inputDecoration("Mobile number"),
                              onFieldSubmitted: (value) {},
                              onChanged: (value) {
                                // retailListProvider.filterRetailList(value);
                              },
                              validator: (value) {
                                if (value!.isNotEmpty) {
                                  if (value.length != 10) {
                                    return "Please enter valid mobile number";
                                  }
                                }

                                return null;
                              },
                            ),
                            SizedBox(height: 10),
                            Text("Email ID", style: labelStyle),
                            TextFormField(
                              controller: _emailIdController,
                              enabled: isEdit,
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.emailAddress,
                              keyboardAppearance: Brightness.dark,
                              decoration: inputDecoration("Email ID"),
                              onFieldSubmitted: (value) {},
                              onChanged: (value) {
                                // retailListProvider.filterRetailList(value);
                              },
                              validator: (value) {
                                if (value!.isNotEmpty) {
                                  if (!RegExp(
                                    r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                                  ).hasMatch(value)) {
                                    return 'Enter a valid email address';
                                  }
                                }
                                return null;
                              },
                            ),
                            SizedBox(height: 10),
                            Text("Display Address", style: labelStyle),
                            TextFormField(
                              controller: _displayAddressController,
                              enabled: isEdit,
                              textInputAction: TextInputAction.next,
                              keyboardType: TextInputType.text,
                              keyboardAppearance: Brightness.dark,
                              // Minimum height
                              minLines: 1,
                              // Expands indefinitely
                              maxLines: 4,
                              decoration: inputDecoration("Display Address"),
                              onFieldSubmitted: (value) {},
                              onChanged: (value) {
                                // retailListProvider.filterRetailList(value);
                              },
                              validator: (value) {
                                // if (value!.isEmpty) {
                                //   return "Please enter display address";
                                // }
                                return null;
                              },
                            ),

                            SizedBox(height: 10),

                            Text("Opening Time", style: labelStyle),
                            Consumer<TimeProvider>(
                              builder: (context, value, child) {
                                return Autocomplete<String>(
                                  optionsBuilder: (textEditingValue) {
                                    if (textEditingValue.text.isEmpty) {
                                      return value.openingTimeList.map(
                                        (e) => e.time,
                                      );
                                    }
                                    return value.openingTimeList
                                        .where(
                                          (e) => e.time.toLowerCase().contains(
                                            textEditingValue.text.toLowerCase(),
                                          ),
                                        )
                                        .map((e) => e.time);
                                  },
                                  onSelected: (selected) {
                                    final selectedObj = value.openingTimeList
                                        .firstWhere((e) => e.time == selected);
                                    setState(() {
                                      _openingTimeController.text = selectedObj
                                          .id
                                          .toString();
                                    });
                                  },
                                  fieldViewBuilder:
                                      (context, controller, focusNode, _) {
                                        if (_openingTimeController
                                            .text
                                            .isNotEmpty) {
                                          if (int.parse(
                                                _openingTimeController.text,
                                              ) >
                                              0) {
                                            final openingId =
                                                _openingTimeController.text;
                                            final openingTime = value
                                                .getSelectedOpeningTime(
                                                  int.parse(openingId),
                                                )
                                                .time;
                                            controller.text = openingTime;
                                          }
                                        }
                                        return TextField(
                                          controller: controller,
                                          enabled:
                                              value
                                                  .openingTimeList
                                                  .isNotEmpty &&
                                              isEdit,
                                          focusNode: focusNode,
                                          decoration: dropdownDecoration()
                                              .copyWith(
                                                hintText: "Opening Time",
                                                hintStyle: labelStyle,
                                                suffixIcon: suffixIcon(
                                                  focusNode,
                                                ),
                                              ),
                                          style: isEdit
                                              ? textStyle
                                              : labelStyle,
                                        );
                                      },
                                  optionsViewBuilder:
                                      (context, onSelected, options) =>
                                          buildOptionsView(options, onSelected),
                                );
                              },
                            ),
                            SizedBox(height: 10),
                            Text("Closing Time", style: labelStyle),
                            Consumer<TimeProvider>(
                              builder: (context, value, child) {
                                return Autocomplete<String>(
                                  optionsBuilder: (textEditingValue) {
                                    if (textEditingValue.text.isEmpty) {
                                      return value.closingTimeList.map(
                                        (e) => e.time,
                                      );
                                    }
                                    return value.closingTimeList
                                        .where(
                                          (e) => e.time.toLowerCase().contains(
                                            textEditingValue.text.toLowerCase(),
                                          ),
                                        )
                                        .map((e) => e.time);
                                  },
                                  onSelected: (selected) {
                                    final selectedObj = value.closingTimeList
                                        .firstWhere((e) => e.time == selected);
                                    setState(() {
                                      _closingTimeController.text = selectedObj
                                          .id
                                          .toString();
                                    });
                                  },
                                  fieldViewBuilder:
                                      (context, controller, focusNode, _) {
                                        if (_closingTimeController
                                            .text
                                            .isNotEmpty) {
                                          if (int.parse(
                                                _closingTimeController.text,
                                              ) >
                                              0) {
                                            final closingId =
                                                _closingTimeController.text;
                                            final closingTime = value
                                                .getSelectedClosingTime(
                                                  int.parse(closingId),
                                                )
                                                .time;
                                            controller.text = closingTime;
                                          }
                                        }
                                        return TextField(
                                          controller: controller,
                                          enabled:
                                              value
                                                  .closingTimeList
                                                  .isNotEmpty &&
                                              isEdit,
                                          focusNode: focusNode,
                                          decoration: dropdownDecoration()
                                              .copyWith(
                                                hintText: "Closing Time",
                                                hintStyle: labelStyle,
                                                suffixIcon: suffixIcon(
                                                  focusNode,
                                                ),
                                              ),
                                          style: isEdit
                                              ? textStyle
                                              : labelStyle,
                                        );
                                      },
                                  optionsViewBuilder:
                                      (context, onSelected, options) =>
                                          buildOptionsView(options, onSelected),
                                );
                              },
                            ),
                            SizedBox(height: 10),
                            Text("Daily Avg Revenue", style: labelStyle),
                            TextFormField(
                              controller: _dailyAvgRevenueController,
                              textInputAction: TextInputAction.next,
                              enabled: isEdit,
                              keyboardType: TextInputType.number,
                              keyboardAppearance: Brightness.dark,
                              decoration: inputDecoration("Daily Avg Revenue"),
                              onFieldSubmitted: (value) {},
                              onChanged: (value) {
                                // retailListProvider.filterRetailList(value);
                              },
                              validator: (value) {
                                // if (value!.isEmpty) {
                                //   return "Please enter daily avg revenue";
                                // }
                                return null;
                              },
                            ),
                            SizedBox(height: 10),
                            Text("Class of Retailer", style: labelStyle),
                            DropdownButtonFormField<String>(
                              elevation: 0,
                              borderRadius: BorderRadius.circular(10),
                              style: textStyle,
                              decoration: dropdownDecoration(),
                              // validator: (value) {
                              //   if (value == null) {
                              //     return "Please select class of retailer";
                              //   }
                              //   return null;
                              // },
                              dropdownColor: AppColors.white,
                              isExpanded: true,
                              hint: Text(
                                "Select Class of Retailer",
                                style: labelStyle,
                              ),
                              value:
                                  UtilityData.classOfRetailerKey.contains(
                                    _classOfRetailerController.text,
                                  )
                                  ? _classOfRetailerController.text
                                  : null,
                              items: UtilityData.classOfRetailerData
                                  .map<DropdownMenuItem<String>>((e) {
                                    return DropdownMenuItem<String>(
                                      value: e['key'],
                                      child: Text(e['value']!),
                                    );
                                  })
                                  .toList(),
                              onChanged: isEdit
                                  ? (String? newValue) {
                                      if (newValue != null) {
                                        setState(() {
                                          _classOfRetailerController.text =
                                              newValue;
                                        });
                                      }
                                    }
                                  : null,
                            ),
                            SizedBox(height: 10),
                            RichText(
                              text: TextSpan(
                                text: 'Retailer Ownership',
                                style: labelStyle, // Your existing style
                                children: [
                                  TextSpan(
                                    text: ' *',
                                    style: labelStyle.copyWith(color: Colors.red), // Make the asterisk red
                                  ),
                                ],
                              ),
                            ),
                            Consumer<RetailerOwnershipProvider>(
                              builder: (context, value, child) {
                                return DropdownButtonFormField<String>(
                                  elevation: 0,
                                  borderRadius: BorderRadius.circular(10),
                                  style: textStyle,
                                  decoration: dropdownDecoration(),
                                  dropdownColor: AppColors.white,
                                  isExpanded: true,

                                  hint: Text(
                                    "Select Retailer Ownership",
                                    style: labelStyle,
                                  ),
                                  value:
                                      _retailerOwnershipController
                                              .text
                                              .isNotEmpty &&
                                          int.parse(
                                                _retailerOwnershipController
                                                    .text,
                                              ) >
                                              0 &&
                                          int.parse(_countryController.text) > 0
                                      ? value
                                            .getSelectedRetailerOwnership(
                                              int.parse(
                                                _retailerOwnershipController
                                                    .text,
                                              ),
                                            )
                                            .id
                                            .toString()
                                      : null,
                                  items: value.retailerOwnershipList
                                      .map<DropdownMenuItem<String>>((e) {
                                        return DropdownMenuItem<String>(
                                          value: e.id.toString(),
                                          child: Text(e.name),
                                        );
                                      })
                                      .toList(),
                                  onChanged: isEdit
                                      ? (String? newValue) {
                                          //print(
                                          //   "new value _retailerOwnershipController $newValue",
                                          // );
                                          if (newValue != null) {
                                            setState(() {
                                              _retailerOwnershipController
                                                      .text =
                                                  newValue;
                                            });
                                            value
                                                .setSelectedRetailerOwnershipId(
                                                  int.parse(newValue),
                                                );
                                            outletKycDocumentListProvider
                                                .fetchAndMergeKycDocuments(
                                                  int.parse(newValue),
                                                  leadId,
                                                );
                                          }
                                        }
                                      : null,
                                );
                              },
                            ),
                            SizedBox(height: 10),
                            Text("Channel Type", style: labelStyle),
                            Consumer<ChannelTypeProvider>(
                              builder: (context, value, child) {
                                return DropdownButtonFormField<String>(
                                  elevation: 0,
                                  borderRadius: BorderRadius.circular(10),
                                  style: textStyle,
                                  decoration: dropdownDecoration(),
                                  // validator: (value) {
                                  //   if (value == null) {
                                  //     return "Please select state";
                                  //   }
                                  //   return null;
                                  // },
                                  dropdownColor: AppColors.white,
                                  isExpanded: true,
                                  hint: Text(
                                    "Select Channel Type",
                                    style: labelStyle,
                                  ),
                                  value:
                                      _channelTypeController.text.isNotEmpty &&
                                          int.parse(
                                                _channelTypeController.text,
                                              ) >
                                              0
                                      ? value
                                            .getSelectedChannelType(
                                              int.parse(
                                                _channelTypeController.text,
                                              ),
                                            )
                                            .id
                                            .toString()
                                      : null,
                                      // items: null,
                                  items: value.channelTypeList
                                      .map<DropdownMenuItem<String>>((e) {
                                        return DropdownMenuItem<String>(
                                          value: e.id.toString(),
                                          child: Text(e.name),
                                        );
                                      })
                                      .toList(),
                                  onChanged: false
                                      ? (String? newValue) {
                                          // print(
                                          //   "new value _channelTypeController $newValue",
                                          // );
                                          if (newValue != null) {
                                            setState(() {
                                              _channelTypeController.text =
                                                  newValue;
                                            });
                                            value.setSelectedChannelTypeId(
                                              int.parse(newValue),
                                            );
                                          }
                                        }
                                      : null,
                                );
                              },
                            ),
                            SizedBox(height: 10),
                            RichText(
                              text: TextSpan(
                                text: "Business Category",
                                style: labelStyle, // Your existing style
                                children: [
                                  TextSpan(
                                    text: ' *',
                                    style: labelStyle.copyWith(color: Colors.red), // Make the asterisk red
                                  ),
                                ],
                              ),
                            ),
                            Consumer<BusinessCategoryListProvider>(
                              builder: (context, value, child) {
                                return FormField<String>(
                                  validator: (val) {
                                    if (_businessCategoryController.text.isEmpty) {
                                      return 'Please select a business category';
                                    }
                                    return null;
                                  },
                                  builder: (formFieldState) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Autocomplete<String>(
                                          optionsBuilder: (textEditingValue) {
                                            if (textEditingValue.text.isEmpty) {
                                              return value.businessCategoryList
                                                  .map((e) => e.name);
                                            }
                                            return value.businessCategoryList
                                                .where(
                                                  (e) => e.name
                                                      .toLowerCase()
                                                      .contains(
                                                        textEditingValue.text
                                                            .toLowerCase(),
                                                      ),
                                                )
                                                .map((e) => e.name);
                                          },
                                          onSelected: (selected) async {
                                            final selectedObj = value
                                                .businessCategoryList
                                                .firstWhere(
                                                  (e) => e.name == selected,
                                                  orElse: () =>
                                                      BusinessCategoryModel(
                                                        id: -1,
                                                        name: "",
                                                      ),
                                                );
                                            if (selectedObj.id <= 0) {
                                              return; // invalid entry fallback
                                            }
                                            setState(() {
                                              _businessCategoryController.text =
                                                  selectedObj.id.toString();
                                            });
                                            formFieldState.didChange(
                                              selected,
                                            ); // Validation state update

                                            // Update provider state
                                            value.setSelectedBusinessCategoryId(
                                              selectedObj.id,
                                            );

                                            // Fetch subcategories
                                            BusinessSubCategoryList
                                            subCatProvider =
                                                Provider.of<
                                                  BusinessSubCategoryList
                                                >(context, listen: false);
                                            await subCatProvider
                                                .getBusinessSubCategoryList(
                                                  selectedObj.id,
                                                );
                                          },
                                          fieldViewBuilder:
                                              (
                                                context,
                                                controller,
                                                focusNode,
                                                _,
                                              ) {
                                                // Pre-fill name if editing
                                                final existingCategory = value
                                                    .businessCategoryList
                                                    .firstWhere(
                                                      (e) =>
                                                          e.id.toString() ==
                                                          _businessCategoryController
                                                              .text,
                                                      orElse: () =>
                                                          BusinessCategoryModel(
                                                            id: -1,
                                                            name: "",
                                                          ),
                                                    );
                                                controller.text =
                                                    existingCategory.name;

                                                return TextFormField(
                                                  controller: controller,
                                                  enabled: isEdit,
                                                  focusNode: focusNode,
                                                  decoration: dropdownDecoration()
                                                      .copyWith(
                                                        hintText:
                                                            "Select Business Category",
                                                        hintStyle: labelStyle,
                                                        errorText:
                                                            formFieldState
                                                                .errorText,
                                                        suffixIcon: suffixIcon(
                                                          focusNode,
                                                        ),
                                                      ),
                                                  style: isEdit
                                                      ? textStyle
                                                      : labelStyle,
                                                );
                                              },
                                          optionsViewBuilder:
                                              (context, onSelected, options) {
                                                return buildOptionsView(
                                                  options,
                                                  onSelected,
                                                );
                                              },
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),

                            SizedBox(height: 10),
                            RichText(
                              text: TextSpan(
                                text: "Business Sub Category",
                                style: labelStyle, // Your existing style
                                children: [
                                  TextSpan(
                                    text: ' *',
                                    style: labelStyle.copyWith(color: Colors.red), // Make the asterisk red
                                  ),
                                ],
                              ),
                            ),
                            Consumer<BusinessSubCategoryList>(
                              builder: (context, value, child) {
                                return FormField<String>(
                                  validator: (val) {
                                    if ( _businessSubCategoryController
                                                  .text.isEmpty) {
                                      return 'Please select a business sub category';
                                    }
                                    if ( _businessSubCategoryController
                                                  .text.isEmpty) {
                                      return 'Please select a business sub category';
                                    }
                                    return null;
                                  },
                                  builder: (formFieldState) {
                                    return Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Autocomplete<String>(
                                          optionsBuilder: (textEditingValue) {
                                            if (textEditingValue.text.isEmpty) {
                                              return value
                                                  .businessSubCategoryList
                                                  .map((e) => e.name);
                                            }
                                            return value.businessSubCategoryList
                                                .where(
                                                  (e) => e.name
                                                      .toLowerCase()
                                                      .contains(
                                                        textEditingValue.text
                                                            .toLowerCase(),
                                                      ),
                                                )
                                                .map((e) => e.name);
                                          },
                                          onSelected: (selected) {
                                            final selectedObj = value
                                                .businessSubCategoryList
                                                .firstWhere(
                                                  (e) => e.name == selected,
                                                  orElse: () =>
                                                      BusinessSubCategoryModel(
                                                        id: -1,
                                                        name: '',
                                                        retailerCategoryName:
                                                            '',
                                                        retailerCategoryId: -1,
                                                      ),
                                                );

                                            if (selectedObj.id <= 0) {
                                              return; // invalid
                                            }

                                            setState(() {
                                              _businessSubCategoryController
                                                  .text = selectedObj.id
                                                  .toString();
                                              retailerCategoryId = selectedObj
                                                  .retailerCategoryId;
                                            });

                                            formFieldState.didChange(selected);
                                            value
                                                .setSelectedBusinessSubCategoryId(
                                                  selectedObj.id,
                                                );
                                          },
                                          fieldViewBuilder:
                                              (
                                                context,
                                                controller,
                                                focusNode,
                                                _,
                                              ) {
                                                final existingSubCat = value
                                                    .businessSubCategoryList
                                                    .firstWhere(
                                                      (e) =>
                                                          e.id.toString() ==
                                                          _businessSubCategoryController
                                                              .text,
                                                      orElse: () =>
                                                          BusinessSubCategoryModel(
                                                            id: -1,
                                                            name: '',
                                                            retailerCategoryName:
                                                                '',
                                                            retailerCategoryId:
                                                                -1,
                                                          ),
                                                    );

                                                controller.text =
                                                    existingSubCat.name;

                                                return TextField(
                                                  controller: controller,
                                                  enabled: isEdit,
                                                  focusNode: focusNode,
                                                  decoration: dropdownDecoration()
                                                      .copyWith(
                                                        hintText:
                                                            "Select Business Sub Category",
                                                        hintStyle: labelStyle,
                                                        errorText:
                                                            formFieldState
                                                                .errorText,
                                                        suffixIcon: suffixIcon(
                                                          focusNode,
                                                        ),
                                                      ),
                                                  style: isEdit
                                                      ? textStyle
                                                      : labelStyle,
                                                );
                                              },
                                          optionsViewBuilder:
                                              (context, onSelected, options) =>
                                                  buildOptionsView(
                                                    options,
                                                    onSelected,
                                                  ),
                                        ),
                                      ],
                                    );
                                  },
                                );
                              },
                            ),

                            SizedBox(height: 10),
                            Text("Store Logo", style: labelStyle),
                            SizedBox(height: 5),
                            DottedBorder(
                              color: _isStoreLogoSelected
                                  ? AppColors.selectDocumentCardBorderColor
                                  : Colors.red,
                              borderType: BorderType.RRect,
                              radius: Radius.circular(10),
                              strokeWidth: 1,
                              child: Container(
                                color:
                                    AppColors.selectDocumentCardBackgroundColor,
                                width: double.infinity,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Stack(
                                    children: [
                                      _storeLogo.isEmpty
                                          ? InkWell(
                                              onTap: () {
                                                if (!isEdit) {
                                                  return;
                                                }
                                                if (kIsWeb || kIsWasm) {
                                                  Get.snackbar(
                                                    "Error",
                                                    "This feature is not supported in web",
                                                    backgroundColor: Colors.red,
                                                    colorText: Colors.white,
                                                    snackPosition:
                                                        SnackPosition.TOP,
                                                    titleText: Text(
                                                      "Error",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  );
                                                  return;
                                                }
                                                // print('Store Logo');

                                                _showBottomSheet(
                                                  context,
                                                  () async {
                                                    String? filePath =
                                                        await Helper()
                                                            .captureImage(
                                                              context,
                                                            );
                                                    //print(filePath);
                                                    if (filePath!.isEmpty) {
                                                      Get.snackbar(
                                                        "Error",
                                                        "store image upload failed. Please reselect the images.",
                                                        backgroundColor:
                                                            Colors.red,
                                                        colorText: Colors.white,
                                                        snackPosition:
                                                            SnackPosition
                                                                .BOTTOM,
                                                        titleText: Text(
                                                          "Error",
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      );
                                                      return;
                                                    }
                                                    try {
                                                      _storeLogo =
                                                          await Helper.imageToBase64(
                                                            filePath,
                                                          );
                                                      setState(() {});
                                                    } catch (e) {
                                                      Get.snackbar(
                                                        "Error",
                                                        "store image upload failed. Please reselect the images.",
                                                        backgroundColor:
                                                            Colors.red,
                                                        colorText: Colors.white,
                                                        snackPosition:
                                                            SnackPosition
                                                                .BOTTOM,
                                                        titleText: Text(
                                                          "Error",
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  () async {
                                                    String? filePath =
                                                        await Helper()
                                                            .pickImage(context);
                                                    //print(filePath);
                                                    if (filePath!.isEmpty) {
                                                      Get.snackbar(
                                                        "Error",
                                                        "store image upload failed. Please reselect the images.",
                                                        backgroundColor:
                                                            Colors.red,
                                                        colorText: Colors.white,
                                                        snackPosition:
                                                            SnackPosition
                                                                .BOTTOM,
                                                        titleText: Text(
                                                          "Error",
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      );
                                                      return;
                                                    }
                                                    try {
                                                      _storeLogo =
                                                          await Helper.imageToBase64(
                                                            filePath,
                                                          );
                                                      setState(() {});
                                                    } catch (e) {
                                                      Get.snackbar(
                                                        "Error",
                                                        "store image upload failed. Please reselect the images.",
                                                        backgroundColor:
                                                            Colors.red,
                                                        colorText: Colors.white,
                                                        snackPosition:
                                                            SnackPosition
                                                                .BOTTOM,
                                                        titleText: Text(
                                                          "Error",
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                );
                                              },
                                              child: Center(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Image.asset(
                                                      "assets/images/image_icon.png",
                                                      height: 40,
                                                      opacity:
                                                          AlwaysStoppedAnimation(
                                                            0.5,
                                                          ),
                                                    ),
                                                    Text(
                                                      'Upload Store Logo',
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color:
                                                                AppColors.black,
                                                          ),
                                                    ),
                                                    Text(
                                                      'Support: JPG, JPEG, PNG, HEIC',
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color: AppColors
                                                                .paragraph,
                                                          ),
                                                    ),
                                                    SizedBox(height: 5),
                                                  ],
                                                ),
                                              ),
                                            )
                                          : Center(
                                              child: Column(
                                                children: [
                                                  Image.memory(
                                                    base64Decode(_storeLogo),
                                                    height: 100,
                                                    width: 100,
                                                    fit: BoxFit.contain,
                                                  ),
                                                ],
                                              ),
                                            ),
                                      _storeLogo.isEmpty
                                          ? Container()
                                          : Align(
                                              alignment: Alignment.topRight,
                                              child: IconButton(
                                                onPressed: () {
                                                  if (!isEdit) {
                                                    return;
                                                  }
                                                  setState(() {
                                                    _storeLogo = '';
                                                  });
                                                },
                                                icon: SvgPicture.string(
                                                  SvgIcons.deleteIcon,
                                                  color: isEdit
                                                      ? Colors.red
                                                      : Colors.grey,
                                                ),
                                              ),
                                            ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            !_isStoreLogoSelected
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 5),
                                    child: Text(
                                      "Please upload store logo",
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                  )
                                : Container(),
                            SizedBox(height: 10),
                            Text("Store Image 1", style: labelStyle),
                            SizedBox(height: 5),
                            DottedBorder(
                              color: _isStoreImage1Selected
                                  ? AppColors.selectDocumentCardBorderColor
                                  : Colors.red,
                              borderType: BorderType.RRect,
                              radius: Radius.circular(10),
                              strokeWidth: 1,
                              child: Container(
                                color:
                                    AppColors.selectDocumentCardBackgroundColor,
                                width: double.infinity,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Stack(
                                    children: [
                                      _storeImage1.isEmpty
                                          ? InkWell(
                                              onTap: () async {
                                                if (!isEdit) {
                                                  return;
                                                }
                                                if (kIsWeb || kIsWasm) {
                                                  Get.snackbar(
                                                    "Error",
                                                    "This feature is not supported in web",
                                                    backgroundColor: Colors.red,
                                                    colorText: Colors.white,
                                                    snackPosition:
                                                        SnackPosition.TOP,
                                                    titleText: Text(
                                                      "Error",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  );
                                                  return;
                                                }
                                                _showBottomSheet(
                                                  context,
                                                  () async {
                                                    String? filePath =
                                                        await Helper()
                                                            .captureImage(
                                                              context,
                                                            );
                                                    //print(filePath);
                                                    if (filePath!.isEmpty) {
                                                      Get.snackbar(
                                                        "Error",
                                                        "store image upload failed. Please reselect the images.",
                                                        backgroundColor:
                                                            Colors.red,
                                                        colorText: Colors.white,
                                                        snackPosition:
                                                            SnackPosition
                                                                .BOTTOM,
                                                        titleText: Text(
                                                          "Error",
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      );
                                                      return;
                                                    }
                                                    try {
                                                      _storeImage1 =
                                                          await Helper.imageToBase64(
                                                            filePath,
                                                          );
                                                      setState(() {});
                                                    } catch (e) {
                                                      Get.snackbar(
                                                        "Error",
                                                        "store image upload failed. Please reselect the images.",
                                                        backgroundColor:
                                                            Colors.red,
                                                        colorText: Colors.white,
                                                        snackPosition:
                                                            SnackPosition
                                                                .BOTTOM,
                                                        titleText: Text(
                                                          "Error",
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  () async {
                                                    String? filePath =
                                                        await Helper()
                                                            .pickImage(context);
                                                    //print(filePath);
                                                    if (filePath!.isEmpty) {
                                                      Get.snackbar(
                                                        "Error",
                                                        "store image upload failed. Please reselect the images.",
                                                        backgroundColor:
                                                            Colors.red,
                                                        colorText: Colors.white,
                                                        snackPosition:
                                                            SnackPosition
                                                                .BOTTOM,
                                                        titleText: Text(
                                                          "Error",
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      );
                                                      return;
                                                    }
                                                    try {
                                                      _storeImage1 =
                                                          await Helper.imageToBase64(
                                                            filePath,
                                                          );
                                                      setState(() {});
                                                    } catch (e) {
                                                      Get.snackbar(
                                                        "Error",
                                                        "store image upload failed. Please reselect the images.",
                                                        backgroundColor:
                                                            Colors.red,
                                                        colorText: Colors.white,
                                                        snackPosition:
                                                            SnackPosition
                                                                .BOTTOM,
                                                        titleText: Text(
                                                          "Error",
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                );
                                              },
                                              child: Center(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Image.asset(
                                                      "assets/images/image_icon.png",
                                                      height: 40,
                                                      opacity:
                                                          AlwaysStoppedAnimation(
                                                            0.5,
                                                          ),
                                                    ),
                                                    Text(
                                                      'Upload Store Image 1',
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color:
                                                                AppColors.black,
                                                          ),
                                                    ),
                                                    Text(
                                                      'Support: JPG, JPEG, PNG, HEIC',
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color: AppColors
                                                                .paragraph,
                                                          ),
                                                    ),
                                                    SizedBox(height: 5),
                                                  ],
                                                ),
                                              ),
                                            )
                                          : Center(
                                              child: Column(
                                                children: [
                                                  Image.memory(
                                                    base64Decode(_storeImage1),
                                                    height: 100,
                                                    width: 100,
                                                    fit: BoxFit.contain,
                                                  ),
                                                ],
                                              ),
                                            ),
                                      _storeImage1.isEmpty
                                          ? Container()
                                          : Align(
                                              alignment: Alignment.topRight,
                                              child: IconButton(
                                                onPressed: () {
                                                  if (!isEdit) {
                                                    return;
                                                  }
                                                  setState(() {
                                                    _storeImage1 = '';
                                                  });
                                                },
                                                icon: SvgPicture.string(
                                                  SvgIcons.deleteIcon,
                                                  color: isEdit
                                                      ? Colors.red
                                                      : Colors.grey,
                                                ),
                                              ),
                                            ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            !_isStoreImage1Selected
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 5),
                                    child: Text(
                                      "Please upload store image",
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                  )
                                : Container(),
                            SizedBox(height: 10),
                            Text("Store Image 2", style: labelStyle),
                            SizedBox(height: 5),
                            DottedBorder(
                              color: _isStoreImage2Selected
                                  ? AppColors.selectDocumentCardBorderColor
                                  : Colors.red,
                              borderType: BorderType.RRect,
                              radius: Radius.circular(10),
                              strokeWidth: 1,
                              child: Container(
                                color:
                                    AppColors.selectDocumentCardBackgroundColor,
                                width: double.infinity,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Stack(
                                    children: [
                                      _storeImage2.isEmpty
                                          ? InkWell(
                                              onTap: () async {
                                                if (!isEdit) {
                                                  return;
                                                }
                                                if (kIsWeb || kIsWasm) {
                                                  Get.snackbar(
                                                    "Error",
                                                    "This feature is not supported in web",
                                                    backgroundColor: Colors.red,
                                                    colorText: Colors.white,
                                                    snackPosition:
                                                        SnackPosition.TOP,
                                                    titleText: Text(
                                                      "Error",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  );
                                                  return;
                                                }
                                                _showBottomSheet(
                                                  context,
                                                  () async {
                                                    String? filePath =
                                                        await Helper()
                                                            .captureImage(
                                                              context,
                                                            );
                                                    //print(filePath);
                                                    if (filePath!.isEmpty) {
                                                      Get.snackbar(
                                                        "Error",
                                                        "store image upload failed. Please reselect the images.",
                                                        backgroundColor:
                                                            Colors.red,
                                                        colorText: Colors.white,
                                                        snackPosition:
                                                            SnackPosition
                                                                .BOTTOM,
                                                        titleText: Text(
                                                          "Error",
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      );
                                                      return;
                                                    }
                                                    try {
                                                      _storeImage2 =
                                                          await Helper.imageToBase64(
                                                            filePath,
                                                          );
                                                      setState(() {});
                                                    } catch (e) {
                                                      Get.snackbar(
                                                        "Error",
                                                        "store image upload failed. Please reselect the images.",
                                                        backgroundColor:
                                                            Colors.red,
                                                        colorText: Colors.white,
                                                        snackPosition:
                                                            SnackPosition
                                                                .BOTTOM,
                                                        titleText: Text(
                                                          "Error",
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  () async {
                                                    String? filePath =
                                                        await Helper()
                                                            .pickImage(context);
                                                    // print(filePath);
                                                    if (filePath!.isEmpty) {
                                                      Get.snackbar(
                                                        "Error",
                                                        "store image upload failed. Please reselect the images.",
                                                        backgroundColor:
                                                            Colors.red,
                                                        colorText: Colors.white,
                                                        snackPosition:
                                                            SnackPosition
                                                                .BOTTOM,
                                                        titleText: Text(
                                                          "Error",
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      );
                                                      return;
                                                    }
                                                    try {
                                                      _storeImage2 =
                                                          await Helper.imageToBase64(
                                                            filePath,
                                                          );
                                                      setState(() {});
                                                    } catch (e) {
                                                      Get.snackbar(
                                                        "Error",
                                                        "store image upload failed. Please reselect the images.",
                                                        backgroundColor:
                                                            Colors.red,
                                                        colorText: Colors.white,
                                                        snackPosition:
                                                            SnackPosition
                                                                .BOTTOM,
                                                        titleText: Text(
                                                          "Error",
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                );
                                              },
                                              child: Center(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Image.asset(
                                                      "assets/images/image_icon.png",
                                                      height: 40,
                                                      opacity:
                                                          AlwaysStoppedAnimation(
                                                            0.5,
                                                          ),
                                                    ),
                                                    Text(
                                                      'Upload Store Image 2',
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color:
                                                                AppColors.black,
                                                          ),
                                                    ),
                                                    Text(
                                                      'Support: JPG, JPEG, PNG, HEIC',
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color: AppColors
                                                                .paragraph,
                                                          ),
                                                    ),
                                                    SizedBox(height: 5),
                                                  ],
                                                ),
                                              ),
                                            )
                                          : Center(
                                              child: Column(
                                                children: [
                                                  Image.memory(
                                                    base64Decode(_storeImage2),
                                                    height: 100,
                                                    width: 100,
                                                    fit: BoxFit.contain,
                                                  ),
                                                ],
                                              ),
                                            ),
                                      _storeImage2.isEmpty
                                          ? Container()
                                          : Align(
                                              alignment: Alignment.topRight,
                                              child: IconButton(
                                                onPressed: () {
                                                  if (!isEdit) {
                                                    return;
                                                  }
                                                  setState(() {
                                                    _storeImage2 = '';
                                                  });
                                                },
                                                icon: SvgPicture.string(
                                                  SvgIcons.deleteIcon,
                                                  color: isEdit
                                                      ? Colors.red
                                                      : Colors.grey,
                                                ),
                                              ),
                                            ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            !_isStoreImage2Selected
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 5),
                                    child: Text(
                                      "Please upload store image",
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                  )
                                : Container(),
                            SizedBox(height: 10),
                            Text("Store Image 3", style: labelStyle),
                            SizedBox(height: 5),
                            DottedBorder(
                              color: _isStoreImage3Selected
                                  ? AppColors.selectDocumentCardBorderColor
                                  : Colors.red,
                              borderType: BorderType.RRect,
                              radius: Radius.circular(10),
                              strokeWidth: 1,
                              child: Container(
                                color:
                                    AppColors.selectDocumentCardBackgroundColor,
                                width: double.infinity,
                                child: Padding(
                                  padding: const EdgeInsets.all(8.0),
                                  child: Stack(
                                    children: [
                                      _storeImage3.isEmpty
                                          ? InkWell(
                                              onTap: () async {
                                                if (kIsWeb || kIsWasm) {
                                                  if (!isEdit) {
                                                    return;
                                                  }
                                                  Get.snackbar(
                                                    "Error",
                                                    "This feature is not supported in web",
                                                    backgroundColor: Colors.red,
                                                    colorText: Colors.white,
                                                    snackPosition:
                                                        SnackPosition.TOP,
                                                    titleText: Text(
                                                      "Error",
                                                      style: TextStyle(
                                                        color: Colors.white,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                      ),
                                                    ),
                                                  );
                                                  return;
                                                }
                                                _showBottomSheet(
                                                  context,
                                                  () async {
                                                    String? filePath =
                                                        await Helper()
                                                            .captureImage(
                                                              context,
                                                            );
                                                    // print(filePath);
                                                    if (filePath!.isEmpty) {
                                                      Get.snackbar(
                                                        "Error",
                                                        "store image upload failed. Please reselect the images.",
                                                        backgroundColor:
                                                            Colors.red,
                                                        colorText: Colors.white,
                                                        snackPosition:
                                                            SnackPosition
                                                                .BOTTOM,
                                                        titleText: Text(
                                                          "Error",
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      );
                                                      return;
                                                    }
                                                    try {
                                                      _storeImage3 =
                                                          await Helper.imageToBase64(
                                                            filePath,
                                                          );
                                                      setState(() {});
                                                    } catch (e) {
                                                      Get.snackbar(
                                                        "Error",
                                                        "store image upload failed. Please reselect the images.",
                                                        backgroundColor:
                                                            Colors.red,
                                                        colorText: Colors.white,
                                                        snackPosition:
                                                            SnackPosition
                                                                .BOTTOM,
                                                        titleText: Text(
                                                          "Error",
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                  () async {
                                                    String? filePath =
                                                        await Helper()
                                                            .pickImage(context);
                                                    // print(filePath);
                                                    if (filePath!.isEmpty) {
                                                      Get.snackbar(
                                                        "Error",
                                                        "store image upload failed. Please reselect the images.",
                                                        backgroundColor:
                                                            Colors.red,
                                                        colorText: Colors.white,
                                                        snackPosition:
                                                            SnackPosition
                                                                .BOTTOM,
                                                        titleText: Text(
                                                          "Error",
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      );
                                                      return;
                                                    }
                                                    try {
                                                      _storeImage3 =
                                                          await Helper.imageToBase64(
                                                            filePath,
                                                          );
                                                      setState(() {});
                                                    } catch (e) {
                                                      Get.snackbar(
                                                        "Error",
                                                        "store image upload failed. Please reselect the images.",
                                                        backgroundColor:
                                                            Colors.red,
                                                        colorText: Colors.white,
                                                        snackPosition:
                                                            SnackPosition
                                                                .BOTTOM,
                                                        titleText: Text(
                                                          "Error",
                                                          style: TextStyle(
                                                            color: Colors.white,
                                                            fontWeight:
                                                                FontWeight.bold,
                                                          ),
                                                        ),
                                                      );
                                                    }
                                                  },
                                                );
                                              },
                                              child: Center(
                                                child: Column(
                                                  mainAxisAlignment:
                                                      MainAxisAlignment.center,
                                                  children: [
                                                    Image.asset(
                                                      "assets/images/image_icon.png",
                                                      height: 40,
                                                      opacity:
                                                          AlwaysStoppedAnimation(
                                                            0.5,
                                                          ),
                                                    ),
                                                    Text(
                                                      'Upload Store Image 3',
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 14,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color:
                                                                AppColors.black,
                                                          ),
                                                    ),
                                                    Text(
                                                      'Support: JPG, JPEG, PNG, HEIC',
                                                      style:
                                                          GoogleFonts.poppins(
                                                            fontSize: 10,
                                                            fontWeight:
                                                                FontWeight.w500,
                                                            color: AppColors
                                                                .paragraph,
                                                          ),
                                                    ),
                                                    SizedBox(height: 5),
                                                  ],
                                                ),
                                              ),
                                            )
                                          : Center(
                                              child: Column(
                                                children: [
                                                  Image.memory(
                                                    base64Decode(_storeImage3),
                                                    height: 100,
                                                    width: 100,
                                                    fit: BoxFit.contain,
                                                  ),
                                                ],
                                              ),
                                            ),
                                      _storeImage3.isEmpty
                                          ? Container()
                                          : Align(
                                              alignment: Alignment.topRight,
                                              child: IconButton(
                                                onPressed: () {
                                                  if (!isEdit) {
                                                    return;
                                                  }
                                                  setState(() {
                                                    _storeImage3 = '';
                                                  });
                                                },
                                                icon: SvgPicture.string(
                                                  SvgIcons.deleteIcon,
                                                  color: isEdit
                                                      ? Colors.red
                                                      : Colors.grey,
                                                ),
                                              ),
                                            ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                            !_isStoreImage3Selected
                                ? Padding(
                                    padding: const EdgeInsets.only(top: 5),
                                    child: Text(
                                      "Please upload store image",
                                      style: TextStyle(
                                        color: Colors.red,
                                        fontSize: 12,
                                      ),
                                    ),
                                  )
                                : Container(),
                            SizedBox(height: 20),
                            ElevatedButton(
                              onPressed: () async {
                                if (!isEdit) {
                                  setState(() {
                                    isEdit = !isEdit;
                                  });
                                  return;
                                }

                                if (!_formKey.currentState!.validate()) {
                                  Get.snackbar(
                                    "Error",
                                    "Please enter required fields",
                                    backgroundColor: Colors.red,
                                    colorText: Colors.white,
                                    snackPosition: SnackPosition.BOTTOM,
                                  );
                                  return;
                                }
                                int userId = await SharedPreference.getUserId();
                                Map<String, dynamic>
                                body = OutletCreationBody.updateListingData(
                                  brand_description:
                                      _brandDescriptionController.text,
                                  brand_type: _brandTypeController.text,
                                  website: _websiteController.text,
                                  lead_id: leadId,
                                  user_id: userId,
                                  brand_name: _brandNameController.text.trim(),
                                  name: _retailerNameController.text.trim(),
                                  street: _street1Controller.text.trim(),
                                  street2: _street2Controller.text.trim(),
                                  country_id: _countryController.text.trim(),
                                  state_id: _stateController.text.trim(),
                                  district_id: _districtController.text.trim(),
                                  city_id: _cityController.text.trim(),
                                  zip_code_id: _pinCodeController.text.trim(),
                                  latitude: _gpsLocationController.text
                                      .split(",")[0]
                                      .trim(),
                                  longitude: _gpsLocationController.text
                                      .split(",")[1]
                                      .trim(),
                                  contact_name: _contactNameController.text
                                      .trim(),
                                  mobile: _mobileNumberController.text.trim(),
                                  email: _emailIdController.text.trim(),
                                  expected_revenue: _dailyAvgRevenueController
                                      .text
                                      .trim(),
                                  class_of_retailer: _classOfRetailerController
                                      .text
                                      .trim(),
                                  retailer_ownership_id:
                                      _retailerOwnershipController.text.trim(),
                                  // channel_id: _channelTypeController.text
                                  //     .trim(),
                                  channel_id:"6",
                                  business_category_id:
                                      _businessCategoryController.text.trim(),
                                  business_sub_category_id:
                                      _businessSubCategoryController.text
                                          .trim(),
                                  logo: _storeLogo,
                                  image1: _storeImage1,
                                  image2: _storeImage2,
                                  image3: _storeImage3,
                                  opening_time: _openingTimeController.text,
                                  closing_time: _closingTimeController.text,
                                  pos_name: _posNameController.text,
                                  pos_no: _posNumberController.text,
                                  next_follow_up: _nextFollowUpDateController.text.isNotEmpty
                                      ? output.format(formatDate(_nextFollowUpDateController.text))
                                      : null,
                                  description: _descriptionController.text,
                                  //output.format(selectedDate)
                                );
                                final context = _brandNameKey.currentContext;
                                if (context != null) {
                                  Scrollable.ensureVisible(
                                    context,
                                    duration: Duration(milliseconds: 500),
                                    curve: Curves.easeInOut,
                                    alignment: 0.1, // Adjust as needed
                                  );
                                }
                                isEdit = !isEdit;
                                isLoading = true;
                                await outletDescriptionProvider.updateLead(
                                  body,
                                  isBack: false,
                                  showMessage: true,
                                );
                                //print(jsonEncode(body));
                                // ClearProvider.clearLocationBaseProviders(context);
                                await outletDescriptionProvider.getOutlet(
                                  leadId,
                                );

                                setData();
                              },
                              style: ElevatedButton.styleFrom(
                                foregroundColor: Colors.white,
                                backgroundColor: AppColors.primaryColor,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                minimumSize: Size(double.infinity, 50),
                              ),
                              child: Text(
                                isEdit ? "Save Lead" : "Edit Lead",
                                style: Theme.of(context).textTheme.titleMedium!
                                    .copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                              ),
                            ),
                            SizedBox(height: 10),
                            if (leadStatus == "subscribed" && !isEdit) ...[
                              if (outletDescriptionProvider
                                  .outletList
                                  .isNotEmpty) ...[
                                if (outletDescriptionProvider
                                        .outletList[0]
                                        .kycDocumentList
                                        .isNotEmpty ||
                                    int.parse(
                                          _retailerOwnershipController
                                                  .text
                                                  .isEmpty
                                              ? "-1"
                                              : _retailerOwnershipController
                                                    .text,
                                        ) >
                                        0) ...[
                                  ElevatedButton(
                                    onPressed: () async {
                                      if (_retailerOwnershipController
                                              .text
                                              .isEmpty ||
                                          int.parse(
                                                _retailerOwnershipController
                                                    .text,
                                              ) <
                                              1) {
                                        Get.snackbar(
                                          "Error",
                                          "Please select retailer ownership",
                                          backgroundColor: Colors.red,
                                          colorText: Colors.white,
                                          snackPosition: SnackPosition.BOTTOM,
                                        );
                                        return;
                                      }
                                      setState(() {
                                        isLoading = true;
                                      });
                                      await outletKycDocumentListProvider
                                          .fetchAndMergeKycDocuments(
                                            outletDescriptionProvider
                                                .outletList[0]
                                                .retailerOwnershipId,
                                            outletDescriptionProvider
                                                .outletList[0]
                                                .id,
                                        isNavigate: true
                                          );
                                      setState(() {
                                        isLoading = false;
                                      });
                                    },
                                    style: ElevatedButton.styleFrom(
                                      foregroundColor: Colors.white,
                                      backgroundColor: AppColors.primaryColor,
                                      shape: RoundedRectangleBorder(
                                        borderRadius: BorderRadius.circular(12),
                                      ),
                                      minimumSize: Size(double.infinity, 50),
                                    ),
                                    child: Text(
                                      "View KYC Documents",
                                      style: Theme.of(context)
                                          .textTheme
                                          .titleMedium!
                                          .copyWith(
                                            fontWeight: FontWeight.bold,
                                            color: Colors.white,
                                          ),
                                    ),
                                  ),
                                  SizedBox(height: 10),
                                ],
                              ],
                            ],

                            if (!isEdit) ...[
                              if(leadStatus != "subscribed")...[
                                ElevatedButton(
                                  onPressed: () async {
                                    showDialog(
                                      context: context,
                                      useSafeArea: true,
                                      builder: (context) {
                                        return Dialog(
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              20,
                                            ),
                                          ),
                                          backgroundColor: Colors.white,
                                          child: Padding(
                                            padding: const EdgeInsets.all(20.0),
                                            child: Column(
                                              mainAxisAlignment:
                                              MainAxisAlignment.center,
                                              crossAxisAlignment:
                                              CrossAxisAlignment.center,
                                              mainAxisSize: MainAxisSize.min,
                                              children: [
                                                // Text(
                                                //   "Select Lead Status",
                                                //   textAlign: TextAlign.center,
                                                //   style: GoogleFonts.poppins(
                                                //     fontSize: 16,
                                                //     fontWeight: FontWeight.w500,
                                                //     color: AppColors.black,
                                                //   ),
                                                // ),
                                                // SizedBox(height: 10),
                                                //
                                                if (leadStatus !=
                                                    "free_listing") ...[
                                                  ElevatedButton(
                                                    onPressed: () async {
                                                      int userId =
                                                      await SharedPreference.getUserId();
                                                      Map<String, dynamic>
                                                      body = {
                                                        "id": leadId,
                                                        "user_id": userId,
                                                        "type": "opportunity",
                                                        "active": true,
                                                        "stage_id": 1,
                                                        "is_subscription_declined":
                                                        false,
                                                        "listing_status":
                                                        "free_listing",
                                                      };
                                                      outletDescriptionProvider
                                                          .updateLead(body);
                                                      //print(jsonEncode(body));
                                                      GetxNavigation().goBack();
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                      // foregroundColor:
                                                      // getLeadStatusBackgroundColor(
                                                      //   "free_listing",
                                                      // ),
                                                      backgroundColor:
                                                      getLeadStatusBackgroundColor(
                                                        "free_listing",
                                                      ),
                                                      surfaceTintColor:
                                                      getLeadStatusBackgroundColor(
                                                        "free_listing",
                                                      ),
                                                      // 👈 prevents tint overlay
                                                      shadowColor:
                                                      getLeadStatusBackgroundColor(
                                                        "free_listing",
                                                      ),
                                                      // 👈 optional: avoid unwanted shadow blend
                                                      elevation: 0,
                                                      // 👈 optional: reduce shadow effect
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                      ),
                                                      minimumSize: Size(
                                                        double.infinity,
                                                        50,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      "Free listing",
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleMedium!
                                                          .copyWith(
                                                        fontWeight:
                                                        FontWeight.bold,
                                                        color:
                                                        getLeadStatusColor(
                                                          "free_listing",
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(height: 10),
                                                ],
                                                if (leadStatus !=
                                                    "decline_subscription" && leadStatus !=
                                                    "subscribed") ...[
                                                  ElevatedButton(
                                                    onPressed: () async {
                                                      int userId =
                                                      await SharedPreference.getUserId();
                                                      Map<String, dynamic>
                                                      body = {
                                                        "id": leadId,
                                                        "user_id": userId,
                                                        // "type": "opportunity",
                                                        "active": false,
                                                        "is_subscription_declined":
                                                        true,
                                                        "listing_status":
                                                        "decline_subscription",
                                                      };
                                                      outletDescriptionProvider
                                                          .updateLead(body);
                                                      // print(jsonEncode(body));
                                                      GetxNavigation().goBack();
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                      foregroundColor:
                                                      getLeadStatusBackgroundColor(
                                                        "decline_subscription",
                                                      ),
                                                      backgroundColor:
                                                      getLeadStatusBackgroundColor(
                                                        "decline_subscription",
                                                      ),
                                                      surfaceTintColor:
                                                      getLeadStatusBackgroundColor(
                                                        "decline_subscription",
                                                      ),
                                                      // 👈 prevents tint overlay
                                                      shadowColor:
                                                      getLeadStatusBackgroundColor(
                                                        "decline_subscription",
                                                      ),
                                                      // 👈 optional: avoid unwanted shadow blend
                                                      elevation: 0,
                                                      // 👈 optional: reduce shadow effect
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                      ),
                                                      minimumSize: Size(
                                                        double.infinity,
                                                        50,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      "Decline Subscription",
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleMedium!
                                                          .copyWith(
                                                        fontWeight:
                                                        FontWeight.bold,
                                                        color: getLeadStatusColor(
                                                          "decline_subscription",
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(height: 10),
                                                ],
                                                if (leadStatus !=
                                                    "subscribed") ...[
                                                  ElevatedButton(
                                                    onPressed: () async {
                                                      if (_retailerOwnershipController
                                                          .text
                                                          .isEmpty ||
                                                          int.parse(
                                                            _retailerOwnershipController
                                                                .text,
                                                          ) <
                                                              1) {
                                                        Get.snackbar(
                                                          "Error",
                                                          "Please select retailer ownership",
                                                          backgroundColor:
                                                          Colors.red,
                                                          colorText: Colors.white,
                                                          snackPosition:
                                                          SnackPosition
                                                              .BOTTOM,
                                                        );
                                                        return;
                                                      }


                                                        GetxNavigation().goBack();
                                                        GetxNavigation().next(KycDescriptionScreen.routeName);

                                                      //print(jsonEncode(body));
                                                      setState(() {
                                                        leadStatus = "free_listing";
                                                      });
                                                    },
                                                    style: ElevatedButton.styleFrom(
                                                      foregroundColor:
                                                      getLeadStatusBackgroundColor(
                                                        "subscribed",
                                                      ),
                                                      backgroundColor:
                                                      getLeadStatusBackgroundColor(
                                                        "subscribed",
                                                      ),
                                                      surfaceTintColor:
                                                      getLeadStatusBackgroundColor(
                                                        "subscribed",
                                                      ),
                                                      // 👈 prevents tint overlay
                                                      shadowColor:
                                                      getLeadStatusBackgroundColor(
                                                        "subscribed",
                                                      ),
                                                      // 👈 optional: avoid unwanted shadow blend
                                                      elevation: 0,

                                                      // 👈 optional: reduce shadow effect
                                                      shape: RoundedRectangleBorder(
                                                        borderRadius:
                                                        BorderRadius.circular(
                                                          8,
                                                        ),
                                                      ),
                                                      minimumSize: Size(
                                                        double.infinity,
                                                        50,
                                                      ),
                                                    ),
                                                    child: Text(
                                                      "Subscribe",
                                                      style: Theme.of(context)
                                                          .textTheme
                                                          .titleMedium!
                                                          .copyWith(
                                                        fontWeight:
                                                        FontWeight.bold,
                                                        color:
                                                        getLeadStatusColor(
                                                          "subscribed",
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  SizedBox(height: 10),
                                                ],

                                                // if (leadStatus !=
                                                //     "decline_listing") ...[
                                                //   ElevatedButton(
                                                //     onPressed: () async {
                                                //       int userId =
                                                //       await SharedPreference.getUserId();
                                                //       Map<String, dynamic>
                                                //       body = {
                                                //         "id": leadId,
                                                //         "user_id": userId,
                                                //         "type": "lead",
                                                //         "active": true,
                                                //         "is_subscription_declined":
                                                //         false,
                                                //         "is_subscribed": false,
                                                //         "listing_status":
                                                //         "decline_listing",
                                                //       };
                                                //       outletDescriptionProvider
                                                //           .updateLead(body);
                                                //       //print(jsonEncode(body));
                                                //       GetxNavigation().goBack();
                                                //     },
                                                //     style: ElevatedButton.styleFrom(
                                                //       foregroundColor:
                                                //       getLeadStatusBackgroundColor(
                                                //         "decline_listing",
                                                //       ),
                                                //       backgroundColor:
                                                //       getLeadStatusBackgroundColor(
                                                //         "decline_listing",
                                                //       ),
                                                //
                                                //       surfaceTintColor:
                                                //       getLeadStatusBackgroundColor(
                                                //         "decline_listing",
                                                //       ),
                                                //       // 👈 prevents tint overlay
                                                //       shadowColor:
                                                //       getLeadStatusBackgroundColor(
                                                //         "decline_listing",
                                                //       ),
                                                //       // 👈 optional: avoid unwanted shadow blend
                                                //       elevation: 0,
                                                //       // 👈 optional: reduce shadow effect
                                                //       shape: RoundedRectangleBorder(
                                                //         borderRadius:
                                                //         BorderRadius.circular(
                                                //           8,
                                                //         ),
                                                //       ),
                                                //       minimumSize: Size(
                                                //         double.infinity,
                                                //         50,
                                                //       ),
                                                //     ),
                                                //     child: Text(
                                                //       "Decline",
                                                //       style: Theme.of(context)
                                                //           .textTheme
                                                //           .titleMedium!
                                                //           .copyWith(
                                                //         fontWeight:
                                                //         FontWeight.bold,
                                                //         color:
                                                //         getLeadStatusColor(
                                                //           "decline_listing",
                                                //         ),
                                                //       ),
                                                //     ),
                                                //   ),
                                                // ],
                                              ],
                                            ),
                                          ),
                                        );
                                      },
                                    );
                                  },
                                  style: ElevatedButton.styleFrom(
                                    foregroundColor: Colors.white,
                                    backgroundColor: AppColors.primaryColor,
                                    shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(12),
                                    ),
                                    minimumSize: Size(double.infinity, 50),
                                  ),
                                  child: Text(
                                    "Change Lead Status",
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium!
                                        .copyWith(
                                      fontWeight: FontWeight.bold,
                                      color: Colors.white,
                                    ),
                                  ),
                                ),
                              ],

                            ],
                            SizedBox(height: 30),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
        isLoading ? LoadingWidget() : Container(),
      ],
    );
  }
}
