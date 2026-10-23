import 'package:retail_gpt/models/utility_model/document_model.dart';

class RetailerOwnershipModel {
  int id;
  String name;
  List<DocumentModel> documentModel;

  RetailerOwnershipModel({
    required this.id,
    required this.name,
    required this.documentModel,
  });

  factory RetailerOwnershipModel.fromJson(Map<String, dynamic> json) {
    print(json);
    print(json['document_type_ids']);
    return RetailerOwnershipModel(
      id: json['id'],
      name: json['name'],
      documentModel:
          json['document_type_ids'] != null
              ? List<DocumentModel>.from(
                json['document_type_ids'].map((x) => DocumentModel.fromJson(x)),
              )
              : [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'document_type_ids': documentModel.map((e) => e.toJson()).toList(),
    };
  }
}
