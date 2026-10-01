// ABOUTME: Waits on PeopleListsBloc for the outcome of the picks the
// ABOUTME: add-to-lists sheet applied, once the sheet itself has closed.

import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';

/// Resolves with how many of the sheet's picks for [pubkey] a relay refused.
///
/// The sheet sends one [PeopleListsPicksApplied] and closes at once; the
/// bloc applies the picks in order and then records a
/// [PeopleListsPicksOutcome] on its state. This waits on [states] for the
/// first outcome for [pubkey] newer than [before], the outcome the state
/// held when the picks were sent (null when there was none), so an outcome
/// left over from an earlier visit cannot be mistaken for this one. Resolves
/// with 0 if the stream closes first.
Future<int> awaitRefusedPicks({
  required Stream<PeopleListsState> states,
  required PeopleListsPicksOutcome? before,
  required String pubkey,
}) async {
  final seen = before?.sequence ?? 0;
  final outcome = await states
      .map((state) => state.lastPicksOutcome)
      .firstWhere(
        (outcome) =>
            outcome != null &&
            outcome.sequence > seen &&
            outcome.pubkey == pubkey,
        orElse: () => null,
      );
  return outcome?.refused ?? 0;
}
