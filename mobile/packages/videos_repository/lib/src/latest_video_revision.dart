// ABOUTME: Result of reading the newest revision at a video address before
// ABOUTME: replacing it: found, absent, or unknown when nothing settled it.

import 'package:nostr_sdk/nostr_sdk.dart';

/// The revision a caller about to replace a video opened: its Nostr
/// `created_at` and event id. A read given it asks the relays before
/// returning a Divine REST answer older than this under NIP-01 ordering, and
/// still returns that answer when no relay has a newer one. See
/// `VideosRepository.fetchLatestVideoRevision`.
typedef VideoRevisionFloor = ({int createdAt, String id});

/// What reading a video address returned, for a caller about to replace it:
/// Divine's REST API first, then the relays. See
/// `VideosRepository.fetchLatestVideoRevision`.
sealed class LatestVideoRevision {
  /// Base constructor for the three outcomes.
  const LatestVideoRevision();
}

/// [event] is the newest signed revision the read returned. It can be older
/// than the [VideoRevisionFloor] the read was given, so compare it with the
/// opened revision before building on it.
final class LatestVideoRevisionFound extends LatestVideoRevision {
  /// The read returned [event] as the newest revision.
  const LatestVideoRevisionFound(this.event);

  /// The raw, signature-checked event, unfiltered by viewer preferences.
  final Event event;
}

/// No relay returned a revision at the address, and either the relay read
/// completed or the REST API answered that it holds none there. The REST
/// API hides deleted videos, so a deletion reads as absent.
final class LatestVideoRevisionAbsent extends LatestVideoRevision {
  /// No signed revision was returned for the address.
  const LatestVideoRevisionAbsent();
}

/// Neither the REST API nor a relay returned a revision, the relay read did
/// not complete, and the REST API did not answer that it holds none (it
/// failed or was not asked), so a revision may exist that this read did not
/// see.
final class LatestVideoRevisionUnknown extends LatestVideoRevision {
  /// The read returned nothing and did not complete.
  const LatestVideoRevisionUnknown();
}
