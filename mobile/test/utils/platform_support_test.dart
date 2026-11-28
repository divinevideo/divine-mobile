import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/platform_support.dart';

void main() {
  group('isFirebaseSupported', () {
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('is true on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(isFirebaseSupported, isTrue);
    });

    test('is true on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(isFirebaseSupported, isTrue);
    });

    test('is true on macOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(isFirebaseSupported, isTrue);
    });

    test('is false on Linux', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(isFirebaseSupported, isFalse);
    });

    test('is false on Windows', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(isFirebaseSupported, isFalse);
    });
  });

  group('hasNativeVideoPlayer', () {
    tearDown(() {
      debugDefaultTargetPlatformOverride = null;
    });

    test('is true on Android', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.android;
      expect(hasNativeVideoPlayer, isTrue);
    });

    test('is true on iOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
      expect(hasNativeVideoPlayer, isTrue);
    });

    test('is true on macOS', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.macOS;
      expect(hasNativeVideoPlayer, isTrue);
    });

    test('is false on Linux', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.linux;
      expect(hasNativeVideoPlayer, isFalse);
    });

    test('is true on Windows', () {
      debugDefaultTargetPlatformOverride = TargetPlatform.windows;
      expect(hasNativeVideoPlayer, isTrue);
    });
  });
}
