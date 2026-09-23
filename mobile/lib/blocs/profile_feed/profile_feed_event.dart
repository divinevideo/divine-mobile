part of 'profile_feed_cubit.dart';

/// Base class for [ProfileFeedCubit] events.
sealed class ProfileFeedEvent extends Equatable {
  const ProfileFeedEvent();

  @override
  List<Object?> get props => [];
}

/// Kicks off the cold load (relay snapshot + REST composition). Dispatched once
/// from the constructor.
final class ProfileFeedStarted extends ProfileFeedEvent {
  const ProfileFeedStarted();
}

/// Loads the next page (REST offset page or Nostr-fallback page). `droppable`.
final class ProfileFeedLoadMoreRequested extends ProfileFeedEvent {
  const ProfileFeedLoadMoreRequested();
}

/// Forces a full refresh. `restartable` — the latest refresh wins.
final class ProfileFeedRefreshRequested extends ProfileFeedEvent {
  const ProfileFeedRefreshRequested({this.completer});

  /// Optional completion signal for UI refresh affordances, completed once the
  /// handler is fully done. See [completeProfileTabSync].
  ///
  /// Deliberately not in [props]: the completer is an out-of-band callback, not
  /// part of the event's identity, and equality is what lets a caller verify
  /// `add(const ProfileFeedRefreshRequested())` regardless of the waiter.
  final Completer<void>? completer;
}

/// Re-applies feed filters in place over the cached source (no re-fetch).
/// Dispatched when a blocklist/content-preference version changes (#4782).
final class ProfileFeedFiltersChanged extends ProfileFeedEvent {
  const ProfileFeedFiltersChanged();
}

/// Internal: the VideoEventService relay snapshot changed (via `addListener`).
/// This is the sole realtime add path — new videos for the author flow through
/// here too, since the service always notifies listeners when a video lands.
final class ProfileFeedRelaySnapshotChanged extends ProfileFeedEvent {
  const ProfileFeedRelaySnapshotChanged();
}

/// Internal: a video by this author was updated; collapses to a refresh.
/// `restartable`.
final class ProfileFeedVideoUpdated extends ProfileFeedEvent {
  const ProfileFeedVideoUpdated();
}

/// Internal: the cold-load hard timeout fired; clears [ProfileFeedState.isInitialLoad].
final class ProfileFeedInitialLoadTimedOut extends ProfileFeedEvent {
  const ProfileFeedInitialLoadTimedOut();
}

/// Internal: background Nostr enrichment of the REST page completed; merge the
/// enriched copies back over their source keys (#3705).
final class ProfileFeedEnrichmentReady extends ProfileFeedEvent {
  const ProfileFeedEnrichmentReady({
    required this.enriched,
    required this.sourceKeys,
  });

  final List<VideoEvent> enriched;
  final Set<String> sourceKeys;

  @override
  List<Object?> get props => [enriched, sourceKeys];
}

/// Internal: the author's pin list arrived (cache, relay, or an accepted
/// mutation); re-derive the pinned-first sequence and resolve any pinned video
/// outside the loaded feed window.
final class ProfileFeedPinsChanged extends ProfileFeedEvent {
  const ProfileFeedPinsChanged(this.coordinates);

  /// Managed kind-34236 coordinates in stored order.
  final List<String> coordinates;

  @override
  List<Object?> get props => [coordinates];
}

/// Re-reads the locally accepted pin list, e.g. after another route changed
/// it through the shared repository.
final class ProfileFeedPinsReloadRequested extends ProfileFeedEvent {
  const ProfileFeedPinsReloadRequested();
}

/// Pin mutations use one serialized bucket so coordinate recovery cannot race
/// a video-based pin or unpin operation.
sealed class ProfileFeedPinMutation extends ProfileFeedEvent {
  const ProfileFeedPinMutation();
}

/// A pin-list mutation for one of the viewer's own videos. The repository
/// serializes read-modify-write operations; this event bucket also keeps the
/// cubit's state updates and cap checks in the same order.
sealed class ProfileFeedPinMutationRequested extends ProfileFeedPinMutation {
  const ProfileFeedPinMutationRequested(this.video, {this.quiet = false});

  final VideoEvent video;

  /// Leave [ProfileFeedState.pinFeedback] untouched whatever the outcome, for
  /// a mutation the viewer did not ask for by name.
  final bool quiet;

  @override
  List<Object?> get props => [video, quiet];
}

/// Pins [video] to the front of the viewer's own profile.
final class ProfileFeedPinRequested extends ProfileFeedPinMutationRequested {
  const ProfileFeedPinRequested(super.video);
}

/// Removes [video] from the viewer's own pinned videos.
///
/// The grid sends it [quiet] after a successful delete of a pinned video:
/// the deleted coordinate would otherwise keep occupying one of the pin
/// slots with no tile left to unpin it from. That cleanup is best-effort and
/// rides on the delete's own snackbar, so neither outcome announces itself;
/// one that never lands is retried by the next profile open, which releases
/// every pinned coordinate the relays report deleted.
final class ProfileFeedUnpinRequested extends ProfileFeedPinMutationRequested {
  const ProfileFeedUnpinRequested(super.video, {super.quiet});
}

/// Removes a stored pin by coordinate when the video itself cannot resolve.
final class ProfileFeedPinnedCoordinateRemoveRequested
    extends ProfileFeedPinMutation {
  const ProfileFeedPinnedCoordinateRemoveRequested(this.coordinate);

  final String coordinate;

  @override
  List<Object?> get props => [coordinate];
}
