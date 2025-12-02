// ABOUTME: Tests for default video title "Do it for the Vine!" functionality
// ABOUTME: Ensures all video metadata screens initialize with the correct default title

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/pure/video_metadata_screen_pure.dart';
import 'package:openvine/screens/pure/vine_preview_screen_pure.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('Default Video Title Tests (TDD)', () {
    late File testVideoFile;

    setUp(() async {
      TestWidgetsFlutterBinding.ensureInitialized();

      // Mock SharedPreferences
      SharedPreferences.setMockInitialValues({});

      // Create a test video file path (file doesn't need to exist for title test)
      testVideoFile = File('test_assets/test_video.mp4');
    });

    testWidgets(
      'VideoMetadataScreenPure should initialize with default title "Do it for the Vine!"',
      (WidgetTester tester) async {
        // Arrange - Build the screen
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: VideoMetadataScreenPure(
                videoFile: testVideoFile,
                duration: const Duration(seconds: 5),
              ),
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
            child: MaterialApp(
              home: VinePreviewScreenPure(
                videoFile: testVideoFile,
                frameCount: 10,
                selectedApproach: 'test',
              ),
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
      'VideoMetadataScreenPure should allow users to change the default title',
      (WidgetTester tester) async {
        // Arrange - Build the screen
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              home: VideoMetadataScreenPure(
                videoFile: testVideoFile,
                duration: const Duration(seconds: 5),
              ),
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
            child: MaterialApp(
              home: VinePreviewScreenPure(
                videoFile: testVideoFile,
                frameCount: 10,
                selectedApproach: 'test',
              ),
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
        await tester.enterText(titleTextField, 'Another Custom Title');
        await tester.pump();

        // Assert - Verify title was changed
        final TextField textField = tester.widget(titleTextField);
        expect(textField.controller?.text, equals('Another Custom Title'));
      },
    );
  });
}
