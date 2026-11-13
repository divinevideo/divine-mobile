// ABOUTME: Tests MediaCacheBudgetService applying the disk-aware budget to the
// ABOUTME: video and image caches, honouring a user's fixed video-cache size.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/constants/storage_cache_constants.dart';
import 'package:openvine/services/device_storage_service.dart';
import 'package:openvine/services/media_cache_budget.dart';
import 'package:openvine/services/media_cache_budget_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockMediaCacheManager extends Mock implements MediaCacheManager {}

const int _mb = 1024 * 1024;
const int _gb = 1024 * _mb;

const _ceiling = MediaCacheBudget(
  videoBytes: 2 * _gb,
  imageBytes: 256 * _mb,
  playerBytes: 500 * _mb,
);

const _roomyDisk = DeviceStorageSpace(
  totalBytes: 256 * _gb,
  freeBytes: 120 * _gb,
);
const _fullDisk = DeviceStorageSpace(totalBytes: 64 * _gb, freeBytes: 2 * _gb);

void main() {
  group(MediaCacheBudgetService, () {
    late _MockMediaCacheManager videoCache;
    late _MockMediaCacheManager imageCache;
    late SharedPreferences prefs;
    late int? videoBudget;
    late int? imageBudget;

    _MockMediaCacheManager stubbedCache() {
      final cache = _MockMediaCacheManager();
      when(() => cache.knownCacheBytes).thenReturn(0);
      when(
        () => cache.enforceCacheLimits(force: any(named: 'force')),
      ).thenAnswer((_) async {});
      return cache;
    }

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      videoBudget = _ceiling.videoBytes;
      imageBudget = _ceiling.imageBytes;
      videoCache = stubbedCache();
      imageCache = stubbedCache();
      when(() => videoCache.maxCacheSizeBytes).thenAnswer((_) => videoBudget);
      when(() => imageCache.maxCacheSizeBytes).thenAnswer((_) => imageBudget);
      when(() => videoCache.maxCacheSizeBytes = any()).thenAnswer(
        (i) => videoBudget = i.positionalArguments.single as int?,
      );
      when(() => imageCache.maxCacheSizeBytes = any()).thenAnswer(
        (i) => imageBudget = i.positionalArguments.single as int?,
      );
    });

    MediaCacheBudgetService build({
      DeviceStorageSpace? storage,
      Future<DeviceStorageSpace?> Function()? readStorageSpace,
      DateTime Function()? now,
      MediaCacheBudgetListener? onBudgetApplied,
    }) => MediaCacheBudgetService(
      videoCache: videoCache,
      imageCache: imageCache,
      prefs: prefs,
      readStorageSpace: readStorageSpace ?? () async => storage,
      ceiling: _ceiling,
      now: now,
      onBudgetApplied: onBudgetApplied,
    );

    group('refresh', () {
      test('keeps the caches at their ceilings on a roomy disk', () async {
        final budget = await build(storage: _roomyDisk).refresh();

        expect(budget, equals(_ceiling));
        expect(videoBudget, equals(_ceiling.videoBytes));
        expect(imageBudget, equals(_ceiling.imageBytes));
        verifyNever(() => videoCache.enforceCacheLimits(force: true));
        verifyNever(() => imageCache.enforceCacheLimits(force: true));
      });

      test('shrinks both caches to their floors and trims them on a nearly '
          'full disk', () async {
        final budget = await build(storage: _fullDisk).refresh();

        expect(budget.videoBytes, equals(kVideoCacheFloorBytes));
        expect(budget.imageBytes, equals(kImageCacheFloorBytes));
        expect(videoBudget, equals(kVideoCacheFloorBytes));
        expect(imageBudget, equals(kImageCacheFloorBytes));
        verify(() => videoCache.enforceCacheLimits(force: true)).called(1);
        verify(() => imageCache.enforceCacheLimits(force: true)).called(1);
      });

      test('grows the caches back without a trim once space returns', () async {
        final service = build(storage: _fullDisk);
        await service.refresh();
        clearInteractions(videoCache);
        clearInteractions(imageCache);

        final regrown = MediaCacheBudgetService(
          videoCache: videoCache,
          imageCache: imageCache,
          prefs: prefs,
          readStorageSpace: () async => _roomyDisk,
          ceiling: _ceiling,
        );
        await regrown.refresh();

        expect(videoBudget, equals(_ceiling.videoBytes));
        expect(imageBudget, equals(_ceiling.imageBytes));
        verifyNever(() => videoCache.enforceCacheLimits(force: true));
        verifyNever(() => imageCache.enforceCacheLimits(force: true));
      });

      test('counts what both caches hold as space they may keep', () async {
        // 100 GB disk, 15 GB reserve: 15 GB free plus 1 GB already cached is
        // 1 GB of room, the same as 16 GB free with empty caches.
        when(() => videoCache.knownCacheBytes).thenReturn(768 * _mb);
        when(() => imageCache.knownCacheBytes).thenReturn(256 * _mb);
        const disk = DeviceStorageSpace(
          totalBytes: 100 * _gb,
          freeBytes: 15 * _gb,
        );

        final budget = await build(storage: disk).refresh();

        expect(
          budget,
          equals(
            automaticMediaCacheBudget(
              storage: const DeviceStorageSpace(
                totalBytes: 100 * _gb,
                freeBytes: 16 * _gb,
              ),
              cacheUsageBytes: 0,
              ceiling: _ceiling,
            ),
          ),
        );
      });

      test('keeps a fixed video-cache size the user chose, even on a full '
          'disk', () async {
        await prefs.setInt(kCacheLimitPrefKey, 5 * _gb);

        final budget = await build(storage: _fullDisk).refresh();

        expect(budget.videoBytes, equals(5 * _gb));
        expect(videoBudget, equals(5 * _gb));
        expect(budget.imageBytes, equals(kImageCacheFloorBytes));
        verifyNever(() => videoCache.enforceCacheLimits(force: true));
      });

      test('falls back to the ceilings when the disk cannot be read', () async {
        final budget = await build().refresh();

        expect(budget, equals(_ceiling));
        expect(videoBudget, equals(_ceiling.videoBytes));
      });

      group('while a refresh is running', () {
        test('runs one follow-up for every call made meanwhile', () async {
          var reads = 0;
          final readings = <Completer<DeviceStorageSpace?>>[];
          final service = build(
            readStorageSpace: () {
              reads++;
              final reading = Completer<DeviceStorageSpace?>();
              readings.add(reading);
              return reading.future;
            },
          );

          final first = service.refresh();
          final second = service.refresh();
          final third = service.refresh();
          readings.single.complete(_fullDisk);
          await first;
          await pumpEventQueue();
          expect(reads, equals(2));
          readings.last.complete(_roomyDisk);

          expect(await second, equals(_ceiling));
          expect(await third, equals(_ceiling));
          expect(reads, equals(2));
        });

        test('applies the automatic budget to a caller that removed the '
            'fixed size mid-refresh', () async {
          await prefs.setInt(kCacheLimitPrefKey, 5 * _gb);
          final trim = Completer<void>();
          when(
            () => imageCache.enforceCacheLimits(force: any(named: 'force')),
          ).thenAnswer((_) => trim.future);
          final heard = <(MediaCacheBudget, bool)>[];
          final service = build(
            storage: _fullDisk,
            onBudgetApplied: (_, budget, {required automatic}) =>
                heard.add((budget, automatic)),
          );

          final first = service.refresh();
          await pumpEventQueue();
          await prefs.remove(kCacheLimitPrefKey);
          final second = service.refresh();
          trim.complete();

          expect((await first).videoBytes, equals(5 * _gb));
          expect((await second).videoBytes, equals(kVideoCacheFloorBytes));
          expect(videoBudget, equals(kVideoCacheFloorBytes));
          expect(
            heard.map((entry) => (entry.$1.videoBytes, entry.$2)),
            equals([(5 * _gb, false), (kVideoCacheFloorBytes, true)]),
          );
        });

        test(
          'still re-reads the disk after the running refresh fails',
          () async {
            final reading = Completer<DeviceStorageSpace?>();
            var reads = 0;
            final service = build(
              readStorageSpace: () {
                reads++;
                return reads == 1 ? reading.future : Future.value(_roomyDisk);
              },
            );

            final first = service.refresh();
            final second = service.refresh();
            reading.completeError(Exception('disk read failed'));

            await expectLater(first, throwsException);
            expect(await second, equals(_ceiling));
            expect(reads, equals(2));
          },
        );
      });

      test('lets the next call re-read the disk after a failure', () async {
        var reads = 0;
        final service = build(
          readStorageSpace: () async {
            reads++;
            if (reads == 1) throw Exception('disk read failed');
            return _roomyDisk;
          },
        );

        await expectLater(service.refresh(), throwsException);
        expect(await service.refresh(), equals(_ceiling));
        expect(reads, equals(2));
      });

      test('tells the listener what it read and what it applied', () async {
        await prefs.setInt(kCacheLimitPrefKey, 5 * _gb);
        final heard = <(DeviceStorageSpace?, MediaCacheBudget, bool)>[];

        final budget = await build(
          storage: _fullDisk,
          onBudgetApplied: (storage, budget, {required automatic}) =>
              heard.add((storage, budget, automatic)),
        ).refresh();

        expect(heard, equals([(_fullDisk, budget, false)]));
      });

      test('remembers the budget it applied', () async {
        final service = build(storage: _fullDisk);
        expect(service.appliedBudget, isNull);

        final budget = await service.refresh();

        expect(service.appliedBudget, equals(budget));
      });
    });

    group('refreshIfStale', () {
      test('skips a refresh inside the interval and runs one after', () async {
        var clock = DateTime(2026, 11, 13, 12);
        var reads = 0;
        final service = build(
          readStorageSpace: () async {
            reads++;
            return _roomyDisk;
          },
          now: () => clock,
        );

        await service.refreshIfStale();
        clock = clock.add(MediaCacheBudgetService.staleAfter);
        await service.refreshIfStale();
        clock = clock.add(const Duration(seconds: 1));
        await service.refreshIfStale();

        expect(reads, equals(2));
      });
    });

    group('isAutomatic', () {
      test('is true until the user picks a fixed size', () async {
        final service = build(storage: _roomyDisk);
        expect(service.isAutomatic, isTrue);

        await prefs.setInt(kCacheLimitPrefKey, 1 * _gb);

        expect(service.isAutomatic, isFalse);
      });
    });
  });
}
