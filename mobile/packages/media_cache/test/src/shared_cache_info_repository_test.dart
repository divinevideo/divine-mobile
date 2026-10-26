import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('createSharedCacheInfoRepository', () {
    const pathChannel = MethodChannel('plugins.flutter.io/path_provider');
    late Directory directory;

    setUp(() async {
      directory = await Directory.systemTemp.createTemp('shared_image_index_');
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, (_) async => directory.path);
      sqfliteFfiInit();
      databaseFactory = databaseFactoryFfi;
    });

    tearDown(() async {
      debugDefaultTargetPlatformOverride = null;
      databaseFactory = null;
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(pathChannel, null);
      await directory.delete(recursive: true);
    });

    for (final platform in [
      TargetPlatform.android,
      TargetPlatform.iOS,
      TargetPlatform.macOS,
    ]) {
      test('commits background rows before returning on $platform', () async {
        debugDefaultTargetPlatformOverride = platform;
        final foreground = createSharedCacheInfoRepository('images');
        final background = createSharedCacheInfoRepository('images');
        final reopened = createSharedCacheInfoRepository('images');
        addTearDown(() async {
          await reopened.close();
          await background.close();
          await foreground.close();
        });
        await foreground.open();
        await background.open();
        await background.insert(
          CacheObject(
            'https://example.com/background.jpg',
            key: 'background',
            relativePath: 'background.jpg',
            validTill: DateTime.utc(2030),
          ),
        );
        // Read before any debounce timer or close can flush the writer.
        await reopened.open();
        expect(
          (await reopened.get('background'))?.relativePath,
          'background.jpg',
        );
        expect(
          (await foreground.get('background'))?.relativePath,
          'background.jpg',
        );
        await foreground.insert(
          CacheObject(
            'https://example.com/foreground.jpg',
            key: 'foreground',
            relativePath: 'foreground.jpg',
            validTill: DateTime.utc(2030),
          ),
        );
        expect(await background.get('foreground'), isNotNull);
        expect(await reopened.getAllObjects(), hasLength(2));
      });
    }

    test('retains the desktop JSON corruption-recovery repository', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final repository = createSharedCacheInfoRepository('desktop');
      expect(repository, isA<SafeCacheInfoRepository>());
      // No open means there is no repository connection or timer to close.
    });
  });
}
