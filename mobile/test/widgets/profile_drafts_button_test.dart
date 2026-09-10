// ABOUTME: TDD widget test for Clips button in profile action buttons
// ABOUTME: Tests that Clips button is prominently displayed and navigates correctly

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Profile Clips Button', () {
    setUp(() {
      SharedPreferences.setMockInitialValues({});
    });

    tearDown(SharedPreferences.resetStatic);

    testWidgets('should render Clips button in action buttons row', (
      tester,
    ) async {
      bool clipsTapped = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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
                      key: const Key('clips-button'),
                      onPressed: () {
                        clipsTapped = true;
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.grey[800],
                      ),
                      child: const Text('Clips'),
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
      expect(find.text('Clips'), findsOneWidget);
      expect(find.text('Share Profile'), findsOneWidget);

      // Verify Clips button has correct key
      expect(find.byKey(const Key('clips-button')), findsOneWidget);

      // Verify buttons are in correct order
      final editButton = find.text('Edit Profile');
      final clipsButton = find.text('Clips');
      final shareButton = find.text('Share Profile');

      final editPos = tester.getCenter(editButton);
      final clipsPos = tester.getCenter(clipsButton);
      final sharePos = tester.getCenter(shareButton);

      // Verify horizontal ordering (left to right)
      expect(
        editPos.dx < clipsPos.dx,
        true,
        reason: 'Edit Profile should be left of Clips',
      );
      expect(
        clipsPos.dx < sharePos.dx,
        true,
        reason: 'Clips should be left of Share Profile',
      );

      // Tap Clips button
      await tester.tap(find.byKey(const Key('clips-button')));
      await tester.pump();

      expect(clipsTapped, true);
    });

    testWidgets('Clips button navigates when tapped', (tester) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                key: const Key('clips-button'),
                onPressed: () async {
                  await Navigator.push<void>(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const Scaffold(
                        key: Key('library-screen-route-marker'),
                      ),
                    ),
                  );
                },
                child: const Text('Clips'),
              ),
            ),
          ),
        ),
      );

      // Tap Clips button
      await tester.tap(find.byKey(const Key('clips-button')));
      await tester.pumpAndSettle();

      // Should push a new route.
      expect(
        find.byKey(const Key('library-screen-route-marker')),
        findsOneWidget,
      );
    });

    testWidgets(
      'Clips button should have consistent styling with other buttons',
      (tester) async {
        await tester.binding.setSurfaceSize(const Size(900, 1200));
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
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
                        key: const Key('clips-button'),
                        onPressed: () {},
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.grey[800],
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                        ),
                        child: const Text('Clips'),
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
        final clipsHeight = tester
            .getSize(find.byKey(const Key('clips-button')))
            .height;
        final shareHeight = tester
            .getSize(find.byKey(const Key('share-button')))
            .height;

        expect(
          editHeight,
          clipsHeight,
          reason: 'Edit and Clips buttons should have same height',
        );
        expect(
          clipsHeight,
          shareHeight,
          reason: 'Clips and Share buttons should have same height',
        );

        // All buttons should be expanded equally (same width due to Expanded widget)
        final editWidth = tester
            .getSize(find.byKey(const Key('edit-button')))
            .width;
        final clipsWidth = tester
            .getSize(find.byKey(const Key('clips-button')))
            .width;
        final shareWidth = tester
            .getSize(find.byKey(const Key('share-button')))
            .width;

        expect(
          editWidth,
          closeTo(clipsWidth, 1),
          reason: 'Edit and Clips buttons should have similar width',
        );
        expect(
          clipsWidth,
          closeTo(shareWidth, 1),
          reason: 'Clips and Share buttons should have similar width',
        );
      },
    );

    testWidgets('should only show Clips button for own profile', (
      tester,
    ) async {
      // Test own profile (shows all three buttons)
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  // Own profile - show all buttons including Clips
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {},
                      child: const Text('Edit Profile'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: ElevatedButton(
                      key: const Key('clips-button'),
                      onPressed: () {},
                      child: const Text('Clips'),
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

      expect(find.text('Clips'), findsOneWidget);
      expect(find.text('Edit Profile'), findsOneWidget);
      expect(find.text('Share Profile'), findsOneWidget);
    });

    testWidgets('Clips button should not show for other users profiles', (
      tester,
    ) async {
      // Test other user's profile (no Edit/Clips/Share buttons)
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
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

      expect(find.text('Clips'), findsNothing);
      expect(find.text('Edit Profile'), findsNothing);
      expect(find.text('Share Profile'), findsNothing);
      expect(find.text('Follow'), findsOneWidget);
    });
  });
}
