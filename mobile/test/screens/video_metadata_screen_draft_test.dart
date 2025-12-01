// ABOUTME: Tests for VideoMetadataScreenPure draft loading and publish status
// ABOUTME: Validates same draft behavior as VinePreviewScreenPure

import 'dart:io';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/screens/pure/video_metadata_screen_pure.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('VideoMetadataScreenPure draft loading', () {
    testWidgets('should load draft by ID', (tester) async {
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final draftStorage = DraftStorageService(prefs);

      final draft = VineDraft.create(
        videoFile: File('/path/to/video.mp4'),
        title: 'Metadata Test',
        description: 'Test description',
        hashtags: ['metadata', 'test'],
        frameCount: 30,
        selectedApproach: 'native',
      );
      await draftStorage.saveDraft(draft);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: VideoMetadataScreenPure(draftId: draft.id)),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Metadata Test'), findsOneWidget);
      expect(find.text('Test description'), findsOneWidget);
    });
  });
}
