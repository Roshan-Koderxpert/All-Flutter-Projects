import 'dart:io';
import 'package:retail_gpt/local_storage/shared_preference.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import 'package:retail_gpt/navigation/getx_navigation.dart';
import 'package:retail_gpt/providers/home_screen/home_screen_provider.dart';
import 'package:retail_gpt/providers/retail_list_screen/retail_list_screen_provider.dart';
import 'package:retail_gpt/screens/outlet_screens/create_new_outlet_screen.dart';
import 'package:retail_gpt/screens/retail_list_screen/retail_list_screen.dart';
import 'package:retail_gpt/utils/app_colors.dart';
import 'package:retail_gpt/widgets/background_widget.dart';
import 'package:shimmer/shimmer.dart';
import '../../providers/utility_provider/local_data_provider.dart';



class HomeScreen extends StatefulWidget {
  static const String routeName = '/home-screen';

  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  void initState() {
    // TODO: implement initState

    Future.microtask(() async {
      final homeScreenProvider = Provider.of<HomeScreenProvider>(
        context,
        listen: false,
      );
      RetailListScreenProvider retailScreenProvider =
      Provider.of<RetailListScreenProvider>(context, listen: false);
     await retailScreenProvider.getRetailList();
     await homeScreenProvider.getData();
    });

    super.initState();
  }

  @override
  Widget build(BuildContext context) {
    final homeProvider = context.watch<HomeScreenProvider>();
    LocalDataProvider localeDataProvider = Provider.of<LocalDataProvider>(
      context,
      listen: false,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        double boxWidth = constraints.maxWidth / 2 - 26;
        return BackgroundWidget(
          headerWidget: Container(
            padding: const EdgeInsets.only(left: 16),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Welcome\n${localeDataProvider.userName}\n(${localeDataProvider.companyName})',
                  style: GoogleFonts.poppins(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.white,
                  ),
                ),
                IconButton(
                  onPressed: () {
                    if (Platform.isIOS) {
                      // iOS specific code
                      showCupertinoDialog(
                        context: context,
                        builder: (context) => CupertinoAlertDialog(
                          title: Text('Logout'),
                          content: Text('Are you sure you want to logout?'),
                          actions: [
                            CupertinoDialogAction(
                              isDefaultAction: true,
                              onPressed: () {
                                Navigator.of(context).pop();
                              },
                              child: Text('Cancel'),
                            ),
                            CupertinoDialogAction(
                              isDestructiveAction: true,
                              onPressed: () async {
                                await SharedPreference.logout("");
                              },
                              child: Text('Logout'),
                            ),
                          ],
                        ),
                      );

                    } else {
                      // Android specific code
                      showDialog(
                        context: context,
                        builder:
                            (context) => AlertDialog(
                              title: Text('Logout'),
                              content: Text('Are you sure you want to logout?'),
                              actions: [
                                TextButton(
                                  onPressed: () {
                                    Navigator.of(context).pop();
                                  },
                                  child: Text('Cancel'),
                                ),
                                TextButton(
                                  onPressed: () async {
                                    await SharedPreference.logout("");
                                  },
                                  child: Text('Logout'),
                                ),
                              ],
                            ),
                      );
                    }
                  },
                  icon: Icon(Icons.logout, color: AppColors.white),
                ),
              ],
            ),
          ),
          bottomSheetWidget: Padding(
            padding: const EdgeInsets.only(top: 20),
            child: RefreshIndicator(
              onRefresh: () async {
                // await Future.delayed(Duration(milliseconds: 800));
                return await Provider.of<HomeScreenProvider>(
                  context,
                  listen: false,
                ).getData();
              },
              semanticsLabel: 'get-data',
              semanticsValue: 'Reset Form',
              child: SingleChildScrollView(
                physics: const AlwaysScrollableScrollPhysics(),
                child: Column(
                  children: [
                    _toggleSwitchButton(boxWidth),
                    SizedBox(height: 20),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        homeProvider.isLoading
                            ? Shimmer.fromColors(
                              baseColor: Colors.grey.shade300,
                              highlightColor: Colors.grey.shade100,
                              child: Container(
                                width: boxWidth,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: Colors.grey.shade300,
                                  ),
                                ),
                                child: Column(
                                  spacing: 3,
                                  children: [
                                    SizedBox(height: 10),
                                    Center(
                                      child: Text(
                                        'Free Listing',
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: Colors.grey.shade300,
                                        ),
                                      ),
                                    ),
                                    Column(
                                      children: [
                                        Center(
                                          child: Text(
                                            "",
                                            style: GoogleFonts.poppins(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                        ),
                                        Center(
                                          child: Text(
                                            'Achieved /Target',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 10),
                                  ],
                                ),
                              ),
                            )
                            : InkWell(
                              onTap: () {
                                RetailListScreenProvider
                                retailListScreenProvider =
                                    Provider.of<RetailListScreenProvider>(
                                      context,
                                      listen: false,
                                    );
                                retailListScreenProvider
                                    .setSubscribeSelectedFilterOption(2);
                                retailListScreenProvider.applyFilter(
                                  "",
                                  "",
                                  canGoBack: false,
                                );
                                GetxNavigation().next(
                                  RetailListScreen.routeName,
                                );
                              },
                              child: Container(
                                width: boxWidth,
                                decoration: BoxDecoration(
                                  color: AppColors.freeListingFillColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.freeListingBorderColor,
                                  ),
                                ),
                                child: Column(
                                  spacing: 3,
                                  children: [
                                    SizedBox(height: 10),
                                    Center(
                                      child: Text(
                                        'Free Listing',
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color: AppColors.freeListingTextColor,
                                        ),
                                      ),
                                    ),
                                    Column(
                                      children: [
                                        Center(
                                          child: Text(
                                            homeProvider.toggleValue == 0
                                                ? '${homeProvider.achievedFreeListingMonthlyTarget}/${homeProvider.monthlyFreeListingTarget}'
                                                : '${homeProvider.achievedFreeListingYearlyTarget}/${homeProvider.yearlyFreeListingTarget}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.black,
                                            ),
                                          ),
                                        ),
                                        Center(
                                          child: Text(
                                            'Achieved /Target',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF4E4D53),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 10),
                                  ],
                                ),
                              ),
                            ),
                        homeProvider.isLoading
                            ? Shimmer.fromColors(
                              baseColor: Colors.grey.shade300,
                              highlightColor: Colors.grey.shade100,
                              child: Container(
                                width: boxWidth,
                                decoration: BoxDecoration(
                                  color: Colors.grey.shade300,
                                  //#F1EDFF
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color:
                                    Colors.grey.shade300,
                                  ),
                                ),
                                child: Column(
                                  spacing: 3,
                                  children: [
                                    SizedBox(height: 10),
                                    Center(
                                      child: Text(
                                        'Subscription',
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color:
                                          Colors.grey.shade300,
                                        ),
                                      ),
                                    ),
                                    Column(
                                      children: [
                                        Center(
                                          child: Text(
                                            "",
                                            style: GoogleFonts.poppins(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                        ),
                                        Center(
                                          child: Text(
                                            'Achieved /Target',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Colors.grey.shade300,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 10),
                                  ],
                                ),
                              ),
                            )
                            : InkWell(
                              onTap: () {
                                RetailListScreenProvider
                                retailListScreenProvider =
                                    Provider.of<RetailListScreenProvider>(
                                      context,
                                      listen: false,
                                    );
                                retailListScreenProvider
                                    .setSubscribeSelectedFilterOption(3);
                                retailListScreenProvider.applyFilter(
                                  "",
                                  "",
                                  canGoBack: false,
                                );
                                GetxNavigation().next(
                                  RetailListScreen.routeName,
                                );
                              },
                              child: Container(
                                width: boxWidth,
                                decoration: BoxDecoration(
                                  color: AppColors.subscriptionListingFillColor,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color:
                                        AppColors
                                            .subscriptionListingBorderColor,
                                  ),
                                ),
                                child: Column(
                                  spacing: 3,
                                  children: [
                                    SizedBox(height: 10),
                                    Center(
                                      child: Text(
                                        'Subscription',
                                        style: GoogleFonts.poppins(
                                          fontSize: 18,
                                          fontWeight: FontWeight.w600,
                                          color:
                                              AppColors
                                                  .subscriptionListingTextColor,
                                        ),
                                      ),
                                    ),
                                    Column(
                                      children: [
                                        Center(
                                          child: Text(
                                            homeProvider.toggleValue == 0
                                                ? '${homeProvider.achievedSubscriptionMonthlyTarget}/${homeProvider.monthlySubscriptionTarget}'
                                                : '${homeProvider.achievedSubscriptionYearlyTarget}/${homeProvider.yearlySubscriptionTarget}',
                                            style: GoogleFonts.poppins(
                                              fontSize: 20,
                                              fontWeight: FontWeight.w700,
                                              color: AppColors.black,
                                            ),
                                          ),
                                        ),
                                        Center(
                                          child: Text(
                                            'Achieved /Target',
                                            style: GoogleFonts.poppins(
                                              fontSize: 12,
                                              fontWeight: FontWeight.w500,
                                              color: Color(0xFF4E4D53),
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                    SizedBox(height: 10),
                                  ],
                                ),
                              ),
                            ),
                      ],
                    ),
                    SizedBox(height: 20),
                    homeProvider.isLoading
                        ? Shimmer.fromColors(
                          baseColor: Colors.grey.shade300,
                          highlightColor: Colors.grey.shade100,
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color:
                              Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                Colors.grey.shade300,
                              ),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              spacing: 3,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Text(
                                  'Declined Free Listing',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color:
                                    Colors.grey.shade300,
                                  ),
                                ),
                                Column(
                                  children: [
                                    Text(
                                      '',
                                      style: GoogleFonts.poppins(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: Colors.grey.shade300,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )
                        : InkWell(
                      onTap: (){
                        RetailListScreenProvider
                        retailListScreenProvider =
                        Provider.of<RetailListScreenProvider>(
                          context,
                          listen: false,
                        );
                        retailListScreenProvider
                            .setSubscribeSelectedFilterOption(5);
                        retailListScreenProvider.applyFilter(
                          "",
                          "",
                          canGoBack: false,
                        );
                        GetxNavigation().next(
                          RetailListScreen.routeName,
                        );
                      },
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color:
                                  AppColors.declineFreeListingFillColor, //FEF2E6
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    AppColors
                                        .declineFreeListingBorderColor, //#F5E5D4
                              ),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              spacing: 3,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Text(
                                  'Declined Free Listing',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        AppColors
                                            .declineFreeListingTextColor, //#C5A360
                                  ),
                                ),
                                Column(
                                  children: [
                                    Text(
                                      homeProvider.toggleValue == 0
                                          ? '${homeProvider.declineFreeListingMonthlyTarget}'
                                          : '${homeProvider.declineFreeListingYearlyTarget}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    SizedBox(height: 20),
                    homeProvider.isLoading
                        ? Shimmer.fromColors(
                          baseColor: Colors.grey.shade300,
                          highlightColor: Colors.grey.shade100,
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color:
                              Colors.grey.shade300,
                              //#FFEEF0
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                Colors.grey.shade300,
                              ),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              spacing: 3,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Text(
                                  'Declined Subscription',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color:
                                    Colors.grey.shade300,
                                  ),
                                ),
                                Column(
                                  children: [
                                    Text(
                                      '',
                                      style: GoogleFonts.poppins(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color:Colors.grey.shade300,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        )
                        : InkWell(
                      onTap: (){
                        RetailListScreenProvider
                        retailListScreenProvider =
                        Provider.of<RetailListScreenProvider>(
                          context,
                          listen: false,
                        );
                        retailListScreenProvider
                            .setSubscribeSelectedFilterOption(6);
                        retailListScreenProvider.applyFilter(
                          "",
                          "",
                          canGoBack: false,
                        );
                        GetxNavigation().next(
                          RetailListScreen.routeName,
                        );
                      },
                          child: Container(
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color:
                                  AppColors.declineSubscriptionListingFillColor,
                              //#FFEEF0
                              borderRadius: BorderRadius.circular(8),
                              border: Border.all(
                                color:
                                    AppColors
                                        .declineSubscriptionListingBorderColor, //#F1C9CF
                              ),
                            ),
                            padding: const EdgeInsets.all(16),
                            child: Column(
                              spacing: 3,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.start,
                              children: [
                                Text(
                                  'Declined Subscription',
                                  style: GoogleFonts.poppins(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w600,
                                    color:
                                        AppColors
                                            .declineSubscriptionListingTextColor, //#D1576B
                                  ),
                                ),
                                Column(
                                  children: [
                                    Text(
                                      homeProvider.toggleValue == 0
                                          ? '${homeProvider.declineSubscriptionMonthlyTarget}'
                                          : '${homeProvider.declineSubscriptionYearlyTarget}',
                                      style: GoogleFonts.poppins(
                                        fontSize: 20,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.black,
                                      ),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ),
                    SizedBox(height: 20),
                    homeProvider.isLoading
                        ? Shimmer.fromColors(
                          baseColor: Colors.grey.shade300,
                          highlightColor: Colors.grey.shade100,
                          child: Container(
                            height: 56,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        )
                        : ElevatedButton(
                          onPressed: () {
                            RetailListScreenProvider retailListScreenProvider =
                                Provider.of<RetailListScreenProvider>(
                                  context,
                                  listen: false,
                                );
                            retailListScreenProvider.clearFilter(
                              canGoBack: false,
                            );
                            GetxNavigation().next(RetailListScreen.routeName);
                          },
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: AppColors.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: Size(double.infinity, 56),
                          ),
                          child: Text(
                            "All Listing",
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium!.copyWith(
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ),
                    SizedBox(height: 20),
                    homeProvider.isLoading
                        ? Shimmer.fromColors(
                          baseColor: Colors.grey.shade300,
                          highlightColor: Colors.grey.shade100,
                          child: Container(
                            height: 56,
                            width: double.infinity,
                            decoration: BoxDecoration(
                              color: Colors.grey.shade300,
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                        )
                        : ElevatedButton(
                          onPressed: () {
                            RetailListScreenProvider retailListScreenProvider =
                                Provider.of<RetailListScreenProvider>(
                                  context,
                                  listen: false,
                                );
                            retailListScreenProvider.clearFilter(
                              canGoBack: false,
                            );
                            GetxNavigation().next(
                              CreateNewOutletScreen.routeName,
                            );
                          },
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: AppColors.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            minimumSize: Size(double.infinity, 56),
                          ),
                          child: Text(
                            "Register New Outlet",
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium!.copyWith(
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

  // toggle witch
  Widget _toggleSwitchButton(double screenWidth) {
    final homeProvider = context.watch<HomeScreenProvider>();
    return homeProvider.isLoading
        ? Shimmer.fromColors(
          baseColor: Colors.grey.shade300,
          highlightColor: Colors.grey.shade100,
          child: Container(
            padding: const EdgeInsets.all(8),
            height: 60,
            decoration: BoxDecoration(
              color: AppColors.grey,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                InkWell(
                  onTap:
                      () => Provider.of<HomeScreenProvider>(
                        context,
                        listen: false,
                      ).onToggle(0),
                  child: Container(
                    width: screenWidth,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          context.watch<HomeScreenProvider>().toggleValue == 0
                              ? AppColors.white
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Month',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: AppColors.black,
                      ),
                    ),
                  ),
                ),
                InkWell(
                  onTap:
                      () => Provider.of<HomeScreenProvider>(
                        context,
                        listen: false,
                      ).onToggle(1),
                  child: Container(
                    width: screenWidth,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color:
                          context.watch<HomeScreenProvider>().toggleValue == 1
                              ? AppColors.white
                              : Colors.transparent,
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: Text(
                      'Total',
                      style: GoogleFonts.poppins(
                        fontSize: 18,
                        fontWeight: FontWeight.w500,
                        color: AppColors.black,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        )
        : Container(
          padding: const EdgeInsets.all(4),
          height: 60,
          decoration: BoxDecoration(
            color: AppColors.grey,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              InkWell(
                onTap:
                    () => Provider.of<HomeScreenProvider>(
                      context,
                      listen: false,
                    ).onToggle(0),
                child: Container(
                  width: screenWidth,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        context.watch<HomeScreenProvider>().toggleValue == 0
                            ? AppColors.white
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Month',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.black,
                    ),
                  ),
                ),
              ),
              InkWell(
                onTap:
                    () => Provider.of<HomeScreenProvider>(
                      context,
                      listen: false,
                    ).onToggle(1),
                child: Container(
                  width: screenWidth,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color:
                        context.watch<HomeScreenProvider>().toggleValue == 1
                            ? AppColors.white
                            : Colors.transparent,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    'Total',
                    style: GoogleFonts.poppins(
                      fontSize: 18,
                      fontWeight: FontWeight.w500,
                      color: AppColors.black,
                    ),
                  ),
                ),
              ),
            ],
          ),
        );
  }
}
