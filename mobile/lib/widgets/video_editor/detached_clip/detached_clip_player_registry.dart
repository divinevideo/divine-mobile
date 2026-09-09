// ABOUTME: Keeps a detached clip's player alive across the remount the editor
// ABOUTME: performs when a layer is dragged, so the texture never blanks

import 'package:openvine/utils/grace_period_registry.dart';
import 'package:openvine/widgets/video_editor/detached_clip/detached_clip_player.dart';

/// The editor's companion players for detached clips, one per clip source.
///
/// Pooled rather than owned by the layer's `State`: the editor's layer stack
/// re-parents a layer while it is dragged, remounting the widget about once a
/// second, and a decoder tied to that lifetime is torn down and stood back up
/// just as often.
final detachedClipPlayers = GracePeriodRegistry<DetachedClipPlayer>(
  graceWindow: const Duration(seconds: 3),
  dispose: (player) => player.dispose(),
);
