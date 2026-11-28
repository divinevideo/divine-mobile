// ABOUTME: Overlay controls of the video effects editor: close/done toolbar,
// ABOUTME: intensity slider, the button to the effect's settings and the
// ABOUTME: play/pause tap area.

import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/effects_editor/video_editor_effects_cubit.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/constants/text_scale_limits.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/video_editor_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:openvine/widgets/video_editor/effects_editor/exclusive_effect_snack_bar.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';
import 'package:openvine/widgets/video_editor/video_editor_vertical_slider.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show VideoEffectPreview;

/// What the cards over the preview leave free on the right for the intensity
/// slider.
const double _sliderClearance = 72;

/// Overlay controls for the effects editor.
///
/// Shows a vertical intensity slider on the right while an effect is picked,
/// with a button below it that shows the effect's settings in the bar under
/// the preview when it has any (see [VideoEditorEffectsState.hasSettings]),
/// and says so when this device cannot preview effects at all.
class VideoEditorEffectsOverlayControls extends StatelessWidget {
  const VideoEditorEffectsOverlayControls({super.key});

  @override
  Widget build(BuildContext context) {
    final hasEffect = context.select(
      (VideoEditorEffectsCubit c) => c.state.selectedType != null,
    );
    return BlocListener<VideoEditorEffectsCubit, VideoEditorEffectsState>(
      listenWhen: (previous, current) =>
          current.isEditing && previous.selectedType != current.selectedType,
      listener: _showIntroOutro,
      child: Stack(
        fit: .expand,
        children: [
          Semantics(
            button: true,
            label: context.l10n.videoEditorPlayPauseSemanticLabel,
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => context.read<VideoEditorMainBloc>().add(
                const VideoEditorPlaybackToggleRequested(),
              ),
            ),
          ),
          Column(
            children: [
              const _TopBarContent(),
              // Everything else sits under the toolbar: the bar under the
              // preview is tall, so nothing may reach up behind it.
              Expanded(
                child: _ControlsLayout(
                  slider: AnimatedSwitcher(
                    transitionBuilder: (child, animation) {
                      return FadeTransition(
                        opacity: animation,
                        child: SlideTransition(
                          position: Tween(
                            begin: const Offset(1, 0),
                            end: Offset.zero,
                          ).animate(animation),
                          child: child,
                        ),
                      );
                    },
                    switchInCurve: Curves.easeInOut,
                    duration: const Duration(milliseconds: 220),
                    child: hasEffect
                        ? const _IntensitySlider()
                        : const SizedBox.shrink(),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Moves the playhead to where a picked intro or outro plays, which may be
  /// seconds away from it; see
  /// [VideoEditorEffectsState.introOutroPreviewPosition].
  static void _showIntroOutro(
    BuildContext context,
    VideoEditorEffectsState state,
  ) {
    final mainBloc = context.read<VideoEditorMainBloc>();
    final position = state.introOutroPreviewPosition(
      playing: mainBloc.state.isPlaying,
    );
    if (position != null) mainBloc.add(VideoEditorSeekRequested(position));
  }
}

/// Lays out the controls under the toolbar.
///
/// The intensity slider is centred on the right in the space above the bar
/// under the preview, and the button to the picked effect's settings sits on
/// the right just above the bottom bar, the sheet it opens them in. The
/// notice that the preview cannot show effects lies over the preview at the
/// top, which shows no effects on such a device anyway.
class _ControlsLayout extends StatelessWidget {
  const _ControlsLayout({required this.slider});

  final Widget slider;

  /// The gap between the settings button and the bottom bar below it.
  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = max(
          0.0,
          constraints.maxHeight - VideoEditorConstants.bottomBarHeight,
        );
        final sliderHeight = _IntensitySlider.heightIn(area);
        return Stack(
          children: [
            const Align(
              alignment: .topCenter,
              child: _PreviewUnavailableNotice(),
            ),
            Positioned(
              top: (area - sliderHeight) / 2,
              right: 0,
              height: sliderHeight,
              child: slider,
            ),
            const Positioned(
              right: 0,
              bottom: _gap,
              child: _SettingsButton(),
            ),
          ],
        );
      },
    );
  }
}

/// Shows the picked effect's settings in place of the effects picker, or the
/// picker again; only for an effect that has settings.
class _SettingsButton extends StatelessWidget {
  const _SettingsButton();

  @override
  Widget build(BuildContext context) {
    final hasSettings = context.select(
      (VideoEditorEffectsCubit c) => c.state.hasSettings,
    );
    if (!hasSettings) return const SizedBox.shrink();
    final isOpen = context.select(
      (VideoEditorEffectsCubit c) => c.state.isSettingsOpen,
    );
    final label = context.l10n.videoEditorEffectSettingsOpen;
    return Padding(
      padding: const .only(right: 16),
      child: DivineIconButton(
        icon: .slidersHorizontal,
        type: isOpen ? .primary : .secondary,
        size: .small,
        tooltip: label,
        semanticLabel: label,
        semanticToggled: isOpen,
        onPressed: () =>
            context.read<VideoEditorEffectsCubit>().setSettingsOpen(
              open: !isOpen,
            ),
      ),
    );
  }
}

/// The intensity slider, as tall as it is allowed to be.
class _IntensitySlider extends StatelessWidget {
  const _IntensitySlider();

  /// How tall the slider is in [area] of height.
  static double heightIn(double area) => min(300, area * 0.8);

  @override
  Widget build(BuildContext context) {
    final intensity = context.select(
      (VideoEditorEffectsCubit c) => c.state.intensity,
    );
    final look = context.select(
      (VideoEditorEffectsCubit c) => c.state.selectedType?.introOutroLook,
    );
    final l10n = context.l10n;
    return Padding(
      padding: const .only(right: 16),
      child: LayoutBuilder(
        builder: (_, constraints) => VideoEditorVerticalSlider(
          height: constraints.maxHeight,
          value: intensity,
          // An intro or outro's slider changes the structure of its look.
          semanticLabel: switch (look) {
            IntroOutroLook.fade => l10n.videoEditorEffectShapeFadeColor,
            IntroOutroLook.circle => l10n.videoEditorEffectShapeCircleSoftness,
            IntroOutroLook.cinema => l10n.videoEditorEffectShapeCinemaBars,
            IntroOutroLook.curtain => l10n.videoEditorEffectShapeCurtainFolds,
            IntroOutroLook.focus => l10n.videoEditorEffectShapeFocusBlur,
            null => null,
          },
          onChanged: context.read<VideoEditorEffectsCubit>().setIntensity,
        ),
      ),
    );
  }
}

class _TopBarContent extends StatelessWidget {
  const _TopBarContent();

  @override
  Widget build(BuildContext context) {
    final cubit = context.read<VideoEditorEffectsCubit>();
    final mainBloc = context.read<VideoEditorMainBloc>();
    final scope = VideoEditorScope.of(context);
    final toolName = context.l10n.videoEditorEffectsLabel;

    return Align(
      alignment: .topCenter,
      child: VideoEditorToolbar(
        closeSemanticLabel: context.l10n
            .videoEditorDiscardToolChangesSemanticLabel(toolName),
        doneSemanticLabel: context.l10n
            .videoEditorApplyToolChangesSemanticLabel(toolName),
        onClose: () {
          cubit.cancel();
          mainBloc.add(const VideoEditorMainSubEditorClosed());
        },
        onDone: () {
          final result = cubit.confirm();
          scope.editor?.setVideoEffectEntries(result.effects);
          if (result.replaced case final group?) {
            showExclusiveEffectReplacedSnackBar(context, group);
          }
          mainBloc.add(const VideoEditorMainSubEditorClosed());
        },
      ),
    );
  }
}

/// Says so when this device cannot show effects in the preview.
///
/// Without it the preview would quietly show the plain video, which reads as
/// "the effect does nothing" rather than "you can't see it here".
class _PreviewUnavailableNotice extends StatefulWidget {
  const _PreviewUnavailableNotice();

  @override
  State<_PreviewUnavailableNotice> createState() =>
      _PreviewUnavailableNoticeState();
}

class _PreviewUnavailableNoticeState extends State<_PreviewUnavailableNotice> {
  late final Future<bool> _canPreview = VideoEffectPreview.precache();

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: _canPreview,
      builder: (context, snapshot) {
        if (snapshot.data != false) return const SizedBox.shrink();
        return Padding(
          padding: const .only(left: 16, right: _sliderClearance),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.vineColors.surfaceContainer,
              borderRadius: .circular(12),
            ),
            child: Padding(
              padding: const .symmetric(horizontal: 12, vertical: 8),
              // Covers the preview, so it stops growing before it covers
              // most of it.
              child: MediaQuery.withClampedTextScaling(
                maxScaleFactor: chipLabelTextScaleLimit,
                child: Text(
                  context.l10n.videoEditorChromaKeyPreviewUnavailable,
                  textAlign: .center,
                  style: VineTheme.bodySmallFont(
                    color: context.vineColors.onSurface,
                  ),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
