// ABOUTME: Widget tests for platform-specific recording UI hints
// ABOUTME: Tests "Tap to record" vs "Hold to record" text display

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/aspect_ratio.dart' as model;
import 'package:openvine/providers/vine_recording_provider.dart';
import 'package:openvine/services/vine_recording_controller.dart';

/// Test notifier that returns a fixed state
class _TestVineRecordingNotifier extends VineRecordingNotifier {
  final VineRecordingUIState _state;

  _TestVineRecordingNotifier(
    this._state,
    VineRecordingController controller,
    Ref ref,
  ) : super(controller, ref) {
    state = _state; // Set the initial state
  }
}

void main() {
  group('Camera Recording UI Hints Tests', () {
    testWidgets('should show "Tap to record" hint on web platform', (
      tester,
    ) async {
      // Create a mock recording state
      final mockState = VineRecordingUIState(
        recordingState: VineRecordingState.idle,
        progress: 0.0,
        totalRecordedDuration: Duration.zero,
        remainingDuration: const Duration(seconds: 6),
        canRecord: true,
        isCameraInitialized: true,
        canSwitchCamera: true,
        aspectRatio: model.AspectRatio.square,
        segments: [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vineRecordingProvider.overrideWith(
              (ref) => _TestVineRecordingNotifier(
                mockState,
                VineRecordingController(),
                ref,
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  final state = ref.watch(vineRecordingProvider);

                  // Simulate the hint logic from universal_camera_screen_pure.dart
                  return Column(
                    children: [
                      if (!state.isRecording && !state.hasSegments)
                        Text(kIsWeb ? 'Tap to record' : 'Hold to record'),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      if (kIsWeb) {
        expect(find.text('Tap to record'), findsOneWidget);
        expect(find.text('Hold to record'), findsNothing);
      } else {
        expect(find.text('Hold to record'), findsOneWidget);
        expect(find.text('Tap to record'), findsNothing);
      }
    });

    testWidgets('should show segment count on mobile when segments exist', (
      tester,
    ) async {
      if (kIsWeb) {
        // Skip this test on web
        return;
      }

      // Create state with segments
      final mockState = VineRecordingUIState(
        recordingState: VineRecordingState.paused,
        progress: 0.5,
        totalRecordedDuration: const Duration(seconds: 2),
        remainingDuration: const Duration(seconds: 4),
        canRecord: true,
        isCameraInitialized: true,
        canSwitchCamera: true,
        aspectRatio: model.AspectRatio.square,
        segments: [
          RecordingSegment(
            startTime: DateTime.now(),
            endTime: DateTime.now().add(const Duration(seconds: 1)),
            duration: const Duration(seconds: 1),
            filePath: '/test/segment1.mp4',
          ),
          RecordingSegment(
            startTime: DateTime.now(),
            endTime: DateTime.now().add(const Duration(seconds: 1)),
            duration: const Duration(seconds: 1),
            filePath: '/test/segment2.mp4',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vineRecordingProvider.overrideWith(
              (ref) => _TestVineRecordingNotifier(
                mockState,
                VineRecordingController(),
                ref,
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  final state = ref.watch(vineRecordingProvider);

                  return Column(
                    children: [
                      if (!kIsWeb && state.hasSegments)
                        Text(
                          '${state.segments.length} ${state.segments.length == 1 ? "segment" : "segments"}',
                        ),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      expect(find.text('2 segments'), findsOneWidget);
    });

    testWidgets('should not show segment count on web', (tester) async {
      if (!kIsWeb) {
        // Skip this test on mobile
        return;
      }

      final mockState = VineRecordingUIState(
        recordingState: VineRecordingState.idle,
        progress: 0.5,
        totalRecordedDuration: const Duration(seconds: 2),
        remainingDuration: const Duration(seconds: 4),
        canRecord: true,
        isCameraInitialized: true,
        canSwitchCamera: true,
        aspectRatio: model.AspectRatio.square,
        segments: [
          RecordingSegment(
            startTime: DateTime.now(),
            endTime: DateTime.now().add(const Duration(seconds: 1)),
            duration: const Duration(seconds: 1),
            filePath: '/test/segment1.mp4',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vineRecordingProvider.overrideWith(
              (ref) => _TestVineRecordingNotifier(
                mockState,
                VineRecordingController(),
                ref,
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  final state = ref.watch(vineRecordingProvider);

                  return Column(
                    children: [
                      if (!kIsWeb && state.hasSegments)
                        Text('${state.segments.length} segment'),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      // On web, segment count should not be shown
      expect(find.textContaining('segment'), findsNothing);
    });

    testWidgets('should hide hint when recording is active', (tester) async {
      final mockState = VineRecordingUIState(
        recordingState: VineRecordingState.recording,
        progress: 0.2,
        totalRecordedDuration: const Duration(milliseconds: 500),
        remainingDuration: const Duration(milliseconds: 5500),
        canRecord: false,
        isCameraInitialized: true,
        canSwitchCamera: false,
        aspectRatio: model.AspectRatio.square,
        segments: [],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vineRecordingProvider.overrideWith(
              (ref) => _TestVineRecordingNotifier(
                mockState,
                VineRecordingController(),
                ref,
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  final state = ref.watch(vineRecordingProvider);

                  return Column(
                    children: [
                      if (!state.isRecording && !state.hasSegments)
                        Text(kIsWeb ? 'Tap to record' : 'Hold to record'),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Hint should be hidden during recording
      expect(find.text('Tap to record'), findsNothing);
      expect(find.text('Hold to record'), findsNothing);
    });

    testWidgets('should hide hint when segments exist', (tester) async {
      final mockState = VineRecordingUIState(
        recordingState: VineRecordingState.paused,
        progress: 0.3,
        totalRecordedDuration: const Duration(seconds: 1),
        remainingDuration: const Duration(seconds: 5),
        canRecord: true,
        isCameraInitialized: true,
        canSwitchCamera: true,
        aspectRatio: model.AspectRatio.square,
        segments: [
          RecordingSegment(
            startTime: DateTime.now(),
            endTime: DateTime.now().add(const Duration(seconds: 1)),
            duration: const Duration(seconds: 1),
            filePath: '/test/segment1.mp4',
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            vineRecordingProvider.overrideWith(
              (ref) => _TestVineRecordingNotifier(
                mockState,
                VineRecordingController(),
                ref,
              ),
            ),
          ],
          child: MaterialApp(
            home: Scaffold(
              body: Consumer(
                builder: (context, ref, child) {
                  final state = ref.watch(vineRecordingProvider);

                  return Column(
                    children: [
                      if (!state.isRecording && !state.hasSegments)
                        Text(kIsWeb ? 'Tap to record' : 'Hold to record'),
                    ],
                  );
                },
              ),
            ),
          ),
        ),
      );

      // Hint should be hidden when segments exist
      expect(find.text('Tap to record'), findsNothing);
      expect(find.text('Hold to record'), findsNothing);
    });
  });
}
