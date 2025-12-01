// ABOUTME: Simple unit test for follow/unfollow functionality without complex provider dependencies
// ABOUTME: Tests the core FollowActionsHelper logic with minimal mocking

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:openvine/services/social_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/helpers/follow_actions_helper.dart';

import 'follow_actions_helper_simple_test.mocks.dart';

@GenerateMocks([SocialService, AuthService])
void main() {
  group('FollowActionsHelper Simple Tests', () {
    late MockSocialService mockSocialService;
    late MockAuthService mockAuthService;

    setUp(() {
      mockSocialService = MockSocialService();
      mockAuthService = MockAuthService();
    });

    testWidgets('Follow action calls socialService.followUser', (
      WidgetTester tester,
    ) async {
      const targetPubkey = 'test_pubkey_123';

      // Setup mocks
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockSocialService.isFollowing(targetPubkey)).thenReturn(false);
      when(mockSocialService.followUser(targetPubkey)).thenAnswer((_) async {});

      // Build test widget
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
                  return Builder(
                    builder: (context) {
                      return ElevatedButton(
                        onPressed: () async {
                          await FollowActionsHelper.followUser(
                            ref: ref,
                            context: context,
                            pubkey: targetPubkey,
                            contextName: 'Test',
                          );
                        },
                        child: const Text('Follow'),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Tap the follow button
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Verify followUser was called
      verify(mockSocialService.followUser(targetPubkey)).called(1);
    });

    testWidgets('Unfollow action calls socialService.unfollowUser', (
      WidgetTester tester,
    ) async {
      const targetPubkey = 'test_pubkey_456';

      // Setup mocks
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockSocialService.isFollowing(targetPubkey)).thenReturn(true);
      when(
        mockSocialService.unfollowUser(targetPubkey),
      ).thenAnswer((_) async {});

      // Build test widget
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
                  return Builder(
                    builder: (context) {
                      return ElevatedButton(
                        onPressed: () async {
                          await FollowActionsHelper.unfollowUser(
                            ref: ref,
                            context: context,
                            pubkey: targetPubkey,
                            contextName: 'Test',
                          );
                        },
                        child: const Text('Unfollow'),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Tap the unfollow button
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Verify unfollowUser was called
      verify(mockSocialService.unfollowUser(targetPubkey)).called(1);
    });

    testWidgets('Toggle follow calls correct method based on state', (
      WidgetTester tester,
    ) async {
      const targetPubkey = 'test_pubkey_789';

      // Setup mocks - not following initially
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockSocialService.isFollowing(targetPubkey)).thenReturn(false);
      when(mockSocialService.followUser(targetPubkey)).thenAnswer((_) async {});

      // Build test widget
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
                  return Builder(
                    builder: (context) {
                      return ElevatedButton(
                        onPressed: () async {
                          await FollowActionsHelper.toggleFollow(
                            ref: ref,
                            context: context,
                            pubkey: targetPubkey,
                            isCurrentlyFollowing: false,
                            contextName: 'Test',
                          );
                        },
                        child: const Text('Toggle'),
                      );
                    },
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Tap to follow
      await tester.tap(find.byType(ElevatedButton));
      await tester.pump();

      // Verify followUser was called
      verify(mockSocialService.followUser(targetPubkey)).called(1);
    });
  });
}
