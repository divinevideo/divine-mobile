import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/widgets.dart';
import 'package:infinite_video_feed/src/models/video_error_type.dart';
import 'package:models/models.dart';

/// Builder for the loading state shown while a video initializes.
///
/// [isSquare] is `true` when the controller has resolved the video
/// dimensions and they are equal (1:1 aspect ratio). It is `false`
/// when the video is not square or dimensions are not yet known.
///
/// [hasSourceFailure] is `true` once a playback source attempt for [index]
/// has failed or stalled while loading continues (for example, while failover
/// tries another URL or waits on media processing). Healthy loads pass `false`
/// so loading overlays can avoid speculative network lookups on normal swipes.
typedef LoadingBuilder =
    Widget Function(
      BuildContext context,
      int index, {
      required bool isSquare,
      required bool hasSourceFailure,
    });

/// Builder for the error state.
typedef ErrorBuilder =
    Widget Function(
      BuildContext context,
      int index,
      VoidCallback onRetry,
      VideoErrorType errorType,
    );

/// Builder that wraps or replaces the default video player widget.
///
/// [child] is the default video item widget for the current feed item.
/// Return it directly to keep the default player, or wrap/replace it to
/// inject metrics tracking, custom sizing, or other feed-specific chrome.
typedef VideoBuilder =
    Widget Function(
      BuildContext context,
      Widget child,
      int index,
      DivineVideoPlayerController? controller,
    );

/// Builder for the overlay layer rendered on top of the video.
typedef OverlayBuilder =
    Widget Function(
      BuildContext context,
      int index,
      DivineVideoPlayerController? controller, {
      required bool isActive,
    });

/// Callback when the active video changes.
typedef OnActiveVideoChanged = void Function(VideoEvent video, int index);
