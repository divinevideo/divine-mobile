// ABOUTME: Tests for tab visibility provider that manages active tab state
// ABOUTME: Ensures proper tab switching and visibility state management

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/tab_visibility_provider.dart';

void main() {
  group('TabVisibility Provider Tests', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('TabVisibility provider should start with tab 0 as active', () {
      // Arrange & Act
      final activeTab = container.read(tabVisibilityProvider);

      // Assert
      expect(activeTab, equals(0));
    });

    test(
      'TabVisibility provider should update active tab when setActiveTab is called',
      () {
        // Arrange
        final notifier = container.read(tabVisibilityProvider.notifier);

        // Act
        notifier.setActiveTab(2);
        final activeTab = container.read(tabVisibilityProvider);

        // Assert
        expect(activeTab, equals(2));
      },
    );

    test('TabVisibility provider should notify listeners when tab changes', () {
      // Arrange
      final notifier = container.read(tabVisibilityProvider.notifier);
      int? capturedValue;

      container.listen(tabVisibilityProvider, (previous, next) {
        capturedValue = next;
      });

      // Act
      notifier.setActiveTab(1);

      // Assert
      expect(capturedValue, equals(1));
    });

    test('isFeedTabActive should return true when tab 0 is active', () {
      // Arrange & Act
      final isFeedActive = container.read(isFeedTabActiveProvider);

      // Assert
      expect(isFeedActive, isTrue);
    });

    test('isFeedTabActive should return false when tab 1 is active', () {
      // Arrange
      final tabNotifier = container.read(tabVisibilityProvider.notifier);

      // Act
      tabNotifier.setActiveTab(1);
      final isFeedActive = container.read(isFeedTabActiveProvider);

      // Assert
      expect(isFeedActive, isFalse);
    });

    test('isExploreTabActive should return true when tab 2 is active', () {
      // Arrange
      final tabNotifier = container.read(tabVisibilityProvider.notifier);

      // Act
      tabNotifier.setActiveTab(2);
      final isExploreActive = container.read(isExploreTabActiveProvider);

      // Assert
      expect(isExploreActive, isTrue);
    });

    test('isExploreTabActive should return false when tab 0 is active', () {
      // Arrange & Act
      final isExploreActive = container.read(isExploreTabActiveProvider);

      // Assert
      expect(isExploreActive, isFalse);
    });

    test('isProfileTabActive should return true when tab 3 is active', () {
      // Arrange
      final tabNotifier = container.read(tabVisibilityProvider.notifier);

      // Act
      tabNotifier.setActiveTab(3);
      final isProfileActive = container.read(isProfileTabActiveProvider);

      // Assert
      expect(isProfileActive, isTrue);
    });

    test('isProfileTabActive should return false when tab 1 is active', () {
      // Arrange
      final tabNotifier = container.read(tabVisibilityProvider.notifier);

      // Act
      tabNotifier.setActiveTab(1);
      final isProfileActive = container.read(isProfileTabActiveProvider);

      // Assert
      expect(isProfileActive, isFalse);
    });

    test(
      'tab visibility providers should update reactively when tab changes',
      () {
        // Arrange
        final tabNotifier = container.read(tabVisibilityProvider.notifier);

        // Initial state - feed should be active
        expect(container.read(isFeedTabActiveProvider), isTrue);
        expect(container.read(isExploreTabActiveProvider), isFalse);
        expect(container.read(isProfileTabActiveProvider), isFalse);

        // Act - switch to explore tab
        tabNotifier.setActiveTab(2);

        // Assert
        expect(container.read(isFeedTabActiveProvider), isFalse);
        expect(container.read(isExploreTabActiveProvider), isTrue);
        expect(container.read(isProfileTabActiveProvider), isFalse);

        // Act - switch to profile tab
        tabNotifier.setActiveTab(3);

        // Assert
        expect(container.read(isFeedTabActiveProvider), isFalse);
        expect(container.read(isExploreTabActiveProvider), isFalse);
        expect(container.read(isProfileTabActiveProvider), isTrue);
      },
    );
  });
}
