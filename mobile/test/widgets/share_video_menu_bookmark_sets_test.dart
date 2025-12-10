// ABOUTME: TDD tests for bookmark sets dialog functionality in ShareVideoMenu
// ABOUTME: Tests creating, selecting, and managing bookmark sets with real BookmarkService

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/widgets/share_video_menu.dart';
import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/bookmark_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_service.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('ShareVideoMenu - Bookmark Sets Dialog (TDD)', () {
    late NostrService nostrService;
    late NostrKeyManager keyManager;
    late AuthService authService;
    late BookmarkService bookmarkService;
    late SharedPreferences prefs;
    late VideoEvent testVideo;

    setUpAll(() async {
      // Initialize services
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      keyManager = NostrKeyManager();
      await keyManager.initialize();

      nostrService = NostrService(keyManager);
      await nostrService.initialize();

      authService = AuthService(keyStorage: null);
      bookmarkService = BookmarkService(
        nostrService: nostrService,
        authService: authService,
        prefs: prefs,
      );

      // Create test video
      testVideo = VideoEvent(
        id: 'test_video_123',
        title: 'Test Video for Bookmarks',
        videoUrl: 'https://example.com/video.mp4',
        pubkey: 'test_pubkey',
        content: 'Test content',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        timestamp: DateTime.now(),
      );
    });

    tearDownAll(() async {
      await nostrService.closeAllSubscriptions();
      nostrService.dispose();
    });

    group('Dialog Rendering', () {
      testWidgets(
        'FAIL: should show bookmark sets dialog when "Add to Bookmark Set" is tapped',
        (tester) async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                bookmarkServiceProvider.overrideWithValue(
                  AsyncValue.data(bookmarkService),
                ),
              ],
              child: MaterialApp(
                home: Scaffold(body: ShareVideoMenu(video: testVideo)),
              ),
            ),
          );

          await tester.pumpAndSettle();

          // Find and tap "Add to Bookmark Set" button
          final bookmarkSetButton = find.text('Add to Bookmark Set');
          expect(
            bookmarkSetButton,
            findsOneWidget,
            reason: 'Should have "Add to Bookmark Set" option',
          );

          await tester.tap(bookmarkSetButton);
          await tester.pumpAndSettle();

          // Should show dialog, NOT snackbar with "coming soon"
          expect(
            find.byType(AlertDialog),
            findsOneWidget,
            reason:
                'Should show bookmark sets dialog instead of "coming soon" snackbar',
          );
          expect(
            find.text('Bookmark sets feature coming soon!'),
            findsNothing,
            reason: 'Should NOT show coming soon message',
          );
        },
      );

      testWidgets('FAIL: bookmark sets dialog should show existing sets', (
        tester,
      ) async {
        // Pre-create bookmark sets
        await bookmarkService.createBookmarkSet(
          name: 'My Favorites',
          description: 'Videos I love',
        );
        await bookmarkService.createBookmarkSet(name: 'Watch Later');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              bookmarkServiceProvider.overrideWithValue(
                AsyncValue.data(bookmarkService),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(body: ShareVideoMenu(video: testVideo)),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Tap "Add to Bookmark Set"
        await tester.tap(find.text('Add to Bookmark Set'));
        await tester.pumpAndSettle();

        // Should show existing bookmark sets
        expect(find.text('My Favorites'), findsOneWidget);
        expect(find.text('Watch Later'), findsOneWidget);
      });

      testWidgets(
        'FAIL: bookmark sets dialog should show "Create New Set" option',
        (tester) async {
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                bookmarkServiceProvider.overrideWithValue(
                  AsyncValue.data(bookmarkService),
                ),
              ],
              child: MaterialApp(
                home: Scaffold(body: ShareVideoMenu(video: testVideo)),
              ),
            ),
          );

          await tester.pumpAndSettle();

          await tester.tap(find.text('Add to Bookmark Set'));
          await tester.pumpAndSettle();

          // Should have option to create new set
          expect(find.text('Create New Set'), findsOneWidget);
          expect(find.byIcon(Icons.add), findsOneWidget);
        },
      );
    });

    group('Creating New Bookmark Set', () {
      testWidgets('FAIL: should allow creating new bookmark set from dialog', (
        tester,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              bookmarkServiceProvider.overrideWithValue(
                AsyncValue.data(bookmarkService),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(body: ShareVideoMenu(video: testVideo)),
            ),
          ),
        );

        await tester.pumpAndSettle();

        // Open bookmark sets dialog
        await tester.tap(find.text('Add to Bookmark Set'));
        await tester.pumpAndSettle();

        // Tap "Create New Set"
        await tester.tap(find.text('Create New Set'));
        await tester.pumpAndSettle();

        // Should show create dialog
        expect(find.text('Create Bookmark Set'), findsOneWidget);

        // Enter set name
        await tester.enterText(find.byType(TextField).first, 'My New Set');
        await tester.pumpAndSettle();

        // Tap Create button
        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();

        // Video should be added to new set
        final sets = bookmarkService.getBookmarkSetsContainingVideo(
          testVideo.id,
        );
        expect(sets.length, 1);
        expect(sets.first.name, 'My New Set');
      });

      testWidgets('FAIL: should validate bookmark set name is not empty', (
        tester,
      ) async {
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              bookmarkServiceProvider.overrideWithValue(
                AsyncValue.data(bookmarkService),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(body: ShareVideoMenu(video: testVideo)),
            ),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.text('Add to Bookmark Set'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Create New Set'));
        await tester.pumpAndSettle();

        // Try to create with empty name
        await tester.tap(find.text('Create'));
        await tester.pumpAndSettle();

        // Should still be in create dialog (not created)
        expect(find.text('Create Bookmark Set'), findsOneWidget);
        expect(bookmarkService.bookmarkSets.length, 0);
      });
    });

    group('Adding to Existing Set', () {
      testWidgets(
        'FAIL: should add video to existing bookmark set when selected',
        (tester) async {
          // Pre-create a set
          final existingSet = await bookmarkService.createBookmarkSet(
            name: 'Existing Set',
          );
          expect(existingSet, isNotNull);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                bookmarkServiceProvider.overrideWithValue(
                  AsyncValue.data(bookmarkService),
                ),
              ],
              child: MaterialApp(
                home: Scaffold(body: ShareVideoMenu(video: testVideo)),
              ),
            ),
          );

          await tester.pumpAndSettle();

          // Open bookmark sets dialog
          await tester.tap(find.text('Add to Bookmark Set'));
          await tester.pumpAndSettle();

          // Tap existing set
          await tester.tap(find.text('Existing Set'));
          await tester.pumpAndSettle();

          // Video should be in the set
          final sets = bookmarkService.getBookmarkSetsContainingVideo(
            testVideo.id,
          );
          expect(sets.length, 1);
          expect(sets.first.name, 'Existing Set');
        },
      );

      testWidgets(
        'FAIL: should show checkmark for sets already containing video',
        (tester) async {
          // Create set and add video
          final set = await bookmarkService.createBookmarkSet(
            name: 'Already Added',
          );
          await bookmarkService.addToBookmarkSet(
            set!.id,
            BookmarkItem(type: 'e', id: testVideo.id),
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                bookmarkServiceProvider.overrideWithValue(
                  AsyncValue.data(bookmarkService),
                ),
              ],
              child: MaterialApp(
                home: Scaffold(body: ShareVideoMenu(video: testVideo)),
              ),
            ),
          );

          await tester.pumpAndSettle();

          await tester.tap(find.text('Add to Bookmark Set'));
          await tester.pumpAndSettle();

          // Should show checkmark icon for set already containing video
          expect(find.byIcon(Icons.check_circle), findsOneWidget);
        },
      );

      testWidgets(
        'FAIL: should toggle video in/out of set when tapped multiple times',
        (tester) async {
          final set = await bookmarkService.createBookmarkSet(
            name: 'Toggle Set',
          );

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                bookmarkServiceProvider.overrideWithValue(
                  AsyncValue.data(bookmarkService),
                ),
              ],
              child: MaterialApp(
                home: Scaffold(body: ShareVideoMenu(video: testVideo)),
              ),
            ),
          );

          await tester.pumpAndSettle();

          // First tap - add to set
          await tester.tap(find.text('Add to Bookmark Set'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Toggle Set'));
          await tester.pumpAndSettle();

          expect(
            bookmarkService.isInBookmarkSet(set!.id, testVideo.id, 'e'),
            true,
          );

          // Second tap - remove from set
          await tester.tap(find.text('Add to Bookmark Set'));
          await tester.pumpAndSettle();
          await tester.tap(find.text('Toggle Set'));
          await tester.pumpAndSettle();

          expect(
            bookmarkService.isInBookmarkSet(set.id, testVideo.id, 'e'),
            false,
          );
        },
      );
    });

    group('Empty State', () {
      testWidgets(
        'FAIL: should show helpful message when no bookmark sets exist',
        (tester) async {
          // Ensure no sets exist
          for (final set in bookmarkService.bookmarkSets) {
            await bookmarkService.deleteBookmarkSet(set.id);
          }

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                bookmarkServiceProvider.overrideWithValue(
                  AsyncValue.data(bookmarkService),
                ),
              ],
              child: MaterialApp(
                home: Scaffold(body: ShareVideoMenu(video: testVideo)),
              ),
            ),
          );

          await tester.pumpAndSettle();

          await tester.tap(find.text('Add to Bookmark Set'));
          await tester.pumpAndSettle();

          // Should show helpful empty state
          expect(find.textContaining('No bookmark sets yet'), findsOneWidget);
          expect(find.text('Create New Set'), findsOneWidget);
        },
      );
    });

    group('UI Feedback', () {
      testWidgets('FAIL: should show success snackbar after adding to set', (
        tester,
      ) async {
        await bookmarkService.createBookmarkSet(name: 'Success Set');

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              bookmarkServiceProvider.overrideWithValue(
                AsyncValue.data(bookmarkService),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(body: ShareVideoMenu(video: testVideo)),
            ),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.text('Add to Bookmark Set'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Success Set'));
        await tester.pumpAndSettle();

        // Should show success message
        expect(find.text('Added to "Success Set"'), findsOneWidget);
      });

      testWidgets('FAIL: should close share menu after successful add', (
        tester,
      ) async {
        await bookmarkService.createBookmarkSet(name: 'Close Test Set');
        bool dismissed = false;

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              bookmarkServiceProvider.overrideWithValue(
                AsyncValue.data(bookmarkService),
              ),
            ],
            child: MaterialApp(
              home: Scaffold(
                body: ShareVideoMenu(
                  video: testVideo,
                  onDismiss: () => dismissed = true,
                ),
              ),
            ),
          ),
        );

        await tester.pumpAndSettle();

        await tester.tap(find.text('Add to Bookmark Set'));
        await tester.pumpAndSettle();
        await tester.tap(find.text('Close Test Set'));
        await tester.pumpAndSettle();

        // Share menu should be dismissed
        expect(dismissed, true);
      });
    });
  });
}
