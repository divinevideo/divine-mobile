// ABOUTME: Tags row for the metadata expanded sheet.
// ABOUTME: Displays category chips (accent-colored with emoji) and hashtag
// ABOUTME: chips (green "#" prefix) in a wrapping layout. Rendered inline
// ABOUTME: inside the header section right below the description, so the
// ABOUTME: surrounding container owns padding.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/utils/pause_aware_modals.dart';
import 'package:openvine/widgets/video_feed_item/metadata/metadata_categories_section.dart'
    show CategoryChip;

/// Tags section showing category chips and hashtag chips.
///
/// Category chips have accent-colored backgrounds with emoji. Hashtag chips
/// have a green "#" prefix. Classic Vine videos prepend a "classic" hashtag.
///
/// Rendered inline inside the metadata header section right below the
/// description, between the description and the stats row.
///
/// Returns [SizedBox.shrink] when the video has no tags and no categories.
///
/// Matches Figma node `15728:88010`.
class MetadataTagsSection extends StatelessWidget {
  const MetadataTagsSection({required this.video, super.key});

  final VideoEvent video;

  @override
  Widget build(BuildContext context) {
    final allHashtags = video.allHashtags;
    final hasCategories = video.categories.isNotEmpty;
    final hasHashtags = allHashtags.isNotEmpty;

    if (!hasCategories && !hasHashtags) return const SizedBox.shrink();

    // ⚠ LOAD-BEARING: this Wrap's `runSpacing` MUST stay at the default
    // (0). Three load-bearing constants in three files conspire to keep
    // the visible chip 40 dp tall (Figma) while giving each chip a
    // 48 dp tap target (WCAG):
    //
    //   1. `_HashtagChip` (below): wraps the chip in `Padding(vertical: 4)`
    //      inside its GestureDetector so the tap target = 4 + 40 + 4 = 48.
    //   2. This Wrap: `runSpacing = 0`. Adjacent chips' 4 + 4 invisible
    //      padding produces the visible 8 px row gap; raising runSpacing
    //      double-counts and adds extra visible space.
    //   3. `_OverviewSection` (`metadata_expanded_sheet.dart`): bottom
    //      padding drops from 20 → 16 when `hasTags`, and the spacer
    //      before the wrap is 12 (not 16), to absorb the chips' 4 px
    //      invisible padding above and below the row.
    //
    // Locked in by `hashtag chip tap target meets the 48 dp WCAG
    // minimum` + `hashtag chip Wrap uses runSpacing 0` in
    // `metadata_expanded_sheet_test.dart`. If you must tweak any of
    // these, update all three and rerun those tests.
    return Wrap(
      spacing: 8,
      children: [
        for (var i = 0; i < video.categories.length; i++)
          CategoryChip(categoryName: video.categories[i], index: i),
        for (final tag in allHashtags) _HashtagChip(tag: tag),
      ],
    );
  }
}

/// A single tappable hashtag chip with green "#" prefix and bold tag name.
///
/// Tapping dismisses the metadata sheet and pushes the hashtag feed for
/// [tag], matching the behaviour of hashtag chips elsewhere in the app
/// (trending row, search results, linkified text).
class _HashtagChip extends StatelessWidget {
  const _HashtagChip({required this.tag});

  final String tag;

  @override
  Widget build(BuildContext context) {
    final chip = Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      decoration: BoxDecoration(
        color: context.vineColors.surfaceContainer,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 4,
        children: [
          Text(
            '#',
            style: VineTheme.bodyLargeFont(
              color: context.vineColors.accentPositive,
            ),
          ),
          Flexible(
            child: Text(
              tag,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: VineTheme.titleSmallFont(
                color: context.vineColors.primaryText,
              ),
            ),
          ),
        ],
      ),
    );

    return Semantics(
      button: true,
      label: context.l10n.metadataHashtagChipTapHint(tag),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _navigateToHashtag(context),
        // ⚠ LOAD-BEARING: this 4 px is one of three constants that
        // conspire to keep the visible chip 40 dp tall (Figma) while
        // giving every chip a 48 dp tap target (WCAG). See the full
        // dependency map in `MetadataTagsSection.build` above —
        // tweaking this number requires updating `Wrap.runSpacing`
        // there and the `hasTags`-conditional bottom padding +
        // pre-tag spacer in `_OverviewSection`
        // (`metadata_expanded_sheet.dart`).
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: chip,
        ),
      ),
    );
  }

  void _navigateToHashtag(BuildContext context) {
    // Dismiss the metadata sheet first, then navigate from the root
    // navigator. GoRouter extensions throw when called from inside a modal
    // bottom sheet (the router is not in the modal's widget tree).
    // Mirrors the pattern used by user-chip taps in metadata_user_chips.dart.
    final hostContext = Navigator.of(context, rootNavigator: true).context;
    Navigator.of(context).pop();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!hostContext.mounted) return;
      hostContext.pushWithVideoPause(HashtagScreenRouter.pathForTag(tag));
    });
  }
}
