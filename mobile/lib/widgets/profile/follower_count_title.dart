// ABOUTME: Reusable title widget for follower/following screens
// ABOUTME: Uses BlocSelector for efficient rebuilds on count changes only

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';

/// A title widget that shows a label with a count subtitle.
///
/// Uses [BlocSelector] to only rebuild when the count changes,
/// improving performance by avoiding unnecessary rebuilds when
/// other parts of the state change.
///
/// Example usage:
/// ```dart
/// FollowerCountTitle<MyFollowersBloc, MyFollowersState>(
///   title: 'Followers',
///   selector: (state) => state.status == MyFollowersStatus.success
///       ? state.followersPubkeys.length
///       : 0,
/// )
/// ```
class FollowerCountTitle<B extends StateStreamable<S>, S>
    extends StatelessWidget {
  /// Creates a [FollowerCountTitle] widget.
  ///
  /// [title] is the main title text (e.g., "John's Followers").
  /// [selector] extracts the count from the bloc state.
  const FollowerCountTitle({
    required this.title,
    required this.selector,
    super.key,
  });

  /// The main title text to display.
  final String title;

  /// Selector function to extract the count from the bloc state.
  ///
  /// Should return 0 when the data is not yet loaded.
  final int Function(S state) selector;

  @override
  Widget build(BuildContext context) {
    return BlocSelector<B, S, int>(
      selector: selector,
      builder: (context, count) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              title,
              style: VineTheme.titleLargeFont(
                color: context.vineColors.primaryText,
              ),
            ),
            Text(
              context.l10n.profileFollowerCountUsers(count),
              style: VineTheme.bodySmallFont(
                color: context.vineColors.onSurfaceVariant,
              ),
            ),
          ],
        );
      },
    );
  }
}
