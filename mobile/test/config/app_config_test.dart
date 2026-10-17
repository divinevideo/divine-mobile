import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/config/app_config.dart';
import 'package:openvine/models/environment_config.dart';

void main() {
  group('AppConfig.resolveLiveApiBaseUrl', () {
    test('prefers an explicit live API override', () {
      final baseUrl = AppConfig.resolveLiveApiBaseUrl(
        overrideBaseUrl: 'http://192.168.0.10:8088',
        appEnvironment: AppEnvironment.local,
        targetPlatform: TargetPlatform.android,
      );

      expect(baseUrl, equals('http://192.168.0.10:8088'));
    });

    test('uses the Android emulator host for the local environment', () {
      final baseUrl = AppConfig.resolveLiveApiBaseUrl(
        appEnvironment: AppEnvironment.local,
        targetPlatform: TargetPlatform.android,
      );

      expect(baseUrl, equals('http://10.0.2.2:8088'));
    });

    test('uses localhost for iOS simulator and desktop local defaults', () {
      final iosBaseUrl = AppConfig.resolveLiveApiBaseUrl(
        appEnvironment: AppEnvironment.local,
        targetPlatform: TargetPlatform.iOS,
      );
      final desktopBaseUrl = AppConfig.resolveLiveApiBaseUrl(
        appEnvironment: AppEnvironment.local,
        targetPlatform: TargetPlatform.macOS,
      );

      expect(iosBaseUrl, equals('http://localhost:8088'));
      expect(desktopBaseUrl, equals('http://localhost:8088'));
    });

    for (final environment in [
      AppEnvironment.production,
      AppEnvironment.staging,
      AppEnvironment.poc,
    ]) {
      test('uses the hosted live API for ${environment.name}', () {
        final baseUrl = AppConfig.resolveLiveApiBaseUrl(
          appEnvironment: environment,
          targetPlatform: TargetPlatform.android,
        );

        expect(baseUrl, equals(productionLiveApiBaseUrl));
      });
    }

    test(
      'defaults to the hosted live API when no environment is passed, '
      'because release builds set DEFAULT_ENV and never ENVIRONMENT',
      () {
        // Test runs define neither DEFAULT_ENV nor ENVIRONMENT, matching a
        // production release build.
        expect(buildTimeDefaultEnvironment, equals(AppEnvironment.production));

        final baseUrl = AppConfig.resolveLiveApiBaseUrl(
          targetPlatform: TargetPlatform.android,
        );

        expect(baseUrl, equals(productionLiveApiBaseUrl));
        expect(AppConfig.liveApiBaseUrl, equals(productionLiveApiBaseUrl));
      },
    );
  });
}
