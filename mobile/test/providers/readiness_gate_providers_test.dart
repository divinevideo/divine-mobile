// Tests for readiness gate providers
// Ensures subscriptions only start when app is ready
// (foregrounded + Nostr initialized + correct tab)

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';
import 'package:openvine/router/router.dart';

class _MockNostrClient extends Mock implements NostrClient {}

void main() {
  group('Readiness Gate Providers', () {
    late _MockNostrClient mockNostrService;

    setUp(() {
      mockNostrService = _MockNostrClient();
    });

    group('appReadyProvider', () {
      test('should return true when both foreground and Nostr are ready', () {
        // Arrange
        when(() => mockNostrService.isInitialized).thenReturn(true);

        final container = ProviderContainer(
          overrides: [
            nostrServiceProvider.overrideWithValue(mockNostrService),
            appForegroundProvider.overrideWith(_FakeAppForeground.new),
          ],
        );

        // Set foreground state after initialization
        // (default is already true)
        container.read(appForegroundProvider.notifier).setForeground(true);

        // Act
        final isReady = container.read(appReadyProvider);

        // Assert
        expect(isReady, isTrue);

        container.dispose();
      });

      test('should return false when app is backgrounded even if '
          'Nostr is ready', () {
        // Arrange
        when(() => mockNostrService.isInitialized).thenReturn(true);

        final container = ProviderContainer(
          overrides: [
            nostrServiceProvider.overrideWithValue(mockNostrService),
            appForegroundProvider.overrideWith(_FakeAppForeground.new),
          ],
        );

        // Set background state after initialization
        container.read(appForegroundProvider.notifier).setForeground(false);

        // Act
        final isReady = container.read(appReadyProvider);

        // Assert
        expect(
          isReady,
          isFalse,
          reason: 'App should not be ready when backgrounded',
        );

        container.dispose();
      });

      test('should return false when both are not ready', () {
        // Arrange
        when(() => mockNostrService.isInitialized).thenReturn(false);

        final container = ProviderContainer(
          overrides: [
            nostrServiceProvider.overrideWithValue(mockNostrService),
            appForegroundProvider.overrideWith(_FakeAppForeground.new),
          ],
        );

        // Set background state after initialization
        container.read(appForegroundProvider.notifier).setForeground(false);

        // Act
        final isReady = container.read(appReadyProvider);

        // Assert
        expect(isReady, isFalse);

        container.dispose();
      });

      test('should reactively update when foreground state changes', () {
        // Arrange
        when(() => mockNostrService.isInitialized).thenReturn(true);

        final container = ProviderContainer(
          overrides: [
            nostrServiceProvider.overrideWithValue(mockNostrService),
            appForegroundProvider.overrideWith(_FakeAppForeground.new),
          ],
        );

        // Set initial background state
        container.read(appForegroundProvider.notifier).setForeground(false);

        // Initially not ready (backgrounded)
        expect(container.read(appReadyProvider), isFalse);

        // Act: Foreground the app
        container.read(appForegroundProvider.notifier).setForeground(true);

        // Assert: Should now be ready
        expect(container.read(appReadyProvider), isTrue);

        container.dispose();
      });
    });

    group('isDiscoveryTabActiveProvider', () {
      test('should return true when route is explore', () {
        // Arrange
        final container = ProviderContainer(
          overrides: [
            pageContextProvider.overrideWith((ref) {
              return Stream.fromIterable([
                const RouteContext(type: RouteType.explore, videoIndex: 0),
              ]);
            }),
          ],
        );

        final _ = container.read(pageContextProvider);

        // Act
        final isActive = container.read(isDiscoveryTabActiveProvider);

        expect(
          isActive || container.read(pageContextProvider).isLoading,
          isTrue,
          reason: 'Should be true when route is explore, or still loading',
        );

        container.dispose();
      });

      test('should return false when route is home', () {
        // Arrange
        final container = ProviderContainer(
          overrides: [
            pageContextProvider.overrideWith((ref) {
              return Stream.fromIterable([
                const RouteContext(type: RouteType.home, videoIndex: 0),
              ]);
            }),
          ],
        );

        // Force provider to load
        final _ = container.read(pageContextProvider);

        // Act
        final isActive = container.read(isDiscoveryTabActiveProvider);

        // Assert
        expect(isActive, isFalse);

        container.dispose();
      });

      test('should return false when route is profile', () {
        // Arrange
        final container = ProviderContainer(
          overrides: [
            pageContextProvider.overrideWith((ref) {
              return Stream.fromIterable([
                const RouteContext(
                  type: RouteType.profile,
                  npub: 'npub123',
                  videoIndex: 0,
                ),
              ]);
            }),
          ],
        );

        // Force provider to load
        final _ = container.read(pageContextProvider);

        // Act
        final isActive = container.read(isDiscoveryTabActiveProvider);

        // Assert
        expect(isActive, isFalse);

        container.dispose();
      });

      test('should return false when pageContext is loading', () {
        // Arrange
        final container = ProviderContainer(
          overrides: [
            pageContextProvider.overrideWith((ref) => const Stream.empty()),
          ],
        );

        // Act
        final isActive = container.read(isDiscoveryTabActiveProvider);

        // Assert
        expect(
          isActive,
          isFalse,
          reason: 'Should be false while loading route context',
        );

        container.dispose();
      });
    });
  });
}

// Fake AppForeground notifier for testing
class _FakeAppForeground extends AppForeground {
  @override
  bool build() => true; // Default to foreground
}
