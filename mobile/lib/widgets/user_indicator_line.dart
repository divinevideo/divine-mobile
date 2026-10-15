// ABOUTME: Shared, facts-only account metadata for vertical people rows.
// ABOUTME: Recent posts make a positive claim only within seven days.

import 'package:clock/clock.dart';
import 'package:count_formatter/count_formatter.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/l10n/localized_time_formatter.dart';

const _recentPostWindow = Duration(days: 7);

/// Existing account identity and cached activity, without fetching any data.
class UserIndicatorLine extends StatelessWidget {
  const UserIndicatorLine({
    required this.now,
    this.identifier,
    this.relationship = FollowRelationship.none,
    this.isOgViner = false,
    this.videoCount,
    this.lastPostedAt,
    this.style,
    super.key,
  });

  final String? identifier;
  final FollowRelationship relationship;
  final bool isOgViner;
  final int? videoCount;
  final DateTime? lastPostedAt;
  final DateTime now;
  final TextStyle? style;

  bool get _hasRecentPost =>
      lastPostedAt != null && now.difference(lastPostedAt!) < _recentPostWindow;

  /// Lets a parent omit the entire child, including inter-child spacing.
  bool get hasContent =>
      identifier?.isNotEmpty == true ||
      relationship != FollowRelationship.none ||
      isOgViner ||
      (videoCount != null && videoCount! > 0) ||
      _hasRecentPost;

  @override
  Widget build(BuildContext context) {
    if (!hasContent) return const SizedBox.shrink();
    final l10n = context.l10n;
    final locale = Localizations.localeOf(context).toLanguageTag();
    final relationshipLabel = switch (relationship) {
      FollowRelationship.mutual => l10n.socialProofMutual,
      FollowRelationship.followsYou => l10n.socialProofFollowsYou,
      FollowRelationship.youFollow => l10n.socialProofYouFollow,
      FollowRelationship.none => null,
    };
    final count = videoCount;
    final posted = lastPostedAt;
    final parts = [
      ?relationshipLabel,
      if (identifier?.isNotEmpty == true) identifier!,
      if (isOgViner) l10n.ogVinerBadgeLabel,
      if (count != null && count > 0)
        l10n.searchUserVideoCount(
          count,
          CountFormatter.formatCompact(count, locale: locale),
        ),
      if (posted != null && _hasRecentPost)
        l10n.userRowPosted(
          withClock(
            Clock.fixed(now),
            () => LocalizedTimeFormatter.formatRelativeVerbose(
              l10n,
              posted.millisecondsSinceEpoch ~/ 1000,
            ),
          ),
        ),
    ];
    return Text(
      parts.join(' · '),
      style:
          style ??
          VineTheme.bodySmallFont(color: context.vineColors.onSurfaceVariant),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }
}
