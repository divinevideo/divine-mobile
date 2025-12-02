// ABOUTME: Integration test for auto-saving recordings as drafts when user navigates back
// ABOUTME: Tests TDD fix for bug where recordings are lost when navigating away from camera

import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:integration_test/integration_test.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/vine_recording_controller.dart';
import 'package:openvine/providers/vine_recording_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/pure/universal_camera_screen_pure.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  group('Camera Draft Auto-Save Tests', () {
    late SharedPreferences prefs;
    late DraftStorageService draftStorage;

    setUp(() async {
      // Initialize preferences
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      draftStorage = DraftStorageService(prefs);

      // Clear any existing drafts
      await draftStorage.clearAllDrafts();
    });

    tearDown(() async {
      // Clean up drafts
      await draftStorage.clearAllDrafts();
    });

    testWidgets(
      'FAILING: Recording auto-saved as draft when user navigates back after completion',
      (WidgetTester tester) async {
        if (!Platform.isMacOS && !Platform.isIOS && !Platform.isAndroid) {
          return; // Skip on unsupported platforms
        }

        // Build camera screen with providers
        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              // Provide draft storage service (override async provider with sync value)
              draftStorageServiceProvider.overrideWith(
                (ref) => Future.value(draftStorage),
              ),
            ],
            child: MaterialApp(home: UniversalCameraScreenPure()),
          ),
        );

        // Wait for camera initialization
        await tester.pumpAndSettle(const Duration(seconds: 2));

        // Get the recording provider
        final container = ProviderScope.containerOf(
          tester.element(find.byType(UniversalCameraScreenPure)),
        );
        final recordingNotifier = container.read(
          vineRecordingProvider.notifier,
        );

        // Verify no drafts initially
        final initialDrafts = await draftStorage.getAllDrafts();
        expect(
          initialDrafts,
          isEmpty,
          reason: 'Should have no drafts initially',
        );

        // Start recording
        await recordingNotifier.startRecording();
        await tester.pump();

        // Verify recording started
        final recordingState = container.read(vineRecordingProvider);
        expect(
          recordingState.recordingState,
          equals(VineRecordingState.recording),
          reason: 'Recording should be in progress',
        );

        // Wait for auto-stop (6.3 seconds)
        await tester.pump(const Duration(milliseconds: 6400));
        await tester.pumpAndSettle();

        // Verify recording completed
        final completedState = container.read(vineRecordingProvider);
        expect(
          completedState.recordingState,
          equals(VineRecordingState.completed),
          reason: 'Recording should auto-complete after max duration',
        );

        // Simulate user pressing back button (navigating away)
        await tester.pageBack();
        await tester.pumpAndSettle();

        // THIS IS THE FAILING ASSERTION - recording should be auto-saved as draft
        final draftsAfterNav = await draftStorage.getAllDrafts();
        expect(
          draftsAfterNav,
          isNotEmpty,
          reason:
              'Recording should be auto-saved as draft when navigating back',
        );

        // Verify draft has correct properties
        final draft = draftsAfterNav.first;
        expect(
          draft.videoFile.existsSync(),
          isTrue,
          reason: 'Draft video file should exist',
        );
        expect(
          draft.title,
          isNotEmpty,
          reason: 'Draft should have a default title',
        );

        // Verify video file is NOT deleted after navigation
        expect(
          draft.videoFile.existsSync(),
          isTrue,
          reason: 'Video file should not be deleted when saved as draft',
        );
      },
    );

    testWidgets('FAILING: Cleanup does not delete files saved as drafts', (
      WidgetTester tester,
    ) async {
      if (!Platform.isMacOS && !Platform.isIOS && !Platform.isAndroid) {
        return;
      }

      // Build camera screen
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            draftStorageServiceProvider.overrideWith(
              (ref) => Future.value(draftStorage),
            ),
          ],
          child: MaterialApp(home: UniversalCameraScreenPure()),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      final container = ProviderScope.containerOf(
        tester.element(find.byType(UniversalCameraScreenPure)),
      );
      final recordingNotifier = container.read(vineRecordingProvider.notifier);

      // Record and auto-complete
      await recordingNotifier.startRecording();
      await tester.pump(const Duration(milliseconds: 6400));
      await tester.pumpAndSettle();

      // Navigate back to trigger auto-save
      await tester.pageBack();
      await tester.pumpAndSettle();

      // Get the saved draft
      final drafts = await draftStorage.getAllDrafts();
      expect(drafts, isNotEmpty);

      final draftVideoPath = drafts.first.videoFile.path;
      final draftVideoFile = File(draftVideoPath);

      expect(
        draftVideoFile.existsSync(),
        isTrue,
        reason: 'Draft video should exist before re-entering camera',
      );

      // Navigate to camera again
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            draftStorageServiceProvider.overrideWith(
              (ref) => Future.value(draftStorage),
            ),
          ],
          child: MaterialApp(home: UniversalCameraScreenPure()),
        ),
      );

      await tester.pumpAndSettle(const Duration(seconds: 2));

      // THIS IS THE FAILING ASSERTION - draft file should NOT be deleted
      expect(
        draftVideoFile.existsSync(),
        isTrue,
        reason: 'Draft video file should not be deleted by camera cleanup',
      );
    });

    testWidgets('FAILING: No race condition with dual auto-stop timers', (
      WidgetTester tester,
    ) async {
      if (!Platform.isMacOS) {
        return; // This specifically tests macOS dual timer issue
      }

      final controller = VineRecordingController();

      try {
        await controller.initialize();

        // Start recording (should trigger only ONE timer after the fix)
        await controller.startRecording();

        // Wait for auto-stop
        await tester.pump(const Duration(milliseconds: 6400));
        await tester.pumpAndSettle();

        // Verify state is completed
        expect(
          controller.state,
          equals(VineRecordingState.completed),
          reason: 'Should be in completed state after auto-stop',
        );

        // THIS IS THE FAILING ASSERTION - should only have ONE segment from ONE timer
        expect(
          controller.segments.length,
          equals(1),
          reason: 'Should have exactly one segment (no race condition)',
        );

        // Verify finishRecording works correctly
        final (videoFile, _) = await controller.finishRecording();
        expect(videoFile, isNotNull);
        expect(videoFile!.existsSync(), isTrue);
      } finally {
        controller.dispose();
      }
    });
  });
}
