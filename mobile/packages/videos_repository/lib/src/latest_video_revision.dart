// ABOUTME: Result of reading the newest revision at a video address before
// ABOUTME: replacing it: found, absent, or unknown when no read completed.

import 'package:nostr_sdk/nostr_sdk.dart';

/// What Divine's REST API or the relays hold at a video address, read so
/// the caller can replace it. See `VideosRepository.fetchLatestVideoRevision`.
sealed class LatestVideoRevision {
  /// Base constructor for the three outcomes.
  const LatestVideoRevision();
}

/// [event] is the newest signed revision the read returned.
final class LatestVideoRevisionFound extends LatestVideoRevision {
  /// The newest revision is [event].
  const LatestVideoRevisionFound(this.event);

  /// The raw, signature-checked event, unfiltered by viewer preferences.
  final Event event;
}

/// The REST API held no revision at the address, and the relay read
/// completed without one.
final class LatestVideoRevisionAbsent extends LatestVideoRevision {
  /// No signed revision was returned for the address.
  const LatestVideoRevisionAbsent();
}

/// Neither the REST API nor a relay returned a revision, and the relay read
/// did not complete, so a revision may exist that this read did not see.
final class LatestVideoRevisionUnknown extends LatestVideoRevision {
  /// The read returned nothing and did not complete.
  const LatestVideoRevisionUnknown();
}
