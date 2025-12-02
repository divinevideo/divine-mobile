// Tests for app foreground state provider
// Ensures videos never play when app is backgrounded

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_foreground_provider.dart';

void main() {
  group('AppForeground Provider', () {
    test('should start in foreground state', () {
      final container = ProviderContainer();

      final state = container.read(appForegroundProvider);
      expect(state, isTrue, reason: 'App should start in foreground');

      container.dispose();
    });

    test(
      'should transition to background when setForeground(false) is called',
      () {
        final container = ProviderContainer();

        // Initially foreground
        expect(container.read(appForegroundProvider), isTrue);

        // Background the app
        container.read(appForegroundProvider.notifier).setForeground(false);

        // Should now be background
        expect(container.read(appForegroundProvider), isFalse);

        container.dispose();
      },
    );

    test(
      'should transition back to foreground when setForeground(true) is called',
      () {
        final container = ProviderContainer();

        // Start foreground
        expect(container.read(appForegroundProvider), isTrue);

        // Background the app
        container.read(appForegroundProvider.notifier).setForeground(false);
        expect(container.read(appForegroundProvider), isFalse);

        // Resume to foreground
        container.read(appForegroundProvider.notifier).setForeground(true);
        expect(container.read(appForegroundProvider), isTrue);

        container.dispose();
      },
    );

    test('should notify listeners when foreground state changes', () {
      final container = ProviderContainer();

      final states = <bool>[];

      // Listen to state changes
      container.listen(appForegroundProvider, (previous, next) {
        states.add(next);
      });

      // Trigger state changes
      container.read(appForegroundProvider.notifier).setForeground(false);
      container.read(appForegroundProvider.notifier).setForeground(true);
      container.read(appForegroundProvider.notifier).setForeground(false);

      expect(
        states,
        equals([false, true, false]),
        reason: 'Should emit state change for each setForeground call',
      );

      container.dispose();
    });

    test('should handle rapid foreground/background transitions', () {
      final container = ProviderContainer();

      // Rapid transitions
      for (int i = 0; i < 10; i++) {
        container
            .read(appForegroundProvider.notifier)
            .setForeground(i % 2 == 0);
      }

      // Final state should be false (last iteration i=9, 9%2=1, so false)
      expect(container.read(appForegroundProvider), isFalse);

      container.dispose();
    });

    test(
      'isAppInForegroundProvider should mirror appForegroundProvider state',
      () {
        final container = ProviderContainer();

        // Initially both should be true
        expect(container.read(appForegroundProvider), isTrue);
        expect(container.read(isAppInForegroundProvider), isTrue);

        // Background
        container.read(appForegroundProvider.notifier).setForeground(false);
        expect(container.read(appForegroundProvider), isFalse);
        expect(container.read(isAppInForegroundProvider), isFalse);

        // Foreground
        container.read(appForegroundProvider.notifier).setForeground(true);
        expect(container.read(appForegroundProvider), isTrue);
        expect(container.read(isAppInForegroundProvider), isTrue);

        container.dispose();
      },
    );
  });
}
