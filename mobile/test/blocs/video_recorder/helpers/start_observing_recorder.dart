// ABOUTME: A recorder that reports when its recording-start handler finished,
// ABOUTME: for tests asserting on work that handler awaits, such as file I/O.

import 'dart:async';

import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';

/// A [VideoRecorderBloc] that completes [startDone] when a
/// [VideoRecorderRecordingStartRequested] handler has run to its end.
///
/// A start aborted by the navigation lock deletes its file with real file
/// I/O inside that handler. No pump of the event loop waits for an I/O
/// thread, so only the handler's end says the file is gone.
class StartObservingRecorder extends VideoRecorderBloc {
  StartObservingRecorder({
    required super.readClipManager,
    required super.readVideoEditor,
    required super.readVideoEditorState,
    required super.readSharedPreferences,
    required super.cameraService,
  });

  /// Completes once the first start handler has returned or thrown.
  final startDone = Completer<void>();

  @override
  void onDone(
    VideoRecorderEvent event, [
    Object? error,
    StackTrace? stackTrace,
  ]) {
    super.onDone(event, error, stackTrace);
    if (event is VideoRecorderRecordingStartRequested &&
        !startDone.isCompleted) {
      startDone.complete();
    }
  }
}
