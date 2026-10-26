part of 'badges_cubit.dart';

/// Dashboard loading status.
enum BadgesStatus {
  /// No badge data has been requested yet.
  initial,

  /// Badge data is loading.
  loading,

  /// Badge data loaded successfully.
  loaded,

  /// Badge data could not be loaded.
  error,
}

/// Current mutation status for badge actions.
enum BadgeActionStatus {
  /// No mutation is running.
  idle,

  /// An accept action is publishing.
  accepting,

  /// A remove action is publishing.
  removing,

  /// A hide or restore action is syncing.
  hiding,

  /// The last mutation completed.
  completed,

  /// The last mutation failed.
  error,
}

/// State for the [BadgesCubit].
class BadgesState extends Equatable {
  /// Creates badge dashboard state.
  const BadgesState({
    this.status = BadgesStatus.initial,
    this.actionStatus = BadgeActionStatus.idle,
    this.awarded = const [],
    this.issued = const [],
    this.created = const [],
    this.hidden = const [],
  });

  /// Current dashboard loading status.
  final BadgesStatus status;

  /// Current accept, remove, or hide action status.
  final BadgeActionStatus actionStatus;

  /// Badge awards addressed to the current user.
  final List<BadgeAwardViewData> awarded;

  /// Badge awards issued by the current user.
  final List<IssuedBadgeViewData> issued;

  /// Badge definitions authored by the current user.
  final List<CreatedBadgeViewData> created;

  /// Awards the account dismissed, kept so they can be restored.
  final List<BadgeAwardViewData> hidden;

  /// Awards waiting on a decision — offered, not yet accepted or dismissed.
  ///
  /// [hidden] is a separate list, so an award is pending purely on not having
  /// been accepted. Badge awards arrive rarely and a user holds a handful, so
  /// the filter stays a getter rather than another stored field.
  List<BadgeAwardViewData> get pending =>
      awarded.where((award) => !award.isAccepted).toList();

  /// Whether [actionStatus] is a finished outcome a reload should clear.
  ///
  /// The in-flight values gate the action buttons, so a pull to refresh
  /// landing mid-publish must leave them alone.
  bool get hasSettledAction =>
      actionStatus == BadgeActionStatus.completed ||
      actionStatus == BadgeActionStatus.error;

  /// Returns a copy with selected fields replaced.
  BadgesState copyWith({
    BadgesStatus? status,
    BadgeActionStatus? actionStatus,
    List<BadgeAwardViewData>? awarded,
    List<IssuedBadgeViewData>? issued,
    List<CreatedBadgeViewData>? created,
    List<BadgeAwardViewData>? hidden,
  }) {
    return BadgesState(
      status: status ?? this.status,
      actionStatus: actionStatus ?? this.actionStatus,
      awarded: awarded ?? this.awarded,
      issued: issued ?? this.issued,
      created: created ?? this.created,
      hidden: hidden ?? this.hidden,
    );
  }

  @override
  List<Object?> get props => [
    status,
    actionStatus,
    awarded,
    issued,
    created,
    hidden,
  ];
}
