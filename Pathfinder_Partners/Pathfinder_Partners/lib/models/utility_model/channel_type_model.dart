class ChannelTypeModel {
  int id;
  String name;

  ChannelTypeModel({required this.id, required this.name});

  factory ChannelTypeModel.fromJson(Map<String, dynamic> json) {
    return ChannelTypeModel(id: json['id'], name: json['name']);
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': name};
  }
}
