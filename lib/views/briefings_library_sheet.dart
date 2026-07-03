import 'dart:io';

import 'widgets/animated_scale_on_press.dart';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path/path.dart' as path;
import 'package:share_plus/share_plus.dart';

import '../enums/brief_type.dart';
import '../models/briefing_model.dart';
import '../services/briefings_storage_service.dart';
import '../services/session_service.dart';
import '../utils/notifications.dart';
import 'file_view_screen.dart';

enum BriefingsLibraryInitialAction { none, uploadPdf, capturePhoto }

Future<T?> showBriefingsLibrarySheet<T>(
  BuildContext context, {
  bool allowSelection = false,
  bool isExamCompleted = false,
  Set<String> initiallySelectedPaths = const <String>{},
  ValueChanged<List<BriefingItem>>? onSelectionApplied,
  String? title,
  String? selectionActionLabel,
  String? emptySelectionMessage,
  BriefingsLibraryInitialAction initialAction =
      BriefingsLibraryInitialAction.none,
  String setUpBy = '',
  String setUpRole = '',
}) {
  return showModalBottomSheet<T>(
    context: context,
    isScrollControlled: true,
    backgroundColor: Colors.transparent,
    builder: (_) => BriefingsLibrarySheet(
      allowSelection: allowSelection,
      initiallySelectedPaths: initiallySelectedPaths,
      onSelectionApplied: onSelectionApplied,
      title: title,
      selectionActionLabel: selectionActionLabel,
      emptySelectionMessage: emptySelectionMessage,
      initialAction: initialAction,
      isExamCompleted: isExamCompleted,
      setUpBy: setUpBy,
      setUpRole: setUpRole,
    ),
  );
}

class _SheetColorPalette {
  final BuildContext context;
  _SheetColorPalette(this.context);

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Color get panel =>
      _isDark ? const Color(0xFF10263D) : const Color(0xFFFFFFFF);
  Color get panel2 =>
      _isDark ? const Color(0xFF16314D) : const Color(0xFFF1F5F9);
  Color get line => _isDark ? const Color(0xFF294867) : const Color(0xFFE2E8F0);
  Color get lineSoft =>
      _isDark ? const Color(0xFF395B7D) : const Color(0xFFCBD5E1);
  Color get text => _isDark ? const Color(0xFFF3F7FC) : const Color(0xFF0B253A);
  Color get textSoft =>
      _isDark ? const Color(0xFFB6C7D8) : const Color(0xFF475569);
  Color get blue => _isDark ? const Color(0xFF4B86F8) : const Color(0xFF2563EB);
  Color get blackWhite =>
      _isDark ? const Color(0xFFFFFFFF) : const Color(0xFF000000);
  Color get blueSoft =>
      _isDark ? const Color(0xFF8FD4FF) : const Color(0xFF3B82F6);
}

class BriefingsLibrarySheet extends StatefulWidget {
  const BriefingsLibrarySheet({
    super.key,
    this.allowSelection = false,
    this.isExamCompleted = false,
    this.initiallySelectedPaths = const <String>{},
    this.onSelectionApplied,
    this.title,
    this.selectionActionLabel,
    this.emptySelectionMessage,
    this.initialAction = BriefingsLibraryInitialAction.none,
    this.setUpBy = '',
    this.setUpRole = '',
  });

  final bool allowSelection;
  final bool isExamCompleted;
  final Set<String> initiallySelectedPaths;
  final ValueChanged<List<BriefingItem>>? onSelectionApplied;
  final String? title;
  final String? selectionActionLabel;
  final String? emptySelectionMessage;
  final BriefingsLibraryInitialAction initialAction;
  final String setUpBy;
  final String setUpRole;

  @override
  State<BriefingsLibrarySheet> createState() => _BriefingsLibrarySheetState();
}

class _BriefingsLibrarySheetState extends State<BriefingsLibrarySheet> {
  // ignore: non_constant_identifier_names
  _SheetColorPalette get _SheetColors => _SheetColorPalette(context);
  final SessionService _sessionService = SessionService();
  final BriefingsStorageService _storageService = BriefingsStorageService();
  final Set<String> _selectedPaths = <String>{};
  List<BriefingItem> _items = <BriefingItem>[];
  bool _loading = true;
  // bool _showGrid = false; // Commented out to resolve unused field compiler warning
  bool _operationInProgress = false;
  bool _initialActionHandled = false;

  @override
  void initState() {
    super.initState();
    _selectedPaths.addAll(widget.initiallySelectedPaths);
    _loadLibrary();
  }

  Future<void> _loadLibrary() async {
    final storedItems = await _sessionService.loadGlobalBriefingsLibrary();
    final items = <BriefingItem>[];
    var removedMissing = 0;
    for (final item in storedItems) {
      if (await File(item.path).exists()) {
        items.add(item);
      } else {
        removedMissing++;
      }
    }
    if (removedMissing > 0) {
      await _sessionService.saveGlobalBriefingsLibrary(items);
    }
    if (!mounted) return;
    setState(() {
      _items = items;
      _selectedPaths.removeWhere(
        (path) => !_items.any((item) => item.path == path),
      );
      _loading = false;
    });
    if (removedMissing > 0 && mounted) {
      _toast(
        'Files Removed',
        '$removedMissing Missing briefing files removed',
        Icons.delete_outline_rounded,
        NotificationType.warning,
      );
    }
    await _runInitialActionIfNeeded();
  }

  Future<void> _runInitialActionIfNeeded() async {
    if (_initialActionHandled || !mounted) return;
    _initialActionHandled = true;
    switch (widget.initialAction) {
      case BriefingsLibraryInitialAction.none:
        return;
      case BriefingsLibraryInitialAction.uploadPdf:
        await _uploadPdf();
        return;
      case BriefingsLibraryInitialAction.capturePhoto:
        await _capturePhoto();
        return;
    }
  }

  void _toast(String title, [String? subtitle, IconData? icon, NotificationType type = NotificationType.information]) {
    NotificationService.show(
      context,
      title: title,
      subtitle: subtitle,
      icon: icon ?? Icons.info_outline_rounded,
      type: type,
    );
  }

  Future<void> _saveLibrary(List<BriefingItem> items) async {
    await _sessionService.saveGlobalBriefingsLibrary(items);
    if (!mounted) return;
    setState(() {
      _items = items;
      _selectedPaths.removeWhere(
        (selectedPath) => !_items.any((item) => item.path == selectedPath),
      );
    });
  }

  Future<void> _runLibraryOperation(Future<void> Function() action) async {
    if (_operationInProgress) return;
    setState(() {
      _operationInProgress = true;
    });
    try {
      await action();
    } catch (e) {
      if (mounted) {
        _toast('Operation Failed', '', Icons.error_outline_rounded, NotificationType.error);
      }
    } finally {
      if (mounted) {
        setState(() {
          _operationInProgress = false;
        });
      }
    }
  }

  Future<void> _uploadPdf() async {
    await _runLibraryOperation(() async {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['pdf'],
      );
      if (result == null) return;

      final sourcePath = result.files.single.path;
      if (sourcePath == null || sourcePath.trim().isEmpty) return;

      final sourceName = result.files.single.name.trim();
      final fileName = sourceName.isEmpty
          ? path.basename(sourcePath)
          : sourceName;
      final copiedFile = await _storageService.persistFile(
        sourcePath: sourcePath,
        suggestedFileName: fileName,
      );

      final updated = <BriefingItem>[
        BriefingItem(
          type: BriefType.pdf,
          title: fileName,
          path: copiedFile.path,
          createdAt: DateTime.now(),
          uploadedBy: _currentUploader,
        ),
        ..._items,
      ];
      await _saveLibrary(updated);
      _toast('Upload Successful', 'PDF uploaded', Icons.check_circle_outline_rounded, NotificationType.success);
    });
  }

  Future<void> _capturePhoto() async {
    await _runLibraryOperation(() async {
      final image = await ImagePicker().pickImage(source: ImageSource.camera);
      if (image == null) return;

      final now = DateTime.now();
      String twoDigits(int n) => n.toString().padLeft(2, '0');
      final formattedTime = '${twoDigits(now.hour)}:${twoDigits(now.minute)}';

      final title = 'Captured photo · $formattedTime';
      final ext = path.extension(image.path);
      final suggestedName = 'Photo_${now.millisecondsSinceEpoch}$ext';

      final copiedFile = await _storageService.persistFile(
        sourcePath: image.path,
        suggestedFileName: suggestedName,
      );
      final updated = <BriefingItem>[
        BriefingItem(
          type: BriefType.photo,
          title: title,
          path: copiedFile.path,
          createdAt: now,
          uploadedBy: _currentUploader,
        ),
        ..._items,
      ];
      await _saveLibrary(updated);
      _toast('Capture Successful', 'Photo captured', Icons.camera_alt_outlined, NotificationType.success);
    });
  }

  Future<bool> _confirmDelete(BriefingItem item) async {
    final colors = _SheetColorPalette(context);
    final dangerColor = const Color(0xFFE85D73);
    final dangerSoftColor = const Color(0x33E85D73);

    final ok = await showDialog<bool>(
      context: context,
      barrierColor: Colors.black.withOpacity(0.72),
      builder: (ctx) {
        return Dialog(
          backgroundColor: Colors.transparent,
          insetPadding: const EdgeInsets.symmetric(horizontal: 8),
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: colors.panel,
              borderRadius: BorderRadius.circular(30),
              border: Border.all(
                color: colors.line.withOpacity(0.9),
                width: 1.2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.45),
                  blurRadius: 28,
                  offset: const Offset(0, 14),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      width: 58,
                      height: 58,
                      decoration: BoxDecoration(
                        color: dangerSoftColor,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(
                          color: dangerColor.withOpacity(0.55),
                          width: 1.2,
                        ),
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: dangerColor,
                        size: 30,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.only(top: 2),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Delete Briefing?',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(
                                color: colors.text,
                                fontSize: 26,
                                fontWeight: FontWeight.w800,
                                height: 1.08,
                              ),
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'This briefing will be removed from all exams and briefing lists',
                              style: TextStyle(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFD2DCE8)
                                    : colors.textSoft,
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                height: 1.42,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'This cannot be undone',
                              style: TextStyle(
                                color: Theme.of(context).brightness == Brightness.dark
                                    ? const Color(0xFFAEBCCC)
                                    : colors.textSoft.withOpacity(0.8),
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                height: 1.42,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 30),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        style: OutlinedButton.styleFrom(
                          minimumSize: const Size.fromHeight(58),
                          side: BorderSide(
                            color: colors.line.withOpacity(0.85),
                            width: 1.2,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            color: colors.blue,
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 16),
                    Expanded(
                      child: ElevatedButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: dangerColor,
                          foregroundColor: Colors.white,
                          elevation: 0,
                          minimumSize: const Size.fromHeight(58),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(22),
                          ),
                        ),
                        child: const Text(
                          'Delete',
                          style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
    return ok == true;
  }

  Future<void> _deleteBriefing(BriefingItem item) async {
    await _runLibraryOperation(() async {
      final shouldDelete = await _confirmDelete(item);
      if (!shouldDelete) return;

      final updated = _items.where((entry) => entry.path != item.path).toList();
      _selectedPaths.remove(item.path);
      await _saveLibrary(updated);

      try {
        final file = File(item.path);
        if (await file.exists()) {
          await file.delete();
        }
      } catch (_) {}

      _toast('Briefing Deleted', 'The briefing has been removed', Icons.delete_outline_rounded, NotificationType.success);
    });
  }

  Future<void> _shareBriefing(BriefingItem item) async {
    final xFile = XFile(item.path);
    await Share.shareXFiles([xFile], text: item.title);
  }

  void _openBriefing(BriefingItem item) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => FileViewerPage(
          path: item.path,
          isImage: item.type == BriefType.photo,
          fileName: item.title,
        ),
      ),
    );
  }

  // String _prettyDate(DateTime? date) {
  //   if (date == null) return '';
  //   final local = date.toLocal();
  //   String two(int n) => n.toString().padLeft(2, '0');
  //   return '${local.year}-${two(local.month)}-${two(local.day)} '
  //       '${two(local.hour)}:${two(local.minute)}';
  // }

  String get _currentUploader {
    if (widget.setUpBy.trim().isNotEmpty) {
      return widget.setUpBy.trim();
    } else if (widget.setUpRole.trim().isNotEmpty) {
      return widget.setUpRole.trim();
    } else {
      return "Exam Officer";
    }
  }

  String _formatSubtitle(BriefingItem item) {
    final uploader = item.uploadedBy ?? _currentUploader;

    if (item.createdAt == null) {
      return "Uploaded today · by $uploader";
    }
    final local = item.createdAt!.toLocal();
    final hourStr = local.hour.toString().padLeft(2, '0');
    final minStr = local.minute.toString().padLeft(2, '0');
    final timeStr = "$hourStr:$minStr";

    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final yesterday = today.subtract(const Duration(days: 1));
    final itemDate = DateTime(local.year, local.month, local.day);

    final String dayStr;
    if (itemDate == today) {
      dayStr = "today";
    } else if (itemDate == yesterday) {
      dayStr = "yesterday";
    } else {
      dayStr =
          "${local.year}-${local.month.toString().padLeft(2, '0')}-${local.day.toString().padLeft(2, '0')}";
    }

    return "Uploaded $dayStr · $timeStr · by $uploader";
  }

  void _toggleSelection(BriefingItem item) {
    if (!widget.allowSelection) {
      _openBriefing(item);
      return;
    }
    setState(() {
      if (_selectedPaths.contains(item.path)) {
        _selectedPaths.remove(item.path);
      } else {
        _selectedPaths.add(item.path);
      }
    });
  }

  void _applySelection() {
    final selected = _items
        .where((item) => _selectedPaths.contains(item.path))
        .toList(growable: false);
    final emptySelectionMessage = widget.emptySelectionMessage;
    if (selected.isEmpty && emptySelectionMessage != null) {
      _toast('Selection Empty', emptySelectionMessage, Icons.warning_amber_rounded, NotificationType.warning);
      return;
    }
    widget.onSelectionApplied?.call(selected);
    Navigator.pop(context);
  }

  // Widget _buildGridItem(BriefingItem item) {
  //   final isSelected = _selectedPaths.contains(item.path);
  //   final isPhoto = item.type == BriefType.photo;
  //
  //   return InkWell(
  //     onTap: () => _toggleSelection(item),
  //     borderRadius: BorderRadius.circular(12),
  //     child: Stack(
  //       children: [
  //         Container(
  //           decoration: BoxDecoration(
  //             borderRadius: BorderRadius.circular(12),
  //             color: _SheetColors.panel2,
  //             image: isPhoto
  //                 ? DecorationImage(
  //                     image: FileImage(File(item.path)),
  //                     fit: BoxFit.cover,
  //                   )
  //                 : null,
  //           ),
  //         ),
  //         if (!isPhoto)
  //           Center(
  //             child: Icon(
  //               Icons.picture_as_pdf,
  //               size: 44,
  //               color: Theme.of(context).brightness == Brightness.dark
  //                   ? Colors.white70
  //                   : Colors.black54,
  //             ),
  //           ),
  //         Positioned(
  //           left: 8,
  //           right: 8,
  //           bottom: 8,
  //           child: Container(
  //             padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
  //             decoration: BoxDecoration(
  //               borderRadius: BorderRadius.circular(8),
  //               color: Colors.black.withValues(alpha: 0.55),
  //             ),
  //             child: Text(
  //               item.title,
  //               maxLines: 2,
  //               overflow: TextOverflow.ellipsis,
  //               style: const TextStyle(color: Colors.white, fontSize: 12),
  //             ),
  //           ),
  //         ),
  //         Positioned(
  //           top: 6,
  //           right: 6,
  //           child: Row(
  //             mainAxisSize: MainAxisSize.min,
  //             children: [
  //               IconButton(
  //                 tooltip: 'Preview',
  //                 padding: EdgeInsets.zero,
  //                 visualDensity: VisualDensity(
  //                   horizontal: VisualDensity.minimumDensity,
  //                   vertical: VisualDensity.minimumDensity,
  //                 ),
  //                 onPressed: () => _openBriefing(item),
  //                 icon: const Icon(Icons.remove_red_eye, color: Colors.white),
  //               ),
  //               SizedBox(width: 8),
  //               IconButton(
  //                 tooltip: 'Delete',
  //                 padding: EdgeInsets.zero,
  //                 visualDensity: VisualDensity(
  //                   horizontal: VisualDensity.minimumDensity,
  //                   vertical: VisualDensity.minimumDensity,
  //                 ),
  //                 onPressed: () => _deleteBriefing(item),
  //                 icon: const Icon(Icons.delete, color: Colors.white),
  //               ),
  //             ],
  //           ),
  //         ),
  //         if (widget.allowSelection)
  //           Positioned(
  //             top: 9,
  //             left: 9,
  //             child: Icon(
  //               isSelected
  //                   ? Icons.check_circle_rounded
  //                   : Icons.radio_button_unchecked,
  //               color: isSelected ? kBlue : Colors.white70,
  //             ),
  //           ),
  //       ],
  //     ),
  //   );
  // }

  Widget _buildListItem(BriefingItem item) {
    final isSelected = _selectedPaths.contains(item.path);
    final isPhoto = item.type == BriefType.photo;
    final subtitle = _formatSubtitle(item);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: _SheetColors.panel2.withValues(alpha: .7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _SheetColors.lineSoft),
      ),
      child: Material(
        color: Colors.transparent,
        child: ListTile(
          onTap: () => _toggleSelection(item),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          leading: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: _SheetColors.blue.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: _SheetColors.blue.withValues(alpha: 0.4),
                width: 1,
              ),
            ),
            child: Icon(
              isPhoto ? Icons.image_outlined : Icons.picture_as_pdf_outlined,
              color: _SheetColors.blue,
              size: 22,
            ),
          ),
          title: Text(
            item.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              color: _SheetColors.text,
              fontWeight: FontWeight.w900,
              fontSize: 16,
            ),
          ),
          subtitle: Text(
            subtitle,
            style: TextStyle(
              color: _SheetColors.textSoft,
              fontSize: 13,
              fontWeight: FontWeight.w600,
            ),
          ),
          contentPadding: EdgeInsets.only(
            left: 16,
            top: 4,
            bottom: 4,
            right: widget.allowSelection ? 16 : 6,
          ),
          trailing: widget.allowSelection
              ? Icon(
                  isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  color: isSelected ? _SheetColors.blue : _SheetColors.textSoft,
                  size: 24,
                )
              : PopupMenuButton<String>(
                  icon: Icon(
                    Icons.more_vert_rounded,
                    color: _SheetColors.textSoft,
                    size: 24,
                  ),
                  color: _SheetColors.panel2,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: _SheetColors.lineSoft),
                  ),
                  onSelected: (value) {
                    if (value == 'open') {
                      _openBriefing(item);
                    } else if (value == 'share') {
                      _shareBriefing(item);
                    } else if (value == 'delete') {
                      _deleteBriefing(item);
                    }
                  },
                  itemBuilder: (context) => [
                    PopupMenuItem(
                      value: 'open',
                      child: Row(
                        children: [
                          Icon(
                            Icons.open_in_new_rounded,
                            size: 20,
                            color: _SheetColors.blueSoft,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Open',
                            style: TextStyle(
                              color: _SheetColors.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    PopupMenuItem(
                      value: 'share',
                      child: Row(
                        children: [
                          Icon(
                            Icons.share_rounded,
                            size: 20,
                            color: _SheetColors.blueSoft,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Share',
                            style: TextStyle(
                              color: _SheetColors.text,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const PopupMenuDivider(thickness: .2),
                    PopupMenuItem(
                      value: 'delete',
                      child: Row(
                        children: [
                          Icon(
                            Icons.delete_outline_rounded,
                            size: 20,
                            color: Colors.red.shade400,
                          ),
                          const SizedBox(width: 12),
                          Text(
                            'Delete',
                            style: TextStyle(
                              color: Colors.red.shade400,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _buildUploadPdfButton() {
    return AnimatedScaleOnPress(
      child: SizedBox(
        height: 44,
        child: FilledButton(
          style: FilledButton.styleFrom(
            backgroundColor: _SheetColors.blue,
            shape: StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          onPressed: _loading || _operationInProgress ? () {} : _uploadPdf,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 4,
            children: [
              const Icon(
                Icons.picture_as_pdf_outlined,
                color: Colors.white,
                size: 17,
              ),
              Flexible(
                child: Text(
                  "Upload PDF",
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                    color: Colors.white,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCapturePhotoButton() {
    return AnimatedScaleOnPress(
      child: SizedBox(
        height: 44,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: _SheetColors.lineSoft),
            backgroundColor: _SheetColors.panel2.withValues(alpha: .7),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          onPressed: _loading || _operationInProgress ? () {} : _capturePhoto,
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            spacing: 4,
            children: [
              Icon(
                Icons.photo_camera_outlined,
                color: _SheetColors.text,
                size: 17,
              ),
              Flexible(
                child: Text(
                  'Capture Photo',
                  softWrap: false,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    color: _SheetColors.blackWhite,
                    fontSize: 14,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // Widget _iconChipButton(
  //   IconData icon, {
  //   required VoidCallback onTap,
  //   String? tooltip,
  // }) {
  //   final button = GestureDetector(
  //     onTap: onTap,
  //     child: Container(
  //       width: 45,
  //       height: 45,
  //       decoration: BoxDecoration(
  //         color: _SheetColors.panel2,
  //         borderRadius: BorderRadius.circular(14),
  //         border: Border.all(color: _SheetColors.line),
  //       ),
  //       child: Icon(icon, size: 24),
  //     ),
  //   );
  //   if (tooltip == null) return button;
  //   return Tooltip(message: tooltip, child: button);
  // }

  Widget _utilityButton(String text, {required VoidCallback onTap}) {
    return AnimatedScaleOnPress(
      child: SizedBox(
        height: 44,
        child: OutlinedButton(
          style: OutlinedButton.styleFrom(
            side: BorderSide(color: _SheetColors.lineSoft),
            backgroundColor: _SheetColors.panel2.withValues(alpha: .7),
            shape: const StadiumBorder(),
            padding: const EdgeInsets.symmetric(horizontal: 10),
          ),
          onPressed: onTap,
          child: Text(
            text,
            softWrap: false,
            overflow: TextOverflow.ellipsis,
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: _SheetColors.blackWhite,
              fontWeight: FontWeight.w900,
            ),
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final title =
        widget.title ??
        (widget.allowSelection ? 'Select Briefings' : 'Briefings');
    final selectionActionLabel = widget.selectionActionLabel ?? 'Apply';

    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: BoxDecoration(
        color: _SheetColors.panel.withValues(alpha: 0.995),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        border: Border.all(
          color: _SheetColors.lineSoft.withValues(alpha: 0.55),
        ),
        boxShadow: const [
          BoxShadow(
            color: Colors.black54,
            blurRadius: 24,
            offset: Offset(0, -8),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: const BorderRadius.vertical(top: Radius.circular(30)),
        child: Scaffold(
          backgroundColor: Colors.transparent,
          body: SafeArea(
            child: Column(
              children: [
                const SizedBox(height: 14),
                Container(
                  width: 70,
                  height: 5,
                  decoration: BoxDecoration(
                    color: _SheetColors.lineSoft,
                    borderRadius: BorderRadius.circular(20),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    spacing: 8,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              title,
                              overflow: TextOverflow.ellipsis,
                              maxLines: 1,
                              style: TextStyle(
                                color: _SheetColors.text,
                                fontSize: 23,
                                fontWeight: FontWeight.w900,
                              ),
                            ),
                            Text(
                              "Exam setup documents and invigilator briefing references",
                              style: TextStyle(
                                color: _SheetColors.textSoft,
                                fontSize: 13.5,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ],
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.pop(context),
                        child: Container(
                          width: 45,
                          height: 45,
                          decoration: BoxDecoration(
                            color: _SheetColors.panel2,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(color: _SheetColors.line),
                          ),
                          child: Icon(
                            Icons.close_rounded,
                            color: _SheetColors.text,
                            size: 24,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                IgnorePointer(
                  ignoring: widget.isExamCompleted,
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 8, 20, 16),
                    child: Row(
                      spacing: 10,
                      children: [
                        Expanded(child: _buildUploadPdfButton()),
                        Expanded(child: _buildCapturePhotoButton()),
                      ],
                    ),
                  ),
                ),
                if (widget.allowSelection)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: Text(
                        'Selected: ${_selectedPaths.length}',
                        style: TextStyle(
                          color: _SheetColors.textSoft,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                if (!_loading && _items.isNotEmpty)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                      child: Text(
                        "UPLOADED BRIEFINGS",
                        style: TextStyle(
                          color: _SheetColors.blueSoft,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w900,
                          letterSpacing: 1.1,
                        ),
                      ),
                    ),
                  ),
                Expanded(
                  child: _loading
                      ? const Center(child: CircularProgressIndicator())
                      : _items.isEmpty
                      ? SingleChildScrollView(
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          child: Column(
                            children: [
                              Container(
                                width: double.infinity,
                                padding: const EdgeInsets.all(28),
                                decoration: BoxDecoration(
                                  color: _SheetColors.panel2.withValues(
                                    alpha: 0.7,
                                  ),
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _SheetColors.lineSoft,
                                  ),
                                ),
                                child: Column(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Container(
                                      width: 54,
                                      height: 54,
                                      decoration: BoxDecoration(
                                        color: _SheetColors.blue.withValues(
                                          alpha: 0.15,
                                        ),
                                        borderRadius: BorderRadius.circular(16),
                                        border: Border.all(
                                          color: _SheetColors.blue.withValues(
                                            alpha: 0.4,
                                          ),
                                          width: 1,
                                        ),
                                      ),
                                      child: Icon(
                                        Icons.folder_open_outlined,
                                        color: _SheetColors.blue,
                                        size: 26,
                                      ),
                                    ),
                                    const SizedBox(height: 18),
                                    Text(
                                      "No Additional Briefings",
                                      style: TextStyle(
                                        color: _SheetColors.text,
                                        fontSize: 18,
                                        fontWeight: FontWeight.w900,
                                      ),
                                    ),
                                    const SizedBox(height: 10),
                                    Text(
                                      "Upload setup sheets, seating plans, room instructions or invigilator guidance documents.",
                                      textAlign: TextAlign.center,
                                      style: TextStyle(
                                        color: _SheetColors.textSoft,
                                        fontSize: 13.5,
                                        height: 1.4,
                                        fontWeight: FontWeight.w600,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              /*const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                                decoration: BoxDecoration(
                                  color: _SheetColors.blue.withValues(
                                    alpha: .15,
                                  ),
                                  borderRadius: BorderRadius.circular(16),
                                  border: Border.all(
                                    color: _SheetColors.blueSoft.withValues(
                                      alpha: .4,
                                    ),
                                  ),
                                ),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.info_outline_rounded,
                                      color: _SheetColors.blueSoft,
                                      size: 18,
                                    ),
                                    const SizedBox(width: 12),
                                    Expanded(
                                      child: Text(
                                        "Briefings remain linked to the exam session and can be referenced later during export or audit review.",
                                        style: TextStyle(
                                          color: _SheetColors.blueSoft,
                                          fontSize: 12.5,
                                          height: 1.4,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),*/
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                          itemCount: _items.length,
                          itemBuilder: (context, index) =>
                              _buildListItem(_items[index]),
                        ),
                ),
                if (widget.allowSelection)
                  SafeArea(
                    top: false,
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: Row(
                        children: [
                          Expanded(
                            child: _utilityButton(
                              'Cancel',
                              onTap: () => Navigator.pop(context),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: AnimatedScaleOnPress(
                              child: SizedBox(
                                height: 44,
                                child: FilledButton(
                                  style: FilledButton.styleFrom(
                                    backgroundColor: _SheetColors.blue,
                                    foregroundColor: Colors.white,
                                    shape: const StadiumBorder(),
                                  ),
                                  onPressed: _applySelection,
                                  child: Text(
                                    selectionActionLabel,
                                    style: const TextStyle(
                                      fontSize: 14,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
