import 'dart:async';
import 'dart:io';

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
import 'package:retail_gpt/navigation/getx_navigation.dart';
import 'package:retail_gpt/providers/create_new_outlet_screens/create_outlet_provider.dart';
import 'package:retail_gpt/providers/utility_provider/business_category_list_provider.dart';
import 'package:retail_gpt/providers/utility_provider/business_sub_category_list.dart';
import 'package:retail_gpt/providers/utility_provider/channel_type_provider.dart';
import 'package:retail_gpt/providers/utility_provider/city_list_provider.dart';
import 'package:retail_gpt/providers/utility_provider/district_list_provider.dart';
import 'package:retail_gpt/providers/utility_provider/local_data_provider.dart';
import 'package:retail_gpt/providers/utility_provider/pin_code_list_provider.dart';
import 'package:retail_gpt/providers/utility_provider/retailer_ownership_provider.dart';
import 'package:retail_gpt/providers/utility_provider/state_list_provider.dart';
import 'package:retail_gpt/utils/app_colors.dart';
import 'package:retail_gpt/utils/outlet_creation_body.dart';
import 'package:retail_gpt/utils/utility_data.dart';
import 'package:retail_gpt/widgets/background_widget.dart';
import 'package:retail_gpt/widgets/loading_widget.dart';

import '../../providers/utility_provider/country_list_provider.dart';

class CreateNewOutletScreen extends StatefulWidget {
  static const String routeName = '/create-new-outlet-screen';

  const CreateNewOutletScreen({super.key});

  @override
  State<CreateNewOutletScreen> createState() => _CreateNewOutletScreenState();
}

class _CreateNewOutletScreenState extends State<CreateNewOutletScreen> {
  final _formKey = GlobalKey<FormState>();
  final ScrollController _scrollController = ScrollController();


  Timer? _emailDebounce;
  String? _emailErrorText;
  bool _isCheckingEmail = false;

  Timer? _mobileDebounce;
  String? _mobileErrorText;
  bool _isCheckingMobile = false;

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

  // Retailer Name
  final _retailerNameController = TextEditingController();

  // pos name
  final _posNameController = TextEditingController();

  // pos number
  final _posNumberController = TextEditingController();

  // next follow up date
  final _nextFollowUpDateController = TextEditingController();

  // description
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


  // ADD THESE GlobalKeys
  final GlobalKey _retailerNameKey = GlobalKey();
  final GlobalKey _brandNameKey = GlobalKey();
  final GlobalKey _countryKey = GlobalKey();
  final GlobalKey _stateKey = GlobalKey();
  final GlobalKey _districtKey = GlobalKey();
  final GlobalKey _cityKey = GlobalKey();
  final GlobalKey _gpsLocationKey = GlobalKey();
  final GlobalKey _mobileNumberKey = GlobalKey();
  final GlobalKey _emailIdKey = GlobalKey();
  final GlobalKey _retailerOwnershipKey = GlobalKey();
  final GlobalKey _businessCategoryKey = GlobalKey();
  final GlobalKey _businessSubCategoryKey = GlobalKey();

  int retailerCategoryId = -1;

  // store logo
  String _storeLogo = '';
  String base64logo = '';
  bool _isStoreLogoSelected = true;

  // store image
  String _storeImage1 = '';
  String base64image1 = '';
  bool _isStoreImage1Selected = true;
  String _storeImage2 = '';
  String base64image2 = '';
  bool _isStoreImage2Selected = true;
  String _storeImage3 = '';
  String base64image3 = '';
  bool _isStoreImage3Selected = true;

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
    setState(() {
      _brandNameController.clear();
      _retailerNameController.clear();
      _brandDescriptionController.clear();
      _descriptionController.clear();
      _posNameController.clear();
      _posNumberController.clear();
      _nextFollowUpDateController.clear();
      _brandTypeController.clear();
      _districtController.clear();
      _street1Controller.clear();
      _street2Controller.clear();
      _countryController.clear();
      _stateController.clear();
      _cityController.clear();
      _pinCodeController.clear();
      _gpsLocationController.clear();
      _contactNameController.clear();
      _websiteController.clear();
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
      _storeLogo = '';
      _isStoreLogoSelected = true;
      _storeImage1 = '';
      _isStoreImage1Selected = true;
      _storeImage2 = '';
      _isStoreImage2Selected = true;
      _storeImage3 = '';
      _isStoreImage3Selected = true;
      _formKey.currentState!.reset();
    });
  }

  Future<void> _checkEmailExists(String email) async {

    if (email.isEmpty || !RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(email)) {
      setState(() {
        _emailErrorText = null;  // ADD THIS - Clear error for invalid format
        _isCheckingEmail = false;
      });
      return;
    }

    setState(() {
      _isCheckingEmail = true;
      _emailErrorText = null;
    });

    CreateOutletProvider createOutletProvider = Provider.of<CreateOutletProvider>(
      context,
      listen: false,
    );

    bool exists = await createOutletProvider.checkFieldExists('email', email);

    setState(() {
      _emailErrorText = exists ? 'Email already exists' : null;
      _isCheckingEmail = false;
    });
    _formKey.currentState?.validate();

  }



  Future<void> _checkMobileExists(String mobile) async {
    if (mobile.isEmpty || mobile.length != 10) {
      setState(() {
        _mobileErrorText = null;  // ADD THIS - Clear error for invalid format
        _isCheckingMobile = false;
      });
      return;
    }

    setState(() {
      _isCheckingMobile = true;
      _mobileErrorText = null;
    });

    CreateOutletProvider createOutletProvider = Provider.of<CreateOutletProvider>(
      context,
      listen: false,
    );

    bool exists = await createOutletProvider.checkFieldExists('mobile', mobile);

    setState(() {
      _mobileErrorText = exists ? 'Mobile number already exists' : null;
      _isCheckingMobile = false;
    });
    _formKey.currentState?.validate();

  }


  // Call this function when you want to show the dialog
  void confirmReset(BuildContext context) {
    showResetConfirmationDialog(context, resetForm);
  }

  // date
  DateTime selectedDate = DateTime.now();
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

  Future<void> showCupertinoTimePicker(
    BuildContext context,
    Function(String) onTimeSelected,
  ) async {
    await showCupertinoModalPopup<void>(
      context: context,
      builder: (_) {
        final size = MediaQuery.of(context).size;
        return Stack(
          children: [
            Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.only(
                  topLeft: Radius.circular(12),
                  topRight: Radius.circular(12),
                ),
              ),
              height: size.height * 0.27,
              child: CupertinoDatePicker(
                use24hFormat: false,
                backgroundColor: Colors.white,
                itemExtent: 40,
                mode: CupertinoDatePickerMode.time,
                onDateTimeChanged: (value) {
                  setState(() {
                    selectedDate = value;
                  });
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                CupertinoButton(
                  onPressed: () {},
                  child: Text(
                    '',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ),
                CupertinoButton(
                  onPressed: () {
                    setState(() {
                      print(selectedDate);
                      // convert selected date to time of day into 24 hour format
                      String selectedTime =
                          "${selectedDate.hour}:${selectedDate.minute}";

                      print(selectedTime);

                      onTimeSelected(selectedTime);
                    });
                    Navigator.of(context).pop();
                  },
                  child: Text(
                    'Done',
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.primaryColor,
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
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

    print(_countryController.text);

    address[0] = _street1Controller.text;
    address[1] = _street2Controller.text;
    address[2] = _districtController.text.isNotEmpty
        ? districtListProvider
              .getSelectedDistrict(int.parse(_districtController.text))
              .name
        : "";
    address[3] = _cityController.text.isNotEmpty
        ? cityListProvider.getSelectedCity(int.parse(_cityController.text)).name
        : "";
    address[4] = _stateController.text.isNotEmpty
        ? stateListProvider
              .getSelectedState(int.parse(_stateController.text))
              .name
        : "";
    address[5] = _countryController.text.isNotEmpty
        ? countryListProvider
              .getSelectedCountry(int.parse(_countryController.text))
              .name
        : "";
    address[6] = _pinCodeController.text.isNotEmpty
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

  @override
  void initState() {
    // TODO: implement initState
    Future.wait([getData(), setData()]);
    // Future.microtask(() async {
    //   await getData();
    //   setData();
    // });
    super.initState();
  }

  Future<void> getData() async {
    CountryListProvider countryListProvider = Provider.of<CountryListProvider>(
      context,
      listen: false,
    );
    // await countryListProvider.getCountryList();

    ChannelTypeProvider channelTypeProvider = Provider.of<ChannelTypeProvider>(
      context,
      listen: false,
    );
    // await channelTypeProvider.getChannelTypeList();

    BusinessCategoryListProvider businessCategoryListProvider =
        Provider.of<BusinessCategoryListProvider>(context, listen: false);
    // await businessCategoryListProvider.getBusinessCategoryList();

    BusinessSubCategoryList businessSubCategoryListProvider =
        Provider.of<BusinessSubCategoryList>(context, listen: false);
    // await businessSubCategoryListProvider.getBusinessSubCategoryList();

    TimeProvider timeProvider = Provider.of<TimeProvider>(
      context,
      listen: false,
    );
    // await timeProvider.getOpeningTime();

    Future.wait([
      countryListProvider.getCountryList(),
      channelTypeProvider.getChannelTypeList(),
      businessCategoryListProvider.getBusinessCategoryList(),

      timeProvider.getOpeningTime(),
      timeProvider.getClosingTime(),
    ]);
  }

  @override
  void dispose() {
    print('🧹 Disposing email debounce timer');
    _emailDebounce?.cancel();
    _mobileDebounce?.cancel();  // Add this
    _scrollController.dispose();


    super.dispose();
  }

  Future<void> setPreFillData() async {
    // is debug
    if (!kDebugMode) {
      return;
    }
    setState(() {
      _brandNameController.text = "Demo Brand";
      _retailerNameController.text = "Demo Retailer";
      _street1Controller.text = "Demo Street 1";
      _street2Controller.text = "Demo Street 2";
      _countryController.text = "India";
      _stateController.text = "Gujarat";
      _cityController.text = "Ahmedabad";
      _pinCodeController.text = "382350";
      _contactNameController.text = "Demo Contact";
      _mobileNumberController.text = "1234567890";
      _emailIdController.text = "demo@gmail.com";
      _displayAddressController.text = "Demo Display Address";
      _openingTimeController.text = "09:00 AM";
      _closingTimeController.text = "09:00 PM";
      _dailyAvgRevenueController.text = "10000";
      _classOfRetailerController.text = "Grocery";
      _retailerOwnershipController.text = "Individual";
      _channelTypeController.text = "Both";
      _businessCategoryController.text = "Retailer";
      _businessSubCategoryController.text = "Others";
    });
  }

  Future<void> setData() async {
    if (kIsWeb) {
      return;
    }

    // if IOS
    if (Platform.isIOS) {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: AppleSettings(accuracy: LocationAccuracy.high),
      );
      _gpsLocationController.text =
          '${position.latitude}, ${position.longitude}';
    }
    // if Android
    if (Platform.isAndroid) {
      Position position = await Geolocator.getCurrentPosition(
        locationSettings: AndroidSettings(accuracy: LocationAccuracy.high),
      );
      _gpsLocationController.text =
          '${position.latitude}, ${position.longitude}';
    }

    // setState(() {
    //   _stateController.text = _navigationArgumentData['state'];
    //   _cityController.text = _navigationArgumentData['city'];
    //   _pinCodeController.text = _navigationArgumentData['pinCode'];
    // });
  }

  @override
  Widget build(BuildContext context) {
    LocalDataProvider localDataProvider = Provider.of<LocalDataProvider>(
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
    RetailerOwnershipProvider retailerOwnershipProvider =
        Provider.of<RetailerOwnershipProvider>(context, listen: false);
    CreateOutletProvider createOutletProvider =
        Provider.of<CreateOutletProvider>(context, listen: true);

    return Stack(
      children: [
        BackgroundWidget(
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
            padding: EdgeInsets.only(top: 20),
            child: Form(
              key: _formKey,
              child: RefreshIndicator(
                onRefresh: () async {
                  // await Future.delayed(Duration(milliseconds: 800));
                  confirmReset(context);
                },
                semanticsLabel: 'Reset Form',
                semanticsValue: 'Reset Form',
                child: SingleChildScrollView(
                  controller: _scrollController,  // ADD THIS LINE
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
                        key: _retailerNameKey,  // ADD THIS

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
                      TextFormField(
                        key: _brandNameKey,  // ADD THIS
                        controller: _brandNameController,
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
                      SizedBox(height: 10),
                      Text("Brand Description", style: labelStyle),
                      TextFormField(
                        controller: _brandDescriptionController,
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
                        hint: Text("Select Brand Type", style: labelStyle),
                        value: _brandTypeController.text.isNotEmpty
                            ? _brandTypeController.text
                            : null,
                        items: brandTypes.map<DropdownMenuItem<String>>((e) {
                          return DropdownMenuItem<String>(
                            value: e['brandValue'],
                            child: Text(e['brandName']),
                          );
                        }).toList(),
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _brandTypeController.text = newValue;
                            });
                          }
                        },
                      ),
                      SizedBox(height: 10),
                      Text("Pos Name", style: labelStyle),
                      TextFormField(
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
                        enabled: true,
                        keyboardType: TextInputType.text,
                        keyboardAppearance: Brightness.dark,
                        minLines: 1,
                        maxLines: 1,
                        readOnly: true,
                        decoration: inputDecoration("Click to select date"),
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
                                    onTap: () {}, // Prevent tap propagation
                                    child: Align(
                                      alignment: Alignment.bottomCenter,
                                      child: Container(
                                        height: 300,
                                        decoration: BoxDecoration(
                                          color: Colors.white,
                                          borderRadius: BorderRadius.vertical(
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
                                                    padding: EdgeInsets.zero,
                                                    child: Text(
                                                      'Cancel',
                                                      style: TextStyle(
                                                        color: Colors.purple,
                                                      ),
                                                    ),
                                                    onPressed: () =>
                                                        Navigator.of(
                                                          context,
                                                        ).pop(),
                                                  ),
                                                  CupertinoButton(
                                                    padding: EdgeInsets.zero,
                                                    child: Text(
                                                      'Clear',
                                                      style: TextStyle(
                                                        color: Colors.purple,
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
                                                    padding: EdgeInsets.zero,
                                                    child: Text(
                                                      'Done',
                                                      style: TextStyle(
                                                        color: Colors.purple,
                                                      ),
                                                    ),
                                                    onPressed: () {
                                                      // setState(() {
                                                      //   _nextFollowUpDateController
                                                      //           .text =
                                                      //       "${selectedDate.day.toString().padLeft(2, '0')}/${selectedDate.month.toString().padLeft(2, '0')}/${selectedDate.year}";
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
                                                backgroundColor: Colors.white,
                                                mode: CupertinoDatePickerMode
                                                    .date,
                                                minimumDate: DateTime.now(),
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
                                                onDateTimeChanged: (DateTime value) {
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
                                  _nextFollowUpDateController.text.isNotEmpty
                                  ? formatDate(
                                          _nextFollowUpDateController.text,
                                        ).isBefore(DateTime.now())
                                        ? DateTime.now()
                                        : formatDate(
                                            _nextFollowUpDateController.text,
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
                        // validator: (value) {
                        //   if (value!.isEmpty) {
                        //     return "Please enter next followup date";
                        //   }
                        //   return null;
                        // },
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
                        onChanged: (value) {},
                      ),

                      SizedBox(height: 10),
                      Text("Street 1", style: labelStyle),
                      TextFormField(
                        controller: _street1Controller,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.text,
                        keyboardAppearance: Brightness.dark,
                        // Minimum height
                        minLines: 1,
                        // Expands indefinitely
                        maxLines: 4,
                        decoration: inputDecoration("Street 1"),
                        onFieldSubmitted: (value) {},
                        onChanged: (value) {
                          setDisplayAddress();
                        },
                      ),
                      SizedBox(height: 10),
                      Text("Street 2", style: labelStyle),
                      TextFormField(
                        controller: _street2Controller,
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
                      Container(
                        key: _countryKey,  // ADD THIS

                        child: Consumer<CountryListProvider>(
                          builder: (context, value, child) {
                            return Autocomplete<String>(
                              optionsBuilder: (textEditingValue) {
                                if (textEditingValue.text.isEmpty) {
                                  return value.countryList.map((e) => e.name);
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
                                final selectedObj = value.countryList.firstWhere(
                                  (e) => e.name == selected,
                                );
                                setState(() {
                                  _countryController.text = selectedObj.id
                                      .toString();
                                  _stateController.text = '';
                                  _districtController.text = '';
                                  _cityController.text = '';
                                  _pinCodeController.text = '';
                                });
                                value.setSelectedCountryId(selectedObj.id);
                                retailerOwnershipProvider
                                    .getRetailerOwnershipList(selectedObj.id);
                                districtListProvider.clearDistrictList();
                                cityListProvider.clearCityList();
                                pinCodeListProvider.clearPinCodeList();
                                setDisplayAddress();
                              },
                              fieldViewBuilder:
                                  (context, controller, focusNode, _) {
                                    return TextFormField(
                                      controller: controller,
                                      enabled: value.countryList.isNotEmpty,
                                      focusNode: focusNode,
                                      decoration: dropdownDecoration().copyWith(
                                        hintText: "Select Country",
                                        hintStyle: labelStyle,
                                        suffixIcon: suffixIcon(focusNode),
                                      ),
                                      style: textStyle,
                                      validator: (value){
                                        if (value!.isEmpty) {
                                          return "Please select country";
                                        }
                                        return null;
                                      },
                                    );
                                  },
                              optionsViewBuilder:
                                  (context, onSelected, options) =>
                                      buildOptionsView(options, onSelected),
                            );
                          },
                        ),
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
                              final selectedObj = value.stateList.firstWhere(
                                (e) => e.name == selected,
                              );
                              setState(() {
                                _stateController.text = selectedObj.id
                                    .toString();
                                _districtController.text = '';
                                _cityController.text = '';
                                _pinCodeController.text = '';
                              });
                              value.setSelectedStateId(selectedObj.id);
                              cityListProvider.clearCityList();
                              pinCodeListProvider.clearPinCodeList();
                              setDisplayAddress();
                            },
                            fieldViewBuilder:
                                (context, controller, focusNode, _) {
                                  return TextFormField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    enabled: value.stateList.isNotEmpty,
                                    decoration: dropdownDecoration().copyWith(
                                      hintText: "Select State",
                                      hintStyle: labelStyle,
                                      suffixIcon: suffixIcon(focusNode),
                                    ),
                                    style: textStyle,
                                    validator: (value){
                                      if (value!.isEmpty) {
                                        return "Please select state";
                                      }
                                      return null;
                                    },
                                  );
                                },
                            optionsViewBuilder:
                                (context, onSelected, options) =>
                                    buildOptionsView(options, onSelected),
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
                                return value.districtList.map((e) => e.name);
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
                              final selectedObj = value.districtList.firstWhere(
                                (e) => e.name == selected,
                              );
                              setState(() {
                                _districtController.text = selectedObj.id
                                    .toString();
                                _cityController.text = '';
                                _pinCodeController.text = '';
                              });
                              value.setSelectedDistrictId(selectedObj.id);
                              pinCodeListProvider.clearPinCodeList();
                              setDisplayAddress();
                            },
                            fieldViewBuilder:
                                (context, controller, focusNode, _) {
                                  return TextFormField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    enabled: value.districtList.isNotEmpty,
                                    decoration: dropdownDecoration().copyWith(
                                      hintText: "Select District",
                                      hintStyle: labelStyle,
                                      suffixIcon: suffixIcon(focusNode),
                                    ),
                                    style: textStyle,
                                    validator: (value){
                                      if (value!.isEmpty) {
                                        return "Please select district";
                                      }
                                      return null;
                                    },
                                  );
                                },
                            optionsViewBuilder:
                                (context, onSelected, options) =>
                                    buildOptionsView(options, onSelected),
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
                              final selectedObj = value.cityList.firstWhere(
                                (e) => e.name == selected,
                              );
                              setState(() {
                                _cityController.text = selectedObj.id
                                    .toString();
                                _pinCodeController.text = '';
                              });
                              value.setSelectedCityId(selectedObj.id);
                              setDisplayAddress();
                            },
                            fieldViewBuilder:
                                (context, controller, focusNode, _) {
                                  return TextFormField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    enabled: value.cityList.isNotEmpty,
                                    decoration: dropdownDecoration().copyWith(
                                      hintText: "Select City",
                                      hintStyle: labelStyle,
                                      suffixIcon: suffixIcon(focusNode),
                                    ),
                                    style: textStyle,
                                    validator: (value){
                                      if (value!.isEmpty) {
                                        return "Please select city";
                                      }
                                      return null;
                                    },
                                  );
                                },
                            optionsViewBuilder:
                                (context, onSelected, options) =>
                                    buildOptionsView(options, onSelected),
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
                                return value.pinCodeList.map((e) => e.pinCode);
                              }
                              return value.pinCodeList
                                  .where(
                                    (e) => e.pinCode.contains(
                                      textEditingValue.text,
                                    ),
                                  )
                                  .map((e) => e.pinCode);
                            },
                            onSelected: (selected) {
                              final selectedObj = value.pinCodeList.firstWhere(
                                (e) => e.pinCode == selected,
                              );
                              setState(() {
                                _pinCodeController.text = selectedObj.id
                                    .toString();
                              });
                              value.setSelectedPinCodeId(selectedObj.id);
                              setDisplayAddress();
                            },
                            fieldViewBuilder:
                                (context, controller, focusNode, _) {
                                  return TextField(
                                    controller: controller,
                                    focusNode: focusNode,
                                    enabled: value.pinCodeList.isNotEmpty,
                                    decoration: dropdownDecoration().copyWith(
                                      hintText: "Select Postal Code",
                                      hintStyle: labelStyle,
                                      suffixIcon: suffixIcon(focusNode),
                                    ),
                                    style: textStyle,
                                  );
                                },
                            optionsViewBuilder:
                                (context, onSelected, options) =>
                                    buildOptionsView(options, onSelected),
                          );
                        },
                      ),
                      SizedBox(height: 10),
                      Text("GPS Location", style: labelStyle),
                      InkWell(
                        onTap: () async {
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
                          print("GPS");
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
                            hintStyle: TextStyle(color: AppColors.paragraph),
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
                                  mainAxisAlignment: MainAxisAlignment.center,
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
                        keyboardType: TextInputType.text,
                        keyboardAppearance: Brightness.dark,
                        decoration: inputDecoration("Contact name"),
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
                      Text("Mobile Number", style: labelStyle),
                      TextFormField(
                        key: _mobileNumberKey,  // ADD THIS LINE

                        controller: _mobileNumberController,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.phone,
                        keyboardAppearance: Brightness.dark,
                        maxLength: 10,
                        decoration: inputDecoration("Mobile number").copyWith(
                          errorText: _mobileErrorText,
                          suffixIcon: _isCheckingMobile
                              ? Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                              : null,
                        ),
                        inputFormatters: [
                          FilteringTextInputFormatter.digitsOnly,
                          LengthLimitingTextInputFormatter(10),
                        ],
                        onFieldSubmitted: (value) {},
                        onChanged: (value) {
                          _mobileDebounce?.cancel();
                          _mobileDebounce = Timer(Duration(milliseconds: 800), () {
                            _checkMobileExists(value);
                          });
                        },
                        validator: (value) {
                          if (value!.isNotEmpty) {
                            if (value.length != 10) {
                              return "Please enter valid 10 digit mobile number";
                            }
                            if (_mobileErrorText != null) {
                              return _mobileErrorText;
                            }
                          }
                          return null;
                        },
                      ),
                      SizedBox(height: 10),
                      Text("Email ID", style: labelStyle),
                      TextFormField(
                        key: _emailIdKey,  // ADD THIS LINE

                        controller: _emailIdController,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.emailAddress,
                        keyboardAppearance: Brightness.dark,
                        decoration: inputDecoration("Email ID").copyWith(
                          errorText: _emailErrorText,
                          suffixIcon: _isCheckingEmail
                              ? Padding(
                            padding: const EdgeInsets.all(12.0),
                            child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            ),
                          )
                              : null,
                        ),
                        onFieldSubmitted: (value) {},
                        onChanged: (value) {
                          print('⌨️ Email onChanged: $value');
                          _emailDebounce?.cancel();
                          print('⏱️ Starting 800ms debounce timer...');
                          _emailDebounce = Timer(Duration(milliseconds: 800), () {
                            print('⏰ Debounce timer completed, calling _checkEmailExists');
                            _checkEmailExists(value);
                          });
                        },
                        validator: (value) {
                          print('✔️ Email validator called with value: $value');
                          if (value!.isNotEmpty) {
                            if (!RegExp(
                              r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
                            ).hasMatch(value)) {
                              print('❌ Email format invalid');
                              return 'Enter a valid email address';
                            }
                            if (_emailErrorText != null) {
                              print('❌ Email exists error: $_emailErrorText');
                              return _emailErrorText;
                            }
                          }
                          print('✅ Email validation passed');
                          return null;
                        },
                      ),
                      SizedBox(height: 10),
                      Text("Display Address", style: labelStyle),
                      TextFormField(
                        controller: _displayAddressController,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.text,
                        keyboardAppearance: Brightness.dark,
                        enabled: false,
                        // Minimum height
                        minLines: 1,
                        // Expands indefinitely
                        maxLines: 4,
                        decoration: inputDecoration("Display Address"),
                        onFieldSubmitted: (value) {},
                        onChanged: (value) {
                          // retailListProvider.filterRetailList(value);
                        },
                        // validator: (value) {
                        //   if (value!.isEmpty) {
                        //     return "Please enter display address";
                        //   }
                        //   return null;
                        // },
                      ),
                      SizedBox(height: 10),
                      Text("Opening Time", style: labelStyle),
                      Consumer<TimeProvider>(
                        builder: (context, value, child) {
                          return Autocomplete<String>(
                            optionsBuilder: (textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return value.openingTimeList.map((e) => e.time);
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
                                _openingTimeController.text = selectedObj.id
                                    .toString();
                              });
                            },
                            fieldViewBuilder:
                                (context, controller, focusNode, _) {
                                  return TextField(
                                    controller: controller,
                                    enabled: value.openingTimeList.isNotEmpty,
                                    focusNode: focusNode,
                                    decoration: dropdownDecoration().copyWith(
                                      hintText: "Opening Time",
                                      hintStyle: labelStyle,
                                      suffixIcon: suffixIcon(focusNode),
                                    ),
                                    style: textStyle,
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
                      // this is coment
                      Consumer<TimeProvider>(
                        builder: (context, value, child) {
                          return Autocomplete<String>(
                            optionsBuilder: (textEditingValue) {
                              if (textEditingValue.text.isEmpty) {
                                return value.closingTimeList.map((e) => e.time);
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
                                _closingTimeController.text = selectedObj.id
                                    .toString();
                              });
                            },
                            fieldViewBuilder:
                                (context, controller, focusNode, _) {
                                  return TextField(
                                    controller: controller,
                                    enabled: value.closingTimeList.isNotEmpty,
                                    focusNode: focusNode,
                                    decoration: dropdownDecoration().copyWith(
                                      hintText: "Closing Time",
                                      hintStyle: labelStyle,
                                      suffixIcon: suffixIcon(focusNode),
                                    ),
                                    style: textStyle,
                                  );
                                },
                            optionsViewBuilder:
                                (context, onSelected, options) =>
                                    buildOptionsView(options, onSelected),
                          );
                        },
                      ),
                      // InkWell(
                      //   onTap: () async {
                      //     await showCupertinoTimePicker(context, (
                      //       String selectedTime,
                      //     ) {
                      //       _openingTimeController.text =
                      //           selectedTime; // Format time and set in text field
                      //     });
                      //   },
                      //   child: TextFormField(
                      //     controller: _openingTimeController,
                      //     textInputAction: TextInputAction.next,
                      //     keyboardType: TextInputType.text,
                      //     keyboardAppearance: Brightness.dark,
                      //     enabled: false,
                      //     decoration: InputDecoration(
                      //       hintText: "Opening Time",
                      //       counterText: "",
                      //       hintStyle: TextStyle(color: AppColors.paragraph),
                      //       contentPadding: EdgeInsets.only(
                      //         left: 10,
                      //         right: 0,
                      //         top: 0,
                      //         bottom: 0,
                      //       ),
                      //       suffixIcon: Icon(Icons.access_time),
                      //       border: border,
                      //       disabledBorder: border,
                      //       enabledBorder: border,
                      //       focusedBorder: border,
                      //       errorBorder: errorBorder,
                      //     ),
                      //     onFieldSubmitted: (value) {},
                      //     onChanged: (value) {
                      //       // retailListProvider.filterRetailList(value);
                      //     },
                      //     // validator: (value) {
                      //     //   if (value!.isEmpty) {
                      //     //     return "Please enter opening time";
                      //     //   }
                      //     //   return null;
                      //     // },
                      //   ),
                      // ),
                      // SizedBox(height: 10),
                      // Text("Closing Time", style: labelStyle),
                      // InkWell(
                      //   onTap: () async {
                      //     await showCupertinoTimePicker(context, (
                      //       String selectedTime,
                      //     ) {
                      //       _closingTimeController.text =
                      //           selectedTime; // Format time and set in text field
                      //     });
                      //   },
                      //   child: TextFormField(
                      //     controller: _closingTimeController,
                      //     textInputAction: TextInputAction.next,
                      //     keyboardType: TextInputType.text,
                      //     keyboardAppearance: Brightness.dark,
                      //     enabled: false,
                      //     decoration: InputDecoration(
                      //       hintText: "Closing Time",
                      //       counterText: "",
                      //       hintStyle: TextStyle(color: AppColors.paragraph),
                      //       contentPadding: EdgeInsets.only(
                      //         left: 10,
                      //         right: 0,
                      //         top: 0,
                      //         bottom: 0,
                      //       ),
                      //       suffixIcon: Icon(Icons.access_time),
                      //       border: border,
                      //       disabledBorder: border,
                      //       enabledBorder: border,
                      //       focusedBorder: border,
                      //       errorBorder: errorBorder,
                      //     ),
                      //     onFieldSubmitted: (value) {},
                      //     onChanged: (value) {
                      //       // retailListProvider.filterRetailList(value);
                      //     },
                      //     // validator: (value) {
                      //     //   if (value!.isEmpty) {
                      //     //     return "Please enter closing time";
                      //     //   }
                      //     //   return null;
                      //     // },
                      //   ),
                      // ),
                      SizedBox(height: 10),
                      Text("Daily Avg Revenue", style: labelStyle),
                      TextFormField(
                        controller: _dailyAvgRevenueController,
                        textInputAction: TextInputAction.next,
                        keyboardType: TextInputType.number,
                        keyboardAppearance: Brightness.dark,
                        decoration: inputDecoration("Daily Avg Revenue"),
                        onFieldSubmitted: (value) {},
                        onChanged: (value) {
                          // retailListProvider.filterRetailList(value);
                        },
                        // validator: (value) {
                        //   if (value!.isEmpty) {
                        //     return "Please enter daily avg revenue";
                        //   }
                        //   return null;
                        // },
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
                            UtilityData.classOfRetailer.contains(
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
                        onChanged: (String? newValue) {
                          if (newValue != null) {
                            setState(() {
                              _classOfRetailerController.text = newValue;
                            });
                          }
                        },
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
                            // validator: (value) {
                            //   if (value == null) {
                            //     return "Please select state";
                            //   }
                            //   return null;
                            // },
                            dropdownColor: AppColors.white,
                            isExpanded: true,
                            hint: Text(
                              "Select Retailer Ownership",
                              style: labelStyle,
                            ),
                            value: _retailerOwnershipController.text.isNotEmpty
                                ? _retailerOwnershipController.text
                                : null,
                            items: value.retailerOwnershipList
                                .map<DropdownMenuItem<String>>((e) {
                                  return DropdownMenuItem<String>(
                                    value: e.id.toString(),
                                    child: Text(e.name),
                                  );
                                })
                                .toList(),
                            onChanged: (String? newValue) {
                              print(
                                "new value _retailerOwnershipController $newValue",
                              );
                              if (newValue != null) {
                                setState(() {
                                  _retailerOwnershipController.text = newValue;
                                });
                                value.setSelectedRetailerOwnershipId(
                                  int.parse(newValue),
                                );
                              }
                            },
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
                            hint: Text("High Street", style: labelStyle),
                            // value: _channelTypeController.text.isNotEmpty
                            //     ? _channelTypeController.text
                            //     : null,
                            value: "6",
                            items: null,
                            // items: value.channelTypeList
                            //     .map<DropdownMenuItem<String>>((e) {
                            //       return DropdownMenuItem<String>(
                            //         value: e.id.toString(),
                            //         child: Text(e.name),
                            //       );
                            //     })
                            //     .toList(),
                            onChanged: (String? newValue) {
                              print(
                                "new value _channelTypeController $newValue",
                              );
                              if (newValue != null) {
                                setState(() {
                                  _channelTypeController.text = newValue;
                                });
                                value.setSelectedChannelTypeId(
                                  int.parse(newValue),
                                );
                              }
                            },
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
                            validator: (value) {
                              if (_businessCategoryController.text.isEmpty) {
                                return 'Please select a business category';
                              }
                              return null;
                            },
                            builder: (formFieldState) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Autocomplete<String>(
                                    optionsBuilder: (textEditingValue) {
                                      if (textEditingValue.text.isEmpty) {
                                        return value.businessCategoryList.map(
                                          (e) => e.name,
                                        );
                                      }
                                      return value.businessCategoryList
                                          .where(
                                            (e) =>
                                                e.name.toLowerCase().contains(
                                                  textEditingValue.text
                                                      .toLowerCase(),
                                                ),
                                          )
                                          .map((e) => e.name);
                                    },
                                    onSelected: (selected) {
                                      final selectedObj = value
                                          .businessCategoryList
                                          .firstWhere(
                                            (e) => e.name == selected,
                                          );
                                      setState(() {
                                        _businessCategoryController.text =
                                            selectedObj.id.toString();
                                      });
                                      value.setSelectedBusinessCategoryId(
                                        selectedObj.id,
                                      );
                                      Provider.of<BusinessSubCategoryList>(
                                        context,
                                        listen: false,
                                      ).getBusinessSubCategoryList(
                                        selectedObj.id,
                                      );
                                      _businessSubCategoryController.text = '';
                                      formFieldState.didChange(
                                        selected,
                                      ); // mark as valid
                                    },
                                    fieldViewBuilder:
                                        (context, controller, focusNode, _) {
                                          return TextField(
                                            controller: controller,
                                            enabled: value
                                                .businessCategoryList
                                                .isNotEmpty,
                                            focusNode: focusNode,
                                            decoration: dropdownDecoration()
                                                .copyWith(
                                                  hintText:
                                                      "Select Business Category",
                                                  hintStyle: labelStyle,
                                                  suffixIcon: suffixIcon(
                                                    focusNode,
                                                  ),
                                                  errorText: formFieldState
                                                      .errorText, // validation error
                                                ),
                                            style: textStyle,
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
                              if (_businessSubCategoryController.text.isEmpty) {
                                return 'Please select a business sub category';
                              }
                              return null;
                            },
                            builder: (formFieldState) {
                              return Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Autocomplete<String>(
                                    optionsBuilder: (textEditingValue) {
                                      if (textEditingValue.text.isEmpty) {
                                        return value.businessSubCategoryList
                                            .map((e) => e.name);
                                      }
                                      return value.businessSubCategoryList
                                          .where(
                                            (e) =>
                                                e.name.toLowerCase().contains(
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
                                          );
                                      setState(() {
                                        _businessSubCategoryController.text =
                                            selectedObj.id.toString();
                                      });
                                      value.setSelectedBusinessSubCategoryId(
                                        selectedObj.id,
                                      );
                                      formFieldState.didChange(
                                        selected,
                                      ); // mark as valid
                                    },
                                    fieldViewBuilder:
                                        (context, controller, focusNode, _) {
                                          return TextFormField(
                                            controller: controller,
                                            enabled: value
                                                .businessSubCategoryList
                                                .isNotEmpty,
                                            focusNode: focusNode,
                                            decoration: dropdownDecoration().copyWith(
                                              hintText:
                                                  "Select Business Sub Category",
                                              hintStyle: labelStyle,
                                              suffixIcon: suffixIcon(focusNode),
                                              errorText: formFieldState
                                                  .errorText, // validation message
                                            ),
                                            style: textStyle,
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
                            ? AppColors.paragraph
                            : Colors.red,
                        borderType: BorderType.RRect,
                        radius: Radius.circular(10),
                        strokeWidth: 1,
                        child: SizedBox(
                          width: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Stack(
                              children: [
                                _storeLogo.isEmpty
                                    ? InkWell(
                                        onTap: () {
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
                                          print('Store Logo');
                                          _showBottomSheet(
                                            context,
                                            () async {
                                              String? filePath = await Helper()
                                                  .captureImage(context);
                                              setState(() {
                                                _storeLogo = filePath!;
                                              });
                                              print(filePath);
                                              try {
                                                base64logo =
                                                    await Helper.imageToBase64(
                                                      _storeLogo,
                                                    );
                                                setState(() {});
                                              } catch (e) {
                                                Get.snackbar(
                                                  "Error",
                                                  "store logo upload failed. Please reselect the images.",
                                                  backgroundColor: Colors.red,
                                                  colorText: Colors.white,
                                                  snackPosition:
                                                      SnackPosition.BOTTOM,
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
                                              String? filePath = await Helper()
                                                  .pickImage(context);
                                              setState(() {
                                                _storeLogo = filePath!;
                                              });
                                              print(filePath);
                                              try {
                                                base64logo =
                                                    await Helper.imageToBase64(
                                                      _storeLogo,
                                                    );
                                                setState(() {});
                                              } catch (e) {
                                                Get.snackbar(
                                                  "Error",
                                                  "store logo upload failed. Please reselect the images.",
                                                  backgroundColor: Colors.red,
                                                  colorText: Colors.white,
                                                  snackPosition:
                                                      SnackPosition.BOTTOM,
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
                                                opacity: AlwaysStoppedAnimation(
                                                  0.5,
                                                ),
                                              ),
                                              Text(
                                                'Upload Store Logo',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.black,
                                                ),
                                              ),
                                              Text(
                                                'Support: JPG, JPEG, PNG, HEIC',
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
                                        child: Column(
                                          children: [
                                            Image.file(
                                              File(_storeLogo),
                                              height: 100,
                                              width: 100,
                                              fit: BoxFit.contain,
                                            ),
                                            Text(
                                              "${_brandNameController.text.isEmpty ? "undefine" : _brandNameController.text}_${DateTime.now().microsecondsSinceEpoch}.${_storeLogo.split('.').last}",
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.black,
                                              ),
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
                                            setState(() {
                                              _storeLogo = '';
                                            });
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
                            ? AppColors.paragraph
                            : Colors.red,
                        borderType: BorderType.RRect,
                        radius: Radius.circular(10),
                        strokeWidth: 1,
                        child: SizedBox(
                          width: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Stack(
                              children: [
                                _storeImage1.isEmpty
                                    ? InkWell(
                                        onTap: () async {
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
                                          _showBottomSheet(
                                            context,
                                            () async {
                                              String? filePath = await Helper()
                                                  .captureImage(context);
                                              setState(() {
                                                _storeImage1 = filePath!;
                                              });
                                              print(filePath);

                                              try {
                                                base64image1 =
                                                    await Helper.imageToBase64(
                                                      _storeImage1,
                                                    );
                                                setState(() {});
                                              } catch (e) {
                                                Get.snackbar(
                                                  "Error",
                                                  "store image upload failed. Please reselect the images.",
                                                  backgroundColor: Colors.red,
                                                  colorText: Colors.white,
                                                  snackPosition:
                                                      SnackPosition.BOTTOM,
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
                                              String? filePath = await Helper()
                                                  .pickImage(context);
                                              setState(() {
                                                _storeImage1 = filePath!;
                                              });
                                              print(filePath);
                                              try {
                                                base64image1 =
                                                    await Helper.imageToBase64(
                                                      _storeImage1,
                                                    );
                                                setState(() {});
                                              } catch (e) {
                                                Get.snackbar(
                                                  "Error",
                                                  "store image upload failed. Please reselect the images.",
                                                  backgroundColor: Colors.red,
                                                  colorText: Colors.white,
                                                  snackPosition:
                                                      SnackPosition.BOTTOM,
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
                                                opacity: AlwaysStoppedAnimation(
                                                  0.5,
                                                ),
                                              ),
                                              Text(
                                                'Upload Store Image 1',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.black,
                                                ),
                                              ),
                                              Text(
                                                'Support: JPG, JPEG, PNG, HEIC',
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
                                        child: Column(
                                          children: [
                                            Image.file(
                                              File(_storeImage1),
                                              height: 100,
                                              width: 100,
                                              fit: BoxFit.contain,
                                            ),
                                            Text(
                                              "${_brandNameController.text.isEmpty ? "undefine" : _brandNameController.text}_${DateTime.now().microsecondsSinceEpoch}.${_storeImage1.split('.').last}",
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.black,
                                              ),
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
                                            setState(() {
                                              _storeImage1 = '';
                                            });
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
                            ? AppColors.paragraph
                            : Colors.red,
                        borderType: BorderType.RRect,
                        radius: Radius.circular(10),
                        strokeWidth: 1,
                        child: SizedBox(
                          width: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Stack(
                              children: [
                                _storeImage2.isEmpty
                                    ? InkWell(
                                        onTap: () async {
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
                                          _showBottomSheet(
                                            context,
                                            () async {
                                              String? filePath = await Helper()
                                                  .captureImage(context);
                                              setState(() {
                                                _storeImage2 = filePath!;
                                              });
                                              print(filePath);
                                              try {
                                                base64image2 =
                                                    await Helper.imageToBase64(
                                                      _storeImage2,
                                                    );
                                                setState(() {});
                                              } catch (e) {
                                                Get.snackbar(
                                                  "Error",
                                                  "store image upload failed. Please reselect the images.",
                                                  backgroundColor: Colors.red,
                                                  colorText: Colors.white,
                                                  snackPosition:
                                                      SnackPosition.BOTTOM,
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
                                              String? filePath = await Helper()
                                                  .pickImage(context);
                                              setState(() {
                                                _storeImage2 = filePath!;
                                              });
                                              print(filePath);

                                              try {
                                                base64image2 =
                                                    await Helper.imageToBase64(
                                                      _storeImage2,
                                                    );
                                                setState(() {});
                                              } catch (e) {
                                                Get.snackbar(
                                                  "Error",
                                                  "store image upload failed. Please reselect the images.",
                                                  backgroundColor: Colors.red,
                                                  colorText: Colors.white,
                                                  snackPosition:
                                                      SnackPosition.BOTTOM,
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
                                                opacity: AlwaysStoppedAnimation(
                                                  0.5,
                                                ),
                                              ),
                                              Text(
                                                'Upload Store Image 2',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.black,
                                                ),
                                              ),
                                              Text(
                                                'Support: JPG, JPEG, PNG, HEIC',
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
                                        child: Column(
                                          children: [
                                            Image.file(
                                              File(_storeImage2),
                                              height: 100,
                                              width: 100,
                                              fit: BoxFit.contain,
                                            ),
                                            Text(
                                              "${_brandNameController.text.isEmpty ? "undefine" : _brandNameController.text}_${DateTime.now().microsecondsSinceEpoch}.${_storeImage2.split('.').last}",
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.black,
                                              ),
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
                                            setState(() {
                                              _storeImage2 = '';
                                            });
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
                            ? AppColors.paragraph
                            : Colors.red,
                        borderType: BorderType.RRect,
                        radius: Radius.circular(10),
                        strokeWidth: 1,
                        child: SizedBox(
                          width: double.infinity,
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Stack(
                              children: [
                                _storeImage3.isEmpty
                                    ? InkWell(
                                        onTap: () async {
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
                                          _showBottomSheet(
                                            context,
                                            () async {
                                              String? filePath = await Helper()
                                                  .captureImage(context);
                                              setState(() {
                                                _storeImage3 = filePath!;
                                              });
                                              print(filePath);

                                              try {
                                                base64image3 =
                                                    await Helper.imageToBase64(
                                                      _storeImage3,
                                                    );
                                                setState(() {});
                                              } catch (e) {
                                                Get.snackbar(
                                                  "Error",
                                                  "store image upload failed. Please reselect the images.",
                                                  backgroundColor: Colors.red,
                                                  colorText: Colors.white,
                                                  snackPosition:
                                                      SnackPosition.BOTTOM,
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
                                              String? filePath = await Helper()
                                                  .pickImage(context);
                                              setState(() {
                                                _storeImage3 = filePath!;
                                              });
                                              print(filePath);

                                              try {
                                                base64image3 =
                                                    await Helper.imageToBase64(
                                                      _storeImage3,
                                                    );
                                                setState(() {});
                                              } catch (e) {
                                                Get.snackbar(
                                                  "Error",
                                                  "store image upload failed. Please reselect the images.",
                                                  backgroundColor: Colors.red,
                                                  colorText: Colors.white,
                                                  snackPosition:
                                                      SnackPosition.BOTTOM,
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
                                                opacity: AlwaysStoppedAnimation(
                                                  0.5,
                                                ),
                                              ),
                                              Text(
                                                'Upload Store Image 3',
                                                style: GoogleFonts.poppins(
                                                  fontSize: 14,
                                                  fontWeight: FontWeight.w500,
                                                  color: AppColors.black,
                                                ),
                                              ),
                                              Text(
                                                'Support: JPG, JPEG, PNG, HEIC',
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
                                        child: Column(
                                          children: [
                                            Image.file(
                                              File(_storeImage3),
                                              height: 100,
                                              width: 100,
                                              fit: BoxFit.contain,
                                            ),
                                            Text(
                                              "${_brandNameController.text.isEmpty ? "undefine" : _brandNameController.text}_${DateTime.now().microsecondsSinceEpoch}.${_storeImage3.split('.').last}",
                                              textAlign: TextAlign.center,
                                              style: GoogleFonts.poppins(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w500,
                                                color: AppColors.black,
                                              ),
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
                                            setState(() {
                                              _storeImage3 = '';
                                            });
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
                        onPressed: () {
                          print("========== NEXT BUTTON CLICKED =========="); // ADD THIS LINE

                          if (_formKey.currentState!.validate()) {
                            showDialog(
                              context: context,
                              useSafeArea: true,
                              builder: (context) {
                                return Dialog(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
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
                                        /// listing and continue button
                                        ElevatedButton(
                                          onPressed: () async {
                                            print(
                                              _nextFollowUpDateController.text,
                                            );
                                            CreateOutletProvider
                                            createOutletProvider =
                                                Provider.of<
                                                  CreateOutletProvider
                                                >(context, listen: false);
                                            Map<String, dynamic>
                                            body = OutletCreationBody.createFreeListing(
                                              website: _websiteController.text,
                                              brand_description:
                                                  _brandDescriptionController
                                                      .text,
                                              brand_type:
                                                  _brandTypeController.text,
                                              user_id: localDataProvider.userId,
                                              brand_name: _brandNameController
                                                  .text
                                                  .trim(),
                                              name: _retailerNameController.text
                                                  .trim(),
                                              street: _street1Controller.text
                                                  .trim(),
                                              street2: _street2Controller.text
                                                  .trim(),
                                              country_id: _countryController
                                                  .text
                                                  .trim(),
                                              state_id: _stateController.text
                                                  .trim(),
                                              district_id: _districtController
                                                  .text
                                                  .trim(),
                                              city_id: _cityController.text
                                                  .trim(),
                                              zip_code_id: _pinCodeController
                                                  .text
                                                  .trim(),
                                              latitude: _gpsLocationController
                                                  .text
                                                  .split(",")[0]
                                                  .trim(),
                                              longitude: _gpsLocationController
                                                  .text
                                                  .split(",")[1]
                                                  .trim(),
                                              contact_name:
                                                  _contactNameController.text
                                                      .trim(),
                                              mobile: _mobileNumberController
                                                  .text
                                                  .trim(),
                                              email: _emailIdController.text
                                                  .trim(),
                                              opening_time:
                                                  _openingTimeController.text
                                                      .trim(),
                                              closing_time:
                                                  _closingTimeController.text
                                                      .trim(),
                                              expected_revenue:
                                                  _dailyAvgRevenueController
                                                      .text
                                                      .trim(),
                                              class_of_retailer:
                                                  _classOfRetailerController
                                                      .text
                                                      .trim(),
                                              retailer_ownership_id:
                                                  _retailerOwnershipController
                                                      .text
                                                      .trim(),
                                              // channel_id: _channelTypeController
                                              //     .text
                                              //     .trim(),
                                              channel_id: "6",
                                              business_category_id:
                                                  _businessCategoryController
                                                      .text
                                                      .trim(),
                                              business_sub_category_id:
                                                  _businessSubCategoryController
                                                      .text
                                                      .trim(),
                                              logo: base64logo,
                                              image1: base64image1,
                                              image2: base64image2,
                                              image3: base64image3,
                                              type: "opportunity",
                                              stage_id: 1,
                                              active: true,
                                              pos_no: _posNumberController.text,
                                              pos_name: _posNameController.text,
                                              next_follow_up:
                                                  _nextFollowUpDateController
                                                      .text
                                                      .isEmpty
                                                  ? null
                                                  : output.format(
                                                      formatDate(
                                                        _nextFollowUpDateController
                                                            .text,
                                                      ),
                                                    ),
                                              // is_subscription_declined: false,
                                              description:
                                                  _descriptionController.text,
                                            );
                                            print(body);
                                            createOutletProvider
                                                .createOutletForFreeListing(
                                                  body,
                                                );
                                            GetxNavigation().goBack();
                                          },
                                          style: ElevatedButton.styleFrom(
                                            foregroundColor: Colors.white,
                                            backgroundColor: AppColors.white,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                              side: BorderSide(
                                                color: AppColors
                                                    .homePageCardDarkTextColor,
                                                width: 1,
                                              ),
                                            ),
                                            minimumSize: Size(
                                              double.infinity,
                                              45,
                                            ),
                                          ),
                                          child: Text(
                                            "Listing & Continue",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: AppColors
                                                  .homePageCardDarkTextColor,
                                            ),
                                          ),
                                        ),
                                        SizedBox(height: 10),

                                        /// decline listing button
                                        ElevatedButton(
                                          onPressed: () {
                                            print(
                                              _retailerOwnershipController.text,
                                            );
                                            CreateOutletProvider
                                            createOutletProvider =
                                                Provider.of<
                                                  CreateOutletProvider
                                                >(context, listen: false);
                                            Map<String, dynamic>
                                            body = OutletCreationBody.createDecline(
                                              user_id: localDataProvider.userId,
                                              brand_description:
                                                  _brandDescriptionController
                                                      .text,
                                              brand_type:
                                                  _brandTypeController.text,
                                              brand_name: _brandNameController
                                                  .text
                                                  .trim(),
                                              name: _retailerNameController.text
                                                  .trim(),
                                              street: _street1Controller.text
                                                  .trim(),
                                              street2: _street2Controller.text
                                                  .trim(),
                                              country_id: _countryController
                                                  .text
                                                  .trim(),
                                              state_id: _stateController.text
                                                  .trim(),
                                              district_id: _districtController
                                                  .text
                                                  .trim(),
                                              city_id: _cityController.text
                                                  .trim(),
                                              zip_code_id: _pinCodeController
                                                  .text
                                                  .trim(),
                                              latitude: _gpsLocationController
                                                  .text
                                                  .split(",")[0]
                                                  .trim(),
                                              longitude: _gpsLocationController
                                                  .text
                                                  .split(",")[1]
                                                  .trim(),
                                              contact_name:
                                                  _contactNameController.text
                                                      .trim(),
                                              mobile: _mobileNumberController
                                                  .text
                                                  .trim(),
                                              email: _emailIdController.text
                                                  .trim(),
                                              opening_time:
                                                  _openingTimeController.text
                                                      .trim(),
                                              closing_time:
                                                  _closingTimeController.text
                                                      .trim(),
                                              expected_revenue:
                                                  _dailyAvgRevenueController
                                                      .text
                                                      .trim(),
                                              class_of_retailer:
                                                  _classOfRetailerController
                                                      .text
                                                      .trim(),
                                              retailer_ownership_id:
                                                  _retailerOwnershipController
                                                      .text
                                                      .trim(),
                                              channel_id: _channelTypeController
                                                  .text
                                                  .trim(),
                                              business_category_id:
                                                  _businessCategoryController
                                                      .text
                                                      .trim(),
                                              business_sub_category_id:
                                                  _businessSubCategoryController
                                                      .text
                                                      .trim(),
                                              logo: base64logo,
                                              image1: base64image1,
                                              image2: base64image2,
                                              image3: base64image3,
                                              type: "lead",
                                              // stage_id: 1,
                                              // active: true,
                                              // is_subscription_declined: false,
                                              website: _websiteController.text,
                                              pos_no: _posNumberController.text,
                                              pos_name: _posNameController.text,
                                              next_follow_up:
                                              _nextFollowUpDateController
                                                  .text
                                                  .isEmpty
                                                  ? null
                                                  : output.format(
                                                formatDate(
                                                  _nextFollowUpDateController
                                                      .text,
                                                ),
                                              ),
                                              description:
                                                  _descriptionController.text,
                                            );
                                            print(body);
                                            createOutletProvider
                                                .createOutletForDecline(body);
                                            GetxNavigation().goBack();
                                          },
                                          style: ElevatedButton.styleFrom(
                                            foregroundColor: AppColors
                                                .declineSubscriptionListingTextColor,
                                            backgroundColor: AppColors
                                                .declineSubscriptionListingTextColor,
                                            shape: RoundedRectangleBorder(
                                              borderRadius:
                                                  BorderRadius.circular(8),
                                            ),
                                            minimumSize: Size(
                                              double.infinity,
                                              45,
                                            ),
                                          ),
                                          child: Text(
                                            "Decline Listing",
                                            style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.bold,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                );
                              },
                            );
                          } else {
                            print("========== FORM VALIDATION FAILED - SCROLLING TO ERROR ==========");
                            _scrollToFirstError();  // ADD THIS LINE
                          }
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
                          "Next",
                          style: Theme.of(context).textTheme.titleMedium!
                              .copyWith(
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                        ),
                      ),
                      SizedBox(height: 20),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
        createOutletProvider.isLoading ? LoadingWidget() : Container(),
      ],
    );
  }

  void _scrollToFirstError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      // Create a map of field keys with their controllers/error states
      final fieldsToCheck = [
        {'key': _retailerNameKey, 'hasError': () => _retailerNameController.text.isEmpty},
        {'key': _brandNameKey, 'hasError': () => _brandNameController.text.isEmpty},
        {'key': _countryKey, 'hasError': () => _countryController.text.isEmpty},
        {'key': _stateKey, 'hasError': () => _stateController.text.isEmpty},
        {'key': _districtKey, 'hasError': () => _districtController.text.isEmpty},
        {'key': _cityKey, 'hasError': () => _cityController.text.isEmpty},
        {'key': _gpsLocationKey, 'hasError': () => _gpsLocationController.text.isEmpty},
        {'key': _mobileNumberKey, 'hasError': () => _mobileErrorText != null},
        {'key': _emailIdKey, 'hasError': () => _emailErrorText != null || (_emailIdController.text.isNotEmpty && !RegExp(r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$').hasMatch(_emailIdController.text))},
        {'key': _retailerOwnershipKey, 'hasError': () => _retailerOwnershipController.text.isEmpty},
        {'key': _businessCategoryKey, 'hasError': () => _businessCategoryController.text.isEmpty},
        {'key': _businessSubCategoryKey, 'hasError': () => _businessSubCategoryController.text.isEmpty},
      ];

      // Find first field with error
      for (final field in fieldsToCheck) {
        final hasError = (field['hasError'] as Function)();

        if (hasError) {
          final key = field['key'] as GlobalKey;
          final context = key.currentContext;

          if (context != null) {
            // Scroll to the field
            Scrollable.ensureVisible(
              context,
              duration: Duration(milliseconds: 500),
              curve: Curves.easeInOut,
              alignment: 0.2, // Position the field 20% from top of screen
            );

            print("========== SCROLLING TO FIELD WITH ERROR ==========");
            break;
          }
        }
      }
    });
  }}
