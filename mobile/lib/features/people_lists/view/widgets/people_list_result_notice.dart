// ABOUTME: Inline message for a people-list operation that did not succeed.
// ABOUTME: A live region, so screen readers hear the outcome when it appears.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/features/people_lists/bloc/people_lists_bloc.dart';
import 'package:openvine/l10n/l10n.dart';

/// Shows the outcome of a [PeopleListsOperationResult] that needs the user's
/// attention, and nothing for a pending or successful one.
///
/// [failedMessage] is the copy for a failed operation. A cancelled one always
/// reads as a changed session, since the bloc only cancels when the account,
/// the feature flag or the repository changed underneath the request.
///
/// Wrapped in a live region so the message is announced when it appears: the
/// buttons that trigger these operations lose focus to a spinner meanwhile, so
/// nothing else tells a screen-reader user the request ended.
class PeopleListResultNotice extends StatelessWidget {
  /// Creates a notice for [result].
  const PeopleListResultNotice({
    required this.result,
    required this.failedMessage,
    super.key,
  });

  /// The result to report, or `null` while nothing has settled.
  final PeopleListsOperationResult? result;

  /// Copy shown when [result] is [PeopleListsOperationResult.failed].
  final String failedMessage;

  @override
  Widget build(BuildContext context) {
    final message = switch (result) {
      PeopleListsOperationResult.failed => failedMessage,
      PeopleListsOperationResult.cancelled =>
        context.l10n.peopleListsSessionChanged,
      PeopleListsOperationResult.succeeded || null => null,
    };
    if (message == null) return const SizedBox.shrink();

    return Semantics(
      container: true,
      liveRegion: true,
      child: Text(
        message,
        style: VineTheme.bodyMediumFont(color: context.vineColors.onSurface),
      ),
    );
  }
}
