class YearlyModel {
  final double target;
  final double achieved;

  YearlyModel({required this.target, required this.achieved});

  // fromJson
  YearlyModel.fromJson(Map<String, dynamic> json)
    : target = json['target'],
      achieved = json['achieved'];

  // toJson

  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['target'] = target;
    data['achieved'] = achieved;
    return data;
  }
}
