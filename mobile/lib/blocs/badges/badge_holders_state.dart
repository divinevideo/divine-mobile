part of 'badge_holders_cubit.dart';

/// Loading status of a badge's accepted holders.
enum BadgeHoldersStatus {
  /// Nothing has been requested yet.
  initial,

  /// The holders are loading.
  loading,

  /// The holders loaded.
  loaded,

  /// The holders could not be completely loaded.
  failure,
}

/// Status of the viewer's subscription to a badge.
enum BadgeSubscriptionStatus {
  /// Nothing has been requested yet.
  initial,

  /// No account is signed in, so there is nothing to subscribe with.
  unavailable,

  /// The subscription is loading.
  loading,

  /// The subscription is known and can be toggled.
  ready,

  /// A subscription change is publishing.
  saving,

  /// The subscription could not be loaded.
  failure,
}

/// State for the [BadgeHoldersCubit].
class BadgeHoldersState extends Equatable {
  /// Creates badge holder state.
  const BadgeHoldersState({
    required this.coordinate,
    this.holdersStatus = BadgeHoldersStatus.initial,
    this.holders = const [],
    this.subscriptionStatus = BadgeSubscriptionStatus.initial,
    this.isSubscribed = false,
    this.subscriptionRevision = 0,
    this.saveFailures = 0,
  });

  /// Address of the badge.
  final BadgeCoordinate coordinate;

  /// Loading status of [holders].
  final BadgeHoldersStatus holdersStatus;

  /// Pubkeys of every holder who currently accepts the badge.
  final List<String> holders;

  /// Status of the viewer's subscription.
  final BadgeSubscriptionStatus subscriptionStatus;

  /// Whether the viewer subscribes to this badge's holders.
  final bool isSubscribed;

  /// Increments each time a subscription change is published.
  final int subscriptionRevision;

  /// Increments each time a subscription change fails to publish.
  final int saveFailures;

  /// Returns a copy with the given fields replaced.
  BadgeHoldersState copyWith({
    BadgeHoldersStatus? holdersStatus,
    List<String>? holders,
    BadgeSubscriptionStatus? subscriptionStatus,
    bool? isSubscribed,
    int? subscriptionRevision,
    int? saveFailures,
  }) {
    return BadgeHoldersState(
      coordinate: coordinate,
      holdersStatus: holdersStatus ?? this.holdersStatus,
      holders: holders ?? this.holders,
      subscriptionStatus: subscriptionStatus ?? this.subscriptionStatus,
      isSubscribed: isSubscribed ?? this.isSubscribed,
      subscriptionRevision: subscriptionRevision ?? this.subscriptionRevision,
      saveFailures: saveFailures ?? this.saveFailures,
    );
  }

  @override
  List<Object?> get props => [
    coordinate,
    holdersStatus,
    holders,
    subscriptionStatus,
    isSubscribed,
    subscriptionRevision,
    saveFailures,
  ];
}
