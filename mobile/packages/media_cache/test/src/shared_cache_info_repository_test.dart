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

    test(
      'manager reads disk after initialization, sweeps, and account cleanup',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final repository = createSharedCacheInfoRepository('manager_images');
        final manager = MediaCacheManager(
          config: const MediaCacheConfig(
            cacheKey: 'manager_images',
            enableSyncManifest: true,
          ),
          repoOverride: repository,
          tempDirectoryProvider: () async => directory,
        );
        addTearDown(manager.close);
        const url = 'https://example.com/avatar.jpg';
        final bytes = Uint8List.fromList([1, 2, 3]);
        final file = await manager.putFile(url, bytes, key: 'avatar');
        await manager.initialize();
        expect(manager.getCachedFileSync('avatar')?.path, file.path);
        await manager.enforceCacheLimits(force: true);
        final cached = await manager.getFileFromCache(
          'avatar',
          ignoreMemCache: true,
        );
        expect(cached, isNotNull);
        expect(await cached!.file.readAsBytes(), bytes);

        // This is the disk-cache operation used by account-switch cleanup.
        await manager.clearCache();
        expect(await repository.getAllObjects(), isEmpty);
        expect(manager.getCachedFileSync('avatar'), isNull);
        expect(
          await manager.getFileFromCache('avatar', ignoreMemCache: true),
          isNull,
        );
        final replacement = Uint8List.fromList([4, 5, 6]);
        await manager.putFile(url, replacement, key: 'avatar');
        await manager.enforceCacheLimits(force: true);
        final reused = await manager.getFileFromCache(
          'avatar',
          ignoreMemCache: true,
        );
        expect(reused, isNotNull);
        expect(await reused!.file.readAsBytes(), replacement);
      },
    );

    test(
      'keeps serving rows after a cache sweep closes its own connection',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final repository = createSharedCacheInfoRepository('images');
        // The cache store's connection, held for the manager's whole life.
        await repository.open();
        addTearDown(repository.close);
        final cached = CacheObject(
          'https://example.com/avatar.jpg',
          key: 'avatar',
          relativePath: 'avatar.jpg',
          validTill: DateTime.utc(2030),
        );
        await repository.insert(cached);
        // MediaCacheManager.enforceCacheLimits leases its own connection.
        await repository.open();
        expect(await repository.getAllObjects(), hasLength(1));
        await repository.close();
        expect((await repository.get('avatar'))?.relativePath, 'avatar.jpg');
        await repository.insert(
          CacheObject(
            'https://example.com/banner.jpg',
            key: 'banner',
            relativePath: 'banner.jpg',
            validTill: DateTime.utc(2030),
          ),
        );
        expect(await repository.getAllObjects(), hasLength(2));
      },
    );

    test('retains the desktop JSON corruption-recovery repository', () async {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      final repository = createSharedCacheInfoRepository('desktop');
      expect(repository, isA<SafeCacheInfoRepository>());
      // No open means there is no repository connection or timer to close.
    });

    test(
      'recreates an unreadable native index before serving images',
      () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        final database = File('${directory.path}/images.db');
        await database.writeAsString('not a SQLite database');
        final media = File('${directory.path}/thumbnail.jpg');
        await media.writeAsBytes([1, 2, 3]);
        final unrelated = File('${directory.path}/other.db');
        await unrelated.writeAsString('unrelated index');
        final repository = createSharedCacheInfoRepository('images');
        await repository.open();
        addTearDown(repository.close);
        expect(await repository.getAllObjects(), isEmpty);
        await repository.insert(
          CacheObject(
            'https://example.com/recovered.jpg',
            key: 'recovered',
            relativePath: 'recovered.jpg',
            validTill: DateTime.utc(2030),
          ),
        );
        expect(
          (await repository.get('recovered'))?.relativePath,
          'recovered.jpg',
        );
        expect(await media.readAsBytes(), [1, 2, 3]);
        expect(await unrelated.readAsString(), 'unrelated index');
      },
    );
  });
}
