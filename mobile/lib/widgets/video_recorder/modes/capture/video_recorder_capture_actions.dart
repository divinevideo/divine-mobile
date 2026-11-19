import 'package:divine_camera/divine_camera.dart'
    show DivineCameraLens, DivineVideoStabilizationMode;
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/semantics.dart' show OrdinalSortKey;
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
import 'package:openvine/widgets/video_recorder/modes/capture/video_recorder_chroma_key_settings.dart';

/// Width of the pill behind the rail's icons: each icon is 24 wide with 8 of
/// padding around it, and the pill leaves 4 on either side.
const double _railPillWidth = 4 + 8 + 24 + 8 + 4;

/// How long the rail takes to unfold or fold, and its names to fade in.
const Duration _railAnimationDuration = Duration(milliseconds: 220);

// Screen readers read the rail top to bottom, except that the controls an
// unfolded rail reveals come right after the button that revealed them, where
// a swipe on from it lands, although they are drawn above it. Every control
// has its own key: the framework does not keep equal keys in drawn order.
const OrdinalSortKey _flashReadingOrder = OrdinalSortKey(0);
const OrdinalSortKey _flipReadingOrder = OrdinalSortKey(1);
const OrdinalSortKey _aspectRatioReadingOrder = OrdinalSortKey(2);
const OrdinalSortKey _optionsButtonReadingOrder = OrdinalSortKey(3);
const OrdinalSortKey _timerReadingOrder = OrdinalSortKey(4);
const OrdinalSortKey _ghostFrameReadingOrder = OrdinalSortKey(5);
const OrdinalSortKey _gridReadingOrder = OrdinalSortKey(6);
const OrdinalSortKey _dualCameraReadingOrder = OrdinalSortKey(7);
const OrdinalSortKey _stabilizationReadingOrder = OrdinalSortKey(8);
const OrdinalSortKey _colorMaskReadingOrder = OrdinalSortKey(9);

/// Shadow under the controls' names, so they stay readable over a bright
/// viewfinder.
const List<Shadow> _railCaptionShadows = [
  Shadow(color: VineTheme.scrim50, blurRadius: 6),
  Shadow(color: VineTheme.shadow25, offset: Offset(0, 1), blurRadius: 2),
];

/// The camera controls on the right edge of the capture viewfinder.
///
/// Folded, the rail offers flash, lens and aspect ratio, and a fourth button
/// that unfolds it. Unfolded, it lists every control the mode offers, each
/// with its name next to the icon, and the unfold button moves to the bottom
/// to fold it again. A take or a stop-motion interval folds it as well.
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
        isShutterActive: b.state.isShutterActive,
        hasRecordingInFlight: b.state.hasRecordingInFlight,
        showGridLines: b.state.showGridLines,
        isRailExpanded: b.state.isActionRailExpanded,
        supportsTimer: b.state.recorderMode.supportsCountdownTimer,
        supportsGrid: b.state.recorderMode.supportGridLines,
        supportsGhostFrame: b.state.supportsGhostFrame,
        supportsStabilization: b.state.supportsVideoStabilization,
        offersChromaKey: b.state.offersChromaKey,
        supportsDualCamera: b.state.supportsDualCamera,
        isDualCameraEnabled: b.state.isDualCameraEnabled,
      ),
    );
    final hasClips = ref.watch(clipManagerProvider.select((p) => p.hasClips));
    final reduceMotion = MediaQuery.disableAnimationsOf(context);

    // Only listed while the rail is unfolded, so they always show their name.
    final moreOptions = <Widget>[
      if (state.supportsTimer)
        _RailButton(
          key: const ValueKey(SemanticIds.cameraTimerButton),
          icon: state.timer.icon,
          label: l10n.videoRecorderCycleTimerLabel,
          caption: l10n.videoRecorderRailTimerLabel,
          identifier: SemanticIds.cameraTimerButton,
          sortKey: _timerReadingOrder,
          value: _timerDurationValue(l10n, state.timer),
          onTap: () => context.read<VideoRecorderBloc>().add(
            const VideoRecorderTimerCycled(),
          ),
        ),
      if (state.supportsGhostFrame)
        const _GhostFrameButton(
          key: ValueKey(SemanticIds.cameraGhostFrameButton),
        ),
      if (state.supportsGrid)
        _RailButton(
          key: const ValueKey(SemanticIds.cameraGridButton),
          icon: .gridNine,
          label: l10n.videoRecorderToggleGridLabel,
          caption: l10n.videoRecorderRailGridLabel,
          identifier: SemanticIds.cameraGridButton,
          sortKey: _gridReadingOrder,
          toggled: state.showGridLines,
          onTap: () => context.read<VideoRecorderBloc>().add(
            const VideoRecorderGridLinesToggled(),
          ),
        ),
      if (state.supportsDualCamera)
        _RailButton(
          key: const ValueKey(SemanticIds.cameraDualCameraButton),
          icon: .pictureInPicture,
          label: l10n.videoRecorderToggleDualCameraLabel,
          caption: l10n.videoRecorderRailDualCameraLabel,
          identifier: SemanticIds.cameraDualCameraButton,
          sortKey: _dualCameraReadingOrder,
          toggled: state.isDualCameraEnabled,
          // Rebuilding the camera session ends a take, so the recorder
          // refuses it while one is in flight.
          onTap: !state.hasRecordingInFlight
              ? () => context.read<VideoRecorderBloc>().add(
                  const VideoRecorderDualCameraToggled(),
                )
              : null,
        ),
      // Dual capture runs without stabilization; the saved mode returns with
      // one camera.
      if (state.supportsStabilization && !state.isDualCameraEnabled)
        const _StabilizationButton(
          key: ValueKey(SemanticIds.cameraStabilizationButton),
        ),
      if (state.offersChromaKey)
        const _ColorMaskButton(
          key: ValueKey(SemanticIds.cameraColorMaskButton),
        ),
    ];
    final isExpanded = state.isRailExpanded && moreOptions.isNotEmpty;

    return SafeArea(
      top: false,
      left: false,
      bottom: false,
      child: IgnorePointer(
        ignoring: state.isShutterActive,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 220),
          opacity: state.isShutterActive ? 0 : 1,
          child: Padding(
            padding: const .only(right: 16),
            child: Stack(
              children: [
                // Behind the icons only: the names sit on the viewfinder.
                const Positioned(
                  top: 0,
                  right: 0,
                  bottom: 0,
                  width: _railPillWidth,
                  child: DecoratedBox(
                    decoration: ShapeDecoration(
                      color: VineTheme.scrim35,
                      shape: RoundedRectangleBorder(
                        borderRadius: .all(.circular(20)),
                      ),
                    ),
                  ),
                ),
                AnimatedSize(
                  duration: reduceMotion
                      ? Duration.zero
                      : _railAnimationDuration,
                  curve: Curves.easeOutCubic,
                  alignment: .topRight,
                  child: SingleChildScrollView(
                    primary: false,
                    hitTestBehavior: HitTestBehavior.deferToChild,
                    // Leaves room for the names' shadow, which the animation
                    // would clip otherwise.
                    padding: const .fromLTRB(16, 12, 0, 12),
                    child: Column(
                      mainAxisSize: .min,
                      crossAxisAlignment: .end,
                      // The camera stack anchors the pill to the physical
                      // right, including in right-to-left locales.
                      textDirection: TextDirection.ltr,
                      spacing: 8,
                      children: [
                        _RailButton(
                          key: const ValueKey(SemanticIds.cameraFlashButton),
                          icon: state.flashMode.icon,
                          label: l10n.videoRecorderToggleFlashLabel,
                          caption: isExpanded
                              ? l10n.videoRecorderRailFlashLabel
                              : null,
                          identifier: SemanticIds.cameraFlashButton,
                          sortKey: _flashReadingOrder,
                          value: _flashModeValue(l10n, state.flashMode),
                          onTap: state.hasFlash
                              ? () => context.read<VideoRecorderBloc>().add(
                                  const VideoRecorderFlashToggled(),
                                )
                              : null,
                        ),
                        _RailButton(
                          key: const ValueKey(
                            SemanticIds.cameraSwitchCameraButton,
                          ),
                          icon: .arrowsClockwise,
                          label: l10n.videoRecorderSwitchCameraLabel,
                          caption: isExpanded
                              ? l10n.videoRecorderRailFlipLabel
                              : null,
                          identifier: SemanticIds.cameraSwitchCameraButton,
                          sortKey: _flipReadingOrder,
                          value: DivineCameraLens.allCamerasFaceUser
                              ? null
                              : state.isFrontCamera
                              ? l10n.videoRecorderCameraValueFront
                              : l10n.videoRecorderCameraValueBack,
                          // The recorder refuses a flip while a take starts
                          // or finishes, so show it disabled instead of
                          // dropping the tap.
                          onTap:
                              state.canSwitchCamera &&
                                  !state.hasRecordingInFlight
                              ? () => context.read<VideoRecorderBloc>().add(
                                  const VideoRecorderCameraSwitched(),
                                )
                              : null,
                        ),
                        _RailButton(
                          key: const ValueKey(
                            SemanticIds.cameraAspectRatioButton,
                          ),
                          icon: state.aspectRatio == .square
                              ? .cropSquare
                              : .cropPortrait,
                          label: l10n.videoRecorderToggleAspectRatioLabel,
                          caption: isExpanded
                              ? l10n.videoRecorderRailAspectRatioLabel
                              : null,
                          identifier: SemanticIds.cameraAspectRatioButton,
                          sortKey: _aspectRatioReadingOrder,
                          value: _aspectRatioValue(l10n, state.aspectRatio),
                          onTap: !hasClips
                              ? () => context.read<VideoRecorderBloc>().add(
                                  const VideoRecorderAspectRatioToggled(),
                                )
                              : null,
                        ),
                        if (isExpanded) ...moreOptions,
                        if (moreOptions.isNotEmpty)
                          _RailButton(
                            key: const ValueKey(
                              SemanticIds.cameraRailOptionsButton,
                            ),
                            icon: .caretDown,
                            // VoiceOver does not speak the expanded state, so
                            // the label says what a tap does.
                            label: isExpanded
                                ? l10n.videoRecorderRailHideOptionsLabel
                                : l10n.videoRecorderRailShowOptionsLabel,
                            identifier: SemanticIds.cameraRailOptionsButton,
                            sortKey: _optionsButtonReadingOrder,
                            expanded: isExpanded,
                            iconTurns: isExpanded ? 0.5 : 0,
                            onTap: state.hasRecordingInFlight
                                ? null
                                : () => context.read<VideoRecorderBloc>().add(
                                    const VideoRecorderActionRailToggled(),
                                  ),
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Toggles the ghost-frame (onion-skin) overlay on the capture rail, mirroring
/// the classic-mode ghost toggle.
class _GhostFrameButton extends StatelessWidget {
  const _GhostFrameButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isVisible = context.select(
      (VideoRecorderBloc b) => b.state.showLastClipOverlay,
    );
    return _RailButton(
      icon: .ghost,
      label: context.l10n.videoRecorderToggleGhostFrameLabel,
      caption: context.l10n.videoRecorderRailGhostFrameLabel,
      identifier: SemanticIds.cameraGhostFrameButton,
      sortKey: _ghostFrameReadingOrder,
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

/// Turns the color mask on, or opens its settings again while it is on.
///
/// Turning it on opens the settings straight away: the wall and the backdrop
/// are set there, and the sheet is also where the mask is turned off.
class _ColorMaskButton extends StatelessWidget {
  const _ColorMaskButton({super.key});

  @override
  Widget build(BuildContext context) {
    final isEnabled = context.select(
      (VideoRecorderBloc b) => b.state.isChromaKeyEnabled,
    );
    return _RailButton(
      icon: .selection,
      label: context.l10n.videoEditorChromaKeyLabel,
      caption: context.l10n.videoEditorChromaKeyLabel,
      identifier: SemanticIds.cameraColorMaskButton,
      sortKey: _colorMaskReadingOrder,
      toggled: isEnabled,
      highlighted: isEnabled,
      onTap: () async {
        if (!isEnabled) {
          context.read<VideoRecorderBloc>().add(
            const VideoRecorderChromaKeyEnabledSet(enabled: true),
          );
        }
        await showVideoRecorderChromaKeySettings(context);
      },
    );
  }
}

/// Opens a selection menu to change the video stabilization mode.
///
/// Disabled when the active camera reports no stabilization support
/// (e.g. front camera on some devices, macOS, Linux).
class _StabilizationButton extends StatelessWidget {
  const _StabilizationButton({super.key});

  @override
  Widget build(BuildContext context) {
    final (isSupported, mode) = context.select(
      (VideoRecorderBloc b) => (
        b.state.isVideoStabilizationSupported,
        b.state.videoStabilizationMode,
      ),
    );
    return _RailButton(
      icon: .stabilization,
      label: context.l10n.videoRecorderStabilizationLabel,
      caption: context.l10n.videoRecorderStabilizationLabel,
      identifier: SemanticIds.cameraStabilizationButton,
      sortKey: _stabilizationReadingOrder,
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
    .five => l10n.videoRecorderTimerValueFiveSeconds,
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

/// One control on the capture rail: its icon on the rail's pill, and while
/// the rail is unfolded its name to the left, which takes the tap as well.
class _RailButton extends StatelessWidget {
  const _RailButton({
    required this.icon,
    required this.label,
    required this.onTap,
    required this.sortKey,
    this.caption,
    this.identifier,
    this.value,
    this.toggled,
    this.expanded,
    this.iconTurns,
    this.highlighted = false,
    super.key,
  });

  /// What a screen reader announces, and the long-press tooltip.
  final String label;
  final DivineIconName icon;
  final VoidCallback? onTap;

  /// Short name drawn next to the icon, or `null` to show the icon alone.
  ///
  /// Never announced: [label] already says what the control does.
  final String? caption;

  /// Stable `Semantics(identifier:)` anchor for E2E tests. Never announced,
  /// so it carries no meaning for a screen-reader user — that is [label].
  final String? identifier;

  /// Current setting of a control whose states are not just on and off,
  /// announced after [label] (e.g. the active flash mode).
  final String? value;

  /// Current setting of a control that only flips on and off, announced as
  /// "on"/"off" (e.g. the grid overlay).
  final bool? toggled;

  /// Whether the section this control opens is open, for a control that
  /// unfolds one.
  final bool? expanded;

  /// Turns the icon by this fraction of a full turn, animated when it
  /// changes; `null` leaves the icon as drawn.
  final double? iconTurns;

  /// Where a screen reader reads this control among the rail's controls.
  final OrdinalSortKey sortKey;

  /// Draws the icon in the brand green, for a control whose effect is easy to
  /// miss in the viewfinder while it is on.
  final bool highlighted;

  @override
  Widget build(BuildContext context) {
    final alpha = onTap != null ? 255 : 100;
    final caption = this.caption;
    // Drawn over the live preview, so it is re-rasterized on every camera
    // frame: a live tinted SVG is a colour-filter saveLayer each time, the
    // baked glyph is one image draw.
    Widget iconWidget = ShadowedDivineIcon(
      icon: icon,
      color: (highlighted ? VineTheme.vineGreen : VineTheme.whiteText)
          .withAlpha(alpha),
      shadows: const [],
    );
    if (iconTurns case final turns?) {
      iconWidget = AnimatedRotation(
        turns: turns,
        duration: MediaQuery.disableAnimationsOf(context)
            ? Duration.zero
            : _railAnimationDuration,
        curve: Curves.easeOutCubic,
        child: iconWidget,
      );
    }

    return Semantics(
      identifier: identifier,
      button: true,
      enabled: onTap != null,
      label: label,
      value: value,
      toggled: toggled,
      expanded: expanded,
      sortKey: sortKey,
      child: Tooltip(
        message: label,
        // The label above already carries the message; without this the
        // screen reader announces it a second time as a tooltip.
        excludeFromSemantics: true,
        child: InkWell(
          onTap: onTap,
          child: Row(
            mainAxisSize: .min,
            textDirection: TextDirection.ltr,
            spacing: 8,
            children: [
              if (caption != null)
                Flexible(
                  child: ExcludeSemantics(
                    child: _RailCaption(text: caption, alpha: alpha),
                  ),
                ),
              Padding(
                // The pill's inset plus the icon's own padding.
                padding: const .symmetric(horizontal: 12, vertical: 8),
                child: iconWidget,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// A rail control's name, faded in as the rail unfolds.
class _RailCaption extends StatelessWidget {
  const _RailCaption({required this.text, required this.alpha});

  final String text;

  /// Matches the icon, dimmed for a control that is unavailable.
  final int alpha;

  @override
  Widget build(BuildContext context) {
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: MediaQuery.disableAnimationsOf(context)
          ? Duration.zero
          : _railAnimationDuration,
      builder: (context, opacity, child) =>
          Opacity(opacity: opacity, child: child),
      child: Text(
        text,
        textAlign: .right,
        style: VineTheme.labelLargeFont(
          color: VineTheme.whiteText.withAlpha(alpha),
        ).copyWith(shadows: _railCaptionShadows),
      ),
    );
  }
}
