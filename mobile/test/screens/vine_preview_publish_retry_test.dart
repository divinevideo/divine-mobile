// ABOUTME: Tests for publish status tracking and retry logic in VinePreviewScreenPure
// ABOUTME: Validates publishing, failed, and retry state transitions

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/screens/pure/vine_preview_screen_pure.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('VinePreviewScreenPure publish status', () {
    testWidgets('failed publish should show retry button', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final draftStorage = DraftStorageService(prefs);

      // Create draft with failed status
      final now = DateTime.now();
      final draft = VineDraft(
        id: 'failed_draft',
        videoFile: File('/path/to/video.mp4'),
        title: 'Failed Video',
        description: '',
        hashtags: [],
        frameCount: 30,
        selectedApproach: 'native',
        createdAt: now,
        lastModified: now,
        publishStatus: PublishStatus.failed,
        publishError: 'Network timeout',
        publishAttempts: 1,
      );
      await draftStorage.saveDraft(draft);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: VinePreviewScreenPure(draftId: draft.id)),
        ),
      );
      await tester.pumpAndSettle();

      // Should show error message
      expect(find.text('Network timeout'), findsOneWidget);

      // Should show retry button instead of publish
      expect(find.text('Retry'), findsOneWidget);
      expect(find.text('Publish'), findsNothing);
    });

    testWidgets('publishing status should show loading indicator', (
      tester,
    ) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final draftStorage = DraftStorageService(prefs);

      final now = DateTime.now();
      final draft = VineDraft(
        id: 'publishing_draft',
        videoFile: File('/path/to/video.mp4'),
        title: 'Publishing',
        description: '',
        hashtags: [],
        frameCount: 30,
        selectedApproach: 'native',
        createdAt: now,
        lastModified: now,
        publishStatus: PublishStatus.publishing,
        publishError: null,
        publishAttempts: 0,
      );
      await draftStorage.saveDraft(draft);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: VinePreviewScreenPure(draftId: draft.id)),
        ),
      );
      // Use pump instead of pumpAndSettle since CircularProgressIndicator animates forever
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      // Should show loading indicator
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });
  });
}
