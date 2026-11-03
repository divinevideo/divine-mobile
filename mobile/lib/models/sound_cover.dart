// ABOUTME: Artwork shown beside a sound: the cover it was published with, or
// ABOUTME: the frame of its source video, kept out when the feed would hide it.

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:meta/meta.dart';
import 'package:models/models.dart' show AudioEvent, VideoEvent;
import 'package:nostr_sdk/nostr_sdk.dart' show isLoopbackHost;

/// Artwork shown beside a sound in a list.
///
/// Most community sounds are titled "Original sound", so the frame of the
/// video they came from is what tells them apart.
@immutable
class SoundCover {
  const SoundCover({this.imageUrl, this.blurhash});

  /// The cover of a sound published from [video].
  ///
  /// A video the viewer's content filter puts behind a warning keeps only its
  /// blurhash, so the picker does not show the frame the feed hides.
  factory SoundCover.fromSourceVideo(VideoEvent video) => SoundCover(
    imageUrl: video.shouldShowWarning ? null : video.effectiveThumbnailUrl,
    blurhash: video.blurhash,
  );

  /// The cover [audio] was published with, or `null` when it has none or
  /// it is not on [isScreenedHost].
  static SoundCover? publishedWith(AudioEvent audio) {
    final imageUrl = audio.imageUrl;
    if (imageUrl == null || !isScreenedHost(imageUrl)) return null;
    return SoundCover(imageUrl: imageUrl, blurhash: audio.blurhash);
  }

  /// Whether [url] is on Divine's media server, which screens every image it
  /// stores and lets moderators take one down, or, in a debug build, on the
  /// local stack's server.
  ///
  /// Any client can publish a sound whose cover lives anywhere. Shown from
  /// elsewhere, it would go unscreened, could not be taken down, and would
  /// tell that host who looked at it.
  static bool isScreenedHost(String url) {
    final uri = Uri.tryParse(url);
    if (uri == null) return false;
    return switch (uri.scheme) {
      'https' => _screenedHosts.contains(uri.host.toLowerCase()),
      'http' => kDebugMode && isLoopbackHost(uri.host),
      _ => false,
    };
  }

  static const _screenedHosts = {
    'media.divine.video',
    'cdn.divine.video',
    'blossom.divine.video',
  };

  /// The image to show, or `null` to show [blurhash] alone.
  final String? imageUrl;

  /// Shown while [imageUrl] loads, or in its place when there is none.
  final String? blurhash;

  @override
  bool operator ==(Object other) =>
      other is SoundCover &&
      other.imageUrl == imageUrl &&
      other.blurhash == blurhash;

  @override
  int get hashCode => Object.hash(imageUrl, blurhash);
}
