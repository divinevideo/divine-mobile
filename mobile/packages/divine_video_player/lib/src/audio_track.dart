import 'dart:io';

import 'package:divine_video_player/src/audio_equalizer.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';

/// An overlay audio track that plays in sync with the video timeline.
///
/// The audio is mixed on top of the video's original audio, each with
/// independent volume control on the native side.
///
/// [videoStartTime] and [videoEndTime] define **when** in the video
/// timeline the track is audible. [trackStart] and [trackEnd] define
/// **which portion** of the audio file is used.
///
/// Example — play seconds 10-40 of a song starting at video second 5:
/// ```dart
/// AudioTrack(
///   uri: '/path/to/song.mp3',
///   videoStartTime: Duration(seconds: 5),
///   videoEndTime: Duration(seconds: 35),
///   trackStart: Duration(seconds: 10),
///   trackEnd: Duration(seconds: 40),
/// )
/// ```
class AudioTrack {
  /// Creates an audio track from a URI (file path or network URL).
  const AudioTrack({
    required this.uri,
    this.volume = 1.0,
    this.videoStartTime = Duration.zero,
    this.videoEndTime,
    this.trackStart = Duration.zero,
    this.trackEnd,
    this.fadeInDuration = Duration.zero,
    this.fadeOutDuration = Duration.zero,
    this.equalizer,
  });

  /// Creates an [AudioTrack] from a local file path.
  const AudioTrack.file(
    String path, {
    this.volume = 1.0,
    this.videoStartTime = Duration.zero,
    this.videoEndTime,
    this.trackStart = Duration.zero,
    this.trackEnd,
    this.fadeInDuration = Duration.zero,
    this.fadeOutDuration = Duration.zero,
    this.equalizer,
  }) : uri = path;

  /// Creates an [AudioTrack] from a network URL.
  const AudioTrack.network(
    String url, {
    this.volume = 1.0,
    this.videoStartTime = Duration.zero,
    this.videoEndTime,
    this.trackStart = Duration.zero,
    this.trackEnd,
    this.fadeInDuration = Duration.zero,
    this.fadeOutDuration = Duration.zero,
    this.equalizer,
  }) : uri = url;

  /// Creates an [AudioTrack] from a Flutter asset.
  ///
  /// The asset is extracted into a temporary file because native players
  /// cannot read from the Flutter asset bundle directly.
  static Future<AudioTrack> asset(
    String assetPath, {
    double volume = 1.0,
    Duration videoStartTime = Duration.zero,
    Duration? videoEndTime,
    Duration trackStart = Duration.zero,
    Duration? trackEnd,
    Duration fadeInDuration = Duration.zero,
    Duration fadeOutDuration = Duration.zero,
    AudioEqualizer? equalizer,
    AssetBundle? bundle,
  }) async {
    final (data, dir) = await (
      (bundle ?? rootBundle).load(assetPath),
      getTemporaryDirectory(),
    ).wait;
    final fileName = assetPath.split('/').last;
    final file = File('${dir.path}/divine_player_audio_assets/$fileName');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(data.buffer.asUint8List(), flush: true);
    return AudioTrack(
      uri: file.path,
      volume: volume,
      videoStartTime: videoStartTime,
      videoEndTime: videoEndTime,
      trackStart: trackStart,
      trackEnd: trackEnd,
      fadeInDuration: fadeInDuration,
      fadeOutDuration: fadeOutDuration,
      equalizer: equalizer,
    );
  }

  /// Creates an [AudioTrack] from in-memory bytes.
  ///
  /// The bytes are written to a temporary file because native players
  /// cannot play from memory directly.
  static Future<AudioTrack> memory(
    Uint8List bytes, {
    required String fileName,
    double volume = 1.0,
    Duration videoStartTime = Duration.zero,
    Duration? videoEndTime,
    Duration trackStart = Duration.zero,
    Duration? trackEnd,
    Duration fadeInDuration = Duration.zero,
    Duration fadeOutDuration = Duration.zero,
    AudioEqualizer? equalizer,
  }) async {
    final dir = await getTemporaryDirectory();
    final file = File('${dir.path}/divine_player_audio_memory/$fileName');
    await file.parent.create(recursive: true);
    await file.writeAsBytes(bytes, flush: true);
    return AudioTrack(
      uri: file.path,
      volume: volume,
      videoStartTime: videoStartTime,
      videoEndTime: videoEndTime,
      trackStart: trackStart,
      trackEnd: trackEnd,
      fadeInDuration: fadeInDuration,
      fadeOutDuration: fadeOutDuration,
      equalizer: equalizer,
    );
  }

  /// File path or network URL of the audio source.
  final String uri;

  /// Volume for this audio track (0.0 silent, 1.0 original, above 1.0
  /// amplified).
  final double volume;

  /// When in the video timeline this audio starts playing.
  final Duration videoStartTime;

  /// When in the video timeline this audio stops.
  ///
  /// When `null`, the audio plays until the track portion ends
  /// (i.e. for `trackEnd - trackStart` duration from [videoStartTime]).
  final Duration? videoEndTime;

  /// Start position within the audio file.
  final Duration trackStart;

  /// End position within the audio file.
  ///
  /// When `null`, playback continues to the end of the file.
  final Duration? trackEnd;

  /// How long the track rises from silence to [volume] once it starts
  /// playing at [videoStartTime].
  ///
  /// The gain ramps linearly, matching the fade `pro_video_editor` bakes into
  /// an exported track.
  final Duration fadeInDuration;

  /// How long the track falls from [volume] to silence before it stops
  /// sounding: at [videoEndTime], at [trackEnd], or where the file runs out,
  /// whichever comes first.
  ///
  /// The gain ramps linearly, and where it overlaps [fadeInDuration] the
  /// quieter of the two wins.
  final Duration fadeOutDuration;

  /// The equalizer the track plays through, ahead of its [volume] and fades;
  /// `null` plays it unchanged. Android, iOS and macOS only.
  final AudioEqualizer? equalizer;

  /// Serializes this track for platform channel transport.
  Map<String, dynamic> toMap() {
    return {
      'uri': uri,
      'volume': volume,
      'videoStartMs': videoStartTime.inMilliseconds,
      'videoEndMs': videoEndTime?.inMilliseconds,
      'trackStartMs': trackStart.inMilliseconds,
      'trackEndMs': trackEnd?.inMilliseconds,
      'fadeInMs': fadeInDuration.inMilliseconds,
      'fadeOutMs': fadeOutDuration.inMilliseconds,
      if (equalizer case final equalizer? when !equalizer.isFlat)
        'equalizer': equalizer.toMap(),
    };
  }
}
