import 'package:equatable/equatable.dart';
import 'package:post_live_activity_repository/src/models/live_activity_state.dart';

/// A Live Activity the platform reports as running.
class RunningLiveActivity extends Equatable {
  /// Creates a [RunningLiveActivity].
  const RunningLiveActivity({
    required this.id,
    required this.ownerPubkey,
    required this.startedAt,
    required this.state,
    this.postCoordinate,
    this.postEventId,
  });

  /// The platform's identifier for the activity.
  final String id;

  /// The hex pubkey of the account the activity belongs to.
  final String ownerPubkey;

  /// When the activity started.
  final DateTime startedAt;

  /// The addressable coordinate of the post, once known.
  final String? postCoordinate;

  /// The event id of the post, once known.
  final String? postEventId;

  /// The activity's current state.
  final LiveActivityState state;

  @override
  List<Object?> get props => [
    id,
    ownerPubkey,
    startedAt,
    postCoordinate,
    postEventId,
    state,
  ];
}
