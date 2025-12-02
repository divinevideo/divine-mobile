// ABOUTME: Tests for default video title "Do it for the Vine!" functionality
// ABOUTME: Ensures all video metadata screens initialize with the correct default title

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/pure/video_metadata_screen_pure.dart';
import 'package:openvine/screens/pure/vine_preview_screen_pure.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Default Video Title Tests (TDD)', () {
    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();

      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({
        'vine_drafts': jsonEncode([
          {
            'id': 'draft_1',
            // Create a test video file path (file doesn't need to exist for title test)
            'videoFilePath': 'test_assets/test_video.mp4',
            'title': 'Do it for the Vine!',
            'description': 'Test description',
            'hashtags': ['test', 'vines'],
            'frameCount': 10,
            'selectedApproach': 'test',
            'createdAt': DateTime.now().toIso8601String(),
            'lastModified': DateTime.now().toIso8601String(),
            'publishStatus': 'draft',
            'publishError': null,
            'publishAttempts': 0,
            'proofManifestJson': null,
            'aspectRatio': 'square',
          },
        ]),
      });
    });

    tearDown(() {
      SharedPreferences.resetStatic();
    });

    testWidgets(
      'VideoMetadataScreenPure should initialize with default title "Do it for the Vine!"',
      (WidgetTester tester) async {
        // Arrange - Build the screen
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: VideoMetadataScreenPure(draftId: 'draft_1'),
            ),
          ),
        );

        // Allow widget to build
        await tester.pump();

        // Act - Find the title TextField by its hint text
        final titleTextField = find.widgetWithText(
          TextField,
          'Enter video title...',
        );

        // Assert - Verify default title is set
        expect(titleTextField, findsOneWidget);

        final TextField textField = tester.widget(titleTextField);
        expect(textField.controller?.text, equals('Do it for the Vine!'));
      },
    );

    testWidgets(
      'VinePreviewScreenPure should initialize with default title "Do it for the Vine!"',
      (WidgetTester tester) async {
        // Arrange - Build the screen
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: VinePreviewScreenPure(draftId: 'draft_1')),
          ),
        );

        // Allow widget to build
        await tester.pump();

        // Act - Find the title TextField by its hint text
        final titleTextField = find.widgetWithText(
          TextField,
          'Enter video title...',
        );

        // Assert - Verify default title is set
        expect(titleTextField, findsOneWidget);

        final TextField textField = tester.widget(titleTextField);
        expect(textField.controller?.text, equals('Do it for the Vine!'));
      },
    );

    testWidgets(
      'VideoMetadataScreenPure should allow users to change the default title',
      (WidgetTester tester) async {
        // Arrange - Build the screen
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: VideoMetadataScreenPure(draftId: 'draft_1'),
            ),
          ),
        );

        await tester.pump();

        // Act - Find the title TextField and enter new text
        final titleTextField = find.widgetWithText(
          TextField,
          'Enter video title...',
        );

        // Clear default title and enter custom title
        await tester.enterText(titleTextField, 'My Custom Title');
        await tester.pump();

        // Assert - Verify title was changed
        final TextField textField = tester.widget(titleTextField);
        expect(textField.controller?.text, equals('My Custom Title'));
      },
    );

    testWidgets(
      'VinePreviewScreenPure should allow users to change the default title',
      (WidgetTester tester) async {
        // Arrange - Build the screen
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(home: VinePreviewScreenPure(draftId: 'draft_1')),
          ),
        );

        await tester.pump();

        // Act - Find the title TextField and enter new text
        final titleTextField = find.widgetWithText(
          TextField,
          'Enter video title...',
        );

        // Clear default title and enter custom title
        await tester.enterText(titleTextField, 'Another Custom Title');
        await tester.pump();

        // Assert - Verify title was changed
        final TextField textField = tester.widget(titleTextField);
        expect(textField.controller?.text, equals('Another Custom Title'));
      },
    );
  });
}
