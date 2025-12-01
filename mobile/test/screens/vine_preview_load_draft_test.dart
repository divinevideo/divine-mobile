// ABOUTME: Tests for VinePreviewScreenPure loading drafts by ID
// ABOUTME: Validates draft loading, editing, and publish status updates

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/screens/pure/vine_preview_screen_pure.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('VinePreviewScreenPure draft loading', () {
    testWidgets('should load draft by ID on initialization', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final draftStorage = DraftStorageService(prefs);

      // Create a draft
      final draft = VineDraft.create(
        videoFile: File('/path/to/video.mp4'),
        title: 'Test Video',
        description: 'Test description',
        hashtags: ['test', 'video'],
        frameCount: 30,
        selectedApproach: 'native',
      );
      await draftStorage.saveDraft(draft);

      // Build screen with draft ID
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: VinePreviewScreenPure(draftId: draft.id)),
        ),
      );
      await tester.pumpAndSettle();

      // Verify draft data loaded into form
      expect(find.text('Test Video'), findsOneWidget);
      expect(find.text('Test description'), findsOneWidget);
    });

    testWidgets('save button should update existing draft', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final draftStorage = DraftStorageService(prefs);

      final draft = VineDraft.create(
        videoFile: File('/path/to/video.mp4'),
        title: 'Original',
        description: '',
        hashtags: [],
        frameCount: 30,
        selectedApproach: 'native',
      );
      await draftStorage.saveDraft(draft);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: VinePreviewScreenPure(draftId: draft.id)),
        ),
      );
      await tester.pumpAndSettle();

      // Edit title
      await tester.enterText(find.byType(TextField).first, 'Updated Title');

      // Tap save
      await tester.tap(find.text('Save Draft'));
      await tester.pumpAndSettle();

      // Verify draft updated (not duplicated)
      final drafts = await draftStorage.getAllDrafts();
      expect(drafts.length, 1);
      expect(drafts.first.id, draft.id);
      expect(drafts.first.title, 'Updated Title');
    });
  });
}
