import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/effects_editor/video_editor_effects_cubit.dart';
import 'package:openvine/blocs/video_editor/main_editor/video_editor_main_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/blocs/video_editor/tune_editor/video_editor_tune_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/media_query_extensions.dart';
import 'package:openvine/extensions/tune_adjustment_matrix_extensions.dart';
import 'package:openvine/extensions/video_editor_extensions.dart';
import 'package:openvine/extensions/video_editor_history_extensions.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/timeline_overlay_item.dart';
import 'package:openvine/models/video_editor/detached_clip_layer.dart';
import 'package:openvine/models/video_editor/editor_censor_area.dart';
import 'package:openvine/models/video_editor/title_style.dart';
import 'package:openvine/screens/video_editor/video_audio_editor_timing_screen.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_chroma_key.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_layer_view.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_opacity.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_reattach.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_transform.dart';
import 'package:openvine/widgets/video_editor/effects_editor/flashing_effect_snack_bar.dart';
import 'package:openvine/widgets/video_editor/effects_editor/open_effects_editor.dart';
import 'package:openvine/widgets/video_editor/main_editor/video_editor_scope.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_audio_fade_sheet.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_layer_animation_sheet.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_saved_title_styles_sheet.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_timeline_controls.dart';
import 'package:openvine/widgets/video_editor/timeline_editor/controls/video_editor_voice_effect_sheet.dart';
import 'package:openvine/widgets/video_editor/tune_editor/open_tune_editor.dart';
import 'package:pro_image_editor/core/models/layers/layer.dart';
import 'package:pro_image_editor/features/filter_editor/types/filter_state.dart';
import 'package:pro_image_editor/features/tune_editor/models/tune_adjustment_matrix.dart';

/// Controls shown when an overlay item is selected.
/// Adapts buttons based on the overlay type.
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
      .effect => _EffectOverlayControls(item: item),
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

  /// The layer as the editor holds it right now.
  ///
  /// Every action resolves the layer when it fires rather than using the one
  /// [build] saw. This bar is rebuilt only when the selected item changes,
  /// and `Layer.==` compares id, placement, timing and animations — not a
  /// text layer's colors, font or size — so an edit that only recolours the
  /// text leaves the item "equal", the bar unrebuilt, and a layer captured in
  /// [build] describing a look the editor no longer shows. An action that
  /// copied from that capture would write the old look back.
  Layer? _liveLayer(BuildContext context) => VideoEditorScope.of(
    context,
  ).editor?.activeLayers.where((l) => l.id == item.id).firstOrNull;

  @override
  Widget build(BuildContext context) {
    final scope = VideoEditorScope.of(context);

    // Decides which actions to offer; the actions themselves re-resolve the
    // layer through [_liveLayer].
    final layer = _liveLayer(context);
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
      onDelete: () => _removeLayer(context: context),
      onEdit: isTextLayer ? () => _editTextLayer(context: context) : null,
      onDuplicated: () => _duplicateLayer(context: context),
      onMultiSelect: canMultiSelect
          ? () => _startLayerMultiSelect(context: context)
          : null,
      multiSelectSemanticLabel:
          context.l10n.videoEditorLayerMultiSelectSemanticLabel,
      onSplit: () => _splitLayer(context: context),
      // The way back from Detach, for a detached clip only.
      onReattach: isDetachedClip
          ? () => _reattachLayer(context: context)
          : null,
      // Crop / rotate / flip, for a detached clip only. Every other layer is
      // already whatever shape it was drawn or typed at; a detached clip
      // carries a video file that can genuinely be re-rendered.
      onTransform: isDetachedClip
          ? () => _transformLayer(context: context)
          : null,
      // Green screen, for a detached clip only — and, unlike the timeline's,
      // never baked: the export composites the layer over the track, so the
      // removed area can be left genuinely see-through.
      onChromaKey: isDetachedClip
          ? () => _editChromaKey(context: context)
          : null,
      hasChromaKey:
          isDetachedClip &&
          DetachedClipLayerData.hasChromaKey(
            DetachedClipLayerData.metaOf(layer),
          ),
      // Opacity, for a detached clip only: the export composites it as a
      // `VideoLayer` of its own, which fades it over the track underneath.
      onOpacity: isDetachedClip ? () => _editOpacity(context: context) : null,
      hasOpacity:
          isDetachedClip &&
          DetachedClipLayerData.opacityOf(DetachedClipLayerData.metaOf(layer)) <
              1,
      // Animations are off for a detached clip: the export composites it as a
      // `VideoLayer`, and neither that nor the `VideoSegment` under it carries
      // an `animations` field the way a rasterized `ImageLayer` does. Offering
      // the action would animate the layer in the editor and drop it silently
      // from the file.
      //
      // They are off for a hidden area (blur, pixelate) too: it hides what is
      // beneath it the moment it shows, and an area that slid or faded in
      // would show that for a moment first.
      onAnimate: layer == null || isDetachedClip || isCensorLayer(layer)
          ? null
          : () => _animateLayer(context: context),
      // Saved title styles, for text only. A burned-in caption cue is a text
      // layer too, but it never reaches this bar: the timeline partitions it
      // into the captions strip, whose look the caption track owns.
      onStyles: isTextLayer ? () => _openTitleStyles(context: context) : null,
      onDone: () => TimelineOverlayControls._deselect(context),
    );
  }

  void _removeLayer({required BuildContext context}) {
    // Remove from the ProImageEditor active layers.
    final scope = VideoEditorScope.of(context);
    final editor = scope.editor;
    final layer = _liveLayer(context);
    if (editor != null && layer != null) {
      editor.removeLayer(layer);
    }
  }

  Future<void> _editTextLayer({required BuildContext context}) async {
    final scope = VideoEditorScope.of(context);
    final editor = scope.editor;
    final layer = _liveLayer(context);
    if (editor == null || layer is! TextLayer) return;

    final updatedLayer = await scope.onAddEditTextLayer(layer);
    if (updatedLayer == null) return;

    editor.applyTextLayerChanges(layer, updatedLayer);
  }

  Future<void> _reattachLayer({required BuildContext context}) async {
    final layer = _liveLayer(context);
    if (layer == null) return;
    await reattachDetachedClip(context, layer, item: item);
  }

  Future<void> _transformLayer({required BuildContext context}) async {
    final layer = _liveLayer(context);
    if (layer == null) return;
    await transformDetachedClip(context, layer);
  }

  Future<void> _editChromaKey({required BuildContext context}) async {
    final layer = _liveLayer(context);
    if (layer == null) return;
    await editDetachedClipChromaKey(context, layer);
  }

  Future<void> _editOpacity({required BuildContext context}) async {
    final layer = _liveLayer(context);
    if (layer == null) return;
    await editDetachedClipOpacity(context, layer, item: item);
  }

  Future<void> _animateLayer({required BuildContext context}) async {
    final layer = _liveLayer(context);
    if (layer == null) return;
    await editLayerAnimation(
      context,
      layer,
      // The stable editor-timeline total (sum of clip playback lengths), not
      // item.endTime (the layer's own clamped end) and not
      // VideoEditorMainBloc.totalDuration — the latter is derived from player
      // duration reports and can be a transient zero right after a clip
      // change. A too-small total here would collapse the layer's
      // leave-animation window and drop it from the timeline.
      totalDuration: context.read<ClipEditorBloc>().state.totalDuration,
    );
  }

  /// Opens the saved title styles sheet for the selected text layer and,
  /// when one is chosen, writes it onto the layer through the editor history.
  Future<void> _openTitleStyles({required BuildContext context}) async {
    final scope = VideoEditorScope.of(context);
    final editor = scope.editor;
    final layer = _liveLayer(context);
    if (editor == null || layer is! TextLayer) return;
    // Read before the await: the total is needed after the sheet closes, and
    // the context may be gone by then.
    final totalDuration = context.read<ClipEditorBloc>().state.totalDuration;

    final style = await showSavedTitleStylesSheet(
      context,
      currentStyle: TitleStyle.of(layer),
      sampleText: layer.text,
    );
    // The editor can be torn down while the sheet is open; writing history
    // onto a dead one, or sizing the style against a canvas that is gone,
    // would land the style nowhere.
    if (style == null || !context.mounted) return;

    final layers = List<Layer>.from(editor.activeLayers);
    final index = layers.indexWhere((l) => l.id == layer.id);
    if (index < 0) return;

    layers[index] = style.applyTo(
      layer,
      canvasSize: scope.canvasRenderSize,
      totalDuration: totalDuration,
    );
    editor.addHistory(layers: layers);
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

  void _duplicateLayer({required BuildContext context}) {
    final editor = VideoEditorScope.of(context).editor;
    final layer = _liveLayer(context);
    if (editor == null || layer == null) return;

    final layers = List<Layer>.from(editor.activeLayers);
    final layerIdx = layers.indexWhere((l) => l.id == item.id);
    if (layerIdx < 0) return;

    final copyId = _copyId(layer.id);
    final copy = _reownDetachedClip(
      layer.copyWith(id: copyId, offset: layer.offset + const Offset(24, 24)),
      layerId: copyId,
    );

    layers.insert(layerIdx + 1, copy);
    editor.addHistory(layers: layers);
    context.read<TimelineOverlayBloc>().add(
      TimelineOverlayItemSelected(copy.id),
    );
  }

  void _splitLayer({required BuildContext context}) {
    final editor = VideoEditorScope.of(context).editor;
    final layer = _liveLayer(context);
    if (editor == null || layer == null) return;

    final splitAt = _validSplitPosition(context, item);
    if (splitAt == null) return;

    final layers = List<Layer>.from(editor.activeLayers);
    final layerIdx = layers.indexWhere((l) => l.id == item.id);
    if (layerIdx < 0) return;

    final secondId = _copyId(layer.id);
    // The tail plays on from where the head stopped, so it starts that much
    // further into the clip. Measured from the layer's own start rather than
    // from zero, so splitting a tail again keeps accumulating.
    final headOffset =
        DetachedClipLayerData.sourceOffsetOf(
          DetachedClipLayerData.metaOf(layer),
        ) ??
        Duration.zero;
    final second = _reownDetachedClip(
      layer.copyWith(
        id: secondId,
        startTime: splitAt,
        endTime: item.endTime,
      ),
      layerId: secondId,
      sourceOffset: headOffset + (splitAt - item.startTime),
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

/// Controls for a video effect: delete, edit, duplicate, split, and done.
///
/// Edit reopens the effects editor on this effect, keeping its window.
/// Duplicate places the copy right after it in the list, overlapping until
/// moved, except for a flashing effect, which may not overlap another; split
/// cuts it at the playhead, the tail becoming a new effect whose animation
/// starts over there.
class _EffectOverlayControls extends StatelessWidget {
  const _EffectOverlayControls({required this.item});

  final TimelineOverlayItem item;

  @override
  Widget build(BuildContext context) {
    return VideoEditorTimelineControls(
      onDelete: () => _removeEffect(context: context),
      onEdit: () => openEffectsEditor(
        context.read<VideoEditorMainBloc>(),
        context.read<VideoEditorEffectsCubit>(),
        reduceMotion: context.reduceMotion,
        effectId: item.id,
      ),
      onDuplicated: () => _duplicateEffect(context: context),
      onSplit: () => _splitEffect(context: context),
      onDone: () => TimelineOverlayControls._deselect(context),
    );
  }

  void _removeEffect({required BuildContext context}) {
    VideoEditorScope.of(context).editor?.removeVideoEffect(item.id);
    TimelineOverlayControls._deselect(context);
  }

  void _duplicateEffect({required BuildContext context}) {
    final editor = VideoEditorScope.of(context).editor;
    if (editor == null) return;

    final effects = editor.stateManager.videoEffectEntries;
    final index = effects.indexWhere((e) => e.id == item.id);
    if (index < 0) return;
    // The copy would lie on top of the original and flash along with it.
    if (effects[index].type.isFlashing) {
      showFlashingEffectNotDuplicatedSnackBar(context);
      return;
    }

    final copy = effects[index].withId(_copyId(item.id));
    effects.insert(index + 1, copy);
    editor.setVideoEffectEntries(effects);
    context.read<TimelineOverlayBloc>().add(
      TimelineOverlayItemSelected(copy.id),
    );
  }

  void _splitEffect({required BuildContext context}) {
    final editor = VideoEditorScope.of(context).editor;
    if (editor == null) return;

    final splitAt = _validSplitPosition(context, item);
    if (splitAt == null) return;

    final effects = editor.stateManager.videoEffectEntries;
    final index = effects.indexWhere((e) => e.id == item.id);
    if (index < 0) return;

    final effect = effects[index];
    final second = effect
        .withId(_copyId(item.id))
        .retimed(startTime: splitAt, endTime: item.endTime);

    effects[index] = effect.retimed(
      startTime: item.startTime,
      endTime: splitAt,
    );
    effects.insert(index + 1, second);
    editor.setVideoEffectEntries(effects);
    context.read<TimelineOverlayBloc>().add(
      TimelineOverlayItemSelected(second.id),
    );
  }
}

/// Controls for a tune-adjustment *set* overlay: delete, edit, duplicate,
/// split, and done.
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
    // Every sound with audio to process can change voice: voice-overs,
    // music, bundled, published and imported sounds and extracted clip audio.
    final (canChangeVoice, hasVoiceEffect) = context.select(
      (TimelineOverlayBloc bloc) {
        final track = bloc.state.audioTracks
            .where((track) => track.id == item.id)
            .firstOrNull;
        return (
          track?.originalSource != null,
          track?.hasVoiceProcessing ?? false,
        );
      },
    );
    return VideoEditorTimelineControls(
      onDelete: () => _removeSound(context: context),
      onEdit: () => _editSound(context: context),
      onFade: () => _fadeSound(context: context),
      hasFade: item.hasFade,
      onVoiceEffect: canChangeVoice
          ? () => _changeVoice(context: context)
          : null,
      hasVoiceEffect: hasVoiceEffect,
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

  Future<void> _fadeSound({required BuildContext context}) async {
    final editor = VideoEditorScope.of(context).editor;
    if (editor == null) return;

    final sound = editor.stateManager.audioTracks
        .where((t) => t.id == item.id)
        .firstOrNull;
    if (sound == null) return;

    final result = await VineBottomSheet.show<AudioFadeSelection>(
      context: context,
      expanded: false,
      scrollable: false,
      isScrollControlled: true,
      body: VideoEditorAudioFadeSheet(
        soundLength: item.duration,
        initialFadeIn: sound.fadeInDuration,
        initialFadeOut: sound.fadeOutDuration,
      ),
    );
    if (result == null || !context.mounted) return;

    // Re-read the tracks after the async gap: another edit (an undo, a
    // finished extraction) may have changed them while the sheet was open.
    final tracks = editor.stateManager.audioTracks;
    if (!tracks.any((t) => t.id == item.id)) return;
    editor.addHistory(
      meta: {
        ...editor.stateManager.activeMeta,
        VideoEditorConstants.audioStateHistoryKey: tracks
            .map(
              (t) => t.id == item.id
                  ? t.copyWith(
                      fadeInDuration: result.fadeIn,
                      fadeOutDuration: result.fadeOut,
                    )
                  : t,
            )
            .map((e) => e.toJson())
            .toList(),
      },
    );
  }

  Future<void> _changeVoice({required BuildContext context}) async {
    final editor = VideoEditorScope.of(context).editor;
    if (editor == null) return;

    final sound = editor.stateManager.audioTracks
        .where((t) => t.id == item.id)
        .firstOrNull;
    if (sound == null) return;

    // The sheet loops the take on its own player; the preview playing on
    // underneath would drown it out.
    final mainBloc = context.read<VideoEditorMainBloc>();
    final wasPlaying = mainBloc.state.isPlaying;
    if (wasPlaying) {
      mainBloc.add(const VideoEditorExternalPauseRequested(isPaused: true));
    }
    final processed = await VideoEditorVoiceEffectSheet.show(
      context: context,
      track: sound,
    );
    if (wasPlaying) {
      mainBloc.add(const VideoEditorExternalPauseRequested(isPaused: false));
    }
    if (processed == null || !context.mounted) return;

    // Re-read the tracks after the async gap, and carry only the processed
    // file over: the track's timing is whatever it is now.
    final tracks = editor.stateManager.audioTracks;
    if (!tracks.any((t) => t.id == item.id)) return;
    editor.addHistory(
      meta: {
        ...editor.stateManager.activeMeta,
        VideoEditorConstants.audioStateHistoryKey: tracks
            .map(
              (t) => t.id == item.id
                  ? t.copyWith(
                      id: processed.id,
                      url: processed.url,
                      mimeType: processed.mimeType,
                      clearMimeType: processed.mimeType == null,
                      voiceEffect: processed.voiceEffect,
                      noiseReduction: processed.noiseReduction,
                      originalUrl: processed.originalUrl,
                      clearOriginalUrl: processed.originalUrl == null,
                      originalMimeType: processed.originalMimeType,
                      clearOriginalMimeType: processed.originalMimeType == null,
                    )
                  : t,
            )
            .map((e) => e.toJson())
            .toList(),
      },
    );
    // The processed track has a new id; keep it selected so its controls
    // stay open.
    context.read<TimelineOverlayBloc>().add(
      TimelineOverlayItemSelected(processed.id),
    );
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
    // The fade in stays with the head and the fade out with the tail: the cut
    // itself is a new edge, which starts and ends at full volume.
    final second = track.copyWith(
      id: _copyId(item.id),
      startOffset: track.startOffset + offsetShift,
      startTime: splitAt,
      endTime: item.endTime,
      fadeInDuration: Duration.zero,
    );
    final first = track.copyWith(
      endTime: splitAt,
      fadeOutDuration: Duration.zero,
    );

    final updatedTracks = List.of(tracks)
      ..[trackIdx] = first
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

/// Re-points a copied detached clip's meta at [copy]'s own layer id, and at
/// [sourceOffset] when the copy starts partway into the clip.
///
/// `copyWith` gives the copy a fresh `Layer.id` but carries the meta verbatim,
/// so without this the copy still names the layer it came from — and then reads
/// that layer's window off the timeline while the export uses its own. The two
/// agree only while the copy sits at the same time as the original, which is
/// where a duplicate starts and why the mismatch surfaces only once it moves.
///
/// Returns [copy] unchanged for every other kind of layer.
Layer _reownDetachedClip(
  Layer copy, {
  required String layerId,
  Duration? sourceOffset,
}) {
  if (copy is! WidgetLayer) return copy;
  final meta = DetachedClipLayerData.rebase(
    DetachedClipLayerData.metaOf(copy),
    layerId: layerId,
    sourceOffset: sourceOffset,
  );
  if (meta == null) return copy;
  return copy.copyWith(
    widget: DetachedClipLayerView(meta: meta),
    meta: meta,
    exportConfigs: copy.exportConfigs.copyWith(id: layerId, meta: meta),
  );
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
