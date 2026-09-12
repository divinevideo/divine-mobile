// ABOUTME: Overlay controls for the video editor filter selection.
// ABOUTME: Contains top action buttons and vertical opacity slider.

import 'dart:math';

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';
import 'package:openvine/widgets/video_editor/video_editor_vertical_slider.dart';

/// Overlay controls for the filter editor.
///
/// Shows a vertical opacity slider on the right side of the video preview
/// when a filter is selected (not "None"). The slider allows adjusting the
/// filter intensity from 0% to 100%.
class VideoEditorFilterOverlayControls extends StatelessWidget {
  const VideoEditorFilterOverlayControls({super.key});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: .expand,
      children: [
        // Catch taps on the video area for play/pause toggle.
        // ProImageEditor's filter sub-editor doesn't forward onTap.
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
          child:
              BlocSelector<VideoEditorFilterBloc, VideoEditorFilterState, bool>(
                selector: (state) => state.hasFilter,
                builder: (context, hasFilter) {
                  return AnimatedSwitcher(
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
                    child: hasFilter
                        ? const _OpacitySlider()
                        : const SizedBox.shrink(),
                  );
                },
              ),
        ),
        const _TopBarContent(),
      ],
    );
  }
}

/// Vertical slider for adjusting filter opacity.
class _OpacitySlider extends StatelessWidget {
  const _OpacitySlider();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .only(right: 16),
      child: LayoutBuilder(
        builder: (_, constraints) {
          return BlocSelector<
            VideoEditorFilterBloc,
            VideoEditorFilterState,
            double
          >(
            selector: (state) => state.opacity,
            builder: (context, opacity) {
              return VideoEditorVerticalSlider(
                height: min(300, constraints.maxHeight * 0.8),
                value: opacity,
                onChanged: (value) {
                  context.read<VideoEditorFilterBloc>().add(
                    VideoEditorFilterOpacityChanged(value),
                  );
                  final scope = VideoEditorScope.of(context);

                  scope.filterEditor?.setFilterOpacity(value);
                },
              );
            },
          );
        },
      ),
    );
  }
}

class _TopBarContent extends StatelessWidget {
  const _TopBarContent();

  @override
  Widget build(BuildContext context) {
    final bloc = context.read<VideoEditorFilterBloc>();
    final scope = VideoEditorScope.of(context);

    return Align(
      alignment: .topCenter,
      child: VideoEditorToolbar(
        closeSemanticLabel: context.l10n
            .videoEditorDiscardToolChangesSemanticLabel(
              context.l10n.videoEditorFilterLabel,
            ),
        doneSemanticLabel: context.l10n
            .videoEditorApplyToolChangesSemanticLabel(
              context.l10n.videoEditorFilterLabel,
            ),
        onClose: () {
          bloc.add(const VideoEditorFilterCancelled());
          scope.filterEditor?.close();
        },
        onDone: () {
          bloc.add(const VideoEditorFilterConfirmed());
          scope.filterEditor?.done();
        },
      ),
    );
  }
}
