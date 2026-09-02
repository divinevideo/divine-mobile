// ABOUTME: State for the Explore Lists discovery gallery: two independent
// ABOUTME: columns (video lists and people lists), each with its own status.

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';
import 'package:people_lists_repository/people_lists_repository.dart';

/// Load status of one discovery column.
enum ListsDiscoveryColumnStatus { initial, loading, success, failure }

/// State of the discovery gallery.
///
/// The columns are independent by design: video lists come from a relay
/// stream while people lists come from a one-shot query, and either can
/// fail or stay empty without affecting the other.
class ListsDiscoveryState extends Equatable {
  const ListsDiscoveryState({
    this.videoStatus = ListsDiscoveryColumnStatus.initial,
    this.peopleStatus = ListsDiscoveryColumnStatus.initial,
    this.videoLists = const [],
    this.peopleLists = const [],
  });

  final ListsDiscoveryColumnStatus videoStatus;
  final ListsDiscoveryColumnStatus peopleStatus;

  /// Discovered kind-30005 video lists, newest first.
  final List<CuratedList> videoLists;

  /// Discovered kind-30000 people lists, newest first.
  final List<PeopleListSearchResult> peopleLists;

  /// Whether both columns finished without anything to show.
  bool get isEmpty =>
      videoStatus == ListsDiscoveryColumnStatus.success &&
      peopleStatus == ListsDiscoveryColumnStatus.success &&
      videoLists.isEmpty &&
      peopleLists.isEmpty;

  ListsDiscoveryState copyWith({
    ListsDiscoveryColumnStatus? videoStatus,
    ListsDiscoveryColumnStatus? peopleStatus,
    List<CuratedList>? videoLists,
    List<PeopleListSearchResult>? peopleLists,
  }) {
    return ListsDiscoveryState(
      videoStatus: videoStatus ?? this.videoStatus,
      peopleStatus: peopleStatus ?? this.peopleStatus,
      videoLists: videoLists ?? this.videoLists,
      peopleLists: peopleLists ?? this.peopleLists,
    );
  }

  @override
  List<Object?> get props => [
    videoStatus,
    peopleStatus,
    videoLists,
    peopleLists,
  ];
}
