// ABOUTME: An audio visualizer overlay: the look a creator picked, kept in the
// ABOUTME: meta of its widget layer on the canvas.

import 'dart:typed_data';

import 'package:divine_ui/divine_ui.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/layer_animation_storage.dart';
import 'package:openvine/extensions/layer_keyframes.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:openvine/utils/audio_band_energies.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as pve;
import 'package:pro_video_editor/pro_video_editor.dart'
    show AudioVisualizerStyle;

/// The meta key that names what kind of widget layer a layer is.
const String audioVisualizerLayerKindKey = 'kind';

/// The [audioVisualizerLayerKindKey] value of an audio visualizer layer.
const String audioVisualizerLayerKind = 'divine.audioVisualizer';

/// The meta key of the visualizer's [AudioVisualizerStyle], by name.
const String audioVisualizerLayerStyleKey = 'style';

/// The meta key of the visualizer's color, as an ARGB integer.
const String audioVisualizerLayerColorKey = 'color';

/// The meta key of how many bands the visualizer shows; absent for the
/// style's own number.
const String audioVisualizerLayerBandCountKey = 'bandCount';

/// The meta key of how lively the visualizer reacts, from 0 to 1.
const String audioVisualizerLayerReactionKey = 'reaction';

/// The meta key of how much of its share a bar fills; absent for the style's
/// own width.
const String audioVisualizerLayerBarFillKey = 'barFill';

/// What an audio visualizer layer draws: bars or a wave in one color, moving
/// with everything that plays in the video.
///
/// Stored in both meta slots of its `WidgetLayer`, like a detached clip, so it
/// survives undo, drafts and the re-import of a draft.
class AudioVisualizerLayerData extends Equatable {
  const AudioVisualizerLayerData({
    this.style = AudioVisualizerStyle.bars,
    this.color = VideoEditorConstants.audioVisualizerDefaultColor,
    this.bands,
    this.reaction = VideoEditorConstants.audioVisualizerDefaultReaction,
    this.barFill,
  });

  /// How the visualizer draws the sound.
  final AudioVisualizerStyle style;

  /// The color it draws in.
  final Color color;

  /// How many frequency bands it shows, or `null` for its style's own
  /// number, [VideoEditorConstants.audioVisualizerBandCount].
  final int? bands;

  /// How lively it reacts to the sound, from 0 (calm) to 1 (lively); see
  /// `audioVisualizerLevels`.
  final double reaction;

  /// How much of its share a bar fills, or `null` for the style's own
  /// width, [VideoEditorConstants.audioVisualizerDefaultBarFill]. The wave
  /// has no bars and ignores it.
  final double? barFill;

  /// How many frequency bands the visualizer shows: [bands], or its style's
  /// own number, within what the sound is measured in.
  int get bandCount =>
      (bands ?? VideoEditorConstants.audioVisualizerBandCount(style)).clamp(
        VideoEditorConstants.audioVisualizerMinBandCount,
        audioBandCount,
      );

  /// How much of its share a bar fills as it is drawn: [barFill], or the
  /// style's own width.
  double get effectiveBarFill =>
      barFill ?? VideoEditorConstants.audioVisualizerDefaultBarFill(style);

  /// This visualizer drawn from [energies], band energies laid out by
  /// `bandEnergies` (none rests it). The editor, the sheet preview and the
  /// export all draw through it, so they show the same shapes. [color]
  /// replaces [AudioVisualizerLayerData.color], as the export's does to carry
  /// the layer's opacity.
  pve.LayerAudioVisualizer visualizerFor(
    Float32List energies, {
    Color? color,
  }) => pve.LayerAudioVisualizer(
    style: style,
    color: color ?? this.color,
    bandCount: bandCount,
    levels: audioVisualizerLevels(
      energies,
      bandCount: bandCount,
      reaction: reaction,
    ),
    framesPerSecond: audioBandFrameRate.toDouble(),
    barFill: effectiveBarFill,
  );

  /// The width of the visualizer's box against its height.
  double get aspectRatio =>
      VideoEditorConstants.audioVisualizerAspectRatio(style);

  /// The meta stored on the layer.
  Map<String, dynamic> toMeta() => {
    audioVisualizerLayerKindKey: audioVisualizerLayerKind,
    audioVisualizerLayerStyleKey: style.name,
    audioVisualizerLayerColorKey: color.toARGB32(),
    audioVisualizerLayerBandCountKey: ?bands,
    audioVisualizerLayerReactionKey: reaction,
    audioVisualizerLayerBarFillKey: ?barFill,
  };

  /// This visualizer with what is given changed.
  AudioVisualizerLayerData copyWith({
    AudioVisualizerStyle? style,
    Color? color,
    int? bands,
    double? reaction,
    double? barFill,
  }) => AudioVisualizerLayerData(
    style: style ?? this.style,
    color: color ?? this.color,
    bands: bands ?? this.bands,
    reaction: reaction ?? this.reaction,
    barFill: barFill ?? this.barFill,
  );

  /// Whether [meta] describes an audio visualizer.
  static bool isAudioVisualizerMeta(Map<String, dynamic>? meta) =>
      meta != null &&
      meta[audioVisualizerLayerKindKey] == audioVisualizerLayerKind;

  /// Whether [layer] is an audio visualizer. Checks the kind alone, without
  /// reading the rest of the meta as [of] does: the canvas asks it of every
  /// layer on every edit.
  static bool isAudioVisualizerLayer(Layer layer) =>
      layer is WidgetLayer &&
      (isAudioVisualizerMeta(layer.exportConfigs.meta) ||
          isAudioVisualizerMeta(layer.meta));

  /// The visualizer [meta] describes, or `null` when it describes none. An
  /// unknown style draws bars, and anything else missing or out of range
  /// takes its default, so a visualizer saved before an option existed opens
  /// as it looked.
  static AudioVisualizerLayerData? fromMeta(Map<String, dynamic>? meta) {
    if (!isAudioVisualizerMeta(meta)) return null;
    final styleName = meta![audioVisualizerLayerStyleKey];
    final bands = meta[audioVisualizerLayerBandCountKey];
    final color = meta[audioVisualizerLayerColorKey];
    final reaction = meta[audioVisualizerLayerReactionKey];
    final barFill = meta[audioVisualizerLayerBarFillKey];
    return AudioVisualizerLayerData(
      style: AudioVisualizerStyle.values.firstWhere(
        (style) => style.name == styleName,
        orElse: () => AudioVisualizerStyle.bars,
      ),
      color: color is int
          ? colorFromArgb32(color)
          : VideoEditorConstants.audioVisualizerDefaultColor,
      bands:
          bands is int &&
              bands >= VideoEditorConstants.audioVisualizerMinBandCount &&
              bands <= audioBandCount
          ? bands
          : null,
      reaction: reaction is num && reaction >= 0 && reaction <= 1
          ? reaction.toDouble()
          : VideoEditorConstants.audioVisualizerDefaultReaction,
      barFill: barFill is num && barFill > 0 && barFill <= 1
          ? barFill.toDouble()
          : null,
    );
  }

  /// The visualizer [layer] draws, read from whichever of its two meta slots
  /// holds it: `exportConfigs.meta` on a re-imported layer, `Layer.meta` on
  /// one built in this session.
  static AudioVisualizerLayerData? of(Layer layer) {
    if (layer is! WidgetLayer) return null;
    return fromMeta(layer.exportConfigs.meta) ?? fromMeta(layer.meta);
  }

  @override
  List<Object?> get props => [style, color, bands, reaction, barFill];
}

/// The image layer the audio visualizer [item] exports as: [data] drawn from
/// [energies], the band energies of everything that plays on the exported
/// video (see `VideoEditorAudioLevelResolver.energiesOnOutput`), laid out by
/// [mapping] over the frame the image layers are composited on.
///
/// Its raster is not used: the export draws the visualizer itself, in the
/// layer's unrotated box with the rotation passed on, as a censor area is.
/// [ExportedLayer.logicalSize] is the box turned by the layer's rotation, so
/// the unturned box is worked back out of it with the visualizer's aspect
/// ratio. The layer's opacity, baked into every other layer's raster, goes
/// into the color instead; keyframes carry their own.
///
/// Without [energies] the visualizer rests, as it does in the editor before
/// the sound is read.
pve.ImageLayer audioVisualizerImageLayer(
  ExportedLayer item,
  AudioVisualizerLayerData data, {
  required Size bodySize,
  required ExportLayerMapping mapping,
  required TransitionTimelineMap timelineMap,
  Float32List? energies,
}) {
  final layer = item.layer;
  final size = unrotatedLayerBox(
    boundingBox: item.logicalSize,
    rotation: layer.rotation,
    aspectRatio: data.aspectRatio,
  );
  final color = layer.hasKeyframes
      ? data.color
      : data.color.withValues(alpha: data.color.a * layer.opacity);
  return pve.ImageLayer.audioVisualizer(
    visualizer: data.visualizerFor(energies ?? Float32List(0), color: color),
    startTime: timelineMap.editorToOutputOrNull(layer.startTime),
    endTime: timelineMap.editorToOutputOrNull(layer.endTime),
    offset: exportedLayerTopLeft(
      anchor: layer.offset,
      bodySize: bodySize,
      logicalSize: size,
      mapping: mapping,
    ),
    size: size * mapping.scale,
    rotation: layer.rotation,
    animations: [
      ...layer.divineAnimationsForExport(
        bodySize: bodySize,
        logicalSize: size,
        mapping: mapping,
      ),
      ...layer.divineKeyframeEffectsForExport(timelineMap: timelineMap),
    ],
    keyframes: layer.divineKeyframesForExport(
      bodySize: bodySize,
      logicalSize: size,
      mapping: mapping,
      turnedRaster: false,
    ),
    keyframeClock: layer.divineKeyframeClockForExport(timelineMap: timelineMap),
  );
}
