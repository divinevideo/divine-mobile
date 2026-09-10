// ABOUTME: Profile support affordance sheet for outbound monetization links.
// ABOUTME: Groups one-time tips separately from subscription/support links.

import 'package:analytics/analytics.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/features/monetization/monetization_analytics.dart';
import 'package:openvine/features/monetization/monetization_storefront_policy.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/utils/external_link_launcher.dart';

Future<void> showProfileSupportSheet({
  required BuildContext context,
  required List<MonetizationLink> links,
  required AnalyticsEventSink analytics,
}) {
  final appStoreTipPolicy = usesAppleAppStoreTipPolicy;
  final visibleLinks = monetizationLinksForCurrentStorefront(links);
  final tipLinks = visibleLinks
      .where((link) => link.category == MonetizationLinkCategory.tip)
      .toList(growable: false);
  final subscriptionLinks = visibleLinks
      .where((link) => link.category == MonetizationLinkCategory.subscription)
      .toList(growable: false);

  return VineBottomSheet.show<void>(
    context: context,
    scrollable: false,
    expanded: false,
    contentTitle: appStoreTipPolicy
        ? context.l10n.profileTipSheetTitle
        : context.l10n.profileSupportSheetTitle,
    children: [
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        child: Text(
          appStoreTipPolicy
              ? context.l10n.profileTipSheetBody
              : context.l10n.profileSupportSheetBody,
          style: VineTheme.bodyMediumFont(
            color: context.vineColors.onSurfaceVariant,
          ),
        ),
      ),
      if (tipLinks.isNotEmpty)
        _SupportLinkGroup(
          title: context.l10n.profileSupportTipSection,
          links: tipLinks,
          analytics: analytics,
        ),
      if (subscriptionLinks.isNotEmpty)
        _SupportLinkGroup(
          title: context.l10n.profileSupportSubscriptionSection,
          links: subscriptionLinks,
          analytics: analytics,
        ),
      const SizedBox(height: 8),
    ],
  );
}

class _SupportLinkGroup extends StatelessWidget {
  const _SupportLinkGroup({
    required this.title,
    required this.links,
    required this.analytics,
  });

  final String title;
  final List<MonetizationLink> links;
  final AnalyticsEventSink analytics;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            title.toUpperCase(),
            style: VineTheme.labelSmallFont(
              color: context.vineColors.onSurfaceVariant,
            ),
          ),
        ),
        for (final link in links)
          _SupportLinkTile(link: link, analytics: analytics),
      ],
    );
  }
}

class _SupportLinkTile extends StatelessWidget {
  const _SupportLinkTile({required this.link, required this.analytics});

  final MonetizationLink link;
  final AnalyticsEventSink analytics;

  @override
  Widget build(BuildContext context) {
    return Material(
      type: MaterialType.transparency,
      child: ListTile(
        minTileHeight: 56,
        leading: DivineIcon(
          icon: DivineIconName.linkSimple,
          color: context.vineColors.accentPositive,
        ),
        title: Text(
          link.provider.displayName,
          style: VineTheme.titleMediumFont(
            color: context.vineColors.primaryText,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        trailing: DivineIcon(
          icon: DivineIconName.arrowUpRight,
          color: context.vineColors.onSurfaceVariant,
          size: 20,
        ),
        onTap: () async {
          trackMonetizationOutboundClicked(analytics: analytics, link: link);
          await openExternalLink(context, link.url);
          if (context.mounted) Navigator.of(context).pop();
        },
      ),
    );
  }
}
