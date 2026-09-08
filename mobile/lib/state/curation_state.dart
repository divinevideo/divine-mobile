// ABOUTME: State model for curation provider containing curated video sets
// ABOUTME: Manages only editor picks - trending/popular handled by infinite feeds

import 'dart:collection';

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:openvine/state/copy_with_sentinel.dart';

/// State model for curation provider (only Editor's Picks)
class CurationState extends Equatable {
  const CurationState({
    required List<VideoEvent> editorsPicks,
    required this.isLoading,
    List<VideoEvent> trending = const [],
    List<CurationSet> curationSets = const [],
    this.lastRefreshed,
    this.error,
  }) : _editorsPicks = editorsPicks,
       _trending = trending,
       _curationSets = curationSets;

  /// Editor's picks videos (classic vines)
  final List<VideoEvent> _editorsPicks;
  List<VideoEvent> get editorsPicks => UnmodifiableListView(_editorsPicks);

  /// Whether curation data is loading
  final bool isLoading;

  /// Trending videos (popular now)
  final List<VideoEvent> _trending;
  List<VideoEvent> get trending => UnmodifiableListView(_trending);

  /// All available curation sets
  final List<CurationSet> _curationSets;
  List<CurationSet> get curationSets => UnmodifiableListView(_curationSets);

  /// Last refresh timestamp
  final DateTime? lastRefreshed;

  /// Error message if any
  final String? error;

  /// Get total number of curated videos
  int get totalCuratedVideos => editorsPicks.length + trending.length;

  /// Check if we have any curated content
  bool get hasCuratedContent => totalCuratedVideos > 0;

  /// Get videos for a specific curation type
  List<VideoEvent> getVideosForType(CurationSetType type) => switch (type) {
    CurationSetType.editorsPicks => editorsPicks,
    CurationSetType.trending => trending,
  };

  CurationState copyWith({
    List<VideoEvent>? editorsPicks,
    bool? isLoading,
    List<VideoEvent>? trending,
    List<CurationSet>? curationSets,
    Object? lastRefreshed = unsetCopyWithArgument,
    Object? error = unsetCopyWithArgument,
  }) {
    return CurationState(
      editorsPicks: editorsPicks ?? this.editorsPicks,
      isLoading: isLoading ?? this.isLoading,
      trending: trending ?? this.trending,
      curationSets: curationSets ?? this.curationSets,
      lastRefreshed: identical(lastRefreshed, unsetCopyWithArgument)
          ? this.lastRefreshed
          : lastRefreshed as DateTime?,
      error: identical(error, unsetCopyWithArgument)
          ? this.error
          : error as String?,
    );
  }

  @override
  List<Object?> get props => [
    editorsPicks,
    isLoading,
    trending,
    curationSets,
    lastRefreshed,
    error,
  ];
}
