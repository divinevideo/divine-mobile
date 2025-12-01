// ABOUTME: Tests for NostrInitialization state notifier
// ABOUTME: Ensures proper tracking of Nostr service initialization state

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/readiness_gate_providers.dart';

void main() {
  group('NostrInitialization', () {
    test('starts uninitialized (false)', () {
      // Arrange
      final container = ProviderContainer();

      // Act
      final state = container.read(nostrInitializationProvider);

      // Assert
      expect(state, isFalse, reason: 'Should start as uninitialized');

      container.dispose();
    });

    test('becomes true when markInitialized is called', () {
      // Arrange
      final container = ProviderContainer();

      // Act - mark as initialized
      container.read(nostrInitializationProvider.notifier).markInitialized();
      final state = container.read(nostrInitializationProvider);

      // Assert
      expect(
        state,
        isTrue,
        reason: 'Should be initialized after markInitialized()',
      );

      container.dispose();
    });

    test('notifies listeners when state changes', () {
      // Arrange
      final container = ProviderContainer();

      final states = <bool>[];
      container.listen(
        nostrInitializationProvider,
        (previous, next) => states.add(next),
      );

      // Act
      container.read(nostrInitializationProvider.notifier).markInitialized();

      // Assert
      expect(states, [
        true,
      ], reason: 'Should notify with true when initialized');

      container.dispose();
    });
  });

  group('nostrReadyProvider integration', () {
    test('returns false when NostrInitialization is false', () {
      // Arrange
      final container = ProviderContainer();

      // Act
      final ready = container.read(nostrReadyProvider);

      // Assert
      expect(ready, isFalse, reason: 'Should not be ready when uninitialized');

      container.dispose();
    });

    test('returns true when NostrInitialization is true', () {
      // Arrange
      final container = ProviderContainer();

      // Act - mark as initialized
      container.read(nostrInitializationProvider.notifier).markInitialized();
      final ready = container.read(nostrReadyProvider);

      // Assert
      expect(ready, isTrue, reason: 'Should be ready when initialized');

      container.dispose();
    });

    test('notifies listeners when initialization state changes', () async {
      // Arrange
      final container = ProviderContainer();

      // Read initial value to ensure provider is instantiated
      container.read(nostrReadyProvider);

      final readyStates = <bool>[];
      container.listen(
        nostrReadyProvider,
        (previous, next) => readyStates.add(next),
      );

      // Act
      container.read(nostrInitializationProvider.notifier).markInitialized();

      // Wait for any microtasks to complete
      await Future.delayed(Duration.zero);

      // Assert
      expect(
        readyStates,
        [true],
        reason: 'nostrReadyProvider should notify when initialization changes',
      );

      container.dispose();
    });
  });
}
