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

  /// The sounds a sound credit can credit: those in the video with a title
  /// and an artist, and the one it credits now.
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

  /// Whether the sticker can be placed as it is.
  bool get canConfirm => data.isComplete && !isOverHashtagLimit;

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
