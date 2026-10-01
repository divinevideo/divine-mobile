// ABOUTME: Waits for the exact people-list batch submitted by a picker.
// ABOUTME: Account changes or stream closure settle the waiter quietly.

import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';

/// Observes one batch before it is dispatched, retaining even a fast answer.
///
/// Another visit for the same person cannot complete this wait: [requestId]
/// must match. Returns 0 if the owner changes, the feature is disabled, or
/// the stream closes before the batch finishes.
Future<int> awaitRefusedPicks({
  required Stream<PeopleListsState> states,
  required Object requestId,
  required String ownerPubkey,
  required PeopleListsPicksOutcome? before,
  required String pubkey,
}) async {
  final seen = before?.sequence ?? 0;
  final state = await states.firstWhere(
    (state) {
      if (state.activeOwnerPubkey != ownerPubkey) return true;
      final outcome = state.lastPicksOutcome;
      return outcome != null &&
          identical(outcome.requestId, requestId) &&
          outcome.sequence > seen &&
          outcome.pubkey == pubkey;
    },
    orElse: () => const PeopleListsState(),
  );
  return state.activeOwnerPubkey == ownerPubkey
      ? state.lastPicksOutcome?.refused ?? 0
      : 0;
}
