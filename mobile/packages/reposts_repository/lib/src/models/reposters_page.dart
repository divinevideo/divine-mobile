import 'package:meta/meta.dart';

/// The people who reposted an event, read from the relays in one page.
@immutable
class RepostersPage {
  /// Creates a page of reposters.
  const RepostersPage({required this.pubkeys, this.isComplete = true});

  /// Reposters, most recent first and deduplicated.
  final List<String> pubkeys;

  /// Whether every relay finished answering the repost reads.
  ///
  /// `false` when a read ran out of time, a relay was cut off or dropped, or
  /// a relay refused while no other relay answered or for a reason a retry
  /// may change (rate limit, `auth-required`, a transient error): [pubkeys]
  /// then holds only the people found before the read stopped, and an empty
  /// list does not mean nobody reposted (#10846).
  final bool isComplete;
}
