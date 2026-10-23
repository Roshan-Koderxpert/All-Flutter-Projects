class KycDocumentModel {
  int id;
  int documentId;
  String documentName;
  String image;

  KycDocumentModel({
    required this.id,
    required this.documentId,
    required this.documentName,
    required this.image,
  });

  factory KycDocumentModel.fromJson(Map<String, dynamic> json) {
    print(json['document_id'][0]);
    print(json['document_id'][1]);
    return KycDocumentModel(
      id: json['id'],
      documentId: json['document_id'][0],
      documentName: json['document_id'][1],
      image: json['image'],
    );
  }
}