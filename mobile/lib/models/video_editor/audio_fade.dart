import 'dart:math' as math;

import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';

/// The gain of a sound track [position] into a track that sounds for
/// [length], faded in over [fadeIn] and out over [fadeOut].
///
/// Linear ramps from and to silence, the quieter one winning where they
/// overlap — the same envelope `pro_video_editor` bakes into the export and
/// `divine_video_player` plays in the preview, so the timeline draws what the
/// creator will hear.
double audioFadeGain({
  required Duration position,
  required Duration length,
  required Duration fadeIn,
  required Duration fadeOut,
}) {
  final inGain = fadeIn > Duration.zero
      ? position.inMicroseconds / fadeIn.inMicroseconds
      : 1.0;
  final outGain = fadeOut > Duration.zero
      ? (length - position).inMicroseconds / fadeOut.inMicroseconds
      : 1.0;
  return math.min(inGain, outGain).clamp(0.0, 1.0);
}

/// Where the exported video ends: the transition-shortened length of
/// [clips], capped at [VideoEditorConstants.maxDuration] like the render.
Duration renderedAudioEnd(List<DivineVideoClip> clips) {
  final output = renderedOutputDuration(clips);
  return output > VideoEditorConstants.maxDuration
      ? VideoEditorConstants.maxDuration
      : output;
}

/// Where a sound placed from [startTime] to [endTime] stops sounding, and so
/// where its fade out ends, when the export ends at [outputEnd].
///
/// The export clamps every sound to [outputEnd], which overlap transitions and
/// the length cap pull in before a sound that runs to the end of the
/// timeline. Only a sound with a [fadeOut] follows it in the preview and on
/// the strip: until a transition's seam renders, the preview still plays the
/// unshortened clips, and a sound without a fade loses nothing by running on
/// past the loop point.
Duration fadedSoundEnd({
  required Duration startTime,
  required Duration endTime,
  required Duration fadeOut,
  required Duration outputEnd,
}) => fadeOut > Duration.zero && endTime > outputEnd && outputEnd > startTime
    ? outputEnd
    : endTime;
