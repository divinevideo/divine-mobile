// ABOUTME: Applies a verified loop as one history edit, plays its seam after
// ABOUTME: player readiness, and presents cancellable progress and Undo.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/loop_suggestion/loop_suggestion_cubit.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/video_editor_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/composition_duration.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_geometry.dart';
import 'package:openvine/widgets/video_editor/video_editor_blocking_overlay.dart';
import 'package:unified_logger/unified_logger.dart';

/// Starts whole-composition loop alignment from the editing-tools drawer.
///
/// Does nothing once [context] has unmounted: the drawer can outlive the
/// tools bar that opened it, which leaves the tree whenever it is hidden.
void alignEditorLoop(BuildContext context) {
  if (!context.mounted) return;
  final clipState = context.read<ClipEditorBloc>().state;
  final main = context.read<VideoEditorMainBloc>().state;
  final editor = VideoEditorScope.of(context).editor;
  final listener = context
      .findAncestorStateOfType<_LoopRepairResultListenerState>();
  if (editor == null ||
      !editor.mounted ||
      clipState.hasPendingClipOperation ||
      clipState.isTrimDragging ||
      main.isSubEditorOpen ||
      main.isReordering ||
      (main.audition != null &&
          (!(listener?._ownsAudition ?? false) ||
              main.auditionOwner != listener?._auditionOwner))) {
    return;
  }
  listener?._endSeam();
  final overlays = context.read<TimelineOverlayBloc>().state;
  runDetached(
    context.read<LoopSuggestionCubit>().fix(
      editor.loopRepairInput(
        clipState.clips,
        audioTracks: overlays.audioTracks,
        timelineMarkers: overlays.timelineMarkers,
      ),
    ),
    'repair loop',
    logName: 'LoopRepair',
    category: LogCategory.video,
  );
}

class LoopRepairProgressOverlay extends StatelessWidget {
  const LoopRepairProgressOverlay({super.key});
  @override
  Widget build(BuildContext context) =>
      BlocBuilder<LoopSuggestionCubit, LoopSuggestionState>(
        builder: (context, state) {
          if (!state.isSearching) return const SizedBox.shrink();
          return VideoEditorBlockingOverlay(
            announcement: context.l10n.videoEditorLoopRepairProgress,
            child: Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                spacing: 24,
                children: [
                  Semantics(
                    label: context.l10n.videoEditorLoopRepairProgress,
                    value: NumberFormat.percentPattern(
                      Localizations.localeOf(context).toString(),
                    ).format(state.progress),
                    child: PartialCircleSpinner(progress: state.progress),
                  ),
                  Text(
                    context.l10n.videoEditorLoopRepairProgress,
                    style: VineTheme.bodyMediumFont(
                      color: context.vineColors.primaryText,
                    ),
                  ),
                  DivineButton(
                    type: DivineButtonType.secondary,
                    label: context.l10n.commonCancel,
                    onPressed: () =>
                        context.read<LoopSuggestionCubit>().cancel(),
                  ),
                ],
              ),
            ),
          );
        },
      );
}

class LoopRepairResultListener extends StatefulWidget {
  const LoopRepairResultListener({required this.child, super.key});
  final Widget child;
  @override
  State<LoopRepairResultListener> createState() =>
      _LoopRepairResultListenerState();
}

class _LoopRepairResultListenerState extends State<LoopRepairResultListener> {
  PlaybackAudition? _pendingAudition;
  List<DivineVideoClip>? _playingClips;
  bool _sawNotReady = false;
  bool _ownsAudition = false;
  String? _auditionOwner;

  @override
  Widget build(BuildContext context) => MultiBlocListener(
    listeners: [
      BlocListener<LoopSuggestionCubit, LoopSuggestionState>(
        listenWhen: (a, b) => a.status != b.status || a.taskId != b.taskId,
        listener: _onResult,
      ),
      BlocListener<ClipEditorBloc, ClipEditorState>(listener: _onClipState),
      BlocListener<TimelineOverlayBloc, TimelineOverlayState>(
        listener: (_, _) => _invalidate(),
      ),
      BlocListener<VideoEditorMainBloc, VideoEditorMainState>(
        listener: _onMainState,
      ),
    ],
    child: widget.child,
  );

  void _invalidate() {
    final cubit = context.read<LoopSuggestionCubit>();
    if (cubit.state.request == null) return;
    final editor = VideoEditorScope.of(context).editor;
    final clips = context.read<ClipEditorBloc>().state.clips;
    final overlays = context.read<TimelineOverlayBloc>().state;
    if (editor == null ||
        !editor.mounted ||
        !(ModalRoute.isCurrentOf(context) ?? true)) {
      cubit.compositionChanged('editor-inactive');
      return;
    }
    cubit.compositionChanged(
      editor
          .loopRepairInput(
            clips,
            audioTracks: overlays.audioTracks,
            timelineMarkers: overlays.timelineMarkers,
          )
          .revision,
    );
  }

  void _onResult(BuildContext context, LoopSuggestionState state) {
    final clips = context.read<ClipEditorBloc>();
    final cubit = context.read<LoopSuggestionCubit>();
    if (state.isSearching) {
      clips.add(const ClipEditorLoopRepairPendingChanged(true));
      return;
    }
    if (state.status == LoopSuggestionStatus.repaired) {
      _invalidate();
      if (!identical(cubit.state, state)) return;
      final result = state.result;
      if (result == null || state.taskId == null) return;
      final original = List<DivineVideoClip>.of(clips.state.clips);
      cubit.resultHandled();
      clips.add(
        ClipEditorLoopRepairApplied(
          expectedClips: original,
          result: result,
          operationId: state.taskId!,
        ),
      );
      return;
    }
    clips.add(const ClipEditorLoopRepairPendingChanged(false));
    final message = switch (state.status) {
      LoopSuggestionStatus.alreadySmooth =>
        context.l10n.videoEditorLoopAlreadySmooth,
      LoopSuggestionStatus.noMatch ||
      LoopSuggestionStatus.unsupported => context.l10n.videoEditorLoopNoMatch,
      LoopSuggestionStatus.failed ||
      LoopSuggestionStatus.timedOut => context.l10n.videoEditorLoopFailed,
      _ => null,
    };
    if (message != null) {
      cubit.resultHandled();
      _report(message);
    }
  }

  void _onClipState(BuildContext context, ClipEditorState state) {
    _invalidate();
    final result = state.lastLoopRepair;
    if (result != null && !identical(result, _lastApplication)) {
      _lastApplication = result;
      if (result is ClipLoopRepairSuccess) {
        _commit(result);
      } else {
        runDetached(
          context.read<LoopSuggestionCubit>().discard(result.repair),
          'discard unapplied loop',
          logName: 'LoopRepair',
          category: LogCategory.video,
        );
        if (result is ClipLoopRepairFailure) {
          _report(context.l10n.videoEditorLoopFailed);
        }
      }
    }
    if (_playingClips != null && !listEquals(state.clips, _playingClips)) {
      _endSeam();
    }
  }

  ClipLoopRepairResult? _lastApplication;

  void _commit(ClipLoopRepairSuccess result) {
    final editor = VideoEditorScope.of(context).editor;
    if (editor == null || !editor.mounted) return;
    final overlay = context.read<TimelineOverlayBloc>();
    final markers = rebaseTimelineMarkersForClipState(
      oldClips: result.before,
      newClips: result.after,
      markers: overlay.state.timelineMarkers,
    );
    editor.setLengthenedClipState(
      previousClips: result.before,
      clips: result.after,
      timelineMarkers: markers,
      replacedClipIds: {for (final clip in result.after) clip.id},
    );
    overlay.add(TimelineMarkersRebased(markers));
    overlay.add(
      TimelineOverlayTotalDurationChanged(compositionDuration(result.after)),
    );
    final duration = compositionDuration(result.after);
    const side = VideoEditorConstants.loopSeamPreviewSide;
    _playingClips = result.after;
    _auditionOwner = result.operationId;
    _pendingAudition = duration > side * 2
        ? (start: duration - side, end: side)
        : (start: Duration.zero, end: duration);
    _sawNotReady = !context.read<VideoEditorMainBloc>().state.isPlayerReady;
    final previousDuration = compositionDuration(result.before);
    final previousExportDuration =
        previousDuration > VideoEditorConstants.maxDuration
        ? VideoEditorConstants.maxDuration
        : previousDuration;
    final removed = previousExportDuration - duration;
    final message = removed > Duration.zero
        ? context.l10n.videoEditorLoopRepairTrimmed(
            NumberFormat(
              '0.##',
              Localizations.localeOf(context).toString(),
            ).format(removed.inMicroseconds / Duration.microsecondsPerSecond),
          )
        : context.l10n.videoEditorLoopRepairSmoothed;
    _report(message, undo: true);
  }

  void _onMainState(BuildContext context, VideoEditorMainState state) {
    if (_ownsAudition &&
        state.audition != null &&
        state.auditionOwner != _auditionOwner) {
      _ownsAudition = false;
      _playingClips = null;
      _auditionOwner = null;
    }
    if (state.isSubEditorOpen ||
        state.isReordering ||
        !(ModalRoute.isCurrentOf(context) ?? true)) {
      context.read<LoopSuggestionCubit>().compositionChanged('editor-inactive');
      _endSeam();
      return;
    }
    if (!state.isPlayerReady) _sawNotReady = true;
    final audition = _pendingAudition;
    if (audition == null || !state.isPlayerReady || !_sawNotReady) return;
    _pendingAudition = null;
    _ownsAudition = true;
    context.read<VideoEditorMainBloc>().add(
      VideoEditorAuditionStarted(
        start: audition.start,
        end: audition.end,
        owner: _auditionOwner,
      ),
    );
  }

  void _endSeam() {
    _pendingAudition = null;
    _playingClips = null;
    if (!_ownsAudition) return;
    _ownsAudition = false;
    context.read<VideoEditorMainBloc>().add(
      VideoEditorAuditionEnded(owner: _auditionOwner),
    );
    _auditionOwner = null;
  }

  void _report(String message, {bool undo = false}) {
    runDetached(
      SemanticsService.sendAnnouncement(
        View.of(context),
        message,
        Directionality.of(context),
      ),
      'announce loop repair',
      logName: 'LoopRepair',
      category: LogCategory.ui,
    );
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        action: undo
            ? SnackBarAction(
                label: context.l10n.videoEditorUndoSemanticLabel,
                onPressed: () {
                  _endSeam();
                  VideoEditorScope.of(context).editor?.undoAction();
                },
              )
            : null,
      ),
    );
  }
}
