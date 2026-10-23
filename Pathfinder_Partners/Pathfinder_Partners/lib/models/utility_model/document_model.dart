class DocumentModel {
  int id;
  String documentName;

  DocumentModel({
    required this.id,
    required this.documentName,
  });

  factory DocumentModel.fromJson(Map<String, dynamic> json) {
    return DocumentModel(
      id: json['id'],
      documentName: json['name'],
    );
  }

  Map<String, dynamic> toJson() {
    return {'id': id, 'name': documentName};
  }
}