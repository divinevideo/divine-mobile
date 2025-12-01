// ABOUTME: Freezed state model for curation provider containing curated video sets
// ABOUTME: Manages only editor picks - trending/popular handled by infinite feeds

import 'package:freezed_annotation/freezed_annotation.dart';
import 'package:openvine/models/curation_set.dart';
import 'package:openvine/models/video_event.dart';

part 'curation_state.freezed.dart';

/// State model for curation provider (only Editor's Picks)
@freezed
sealed class CurationState with _$CurationState {
  const factory CurationState({
    /// Editor's picks videos (classic vines)
    required List<VideoEvent> editorsPicks,

    /// Trending videos (popular now)
    @Default([]) List<VideoEvent> trending,

    /// Whether curation data is loading
    required bool isLoading,

    /// All available curation sets
    @Default([]) List<CurationSet> curationSets,

    /// Last refresh timestamp
    DateTime? lastRefreshed,

    /// Error message if any
    String? error,
  }) = _CurationState;

  const CurationState._();

  /// Get total number of curated videos
  int get totalCuratedVideos => editorsPicks.length + trending.length;

  /// Check if we have any curated content
  bool get hasCuratedContent => totalCuratedVideos > 0;

  /// Get videos for a specific curation type
  List<VideoEvent> getVideosForType(CurationSetType type) => switch (type) {
    CurationSetType.editorsPicks => editorsPicks,
    CurationSetType.trending => trending,
  };
}
