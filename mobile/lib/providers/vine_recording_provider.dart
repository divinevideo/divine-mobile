// ABOUTME: Riverpod state management for VineRecordingController
// ABOUTME: Provides reactive state updates for recording UI without ChangeNotifier

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:riverpod/riverpod.dart' show Ref;
import 'package:openvine/services/vine_recording_controller.dart'
    show VineRecordingController, VineRecordingState, RecordingSegment, MacOSCameraInterface;
import 'package:openvine/services/proofmode_session_service.dart'
    show ProofManifest, ProofModeSessionService;
import 'package:openvine/services/proofmode_key_service.dart';
import 'package:openvine/services/proofmode_attestation_service.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;

/// State class for VineRecording that captures all necessary UI state
class VineRecordingUIState {
  const VineRecordingUIState({
    required this.recordingState,
    required this.progress,
    required this.totalRecordedDuration,
    required this.remainingDuration,
    required this.canRecord,
    required this.segments,
  });

  final VineRecordingState recordingState;
  final double progress;
  final Duration totalRecordedDuration;
  final Duration remainingDuration;
  final bool canRecord;
  final List<RecordingSegment> segments;

  // Convenience getters used by UI
  bool get isRecording => recordingState == VineRecordingState.recording;
  bool get isInitialized => recordingState != VineRecordingState.processing && recordingState != VineRecordingState.error;
  bool get isError => recordingState == VineRecordingState.error;
  bool get hasSegments => segments.isNotEmpty;
  Duration get recordingDuration => totalRecordedDuration;
  String? get errorMessage => isError ? 'Recording error occurred' : null;

  VineRecordingUIState copyWith({
    VineRecordingState? recordingState,
    double? progress,
    Duration? totalRecordedDuration,
    Duration? remainingDuration,
    bool? canRecord,
    List<RecordingSegment>? segments,
  }) {
    return VineRecordingUIState(
      recordingState: recordingState ?? this.recordingState,
      progress: progress ?? this.progress,
      totalRecordedDuration:
          totalRecordedDuration ?? this.totalRecordedDuration,
      remainingDuration: remainingDuration ?? this.remainingDuration,
      canRecord: canRecord ?? this.canRecord,
      segments: segments ?? this.segments,
    );
  }
}

/// StateNotifier that wraps VineRecordingController and provides reactive updates
class VineRecordingNotifier extends StateNotifier<VineRecordingUIState> {
  VineRecordingNotifier(this._controller, this._ref)
      : super(
          VineRecordingUIState(
            recordingState: _controller.state,
            progress: _controller.progress,
            totalRecordedDuration: _controller.totalRecordedDuration,
            remainingDuration: _controller.remainingDuration,
            canRecord: _controller.canRecord,
            segments: _controller.segments,
          ),
        ) {
    // Set up callback for recording progress updates
    _controller.setStateChangeCallback(updateState);
  }

  final VineRecordingController _controller;
  final Ref _ref;

  // Track whether video was successfully published to prevent auto-save
  bool _wasPublished = false;

  /// Get the camera preview widget from the controller
  Widget get previewWidget => _controller.previewWidget;

  /// Update the state based on the current controller state
  void updateState() {
    state = VineRecordingUIState(
      recordingState: _controller.state,
      progress: _controller.progress,
      totalRecordedDuration: _controller.totalRecordedDuration,
      remainingDuration: _controller.remainingDuration,
      canRecord: _controller.canRecord,
      segments: _controller.segments,
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

  Future<(File?, ProofManifest?)> stopRecording() async {
    await _controller.stopRecording();
    final result = await _controller.finishRecording();
    updateState();
    return result;
  }

  Future<(File?, ProofManifest?)> finishRecording() async {
    final result = await _controller.finishRecording();
    updateState();
    return result;
  }

  Future<void> switchCamera() async {
    await _controller.switchCamera();
    updateState();
  }

  void reset() {
    _controller.reset();
    _wasPublished = false; // Reset publish flag for new recording
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
    });

    super.dispose();
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
}

/// Provider for VineRecordingController with reactive state management
final vineRecordingProvider =
    StateNotifierProvider<VineRecordingNotifier, VineRecordingUIState>((ref) {
  // Initialize ProofMode services
  final keyService = ProofModeKeyService();
  final attestationService = ProofModeAttestationService();
  final proofModeSession = ProofModeSessionService(keyService, attestationService);

  final controller = VineRecordingController(proofModeSession: proofModeSession);
  final notifier = VineRecordingNotifier(controller, ref);

  ref.onDispose(() {
    notifier.dispose();
  });

  return notifier;
});
