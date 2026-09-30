// ABOUTME: Overlay controls of the video effects editor: close/done toolbar,
// ABOUTME: vertical intensity slider and the play/pause tap area.

import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/effects_editor/video_editor_effects_cubit.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/extensions/video_editor_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/effects_editor/flashing_effect_snack_bar.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';
import 'package:openvine/widgets/video_editor/video_editor_vertical_slider.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show VideoEffectPreview;

/// Overlay controls for the effects editor.
///
/// Shows a vertical intensity slider on the right while an effect is picked,
/// and says so when this device cannot preview effects at all.
class VideoEditorEffectsOverlayControls extends StatelessWidget {
  const VideoEditorEffectsOverlayControls({super.key});

  @override
  Widget build(BuildContext context) {
    final hasEffect = context.select(
      (VideoEditorEffectsCubit c) => c.state.selectedType != null,
    );
    return Stack(
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
        Align(
          alignment: .centerRight,
          child: AnimatedSwitcher(
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
        const _TopBarContent(),
      ],
    );
  }
}

class _IntensitySlider extends StatelessWidget {
  const _IntensitySlider();

  @override
  Widget build(BuildContext context) {
    final intensity = context.select(
      (VideoEditorEffectsCubit c) => c.state.intensity,
    );
    return Padding(
      padding: const .only(right: 16),
      child: LayoutBuilder(
        builder: (_, constraints) => VideoEditorVerticalSlider(
          height: min(300, constraints.maxHeight * 0.8),
          value: intensity,
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
      child: Column(
        mainAxisSize: .min,
        children: [
          VideoEditorToolbar(
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
              if (result.replacedFlashing) {
                showFlashingEffectReplacedSnackBar(context);
              }
              mainBloc.add(const VideoEditorMainSubEditorClosed());
            },
          ),
          const _PreviewUnavailableNotice(),
        ],
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
          padding: const .symmetric(horizontal: 16),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: context.vineColors.surfaceContainer,
              borderRadius: .circular(12),
            ),
            child: Padding(
              padding: const .symmetric(horizontal: 12, vertical: 8),
              child: Text(
                context.l10n.videoEditorChromaKeyPreviewUnavailable,
                textAlign: .center,
                style: VineTheme.bodySmallFont(
                  color: context.vineColors.onSurface,
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
