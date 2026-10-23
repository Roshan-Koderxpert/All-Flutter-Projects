class BusinessSubCategoryModel {
  int id;
  String name;
  String retailerCategoryName;
  int retailerCategoryId;

  BusinessSubCategoryModel({
    required this.id,
    required this.name,
    required this.retailerCategoryName,
    required this.retailerCategoryId,
  });

  factory BusinessSubCategoryModel.fromJson(Map<String, dynamic> json) {
    print(json['name']);
    return BusinessSubCategoryModel(
      id: json['id'],
      name: json['name'],
      retailerCategoryName: json['retailer_category_id'][1],
      retailerCategoryId: json['retailer_category_id'][0],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'retailer_category_name': retailerCategoryName,
      'retailer_category_id': retailerCategoryId,
    };
  }
}
