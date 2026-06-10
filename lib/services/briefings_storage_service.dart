import 'dart:io';

import 'package:path/path.dart' as path;
import 'package:path_provider/path_provider.dart';

import '../utils/id_generator.dart';

typedef DocumentsDirectoryProvider = Future<Directory> Function();

class BriefingsStorageService {
  BriefingsStorageService({
    DocumentsDirectoryProvider? documentsDirectoryProvider,
    String libraryFolderName = 'briefings_library',
  }) : _documentsDirectoryProvider =
           documentsDirectoryProvider ?? getApplicationDocumentsDirectory,
       _libraryFolderName = libraryFolderName;

  final DocumentsDirectoryProvider _documentsDirectoryProvider;
  final String _libraryFolderName;

  String safeFileName(String name) {
    final sanitized = name.replaceAll(RegExp(r'[^A-Za-z0-9._-]'), '_').trim();
    if (sanitized.isNotEmpty) return sanitized;
    return 'briefing_file';
  }

  Future<Directory> getLibraryDirectory() async {
    final appDir = await _documentsDirectoryProvider();
    final libraryDir = Directory(path.join(appDir.path, _libraryFolderName));
    if (!await libraryDir.exists()) {
      await libraryDir.create(recursive: true);
    }
    return libraryDir;
  }

  Future<File> persistFile({
    required String sourcePath,
    required String suggestedFileName,
  }) async {
    final source = File(sourcePath);
    if (!await source.exists()) {
      throw FileSystemException('Source file does not exist', sourcePath);
    }

    final libraryDir = await getLibraryDirectory();
    final normalizedName = safeFileName(suggestedFileName);
    final extension = path.extension(normalizedName);
    final baseName = path.basenameWithoutExtension(normalizedName);
    final safeBase = baseName.isEmpty ? 'briefing_file' : baseName;

    for (var attempts = 0; attempts < 8; attempts++) {
      final uniquePart =
          '${DateTime.now().microsecondsSinceEpoch}_${generateId()}';
      final targetName = extension.isEmpty
          ? '${safeBase}_$uniquePart'
          : '${safeBase}_$uniquePart$extension';
      final targetPath = path.join(libraryDir.path, targetName);
      final targetFile = File(targetPath);
      if (await targetFile.exists()) {
        continue;
      }
      final copied = await source.copy(targetPath);
      return copied.absolute;
    }

    throw FileSystemException(
      'Unable to allocate a unique file name for briefing copy',
      sourcePath,
    );
  }
}
