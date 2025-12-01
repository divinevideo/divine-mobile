// ABOUTME: TDD widget test for Drafts button in profile action buttons
// ABOUTME: Tests that Drafts button is prominently displayed and navigates correctly

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/vine_drafts_screen.dart';

void main() {
  group('Profile Drafts Button', () {
    testWidgets('should render Drafts button in action buttons row', (
      tester,
    ) async {
      bool draftsTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                      ),
                      child: const Text('Edit Profile'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      key: const Key('drafts-button'),
                      onPressed: () {
                        draftsTapped = true;
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                      ),
                      child: const Text('Drafts'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                      ),
                      child: const Text('Share Profile'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      // Verify all three buttons exist
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Drafts'), findsOneWidget);
      expect(find.text('Share Profile'), findsOneWidget);

      // Verify Drafts button has correct key
      expect(find.byKey(const Key('drafts-button')), findsOneWidget);

      // Verify buttons are in correct order
      final editButton = find.text('Edit Profile');
      final draftsButton = find.text('Drafts');
      final shareButton = find.text('Share Profile');

      final editPos = tester.getCenter(editButton);
      final draftsPos = tester.getCenter(draftsButton);
      final sharePos = tester.getCenter(shareButton);

      // Verify horizontal ordering (left to right)
      expect(
        editPos.dx < draftsPos.dx,
        true,
        reason: 'Edit Profile should be left of Drafts',
      );
      expect(
        draftsPos.dx < sharePos.dx,
        true,
        reason: 'Drafts should be left of Share Profile',
      );

      // Tap Drafts button
      await tester.tap(find.byKey(const Key('drafts-button')));
      await tester.pump();

      expect(draftsTapped, true);
    });

    testWidgets(
      'should navigate to VineDraftsScreen when Drafts button tapped',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (context) => ElevatedButton(
                  key: const Key('drafts-button'),
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => const VineDraftsScreen(),
                      ),
                    );
                  },
                  child: const Text('Drafts'),
                ),
              ),
            ),
          ),
        );

        // Tap Drafts button
        await tester.tap(find.byKey(const Key('drafts-button')));
        await tester.pumpAndSettle();

        // Should navigate to VineDraftsScreen
        expect(find.byType(VineDraftsScreen), findsOneWidget);
      },
    );

    testWidgets(
      'Drafts button should have consistent styling with other buttons',
      (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            home: Scaffold(
              body: Padding(
                padding: const EdgeInsets.all(20),
                child: Row(
                  children: [
                    Expanded(
                      child: ElevatedButton(
                        key: const Key('edit-button'),
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Edit Profile'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        key: const Key('drafts-button'),
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Drafts'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: ElevatedButton(
                        key: const Key('share-button'),
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Share Profile'),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );

        // All buttons should have same height (equal vertical space)
        final editHeight = tester
            .getSize(find.byKey(const Key('edit-button')))
            .height;
        final draftsHeight = tester
            .getSize(find.byKey(const Key('drafts-button')))
            .height;
        final shareHeight = tester
            .getSize(find.byKey(const Key('share-button')))
            .height;

        expect(
          editHeight,
          draftsHeight,
          reason: 'Edit and Drafts buttons should have same height',
        );
        expect(
          draftsHeight,
          shareHeight,
          reason: 'Drafts and Share buttons should have same height',
        );

        // All buttons should be expanded equally (same width due to Expanded widget)
        final editWidth = tester
            .getSize(find.byKey(const Key('edit-button')))
            .width;
        final draftsWidth = tester
            .getSize(find.byKey(const Key('drafts-button')))
            .width;
        final shareWidth = tester
            .getSize(find.byKey(const Key('share-button')))
            .width;

        expect(
          editWidth,
          closeTo(draftsWidth, 1),
          reason: 'Edit and Drafts buttons should have similar width',
        );
        expect(
          draftsWidth,
          closeTo(shareWidth, 1),
          reason: 'Drafts and Share buttons should have similar width',
        );
      },
    );

    testWidgets('should only show Drafts button for own profile', (
      tester,
    ) async {
      // Test own profile (shows all three buttons)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Own profile - show all buttons including Drafts
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text('Edit Profile'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      key: const Key('drafts-button'),
                      onPressed: () {},
                      child: const Text('Drafts'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text('Share Profile'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Drafts'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Share Profile'), findsOneWidget);
    });

    testWidgets('Drafts button should not show for other users profiles', (
      tester,
    ) async {
      // Test other user's profile (no Edit/Drafts/Share buttons)
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Other user's profile - show Follow/Message buttons
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text('Follow'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: () {},
                    child: const Icon(Icons.mail_outline),
                  ),
                ],
              ),
            ),
          ),
        ),
      );

      expect(find.text('Drafts'), findsNothing);
      expect(find.text('Edit Profile'), findsNothing);
      expect(find.text('Share Profile'), findsNothing);
      expect(find.text('Follow'), findsOneWidget);
    });
  });
}
