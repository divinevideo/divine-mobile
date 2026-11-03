// ABOUTME: Counts what the step a draft shows holds (layer kinds, clip
// ABOUTME: features, sounds) so draft load and save logs say what is heavy

import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/extensions/video_editor_history_extensions.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/caption_track.dart';
import 'package:openvine/models/video_editor/sticker_group.dart';

/// What the step a draft shows holds: the kinds of its layers, the timeline
/// features its clips use, and its sounds.
///
/// `EditorStateHistoryStats` says how much a draft holds; this says what.
/// A draft that runs the editor out of memory (#10677) needs both in its
/// report, because a handful of layers can cost more than a long history.
/// These hold counts only, never layer content or file names.
class EditorStateContents {
  /// Creates the contents from the counts.
  const EditorStateContents({
    this.layerKinds = const {},
    this.maskedLayers = 0,
    this.layerKeyframes = 0,
    this.clipFeatures = const {},
    this.audioTracks = 0,
    this.voiceOvers = 0,
    this.audioSourceSeconds = 0,
    this.audioFeatures = const {},
    this.captions = 0,
    this.effects = 0,
  });

  /// Counts the shown step of the persisted, unminified [history] the editor
  /// exports, and the features of the draft's [clips].
  factory EditorStateContents.of({
    required Map<String, dynamic> history,
    required List<DivineVideoClip> clips,
  }) {
    final entries = history[_historyKey];
    final steps = entries is List ? entries : const <Object?>[];
    final position = history[_positionKey];
    final shown = position is int && position >= 0 && position < steps.length
        ? steps[position]
        : (steps.isEmpty ? null : steps.last);
    final references = history[_referencesKey];

    final layerKinds = <String, int>{};
    var maskedLayers = 0;
    var layerKeyframes = 0;
    final layers = shown is Map ? shown[_layersKey] : null;
    for (final stored in layers is List ? layers : const <Object?>[]) {
      if (stored is! Map) continue;
      // A step stores an unchanged layer as its id plus the fields that
      // differ from the copy under `references`.
      final reference = references is Map ? references[stored[_idKey]] : null;
      final layer = {if (reference is Map) ...reference, ...stored};
      _bump(layerKinds, _kindOf(layer));
      if (layer[_maskKey] is Map) maskedLayers++;
      final keyframes = layer[_keyframesKey];
      if (keyframes is List) layerKeyframes += keyframes.length;
    }

    final clipFeatures = <String, int>{};
    for (final clip in clips) {
      if (clip.playbackSpeed != null && clip.playbackSpeed != 1.0) {
        _bump(clipFeatures, 'speed');
      }
      if (clip.speedRamp != null) _bump(clipFeatures, 'ramp');
      if (clip.reversed) _bump(clipFeatures, 'reversed');
      if (clip.mask != null) _bump(clipFeatures, 'mask');
      if (clip.keyframes.isNotEmpty) _bump(clipFeatures, 'keyframes');
      if (clip.chromaKey != null || clip.captureChromaKey != null) {
        _bump(clipFeatures, 'chroma key');
      }
      if (clip.stabilization != null) _bump(clipFeatures, 'stabilized');
      if (clip.transition != null) _bump(clipFeatures, 'transition');
      if (clip.isFreezeFrame) _bump(clipFeatures, 'freeze');
      if (clip.isStopMotion) _bump(clipFeatures, 'stop motion');
    }

    final meta = shown is Map ? shown[_metaKey] : null;
    final sounds = _audioTracksOf(meta is Map ? meta : null);
    final audioFeatures = <String, int>{};
    var sourceSeconds = 0.0;
    for (final sound in sounds) {
      sourceSeconds += sound.duration ?? 0;
      if (!sound.voiceEffect.isNone) _bump(audioFeatures, 'voice effect');
      if (sound.noiseReduction) _bump(audioFeatures, 'denoised');
      if (!sound.equalizer.isNone) _bump(audioFeatures, 'eq');
      if (sound.ducksUnderVoiceOver) _bump(audioFeatures, 'ducking');
      if (sound.playbackSpeed != 1 || sound.speedRampMap != null) {
        _bump(audioFeatures, 'speed');
      }
    }

    return EditorStateContents(
      layerKinds: layerKinds,
      maskedLayers: maskedLayers,
      layerKeyframes: layerKeyframes,
      clipFeatures: clipFeatures,
      audioTracks: sounds.length,
      voiceOvers: sounds.where((sound) => sound.isVoiceOver).length,
      audioSourceSeconds: sourceSeconds.round(),
      audioFeatures: audioFeatures,
      captions: _captionsOf(meta is Map ? meta : null),
      effects: meta is Map
          ? videoEffectsFromMeta(
              meta[VideoEditorConstants.effectsStateHistoryKey],
            ).length
          : 0,
    );
  }

  /// How many layers of each kind the shown step holds: the layer type, or
  /// for a widget layer what it shows (a sticker, a detached clip, …).
  final Map<String, int> layerKinds;

  /// Shown layers with a shape mask.
  final int maskedLayers;

  /// Keyframes over all shown layers; object tracking writes one per tracked
  /// frame.
  final int layerKeyframes;

  /// How many clips use each timeline feature.
  final Map<String, int> clipFeatures;

  /// Sounds on the timeline, voice-over takes included.
  final int audioTracks;

  /// The [audioTracks] that are voice-over takes.
  final int voiceOvers;

  /// The length of every sound's source file, summed, in seconds.
  final int audioSourceSeconds;

  /// How many sounds use each sound feature.
  final Map<String, int> audioFeatures;

  /// Caption cues.
  final int captions;

  /// Video effects on the timeline.
  final int effects;

  @override
  String toString() {
    final audioDetails = [
      if (voiceOvers > 0) 'voice-over $voiceOvers',
      if (audioTracks > 0) '$audioSourceSeconds s source',
      ..._counts(audioFeatures),
    ].join(', ');
    return [
      if (layerKinds.isNotEmpty)
        'layer kinds ${_counts(layerKinds).join(', ')}',
      if (maskedLayers > 0) 'masked layers $maskedLayers',
      if (layerKeyframes > 0) 'layer keyframes $layerKeyframes',
      if (clipFeatures.isNotEmpty) 'clip ${_counts(clipFeatures).join(', ')}',
      if (audioTracks > 0) 'audio $audioTracks ($audioDetails)',
      if (captions > 0) 'captions $captions',
      if (effects > 0) 'effects $effects',
    ].join('; ');
  }
}

const _historyKey = 'history';
const _positionKey = 'position';
const _referencesKey = 'references';
const _layersKey = 'layers';
const _idKey = 'id';
const _typeKey = 'type';
const _metaKey = 'meta';
const _maskKey = 'mask';
const _keyframesKey = 'keyframes';
const _kindKey = 'kind';
const _exportConfigsKey = 'exportConfigs';
const _divineKindPrefix = 'divine.';

void _bump(Map<String, int> counts, String key) =>
    counts[key] = (counts[key] ?? 0) + 1;

/// `name count` for each entry of [counts], most frequent first.
List<String> _counts(Map<String, int> counts) {
  final entries = counts.entries.toList()
    ..sort((a, b) => b.value.compareTo(a.value));
  return [for (final entry in entries) '${entry.key} ${entry.value}'];
}

String _kindOf(Map<Object?, Object?> layer) {
  // A widget layer keeps what it shows in its export configs, as the editor
  // reads it (`exportConfigs.meta ?? meta`).
  final exportConfigs = layer[_exportConfigsKey];
  final exportMeta = exportConfigs is Map ? exportConfigs[_metaKey] : null;
  final meta = exportMeta ?? layer[_metaKey];
  final layerMeta = meta is Map<String, dynamic> ? meta : null;
  if (layerMeta?[VideoEditorConstants.captionCueMetaKey] == true) {
    return 'caption';
  }
  final kind = layerMeta?[_kindKey];
  if (kind is String) {
    return kind.startsWith(_divineKindPrefix)
        ? kind.substring(_divineKindPrefix.length)
        : kind;
  }
  if (isStickerLayerMeta(layerMeta)) return 'sticker';
  final type = layer[_typeKey];
  return type is String ? type : 'unknown';
}

List<AudioEvent> _audioTracksOf(Map<Object?, Object?>? meta) {
  final raw = meta?[VideoEditorConstants.audioStateHistoryKey];
  if (raw is! List) return const [];
  return [
    for (final track in raw)
      if (track is Map<String, dynamic>) ?_audioTrackOrNull(track),
  ];
}

AudioEvent? _audioTrackOrNull(Map<String, dynamic> json) {
  try {
    return AudioEvent.fromJson(json);
  } on Object {
    // A malformed sound must not break a log line; it is left out.
    return null;
  }
}

int _captionsOf(Map<Object?, Object?>? meta) {
  final raw = meta?[VideoEditorConstants.captionsStateHistoryKey];
  if (raw is! Map<Object?, Object?>) return 0;
  try {
    return CaptionTrack.fromJson(raw).cues.length;
  } on Object {
    // A malformed caption track counts as none, as the editor treats it.
    return 0;
  }
}
