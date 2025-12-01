// ABOUTME: Unit tests for FollowActionsHelper shared functionality
// ABOUTME: Tests follow/unfollow actions with mocked services

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:openvine/helpers/follow_actions_helper.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/optimistic_follow_provider.dart';

import 'follow_actions_helper_test.mocks.dart';

@GenerateMocks([AuthService, OptimisticFollowMethods])
void main() {
  group('FollowActionsHelper Tests', () {
    late MockAuthService mockAuthService;
    late MockOptimisticFollowMethods mockOptimisticMethods;

    setUp(() {
      mockAuthService = MockAuthService();
      mockOptimisticMethods = MockOptimisticFollowMethods();

      // Setup default mock behaviors
      when(mockAuthService.isAuthenticated).thenReturn(true);
    });

    testWidgets('toggleFollow should call followUser when not following', (
      WidgetTester tester,
    ) async {
      const testPubkey = 'test_pubkey_123';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(mockAuthService),
            optimisticFollowMethodsProvider.overrideWithValue(
              mockOptimisticMethods,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) => ElevatedButton(
                  onPressed: () async {
                    await FollowActionsHelper.toggleFollow(
                      ref: ref,
                      context: context,
                      pubkey: testPubkey,
                      isCurrentlyFollowing: false,
                      contextName: 'Test',
                    );
                  },
                  child: const Text('Toggle'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap the button
      await tester.tap(find.text('Toggle'));
      await tester.pumpAndSettle();

      // Verify followUser was called
      verify(mockOptimisticMethods.followUser(testPubkey)).called(1);
      verifyNever(mockOptimisticMethods.unfollowUser(any));
    });

    testWidgets(
      'toggleFollow should call unfollowUser when already following',
      (WidgetTester tester) async {
        const testPubkey = 'test_pubkey_456';

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              authServiceProvider.overrideWithValue(mockAuthService),
              optimisticFollowMethodsProvider.overrideWithValue(
                mockOptimisticMethods,
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, child) => ElevatedButton(
                    onPressed: () async {
                      await FollowActionsHelper.toggleFollow(
                        ref: ref,
                        context: context,
                        pubkey: testPubkey,
                        isCurrentlyFollowing: true,
                        contextName: 'Test',
                      );
                    },
                    child: const Text('Toggle'),
                  ),
                ),
              ),
            ),
          ),
        );

        // Tap the button
        await tester.tap(find.text('Toggle'));
        await tester.pumpAndSettle();

        // Verify unfollowUser was called
        verify(mockOptimisticMethods.unfollowUser(testPubkey)).called(1);
        verifyNever(mockOptimisticMethods.followUser(any));
      },
    );

    testWidgets('Should show error when not authenticated', (
      WidgetTester tester,
    ) async {
      const testPubkey = 'test_pubkey_789';

      // Setup: User is not authenticated
      when(mockAuthService.isAuthenticated).thenReturn(false);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(mockAuthService),
            optimisticFollowMethodsProvider.overrideWithValue(
              mockOptimisticMethods,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) => ElevatedButton(
                  onPressed: () async {
                    await FollowActionsHelper.followUser(
                      ref: ref,
                      context: context,
                      pubkey: testPubkey,
                      contextName: 'Test',
                    );
                  },
                  child: const Text('Follow'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap the button
      await tester.tap(find.text('Follow'));
      await tester.pumpAndSettle();

      // Verify no follow action was performed
      verifyNever(mockOptimisticMethods.followUser(any));
      verifyNever(mockOptimisticMethods.unfollowUser(any));

      // Check for error message
      expect(find.text('Please login to follow users'), findsOneWidget);
    });

    testWidgets('Should show success message on successful follow', (
      WidgetTester tester,
    ) async {
      const testPubkey = 'test_pubkey_abc';

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(mockAuthService),
            optimisticFollowMethodsProvider.overrideWithValue(
              mockOptimisticMethods,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) => ElevatedButton(
                  onPressed: () async {
                    await FollowActionsHelper.followUser(
                      ref: ref,
                      context: context,
                      pubkey: testPubkey,
                      contextName: 'Test',
                    );
                  },
                  child: const Text('Follow'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap the button
      await tester.tap(find.text('Follow'));
      await tester.pumpAndSettle();

      // Verify followUser was called
      verify(mockOptimisticMethods.followUser(testPubkey)).called(1);

      // Check for success message
      expect(find.text('Successfully followed user'), findsOneWidget);
    });

    testWidgets('Should show error message on follow failure', (
      WidgetTester tester,
    ) async {
      const testPubkey = 'test_pubkey_def';

      // Setup: followUser throws exception
      when(
        mockOptimisticMethods.followUser(testPubkey),
      ).thenThrow(Exception('Network error'));

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(mockAuthService),
            optimisticFollowMethodsProvider.overrideWithValue(
              mockOptimisticMethods,
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) => ElevatedButton(
                  onPressed: () async {
                    await FollowActionsHelper.followUser(
                      ref: ref,
                      context: context,
                      pubkey: testPubkey,
                      contextName: 'Test',
                    );
                  },
                  child: const Text('Follow'),
                ),
              ),
            ),
          ),
        ),
      );

      // Tap the button
      await tester.tap(find.text('Follow'));
      await tester.pumpAndSettle();

      // Check for error message
      expect(find.textContaining('Failed to follow user'), findsOneWidget);
    });
  });
}
