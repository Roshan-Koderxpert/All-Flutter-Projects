class RetailModel {
  int id;
  String name;
  String brandDescription;
  String brandType;
  String contactName;
  dynamic email;
  double expectedRevenue;
  int stageId;
  String type;
  String mobile;
  String street;
  dynamic street2;
  dynamic cityId;
  String cityName;
  dynamic districtId;
  String districtName;
  dynamic stateId;
  String stateName;
  dynamic countryId;
  String countryName;
  dynamic zipId;
  String zipCode;
  String leadStatus;
  String description;

  RetailModel({
    required this.id,
    required this.name,
    required this.brandDescription,
    required this.brandType,
    required this.contactName,
    required this.email,
    required this.expectedRevenue,
    required this.stageId,
    required this.type,
    required this.mobile,
    required this.street,
    required this.street2,
    required this.cityId,
    required this.cityName,
    required this.districtId,
    required this.districtName,
    required this.stateId,
    required this.stateName,
    required this.countryId,
    required this.countryName,
    required this.zipId,
    required this.zipCode,
    required this.leadStatus,
    required this.description,
  });
}
