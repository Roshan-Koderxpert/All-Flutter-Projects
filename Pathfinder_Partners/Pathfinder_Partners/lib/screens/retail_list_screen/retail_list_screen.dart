import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:retail_gpt/Icons/SVG/svg_icons.dart';
import 'package:retail_gpt/navigation/getx_navigation.dart';
import 'package:retail_gpt/providers/utility_provider/city_list_provider.dart';
import 'package:retail_gpt/providers/utility_provider/district_list_provider.dart';
import 'package:retail_gpt/providers/utility_provider/pin_code_list_provider.dart';
import 'package:retail_gpt/providers/utility_provider/state_list_provider.dart';
import 'package:retail_gpt/screens/outlet_screens/create_new_outlet_screen.dart';
import 'package:retail_gpt/screens/outlet_screens/outlet_description_screen.dart';
import 'package:retail_gpt/providers/retail_list_screen/retail_list_screen_provider.dart';
import 'package:retail_gpt/utils/app_colors.dart';
import 'package:retail_gpt/widgets/background_widget.dart';
import 'package:shimmer/shimmer.dart';

import '../../providers/utility_provider/country_list_provider.dart';
import '../../utils/clear_provider.dart';

class RetailListScreen extends StatefulWidget {
  static const routeName = "/retail-list-screen";

  const RetailListScreen({super.key});

  @override
  State<RetailListScreen> createState() => _RetailListScreenState();
}

class _RetailListScreenState extends State<RetailListScreen> {
  final _formKey = GlobalKey<FormState>();
  final _searchController = TextEditingController();
  final _pinCodeController = TextEditingController();
  final _searchFocusNode = FocusNode();
  final _pinCodeFocusNode = FocusNode();
  bool isSelect = false;

  @override
  void initState() {
    // TODO: implement initState
    Future.microtask(() {
      RetailListScreenProvider retailScreenProvider =
          Provider.of<RetailListScreenProvider>(context, listen: false);
      retailScreenProvider.getRetailList();
    });
    super.initState();
  }

  String getLeadStatus(String status) {
    switch (status) {
      case "free_listing":
        {
          return "Free Listing";
        }
      case "subscribed":
        {
          return "Subscribed";
        }
      case "decline":
        {
          return "Decline";
        }
      case "decline_listing":
        {
          return "Decline Listing";
        }
      case "decline_subscription":
        {
          return "Decline Subscription";
        }
      default:
        {
          return "Undefined";
        }
    }
  }

  Color getLeadStatusColor(String status) {
    switch (status) {
      case "free_listing":
        {
          return AppColors.freeListingTextColor;
        }
      case "subscribed":
        {
          return AppColors.subscriptionListingTextColor;
        }
      case "decline":
        {
          return AppColors.declineFreeListingTextColor;
        }
      case "decline_listing":
        {
          return AppColors.declineFreeListingTextColor;
        }
      case "decline_subscription":
        {
          return AppColors.declineSubscriptionListingTextColor;
        }
      default:
        {
          return AppColors.primaryColor;
        }
    }
  }

  Color getLeadStatusBackgroundColor(String status) {
    // if (stageId == -1 && type == "opportunity") {
    //   return Color(0xFFFFEEF0); //decline subscription
    // }
    switch (status) {
      case "free_listing":
        {
          return AppColors.freeListingFillColor;
        }
      case "subscribed":
        {
          return AppColors.subscriptionListingFillColor;
        }
      case "decline":
        {
          return AppColors.declineFreeListingFillColor;
        }
      case "decline_listing":
        {
          return AppColors.declineFreeListingFillColor;
        }
      case "decline_subscription":
        {
          return AppColors.declineSubscriptionListingFillColor;
        }
      default:
        {
          return AppColors.primaryColor;
        }
    }
    return Color(0xFFFFEEF0); // decline
  }

  @override
  void dispose() {
    // TODO: implement dispose
    _searchController.dispose();
    _pinCodeController.dispose();
    _searchFocusNode.dispose();
    _pinCodeFocusNode.dispose();
    super.dispose();
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
    fillColor: AppColors.white,
    filled: true,
    border: border,
    enabledBorder: border,
    focusedBorder: border,
    errorBorder: border,
    disabledBorder: border,
    focusedErrorBorder: border,
  );

  void bottomSheet() {
    showModalBottomSheet(
      context: context,
      enableDrag: true,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.only(
          topLeft: Radius.circular(10),
          topRight: Radius.circular(10),
        ),
      ),
      backgroundColor: AppColors.white,
      constraints: BoxConstraints(
        maxHeight: MediaQuery.of(context).size.height * 0.85,
      ),
      isDismissible: false,
      useSafeArea: true,
      builder: (context) {
        final retailListProvider = context.watch<RetailListScreenProvider>();
        _pinCodeController.text = retailListProvider.pinCode;
        return SingleChildScrollView(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom, // adjust for keyboard
          ),
          child: Container(
            decoration: BoxDecoration(
              color: AppColors.white,
              borderRadius: BorderRadius.only(
                topLeft: Radius.circular(10),
                topRight: Radius.circular(10),
              ),
            ),
            child: InkWell(
              onTap: () {
                if (_pinCodeFocusNode.hasFocus) {
                  _pinCodeFocusNode.unfocus();
                }
              },
              splashColor: Colors.transparent,
              highlightColor: Colors.transparent,
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  mainAxisAlignment: MainAxisAlignment.start,
                  children: [
                    InkWell(
                      onTap: () {
                        if (retailListProvider.isFiltering) {
                          retailListProvider.clearFilter();
                          _pinCodeController.clear();
                        } else {
                          Navigator.pop(context);
                        }
                      },
                      child: Text(
                        retailListProvider.isFiltering ? "Clear Filter" : "Close",
                        style: GoogleFonts.poppins(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primaryColor,
                        ),
                        textAlign: TextAlign.end,
                      ),
                    ),
                    Column(
                      spacing: 2,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Country",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.paragraph,
                          ),
                        ),
                        Consumer<CountryListProvider>(
                          builder: (context, value, child) {
                            return Autocomplete<String>(
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                // Show full list if no text is entered
                                if (textEditingValue.text.isEmpty) {
                                  return value.countryList.map((e) => e.name);
                                }
                                // Filter list based on input
                                return value.countryList
                                    .where(
                                      (e) => e.name.toLowerCase().contains(
                                        textEditingValue.text.toLowerCase(),
                                      ),
                                    )
                                    .map((e) => e.name);
                              },
                              onSelected: (String selectedCountry) {
                                final selectedCountryObj = value.countryList
                                    .firstWhere((e) => e.name == selectedCountry);

                                context
                                    .read<RetailListScreenProvider>()
                                    .setSelectedCountry(selectedCountry);
                                value.setSelectedCountryId(selectedCountryObj.id);

                                StateListProvider stateListProvider =
                                    Provider.of<StateListProvider>(
                                      context,
                                      listen: false,
                                    );
                                stateListProvider.getStateList(
                                  selectedCountryObj.id,
                                );
                              },
                              fieldViewBuilder: (
                                context,
                                textEditingController,
                                focusNode,
                                onFieldSubmitted,
                              ) {
                                return TextField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  decoration: dropdownDecoration().copyWith(
                                    hintText: "Select Country",
                                    hintStyle: labelStyle,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        Icons.keyboard_arrow_down,
                                      ), // Dropdown Icon
                                      onPressed: () {
                                        // Show suggestions when clicking the icon

                                        if (focusNode.hasFocus) {
                                          focusNode.unfocus();
                                        } else {
                                          focusNode.requestFocus();
                                        }
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                  style: textStyle,
                                );
                              },
                              optionsViewBuilder: (context, onSelected, options) {
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
                                              padding: EdgeInsets.symmetric(
                                                vertical: 5,
                                                horizontal: 8,
                                              ),
                                              child: Text(
                                                option,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w400,
                                                  color:
                                                      AppColors
                                                          .homePageCardTextColor,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Column(
                      spacing: 2,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          "Emirate/Province/State",
                          style: GoogleFonts.poppins(
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: AppColors.paragraph,
                          ),
                        ),
                        Consumer<StateListProvider>(
                          builder: (context, value, child) {
                            return Autocomplete<String>(
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                // Show full list if no text is entered
                                if (textEditingValue.text.isEmpty) {
                                  return value.stateList.map((e) => e.name);
                                }
                                // Filter list based on input
                                return value.stateList
                                    .where(
                                      (e) => e.name.toLowerCase().contains(
                                        textEditingValue.text.toLowerCase(),
                                      ),
                                    )
                                    .map((e) => e.name);
                              },
                              onSelected: (String selectedState) {
                                final selectedStateObj = value.stateList.firstWhere(
                                  (e) => e.name == selectedState,
                                );

                                context
                                    .read<RetailListScreenProvider>()
                                    .setSelectedState(selectedState);
                                value.getSelectedState(selectedStateObj.id);

                                DistrictListProvider districtListProvider =
                                    Provider.of<DistrictListProvider>(
                                      context,
                                      listen: false,
                                    );
                                districtListProvider.getDistrictList(
                                  selectedStateObj.id,
                                );
                              },
                              fieldViewBuilder: (
                                context,
                                textEditingController,
                                focusNode,
                                onFieldSubmitted,
                              ) {
                                return TextField(
                                  controller: textEditingController,
                                  enabled: value.stateList.isNotEmpty,
                                  focusNode: focusNode,
                                  decoration: dropdownDecoration().copyWith(
                                    hintText: "Select State",
                                    hintStyle: labelStyle,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        Icons.keyboard_arrow_down,
                                        color:
                                            value.stateList.isEmpty
                                                ? Colors.grey
                                                : AppColors.black,
                                      ), // Dropdown Icon
                                      onPressed: () {
                                        // Show suggestions when clicking the icon

                                        if (focusNode.hasFocus) {
                                          focusNode.unfocus();
                                        } else {
                                          focusNode.requestFocus();
                                        }
                                        setState(() {});
                                      },
                                    ),
                                  ),
                                  style: textStyle,
                                );
                              },
                              optionsViewBuilder: (context, onSelected, options) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 4.0,
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.white,
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
                                              padding: EdgeInsets.symmetric(
                                                vertical: 5,
                                                horizontal: 8,
                                              ),
                                              child: Text(
                                                option,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w400,
                                                  color:
                                                  AppColors
                                                      .homePageCardTextColor,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Column(
                      spacing: 2,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("District/Zone", style: labelStyle),
                        Consumer<DistrictListProvider>(
                          builder: (context, value, child) {
                            return Autocomplete<String>(
                              optionsBuilder: (TextEditingValue textEditingValue) {
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
                              onSelected: (String selectedDistrict) {
                                final selectedDistrictObj = value.districtList
                                    .firstWhere((e) => e.name == selectedDistrict);
                                context
                                    .read<RetailListScreenProvider>()
                                    .setDistrict(selectedDistrict);
                                value.setSelectedDistrictId(selectedDistrictObj.id);

                                // Fetch City List for selected District
                                Provider.of<CityListProvider>(
                                  context,
                                  listen: false,
                                ).getCityList(selectedDistrictObj.id);
                              },
                              fieldViewBuilder: (
                                context,
                                textEditingController,
                                focusNode,
                                onFieldSubmitted,
                              ) {
                                return TextField(
                                  controller: textEditingController,
                                  enabled: value.districtList.isNotEmpty,
                                  focusNode: focusNode,
                                  decoration: dropdownDecoration().copyWith(
                                    hintText: "Select District",
                                    hintStyle: labelStyle,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        Icons.keyboard_arrow_down,
                                        color:
                                            value.districtList.isEmpty
                                                ? Colors.grey
                                                : AppColors.black,
                                      ),
                                      onPressed: () {
                                        focusNode.requestFocus();
                                      },
                                    ),
                                  ),
                                  style: textStyle,
                                );
                              },
                              optionsViewBuilder: (context, onSelected, options) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 4.0,
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.white,
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
                                              padding: EdgeInsets.symmetric(
                                                vertical: 5,
                                                horizontal: 8,
                                              ),
                                              child: Text(
                                                option,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w400,
                                                  color:
                                                  AppColors
                                                      .homePageCardTextColor,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Column(
                      spacing: 2,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("City/Town/Cluster", style: labelStyle),
                        Consumer<CityListProvider>(
                          builder: (context, value, child) {
                            return Autocomplete<String>(
                              optionsBuilder: (TextEditingValue textEditingValue) {
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
                              onSelected: (String selectedCity) {
                                final selectedCityObj = value.cityList.firstWhere(
                                  (e) => e.name == selectedCity,
                                );
                                context
                                    .read<RetailListScreenProvider>()
                                    .setSelectedCity(selectedCity);
                                value.setSelectedCityId(selectedCityObj.id);

                                // Fetch Pin Codes for selected City
                                Provider.of<PinCodeListProvider>(
                                  context,
                                  listen: false,
                                ).getPinCode(selectedCityObj.id);
                              },
                              fieldViewBuilder: (
                                context,
                                textEditingController,
                                focusNode,
                                onFieldSubmitted,
                              ) {
                                return TextField(
                                  controller: textEditingController,
                                  focusNode: focusNode,
                                  enabled: value.cityList.isNotEmpty,
                                  decoration: dropdownDecoration().copyWith(
                                    hintText: "Select City",
                                    hintStyle: labelStyle,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        Icons.keyboard_arrow_down,
                                        color:
                                            value.cityList.isEmpty
                                                ? Colors.grey
                                                : AppColors.black,
                                      ),
                                      onPressed: () {
                                        focusNode.requestFocus();
                                      },
                                    ),
                                  ),
                                  style: textStyle,
                                );
                              },
                              optionsViewBuilder: (context, onSelected, options) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 4.0,
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.white,
                                    child: SizedBox(
                                      width: MediaQuery.of(context).size.width-40,
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
                                              padding: EdgeInsets.symmetric(
                                                vertical: 5,
                                                horizontal: 8,
                                              ),
                                              child: Text(
                                                option,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w400,
                                                  color:
                                                  AppColors
                                                      .homePageCardTextColor,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    Column(
                      spacing: 2,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text("Pin Code/Postal Code", style: labelStyle),
                        Consumer<PinCodeListProvider>(
                          builder: (context, value, child) {
                            return Autocomplete<String>(
                              optionsBuilder: (TextEditingValue textEditingValue) {
                                if (textEditingValue.text.isEmpty) {
                                  return value.pinCodeList.map((e) => e.pinCode);
                                }
                                return value.pinCodeList
                                    .where(
                                      (e) => e.pinCode.toLowerCase().contains(
                                        textEditingValue.text.toLowerCase(),
                                      ),
                                    )
                                    .map((e) => e.pinCode);
                              },
                              onSelected: (String selectedPinCode) {
                                final selectedPinCodeObj = value.pinCodeList
                                    .firstWhere(
                                      (e) => e.pinCode == selectedPinCode,
                                    );
                                context.read<RetailListScreenProvider>().setPinCode(
                                  selectedPinCode,
                                );
                                value.setSelectedPinCodeId(selectedPinCodeObj.id);
                              },
                              fieldViewBuilder: (
                                context,
                                textEditingController,
                                focusNode,
                                onFieldSubmitted,
                              ) {
                                return TextField(
                                  controller: textEditingController,
                                  enabled: value.pinCodeList.isNotEmpty,
                                  focusNode: focusNode,
                                  decoration: dropdownDecoration().copyWith(
                                    hintText: "Select Postal Code",
                                    hintStyle: labelStyle,
                                    suffixIcon: IconButton(
                                      icon: Icon(
                                        Icons.keyboard_arrow_down,
                                        color:
                                            value.pinCodeList.isEmpty
                                                ? Colors.grey
                                                : AppColors.black,
                                      ),
                                      onPressed: () {
                                        focusNode.requestFocus();
                                      },
                                    ),
                                  ),
                                  style: textStyle,
                                );
                              },
                              optionsViewBuilder: (context, onSelected, options) {
                                return Align(
                                  alignment: Alignment.topLeft,
                                  child: Material(
                                    elevation: 4.0,
                                    borderRadius: BorderRadius.circular(10),
                                    color: Colors.white,
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
                                              padding: EdgeInsets.symmetric(
                                                vertical: 5,
                                                horizontal: 8,
                                              ),
                                              child: Text(
                                                option,
                                                style: GoogleFonts.poppins(
                                                  fontSize: 16,
                                                  fontWeight: FontWeight.w400,
                                                  color:
                                                  AppColors
                                                      .homePageCardTextColor,
                                                ),
                                              ),
                                            ),
                                          );
                                        },
                                      ),
                                    ),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ],
                    ),
                    SizedBox(height: 10),
                    // Row(
                    //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //   children: [
                    //
                    //   ],
                    // ),
                    // Row(
                    //   mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    //   children: [
                    //
                    //   ],
                    // ),
                    Wrap(
                      // spacing: 5,
                      // alignment: WrapAlignment.start,
                      direction: Axis.horizontal,
                      children: [
                        SizedBox(
                          width: MediaQuery.of(context).size.width / 3 - 15,
                          child: InkWell(
                            onTap: () {
                              retailListProvider.setSubscribeSelectedFilterOption(
                                1,
                              );
                            },
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color:
                                  retailListProvider
                                      .subscribeSelectedFilterOption ==
                                      1
                                      ? AppColors.primaryColor
                                      : AppColors.grey,
                                  width: 1,
                                ),
                              ),
                              color: AppColors.white,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Center(
                                  child: Text(
                                    "All",
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium!.copyWith(
                                      fontWeight: FontWeight.w400,
                                      color:
                                      retailListProvider
                                          .subscribeSelectedFilterOption ==
                                          1
                                          ? AppColors.primaryColor
                                          : Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: MediaQuery.of(context).size.width / 3 - 15,
                          child: InkWell(
                            onTap: () {
                              retailListProvider.setSubscribeSelectedFilterOption(
                                2,
                              );
                            },
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color:
                                  retailListProvider
                                      .subscribeSelectedFilterOption ==
                                      2
                                      ? AppColors.primaryColor
                                      : AppColors.grey,
                                  width: 1,
                                ),
                              ),
                              color: AppColors.white,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Center(
                                  child: Text(
                                    "Free Listing",
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium!.copyWith(
                                      fontWeight: FontWeight.w400,
                                      color:
                                      retailListProvider
                                          .subscribeSelectedFilterOption ==
                                          1
                                          ? AppColors.primaryColor
                                          : Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: MediaQuery.of(context).size.width / 3 - 15,
                          child: InkWell(
                            onTap: () {
                              retailListProvider.setSubscribeSelectedFilterOption(
                                3,
                              );
                            },
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color:
                                  retailListProvider
                                      .subscribeSelectedFilterOption ==
                                      3
                                      ? AppColors.primaryColor
                                      : AppColors.grey,
                                  width: 1,
                                ),
                              ),
                              color: AppColors.white,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Center(
                                  child: Text(
                                    "Subscribe",
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium!.copyWith(
                                      fontWeight: FontWeight.w400,
                                      color:
                                      retailListProvider
                                          .subscribeSelectedFilterOption ==
                                          2
                                          ? AppColors.primaryColor
                                          : Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: MediaQuery.of(context).size.width / 2 - 20,
                          child: InkWell(
                            onTap: () {
                              retailListProvider.setSubscribeSelectedFilterOption(
                                4,
                              );
                            },
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color:
                                  retailListProvider
                                      .subscribeSelectedFilterOption ==
                                      4
                                      ? AppColors.primaryColor
                                      : AppColors.grey,
                                  width: 1,
                                ),
                              ),
                              color: AppColors.white,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Center(
                                  child: Text(
                                    "Decline",
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium!.copyWith(
                                      fontWeight: FontWeight.w400,
                                      color:
                                      retailListProvider
                                          .subscribeSelectedFilterOption ==
                                          4
                                          ? AppColors.primaryColor
                                          : Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          width: MediaQuery.of(context).size.width / 2 - 20,
                          child: InkWell(
                            onTap: () {
                              retailListProvider.setSubscribeSelectedFilterOption(
                                5,
                              );
                            },
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color:
                                  retailListProvider
                                      .subscribeSelectedFilterOption ==
                                      5
                                      ? AppColors.primaryColor
                                      : AppColors.grey,
                                  width: 1,
                                ),
                              ),
                              color: AppColors.white,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Center(
                                  child: Text(
                                    "Decline Listing",
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium!.copyWith(
                                      fontWeight: FontWeight.w400,
                                      color:
                                      retailListProvider
                                          .subscribeSelectedFilterOption ==
                                          5
                                          ? AppColors.primaryColor
                                          : Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                        SizedBox(
                          // width: MediaQuery.of(context).size.width / 3 - 15,
                          child: InkWell(
                            onTap: () {
                              retailListProvider.setSubscribeSelectedFilterOption(
                                6,
                              );
                            },
                            splashColor: Colors.transparent,
                            highlightColor: Colors.transparent,
                            child: Card(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(10),
                                side: BorderSide(
                                  color:
                                  retailListProvider
                                      .subscribeSelectedFilterOption ==
                                      6
                                      ? AppColors.primaryColor
                                      : AppColors.grey,
                                  width: 1,
                                ),
                              ),
                              color: AppColors.white,
                              child: Padding(
                                padding: const EdgeInsets.all(8.0),
                                child: Center(
                                  child: Text(
                                    "Decline Subscription",
                                    style: Theme.of(
                                      context,
                                    ).textTheme.titleMedium!.copyWith(
                                      fontWeight: FontWeight.w400,
                                      color:
                                      retailListProvider
                                          .subscribeSelectedFilterOption ==
                                          6
                                          ? AppColors.primaryColor
                                          : Colors.black,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                    SizedBox(height: 30),
                    ElevatedButton(
                      onPressed: () {
                        /// 27-03-25
                        retailListProvider.applyFilter(
                          _pinCodeController.text,
                          _searchController.text,
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        foregroundColor: Colors.white,
                        backgroundColor: AppColors.primaryColor,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                        minimumSize: Size(double.infinity, 45),
                      ),
                      child: Text(
                        "Apply Filters",
                        style: Theme.of(context).textTheme.titleMedium!.copyWith(
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final retailListProvider = context.watch<RetailListScreenProvider>();
    return BackgroundWidget(
      headerWidget: InkWell(
        onTap: () {
          if (_searchFocusNode.hasFocus) {
            _searchFocusNode.unfocus();
          }
        },
        child: Container(
          padding: const EdgeInsets.only(left: 16),
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
                  child: Icon(Icons.arrow_back, color: Colors.black, size: 20),
                ),
              ),
              Spacer(),
              Text(
                'Retail List',
                style: GoogleFonts.poppins(
                  fontSize: 24,
                  fontWeight: FontWeight.w600,
                  color: AppColors.white,
                ),
              ),
              Spacer(),
              Spacer(),
            ],
          ),
        ),
      ),
      bottomSheetWidget: Padding(
        padding: EdgeInsets.only(top: 20.0),
        child: SizedBox(
          height: double.infinity,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                height: 60,
                child:
                    retailListProvider.isLoading
                        ? Shimmer.fromColors(
                          baseColor: Colors.grey.shade300,
                          highlightColor: Colors.grey.shade100,
                          child: Row(
                            children: [
                              Expanded(
                                child: Container(
                                  height: 50,
                                  decoration: BoxDecoration(
                                    color: AppColors.grey,
                                    borderRadius: BorderRadius.circular(10),
                                  ),
                                ),
                              ),
                              Container(
                                margin: const EdgeInsets.only(left: 10),
                                height: 50,
                                width: 70,
                                decoration: BoxDecoration(
                                  color: AppColors.grey,
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                            ],
                          ),
                        )
                        : Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: TextFormField(
                                focusNode: _searchFocusNode,
                                controller: _searchController,
                                textInputAction: TextInputAction.done,
                                keyboardAppearance: Brightness.dark,
                                textAlign: TextAlign.start,
                                textAlignVertical: TextAlignVertical.bottom,
                                decoration: InputDecoration(
                                  fillColor: AppColors.white,
                                  filled: true,
                                  hintText: "Search",
                                  hintStyle: GoogleFonts.poppins(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w400,
                                    color: AppColors.textFieldHintTextColor,
                                  ),
                                  helperText:
                                      "Search by name, phone, email and address",
                                  prefixIcon: Icon(
                                    Icons.search,
                                    color: AppColors.textFieldHintTextColor,
                                  ),
                                  border: border,
                                  disabledBorder: border,
                                  enabledBorder: border,
                                  focusedBorder: border,
                                ),
                                onFieldSubmitted: (value) {
                                  if (_searchFocusNode.hasFocus) {
                                    _searchFocusNode.unfocus();
                                  }
                                },
                                onChanged: (value) {
                                  // if (_searchController.text.isEmpty) {
                                  //   retailListProvider.setFiltering(false);
                                  // }
                                  retailListProvider.filterRetailList(
                                    _pinCodeController.text,
                                    value,
                                  );
                                },
                              ),
                            ),
                            InkWell(
                              onTap: () {
                                if (!retailListProvider.isFiltering) {
                                  retailListProvider.clearFilter(
                                    canGoBack: false,
                                  );
                                }
                                bottomSheet();
                              },
                              child: Container(
                                margin: const EdgeInsets.only(left: 10),
                                height: 40,
                                width: 44,
                                decoration: BoxDecoration(
                                  color: AppColors.filterBackgroundColor,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: AppColors.filterBorderColor,
                                  ),
                                ),
                                child: IconButton(
                                  onPressed: null,
                                  icon: Icon(
                                    Icons.filter_alt_outlined,
                                    color: AppColors.filterIconColor,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
              ),
              Align(
                alignment: Alignment.topLeft,
                child: Wrap(
                  spacing: 5,
                  // Space between chips
                  runSpacing: 5,
                  // Space between lines
                  alignment: WrapAlignment.start,
                  crossAxisAlignment: WrapCrossAlignment.start,
                  direction: Axis.horizontal,
                  runAlignment: WrapAlignment.start,
                  verticalDirection: VerticalDirection.down,
                  children: [
                    if (retailListProvider.isFiltering &&
                        retailListProvider.selectedCountry.isNotEmpty &&
                        !retailListProvider.isLoading) ...[
                      InputChip(
                        selected: true,
                        showCheckmark: false,
                        // Hide default checkmark
                        deleteIcon: Icon(Icons.close),
                        // Close icon on the right
                        onDeleted: () {
                          retailListProvider.removeSelectedCountry();
                        },
                        label: Text(
                          retailListProvider.selectedCountry,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.black,
                          ),
                        ),
                        onSelected: (value) {
                          retailListProvider.removeSelectedCountry();
                        },
                      ),
                    ],
                    if (retailListProvider.isFiltering &&
                        retailListProvider.selectedState.isNotEmpty &&
                        !retailListProvider.isLoading) ...[
                      InputChip(
                        selected: true,
                        showCheckmark: false,
                        // Hide default checkmark
                        deleteIcon: Icon(Icons.close),
                        // Close icon on the right
                        onDeleted: () {
                          retailListProvider.removeSelectedState();
                        },
                        label: Text(
                          retailListProvider.selectedState,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.black,
                          ),
                        ),
                        onSelected: (value) {
                          retailListProvider.removeSelectedState();
                        },
                      ),
                    ],
                    if (retailListProvider.isFiltering &&
                        retailListProvider.selectedDistrict.isNotEmpty &&
                        !retailListProvider.isLoading) ...[
                      InputChip(
                        selected: true,
                        showCheckmark: false,
                        // Hide default checkmark
                        deleteIcon: Icon(Icons.close),
                        // Close icon on the right
                        onDeleted: () {
                          retailListProvider.removeDistrict();
                        },
                        label: Text(
                          retailListProvider.selectedDistrict,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.black,
                          ),
                        ),
                        onSelected: (value) {
                          retailListProvider.removeDistrict();
                        },
                      ),
                    ],
                    if (retailListProvider.isFiltering &&
                        retailListProvider.selectedCity.isNotEmpty &&
                        !retailListProvider.isLoading) ...[
                      InputChip(
                        selected: true,
                        showCheckmark: false,
                        // Hide default checkmark
                        deleteIcon: Icon(Icons.close),
                        // Close icon on the right
                        onDeleted: () {
                          retailListProvider.removeSelectedCity();
                        },
                        label: Text(
                          retailListProvider.selectedCity,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.black,
                          ),
                        ),
                        onSelected: (value) {
                          retailListProvider.removeSelectedCity();
                        },
                      ),
                    ],
                    if (retailListProvider.isFiltering &&
                        retailListProvider.pinCode.isNotEmpty &&
                        !retailListProvider.isLoading) ...[
                      InputChip(
                        selected: true,
                        showCheckmark: false,
                        // Hide default checkmark
                        deleteIcon: Icon(Icons.close),
                        // Close icon on the right
                        onDeleted: () {
                          retailListProvider.removePinCode();
                        },
                        label: Text(
                          retailListProvider.pinCode,
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.black,
                          ),
                        ),
                        onSelected: (value) {
                          retailListProvider.removePinCode();
                        },
                      ),
                    ],
                    if (retailListProvider.isFiltering &&
                        (retailListProvider.subscribeSelectedFilterOption ==
                                2 ) &&
                        !retailListProvider.isLoading) ...[
                      InputChip(
                        selected: true,
                        showCheckmark: false,
                        // Hide default checkmark
                        deleteIcon: Icon(Icons.close),
                        // Close icon on the right
                        onDeleted: () {
                          retailListProvider
                              .removeSubscribeSelectedFilterOption();
                        },
                        label: Text(
                          "Free Listing",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.black,
                          ),
                        ),
                        onSelected: (value) {
                          retailListProvider
                              .removeSubscribeSelectedFilterOption();
                        },
                      ),
                    ],
                    if (retailListProvider.isFiltering &&
                        (retailListProvider.subscribeSelectedFilterOption ==
                            3 ) &&
                        !retailListProvider.isLoading) ...[
                      InputChip(
                        selected: true,
                        showCheckmark: false,
                        // Hide default checkmark
                        deleteIcon: Icon(Icons.close),
                        // Close icon on the right
                        onDeleted: () {
                          retailListProvider
                              .removeSubscribeSelectedFilterOption();
                        },
                        label: Text(
                          "Subscribe",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.black,
                          ),
                        ),
                        onSelected: (value) {
                          retailListProvider
                              .removeSubscribeSelectedFilterOption();
                        },
                      ),
                    ],
                    if (retailListProvider.isFiltering &&
                        (retailListProvider.subscribeSelectedFilterOption ==
                            4 ) &&
                        !retailListProvider.isLoading) ...[
                      InputChip(
                        selected: true,
                        showCheckmark: false,
                        // Hide default checkmark
                        deleteIcon: Icon(Icons.close),
                        // Close icon on the right
                        onDeleted: () {
                          retailListProvider
                              .removeSubscribeSelectedFilterOption();
                        },
                        label: Text(
                          "Decline",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.black,
                          ),
                        ),
                        onSelected: (value) {
                          retailListProvider
                              .removeSubscribeSelectedFilterOption();
                        },
                      ),
                    ],
                    if (retailListProvider.isFiltering &&
                        (retailListProvider.subscribeSelectedFilterOption ==
                            5 ) &&
                        !retailListProvider.isLoading) ...[
                      InputChip(
                        selected: true,
                        showCheckmark: false,
                        // Hide default checkmark
                        deleteIcon: Icon(Icons.close),
                        // Close icon on the right
                        onDeleted: () {
                          retailListProvider
                              .removeSubscribeSelectedFilterOption();
                        },
                        label: Text(
                          "Decline Listing",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.black,
                          ),
                        ),
                        onSelected: (value) {
                          retailListProvider
                              .removeSubscribeSelectedFilterOption();
                        },
                      ),
                    ],
                    if (retailListProvider.isFiltering &&
                        (retailListProvider.subscribeSelectedFilterOption ==
                            6 ) &&
                        !retailListProvider.isLoading) ...[
                      InputChip(
                        selected: true,
                        showCheckmark: false,
                        // Hide default checkmark
                        deleteIcon: Icon(Icons.close),
                        // Close icon on the right
                        onDeleted: () {
                          retailListProvider
                              .removeSubscribeSelectedFilterOption();
                        },
                        label: Text(
                          "Decline Subscription",
                          style: GoogleFonts.poppins(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: AppColors.black,
                          ),
                        ),
                        onSelected: (value) {
                          retailListProvider
                              .removeSubscribeSelectedFilterOption();
                        },
                      ),
                    ],
                  ],
                ),
              ),
              SizedBox(height: 0),
              retailListProvider.isFiltering &&
                      retailListProvider.filteredRetailList.isEmpty
                  ? SizedBox(
                    width: double.infinity,
                    child: Text(
                      "No data found for the selected search/filter criteria.",
                      textAlign: TextAlign.center,
                      style: GoogleFonts.poppins(
                        fontSize: 24,
                        fontWeight: FontWeight.w500,
                        color: AppColors.black,
                      ),
                    ),
                  )
                  : !retailListProvider.isFiltering &&
                      retailListProvider.retailList.isEmpty &&
                      !retailListProvider.isLoading
                  ? SizedBox(
                    height: MediaQuery.of(context).size.height * 0.7,
                    width: double.infinity,
                    child: Center(
                      child: Text(
                        "No Lead found",
                        textAlign: TextAlign.center,
                        style: GoogleFonts.poppins(
                          fontSize: 24,
                          fontWeight: FontWeight.w500,
                          color: AppColors.black,
                        ),
                      ),
                    ),
                  )
                  : Expanded(
                    child: RefreshIndicator(
                      onRefresh: () async {
                        // Return the Future from your data fetching method
                        return await Provider.of<RetailListScreenProvider>(
                          context,
                          listen: false,
                        ).getRetailList();
                      },
                      child: ListView.builder(
                        itemCount:
                            retailListProvider.isLoading
                                ? 20
                                : !retailListProvider.isFiltering
                                ? retailListProvider.retailList.length
                                : retailListProvider.filteredRetailList.length,
                        physics:
                            retailListProvider.isLoading
                                ? const NeverScrollableScrollPhysics()
                                : const BouncingScrollPhysics(),
                        itemBuilder: (context, index) {
                          // print("search controller : ${_searchController.text.isEmpty}");
                          // print("is filter : ${retailListProvider.isFiltering}");
                          return retailListProvider.isLoading
                              ? Shimmer.fromColors(
                                baseColor: Colors.grey.shade300,
                                highlightColor: Colors.grey.shade100,
                                child: Container(
                                  margin: const EdgeInsets.only(bottom: 10),
                                  decoration: BoxDecoration(
                                    color: AppColors.grey,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  height: 70,
                                ),
                              )
                              : InkWell(
                                onTap: () {
                                  if (_searchFocusNode.hasFocus) {
                                    _searchFocusNode.unfocus();
                                  }
                                  ClearProvider.clearLocationBaseProviders(
                                    context,
                                  );
                                  GetxNavigation().next(
                                    OutletDescriptionScreen.routeName,
                                    arguments: {
                                      "_id":
                                          !retailListProvider.isFiltering
                                              ? retailListProvider
                                                  .retailList[index]
                                                  .id
                                              : retailListProvider
                                                  .filteredRetailList[index]
                                                  .id,
                                      "status":
                                          !retailListProvider.isFiltering
                                              ? retailListProvider
                                                  .retailList[index]
                                                  .leadStatus
                                              : retailListProvider
                                                  .filteredRetailList[index]
                                                  .leadStatus,
                                    },
                                  );
                                },
                                child: Card(
                                  margin: const EdgeInsets.only(
                                    bottom: 0,
                                    top: 20,
                                  ),
                                  color: Colors.white,
                                  shadowColor:
                                      AppColors.homePageCardShadowColor,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(10),
                                    side: BorderSide(
                                      color: AppColors.homePageCardBorderColor,
                                      width: 1,
                                    ),
                                  ),
                                  elevation: 1,
                                  child: Padding(
                                    padding: const EdgeInsets.all(10),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      mainAxisAlignment:
                                          MainAxisAlignment.start,
                                      spacing: 10,
                                      children: [
                                        Row(
                                          crossAxisAlignment:
                                              CrossAxisAlignment.start,
                                          mainAxisAlignment:
                                              MainAxisAlignment.spaceBetween,
                                          children: [
                                            Text(
                                              !retailListProvider.isFiltering
                                                  ? "${retailListProvider.retailList[index].name} "
                                                  : retailListProvider
                                                      .filteredRetailList[index]
                                                      .name,
                                              style: GoogleFonts.poppins(
                                                fontSize: 18,
                                                fontWeight: FontWeight.w700,
                                                color:
                                                    AppColors
                                                        .homePageCardDarkTextColor,
                                              ),
                                            ),

                                            Container(
                                              padding: const EdgeInsets.all(5),
                                              decoration: BoxDecoration(
                                                color:
                                                    !retailListProvider
                                                            .isFiltering
                                                        ? getLeadStatusBackgroundColor(
                                                          retailListProvider
                                                              .retailList[index]
                                                              .leadStatus,
                                                        )
                                                        : getLeadStatusBackgroundColor(
                                                          retailListProvider
                                                              .filteredRetailList[index]
                                                              .leadStatus,
                                                        ),
                                                borderRadius:
                                                    BorderRadius.circular(6),
                                              ),
                                              child: Row(
                                                spacing: 5,
                                                children: [
                                                  SvgPicture.string(
                                                    SvgIcons.subscriptionIcon,
                                                    height: 16,
                                                    width: 16,
                                                    color:
                                                        !retailListProvider
                                                                .isFiltering
                                                            ? getLeadStatusColor(
                                                              retailListProvider
                                                                  .retailList[index]
                                                                  .leadStatus,
                                                            )
                                                            : getLeadStatusColor(
                                                              retailListProvider
                                                                  .filteredRetailList[index]
                                                                  .leadStatus,
                                                            ),
                                                  ),
                                                  Text(
                                                    !retailListProvider
                                                            .isFiltering
                                                        ? getLeadStatus(
                                                          retailListProvider
                                                              .retailList[index]
                                                              .leadStatus,
                                                        )
                                                        : getLeadStatus(
                                                          retailListProvider
                                                              .filteredRetailList[index]
                                                              .leadStatus,
                                                        ),
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 12,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color:
                                                          !retailListProvider
                                                                  .isFiltering
                                                              ? getLeadStatusColor(
                                                                retailListProvider
                                                                    .retailList[index]
                                                                    .leadStatus,
                                                              )
                                                              : getLeadStatusColor(
                                                                retailListProvider
                                                                    .filteredRetailList[index]
                                                                    .leadStatus,
                                                              ),
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          spacing: 8,
                                          children: [
                                            SvgPicture.string(
                                              SvgIcons.userAvtarIcon,
                                              height: 18,
                                              width: 18,
                                            ),
                                            Text(
                                              !retailListProvider.isFiltering
                                                  ? retailListProvider
                                                      .retailList[index]
                                                      .contactName
                                                  : retailListProvider
                                                      .filteredRetailList[index]
                                                      .contactName,
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                color:
                                                    AppColors
                                                        .homePageCardTextColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          spacing: 8,
                                          children: [
                                            SvgPicture.string(
                                              SvgIcons.callIcon,
                                              height: 18,
                                              width: 18,
                                            ),
                                            Text(
                                              !retailListProvider.isFiltering
                                                  ? retailListProvider
                                                      .retailList[index]
                                                      .mobile
                                                  : retailListProvider
                                                      .filteredRetailList[index]
                                                      .mobile,
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                color:
                                                    AppColors
                                                        .homePageCardTextColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Row(
                                          spacing: 8,
                                          children: [
                                            SvgPicture.string(
                                              SvgIcons.emailIcon,
                                              height: 18,
                                              width: 18,
                                            ),
                                            Text(
                                              !retailListProvider.isFiltering
                                                  ? retailListProvider
                                                      .retailList[index]
                                                      .email
                                                  : retailListProvider
                                                      .filteredRetailList[index]
                                                      .email,
                                              style: GoogleFonts.poppins(
                                                fontSize: 16,
                                                fontWeight: FontWeight.w500,
                                                color:
                                                    AppColors
                                                        .homePageCardTextColor,
                                              ),
                                            ),
                                          ],
                                        ),
                                        Wrap(
                                          children: [
                                            Row(
                                              spacing: 8,
                                              mainAxisSize: MainAxisSize.min,
                                              mainAxisAlignment:
                                                  MainAxisAlignment.start,
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                SvgPicture.string(
                                                  SvgIcons.locationIcon,
                                                  height: 18,
                                                  width: 18,
                                                ),
                                                SizedBox(
                                                  width:
                                                      MediaQuery.of(
                                                        context,
                                                      ).size.width *
                                                      0.8,
                                                  child: Text(
                                                    !retailListProvider
                                                            .isFiltering
                                                        ? "${retailListProvider.retailList[index].street}, "
                                                            "${retailListProvider.retailList[index].street2}, "
                                                            "${retailListProvider.retailList[index].cityName}, "
                                                            "${retailListProvider.retailList[index].stateName}, "
                                                            "${retailListProvider.retailList[index].zipCode}, "
                                                            "${retailListProvider.retailList[index].countryName}"
                                                        : "${retailListProvider.filteredRetailList[index].street}, "
                                                            "${retailListProvider.filteredRetailList[index].street2}, "
                                                            "${retailListProvider.filteredRetailList[index].cityName}, "
                                                            "${retailListProvider.filteredRetailList[index].stateName}, "
                                                            "${retailListProvider.filteredRetailList[index].zipCode}, "
                                                            "${retailListProvider.filteredRetailList[index].countryName}",
                                                    style: GoogleFonts.poppins(
                                                      fontSize: 16,
                                                      fontWeight:
                                                          FontWeight.w500,
                                                      color:
                                                          AppColors
                                                              .homePageCardTextColor,
                                                    ),
                                                    // maxLines: 1, // Limits the text to one line
                                                    // overflow: TextOverflow.ellipsis, // Adds "..." if text overflows
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),
                                  ),
                                ),
                              );
                        },
                      ),
                    ),
                  ),
            ],
          ),
        ),
      ),
      floatingActionButton:
          retailListProvider.isLoading
              ? Shimmer.fromColors(
                baseColor: Colors.grey.shade300,
                highlightColor: Colors.grey.shade100,
                child: Container(
                  height: 55,
                  width: 55,
                  decoration: BoxDecoration(
                    color: AppColors.grey,
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
              )
              : FloatingActionButton(
                onPressed: () {
                  GetxNavigation().next(CreateNewOutletScreen.routeName);
                },
                backgroundColor: AppColors.primaryColor,
                mouseCursor: WidgetStateMouseCursor.clickable,
                child: Icon(Icons.add, color: Colors.white, size: 30),
              ),
    );
  }
}
