class TimeModel {
  int id;
  String time;

  TimeModel({required this.id, required this.time});

  factory TimeModel.fromJson(Map<String, dynamic> json) {
    return TimeModel(id: json['id'] as int, time: json['name'] as String);
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': time};
  }
}
