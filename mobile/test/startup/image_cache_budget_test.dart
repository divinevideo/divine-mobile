// ABOUTME: Tests the RAM-sized decoded-image cache budget.
// ABOUTME: Covers rounding of OS-reported RAM, the clamp, and the fallback.

import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/app_constants.dart';
import 'package:openvine/startup/image_cache_budget.dart';

const int _mib = 1 << 20;
const int _gib = 1 << 30;

void main() {
  group('imageCacheBudgetBytes', () {
    test('gives a 12 GB device the 256 MB ceiling', () {
      // MemTotal of the Galaxy S26 (12 GB) used in #10301.
      expect(imageCacheBudgetBytes(11910616 * 1024), equals(256 * _mib));
    });

    test('gives an 8 GB device about 170 MB', () {
      expect(
        imageCacheBudgetBytes((7.4 * _gib).round()),
        equals(8 * _gib ~/ 48),
      );
    });

    test('gives a 6 GB device 128 MB', () {
      expect(imageCacheBudgetBytes((5.6 * _gib).round()), equals(128 * _mib));
    });

    test('does not round a reading of exactly 6 GiB up to 7 GiB', () {
      expect(imageCacheBudgetBytes(6 * _gib), equals(128 * _mib));
    });

    test('raises devices with 4 GB or less to the 96 MB floor', () {
      expect(imageCacheBudgetBytes((3.6 * _gib).round()), equals(96 * _mib));
      expect(imageCacheBudgetBytes((1.8 * _gib).round()), equals(96 * _mib));
    });

    test('caps devices with more than 12 GB at 256 MB', () {
      expect(imageCacheBudgetBytes(16 * _gib), equals(256 * _mib));
    });

    test('falls back to 128 MB when RAM is unknown', () {
      expect(
        imageCacheBudgetBytes(null),
        equals(AppConstants.imageCacheFallbackBytes),
      );
      expect(imageCacheBudgetBytes(0), equals(128 * _mib));
      expect(imageCacheBudgetBytes(-1), equals(128 * _mib));
    });
  });

  group('configureImageCacheBudget', () {
    test('sets the budget the reported RAM calls for', () async {
      // Neither the fallback nor a clamp bound, so ignoring the reading fails.
      const expected = 8 * _gib ~/ 48;
      final cache = ImageCache();
      expect(cache.maximumSizeBytes, isNot(equals(expected)));

      final budget = await configureImageCacheBudget(
        cache: cache,
        readPhysicalMemoryBytes: () async => (7.4 * _gib).round(),
      );

      expect(budget, equals(expected));
      expect(cache.maximumSizeBytes, equals(expected));
    });

    test('sets the fallback budget when RAM cannot be read', () async {
      final cache = ImageCache();

      await configureImageCacheBudget(
        cache: cache,
        readPhysicalMemoryBytes: () async => null,
      );

      expect(
        cache.maximumSizeBytes,
        equals(AppConstants.imageCacheFallbackBytes),
      );
    });
  });
}
