import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_timeline_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_clip_strip.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/strips/video_editor_timeline_overlay_strip.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_body.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_markers.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_playhead.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_volume.dart';

/// Interactive layer of the timeline: the horizontally-scrollable body, the
/// volume-edit overlay, the markers, and the fixed playhead.
///
/// All gesture/scroll state lives in the enclosing timeline `State`; this
/// widget only wires the passed-in callbacks and controllers to the visuals.
class VideoEditorTimelineInteractiveBody extends StatelessWidget {
  const VideoEditorTimelineInteractiveBody({
    required this.playheadPosition,
    required this.totalDuration,
    required this.formatPosition,
    required this.onStepPosition,
    required this.onPointerDown,
    required this.onPointerMove,
    required this.onPointerUp,
    required this.onPointerCancel,
    required this.onScrollNotification,
    required this.scrollController,
    required this.isPinching,
    required this.isTrimming,
    required this.halfScreen,
    required this.pixelsPerSecond,
    required this.clips,
    required this.totalWidth,
    required this.isInteracting,
    required this.onReorder,
    required this.onReorderChanged,
    required this.trimmingClipId,
    required this.onTrimChanged,
    required this.onTrimDragChanged,
    required this.onClipTapped,
    required this.isMultiSelectMode,
    required this.selectedClipIds,
    required this.onOverlayItemMoved,
    required this.onOverlayItemMoving,
    required this.onOverlayItemTrimmed,
    required this.onOverlayTrimDragChanged,
    required this.onOverlayItemTapped,
    required this.onOverlayDragStarted,
    required this.onOverlayDragEnded,
    required this.verticalScrollController,
    required this.overlayStripsScrollController,
    required this.volumePreviewNotifier,
    super.key,
  });

  final ValueNotifier<Duration> playheadPosition;
  final Duration totalDuration;
  final String Function(Duration) formatPosition;
  final void Function(Duration, Duration, Duration) onStepPosition;
  final PointerDownEventListener onPointerDown;
  final PointerMoveEventListener onPointerMove;
  final PointerUpEventListener onPointerUp;
  final PointerCancelEventListener onPointerCancel;
  final bool Function(ScrollNotification) onScrollNotification;
  final ScrollController scrollController;
  final bool isPinching;
  final bool isTrimming;
  final double halfScreen;
  final double pixelsPerSecond;
  final List<DivineVideoClip> clips;
  final double totalWidth;
  final bool isInteracting;
  final void Function(List<DivineVideoClip>) onReorder;
  final ValueChanged<bool> onReorderChanged;
  final String? trimmingClipId;
  final ClipTrimCallback onTrimChanged;
  final ValueChanged<bool> onTrimDragChanged;
  final ValueChanged<int> onClipTapped;
  final bool isMultiSelectMode;
  final Set<String> selectedClipIds;
  final OverlayMoveCallback onOverlayItemMoved;
  final OverlayMovingCallback onOverlayItemMoving;
  final OverlayTrimCallback onOverlayItemTrimmed;
  final ValueChanged<bool> onOverlayTrimDragChanged;
  final ValueChanged<TimelineOverlayItem> onOverlayItemTapped;
  final ValueChanged<TimelineOverlayItem> onOverlayDragStarted;
  final VoidCallback onOverlayDragEnded;
  final ScrollController verticalScrollController;
  final ScrollController overlayStripsScrollController;
  final ValueNotifier<double?> volumePreviewNotifier;

  static const _scrollBottomPadding = 100;

  @override
  Widget build(BuildContext context) {
    final isVolumeEditMode = context.select(
      (VideoEditorMainBloc b) => b.state.isVolumeEditMode,
    );
    final soundItemCount = context.select(
      (TimelineOverlayBloc b) => b.state.items
          .where((i) => i.type == TimelineOverlayType.sound)
          .length,
    );
    final rawVolumeContentHeight =
        TimelineConstants.rulerHeight +
        4 +
        clips.length *
            (TimelineConstants.thumbnailStripHeight +
                TimelineConstants.thumbnailVerticalRowGap) -
        TimelineConstants.thumbnailVerticalRowGap +
        4 +
        TimelineConstants.overlayStripGap +
        soundItemCount * TimelineConstants.soundOverlayRowHeight;
    final volumeContentHeight =
        rawVolumeContentHeight > TimelineConstants.height
        ? rawVolumeContentHeight
        : TimelineConstants.height;

    return Stack(
      fit: .expand,
      children: [
        SingleChildScrollView(
          controller: verticalScrollController,
          physics: isVolumeEditMode
              ? const ClampingScrollPhysics()
              : const NeverScrollableScrollPhysics(),
          padding: .only(
            bottom: _scrollBottomPadding + MediaQuery.paddingOf(context).bottom,
          ),
          child: ClipRect(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 250),
              curve: Curves.easeInOut,
              height: isVolumeEditMode
                  ? volumeContentHeight
                  : TimelineConstants.height,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  ValueListenableBuilder<Duration>(
                    valueListenable: playheadPosition,
                    builder: (context, position, child) {
                      final increased = Duration(
                        milliseconds: (position + const Duration(seconds: 1))
                            .inMilliseconds
                            .clamp(0, totalDuration.inMilliseconds),
                      );
                      final decreased = Duration(
                        milliseconds: (position - const Duration(seconds: 1))
                            .inMilliseconds
                            .clamp(0, totalDuration.inMilliseconds),
                      );
                      return Semantics(
                        label:
                            context.l10n.videoEditorVideoTimelineSemanticLabel,
                        slider: true,
                        value: formatPosition(position),
                        increasedValue: formatPosition(increased),
                        decreasedValue: formatPosition(decreased),
                        onIncrease: () => onStepPosition(
                          position,
                          totalDuration,
                          const Duration(seconds: 1),
                        ),
                        onDecrease: () => onStepPosition(
                          position,
                          totalDuration,
                          const Duration(seconds: -1),
                        ),
                        child: child ?? const SizedBox.shrink(),
                      );
                    },
                    child: Listener(
                      onPointerDown: onPointerDown,
                      onPointerMove: onPointerMove,
                      onPointerUp: onPointerUp,
                      onPointerCancel: onPointerCancel,
                      child: NotificationListener<ScrollNotification>(
                        onNotification: onScrollNotification,
                        child: SingleChildScrollView(
                          controller: scrollController,
                          scrollDirection: Axis.horizontal,
                          physics: isPinching || isTrimming
                              ? const NeverScrollableScrollPhysics()
                              : const ClampingScrollPhysics(),
                          clipBehavior: .none,
                          padding: .symmetric(horizontal: halfScreen),
                          child: VideoEditorTimelineBody(
                            totalDuration: totalDuration,
                            pixelsPerSecond: pixelsPerSecond,
                            scrollController: scrollController,
                            overlayStripsScrollController:
                                overlayStripsScrollController,
                            scrollPadding: halfScreen,
                            clips: clips,
                            totalWidth: totalWidth,
                            isInteracting: isInteracting,
                            onReorder: onReorder,
                            onReorderChanged: onReorderChanged,
                            trimmingClipId: trimmingClipId,
                            onTrimChanged: onTrimChanged,
                            onTrimDragChanged: onTrimDragChanged,
                            onClipTapped: isVolumeEditMode
                                ? null
                                : onClipTapped,
                            isMultiSelectMode: isMultiSelectMode,
                            selectedClipIds: selectedClipIds,
                            onOverlayItemMoved: onOverlayItemMoved,
                            onOverlayItemMoving: onOverlayItemMoving,
                            onOverlayItemTrimmed: onOverlayItemTrimmed,
                            onOverlayTrimDragChanged: onOverlayTrimDragChanged,
                            onOverlayItemTapped: isVolumeEditMode
                                ? null
                                : onOverlayItemTapped,
                            onOverlayDragStarted: onOverlayDragStarted,
                            onOverlayDragEnded: onOverlayDragEnded,
                            playheadPosition: playheadPosition,
                          ),
                        ),
                      ),
                    ),
                  ),
                  Positioned(
                    left: 0,
                    top: 0,
                    child: ClipRect(
                      child: AnimatedSwitcher(
                        duration: const Duration(milliseconds: 220),
                        transitionBuilder: (child, animation) =>
                            SlideTransition(
                              position:
                                  Tween<Offset>(
                                    begin: const Offset(-1.0, 0.0),
                                    end: Offset.zero,
                                  ).animate(
                                    CurvedAnimation(
                                      parent: animation,
                                      curve: Curves.easeInOut,
                                    ),
                                  ),
                              child: child,
                            ),
                        layoutBuilder: (currentChild, previousChildren) =>
                            Stack(
                              alignment: Alignment.centerLeft,
                              children: <Widget>[
                                ...previousChildren,
                                ?currentChild,
                              ],
                            ),
                        child: isVolumeEditMode
                            ? VideoEditorTimelineVolume(
                                key: const ValueKey('volume'),
                                volumePreviewNotifier: volumePreviewNotifier,
                              )
                            : const SizedBox.shrink(key: ValueKey('empty')),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        VideoEditorTimelineMarkers(
          scrollController: scrollController,
          scrollPadding: halfScreen,
          pixelsPerSecond: pixelsPerSecond,
        ),
        const VideoEditorTimelinePlayhead(),
      ],
    );
  }
}
