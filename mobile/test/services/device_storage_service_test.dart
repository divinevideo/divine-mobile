// ABOUTME: Tests DeviceStorageService's method-channel reading of disk space.
// ABOUTME: Covers the mobile platforms, unsupported platforms and failures.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/device_storage_service.dart';
import 'package:unified_logger/unified_logger.dart';

const _channel = MethodChannel('divine/device_storage');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void answerWith(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, handler);
  }

  group(DeviceStorageService, () {
    group('storageSpace', () {
      tearDown(() {
        debugDefaultTargetPlatformOverride = null;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(_channel, null);
      });

      for (final platform in [TargetPlatform.android, TargetPlatform.iOS]) {
        test('returns what the channel reports on ${platform.name}', () async {
          debugDefaultTargetPlatformOverride = platform;
          final methods = <String>[];
          answerWith((call) async {
            methods.add(call.method);
            return {'totalBytes': 128000000000, 'freeBytes': 9000000000};
          });

          final space = await const DeviceStorageService().storageSpace();

          expect(
            space,
            equals(
              const DeviceStorageSpace(
                totalBytes: 128000000000,
                freeBytes: 9000000000,
              ),
            ),
          );
          expect(methods, equals(['getStorageSpace']));
        });
      }

      test('returns null without asking on desktop', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        var asked = false;
        answerWith((_) async {
          asked = true;
          return {'totalBytes': 1, 'freeBytes': 1};
        });

        final space = await const DeviceStorageService().storageSpace();

        expect(space, isNull);
        expect(asked, isFalse);
      });

      test('returns null when the channel reports nothing', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        answerWith((_) async => null);

        expect(await const DeviceStorageService().storageSpace(), isNull);
      });

      test('returns null for a reading that cannot be a real disk', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        const readings = <Map<String, Object?>>[
          {'totalBytes': 0, 'freeBytes': 0},
          {'totalBytes': 64000000000},
          {'totalBytes': 64000000000, 'freeBytes': -1},
          {'totalBytes': 64000000000, 'freeBytes': 'lots'},
          {'totalBytes': 1000, 'freeBytes': 2000},
        ];
        for (final reading in readings) {
          answerWith((_) async => reading);

          expect(
            await const DeviceStorageService().storageSpace(),
            isNull,
            reason: '$reading',
          );
        }
      });

      group('logs', () {
        List<String> storageWarnings() => [
          for (final entry in LogCaptureService().getRecentLogs())
            if (entry.name == 'DeviceStorageService' &&
                entry.level == LogLevel.warning)
              entry.message,
        ];

        test('a warning when the channel reports nothing', () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
          answerWith((_) async => null);
          final before = storageWarnings().length;

          await const DeviceStorageService().storageSpace();

          expect(storageWarnings().skip(before), [
            'Device storage unavailable from the platform',
          ]);
        });

        test('a warning without the figures for a rejected reading', () async {
          debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
          answerWith(
            (_) async => {'totalBytes': 1234567, 'freeBytes': 7654321},
          );
          final before = storageWarnings().length;

          await const DeviceStorageService().storageSpace();

          final logged = storageWarnings().skip(before).toList();
          expect(logged, ['Device storage reading rejected as inconsistent']);
          expect(logged.single, isNot(contains('1234567')));
          expect(logged.single, isNot(contains('7654321')));
        });
      });

      test('returns null when the platform call fails', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        answerWith((_) async => throw PlatformException(code: 'UNAVAILABLE'));

        expect(await const DeviceStorageService().storageSpace(), isNull);
      });

      test('returns null when the native side has no channel', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        expect(await const DeviceStorageService().storageSpace(), isNull);
      });
    });
  });
}
