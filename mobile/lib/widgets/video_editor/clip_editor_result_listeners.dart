// ABOUTME: Surfaces the outcome of every ClipEditorBloc operation the user
// ABOUTME: waits on — snackbars for failures, history commits for successes.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/extensions/video_editor_extensions.dart';
import 'package:openvine/extensions/video_editor_history_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion/stop_motion_frame_ops.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/models/video_editor/detached_clip_window.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_layer_view.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/video_editor_timeline_geometry.dart';
import 'package:pro_image_editor/pro_image_editor.dart'
    show WidgetLayer, WidgetLayerExportConfigs;

/// Reacts to the result of each [ClipEditorBloc] operation.
///
/// Every operation the user can wait on — split, reverse, transform, merge,
/// detach, backdrop change, detached-clip transform, remove, audio extraction,
/// library save, library import — reports its outcome through a `last*Result`
/// field on
/// [ClipEditorState].
/// The listeners below turn those into user-visible feedback and, for the
/// operations that change the timeline, into one editor-history step.
///
/// Mounted once at the scaffold level (always alive) so the feedback fires
/// even when the timeline controls are hidden while a render is in flight.
class ClipEditorResultListeners extends StatelessWidget {
  const ClipEditorResultListeners({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return _SplitFailureListener(
      child: _ClipReverseResultListener(
        child: _ClipTransformResultListener(
          child: _ClipMergeResultListener(
            child: _ClipDetachResultListener(
              child: _ClipPlaceholderFillResultListener(
                child: _DetachedClipTransformResultListener(
                  child: _ClipsRemovedResultListener(
                    child: _AudioExtractionResultListener(
                      child: _ClipLibrarySaveResultListener(
                        child: _ClipLibraryImportResultListener(child: child),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Listens to [ClipEditorState.lastSplitFailure] and shows an error
/// snackbar when a split fails.
///
/// Kept at the scaffold level (always mounted) so the snackbar fires even
/// if the timeline controls are hidden.
class _SplitFailureListener extends StatelessWidget {
  const _SplitFailureListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ClipEditorBloc, ClipEditorState>(
      listenWhen: (prev, curr) =>
          !identical(prev.lastSplitFailure, curr.lastSplitFailure) &&
          curr.lastSplitFailure != null,
      listener: (context, state) {
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(context.l10n.videoEditorSplitFailed),
        );
      },
      child: child,
    );
  }
}

/// Listens to [ClipEditorState.lastReverseResult] and surfaces a
/// snackbar when a reverse-render operation fails or the clip has no local
/// file. Success is handled by the canvas player-sync listener; this listener
/// only covers the failure outcomes so they aren't silent to the user.
///
/// Kept at the scaffold level (always mounted) so the snackbar fires even
/// if the timeline controls are hidden while the render is in flight.
class _ClipReverseResultListener extends StatelessWidget {
  const _ClipReverseResultListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ClipEditorBloc, ClipEditorState>(
      listenWhen: (prev, curr) =>
          !identical(prev.lastReverseResult, curr.lastReverseResult) &&
          curr.lastReverseResult != null,
      listener: _onReverseResult,
      child: child,
    );
  }

  void _onReverseResult(BuildContext context, ClipEditorState state) {
    final result = state.lastReverseResult;
    if (result == null) return;

    switch (result) {
      case ClipReverseNoLocalFile():
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.videoEditorReverseNoLocalFile,
          ),
        );
      case ClipReverseFailure():
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.videoEditorReverseFailed,
          ),
        );
      case ClipReverseDiscarded():
        // Source clip was removed during the async gap — there is no clip to
        // attach the reversed render to and no user action that warrants a
        // snackbar.
        break;
      case ClipReverseSuccess():
        // Player sync is handled by the canvas listener; nothing to do here.
        break;
    }
  }
}

// No chroma-key result listener here on purpose. Both chroma-key events are
// dispatched from `VideoClipChromaKeyScreen`, which cannot be left while a bake
// is in flight, so that screen is always mounted when the result lands and owns
// the message. A second listener at this level would queue the same snackbar on
// the same root `ScaffoldMessenger` and show it twice.

/// Listens to [ClipEditorState.lastTransformResult] and surfaces a
/// snackbar when a transform-render operation fails or the clip has no local
/// file. Success is handled by the canvas player-sync listener that reacts to
/// the swapped clip file; this listener only covers the failure outcomes so
/// they aren't silent to the user.
///
/// Kept at the scaffold level (always mounted) so the snackbar fires even
/// if the timeline controls are hidden while the render is in flight.
class _ClipTransformResultListener extends StatelessWidget {
  const _ClipTransformResultListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ClipEditorBloc, ClipEditorState>(
      listenWhen: (prev, curr) =>
          !identical(prev.lastTransformResult, curr.lastTransformResult) &&
          curr.lastTransformResult != null,
      listener: _onTransformResult,
      child: child,
    );
  }

  void _onTransformResult(BuildContext context, ClipEditorState state) {
    final result = state.lastTransformResult;
    if (result == null) return;

    switch (result) {
      case ClipTransformNoLocalFile():
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.videoEditorTransformNoLocalFile,
          ),
        );
      case ClipTransformFailure():
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.videoEditorTransformFailed,
          ),
        );
      case ClipTransformFrameFailure():
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.videoEditorTransformFrameFailed,
          ),
        );
      case ClipTransformDiscarded():
        // Source clip was removed during the async gap — nothing to attach
        // the transformed render to and no user action that warrants a
        // snackbar.
        break;
      case ClipTransformSuccess():
        // Player sync is handled by the canvas listener; nothing to do here.
        break;
    }
  }
}

/// Listens to [ClipEditorState.lastMergeResult] and commits a successful
/// merge to editor history (replacing the selected clips with the merged clip,
/// with timeline markers rebased) or surfaces a snackbar on failure.
///
/// The bloc has already swapped the clip list by the time this fires; this
/// listener persists that change plus the rebased markers as one history entry
/// so undo/redo restores a consistent timeline. Kept at the scaffold level
/// (always mounted) so it survives the multi-select controls unmounting when
/// the bloc exits multi-select mode on success.
class _ClipMergeResultListener extends StatelessWidget {
  const _ClipMergeResultListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ClipEditorBloc, ClipEditorState>(
      listenWhen: (prev, curr) =>
          !identical(prev.lastMergeResult, curr.lastMergeResult) &&
          curr.lastMergeResult != null,
      listener: _onMergeResult,
      child: child,
    );
  }

  void _onMergeResult(BuildContext context, ClipEditorState state) {
    final result = state.lastMergeResult;
    if (result == null) return;

    switch (result) {
      case ClipMergeSuccess(:final previousClips):
        _commitMerge(context, state, previousClips);
      case ClipMergeFailure():
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(context.l10n.videoEditorMergeFailed),
        );
      case ClipMergeDiscarded():
        // A selected clip was removed during the async render — nothing to
        // commit and no user action that warrants a snackbar.
        break;
    }
  }

  void _commitMerge(
    BuildContext context,
    ClipEditorState state,
    List<DivineVideoClip> previousClips,
  ) {
    final editor = VideoEditorScope.of(context).requireEditor;
    final overlayBloc = context.read<TimelineOverlayBloc>();

    final rebasedMarkers = rebaseTimelineMarkersForClipState(
      oldClips: previousClips,
      newClips: state.clips,
      markers: overlayBloc.state.timelineMarkers,
    );

    overlayBloc.add(TimelineMarkersRebased(rebasedMarkers));
    editor.setClipState(state.clips, timelineMarkers: rebasedMarkers);
  }
}

/// Listens to [ClipEditorState.lastDetachResult] and finishes a detach:
/// puts the clip on the canvas as a layer and commits both halves of the change
/// to editor history as one entry.
///
/// The BLoC owns the clip-list mutation and the placeholder render, but it
/// cannot reach the editor. Kept at the scaffold level (always mounted) so the
/// layer still lands if the user leaves clip-edit mode while the placeholder
/// renders.
class _ClipDetachResultListener extends StatelessWidget {
  const _ClipDetachResultListener({required this.child});

  final Widget child;

  /// Fraction of the *video's* width a freshly detached clip takes up.
  ///
  /// Wider than a sticker's third on purpose: the clip was filling the frame a
  /// moment ago, so it has to land big enough to still be the thing the user is
  /// looking at — just clearly inset, so it reads as placed rather than as the
  /// track it came off.
  static const double _initialWidthFraction = 0.8;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ClipEditorBloc, ClipEditorState>(
      listenWhen: (prev, curr) =>
          !identical(prev.lastDetachResult, curr.lastDetachResult) &&
          curr.lastDetachResult != null,
      listener: _onDetachResult,
      child: child,
    );
  }

  void _onDetachResult(BuildContext context, ClipEditorState state) {
    final result = state.lastDetachResult;
    switch (result) {
      case ClipDetachSuccess(:final previousClips, :final detachedClip):
        _commitDetach(context, state, previousClips, detachedClip);
      case ClipDetachFailure():
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.videoEditorDetachFailed,
          ),
        );
      case ClipDetachDiscarded():
      // The clip the user asked to detach was removed while its placeholder
      // rendered — nothing to place, and no action that warrants a snackbar.
      case null:
        break;
    }
  }

  void _commitDetach(
    BuildContext context,
    ClipEditorState state,
    List<DivineVideoClip> previousClips,
    DivineVideoClip detachedClip,
  ) {
    final scope = VideoEditorScope.of(context);
    final editor = scope.editor;
    if (editor == null) return;
    final overlayBloc = context.read<TimelineOverlayBloc>();

    final rebasedMarkers = rebaseTimelineMarkersForClipState(
      oldClips: previousClips,
      newClips: state.clips,
      markers: overlayBloc.state.timelineMarkers,
    );

    // Measured against the render surface, not the editor body: a layer width
    // *is* a render coordinate, so this fraction is a fraction of the video
    // itself. Going through the body would overshoot by `body / target`, which
    // is letterboxing the clip never sits on.
    final width = scope.canvasRenderSize.width * _initialWidthFraction;

    // The layer keeps the slot the clip came out of: it stays where it was in
    // time, is hidden outside it, and the export draws it over exactly the same
    // stretch. Without a window the clip sat frozen on its last frame for the
    // rest of the composition while the export showed nothing there.
    //
    // Measured against the composition as it is *now*: closing the slot
    // shortened it, and a slot at the old tail end would otherwise sit past
    // the new end where nothing plays it.
    final slotStart = previousClips
        .takeWhile((c) => c.id != detachedClip.id)
        .fold(Duration.zero, (total, c) => total + c.playbackDuration);
    final window = detachedClipWindow(
      slotStart: slotStart,
      playbackDuration: detachedClip.playbackDuration,
      compositionDuration: state.totalDuration,
    );

    final layerId = 'detached_${detachedClip.id}';
    final meta = DetachedClipLayerData(
      clip: detachedClip,
      layerId: layerId,
    ).toMeta();
    final layer = WidgetLayer(
      id: layerId,
      startTime: window.start,
      endTime: window.end,
      width: width,
      widget: DetachedClipLayerView(meta: meta),
      meta: meta,
      exportConfigs: WidgetLayerExportConfigs(id: layerId, meta: meta),
    );

    overlayBloc.add(TimelineMarkersRebased(rebasedMarkers));
    editor.setClipStateWithNewLayer(
      clips: state.clips,
      layer: layer,
      timelineMarkers: rebasedMarkers,
    );
  }
}

/// Listens to [ClipEditorState.lastPlaceholderFillResult] and surfaces a
/// snackbar when re-rendering a placeholder's backdrop fails.
///
/// Success needs nothing here: the bloc has already swapped the clip and
/// committed the list to editor history, and the canvas reloads off the new
/// file through the same player-sync listener a transform goes through.
///
/// Kept at the scaffold level (always mounted) so the snackbar fires even if
/// the timeline controls are hidden while the render is in flight.
class _ClipPlaceholderFillResultListener extends StatelessWidget {
  const _ClipPlaceholderFillResultListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ClipEditorBloc, ClipEditorState>(
      listenWhen: (prev, curr) =>
          !identical(
            prev.lastPlaceholderFillResult,
            curr.lastPlaceholderFillResult,
          ) &&
          curr.lastPlaceholderFillResult != null,
      listener: _onPlaceholderFillResult,
      child: child,
    );
  }

  void _onPlaceholderFillResult(BuildContext context, ClipEditorState state) {
    switch (state.lastPlaceholderFillResult) {
      case ClipPlaceholderFillFailure():
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.videoEditorBackdropFailed,
          ),
        );
      case ClipPlaceholderFillDiscarded():
      // The slot the user asked to refill was removed while the new still
      // rendered — nothing to swap onto, and no action worth a snackbar.
      case ClipPlaceholderFillSuccess():
      // The swapped clip file drives the canvas; nothing to do here.
      case null:
        break;
    }
  }
}

/// Writes a cropped detached clip back onto the layer that carries it.
///
/// The BLoC half is [ClipEditorBloc]'s detached-clip transform handler, which
/// renders the new file; this half swaps it into the layer's meta and its live
/// widget, as one editor-history entry so undo restores the pre-crop clip.
///
/// Kept at the scaffold level (always mounted) so the write-back survives the
/// layer's action bar unmounting while the render is in flight — the same
/// reason every other render listener lives here.
class _DetachedClipTransformResultListener extends StatelessWidget {
  const _DetachedClipTransformResultListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ClipEditorBloc, ClipEditorState>(
      listenWhen: (prev, curr) =>
          !identical(
            prev.lastDetachedClipTransformResult,
            curr.lastDetachedClipTransformResult,
          ) &&
          curr.lastDetachedClipTransformResult != null,
      listener: _onResult,
      child: child,
    );
  }

  void _onResult(BuildContext context, ClipEditorState state) {
    switch (state.lastDetachedClipTransformResult) {
      case DetachedClipTransformSuccess(:final layerId, :final clip):
        _applyToLayer(context, layerId, clip);
      case DetachedClipTransformFailure():
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.videoEditorTransformFailed,
          ),
        );
      case null:
        break;
    }
  }

  void _applyToLayer(
    BuildContext context,
    String layerId,
    DivineVideoClip clip,
  ) {
    final editor = VideoEditorScope.of(context).editor;
    if (editor == null) return;

    final index = editor.activeLayers.indexWhere((l) => l.id == layerId);
    if (index < 0) return;
    final layer = editor.activeLayers[index];
    if (layer is! WidgetLayer) return;

    // Only the clip is swapped. The layer's own settings — where a split tail
    // starts inside the clip, and its live green screen — describe the layer,
    // not the footage, and a crop changes neither.
    final meta = DetachedClipLayerData.withClip(
      DetachedClipLayerData.metaOf(layer),
      clip,
    );
    if (meta == null) return;

    // The layer keeps its width; the crop changes the content's aspect ratio,
    // so the height follows on its own through the frame that lays it out. A
    // crop should change the shape of the box, not jump its size.
    editor.replaceLayer(
      index: index,
      layer: layer.copyWith(
        widget: DetachedClipLayerView(meta: meta),
        meta: meta,
        exportConfigs: layer.exportConfigs.copyWith(meta: meta),
      ),
    );
  }
}

/// Listens to [ClipEditorState.lastClipsRemovedResult] and commits a
/// multi-select removal to editor history (the new clip list with timeline
/// markers rebased).
///
/// The bloc owns the clip-list mutation; this listener only persists it. Kept
/// at the scaffold level (always mounted) so it survives the multi-select
/// controls unmounting when the bloc exits multi-select mode on removal.
class _ClipsRemovedResultListener extends StatelessWidget {
  const _ClipsRemovedResultListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ClipEditorBloc, ClipEditorState>(
      listenWhen: (prev, curr) =>
          !identical(
            prev.lastClipsRemovedResult,
            curr.lastClipsRemovedResult,
          ) &&
          curr.lastClipsRemovedResult != null,
      listener: _onClipsRemoved,
      child: child,
    );
  }

  void _onClipsRemoved(BuildContext context, ClipEditorState state) {
    final result = state.lastClipsRemovedResult;
    if (result == null) return;

    final editor = VideoEditorScope.of(context).requireEditor;
    final overlayBloc = context.read<TimelineOverlayBloc>();

    final rebasedMarkers = rebaseTimelineMarkersForClipState(
      oldClips: result.previousClips,
      newClips: state.clips,
      markers: overlayBloc.state.timelineMarkers,
    );

    overlayBloc.add(TimelineMarkersRebased(rebasedMarkers));
    editor.setClipState(state.clips, timelineMarkers: rebasedMarkers);
  }
}

/// Listens to [ClipEditorState.lastAudioExtraction] from a widget that
/// stays mounted for the entire editor session, so the success/failure
/// side effect (history write or snackbar) survives the user leaving edit
/// mode, switching clips, or unmounting the timeline-level controls while
/// extraction is in flight.
class _AudioExtractionResultListener extends StatelessWidget {
  const _AudioExtractionResultListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ClipEditorBloc, ClipEditorState>(
      listenWhen: (prev, curr) =>
          !identical(prev.lastAudioExtraction, curr.lastAudioExtraction) &&
          curr.lastAudioExtraction != null,
      listener: _onAudioExtractionResult,
      child: child,
    );
  }

  void _onAudioExtractionResult(BuildContext context, ClipEditorState state) {
    final result = state.lastAudioExtraction;
    if (result == null) return;

    switch (result) {
      case ClipAudioExtractionNoLocalFile():
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.videoEditorExtractAudioNoLocalFile,
          ),
        );
      case ClipAudioExtractionDiscarded():
        // Source clip was removed during the async gap — nothing to
        // attach the extracted track to and no user action that
        // warrants a snackbar.
        break;
      case ClipAudioExtractionSuccess(:final audioEvent):
        _writeAudioExtractionHistory(context, state, audioEvent);
      case ClipAudioExtractionFailure():
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.videoEditorExtractAudioFailed,
          ),
        );
    }
  }

  void _writeAudioExtractionHistory(
    BuildContext context,
    ClipEditorState state,
    AudioEvent audioEvent,
  ) {
    final editor = VideoEditorScope.of(context).requireEditor;

    // state.clips already reflects the muted clip applied by the bloc;
    // combine with the new audio track for a single atomic history entry
    // so undo/redo reverts both the mute and the added track together.
    final updatedTracks = [...editor.stateManager.audioTracks, audioEvent];
    editor.setClipAndAudioState(clips: state.clips, audioTracks: updatedTracks);
  }
}

/// Listens to [ClipEditorState.lastClipLibrarySave] from a widget that
/// stays mounted for the entire editor session, so the save's outcome still
/// reaches the user after they leave edit mode or switch clips mid-render.
///
/// No history is written: saving to the library copies the clip out of the
/// session and never mutates the timeline.
class _ClipLibrarySaveResultListener extends StatelessWidget {
  const _ClipLibrarySaveResultListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ClipEditorBloc, ClipEditorState>(
      listenWhen: (prev, curr) =>
          !identical(prev.lastClipLibrarySave, curr.lastClipLibrarySave) &&
          curr.lastClipLibrarySave != null,
      listener: _onClipLibrarySaveResult,
      child: child,
    );
  }

  void _onClipLibrarySaveResult(BuildContext context, ClipEditorState state) {
    final result = state.lastClipLibrarySave;
    if (result == null) return;

    switch (result) {
      case ClipLibrarySaveSuccess():
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.videoEditorClipSavedSuccess,
          ),
        );
      case ClipLibrarySaveDiscarded():
        // The source clip was deleted while the re-encode ran — the user
        // discarded what they asked to save, so neither outcome warrants a
        // snackbar.
        break;
      case ClipLibrarySaveFailure():
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.videoEditorClipSaveFailed,
          ),
        );
    }
  }
}

/// Listens to [ClipEditorState.lastLibraryImportResult] and commits a
/// successful import — clips picked in the library, now on the timeline — to
/// editor history, or surfaces a snackbar when a picked clip could not take
/// the composition's shape (a set that would not render into a clip, a clip
/// that would not sample into stills).
///
/// The bloc has already grown its clip list by the time this fires. The
/// history entry is what carries the change to the clip manager (and so to
/// autosave), and it is written with
/// [VideoEditorExtensions.setLengthenedClipState] because an import only ever
/// makes the composition longer: a sound window that ran to the old end is
/// carried onto the new one (#6401), while one the user trimmed short stays
/// put. The sound a sampled clip brought along goes into the same entry, so
/// one undo removes the stills and their sound together.
class _ClipLibraryImportResultListener extends StatelessWidget {
  const _ClipLibraryImportResultListener({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return BlocListener<ClipEditorBloc, ClipEditorState>(
      listenWhen: (prev, curr) =>
          !identical(
            prev.lastLibraryImportResult,
            curr.lastLibraryImportResult,
          ) &&
          curr.lastLibraryImportResult != null,
      listener: _onLibraryImportResult,
      child: child,
    );
  }

  void _onLibraryImportResult(BuildContext context, ClipEditorState state) {
    final result = state.lastLibraryImportResult;
    if (result == null) return;

    switch (result) {
      case ClipLibraryImportSuccess(:final previousClips, :final audioTracks):
        VideoEditorScope.of(context).requireEditor.setLengthenedClipState(
          previousClips: previousClips,
          clips: state.clips,
          addedAudioTracks: audioTracks,
        );
      case ClipLibraryImportFailure():
        // The timeline is unchanged on failure, so its kind still says which
        // shape the picked clip failed to take.
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            isStopMotionComposition(state.clips)
                ? context.l10n.videoEditorLibraryImportStillsFailed
                : context.l10n.videoEditorLibraryImportFailed,
          ),
        );
      case ClipLibraryImportStillsMissing():
        ScaffoldMessenger.of(context).showSnackBar(
          DivineSnackbarContainer.snackBar(
            context.l10n.videoEditorLibraryImportStillsMissing,
          ),
        );
      case ClipLibraryImportDiscarded():
        // The render was cancelled by the editor's own teardown — there is no
        // timeline left to add to and no user action that warrants a snackbar.
        break;
    }
  }
}
