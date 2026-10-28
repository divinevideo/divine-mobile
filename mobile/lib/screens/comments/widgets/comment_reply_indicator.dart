// ABOUTME: "Re: {display_name}" line naming who a comment answered.
// ABOUTME: Shared by the comments sheet and the feed's reactions overlay.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' show UserProfile;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';

/// Shows "Re: {display_name}" for the author a comment replied to.
///
/// Fetches [parentAuthorPubkey]'s profile and renders their name in a mention
/// chip. The chip takes the app surface's container colour unless
/// [chipColor] fixes it, as a surface drawn over video does.
class CommentReplyIndicator extends ConsumerWidget {
  const CommentReplyIndicator({
    required this.parentAuthorPubkey,
    this.chipColor,
    super.key,
  });

  final String parentAuthorPubkey;

  /// Background of the name chip. Defaults to the adaptive `containerLow`.
  final Color? chipColor;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref
        .watch(userProfileReactiveProvider(parentAuthorPubkey))
        .value;

    // bestDisplayName is the same displayName -> name chain, but sanitized:
    // a lone UTF-16 surrogate in either field crashes the paragraph builder
    // when this renders.
    final displayName =
        profile?.bestDisplayName ??
        UserProfile.generatedNameFor(parentAuthorPubkey);

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          context.l10n.commentReplyToPrefix,
          style: VineTheme.bodySmallFont(color: VineTheme.tabIndicatorGreen),
        ),
        const SizedBox(width: 4),
        Flexible(
          child: Container(
            decoration: BoxDecoration(
              color: chipColor ?? context.vineColors.containerLow,
              borderRadius: BorderRadius.circular(8),
            ),
            padding: const EdgeInsets.symmetric(vertical: 2, horizontal: 4),
            child: Text(
              displayName,
              style: VineTheme.bodySmallFont(
                color: VineTheme.tabIndicatorGreen,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ),
      ],
    );
  }
}
