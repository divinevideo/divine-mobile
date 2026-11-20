// ABOUTME: Camera preview widget with animated aspect ratio transitions and grid overlay
// ABOUTME: Handles tap-to-focus and displays rule-of-thirds grid during non-recording state

import 'dart:async';
import 'dart:ui' as ui;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/config/screenshot_mode.dart';
import 'package:openvine/l10n/camera_initialization_error_l10n.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/split_screen_layout.dart';
import 'package:openvine/ui/adaptive_layout.dart';
import 'package:openvine/utils/platform_helpers.dart';
import 'package:openvine/widgets/video_clip/clip_crop_guide.dart';
import 'package:openvine/widgets/video_editor/chroma_key/chroma_key_backdrop.dart';
import 'package:openvine/widgets/video_editor/chroma_key/chroma_key_tap_to_pick.dart';
import 'package:openvine/widgets/video_editor/chroma_key/chroma_keyed_video.dart';
import 'package:openvine/widgets/video_recorder/preview/video_recorder_dual_camera_window.dart';
import 'package:openvine/widgets/video_recorder/preview/video_recorder_mobile_preview.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_camera_placeholder.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_focus_point.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_ghost_frame.dart';

/// Displays the camera preview with animated aspect ratio changes.
///
/// Includes a grid overlay for composition guidance and tap-to-focus
/// functionality.
class VideoRecorderCameraPreview extends StatelessWidget {
  /// Creates a camera preview widget.
  const VideoRecorderCameraPreview({
    this.enableTapToFocus = true,
    this.borderRadius = .zero,
    this.onColorPatchPicked,
    super.key,
  });

  final BorderRadius borderRadius;
  final bool enableTapToFocus;

  /// When set, a tap on the picture reads the patch of raw camera pixels
  /// under the finger — below the color mask, so the wall's own color — and
  /// hands it over as straight RGBA, for the color mask screen.
  final ValueChanged<Uint8List>? onColorPatchPicked;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final aspectRatio = context.select(
          (VideoRecorderBloc b) => b.state.aspectRatio,
        );
        // In vertical mode a phone, and the folded iPhone Duo, uses the full
        // available screen size, even if it's not exactly 16:9. The desktop,
        // and with the large-screen layouts a large screen (the open iPhone
        // Duo, iPads), shows the 9:16 frame that is recorded instead of more
        // than lands in it.
        final availableAspectRatio = constraints.biggest.aspectRatio;
        final showsRecordedFrame =
            isDesktopPlatform ||
            (context.adaptiveLayout.isLargeScreen &&
                availableAspectRatio > 9 / 16);
        final aspectRatioValue = aspectRatio == .vertical
            ? showsRecordedFrame
                  ? 9 / 16
                  : availableAspectRatio
            : 1.0;

        return Center(
          child: TweenAnimationBuilder<double>(
            duration: const Duration(milliseconds: 220),
            curve: Curves.easeInOut,
            tween: Tween(begin: aspectRatioValue, end: aspectRatioValue),
            builder: (context, aspectRatio, _) {
              return AspectRatio(
                aspectRatio: aspectRatio,
                child: ClipRRect(
                  clipBehavior: .hardEdge,
                  borderRadius: borderRadius,
                  // The blur wraps the whole stack from above its camera-rebuild
                  // [ValueKey], so a switch's rebuild doesn't dispose the ramp.
                  child: _CameraSwitchBlur(
                    child: _StackItems(
                      enableTapToFocus: enableTapToFocus,
                      onColorPatchPicked: onColorPatchPicked,
                    ),
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }
}

class _StackItems extends StatelessWidget {
  const _StackItems({
    required this.enableTapToFocus,
    required this.onColorPatchPicked,
  });

  final bool enableTapToFocus;
  final ValueChanged<Uint8List>? onColorPatchPicked;

  @override
  Widget build(BuildContext context) {
    final state = context.select(
      (VideoRecorderBloc b) => (
        isCameraInitialized: b.state.isCameraInitialized,
        cameraRebuildCount: b.state.cameraRebuildCount,
        initializationError: b.state.initializationError,
        isDualCameraEnabled: b.state.isDualCameraEnabled,
      ),
    );
    return Stack(
      fit: .expand,
      key: ValueKey('Camera-Count-${state.cameraRebuildCount}'),
      children: [
        // Simulators never initialize the camera, so the screenshot pipeline
        // renders the stubbed preview instead of the black placeholder.
        if (state.isCameraInitialized || ScreenshotMode.enabled)
          _CameraPreview(
            enableTapToFocus: enableTapToFocus,
            onColorPatchPicked: onColorPatchPicked,
          )
        else
          VideoRecorderCameraPlaceholder(
            errorMessage: switch (state.initializationError) {
              null => null,
              final error => context.l10n.cameraInitializationErrorMessage(
                error,
              ),
            },
          ),
        const VideoRecorderGhostFrame(),
        if (ClipCropGuide.maybeOf(context) case final guide?)
          _CropGuide(aspectRatio: guide.aspectRatio, shape: guide.shape),
        const _OverlayGrid(),
        if (enableTapToFocus) const VideoRecorderFocusPoint(),
        if (state.isCameraInitialized && state.isDualCameraEnabled)
          const VideoRecorderDualCameraWindow(),
      ],
    );
  }
}

/// The part of the camera frame the take will be cropped to.
///
/// The recording is the whole sensor frame, which the preview covers its box
/// with — so the crop is cut from the sensor's shape, not the box's, and can
/// reach past a square preview on one side.
class _CropGuide extends StatelessWidget {
  const _CropGuide({required this.aspectRatio, required this.shape});

  final double aspectRatio;
  final SplitScreenCellShape shape;

  @override
  Widget build(BuildContext context) {
    final sensorAspectRatio = context.select(
      (VideoRecorderBloc b) => b.state.cameraSensorAspectRatio,
    );
    if (sensorAspectRatio <= 0) return const SizedBox.shrink();
    return ClipCropGuideOverlay(
      aspectRatio: aspectRatio,
      contentAspectRatio: sensorAspectRatio,
      shape: shape,
    );
  }
}

class _CameraPreview extends StatelessWidget {
  const _CameraPreview({
    required this.enableTapToFocus,
    required this.onColorPatchPicked,
  });

  final bool enableTapToFocus;
  final ValueChanged<Uint8List>? onColorPatchPicked;

  @override
  Widget build(BuildContext context) {
    // Simulators have no camera, so the sensor aspect ratio stays 0 and the
    // live preview collapses to nothing. The screenshot pipeline substitutes
    // a full-bleed bundled frame. Compile-time false outside screenshot
    // builds.
    if (ScreenshotMode.enabled) {
      return const VideoRecorderMobilePreview(enableTapToFocus: false);
    }

    final (:sensorAspectRatio, :textureId) = context.select(
      (VideoRecorderBloc b) => (
        sensorAspectRatio: b.state.cameraSensorAspectRatio,
        textureId: b.state.previewTextureId,
      ),
    );

    return FittedBox(
      fit: .cover,
      child: SizedBox(
        width: 1000 * sensorAspectRatio,
        height: 1000,
        child: Stack(
          children: [
            Container(color: const Color(0xFF141414)),

            /// Preview widget
            if (!kIsWeb && defaultTargetPlatform == TargetPlatform.linux)
              const SizedBox.shrink()
            else
              // Keyed on the texture id: a facing flip rebinds the incoming
              // camera onto a fresh texture, so a changed id remounts the
              // preview to pick up its frames. Neither this remount nor the
              // camera-rebuild remount of the enclosing Stack resets the switch
              // blur — it lives above [_StackItems], so its ramp-out plays over
              // the new frame.
              _ChromaKeyViewfinder(
                child: _TapToPickWhenAsked(
                  onPatchPicked: onColorPatchPicked,
                  child: VideoRecorderMobilePreview(
                    key: ValueKey(textureId),
                    enableTapToFocus: enableTapToFocus,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Wraps [child] in [ChromaKeyTapToPick] when [onPatchPicked] is set, and
/// passes it through otherwise.
class _TapToPickWhenAsked extends StatelessWidget {
  const _TapToPickWhenAsked({required this.onPatchPicked, required this.child});

  final ValueChanged<Uint8List>? onPatchPicked;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final onPatchPicked = this.onPatchPicked;
    if (onPatchPicked == null) return child;
    return ChromaKeyTapToPick(onPatchPicked: onPatchPicked, child: child);
  }
}

/// Keys the camera texture live while the color mask is on, and passes it
/// through untouched otherwise.
///
/// Preview only: the recorder still writes the raw camera frames. Sits inside
/// the sensor-shaped box the texture fills, so the backdrop is stretched over
/// exactly the frame the recording will contain — which is how the editor's
/// bake places it — and the viewfinder's crop then trims both alike.
class _ChromaKeyViewfinder extends StatefulWidget {
  const _ChromaKeyViewfinder({required this.child});

  final Widget child;

  @override
  State<_ChromaKeyViewfinder> createState() => _ChromaKeyViewfinderState();
}

class _ChromaKeyViewfinderState extends State<_ChromaKeyViewfinder> {
  final _recordingStarts = StreamController<void>.broadcast();
  StreamSubscription<VideoRecorderBlocState>? _stateSubscription;

  /// Restarts a video backdrop each time the camera starts writing a take.
  ///
  /// The bake plays the backdrop from its first frame under every clip, so
  /// starting it over then is what lets the user react to what is behind
  /// them at the moment it will really be there. Not at the tap: a countdown
  /// would run the backdrop seconds ahead of the take.
  late final _backdropSync = ChromaKeyBackdropSync(
    restarts: _recordingStarts.stream,
  );

  @override
  void initState() {
    super.initState();
    final bloc = context.read<VideoRecorderBloc>();
    var wasCapturing = bloc.state.isCapturingFootage;
    _stateSubscription = bloc.stream.listen((state) {
      if (state.isCapturingFootage && !wasCapturing) {
        _recordingStarts.add(null);
      }
      wasCapturing = state.isCapturingFootage;
    });
  }

  @override
  void dispose() {
    unawaited(_stateSubscription?.cancel());
    unawaited(_recordingStarts.close());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final (:chromaKey, :isFrontCamera) = context.select(
      (VideoRecorderBloc b) => (
        chromaKey: b.state.isChromaKeyActive ? b.state.chromaKey : null,
        isFrontCamera: b.state.isFrontCamera,
      ),
    );

    // A key with no backdrop is baked onto the renderer's black canvas, so the
    // viewfinder shows that black instead of a checkerboard.
    return ColoredBox(
      color: VineTheme.backgroundColor,
      child: ChromaKeyedVideo(
        chromaKey: chromaKey,
        backdropSync: _backdropSync,
        previewTransparency: false,
        // The selfie preview is shown mirrored while the recording is not.
        mirrorBackdrop: isFrontCamera,
        child: widget.child,
      ),
    );
  }
}

/// Softens a front/back lens switch: while the preview is frozen on its last
/// frame (see [VideoRecorderBlocState.isSwitchingCamera]) this ramps a gaussian
/// blur over it, then deblurs as the new lens's first frames arrive — the same
/// cue the native camera app uses to hide the hard cut and the new sensor's
/// initial unfocused frames.
///
/// Wraps the preview stack from above its camera-rebuild [ValueKey], so the
/// ramp survives the remount a switch triggers and deblurs over the new frame.
class _CameraSwitchBlur extends StatelessWidget {
  const _CameraSwitchBlur({required this.child});

  final Widget child;

  /// Peak gaussian sigma applied to the frozen frame mid-switch. Deliberately
  /// moderate — a full-screen blur pass over the camera texture is
  /// raster-thread work, and it only runs for the brief switch transition.
  static const double _peakBlurSigma = 16;

  /// Blur ramp duration each way. Kept short so the new lens is revealed
  /// quickly once the deblur starts.
  static const Duration _rampDuration = Duration(milliseconds: 50);

  /// Below this sigma the blur is visually a no-op; skip the filter layer so
  /// there is zero blur cost at rest and once the deblur completes.
  static const double _blurEpsilon = 0.1;

  @override
  Widget build(BuildContext context) {
    final isSwitching = context.select(
      (VideoRecorderBloc b) => b.state.isSwitchingCamera,
    );
    // Under reduced motion, snap the blur in/out instead of ramping it.
    final reduceMotion = MediaQuery.disableAnimationsOf(context);
    return TweenAnimationBuilder<double>(
      tween: Tween<double>(end: isSwitching ? _peakBlurSigma : 0),
      duration: reduceMotion ? Duration.zero : _rampDuration,
      curve: Curves.easeOut,
      child: child,
      builder: (context, sigma, child) {
        if (sigma < _blurEpsilon) return child!;
        return ClipRect(
          child: ImageFiltered(
            imageFilter: ui.ImageFilter.blur(sigmaX: sigma, sigmaY: sigma),
            child: child,
          ),
        );
      },
    );
  }
}

class _OverlayGrid extends StatelessWidget {
  const _OverlayGrid();

  @override
  Widget build(BuildContext context) {
    final (:isRecording, :showGridLines) = context.select(
      (VideoRecorderBloc b) => (
        isRecording: b.state.isRecording,
        showGridLines: b.state.showGridLines,
      ),
    );

    return IgnorePointer(
      child: AnimatedOpacity(
        opacity: (isRecording || !showGridLines) ? 0.0 : 1.0,
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeInOut,
        child: CustomPaint(painter: _GridPainter()),
      ),
    );
  }
}

/// Custom painter for grid overlay (rule of thirds)
class _GridPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = VineTheme.onSurfaceVariant
      ..strokeWidth = 1;

    // Vertical lines
    canvas
      ..drawLine(
        Offset(size.width / 3, 0),
        Offset(size.width / 3, size.height),
        paint,
      )
      ..drawLine(
        Offset(size.width * 2 / 3, 0),
        Offset(size.width * 2 / 3, size.height),
        paint,
      )
      // Horizontal lines
      ..drawLine(
        Offset(0, size.height / 3),
        Offset(size.width, size.height / 3),
        paint,
      )
      ..drawLine(
        Offset(0, size.height * 2 / 3),
        Offset(size.width, size.height * 2 / 3),
        paint,
      );
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
