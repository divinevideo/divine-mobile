// ABOUTME: What NostrClient.readCurrentVersion learned about one replaceable
// ABOUTME: or addressable address: its newest version, none, or not knowable.

import 'package:nostr_sdk/nostr_sdk.dart' show Event;

/// The current version of one replaceable or addressable event, read with
/// every relay settled by `NostrClient.readCurrentVersion`.
///
/// Build a replacement only on [CurrentVersionFound] or
/// [CurrentVersionAbsent]. On [CurrentVersionFailed] a relay may hold a newer
/// version nobody heard, and publishing over it deletes whatever only that
/// relay holds. Switch over all three: an `is CurrentVersionFound` test alone
/// treats a failed read as an absent one.
sealed class CurrentVersionRead {
  /// Base constructor for the three outcomes.
  const CurrentVersionRead();
}

/// Every relay answered, and [event] is the newest version any of them holds:
/// the latest `created_at`, then the lowest id (NIP-01).
final class CurrentVersionFound extends CurrentVersionRead {
  /// The read found [event].
  const CurrentVersionFound(this.event);

  /// The current version, signed by the author that was asked for.
  final Event event;
}

/// Every relay answered, and none holds a version.
final class CurrentVersionAbsent extends CurrentVersionRead {
  /// The read found nothing.
  const CurrentVersionAbsent();
}

/// At least one relay did not answer, so the current version is unknown, even
/// when another relay returned one.
final class CurrentVersionFailed extends CurrentVersionRead {
  /// The read could not finish; [noRelay] says whether anything was asked.
  const CurrentVersionFailed({required this.noRelay});

  /// Whether no relay took the read at all, as when the device is offline.
  final bool noRelay;
}
