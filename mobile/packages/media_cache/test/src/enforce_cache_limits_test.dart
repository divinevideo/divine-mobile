import 'dart:async';
import 'dart:io';

import 'package:clock/clock.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';
import 'package:unified_logger/unified_logger.dart';

import 'helpers/mocks.dart';
import 'helpers/test_helpers.dart';

void main() {
  setUpTestEnvironment();

  group('MediaCacheManager.enforceCacheLimits', () {
    late MockCacheInfoRepository repo;

    setUpAll(() async {
      await setUpTestDirectories();
      registerFallbackValue(<int>[]);
      registerFallbackValue(
        CacheObject('u', relativePath: 'r', validTill: DateTime(2099)),
      );
    });

    tearDownAll(() async {
      await tearDownTestDirectories();
    });

    setUp(() {
      repo = MockCacheInfoRepository();
      when(repo.open).thenAnswer((_) async => true);
      when(repo.close).thenAnswer((_) async => true);
      when(() => repo.deleteAll(any())).thenAnswer((_) async => 0);
    });

    (MediaCacheManager, Directory) build({int? maxCacheSizeBytes}) {
      final cacheKey = 'enforce_${DateTime.now().microsecondsSinceEpoch}';
      final dir = Directory('$testTempPath/$cacheKey')
        ..createSync(recursive: true);
      final manager = MediaCacheManager(
        config: MediaCacheConfig(
          cacheKey: cacheKey,
          enableSyncManifest: true,
          maxCacheSizeBytes: maxCacheSizeBytes,
        ),
        repoOverride: repo,
      );
      return (manager, dir);
    }

    // Files are written with an old mtime by default so they sit outside the
    // reclamation freshness window — leaked orphans in the wild are old.
    // Pass [modified] to model a freshly-written file.
    File writeFile(
      Directory dir,
      String name,
      int bytes, {
      DateTime? modified,
    }) {
      return File('${dir.path}/$name')
        ..writeAsBytesSync(List<int>.filled(bytes, 0))
        ..setLastModifiedSync(modified ?? DateTime(2020));
    }

    CacheObject obj(String relativePath, {int? id, DateTime? touched}) {
      return CacheObject(
        'https://example.com/$relativePath',
        key: 'key_$relativePath',
        relativePath: relativePath,
        validTill: DateTime(2099),
        id: id,
        touched: touched,
      );
    }

    test('reclaims untracked managed-pattern files, keeps everything '
        'else', () async {
      final (manager, dir) = build();
      final tracked = writeFile(dir, 'vid_key_100_1.mp4', 10);
      final orphan = writeFile(dir, 'vid_key_200_2.mp4', 10);
      final seedVideo = writeFile(dir, 'a1b2c3d4e5f6', 10);
      final seedThumb = writeFile(dir, 'thumbnail_a1b2c3.jpg', 10);
      final aliases = writeFile(dir, 'aliases.json', 10);
      final nested = Directory('${dir.path}/nested')..createSync();
      final nestedManagedName = writeFile(nested, 'nested_300_3.mp4', 10);

      when(repo.getAllObjects).thenAnswer(
        (_) async => [obj('vid_key_100_1.mp4', id: 1)],
      );

      await manager.enforceCacheLimits();

      expect(orphan.existsSync(), isFalse, reason: 'untracked orphan removed');
      expect(tracked.existsSync(), isTrue, reason: 'tracked file kept');
      expect(seedVideo.existsSync(), isTrue, reason: 'seed video kept');
      expect(seedThumb.existsSync(), isTrue, reason: 'seed thumbnail kept');
      expect(aliases.existsSync(), isTrue, reason: 'alias manifest kept');
      expect(nested.existsSync(), isTrue, reason: 'subdirectory kept');
      expect(
        nestedManagedName.existsSync(),
        isTrue,
        reason: 'caller-owned subdirectories are not reclaimed by pattern',
      );
    });

    // Before `_extensionFor` gained its usable-extension guard (#7364), the
    // extension was `path.extension` of a percent-decoded URL segment,
    // verbatim. An image proxied through
    // `…/https%3A%2F%2Fbucket%2Fx.png%3Fv%3D2` therefore cached as
    // `…_<micros>_<seq>.png?v=2`. Writes have carried a 16-digit microsecond
    // epoch since 2001.
    const legacyMicros = '1723600000000000';

    test('reclaims untracked orphans whose extension came from a pre-cap '
        'URL tail', () async {
      final (manager, dir) = build();
      final query = writeFile(dir, 'img_key_${legacyMicros}_4.png?v=2', 10);
      final spaced = writeFile(dir, 'img_key_${legacyMicros}_5.jpg (1)', 10);
      final bareDot = writeFile(dir, 'img_key_${legacyMicros}_6.', 10);

      when(repo.getAllObjects).thenAnswer((_) async => []);

      await manager.enforceCacheLimits();

      expect(
        query.existsSync(),
        isFalse,
        reason: 'a query string after the dot no longer strands the file',
      );
      expect(
        spaced.existsSync(),
        isFalse,
        reason: 'any non-extension tail is reclaimable, not just query ones',
      );
      expect(
        bareDot.existsSync(),
        isFalse,
        reason: 'a segment ending in a dot wrote an empty extension',
      );
    });

    test('keeps externally-owned files that resemble a pre-cap name', () async {
      final (manager, dir) = build();
      final aliases = writeFile(dir, 'aliases.json', 10);
      final aliasesTmp = writeFile(dir, 'aliases.json.tmp', 10);
      final seedThumb = writeFile(dir, 'thumbnail_${'a1b2c3d4' * 8}.jpg', 10);
      final seedMarker = writeFile(dir, '.seed_media_loaded', 10);
      // Two digit runs and a multi-part tail, but four digits cannot be a
      // microsecond epoch, so this is not one of our writes.
      final shortInfix = writeFile(dir, 'report_2024_01.csv.gz', 10);

      when(repo.getAllObjects).thenAnswer((_) async => []);

      await manager.enforceCacheLimits();

      expect(aliases.existsSync(), isTrue, reason: 'alias manifest kept');
      expect(aliasesTmp.existsSync(), isTrue, reason: 'alias temp file kept');
      expect(seedThumb.existsSync(), isTrue, reason: 'seed thumbnail kept');
      expect(
        seedMarker.existsSync(),
        isTrue,
        reason: 'SeedMediaCleanupService retries off this marker',
      );
      expect(
        shortInfix.existsSync(),
        isTrue,
        reason: 'a short digit infix is not a microsecond timestamp',
      );
    });

    test('keeps a tracked pre-cap file, which is still a live entry', () async {
      final (manager, dir) = build();
      const name = 'img_key_${legacyMicros}_4.png?v=2';
      final tracked = writeFile(dir, name, 10);

      when(repo.getAllObjects).thenAnswer((_) async => [obj(name, id: 1)]);

      await manager.enforceCacheLimits();

      expect(
        tracked.existsSync(),
        isTrue,
        reason: 'the store still serves this file; reclamation is for orphans',
      );
    });

    test('evicts a tracked pre-cap file to converge on the byte '
        'budget', () async {
      final (manager, dir) = build(maxCacheSizeBytes: 50);
      const name = 'img_key_${legacyMicros}_4.png?v=2';
      final tracked = writeFile(dir, name, 60);

      when(repo.getAllObjects).thenAnswer(
        (_) async => [obj(name, id: 1, touched: DateTime(2020))],
      );

      await manager.enforceCacheLimits();

      expect(tracked.existsSync(), isFalse);
      final captured =
          verify(() => repo.deleteAll(captureAny())).captured.single as List;
      expect(captured, equals(<int>[1]));
    });

    test('releases the repository lease after each sweep', () async {
      when(repo.getAllObjects).thenAnswer((_) async => []);
      final (manager, _) = build();

      await manager.enforceCacheLimits(force: true);

      // CacheStore owns the first open for the manager lifetime; the sweep's
      // second open is the lease that must be released here.
      verify(repo.open).called(2);
      verify(repo.close).called(1);
    });

    test('reclaims aged uuid-named orphans from the inherited '
        'downloadFile path', () async {
      final (manager, dir) = build();
      final uuidVideo = writeFile(
        dir,
        '1b4e28ba-2fa1-11d2-883f-0016d3cca427.mp4',
        10,
      );
      final uuidPartial = writeFile(
        dir,
        '5c0e8de0-4f9a-11ee-a3b2-0242ac120002.file',
        10,
      );
      final seedVideo = writeFile(dir, 'a1b2c3d4e5f6', 10);

      when(repo.getAllObjects).thenAnswer((_) async => []);

      await manager.enforceCacheLimits();

      expect(uuidVideo.existsSync(), isFalse, reason: 'uuid orphan removed');
      expect(
        uuidPartial.existsSync(),
        isFalse,
        reason: 'uuid .file orphan removed',
      );
      expect(seedVideo.existsSync(), isTrue, reason: 'seed video kept');
    });

    test('leaves freshly-written untracked files for a later sweep', () async {
      final (manager, dir) = build();
      final freshManaged = writeFile(
        dir,
        'vid_key_300_3.mp4',
        10,
        modified: DateTime.now(),
      );
      final freshUuid = writeFile(
        dir,
        '1b4e28ba-2fa1-11d2-883f-0016d3cca427.jpg',
        10,
        modified: DateTime.now(),
      );
      when(repo.getAllObjects).thenAnswer((_) async => []);

      await manager.enforceCacheLimits();

      expect(
        freshManaged.existsSync(),
        isTrue,
        reason:
            'a file inside the freshness window may be a download that '
            'settled after the sweep snapshots were taken',
      );
      expect(
        freshUuid.existsSync(),
        isTrue,
        reason:
            'WebHelper writes carry no in-flight shield; freshness is '
            'their only protection',
      );
    });

    test('evicts least-recently-used tracked files until under '
        'budget', () async {
      final (manager, dir) = build(maxCacheSizeBytes: 100);
      final oldest = writeFile(dir, 'a_1_1.mp4', 60);
      final middle = writeFile(dir, 'b_2_2.mp4', 60);
      final newest = writeFile(dir, 'c_3_3.mp4', 60);

      when(repo.getAllObjects).thenAnswer(
        (_) async => [
          obj('a_1_1.mp4', id: 1, touched: DateTime(2020)),
          obj('b_2_2.mp4', id: 2, touched: DateTime(2020, 1, 2)),
          obj('c_3_3.mp4', id: 3, touched: DateTime(2020, 1, 3)),
        ],
      );

      await manager.enforceCacheLimits();

      // 180 bytes > 100: drop oldest (→120), still over, drop middle (→60).
      expect(oldest.existsSync(), isFalse);
      expect(middle.existsSync(), isFalse);
      expect(newest.existsSync(), isTrue);

      final captured =
          verify(() => repo.deleteAll(captureAny())).captured.single as List;
      expect(captured, containsAll(<int>[1, 2]));
      expect(captured, isNot(contains(3)));
    });

    test('does not evict when total size is within budget', () async {
      final (manager, dir) = build(maxCacheSizeBytes: 1000);
      final file = writeFile(dir, 'a_1_1.mp4', 60);

      when(repo.getAllObjects).thenAnswer(
        (_) async => [obj('a_1_1.mp4', id: 1, touched: DateTime(2020))],
      );

      await manager.enforceCacheLimits();

      expect(file.existsSync(), isTrue);
      verifyNever(() => repo.deleteAll(any()));
    });

    test('skips tracked objects whose file is missing on disk', () async {
      final (manager, dir) = build(maxCacheSizeBytes: 50);
      final present = writeFile(dir, 'present_2_2.mp4', 60);

      when(repo.getAllObjects).thenAnswer(
        (_) async => [
          obj('missing_9_9.mp4', id: 1, touched: DateTime(2020)),
          obj('present_2_2.mp4', id: 2, touched: DateTime(2020, 1, 2)),
        ],
      );

      await manager.enforceCacheLimits();

      expect(present.existsSync(), isFalse);
      final captured =
          verify(() => repo.deleteAll(captureAny())).captured.single as List;
      expect(captured, equals(<int>[2]));
    });

    test('evicts files whose object has no id without calling '
        'deleteAll', () async {
      final (manager, dir) = build(maxCacheSizeBytes: 50);
      final file = writeFile(dir, 'a_1_1.mp4', 60);

      when(repo.getAllObjects).thenAnswer(
        (_) async => [obj('a_1_1.mp4', touched: DateTime(2020))],
      );

      await manager.enforceCacheLimits();

      expect(file.existsSync(), isFalse);
      verifyNever(() => repo.deleteAll(any()));
    });

    test('does nothing when the repository fails to open', () async {
      when(repo.open).thenAnswer((_) async => false);
      final (manager, dir) = build();
      final orphan = writeFile(dir, 'x_1_1.mp4', 10);

      await manager.enforceCacheLimits();

      expect(orphan.existsSync(), isTrue);
      verifyNever(repo.getAllObjects);
    });

    test('does not throttle the retry after a failed repository '
        'open', () async {
      when(repo.open).thenAnswer((_) async => false);
      final (manager, dir) = build();
      final orphan = writeFile(dir, 'x_1_1.mp4', 10);

      await manager.enforceCacheLimits();
      expect(orphan.existsSync(), isTrue, reason: 'first pass could not run');

      when(repo.open).thenAnswer((_) async => true);
      when(repo.getAllObjects).thenAnswer((_) async => []);
      await manager.enforceCacheLimits();

      expect(
        orphan.existsSync(),
        isFalse,
        reason:
            'a pass that never opened the repo must not start the '
            'throttle window',
      );
    });

    test('swallows repository errors without throwing', () async {
      final (manager, _) = build();
      when(repo.getAllObjects).thenThrow(Exception('boom'));

      await expectLater(manager.enforceCacheLimits(), completes);
    });

    test('is a no-op after the manager is closed', () async {
      when(repo.getAllObjects).thenAnswer((_) async => []);
      final (manager, dir) = build();
      await runZonedGuarded(() async {
        try {
          await manager.close();
        } on Object catch (_) {}
      }, (_, _) {});
      final orphan = writeFile(dir, 'x_1_1.mp4', 10);

      await manager.enforceCacheLimits();

      expect(orphan.existsSync(), isTrue);
      verifyNever(repo.getAllObjects);
    });

    test('ignores an overlapping call while a sweep is in progress', () async {
      final gate = Completer<List<CacheObject>>();
      when(repo.getAllObjects).thenAnswer((_) => gate.future);
      final (manager, dir) = build();
      final orphan = writeFile(dir, 'x_1_1.mp4', 10);

      final first = manager.enforceCacheLimits();
      // Second call sees _sweepInProgress and returns immediately.
      await manager.enforceCacheLimits();
      expect(orphan.existsSync(), isTrue, reason: 'first sweep still parked');

      gate.complete([]);
      await first;

      expect(orphan.existsSync(), isFalse);
      verify(repo.getAllObjects).called(1);
    });

    test('skips a second pass within the throttle window', () async {
      when(repo.getAllObjects).thenAnswer((_) async => []);
      final (manager, dir) = build();
      final firstOrphan = writeFile(dir, 'a_1_1.mp4', 10);

      await manager.enforceCacheLimits();
      expect(firstOrphan.existsSync(), isFalse, reason: 'first pass ran');

      final secondOrphan = writeFile(dir, 'b_2_2.mp4', 10);
      await manager.enforceCacheLimits();

      expect(
        secondOrphan.existsSync(),
        isTrue,
        reason: 'second pass throttled within the interval',
      );
      verify(repo.getAllObjects).called(1);
    });

    test('force bypasses the throttle window', () async {
      when(repo.getAllObjects).thenAnswer((_) async => []);
      final (manager, dir) = build();
      final firstOrphan = writeFile(dir, 'a_1_1.mp4', 10);

      await manager.enforceCacheLimits();
      expect(firstOrphan.existsSync(), isFalse);

      final secondOrphan = writeFile(dir, 'b_2_2.mp4', 10);
      await manager.enforceCacheLimits(force: true);

      expect(
        secondOrphan.existsSync(),
        isFalse,
        reason: 'force runs even within the throttle interval',
      );
      verify(repo.getAllObjects).called(2);
    });

    test('does not reclaim files still referenced by the sync '
        'manifest', () async {
      final downloader = FakeCancellableDownloader();
      final cacheKey = 'manifest_${DateTime.now().microsecondsSinceEpoch}';
      Directory('$testTempPath/$cacheKey').createSync(recursive: true);
      when(() => repo.updateOrInsert(any())).thenAnswer((_) async => 0);
      // The store reports nothing — as if flutter_cache_manager demoted the
      // row past its object cap while the file stays live in the manifest.
      when(repo.getAllObjects).thenAnswer((_) async => []);

      final manager = MediaCacheManager(
        config: MediaCacheConfig(cacheKey: cacheKey, enableSyncManifest: true),
        repoOverride: repo,
        downloaderOverride: downloader,
      );

      final op = manager.cacheFileCancellable(
        'https://example.com/v.mp4',
        key: 'k',
      );
      for (var i = 0; i < 400 && downloader.downloads.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      final target = downloader.downloads.single.targetFile
        ..writeAsBytesSync(const [1, 2, 3]);
      downloader.downloads.single.completeWith(target);
      await op.file;
      expect(target.existsSync(), isTrue);
      // Age the file past the freshness window so this test pins the
      // manifest protection, not the freshness guard.
      target.setLastModifiedSync(DateTime(2020));

      await manager.enforceCacheLimits();

      expect(
        target.existsSync(),
        isTrue,
        reason: 'a manifest-referenced file must survive reclamation',
      );
    });

    test('keeps a file a stalled in-flight download is still '
        'writing', () async {
      final downloader = FakeCancellableDownloader();
      final cacheKey = 'inflight_${DateTime.now().microsecondsSinceEpoch}';
      Directory('$testTempPath/$cacheKey').createSync(recursive: true);
      when(repo.getAllObjects).thenAnswer((_) async => []);
      when(() => repo.updateOrInsert(any())).thenAnswer((_) async => 0);

      final manager = MediaCacheManager(
        config: MediaCacheConfig(cacheKey: cacheKey, enableSyncManifest: true),
        repoOverride: repo,
        downloaderOverride: downloader,
      );

      final op = manager.cacheFileCancellable(
        'https://example.com/v.mp4',
        key: 'k',
      );
      for (var i = 0; i < 400 && downloader.downloads.isEmpty; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      // A long-stalled download: partial bytes on disk with an old mtime, so
      // only the in-flight shield (not the freshness guard) protects it.
      final target = downloader.downloads.single.targetFile
        ..writeAsBytesSync(const [1, 2, 3])
        ..setLastModifiedSync(DateTime(2020));

      await manager.enforceCacheLimits();

      expect(
        target.existsSync(),
        isTrue,
        reason: 'an in-flight download must never be reclaimed',
      );

      downloader.downloads.single.completeWith(target);
      await op.file;
    });

    test(
      'counts manifest-only managed files towards the byte budget',
      () async {
        final cacheKey =
            'manifest_budget_${DateTime.now().microsecondsSinceEpoch}';
        final dir = Directory('$testTempPath/$cacheKey')
          ..createSync(recursive: true);
        final target = writeFile(dir, 'legacy-cache-file.mp4', 3);
        var reads = 0;
        // Simulate flutter_cache_manager demoting the row after the manifest
        // was populated. The file remains playable through the sync manifest.
        when(repo.getAllObjects).thenAnswer((_) async {
          reads++;
          return reads == 1 ? [obj('legacy-cache-file.mp4', id: 1)] : [];
        });

        final manager = MediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: cacheKey,
            enableSyncManifest: true,
            maxCacheSizeBytes: 2,
          ),
          repoOverride: repo,
        );
        await manager.initialize();
        expect(
          manager.getCachedFileSync('key_legacy-cache-file.mp4')?.path,
          target.path,
        );

        await manager.enforceCacheLimits();

        expect(target.existsSync(), isFalse);
        expect(manager.getCachedFileSync('key_legacy-cache-file.mp4'), isNull);
      },
    );

    test('a runtime maxCacheSizeBytes override drives eviction', () async {
      final (manager, dir) = build();
      final oldest = writeFile(dir, 'a_1_1.mp4', 60);
      final newest = writeFile(dir, 'b_2_2.mp4', 60);
      when(repo.getAllObjects).thenAnswer(
        (_) async => [
          obj('a_1_1.mp4', id: 1, touched: DateTime(2020)),
          obj('b_2_2.mp4', id: 2, touched: DateTime(2020, 1, 2)),
        ],
      );

      // Base config has no byte budget; the override supplies one.
      manager.maxCacheSizeBytes = 100;
      expect(manager.maxCacheSizeBytes, 100);

      await manager.enforceCacheLimits();

      expect(oldest.existsSync(), isFalse);
      expect(newest.existsSync(), isTrue);
    });

    group('directory-total byte budget', () {
      test('counts untracked unmanaged bytes towards the budget', () async {
        final (manager, dir) = build(maxCacheSizeBytes: 100);
        final oldest = writeFile(dir, 'a_1_1.mp4', 60);
        final newest = writeFile(dir, 'b_2_2.mp4', 30);
        // Matches neither reclamation pattern, has no store row: reclamation
        // keeps it and eviction cannot delete it — but its bytes are real, so
        // they must count against the budget the way every on-disk measure
        // of the directory counts them (#8242).
        final unmanaged = writeFile(dir, 'externally-managed.bin', 30);

        when(repo.getAllObjects).thenAnswer(
          (_) async => [
            obj('a_1_1.mp4', id: 1, touched: DateTime(2020)),
            obj('b_2_2.mp4', id: 2, touched: DateTime(2020, 1, 2)),
          ],
        );

        await manager.enforceCacheLimits();

        // 120 bytes on disk > 100: evict the oldest tracked file (→ 60).
        // Tracked bytes alone were 90 ≤ 100, so this eviction only happens
        // when the unmanaged file is counted.
        expect(oldest.existsSync(), isFalse);
        expect(newest.existsSync(), isTrue);
        expect(unmanaged.existsSync(), isTrue, reason: 'never a candidate');
      });

      test('counts files in nested directories towards the budget', () async {
        final (manager, dir) = build(maxCacheSizeBytes: 100);
        final tracked = writeFile(dir, 'a_1_1.mp4', 60);
        final nested = Directory('${dir.path}/caller-owned')..createSync();
        final nestedFile = writeFile(nested, 'sidecar.bin', 60);
        when(repo.getAllObjects).thenAnswer(
          (_) async => [obj('a_1_1.mp4', id: 1, touched: DateTime(2020))],
        );

        await manager.enforceCacheLimits();

        expect(tracked.existsSync(), isFalse);
        expect(nestedFile.existsSync(), isTrue, reason: 'never a candidate');
      });
      test('stops cleanly when only undeletable bytes remain over '
          'budget', () async {
        final (manager, dir) = build(maxCacheSizeBytes: 10);
        final unmanaged = writeFile(dir, 'externally-managed.bin', 50);

        when(repo.getAllObjects).thenAnswer((_) async => <CacheObject>[]);

        await manager.enforceCacheLimits();

        expect(unmanaged.existsSync(), isTrue);
        verifyNever(() => repo.deleteAll(any()));
      });

      test('admits an entry larger than the remaining budget, then '
          'reconciles', () async {
        final (manager, dir) = build(maxCacheSizeBytes: 100);
        final oldest = writeFile(dir, 'a_1_1.mp4', 50);
        // No admission control: a download larger than the remaining
        // capacity lands whole and the next sweep trims oldest-first.
        final oversized = writeFile(dir, 'b_2_2.mp4', 80);

        when(repo.getAllObjects).thenAnswer(
          (_) async => [
            obj('a_1_1.mp4', id: 1, touched: DateTime(2020)),
            obj('b_2_2.mp4', id: 2, touched: DateTime(2020, 1, 2)),
          ],
        );

        await manager.enforceCacheLimits();

        expect(oldest.existsSync(), isFalse);
        expect(oversized.existsSync(), isTrue);
      });

      test('evicting an aliased file prunes and persists its '
          'aliases', () async {
        final downloader = FakeCancellableDownloader();
        final cacheKey = 'alias_${DateTime.now().microsecondsSinceEpoch}';
        Directory('$testTempPath/$cacheKey').createSync(recursive: true);
        when(repo.getAllObjects).thenAnswer((_) async => []);
        when(() => repo.updateOrInsert(any())).thenAnswer((_) async => 0);

        final manager = MediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: cacheKey,
            enableSyncManifest: true,
            maxCacheSizeBytes: 2,
          ),
          repoOverride: repo,
          downloaderOverride: downloader,
        );
        addTearDown(manager.close);

        final op = manager.cacheFileCancellable(
          'https://example.com/v.mp4',
          key: 'k__fb1',
          aliasKey: 'k',
        );
        for (var i = 0; i < 400 && downloader.downloads.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        final target = downloader.downloads.single.targetFile
          ..writeAsBytesSync(const [1, 2, 3]);
        downloader.downloads.single.completeWith(target);
        await op.file;
        expect(manager.getCachedFileSync('k')?.path, target.path);

        await manager.enforceCacheLimits(force: true);
        await manager.waitForPendingAliasWrites();

        expect(target.existsSync(), isFalse);
        expect(
          manager.getCachedFileSync('k'),
          isNull,
          reason: 'the alias must not survive its target',
        );
        final aliasFile = File('$testTempPath/$cacheKey/aliases.json');
        expect(
          aliasFile.existsSync() && aliasFile.readAsStringSync().contains('k'),
          isFalse,
          reason: 'the persisted alias map must drop the evicted entry',
        );
      });
    });

    group('byte-armed and trailing sweeps', () {
      (MediaCacheManager, Directory, FakeCancellableDownloader) buildWithBudget(
        String prefix, {
        required int maxCacheSizeBytes,
        required Duration sweepThrottle,
      }) {
        final downloader = FakeCancellableDownloader();
        final cacheKey = '${prefix}_${DateTime.now().microsecondsSinceEpoch}';
        final dir = Directory('$testTempPath/$cacheKey')
          ..createSync(recursive: true);
        when(repo.getAllObjects).thenAnswer((_) async => []);
        when(() => repo.updateOrInsert(any())).thenAnswer((_) async => 0);
        final manager = MediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: cacheKey,
            enableSyncManifest: true,
            maxCacheSizeBytes: maxCacheSizeBytes,
          ),
          repoOverride: repo,
          downloaderOverride: downloader,
          sweepThrottleOverride: sweepThrottle,
        );
        addTearDown(manager.close);
        return (manager, dir, downloader);
      }

      Future<File> completeDownload(
        MediaCacheManager manager,
        FakeCancellableDownloader downloader, {
        required int bytes,
      }) async {
        final op = manager.cacheFileCancellable(
          'https://example.com/v.mp4',
          key: 'k',
        );
        for (var i = 0; i < 400 && downloader.downloads.isEmpty; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        final target = downloader.downloads.single.targetFile
          ..writeAsBytesSync(List<int>.filled(bytes, 0));
        downloader.downloads.single.completeWith(target);
        await op.file;
        return target;
      }

      test('sweeps immediately when a download crosses the byte '
          'budget, before the 25-download counter', () async {
        final (manager, _, downloader) = buildWithBudget(
          'bytearm',
          maxCacheSizeBytes: 4,
          sweepThrottle: const Duration(milliseconds: 50),
        );

        final target = await completeDownload(manager, downloader, bytes: 10);

        // One 10-byte download over a 4-byte budget: the crossing sweeps
        // without waiting for 24 more downloads.
        for (var i = 0; i < 400 && target.existsSync(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(target.existsSync(), isFalse);
        final sweepLogs = LogCaptureService().getRecentLogs().where(
          (entry) => entry.message.contains('sweep reclaimed'),
        );
        expect(sweepLogs, isNotEmpty, reason: 'sweeps must be visible in logs');
      });

      test('arms a trailing sweep inside the throttle window and fires '
          'it with no further downloads', () async {
        final (manager, _, downloader) = buildWithBudget(
          'trailing',
          maxCacheSizeBytes: 4,
          sweepThrottle: const Duration(seconds: 1),
        );
        // Stamp the throttle window so the crossing lands inside it.
        await manager.enforceCacheLimits(force: true);

        final target = await completeDownload(manager, downloader, bytes: 10);

        expect(
          target.existsSync(),
          isTrue,
          reason: 'crossing inside the window must not sweep immediately',
        );

        // No further download lands; only the armed timer can converge this.
        for (var i = 0; i < 800 && target.existsSync(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(target.existsSync(), isFalse);
      });

      test('resyncs after a download settles during a sweep', () async {
        final deleteStarted = Completer<void>();
        final allowDeleteToFinish = Completer<void>();
        when(() => repo.deleteAll(any())).thenAnswer((_) async {
          deleteStarted.complete();
          await allowDeleteToFinish.future;
          return 1;
        });
        final (manager, dir, downloader) = buildWithBudget(
          'mid_sweep_download',
          maxCacheSizeBytes: 4,
          sweepThrottle: const Duration(milliseconds: 100),
        );
        final oldFile = writeFile(dir, 'old_1_1.mp4', 10);
        when(repo.getAllObjects).thenAnswer(
          (_) async => [obj('old_1_1.mp4', id: 1, touched: DateTime(2020))],
        );

        final sweep = manager.enforceCacheLimits(force: true);
        await deleteStarted.future;
        expect(oldFile.existsSync(), isFalse);

        final downloaded = await completeDownload(
          manager,
          downloader,
          bytes: 10,
        );
        allowDeleteToFinish.complete();
        await sweep;

        for (var i = 0; i < 100 && downloaded.existsSync(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(
          downloaded.existsSync(),
          isFalse,
          reason: 'the mid-sweep download must trigger a resyncing pass',
        );
      });

      test('resetForTesting cancels a pending trailing sweep', () async {
        var reads = 0;
        final (manager, _, downloader) = buildWithBudget(
          'reset_pending_sweep',
          maxCacheSizeBytes: 4,
          sweepThrottle: const Duration(milliseconds: 300),
        );
        when(repo.getAllObjects).thenAnswer((_) async {
          reads++;
          return <CacheObject>[];
        });
        await manager.enforceCacheLimits(force: true);
        final readsAfterForcedSweep = reads;
        expect(readsAfterForcedSweep, 1, reason: 'the forced sweep read once');
        final target = await completeDownload(manager, downloader, bytes: 10);
        expect(target.existsSync(), isTrue, reason: 'inside the window');
        await Future<void>.delayed(const Duration(milliseconds: 10));

        manager.resetForTesting();
        await Future<void>.delayed(const Duration(milliseconds: 600));

        expect(target.existsSync(), isTrue);
        expect(reads, readsAfterForcedSweep);
      });

      test(
        're-arms when a forced sweep restarts the throttle window',
        () async {
          var reads = 0;
          final (manager, _, downloader) = buildWithBudget(
            'rearm_pending_sweep',
            maxCacheSizeBytes: 4,
            sweepThrottle: const Duration(milliseconds: 300),
          );
          when(repo.getAllObjects).thenAnswer((_) async {
            reads++;
            if (reads == 2) throw StateError('forced diagnostic failure');
            return <CacheObject>[];
          });
          await manager.enforceCacheLimits(force: true);
          final target = await completeDownload(manager, downloader, bytes: 10);
          await Future<void>.delayed(const Duration(milliseconds: 10));

          await Future<void>.delayed(const Duration(milliseconds: 150));
          await manager.enforceCacheLimits(force: true);

          for (var i = 0; i < 200 && target.existsSync(); i++) {
            await Future<void>.delayed(const Duration(milliseconds: 5));
          }
          expect(target.existsSync(), isFalse);
          expect(reads, 3, reason: 'the pending timer must re-arm once');
        },
      );

      test('does not spin sweeps while undeletable bytes hold the '
          'directory over budget', () async {
        var reads = 0;
        when(repo.getAllObjects).thenAnswer((_) async {
          reads++;
          return <CacheObject>[];
        });
        final downloader = FakeCancellableDownloader();
        final cacheKey = 'nospin_${DateTime.now().microsecondsSinceEpoch}';
        final dir = Directory('$testTempPath/$cacheKey')
          ..createSync(recursive: true);
        writeFile(dir, 'externally-managed.bin', 50);
        final manager = MediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: cacheKey,
            enableSyncManifest: true,
            maxCacheSizeBytes: 4,
          ),
          repoOverride: repo,
          downloaderOverride: downloader,
          sweepThrottleOverride: const Duration(milliseconds: 50),
        );
        addTearDown(manager.close);

        await manager.enforceCacheLimits(force: true);
        expect(reads, 1);

        await Future<void>.delayed(const Duration(milliseconds: 400));
        expect(
          reads,
          1,
          reason: 'a sweep that ends over budget must not reschedule itself',
        );
      });

      test('a trailing sweep armed before close() never runs after '
          'it', () async {
        var reads = 0;
        final (manager, _, downloader) = buildWithBudget(
          'closed',
          maxCacheSizeBytes: 4,
          sweepThrottle: const Duration(milliseconds: 300),
        );
        // Stub after buildWithBudget, which installs its own non-counting
        // getAllObjects stub. With the order reversed the counter never moved
        // and the final assertion compared 0 with 0 (#8617).
        when(repo.getAllObjects).thenAnswer((_) async {
          reads++;
          return <CacheObject>[];
        });
        await manager.enforceCacheLimits(force: true);
        final readsAfterForcedSweep = reads;
        expect(readsAfterForcedSweep, 1, reason: 'the forced sweep read once');

        final target = await completeDownload(manager, downloader, bytes: 10);
        expect(target.existsSync(), isTrue, reason: 'inside the window');

        await manager.close();
        await Future<void>.delayed(const Duration(milliseconds: 600));

        expect(target.existsSync(), isTrue);
        expect(reads, readsAfterForcedSweep);
      });

      test('close waits for an in-flight sweep to settle', () async {
        final deleteStarted = Completer<void>();
        final deleteGate = Completer<void>();
        when(repo.getAllObjects).thenAnswer(
          (_) async => [obj('old_1_1.mp4', id: 1, touched: DateTime(2020))],
        );
        when(() => repo.deleteAll(any())).thenAnswer((_) async {
          deleteStarted.complete();
          await deleteGate.future;
          return 1;
        });
        final (manager, dir) = build(maxCacheSizeBytes: 50);
        writeFile(dir, 'old_1_1.mp4', 100);

        final sweep = manager.enforceCacheLimits(force: true);
        await deleteStarted.future;
        var closeCompleted = false;
        final closing = manager.close().then((_) => closeCompleted = true);
        await Future<void>.delayed(Duration.zero);

        expect(closeCompleted, isFalse);
        deleteGate.complete();
        await Future.wait([sweep, closing]);
        expect(closeCompleted, isTrue);
      });

      test('reconciles a download that settles during byte eviction', () async {
        final deleteStarted = Completer<void>();
        final deleteGate = Completer<void>();
        var reads = 0;
        when(repo.getAllObjects).thenAnswer((_) async {
          reads++;
          return reads == 1
              ? [obj('old_1_1.mp4', id: 1, touched: DateTime(2020))]
              : <CacheObject>[];
        });
        when(() => repo.deleteAll(any())).thenAnswer((_) async {
          deleteStarted.complete();
          await deleteGate.future;
          return 1;
        });
        when(() => repo.updateOrInsert(any())).thenAnswer((_) async => 0);

        final downloader = FakeCancellableDownloader();
        final cacheKey = 'raced_${DateTime.now().microsecondsSinceEpoch}';
        final dir = Directory('$testTempPath/$cacheKey')
          ..createSync(recursive: true);
        writeFile(dir, 'old_1_1.mp4', 60);
        writeFile(dir, 'externally-managed.bin', 60);
        final manager = MediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: cacheKey,
            enableSyncManifest: true,
            maxCacheSizeBytes: 100,
          ),
          repoOverride: repo,
          downloaderOverride: downloader,
          sweepThrottleOverride: const Duration(milliseconds: 50),
        );

        final sweep = manager.enforceCacheLimits(force: true);
        await deleteStarted.future;

        final target = await completeDownload(manager, downloader, bytes: 80);
        deleteGate.complete();
        await sweep;

        for (var i = 0; i < 400 && target.existsSync(); i++) {
          await Future<void>.delayed(const Duration(milliseconds: 5));
        }
        expect(
          target.existsSync(),
          isFalse,
          reason: 'a completion raced by the first scan must trigger a retry',
        );
        expect(reads, 2);
        await manager.close();
      });
    });

    test('runs a throttled sweep after enough downloads', () async {
      final downloader = FakeCancellableDownloader();
      final cacheKey = 'throttle_${DateTime.now().microsecondsSinceEpoch}';
      Directory('$testTempPath/$cacheKey').createSync(recursive: true);
      when(repo.getAllObjects).thenAnswer((_) async => []);
      when(() => repo.updateOrInsert(any())).thenAnswer((_) async => 0);

      final manager = MediaCacheManager(
        config: MediaCacheConfig(cacheKey: cacheKey, enableSyncManifest: true),
        repoOverride: repo,
        downloaderOverride: downloader,
      );

      final sourceDir = Directory.systemTemp.createTempSync('throttle_src_');
      final file = File('${sourceDir.path}/v.mp4')
        ..writeAsBytesSync(const [1, 2, 3]);

      final ops = [
        for (var i = 0; i < 25; i++)
          manager.cacheFileCancellable(
            'https://example.com/v$i.mp4',
            key: 'k$i',
          ),
      ];

      for (var i = 0; i < 400 && downloader.downloads.length < 25; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
      }
      for (final download in downloader.downloads) {
        download.completeWith(file);
      }
      await Future.wait(ops.map((op) => op.file));
      await Future<void>.delayed(const Duration(milliseconds: 5));

      verify(repo.getAllObjects).called(greaterThanOrEqualTo(1));
      sourceDir.deleteSync(recursive: true);
    });

    test('retains the download counter while the sweep is '
        'throttled', () async {
      var offset = Duration.zero;
      await withClock(Clock(() => DateTime.now().add(offset)), () async {
        final downloader = FakeCancellableDownloader();
        final cacheKey = 'counter_${DateTime.now().microsecondsSinceEpoch}';
        Directory('$testTempPath/$cacheKey').createSync(recursive: true);
        var sweeps = 0;
        when(repo.getAllObjects).thenAnswer((_) async {
          sweeps++;
          return [];
        });
        when(() => repo.updateOrInsert(any())).thenAnswer((_) async => 0);

        final manager = MediaCacheManager(
          config: MediaCacheConfig(
            cacheKey: cacheKey,
            enableSyncManifest: true,
          ),
          repoOverride: repo,
          downloaderOverride: downloader,
        );

        final sourceDir = Directory.systemTemp.createTempSync('counter_src_');
        addTearDown(() => sourceDir.deleteSync(recursive: true));
        final file = File('${sourceDir.path}/v.mp4')
          ..writeAsBytesSync(const [1, 2, 3]);

        Future<void> drive(int from, int count) async {
          final ops = [
            for (var i = from; i < from + count; i++)
              manager.cacheFileCancellable(
                'https://example.com/v$i.mp4',
                key: 'k$i',
              ),
          ];
          for (
            var i = 0;
            i < 400 && downloader.downloads.length < from + count;
            i++
          ) {
            await Future<void>.delayed(const Duration(milliseconds: 1));
          }
          for (final download in downloader.downloads.sublist(from)) {
            download.completeWith(file);
          }
          await Future.wait(ops.map((op) => op.file));
        }

        await drive(0, 25);
        for (var i = 0; i < 400 && sweeps < 1; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        expect(sweeps, 1, reason: 'first batch triggers a sweep');
        // Let the sweep finish so _lastSweepAt is stamped.
        await Future<void>.delayed(const Duration(milliseconds: 5));

        // A second full batch inside the throttle window: no sweep runs, but
        // the counter must be retained instead of consumed.
        await drive(25, 25);
        await Future<void>.delayed(const Duration(milliseconds: 5));
        expect(sweeps, 1, reason: 'second batch is throttled');

        // Once the window has passed, the retained counter means a single
        // further download is enough to trigger the deferred sweep.
        offset += const Duration(minutes: 2);
        await drive(50, 1);
        for (var i = 0; i < 400 && sweeps < 2; i++) {
          await Future<void>.delayed(const Duration(milliseconds: 1));
        }
        expect(
          sweeps,
          2,
          reason: 'throttled downloads still count toward the next pass',
        );
      });
    });

    test('runs a throttled sweep after enough cacheFile downloads', () async {
      final mockFile = MockFile();
      final mockFileInfo = MockFileInfo();
      when(mockFile.existsSync).thenReturn(true);
      when(() => mockFile.path).thenReturn('/test/path/video.mp4');
      when(() => mockFileInfo.file).thenReturn(mockFile);
      when(repo.getAllObjects).thenAnswer((_) async => []);

      final manager = TestableMediaCacheManager(
        config: MediaCacheConfig(
          cacheKey: 'cache_file_sweep_${DateTime.now().microsecondsSinceEpoch}',
        ),
        repoOverride: repo,
        mockGetFileFromCache: (_) async => null,
        mockDownloadFile: (_, {key, authHeaders}) async => mockFileInfo,
      );

      for (var i = 0; i < 25; i++) {
        await manager.cacheFile(
          'https://example.com/v$i.mp4',
          key: 'k$i',
        );
      }
      for (var i = 0; i < 400; i++) {
        await Future<void>.delayed(const Duration(milliseconds: 1));
        try {
          verify(repo.getAllObjects).called(1);
          return;
        } on TestFailure {
          // The sweep is deliberately unawaited; keep polling briefly.
        }
      }
      fail('cacheFile downloads did not trigger a cache-limit sweep');
    });

    test('queues a forced sweep behind an in-progress pass', () async {
      final gate = Completer<List<CacheObject>>();
      var calls = 0;
      when(repo.getAllObjects).thenAnswer((_) {
        calls++;
        return calls == 1 ? gate.future : Future.value([]);
      });
      final (manager, _) = build();

      final first = manager.enforceCacheLimits();
      final forced = manager.enforceCacheLimits(force: true);
      var forcedCompleted = false;
      unawaited(forced.then((_) => forcedCompleted = true));
      await Future<void>.delayed(Duration.zero);
      expect(forcedCompleted, isFalse);

      gate.complete([]);
      await first;
      await forced;

      expect(calls, 2);
    });

    test('reports the byte budget via getCacheStats', () {
      final (manager, _) = build(maxCacheSizeBytes: 4096);
      expect(manager.getCacheStats()['maxCacheSizeBytes'], 4096);
    });
  });
}
