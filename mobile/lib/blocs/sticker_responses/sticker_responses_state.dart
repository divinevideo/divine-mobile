part of 'sticker_responses_cubit.dart';

/// Where reading a sticker's responses stands.
enum StickerResponsesStatus {
  /// Nothing read yet.
  initial,

  /// Being read.
  loading,

  /// Read; [StickerResponsesState.videos] holds them.
  loaded,

  /// Could not be read.
  failure,
}

/// Who joined an Add yours or replied to a video, as its sticker shows them.
class StickerResponsesState extends Equatable {
  const StickerResponsesState({
    this.status = StickerResponsesStatus.initial,
    this.total = 0,
    this.videos = const [],
    this.curation = const RepliesCuration(),
  });

  final StickerResponsesStatus status;

  /// How many there are in all that the viewer may see, more than [videos]
  /// may hold.
  final int total;

  /// The latest the viewer may see, in the order they show: a replies
  /// sticker's pinned reply first.
  final List<VideoEvent> videos;

  /// The reply the creator pinned and the ones they hid, for a replies
  /// sticker.
  final RepliesCuration curation;

  StickerResponsesState copyWith({
    StickerResponsesStatus? status,
    int? total,
    List<VideoEvent>? videos,
    RepliesCuration? curation,
  }) => StickerResponsesState(
    status: status ?? this.status,
    total: total ?? this.total,
    videos: videos ?? this.videos,
    curation: curation ?? this.curation,
  );

  @override
  List<Object?> get props => [status, total, videos, curation];
}
