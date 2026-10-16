// ABOUTME: What one relay sent in answer to a REQ, as RelayPool counts it,
// ABOUTME: and whether that answer may have stopped at the relay's cap.

import 'dart:math' as math;

import 'package:meta/meta.dart';

import '../../event.dart';
import '../../filter.dart';
import '../../relay/relay.dart';
import '../../relay/relay_type.dart';

/// What one relay sent in answer to a `REQ`: the counts a one-shot read and
/// a live subscription's stored batch are both judged by.
@internal
class RelayAnswerTally {
  RelayAnswerTally(int filterCount)
    : eventsPerFilter = List<int>.filled(filterCount, 0);

  /// The NIP-67 hint confirming a relay sent every matching stored event.
  static const finishHint = 'finish';

  /// The NIP-67 hint saying a relay holds more matching events than it sent.
  static const moreHint = 'more';

  /// `EVENT` frames that matched each filter, by filter index.
  final List<int> eventsPerFilter;

  /// `EVENT` frames from this relay that matched any filter.
  int events = 0;

  /// The oldest `created_at` among those frames; null while there are none.
  int? oldestCreatedAt;

  /// NIP-67 hints from the relay's latest `EOSE`.
  Set<String> hints = const <String>{};

  /// `EVENT` frames from this relay that matched none of the filters.
  int outsideFilter = 0;

  /// `EVENT` frames from this relay that the pool rejected before judging
  /// them against the filters: not an event, or not validly signed.
  int rejected = 0;

  /// Records an `EVENT` frame that passed [filters], so a single filter
  /// counts it without matching it again.
  void recordEvent(Event event, List<Filter> filters) {
    events += 1;
    final oldest = oldestCreatedAt;
    if (oldest == null || event.createdAt < oldest) {
      oldestCreatedAt = event.createdAt;
    }
    if (filters.length == 1) {
      eventsPerFilter[0] += 1;
      return;
    }
    for (var i = 0; i < filters.length; i++) {
      if (filters[i].checkEvent(event)) eventsPerFilter[i] += 1;
    }
  }

  /// Keeps the NIP-67 hints an `EOSE` [frame] carries.
  ///
  /// Hints are the string elements of a list in the frame's third position.
  /// A third element that is not a list is ignored, as are elements that are
  /// not strings and hint values nothing here acts on.
  void recordEoseHints(List<dynamic> frame) {
    final hints = frame.length > 2 ? frame[2] : null;
    this.hints = hints is List
        ? {...hints.whereType<String>()}
        : const <String>{};
  }

  /// Whether [relay]'s answer to [filters] may have stopped at its
  /// result-size limit.
  ///
  /// A cache relay never has: it serves the pool's own copies of what relays
  /// sent, so reaching a limit says nothing a relay withheld. Any other relay
  /// may when it sent events outside the filters, or frames the pool
  /// rejected: either may have spent its limit on something nobody can use.
  /// Otherwise a NIP-67 `more` hint settles it as capped and `finish` as not.
  /// Failing both, it may when its events for some filter reached
  /// `min(limit ?? max_limit, max_limit)`, with `max_limit` from the relay's
  /// NIP-11 document. A relay that publishes none may when those events
  /// reached the filter's `limit` or, with no `limit` either, numbered at
  /// least one.
  bool mayBeCapped(Relay relay, List<Filter> filters) {
    if (relay.relayStatus.relayType == RelayType.cache) return false;
    if (outsideFilter > 0 || rejected > 0) return true;
    if (hints.contains(moreHint)) return true;
    if (hints.contains(finishHint)) return false;
    final maxLimit = relay.info?.maxLimit;
    for (var i = 0; i < filters.length; i++) {
      final limit = filters[i].limit;
      final count = eventsPerFilter[i];
      if (maxLimit != null) {
        if (count >= math.min(limit ?? maxLimit, maxLimit)) return true;
      } else if (limit != null ? count >= limit : count > 0) {
        return true;
      }
    }
    return false;
  }
}
