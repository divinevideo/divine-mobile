part of 'explore_badges_cubit.dart';

/// Loading status of Explore's community badges.
enum ExploreBadgesStatus {
  /// Nothing has been requested yet.
  initial,

  /// The definitions are loading.
  loading,

  /// The definitions loaded.
  loaded,

  /// The definitions could not be completely loaded.
  failure,
}

/// State for the [ExploreBadgesCubit].
class ExploreBadgesState extends Equatable {
  /// Creates Explore badge state.
  const ExploreBadgesState({
    this.status = ExploreBadgesStatus.initial,
    this.definitions = const [],
    this.refreshFailures = 0,
    this.visibleCount = pageSize,
    this.previews = const {},
  });

  /// Cards revealed per page of the discovery window.
  static const pageSize = 24;

  /// Loading status of [definitions].
  final ExploreBadgesStatus status;

  /// Public definitions, newest first, deduplicated by issuer and identifier.
  final List<Nip58BadgeDefinition> definitions;

  /// Failed refresh attempts while retaining a loaded snapshot.
  final int refreshFailures;

  /// How many cards have been revealed from the bounded window.
  final int visibleCount;

  /// Indexed accepted-member previews, never a complete membership count.
  final Map<String, List<String>> previews;

  List<Nip58BadgeDefinition> get visibleDefinitions =>
      definitions.take(visibleCount).toList(growable: false);

  bool get hasMore => visibleCount < definitions.length;

  /// Returns a copy with the given fields replaced.
  ExploreBadgesState copyWith({
    ExploreBadgesStatus? status,
    List<Nip58BadgeDefinition>? definitions,
    int? refreshFailures,
    int? visibleCount,
    Map<String, List<String>>? previews,
  }) {
    return ExploreBadgesState(
      status: status ?? this.status,
      definitions: definitions ?? this.definitions,
      refreshFailures: refreshFailures ?? this.refreshFailures,
      visibleCount: visibleCount ?? this.visibleCount,
      previews: previews ?? this.previews,
    );
  }

  @override
  List<Object?> get props => [
    status,
    definitions,
    refreshFailures,
    visibleCount,
    previews,
  ];
}
