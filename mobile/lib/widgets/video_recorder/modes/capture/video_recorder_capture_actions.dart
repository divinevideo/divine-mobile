import 'package:divine_camera/divine_camera.dart'
    show DivineVideoStabilizationMode;
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/constants/semantic_ids.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_recorder/video_recorder_flash_mode.dart';
import 'package:openvine/models/video_recorder/video_recorder_timer_duration.dart';
import 'package:openvine/providers/clip_manager_provider.dart';

class VideoRecorderCaptureActions extends ConsumerWidget {
  const VideoRecorderCaptureActions({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final l10n = context.l10n;
    final state = context.select(
      (VideoRecorderBloc b) => (
        flashMode: b.state.flashMode,
        timer: b.state.timerDuration,
        aspectRatio: b.state.aspectRatio,
        canSwitchCamera: b.state.canSwitchCamera,
        isFrontCamera: b.state.isFrontCamera,
        hasFlash: b.state.hasFlash,
        isRecording: b.state.isRecording,
        showGridLines: b.state.showGridLines,
        supportsTimer: b.state.recorderMode.supportsCountdownTimer,
        capturesStills: b.state.recorderMode.capturesStills,
        supportsStabilization: b.state.recorderMode.supportsVideoStabilization,
      ),
    );
    final hasClips = ref.watch(clipManagerProvider.select((p) => p.hasClips));

    return SafeArea(
      top: false,
      left: false,
      bottom: false,
      child: IgnorePointer(
        ignoring: state.isRecording,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: state.isRecording ? 0 : 1,
          child: Container(
            margin: const .symmetric(horizontal: 16),
            padding: const .symmetric(vertical: 12, horizontal: 4),
            decoration: ShapeDecoration(
              color: VineTheme.scrim35,
              shape: RoundedRectangleBorder(borderRadius: .circular(20)),
            ),
            child: Column(
              mainAxisSize: .min,
              spacing: 8,
              children: [
                _IconButton(
                  icon: state.flashMode.icon,
                  label: l10n.videoRecorderToggleFlashLabel,
                  identifier: SemanticIds.cameraFlashButton,
                  value: _flashModeValue(l10n, state.flashMode),
                  onTap: state.hasFlash
                      ? () => context.read<VideoRecorderBloc>().add(
                          const VideoRecorderFlashToggled(),
                        )
                      : null,
                ),
                if (state.supportsTimer)
                  _IconButton(
                    icon: state.timer.icon,
                    label: l10n.videoRecorderCycleTimerLabel,
                    identifier: SemanticIds.cameraTimerButton,
                    value: _timerDurationValue(l10n, state.timer),
                    onTap: () => context.read<VideoRecorderBloc>().add(
                      const VideoRecorderTimerCycled(),
                    ),
                  ),
                if (state.capturesStills) const _GhostFrameButton(),
                if (state.capturesStills)
                  _IconButton(
                    icon: .gridNine,
                    label: l10n.videoRecorderToggleGridLabel,
                    identifier: SemanticIds.cameraGridButton,
                    toggled: state.showGridLines,
                    onTap: () => context.read<VideoRecorderBloc>().add(
                      const VideoRecorderGridLinesToggled(),
                    ),
                  ),
                _IconButton(
                  icon: state.aspectRatio == .square
                      ? .cropSquare
                      : .cropPortrait,
                  label: l10n.videoRecorderToggleAspectRatioLabel,
                  identifier: SemanticIds.cameraAspectRatioButton,
                  value: _aspectRatioValue(l10n, state.aspectRatio),
                  onTap: !hasClips
                      ? () => context.read<VideoRecorderBloc>().add(
                          const VideoRecorderAspectRatioToggled(),
                        )
                      : null,
                ),
                _IconButton(
                  icon: .arrowsClockwise,
                  label: l10n.videoRecorderSwitchCameraLabel,
                  identifier: SemanticIds.cameraSwitchCameraButton,
                  value: state.isFrontCamera
                      ? l10n.videoRecorderCameraValueFront
                      : l10n.videoRecorderCameraValueBack,
                  onTap: state.canSwitchCamera
                      ? () => context.read<VideoRecorderBloc>().add(
                          const VideoRecorderCameraSwitched(),
                        )
                      : null,
                ),
                if (state.supportsStabilization) const _StabilizationButton(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Toggles the ghost-frame (onion-skin) overlay in stop-motion mode, mirroring
/// the classic-mode ghost toggle.
class _GhostFrameButton extends StatelessWidget {
  const _GhostFrameButton();

  @override
  Widget build(BuildContext context) {
    final isVisible = context.select(
      (VideoRecorderBloc b) => b.state.showLastClipOverlay,
    );
    return _IconButton(
      icon: .ghost,
      label: context.l10n.videoRecorderToggleGhostFrameLabel,
      identifier: SemanticIds.cameraGhostFrameButton,
      toggled: isVisible,
      onTap: () {
        final willEnable = !isVisible;
        context.read<VideoRecorderBloc>().add(
          const VideoRecorderShowLastClipOverlayToggled(),
        );
        ScaffoldMessenger.of(context)
          ..clearSnackBars()
          ..showSnackBar(
            DivineSnackbarContainer.snackBar(
              willEnable
                  ? context.l10n.videoRecorderGhostFrameEnabled
                  : context.l10n.videoRecorderGhostFrameDisabled,
            ),
          );
      },
    );
  }
}

/// Opens a selection menu to change the video stabilization mode.
///
/// Disabled when the active camera reports no stabilization support
/// (e.g. front camera on some devices, macOS, Linux).
class _StabilizationButton extends StatelessWidget {
  const _StabilizationButton();

  @override
  Widget build(BuildContext context) {
    final (isSupported, mode) = context.select(
      (VideoRecorderBloc b) => (
        b.state.isVideoStabilizationSupported,
        b.state.videoStabilizationMode,
      ),
    );
    return _IconButton(
      icon: .sparkle,
      label: context.l10n.videoRecorderStabilizationLabel,
      identifier: SemanticIds.cameraStabilizationButton,
      value: _stabilizationModeLabel(context.l10n, mode),
      onTap: isSupported ? () => _showStabilizationMenu(context) : null,
    );
  }

  Future<void> _showStabilizationMenu(BuildContext context) async {
    final l10n = context.l10n;
    final bloc = context.read<VideoRecorderBloc>();
    final state = bloc.state;

    final selected = await VineBottomSheetSelectionMenu.show(
      context: context,
      title: Text(
        l10n.videoRecorderStabilizationLabel,
        style: VineTheme.titleMediumFont(color: context.vineColors.primaryText),
      ),
      selectedValue: state.videoStabilizationMode.toNativeString(),
      options: [
        for (final mode in state.availableVideoStabilizationModes)
          VineBottomSheetSelectionOptionData(
            label: _stabilizationModeLabel(l10n, mode),
            value: mode.toNativeString(),
          ),
      ],
    );

    if (selected == null || !context.mounted || bloc.isClosed) return;
    bloc.add(
      VideoRecorderStabilizationModeSet(
        DivineVideoStabilizationMode.fromNativeString(selected),
      ),
    );
  }
}

/// Maps a [DivineVideoStabilizationMode] to its localized label.
String _stabilizationModeLabel(
  AppLocalizations l10n,
  DivineVideoStabilizationMode mode,
) {
  return switch (mode) {
    .off => l10n.videoRecorderStabilizationModeOff,
    .standard => l10n.videoRecorderStabilizationModeStandard,
    .cinematic => l10n.videoRecorderStabilizationModeCinematic,
    .cinematicExtended => l10n.videoRecorderStabilizationModeCinematicExtended,
    .previewOptimized => l10n.videoRecorderStabilizationModePreviewOptimized,
    .lowLatency => l10n.videoRecorderStabilizationModeLowLatency,
    .auto => l10n.videoRecorderStabilizationModeAuto,
  };
}

/// Maps a [DivineFlashMode] to the localized state a screen reader announces.
String _flashModeValue(AppLocalizations l10n, DivineFlashMode mode) {
  return switch (mode) {
    .off => l10n.videoRecorderFlashValueOff,
    .torch => l10n.videoRecorderFlashValueOn,
    .auto => l10n.videoRecorderFlashValueAuto,
  };
}

/// Maps a [TimerDuration] to the localized state a screen reader announces.
String _timerDurationValue(AppLocalizations l10n, TimerDuration timer) {
  return switch (timer) {
    .off => l10n.videoRecorderTimerValueOff,
    .three => l10n.videoRecorderTimerValueThreeSeconds,
    .ten => l10n.videoRecorderTimerValueTenSeconds,
  };
}

/// Maps an [model.AspectRatio] to the localized state a screen reader
/// announces.
String _aspectRatioValue(AppLocalizations l10n, model.AspectRatio ratio) {
  return switch (ratio) {
    .square => l10n.videoRecorderAspectRatioValueSquare,
    .vertical => l10n.videoRecorderAspectRatioValueVertical,
  };
}

class _IconButton extends StatelessWidget {
  const _IconButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.identifier,
    this.value,
    this.toggled,
  });

  final String label;
  final DivineIconName icon;
  final VoidCallback? onTap;

  /// Stable `Semantics(identifier:)` anchor for E2E tests. Never announced,
  /// so it carries no meaning for a screen-reader user — that is [label].
  final String? identifier;

  /// Current setting of a control that cycles through more than two states,
  /// announced after [label] (e.g. the active flash mode).
  final String? value;

  /// Current setting of a control that only flips on and off, announced as
  /// "on"/"off" (e.g. the grid overlay).
  final bool? toggled;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: identifier,
      button: true,
      enabled: onTap != null,
      label: label,
      value: value,
      toggled: toggled,
      child: Tooltip(
        message: label,
        // The label above already carries the message; without this the
        // screen reader announces it a second time as a tooltip.
        excludeFromSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: Padding(
            padding: const .all(8),
            child: DivineIcon(
              icon: icon,
              color: VineTheme.whiteText.withAlpha(onTap != null ? 255 : 100),
            ),
          ),
        ),
      ),
    );
  }
}
