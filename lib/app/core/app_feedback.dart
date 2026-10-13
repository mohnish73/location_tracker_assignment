import 'package:flutter/material.dart';
import 'package:get/get.dart';

import '../data/channel_result.dart';

/// Snackbars and dialogs, all through GetX (no BuildContext plumbing).
/// Every helper is a no-op when no app is mounted (e.g. in unit tests).
abstract final class AppFeedback {
  static bool get _hasUi => Get.context != null;

  static void success(String title, String message) {
    if (!_hasUi) return;
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
      icon: const Icon(Icons.check_circle_outline),
      duration: const Duration(seconds: 2),
    );
  }

  static void error(String title, String message, {String? actionLabel, VoidCallback? onAction}) {
    if (!_hasUi) return;
    final colors = Get.theme.colorScheme;
    Get.snackbar(
      title,
      message,
      snackPosition: SnackPosition.BOTTOM,
      margin: const EdgeInsets.all(12),
      backgroundColor: colors.errorContainer,
      colorText: colors.onErrorContainer,
      icon: Icon(Icons.error_outline, color: colors.onErrorContainer),
      duration: const Duration(seconds: 4),
      mainButton: actionLabel == null
          ? null
          : TextButton(
              onPressed: () {
                if (Get.isSnackbarOpen) Get.closeCurrentSnackbar();
                onAction?.call();
              },
              child: Text(actionLabel),
            ),
    );
  }

  static void nativeError(NativeError error, {String? title}) =>
      AppFeedback.error(title ?? _titleFor(error.code), error.message);

  static String _titleFor(String code) => switch (code) {
        NativeErrorCode.permissionDenied => 'Permission required',
        NativeErrorCode.locationDisabled => 'Location is off',
        NativeErrorCode.databaseError => 'Database error',
        NativeErrorCode.serviceError => 'Tracking service error',
        NativeErrorCode.exportFailed => 'Export failed',
        NativeErrorCode.invalidArgument => 'Invalid request',
        _ => 'Something went wrong',
      };

  /// Returns true only if the user tapped [confirmLabel].
  static Future<bool> confirm({
    required String title,
    required String message,
    String confirmLabel = 'OK',
    String cancelLabel = 'Cancel',
    bool destructive = false,
  }) async {
    if (!_hasUi) return false;
    final result = await Get.dialog<bool>(
      AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Get.back(result: false), child: Text(cancelLabel)),
          FilledButton(
            style: destructive
                ? FilledButton.styleFrom(
                    backgroundColor: Get.theme.colorScheme.error,
                    foregroundColor: Get.theme.colorScheme.onError,
                  )
                : null,
            onPressed: () => Get.back(result: true),
            child: Text(confirmLabel),
          ),
        ],
      ),
    );
    return result ?? false;
  }
}
