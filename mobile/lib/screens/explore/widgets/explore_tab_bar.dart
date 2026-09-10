// ABOUTME: Scrollable explore tab bar with a right-edge fade gradient.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/blocs/explore_tabs/explore_tabs_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/explore/explore_tab_labels.dart';
import 'package:pointer_interceptor/pointer_interceptor.dart';

/// The explore screen's scrollable tab bar.
///
/// Tab labels are derived from [tabsState] so the visible set matches the
/// [controller]'s tab count. [onTap] receives the tapped index.
class ExploreTabBar extends StatelessWidget {
  /// Creates the explore tab bar.
  const ExploreTabBar({
    required this.controller,
    required this.tabsState,
    required this.onTap,
    super.key,
  });

  /// Controller driving tab selection; must match [tabsState.tabCount].
  final TabController controller;

  /// Current tab availability/order.
  final ExploreTabsState tabsState;

  /// Called with the tapped tab index.
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) {
    // Material is required for TabBar ink splashes; PointerInterceptor ensures
    // tabs receive taps on web.
    return PointerInterceptor(
      intercepting: kIsWeb,
      child: Material(
        color: VineTheme.transparent,
        child: Stack(
          children: [
            TabBar(
              controller: controller,
              isScrollable: true,
              tabAlignment: TabAlignment.start,
              padding: const EdgeInsetsDirectional.only(start: 16),
              indicatorColor: VineTheme.tabIndicatorGreen,
              indicatorWeight: 4,
              indicatorSize: TabBarIndicatorSize.tab,
              dividerColor: VineTheme.transparent,
              labelColor: context.vineColors.primaryText,
              unselectedLabelColor: context.vineColors.onSurfaceMuted,
              labelPadding: const EdgeInsets.symmetric(horizontal: 14),
              labelStyle: VineTheme.titleMediumFont(
                color: context.vineColors.primaryText,
              ),
              unselectedLabelStyle: VineTheme.titleMediumFont(
                color: context.vineColors.onSurfaceMuted,
              ),
              onTap: onTap,
              tabs: [
                for (final name in tabsState.tabNames)
                  Tab(
                    child: _ExploreTabLabel(
                      name: name,
                      featuredTab: tabsState.featuredTab,
                    ),
                  ),
              ],
            ),
            // Right-edge fade gradient shim
            Positioned(
              top: 0,
              bottom: 0,
              right: 0,
              width: 24,
              child: IgnorePointer(
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      begin: Alignment.centerRight,
                      end: Alignment.centerLeft,
                      // Both stops are the same surface at different alpha.
                      // Fading to a hardcoded transparent *black* instead
                      // muddies the midpoint once the surface is light.
                      colors: [
                        context.vineColors.surfaceContainerHigh,
                        context.vineColors.surfaceContainerHigh.withValues(
                          alpha: 0,
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One tab's label, with the featured tab's optional collection pill.
///
/// The featured tab itself always reads "Featured"; the collection's own name
/// rides beside it in a pill whose colour carries the sponsorship state.
class _ExploreTabLabel extends StatelessWidget {
  const _ExploreTabLabel({required this.name, this.featuredTab});

  final String name;
  final FeaturedTabConfig? featuredTab;

  @override
  Widget build(BuildContext context) {
    final l10n = context.l10n;
    final label = labelForExploreTabName(l10n, name);
    final featured = featuredTab;
    if (name != exploreFeaturedTabName || featured == null) {
      return Text(label);
    }

    // Same untrusted-input path as the label beside it, so same treatment,
    // against a tighter budget because the pill shares the tab's width.
    final rawPill = featured.pillLabelFor(l10n.localeName);
    final pill = rawPill == null
        ? null
        : sanitizeFeaturedTabText(rawPill, maxLength: featuredTabPillMaxLength);
    if (pill == null || pill.isEmpty) return Text(label);

    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        Text(label),
        _FeaturedTabPill(
          text: pill,
          isSponsored: featuredTabIsSponsored(featured, l10n.localeName),
        ),
      ],
    );
  }
}

/// The collection-name pill beside the featured tab's label.
///
/// Yellow normally, pink when sponsored. The colour is a secondary cue only —
/// it is unreliable for anyone with a colour vision deficiency, and yellow
/// against pink is a hard pair — so the state is also spoken here and written
/// out in full by the partnership line above the grid.
class _FeaturedTabPill extends StatelessWidget {
  const _FeaturedTabPill({required this.text, required this.isSponsored});

  final String text;
  final bool isSponsored;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final chip = isSponsored ? colors.accentChipPink : colors.accentChipYellow;

    return Semantics(
      label: isSponsored
          ? context.l10n.exploreFeaturedSponsoredPillSemanticLabel(text)
          : text,
      excludeSemantics: true,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: chip.container,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
          child: Text(
            text,
            style: VineTheme.labelSmallFont(color: chip.onContainer),
          ),
        ),
      ),
    );
  }
}
