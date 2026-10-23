
class StateModel {
  int id;
  String name;
  String code;

  StateModel({
    required this.id,
    required this.name,
    required this.code,
  });

  factory StateModel.fromJson(Map<String, dynamic> json) {
    return StateModel(
      id: json['id'],
      name: json['name'],
      code: json['code'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name, 'code': code};
  }
}
