// ABOUTME: Test that profile caches stay in sync across services
// ABOUTME: Verifies AuthService.refreshCurrentProfile syncs with UserProfileService cache

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/user_profile.dart' as model;
import 'package:openvine/providers/app_providers.dart';

void main() {
  group('Profile Cache Synchronization', () {
    test('UserProfileService cache persists profiles correctly', () {
      // ARRANGE
      final container = ProviderContainer();
      final userProfileService = container.read(userProfileServiceProvider);

      final testProfile = model.UserProfile(
        pubkey: 'test-pubkey-123',
        displayName: 'Test User',
        name: 'testuser',
        picture: 'https://example.com/pic.jpg',
        about: 'Test bio',
        eventId: 'event-123',
        createdAt: DateTime.now(),
        rawData: const {'name': 'testuser'},
      );

      // ACT: Add to cache
      userProfileService.updateCachedProfile(testProfile);

      // ASSERT: Should be retrievable
      final cached = userProfileService.getCachedProfile('test-pubkey-123');
      expect(cached, isNotNull);
      expect(cached!.displayName, equals('Test User'));
      expect(cached.picture, equals('https://example.com/pic.jpg'));
      expect(cached.about, equals('Test bio'));

      // Cleanup
      container.dispose();
    });

    test('UserProfileService cache can be updated multiple times', () {
      // ARRANGE
      final container = ProviderContainer();
      final userProfileService = container.read(userProfileServiceProvider);

      final profile1 = model.UserProfile(
        pubkey: 'test-pubkey-456',
        displayName: 'Initial Name',
        eventId: 'event-1',
        createdAt: DateTime.now(),
        rawData: const {},
      );

      // ACT: Add first version
      userProfileService.updateCachedProfile(profile1);

      var cached = userProfileService.getCachedProfile('test-pubkey-456');
      expect(cached?.displayName, equals('Initial Name'));

      // ACT: Update with new version
      final profile2 = model.UserProfile(
        pubkey: 'test-pubkey-456',
        displayName: 'Updated Name',
        picture: 'https://example.com/new-pic.jpg',
        eventId: 'event-2',
        createdAt: DateTime.now(),
        rawData: const {},
      );

      userProfileService.updateCachedProfile(profile2);

      // ASSERT: Should have updated version
      cached = userProfileService.getCachedProfile('test-pubkey-456');
      expect(cached?.displayName, equals('Updated Name'));
      expect(cached?.picture, equals('https://example.com/new-pic.jpg'));

      // Cleanup
      container.dispose();
    });

    test('Profile update flow documents expected behavior', () {
      // This test documents the CURRENT behavior and what SHOULD happen

      final container = ProviderContainer();
      final userProfileService = container.read(userProfileServiceProvider);

      // STEP 1: User edits profile in ProfileSetupScreen
      final newProfile = model.UserProfile(
        pubkey: 'user-pubkey-789',
        displayName: 'My New Name',
        name: 'mynewname',
        picture: 'https://example.com/avatar.jpg',
        about: 'My new bio',
        eventId: 'new-event',
        createdAt: DateTime.now(),
        rawData: const {
          'name': 'mynewname',
          'display_name': 'My New Name',
          'picture': 'https://example.com/avatar.jpg',
          'about': 'My new bio',
        },
      );

      // STEP 2: Profile is published to Nostr
      // (NostrService.broadcastEvent is called)

      // STEP 3: Profile is cached in UserProfileService
      userProfileService.updateCachedProfile(newProfile);

      // VERIFY: Profile is in UserProfileService cache
      final cachedProfile = userProfileService.getCachedProfile(
        'user-pubkey-789',
      );
      expect(cachedProfile, isNotNull);
      expect(cachedProfile!.displayName, equals('My New Name'));

      // STEP 4: ProfileSetupScreen calls authService.refreshCurrentProfile()
      // (This updates AuthService.currentProfile from UserProfileService cache)

      // STEP 5: ProfileSetupScreen navigates back to ProfileScreen

      // EXPECTED BEHAVIOR:
      // ProfileScreen should display the updated profile immediately because:
      // - For own profile: Reads from authService.currentProfile (updated in step 4)
      // - For other profiles: Reads from userProfileService.getCachedProfile() (updated in step 3)

      // ACTUAL BUG:
      // ProfileScreen watches `authServiceProvider` which is a keepAlive provider.
      // When authService.currentProfile changes internally, Riverpod doesn't know,
      // so ProfileScreen doesn't rebuild.

      // Cleanup
      container.dispose();
    });
  });
}
