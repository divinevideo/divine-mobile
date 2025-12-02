// ABOUTME: Displays horizontal scrollable list of trending hashtags
// ABOUTME: Extracted from ExploreScreen for reusability and testability

import 'package:flutter/material.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/theme/vine_theme.dart';

/// A section displaying trending hashtags in a horizontal scrollable list.
///
/// Shows a title "Trending Hashtags" followed by tappable hashtag chips.
/// Tapping a hashtag navigates to the hashtag feed.
class TrendingHashtagsSection extends StatelessWidget {
  const TrendingHashtagsSection({
    super.key,
    required this.hashtags,
    this.isLoading = false,
    this.onHashtagTap,
  });

  /// List of hashtag strings (without the # prefix)
  final List<String> hashtags;

  /// Whether hashtags are still loading
  final bool isLoading;

  /// Optional callback when a hashtag is tapped.
  /// If not provided, defaults to navigating via goHashtag.
  final void Function(String hashtag)? onHashtagTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Trending Hashtags',
              style: TextStyle(
                color: VineTheme.primaryText,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            height: 28,
            child: hashtags.isEmpty
                ? const _HashtagLoadingPlaceholder()
                : _HashtagChipList(
                    hashtags: hashtags,
                    onHashtagTap: onHashtagTap,
                  ),
          ),
        ],
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
        'Loading hashtags...',
        style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
      ),
    );
  }
}

/// Horizontal scrollable list of tappable hashtag chips.
class _HashtagChipList extends StatelessWidget {
  const _HashtagChipList({required this.hashtags, this.onHashtagTap});

  final List<String> hashtags;
  final void Function(String hashtag)? onHashtagTap;

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: hashtags.length,
      itemBuilder: (context, index) {
        final hashtag = hashtags[index];
        return _HashtagChip(
          hashtag: hashtag,
          onTap: () {
            if (onHashtagTap != null) {
              onHashtagTap!(hashtag);
            } else {
              context.goHashtag(hashtag);
            }
          },
        );
      },
    );
  }
}

/// Individual hashtag chip with tap behavior.
class _HashtagChip extends StatelessWidget {
  const _HashtagChip({required this.hashtag, required this.onTap});

  final String hashtag;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 12.8),
          decoration: BoxDecoration(
            color: VineTheme.cardBackground,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Center(
            child: Text(
              '#$hashtag',
              style: const TextStyle(
                color: VineTheme.vineGreen,
                fontSize: 14,
                fontWeight: FontWeight.w500,
                height: 1.0,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
