// ABOUTME: Artwork shown beside a sound (the cover it was published with, or the
// ABOUTME: frame of its source video) and whether a saved sound can be reused.

import 'package:flutter/foundation.dart' show kDebugMode;
import 'package:meta/meta.dart';
import 'package:models/models.dart' show AudioEvent, VideoEvent;
import 'package:nostr_sdk/nostr_sdk.dart' show isLoopbackHost;
import 'package:openvine/models/saved_sound.dart';

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

  /// The cover of [sound], a sound saved to My Sounds.
  ///
  /// The cover it was published with wins. Otherwise [sourceCovers], a lookup
  /// of the saved sounds' source videos, decides: a video it found gives the
  /// frame it shows now, kept out when the feed would hide it, and one it
  /// found gone gives none. Until it answers, the frame stored with the sound
  /// stands in.
  static SoundCover? forSavedSound(
    SavedSound sound, {
    required Map<String, SoundCover?>? sourceCovers,
  }) {
    if (publishedWith(sound.audio) case final cover?) return cover;
    final reference = sound.audio.sourceVideoReference;
    if (reference != null && (sourceCovers?.containsKey(reference) ?? false)) {
      return sourceCovers![reference];
    }
    final thumbnailUrl = sound.sourceContext?.thumbnailUrl;
    return thumbnailUrl == null ? null : SoundCover(imageUrl: thumbnailUrl);
  }

  /// Whether [audio] can no longer be used in a new video because it was
  /// taken from a video [sourceCovers] looked for and found gone: deleted,
  /// hidden from this viewer, or from a creator who lets no one else reuse
  /// its sound. A video the lookup has not reached is not.
  ///
  /// Never true for a sound the viewer published, [viewerPubkeyHex] in hex
  /// like [AudioEvent.pubkey]: its creator may always reuse it, as the reuse
  /// check also allows.
  ///
  /// [sourceCovers] is keyed by [AudioEvent.sourceVideoReference], `null` for
  /// a video found gone, as the sound providers' cover lookups return it.
  static bool cannotBeReused(
    AudioEvent audio,
    Map<String, SoundCover?>? sourceCovers, {
    required String? viewerPubkeyHex,
  }) {
    if (viewerPubkeyHex != null &&
        viewerPubkeyHex.isNotEmpty &&
        viewerPubkeyHex == audio.pubkey) {
      return false;
    }
    final reference = audio.sourceVideoReference;
    return reference != null &&
        sourceCovers != null &&
        sourceCovers.containsKey(reference) &&
        sourceCovers[reference] == null;
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
