// ABOUTME: Follow/Following button for a list somebody else owns: in the header
// ABOUTME: action row of the list screens, or compact while a list resolves.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/l10n/l10n.dart';

/// Follow/Following button shown to non-owners in a list header's action row,
/// filling its slot there, or as a [compact] pill in an app bar.
///
/// Following a list adds it to the feed selector in Home.
class FollowListButton extends StatelessWidget {
  const FollowListButton({
    required this.isFollowing,
    required this.isBusy,
    required this.onPressed,
    this.compact = false,
    super.key,
  });

  final bool isFollowing;

  /// A follow or unfollow is in flight: shows progress and ignores taps.
  final bool isBusy;

  final VoidCallback onPressed;

  /// A small pill sized to its label, for an app bar, instead of a button
  /// that fills its slot in a header row.
  final bool compact;

  @override
  Widget build(BuildContext context) {
    return DivineButton(
      label: isFollowing
          ? context.l10n.listFollowingButton
          : context.l10n.listFollowButton,
      size: compact ? DivineButtonSize.small : DivineButtonSize.base,
      expanded: !compact,
      type: isFollowing ? DivineButtonType.secondary : DivineButtonType.primary,
      leadingIcon: isFollowing ? DivineIconName.check : DivineIconName.plus,
      isLoading: isBusy,
      onPressed: isBusy ? null : onPressed,
    );
  }
}
