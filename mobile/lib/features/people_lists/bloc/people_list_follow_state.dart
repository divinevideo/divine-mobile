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

  /// The last follow or unfollow could not be written, or the follows could
  /// not be watched. [PeopleListFollowState.isFollowing] is the last follow
  /// known, or the stored one when it can still be read.
  failure,
}

class PeopleListFollowState extends Equatable {
  const PeopleListFollowState({
    this.status = PeopleListFollowStatus.loading,
    this.isFollowing = false,
    this.hasReadFollowing = false,
  });

  final PeopleListFollowStatus status;

  /// Whether the viewer follows the list.
  final bool isFollowing;

  /// A durable read has established the follow state for this session.
  final bool hasReadFollowing;

  /// The control cannot be used while the follows are unread or a write is
  /// in flight.
  bool get isBusy =>
      !hasReadFollowing ||
      status == PeopleListFollowStatus.loading ||
      status == PeopleListFollowStatus.updating;

  PeopleListFollowState copyWith({
    PeopleListFollowStatus? status,
    bool? isFollowing,
    bool? hasReadFollowing,
  }) {
    return PeopleListFollowState(
      status: status ?? this.status,
      isFollowing: isFollowing ?? this.isFollowing,
      hasReadFollowing: hasReadFollowing ?? this.hasReadFollowing,
    );
  }

  @override
  List<Object?> get props => [status, isFollowing, hasReadFollowing];
}
