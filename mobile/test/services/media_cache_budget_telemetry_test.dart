// ABOUTME: Tests the coarse disk and cache-budget labels recorded so cache
// ABOUTME: sizing can be tuned from real devices, and where they are sent.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/storage_cache_constants.dart';
import 'package:openvine/services/device_storage_service.dart';
import 'package:openvine/services/media_cache_budget.dart';
import 'package:openvine/services/media_cache_budget_telemetry.dart';

const int _mb = 1024 * 1024;
const int _gb = 1000 * 1000 * 1000;

MediaCacheBudget _video(int bytes) =>
    MediaCacheBudget(videoBytes: bytes, imageBytes: 0, playerBytes: 0);

Map<String, String> _properties({
  DeviceStorageSpace? storage,
  int videoBytes = kCacheLimitDefaultBytes,
  bool automatic = true,
  bool diskSpaceMayLeaveDevice = true,
}) => mediaCacheBudgetProperties(
  storage: storage,
  budget: _video(videoBytes),
  automatic: automatic,
  diskSpaceMayLeaveDevice: diskSpaceMayLeaveDevice,
);

void main() {
  group('mediaCacheBudgetProperties', () {
    test('names the disk by the marketed size its reading falls under', () {
      // Android reports the data partition only, so a 64 GB phone reads low.
      const readings = {
        14 * _gb: '16gb',
        58 * _gb: '64gb',
        64 * _gb: '64gb',
        119 * _gb: '128gb',
        250 * _gb: '256gb',
        500 * _gb: '512gb',
        1000 * _gb: '1tb',
        2000 * _gb: '2tb_plus',
      };
      for (final MapEntry(key: total, value: label) in readings.entries) {
        expect(
          _properties(
            storage: DeviceStorageSpace(totalBytes: total, freeBytes: 0),
          )['storage_total'],
          equals(label),
          reason: '$total bytes',
        );
      }
    });

    test('buckets how much of the disk is free', () {
      const readings = {
        3: 'lt5',
        7: '5_10',
        12: '10_15',
        20: '15_25',
        40: '25_50',
        80: '50_plus',
      };
      for (final MapEntry(key: percent, value: label) in readings.entries) {
        expect(
          _properties(
            storage: DeviceStorageSpace(
              totalBytes: 100 * _gb,
              freeBytes: percent * _gb,
            ),
          )['storage_free_pct'],
          equals(label),
          reason: '$percent%',
        );
      }
    });

    test('says when the disk could not be read', () {
      final properties = _properties();

      expect(properties['storage_total'], equals('unknown'));
      expect(properties['storage_free_pct'], equals('unknown'));
    });

    test('records whether the size is automatic or fixed', () {
      expect(_properties()['cache_mode'], equals('automatic'));
      expect(_properties(automatic: false)['cache_mode'], equals('fixed'));
    });

    test('buckets the video budget, marking the floor', () {
      const budgets = {
        kVideoCacheFloorBytes: 'floor',
        200 * _mb: 'lt256mb',
        700 * _mb: 'lt1gb',
        1536 * _mb: 'lt2gb',
        kCacheLimitDefaultBytes: '2gb',
        kCacheLimitMaxBytes: 'gt2gb',
      };
      for (final MapEntry(key: bytes, value: label) in budgets.entries) {
        expect(
          _properties(videoBytes: bytes)['cache_budget'],
          equals(label),
          reason: '$bytes bytes',
        );
      }
    });

    test('carries nothing derived from disk space where it may not leave '
        'the device', () {
      // Apple's E174.1: disk space read to free space, and anything derived
      // from it — the budget included — may not be sent off-device.
      final properties = _properties(
        storage: const DeviceStorageSpace(
          totalBytes: 64 * _gb,
          freeBytes: 2 * _gb,
        ),
        videoBytes: kVideoCacheFloorBytes,
        diskSpaceMayLeaveDevice: false,
      );

      expect(properties, equals({'cache_mode': 'automatic'}));
    });

    test('keeps every label within analytics user-property limits', () {
      final properties = _properties(
        storage: const DeviceStorageSpace(
          totalBytes: 2000 * _gb,
          freeBytes: 1000 * _gb,
        ),
      );

      for (final MapEntry(:key, :value) in properties.entries) {
        expect(key.length, lessThanOrEqualTo(24));
        expect(key, matches(RegExp(r'^[a-z][a-z0-9_]*$')));
        expect(value.length, lessThanOrEqualTo(36));
      }
    });
  });

  group('reportMediaCacheBudgetProperties', () {
    test('sends every property to analytics and to crash reports', () async {
      final analytics = <String, String?>{};
      final crashKeys = <String, Object>{};

      await reportMediaCacheBudgetProperties(
        const {'cache_mode': 'automatic', 'storage_total': '64gb'},
        setUserProperty: ({required name, required value}) async =>
            analytics[name] = value,
        setCustomKey: (key, value) async => crashKeys[key] = value,
      );

      expect(
        analytics,
        equals({'cache_mode': 'automatic', 'storage_total': '64gb'}),
      );
      expect(
        crashKeys,
        equals({'cache_mode': 'automatic', 'storage_total': '64gb'}),
      );
    });
  });
}
