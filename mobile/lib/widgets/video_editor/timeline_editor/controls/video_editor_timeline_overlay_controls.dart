import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/blocs/video_editor/tune_editor/video_editor_tune_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/tune_adjustment_matrix_extensions.dart';
import 'package:openvine/extensions/video_editor_extensions.dart';
import 'package:openvine/extensions/video_editor_history_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/screens/video_editor/video_audio_editor_timing_screen.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_transform.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_layer_animation_sheet.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_controls.dart';
import 'package:openvine/widgets/video_editor/tune_editor/open_tune_editor.dart';
import 'package:pro_image_editor/core/models/layers/layer.dart';
import 'package:pro_image_editor/features/filter_editor/types/filter_state.dart';
import 'package:pro_image_editor/features/tune_editor/models/tune_adjustment_matrix.dart';

/// Controls shown when an overlay item is selected.
/// Adapts buttons based on the overlay type (layer vs filter).
class TimelineOverlayControls extends StatelessWidget {
  const TimelineOverlayControls({required this.item, super.key});

  final TimelineOverlayItem item;

  @override
  Widget build(BuildContext context) {
    return switch (item.type) {
      .sound => _SoundOverlayControls(item: item),
      .filter => _FilterOverlayControls(item: item),
      .tune => _TuneOverlayControls(item: item),
      .layer => _LayerOverlayControls(item: item),
      .captions => _CaptionOverlayControls(item: item),
    };
  }

  static void _deselect(BuildContext context) {
    context.read<TimelineOverlayBloc>().add(
      const TimelineOverlayItemSelected(null),
    );
  }
}

/// Controls for layer overlays (text, drawing, emoji, sticker).
/// Text layers get an Edit button; all layers support delete, duplicate,
/// split, and done.
class _LayerOverlayControls extends StatelessWidget {
  const _LayerOverlayControls({required this.item});

  final TimelineOverlayItem item;

  @override
  Widget build(BuildContext context) {
    final scope = VideoEditorScope.of(context);

    final layer = scope.editor?.activeLayers
        .where((l) => l.id == item.id)
        .firstOrNull;
    final isTextLayer = layer is TextLayer;
    final isDetachedClip =
        layer != null && DetachedClipLayerData.isDetachedClipLayer(layer);

    // Draw layers can be multi-selected and combined when the selected layer is
    // itself a mergeable draw layer and at least two mergeable draw layers exist
    // on the canvas.
    final mergeableDrawLayerCount =
        scope.editor?.activeLayers.where(isMergeableDrawLayer).length ?? 0;
    final canMultiSelect =
        isMergeableDrawLayer(layer) && mergeableDrawLayerCount >= 2;

    return VideoEditorTimelineControls(
      onDelete: () => _removeLayer(context: context, layer: layer),
      onEdit: isTextLayer
          ? () => _editTextLayer(context: context, layer: layer)
          : null,
      // A detached clip owns one timed video player. Duplicating or splitting
      // the generic WidgetLayer would copy its player identity and layer-id
      // metadata verbatim, making preview timing disagree with export.
      onDuplicated: isDetachedClip
          ? null
          : () => _duplicateLayer(context: context, layer: layer),
      onMultiSelect: canMultiSelect
          ? () => _startLayerMultiSelect(context: context)
          : null,
      multiSelectSemanticLabel:
          context.l10n.videoEditorLayerMultiSelectSemanticLabel,
      onSplit: isDetachedClip
          ? null
          : () => _splitLayer(context: context, layer: layer),
      // Crop / rotate / flip, for a detached clip only. Every other layer is
      // already whatever shape it was drawn or typed at; a detached clip
      // carries a video file that can genuinely be re-rendered.
      onTransform: isDetachedClip
          ? () => transformDetachedClip(context, layer)
          : null,
      // Animations are off for a detached clip: the export composites it as a
      // `VideoLayer`, and neither that nor the `VideoSegment` under it carries
      // an `animations` field the way a rasterized `ImageLayer` does. Offering
      // the action would animate the layer in the editor and drop it silently
      // from the file.
      onAnimate: layer == null || isDetachedClip
          ? null
          : () => editLayerAnimation(
              context,
              layer,
              // The stable editor-timeline total (sum of clip playback
              // lengths), not item.endTime (the layer's own clamped end) and
              // not VideoEditorMainBloc.totalDuration — the latter is derived
              // from player duration reports and can be a transient zero right
              // after a clip change. A too-small total here would collapse the
              // layer's leave-animation window and drop it from the timeline.
              totalDuration: context.read<ClipEditorBloc>().state.totalDuration,
            ),
      onDone: () => TimelineOverlayControls._deselect(context),
    );
  }

  void _removeLayer({required BuildContext context, Layer? layer}) {
    // Remove from the ProImageEditor active layers.
    final scope = VideoEditorScope.of(context);
    final editor = scope.editor;
    if (editor != null && layer != null) {
      editor.removeLayer(layer);
    }
  }

  Future<void> _editTextLayer({
    required BuildContext context,
    required TextLayer layer,
  }) async {
    final scope = VideoEditorScope.of(context);
    final editor = scope.editor;
    if (editor == null) return;
    final originalLayer = layer;

    final updatedLayer = await scope.onAddEditTextLayer(originalLayer);
    if (updatedLayer == null) return;

    editor.applyTextLayerChanges(layer, updatedLayer);
  }

  /// Enters draw-layer multi-select mode, seeded with the tapped layer.
  ///
  /// The user then toggles additional draw layers and combines the selection
  /// via the multi-select control bar.
  void _startLayerMultiSelect({required BuildContext context}) {
    context.read<TimelineOverlayBloc>().add(
      TimelineOverlayLayerMultiSelectStarted(item.id),
    );
  }

  void _duplicateLayer({required BuildContext context, Layer? layer}) {
    final editor = VideoEditorScope.of(context).editor;
    if (editor == null || layer == null) return;

    final layers = List<Layer>.from(editor.activeLayers);
    final layerIdx = layers.indexWhere((l) => l.id == item.id);
    if (layerIdx < 0) return;

    final copy = layer.copyWith(
      id: _copyId(layer.id),
      offset: layer.offset + const Offset(24, 24),
    );

    layers.insert(layerIdx + 1, copy);
    editor.addHistory(layers: layers);
    context.read<TimelineOverlayBloc>().add(
      TimelineOverlayItemSelected(copy.id),
    );
  }

  void _splitLayer({required BuildContext context, Layer? layer}) {
    final editor = VideoEditorScope.of(context).editor;
    if (editor == null || layer == null) return;

    final splitAt = _validSplitPosition(context, item);
    if (splitAt == null) return;

    final layers = List<Layer>.from(editor.activeLayers);
    final layerIdx = layers.indexWhere((l) => l.id == item.id);
    if (layerIdx < 0) return;

    final second = layer.copyWith(
      id: _copyId(layer.id),
      startTime: splitAt,
      endTime: item.endTime,
    );

    layers[layerIdx] = layer.copyWith(endTime: splitAt);
    layers.insert(layerIdx + 1, second);
    editor.addHistory(layers: layers);
    context.read<TimelineOverlayBloc>().add(
      TimelineOverlayItemSelected(second.id),
    );
  }
}

/// Controls for caption cues: edit (re-opens the captions editor), delete
/// (removes just this cue), and done.
class _CaptionOverlayControls extends StatelessWidget {
  const _CaptionOverlayControls({required this.item});

  final TimelineOverlayItem item;

  @override
  Widget build(BuildContext context) {
    return VideoEditorTimelineControls(
      onDelete: () => _removeCue(context),
      onEdit: () => _editCaptions(context),
      onDone: () => TimelineOverlayControls._deselect(context),
    );
  }

  /// Re-opens the captions editor for the whole track; per-cue text editing
  /// lives there alongside preset and mode controls.
  void _editCaptions(BuildContext context) {
    final scope = VideoEditorScope.of(context);
    TimelineOverlayControls._deselect(context);
    scope.onOpenCaptions();
  }

  void _removeCue(BuildContext context) {
    final scope = VideoEditorScope.of(context);
    final editor = scope.editor;
    if (editor == null) return;

    // Drops the cue and, when burned in, its text layer together — so a
    // deleted caption never lingers in the exported video.
    editor.removeCaptionCue(item.id);
    TimelineOverlayControls._deselect(context);
  }
}

/// Controls for filter overlays: delete, duplicate, split, and done.
class _FilterOverlayControls extends StatelessWidget {
  const _FilterOverlayControls({required this.item});

  final TimelineOverlayItem item;

  @override
  Widget build(BuildContext context) {
    return VideoEditorTimelineControls(
      onDelete: () => _removeFilter(context: context),
      onDuplicated: () => _duplicateFilter(context: context),
      onSplit: () => _splitFilter(context: context),
      onDone: () => TimelineOverlayControls._deselect(context),
    );
  }

  void _removeFilter({required BuildContext context}) {
    final editor = VideoEditorScope.of(context).editor;
    if (editor == null) return;

    final filters = editor.stateManager.activeFilters;
    final updatedFilters = filters
        .where((t) => t.id != item.id)
        .map((e) => e.copy())
        .toList();

    editor.addHistory(filters: updatedFilters);

    context.read<TimelineOverlayBloc>().add(
      const TimelineOverlayItemSelected(null),
    );
  }

  void _duplicateFilter({required BuildContext context}) {
    final editor = VideoEditorScope.of(context).editor;
    if (editor == null) return;

    final filters = List<FilterState>.from(editor.stateManager.activeFilters);
    final filterIdx = filters.indexWhere((t) => t.id == item.id);
    if (filterIdx < 0) return;

    final copy = filters[filterIdx].copyWith(id: _copyId(item.id));
    filters.insert(filterIdx + 1, copy);
    editor.addHistory(filters: filters);
    context.read<TimelineOverlayBloc>().add(
      TimelineOverlayItemSelected(copy.id),
    );
  }

  void _splitFilter({required BuildContext context}) {
    final editor = VideoEditorScope.of(context).editor;
    if (editor == null) return;

    final splitAt = _validSplitPosition(context, item);
    if (splitAt == null) return;

    final filters = List<FilterState>.from(editor.stateManager.activeFilters);
    final filterIdx = filters.indexWhere((t) => t.id == item.id);
    if (filterIdx < 0) return;

    final filter = filters[filterIdx];
    final second = filter.copyWith(
      id: _copyId(item.id),
      startTime: splitAt,
      endTime: item.endTime,
    );

    filters[filterIdx] = filter.copyWith(endTime: splitAt);
    filters.insert(filterIdx + 1, second);
    editor.addHistory(filters: filters);
    context.read<TimelineOverlayBloc>().add(
      TimelineOverlayItemSelected(second.id),
    );
  }
}

/// Controls for a tune-adjustment *set* overlay: delete, duplicate, split,
/// and done.
///
/// Each bar bundles one Adjust session's adjustments (a set sharing one
/// window). Delete removes every member; duplicate copies the whole set into a
/// new set (overlapping until moved); split cuts every member at the playhead,
/// leaving the tail as a new set. All new sets get a fresh set id so they
/// render as their own bar.
class _TuneOverlayControls extends StatelessWidget {
  const _TuneOverlayControls({required this.item});

  final TimelineOverlayItem item;

  @override
  Widget build(BuildContext context) {
    return VideoEditorTimelineControls(
      onDelete: () => _removeTuneSet(context: context),
      onEdit: () => _editTuneSet(context: context),
      onDuplicated: () => _duplicateTuneSet(context: context),
      onSplit: () => _splitTuneSet(context: context),
      onDone: () => TimelineOverlayControls._deselect(context),
    );
  }

  void _editTuneSet({required BuildContext context}) {
    openTuneEditor(
      context.read<VideoEditorMainBloc>(),
      context.read<VideoEditorTuneBloc>(),
      VideoEditorScope.of(context),
      editSetId: item.id,
    );
  }

  void _removeTuneSet({required BuildContext context}) {
    final editor = VideoEditorScope.of(context).editor;
    if (editor == null) return;

    final updated = editor.stateManager.activeTuneAdjustments
        .where((t) => t.tuneSetId != item.id)
        .map((e) => e.copy())
        .toList();

    editor.addHistory(tuneAdjustments: updated);

    context.read<TimelineOverlayBloc>().add(
      const TimelineOverlayItemSelected(null),
    );
  }

  void _duplicateTuneSet({required BuildContext context}) {
    final editor = VideoEditorScope.of(context).editor;
    if (editor == null) return;

    final tunes = editor.stateManager.activeTuneAdjustments;
    final members = tunes.where((t) => t.tuneSetId == item.id);
    if (members.isEmpty) return;

    final newSetId = TuneSet.newId();
    final copies = members
        .map((m) => _reSet(m, newSetId))
        .toList(growable: false);

    editor.addHistory(
      tuneAdjustments: [...tunes.map((e) => e.copy()), ...copies],
    );
    context.read<TimelineOverlayBloc>().add(
      TimelineOverlayItemSelected(newSetId),
    );
  }

  void _splitTuneSet({required BuildContext context}) {
    final editor = VideoEditorScope.of(context).editor;
    if (editor == null) return;

    final splitAt = _validSplitPosition(context, item);
    if (splitAt == null) return;

    final newSetId = TuneSet.newId();
    final updated = <TuneAdjustmentMatrix>[];
    for (final m in editor.stateManager.activeTuneAdjustments) {
      if (m.tuneSetId != item.id) {
        updated.add(m.copy());
        continue;
      }
      // Head keeps the set id and ends at the split; tail becomes a new set.
      updated
        ..add(m.copyWith(endTime: splitAt))
        ..add(
          _reSet(
            m,
            newSetId,
          ).copyWith(startTime: splitAt, endTime: item.endTime),
        );
    }

    editor.addHistory(tuneAdjustments: updated);
    context.read<TimelineOverlayBloc>().add(
      TimelineOverlayItemSelected(newSetId),
    );
  }
}

/// Copies [m] into the set [setId] with a fresh per-instance id.
TuneAdjustmentMatrix _reSet(TuneAdjustmentMatrix m, String setId) {
  final kind = m.tuneKind;
  return m.copyWith(
    id: TuneSet.memberId(kind: kind, setId: setId),
    meta: TuneSet.metaFor(setId: setId, kind: kind),
  );
}

/// Controls for sound overlays: delete, edit, duplicate, split, and done.
class _SoundOverlayControls extends StatelessWidget {
  const _SoundOverlayControls({required this.item});

  final TimelineOverlayItem item;

  @override
  Widget build(BuildContext context) {
    return VideoEditorTimelineControls(
      onDelete: () => _removeSound(context: context),
      onEdit: () => _editSound(context: context),
      onDuplicated: () => _duplicateSound(context: context),
      onSplit: () => _splitSound(context: context),
      onDone: () => TimelineOverlayControls._deselect(context),
    );
  }

  Future<void> _editSound({required BuildContext context}) async {
    final editor = VideoEditorScope.of(context).editor;
    if (editor == null) return;

    final tracks = editor.stateManager.audioTracks;
    final sound = tracks.where((t) => t.id == item.id).firstOrNull;
    if (sound == null) return;

    final timingResult = await Navigator.of(context).push<AudioTimingResult>(
      PageRouteBuilder(
        settings: const RouteSettings(name: 'audio_timing'),
        opaque: false,
        barrierColor: VineTheme.transparent,
        transitionsBuilder: (_, animation, _, child) =>
            FadeTransition(opacity: animation, child: child),
        pageBuilder: (_, _, _) => VideoAudioEditorTimingScreen(sound: sound),
      ),
    );
    if (timingResult == null || !context.mounted) return;

    switch (timingResult) {
      case AudioTimingConfirmed(:final sound):
        final updatedTracks = tracks
            .map((t) => t.id == item.id ? sound : t)
            .map((e) => e.toJson())
            .toList();
        editor.addHistory(
          meta: {
            ...editor.stateManager.activeMeta,
            VideoEditorConstants.audioStateHistoryKey: updatedTracks,
          },
        );
      case AudioTimingDeleted():
        _removeSound(context: context);
    }
  }

  void _removeSound({required BuildContext context}) {
    final editor = VideoEditorScope.of(context).editor;
    if (editor == null) return;

    final tracks = editor.stateManager.audioTracks;
    final updatedTracks = tracks
        .where((t) => t.id != item.id)
        .map((e) => e.toJson())
        .toList();

    editor.addHistory(
      meta: {
        ...editor.stateManager.activeMeta,
        VideoEditorConstants.audioStateHistoryKey: updatedTracks,
      },
    );

    context.read<TimelineOverlayBloc>().add(
      const TimelineOverlayItemSelected(null),
    );
  }

  void _duplicateSound({required BuildContext context}) {
    final editor = VideoEditorScope.of(context).editor;
    if (editor == null) return;

    final tracks = editor.stateManager.audioTracks;
    final trackIdx = tracks.indexWhere((t) => t.id == item.id);
    if (trackIdx < 0) return;

    final copy = tracks[trackIdx].copyWith(id: _copyId(item.id));
    final updatedTracks = List.of(tracks)..insert(trackIdx + 1, copy);

    editor.addHistory(
      meta: {
        ...editor.stateManager.activeMeta,
        VideoEditorConstants.audioStateHistoryKey: updatedTracks
            .map((e) => e.toJson())
            .toList(),
      },
    );
    context.read<TimelineOverlayBloc>().add(
      TimelineOverlayItemSelected(copy.id),
    );
  }

  void _splitSound({required BuildContext context}) {
    final editor = VideoEditorScope.of(context).editor;
    if (editor == null) return;

    final splitAt = _validSplitPosition(context, item);
    if (splitAt == null) return;

    final tracks = editor.stateManager.audioTracks;
    final trackIdx = tracks.indexWhere((t) => t.id == item.id);
    if (trackIdx < 0) return;

    final track = tracks[trackIdx];
    final offsetShift = splitAt - item.startTime;
    final second = track.copyWith(
      id: _copyId(item.id),
      startOffset: track.startOffset + offsetShift,
      startTime: splitAt,
      endTime: item.endTime,
    );

    final updatedTracks = List.of(tracks)
      ..[trackIdx] = track.copyWith(endTime: splitAt)
      ..insert(trackIdx + 1, second);

    editor.addHistory(
      meta: {
        ...editor.stateManager.activeMeta,
        VideoEditorConstants.audioStateHistoryKey: updatedTracks
            .map((e) => e.toJson())
            .toList(),
      },
    );
    context.read<TimelineOverlayBloc>().add(
      TimelineOverlayItemSelected(second.id),
    );
  }
}

String _copyId(String id) =>
    '${id}_copy_${DateTime.now().microsecondsSinceEpoch}';

Duration? _validSplitPosition(BuildContext context, TimelineOverlayItem item) {
  final splitAt = context.read<VideoEditorMainBloc>().state.currentPosition;
  if (splitAt <= item.startTime || splitAt >= item.endTime) {
    ScaffoldMessenger.of(context).showSnackBar(
      DivineSnackbarContainer.snackBar(
        context.l10n.videoEditorSplitPlayheadOutsideClip,
      ),
    );
    return null;
  }

  return splitAt;
}
