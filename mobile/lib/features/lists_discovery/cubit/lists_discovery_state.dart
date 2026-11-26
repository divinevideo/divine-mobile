// ABOUTME: State for the Explore Lists discovery gallery: two independent
// ABOUTME: columns (video lists and people lists), each with its own status.

import 'package:curated_list_repository/curated_list_repository.dart';
import 'package:equatable/equatable.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

/// Load status of one discovery column.
enum ListsDiscoveryColumnStatus { initial, loading, success, failure }

/// State of the discovery gallery.
///
/// The columns are independent by design: video lists arrive as a stream
/// that fills in step by step while people lists come from a one-shot query,
/// and either can fail or stay empty without affecting the other.
class ListsDiscoveryState extends Equatable {
  const ListsDiscoveryState({
    this.videoStatus = ListsDiscoveryColumnStatus.initial,
    this.peopleStatus = ListsDiscoveryColumnStatus.initial,
    this.videoLists = const [],
    this.peopleLists = const [],
    this.videoThumbnailsPending = false,
    this.peopleLoadGeneration = 0,
    this.videoInitializationFailed = false,
  });

  final ListsDiscoveryColumnStatus videoStatus;
  final ListsDiscoveryColumnStatus peopleStatus;

  /// Discovered kind-30005 video lists, most recently updated first. A list
  /// from FunnelCake's index starts as a summary without its videos (see
  /// [CuratedListSearchResult.isComplete]).
  final List<CuratedListSearchResult> videoLists;

  /// Discovered kind-30000 people lists, newest first.
  final List<PeopleListSearchResult> peopleLists;

  /// Whether [videoLists] are still waiting on their thumbnails: true from
  /// the first lists until the discovery stream ends, so cards can shimmer
  /// their empty fan slots.
  final bool videoThumbnailsPending;

  /// Identifies the people-list request whose result may update this state.
  final int peopleLoadGeneration;

  /// Saved video-list recovery must succeed before video discovery can run.
  final bool videoInitializationFailed;

  /// Whether both columns finished without anything to show.
  bool get isEmpty =>
      videoStatus == ListsDiscoveryColumnStatus.success &&
      peopleStatus == ListsDiscoveryColumnStatus.success &&
      videoLists.isEmpty &&
      peopleLists.isEmpty;

  ListsDiscoveryState copyWith({
    ListsDiscoveryColumnStatus? videoStatus,
    ListsDiscoveryColumnStatus? peopleStatus,
    List<CuratedListSearchResult>? videoLists,
    List<PeopleListSearchResult>? peopleLists,
    bool? videoThumbnailsPending,
    int? peopleLoadGeneration,
    bool? videoInitializationFailed,
  }) {
    return ListsDiscoveryState(
      videoStatus: videoStatus ?? this.videoStatus,
      peopleStatus: peopleStatus ?? this.peopleStatus,
      videoLists: videoLists ?? this.videoLists,
      peopleLists: peopleLists ?? this.peopleLists,
      videoThumbnailsPending:
          videoThumbnailsPending ?? this.videoThumbnailsPending,
      peopleLoadGeneration: peopleLoadGeneration ?? this.peopleLoadGeneration,
      videoInitializationFailed:
          videoInitializationFailed ?? this.videoInitializationFailed,
    );
  }

  @override
  List<Object?> get props => [
    videoStatus,
    peopleStatus,
    videoLists,
    peopleLists,
    videoThumbnailsPending,
    peopleLoadGeneration,
    videoInitializationFailed,
  ];
}
