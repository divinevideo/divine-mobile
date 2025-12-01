// ABOUTME: Pure universal camera screen using revolutionary Riverpod architecture
// ABOUTME: Cross-platform recording without VideoManager dependencies using pure providers

import 'dart:convert';
import 'dart:io';
import 'package:camera/camera.dart' show FlashMode;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/aspect_ratio.dart' as vine;
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/providers/vine_recording_provider.dart';
import 'package:openvine/models/native_proof_data.dart';
import 'package:openvine/screens/vine_drafts_screen.dart';
import 'package:openvine/services/camera/enhanced_mobile_camera_interface.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/utils/video_controller_cleanup.dart';
import 'package:openvine/screens/pure/video_metadata_screen_pure.dart';
import 'package:openvine/services/camera/native_macos_camera.dart';
import 'package:openvine/services/native_proofmode_service.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/macos_camera_preview.dart'
    show CameraPreviewPlaceholder;
import 'package:openvine/widgets/camera_controls_overlay.dart';
import 'package:openvine/widgets/dynamic_zoom_selector.dart';
import 'package:openvine/services/camera/camerawesome_mobile_camera_interface.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Pure universal camera screen using revolutionary single-controller Riverpod architecture
class UniversalCameraScreenPure extends ConsumerStatefulWidget {
  const UniversalCameraScreenPure({super.key});

  @override
  ConsumerState<UniversalCameraScreenPure> createState() =>
      _UniversalCameraScreenPureState();
}

class _UniversalCameraScreenPureState
    extends ConsumerState<UniversalCameraScreenPure>
    with WidgetsBindingObserver {
  String? _errorMessage;
  bool _isProcessing = false;
  bool _permissionDenied = false;

  // Camera control states
  FlashMode _flashMode = FlashMode.off;
  TimerDuration _timerDuration = TimerDuration.off;
  int? _countdownValue;

  // Track current device orientation for debugging
  DeviceOrientation? _currentOrientation;

  @override
  void initState() {
    super.initState();

    // Add app lifecycle observer to detect when user returns from Settings
    WidgetsBinding.instance.addObserver(this);

    // Log initial orientation
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final orientation = MediaQuery.of(context).orientation;
      _currentOrientation = orientation == Orientation.portrait
          ? DeviceOrientation.portraitUp
          : DeviceOrientation.landscapeLeft;
      Log.info(
        '📱 [ORIENTATION] Camera screen initial orientation: $_currentOrientation, MediaQuery: $orientation',
        category: LogCategory.video,
      );
    });

    _initializeServices();

    // CRITICAL: Dispose all video controllers when entering camera screen
    // IndexedStack keeps widgets alive, so we must force-dispose controllers
    WidgetsBinding.instance.addPostFrameCallback((_) {
      try {
        // Force dispose all video controllers (this also clears active video)
        disposeAllVideoControllers(ref);
        Log.info(
          '🗑️ UniversalCameraScreenPure: Disposed all video controllers',
          category: LogCategory.video,
        );
      } catch (e) {
        Log.warning(
          '📹 Failed to dispose video controllers: $e',
          category: LogCategory.video,
        );
      }
    });

    Log.info(
      '📹 UniversalCameraScreenPure: Initialized',
      category: LogCategory.video,
    );
  }

  @override
  void dispose() {
    // Remove app lifecycle observer
    WidgetsBinding.instance.removeObserver(this);

    // Provider handles disposal automatically
    super.dispose();

    Log.info(
      '📹 UniversalCameraScreenPure: Disposed',
      category: LogCategory.video,
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    // When app resumes, re-check permissions in case user granted them in Settings
    if (state == AppLifecycleState.resumed && _permissionDenied) {
      Log.info(
        '📹 App resumed, re-checking permissions',
        category: LogCategory.video,
      );
      _recheckPermissions();
    }
  }

  /// Re-check permissions after returning from Settings
  Future<void> _recheckPermissions() async {
    try {
      if (Platform.isMacOS) {
        final hasPermission = await NativeMacOSCamera.hasPermission();
        if (hasPermission && mounted) {
          Log.info(
            '📹 macOS permission now granted, initializing camera',
            category: LogCategory.video,
          );
          setState(() {
            _permissionDenied = false;
          });
          await _initializeServices();
        }
      } else if (Platform.isIOS || Platform.isAndroid) {
        // iOS permission_handler has a known caching bug - status doesn't update after granting in Settings
        // Even calling .request() again returns the stale cached status
        // SOLUTION: Attempt camera initialization directly, bypassing permission_handler
        // The actual AVCaptureDevice will fail if permissions aren't granted
        Log.info(
          '📹 Bypassing permission_handler cache, attempting camera initialization',
          category: LogCategory.video,
        );

        setState(() {
          _permissionDenied = false;
        });

        // Try to initialize - if permissions really aren't granted, this will fail
        // and error handling will show permission screen again
        try {
          await ref.read(vineRecordingProvider.notifier).initialize();
          Log.info(
            '📹 Camera initialized successfully - permissions were granted',
            category: LogCategory.video,
          );
        } catch (e) {
          Log.error(
            '📹 Camera initialization failed: $e',
            category: LogCategory.video,
          );
          if (mounted) {
            // Check if it's a permission error
            final errorStr = e.toString().toLowerCase();
            if (errorStr.contains('permission') ||
                errorStr.contains('denied') ||
                errorStr.contains('authorized')) {
              Log.warning(
                '📹 Still no camera permissions - showing permission screen',
                category: LogCategory.video,
              );
              setState(() {
                _permissionDenied = true;
              });
            } else {
              // Some other error
              setState(() {
                _errorMessage = 'Failed to initialize camera: $e';
              });
            }
          }
        }
      }
    } catch (e) {
      Log.error(
        '📹 Failed to recheck permissions: $e',
        category: LogCategory.video,
      );
    }
  }

  Future<void> _initializeServices() async {
    // Use Future.microtask to safely initialize after build completes
    // This ensures provider reads happen outside the build phase while still completing promptly
    Future.microtask(() => _performAsyncInitialization());
  }

  /// Perform async initialization after the first frame
  Future<void> _performAsyncInitialization() async {
    try {
      // Clean up any old temp files and reset state from previous recordings
      ref.read(vineRecordingProvider.notifier).cleanupAndReset();

      // Check platform and request permissions if needed
      if (Platform.isMacOS) {
        // macOS uses native platform channel
        Log.info(
          '📹 Checking macOS camera permission status',
          category: LogCategory.video,
        );

        final hasPermission = await NativeMacOSCamera.hasPermission();
        Log.info(
          '📹 macOS camera permission status: $hasPermission',
          category: LogCategory.video,
        );

        if (!hasPermission) {
          Log.info(
            '📹 Requesting macOS camera permission from user',
            category: LogCategory.video,
          );
          final granted = await NativeMacOSCamera.requestPermission();
          Log.info(
            '📹 macOS camera permission request result: $granted',
            category: LogCategory.video,
          );

          if (!granted) {
            Log.warning(
              '📹 macOS camera permission denied by user',
              category: LogCategory.video,
            );
            if (mounted) {
              setState(() {
                _permissionDenied = true;
              });
            }
            return;
          }

          Log.info(
            '📹 macOS camera permission granted, proceeding with initialization',
            category: LogCategory.video,
          );
        } else {
          Log.info(
            '📹 macOS camera permission already granted, proceeding with initialization',
            category: LogCategory.video,
          );
        }
      } else if (Platform.isIOS || Platform.isAndroid) {
        // iOS: permission_handler has caching issues - bypass it entirely
        // Try to initialize camera directly, let native AVFoundation check permissions
        Log.info(
          '📹 Bypassing permission_handler, attempting camera initialization directly',
          category: LogCategory.video,
        );

        try {
          // Initialize the recording service - will fail if permissions not granted
          await ref.read(vineRecordingProvider.notifier).initialize();
          Log.info(
            '📹 Recording service initialized successfully',
            category: LogCategory.video,
          );
          return; // Success - exit early
        } catch (e) {
          final errorStr = e.toString().toLowerCase();

          // Check if it's a permission error
          if (errorStr.contains('permission') ||
              errorStr.contains('denied') ||
              errorStr.contains('authorized')) {
            Log.info(
              '📹 Camera initialization failed due to permissions, requesting permissions',
              category: LogCategory.video,
            );

            // Request permissions
            final Map<Permission, PermissionStatus> statuses = await [
              Permission.camera,
              Permission.microphone,
            ].request();

            final cameraGranted =
                statuses[Permission.camera]?.isGranted ?? false;
            final microphoneGranted =
                statuses[Permission.microphone]?.isGranted ?? false;

            Log.info(
              '📹 Permission request results - Camera: $cameraGranted, Microphone: $microphoneGranted',
              category: LogCategory.video,
            );

            if (!cameraGranted || !microphoneGranted) {
              Log.warning(
                '📹 Permissions denied by user',
                category: LogCategory.video,
              );
              if (mounted) {
                setState(() {
                  _permissionDenied = true;
                });
              }
              return;
            }

            // Try initializing again after granting permissions
            try {
              await ref.read(vineRecordingProvider.notifier).initialize();
              Log.info(
                '📹 Recording service initialized after permission grant',
                category: LogCategory.video,
              );
              return;
            } catch (retryError) {
              Log.error(
                '📹 Failed to initialize even after granting permissions: $retryError',
                category: LogCategory.video,
              );
              if (mounted) {
                setState(() {
                  _errorMessage = 'Failed to initialize camera: $retryError';
                });
              }
              return;
            }
          } else {
            // Some other error
            Log.error(
              '📹 Camera initialization failed: $e',
              category: LogCategory.video,
            );
            if (mounted) {
              setState(() {
                _errorMessage = 'Failed to initialize camera: $e';
              });
            }
            return;
          }
        }
      }

      // macOS path continues here
      Log.info(
        '📹 Initializing recording service',
        category: LogCategory.video,
      );
      await ref.read(vineRecordingProvider.notifier).initialize();
      Log.info(
        '📹 Recording service initialized successfully',
        category: LogCategory.video,
      );
    } catch (e) {
      Log.error(
        '📹 UniversalCameraScreenPure: Failed to initialize recording: $e',
        category: LogCategory.video,
      );

      if (mounted) {
        // Check if it's a permission error
        final errorStr = e.toString();
        if (errorStr.contains('PERMISSION_DENIED') ||
            errorStr.contains('permission')) {
          setState(() {
            _permissionDenied = true;
          });
        } else {
          setState(() {
            _errorMessage = 'Failed to initialize camera: $e';
          });
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    // Debug: Track orientation changes
    final mediaQueryOrientation = MediaQuery.of(context).orientation;
    final newOrientation = mediaQueryOrientation == Orientation.portrait
        ? DeviceOrientation.portraitUp
        : DeviceOrientation.landscapeLeft;

    if (_currentOrientation != newOrientation) {
      _currentOrientation = newOrientation;
      Log.warning(
        '📱 [ORIENTATION] Device orientation changed! MediaQuery: $mediaQueryOrientation, DeviceOrientation: $newOrientation',
        category: LogCategory.video,
      );
      Log.warning(
        '📱 [ORIENTATION] MediaQuery size: ${MediaQuery.of(context).size}',
        category: LogCategory.video,
      );
    }

    if (_permissionDenied) {
      return _buildPermissionScreen();
    }

    if (_errorMessage != null) {
      return _buildErrorScreen();
    }

    return Scaffold(
      backgroundColor: Colors.black,
      body: Consumer(
        builder: (context, ref, child) {
          final recordingState = ref.watch(vineRecordingProvider);

          // Listen for auto-stop (when recording stops without user action)
          ref.listen<VineRecordingUIState>(vineRecordingProvider, (
            previous,
            next,
          ) {
            if (previous != null &&
                previous.isRecording &&
                !next.isRecording &&
                !_isProcessing) {
              // Recording stopped - check if it was max duration, manual stop, or error
              if (next.hasSegments) {
                // Check if this was an auto-stop due to max duration (remaining time ~0ms)
                // vs. manual segment stop (remaining time > 50ms)
                // With 6.3s max duration, timer should stop at exactly 0ms remaining
                if (next.remainingDuration.inMilliseconds < 50) {
                  // Has segments + virtually no remaining time = legitimate max duration auto-stop
                  Log.info(
                    '📹 Recording auto-stopped at max duration',
                    category: LogCategory.video,
                  );
                  _handleRecordingAutoStop();
                } else {
                  // Has segments + time remaining = manual segment stop (user released button)
                  Log.debug(
                    '📹 Manual segment stop (${next.remainingDuration.inMilliseconds}ms remaining)',
                    category: LogCategory.video,
                  );
                  // Don't show "max time reached" message for manual stops
                }
              } else {
                // No segments = recording failure
                Log.warning(
                  '📹 Recording stopped due to error (no segments)',
                  category: LogCategory.video,
                );
                _handleRecordingFailure();
              }
            }
          });

          if (recordingState.isError) {
            return _buildErrorScreen(recordingState.errorMessage);
          }

          // Show processing overlay if processing (even if camera not initialized)
          if (_isProcessing) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: VineTheme.vineGreen),
                  SizedBox(height: 16),
                  Text(
                    'Processing video...',
                    style: TextStyle(color: Colors.white, fontSize: 16),
                  ),
                ],
              ),
            );
          }

          if (!recordingState.isInitialized) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(color: VineTheme.vineGreen),
                  SizedBox(height: 16),
                  Text(
                    'Initializing camera...',
                    style: TextStyle(color: Colors.white),
                  ),
                ],
              ),
            );
          }

          return Stack(
            fit: StackFit.expand,
            children: [
              // Camera preview - EXACTLY matching experimental app structure
              if (recordingState.isInitialized)
                ref.read(vineRecordingProvider.notifier).previewWidget
              else
                CameraPreviewPlaceholder(
                  isRecording: recordingState.isRecording,
                ),

              // Tap-anywhere-to-record gesture detector (MUST be before top bar so bar receives taps)
              Positioned.fill(
                child: GestureDetector(
                  onTapDown: !kIsWeb && recordingState.canRecord
                      ? (_) => _startRecording()
                      : null,
                  onTapUp: !kIsWeb && recordingState.isRecording
                      ? (_) => _stopRecording()
                      : null,
                  onTapCancel: !kIsWeb && recordingState.isRecording
                      ? () => _stopRecording()
                      : null,
                  behavior: HitTestBehavior.translucent,
                  child: const SizedBox.expand(),
                ),
              ),

              // Top progress bar - Vine-style full width at top (AFTER gesture detector so buttons work)
              Positioned(
                top: MediaQuery.of(context).padding.top,
                left: 0,
                right: 0,
                child: _buildTopProgressBar(recordingState),
              ),

              // Square crop mask overlay (only shown in square mode)
              // Positioned OUTSIDE ClipRect so it's not clipped away
              if (recordingState.aspectRatio == vine.AspectRatio.square && recordingState.isInitialized)
                LayoutBuilder(
                  builder: (context, constraints) {
                    Log.info('🎭 Building square crop mask overlay',
                        name: 'UniversalCameraScreenPure', category: LogCategory.video);

                    // Use screen dimensions, not camera preview dimensions
                    final screenWidth = constraints.maxWidth;
                    final screenHeight = constraints.maxHeight;
                    final squareSize = screenWidth; // Square uses full screen width

                    Log.info('🎭 Mask dimensions: screenWidth=$screenWidth, screenHeight=$screenHeight, squareSize=$squareSize',
                        name: 'UniversalCameraScreenPure', category: LogCategory.video);

                    return _buildSquareCropMaskForPreview(
                      screenWidth,
                      screenHeight,
                    );
                  },
                ),

              // Dynamic zoom selector (above recording controls)
              if (recordingState.isInitialized && !recordingState.isRecording)
                Positioned(
                  bottom: 180,
                  left: 0,
                  right: 0,
                  child: _buildZoomSelector(),
                ),

              // Recording controls overlay (bottom)
              Positioned(
                bottom: 0,
                left: 0,
                right: 0,
                child: Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.topCenter,
                      end: Alignment.bottomCenter,
                      colors: [
                        Colors.transparent,
                        Colors.black.withValues(alpha: 0.7),
                      ],
                    ),
                  ),
                  child: _buildRecordingControls(recordingState),
                ),
              ),

              // Camera controls (right side, vertically centered)
              if (recordingState.isInitialized && !recordingState.isRecording)
                Positioned(
                  top: 0,
                  bottom: 180, // Above the bottom recording controls
                  right: 16,
                  child: Center(
                    child: _buildCameraControls(recordingState),
                  ),
                ),

              // Countdown overlay
              if (_countdownValue != null)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.5),
                    child: Center(
                      child: Text(
                        _countdownValue.toString(),
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 72,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ),

              // Processing overlay
              if (_isProcessing)
                Positioned.fill(
                  child: Container(
                    color: Colors.black.withValues(alpha: 0.7),
                    child: const Center(
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          CircularProgressIndicator(color: VineTheme.vineGreen),
                          SizedBox(height: 16),
                          Text(
                            'Processing video...',
                            style: TextStyle(color: Colors.white, fontSize: 16),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  Widget _buildPermissionScreen() {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: VineTheme.vineGreen,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Camera Permission',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.videocam_off, size: 64, color: Colors.orange),
              const SizedBox(height: 16),
              const Text(
                'Camera Permission Required',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Divine needs access to your camera to record videos. Please grant camera permission in System Settings.',
                style: TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: _openSystemSettings,
                style: ElevatedButton.styleFrom(
                  backgroundColor: VineTheme.vineGreen,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                ),
                icon: const Icon(Icons.settings),
                label: const Text('Open System Settings'),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: _tryRequestPermission,
                child: const Text(
                  'Try Again',
                  style: TextStyle(color: Colors.white),
                ),
              ),
              const SizedBox(height: 12),
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text(
                  'Cancel',
                  style: TextStyle(color: Colors.grey),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildErrorScreen([String? customMessage]) {
    final message = customMessage ?? _errorMessage ?? 'Unknown error occurred';

    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: VineTheme.vineGreen,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: Colors.white),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: const Text(
          'Camera Error',
          style: TextStyle(color: Colors.white),
        ),
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.error_outline, size: 64, color: Colors.red),
              const SizedBox(height: 16),
              const Text(
                'Camera Error',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                message,
                style: const TextStyle(color: Colors.grey, fontSize: 14),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _retryInitialization,
                style: ElevatedButton.styleFrom(
                  backgroundColor: VineTheme.vineGreen,
                ),
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Vine-style top bar with X (close), progress bar, and > (publish) buttons
  Widget _buildTopProgressBar(VineRecordingUIState recordingState) {
    final progress = recordingState.progress;
    final hasSegments = recordingState.hasSegments;

    return Container(
      height: 44, // Taller to accommodate buttons
      color: VineTheme.vineGreen,
      child: Row(
        children: [
          // X button (close/cancel) on the left - pops back to previous screen
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              Log.info(
                '📹 X CANCEL - popping back',
                category: LogCategory.video,
              );
              // Camera is pushed via pushCamera(), so pop() returns to previous screen
              GoRouter.of(context).pop();
            },
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              child: const Icon(
                Icons.close,
                color: Colors.white,
                size: 28,
              ),
            ),
          ),
          // Progress bar in the middle (takes remaining space)
          Expanded(
            child: Container(
              height: 24,
              margin: const EdgeInsets.symmetric(horizontal: 8),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(4),
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: Align(
                  alignment: Alignment.centerLeft,
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 50),
                    width: double.infinity,
                    child: FractionallySizedBox(
                      alignment: Alignment.centerLeft,
                      widthFactor: progress.clamp(0.0, 1.0),
                      child: Container(
                        decoration: BoxDecoration(
                          color: Colors.white,
                          boxShadow: [
                            BoxShadow(
                              color: Colors.white.withValues(alpha: 0.5),
                              blurRadius: 4,
                              spreadRadius: 1,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          // > button (publish/proceed) on the right
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: hasSegments
                ? () {
                    Log.info(
                      '📹 > PUBLISH BUTTON PRESSED',
                      category: LogCategory.video,
                    );
                    _finishRecording();
                  }
                : null,
            child: Container(
              width: 44,
              height: 44,
              alignment: Alignment.center,
              child: Icon(
                Icons.chevron_right,
                color: hasSegments ? Colors.white : Colors.white.withValues(alpha: 0.3),
                size: 32,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRecordingControls(dynamic recordingState) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // ProofMode indicator - HIDDEN (now shown in Settings -> ProofMode Info)

        // Platform-specific instruction hint (reserve space to prevent layout shift)
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(
            (!recordingState.isRecording && !recordingState.hasSegments)
                ? (kIsWeb
                    ? 'Tap to record' // Web: single-shot
                    : 'Tap and hold anywhere to record') // Mobile: press-and-hold segments anywhere on screen
                : '', // Empty but reserves space
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.8),
              fontSize: 14,
            ),
          ),
        ),

        // Show segment count on mobile (reserve space to prevent layout shift)
        if (!kIsWeb)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Text(
              recordingState.hasSegments
                  ? '${recordingState.segments.length} ${recordingState.segments.length == 1 ? "segment" : "segments"}'
                  : '', // Empty but reserves space
              style: TextStyle(
                color: VineTheme.vineGreen.withValues(alpha: 0.9),
                fontSize: 14,
                fontWeight: FontWeight.bold,
              ),
            ),
          ),

        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            // Record button - Platform-specific interaction
            // Web: Tap to start/stop (single continuous recording)
            // Mobile: Press-and-hold to record, release to pause (segmented)
            GestureDetector(
              onTap: kIsWeb ? _toggleRecordingWeb : null,
              onTapDown: !kIsWeb && recordingState.canRecord
                  ? (_) => _startRecording()
                  : null,
              onTapUp: !kIsWeb && recordingState.isRecording
                  ? (_) => _stopRecording()
                  : null,
              onTapCancel: !kIsWeb && recordingState.isRecording
                  ? () => _stopRecording()
                  : null,
              child: Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: recordingState.isRecording ? Colors.red : Colors.white,
                  border: Border.all(
                    color: recordingState.isRecording
                        ? Colors.white
                        : Colors.grey,
                    width: 4,
                  ),
                ),
                child: recordingState.isRecording
                    ? Center(
                        child: Text(
                          _formatDuration(recordingState.recordingDuration),
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.fiber_manual_record,
                        color: Colors.red,
                        size: 32,
                      ),
              ),
            ),

            // Camera switch button moved to right side controls
            // Placeholder to balance the row layout
            const SizedBox(width: 48),
          ],
        ),
      ],
    );
  }

  Widget _buildCameraControls(VineRecordingUIState recordingState) {
    final cameraInterface = ref.read(vineRecordingProvider.notifier).cameraInterface;
    // Check if front camera is active for either camera interface type
    final isFrontCamera = (cameraInterface is EnhancedMobileCameraInterface && cameraInterface.isFrontCamera) ||
        (cameraInterface is CamerAwesomeMobileCameraInterface && cameraInterface.isFrontCamera);

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Camera switch button (front/back)
        if (recordingState.canSwitchCamera) ...[
          _buildControlButton(
            icon: Icons.flip_camera_ios,
            onTap: _switchCamera,
          ),
          const SizedBox(height: 12),
        ],
        // Flash toggle (only show for rear camera - front cameras don't have flash)
        if (!isFrontCamera) ...[
          _buildControlButton(
            icon: _getFlashIcon(),
            onTap: _toggleFlash,
          ),
          const SizedBox(height: 12),
        ],
        // Timer toggle
        _buildControlButton(
          icon: _getTimerIcon(),
          onTap: _toggleTimer,
        ),
        const SizedBox(height: 12),
        // Aspect ratio toggle
        _buildAspectRatioToggle(recordingState),
      ],
    );
  }

  Widget _buildControlButton({
    required IconData icon,
    required VoidCallback onTap,
  }) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
      child: IconButton(
        onPressed: onTap,
        icon: Icon(icon, color: Colors.white, size: 26),
      ),
    );
  }

  Widget _buildAspectRatioToggle(VineRecordingUIState recordingState) {
    return Container(
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(8),
      ),
      child: IconButton(
        icon: Icon(
          recordingState.aspectRatio == vine.AspectRatio.square
              ? Icons
                    .crop_square // Square icon for 1:1
              : Icons.crop_portrait, // Portrait icon for 9:16
          color: Colors.white,
          size: 28,
        ),
        onPressed: recordingState.isRecording
            ? null
            : () {
                final currentRatio = recordingState.aspectRatio;
                final newRatio =
                    recordingState.aspectRatio == vine.AspectRatio.square
                    ? vine.AspectRatio.vertical
                    : vine.AspectRatio.square;
                Log.info('🎭 Aspect ratio button pressed: $currentRatio -> $newRatio',
                    name: 'UniversalCameraScreenPure', category: LogCategory.video);
                ref
                    .read(vineRecordingProvider.notifier)
                    .setAspectRatio(newRatio);
              },
      ),
    );
  }

  /// Build dynamic zoom selector if using CamerAwesome
  Widget _buildZoomSelector() {
    final cameraInterface = ref.read(vineRecordingProvider.notifier).getCameraInterface();

    // Only show zoom selector for CamerAwesome interface (iOS)
    if (cameraInterface is CamerAwesomeMobileCameraInterface) {
      return DynamicZoomSelector(
        cameraInterface: cameraInterface,
      );
    }

    // No zoom selector for other camera interfaces
    return const SizedBox.shrink();
  }

  /// Build square crop mask overlay centered on screen
  /// Shows semi-transparent overlay outside the 1:1 square
  Widget _buildSquareCropMaskForPreview(double screenWidth, double screenHeight) {
    // Square uses full screen width
    final squareSize = screenWidth;

    // Calculate top/bottom areas to darken (centered vertically on screen)
    final topBottomHeight = (screenHeight - squareSize) / 2;

    return Stack(
      children: [
        // Top darkened area
        if (topBottomHeight > 0)
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: topBottomHeight,
            child: Container(
              color: Colors.black.withValues(alpha: 0.6),
            ),
          ),

        // Bottom darkened area
        if (topBottomHeight > 0)
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            height: topBottomHeight,
            child: Container(
              color: Colors.black.withValues(alpha: 0.6),
            ),
          ),

        // Square frame outline (visual guide)
        Positioned(
          top: topBottomHeight > 0 ? topBottomHeight : 0,
          left: 0,
          width: squareSize,
          height: squareSize,
          child: Container(
            decoration: BoxDecoration(
              border: Border.all(
                color: VineTheme.vineGreen,
                width: 3,
              ),
            ),
          ),
        ),
      ],
    );
  }

  IconData _getFlashIcon() {
    switch (_flashMode) {
      case FlashMode.off:
        return Icons.flash_off;
      case FlashMode.torch:
        return Icons.flashlight_on;
      case FlashMode.auto:
      case FlashMode.always:
        return Icons.flash_on;
    }
  }

  IconData _getTimerIcon() {
    switch (_timerDuration) {
      case TimerDuration.off:
        return Icons.timer;
      case TimerDuration.threeSeconds:
        return Icons.timer_3;
      case TimerDuration.tenSeconds:
        return Icons.timer_10;
    }
  }

  /// Web-specific: Toggle recording on/off with tap
  Future<void> _toggleRecordingWeb() async {
    final state = ref.read(vineRecordingProvider);

    if (state.isRecording) {
      // Stop recording
      _finishRecording();
    } else if (state.canRecord) {
      // Start recording
      _startRecording();
    }
  }

  Future<void> _startRecording() async {
    try {
      // Handle timer countdown if enabled
      if (_timerDuration != TimerDuration.off) {
        await _startCountdownTimer();
      }

      final notifier = ref.read(vineRecordingProvider.notifier);
      Log.info('📹 Starting recording segment', category: LogCategory.video);
      await notifier.startRecording();
    } catch (e) {
      Log.error(
        '📹 UniversalCameraScreenPure: Start recording failed: $e',
        category: LogCategory.video,
      );

      _showErrorSnackBar('Recording failed: $e');
    }
  }

  Future<void> _startCountdownTimer() async {
    final duration = _timerDuration == TimerDuration.threeSeconds ? 3 : 10;

    for (int i = duration; i > 0; i--) {
      if (!mounted) return;

      setState(() {
        _countdownValue = i;
      });

      await Future.delayed(const Duration(seconds: 1));
    }

    if (mounted) {
      setState(() {
        _countdownValue = null;
      });
    }
  }

  void _stopRecording() async {
    // Just stop the current segment - don't finish the recording
    // This allows the user to record multiple segments before finalizing
    try {
      final notifier = ref.read(vineRecordingProvider.notifier);
      Log.info('📹 Stopping recording segment (not finishing)', category: LogCategory.video);
      await notifier.stopSegment();

      Log.info(
        '📹 Segment stopped, user can record more or tap Publish to finish',
        category: LogCategory.video,
      );

      // Reset processing state - we're NOT processing yet, just paused between segments
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }
    } catch (e) {
      Log.error(
        '📹 UniversalCameraScreenPure: Stop segment failed: $e',
        category: LogCategory.video,
      );

      _showErrorSnackBar('Stop recording failed: $e');
    }
  }

  void _finishRecording() async {
    // Set processing state immediately so UI shows "Processing video..."
    // during the entire FFmpeg processing time
    if (_isProcessing) {
      Log.warning(
        '📹 Already processing a recording, ignoring duplicate finish call',
        category: LogCategory.video,
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final notifier = ref.read(vineRecordingProvider.notifier);
      Log.info(
        '📹 Finishing recording and concatenating segments',
        category: LogCategory.video,
      );

      final (videoFile, proofManifest) = await notifier.finishRecording();
      Log.info(
        '📹 Recording finished, video: ${videoFile?.path}, proof: ${proofManifest != null}',
        category: LogCategory.video,
      );

      if (videoFile != null && mounted) {
        _processRecording(videoFile, proofManifest);
      } else {
        Log.warning(
          '📹 No file returned from finishRecording',
          category: LogCategory.video,
        );
        // Reset processing state since nothing to process
        if (mounted) {
          setState(() {
            _isProcessing = false;
          });
        }
      }
    } catch (e) {
      Log.error(
        '📹 UniversalCameraScreenPure: Finish recording failed: $e',
        category: LogCategory.video,
      );

      // Reset processing state on error
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
      }

      _showErrorSnackBar('Finish recording failed: $e');
    }
  }

  void _switchCamera() async {
    Log.info('🔄 _switchCamera() UI button pressed',
        name: 'UniversalCameraScreenPure', category: LogCategory.system);

    try {
      Log.info('🔄 Calling vineRecordingProvider.notifier.switchCamera()...',
          name: 'UniversalCameraScreenPure', category: LogCategory.system);
      await ref.read(vineRecordingProvider.notifier).switchCamera();
      Log.info('🔄 vineRecordingProvider.notifier.switchCamera() completed',
          name: 'UniversalCameraScreenPure', category: LogCategory.system);

      // Force rebuild by calling setState
      Log.info('🔄 Calling setState() to force UI rebuild',
          name: 'UniversalCameraScreenPure', category: LogCategory.system);
      setState(() {});
      Log.info('🔄 setState() completed',
          name: 'UniversalCameraScreenPure', category: LogCategory.system);
    } catch (e) {
      Log.error(
        '📹 UniversalCameraScreenPure: Camera switch failed: $e',
        category: LogCategory.video,
      );
    }
  }

  void _toggleFlash() {
    Log.info('🔦 Flash button tapped', category: LogCategory.video);

    final cameraInterface = ref.read(vineRecordingProvider.notifier).cameraInterface;

    // Update local state to cycle through: off → torch (for video recording)
    // For video, we use torch mode (continuous light) instead of flash
    setState(() {
      switch (_flashMode) {
        case FlashMode.off:
          _flashMode = FlashMode.torch;
          break;
        case FlashMode.torch:
        case FlashMode.auto:
        case FlashMode.always:
          _flashMode = FlashMode.off;
          break;
      }
    });

    Log.info('🔦 Flash mode toggled to: $_flashMode', category: LogCategory.video);

    // Apply the new flash mode to camera - support both camera interfaces
    if (cameraInterface is EnhancedMobileCameraInterface) {
      cameraInterface.setFlashMode(_flashMode);
    } else if (cameraInterface is CamerAwesomeMobileCameraInterface) {
      cameraInterface.setFlashMode(_flashMode);
    } else {
      Log.warning('🔦 Camera interface does not support flash control', category: LogCategory.video);
    }
  }

  void _handleRecordingAutoStop() async {
    try {
      // Auto-stop just pauses the current segment
      // User must press publish button to finish and concatenate
      Log.info(
        '📹 Recording auto-stopped (max duration reached)',
        category: LogCategory.video,
      );

      _showSuccessSnackBar('Maximum recording time reached. Press ✓ to publish.');
    } catch (e) {
      Log.error(
        '📹 Failed to handle auto-stop: $e',
        category: LogCategory.video,
      );
    }
  }

  void _handleRecordingFailure() {
    if (!mounted) return;

    _showErrorSnackBar('Camera recording failed. Please try again.');
  }

  void _toggleTimer() {
    setState(() {
      switch (_timerDuration) {
        case TimerDuration.off:
          _timerDuration = TimerDuration.threeSeconds;
          break;
        case TimerDuration.threeSeconds:
          _timerDuration = TimerDuration.tenSeconds;
          break;
        case TimerDuration.tenSeconds:
          _timerDuration = TimerDuration.off;
          break;
      }
    });
    Log.info(
      '📹 Timer duration changed to: $_timerDuration',
      category: LogCategory.video,
    );
  }

  void _processRecording(
    File recordedFile,
    NativeProofData? nativeProof,
  ) async {
    // Note: _isProcessing is set by _finishRecording() before this is called
    // to ensure the "Processing video..." UI shows during FFmpeg processing

    try {
      Log.info(
        '📹 UniversalCameraScreenPure: Processing recorded file: ${recordedFile.path}',
        category: LogCategory.video,
      );

      // Create a draft for the recorded video
      final prefs = await SharedPreferences.getInstance();
      final draftService = DraftStorageService(prefs);

      // Serialize NativeProofData to JSON if available
      String? proofManifestJson;
      if (nativeProof != null) {
        try {
          proofManifestJson = jsonEncode(nativeProof.toJson());
          Log.info(
            '📜 Native ProofMode data attached to draft from universal camera',
            category: LogCategory.video,
          );
        } catch (e) {
          Log.error(
            'Failed to serialize NativeProofData for draft: $e',
            category: LogCategory.video,
          );
        }
      }

      // Get current aspect ratio from recording state
      final recordingState = ref.read(vineRecordingProvider);

      final draft = VineDraft.create(
        videoFile: recordedFile,
        title: '',
        description: '',
        hashtags: [],
        frameCount: 0,
        selectedApproach: 'video',
        proofManifestJson: proofManifestJson,
        aspectRatio: recordingState.aspectRatio,
      );

      await draftService.saveDraft(draft);

      Log.info(
        '📹 Created draft with ID: ${draft.id}',
        category: LogCategory.video,
      );

      if (mounted) {
        // Navigate to metadata screen
        await Navigator.of(context).push(
          MaterialPageRoute(
            builder: (context) => VideoMetadataScreenPure(draftId: draft.id),
          ),
        );

        // After metadata screen returns, navigate to profile
        if (mounted) {
          Log.info(
            '📹 Returned from metadata screen, navigating to profile',
            category: LogCategory.video,
          );

          // CRITICAL: Dispose all controllers again before navigation
          // This ensures no stale controllers exist when switching to profile tab
          disposeAllVideoControllers(ref);
          Log.info(
            '🗑️ Disposed controllers before profile navigation',
            category: LogCategory.video,
          );

          // Navigate to user's own profile using GoRouter
          context.go('/profile/me/0');
          Log.info(
            '📹 Successfully navigated to profile',
            category: LogCategory.video,
          );

          // Reset processing flag after navigation
          setState(() {
            _isProcessing = false;
          });
        }
      }
    } catch (e) {
      Log.error(
        '📹 UniversalCameraScreenPure: Processing failed: $e',
        category: LogCategory.video,
      );

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });

        _showErrorSnackBar('Processing failed: $e');
      }
    }
  }

  void _retryInitialization() async {
    setState(() {
      _errorMessage = null;
      _permissionDenied = false;
    });

    await _initializeServices();
  }

  void _tryRequestPermission() async {
    try {
      Log.info('📹 Requesting camera permission', category: LogCategory.video);

      bool granted = false;

      // Platform-specific permission request
      if (Platform.isMacOS) {
        granted = await NativeMacOSCamera.requestPermission();
      } else if (Platform.isIOS || Platform.isAndroid) {
        // Check current status first
        final cameraStatus = await Permission.camera.status;
        final microphoneStatus = await Permission.microphone.status;

        // On iOS, if permission was previously denied, .request() won't show a dialog
        // We need to check for permanentlyDenied and direct user to Settings
        if (cameraStatus.isPermanentlyDenied ||
            microphoneStatus.isPermanentlyDenied) {
          Log.warning(
            '📹 Permissions permanently denied, opening Settings',
            category: LogCategory.video,
          );
          _openSystemSettings();
          return;
        }

        // Try to request permissions
        final Map<Permission, PermissionStatus> statuses = await [
          Permission.camera,
          Permission.microphone,
        ].request();

        final cameraGranted = statuses[Permission.camera]?.isGranted ?? false;
        final microphoneGranted =
            statuses[Permission.microphone]?.isGranted ?? false;

        granted = cameraGranted && microphoneGranted;

        Log.info(
          '📹 Permission request results - Camera: $cameraGranted, Microphone: $microphoneGranted',
          category: LogCategory.video,
        );

        // If still denied, it might be permanently denied now - guide to Settings
        if (!granted) {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Please grant camera and microphone permissions in Settings to record videos.',
                ),
                backgroundColor: Colors.orange,
                duration: Duration(seconds: 3),
              ),
            );
          }
          return;
        }
      }

      if (granted) {
        Log.info(
          '📹 Permission granted, initializing camera',
          category: LogCategory.video,
        );
        setState(() {
          _permissionDenied = false;
        });
        await _initializeServices();
      }
    } catch (e) {
      Log.error(
        '📹 Failed to request permission: $e',
        category: LogCategory.video,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to request permission: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _openSystemSettings() async {
    try {
      // Use permission_handler's built-in method to open app settings
      // This works across all platforms (iOS, Android, macOS)
      final opened = await openAppSettings();

      if (!opened) {
        Log.warning('Failed to open app settings', category: LogCategory.video);
      } else {
        Log.info(
          'Opened app settings successfully',
          category: LogCategory.video,
        );
      }
    } catch (e) {
      Log.error(
        '📹 Failed to open system settings: $e',
        category: LogCategory.video,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Please open System Settings manually and grant camera permission to Divine.',
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 4),
          ),
        );
      }
    }
  }

  String _formatDuration(Duration duration) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    String twoDigitMinutes = twoDigits(duration.inMinutes.remainder(60));
    String twoDigitSeconds = twoDigits(duration.inSeconds.remainder(60));
    return '$twoDigitMinutes:$twoDigitSeconds';
  }

  /// Show error snackbar at top of screen to avoid blocking controls
  void _showErrorSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 150,
          left: 10,
          right: 10,
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Show success snackbar at top of screen
  void _showSuccessSnackBar(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: VineTheme.vineGreen,
        behavior: SnackBarBehavior.floating,
        margin: EdgeInsets.only(
          bottom: MediaQuery.of(context).size.height - 150,
          left: 10,
          right: 10,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }
}

/// Timer duration options for delayed recording
enum TimerDuration { off, threeSeconds, tenSeconds }
