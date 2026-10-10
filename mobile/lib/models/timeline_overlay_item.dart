// ABOUTME: Data model for overlay items (layers, filters, sounds) on the
// ABOUTME: video editor timeline. Each item has a time position, duration,
// ABOUTME: row assignment, and trim state.

import 'dart:typed_data';

import 'package:equatable/equatable.dart';
import 'package:openvine/models/video_editor/editor_video_effect.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// Whether [layer] is a draw layer that can take part in a merge.
///
/// Mirrors `pro_image_editor`'s `PaintLayerMergeManager.isMergeable`: a censor
/// layer, a layer scheduled to a video-timeline window ([Layer.startTime] /
/// [Layer.endTime]), or one carrying enter/leave animations or keyframes
/// cannot be baked into a single static merged layer.
bool isMergeableDrawLayer(Layer? layer) =>
    layer is PaintLayer &&
    !layer.isCensor &&
    layer.startTime == null &&
    layer.endTime == null &&
    layer.animations.isEmpty &&
    !layer.hasKeyframes;

/// The type of overlay on the timeline.
enum TimelineOverlayType {
  /// Visual overlay: text, drawing, sticker, etc.
  layer,

  /// Filter effect applied to the video.
  filter,

  /// Tune adjustment (brightness, contrast, …) applied to the video.
  tune,

  /// Audio track added on top of the original video audio.
  sound,

  /// Caption cue (burned-in caption layer or CC overlay cue).
  captions,

  /// Video effect (glitch, VHS, old film, …) that distorts the picture.
  effect,
}

/// The audio source for a sound overlay item.
enum AudioSource {
  /// The original audio track extracted from the video clips.
  original,

  /// A custom audio track added by the user.
  custom,
}

/// An overlay item positioned on the video editor timeline.
///
/// Items live in typed strips (layer / filter / sound) and can be
/// repositioned in time (horizontal) and in z-order (vertical row).
///
/// For layers, lower [row] values render in front (higher z-index).
class TimelineOverlayItem extends Equatable {
  const TimelineOverlayItem({
    required this.id,
    required this.type,
    required this.startTime,
    required this.endTime,
    this.row = 0,
    this.label = '',
    this.layer,
    this.maxDuration,
    this.sourceDuration,
    this.startOffset = Duration.zero,
    this.waveformLeftChannel,
    this.waveformRightChannel,
    this.audioSource,
    this.fadeIn = Duration.zero,
    this.fadeOut = Duration.zero,
    this.effectType,
    this.keyframeTimes = const [],
    this.effectOnBeat = false,
  });

  /// Unique identifier.
  final String id;

  /// Determines which strip this item belongs to.
  final TimelineOverlayType type;

  /// Where the item starts on the timeline.
  final Duration startTime;

  /// Where the item ends on the timeline.
  final Duration endTime;

  /// Row index within the strip. For layers, lower row = higher z-index
  /// (rendered in front).
  final int row;

  /// Human-readable label (e.g. "Blur", "Beat Drop", "Hello World").
  final String label;

  /// The original layer data.
  final Layer? layer;

  /// Maximum allowed duration for this item.
  ///
  /// When set (e.g. for sound items), trimming cannot extend
  /// the item beyond this duration — the item moves instead.
  final Duration? maxDuration;

  /// Full duration of the underlying audio source for sound items.
  ///
  /// `null` for non-sound items or when the source duration is unknown.
  /// Distinct from [maxDuration] (which is the remaining audio *after*
  /// [startOffset]); the waveform painter needs the full-source basis to map
  /// samples to time when [startOffset] is non-zero.
  final Duration? sourceDuration;

  /// Offset into the audio source where the visible segment begins.
  ///
  /// Advancing this — e.g. by left-trimming a sound item — scrolls the
  /// waveform so the trimmed-away head leaves the view, rather than the tail
  /// being clipped. [Duration.zero] for non-sound items.
  final Duration startOffset;

  /// Left audio waveform amplitude samples for sound items.
  final Float32List? waveformLeftChannel;

  /// Right audio waveform amplitude samples for sound items.
  final Float32List? waveformRightChannel;

  /// The audio source for sound overlay items.
  ///
  /// `null` for non-sound items.
  final AudioSource? audioSource;

  /// How long a sound item fades in from silence. [Duration.zero] for
  /// non-sound items and sounds that start at full volume.
  final Duration fadeIn;

  /// How long a sound item fades out to silence. [Duration.zero] for
  /// non-sound items and sounds that stop at full volume.
  final Duration fadeOut;

  /// The look of an effect item, which its tile names in the user's language.
  ///
  /// `null` for non-effect items.
  final EditorEffectType? effectType;

  /// When a layer item's keyframes sit, measured from [startTime] and in
  /// order. Empty for any other item and a layer without keyframes.
  ///
  /// A snapshot rather than a read of [layer]: the editor changes a layer's
  /// keyframes in place while it is dragged on the canvas, and only a copy
  /// taken when the item is built tells the timeline that they changed. Times
  /// before 0 or past [duration] belong to keyframes outside the layer's own
  /// range, which still shape its motion but are not shown.
  final List<Duration> keyframeTimes;

  /// Whether an effect item fires on the beat of the music, which its tile
  /// says next to the effect's name.
  final bool effectOnBeat;

  /// Whether a sound item fades in or out at all.
  bool get hasFade => fadeIn > Duration.zero || fadeOut > Duration.zero;

  /// Start time in seconds for layout calculations.
  double get startTimeInSeconds => startTime.inMilliseconds / 1000.0;
  double get durationInSeconds => duration.inMilliseconds / 1000;

  Duration get duration => endTime - startTime;

  TimelineOverlayItem copyWith({
    String? id,
    TimelineOverlayType? type,
    Duration? startTime,
    Duration? endTime,
    int? row,
    String? label,
    Layer? layer,
    Duration? maxDuration,
    Duration? sourceDuration,
    Duration? startOffset,
    Float32List? waveformLeftChannel,
    Float32List? waveformRightChannel,
    AudioSource? audioSource,
    Duration? fadeIn,
    Duration? fadeOut,
    EditorEffectType? effectType,
    List<Duration>? keyframeTimes,
    bool? effectOnBeat,
  }) {
    return TimelineOverlayItem(
      id: id ?? this.id,
      type: type ?? this.type,
      startTime: startTime ?? this.startTime,
      endTime: endTime ?? this.endTime,
      row: row ?? this.row,
      label: label ?? this.label,
      layer: layer ?? this.layer,
      maxDuration: maxDuration ?? this.maxDuration,
      sourceDuration: sourceDuration ?? this.sourceDuration,
      startOffset: startOffset ?? this.startOffset,
      waveformLeftChannel: waveformLeftChannel ?? this.waveformLeftChannel,
      waveformRightChannel: waveformRightChannel ?? this.waveformRightChannel,
      audioSource: audioSource ?? this.audioSource,
      fadeIn: fadeIn ?? this.fadeIn,
      fadeOut: fadeOut ?? this.fadeOut,
      effectType: effectType ?? this.effectType,
      keyframeTimes: keyframeTimes ?? this.keyframeTimes,
      effectOnBeat: effectOnBeat ?? this.effectOnBeat,
    );
  }

  @override
  List<Object?> get props => [
    id,
    type,
    startTime,
    endTime,
    row,
    label,
    layer,
    maxDuration,
    sourceDuration,
    startOffset,
    waveformLeftChannel,
    waveformRightChannel,
    audioSource,
    fadeIn,
    fadeOut,
    effectType,
    keyframeTimes,
    effectOnBeat,
  ];
}
