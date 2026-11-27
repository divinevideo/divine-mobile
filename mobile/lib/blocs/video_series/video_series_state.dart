part of 'video_series_cubit.dart';

/// What [VideoSeriesCubit] knows about the series of a video.
sealed class VideoSeriesState extends Equatable {
  const VideoSeriesState();

  @override
  List<Object?> get props => const [];
}

/// The series is being read.
final class VideoSeriesLoading extends VideoSeriesState {
  const VideoSeriesLoading();
}

/// The video is not an episode of a series this app can show: the series is
/// missing, is not marked as a series, does not hold the video, or could not
/// be read.
final class VideoSeriesNone extends VideoSeriesState {
  const VideoSeriesNone();
}

/// The video is episode [episodeNumber] of [episodeCount] in [series].
final class VideoSeriesEpisode extends VideoSeriesState {
  const VideoSeriesEpisode({
    required this.series,
    required this.authorPubkey,
    required this.episodeNumber,
    required this.episodeCount,
    required this.listPosition,
  });

  final CuratedList series;

  /// The series' author, in hex.
  final String authorPubkey;

  /// The video's place among the series' episodes, counting from 1.
  final int episodeNumber;

  /// How many episodes the series has.
  final int episodeCount;

  /// The video's position in [CuratedList.videoEventIds], which the list
  /// route's `play` parameter takes. It differs from [episodeNumber] minus
  /// one when the list also holds entries that are not episodes.
  final int listPosition;

  @override
  List<Object?> get props => [
    series,
    authorPubkey,
    episodeNumber,
    episodeCount,
    listPosition,
  ];
}
