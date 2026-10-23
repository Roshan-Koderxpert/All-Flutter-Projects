import 'package:flutter/material.dart';
import 'package:get/get.dart';

class NavigationHelper {
  /// ✅ Safe back navigation - handles snackbars, dialogs, and bottom sheets
  static void safeBack({dynamic result}) {
    try {
      // Close any open snackbars first
      if (Get.isSnackbarOpen == true) {
        Get.closeAllSnackbars();
      }

      // Then navigate back
      if (Get.context != null && Navigator.of(Get.context!).canPop()) {
        Navigator.of(Get.context!).pop(result);
      } else if (Get.key.currentState?.canPop() == true) {
        Get.back(result: result, closeOverlays: false);
      }
    } catch (e) {
      print('❌ Navigation error: $e');
      // Fallback to basic navigation
      try {
        if (Get.context != null) {
          Navigator.of(Get.context!).pop(result);
        }
      } catch (e2) {
        print('❌ Fallback navigation error: $e2');
      }
    }
  }

  /// ✅ Safe dialog close
  static void safeCloseDialog() {
    try {
      if (Get.isDialogOpen == true) {
        Get.back(closeOverlays: false);
      }
    } catch (e) {
      print('❌ Dialog close error: $e');
    }
  }

  /// ✅ Safe bottom sheet close
  static void safeCloseBottomSheet() {
    try {
      if (Get.isBottomSheetOpen == true) {
        Get.back(closeOverlays: false);
      }
    } catch (e) {
      print('❌ Bottom sheet close error: $e');
    }
  }

  /// ✅ Safe snackbar close
  static void safeCloseSnackbar() {
    try {
      // ✅ CRITICAL FIX: Add null check before accessing controller
      if (Get.isSnackbarOpen == true) {
        // Use microtask to avoid controller initialization issues
        Future.microtask(() {
          try {
            Get.closeAllSnackbars();
          } catch (e) {
            print("⚠️ Could not close snackbar (non-critical): $e");
          }
        });
      }
    } catch (e) {
      print("⚠️ Could not close snackbar: $e");
      // Don't rethrow - just skip closing
    }
  }

  /// ✅ Close all overlays safely
  static void closeAllOverlays() {
    safeCloseSnackbar();
    safeCloseDialog();
    safeCloseBottomSheet();
  }

  /// ✅ Show safe snackbar with enhanced error handling
  static void showSnackbar({
    required String title,
    required String message,
    Color? backgroundColor,
    Color? textColor,
    Duration? duration,
    SnackPosition position = SnackPosition.BOTTOM,
  }) {
    try {
      // ✅ CRITICAL FIX: Use Future.microtask to avoid race conditions
      // Don't try to close snackbars manually - let GetX handle it
      Future.microtask(() {
        try {
          if (Get.context != null) {
            Get.showSnackbar(
              GetSnackBar(
                title: title,
                message: message,
                backgroundColor: backgroundColor ?? Colors.black87,
                snackPosition: position,
                duration: duration ?? Duration(seconds: 2),
                margin: EdgeInsets.all(10),
                borderRadius: 8,
                isDismissible: true,
                dismissDirection: DismissDirection.horizontal,
              ),
            );
          }
        } catch (e) {
          print("⚠️ Error showing GetX snackbar: $e");
          // Fallback: just log to console
          print("📢 SNACKBAR: $title - $message");
        }
      });
    } catch (e) {
      print("⚠️ Error in showSnackbar: $e");
      print("📢 SNACKBAR: $title - $message");
    }
  }

  /// ✅ Show snackbar using BuildContext (more reliable fallback)
  static void showSnackbarWithContext(
      BuildContext context, {
        required String title,
        required String message,
        Color? backgroundColor,
        Duration? duration,
        IconData? icon,
      }) {
    try {
      ScaffoldMessenger.of(context).clearSnackBars();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: Colors.white),
                SizedBox(width: 12),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        fontWeight: FontWeight.bold,
                        fontSize: 15,
                        color: Colors.white,
                      ),
                    ),
                    SizedBox(height: 4),
                    Text(
                      message,
                      style: TextStyle(
                        fontSize: 13,
                        color: Colors.white,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          backgroundColor: backgroundColor ?? Colors.black87,
          duration: duration ?? Duration(seconds: 3),
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.all(16),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      );
    } catch (e) {
      print("⚠️ Error showing context snackbar: $e");
      print("📢 SNACKBAR: $title - $message");
    }
  }

  /// ✅ Show success message
  static void showSuccess({
    required String message,
    String title = 'Success',
    Duration? duration,
  }) {
    showSnackbar(
      title: title,
      message: message,
      backgroundColor: Colors.green.shade700, // ✅ Changed from Colors.green[700]
      duration: duration ?? Duration(seconds: 3),
    );
  }

  /// ✅ Show error message
  static void showError({
    required String message,
    String title = 'Error',
    Duration? duration,
  }) {
    showSnackbar(
      title: title,
      message: message,
      backgroundColor: Colors.red.shade700, // ✅ Changed
      duration: duration ?? Duration(seconds: 3),
    );
  }

  /// ✅ Show warning message
  static void showWarning({
    required String message,
    String title = 'Warning',
    Duration? duration,
  }) {
    showSnackbar(
      title: title,
      message: message,
      backgroundColor: Colors.orange.shade700, // ✅ Changed
      duration: duration ?? Duration(seconds: 4),
    );
  }

  /// ✅ Show info message
  static void showInfo({
    required String message,
    String title = 'Info',
    Duration? duration,
  }) {
    showSnackbar(
      title: title,
      message: message,
      backgroundColor: Colors.blue.shade700, // ✅ Changed from Colors.blue[700]
      duration: duration ?? Duration(seconds: 3),
    );
  }

  /// ✅ Show safe dialog with loading
  static void showLoading({String? message}) {
    try {
      Get.dialog(
        WillPopScope(
          onWillPop: () async => false,
          child: Center(
            child: Card(
              child: Padding(
                padding: EdgeInsets.all(20),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(),
                    if (message != null) ...[
                      SizedBox(height: 16),
                      Text(message),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ),
        barrierDismissible: false,
      );
    } catch (e) {
      print('❌ Loading dialog error: $e');
    }
  }

  /// ✅ Close loading dialog
  static void closeLoading() {
    safeCloseDialog();
  }

  /// ✅ Safe confirmation dialog
  static Future<bool> showConfirmDialog({
    required String title,
    required String message,
    String confirmText = 'Confirm',
    String cancelText = 'Cancel',
    Color confirmColor = Colors.blue,
  }) async {
    try {
      final result = await Get.dialog<bool>(
        AlertDialog(
          title: Text(title),
          content: Text(message),
          actions: [
            TextButton(
              onPressed: () {
                if (Get.isDialogOpen == true) {
                  Get.back(result: false, closeOverlays: false);
                }
              },
              child: Text(cancelText),
            ),
            ElevatedButton(
              onPressed: () {
                if (Get.isDialogOpen == true) {
                  Get.back(result: true, closeOverlays: false);
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: confirmColor,
              ),
              child: Text(confirmText),
            ),
          ],
        ),
        barrierDismissible: false,
      );
      return result ?? false;
    } catch (e) {
      print('❌ Confirm dialog error: $e');
      return false;
    }
  }

  /// ✅ Safe back with loading state cleanup
  static void safeBackWithCleanup({dynamic result}) {
    try {
      // Close any loading indicators
      if (Get.isDialogOpen == true) {
        Get.back(closeOverlays: false);
      }

      // Then navigate back
      safeBack(result: result);
    } catch (e) {
      print('❌ Navigation cleanup error: $e');
    }
  }
}