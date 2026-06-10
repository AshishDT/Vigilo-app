import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_pdfview/flutter_pdfview.dart';

class FileViewerPage extends StatelessWidget {
  final String path;
  final bool isImage;
  final String fileName;

  const FileViewerPage({
    super.key,
    required this.path,
    required this.fileName,
    required this.isImage,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(fileName)),
      body: isImage
          ? InteractiveViewer(
              panEnabled: true,
              minScale: 1,
              maxScale: 4,
              child: Center(
                child: Image.file(
                  File(path),
                  fit: BoxFit.contain,
                  width: double.infinity,
                  height: double.infinity,
                ),
              ),
            )
          : PDFView(filePath: path),
    );
  }
}
