// ABOUTME: The style of a timeline clip — volume, EQ, speed, color mask and
// ABOUTME: shape mask — as one unit that Copy style lifts off a clip and Paste
// ABOUTME: style writes onto others (#10258).

import 'package:equatable/equatable.dart';
import 'package:models/models.dart' show EqualizerSettings;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show LayerMask;

/// Whether Copy style is offered on [clip]: a clip of footage.
///
/// A placeholder or a freeze frame is a still, whose sound, speed and color
/// mask mean nothing, and a stop-motion clip is a sequence of stills; copying
/// from one of them would paste defaults over every setting of the target.
bool canCopyClipStyle(DivineVideoClip clip) =>
    !clip.isPlaceholder && !clip.isFreezeFrame && !clip.isStopMotion;

/// Whether a pasted style changes anything on [clip]: a clip of footage takes
/// all of it, a freeze frame only the shape mask, and a placeholder or a
/// stop-motion clip none.
bool canPasteClipStyle(DivineVideoClip clip) =>
    !clip.isPlaceholder && !clip.isStopMotion;

/// Everything about how a timeline clip plays and looks that is not its
/// footage, its trim or its place on the timeline.
///
/// Pasting makes the target match: a clip copied without a color mask or a
/// shape mask takes the target's away, as a flat EQ flattens the target's.
class ClipStyle extends Equatable {
  /// Creates a style.
  const ClipStyle({
    required this.volume,
    required this.equalizer,
    required this.playbackSpeed,
    this.chromaKey,
    this.mask,
  });

  /// The style [clip] currently has.
  ///
  /// A key the clip was recorded with but that is not baked in yet is not
  /// part of it: the clip does not show it.
  factory ClipStyle.of(DivineVideoClip clip) => ClipStyle(
    volume: clip.volume,
    equalizer: clip.equalizer,
    playbackSpeed: clip.playbackSpeed ?? 1,
    chromaKey: clip.chromaKey,
    mask: clip.mask,
  );

  /// Playback volume, 0 for muted.
  final double volume;

  /// How the clip's sound is raised or lowered per frequency band.
  final EqualizerSettings equalizer;

  /// Playback speed multiplier, 1 for normal speed.
  final double playbackSpeed;

  /// The color mask, or `null` for none.
  ///
  /// Unlike the other settings it is baked into the clip's file, so pasting
  /// it renders the target again; see `ClipEditorStylePasteRequested`.
  final ClipChromaKey? chromaKey;

  /// The shape mask, or `null` for none.
  ///
  /// Measured in the exported frame, which every timeline clip shares, so it
  /// carries over as it is.
  final LayerMask? mask;

  /// Whether pasting onto [clip] would leave it as it is.
  bool isOn(DivineVideoClip clip) =>
      hasSettingsOn(clip) && !needsColorMaskChange(clip);

  /// Whether [clip] already has every setting of this style it takes, the
  /// color mask aside.
  bool hasSettingsOn(DivineVideoClip clip) {
    if (!canPasteClipStyle(clip)) return true;
    if (clip.mask != mask) return false;
    if (clip.isFreezeFrame) return true;
    return clip.volume == volume &&
        clip.equalizer == equalizer &&
        (clip.playbackSpeed ?? 1) == playbackSpeed;
  }

  /// Whether pasting onto [clip] has to put on, change or take off its color
  /// mask, which a freeze frame never takes.
  bool needsColorMaskChange(DivineVideoClip clip) {
    if (!canPasteClipStyle(clip) || clip.isFreezeFrame) return false;
    return clip.chromaKey != chromaKey ||
        // A key recorded but not baked yet would bake in on the next pass.
        (chromaKey == null && clip.captureChromaKey != null);
  }

  /// [clip] with every setting of this style but the color mask.
  ///
  /// The color mask needs a render and is put on or taken off before this,
  /// by the bloc. A freeze frame only takes the shape mask.
  DivineVideoClip applyTo(DivineVideoClip clip) {
    if (!canPasteClipStyle(clip)) return clip;
    if (clip.isFreezeFrame) {
      return clip.copyWith(mask: mask, clearMask: mask == null);
    }
    return clip.copyWith(
      volume: volume,
      equalizer: equalizer,
      playbackSpeed: playbackSpeed == 1 ? null : playbackSpeed,
      clearPlaybackSpeed: playbackSpeed == 1,
      mask: mask,
      clearMask: mask == null,
    );
  }

  @override
  List<Object?> get props => [
    volume,
    equalizer,
    playbackSpeed,
    chromaKey,
    mask,
  ];
}
