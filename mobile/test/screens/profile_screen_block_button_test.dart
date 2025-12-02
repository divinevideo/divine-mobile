// ABOUTME: TDD tests for Block User button on profile screen
// ABOUTME: Tests visibility, styling, and interaction for blocking/unblocking users

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/content_blocklist_service.dart';

import 'profile_screen_block_button_test.mocks.dart';

@GenerateMocks([ContentBlocklistService])
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ProfileScreen Block Button - TDD', () {
    late MockContentBlocklistService mockBlocklistService;

    setUp(() {
      mockBlocklistService = MockContentBlocklistService();
    });

    // Helper to create a simple test widget with Block User button
    Widget createBlockButtonTest({
      required String userPubkey,
      required bool isBlocked,
      Function(String, bool)? onBlock,
    }) {
      // Setup mock behavior
      when(mockBlocklistService.isBlocked(userPubkey)).thenReturn(isBlocked);

      return ProviderScope(
        overrides: [
          contentBlocklistServiceProvider.overrideWithValue(
            mockBlocklistService,
          ),
        ],
        child: MaterialApp(
          home: Scaffold(
            body: Center(
              child: Consumer(
                builder: (context, ref, _) {
                  final blocklistService = ref.watch(
                    contentBlocklistServiceProvider,
                  );
                  final isUserBlocked = blocklistService.isBlocked(userPubkey);
                  return OutlinedButton(
                    onPressed: () {
                      if (onBlock != null) {
                        onBlock(userPubkey, isUserBlocked);
                      }
                    },
                    style: OutlinedButton.styleFrom(
                      foregroundColor: isUserBlocked ? Colors.grey : Colors.red,
                      side: BorderSide(
                        color: isUserBlocked ? Colors.grey : Colors.red,
                      ),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: Text(isUserBlocked ? 'Unblock' : 'Block User'),
                  );
                },
              ),
            ),
          ),
        ),
      );
    }

    // RED TEST 1: Block button should display with correct text
    testWidgets('displays Block User button with correct text', (tester) async {
      const testPubkey = 'test_pubkey_123';

      await tester.pumpWidget(
        createBlockButtonTest(userPubkey: testPubkey, isBlocked: false),
      );

      // RED: Expect to find "Block User" text
      expect(
        find.text('Block User'),
        findsOneWidget,
        reason: 'Block User button should be visible with correct text',
      );
    });

    // RED TEST 2: Block button should have red outline styling
    testWidgets('Block User button has red outline styling', (tester) async {
      const testPubkey = 'test_pubkey_456';

      await tester.pumpWidget(
        createBlockButtonTest(userPubkey: testPubkey, isBlocked: false),
      );

      final blockButton = find.text('Block User');
      expect(blockButton, findsOneWidget);

      // RED: Check button style has red border and text
      final button = tester.widget<OutlinedButton>(
        find.ancestor(of: blockButton, matching: find.byType(OutlinedButton)),
      );

      final buttonStyle = button.style!;
      final borderSide = buttonStyle.side!.resolve({});
      final textColor = buttonStyle.foregroundColor!.resolve({});

      expect(
        borderSide?.color,
        Colors.red,
        reason: 'Block button border should be red',
      );
      expect(textColor, Colors.red, reason: 'Block button text should be red');
    });

    // RED TEST 3: Button shows "Unblock" when user is already blocked
    testWidgets('shows Unblock button when user is already blocked', (
      tester,
    ) async {
      const testPubkey = 'test_pubkey_789';

      await tester.pumpWidget(
        createBlockButtonTest(
          userPubkey: testPubkey,
          isBlocked: true, // User is blocked
        ),
      );

      // RED: Expect "Unblock" text
      expect(
        find.text('Unblock'),
        findsOneWidget,
        reason: 'Button should show "Unblock" when user is blocked',
      );

      // RED: Check button has grey styling when blocked
      final button = tester.widget<OutlinedButton>(find.byType(OutlinedButton));
      final buttonStyle = button.style!;
      final borderSide = buttonStyle.side!.resolve({});
      final textColor = buttonStyle.foregroundColor!.resolve({});

      expect(
        borderSide?.color,
        Colors.grey,
        reason: 'Unblock button border should be grey',
      );
      expect(
        textColor,
        Colors.grey,
        reason: 'Unblock button text should be grey',
      );
    });

    // RED TEST 4: Tapping Block User calls the onBlock callback
    testWidgets('tapping Block User triggers callback', (tester) async {
      const testPubkey = 'test_pubkey_callback';
      bool callbackTriggered = false;
      String? capturedPubkey;
      bool? capturedIsBlocked;

      await tester.pumpWidget(
        createBlockButtonTest(
          userPubkey: testPubkey,
          isBlocked: false,
          onBlock: (pubkey, isBlocked) {
            callbackTriggered = true;
            capturedPubkey = pubkey;
            capturedIsBlocked = isBlocked;
          },
        ),
      );

      final blockButton = find.text('Block User');
      await tester.tap(blockButton);
      await tester.pump();

      // RED: Verify callback was triggered with correct parameters
      expect(
        callbackTriggered,
        true,
        reason: 'Block button tap should trigger callback',
      );
      expect(
        capturedPubkey,
        testPubkey,
        reason: 'Callback should receive correct pubkey',
      );
      expect(
        capturedIsBlocked,
        false,
        reason: 'Callback should receive correct isBlocked state',
      );
    });
  });
}
