import 'package:retail_gpt/models/home_screen/monthly_model.dart';
import 'package:retail_gpt/models/home_screen/yearly_model.dart';

class HomeScreenModel {
  final String id;
  final String title;
  final MonthlyModel monthly;
  final YearlyModel yearly;

  HomeScreenModel({
    required this.id,
    required this.title,
    required this.monthly,
    required this.yearly,
  });

  // fromJson
  HomeScreenModel.fromJson(Map<String, dynamic> json)
    : id = json['_id'],
      title = json['title'],
      monthly = MonthlyModel.fromJson(json['monthly']),
      yearly = YearlyModel.fromJson(json['yearly']);

  // toJson
  Map<String, dynamic> toJson() {
    final Map<String, dynamic> data = <String, dynamic>{};
    data['_id'] = id;
    data['title'] = title;
    data['monthly'] = monthly.toJson();
    data['yearly'] = yearly.toJson();
    return data;
  }
}
