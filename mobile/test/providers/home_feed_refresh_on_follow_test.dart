// ABOUTME: Tests that home feed refreshes when following list changes, even when length stays same
// ABOUTME: Regression test for bug where unfollow+follow with same count didn't trigger refresh

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/home_feed_provider.dart';
import 'package:openvine/providers/social_providers.dart' as social;
import 'package:openvine/state/social_state.dart';
import 'package:riverpod/riverpod.dart';

/// Test notifier that returns a fixed social state
class TestSocialNotifier extends social.SocialNotifier {
  final SocialState _state;

  TestSocialNotifier(this._state);

  @override
  SocialState build() => _state;
}

void main() {
  group('HomeFeed refresh on follow/unfollow', () {
    test(
      'BUG: should rebuild home feed when following list changes even if count stays same',
      () async {
        // Setup: Following Alice and Bob (2 people)
        final container = ProviderContainer(
          overrides: [
            social.socialProvider.overrideWith(() {
              return TestSocialNotifier(
                const SocialState(
                  isInitialized: true,
                  followingPubkeys: [
                    'alice1230000000000000000000000000000000000000000000000000000000',
                    'bob45600000000000000000000000000000000000000000000000000000000',
                  ],
                ),
              );
            }),
          ],
        );

        // Get initial state - should be stable
        final initialState = await container.read(homeFeedProvider.future);
        final initialBuildId = initialState.hashCode;

        // Change following list: unfollow Bob, follow Charlie (still 2 people)
        container.updateOverrides([
          social.socialProvider.overrideWith(() {
            return TestSocialNotifier(
              const SocialState(
                isInitialized: true,
                followingPubkeys: [
                  'alice1230000000000000000000000000000000000000000000000000000000',
                  'charlie7890000000000000000000000000000000000000000000000000000', // Bob -> Charlie
                ],
              ),
            );
          }),
        ]);

        // Wait for provider to react to change
        await Future.delayed(const Duration(milliseconds: 200));

        // Get new state
        final newState = await container.read(homeFeedProvider.future);
        final newBuildId = newState.hashCode;

        // The state should have been rebuilt (different instance)
        expect(
          newBuildId != initialBuildId,
          isTrue,
          reason:
              'HomeFeed should rebuild when following list changes, even if count stays same',
        );

        container.dispose();
      },
    );

    test('should rebuild home feed when following count increases', () async {
      // Setup: Following Alice (1 person)
      final container = ProviderContainer(
        overrides: [
          social.socialProvider.overrideWith(() {
            return TestSocialNotifier(
              const SocialState(
                isInitialized: true,
                followingPubkeys: [
                  'alice1230000000000000000000000000000000000000000000000000000000',
                ],
              ),
            );
          }),
        ],
      );

      // Get initial state
      final initialState = await container.read(homeFeedProvider.future);
      final initialBuildId = initialState.hashCode;

      // Follow Bob (now 2 people)
      container.updateOverrides([
        social.socialProvider.overrideWith(() {
          return TestSocialNotifier(
            const SocialState(
              isInitialized: true,
              followingPubkeys: [
                'alice1230000000000000000000000000000000000000000000000000000000',
                'bob45600000000000000000000000000000000000000000000000000000000',
              ],
            ),
          );
        }),
      ]);

      // Wait for provider to react
      await Future.delayed(const Duration(milliseconds: 200));

      // Get new state
      final newState = await container.read(homeFeedProvider.future);
      final newBuildId = newState.hashCode;

      // State should have been rebuilt
      expect(
        newBuildId != initialBuildId,
        isTrue,
        reason: 'HomeFeed should rebuild when following count increases',
      );

      container.dispose();
    });

    test('should rebuild home feed when following count decreases', () async {
      // Setup: Following Alice and Bob (2 people)
      final container = ProviderContainer(
        overrides: [
          social.socialProvider.overrideWith(() {
            return TestSocialNotifier(
              const SocialState(
                isInitialized: true,
                followingPubkeys: [
                  'alice1230000000000000000000000000000000000000000000000000000000',
                  'bob45600000000000000000000000000000000000000000000000000000000',
                ],
              ),
            );
          }),
        ],
      );

      // Get initial state
      final initialState = await container.read(homeFeedProvider.future);
      final initialBuildId = initialState.hashCode;

      // Unfollow Bob (now 1 person)
      container.updateOverrides([
        social.socialProvider.overrideWith(() {
          return TestSocialNotifier(
            const SocialState(
              isInitialized: true,
              followingPubkeys: [
                'alice1230000000000000000000000000000000000000000000000000000000',
              ],
            ),
          );
        }),
      ]);

      // Wait for provider to react
      await Future.delayed(const Duration(milliseconds: 200));

      // Get new state
      final newState = await container.read(homeFeedProvider.future);
      final newBuildId = newState.hashCode;

      // State should have been rebuilt
      expect(
        newBuildId != initialBuildId,
        isTrue,
        reason: 'HomeFeed should rebuild when following count decreases',
      );

      container.dispose();
    });

    test('should show empty feed when unfollowing everyone', () async {
      // Setup: Following Alice
      final container = ProviderContainer(
        overrides: [
          social.socialProvider.overrideWith(() {
            return TestSocialNotifier(
              const SocialState(
                isInitialized: true,
                followingPubkeys: [
                  'alice1230000000000000000000000000000000000000000000000000000000',
                ],
              ),
            );
          }),
        ],
      );

      // Get initial state
      await container.read(homeFeedProvider.future);

      // Unfollow everyone
      container.updateOverrides([
        social.socialProvider.overrideWith(() {
          return TestSocialNotifier(
            const SocialState(isInitialized: true, followingPubkeys: []),
          );
        }),
      ]);

      // Wait for provider to react
      await Future.delayed(const Duration(milliseconds: 200));

      // Home feed should be empty
      final newState = await container.read(homeFeedProvider.future);
      expect(
        newState.videos,
        isEmpty,
        reason: 'Home feed should be empty when not following anyone',
      );
      expect(newState.hasMoreContent, isFalse);

      container.dispose();
    });
  });
}
