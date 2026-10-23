class OutletKycDocumentModel {

  int documentId;
  String documentName;
  String base64File;
  String docFileName;

  OutletKycDocumentModel({

    required this.documentId,
    required this.documentName,
    required this.base64File,
    required this.docFileName,
  });

  factory OutletKycDocumentModel.fromJson(Map<String, dynamic> json) {
    return OutletKycDocumentModel(
      documentId: json['id'],
      documentName: json['name'],
      base64File: json['doc_file'] ?? "",
      docFileName: json['doc_file_name'] ?? "",
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'document_id': [documentId, documentName],
      'doc_file': base64File,
      'doc_file_name': docFileName,
    };
  }
}