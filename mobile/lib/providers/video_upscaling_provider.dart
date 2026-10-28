// ABOUTME: Mirrors the videoUpscaling feature flag into the video player package,
// ABOUTME: whose texture players read it when they are created.

import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';

/// Keeps [DivineVideoPlayerController.upscaling] in step with
/// [FeatureFlag.videoUpscaling]. A player takes the value it finds when it
/// is created, so flipping the flag changes the next video that opens, not
/// the ones already playing.
///
/// Activated by `AppRootSideEffects`, before any feed builds a player.
final videoUpscalingSyncProvider = Provider<void>((ref) {
  final enabled = ref.watch(
    isFeatureEnabledProvider(FeatureFlag.videoUpscaling),
  );
  DivineVideoPlayerController.upscaling = enabled
      ? VideoUpscaling.lanczos
      : VideoUpscaling.off;
});
