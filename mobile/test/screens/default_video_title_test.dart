// ABOUTME: Tests for default video title "Do it for the Vine!" functionality
// ABOUTME: Ensures all video metadata screens initialize with the correct default title

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/screens/pure/video_metadata_screen_pure.dart';
import 'package:openvine/screens/pure/vine_preview_screen_pure.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Default Video Title Tests (TDD)', () {
    late DraftStorageService draftStorage;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();

      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      draftStorage = DraftStorageService(prefs);
    });

    testWidgets('VideoMetadataScreenPure should display title from draft', (
      WidgetTester tester,
    ) async {
      final draft = VineDraft.create(
        videoFile: File('/path/to/test_video.mp4'),
        title: 'Do it for the Vine!',
        description: '',
        hashtags: [],
        frameCount: 30,
        selectedApproach: 'native',
      );
      await draftStorage.saveDraft(draft);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: VideoMetadataScreenPure(draftId: draft.id)),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Do it for the Vine!'), findsOneWidget);
    });

    testWidgets('VinePreviewScreenPure should display title from draft', (
      WidgetTester tester,
    ) async {
      final draft = VineDraft.create(
        videoFile: File('/path/to/test_video.mp4'),
        title: 'Do it for the Vine!',
        description: '',
        hashtags: [],
        frameCount: 10,
        selectedApproach: 'test',
      );
      await draftStorage.saveDraft(draft);

      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: VinePreviewScreenPure(draftId: draft.id)),
        ),
      );

      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));
      await tester.pump(const Duration(milliseconds: 100));

      expect(find.text('Do it for the Vine!'), findsOneWidget);
    });

    testWidgets(
      'VideoMetadataScreenPure should allow users to change the title',
      (WidgetTester tester) async {
        final draft = VineDraft.create(
          videoFile: File('/path/to/test_video.mp4'),
          title: 'Do it for the Vine!',
          description: '',
          hashtags: [],
          frameCount: 30,
          selectedApproach: 'native',
        );
        await draftStorage.saveDraft(draft);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: VideoMetadataScreenPure(draftId: draft.id),
            ),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        final titleTextField = find.widgetWithText(
          TextField,
          'Do it for the Vine!',
        );
        expect(titleTextField, findsOneWidget);

        await tester.enterText(titleTextField, 'My Custom Title');
        await tester.pump();

        expect(find.text('My Custom Title'), findsOneWidget);
      },
    );

    testWidgets(
      'VinePreviewScreenPure should allow users to change the title',
      (WidgetTester tester) async {
        final draft = VineDraft.create(
          videoFile: File('/path/to/test_video.mp4'),
          title: 'Do it for the Vine!',
          description: '',
          hashtags: [],
          frameCount: 10,
          selectedApproach: 'test',
        );
        await draftStorage.saveDraft(draft);

        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: VinePreviewScreenPure(draftId: draft.id)),
          ),
        );

        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        await tester.pump(const Duration(milliseconds: 100));

        final titleTextField = find.widgetWithText(
          TextField,
          'Do it for the Vine!',
        );
        expect(titleTextField, findsOneWidget);

        await tester.enterText(titleTextField, 'Another Custom Title');
        await tester.pump();

        expect(find.text('Another Custom Title'), findsOneWidget);
      },
    );
  });
}
