class BusinessCategoryModel {
  int id;
  String name;

  BusinessCategoryModel({required this.id, required this.name});

  factory BusinessCategoryModel.fromJson(Map<String, dynamic> json) {
    return BusinessCategoryModel(id: json['id'], name: json['name']);
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }
}