import 'package:equatable/equatable.dart';
import 'package:post_live_activity_repository/src/models/live_activity_state.dart';

/// An event the platform raises about Live Activities.
sealed class LiveActivityPlatformEvent extends Equatable {
  /// Creates a [LiveActivityPlatformEvent].
  const LiveActivityPlatformEvent();
}

/// The user turned Live Activities on or off.
class EnablementChanged extends LiveActivityPlatformEvent {
  /// Creates an [EnablementChanged].
  const EnablementChanged({required this.enabled});

  /// Whether Live Activities are now enabled.
  final bool enabled;

  @override
  List<Object?> get props => [enabled];
}

/// The platform issued a new push token for an activity.
class PushTokenChanged extends LiveActivityPlatformEvent {
  /// Creates a [PushTokenChanged].
  const PushTokenChanged({required this.activityId, required this.token});

  /// The activity the token belongs to.
  final String activityId;

  /// The new activity push token.
  final String token;

  @override
  List<Object?> get props => [activityId, token];
}

/// An activity's state changed.
class ActivityStateChanged extends LiveActivityPlatformEvent {
  /// Creates an [ActivityStateChanged].
  const ActivityStateChanged({required this.activityId, required this.state});

  /// The activity whose state changed.
  final String activityId;

  /// The activity's new state.
  final LiveActivityState state;

  @override
  List<Object?> get props => [activityId, state];
}
