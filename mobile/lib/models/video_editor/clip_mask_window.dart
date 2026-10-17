// ABOUTME: When a timeline clip's shape mask covers the picture, and how
// ABOUTME: strongly, so the preview and the export fade it alike.

import 'package:flutter/foundation.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/video_editor/transition_geometry.dart';
import 'package:pro_image_editor/pro_image_editor.dart' show LayerMask;

/// A timeline clip's mask while it is being changed, before the change is
/// written to the clip: shown on the canvas in place of the clip's own.
typedef LiveClipMask = ({String clipId, LayerMask? mask});

/// The stretch of the editor timeline a timeline clip's [mask] covers.
///
/// A clip's mask is drawn over the whole picture as a black cover with the
/// shape cut out of it, so it shows exactly while the clip does: from [start]
/// to [end], on the editor timeline. Across an overlap transition (every type
/// but the dips) both clips play at once, so the cover fades in over
/// [fadeIn] and out over [fadeOut] instead of cutting the other clip's half
/// of the blend. A dip to black or white plays one clip at a time and fades
/// nothing.
@immutable
class ClipMaskWindow {
  /// Creates a [ClipMaskWindow].
  const ClipMaskWindow({
    required this.clipId,
    required this.mask,
    required this.start,
    required this.end,
    this.fadeIn = Duration.zero,
    this.fadeOut = Duration.zero,
  });

  /// The clip whose mask this is.
  final String clipId;

  /// The mask, measured in the exported frame.
  final LayerMask mask;

  /// Where the clip starts to show, on the editor timeline: its start, or the
  /// start of the transition into it.
  final Duration start;

  /// Where the clip stops showing, on the editor timeline: its end, or the end
  /// of the transition out of it.
  final Duration end;

  /// How long, on the editor timeline, the cover fades in from [start].
  final Duration fadeIn;

  /// How long, on the editor timeline, the cover fades out before [end].
  final Duration fadeOut;

  /// How strongly the cover shows at [time] on the editor timeline, from 0
  /// (not at all) to 1.
  ///
  /// Linear across each fade, as the blend region maps linearly onto the
  /// output, so the export's linear fade matches it.
  double weightAt(Duration time) {
    if (time < start || time > end) return 0;
    if (fadeIn > Duration.zero && time < start + fadeIn) {
      return (time - start).inMicroseconds / fadeIn.inMicroseconds;
    }
    if (fadeOut > Duration.zero && time > end - fadeOut) {
      return (end - time).inMicroseconds / fadeOut.inMicroseconds;
    }
    return 1;
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is ClipMaskWindow &&
          other.clipId == clipId &&
          other.mask == mask &&
          other.start == start &&
          other.end == end &&
          other.fadeIn == fadeIn &&
          other.fadeOut == fadeOut;

  @override
  int get hashCode => Object.hash(clipId, mask, start, end, fadeIn, fadeOut);

  @override
  String toString() =>
      'ClipMaskWindow(clipId: $clipId, start: $start, end: $end, '
      'fadeIn: $fadeIn, fadeOut: $fadeOut)';
}

/// The windows of every masked clip in [clips], in timeline order.
///
/// [masks] replaces the mask of the clips it names, which is how the editor
/// previews a mask that is still being changed; a `null` value removes it.
List<ClipMaskWindow> clipMaskWindows(
  List<DivineVideoClip> clips, {
  Map<String, LayerMask?> masks = const {},
}) {
  final transitions = clampTransitions(clips);
  // The blend on the editor timeline reaches the transition's duration into
  // each side of a boundary; see [TransitionTimelineMap].
  Duration overlapAfter(int index) {
    if (index < 0 || index >= clips.length - 1) return Duration.zero;
    final transition = transitions[clips[index].id];
    if (transition == null || !transitionOverlapsClips(transition.type)) {
      return Duration.zero;
    }
    return transition.duration;
  }

  final windows = <ClipMaskWindow>[];
  var clipStart = Duration.zero;
  for (var i = 0; i < clips.length; i++) {
    final clip = clips[i];
    final clipEnd = clipStart + clip.playbackDuration;
    final mask = masks.containsKey(clip.id) ? masks[clip.id] : clip.mask;
    if (mask != null) {
      final blendIn = overlapAfter(i - 1);
      final blendOut = overlapAfter(i);
      windows.add(
        ClipMaskWindow(
          clipId: clip.id,
          mask: mask,
          start: clipStart - blendIn,
          end: clipEnd + blendOut,
          fadeIn: blendIn * 2,
          fadeOut: blendOut * 2,
        ),
      );
    }
    clipStart = clipEnd;
  }
  return windows;
}
