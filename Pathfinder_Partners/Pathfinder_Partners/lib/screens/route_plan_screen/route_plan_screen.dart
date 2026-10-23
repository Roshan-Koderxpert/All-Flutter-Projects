import 'package:flutter/material.dart';
import 'package:flutter_svg/svg.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:retail_gpt/Icons/SVG/svg_icons.dart';
import 'package:retail_gpt/providers/create_new_outlet_screens/route_path_screen_provider.dart';
import 'package:retail_gpt/screens/outlet_screens/create_new_outlet_screen.dart';
import 'package:retail_gpt/widgets/background_widget.dart';

import '../../navigation/getx_navigation.dart';
import '../../utils/app_colors.dart';
import '../../utils/utility_data.dart';

class RoutePlanScreen extends StatefulWidget {
  static const String routeName = '/route-plan-screen';

  const RoutePlanScreen({super.key});

  @override
  State<RoutePlanScreen> createState() => _RoutePlanScreenState();
}

class _RoutePlanScreenState extends State<RoutePlanScreen> {
  final _pinCodeController = TextEditingController();
  final _formKey = GlobalKey<FormState>();
  final _searchFocusNode = FocusNode();
  final _pinCodeFocusNode = FocusNode();
  InputBorder? border = OutlineInputBorder(
    borderRadius: BorderRadius.circular(10),
    borderSide: BorderSide(color: Colors.grey.shade300),
  );

  @override
  Widget build(BuildContext context) {
    final routePlanProvider = context.watch<RoutePlanScreenProvider>();
    return BackgroundWidget(
      headerWidget: Container(
        padding: const EdgeInsets.only(left: 16),
        child: Row(
          children: [
            InkWell(
              onTap: () {
                GetxNavigation().goBack();
                routePlanProvider.clearData();
              },
              child: SvgPicture.string(
                SvgIcons.navigationBackIcon,
                key: const Key('navigationBackIcon'),
              ),
            ),
            Spacer(),
            Text(
              'Route Plan',
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
      bottomSheetWidget: Padding(
        padding: const EdgeInsets.only(top: 20.0),
        child: Column(
          children: [
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
                DropdownButtonFormField<String>(
                  elevation: 0,
                  borderRadius: BorderRadius.circular(10),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.black,
                  ),
                  decoration: InputDecoration(
                    fillColor: AppColors.white,
                    filled: true,
                    border: border,
                    enabledBorder: border,
                    focusedBorder: border,
                    errorBorder: border,
                    disabledBorder: border,
                    focusedErrorBorder: border,
                  ),
                  dropdownColor: AppColors.white,
                  isExpanded: true,
                  hint: Text(
                    "Select Emirate/Province/State",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.paragraph,
                    ),
                  ),
                  value:
                      routePlanProvider.selectedState.isNotEmpty
                          ? routePlanProvider.selectedState
                          : null,
                  items:
                      UtilityData.indianStates.map<DropdownMenuItem<String>>((
                        String value,
                      ) {
                        return DropdownMenuItem<String>(
                          value: value,
                          child: Text(value),
                        );
                      }).toList(),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      context.read<RoutePlanScreenProvider>().setSelectedState(
                        newValue,
                      );
                    }
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
                  "City/Town/Cluster",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.paragraph,
                  ),
                ),
                DropdownButtonFormField<String>(
                  elevation: 0,
                  borderRadius: BorderRadius.circular(10),
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.black,
                  ),
                  decoration: InputDecoration(
                    fillColor: AppColors.white,
                    filled: true,
                    border: border,
                    enabledBorder: border,
                    focusedBorder: border,
                    errorBorder: border,
                    disabledBorder: border,
                    focusedErrorBorder: border,
                  ),
                  dropdownColor: AppColors.white,
                  isExpanded: true,
                  hint: Text(
                    "Select City/Town/Cluster",
                    style: GoogleFonts.poppins(
                      fontSize: 16,
                      fontWeight: FontWeight.w500,
                      color: AppColors.paragraph,
                    ),
                  ),
                  value:
                      routePlanProvider.selectedCity.isNotEmpty
                          ? routePlanProvider.selectedCity
                          : null,
                  items:
                      UtilityData
                          .indianStateCities[routePlanProvider
                                  .selectedState
                                  .isEmpty
                              ? 'Gujarat'
                              : routePlanProvider.selectedState]
                          ?.map<DropdownMenuItem<String>>((String value) {
                            return DropdownMenuItem<String>(
                              value: value,
                              child: Text(value),
                            );
                          })
                          .toList(),
                  onChanged:
                      routePlanProvider.selectedState.isEmpty
                          ? null
                          : (String? newValue) {
                            if (newValue != null) {
                              context
                                  .read<RoutePlanScreenProvider>()
                                  .setSelectedCity(newValue);
                            }
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
                  "Postal Code/Zip",
                  style: GoogleFonts.poppins(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                    color: AppColors.paragraph,
                  ),
                ),
                Form(
                  key: _formKey,
                  child: TextFormField(
                    controller: _pinCodeController,
                    focusNode: _pinCodeFocusNode,
                    textInputAction: TextInputAction.next,
                    keyboardType: TextInputType.number,
                    keyboardAppearance: Brightness.dark,
                    maxLength: 6,
                    decoration: InputDecoration(
                      fillColor: AppColors.white,
                      filled: true,
                      hintText: "Postal Code/Zip",
                      counterText: "",
                      hintStyle: TextStyle(color: AppColors.paragraph),
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
                      if (value != null) {
                        if (value.isNotEmpty) {
                          if (value.length != 6) {
                            return 'Postal code must have at least 6 digits.';
                          }
                        }
                      }
                      return null;
                    },
                  ),
                ),
              ],
            ),
            SizedBox(height: 20),
            ElevatedButton(
              onPressed: () {
                GetxNavigation().next(
                  CreateNewOutletScreen.routeName,
                  arguments: {
                    'state': routePlanProvider.selectedState,
                    'city': routePlanProvider.selectedCity,
                    'pinCode': _pinCodeController.text,
                  },
                );
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
                "Next",
                style: Theme.of(context).textTheme.titleMedium!.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.white,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
