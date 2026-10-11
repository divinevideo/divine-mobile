import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/config/app_config.dart';

void main() {
  group('AppConfig.resolveLiveApiBaseUrl', () {
    test('prefers an explicit live API override', () {
      final baseUrl = AppConfig.resolveLiveApiBaseUrl(
        overrideBaseUrl: 'http://192.168.0.10:8088',
        environmentName: 'development',
        targetPlatform: TargetPlatform.android,
      );

      expect(baseUrl, 'http://192.168.0.10:8088');
    });

    test('uses the Android emulator host for development defaults', () {
      final baseUrl = AppConfig.resolveLiveApiBaseUrl(
        environmentName: 'development',
        targetPlatform: TargetPlatform.android,
      );

      expect(baseUrl, 'http://10.0.2.2:8088');
    });

    test('uses localhost for iOS simulator and desktop defaults', () {
      final iosBaseUrl = AppConfig.resolveLiveApiBaseUrl(
        environmentName: 'development',
        targetPlatform: TargetPlatform.iOS,
      );
      final desktopBaseUrl = AppConfig.resolveLiveApiBaseUrl(
        environmentName: 'development',
        targetPlatform: TargetPlatform.macOS,
      );

      expect(iosBaseUrl, 'http://localhost:8088');
      expect(desktopBaseUrl, 'http://localhost:8088');
    });

    test('falls back to the hosted live API outside development', () {
      final baseUrl = AppConfig.resolveLiveApiBaseUrl(
        environmentName: 'production',
        targetPlatform: TargetPlatform.android,
      );

      expect(baseUrl, 'https://live.api.divine.video');
    });
  });
}
