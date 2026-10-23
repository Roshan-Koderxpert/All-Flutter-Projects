import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:image_picker/image_picker.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:retail_gpt/navigation/getx_navigation.dart';
import 'package:retail_gpt/utils/app_colors.dart';

class Helper {
  Future<String?> pickImage(BuildContext context) async {
    _requestStoragePermissions();
    final ImagePicker picker = ImagePicker();
    GetxNavigation().goBack();
    final XFile? result = await picker.pickImage(
      source: ImageSource.gallery,
      imageQuality: 100,
      requestFullMetadata: true,
    );
    // GetxNavigation().goBack();
    if (result != null) {
      String? filePath = await _cropImage(result, context);
      return filePath;
    } else {
      // User canceled the picker
      return null;
    }
  }
  Future<String?> pickPdf1(BuildContext context) async {
    _requestStoragePermissions();
    // final ImagePicker picker = ImagePicker();
    FilePickerResult? result = await FilePicker.platform.pickFiles(
      allowedExtensions: ['pdf'],
      type: FileType.custom,
    );
    // GetxNavigation().goBack();

    // GetxNavigation().goBack();
    if (result != null) {
      File file = File(result.files.single.path!);
      // String? filePath = await _cropImage(result, context);
      return file.path;
    } else {
      // User canceled the picker
      return null;
    }
  }

  Future<String?> captureImage(BuildContext context) async {
    _requestStoragePermissions();
    final ImagePicker picker = ImagePicker();
    GetxNavigation().goBack();
    final XFile? result = await picker.pickImage(source: ImageSource.camera);

    if (result != null) {
      String? filePath = await _cropImage(result, context);
      return filePath;
    } else {
      // User canceled the picker
      return null;
    }
  }

  Future<void> _requestStoragePermissions() async {
    final storagePermissionStatus = await Permission.storage.status;
    final cameraPermissionStatus = await Permission.camera.status;
    if (!storagePermissionStatus.isGranted) {
      await Permission.storage.request(); // Request read permission
    }
    if (!cameraPermissionStatus.isGranted) {
      await Permission.camera.request(); // Request read permission
    }
  }

  Future<String?> _cropImage(XFile? pickedFile, BuildContext context) async {
    if (pickedFile != null) {
      final croppedFile = await ImageCropper().cropImage(
        sourcePath: pickedFile.path,
        compressFormat: ImageCompressFormat.jpg,
        compressQuality: 100,
        uiSettings: [
          AndroidUiSettings(
            toolbarTitle: 'Crop Image',
            toolbarColor: AppColors.primaryColor,
            toolbarWidgetColor: Colors.white,
            initAspectRatio: CropAspectRatioPreset.square,
            backgroundColor: Colors.white,
            activeControlsWidgetColor: AppColors.primaryColor,
            statusBarColor: AppColors.primaryColor,
            lockAspectRatio: false,
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatio2x2(),
              CropAspectRatioPreset.ratio4x3,
            ],
          ),
          IOSUiSettings(
            title: 'Cropper',
            aspectRatioPresets: [
              CropAspectRatioPreset.original,
              CropAspectRatio2x2(),
              CropAspectRatioPreset.ratio4x3,
            ],
          ),
          WebUiSettings(
            context: context,
            presentStyle: WebPresentStyle.dialog,
            size: const CropperSize(width: 520, height: 520),
          ),
        ],
      );
      if (croppedFile != null) {
        return croppedFile.path;
      }
      return pickedFile.path;
    }
    return null;
  }

  static Future<String> imageToBase64(String path) async {
    if (path.isEmpty) {
      print("Error: Empty image path provided");
      return "";
    }

    try {
      File imageFile = File(path);

      // Check if file exists
      if (!await imageFile.exists()) {
        throw Exception("Error: Image file does not exist");
      }

      Uint8List bytes = await imageFile.readAsBytes();
      String base64String = base64.encode(bytes);

      // Check if encoding was successful
      if (base64String.isNotEmpty) {
        print("Image successfully converted to base64");
        return base64String;
      } else {
        throw Exception("Error: Image could not be converted to base64");
      }
    } catch (e) {
      print("Error converting image to base64: $e");
      return e.toString();
    }
  }
}

class CropAspectRatio2x2 implements CropAspectRatioPresetData {
  @override
  (int, int)? get data => (1, 1);

  @override
  String get name => '1x1';
}
