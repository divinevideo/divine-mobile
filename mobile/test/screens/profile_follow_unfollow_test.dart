// ABOUTME: Integration test for profile screen follow/unfollow functionality
// ABOUTME: Tests the actual follow/unfollow behavior with proper mocking

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:openvine/helpers/follow_actions_helper.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/providers/app_providers.dart';

import 'profile_follow_unfollow_test.mocks.dart';

@GenerateMocks([SocialService, AuthService])
void main() {
  group('Profile Follow/Unfollow Integration Tests', () {
    late MockSocialService mockSocialService;
    late MockAuthService mockAuthService;

    setUp(() {
      mockSocialService = MockSocialService();
      mockAuthService = MockAuthService();
    });

    testWidgets('Follow button triggers follow action and shows success', (
      WidgetTester tester,
    ) async {
      const targetPubkey = 'target_user_pubkey_123';

      // Setup mocks
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockSocialService.isFollowing(targetPubkey)).thenReturn(false);
      when(mockSocialService.followUser(targetPubkey)).thenAnswer((_) async {});

      // Build a simple test widget that uses FollowActionsHelper
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            socialServiceProvider.overrideWithValue(mockSocialService),
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  final socialService = ref.read(socialServiceProvider);
                  final isFollowing = socialService.isFollowing(targetPubkey);

                  return Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        await FollowActionsHelper.toggleFollow(
                          ref: ref,
                          context: context,
                          pubkey: targetPubkey,
                          isCurrentlyFollowing: isFollowing,
                          contextName: 'Test',
                        );
                      },
                      child: Text(isFollowing ? 'Following' : 'Follow'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Verify initial state shows "Follow"
      expect(find.text('Follow'), findsOneWidget);
      expect(find.text('Following'), findsNothing);

      // Tap the follow button
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Verify followUser was called
      verify(mockSocialService.followUser(targetPubkey)).called(1);

      // Verify success message appears
      await tester.pumpAndSettle();
      expect(find.text('Successfully followed user'), findsOneWidget);
    });

    testWidgets('Unfollow button triggers unfollow action and shows success', (
      WidgetTester tester,
    ) async {
      const targetPubkey = 'target_user_pubkey_456';

      // Setup mocks
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockSocialService.isFollowing(targetPubkey)).thenReturn(true);
      when(
        mockSocialService.unfollowUser(targetPubkey),
      ).thenAnswer((_) async {});

      // Build a simple test widget
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            socialServiceProvider.overrideWithValue(mockSocialService),
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  final socialService = ref.read(socialServiceProvider);
                  final isFollowing = socialService.isFollowing(targetPubkey);

                  return Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        await FollowActionsHelper.toggleFollow(
                          ref: ref,
                          context: context,
                          pubkey: targetPubkey,
                          isCurrentlyFollowing: isFollowing,
                          contextName: 'Test',
                        );
                      },
                      child: Text(isFollowing ? 'Following' : 'Follow'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Verify initial state shows "Following"
      expect(find.text('Following'), findsOneWidget);
      expect(find.text('Follow'), findsNothing);

      // Tap the unfollow button
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Verify unfollowUser was called
      verify(mockSocialService.unfollowUser(targetPubkey)).called(1);

      // Verify success message appears
      await tester.pumpAndSettle();
      expect(find.text('Successfully unfollowed user'), findsOneWidget);
    });

    testWidgets('Shows error when not authenticated', (
      WidgetTester tester,
    ) async {
      const targetPubkey = 'target_user_pubkey_789';

      // Setup mocks - user not authenticated
      when(mockAuthService.isAuthenticated).thenReturn(false);
      when(mockSocialService.isFollowing(targetPubkey)).thenReturn(false);

      // Build a simple test widget
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            socialServiceProvider.overrideWithValue(mockSocialService),
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  return Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        await FollowActionsHelper.toggleFollow(
                          ref: ref,
                          context: context,
                          pubkey: targetPubkey,
                          isCurrentlyFollowing: false,
                          contextName: 'Test',
                        );
                      },
                      child: const Text('Follow'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Tap the follow button
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Verify error message appears
      expect(find.text('Please login to follow users'), findsOneWidget);

      // Verify no follow action was attempted
      verifyNever(mockSocialService.followUser(any));
    });

    testWidgets('Shows error when follow action fails', (
      WidgetTester tester,
    ) async {
      const targetPubkey = 'target_user_pubkey_error';

      // Setup mocks
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockSocialService.isFollowing(targetPubkey)).thenReturn(false);
      when(
        mockSocialService.followUser(targetPubkey),
      ).thenThrow(Exception('Network error'));

      // Build a simple test widget
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            socialServiceProvider.overrideWithValue(mockSocialService),
            authServiceProvider.overrideWithValue(mockAuthService),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  return Center(
                    child: ElevatedButton(
                      onPressed: () async {
                        await FollowActionsHelper.toggleFollow(
                          ref: ref,
                          context: context,
                          pubkey: targetPubkey,
                          isCurrentlyFollowing: false,
                          contextName: 'Test',
                        );
                      },
                      child: const Text('Follow'),
                    ),
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Tap the follow button
      await tester.tap(find.byType(ElevatedButton));
      await tester.pumpAndSettle();

      // Verify error message appears
      expect(find.textContaining('Failed to follow user'), findsOneWidget);

      // Verify follow was attempted
      verify(mockSocialService.followUser(targetPubkey)).called(1);
    });
  });
}
