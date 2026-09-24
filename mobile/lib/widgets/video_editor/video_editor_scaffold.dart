import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/widgets/branded_loading_scaffold.dart';
import 'package:openvine/widgets/video_editor/clip_editor_result_listeners.dart';
import 'package:openvine/widgets/video_editor/clip_operation_progress_overlays.dart';
import 'package:openvine/widgets/video_editor/draw_editor/video_editor_draw_bottom_bar.dart';
import 'package:openvine/widgets/video_editor/draw_editor/video_editor_draw_overlay_controls.dart';
import 'package:openvine/widgets/video_editor/filter_editor/video_editor_filter_bottom_bar.dart';
import 'package:openvine/widgets/video_editor/filter_editor/video_editor_filter_overlay_controls.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_canvas.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_caption_preview_overlay.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_main_actions_sheet.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_main_overlay_actions.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline.dart';
import 'package:openvine/widgets/video_editor/tune_editor/video_editor_tune_bottom_bar.dart';
import 'package:openvine/widgets/video_editor/tune_editor/video_editor_tune_overlay_controls.dart';

/// Duration for the timeline ↔ bottom-actions switch animation.
const _switchDuration = Duration(milliseconds: 240);

/// A scaffold widget that provides the standard layout for the video editor.
///
/// This widget arranges the video editor UI into three main sections:
/// - A main editor area that displays the video with proper aspect ratio
/// - Overlay controls positioned on top of the video
/// - A bottom bar for additional controls (e.g., timeline, tools)
class VideoEditorScaffold extends StatelessWidget {
  /// Creates a [VideoEditorScaffold].
  const VideoEditorScaffold({required this.isLoading, super.key});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: VideoEditorConstants.uiOverlayStyleFor(context.vineColors),
      child: Scaffold(
        backgroundColor: context.vineColors.surfaceContainerHigh,
        resizeToAvoidBottomInset: false,
        floatingActionButton: const _AddElementFab(),
        body: ClipEditorResultListeners(
          child: _ScaffoldBody(isLoading: isLoading),
        ),
      ),
    );
  }
}

class _ScaffoldBody extends StatelessWidget {
  const _ScaffoldBody({required this.isLoading});

  final bool isLoading;

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: .expand,
      clipBehavior: .none,
      children: [
        Column(
          children: [
            Expanded(
              child: Stack(
                fit: .expand,
                clipBehavior: .none,
                children: [
                  if (isLoading)
                    const BrandedLoadingScaffold()
                  else
                    const VideoEditorCanvas(),

                  const VideoEditorCaptionPreviewOverlay(),

                  const _OverlayControls(),
                ],
              ),
            ),
            const _TimelineSection(),
          ],
        ),

        const ClipOperationProgressOverlays(),
      ],
    );
  }
}

class _TimelineSection extends StatefulWidget {
  const _TimelineSection();

  @override
  State<_TimelineSection> createState() => _TimelineSectionState();
}

class _TimelineSectionState extends State<_TimelineSection>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final CurvedAnimation _animation;

  /// Collapses the whole section — timeline and bottom actions alike — while
  /// the canvas has the full screen (a slide point being placed, the voice-over
  /// recorder playing the preview behind its controls).
  late final AnimationController _collapseController;
  late final CurvedAnimation _collapseAnimation;

  static bool _shouldHide(SubEditorType? type) =>
      type == .draw || type == .filter || type == .tune;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: _switchDuration);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _collapseController = AnimationController(
      vsync: this,
      duration: _switchDuration,
    );
    _collapseAnimation = CurvedAnimation(
      parent: _collapseController,
      curve: Curves.easeInOut,
    );
  }

  @override
  void dispose() {
    _animation.dispose();
    _controller.dispose();
    _collapseAnimation.dispose();
    _collapseController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<VideoEditorMainBloc, VideoEditorMainState>(
          listenWhen: (prev, curr) =>
              _shouldHide(prev.openSubEditor) !=
              _shouldHide(curr.openSubEditor),
          listener: (context, state) {
            if (_shouldHide(state.openSubEditor)) {
              _controller.forward();
            } else {
              _controller.reverse();
            }
          },
        ),
        BlocListener<VideoEditorMainBloc, VideoEditorMainState>(
          listenWhen: (prev, curr) =>
              prev.isCanvasFullscreen != curr.isCanvasFullscreen,
          listener: (context, state) {
            if (state.isCanvasFullscreen) {
              _collapseController.forward();
            } else {
              _collapseController.reverse();
            }
          },
        ),
      ],
      child: SizeTransition(
        sizeFactor: ReverseAnimation(_collapseAnimation),
        alignment: AlignmentDirectional.topStart,
        child: ColoredBox(
          color: context.vineColors.surfaceContainerHigh,
          child: Column(
            mainAxisSize: .min,
            crossAxisAlignment: .stretch,
            children: [
              // Keep timeline always in tree to preserve thumbnail
              // cache. SizeTransition clips without unmounting.
              SizeTransition(
                sizeFactor: ReverseAnimation(_animation),
                alignment: AlignmentDirectional.topStart,
                child: const Padding(
                  padding: .only(top: 12),
                  child: VideoEditorTimelineScaffold(),
                ),
              ),
              SizeTransition(
                sizeFactor: _animation,
                alignment: AlignmentDirectional.topStart,
                child: const _BottomActions(),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _OverlayControls extends StatelessWidget {
  const _OverlayControls();

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<VideoEditorMainBloc, VideoEditorMainState>(
      buildWhen: (previous, current) =>
          previous.isLayerInteractionActive !=
              current.isLayerInteractionActive ||
          previous.openSubEditor != current.openSubEditor ||
          previous.isPlacingSlidePoint != current.isPlacingSlidePoint,
      builder: (context, state) => switch (state) {
        // The point picker brings its own toolbar and owns the whole screen.
        _ when state.isPlacingSlidePoint => const SizedBox.shrink(),
        _ when state.isLayerInteractionActive => const SizedBox(),
        // Text-Editor
        VideoEditorMainState(openSubEditor: .text) => const SizedBox.shrink(),
        // The voice-over recorder brings its own toolbar over the preview.
        VideoEditorMainState(openSubEditor: .voiceOver) =>
          const SizedBox.shrink(),
        // Draw-Editor
        VideoEditorMainState(openSubEditor: .draw) => const Padding(
          key: ValueKey('Draw-Overlay-Controls'),
          padding: .only(bottom: VideoEditorConstants.bottomBarHeight),
          child: VideoEditorDrawOverlayControls(),
        ),
        // Filter-Editor
        VideoEditorMainState(openSubEditor: .filter) => const Padding(
          key: ValueKey('Filter-Overlay-Controls'),
          padding: .only(bottom: VideoEditorConstants.bottomBarHeight),
          child: VideoEditorFilterOverlayControls(),
        ),
        // Tune-Editor
        VideoEditorMainState(openSubEditor: .tune) => const Padding(
          key: ValueKey('Tune-Overlay-Controls'),
          padding: .only(bottom: VideoEditorConstants.bottomBarHeight),
          child: VideoEditorTuneOverlayControls(),
        ),
        // Fallback
        _ => const VideoEditorMainOverlayActions(),
      },
    );
  }
}

/// Bottom section that switches between different toolbars based on context.
///
/// Only visible while the draw, filter or tune sub-editor is open. Otherwise
/// the timeline is shown instead (see [_TimelineSection]).
class _BottomActions extends StatelessWidget {
  const _BottomActions();

  @override
  Widget build(BuildContext context) {
    final systemNavigationBarHeight = MediaQuery.viewPaddingOf(context).bottom;
    final openSubEditor = context.select(
      (VideoEditorMainBloc b) => b.state.openSubEditor,
    );

    return SizedBox(
      height: systemNavigationBarHeight + VideoEditorConstants.bottomBarHeight,
      child: switch (openSubEditor) {
        // Draw-Bar
        SubEditorType.draw => const VideoEditorDrawBottomBar(
          key: ValueKey('Draw-Editor-Bottom-Bar'),
        ),
        // Filter-Bar
        SubEditorType.filter => Padding(
          padding: .only(bottom: systemNavigationBarHeight),
          child: const VideoEditorFilterBottomBar(
            key: ValueKey('Filter-Editor-Bottom-Bar'),
          ),
        ),
        // Tune-Bar
        SubEditorType.tune => Padding(
          padding: .only(bottom: systemNavigationBarHeight),
          child: const VideoEditorTuneBottomBar(
            key: ValueKey('Tune-Editor-Bottom-Bar'),
          ),
        ),
        // Fallback — should not happen since _BottomActions is only
        // rendered for draw/filter/tune, but handle gracefully.
        _ => const SizedBox.shrink(),
      },
    );
  }
}

/// Decides whether the FAB should be visible. Keeps the visibility check in
/// a dedicated widget so that [_AddElementFabContent] is only rebuilt when
/// it actually needs to render — not on every hide/show state change.
class _AddElementFab extends StatelessWidget {
  const _AddElementFab();

  @override
  Widget build(BuildContext context) {
    final shouldHide = context.select(
      (VideoEditorMainBloc b) =>
          b.state.isSubEditorOpen ||
          b.state.isTimelineHiddenByUser ||
          b.state.isMarkerMode,
    );
    final isOverlayInteracting = context.select(
      (TimelineOverlayBloc b) =>
          b.state.selectedItemId != null || b.state.isLayerMultiSelectMode,
    );
    final isClipInteracting = context.select(
      (ClipEditorBloc b) => b.state.isEditing || b.state.isMultiSelectMode,
    );

    if (shouldHide || isOverlayInteracting || isClipInteracting) {
      return const SizedBox.shrink();
    }

    return const _AddElementFabContent();
  }
}

class _AddElementFabContent extends StatelessWidget {
  const _AddElementFabContent();

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      label: context.l10n.videoEditorAddElementSemanticLabel,
      child: GestureDetector(
        onTap: () => VideoEditorMainActionsSheet.show(context),
        child: Container(
          width: 56,
          height: 56,
          decoration: ShapeDecoration(
            color: context.vineColors.surfaceContainer,
            shape: RoundedRectangleBorder(
              side: BorderSide(
                width: 2,
                color: context.vineColors.outlineMuted,
              ),
              borderRadius: .circular(24),
            ),
          ),
          child: Center(
            // Hand-rolled twin of `DivineIconButtonType.secondary`.
            child: DivineIcon(
              icon: .plus,
              color: context.vineColors.accentBrand,
            ),
          ),
        ),
      ),
    );
  }
}
