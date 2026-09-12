// ABOUTME: Displays horizontal scrollable list of trending hashtags
// ABOUTME: Extracted from ExploreScreen for reusability and testability

import 'package:divine_ui/divine_ui.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/constants/text_scale_limits.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';

/// A section displaying trending hashtags in a horizontal scrollable list.
///
/// Shows a title "Trending Hashtags" followed by tappable hashtag chips.
/// Tapping a hashtag navigates to the hashtag feed.
class TrendingHashtagsSection extends StatelessWidget {
  const TrendingHashtagsSection({
    required this.hashtags,
    super.key,
    this.isLoading = false,
    this.leading,
    this.onHashtagTap,
  });

  /// List of hashtag strings (without the # prefix)
  final List<String> hashtags;

  /// Whether hashtags are still loading
  final bool isLoading;

  /// Optional fixed control rendered to the left of the scrolling hashtags.
  final Widget? leading;

  /// Optional callback when a hashtag is tapped.
  /// If not provided, defaults to navigating via goHashtag.
  final void Function(String hashtag)? onHashtagTap;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.vineColors.background,
      child: SizedBox(
        height: 52,
        child: MediaQuery.withClampedTextScaling(
          maxScaleFactor: fixedRowTextScaleLimit,
          child: Row(
            children: [
              if (leading != null)
                Padding(
                  padding: const EdgeInsetsDirectional.only(start: 12, end: 6),
                  child: Center(child: leading),
                ),
              Expanded(
                child: hashtags.isEmpty
                    ? const _HashtagLoadingPlaceholder()
                    : _HashtagChipList(
                        hashtags: hashtags,
                        leadingInset: leading == null ? 16 : 0,
                        onHashtagTap: onHashtagTap,
                      ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Loading placeholder shown when hashtags are not yet available.
class _HashtagLoadingPlaceholder extends StatelessWidget {
  const _HashtagLoadingPlaceholder();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Text(
        context.l10n.trendingHashtagsLoading,
        style: TextStyle(color: context.vineColors.secondaryText, fontSize: 14),
      ),
    );
  }
}

/// Horizontal scrollable list of tappable hashtag chips.
class _HashtagChipList extends StatelessWidget {
  const _HashtagChipList({
    required this.hashtags,
    required this.leadingInset,
    this.onHashtagTap,
  });

  final List<String> hashtags;
  final double leadingInset;
  final void Function(String hashtag)? onHashtagTap;

  @override
  Widget build(BuildContext context) {
    final textScaler = MediaQuery.textScalerOf(
      context,
    ).clamp(maxScaleFactor: 1.5);
    return MediaQuery(
      data: MediaQuery.of(context).copyWith(textScaler: textScaler),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        padding: EdgeInsets.only(
          left: leadingInset,
          right: 16,
          top: 12,
          bottom: 12,
        ),
        itemCount: hashtags.length + 1,
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsetsDirectional.only(end: 10),
              child: Center(
                child: Text(
                  context.l10n.trendingTitle,
                  style: VineTheme.titleSmallFont(
                    color: context.vineColors.primaryText,
                  ),
                ),
              ),
            );
          }
          final hashtag = hashtags[index - 1];
          return _HashtagChip(
            hashtag: hashtag,
            colorIndex: index - 1,
            onTap: () {
              if (onHashtagTap != null) {
                onHashtagTap!(hashtag);
              } else {
                context.push(HashtagScreenRouter.pathForTag(hashtag));
              }
            },
          );
        },
      ),
    );
  }
}

/// Accent colors used for hashtag chip backgrounds.
const List<Color> _accentColors = [
  VineTheme.accentYellow,
  VineTheme.accentLime,
  VineTheme.accentPink,
  VineTheme.accentOrange,
  VineTheme.accentViolet,
  VineTheme.accentPurple,
  VineTheme.accentBlue,
];

/// Individual hashtag chip with tap behavior.
class _HashtagChip extends StatelessWidget {
  const _HashtagChip({
    required this.hashtag,
    required this.onTap,
    required this.colorIndex,
  });

  final String hashtag;
  final VoidCallback onTap;
  final int colorIndex;

  @override
  Widget build(BuildContext context) {
    final color = _accentColors[colorIndex % _accentColors.length];

    return Padding(
      padding: const EdgeInsetsDirectional.only(end: 8),
      child: Semantics(
        label: context.l10n.trendingHashtagsViewVideosTagged(hashtag),
        button: true,
        child: GestureDetector(
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12.8),
            decoration: BoxDecoration(
              color: color,
              borderRadius: BorderRadius.circular(20),
            ),
            child: Center(
              child: Text(
                '#$hashtag',
                style: VineTheme.titleSmallFont(
                  color: VineTheme.primaryDarkGreen,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
