import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_foreground_provider.dart';

/// Whether window focus gates playback on this platform. Only macOS does;
/// other platforms retain their existing foreground playback policy.
bool playbackFollowsWindowFocus() =>
    defaultTargetPlatform == TargetPlatform.macOS;

/// Window focus affects playback on macOS without suspending feed readiness.
/// Other platforms retain their existing foreground playback policy.
final playbackWindowFocusedProvider =
    NotifierProvider<PlaybackWindowFocused, bool>(PlaybackWindowFocused.new);

class PlaybackWindowFocused extends Notifier<bool> {
  /// Starts from the state the app is already in: focus can leave during
  /// bootstrap, before the lifecycle handler listens, and a rebuilt account
  /// container starts here too. Transitions alone would read as focused.
  @override
  bool build() {
    if (!playbackFollowsWindowFocus()) return true;
    final state = SchedulerBinding.instance.lifecycleState;
    return state != AppLifecycleState.inactive &&
        state != AppLifecycleState.hidden;
  }

  void setFocused(bool focused) => state = focused;
}

/// Shared gate for pooled playback and legacy active-video selection.
final playbackEligibleProvider = Provider<bool>((ref) {
  final foreground = ref.watch(appForegroundProvider);
  final focused = ref.watch(playbackWindowFocusedProvider);
  return foreground && focused;
});
