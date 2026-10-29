// ABOUTME: A social sticker (mention, hashtag, link or sound credit), kept in
// ABOUTME: the meta of its layer, and what the stickers add to a video's post.

import 'package:equatable/equatable.dart';
import 'package:hashtag_repository/hashtag_repository.dart';
import 'package:models/models.dart'
    show
        AudioEvent,
        NostrHexUtils,
        UserProfile,
        VideoStickerKind,
        VideoStickerRegion;
import 'package:openvine/models/video_editor/info_sticker.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// The [infoStickerLayerKindKey] value of a social sticker layer.
const String socialStickerLayerKind = 'divine.socialSticker';

/// What a social sticker points to.
enum SocialStickerKind {
  /// A person, who is mentioned in the post.
  mention,

  /// A hashtag, which is added to the post's tags.
  hashtag,

  /// A web page, shown by a short title or its domain, whose address is
  /// added to the post.
  link,

  /// The title and artist of a sound used in the video.
  soundCredit,
}

/// How a sound credit shows its sound.
enum SocialStickerSoundDesign {
  /// A music note before the title and artist.
  note,

  /// A vinyl record before the title and artist.
  vinyl,

  /// A cassette tape before the title and artist.
  cassette,

  /// Equalizer bars before the title and artist.
  equalizer,

  /// A music player: the title and artist above a progress bar and its
  /// controls.
  player,
}

/// What a social sticker layer shows and how it looks.
///
/// Stored in both meta slots of its `WidgetLayer`, like an info sticker. A
/// mention, a hashtag and a link also go into the published event; see
/// [SocialStickerCredits].
class SocialStickerData extends Equatable {
  const SocialStickerData({
    required this.kind,
    this.style = InfoStickerStyle.light,
    this.pubkey,
    this.name,
    this.hashtag,
    this.url,
    this.linkTitle,
    this.soundTitle,
    this.soundArtist,
    this.soundId,
    this.soundDesign = SocialStickerSoundDesign.note,
    this.lyric,
  });

  /// A mention of [profile] in [style], by their handle or, without one, by
  /// their name.
  factory SocialStickerData.mentionOf(
    UserProfile profile, {
    InfoStickerStyle style = InfoStickerStyle.light,
  }) {
    final handle = profile.handle;
    return SocialStickerData(
      kind: SocialStickerKind.mention,
      style: style,
      pubkey: profile.pubkey,
      name: handle.isNotEmpty
          ? handle.replaceFirst('@', '')
          : profile.bestDisplayName,
    );
  }

  /// The credit for [sound], or `null` when it has no title to credit.
  ///
  /// The artist is credited when the sound names one; a third of Divine's
  /// own library does not. A sound from that library keeps its artist in
  /// [AudioEvent.source]; for any other sound that field names where the
  /// sound came from rather than who made it.
  static SocialStickerData? soundCreditFor(AudioEvent sound) {
    final title = sound.title?.trim();
    if (title == null || title.isEmpty) return null;
    final artist =
        (sound.creatorName ??
                sound.externalSource?.creatorName ??
                (sound.isBundled ? sound.source : null))
            ?.trim();
    return SocialStickerData(
      kind: SocialStickerKind.soundCredit,
      soundTitle: title,
      soundArtist: (artist?.isEmpty ?? true) ? null : artist,
      soundId: sound.soundPageId,
    );
  }

  /// The credits for the distinct sounds among [sounds] that have a title,
  /// in order; a sound used twice is offered once.
  static List<SocialStickerData> soundCreditsFor(Iterable<AudioEvent> sounds) {
    final credits = <SocialStickerData>[];
    for (final credit in sounds.map(soundCreditFor).nonNulls) {
      if (!credits.any(credit.isSameSound)) credits.add(credit);
    }
    return credits;
  }

  /// [raw] as the web address a link sticker opens, with `https://` added
  /// when it names no scheme, or `null` when it is no http(s) address of a
  /// named host.
  ///
  /// The same rules a profile's website follows; anything more, such as a
  /// warning before a viewer leaves Divine, belongs to the tap target that
  /// opens it.
  static String? normalizeLinkUrl(String raw) {
    final trimmed = raw.trim();
    if (trimmed.isEmpty || trimmed.contains(RegExp(r'\s'))) return null;
    final hasScheme = trimmed.contains(RegExp('^[a-zA-Z][a-zA-Z0-9+.-]*://'));
    final uri = Uri.tryParse(hasScheme ? trimmed : 'https://$trimmed');
    if (uri == null || !(uri.isScheme('https') || uri.isScheme('http'))) {
      return null;
    }
    final host = uri.host;
    if (host.isEmpty || !host.contains('.') || host.endsWith('.')) {
      return null;
    }
    return uri.toString();
  }

  /// The most characters a line of lyrics can have.
  static const int maxLyricLength = 80;

  /// The most characters a link's title can have.
  static const int maxLinkTitleLength = 40;

  /// What the sticker points to.
  final SocialStickerKind kind;

  /// How the sticker looks; one of [InfoStickerStyle.pills].
  final InfoStickerStyle style;

  /// The hex public key of the person a mention names.
  final String? pubkey;

  /// The handle or name a mention shows after its `@`, as it was when the
  /// creator picked the person.
  final String? name;

  /// The hashtag a hashtag sticker shows, normalized and without its `#`.
  final String? hashtag;

  /// The web address a link sticker points to, as [normalizeLinkUrl] wrote
  /// it.
  final String? url;

  /// The short title a link sticker shows instead of its domain.
  final String? linkTitle;

  /// The title of the credited sound.
  final String? soundTitle;

  /// The artist of the credited sound.
  final String? soundArtist;

  /// The id the credited sound's page opens it by, so a tap on the published
  /// sticker opens that sound; see [AudioEvent.soundPageId].
  final String? soundId;

  /// How a sound credit shows its sound.
  final SocialStickerSoundDesign soundDesign;

  /// A line of lyrics the creator added under a sound credit.
  final String? lyric;

  /// The domain of a link's address, without `www.`, as the sticker shows
  /// it when it has no title.
  String? get linkDomain {
    final host = Uri.tryParse(url ?? '')?.host;
    if (host == null || host.isEmpty) return null;
    return host.startsWith('www.') ? host.substring(4) : host;
  }

  /// Whether the sticker moves with the video: a record or a cassette's reels
  /// turning, an equalizer following the sound, a player's bar running.
  bool get isAnimated =>
      kind == SocialStickerKind.soundCredit &&
      soundDesign != SocialStickerSoundDesign.note;

  /// Whether the sticker moves with how loud the video's sound is.
  bool get listensToSound =>
      kind == SocialStickerKind.soundCredit &&
      soundDesign == SocialStickerSoundDesign.equalizer;

  /// Whether this credits the same sound as [other].
  bool isSameSound(SocialStickerData other) =>
      soundTitle == other.soundTitle && soundArtist == other.soundArtist;

  /// Whether the sticker has everything it needs to be placed.
  bool get isComplete => switch (kind) {
    SocialStickerKind.mention =>
      NostrHexUtils.isValidPubkey(pubkey ?? '') && (name?.isNotEmpty ?? false),
    SocialStickerKind.hashtag =>
      HashtagExtractor.normalizeVideoHashtag(hashtag ?? '') != null,
    SocialStickerKind.link => normalizeLinkUrl(url ?? '') != null,
    SocialStickerKind.soundCredit => soundTitle?.isNotEmpty ?? false,
  };

  /// What a tap on the sticker opens on the published video.
  VideoStickerKind get tapKind => switch (kind) {
    SocialStickerKind.link => VideoStickerKind.link,
    SocialStickerKind.mention => VideoStickerKind.mention,
    SocialStickerKind.hashtag => VideoStickerKind.hashtag,
    SocialStickerKind.soundCredit => VideoStickerKind.sound,
  };

  /// The web address, hex pubkey or hashtag a tap on the published sticker
  /// opens; for a sound credit its sound's page id, or empty when it has
  /// none and opens the video's own sound; `null` when it is not complete.
  String? get tapTarget => switch (kind) {
    SocialStickerKind.link => normalizeLinkUrl(url ?? ''),
    SocialStickerKind.mention =>
      NostrHexUtils.isValidPubkey(pubkey ?? '') ? pubkey!.toLowerCase() : null,
    SocialStickerKind.hashtag => HashtagExtractor.normalizeVideoHashtag(
      hashtag ?? '',
    ),
    SocialStickerKind.soundCredit => isComplete ? soundId ?? '' : null,
  };

  /// The text the sticker shows, without its `@` or `#`, so the published
  /// video can draw it again over itself: for a sound credit its title,
  /// artist and line of lyrics, one per line.
  String? get tapLabel => switch (kind) {
    SocialStickerKind.link => linkTitle ?? linkDomain,
    SocialStickerKind.mention => name,
    SocialStickerKind.hashtag => hashtag,
    SocialStickerKind.soundCredit => [
      soundTitle ?? '',
      soundArtist ?? '',
      lyric ?? '',
    ].join('\n').trimRight(),
  };

  /// Whether the sound credit [region] publishes credits [sound], read from
  /// the title and artist on its first two lines.
  static bool regionCreditsSound(VideoStickerRegion region, AudioEvent sound) {
    final credit = soundCreditFor(sound);
    final lines = (region.label ?? '').split('\n');
    final artist = lines.elementAtOrNull(1) ?? '';
    return region.kind == VideoStickerKind.sound &&
        credit != null &&
        lines.first == credit.soundTitle &&
        (artist.isEmpty ? null : artist) == credit.soundArtist;
  }

  /// The sticker [region] of a published video shows, rebuilt from the look
  /// and text it was published with, or `null` when it names no pill look
  /// this app draws or carries no text. A sound credit comes back as the
  /// still note design, the only one published with a look.
  static SocialStickerData? ofRegion(VideoStickerRegion region) {
    final style = InfoStickerStyle.values.asNameMap()[region.style];
    final label = region.label;
    if (style == null || !InfoStickerStyle.pills.contains(style)) return null;
    if (label == null) return null;
    return switch (region.kind) {
      VideoStickerKind.link => SocialStickerData(
        kind: SocialStickerKind.link,
        style: style,
        url: region.target,
        linkTitle: label,
      ),
      VideoStickerKind.mention => SocialStickerData(
        kind: SocialStickerKind.mention,
        style: style,
        pubkey: region.target,
        name: label,
      ),
      VideoStickerKind.hashtag => SocialStickerData(
        kind: SocialStickerKind.hashtag,
        style: style,
        hashtag: label,
      ),
      VideoStickerKind.sound => SocialStickerData._soundOf(
        style,
        label.split('\n'),
        soundId: region.target,
      ),
    };
  }

  /// The still note design of a sound credit showing [lines]: its title,
  /// artist and line of lyrics, crediting the sound [soundId] names, when it
  /// names one.
  factory SocialStickerData._soundOf(
    InfoStickerStyle style,
    List<String> lines, {
    required String soundId,
  }) {
    String? line(int index) {
      final text = lines.elementAtOrNull(index) ?? '';
      return text.isEmpty ? null : text;
    }

    return SocialStickerData(
      kind: SocialStickerKind.soundCredit,
      style: style,
      soundTitle: line(0),
      soundArtist: line(1),
      soundId: soundId.isEmpty ? null : soundId,
      lyric: line(2),
    );
  }

  /// Whether [layer] is a sticker a viewer can tap on the published video.
  ///
  /// Such a sticker holds still, so its tap area stays where it shows: it
  /// takes no keyframes, no tracking and no animations.
  static bool isTappableLayer(Layer? layer) =>
      layer != null && of(layer) != null;

  /// The meta stored on the layer.
  Map<String, dynamic> toMeta() => {
    infoStickerLayerKindKey: socialStickerLayerKind,
    'socialKind': kind.name,
    'style': style.name,
    'pubkey': ?pubkey,
    'name': ?name,
    'hashtag': ?hashtag,
    'url': ?url,
    'linkTitle': ?linkTitle,
    'soundTitle': ?soundTitle,
    'soundArtist': ?soundArtist,
    'soundId': ?soundId,
    'soundDesign': soundDesign.name,
    'lyric': ?lyric,
  };

  /// This sticker with what is given changed.
  SocialStickerData copyWith({
    InfoStickerStyle? style,
    String? pubkey,
    String? name,
    String? hashtag,
    String? soundTitle,
    String? soundArtist,
    SocialStickerSoundDesign? soundDesign,
    String? lyric,
  }) => SocialStickerData(
    kind: kind,
    style: style ?? this.style,
    pubkey: pubkey ?? this.pubkey,
    name: name ?? this.name,
    hashtag: hashtag ?? this.hashtag,
    url: url,
    linkTitle: linkTitle,
    soundTitle: soundTitle ?? this.soundTitle,
    soundArtist: soundArtist ?? this.soundArtist,
    soundId: soundId,
    soundDesign: soundDesign ?? this.soundDesign,
    lyric: lyric ?? this.lyric,
  );

  /// This sound credit crediting the sound [sound] credits instead: its
  /// title, artist and page id together, which [copyWith] could not clear
  /// when the new sound has no artist or id.
  SocialStickerData withSound(SocialStickerData sound) => SocialStickerData(
    kind: kind,
    style: style,
    soundTitle: sound.soundTitle,
    soundArtist: sound.soundArtist,
    soundId: sound.soundId,
    soundDesign: soundDesign,
    lyric: lyric,
  );

  /// This sound credit with [lyric] as its line of lyrics, or with none when
  /// it is blank; [copyWith] cannot unset it.
  SocialStickerData withLyric(String lyric) {
    final line = lyric.trim();
    return SocialStickerData(
      kind: kind,
      style: style,
      soundTitle: soundTitle,
      soundArtist: soundArtist,
      soundId: soundId,
      soundDesign: soundDesign,
      lyric: line.isEmpty ? null : line,
    );
  }

  /// This link pointing to [url] as it was typed, normalized when it is an
  /// address, and showing [title] when that is not blank.
  SocialStickerData withLink({required String url, required String title}) {
    final heading = title.trim();
    return SocialStickerData(
      kind: kind,
      style: style,
      url: normalizeLinkUrl(url),
      linkTitle: heading.isEmpty ? null : heading,
    );
  }

  /// Whether [meta] describes a social sticker.
  static bool isSocialStickerMeta(Map<String, dynamic>? meta) =>
      meta != null && meta[infoStickerLayerKindKey] == socialStickerLayerKind;

  /// Whether [layer] is a social sticker, checked on the kind alone.
  static bool isSocialStickerLayer(Layer layer) =>
      layer is WidgetLayer &&
      (isSocialStickerMeta(layer.exportConfigs.meta) ||
          isSocialStickerMeta(layer.meta));

  /// The sticker [meta] describes, or `null` when it describes none or names
  /// a kind this version does not know.
  static SocialStickerData? fromMeta(Map<String, dynamic>? meta) {
    if (meta == null || !isSocialStickerMeta(meta)) return null;
    final kind = SocialStickerKind.values
        .where((value) => value.name == meta['socialKind'])
        .firstOrNull;
    if (kind == null) return null;
    final style = InfoStickerStyle.values
        .where((value) => value.name == meta['style'])
        .firstOrNull;
    String? text(String key) => switch (meta[key]) {
      final String value => value,
      _ => null,
    };
    return SocialStickerData(
      kind: kind,
      style: style != null && InfoStickerStyle.pills.contains(style)
          ? style
          : InfoStickerStyle.pills.first,
      pubkey: text('pubkey'),
      name: text('name'),
      hashtag: text('hashtag'),
      url: text('url'),
      linkTitle: text('linkTitle'),
      soundTitle: text('soundTitle'),
      soundArtist: text('soundArtist'),
      soundId: text('soundId'),
      soundDesign:
          SocialStickerSoundDesign.values
              .where((value) => value.name == meta['soundDesign'])
              .firstOrNull ??
          SocialStickerSoundDesign.note,
      lyric: text('lyric'),
    );
  }

  /// The sticker [layer] shows, read from whichever of its two meta slots
  /// holds it.
  static SocialStickerData? of(Layer layer) {
    if (layer is! WidgetLayer) return null;
    return fromMeta(layer.exportConfigs.meta) ?? fromMeta(layer.meta);
  }

  @override
  List<Object?> get props => [
    kind,
    style,
    pubkey,
    name,
    hashtag,
    url,
    linkTitle,
    soundTitle,
    soundArtist,
    soundId,
    soundDesign,
    lyric,
  ];
}

/// What the social stickers on a video add to its post: a `t` tag for each
/// hashtag, a mention `p` tag for each person and an `r` tag for each link.
///
/// Read from the layers whenever it is needed rather than kept on the draft,
/// so a sticker deleted from the video takes its tag with it.
class SocialStickerCredits extends Equatable {
  const SocialStickerCredits({
    this.hashtags = const {},
    this.mentionPubkeys = const {},
    this.links = const {},
  });

  /// The credits of the social stickers among [layers].
  factory SocialStickerCredits.of(Iterable<Layer> layers) {
    final hashtags = <String>{};
    final mentionPubkeys = <String>{};
    final links = <String>{};
    for (final sticker in layers.map(SocialStickerData.of).nonNulls) {
      if (!sticker.isComplete) continue;
      switch (sticker.kind) {
        case SocialStickerKind.mention:
          mentionPubkeys.add(sticker.pubkey!.toLowerCase());
        case SocialStickerKind.hashtag:
          hashtags.add(
            HashtagExtractor.normalizeVideoHashtag(sticker.hashtag!)!,
          );
        case SocialStickerKind.link:
          links.add(SocialStickerData.normalizeLinkUrl(sticker.url!)!);
        case SocialStickerKind.soundCredit:
          // The sound is credited in the event through its own tags already.
          break;
      }
    }
    return SocialStickerCredits(
      hashtags: hashtags,
      mentionPubkeys: mentionPubkeys,
      links: links,
    );
  }

  /// The hashtags of the hashtag stickers, in the order they were placed.
  final Set<String> hashtags;

  /// The hex public keys of the people the mention stickers name.
  final Set<String> mentionPubkeys;

  /// The web addresses of the link stickers.
  final Set<String> links;

  /// [tags] after the stickers' hashtags, as many as a video can carry. The
  /// stickers' come first: they are drawn into the video, the others are not.
  List<String> hashtagsWith(Iterable<String> tags) =>
      HashtagExtractor.normalizeVideoHashtags([...hashtags, ...tags]);

  @override
  List<Object?> get props => [hashtags, mentionPubkeys, links];
}
