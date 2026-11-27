// ABOUTME: Overlay controls for the video editor filter selection: the
// ABOUTME: toolbar, the opacity slider and the button to the filter's settings.

import 'dart:math';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/filter_editor/video_editor_filter_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_editor/filter_settings.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/video_editor_toolbar.dart';
import 'package:openvine/widgets/video_editor/video_editor_vertical_slider.dart';

/// Overlay controls for the filter editor.
///
/// Shows a vertical opacity slider on the right side of the video preview,
/// below the toolbar, when a filter is selected, with a button above the
/// bottom bar that shows the filter's settings there in place of the picker.
///
/// The filter editor previews what the [VideoEditorFilterBloc] holds: the
/// picked preset with its changed settings, at its opacity.
class VideoEditorFilterOverlayControls extends StatelessWidget {
  const VideoEditorFilterOverlayControls({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocListener<VideoEditorFilterBloc, VideoEditorFilterState>(
      listenWhen: (previous, current) => previous.edited != current.edited,
      listener: (context, state) {
        final edited = state.edited;
        if (edited == null) return;
        VideoEditorScope.of(context).filterEditor
          ?..setFilter(edited.filter)
          ..setFilterOpacity(edited.opacity);
      },
      child: Stack(
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
          const Column(
            children: [
              _TopBarContent(),
              // Below the toolbar: the picker under the preview is tall, so
              // nothing may reach up behind the toolbar.
              Expanded(child: _ControlsLayout()),
            ],
          ),
        ],
      ),
    );
  }
}

/// Lays out the controls under the toolbar: the opacity slider centred on
/// the right above the bar under the preview, and the button to the
/// filter's settings on the right just above that bar.
class _ControlsLayout extends StatelessWidget {
  const _ControlsLayout();

  /// The gap between the settings button and the bottom bar below it.
  static const double _gap = 12;

  @override
  Widget build(BuildContext context) {
    final hasFilter = context.select(
      (VideoEditorFilterBloc b) => b.state.hasFilter,
    );
    return LayoutBuilder(
      builder: (context, constraints) {
        final area = max(
          0.0,
          constraints.maxHeight - VideoEditorConstants.bottomBarHeight,
        );
        final sliderHeight = min(300.0, area * 0.8);
        return Stack(
          children: [
            Positioned(
              top: (area - sliderHeight) / 2,
              right: 0,
              height: sliderHeight,
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
                child: hasFilter
                    ? const _OpacitySlider()
                    : const SizedBox.shrink(),
              ),
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

/// Vertical slider for adjusting filter opacity.
class _OpacitySlider extends StatelessWidget {
  const _OpacitySlider();

  @override
  Widget build(BuildContext context) {
    final opacity = context.select(
      (VideoEditorFilterBloc b) => b.state.opacity,
    );
    return Padding(
      padding: const .only(right: 16),
      child: LayoutBuilder(
        builder: (_, constraints) => VideoEditorVerticalSlider(
          height: constraints.maxHeight,
          value: opacity,
          onChanged: (value) => context.read<VideoEditorFilterBloc>().add(
            VideoEditorFilterOpacityChanged(value),
          ),
        ),
      ),
    );
  }
}

/// Shows the picked filter's settings in place of the picker, or the picker
/// again; only for a filter that has settings.
class _SettingsButton extends StatelessWidget {
  const _SettingsButton();

  @override
  Widget build(BuildContext context) {
    final hasSettings = context.select(
      (VideoEditorFilterBloc b) => b.state.hasSettings,
    );
    if (!hasSettings) return const SizedBox.shrink();
    final isOpen = context.select(
      (VideoEditorFilterBloc b) => b.state.isSettingsOpen,
    );
    final label = context.l10n.videoEditorFilterSettingsOpen;
    return Padding(
      padding: const .only(right: 16),
      child: DivineIconButton(
        icon: .slidersHorizontal,
        type: isOpen ? .primary : .secondary,
        size: .small,
        tooltip: label,
        semanticLabel: label,
        semanticToggled: isOpen,
        onPressed: () => context.read<VideoEditorFilterBloc>().add(
          VideoEditorFilterSettingsToggled(open: !isOpen),
        ),
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
        onDone: () => _commit(bloc, scope),
      ),
    );
  }

  /// Commits the filter of this session: a new filter over the whole video,
  /// or the edited one in place, keeping its window on the timeline.
  ///
  /// The editor's own `done()` can only add a filter, and keeps none of the
  /// settings it was made with, so it is closed and the filter written to the
  /// history here, with the matrices the editor previews. With nothing
  /// picked in the editor, which is what it previews, nothing is committed.
  void _commit(VideoEditorFilterBloc bloc, VideoEditorScope scope) {
    final filterEditor = scope.filterEditor;
    final edited = bloc.state.edited;
    final editor = scope.editor;
    if (edited == null ||
        filterEditor == null ||
        filterEditor.selectedFilter.filters.isEmpty) {
      bloc.add(const VideoEditorFilterCancelled());
      filterEditor?.close();
      return;
    }
    final editingId = bloc.state.editingFilterId;
    final matrices = filterEditor.filterMatrix;
    bloc.add(const VideoEditorFilterConfirmed());
    filterEditor.close();
    if (editor == null) return;
    editor.addHistory(
      filters: commitEditedFilter(
        active: editor.stateManager.activeFilters,
        filter: edited,
        matrices: matrices,
        editingId: editingId,
      ),
    );
  }
}
