import 'dart:io';

import 'package:divine_video_player/src/video_buffer_profile.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// A single video clip within the multi-clip timeline.
///
/// [uri] is a file path, network URL, or any URI the native player can
/// resolve. [start] and [end] define the subrange of the source to play.
/// When [end] is `null`, the clip plays to the end of the source file.
/// [volume] controls the audio level for this clip (0.0 = muted, 1.0 = full).
///
/// For Flutter assets and in-memory bytes, use the async helpers
/// [VideoClip.asset] and [VideoClip.memory] which copy data to a temporary
/// file first.
class VideoClip {
  /// Creates a video clip from a file path or URI.
  const VideoClip({
    required this.uri,
    this.start = Duration.zero,
    this.end,
    this.volume = 1.0,
    this.playbackSpeed = 1.0,
    this.httpHeaders = const {},
    this.trimToCommonTrackEnd = false,
  });

  /// Creates a [VideoClip] from a local file path.
  const VideoClip.file(
    String path, {
    this.start = Duration.zero,
    this.end,
    this.volume = 1.0,
    this.playbackSpeed = 1.0,
    this.httpHeaders = const {},
    this.trimToCommonTrackEnd = false,
  }) : uri = path;

  /// Creates a [VideoClip] from a network URL.
  const VideoClip.network(
    String url, {
    this.start = Duration.zero,
    this.end,
    this.volume = 1.0,
    this.playbackSpeed = 1.0,
    this.httpHeaders = const {},
    this.trimToCommonTrackEnd = false,
  }) : uri = url;

  /// Creates a [VideoClip] from a Flutter asset.
  ///
  /// The asset is extracted into a temporary file because native players
  /// cannot read from the Flutter asset bundle directly.
  static Future<VideoClip> asset(
    String assetPath, {
    Duration start = Duration.zero,
    Duration? end,
    double volume = 1.0,
    double playbackSpeed = 1.0,
    AssetBundle? bundle,
    bool trimToCommonTrackEnd = false,
  }) async {
    final (data, dir) = await (
      (bundle ?? rootBundle).load(assetPath),
      getTemporaryDirectory(),
    ).wait;
    final fileName = assetPath.split('/').last;
    final file = File('${dir.path}/divine_player_assets/$fileName');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return VideoClip(
      uri: file.path,
      start: start,
      end: end,
      volume: volume,
      playbackSpeed: playbackSpeed,
      trimToCommonTrackEnd: trimToCommonTrackEnd,
    );
  }

  /// Creates a [VideoClip] from in-memory bytes.
  ///
  /// The bytes are written to a temporary file because native players
  /// cannot play from memory directly.
  static Future<VideoClip> memory(
    Uint8List bytes, {
    required String fileName,
    Duration start = Duration.zero,
    Duration? end,
    double volume = 1.0,
    double playbackSpeed = 1.0,
    bool trimToCommonTrackEnd = false,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/divine_player_memory/$fileName');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return VideoClip(
      uri: file.path,
      start: start,
      end: end,
      volume: volume,
      playbackSpeed: playbackSpeed,
      trimToCommonTrackEnd: trimToCommonTrackEnd,
    );
  }

  /// File path, network URL, or platform URI of the video source.
  final String uri;

  /// Start position within the source video.
  final Duration start;

  /// End position within the source video.
  ///
  /// When `null`, the clip plays to the end of the source. On the Android,
  /// Apple and web backends an [end] past the source duration is clamped to
  /// it, so a caller capping playback without knowing the source length still
  /// gets the natural end for shorter sources. The Linux backend does not
  /// clamp and reports the requested length.
  final Duration? end;

  /// Audio volume for this clip (0.0 = muted, 1.0 = full volume).
  final double volume;

  /// Playback speed multiplier for this clip (1.0 = normal, 2.0 = 2× fast).
  final double playbackSpeed;

  /// HTTP headers to attach when [uri] resolves to a network source.
  final Map<String, String> httpHeaders;

  /// Whether to end the clip where *all* of the source's tracks still have
  /// content, instead of at the container duration.
  ///
  /// An mp4's declared duration is the longest of its tracks, and capture and
  /// export pipelines routinely let the audio and video tracks end tens of
  /// milliseconds apart. Playing to the container duration therefore ends on a
  /// stretch where one track has already run out — silence, or a frozen last
  /// frame. On a looping player that stretch is the loop seam.
  ///
  /// Set this for looping playback of a single clip. It shortens the clip only
  /// when the track mismatch is small (currently at most 500 ms and at most
  /// 10% of the playable duration), so obviously malformed assets keep their
  /// container duration instead of collapsing into a tiny loop. It is wrong for
  /// a clip in the middle of a multi-clip timeline, where it would cut content
  /// rather than a seam. Clamping only ever shortens: [end], when set, still
  /// wins if it is earlier.
  ///
  /// Support is per-platform, and the web and Linux backends ignore it:
  ///
  /// * Apple reads both tracks before it builds the composition, for local
  ///   and remote sources alike. It also starts the clip past an empty edit
  ///   of at most 100 ms that opens either track: every Divine derivative
  ///   opens its video with one of 21–23 ms, some open the audio with a few
  ///   milliseconds, and `AVPlayerLooper` held the last frame ~200 ms at
  ///   every restart of such a clip. Only a clip starting at zero is started
  ///   past it.
  /// * Android takes the track lengths from its own extractor as it parses
  ///   the container during prepare, and clips the source there — before the
  ///   first frame, on every source and every [VideoBufferProfile], with no
  ///   read in front of the load. It also starts the clip at its first frame
  ///   when an empty edit of at most 100 ms delays the picture: every Divine
  ///   derivative carries one of 21–23 ms, which otherwise held the last
  ///   frame that much longer at every restart. Only a clip starting at zero
  ///   is clipped this way; one with a [start] uses lengths already seen for
  ///   its source.
  /// * Neither platform clamps an HLS source: an HLS asset exposes no tracks
  ///   to Apple, and a playlist has no container for Android to read them
  ///   from. An HLS clip plays unclamped on both.
  final bool trimToCommonTrackEnd;

  /// Serializes this clip for platform channel transport.
  Map<String, dynamic> toMap() {
    return {
      'uri': uri,
      'startMs': start.inMilliseconds,
      'endMs': end?.inMilliseconds,
      'volume': volume,
      'playbackSpeed': playbackSpeed,
      if (httpHeaders.isNotEmpty) 'httpHeaders': httpHeaders,
      if (trimToCommonTrackEnd) 'trimToCommonTrackEnd': true,
    };
  }
}
