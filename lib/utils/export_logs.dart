import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../models/exam_card_data.dart';
import '../services/csv_export_service.dart';
import 'notifications.dart';

final CsvExportService _csvExportService = CsvExportService();

void exportCopy(ExamCardData exam, BuildContext context) async {
  try {
    final recordId = exam.recordId;
    if (recordId == null) {
      if (!context.mounted) return;
      _toast("Export Failed", "Exam is not persisted yet", Icons.warning_amber_rounded, context, NotificationType.error);
      return;
    }

    final logText = await _csvExportService.buildRecordCsvText(
      examRecordId: recordId,
    );
    await Clipboard.setData(ClipboardData(text: logText));
    if (!context.mounted) return;
    _toast("Export Successful", "Export log copied to clipboard", Icons.copy_rounded, context, NotificationType.success);
  } catch (e) {
    if (!context.mounted) return;
    _toast("Export Failed", "Failed to copy export log: $e", Icons.error_outline_rounded, context, NotificationType.error);
  }
}

void exportCsvDownload(ExamCardData exam, BuildContext context) async {
  try {
    final recordId = exam.recordId;
    if (recordId == null) {
      if (!context.mounted) return;
      _toast("Export Failed", "Exam is not persisted yet", Icons.warning_amber_rounded, context, NotificationType.error);
      return;
    }
    final file = await _csvExportService.exportRecordToCsv(
      examRecordId: recordId,
    );
    if (!context.mounted) return;
    _showLogSavedSnackBar(context, file.path);
  } catch (e) {
    if (!context.mounted) return;
    _toast("Export Failed", "Failed to save export log: $e", Icons.error_outline_rounded, context, NotificationType.error);
  }
}

void exportCsvShare(ExamCardData exam, BuildContext context) async {
  try {
    final recordId = exam.recordId;
    if (recordId == null) {
      if (!context.mounted) return;
      _toast("Export Failed", "Exam is not persisted yet", Icons.warning_amber_rounded, context, NotificationType.error);
      return;
    }

    final file = await _csvExportService.exportRecordToCsv(
      examRecordId: recordId,
    );

    final params = ShareParams(
      text: 'Exported exam session log for ${exam.subject}',
      files: [XFile(file.path)],
    );
    await SharePlus.instance.share(params);
    if (!context.mounted) return;
    _toast("Export Successful", "Export log shared successfully", Icons.share_rounded, context, NotificationType.success);
  } catch (e) {
    if (!context.mounted) return;
    _toast("Export Failed", "Failed to share export log: $e", Icons.error_outline_rounded, context, NotificationType.error);
  }
}

Future<void> _openLog(String filePath, BuildContext context) async {
  final result = await OpenFilex.open(filePath);
  if (!context.mounted) return;
  if (result.type != ResultType.done) {
    final msg = result.message.trim().isNotEmpty
        ? result.message
        : 'Unknown error';
    _toast("Open Failed", "Could not open export log: $msg", Icons.error_outline_rounded, context, NotificationType.error);
  }
}

void _showLogSavedSnackBar(BuildContext context, String filePath) {
  NotificationService.show(
    context,
    title: "Export Saved",
    subtitle: "Tap to open: $filePath",
    icon: Icons.save_rounded,
    type: NotificationType.success,
    onTap: () {
      _openLog(filePath, context);
    },
  );
}

void _toast(String title, String subtitle, IconData icon, BuildContext context, [NotificationType type = NotificationType.information]) =>
    NotificationService.show(
      context,
      title: title,
      subtitle: subtitle,
      icon: icon,
      type: type,
    );
