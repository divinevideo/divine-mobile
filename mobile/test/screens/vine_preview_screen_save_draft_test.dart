// ABOUTME: TDD test for save draft functionality in VinePreviewScreenPure
// ABOUTME: Ensures draft save button exists and saves to storage correctly

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/pure/vine_preview_screen_pure.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('VinePreviewScreenPure save draft', () {
    late DraftStorageService draftService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      draftService = DraftStorageService(prefs);
    });

    testWidgets('should have a Save Draft button in app bar', (tester) async {
      final videoFile = File('/path/to/test/video.mp4');

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: VinePreviewScreenPure(
              videoFile: videoFile,
              frameCount: 30,
              selectedApproach: 'hybrid',
            ),
          ),
        ),
      );

      // Should have Save Draft button
      expect(find.text('Save Draft'), findsOneWidget);
    });

    testWidgets('should save draft when Save Draft button is tapped', (
      tester,
    ) async {
      final videoFile = File('/path/to/test/video.mp4');

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: VinePreviewScreenPure(
              videoFile: videoFile,
              frameCount: 30,
              selectedApproach: 'hybrid',
            ),
          ),
        ),
      );

      // Enter metadata
      await tester.enterText(
        find.byKey(const Key('title-input')),
        'Test Vine Title',
      );
      await tester.enterText(
        find.byKey(const Key('description-input')),
        'Test description',
      );
      await tester.enterText(
        find.byKey(const Key('hashtags-input')),
        'test vine',
      );

      // Tap Save Draft
      await tester.tap(find.text('Save Draft'));
      await tester.pumpAndSettle();

      // Verify draft was saved to storage
      final drafts = await draftService.getAllDrafts();
      expect(drafts.length, 1);
      expect(drafts.first.title, 'Test Vine Title');
      expect(drafts.first.description, 'Test description');
      expect(drafts.first.hashtags, ['test', 'vine']);
      expect(drafts.first.frameCount, 30);
      expect(drafts.first.selectedApproach, 'hybrid');
      expect(drafts.first.videoFile.path, videoFile.path);
    });

    testWidgets('should show success message and close after saving draft', (
      tester,
    ) async {
      final videoFile = File('/path/to/test/video.mp4');
      bool didPop = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VinePreviewScreenPure(
                          videoFile: videoFile,
                          frameCount: 30,
                          selectedApproach: 'hybrid',
                        ),
                      ),
                    );
                    didPop = true;
                  },
                  child: const Text('Open Preview'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open preview screen
      await tester.tap(find.text('Open Preview'));
      await tester.pumpAndSettle();

      // Tap Save Draft
      await tester.tap(find.text('Save Draft'));
      await tester.pump(); // Process tap

      // Snackbar should appear (may be 1 or 2 due to scaffold nesting)
      expect(find.text('Draft saved'), findsWidgets);

      await tester.pumpAndSettle();

      // Screen should have closed
      expect(didPop, true);
      expect(find.text('Preview Video'), findsNothing);
    });

    testWidgets('should close screen after saving draft', (tester) async {
      final videoFile = File('/path/to/test/video.mp4');
      bool didPop = false;

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => VinePreviewScreenPure(
                          videoFile: videoFile,
                          frameCount: 30,
                          selectedApproach: 'hybrid',
                        ),
                      ),
                    );
                    didPop = true;
                  },
                  child: const Text('Open Preview'),
                ),
              ),
            ),
          ),
        ),
      );

      // Open preview screen
      await tester.tap(find.text('Open Preview'));
      await tester.pumpAndSettle();

      expect(find.text('Preview Video'), findsOneWidget);

      // Save draft
      await tester.tap(find.text('Save Draft'));
      await tester.pumpAndSettle();

      // Screen should have closed
      expect(didPop, true);
      expect(find.text('Preview Video'), findsNothing);
    });

    testWidgets('should save draft with empty fields', (tester) async {
      final videoFile = File('/path/to/test/video.mp4');

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: VinePreviewScreenPure(
              videoFile: videoFile,
              frameCount: 45,
              selectedApproach: 'imageSequence',
            ),
          ),
        ),
      );

      // Don't enter any metadata, just save
      await tester.tap(find.text('Save Draft'));
      await tester.pump(); // Process tap

      // Verify draft was saved with empty fields
      final drafts = await draftService.getAllDrafts();
      expect(drafts.length, 1);
      expect(drafts.first.title, '');
      expect(drafts.first.description, '');
      // Default hashtags are pre-populated (openvine vine), not empty
      expect(drafts.first.hashtags, ['openvine', 'vine']);
      expect(drafts.first.frameCount, 45);
      expect(drafts.first.selectedApproach, 'imageSequence');
    });

    testWidgets('should not disable Save Draft button when uploading', (
      tester,
    ) async {
      final videoFile = File('/path/to/test/video.mp4');

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            home: VinePreviewScreenPure(
              videoFile: videoFile,
              frameCount: 30,
              selectedApproach: 'hybrid',
            ),
          ),
        ),
      );

      // Save Draft button should always be enabled (independent of upload state)
      final saveDraftButton = find.text('Save Draft');
      expect(saveDraftButton, findsOneWidget);

      // Verify it's a TextButton and not disabled
      final textButton = tester.widget<TextButton>(
        find.ancestor(of: saveDraftButton, matching: find.byType(TextButton)),
      );
      expect(textButton.onPressed, isNotNull);
    });
  });
}
