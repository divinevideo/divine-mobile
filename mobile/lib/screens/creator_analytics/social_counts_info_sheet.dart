// ABOUTME: Explains how Divine computes follower/following counts and what
// ABOUTME: blocking does, opened from Creator Analytics' Audience Snapshot card.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';

/// Bottom sheet explaining social-count calculation and blocking.
///
/// Follower totals deliberately exclude blocked accounts and can differ across
/// Nostr clients (indexing differences); the raw numbers on the Audience
/// Snapshot card don't convey that, so this supplies the explanation. #8276.
class SocialCountsInfoSheet extends StatelessWidget {
  @visibleForTesting
  const SocialCountsInfoSheet({super.key});

  /// Opens the explanation over Creator Analytics.
  static Future<void> show(BuildContext context) {
    return VineBottomSheet.show<void>(
      context: context,
      contentTitle: context.l10n.analyticsSocialCountsInfoTitle,
      scrollable: false,
      isScrollControlled: true,
      body: const SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 24),
          child: SocialCountsInfoSheet(),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          l10n.analyticsFollowerCountsHeading,
          style: VineTheme.titleSmallFont(
            color: context.vineColors.primaryText,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.analyticsFollowerCountsBody,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 20),
        Text(
          l10n.analyticsBlockingHeading,
          style: VineTheme.titleSmallFont(
            color: context.vineColors.primaryText,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          l10n.analyticsBlockingBody,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.onSurfaceVariant,
          ),
        ),
      ],
    );
  }
}
