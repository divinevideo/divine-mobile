// ABOUTME: Tests for environment providers publishing service changes to state
// ABOUTME: Covers value propagation, a single subscription, and disposal cleanup

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/environment_provider.dart';
import 'package:openvine/services/environment_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingEnvironmentService extends EnvironmentService {
  int addListenerCalls = 0;
  int removeListenerCalls = 0;

  @override
  void addListener(VoidCallback listener) {
    addListenerCalls++;
    super.addListener(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    removeListenerCalls++;
    super.removeListener(listener);
  }
}

void main() {
  group('environment providers', () {
    late _RecordingEnvironmentService service;

    setUp(() async {
      SharedPreferences.setMockInitialValues(<String, Object>{});
      final prefs = await SharedPreferences.getInstance();
      service = _RecordingEnvironmentService();
      await service.initialize(sharedPreferences: prefs);
    });

    group('currentEnvironmentProvider', () {
      test('publishes environment changes without resubscribing', () async {
        final container = ProviderContainer(
          overrides: [environmentServiceProvider.overrideWithValue(service)],
        );
        addTearDown(container.dispose);

        final environments = <AppEnvironment>[];
        final subscription = container.listen(
          currentEnvironmentProvider,
          (_, next) => environments.add(next.environment),
        );

        expect(
          container.read(currentEnvironmentProvider).environment,
          equals(AppEnvironment.production),
        );
        expect(service.addListenerCalls, equals(1));

        await service.setEnvironment(AppEnvironment.staging);
        await pumpEventQueue();

        expect(environments, equals([AppEnvironment.staging]));
        expect(
          service.addListenerCalls,
          equals(1),
          reason: 'a notification must not rebuild the provider subscription',
        );

        subscription.close();
        await pumpEventQueue();
        expect(service.removeListenerCalls, equals(1));
      });
    });

    group('isDeveloperModeEnabledProvider', () {
      test('publishes developer mode changes without resubscribing', () async {
        final container = ProviderContainer(
          overrides: [environmentServiceProvider.overrideWithValue(service)],
        );
        addTearDown(container.dispose);

        final values = <bool>[];
        final subscription = container.listen(
          isDeveloperModeEnabledProvider,
          (_, next) => values.add(next),
        );

        expect(container.read(isDeveloperModeEnabledProvider), isFalse);
        expect(service.addListenerCalls, equals(1));

        await service.enableDeveloperMode();
        await pumpEventQueue();

        expect(values, equals([true]));
        expect(
          service.addListenerCalls,
          equals(1),
          reason: 'a notification must not rebuild the provider subscription',
        );

        subscription.close();
        await pumpEventQueue();
        expect(service.removeListenerCalls, equals(1));
      });
    });
  });
}
