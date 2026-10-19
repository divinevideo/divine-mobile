// ABOUTME: Shows a smoother loop point on the last clip, plays the seam again
// ABOUTME: and again, and keeps it as one undo step or puts the end back.

import 'package:divine_ui/divine_ui.dart';
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
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_action_bar.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_geometry.dart';
import 'package:unified_logger/unified_logger.dart';

/// Whether [clip] is trimmed like [other]: the same clip, footage and trim.
bool _sameTrim(DivineVideoClip clip, DivineVideoClip other) =>
    clip.id == other.id &&
    clip.video?.file?.path == other.video?.file?.path &&
    clip.trimStart == other.trimStart &&
    clip.trimEnd == other.trimEnd;

/// What the bar says about the suggestion in [state].
String _suggestionText(BuildContext context, LoopSuggestionState state) {
  final original = state.original;
  final suggested = state.suggested;
  if (original == null || suggested == null) return '';
  final l10n = context.l10n;
  final shift = original.trimEnd - suggested.trimEnd;
  final seconds =
      (NumberFormat.decimalPattern(
              Localizations.localeOf(context).toString(),
            )
            ..minimumFractionDigits = 1
            ..maximumFractionDigits = 2)
          .format(
            shift.abs().inMicroseconds / Duration.microsecondsPerSecond,
          );
  final later = shift > Duration.zero;
  return switch ((state.isCloseMatch, later)) {
    (true, false) => l10n.videoEditorLoopFoundEarlier(seconds),
    (true, true) => l10n.videoEditorLoopFoundLater(seconds),
    (false, false) => l10n.videoEditorLoopClosestEarlier(seconds),
    (false, true) => l10n.videoEditorLoopClosestLater(seconds),
  };
}

/// The bar shown while a smoother loop point waits on the last clip: what
/// it changes, a way to keep it and a way to put the old end back.
class TimelineLoopSuggestionControls extends StatelessWidget {
  const TimelineLoopSuggestionControls({super.key});

  @override
  Widget build(BuildContext context) {
    final state = context.watch<LoopSuggestionCubit>().state;
    final l10n = context.l10n;
    return TimelineActionBar(
      countLabel: _suggestionText(context, state),
      actions: [
        TimelineActionButton(
          icon: .x,
          label: l10n.commonCancel,
          semanticLabel: l10n.videoEditorLoopDiscardSemanticLabel,
          onPressed: () => _discard(context),
        ),
        TimelineActionButton(
          icon: .check,
          label: l10n.videoEditorLoopKeepLabel,
          semanticLabel: l10n.videoEditorLoopKeepSemanticLabel,
          onPressed: () => _keep(context),
          type: .primary,
        ),
      ],
    );
  }

  /// Keeps the suggested end as one undo step.
  void _keep(BuildContext context) {
    final cubit = context.read<LoopSuggestionCubit>();
    final original = cubit.state.original;
    final suggested = cubit.state.suggested;
    final editor = VideoEditorScope.of(context).editor;
    final clipBloc = context.read<ClipEditorBloc>();
    final clips = clipBloc.state.clips;
    final index = original == null
        ? -1
        : clips.indexWhere((c) => c.id == original.id);
    if (original == null ||
        suggested == null ||
        index == -1 ||
        editor == null ||
        !editor.mounted) {
      cubit.resultHandled();
      return;
    }

    final clip = clips[index];
    final before = List.of(clips)
      ..[index] = clip.copyWith(
        trimStart: original.trimStart,
        trimEnd: original.trimEnd,
      );
    final after = List.of(clips)
      ..[index] = clip.copyWith(
        trimStart: suggested.trimStart,
        trimEnd: suggested.trimEnd,
      );
    // An undo while the suggestion showed put the old end back.
    if (!_sameTrim(clip, suggested)) {
      clipBloc.add(ClipEditorClipUpdated(clipId: clip.id, clip: after[index]));
    }
    final overlayBloc = context.read<TimelineOverlayBloc>();
    final markers = rebaseTimelineMarkersForClipState(
      oldClips: before,
      newClips: after,
      markers: overlayBloc.state.timelineMarkers,
    );
    overlayBloc.add(TimelineMarkersRebased(markers));
    editor.setLengthenedClipState(
      previousClips: before,
      clips: after,
      timelineMarkers: markers,
    );
    cubit.resultHandled();
  }

  /// Puts the end the clip had before back.
  void _discard(BuildContext context) {
    final cubit = context.read<LoopSuggestionCubit>();
    final original = cubit.state.original;
    final clipBloc = context.read<ClipEditorBloc>();
    final clip = original == null
        ? null
        : clipBloc.state.clips.where((c) => c.id == original.id).firstOrNull;
    if (original != null && clip != null && !_sameTrim(clip, original)) {
      clipBloc.add(
        ClipEditorClipUpdated(
          clipId: clip.id,
          clip: clip.copyWith(
            trimStart: original.trimStart,
            trimEnd: original.trimEnd,
          ),
        ),
      );
    }
    cubit.resultHandled();
  }
}

/// Shows what a loop point search found: puts a smoother end on the last
/// clip for the creator to watch, and says so when the video already loops
/// smoothly or the search failed.
///
/// Kept at the scaffold level, always mounted, so the result lands even
/// when the timeline controls changed while the search ran.
class LoopSuggestionResultListener extends StatelessWidget {
  const LoopSuggestionResultListener({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<LoopSuggestionCubit, LoopSuggestionState>(
          listenWhen: (previous, current) => previous.status != current.status,
          listener: _onResult,
        ),
        BlocListener<LoopSuggestionCubit, LoopSuggestionState>(
          listenWhen: (previous, current) =>
              previous.status == LoopSuggestionStatus.suggested &&
              current.status != LoopSuggestionStatus.suggested,
          listener: (context, _) => context.read<VideoEditorMainBloc>().add(
            const VideoEditorAuditionEnded(),
          ),
        ),
        BlocListener<ClipEditorBloc, ClipEditorState>(
          listenWhen: (previous, current) => previous.clips != current.clips,
          listener: _onClipsChanged,
        ),
      ],
      child: child,
    );
  }

  void _onResult(BuildContext context, LoopSuggestionState state) {
    final l10n = context.l10n;
    switch (state.status) {
      case LoopSuggestionStatus.suggested:
        _preview(context, state);
      case LoopSuggestionStatus.alreadySmooth:
        _report(context, l10n.videoEditorLoopAlreadySmooth);
      case LoopSuggestionStatus.noMatch:
        _report(context, l10n.videoEditorLoopNoMatch);
      case LoopSuggestionStatus.failed:
        _report(context, l10n.videoEditorLoopFailed);
      case LoopSuggestionStatus.idle || LoopSuggestionStatus.searching:
        break;
    }
  }

  void _report(BuildContext context, String message) {
    context.read<LoopSuggestionCubit>().resultHandled();
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(DivineSnackbarContainer.snackBar(message));
  }

  /// Puts the suggested end on the clip, without an undo step yet, and
  /// plays the seam until the creator keeps or drops it.
  void _preview(BuildContext context, LoopSuggestionState state) {
    final cubit = context.read<LoopSuggestionCubit>();
    final original = state.original;
    final suggested = state.suggested;
    final clipBloc = context.read<ClipEditorBloc>();
    final clips = clipBloc.state.clips;
    final index = original == null
        ? -1
        : clips.indexWhere((c) => c.id == original.id);
    // The clip was trimmed, moved or removed while the search ran; the
    // suggestion would undo that.
    if (original == null ||
        suggested == null ||
        index != clips.length - 1 ||
        !_sameTrim(clips[index], original)) {
      cubit.resultHandled();
      return;
    }

    final clip = clips[index].copyWith(
      trimStart: suggested.trimStart,
      trimEnd: suggested.trimEnd,
    );
    clipBloc.add(ClipEditorClipUpdated(clipId: clip.id, clip: clip));

    final end = compositionDuration(List.of(clips)..[index] = clip);
    const side = VideoEditorConstants.loopSeamPreviewSide;
    context.read<VideoEditorMainBloc>().add(
      end > side * 2
          ? VideoEditorAuditionStarted(start: end - side, end: side)
          : VideoEditorAuditionStarted(start: Duration.zero, end: end),
    );
    runDetached(
      SemanticsService.sendAnnouncement(
        View.of(context),
        _suggestionText(context, state),
        Directionality.of(context),
      ),
      'announce loop suggestion',
      logName: 'LoopSuggestionResultListener',
      category: LogCategory.ui,
    );
  }

  /// Drops the suggestion once the last clip was changed some other way,
  /// such as a trim by hand, so the bar never keeps or restores over it.
  void _onClipsChanged(BuildContext context, ClipEditorState clipState) {
    final cubit = context.read<LoopSuggestionCubit>();
    final state = cubit.state;
    final original = state.original;
    final suggested = state.suggested;
    if (state.status != LoopSuggestionStatus.suggested ||
        original == null ||
        suggested == null) {
      return;
    }
    final clip = clipState.clips.where((c) => c.id == original.id).firstOrNull;
    if (clip != null &&
        (_sameTrim(clip, suggested) || _sameTrim(clip, original))) {
      return;
    }
    cubit.resultHandled();
  }
}
