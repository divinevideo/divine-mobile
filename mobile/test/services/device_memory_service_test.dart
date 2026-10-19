// ABOUTME: Tests DeviceMemoryService's method-channel reading of physical RAM.
// ABOUTME: Covers the mobile platforms, unsupported platforms and failures.

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/device_memory_service.dart';

const _channel = MethodChannel('divine/device_memory');

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  void answerWith(Future<Object?> Function(MethodCall call) handler) {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(_channel, handler);
  }

  group(DeviceMemoryService, () {
    group('physicalMemoryBytes', () {
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
            return 12196470784;
          });

          final bytes = await const DeviceMemoryService().physicalMemoryBytes();

          expect(bytes, equals(12196470784));
          expect(methods, equals(['getPhysicalMemoryBytes']));
        });
      }

      test('returns null without asking on desktop', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
        var asked = false;
        answerWith((_) async {
          asked = true;
          return 17179869184;
        });

        final bytes = await const DeviceMemoryService().physicalMemoryBytes();

        expect(bytes, isNull);
        expect(asked, isFalse);
      });

      test('returns null when the channel reports no memory', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;
        answerWith((_) async => null);
        expect(await const DeviceMemoryService().physicalMemoryBytes(), isNull);

        answerWith((_) async => 0);
        expect(await const DeviceMemoryService().physicalMemoryBytes(), isNull);
      });

      test('returns null when the platform call fails', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
        answerWith((_) async => throw PlatformException(code: 'UNAVAILABLE'));

        expect(await const DeviceMemoryService().physicalMemoryBytes(), isNull);
      });

      test('returns null when the native side has no channel', () async {
        debugDefaultTargetPlatformOverride = TargetPlatform.android;

        expect(await const DeviceMemoryService().physicalMemoryBytes(), isNull);
      });
    });
  });
}
