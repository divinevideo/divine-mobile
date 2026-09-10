// ABOUTME: Explains how Divine computes follower/following counts and what
// ABOUTME: blocking does, opened from Creator Analytics' Audience Snapshot card.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/external_link_launcher.dart';

const _linkTapSlack = 14.0;

/// Bottom sheet defining the follower count shown in Creator Analytics.
class SocialCountsInfoSheet extends StatelessWidget {
  @visibleForTesting
  const SocialCountsInfoSheet({super.key});

  static const _faqUrl = 'https://divine.video/faq#follower-counts';

  /// Opens the explanation over Creator Analytics.
  static Future<void> show(BuildContext context) {
    return VineBottomSheet.show<void>(
      context: context,
      contentTitle: context.l10n.analyticsSocialCountsInfoTitle,
      scrollable: false,
      isScrollControlled: true,
      body: const SingleChildScrollView(
        child: Padding(
          padding: EdgeInsets.fromLTRB(16, 8, 16, 24 - _linkTapSlack),
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
          l10n.analyticsFollowerCountsBody,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.onSurfaceVariant,
          ),
        ),
        const SizedBox(height: 12),
        Semantics(
          link: true,
          label: l10n.analyticsSocialCountsLearnMoreSemantics('divine.video'),
          child: GestureDetector(
            onTap: () => openExternalLink(context, _faqUrl),
            behavior: HitTestBehavior.opaque,
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: _linkTapSlack),
              child: ExcludeSemantics(
                child: Text(
                  l10n.analyticsSocialCountsLearnMore,
                  style: VineTheme.bodyMediumFont(
                    color: context.vineColors.primaryText,
                  ).copyWith(decoration: TextDecoration.underline),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
