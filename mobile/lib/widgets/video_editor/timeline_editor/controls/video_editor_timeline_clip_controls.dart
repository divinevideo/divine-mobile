import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/extensions/video_editor_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/screens/video_editor/video_clip_chroma_key_screen.dart';
import 'package:openvine/screens/video_editor/video_clip_transform_screen.dart';
import 'package:openvine/services/video_editor/clip_placeholder_render_service.dart';
import 'package:openvine/services/video_editor/video_editor_split_service.dart';
import 'package:openvine/utils/image_orientation.dart';
import 'package:openvine/utils/path_resolver.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/stop_motion/stop_motion_frame_commands.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_clip_speed_sheet.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_detach_clip_sheet.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_controls.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_geometry.dart';
import 'package:openvine/widgets/video_editor/video_editor_color_picker_sheet.dart';
import 'package:path/path.dart' as p;
import 'package:pro_image_editor/pro_image_editor.dart'
    show ProImageEditorState;
import 'package:pro_video_editor/pro_video_editor.dart' show ExportTransform;
import 'package:unified_logger/unified_logger.dart';

/// Controls shown when a clip is in editing mode: Delete, Copy, Split, Done.
class TimelineClipControls extends StatefulWidget {
  const TimelineClipControls({required this.playheadPosition, super.key});

  final ValueNotifier<Duration> playheadPosition;

  @override
  State<TimelineClipControls> createState() => _TimelineClipControlsState();
}

class _TimelineClipControlsState extends State<TimelineClipControls> {
  @override
  Widget build(BuildContext context) {
    // Frames-only stop-motion clips get a frame-first action set: delete /
    // duplicate / multi-select stills, adjust their hold, transform the
    // selected still. Clip-only actions (split, speed, reverse, extract audio)
    // don't apply to a still sequence and are hidden.
    final isStopMotion = context.select((ClipEditorBloc b) {
      final state = b.state;
      final index = state.currentClipIndex;
      return index >= 0 &&
          index < state.clips.length &&
          state.clips[index].isStopMotion;
    });
    if (isStopMotion) return const _StopMotionClipControls();

    final (
      clipCount,
      isExtractingAudioCurrentClip,
      isSplittingCurrentClip,
      isSavingCurrentClipToLibrary,
      isSavingAnyClipToLibrary,
      isReversed,
      isChromaKeyingCurrentClip,
      hasChromaKey,
      isDetachingCurrentClip,
      isPlaceholderClip,
    ) = context.select((ClipEditorBloc b) {
      final state = b.state;
      final index = state.currentClipIndex;
      final hasClip = index >= 0 && index < state.clips.length;
      final currentClipId = hasClip ? state.clips[index].id : null;
      // Split and Speed are only disabled when the in-flight operation targets
      // *this* clip. A split or audio extraction rendering on a different clip
      // (the user can switch clips mid-render) leaves the current clip's
      // actions available.
      //
      // Save is the exception: a library re-encode is a heavy render we run one
      // at a time, so it is disabled on every clip while any save runs. Only
      // the in-flight clip shows a spinner; the rest show a plain disabled
      // button, so a tap on another clip's Save can never be silently dropped.
      return (
        state.clips.length,
        state.isExtractingAudio &&
            currentClipId != null &&
            state.extractingAudioClipId == currentClipId,
        state.isSplitting &&
            currentClipId != null &&
            state.splittingClipId == currentClipId,
        state.isSavingClipToLibrary &&
            currentClipId != null &&
            state.savingClipToLibraryClipId == currentClipId,
        state.isSavingClipToLibrary,
        hasClip && state.clips[index].reversed,
        state.isChromaKeying &&
            currentClipId != null &&
            state.chromaKeyingClipId == currentClipId,
        hasClip && state.clips[index].chromaKey != null,
        state.isDetaching &&
            currentClipId != null &&
            state.detachingClipId == currentClipId,
        hasClip && state.clips[index].isPlaceholder,
      );
    });
    final isLastClip = clipCount <= 1;

    // A colour or photo standing in for a detached clip is a backdrop, not
    // footage. Splitting, reversing, speeding up or extracting audio from a
    // still are all no-ops dressed as actions, so the only thing offered is
    // removing it — and not even that while it is the composition's last clip.
    if (isPlaceholderClip) {
      return VideoEditorTimelineControls(
        onDelete: isLastClip ? null : () => _deleteClip(context),
        onDone: () => context.read<ClipEditorBloc>().add(
          const ClipEditorEditingStopped(),
        ),
      );
    }

    return VideoEditorTimelineControls(
      onDelete: isLastClip ? null : () => _deleteClip(context),
      onDuplicated: () => _duplicateClip(context),
      // Split/Speed stay mounted and are shown disabled (not removed) while
      // busy, so the control set doesn't visibly reshuffle mid-operation.
      onSplit: () => _splitClip(context),
      onDetach: () => _detachClip(context),
      isDetaching: isDetachingCurrentClip,
      onSpeed: () => _setPlaybackSpeed(context),
      isSplitting: isSplittingCurrentClip,
      onTransform: () => _transformClip(context),
      onChromaKey: () => _editChromaKey(context),
      isChromaKeying: isChromaKeyingCurrentClip,
      hasChromaKey: hasChromaKey,
      onExtractAudio: () => _requestExtractAudio(context),
      onReversed: () => _reverseClip(context),
      onSaveToLibrary: () => _saveClipToLibrary(context),
      isSavingToLibrary: isSavingCurrentClipToLibrary,
      isSaveToLibraryDisabled: isSavingAnyClipToLibrary,
      onMultiSelect: isLastClip ? null : () => _startMultiSelect(context),
      isReversed: isReversed,
      isExtractingAudio: isExtractingAudioCurrentClip,
      // Done stays enabled during a render: leaving edit mode is safe because
      // the extraction/split success/failure side effect is handled by an
      // editor-session-level listener in [VideoEditorScaffold], so it survives
      // even after these controls unmount.
      onDone: () {
        context.read<ClipEditorBloc>().add(const ClipEditorEditingStopped());
      },
    );
  }

  /// The editor backing these controls, or `null` if it has been torn down.
  ///
  /// A gesture can resolve after the editor route is popped (e.g. rapid
  /// editor <-> clips navigation), leaving the [ProImageEditorState]
  /// unmounted. Handlers must bail on `null` rather than force-unwrapping,
  /// which is a release-mode crash.
  ProImageEditorState? _editorOrNull(BuildContext context) =>
      VideoEditorScope.of(context).editor;

  Future<void> _transformClip(BuildContext context) async {
    final bloc = context.read<ClipEditorBloc>();
    final state = bloc.state;
    if (state.currentClipIndex < 0 ||
        state.currentClipIndex >= state.clips.length) {
      return;
    }
    final clip = state.clips[state.currentClipIndex];

    final transform = await Navigator.of(context).push<ExportTransform>(
      PageRouteBuilder<ExportTransform>(
        settings: const RouteSettings(name: 'video_clip_transform'),
        opaque: false,
        barrierColor: context.vineColors.surfaceContainerHigh,
        pageBuilder: (_, _, _) => VideoClipTransformScreen(clip: clip),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );

    if (transform == null || transform.isEmpty || !context.mounted) return;

    // Bake the transform into a new clip file immediately; the bloc renders
    // and swaps the clip's video, the canvas reloads the player, and
    // onFinalClipInvalidated commits the change to the editor history.
    bloc.add(
      ClipEditorClipTransformRequested(clipId: clip.id, transform: transform),
    );
  }

  Future<void> _editChromaKey(BuildContext context) async {
    final bloc = context.read<ClipEditorBloc>();
    final state = bloc.state;
    if (state.currentClipIndex < 0 ||
        state.currentClipIndex >= state.clips.length) {
      return;
    }
    final clip = state.clips[state.currentClipIndex];

    // The screen dispatches the bake itself and stays open until the render
    // lands, so it needs the bloc — a pushed route sits outside this subtree
    // and would not otherwise find it. Nothing comes back through the pop.
    await Navigator.of(context).push<void>(
      PageRouteBuilder<void>(
        settings: const RouteSettings(name: 'video_clip_chroma_key'),
        opaque: false,
        barrierColor: VineTheme.backgroundCamera,
        pageBuilder: (_, _, _) => BlocProvider<ClipEditorBloc>.value(
          value: bloc,
          child: VideoClipChromaKeyScreen(clip: clip),
        ),
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
      ),
    );
  }

  /// Lifts the selected clip off the timeline and onto the canvas.
  ///
  /// Asks first what takes its place, because the answer changes the
  /// composition either way: closing the gap shortens it, a still keeps its
  /// length. The bloc does the rest — the placeholder render and the clip-list
  /// change — and `_ClipDetachResultListener` in the scaffold adds the layer,
  /// so the work survives these controls unmounting mid-render.
  Future<void> _detachClip(BuildContext context) async {
    final bloc = context.read<ClipEditorBloc>();
    final state = bloc.state;
    if (state.currentClipIndex < 0 ||
        state.currentClipIndex >= state.clips.length) {
      return;
    }
    final clip = state.clips[state.currentClipIndex];

    final choice = await showDetachClipSheet(
      context,
      // The composition needs a track. Detaching the only clip is fine, but
      // only if something stays behind in its place.
      canRemoveSlot: state.clips.length > 1,
    );
    if (choice == null || !context.mounted) return;

    final fill = switch (choice) {
      DetachClipChoice.removeSlot => null,
      DetachClipChoice.color => await _pickColorFill(),
      DetachClipChoice.image => await _pickImageFill(),
    };
    // A dismissed colour picker or camera cancels the whole detach: the user
    // chose to keep the slot and then did not say with what.
    if (choice != DetachClipChoice.removeSlot && fill == null) return;
    if (bloc.isClosed) {
      await _deleteUnusedImageFill(fill);
      return;
    }

    bloc.add(ClipEditorClipDetachRequested(clipId: clip.id, replacement: fill));
  }

  Future<ClipPlaceholderFill?> _pickColorFill() async {
    if (!mounted) return null;
    final picked = await showFullColorPicker(
      context,
      initialColor: VineTheme.surfaceBackground,
    );
    return picked == null ? null : ClipPlaceholderColorFill(picked);
  }

  /// Shoots the still that holds the detached clip's place.
  ///
  /// Camera only, matching the green-screen backdrop: the gallery is a route
  /// for AI-generated imagery to enter a Divine video, and a still the user
  /// photographs on the spot cannot be one.
  Future<ClipPlaceholderFill?> _pickImageFill() async {
    try {
      final picked = await ImagePicker().pickImage(source: ImageSource.camera);
      if (picked == null) return null;

      // Bake the EXIF rotation in off the UI isolate: the renderer reads raw
      // pixels, so a phone held sideways would otherwise fill the slot with a
      // rotated still.
      final bytes = await compute(
        bakeImageOrientation,
        await File(picked.path).readAsBytes(),
      );
      final documentsPath = await getDocumentsPath();
      final target = p.join(
        documentsPath,
        'clip_placeholder_${DateTime.now().microsecondsSinceEpoch}.png',
      );
      await File(target).writeAsBytes(bytes, flush: true);
      return ClipPlaceholderImageFill(target);
    } catch (error, stackTrace) {
      Log.error(
        'Failed to capture the detach placeholder photo',
        name: 'TimelineClipControls',
        category: LogCategory.video,
        error: error,
        stackTrace: stackTrace,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.videoEditorDetachImagePickFailed,
          ),
        );
      }
      return null;
    }
  }

  Future<void> _deleteUnusedImageFill(ClipPlaceholderFill? fill) async {
    if (fill is! ClipPlaceholderImageFill) return;
    try {
      final file = File(fill.imagePath);
      if (file.existsSync()) await file.delete();
    } catch (error) {
      Log.warning(
        '⚠️ Failed to delete unused detach placeholder ${fill.imagePath}: '
        '$error',
        name: 'TimelineClipControls',
        category: LogCategory.video,
      );
    }
  }

  void _reverseClip(BuildContext context) {
    final bloc = context.read<ClipEditorBloc>();
    final state = bloc.state;
    if (state.currentClipIndex < 0 ||
        state.currentClipIndex >= state.clips.length) {
      return;
    }
    final clip = state.clips[state.currentClipIndex];
    bloc.add(ClipEditorClipReverseRequested(clipId: clip.id));
  }

  Future<void> _setPlaybackSpeed(BuildContext context) async {
    final bloc = context.read<ClipEditorBloc>();
    final overlayBloc = context.read<TimelineOverlayBloc>();
    final state = bloc.state;
    if (state.currentClipIndex < 0 ||
        state.currentClipIndex >= state.clips.length) {
      return;
    }
    final clip = state.clips[state.currentClipIndex];
    final editor = _editorOrNull(context);
    if (editor == null) return;

    final result = await VineBottomSheet.show<double>(
      context: context,
      expanded: false,
      scrollable: false,
      isScrollControlled: true,
      body: VideoEditorClipSpeedSheet(initialSpeed: clip.playbackSpeed ?? 1.0),
    );

    if (result == null || !mounted) return;

    // Re-read state after the async gap: the clip list may have changed while
    // the sheet was open — e.g. an audio extraction on another clip finished
    // and muted it, or a reverse/transform render completed. Rebuild from the
    // current clips (and apply the speed on top of the current clip version)
    // so this change doesn't clobber those concurrent mutations.
    final currentClips = bloc.state.clips;
    final index = currentClips.indexWhere((c) => c.id == clip.id);
    if (index == -1) return;

    final updated = currentClips[index].copyWith(playbackSpeed: result);
    final newClips = List.of(currentClips)..[index] = updated;
    // A speed change rescales the clip's playbackDuration, shifting every
    // later clip — rebase markers by source position so they follow.
    final rebasedMarkers = rebaseTimelineMarkersForClipState(
      oldClips: currentClips,
      newClips: newClips,
      markers: overlayBloc.state.timelineMarkers,
    );

    bloc.add(ClipEditorClipUpdated(clipId: clip.id, clip: updated));
    overlayBloc.add(TimelineMarkersRebased(rebasedMarkers));

    // Slowing a clip down lengthens the composition, so a sound that covered
    // the old end has to grow with it (#6401); a speed-up passes through
    // unchanged.
    editor.setLengthenedClipState(
      previousClips: currentClips,
      clips: newClips,
      timelineMarkers: rebasedMarkers,
    );
  }

  void _requestExtractAudio(BuildContext context) {
    final bloc = context.read<ClipEditorBloc>();
    final state = bloc.state;
    if (state.currentClipIndex < 0 ||
        state.currentClipIndex >= state.clips.length) {
      return;
    }
    // Bind the request to this clip so a queued extraction (sequential handler)
    // still targets the right clip even if the selection changes meanwhile.
    bloc.add(
      ClipEditorAudioExtractionRequested(
        clipId: state.clips[state.currentClipIndex].id,
        clipTitle: context.l10n.videoEditorClipAudioTitle,
      ),
    );
  }

  Future<void> _saveClipToLibrary(BuildContext context) async {
    final bloc = context.read<ClipEditorBloc>();
    final state = bloc.state;
    if (state.currentClipIndex < 0 ||
        state.currentClipIndex >= state.clips.length) {
      return;
    }
    final clipId = state.clips[state.currentClipIndex].id;

    // Whatever sits over the clip — text, stickers, drawings, filters, tune,
    // blur — has to be baked in too, so the saved clip looks the way it looks
    // on the timeline. Only the editor holds that state, and it hands it over
    // in CompleteParameters solely on Done, so capture it here; the BLoC then
    // windows it down to this clip's slice of the timeline.
    //
    // No editor means the route is already gone (a gesture that resolved after
    // the pop). Bail rather than save the bare video: a clip silently missing
    // the text and filters the user was looking at is worse than no clip.
    final editor = _editorOrNull(context);
    if (editor == null) return;
    final overlays = await editor.captureOverlaySnapshot();

    // Capturing the snapshot rasterizes every layer and costs at least a frame,
    // during which the editor screen can be popped and its bloc closed. Adding
    // to a closed bloc throws, so bail. Guard on the bloc rather than `mounted`:
    // leaving edit mode unmounts these controls while the bloc lives on, and
    // that save should still go through (the scaffold-level listener surfaces
    // its result).
    if (bloc.isClosed) return;

    bloc.add(
      // Bind the request to this clip so the render still targets the intended
      // clip even if the selection changes while it runs.
      ClipEditorSaveClipToLibraryRequested(clipId: clipId, overlays: overlays),
    );
  }

  void _startMultiSelect(BuildContext context) {
    final bloc = context.read<ClipEditorBloc>();
    final state = bloc.state;
    if (state.currentClipIndex < 0 ||
        state.currentClipIndex >= state.clips.length) {
      return;
    }
    bloc.add(
      ClipEditorMultiSelectStarted(state.clips[state.currentClipIndex].id),
    );
  }

  void _deleteClip(BuildContext context) {
    final bloc = context.read<ClipEditorBloc>();
    final overlayBloc = context.read<TimelineOverlayBloc>();
    final state = bloc.state;
    final clipId = state.clips[state.currentClipIndex].id;
    final editor = _editorOrNull(context);
    if (editor == null) return;

    final newClips = state.clips.where((clip) => clip.id != clipId).toList();
    // Markers on the removed clip are dropped; markers on later clips shift
    // earlier — rebase by source position so both rules are honoured.
    final rebasedMarkers = rebaseTimelineMarkersForClipState(
      oldClips: state.clips,
      newClips: newClips,
      markers: overlayBloc.state.timelineMarkers,
    );

    bloc.add(ClipEditorClipRemoved(clipId));

    if (state.currentClipIndex >= state.clips.length - 1) {
      bloc.add(ClipEditorClipSelected(state.clips.length - 2));
    }
    bloc.add(const ClipEditorEditingStopped());

    overlayBloc.add(TimelineMarkersRebased(rebasedMarkers));
    editor.setClipState(newClips, timelineMarkers: rebasedMarkers);
  }

  void _duplicateClip(BuildContext context) {
    final bloc = context.read<ClipEditorBloc>();
    final overlayBloc = context.read<TimelineOverlayBloc>();
    final state = bloc.state;
    final clip = state.clips[state.currentClipIndex];
    final editor = _editorOrNull(context);
    if (editor == null) return;

    final copy = clip.copyWith(
      id:
          '${clip.id}_copy_'
          '${DateTime.now().millisecondsSinceEpoch}',
    );

    // The copy lands directly after its source rather than at the end of the
    // timeline, matching the stop-motion frame duplicate and letting the user
    // build a repeat without dragging the copy back into place.
    final insertIndex = state.currentClipIndex + 1;
    final newClips = [...state.clips]..insert(insertIndex, copy);
    // Markers strictly inside the source and earlier clips keep their
    // positions; markers on later clips shift right by the copy's duration,
    // as does one sitting exactly on the source's trailing seam, which
    // anchors to the following clip. The id-based rebase carries both, and
    // persists them in the same history entry as the clip change.
    final rebasedMarkers = rebaseTimelineMarkersForClipState(
      oldClips: state.clips,
      newClips: newClips,
      markers: overlayBloc.state.timelineMarkers,
    );

    bloc
      ..add(ClipEditorClipInserted(index: insertIndex, clip: copy))
      ..add(const ClipEditorEditingStopped());

    overlayBloc.add(TimelineMarkersRebased(rebasedMarkers));
    // The copy lengthens the composition, so a sound that covered the old end
    // has to grow with it (#6401).
    editor.setLengthenedClipState(
      previousClips: state.clips,
      clips: newClips,
      timelineMarkers: rebasedMarkers,
    );
  }

  void _splitClip(BuildContext context) {
    final bloc = context.read<ClipEditorBloc>();
    final state = bloc.state;
    if (state.currentClipIndex >= state.clips.length) return;

    final selectedClip = state.clips[state.currentClipIndex];

    // The playhead is in playback time; preceding clips must be accumulated
    // with playbackDuration (not trimmedDuration) to stay in the same
    // coordinate space.
    final globalPosition = widget.playheadPosition.value;
    var clipStart = Duration.zero;
    for (var i = 0; i < state.currentClipIndex; i++) {
      clipStart += state.clips[i].playbackDuration;
    }
    final localPlaybackPosition = globalPosition - clipStart;

    // Bounds-check in playback time.
    if (localPlaybackPosition < Duration.zero ||
        localPlaybackPosition > selectedClip.playbackDuration) {
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.videoEditorSplitPlayheadOutsideClip,
        ),
      );
      return;
    }

    // The split service and bloc expect a source-time offset relative to
    // trimmedDuration.  Convert: source = playback × speed
    // (since playbackDuration = trimmedDuration / speed).
    final speed = selectedClip.playbackSpeed ?? 1.0;
    final localPosition = speed == 1.0
        ? localPlaybackPosition
        : Duration(
            microseconds: (localPlaybackPosition.inMicroseconds * speed)
                .round(),
          );

    if (!VideoEditorSplitService.isValidSplitPosition(
      selectedClip,
      localPosition,
    )) {
      const minDuration = VideoEditorSplitService.minClipDuration;
      ScaffoldMessenger.of(context).showSnackBar(
        DivineSnackbarContainer.snackBar(
          context.l10n.videoEditorSplitPositionInvalid(
            minDuration.inMilliseconds,
          ),
        ),
      );
      return;
    }

    // Update the split position and request the split. Bind the request to
    // this clip and cut point so a queued split (sequential handler) still
    // targets the right clip even if the selection changes while an earlier
    // split renders.
    bloc
      ..add(ClipEditorSplitPositionChanged(localPosition))
      ..add(
        ClipEditorSplitRequested(
          clipId: selectedClip.id,
          splitPosition: localPosition,
        ),
      );
  }
}

/// Action bar for a selected still in a frames-only stop-motion clip: delete or
/// duplicate the still and set how many output frames it is held for. Falls back
/// to just Done when no still is selected.
class _StopMotionClipControls extends StatelessWidget {
  const _StopMotionClipControls();

  @override
  Widget build(BuildContext context) {
    final ({String clipId, List<StopMotionClipFrame> frames, int? selected})?
    data = context.select((ClipEditorBloc b) {
      final state = b.state;
      final index = state.currentClipIndex;
      if (index < 0 || index >= state.clips.length) return null;
      final clip = state.clips[index];
      final frames = clip.stopMotionFrames;
      if (frames == null) return null;
      return (
        clipId: clip.id,
        frames: frames,
        selected: state.selectedFrameIndex,
      );
    });

    if (data == null) return const SizedBox.shrink();

    final frames = data.frames;
    final selected = data.selected;
    final hasSelection =
        selected != null && selected >= 0 && selected < frames.length;

    return VideoEditorTimelineControls(
      onDelete: hasSelection && frames.length > 1
          ? () => commitStopMotionFrames(
              context,
              clipId: data.clipId,
              frames: StopMotionFrameOps.removeFrame(frames, selected),
            )
          : null,
      onDuplicated: hasSelection
          ? () => commitStopMotionFrames(
              context,
              clipId: data.clipId,
              frames: StopMotionFrameOps.duplicateFrames(frames, {selected}),
            )
          : null,
      // Crop / rotate / flip the selected still. A stop-motion still is an
      // image, so the transform is applied by the image editor and written
      // straight back to the frame — no clip re-render involved.
      onTransform: hasSelection
          ? () => transformStopMotionFrame(
              context,
              clipId: data.clipId,
              frameIndex: selected,
            )
          : null,
      transformSemanticLabel:
          context.l10n.videoEditorTransformSelectedFrameSemanticLabel,
      // Frame multi-select: batch delete / hold on several stills. Needs a
      // second still to be meaningful.
      onMultiSelect: frames.length > 1
          ? () => context.read<ClipEditorBloc>().add(
              ClipEditorFrameMultiSelectStarted(selected),
            )
          : null,
      onDone: () =>
          context.read<ClipEditorBloc>().add(const ClipEditorEditingStopped()),
      extraControls: hasSelection
          ? [
              _StopMotionFramesButton(
                onPressed: () => editStopMotionFrameHold(
                  context,
                  clipId: data.clipId,
                  frameIndex: selected,
                ),
              ),
            ]
          : const [],
    );
  }
}

/// Action-bar button (icon + label, matching the other controls) that opens the
/// frames-per-image wheel sheet for the selected still.
class _StopMotionFramesButton extends StatelessWidget {
  const _StopMotionFramesButton({required this.onPressed});

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return Column(
      spacing: 8,
      children: [
        DivineIconButton(
          icon: .imagesSquare,
          semanticLabel: context.l10n.videoEditorStopMotionFramesPerImageLabel,
          onPressed: onPressed,
          type: .secondary,
          size: .small,
        ),
        Text(
          context.l10n.videoEditorStopMotionFramesPerImageButtonLabel,
          style: VineTheme.bodySmallFont(color: context.vineColors.primaryText),
        ),
      ],
    );
  }
}
