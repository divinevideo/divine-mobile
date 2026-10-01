// ABOUTME: State for following someone else's people list: whether the
// ABOUTME: viewer follows it, and whether a follow or unfollow is in flight.

import 'package:equatable/equatable.dart';

/// Where a people list's follow control stands.
enum PeopleListFollowStatus {
  /// The stored follows have not been read yet.
  loading,

  /// [PeopleListFollowState.isFollowing] is known and the control is idle.
  ready,

  /// A follow or unfollow is being written.
  updating,

  /// The last follow or unfollow could not be written, or the stored follows
  /// could not be read. [PeopleListFollowState.isFollowing] is unchanged.
  failure,
}

class PeopleListFollowState extends Equatable {
  const PeopleListFollowState({
    this.status = PeopleListFollowStatus.loading,
    this.isFollowing = false,
  });

  final PeopleListFollowStatus status;

  /// Whether the viewer follows the list.
  final bool isFollowing;

  /// The control cannot be used while the follows are unread or a write is
  /// in flight.
  bool get isBusy =>
      status == PeopleListFollowStatus.loading ||
      status == PeopleListFollowStatus.updating;

  PeopleListFollowState copyWith({
    PeopleListFollowStatus? status,
    bool? isFollowing,
  }) {
    return PeopleListFollowState(
      status: status ?? this.status,
      isFollowing: isFollowing ?? this.isFollowing,
    );
  }

  @override
  List<Object?> get props => [status, isFollowing];
}
