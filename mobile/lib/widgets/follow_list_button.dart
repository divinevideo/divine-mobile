// ABOUTME: Follow/Following pill for a list somebody else owns, shown in the
// ABOUTME: app bar of the video-list and people-list screens.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:openvine/l10n/l10n.dart';

/// Follow/Following pill shown to non-owners in a list screen's app bar.
///
/// Following a list adds it to the feed selector in Home.
class FollowListButton extends StatelessWidget {
  const FollowListButton({
    required this.isFollowing,
    required this.isBusy,
    required this.onPressed,
    super.key,
  });

  final bool isFollowing;

  /// A follow or unfollow is in flight: shows progress and ignores taps.
  final bool isBusy;

  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DivineButton(
      label: isFollowing
          ? context.l10n.listFollowingButton
          : context.l10n.listFollowButton,
      size: DivineButtonSize.small,
      type: isFollowing ? DivineButtonType.secondary : DivineButtonType.primary,
      leadingIcon: isFollowing ? DivineIconName.check : DivineIconName.plus,
      isLoading: isBusy,
      onPressed: isBusy ? null : onPressed,
    );
  }
}
