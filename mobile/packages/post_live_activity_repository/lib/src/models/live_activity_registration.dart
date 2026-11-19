import 'package:equatable/equatable.dart';

/// Whether a registered activity is still running.
enum LiveActivityRegistrationState {
  /// The activity is running.
  active,

  /// The activity has ended.
  ended,
}

/// What the push service needs to know to update a post's Live Activity.
class LiveActivityRegistration extends Equatable {
  /// Creates a [LiveActivityRegistration].
  const LiveActivityRegistration({
    required this.activityId,
    required this.ownerPubkey,
    required this.activityPushToken,
    required this.postCoordinate,
    required this.postEventIds,
    required this.postedAt,
    required this.windowEndsAt,
    required this.showFirstRunNote,
    required this.state,
  });

  /// Registers a post, with a window of [window] from [postedAt].
  factory LiveActivityRegistration.forPost({
    required String activityId,
    required String ownerPubkey,
    required String activityPushToken,
    required String postCoordinate,
    required List<String> postEventIds,
    required DateTime postedAt,
    required bool showFirstRunNote,
  }) => LiveActivityRegistration(
    activityId: activityId,
    ownerPubkey: ownerPubkey,
    activityPushToken: activityPushToken,
    postCoordinate: postCoordinate,
    postEventIds: postEventIds,
    postedAt: postedAt,
    windowEndsAt: postedAt.add(window),
    showFirstRunNote: showFirstRunNote,
    state: LiveActivityRegistrationState.active,
  );

  /// How long after posting the activity keeps being updated.
  static const window = Duration(minutes: 60);

  /// The platform's identifier for the activity.
  final String activityId;

  /// The hex pubkey of the account the activity belongs to.
  final String ownerPubkey;

  /// The push token the service uses to update the activity.
  final String activityPushToken;

  /// The addressable coordinate of the post.
  final String postCoordinate;

  /// The event ids of the post.
  final List<String> postEventIds;

  /// When the post was published.
  final DateTime postedAt;

  /// When the service stops updating the activity.
  final DateTime windowEndsAt;

  /// Whether the activity shows the first-run note.
  final bool showFirstRunNote;

  /// Whether the activity is still running.
  final LiveActivityRegistrationState state;

  /// A copy of this registration in the ended state.
  LiveActivityRegistration ended() => LiveActivityRegistration(
    activityId: activityId,
    ownerPubkey: ownerPubkey,
    activityPushToken: activityPushToken,
    postCoordinate: postCoordinate,
    postEventIds: postEventIds,
    postedAt: postedAt,
    windowEndsAt: windowEndsAt,
    showFirstRunNote: showFirstRunNote,
    state: LiveActivityRegistrationState.ended,
  );

  /// The `liveActivity` object of the registration request.
  Map<String, Object?> liveActivityWire() => {
    'activityId': activityId,
    'pushToken': activityPushToken,
    'postCoordinate': postCoordinate,
    'postEventIds': postEventIds,
    'postedAt': postedAt.millisecondsSinceEpoch ~/ 1000,
    'windowEndsAt': windowEndsAt.millisecondsSinceEpoch ~/ 1000,
    'showFirstRunNote': showFirstRunNote,
  };

  @override
  List<Object?> get props => [
    activityId,
    ownerPubkey,
    activityPushToken,
    postCoordinate,
    postEventIds,
    postedAt,
    windowEndsAt,
    showFirstRunNote,
    state,
  ];
}
