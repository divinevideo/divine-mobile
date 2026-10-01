// ABOUTME: Records a real clip on a device and checks the recorder attaches a
// ABOUTME: JPEG thumbnail to it.

import 'dart:io';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/main.dart' as app;
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:patrol/patrol.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'helpers/patrol_semantics.dart';
import 'helpers/permission_helpers.dart';
import 'helpers/test_setup.dart';

/// The recorder's next state matching [test]. Fails the test when none
/// arrives within 10 seconds instead of waiting out the suite timeout.
Future<VideoRecorderBlocState> _nextState(
  VideoRecorderBloc bloc,
  bool Function(VideoRecorderBlocState state) test,
  String step,
) => bloc.stream
    .firstWhere(test)
    .timeout(
      const Duration(seconds: 10),
      onTimeout: () => fail('The recorder did not $step within 10 seconds'),
    );

void main() {
  ignorePlatformSemanticsHandle();

  group('Thumbnail Integration Tests', () {
    patrolTest(
      'Record video and generate thumbnail end-to-end',
      ($) async {
        final tester = $.tester;
        await runWithAppErrorHandlers(() async {
          app.main();
          await tester.pumpAndSettle();
          await grantCameraAndMicrophone($);

          final prefs = await SharedPreferences.getInstance();
          final container = ProviderContainer(
            overrides: [sharedPreferencesProvider.overrideWithValue(prefs)],
          );
          final bloc = VideoRecorderBloc(
            readClipManager: () => container.read(clipManagerProvider.notifier),
            readVideoEditor: () => container.read(videoEditorProvider.notifier),
            readVideoEditorState: () => container.read(videoEditorProvider),
            readSharedPreferences: () =>
                container.read(sharedPreferencesProvider),
          );

          try {
            bloc.add(const VideoRecorderInitializeRequested());
            final initState = await _nextState(
              bloc,
              (s) => s.isCameraInitialized || s.initializationError != null,
              'initialize the camera',
            );
            expect(initState.initializationError, isNull);

            bloc.add(const VideoRecorderRecordingStartRequested());
            await _nextState(bloc, (s) => s.isRecording, 'start recording');

            // Record long enough to produce a real clip.
            await Future<void>.delayed(const Duration(seconds: 2));

            bloc.add(const VideoRecorderRecordingStopRequested());
            await _nextState(
              bloc,
              (s) => !s.isRecording && !s.isStoppingRecording,
              'stop recording',
            );

            // The stop handler emits the idle state before it attaches the
            // thumbnail, so poll the clip for it (bounded).
            final clipProvider = container.read(clipManagerProvider.notifier);
            final postProcessing = Stopwatch()..start();
            while (clipProvider.clips.isNotEmpty &&
                clipProvider.clips.first.thumbnailPath == null &&
                postProcessing.elapsed < const Duration(seconds: 10)) {
              await Future<void>.delayed(const Duration(milliseconds: 100));
            }

            final clips = clipProvider.clips;
            expect(clips, isNotEmpty, reason: 'Recording should add a clip');
            final clip = clips.first;
            final videoFile = File(await clip.requireVideo.safeFilePath());
            expect(videoFile.lengthSync(), greaterThan(0));

            final thumbnailPath = clip.thumbnailPath;
            expect(
              thumbnailPath,
              isNotNull,
              reason: 'The recorded clip should get a thumbnail',
            );
            final thumbnailBytes = await File(thumbnailPath!).readAsBytes();
            expect(
              thumbnailBytes.take(2),
              equals([0xFF, 0xD8]),
              reason: 'The thumbnail should be a JPEG',
            );

            await videoFile.delete();
            await File(thumbnailPath).delete();
          } finally {
            await bloc.close();
            container.dispose();
          }
        });
      },
      timeout: const Timeout(Duration(minutes: 2)),
    );
  });
}
