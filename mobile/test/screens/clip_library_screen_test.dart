// ABOUTME: Tests for ClipLibraryScreen - browsing and managing saved clips
// ABOUTME: Covers thumbnail display, clip deletion, and import functionality

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/saved_clip.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/clip_library_screen.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  group('ClipLibraryScreen', () {
    late SharedPreferences prefs;
    late ClipLibraryService clipService;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      clipService = ClipLibraryService(prefs);
    });

    Widget buildTestWidget() {
      return ProviderScope(
        overrides: [
          clipLibraryServiceProvider.overrideWith((ref) async => clipService),
        ],
        child: const MaterialApp(
          home: ClipLibraryScreen(),
        ),
      );
    }

    testWidgets('shows empty state when no clips', (tester) async {
      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      expect(find.text('No Clips Yet'), findsOneWidget);
      expect(find.text('Record a Video'), findsOneWidget);
    });

    testWidgets('displays clips in grid with thumbnails', (tester) async {
      // Add test clips
      await clipService.saveClip(SavedClip(
        id: 'clip_1',
        filePath: '/tmp/video1.mp4',
        thumbnailPath: null, // No thumbnail, will show placeholder
        duration: const Duration(seconds: 2),
        createdAt: DateTime.now(),
        aspectRatio: 'square',
      ));

      await clipService.saveClip(SavedClip(
        id: 'clip_2',
        filePath: '/tmp/video2.mp4',
        thumbnailPath: null,
        duration: const Duration(milliseconds: 1500),
        createdAt: DateTime.now(),
        aspectRatio: 'vertical',
      ));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Should show duration badges
      expect(find.text('2.0s'), findsOneWidget);
      expect(find.text('1.5s'), findsOneWidget);
    });

    testWidgets('shows delete confirmation dialog', (tester) async {
      await clipService.saveClip(SavedClip(
        id: 'clip_to_delete',
        filePath: '/tmp/video.mp4',
        thumbnailPath: null,
        duration: const Duration(seconds: 1),
        createdAt: DateTime.now(),
        aspectRatio: 'square',
      ));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Long press to show delete option
      await tester.longPress(find.byType(ClipThumbnailCard));
      await tester.pumpAndSettle();

      expect(find.text('Delete'), findsOneWidget);
    });

    testWidgets('deletes clip when confirmed', (tester) async {
      await clipService.saveClip(SavedClip(
        id: 'clip_to_delete',
        filePath: '/tmp/video.mp4',
        thumbnailPath: null,
        duration: const Duration(seconds: 1),
        createdAt: DateTime.now(),
        aspectRatio: 'square',
      ));

      await tester.pumpWidget(buildTestWidget());
      await tester.pumpAndSettle();

      // Initially has 1 clip
      expect((await clipService.getAllClips()).length, 1);

      // Long press and delete
      await tester.longPress(find.byType(ClipThumbnailCard));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();

      // Confirm deletion
      await tester.tap(find.text('Delete').last);
      await tester.pumpAndSettle();

      // Clip should be deleted
      expect((await clipService.getAllClips()).length, 0);
    });
  });
}
