import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as path;
import 'package:sqflite_common_ffi/sqflite_ffi.dart';
import 'package:vigilo/enums/brief_type.dart';
import 'package:vigilo/models/briefing_model.dart';
import 'package:vigilo/services/briefings_storage_service.dart';
import 'package:vigilo/services/session_service.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Briefings photo persistence', () {
    late Directory sandboxRoot;
    late Directory dbDir;
    late Directory docsDir;
    late BriefingsStorageService storageService;

    setUpAll(() async {
      sandboxRoot = await Directory.systemTemp.createTemp(
        'vigilo_briefings_persistence_',
      );
      dbDir = Directory(path.join(sandboxRoot.path, 'db'));
      docsDir = Directory(path.join(sandboxRoot.path, 'docs'));
      await dbDir.create(recursive: true);
      await docsDir.create(recursive: true);

      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
      await databaseFactory.setDatabasesPath(dbDir.path);

      final databaseFile = File(path.join(dbDir.path, 'vigilo_exam_logger.db'));
      if (await databaseFile.exists()) {
        await databaseFile.delete();
      }

      storageService = BriefingsStorageService(
        documentsDirectoryProvider: () async => docsDir,
      );
    });

    test(
      'captures 3+ photos without overwrite and survives restart reload',
      () async {
        final sourceFiles = <File>[];
        for (var i = 0; i < 3; i++) {
          final source = File(
            path.join(sandboxRoot.path, 'source_photo_$i.jpg'),
          );
          await source.writeAsBytes(List<int>.filled(64, i + 1), flush: true);
          sourceFiles.add(source);
        }

        final copiedFiles = <File>[];
        for (final source in sourceFiles) {
          final persisted = await storageService.persistFile(
            sourcePath: source.path,
            suggestedFileName: 'captured_photo.jpg',
          );
          copiedFiles.add(persisted);
        }

        final copiedPaths = copiedFiles.map((file) => file.path).toList();
        expect(copiedPaths.toSet().length, 3);

        for (var i = 0; i < copiedFiles.length; i++) {
          expect(await copiedFiles[i].exists(), isTrue);
          expect(
            await copiedFiles[i].readAsBytes(),
            sourceFiles[i].readAsBytesSync(),
          );
        }

        final saveService = SessionService();
        await saveService.saveGlobalBriefingsLibrary([
          for (var i = 0; i < copiedFiles.length; i++)
            BriefingItem(
              type: BriefType.photo,
              title: 'Capture ${i + 1}',
              path: copiedFiles[i].path,
              createdAt: DateTime.now().subtract(Duration(seconds: i)),
            ),
        ]);

        final restartService = SessionService();
        final loaded = await restartService.loadGlobalBriefingsLibrary();

        expect(loaded.length, 3);
        expect(loaded.map((item) => item.path).toSet().length, 3);

        for (final item in loaded) {
          final file = File(item.path);
          expect(await file.exists(), isTrue);
          final bytes = await file.readAsBytes();
          expect(bytes, isNotEmpty);
        }
      },
    );
  });
}
