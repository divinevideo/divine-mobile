import 'package:equatable/equatable.dart';

/// Like counts for a batch of events, and which of them are only a floor.
///
/// An id in [incompleteIds] was counted from a read that some relay did not
/// settle: its count is what arrived, and the true count may be higher. It
/// was not cached, so the next request asks the relays again (#9223).
class LikeCounts extends Equatable {
  /// Creates a batch result.
  const LikeCounts({
    required this.counts,
    this.incompleteIds = const {},
  });

  /// Like count per event id. Ids whose count is unknown are left out.
  final Map<String, int> counts;

  /// Ids in [counts] whose count some relay did not settle.
  final Set<String> incompleteIds;

  @override
  List<Object?> get props => [counts, incompleteIds];
}
