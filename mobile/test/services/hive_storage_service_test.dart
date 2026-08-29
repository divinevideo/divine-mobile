// ABOUTME: Pins Hive's home path to one directory regardless of open order
// ABOUTME: Covers migration of boxes stranded in the legacy documents directory

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce/hive.dart';
import 'package:openvine/constants/hive_box_names.dart';
import 'package:openvine/services/hive_storage_service.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:plugin_platform_interface/plugin_platform_interface.dart';

class _FakePathProviderPlatform extends Fake
    with MockPlatformInterfaceMixin
    implements PathProviderPlatform {
  _FakePathProviderPlatform({
    required this.documentsPath,
    required this.appSupportPath,
  });

  final String documentsPath;
  final String appSupportPath;

  @override
  Future<String?> getApplicationDocumentsPath() async => documentsPath;

  @override
  Future<String?> getApplicationSupportPath() async => appSupportPath;
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(HiveStorageService, () {
    late Directory root;
    late Directory documentsDir;
    late Directory appSupportDir;
    late String homePath;
    late PathProviderPlatform originalPathProvider;

    setUp(() async {
      originalPathProvider = PathProviderPlatform.instance;
      addTearDown(() {
        PathProviderPlatform.instance = originalPathProvider;
        HiveStorageService.resetForTesting();
      });

      // A box another suite left open short-circuits `Hive.openBox`, which
      // returns the registered box without consulting the home path — these
      // assertions would then read a stale location. Hive unregisters a box
      // before its backend close, so a missing prior home can be tolerated
      // without hiding other close failures.
      try {
        await Hive.close();
      } on FileSystemException {
        // The stale box is already out of Hive's registry.
      }

      root = await Directory.systemTemp.createTemp('hive_storage_service_');
      documentsDir = await Directory(
        p.join(root.path, 'Documents'),
      ).create(recursive: true);
      appSupportDir = await Directory(
        p.join(root.path, 'app_support'),
      ).create(recursive: true);
      homePath = p.join(
        appSupportDir.path,
        HiveStorageService.homeDirectoryName,
      );

      PathProviderPlatform.instance = _FakePathProviderPlatform(
        documentsPath: documentsDir.path,
        appSupportPath: appSupportDir.path,
      );

      HiveStorageService.resetForTesting();
    });

    tearDown(() async {
      try {
        await Hive.close();
      } finally {
        // close() leaves the home path pointing at the directory deleted below,
        // and resetForTesting() only clears this service's own latch.
        Hive.init(null);
        if (root.existsSync()) root.deleteSync(recursive: true);
      }
    });

    test('opens boxes under the Application Support home directory', () async {
      await HiveStorageService.initialize();

      final box = await Hive.openBox<dynamic>(HiveBoxNames.notifications);

      expect(p.dirname(box.path!), homePath);
    });

    test('repeat initialization does not reassign the home path', () async {
      await HiveStorageService.initialize();
      final firstBox = await Hive.openBox<dynamic>(HiveBoxNames.notifications);

      final elsewhere = await Directory(
        p.join(root.path, 'elsewhere'),
      ).create(recursive: true);
      PathProviderPlatform.instance = _FakePathProviderPlatform(
        documentsPath: elsewhere.path,
        appSupportPath: elsewhere.path,
      );

      await HiveStorageService.initialize();
      final secondBox = await Hive.openBox<dynamic>(HiveBoxNames.hashtagStats);

      expect(p.dirname(secondBox.path!), p.dirname(firstBox.path!));
    });

    test(
      'moves a box stranded in the documents directory into the home',
      () async {
        _writeBoxFile(documentsDir, HiveBoxNames.notifications, 'stranded');

        await HiveStorageService.initialize();

        expect(
          _readBoxFile(Directory(homePath), HiveBoxNames.notifications),
          'stranded',
        );
        expect(
          _boxFile(documentsDir, HiveBoxNames.notifications).existsSync(),
          isFalse,
        );
      },
    );

    test('keeps the more recently written copy of a split box', () async {
      const boxName = HiveBoxNames.pushNotificationPreferencesDirty;
      await Directory(homePath).create(recursive: true);

      _writeBoxFile(
        documentsDir,
        boxName,
        'documents',
        modified: DateTime(2026, 8, 12),
      );
      _writeBoxFile(
        Directory(homePath),
        boxName,
        'home',
        modified: DateTime(2026, 8, 10),
      );

      await HiveStorageService.initialize();

      expect(_readBoxFile(Directory(homePath), boxName), 'documents');
      expect(_boxFile(documentsDir, boxName).existsSync(), isFalse);
    });

    test('drops the stranded copy when the home copy is newer', () async {
      const boxName = HiveBoxNames.pushNotificationPreferencesDirty;
      await Directory(homePath).create(recursive: true);

      _writeBoxFile(
        documentsDir,
        boxName,
        'documents',
        modified: DateTime(2026, 8, 10),
      );
      _writeBoxFile(
        Directory(homePath),
        boxName,
        'home',
        modified: DateTime(2026, 8, 12),
      );

      await HiveStorageService.initialize();

      expect(_readBoxFile(Directory(homePath), boxName), 'home');
      expect(_boxFile(documentsDir, boxName).existsSync(), isFalse);
    });

    test('keeps the home copy when the newer stranded one is empty', () async {
      const boxName = HiveBoxNames.pushNotificationPreferencesDirty;
      await Directory(homePath).create(recursive: true);

      // Opening a box read-only creates a 0-byte file, so the stranded side
      // ends up newer than the home copy without ever holding data.
      _writeBoxFile(documentsDir, boxName, '', modified: DateTime(2026, 8, 12));
      _writeBoxFile(
        Directory(homePath),
        boxName,
        'home',
        modified: DateTime(2026, 8, 10),
      );

      await HiveStorageService.initialize();

      expect(_readBoxFile(Directory(homePath), boxName), 'home');
      expect(_boxFile(documentsDir, boxName).existsSync(), isFalse);
    });

    test('takes the stranded copy when the newer home one is empty', () async {
      const boxName = HiveBoxNames.pushNotificationPreferencesDirty;
      await Directory(homePath).create(recursive: true);

      _writeBoxFile(
        documentsDir,
        boxName,
        'documents',
        modified: DateTime(2026, 8, 10),
      );
      _writeBoxFile(
        Directory(homePath),
        boxName,
        '',
        modified: DateTime(2026, 8, 12),
      );

      await HiveStorageService.initialize();

      expect(_readBoxFile(Directory(homePath), boxName), 'documents');
      expect(_boxFile(documentsDir, boxName).existsSync(), isFalse);
    });

    test('falls back to mtime when both copies are empty', () async {
      const boxName = HiveBoxNames.pushNotificationPreferencesDirty;
      await Directory(homePath).create(recursive: true);

      _writeBoxFile(documentsDir, boxName, '', modified: DateTime(2026, 8, 12));
      _writeBoxFile(
        Directory(homePath),
        boxName,
        '',
        modified: DateTime(2026, 8, 10),
      );

      await HiveStorageService.initialize();

      expect(
        _boxFile(Directory(homePath), boxName).lastModifiedSync(),
        DateTime(2026, 8, 12),
      );
      expect(_boxFile(documentsDir, boxName).existsSync(), isFalse);
    });

    test('rescues a stranded box left only as a compacted copy', () async {
      const boxName = HiveBoxNames.notifications;
      _writeCompactedBoxFile(documentsDir, boxName, 'compacted');

      await HiveStorageService.initialize();

      expect(_readBoxFile(Directory(homePath), boxName), 'compacted');
      expect(_compactedBoxFile(documentsDir, boxName).existsSync(), isFalse);
    });

    test('leaves no compacted leftover in the legacy home', () async {
      const boxName = HiveBoxNames.pushNotificationPreferencesDirty;
      await Directory(homePath).create(recursive: true);

      // A crashed compaction leaves the compacted copy beside the box file
      // Hive still prefers, on whichever side of the split it happened.
      _writeBoxFile(
        documentsDir,
        boxName,
        'documents',
        modified: DateTime(2026, 8, 10),
      );
      _writeCompactedBoxFile(documentsDir, boxName, 'documents compacted');
      _writeBoxFile(
        Directory(homePath),
        boxName,
        'home',
        modified: DateTime(2026, 8, 12),
      );

      await HiveStorageService.initialize();

      expect(_readBoxFile(Directory(homePath), boxName), 'home');
      expect(_boxFile(documentsDir, boxName).existsSync(), isFalse);
      expect(_compactedBoxFile(documentsDir, boxName).existsSync(), isFalse);
    });

    test('removes stranded lock files', () async {
      final lockFile = File(
        p.join(documentsDir.path, '${HiveBoxNames.notifications}.lock'),
      )..writeAsStringSync('');

      await HiveStorageService.initialize();

      expect(lockFile.existsSync(), isFalse);
    });

    group('retired boxes', () {
      // personal_events / personal_events_metadata moved to Drift in #6986.
      // They are out of HiveBoxNames.all, so the stranded-box sweep no longer
      // walks them and they have to be deleted explicitly — from both homes,
      // because a pre-#6958 build could have left a copy in documents.
      for (final boxName in const [
        'personal_events',
        'personal_events_metadata',
      ]) {
        test('deletes a retired $boxName left in the home', () async {
          final home = Directory(homePath)..createSync(recursive: true);
          _writeBoxFile(home, boxName, 'retired');
          _writeCompactedBoxFile(home, boxName, 'retired compacted');
          final lockFile = File(p.join(home.path, '$boxName.lock'))
            ..writeAsStringSync('');

          await HiveStorageService.initialize();

          expect(_boxFile(home, boxName).existsSync(), isFalse);
          expect(_compactedBoxFile(home, boxName).existsSync(), isFalse);
          expect(lockFile.existsSync(), isFalse);
        });

        test('deletes a retired $boxName stranded in documents', () async {
          _writeBoxFile(documentsDir, boxName, 'stranded retired');

          await HiveStorageService.initialize();

          expect(_boxFile(documentsDir, boxName).existsSync(), isFalse);
          expect(
            _boxFile(Directory(homePath), boxName).existsSync(),
            isFalse,
            reason: 'a retired box must not be migrated into the home',
          );
        });
      }

      test('leaves live boxes alone', () async {
        _writeBoxFile(documentsDir, HiveBoxNames.notifications, 'live');

        await HiveStorageService.initialize();

        expect(
          _readBoxFile(Directory(homePath), HiveBoxNames.notifications),
          'live',
        );
      });
    });
  });
}

File _boxFile(Directory dir, String boxName) =>
    File(p.join(dir.path, '$boxName.hive'));

/// Where compaction writes the compacted box before renaming it over the box
/// file, and what Hive restores from when the box file is missing.
File _compactedBoxFile(Directory dir, String boxName) =>
    File(p.join(dir.path, '$boxName.hivec'));

void _writeCompactedBoxFile(Directory dir, String boxName, String contents) =>
    _compactedBoxFile(dir, boxName).writeAsStringSync(contents);

void _writeBoxFile(
  Directory dir,
  String boxName,
  String contents, {
  DateTime? modified,
}) {
  final file = _boxFile(dir, boxName)..writeAsStringSync(contents);
  if (modified != null) file.setLastModifiedSync(modified);
}

String _readBoxFile(Directory dir, String boxName) =>
    _boxFile(dir, boxName).readAsStringSync();
