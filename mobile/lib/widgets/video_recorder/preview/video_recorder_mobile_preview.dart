import 'package:divine_camera/divine_camera.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/config/screenshot_mode.dart';
import 'package:openvine/l10n/l10n.dart';

/// Camera preview widget for mobile platforms with touch gestures.
class VideoRecorderMobilePreview extends StatelessWidget {
  const VideoRecorderMobilePreview({required this.enableTapToFocus, super.key});

  final bool enableTapToFocus;

  @override
  Widget build(BuildContext context) {
    // Simulators have no camera hardware, so the App Store screenshot
    // pipeline (debug-only builds) substitutes a bundled frame for the
    // live viewfinder. Compile-time false outside SCREENSHOT_MODE builds.
    if (ScreenshotMode.enabled) {
      return const _ScreenshotViewfinderStandIn();
    }

    final bloc = context.read<VideoRecorderBloc>();

    final preview = CameraPreviewWidget(
      onScaleStart: (details) => bloc.add(VideoRecorderScaleStarted(details)),
      onScaleUpdate: (details) => bloc.add(VideoRecorderScaleUpdated(details)),
      onScaleEnd: (details) => bloc.add(const VideoRecorderScaleEnded()),
      onTap: enableTapToFocus
          ? (localPosition, normalizedPosition) {
              // setFocusPoint already combines AF + AE metering.
              // No need to call setExposurePoint separately.
              bloc.add(VideoRecorderFocusPointSet(normalizedPosition));
            }
          : null,
      loadingWidget: Container(color: const Color(0xFF141414)),
    );

    if (!enableTapToFocus) {
      return ExcludeSemantics(child: preview);
    }

    return Semantics(
      label: context.l10n.videoRecorderCameraPreviewLabel,
      button: true,
      onTapHint: context.l10n.videoRecorderCameraPreviewFocusHint,
      onTap: () => bloc.add(const VideoRecorderFocusPointSet(Offset(0.5, 0.5))),
      excludeSemantics: true,
      child: preview,
    );
  }
}

/// Full-bleed bundled frame shown in place of the live camera preview
/// during screenshot capture runs on the simulator.
class _ScreenshotViewfinderStandIn extends StatelessWidget {
  const _ScreenshotViewfinderStandIn();

  @override
  Widget build(BuildContext context) {
    return const SizedBox.expand(
      child: Image(
        image: AssetImage(ScreenshotMode.viewfinderFixture),
        fit: BoxFit.cover,
      ),
    );
  }
}
