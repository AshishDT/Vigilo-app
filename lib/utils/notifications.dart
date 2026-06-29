import 'package:flutter/material.dart';
import '../views/widgets/erc_notice.dart';

enum NotificationType {
  success,
  information,
  warning,
  error,
}

class NotificationService {
  static void show(
    BuildContext context, {
    required String title,
    String? subtitle,
    IconData icon = Icons.info_outline_rounded,
    VoidCallback? onTap,
    NotificationType type = NotificationType.information,
  }) {
    int durationSeconds;
    switch (type) {
      case NotificationType.success:
      case NotificationType.information:
        durationSeconds = 3;
        break;
      case NotificationType.warning:
        durationSeconds = 4;
        break;
      case NotificationType.error:
        durationSeconds = 5;
        break;
    }

    final messenger = ScaffoldMessenger.of(context);
    messenger.hideCurrentSnackBar();
    messenger.showSnackBar(
      SnackBar(
        content: ERCNotice(
          icon: icon,
          title: title,
          subtitle: subtitle,
          onTap: onTap,
        ),
        behavior: SnackBarBehavior.floating,
        backgroundColor: Colors.transparent,
        elevation: 0,
        padding: EdgeInsets.zero,
        duration: Duration(seconds: durationSeconds),
      ),
    );
  }
}
