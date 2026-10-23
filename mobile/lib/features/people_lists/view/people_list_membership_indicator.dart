// ABOUTME: Compact indicator showing how many people lists contain a pubkey.
// ABOUTME: Renders nothing when the pubkey is not in any list.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/l10n/l10n.dart';

/// Compact label that shows how many of the authenticated user's people
/// lists currently contain [pubkey].
///
/// Behavior:
/// * Hidden when the pubkey is not in any list (count == 0).
/// * Otherwise renders `"In 1 list"` or `"In N lists"`.
///
/// The widget reads the reverse membership index directly from the
/// surrounding [PeopleListsBloc] via `context.select`, so it rebuilds only
/// when the membership count for this exact [pubkey] changes.
class PeopleListMembershipIndicator extends StatelessWidget {
  /// Creates the indicator.
  const PeopleListMembershipIndicator({
    required this.pubkey,
    super.key,
  });

  /// Full 64-hex Nostr pubkey whose list membership should be summarized.
  /// Never truncated in code, logs, tests, or analytics.
  final String pubkey;

  @override
  Widget build(BuildContext context) {
    final count = context.select<PeopleListsBloc, int>(
      (bloc) => bloc.state.listIdsByPubkey[pubkey]?.length ?? 0,
    );
    if (count == 0) {
      return const SizedBox.shrink();
    }

    return Text(
      context.l10n.peopleListsInNLists(count),
      style: VineTheme.labelSmallFont(color: context.vineColors.secondaryText),
    );
  }
}
