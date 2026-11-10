// ABOUTME: Tests for FunnelcakeAvailable provider fast-path and probe logic
// ABOUTME: Verifies *.divine.video APIs skip the probe and other APIs probe

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/models/environment_config.dart';
import 'package:openvine/providers/curation_providers.dart';
import 'package:openvine/providers/environment_provider.dart';

class _MockFunnelcakeApiClient extends Mock implements FunnelcakeApiClient {}

void main() {
  group(FunnelcakeAvailable, () {
    late _MockFunnelcakeApiClient mockFunnelcakeClient;

    setUp(() {
      mockFunnelcakeClient = _MockFunnelcakeApiClient();
    });

    ProviderContainer createContainer({
      EnvironmentConfig environment = EnvironmentConfig.production,
    }) {
      return ProviderContainer(
        overrides: [
          funnelcakeApiClientProvider.overrideWithValue(mockFunnelcakeClient),
          currentEnvironmentProvider.overrideWithValue(environment),
        ],
      );
    }

    test('returns false when Funnelcake client is not available', () async {
      when(() => mockFunnelcakeClient.isAvailable).thenReturn(false);

      final container = createContainer();
      addTearDown(container.dispose);

      final result = await container.read(funnelcakeAvailableProvider.future);

      expect(result, isFalse);
    });

    test(
      'returns true without probing a *.divine.video API',
      () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);

        final container = createContainer();
        addTearDown(container.dispose);

        final result = await container.read(funnelcakeAvailableProvider.future);

        expect(result, isTrue);
        verifyNever(() => mockFunnelcakeClient.getRecentVideos(limit: 1));
      },
    );

    test(
      'probes the POC API and returns true on success',
      () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getRecentVideos(limit: 1),
        ).thenAnswer((_) async => <VideoStats>[]);

        const customEnv = EnvironmentConfig(environment: AppEnvironment.poc);

        final container = createContainer(environment: customEnv);
        addTearDown(container.dispose);

        final result = await container.read(funnelcakeAvailableProvider.future);

        expect(result, isTrue);
        verify(() => mockFunnelcakeClient.getRecentVideos(limit: 1)).called(1);
      },
    );

    test(
      'probes the POC API and returns false on failure',
      () async {
        when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
        when(
          () => mockFunnelcakeClient.getRecentVideos(limit: 1),
        ).thenThrow(Exception('Connection refused'));

        const customEnv = EnvironmentConfig(environment: AppEnvironment.poc);

        final container = createContainer(environment: customEnv);
        addTearDown(container.dispose);

        final result = await container.read(funnelcakeAvailableProvider.future);

        expect(result, isFalse);
        verify(() => mockFunnelcakeClient.getRecentVideos(limit: 1)).called(1);
      },
    );

    test('refresh re-runs the probe', () async {
      when(() => mockFunnelcakeClient.isAvailable).thenReturn(true);
      when(
        () => mockFunnelcakeClient.getRecentVideos(limit: 1),
      ).thenAnswer((_) async => <VideoStats>[]);

      final container = createContainer(
        environment: const EnvironmentConfig(environment: AppEnvironment.poc),
      );
      addTearDown(container.dispose);

      expect(await container.read(funnelcakeAvailableProvider.future), isTrue);

      container.read(funnelcakeAvailableProvider.notifier).refresh();

      expect(await container.read(funnelcakeAvailableProvider.future), isTrue);
      verify(() => mockFunnelcakeClient.getRecentVideos(limit: 1)).called(2);
    });
  });
}
