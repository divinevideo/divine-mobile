// ABOUTME: Riverpod state management for VineRecordingController
// ABOUTME: Provides reactive state updates for recording UI without ChangeNotifier

import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:riverpod/riverpod.dart' show Ref;
import 'package:openvine/services/vine_recording_controller.dart'
    show VineRecordingController, VineRecordingState, RecordingSegment, MacOSCameraInterface, CameraPlatformInterface, MobileCameraInterface;
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/models/native_proof_data.dart';
import 'package:openvine/models/aspect_ratio.dart' as model;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// Result returned from stopRecording containing video file, draft ID, and native proof
class RecordingResult {
  const RecordingResult({
    required this.videoFile,
    required this.draftId,
    this.nativeProof,
  });

  final File? videoFile;
  final String? draftId;
  final NativeProofData? nativeProof;
}

/// State class for VineRecording that captures all necessary UI state
class VineRecordingUIState {
  const VineRecordingUIState({
    required this.recordingState,
    required this.progress,
    required this.totalRecordedDuration,
    required this.remainingDuration,
    required this.canRecord,
    required this.segments,
    required this.hasSegments,
    required this.isCameraInitialized,
    required this.canSwitchCamera,
    required this.aspectRatio,
    this.cameraSwitchCount = 0,
  });

  final VineRecordingState recordingState;
  final double progress;
  final Duration totalRecordedDuration;
  final Duration remainingDuration;
  final bool canRecord;
  final List<RecordingSegment> segments;
  final bool hasSegments; // From controller.hasSegments - includes virtual segments for macOS
  final bool isCameraInitialized;
  final bool canSwitchCamera;
  final model.AspectRatio aspectRatio;
  final int cameraSwitchCount; // Increments each time camera switches to force UI rebuild

  // Convenience getters used by UI
  bool get isRecording => recordingState == VineRecordingState.recording;
  bool get isInitialized => isCameraInitialized && recordingState != VineRecordingState.processing && recordingState != VineRecordingState.error;
  bool get isError => recordingState == VineRecordingState.error;
  Duration get recordingDuration => totalRecordedDuration;
  String? get errorMessage => isError ? 'Recording error occurred' : null;

  VineRecordingUIState copyWith({
    VineRecordingState? recordingState,
    double? progress,
    Duration? totalRecordedDuration,
    Duration? remainingDuration,
    bool? canRecord,
    List<RecordingSegment>? segments,
    bool? hasSegments,
    bool? isCameraInitialized,
    bool? canSwitchCamera,
    model.AspectRatio? aspectRatio,
    int? cameraSwitchCount,
  }) {
    return VineRecordingUIState(
      recordingState: recordingState ?? this.recordingState,
      progress: progress ?? this.progress,
      totalRecordedDuration:
          totalRecordedDuration ?? this.totalRecordedDuration,
      remainingDuration: remainingDuration ?? this.remainingDuration,
      canRecord: canRecord ?? this.canRecord,
      segments: segments ?? this.segments,
      hasSegments: hasSegments ?? this.hasSegments,
      isCameraInitialized: isCameraInitialized ?? this.isCameraInitialized,
      canSwitchCamera: canSwitchCamera ?? this.canSwitchCamera,
      aspectRatio: aspectRatio ?? this.aspectRatio,
      cameraSwitchCount: cameraSwitchCount ?? this.cameraSwitchCount,
    );
  }
}

/// StateNotifier that wraps VineRecordingController and provides reactive updates
class VineRecordingNotifier extends StateNotifier<VineRecordingUIState> {
  VineRecordingNotifier(
    this._controller,
    this._ref,
  ) : super(
          VineRecordingUIState(
            recordingState: _controller.state,
            progress: _controller.progress,
            totalRecordedDuration: _controller.totalRecordedDuration,
            remainingDuration: _controller.remainingDuration,
            canRecord: _controller.canRecord,
            segments: _controller.segments,
            hasSegments: _controller.hasSegments,
            isCameraInitialized: _controller.isCameraInitialized,
            canSwitchCamera: _controller.canSwitchCamera,
            aspectRatio: _controller.aspectRatio,
          ),
        ) {
    // Set up callback for recording progress updates
    _controller.setStateChangeCallback(updateState);
  }

  final VineRecordingController _controller;
  final Ref _ref;

  // Track whether video was successfully published to prevent auto-save
  bool _wasPublished = false;

  // Track the draft ID we created in stopRecording to prevent duplicate drafts
  String? _currentDraftId;

  /// Get the camera preview widget from the controller
  Widget get previewWidget => _controller.previewWidget;

  /// Get the underlying camera interface for advanced controls
  CameraPlatformInterface? get cameraInterface => _controller.cameraInterface;

  /// Get the actual camera preview aspect ratio to prevent distortion
  /// Returns the real camera sensor aspect ratio, or defaults to 3:4 if unavailable
  double get cameraPreviewAspectRatio {
    final interface = _controller.cameraInterface;
    if (interface is MobileCameraInterface) {
      // Get aspect ratio from mobile camera controller
      final controller = interface.controller;
      if (controller != null && controller.value.isInitialized) {
        return controller.value.aspectRatio;
      }
    }
    // Default fallback for macOS/web or uninitialized cameras
    return 3.0 / 4.0;
  }

  /// Update the state based on the current controller state
  void updateState() {
    state = VineRecordingUIState(
      recordingState: _controller.state,
      progress: _controller.progress,
      totalRecordedDuration: _controller.totalRecordedDuration,
      remainingDuration: _controller.remainingDuration,
      canRecord: _controller.canRecord,
      segments: _controller.segments,
      hasSegments: _controller.hasSegments, // CRITICAL: Use controller's hasSegments which includes virtual segments for macOS
      isCameraInitialized: _controller.isCameraInitialized,
      canSwitchCamera: _controller.canSwitchCamera,
      aspectRatio: _controller.aspectRatio,
      cameraSwitchCount: state.cameraSwitchCount, // CRITICAL: Preserve camera switch count
    );
  }

  // Delegate methods to the controller
  Future<void> initialize() async {
    await _controller.initialize();
    updateState();
  }

  Future<void> startRecording() async {
    await _controller.startRecording();
    updateState();
  }

  Future<RecordingResult> stopRecording() async {
    await _controller.stopRecording();
    final result = await _controller.finishRecording();
    updateState();

    Log.info('🔍 PROOFMODE DEBUG: stopRecording() called', category: LogCategory.video);
    Log.info('🔍 Video file: ${result.$1?.path ?? "NULL"}', category: LogCategory.video);
    Log.info('🔍 Native proof: ${result.$2?.toString() ?? "NULL"}', category: LogCategory.video);

    // Auto-create draft immediately after recording finishes
    if (result.$1 != null) {
      try {
        final draftStorage = await _ref.read(draftStorageServiceProvider.future);

        // Serialize NativeProofData to JSON if available
        String? proofManifestJson;
        if (result.$2 != null) {
          try {
            proofManifestJson = jsonEncode(result.$2!.toJson());
            Log.info('📜 Native ProofMode data attached to draft', category: LogCategory.video);
            Log.info('🔍 Proof JSON length: ${proofManifestJson.length} chars', category: LogCategory.video);
            Log.info('🔍 Proof verification level: ${result.$2!.verificationLevel}', category: LogCategory.video);
          } catch (e) {
            Log.error('Failed to serialize NativeProofData for draft: $e', category: LogCategory.video);
          }
        } else {
          Log.warning('⚠️ NO NATIVE PROOF DATA FROM RECORDING! ProofMode will not be published.', category: LogCategory.video);
        }

        final draft = VineDraft.create(
          videoFile: result.$1!,
          title: 'Do it for the Vine!',
          description: '',
          hashtags: ['openvine', 'vine'],
          frameCount: _controller.segments.length,
          selectedApproach: 'native',
          proofManifestJson: proofManifestJson,
          aspectRatio: _controller.aspectRatio,
        );

        await draftStorage.saveDraft(draft);
        _currentDraftId = draft.id; // Track draft to prevent duplicate on dispose
        Log.info('📹 Auto-created draft: ${draft.id}', category: LogCategory.video);

        return RecordingResult(
          videoFile: result.$1,
          draftId: draft.id,
          nativeProof: result.$2,
        );
      } catch (e) {
        Log.error('📹 Failed to auto-create draft: $e', category: LogCategory.video);
        // Still return the video file so user can manually save
        return RecordingResult(
          videoFile: result.$1,
          draftId: null,
          nativeProof: result.$2,
        );
      }
    }

    return RecordingResult(
      videoFile: null,
      draftId: null,
      nativeProof: result.$2,
    );
  }

  /// Stop the current segment without finishing the recording.
  /// This allows the user to record multiple segments before finalizing.
  Future<void> stopSegment() async {
    await _controller.stopRecording();
    updateState();
    Log.info('📹 Segment stopped, total segments: ${_controller.segments.length}',
        category: LogCategory.video);
  }

  Future<(File?, NativeProofData?)> finishRecording() async {
    final result = await _controller.finishRecording();
    updateState();
    return result;
  }

  Future<void> switchCamera() async {
    await _controller.switchCamera();

    // Force state update to rebuild UI with new camera preview
    // Increment camera switch count to ensure state object changes and triggers UI rebuild
    state = state.copyWith(
      cameraSwitchCount: state.cameraSwitchCount + 1,
    );
    updateState();
  }

  /// Set aspect ratio for recording
  void setAspectRatio(model.AspectRatio ratio) {
    _controller.setAspectRatio(ratio);
    updateState();
  }

  void reset() {
    _controller.reset();
    _wasPublished = false; // Reset publish flag for new recording
    _currentDraftId = null; // Clear draft ID for new recording
    updateState();
  }

  /// Mark recording as published to prevent auto-save on dispose
  void markAsPublished() {
    _wasPublished = true;
    Log.info('Recording marked as published - auto-save will be skipped',
        name: 'VineRecordingProvider', category: LogCategory.system);
  }

  /// Clean up temp files and reset for new recording
  Future<void> cleanupAndReset() async {
    try {
      // Clean up temp files first
      _controller.cleanupFiles();
      // Then reset state
      _controller.reset();
      _wasPublished = false;
      _currentDraftId = null; // Clear draft ID for new recording
      updateState();
      Log.info('Cleaned up temp files and reset for new recording',
          name: 'VineRecordingProvider', category: LogCategory.system);
    } catch (e) {
      Log.error('Error during cleanup and reset: $e',
          name: 'VineRecordingProvider', category: LogCategory.system);
    }
  }

  @override
  void dispose() {
    // Auto-save as draft if recording completed but not published
    // Note: We can't await in dispose(), so we use unawaited future
    // The controller cleanup will be delayed until save completes via the future chain
    _autoSaveDraftBeforeDispose().then((_) {
      // Clear callback to prevent memory leaks
      _controller.setStateChangeCallback(null);
      _controller.dispose();
    }).catchError((e) {
      Log.error('Error during auto-save, proceeding with cleanup: $e',
          name: 'VineRecordingProvider', category: LogCategory.system);
      // Ensure cleanup happens even if save fails
      _controller.setStateChangeCallback(null);
      _controller.dispose();
    }).whenComplete(() {
      super.dispose();
    });
  }

  /// Auto-save recording as draft if completed but not published
  Future<void> _autoSaveDraftBeforeDispose() async {
    try {
      // Skip auto-save if video was successfully published
      if (_wasPublished) {
        Log.info('Skipping auto-save - video was published',
            name: 'VineRecordingProvider', category: LogCategory.system);
        return;
      }

      // Skip auto-save if we already created a draft in stopRecording()
      if (_currentDraftId != null) {
        Log.info('Skipping auto-save - draft already created: $_currentDraftId',
            name: 'VineRecordingProvider', category: LogCategory.system);
        return;
      }

      // Only auto-save if recording is completed
      if (_controller.state != VineRecordingState.completed) {
        return;
      }

      // Check if we have segments to save
      if (_controller.segments.isEmpty) {
        Log.debug('No segments to auto-save as draft',
            name: 'VineRecordingProvider', category: LogCategory.system);
        return;
      }

      // Get the video file path from macOS single recording mode
      if (Platform.isMacOS && _controller.cameraInterface is MacOSCameraInterface) {
        final macOSInterface = _controller.cameraInterface as MacOSCameraInterface;
        final videoPath = macOSInterface.currentRecordingPath;

        if (videoPath != null && File(videoPath).existsSync()) {
          await _saveDraftFromPath(videoPath);
          return;
        }
      }

      // For other platforms or if macOS path not available, check segments
      final segment = _controller.segments.firstOrNull;
      if (segment?.filePath != null && File(segment!.filePath!).existsSync()) {
        await _saveDraftFromPath(segment.filePath!);
      }
    } catch (e) {
      Log.error('Failed to auto-save draft on dispose: $e',
          name: 'VineRecordingProvider', category: LogCategory.system);
      // Don't rethrow - ensure cleanup continues
    }
  }

  /// Save draft from video file path
  Future<void> _saveDraftFromPath(String videoPath) async {
    try {
      final draftStorage = await _ref.read(draftStorageServiceProvider.future);

      // Copy video file to permanent draft location using app support directory (sandboxed)
      final appDir = await getApplicationSupportDirectory();
      final draftsDir = Directory(path.join(appDir.path, 'drafts'));
      if (!draftsDir.existsSync()) {
        draftsDir.createSync(recursive: true);
      }

      final timestamp = DateTime.now().millisecondsSinceEpoch;
      final extension = path.extension(videoPath);
      final permanentPath = path.join(draftsDir.path, 'draft_$timestamp$extension');

      // Copy the file to permanent location
      final sourceFile = File(videoPath);
      final permanentFile = await sourceFile.copy(permanentPath);

      Log.info('📁 Copied draft video to permanent location: $permanentPath',
          name: 'VineRecordingProvider', category: LogCategory.system);

      // Create draft with permanent file path
      final draft = VineDraft.create(
        videoFile: permanentFile,
        title: 'Untitled Draft - ${DateTime.now().toLocal().toString().split('.')[0]}',
        description: '',
        hashtags: [],
        frameCount: 0,
        selectedApproach: 'auto',
      );

      await draftStorage.saveDraft(draft);

      Log.info('✅ Auto-saved recording as draft: ${draft.id}',
          name: 'VineRecordingProvider', category: LogCategory.system);
    } catch (e) {
      Log.error('Failed to save draft: $e',
          name: 'VineRecordingProvider', category: LogCategory.system);
      rethrow;
    }
  }

  // Getters that delegate to controller
  VineRecordingController get controller => _controller;
  CameraPlatformInterface? getCameraInterface() => _controller.cameraInterface;
}

/// Provider for VineRecordingController with reactive state management
final vineRecordingProvider =
    StateNotifierProvider<VineRecordingNotifier, VineRecordingUIState>((ref) {
  // Create recording controller (ProofMode handled by Guardian Project native library)
  final controller = VineRecordingController();
  final notifier = VineRecordingNotifier(controller, ref);

  ref.onDispose(() {
    notifier.dispose();
  });

  return notifier;
});
