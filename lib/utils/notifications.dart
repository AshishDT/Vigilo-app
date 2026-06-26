import 'package:flutter/material.dart';
import '../views/widgets/erc_notice.dart';

class NotificationService {
  static void show(
    BuildContext context, {
    required String title,
    String? subtitle,
    IconData icon = Icons.info_outline_rounded,
    VoidCallback? onTap,
  }) {
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
        duration: const Duration(seconds: 3),
      ),
    );
  }
}
