import 'package:flutter/foundation.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/blocs/video_editor/timeline_overlay/timeline_overlay_bloc.dart';
import 'package:openvine/models/video_editor/live_volume.dart';

/// Restores an unfinished preview without changing editor history.
///
/// The notifier owner must check its lifetime before calling this function.
/// Exact identity rejects delayed cleanup from an earlier drag. Publish the
/// committed gain before null: the canvas queues non-null gains and ignores null.
bool cancelLiveVolumePreview({
  required LiveVolume expected,
  required ValueNotifier<LiveVolume?> notifier,
  required ClipEditorState clipState,
  required TimelineOverlayState overlayState,
}) {
  if (!identical(notifier.value, expected)) return false;

  LiveVolume? restored;
  if (expected.clipId case final clipId?) {
    for (final clip in clipState.clips) {
      if (clip.id == clipId) {
        restored = LiveVolume.clip(clipId, clip.volume);
        break;
      }
    }
  } else if (expected.trackId case final trackId?) {
    for (final track in overlayState.audioTracks) {
      if (track.id == trackId) {
        restored = LiveVolume.track(track.id, track.volume);
        break;
      }
    }
  }
  // A detached clip's layer goes back to its stored volume once no preview
  // names it, and deleted targets have no gain to restore; either way the
  // stale preview still clears.
  if (restored != null) notifier.value = restored;
  // A synchronous listener may already have published a newer preview.
  if (identical(notifier.value, restored ?? expected)) notifier.value = null;
  return notifier.value == null;
}
