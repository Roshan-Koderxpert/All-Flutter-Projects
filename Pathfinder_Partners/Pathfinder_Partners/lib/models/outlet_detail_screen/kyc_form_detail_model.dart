class KycFormDetailModel {
  int id;
  int documentId;
  String documentName;
  String documentImage;

  KycFormDetailModel({required this.id,required this.documentId, required this.documentName,required this.documentImage});

  factory KycFormDetailModel.fromJson(Map<String, dynamic> json) {
    return KycFormDetailModel(
      id: json['id'] ?? 0,
      documentId: json['document_id'] ?? 0,
      documentName: json['document_name'] ?? '',
      documentImage: json['document_image'] ?? '',

    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'document_id': documentId,
      'document_name': documentName,
      'document_image': documentImage,
    };
  }
}
