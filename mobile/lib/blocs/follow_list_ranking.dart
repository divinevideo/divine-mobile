// ABOUTME: Stateless local ranking operations shared by owned follow lists.
// ABOUTME: Blocs retain lifecycle, revision, retry, and presentation ownership.

import 'package:openvine/services/user_ranking/user_ranking_signals_loader.dart';
import 'package:unified_logger/unified_logger.dart';
import 'package:user_ranking/user_ranking.dart';

/// Loads authoritative eligible signals, with an eligibility-safe error fallback.
Future<Map<String, UserRankingSignals>> loadFollowListRankingSignals({
  required List<String> pubkeys,
  required UserRankingSignalsLoader loader,
  required String logName,
  required void Function(Object, StackTrace) onError,
}) async {
  try {
    return await loader.load(pubkeys);
  } catch (error, stackTrace) {
    Log.error(
      'Failed to load follow ranking: $error',
      name: logName,
      category: LogCategory.system,
    );
    onError(error, stackTrace);
    return {
      for (final pubkey in pubkeys.where(loader.isEligible))
        pubkey: UserRankingSignals(pubkey: pubkey),
    };
  }
}

/// Reads local name tiebreakers, preserving signal eligibility on name failure.
Future<Map<String, String>> loadFollowListRankingNames({
  required Iterable<String> pubkeys,
  required UserRankingSignalsLoader loader,
  required String logName,
  required void Function(Object, StackTrace) onError,
}) async {
  try {
    return await loader.loadCachedDisplayNames(pubkeys);
  } catch (error, stackTrace) {
    Log.error(
      'Failed to load cached follow names: $error',
      name: logName,
      category: LogCategory.system,
    );
    onError(error, stackTrace);
    return const {};
  }
}

/// Ranks a first snapshot or appends new eligible rows to an existing order.
///
/// Call only after checking the owning bloc's current lifecycle and revisions.
/// Successful loader omissions remain authoritative; a name never adds a row.
({Set<String> eligible, List<String> smartOrder}) rankFollowListSnapshot({
  required List<String> pubkeys,
  required Map<String, UserRankingSignals> signals,
  required Map<String, String> names,
  required bool Function(String) isEligible,
  required bool isSmartOrderReady,
  required List<String> previousSmartOrder,
  required DateTime now,
}) {
  final eligible = pubkeys.where(signals.containsKey).where(isEligible).toSet();
  final previousOrder = previousSmartOrder.toSet();
  final smartOrder = isSmartOrderReady
      ? <String>[
          ...previousSmartOrder.where(eligible.contains),
          ...pubkeys
              .where(
                (key) => eligible.contains(key) && !previousOrder.contains(key),
              )
              .toSet(),
        ]
      : rankUsers(
          signals.values.where((signal) => eligible.contains(signal.pubkey)),
          now: now,
          nameOf: (pubkey) => names[pubkey] ?? pubkey,
        );
  return (eligible: eligible, smartOrder: smartOrder);
}
