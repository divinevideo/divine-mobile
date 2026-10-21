// ABOUTME: State class for MyFollowersBloc
// ABOUTME: Represents all possible states of the current user's followers list

part of 'my_followers_bloc.dart';

/// Enum representing the status of the followers list loading
enum MyFollowersStatus {
  /// Initial state, no data loaded yet
  initial,

  /// Currently loading data from Nostr
  loading,

  /// Data loaded successfully
  success,

  /// An error occurred while loading data
  failure,
}

/// State class for MyFollowersBloc
final class MyFollowersState extends Equatable {
  const MyFollowersState({
    this.status = MyFollowersStatus.initial,
    this.followersPubkeys = const [],
    this.rawFollowersPubkeys = const [],
    this.rawDatedCount = 0,
    this.sortOrder = FollowListSort.smart,
    this.authoritativeFollowerCount = 0,
    this.isRefreshing = false,
    this.smartOrder = const [],
    this.rankingSignals = const {},
    this.isSmartOrderReady = false,
    this.eligibilityRevision = 0,
  });

  /// Block-policy version used to retry snapshots read during a policy change.
  final int eligibilityRevision;

  /// Frozen first-load ranking, with later arrivals appended.
  final List<String> smartOrder;

  /// Local signals for every member, neutral where the loader had none; rows
  /// also read them for presentation.
  final Map<String, UserRankingSignals> rankingSignals;

  /// Whether the initial local ranking has completed, including empty lists.
  final bool isSmartOrderReady;

  /// The current status of the followers list
  final MyFollowersStatus status;

  /// List of pubkeys who follow the current user (blocklist-filtered).
  final List<String> followersPubkeys;

  /// Unfiltered follower pubkeys as received from the repository, newest
  /// follower first.
  ///
  /// Stored in state so blocklist re-filtering and sort changes can replay the
  /// full list without waiting for a new network event.
  final List<String> rawFollowersPubkeys;

  /// How many leading [rawFollowersPubkeys] carry a contact-list timestamp.
  ///
  /// Passed to [FollowSortOrder.fromNewestFirst] so [sortOrder] can flip the dated
  /// prefix while leaving undated followers at the end.
  final int rawDatedCount;

  /// The order [followersPubkeys] is presented in.
  final FollowListSort sortOrder;

  /// Follower count as reported by the repository, before local safety filters.
  ///
  /// Kept separately so blocklist changes can recompute [followerCount] from
  /// the raw list without losing the server-provided baseline.
  final int authoritativeFollowerCount;

  /// Follower count shown in the UI after applying known local safety filters.
  ///
  /// Funnelcake remains the deterministic baseline (#8197), but accounts the
  /// owner has blocked or follow-severed must not still appear in their count.
  /// Only hidden rows actually observed in the fetched list are subtracted;
  /// the result is not floored at the relay-derived visible row count, so relay
  /// coverage cannot inflate or destabilize the displayed number.
  int get followerCount => visibleFollowerCount(
    visiblePubkeyCount: followersPubkeys.length,
    rawPubkeyCount: rawFollowersPubkeys.length,
    authoritativeFollowerCount: authoritativeFollowerCount,
  );

  /// True while cached data is shown but a fresh network fetch is in progress.
  final bool isRefreshing;

  /// Create a copy with updated values
  MyFollowersState copyWith({
    MyFollowersStatus? status,
    List<String>? followersPubkeys,
    List<String>? rawFollowersPubkeys,
    int? rawDatedCount,
    FollowListSort? sortOrder,
    int? authoritativeFollowerCount,
    bool? isRefreshing,
    List<String>? smartOrder,
    Map<String, UserRankingSignals>? rankingSignals,
    bool? isSmartOrderReady,
    int? eligibilityRevision,
  }) {
    return MyFollowersState(
      status: status ?? this.status,
      followersPubkeys: followersPubkeys ?? this.followersPubkeys,
      rawFollowersPubkeys: rawFollowersPubkeys ?? this.rawFollowersPubkeys,
      rawDatedCount: rawDatedCount ?? this.rawDatedCount,
      sortOrder: sortOrder ?? this.sortOrder,
      authoritativeFollowerCount:
          authoritativeFollowerCount ?? this.authoritativeFollowerCount,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      smartOrder: smartOrder ?? this.smartOrder,
      rankingSignals: rankingSignals ?? this.rankingSignals,
      isSmartOrderReady: isSmartOrderReady ?? this.isSmartOrderReady,
      eligibilityRevision: eligibilityRevision ?? this.eligibilityRevision,
    );
  }

  @override
  List<Object?> get props => [
    status,
    followersPubkeys,
    rawFollowersPubkeys,
    rawDatedCount,
    sortOrder,
    authoritativeFollowerCount,
    isRefreshing,
    smartOrder,
    rankingSignals,
    isSmartOrderReady,
    eligibilityRevision,
  ];
}
