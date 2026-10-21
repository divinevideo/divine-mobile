// ABOUTME: State class for MyFollowingBloc
// ABOUTME: Represents all possible states of the current user's following list

part of 'my_following_bloc.dart';

/// Enum representing the status of the following list loading.
enum MyFollowingStatus {
  /// Initial state, no data loaded yet.
  initial,

  /// Data loaded successfully (may be from cache while refreshing).
  success,

  /// A follow or unfollow request failed (list data remains available).
  toggleFailure,

  /// An error occurred while loading data.
  failure,
}

/// State class for MyFollowingBloc.
final class MyFollowingState extends Equatable {
  const MyFollowingState({
    this.status = MyFollowingStatus.initial,
    this.followingPubkeys = const [],
    this.rawFollowingPubkeys = const [],
    this.sortOrder = FollowListSort.smart,
    this.isRefreshing = false,
    this.smartOrder = const [],
    this.rankingSignals = const {},
    this.isSmartOrderReady = false,
    this.eligibilityRevision = 0,
    this.repositoryRevision = 0,
    this.hasLocalFollowEdit = false,
    this.rankedSnapshot,
  });

  /// Last fully ranked membership, retained across optimistic removals and
  /// same-owner bloc replacement so a failed edit restores its original order.
  final ({List<String> order, Map<String, UserRankingSignals> signals})?
  rankedSnapshot;

  /// Live membership revision used to discard older async ranking results.
  final int repositoryRevision;

  /// Block-policy version used to retry snapshots read during a policy change.
  final int eligibilityRevision;

  /// Frozen first-load ranking, with later arrivals appended.
  final List<String> smartOrder;

  /// Local signals for every member, neutral where the loader had none; rows
  /// also read them for presentation.
  final Map<String, UserRankingSignals> rankingSignals;

  /// Whether the initial local ranking has completed, including empty lists.
  final bool isSmartOrderReady;

  /// The current status of the following list.
  final MyFollowingStatus status;

  /// List of pubkeys the current user is following (blocklist-filtered).
  final List<String> followingPubkeys;

  /// Unfiltered following pubkeys as received from the repository, in follow
  /// order — the contact list's `p` tags verbatim, oldest follow first.
  ///
  /// Stored in state so blocklist re-filtering and sort changes can replay the
  /// full list without waiting for a new network event.
  final List<String> rawFollowingPubkeys;

  /// The order [followingPubkeys] is presented in.
  final FollowListSort sortOrder;

  /// True while stale cache data is shown and a fresh fetch is in progress.
  final bool isRefreshing;

  /// True once the user has followed or unfollowed through this bloc.
  ///
  /// After a local edit the repository's in-memory list is the authority.
  /// An in-flight `watchMyFollowingCached` revalidation can still resolve with
  /// the relay-lagged pre-edit snapshot; this flag tells the load handler to
  /// defer to the repository instead of letting that stale emission revert the
  /// button (#5144).
  final bool hasLocalFollowEdit;

  /// Check if the current user is following a specific pubkey.
  bool isFollowing(String pubkey) => followingPubkeys.contains(pubkey);

  /// Create a copy with updated values.
  MyFollowingState copyWith({
    MyFollowingStatus? status,
    List<String>? followingPubkeys,
    List<String>? rawFollowingPubkeys,
    FollowListSort? sortOrder,
    bool? isRefreshing,
    List<String>? smartOrder,
    Map<String, UserRankingSignals>? rankingSignals,
    bool? isSmartOrderReady,
    int? eligibilityRevision,
    int? repositoryRevision,
    bool? hasLocalFollowEdit,
    ({List<String> order, Map<String, UserRankingSignals> signals})?
    rankedSnapshot,
  }) {
    return MyFollowingState(
      status: status ?? this.status,
      followingPubkeys: followingPubkeys ?? this.followingPubkeys,
      rawFollowingPubkeys: rawFollowingPubkeys ?? this.rawFollowingPubkeys,
      sortOrder: sortOrder ?? this.sortOrder,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      smartOrder: smartOrder ?? this.smartOrder,
      rankingSignals: rankingSignals ?? this.rankingSignals,
      isSmartOrderReady: isSmartOrderReady ?? this.isSmartOrderReady,
      eligibilityRevision: eligibilityRevision ?? this.eligibilityRevision,
      repositoryRevision: repositoryRevision ?? this.repositoryRevision,
      hasLocalFollowEdit: hasLocalFollowEdit ?? this.hasLocalFollowEdit,
      rankedSnapshot: rankedSnapshot ?? this.rankedSnapshot,
    );
  }

  @override
  List<Object?> get props => [
    status,
    followingPubkeys,
    rawFollowingPubkeys,
    sortOrder,
    isRefreshing,
    smartOrder,
    rankingSignals,
    isSmartOrderReady,
    eligibilityRevision,
    repositoryRevision,
    hasLocalFollowEdit,
    rankedSnapshot?.order,
    rankedSnapshot?.signals,
  ];
}
