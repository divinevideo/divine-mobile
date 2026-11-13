// ABOUTME: Tests the automatic media-cache budget: keep 15% of the disk free,
// ABOUTME: never exceed today's ceilings, never shrink below the usable floor.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/device_storage_service.dart';
import 'package:openvine/services/media_cache_budget.dart';

const int _mb = 1024 * 1024;
const int _gb = 1024 * _mb;

const _ceiling = MediaCacheBudget(
  videoBytes: 2 * _gb,
  imageBytes: 256 * _mb,
  playerBytes: 500 * _mb,
);
const _floor = MediaCacheBudget(
  videoBytes: 64 * _mb,
  imageBytes: 32 * _mb,
  playerBytes: 32 * _mb,
);

MediaCacheBudget _budget({
  required int totalBytes,
  required int freeBytes,
  int cacheUsageBytes = 0,
  MediaCacheBudget ceiling = _ceiling,
}) => automaticMediaCacheBudget(
  storage: DeviceStorageSpace(totalBytes: totalBytes, freeBytes: freeBytes),
  cacheUsageBytes: cacheUsageBytes,
  ceiling: ceiling,
);

void main() {
  group('automaticMediaCacheBudget', () {
    test('keeps every cache at its ceiling when the disk has room', () {
      expect(
        _budget(totalBytes: 256 * _gb, freeBytes: 120 * _gb),
        equals(_ceiling),
      );
    });

    test('shrinks every cache to its floor when the disk is past 85%', () {
      expect(
        _budget(totalBytes: 64 * _gb, freeBytes: 3 * _gb),
        equals(_floor),
      );
    });

    test('holds the floor on a disk that is completely full', () {
      expect(_budget(totalBytes: 64 * _gb, freeBytes: 0), equals(_floor));
    });

    test('in between, spends no more than the space above the reserve', () {
      // 15% of 100 GB is 15 GB, so 16 GB free leaves 1 GB to spend.
      final budget = _budget(totalBytes: 100 * _gb, freeBytes: 16 * _gb);

      expect(budget.totalBytes, lessThanOrEqualTo(1 * _gb));
      expect(budget.totalBytes, greaterThan(1 * _gb - 4));
      expect(budget.videoBytes, greaterThan(_floor.videoBytes));
      expect(budget.videoBytes, lessThan(_ceiling.videoBytes));
      expect(budget.imageBytes, greaterThan(_floor.imageBytes));
      expect(budget.imageBytes, lessThan(_ceiling.imageBytes));
      expect(budget.playerBytes, greaterThan(_floor.playerBytes));
      expect(budget.playerBytes, lessThan(_ceiling.playerBytes));
    });

    test('counts what the caches already hold as space it may keep', () {
      final empty = _budget(totalBytes: 100 * _gb, freeBytes: 16 * _gb);
      final holding = _budget(
        totalBytes: 100 * _gb,
        freeBytes: 15 * _gb,
        cacheUsageBytes: 1 * _gb,
      );

      // Same disk once the cache's own gigabyte is handed back: no shrink.
      expect(holding, equals(empty));
    });

    test('leaves a cache the platform does not have at zero', () {
      const noPlayer = MediaCacheBudget(
        videoBytes: 2 * _gb,
        imageBytes: 256 * _mb,
        playerBytes: 0,
      );

      final full = _budget(
        totalBytes: 64 * _gb,
        freeBytes: 0,
        ceiling: noPlayer,
      );
      final roomy = _budget(
        totalBytes: 256 * _gb,
        freeBytes: 120 * _gb,
        ceiling: noPlayer,
      );

      expect(full.playerBytes, isZero);
      expect(full.videoBytes, equals(_floor.videoBytes));
      expect(roomy, equals(noPlayer));
    });

    test('never raises a ceiling that is already below its floor', () {
      const tiny = MediaCacheBudget(
        videoBytes: 10 * _mb,
        imageBytes: 10 * _mb,
        playerBytes: 10 * _mb,
      );

      expect(
        _budget(totalBytes: 64 * _gb, freeBytes: 0, ceiling: tiny),
        equals(tiny),
      );
    });
  });

  group(MediaCacheBudget, () {
    test('totalBytes sums the three caches', () {
      expect(_floor.totalBytes, equals(128 * _mb));
    });
  });
}
