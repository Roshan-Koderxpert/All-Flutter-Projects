import 'package:intl/intl.dart';

class OutletModel {
  int id;
  String name;
  String brandName;
  String brandDescription;
  String brandType;
  String contactName;
  double expectedRevenue;
  int countryId;
  String countryName;
  int stateId;
  String stateName;
  int cityId;
  String cityName;
  int districtId;
  String districtName;
  int pinCodeId;
  String pinCodeName;
  String lattitude;
  String longitude;
  String email;
  String mobile;
  String partnerType;
  int channelId;
  String channelName;
  String classOfRetailer;
  int retailerOwnershipId;
  String retailerOwnershipName;
  int businessCategoryId;
  String businessCategoryName;
  int businessSubCategoryId;
  String businessSubCategoryName;
  String street;
  String street2;
  String type;
  int stageId;
  String stageName;
  bool isActive;
  bool isSubscriptionDeclined;
  String base64Logo;
  String base64Image1;
  String base64Image2;
  String base64Image3;
  String website;
  List<int> kycDocumentList;
  String leadStatus;
  int openingId;
  String openingTime;
  int closingId;
  String closingTime;
  String pos_name;
  String pos_no;
  String next_follow_up_date;
  String description ;

  OutletModel({
    required this.id,
    required this.name,
    required this.brandDescription,
    required this.brandType,
    required this.brandName,
    required this.contactName,
    required this.expectedRevenue,
    required this.countryId,
    required this.countryName,
    required this.stateId,
    required this.stateName,
    required this.cityId,
    required this.cityName,
    required this.districtId,
    required this.districtName,
    required this.pinCodeId,
    required this.pinCodeName,
    required this.lattitude,
    required this.longitude,
    required this.email,
    required this.mobile,
    required this.partnerType,
    required this.channelId,
    required this.channelName,
    required this.classOfRetailer,
    required this.retailerOwnershipId,
    required this.retailerOwnershipName,
    required this.businessCategoryId,
    required this.businessCategoryName,
    required this.businessSubCategoryId,
    required this.businessSubCategoryName,
    required this.street,
    required this.street2,
    required this.type,
    required this.stageId,
    required this.stageName,
    required this.isActive,
    required this.isSubscriptionDeclined,
    required this.base64Logo,
    required this.base64Image1,
    required this.base64Image2,
    required this.base64Image3,
    required this.website,
    required this.kycDocumentList,
    required this.leadStatus,
    required this.openingId,
    required this.openingTime,
    required this.closingId,
    required this.closingTime,
    required this.pos_name,
    required this.pos_no,
    required this.next_follow_up_date,
    required this.description,
  });

  factory OutletModel.fromJson(Map<String, dynamic> json) {
    return OutletModel(
      pos_name: checkNullString(json['pos_name']),
      pos_no: checkNullString(json['pos_no']),
      next_follow_up_date: dateFormat(checkNullDouble(json['next_follow_up'])),
      id: checkNullInt(json['id']),
      name: checkNullString(json['name']),
      brandDescription: checkNullString(json['brand_description']),
      brandType: checkNullString(json['brand_type']),
      contactName: checkNullString(json['contact_name']),
      brandName: checkNullString(json['brand_name']),
      expectedRevenue: checkNullDouble(json['expected_revenue']),
      countryId: checkIsList(json['country_id']).isEmpty
          ? -1
          : json['country_id'][0],
      countryName: checkIsList(json['country_id']).isEmpty
          ? ""
          : checkNullString(json['country_id'][1]),
      stateId: checkIsList(json['state_id']).isEmpty ? -1 : json['state_id'][0],
      stateName: checkIsList(json['state_id']).isEmpty
          ? ""
          : checkNullString(json['state_id'][1]),
      cityId: checkIsList(json['city_id']).isEmpty ? -1 : json['city_id'][0],
      cityName: checkIsList(json['city_id']).isEmpty
          ? ""
          : checkNullString(json['city_id'][1]),
      districtId: checkIsList(json['district_id']).isEmpty
          ? -1
          : json['district_id'][0],
      districtName: checkIsList(json['district_id']).isEmpty
          ? ""
          : checkNullString(json['district_id'][1]),
      pinCodeId: checkIsList(json['zip_code_id']).isEmpty
          ? -1
          : json['zip_code_id'][0],
      pinCodeName: checkIsList(json['zip_code_id']).isEmpty
          ? ""
          : json['zip_code_id'][1],
      lattitude: json['latitude'] != null ? json['latitude'].toString() : '0.0',
      longitude: json['longitude'] != null
          ? json['longitude'].toString()
          : '0.0',
      email: checkNullString(json['email']),
      mobile: checkNullString(json['mobile']),
      partnerType: checkNullString(json['partner_type']),
      channelId: checkIsList(json['channel_id']).isEmpty
          ? -1
          : json['channel_id'][0],
      channelName: checkIsList(json['channel_id']).isEmpty
          ? ""
          : json['channel_id'][1],
      classOfRetailer: checkNullString(json['class_of_retailer']),
      retailerOwnershipId: checkIsList(json['retailer_ownership_id']).isEmpty
          ? -1
          : json['retailer_ownership_id'][0],
      retailerOwnershipName: checkIsList(json['retailer_ownership_id']).isEmpty
          ? ""
          : json['retailer_ownership_id'][1],
      businessCategoryId: checkIsList(json['business_category_id']).isEmpty
          ? -1
          : json['business_category_id'][0],
      businessCategoryName: checkIsList(json['business_category_id']).isEmpty
          ? ""
          : json['business_category_id'][1],
      businessSubCategoryId:
          checkIsList(json['business_sub_category_id']).isEmpty
          ? -1
          : json['business_sub_category_id'][0],
      businessSubCategoryName:
          checkIsList(json['business_sub_category_id']).isEmpty
          ? ""
          : json['business_sub_category_id'][1],
      street: checkNullString(json['street']),
      street2: checkNullString(json['street2']),
      type: checkNullString(json['type']),
      stageId: checkIsList(json['stage_id']).isEmpty ? -1 : json['stage_id'][0],
      stageName: checkIsList(json['stage_id']).isEmpty
          ? ""
          : json['stage_id'][1],
      isActive: checkNullBool(json["is_active"]),
      isSubscriptionDeclined: checkNullBool(json["is_subscription_declined"]),
      base64Logo: checkNullString(json['logo']),
      base64Image1: checkNullString(json['image1']),
      base64Image2: checkNullString(json['image2']),
      base64Image3: checkNullString(json['image3']),
      website: checkNullString(json['website']),
      kycDocumentList: checkIsListInt(json['kyc_detail_ids']),
      leadStatus: checkNullString(json['listing_status']),
      openingId: checkIsList(json['opening_id']).isEmpty
          ? -1
          : json['opening_id'][0],
      openingTime: checkIsList(json['opening_id']).isEmpty
          ? ""
          : checkNullString(json['opening_id'][1]),
      closingId: checkIsList(json['closing_id']).isEmpty
          ? -1
          : json['closing_id'][0],
      closingTime: checkIsList(json['closing_id']).isEmpty
          ? ""
          : checkNullString(json['closing_id'][1]),
      description: checkNullString(json['description']),
    );
  }

  static String dateFormat(dynamic timestamp) {
    print(timestamp);
    if (timestamp == null || timestamp is List) {
      return "";
    }
    if(timestamp == 0.0){
      return "";
    }

    // Convert to UTC
    int millis = (timestamp * 1000).toInt();
    DateTime utcTime = DateTime.fromMillisecondsSinceEpoch(
      millis,
      isUtc: true,
    );

    // Convert to IST
    DateTime istTime = utcTime.add(Duration(hours: 5, minutes: 30));

    // Format to DD/MM/YYYY
    String formattedDate = DateFormat('dd/MM/yyyy').format(istTime);
    return formattedDate;
  }

  static String checkNullString(dynamic value) {
    if (value == null) {
      return "";
    }
    if (value is List) {
      return "";
    }
    return value.replaceAll(RegExp(r'<[^>]*>'), '');
  }

  static int checkNullInt(dynamic value) {
    if (value == null) {
      return -1;
    }
    if (value is List) {
      return -1;
    }
    return value;
  }

  static double checkNullDouble(dynamic value) {
    if (value == null) {
      return 0.0;
    }
    if (value is List) {
      return 0.0;
    }
    return value;
  }

  static bool checkNullBool(dynamic value) {
    if (value == null) {
      return false;
    }
    if (value is List) {
      return false;
    }
    return value;
  }

  static List checkIsList(dynamic value) {
    if (value == null) {
      return [];
    }

    if (value is List) {
      return value;
    } else {
      return [];
    }
  }

  static List<int> checkIsListInt(dynamic value) {
    if (value == null || value is! List) {
      return [];
    }

    // Safely convert the list to List<int> using map and toList()
    return value.whereType<int>().toList();
  }
}
