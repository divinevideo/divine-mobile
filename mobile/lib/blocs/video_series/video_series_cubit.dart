// ABOUTME: Finds the series a video is an episode of, and its place in it.
// ABOUTME: Backs SeriesChip; an ordinary video never creates one of these.

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:unified_logger/unified_logger.dart';

part 'video_series_state.dart';

/// Loads the series a video names in its `series` tag, and where the video
/// sits in it.
///
/// The video is an episode only when the series is a list marked as a series
/// that holds the video's own address, as
/// [CuratedListRepository.fetchSeriesContaining] checks. Otherwise the state
/// ends as [VideoSeriesNone].
class VideoSeriesCubit extends Cubit<VideoSeriesState>
    with CloseGuardedEmit<VideoSeriesState> {
  VideoSeriesCubit({
    required CuratedListRepository repository,
    required String seriesCoordinate,
    required String episodeCoordinate,
  }) : _repository = repository,
       _seriesCoordinate = seriesCoordinate,
       _episodeCoordinate = episodeCoordinate,
       super(const VideoSeriesLoading());

  final CuratedListRepository _repository;

  /// The `30005:<pubkey>:<d-tag>` address the video names as its series.
  final String _seriesCoordinate;

  /// The video's own `kind:pubkey:d-tag` address.
  final String _episodeCoordinate;

  /// Reads the series and emits where the video sits in it.
  Future<void> load() async {
    try {
      final series = await _repository.fetchSeriesContaining(
        seriesCoordinate: _seriesCoordinate,
        episodeCoordinate: _episodeCoordinate,
      );
      emitIfOpen(_episodeIn(series) ?? const VideoSeriesNone());
    } on Object catch (error, stackTrace) {
      Log.error(
        'Reading the series of a video failed',
        name: 'VideoSeriesCubit',
        category: LogCategory.ui,
        error: error,
        stackTrace: stackTrace,
      );
      // The repository answers null for every failure it expects, so a
      // throw is a defect.
      addError(Reportable(error, context: 'load'), stackTrace);
      emitIfOpen(const VideoSeriesNone());
    }
  }

  VideoSeriesEpisode? _episodeIn(CuratedList? series) {
    final owner = series?.pubkey;
    if (series == null || owner == null) return null;
    final episodeNumber = series.episodeNumberOf(_episodeCoordinate);
    final listPosition = series.videoEventIds.indexOf(_episodeCoordinate);
    if (episodeNumber == null || listPosition < 0) return null;
    return VideoSeriesEpisode(
      series: series,
      authorPubkey: owner,
      episodeNumber: episodeNumber,
      episodeCount: series.seriesEpisodes.length,
      listPosition: listPosition,
    );
  }
}
