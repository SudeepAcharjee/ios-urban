import 'package:flutter/material.dart';
import 'package:toastification/toastification.dart';

class CustomToast {
  static void show({
    required BuildContext context,
    required String message,
    required ToastificationType type,
    String? title,
  }) {
    toastification.dismissAll();
    toastification.show(
      context: context,
      type: type,
      style: ToastificationStyle.fillColored,
      autoCloseDuration: const Duration(seconds: 3),
      title: Text(
        title ?? message,
        style: const TextStyle(
          fontWeight: FontWeight.bold,
          color: Colors.white,
          fontSize: 14,
        ),
      ),
      description: title != null 
          ? Text(message, style: const TextStyle(color: Colors.white70, fontSize: 12))
          : null,
      alignment: Alignment.topRight,
      direction: TextDirection.ltr,
      animationDuration: const Duration(milliseconds: 300),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      borderRadius: BorderRadius.circular(10),
      showProgressBar: false, // Removed progress bar for cleaner look
      closeButtonShowType: CloseButtonShowType.always,
      closeOnClick: true,
      pauseOnHover: true,
      dragToClose: true,
      applyBlurEffect: false,
    );
  }

  static void error(BuildContext context, String message) {
    show(
      context: context,
      message: message,
      type: ToastificationType.error,
      title: 'Error',
    );
  }

  static void success(BuildContext context, String message) {
    show(
      context: context,
      message: message,
      type: ToastificationType.success,
      title: 'Success',
    );
  }

  static void warning(BuildContext context, String message) {
    show(
      context: context,
      message: message,
      type: ToastificationType.warning,
      title: 'Warning',
    );
  }

  static void info(BuildContext context, String message) {
    show(
      context: context,
      message: message,
      type: ToastificationType.info,
      title: 'Info',
    );
  }
}
