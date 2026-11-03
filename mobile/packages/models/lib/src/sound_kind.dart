import 'package:models/src/audio_event.dart';
import 'package:models/src/vine_sound.dart';

/// What a sound is, for narrowing a sound list to music or to effects.
enum SoundKind {
  /// A song, beat or other piece of music, usually played under a video.
  music,

  /// A short sound that punctuates a moment: a boom, a laugh, a meme line.
  effect;

  /// The public tags that mark a sound as an effect.
  static const effectTags = {'sfx', 'effect', 'soundeffect', 'soundeffects'};

  /// The public tag a sound of this kind is published with.
  String get tag => switch (this) {
    music => 'music',
    effect => 'sfx',
  };

  /// [tags] marking a sound as of [kind], or as of no kind for `null`: every
  /// tag that names a kind is dropped, then [kind]'s added, so a `#music`
  /// typed by hand cannot contradict the choice.
  static List<String> retag(Iterable<String> tags, SoundKind? kind) => [
    for (final tag in tags)
      if (tag.toLowerCase() != 'music' &&
          !effectTags.contains(tag.toLowerCase()))
        tag,
    ?kind?.tag,
  ];
}

/// [SoundKind] of a bundled Divine sound.
extension VineSoundKind on VineSound {
  /// Music when tagged so; every other bundled sound is a short clip, an
  /// effect.
  SoundKind get soundKind =>
      tags.contains('music') ? SoundKind.music : SoundKind.effect;
}

/// [SoundKind] of a published sound, from its public tags.
extension AudioEventKind on AudioEvent {
  /// The kind its public tags name, or `null` when they name none, as with
  /// most sounds taken from a video.
  SoundKind? get soundKind {
    final tags = {for (final tag in publicTags) tag.toLowerCase()};
    if (tags.contains('music')) return SoundKind.music;
    if (tags.any(SoundKind.effectTags.contains)) return SoundKind.effect;
    return null;
  }
}
