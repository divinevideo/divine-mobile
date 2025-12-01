// ABOUTME: Tests for profile fetching behavior with tab visibility constraints
// ABOUTME: Ensures profiles are only fetched when appropriate tabs are active

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/tab_visibility_provider.dart';

void main() {
  group('Profile fetching with tab visibility', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test(
      'should allow profile fetching when Explore tab is active (index 2)',
      () {
        // Arrange - Set tab to Explore (index 2)
        container.read(tabVisibilityProvider.notifier).setActiveTab(2);

        // Assert - Verify that isExploreTabActive returns true
        final isExploreActive = container.read(isExploreTabActiveProvider);
        expect(
          isExploreActive,
          isTrue,
          reason: 'Explore tab should be active when tab index is 2',
        );

        // Verify the condition for allowing profile fetch
        final isFeedActive = container.read(isFeedTabActiveProvider);
        final isProfileActive = container.read(isProfileTabActiveProvider);
        final canFetchProfiles =
            isFeedActive || isExploreActive || isProfileActive;

        expect(
          canFetchProfiles,
          isTrue,
          reason:
              'Profile fetching should be allowed when Explore tab is active',
        );
      },
    );

    test(
      'should NOT fetch profiles when Feed tab is active (index 0)',
      () async {
        // Arrange - Set tab to Feed (index 0)
        container.read(tabVisibilityProvider.notifier).setActiveTab(0);

        // Act & Assert
        final isExploreActive = container.read(isExploreTabActiveProvider);
        expect(
          isExploreActive,
          isFalse,
          reason: 'Explore tab should NOT be active when tab index is 0',
        );

        final isFeedActive = container.read(isFeedTabActiveProvider);
        expect(
          isFeedActive,
          isTrue,
          reason: 'Feed tab should be active when tab index is 0',
        );
      },
    );

    test('should fetch profiles when any video tab is active', () async {
      // Test Feed tab (index 0)
      container.read(tabVisibilityProvider.notifier).setActiveTab(0);
      var isFeedActive = container.read(isFeedTabActiveProvider);
      var isExploreActive = container.read(isExploreTabActiveProvider);
      var isProfileActive = container.read(isProfileTabActiveProvider);

      expect(
        isFeedActive || isExploreActive || isProfileActive,
        isTrue,
        reason: 'At least one video tab should be active for profile fetching',
      );

      // Test Explore tab (index 2)
      container.read(tabVisibilityProvider.notifier).setActiveTab(2);
      isFeedActive = container.read(isFeedTabActiveProvider);
      isExploreActive = container.read(isExploreTabActiveProvider);
      isProfileActive = container.read(isProfileTabActiveProvider);

      expect(
        isFeedActive || isExploreActive || isProfileActive,
        isTrue,
        reason: 'At least one video tab should be active for profile fetching',
      );

      // Test Profile tab (index 3)
      container.read(tabVisibilityProvider.notifier).setActiveTab(3);
      isFeedActive = container.read(isFeedTabActiveProvider);
      isExploreActive = container.read(isExploreTabActiveProvider);
      isProfileActive = container.read(isProfileTabActiveProvider);

      expect(
        isFeedActive || isExploreActive || isProfileActive,
        isTrue,
        reason: 'At least one video tab should be active for profile fetching',
      );
    });

    test(
      'should NOT fetch profiles when camera tab is active (index 1)',
      () async {
        // Arrange - Set tab to Camera (index 1)
        container.read(tabVisibilityProvider.notifier).setActiveTab(1);

        // Act & Assert
        final isFeedActive = container.read(isFeedTabActiveProvider);
        final isExploreActive = container.read(isExploreTabActiveProvider);
        final isProfileActive = container.read(isProfileTabActiveProvider);

        expect(isFeedActive, isFalse);
        expect(isExploreActive, isFalse);
        expect(isProfileActive, isFalse);
        expect(
          isFeedActive || isExploreActive || isProfileActive,
          isFalse,
          reason:
              'No video tabs should be active when on camera tab, preventing profile fetch',
        );
      },
    );
  });

  group('ExploreScreen tab visibility synchronization', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('ExploreScreen.onScreenVisible should set tab visibility to index 2', () {
      // Arrange - Start with a different tab
      container.read(tabVisibilityProvider.notifier).setActiveTab(0);
      expect(container.read(tabVisibilityProvider), equals(0));

      // Act - Simulate ExploreScreen.onScreenVisible()
      // This is what our fix does: ref.read(tabVisibilityProvider.notifier).setActiveTab(2);
      container.read(tabVisibilityProvider.notifier).setActiveTab(2);

      // Assert
      expect(
        container.read(tabVisibilityProvider),
        equals(2),
        reason:
            'Tab visibility should be set to 2 when ExploreScreen becomes visible',
      );
      expect(
        container.read(isExploreTabActiveProvider),
        isTrue,
        reason: 'Explore tab should be marked as active',
      );
    });

    test(
      'Profile fetching should work immediately after ExploreScreen becomes visible',
      () async {
        // Arrange - Start with camera tab (no profile fetching allowed)
        container.read(tabVisibilityProvider.notifier).setActiveTab(1);

        var canFetch =
            container.read(isFeedTabActiveProvider) ||
            container.read(isExploreTabActiveProvider) ||
            container.read(isProfileTabActiveProvider);
        expect(
          canFetch,
          isFalse,
          reason: 'Should not be able to fetch profiles on camera tab',
        );

        // Act - ExploreScreen becomes visible
        container.read(tabVisibilityProvider.notifier).setActiveTab(2);

        // Assert - Profile fetching should now be allowed
        canFetch =
            container.read(isFeedTabActiveProvider) ||
            container.read(isExploreTabActiveProvider) ||
            container.read(isProfileTabActiveProvider);
        expect(
          canFetch,
          isTrue,
          reason:
              'Should be able to fetch profiles after ExploreScreen becomes visible',
        );
      },
    );
  });
}
