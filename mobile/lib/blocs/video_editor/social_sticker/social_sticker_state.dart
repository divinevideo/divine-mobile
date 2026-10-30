part of 'social_sticker_cubit.dart';

/// A social sticker as the creator is setting it up.
class SocialStickerState extends Equatable {
  const SocialStickerState({
    required this.data,
    this.otherHashtags = const {},
    this.soundChoices = const [],
    this.personBlocked = false,
  });

  /// The sticker as it would be placed now.
  final SocialStickerData data;

  /// The post's hashtags besides this sticker's: the creator's own and those
  /// of the other hashtag stickers.
  final Set<String> otherHashtags;

  /// The sounds a sound credit can credit: those in the video with a title,
  /// and the one it credits now.
  final List<SocialStickerData> soundChoices;

  /// Whether the last person picked cannot be mentioned.
  final bool personBlocked;

  /// Whether this sticker's hashtag would take the post past the most
  /// hashtags a video can carry.
  bool get isOverHashtagLimit {
    final hashtag = data.hashtag;
    if (data.kind != SocialStickerKind.hashtag || hashtag == null) {
      return false;
    }
    return !otherHashtags.contains(hashtag) &&
        otherHashtags.length >= HashtagExtractor.maxHashtagsPerVideo;
  }

  /// Whether a countdown counts down to a moment that has passed, such as one
  /// in a draft reopened later.
  bool get isCountdownOver {
    final end = data.countdownEnd;
    return data.kind == SocialStickerKind.countdown &&
        end != null &&
        !end.isAfter(clock.now());
  }

  /// Whether the sticker can be placed as it is.
  bool get canConfirm =>
      data.isComplete && !isOverHashtagLimit && !isCountdownOver;

  SocialStickerState copyWith({
    SocialStickerData? data,
    bool? personBlocked,
  }) => SocialStickerState(
    data: data ?? this.data,
    otherHashtags: otherHashtags,
    soundChoices: soundChoices,
    personBlocked: personBlocked ?? this.personBlocked,
  );

  @override
  List<Object?> get props => [
    data,
    otherHashtags,
    soundChoices,
    personBlocked,
  ];
}
