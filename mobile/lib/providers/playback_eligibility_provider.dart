import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/app_foreground_provider.dart';

/// Window focus affects playback on macOS without suspending feed readiness.
/// Other platforms retain their existing foreground playback policy.
final playbackWindowFocusedProvider =
    NotifierProvider<PlaybackWindowFocused, bool>(PlaybackWindowFocused.new);

class PlaybackWindowFocused extends Notifier<bool> {
  @override
  bool build() => true;

  void setFocused(bool focused) => state = focused;
}

/// Shared gate for pooled playback and legacy active-video selection.
final playbackEligibleProvider = Provider<bool>((ref) {
  final foreground = ref.watch(appForegroundProvider);
  final focused = ref.watch(playbackWindowFocusedProvider);
  return foreground && focused;
});
