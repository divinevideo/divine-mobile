import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';

/// Toggles mute on every video clip and every independently-controllable
/// audio track at once.
///
/// If anything is currently audible (any clip or custom track with
/// `volume > 0`), this mutes everything to `0.0`. Otherwise it restores all
/// to `1.0`. Triggers `HapticFeedback.mediumImpact()` to acknowledge the
/// gesture — call sites should not add their own haptic on top.
///
/// Both the timeline header's volume button (long-press) and the per-arc
/// volume controls in [VideoEditorTimelineVolume] route through this so
/// behaviour stays in lockstep.
void toggleAllTimelineVolumeMuted(BuildContext context) {
  final clipBloc = context.read<ClipEditorBloc>();
  final overlayBloc = context.read<TimelineOverlayBloc>();

  final clips = clipBloc.state.clips;
  final customAudioTracks = overlayBloc.state.audioTracks
      .where((t) => !t.isClipAnchoredOriginalSound)
      .toList(growable: false);

  final allMuted =
      clips.every((c) => c.volume == 0.0) &&
      (customAudioTracks.isEmpty ||
          customAudioTracks.every((t) => t.volume == 0.0));
  final targetVolume = allMuted ? 1.0 : 0.0;

  unawaited(HapticFeedback.mediumImpact());
  clipBloc.add(ClipEditorAllClipsVolumeChanged(volume: targetVolume));
  overlayBloc.add(
    TimelineOverlayAllAudioVolumeChanged(volume: targetVolume),
  );
}
