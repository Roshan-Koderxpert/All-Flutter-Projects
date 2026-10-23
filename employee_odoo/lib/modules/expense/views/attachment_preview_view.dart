import 'dart:io';
import 'dart:typed_data';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/material.dart';
import 'package:get/get_core/src/get_main.dart';
import 'package:get/get_navigation/src/extension_navigation.dart';
import 'package:get/get_navigation/src/snackbar/snackbar.dart';
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';

class AttachmentPreviewView extends StatelessWidget {
  const AttachmentPreviewView({
    super.key,
    required this.imageBytes,
    required this.fileName,
  });

  final List<int> imageBytes;
  final String fileName;

  Future<void> _save(BuildContext context) async {
    final ext = fileName.contains('.') ? fileName.split('.').last : 'jpg';
    final baseName = fileName.contains('.')
        ? fileName.substring(0, fileName.lastIndexOf('.'))
        : fileName;

    await FileSaver.instance.saveFile(
      name: baseName,
      bytes: Uint8List.fromList(imageBytes),
      fileExtension: ext,
      mimeType: MimeType.other,
    );

    Get.snackbar('Downloaded', '$fileName saved to your device',
        snackPosition: SnackPosition.BOTTOM);
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        iconTheme: const IconThemeData(color: Colors.white),
        title: Text(
          fileName,
          style: const TextStyle(color: Colors.white, fontSize: 14),
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.download_outlined, color: Colors.white),
            onPressed: () => _save(context),
            tooltip: 'Save',
          ),
        ],
      ),
      body: Center(
        child: InteractiveViewer(
          minScale: 0.5,
          maxScale: 5,
          child: Image.memory(
            Uint8List.fromList(imageBytes),
            fit: BoxFit.contain,
          ),
        ),
      ),
    );
  }
}