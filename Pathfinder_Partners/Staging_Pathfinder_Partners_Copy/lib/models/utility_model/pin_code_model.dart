class PinCodeModel {
  int id;
  String pinCode;

  PinCodeModel({required this.id, required this.pinCode});

  factory PinCodeModel.fromJson(Map<String, dynamic> json) {
    return PinCodeModel(id: json['id'], pinCode: json['name']);
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': pinCode};
  }
}
