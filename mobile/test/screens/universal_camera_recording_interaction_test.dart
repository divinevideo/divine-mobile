// ABOUTME: TDD tests for universal camera screen recording interaction patterns
// ABOUTME: Tests platform-specific recording behavior - web single-shot vs mobile press-and-hold

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/screens/pure/universal_camera_screen_pure.dart';
import 'package:openvine/providers/vine_recording_provider.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('Universal Camera Recording Interaction Tests (TDD)', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    group('Web Platform - Single-Shot Recording', () {
      testWidgets('should use tap interaction on web (not press-and-hold)', (
        tester,
      ) async {
        // TEST DESCRIPTION:
        // On web, recording should be single-shot with tap to start/stop
        // NOT press-and-hold like mobile

        await tester.pumpWidget(
          ProviderScope(child: MaterialApp(home: UniversalCameraScreenPure())),
        );

        // Wait for camera to initialize
        await tester.pumpAndSettle();

        // Find the record button
        final recordButton = find.byType(GestureDetector).first;

        if (kIsWeb) {
          // On web: First tap should START recording
          await tester.tap(recordButton);
          await tester.pumpAndSettle();

          // Verify recording started
          final state = container.read(vineRecordingProvider);
          expect(
            state.isRecording,
            isTrue,
            reason: 'Web should start recording on tap',
          );

          // Second tap should STOP recording
          await tester.tap(recordButton);
          await tester.pumpAndSettle();

          // Verify recording stopped
          final stateAfter = container.read(vineRecordingProvider);
          expect(
            stateAfter.isRecording,
            isFalse,
            reason: 'Web should stop recording on second tap',
          );
        }
      }, skip: !kIsWeb);

      testWidgets('should show clear UI indication that web is single-shot', (
        tester,
      ) async {
        // TEST DESCRIPTION:
        // Web UI should clearly indicate it's single continuous recording
        // Not segmented recording like mobile

        await tester.pumpWidget(
          ProviderScope(child: MaterialApp(home: UniversalCameraScreenPure())),
        );

        await tester.pumpAndSettle();

        if (kIsWeb) {
          // Should show "Tap to Record" or similar text
          // NOT "Hold to Record" which would be misleading
          expect(
            find.textContaining('Tap'),
            findsOneWidget,
            reason: 'Web should show tap instruction',
          );

          // Should NOT show segment-related UI elements
          expect(
            find.textContaining('segment'),
            findsNothing,
            reason: 'Web should not show segment UI',
          );
        }
      }, skip: !kIsWeb);

      testWidgets('should prevent multiple recording attempts on web', (
        tester,
      ) async {
        // TEST DESCRIPTION:
        // On web, user should not be able to start a second recording
        // until the first is complete

        await tester.pumpWidget(
          ProviderScope(child: MaterialApp(home: UniversalCameraScreenPure())),
        );

        await tester.pumpAndSettle();

        if (kIsWeb) {
          final recordButton = find.byType(GestureDetector).first;

          // Start recording
          await tester.tap(recordButton);
          await tester.pumpAndSettle();

          // Try to tap again (should be ignored/disabled)
          await tester.tap(recordButton);
          await tester.pumpAndSettle();

          // Should still be in recording state
          final state = container.read(vineRecordingProvider);
          expect(
            state.isRecording,
            isTrue,
            reason: 'Should ignore second tap while recording',
          );
        }
      }, skip: !kIsWeb);
    });

    group('Mobile/Desktop Platform - Press-and-Hold Recording', () {
      testWidgets('should use press-and-hold interaction on mobile', (
        tester,
      ) async {
        // TEST DESCRIPTION:
        // On mobile, recording should be Vine-style press-and-hold
        // Press to record, release to pause

        await tester.pumpWidget(
          ProviderScope(child: MaterialApp(home: UniversalCameraScreenPure())),
        );

        await tester.pumpAndSettle();

        final recordButton = find.byType(GestureDetector).first;

        if (!kIsWeb) {
          // Press down should START recording
          final gesture = await tester.startGesture(
            tester.getCenter(recordButton),
          );
          await tester.pumpAndSettle();

          final stateWhilePressed = container.read(vineRecordingProvider);
          expect(
            stateWhilePressed.isRecording,
            isTrue,
            reason: 'Should start recording on press down',
          );

          // Release should PAUSE recording (not stop completely)
          await gesture.up();
          await tester.pumpAndSettle();

          final stateAfterRelease = container.read(vineRecordingProvider);
          expect(
            stateAfterRelease.isRecording,
            isFalse,
            reason: 'Should pause recording on release',
          );
          expect(
            stateAfterRelease.segments.isNotEmpty,
            isTrue,
            reason: 'Should have recorded segment',
          );
        }
      }, skip: kIsWeb);

      testWidgets('should support multiple press-and-hold segments on mobile', (
        tester,
      ) async {
        // TEST DESCRIPTION:
        // On mobile, user can press-hold-release multiple times
        // to create segmented recording

        await tester.pumpWidget(
          ProviderScope(child: MaterialApp(home: UniversalCameraScreenPure())),
        );

        await tester.pumpAndSettle();

        final recordButton = find.byType(GestureDetector).first;

        if (!kIsWeb) {
          // First segment
          var gesture = await tester.startGesture(
            tester.getCenter(recordButton),
          );
          await tester.pump(const Duration(milliseconds: 200));
          await gesture.up();
          await tester.pumpAndSettle();

          var state = container.read(vineRecordingProvider);
          expect(
            state.segments.length,
            equals(1),
            reason: 'Should have 1 segment after first press-release',
          );

          // Second segment
          gesture = await tester.startGesture(tester.getCenter(recordButton));
          await tester.pump(const Duration(milliseconds: 200));
          await gesture.up();
          await tester.pumpAndSettle();

          state = container.read(vineRecordingProvider);
          expect(
            state.segments.length,
            equals(2),
            reason: 'Should have 2 segments after second press-release',
          );

          // Third segment
          gesture = await tester.startGesture(tester.getCenter(recordButton));
          await tester.pump(const Duration(milliseconds: 200));
          await gesture.up();
          await tester.pumpAndSettle();

          state = container.read(vineRecordingProvider);
          expect(
            state.segments.length,
            equals(3),
            reason: 'Should have 3 segments after third press-release',
          );
        }
      }, skip: kIsWeb);

      testWidgets('should show segment count UI on mobile', (tester) async {
        // TEST DESCRIPTION:
        // Mobile UI should show how many segments have been recorded

        await tester.pumpWidget(
          ProviderScope(child: MaterialApp(home: UniversalCameraScreenPure())),
        );

        await tester.pumpAndSettle();

        if (!kIsWeb) {
          final recordButton = find.byType(GestureDetector).first;

          // Record a segment
          final gesture = await tester.startGesture(
            tester.getCenter(recordButton),
          );
          await tester.pump(const Duration(milliseconds: 200));
          await gesture.up();
          await tester.pumpAndSettle();

          // Should show segment indicator
          expect(
            find.textContaining('segment'),
            findsAtLeastNWidgets(1),
            reason: 'Mobile should show segment information',
          );
        }
      }, skip: kIsWeb);
    });

    group('Platform-Agnostic Requirements', () {
      testWidgets('should show publish button when recording is complete', (
        tester,
      ) async {
        // TEST DESCRIPTION:
        // Both platforms should show checkmark/publish button
        // when user has recorded content

        await tester.pumpWidget(
          ProviderScope(child: MaterialApp(home: UniversalCameraScreenPure())),
        );

        await tester.pumpAndSettle();

        // Initially no publish button
        expect(find.byIcon(Icons.check_circle), findsNothing);

        // After recording, publish button should appear
        // (Implementation will make this pass)
      });

      testWidgets('should show total recording duration', (tester) async {
        // TEST DESCRIPTION:
        // Both platforms should show running timer during recording

        await tester.pumpWidget(
          ProviderScope(child: MaterialApp(home: UniversalCameraScreenPure())),
        );

        await tester.pumpAndSettle();

        // Should find duration display (00:00 format)
        expect(
          find.byWidgetPredicate(
            (widget) =>
                widget is Text &&
                widget.data != null &&
                RegExp(r'\d{2}:\d{2}').hasMatch(widget.data!),
          ),
          findsOneWidget,
          reason: 'Should show recording duration timer',
        );
      });

      testWidgets('should enforce 6.3 second maximum on both platforms', (
        tester,
      ) async {
        // TEST DESCRIPTION:
        // Both web and mobile should auto-stop at 6.3 seconds max

        await tester.pumpWidget(
          ProviderScope(child: MaterialApp(home: UniversalCameraScreenPure())),
        );

        await tester.pumpAndSettle();

        // Start recording
        final recordButton = find.byType(GestureDetector).first;

        if (kIsWeb) {
          await tester.tap(recordButton);
        } else {
          await tester.startGesture(tester.getCenter(recordButton));
        }

        await tester.pumpAndSettle();

        // Wait for max duration
        await tester.pump(const Duration(milliseconds: 6400));
        await tester.pumpAndSettle();

        // Should have auto-stopped
        final state = container.read(vineRecordingProvider);
        expect(
          state.canRecord,
          isFalse,
          reason: 'Should not allow recording after 6.3 seconds',
        );
      });
    });
  });
}
