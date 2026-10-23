import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';

class PdfPreviewView extends StatelessWidget {
  const PdfPreviewView({
    super.key,
    required this.pdfBytes,
    required this.fileName,
  });

  final List<int> pdfBytes;
  final String fileName;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(fileName, overflow: TextOverflow.ellipsis),
      ),
      body: SfPdfViewer.memory(
        Uint8List.fromList(pdfBytes),
      ),
    );
  }
}