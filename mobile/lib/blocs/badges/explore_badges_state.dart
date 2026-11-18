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
    this.hiddenIssuers = const {},
    this.refreshFailures = 0,
    this.visibleCount = pageSize,
    this.previews = const {},
    this.refreshGeneration = 0,
    this.previewGeneration = 0,
    this.isRefreshing = false,
    this.activePreviews = 0,
    this.previewQueue = const [],
    this.requestedPreviews = const {},
  });

  /// Cards revealed per page of the discovery window.
  static const pageSize = 24;

  /// Loading status of [definitions].
  final ExploreBadgesStatus status;

  /// Public definitions, newest first, deduplicated by issuer and identifier.
  final List<Nip58BadgeDefinition> definitions;

  /// Issuers excluded from the gallery and preview requests.
  final Set<String> hiddenIssuers;

  /// Failed refresh attempts while retaining a loaded snapshot.
  final int refreshFailures;

  /// How many cards have been revealed from the bounded window.
  final int visibleCount;

  /// Indexed accepted-member previews, never a complete membership count.
  final Map<String, List<String>> previews;

  /// The latest discovery read, used to ignore superseded refreshes.
  final int refreshGeneration;

  /// The last applied discovery read, used to reject old preview results.
  final int previewGeneration;

  /// Whether the latest discovery read is in flight.
  final bool isRefreshing;

  /// Outstanding preview reads, including those for older snapshots.
  final int activePreviews;

  /// Visible coordinates waiting for a preview slot.
  final List<String> previewQueue;

  /// Coordinates already queued or attempted for this snapshot.
  final Set<String> requestedPreviews;

  List<Nip58BadgeDefinition> get visibleDefinitions =>
      _eligibleDefinitions.take(visibleCount).toList(growable: false);

  bool get hasMore => _eligibleDefinitions.skip(visibleCount).isNotEmpty;

  Iterable<Nip58BadgeDefinition> get _eligibleDefinitions =>
      hiddenIssuers.isEmpty
      ? definitions
      : definitions.where((d) => !hiddenIssuers.contains(d.event.pubkey));

  /// Returns a copy with the given fields replaced.
  ExploreBadgesState copyWith({
    ExploreBadgesStatus? status,
    List<Nip58BadgeDefinition>? definitions,
    Set<String>? hiddenIssuers,
    int? refreshFailures,
    int? visibleCount,
    Map<String, List<String>>? previews,
    int? refreshGeneration,
    int? previewGeneration,
    bool? isRefreshing,
    int? activePreviews,
    List<String>? previewQueue,
    Set<String>? requestedPreviews,
  }) {
    return ExploreBadgesState(
      status: status ?? this.status,
      definitions: definitions ?? this.definitions,
      hiddenIssuers: hiddenIssuers ?? this.hiddenIssuers,
      refreshFailures: refreshFailures ?? this.refreshFailures,
      visibleCount: visibleCount ?? this.visibleCount,
      previews: previews ?? this.previews,
      refreshGeneration: refreshGeneration ?? this.refreshGeneration,
      previewGeneration: previewGeneration ?? this.previewGeneration,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      activePreviews: activePreviews ?? this.activePreviews,
      previewQueue: previewQueue ?? this.previewQueue,
      requestedPreviews: requestedPreviews ?? this.requestedPreviews,
    );
  }

  @override
  List<Object?> get props => [
    status,
    definitions,
    hiddenIssuers,
    refreshFailures,
    visibleCount,
    previews,
    refreshGeneration,
    previewGeneration,
    isRefreshing,
    activePreviews,
    previewQueue,
    requestedPreviews,
  ];
}
