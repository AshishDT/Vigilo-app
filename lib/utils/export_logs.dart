import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';

import '../models/exam_card_data.dart';
import '../services/csv_export_service.dart';

final CsvExportService _csvExportService = CsvExportService();

void exportCopy(ExamCardData exam, BuildContext context) async {
  try {
    final recordId = exam.recordId;
    if (recordId == null) {
      if (!context.mounted) return;
      _toast("Unable to export: exam is not persisted yet", context);
      return;
    }

    final logText = await _csvExportService.buildRecordCsvText(
      examRecordId: recordId,
    );
    await Clipboard.setData(ClipboardData(text: logText));
    if (!context.mounted) return;
    _toast("Export log copied to clipboard", context);
  } catch (e) {
    if (!context.mounted) return;
    _toast("Failed to copy export log: $e", context);
  }
}

void exportCsvDownload(ExamCardData exam, BuildContext context) async {
  try {
    final recordId = exam.recordId;
    if (recordId == null) {
      if (!context.mounted) return;
      _toast("Unable to export: exam is not persisted yet", context);
      return;
    }
    final file = await _csvExportService.exportRecordToCsv(
      examRecordId: recordId,
    );
    if (!context.mounted) return;
    _showLogSavedSnackBar(context, file.path);
  } catch (e) {
    if (!context.mounted) return;
    _toast("Failed to save export log: $e", context);
  }
}

void exportCsvShare(ExamCardData exam, BuildContext context) async {
  try {
    final recordId = exam.recordId;
    if (recordId == null) {
      if (!context.mounted) return;
      _toast("Unable to export: exam is not persisted yet", context);
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
    _toast("Export log shared successfully", context);
  } catch (e) {
    if (!context.mounted) return;
    _toast("Failed to share export log: $e", context);
  }
}

Future<void> _openLog(String filePath, BuildContext context) async {
  final result = await OpenFilex.open(filePath);
  if (!context.mounted) return;
  if (result.type != ResultType.done) {
    final msg = result.message.trim().isNotEmpty
        ? result.message
        : 'Unknown error';
    _toast("Could not open export log: $msg", context);
  }
}

void _showLogSavedSnackBar(BuildContext context, String filePath) {
  final messenger = ScaffoldMessenger.of(context);
  messenger.hideCurrentSnackBar();
  messenger.showSnackBar(
    SnackBar(
      content: Text("Export log saved: $filePath"),
      behavior: SnackBarBehavior.floating,
      duration: const Duration(seconds: 6),
      action: SnackBarAction(
        label: 'Open',
        onPressed: () {
          _openLog(filePath, context);
        },
      ),
    ),
  );
}

void _toast(String msg, BuildContext context) =>
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(msg),
        behavior: SnackBarBehavior.floating,
        duration: const Duration(seconds: 3),
      ),
    );
