// ABOUTME: A social sticker (mention, hashtag, link, sound credit, countdown or
// ABOUTME: reply), kept in its layer's meta, and what they add to the post.

import 'package:characters/characters.dart';
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
import 'package:openvine/models/video_editor/sticker_text_glyphs.dart';
import 'package:openvine/models/video_reply_context.dart';
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

  /// A title and the moment it counts down to. The Divine player shows the
  /// time left over it, and a tap sets a reminder for when it ends.
  countdown,

  /// The comment or video this video replies to: who wrote it and what they
  /// wrote, or the video's thumbnail. A tap opens it.
  reply;

  /// The looks a sticker of this kind can take, the default first. A
  /// countdown takes only solid ones, which the player's time left can cover
  /// the date in the frames with; a reply's card only a light and a dark one.
  List<InfoStickerStyle> get styles => switch (this) {
    countdown => const [
      InfoStickerStyle.light,
      InfoStickerStyle.brand,
      InfoStickerStyle.highlight,
    ],
    reply => const [InfoStickerStyle.light, InfoStickerStyle.dark],
    _ => InfoStickerStyle.pills,
  };
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
/// [SocialStickerCredits]. A reply keeps the name, text and picture of what it
/// replies to as they were when the video was recorded.
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
    this.countdownTitle,
    this.countdownEnd,
    this.localeName,
    this.use24HourFormat = false,
    this.replyEventId,
    this.replyText,
    this.replyImageUrl,
    this.replyToVideo = false,
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

  /// The most characters a countdown's title can have.
  static const int maxCountdownTitleLength = 40;

  /// A new countdown, in [style], writing its date in [localeName], its time
  /// on a 24-hour clock when [use24HourFormat], and counting down to the full
  /// hour after a day from [now].
  factory SocialStickerData.countdown({
    required DateTime now,
    String? localeName,
    bool use24HourFormat = false,
    InfoStickerStyle style = InfoStickerStyle.light,
  }) => SocialStickerData(
    kind: SocialStickerKind.countdown,
    style: style,
    localeName: localeName,
    use24HourFormat: use24HourFormat,
    countdownEnd: defaultCountdownEnd(now).toUtc(),
  );

  /// The sticker showing what [context] replies to, from the snapshot taken
  /// when the reply was recorded, or `null` when it has none. The comment is
  /// kept on one line and cut to [maxReplyTextLength].
  static SocialStickerData? replyTo(
    VideoReplyContext context, {
    InfoStickerStyle style = InfoStickerStyle.light,
  }) {
    final name = context.replyToName?.trim();
    if (name == null || name.isEmpty) return null;
    final text = context.replyToText?.replaceAll(RegExp(r'\s+'), ' ').trim();
    final chars = text?.characters;
    final imageUrl = context.replyToImageUrl?.trim();
    return SocialStickerData(
      kind: SocialStickerKind.reply,
      style: style,
      pubkey: context.replyToPubkey,
      name: name,
      replyEventId: context.replyToEventId,
      replyText: chars == null || chars.isEmpty
          ? null
          : chars.length <= maxReplyTextLength
          ? text
          : '${chars.take(maxReplyTextLength - 1).toString().trimRight()}…',
      replyImageUrl: imageUrl == null || imageUrl.isEmpty ? null : imageUrl,
      replyToVideo: !context.isReplyToComment,
    );
  }

  /// The full hour after a day from [now], where a new countdown starts.
  static DateTime defaultCountdownEnd(DateTime now) {
    final local = now.toLocal();
    return DateTime(local.year, local.month, local.day + 1, local.hour + 1);
  }

  /// The most characters of a comment a reply shows.
  static const int maxReplyTextLength = 140;

  /// What the sticker points to.
  final SocialStickerKind kind;

  /// How the sticker looks; one of its kind's [SocialStickerKind.styles].
  final InfoStickerStyle style;

  /// The hex public key of the person a mention names, or of the one who
  /// wrote what a reply replies to.
  final String? pubkey;

  /// The handle or name a mention shows after its `@`, or a reply shows for
  /// whoever wrote what it replies to, as it was when the creator picked the
  /// person or recorded the reply.
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

  /// The title a countdown shows over its date, such as "Summer".
  final String? countdownTitle;

  /// The moment a countdown counts down to, in UTC.
  final DateTime? countdownEnd;

  /// The locale a countdown writes its date in, as `Locale.toString` gives
  /// it, so a draft reopened in another language looks the way it was
  /// published.
  final String? localeName;

  /// Whether a countdown writes its time on a 24-hour clock, as the phone
  /// did when it was made.
  final bool use24HourFormat;

  /// The hex id of the comment or video a reply replies to.
  final String? replyEventId;

  /// The text of the comment a reply replies to, cut to
  /// [maxReplyTextLength]; `null` for a reply to a video.
  final String? replyText;

  /// The picture a reply shows: the avatar of whoever wrote the comment, or
  /// the thumbnail of the video.
  final String? replyImageUrl;

  /// Whether a reply replies to a video rather than to a comment.
  final bool replyToVideo;

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

  /// The text the sticker draws, its link or note mark aside. A countdown's
  /// date is left out: the copy the player draws over it covers it with the
  /// time left.
  String get _drawnText => [
    name,
    hashtag,
    linkTitle ?? linkDomain,
    soundTitle,
    soundArtist,
    lyric,
    countdownTitle,
    replyText,
  ].nonNulls.join('\n');

  /// Whether the sticker's text is in the sticker font but for its emoji,
  /// which look the same on every phone only in the sticker emoji font. Text
  /// with a character neither font has does not count: another phone draws
  /// it differently anyway.
  bool get hasEmoji => StickerTextGlyphs.of(_drawnText) == .emoji;

  /// Whether the sticker's text allows a sharp copy over the same sticker in
  /// a video's frames. A solid pill hides the sticker beneath, so its text
  /// can be in any script and its emoji in any font. The frames show through
  /// any other look, so its text needs glyphs every phone draws alike: all in
  /// the sticker font, with emoji in the loaded sticker emoji font. Whether
  /// the sticker holds still is up to the caller; see [isAnimated]. A reply
  /// is never drawn again: its picture is not in the event.
  bool canBeRedrawn({required bool emojiFontLoaded}) =>
      kind != SocialStickerKind.reply &&
      (style.hasSolidPill ||
          StickerTextGlyphs.of(
            _drawnText,
          ).isDrawnAlike(emojiFontLoaded: emojiFontLoaded));

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
    SocialStickerKind.countdown =>
      (countdownTitle?.trim().isNotEmpty ?? false) && countdownEnd != null,
    SocialStickerKind.reply =>
      NostrHexUtils.isValidEventId(replyEventId?.toLowerCase() ?? '') &&
          (name?.isNotEmpty ?? false),
  };

  /// What a tap on the sticker opens on the published video.
  VideoStickerKind get tapKind => switch (kind) {
    SocialStickerKind.link => VideoStickerKind.link,
    SocialStickerKind.mention => VideoStickerKind.mention,
    SocialStickerKind.hashtag => VideoStickerKind.hashtag,
    SocialStickerKind.soundCredit => VideoStickerKind.sound,
    SocialStickerKind.countdown => VideoStickerKind.countdown,
    SocialStickerKind.reply => VideoStickerKind.reply,
  };

  /// The web address, hex pubkey or hashtag a tap on the published sticker
  /// opens; for a sound credit its sound's page id, or empty when it has
  /// none and opens the video's own sound; a countdown's end in Unix seconds;
  /// a reply's event id; `null` when it is not complete.
  String? get tapTarget => switch (kind) {
    SocialStickerKind.link => normalizeLinkUrl(url ?? ''),
    SocialStickerKind.mention =>
      NostrHexUtils.isValidPubkey(pubkey ?? '') ? pubkey!.toLowerCase() : null,
    SocialStickerKind.hashtag => HashtagExtractor.normalizeVideoHashtag(
      hashtag ?? '',
    ),
    SocialStickerKind.soundCredit => isComplete ? soundId ?? '' : null,
    SocialStickerKind.countdown =>
      isComplete
          ? '${countdownEnd!.millisecondsSinceEpoch ~/ Duration.millisecondsPerSecond}'
          : null,
    SocialStickerKind.reply => isComplete ? replyEventId!.toLowerCase() : null,
  };

  /// The text the sticker shows, without its `@` or `#`, so the published
  /// video can draw it again over itself: for a sound credit its title,
  /// artist and line of lyrics, one per line; for a reply the name and
  /// comment it shows, one per line.
  String? get tapLabel => switch (kind) {
    SocialStickerKind.link => linkTitle ?? linkDomain,
    SocialStickerKind.mention => name,
    SocialStickerKind.hashtag => hashtag,
    SocialStickerKind.soundCredit => [
      soundTitle ?? '',
      soundArtist ?? '',
      lyric ?? '',
    ].join('\n').trimRight(),
    SocialStickerKind.countdown => countdownTitle?.trim(),
    SocialStickerKind.reply => [?name, ?replyText].join('\n'),
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
  /// and text it was published with, or `null` when it names no look this
  /// app draws for its kind, carries no text, or is no social sticker the
  /// player draws again. A sound credit comes back as the still note design,
  /// the only one published with a look.
  static SocialStickerData? ofRegion(VideoStickerRegion region) {
    final kind = switch (region.kind) {
      VideoStickerKind.link => SocialStickerKind.link,
      VideoStickerKind.mention => SocialStickerKind.mention,
      VideoStickerKind.hashtag => SocialStickerKind.hashtag,
      VideoStickerKind.sound => SocialStickerKind.soundCredit,
      VideoStickerKind.countdown => SocialStickerKind.countdown,
      VideoStickerKind.place || VideoStickerKind.reply => null,
    };
    final style = InfoStickerStyle.values.asNameMap()[region.style];
    final label = region.label;
    if (kind == null || style == null || !kind.styles.contains(style)) {
      return null;
    }
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
      VideoStickerKind.countdown => SocialStickerData(
        kind: SocialStickerKind.countdown,
        style: style,
        countdownTitle: label,
        countdownEnd: region.countdownEnd,
      ),
      VideoStickerKind.place || VideoStickerKind.reply => null,
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
    'countdownTitle': ?countdownTitle,
    'countdownEnd': ?countdownEnd?.toUtc().toIso8601String(),
    'locale': ?localeName,
    if (use24HourFormat) 'use24HourFormat': true,
    'replyEventId': ?replyEventId,
    'replyText': ?replyText,
    'replyImageUrl': ?replyImageUrl,
    if (replyToVideo) 'replyToVideo': true,
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
    String? countdownTitle,
    DateTime? countdownEnd,
    String? localeName,
    bool? use24HourFormat,
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
    countdownTitle: countdownTitle ?? this.countdownTitle,
    countdownEnd: countdownEnd ?? this.countdownEnd,
    localeName: localeName ?? this.localeName,
    use24HourFormat: use24HourFormat ?? this.use24HourFormat,
    replyEventId: replyEventId,
    replyText: replyText,
    replyImageUrl: replyImageUrl,
    replyToVideo: replyToVideo,
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
      style: style != null && kind.styles.contains(style)
          ? style
          : kind.styles.first,
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
      countdownTitle: text('countdownTitle'),
      countdownEnd: DateTime.tryParse(text('countdownEnd') ?? '')?.toUtc(),
      localeName: text('locale'),
      use24HourFormat: meta['use24HourFormat'] == true,
      replyEventId: text('replyEventId'),
      replyText: text('replyText'),
      replyImageUrl: text('replyImageUrl'),
      replyToVideo: meta['replyToVideo'] == true,
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
    countdownTitle,
    countdownEnd,
    localeName,
    use24HourFormat,
    replyEventId,
    replyText,
    replyImageUrl,
    replyToVideo,
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
        case SocialStickerKind.countdown || SocialStickerKind.reply:
          // A countdown adds nothing, and what a reply replies to is in the
          // event through the reply's own tags.
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
