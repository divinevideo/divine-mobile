// ABOUTME: Shared localized labels for canonical Explore tab names.
// ABOUTME: Keeps tab bar and feed-mode shell titles in sync.

import 'package:characters/characters.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:openvine/blocs/explore_tabs/explore_tabs_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';

/// Longest server-supplied string the tab bar will render.
///
/// Applies to the sponsor name and, through [featuredTabPillMaxLength], the
/// collection pill. Both are authored outside this repo, so both are treated
/// as untrusted for layout purposes and clamped before they reach the bar.
const featuredTabLabelMaxLength = 24;

/// Longest collection-name pill the tab bar will render beside the label.
///
/// Shorter than the label's own limit because the pill is laid out *next to*
/// "Featured" on a scrollable bar: at 24 characters the pill runs past the
/// right edge of a 390 px screen, so the tab opens partly off-screen.
const featuredTabPillMaxLength = 16;

/// Returns the localized display label for an Explore tab [name].
///
/// The shell uses a little more context for video mode ("New Videos",
/// "Trending") while the tab bar keeps the shorter tab copy ("New", "Popular").
///
/// The featured tab reads "Featured" like any other tab. The server sends a
/// label too, but it is now pinned to that one word rather than being
/// editorial, so translating it here reaches every locale where echoing the
/// server's copy would have shipped English to all of them. The collection's
/// own name is the pill beside it.
String labelForExploreTabName(
  AppLocalizations l10n,
  String name, {
  bool shellTitle = false,
}) => switch (name) {
  exploreFeaturedTabName => l10n.exploreTabFeatured,
  exploreClassicsTabName =>
    shellTitle ? l10n.navExploreClassics : l10n.exploreTabClassics,
  exploreDefaultTabName =>
    shellTitle ? l10n.navExploreNewVideos : l10n.exploreTabNew,
  explorePopularTabName =>
    shellTitle ? l10n.navExploreTrending : l10n.exploreTabPopular,
  exploreCategoriesTabName => l10n.exploreTabCategories,
  exploreForYouTabName =>
    shellTitle ? l10n.navExploreForYou : l10n.exploreTabForYou,
  exploreListsTabName =>
    shellTitle ? l10n.navExploreLists : l10n.exploreTabLists,
  exploreBadgesTabName => l10n.badgesTitle,
  exploreAppsTabName => l10n.exploreTabIntegratedApps,
  _ => l10n.navExplore,
};

/// Collapses and clamps a server-supplied string bound for the tab bar.
///
/// Length alone does not bound a tab: `Tab` lays out at a fixed height, so a
/// label carrying newlines paints extra lines into a box that cannot grow, and
/// bidi overrides reorder glyphs across the whole bar. Neither is caught by a
/// grapheme count. Both fields on a featured tab are editorial copy authored
/// outside this repo, so both go through here.
///
/// Returns an empty string when nothing renderable survives.
String sanitizeFeaturedTabText(
  String raw, {
  int maxLength = featuredTabLabelMaxLength,
}) {
  final collapsed = raw
      .replaceAll(_featuredTabControlCharacters, ' ')
      .replaceAll(_repeatedWhitespace, ' ')
      .trim();
  if (collapsed.isEmpty) return '';
  final characters = collapsed.characters;
  if (characters.length <= maxLength) return collapsed;
  return '${characters.take(maxLength - 1).toString().trimRight()}…';
}

/// C0/C1 controls, line/paragraph separators, and bidi formatting overrides.
final _featuredTabControlCharacters = RegExp(
  '[\u0000-\u001f\u007f-\u009f\u2028\u2029'
  '\u200e\u200f\u202a-\u202e\u2066-\u2069]',
);

final _repeatedWhitespace = RegExp(r'\s+');

/// The sanitised sponsor name for [config] in [localeCode], or `null` when
/// this locale has no sponsor to disclose.
///
/// Both the partnership line and the pill's sponsored state resolve through
/// here, so the pill can never announce a sponsor the grid never names: a
/// map whose only entries resolve for other locales, or a value that is
/// nothing but control characters, means no sponsor for this viewer.
String? featuredTabSponsorName(
  FeaturedTabConfig config,
  String? localeCode,
) {
  final raw = config.sponsorNameFor(localeCode);
  if (raw == null) return null;
  final sanitized = sanitizeFeaturedTabText(raw);
  return sanitized.isEmpty ? null : sanitized;
}

/// Whether the featured tab presents as sponsored for [localeCode].
///
/// Derived from [featuredTabSponsorName] rather than the raw field so the
/// pill's colour and spoken label agree with the partnership line above the
/// grid in every locale.
bool featuredTabIsSponsored(FeaturedTabConfig config, String? localeCode) =>
    featuredTabSponsorName(config, localeCode) != null;
