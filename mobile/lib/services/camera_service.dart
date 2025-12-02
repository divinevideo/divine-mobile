// ABOUTME: Stub camera service interface for backward compatibility with tests
// ABOUTME: Minimal implementation to resolve compilation errors in legacy test files

import 'dart:io';

/// Result of a vine recording operation
class VineRecordingResult {
  final File videoFile;
  final Duration duration;

  VineRecordingResult({required this.videoFile, required this.duration});
}

/// Abstract camera service interface for backward compatibility
abstract class CameraService {
  Future<void> startRecording();
  Future<VineRecordingResult> stopRecording();
  bool get isRecording;
}
