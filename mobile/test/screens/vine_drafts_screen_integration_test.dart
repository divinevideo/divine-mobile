// ABOUTME: Integration tests for VineDraftsScreen with DraftStorageService
// ABOUTME: Tests load, delete, and clear all operations with real storage

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/vine_drafts_screen.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('VineDraftsScreen integration', () {
    late DraftStorageService draftService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      draftService = DraftStorageService(prefs);
    });

    testWidgets('should load and display drafts from storage', (tester) async {
      // Arrange: Save drafts to storage
      final now = DateTime.now();
      final draft1 = VineDraft(
        id: 'draft_1',
        videoFile: File('/path/to/video1.mp4'),
        title: 'Test Vine 1',
        description: 'Description 1',
        hashtags: ['test'],
        frameCount: 30,
        selectedApproach: 'hybrid',
        createdAt: now,
        lastModified: now,
        publishStatus: PublishStatus.draft,
        publishError: null,
        publishAttempts: 0,
      );

      final draft2 = VineDraft(
        id: 'draft_2',
        videoFile: File('/path/to/video2.mp4'),
        title: 'Test Vine 2',
        description: 'Description 2',
        hashtags: ['test', 'vine'],
        frameCount: 45,
        selectedApproach: 'imageSequence',
        createdAt: now,
        lastModified: now,
        publishStatus: PublishStatus.draft,
        publishError: null,
        publishAttempts: 0,
      );

      await draftService.saveDraft(draft1);
      await draftService.saveDraft(draft2);

      // Act: Build the screen
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            draftStorageServiceProvider.overrideWith(
              (ref) async => draftService,
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const VineDraftsScreen(),
          ),
        ),
      );

      // Should show loading initially
      expect(find.byType(CircularProgressIndicator), findsOneWidget);

      // Wait for drafts to load
      await tester.pump();
      await tester.pump();

      // Assert: Should display both drafts
      expect(find.byType(CircularProgressIndicator), findsNothing);
      expect(find.text('Test Vine 1'), findsOneWidget);
      expect(find.text('Test Vine 2'), findsOneWidget);
      expect(find.text('30 frames • hybrid'), findsOneWidget);
      expect(find.text('45 frames • imageSequence'), findsOneWidget);
    });

    testWidgets('should show empty state when no drafts exist', (tester) async {
      // Act: Build the screen with no drafts
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            draftStorageServiceProvider.overrideWith(
              (ref) async => draftService,
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const VineDraftsScreen(),
          ),
        ),
      );

      // Wait for loading
      await tester.pump();
      await tester.pump();

      // Assert: Should show empty state
      expect(find.text('No Drafts Yet'), findsOneWidget);
      expect(
        find.text('Your saved Vine drafts will appear here'),
        findsOneWidget,
      );
      expect(find.text('Record a Vine'), findsOneWidget);
    });

    testWidgets('should delete draft when delete is confirmed', (tester) async {
      // Arrange: Save drafts
      final now = DateTime.now();
      final draft1 = VineDraft(
        id: 'draft_1',
        videoFile: File('/path/to/video1.mp4'),
        title: 'To Delete',
        description: '',
        hashtags: [],
        frameCount: 30,
        selectedApproach: 'hybrid',
        createdAt: now,
        lastModified: now,
        publishStatus: PublishStatus.draft,
        publishError: null,
        publishAttempts: 0,
      );

      final draft2 = VineDraft(
        id: 'draft_2',
        videoFile: File('/path/to/video2.mp4'),
        title: 'To Keep',
        description: '',
        hashtags: [],
        frameCount: 45,
        selectedApproach: 'imageSequence',
        createdAt: now,
        lastModified: now,
        publishStatus: PublishStatus.draft,
        publishError: null,
        publishAttempts: 0,
      );

      await draftService.saveDraft(draft1);
      await draftService.saveDraft(draft2);

      // Act: Build screen
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            draftStorageServiceProvider.overrideWith(
              (ref) async => draftService,
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const VineDraftsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      // Find and tap delete menu for first draft
      final moreButtons = find.byIcon(Icons.more_vert);
      await tester.tap(moreButtons.first);
      await tester.pumpAndSettle();

      // Tap delete option
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Confirm deletion in dialog
      final deleteButton = find.widgetWithText(TextButton, 'Delete');
      await tester.tap(deleteButton);
      await tester.pumpAndSettle();

      // Assert: First draft should be gone, second should remain
      expect(find.text('To Delete'), findsNothing);
      expect(find.text('To Keep'), findsOneWidget);

      // Verify storage was updated
      final remainingDrafts = await draftService.getAllDrafts();
      expect(remainingDrafts.length, 1);
      expect(remainingDrafts.first.title, 'To Keep');
    });

    testWidgets('should clear all drafts when clear all is confirmed', (
      tester,
    ) async {
      // Arrange: Save multiple drafts
      final now = DateTime.now();
      final draft1 = VineDraft(
        id: 'draft_1',
        videoFile: File('/path/to/video1.mp4'),
        title: 'Draft 1',
        description: '',
        hashtags: [],
        frameCount: 30,
        selectedApproach: 'hybrid',
        createdAt: now,
        lastModified: now,
        publishStatus: PublishStatus.draft,
        publishError: null,
        publishAttempts: 0,
      );

      final draft2 = VineDraft(
        id: 'draft_2',
        videoFile: File('/path/to/video2.mp4'),
        title: 'Draft 2',
        description: '',
        hashtags: [],
        frameCount: 45,
        selectedApproach: 'imageSequence',
        createdAt: now,
        lastModified: now,
        publishStatus: PublishStatus.draft,
        publishError: null,
        publishAttempts: 0,
      );

      await draftService.saveDraft(draft1);
      await draftService.saveDraft(draft2);

      // Act: Build screen
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            draftStorageServiceProvider.overrideWith(
              (ref) async => draftService,
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const VineDraftsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      // Tap app bar menu
      await tester.tap(find.byIcon(Icons.more_vert).last);
      await tester.pumpAndSettle();

      // Tap clear all
      await tester.tap(find.text('Clear All Drafts'));
      await tester.pumpAndSettle();

      // Confirm in dialog
      final clearAllButton = find.widgetWithText(TextButton, 'Clear All');
      await tester.tap(clearAllButton);
      await tester.pumpAndSettle();

      // Assert: Should show empty state
      expect(find.text('No Drafts Yet'), findsOneWidget);
      expect(find.text('Draft 1'), findsNothing);
      expect(find.text('Draft 2'), findsNothing);

      // Verify storage was cleared
      final remainingDrafts = await draftService.getAllDrafts();
      expect(remainingDrafts, isEmpty);
    });

    testWidgets('should not delete draft when cancel is tapped', (
      tester,
    ) async {
      // Arrange
      final now = DateTime.now();
      final draft = VineDraft(
        id: 'draft_1',
        videoFile: File('/path/to/video.mp4'),
        title: 'Test Draft',
        description: '',
        hashtags: [],
        frameCount: 30,
        selectedApproach: 'hybrid',
        createdAt: now,
        lastModified: now,
        publishStatus: PublishStatus.draft,
        publishError: null,
        publishAttempts: 0,
      );

      await draftService.saveDraft(draft);

      // Act: Build screen
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            draftStorageServiceProvider.overrideWith(
              (ref) async => draftService,
            ),
          ],
          child: MaterialApp(
            theme: ThemeData.dark(),
            home: const VineDraftsScreen(),
          ),
        ),
      );

      await tester.pump();
      await tester.pump();

      // Open delete menu (use first occurrence - the one in the draft card)
      final moreButtons = find.byIcon(Icons.more_vert);
      await tester.tap(moreButtons.first);
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Cancel deletion
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      // Assert: Draft should still be there
      expect(find.text('Test Draft'), findsOneWidget);

      final drafts = await draftService.getAllDrafts();
      expect(drafts.length, 1);
    });
  });
}
