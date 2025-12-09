// ABOUTME: Integration test for complete block/unblock user workflow
// ABOUTME: Tests end-to-end journey from profile screen to blocklist updates

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/content_blocklist_service.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Block User Flow Integration Tests', () {
    late ProviderContainer container;
    late GoRouter router;
    late ContentBlocklistService blocklistService;

    setUp(() {
      // Create provider container for test
      container = ProviderContainer();
      addTearDown(container.dispose);

      // Get router from provider
      router = container.read(goRouterProvider);

      // Get blocklist service
      blocklistService = container.read(contentBlocklistServiceProvider);
    });

    testWidgets('Block and unblock user from profile screen', (tester) async {
      // Setup: Create test app with router
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      // Wait for initial route
      await tester.pumpAndSettle();

      // Define test user pubkeys (distinct from current user)
      // Using real hex pubkeys that will work with Nostr encoding
      const testUserHex =
          '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
      final testUserNpub = NostrKeyUtils.encodePubKey(testUserHex);

      // Verify user is NOT blocked initially
      expect(
        blocklistService.isBlocked(testUserHex),
        isFalse,
        reason: 'User should not be blocked initially',
      );

      // Navigate to test user's profile
      router.go('/profile/$testUserNpub/0');
      await tester.pumpAndSettle();

      // STEP 1: Verify "Block User" button is visible
      final blockButtonFinder = find.widgetWithText(
        OutlinedButton,
        'Block User',
      );
      expect(
        blockButtonFinder,
        findsOneWidget,
        reason: 'Block User button should be visible on profile',
      );

      // STEP 2: Tap "Block User" button
      await tester.tap(blockButtonFinder);
      await tester.pumpAndSettle();

      // STEP 3: Verify confirmation dialog appears
      expect(
        find.text('Block @'),
        findsOneWidget,
        reason: 'Block confirmation dialog should appear',
      );
      expect(
        find.text(
          'You won\'t see their content in feeds. They won\'t be notified. You can still visit their profile.',
        ),
        findsOneWidget,
        reason: 'Dialog explanation should be present',
      );

      // STEP 4: Confirm block action
      final confirmButtonFinder = find.widgetWithText(TextButton, 'Block');
      expect(
        confirmButtonFinder,
        findsOneWidget,
        reason: 'Block confirmation button should exist',
      );

      await tester.tap(confirmButtonFinder);
      await tester.pumpAndSettle();

      // STEP 5: Verify user is added to blocklist
      expect(
        blocklistService.isBlocked(testUserHex),
        isTrue,
        reason: 'User should be blocked after confirmation',
      );

      // STEP 6: Verify button changes to "Unblock"
      final unblockButtonFinder = find.widgetWithText(
        OutlinedButton,
        'Unblock',
      );
      expect(
        unblockButtonFinder,
        findsOneWidget,
        reason: 'Button should change to "Unblock" after blocking',
      );

      // Verify "Block User" button is gone
      expect(
        find.widgetWithText(OutlinedButton, 'Block User'),
        findsNothing,
        reason: 'Block User button should not be visible when user is blocked',
      );

      // Verify snackbar confirmation
      expect(
        find.text('User blocked'),
        findsOneWidget,
        reason: 'Success snackbar should appear',
      );

      // Wait for snackbar to dismiss
      await tester.pump(const Duration(seconds: 3));
      await tester.pumpAndSettle();

      // STEP 7: Tap "Unblock" button
      await tester.tap(unblockButtonFinder);
      await tester.pumpAndSettle();

      // STEP 8: Verify user is removed from blocklist (no confirmation needed for unblock)
      expect(
        blocklistService.isBlocked(testUserHex),
        isFalse,
        reason: 'User should be unblocked after tapping Unblock',
      );

      // STEP 9: Verify button changes back to "Block User"
      expect(
        find.widgetWithText(OutlinedButton, 'Block User'),
        findsOneWidget,
        reason: 'Button should change back to "Block User" after unblocking',
      );

      // Verify "Unblock" button is gone
      expect(
        find.widgetWithText(OutlinedButton, 'Unblock'),
        findsNothing,
        reason: 'Unblock button should not be visible when user is not blocked',
      );

      // Verify snackbar confirmation
      expect(
        find.text('User unblocked'),
        findsOneWidget,
        reason: 'Success snackbar should appear',
      );
    });

    testWidgets('Cancel block action keeps user unblocked', (tester) async {
      // Setup: Create test app with router
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();

      // Define test user
      const testUserHex =
          '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';
      final testUserNpub = NostrKeyUtils.encodePubKey(testUserHex);

      // Ensure user is not blocked
      expect(blocklistService.isBlocked(testUserHex), isFalse);

      // Navigate to test user's profile
      router.go('/profile/$testUserNpub/0');
      await tester.pumpAndSettle();

      // Tap "Block User" button
      await tester.tap(find.widgetWithText(OutlinedButton, 'Block User'));
      await tester.pumpAndSettle();

      // Verify dialog appears
      expect(find.text('Block @'), findsOneWidget);

      // Tap "Cancel" button
      final cancelButtonFinder = find.widgetWithText(TextButton, 'Cancel');
      expect(cancelButtonFinder, findsOneWidget);

      await tester.tap(cancelButtonFinder);
      await tester.pumpAndSettle();

      // Verify user is still NOT blocked
      expect(
        blocklistService.isBlocked(testUserHex),
        isFalse,
        reason: 'User should not be blocked after canceling',
      );

      // Verify button is still "Block User"
      expect(
        find.widgetWithText(OutlinedButton, 'Block User'),
        findsOneWidget,
        reason: 'Block User button should still be visible after canceling',
      );

      // Verify no snackbar
      expect(
        find.text('User blocked'),
        findsNothing,
        reason: 'No success snackbar should appear when canceled',
      );
    });
  });
}
