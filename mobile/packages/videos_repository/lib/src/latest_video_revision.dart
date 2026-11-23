// ABOUTME: Result of reading the newest revision at a video address before
// ABOUTME: replacing it: found, absent, or unknown when a relay never settled.

import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';

/// What the relays hold at a video address, read so the caller can replace
/// it. See `VideosRepository.fetchLatestVideoRevision`.
sealed class LatestVideoRevision {
  /// Base constructor for the three outcomes.
  const LatestVideoRevision();

  /// Adapts the canonical settled read without treating failure as absence.
  factory LatestVideoRevision.fromCurrentVersion(CurrentVersionRead read) =>
      switch (read) {
        CurrentVersionFound(:final event) => LatestVideoRevisionFound(event),
        CurrentVersionAbsent() => const LatestVideoRevisionAbsent(),
        CurrentVersionFailed() => const LatestVideoRevisionUnknown(),
      };
}

/// The read settled, and [event] is the newest signed revision it returned.
final class LatestVideoRevisionFound extends LatestVideoRevision {
  /// The newest revision is [event].
  const LatestVideoRevisionFound(this.event);

  /// The raw, signature-checked event, unfiltered by viewer preferences.
  final Event event;
}

/// The read settled without a signed revision at the address.
final class LatestVideoRevisionAbsent extends LatestVideoRevision {
  /// No signed revision was returned for the address.
  const LatestVideoRevisionAbsent();
}

/// A relay did not answer in full, so a newer revision may exist that this
/// read did not see. Replacing the address now could delete it.
final class LatestVideoRevisionUnknown extends LatestVideoRevision {
  /// The read did not settle.
  const LatestVideoRevisionUnknown();
}
