// ABOUTME: Card widget for displaying curated video list search results.
// ABOUTME: Shows stacked video thumbnails with a count badge,
// ABOUTME: plus title and description below. Designed for 2-column grid layout.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:models/models.dart' hide AspectRatio;
import 'package:openvine/widgets/list_card_parts.dart';
import 'package:openvine/widgets/video_thumbnail_widget.dart';

/// Number of portrait card slots to display.
const _thumbnailSlotCount = 5;

/// Border width around each portrait card.
const _cardBorder = 2.0;

/// Corner radius of the media block and each portrait card.
const _cardRadius = 16.0;

/// Media block aspect ratio (from Figma 177:120, shared with the people
/// card so equal-width cards come out equal-height).
const double _mediaAspectRatio = 177 / 120;

/// Portrait slot aspect ratio (width:height, from Figma 177:236).
const double _slotAspectRatio = 177 / 236;

/// Search card for a curated video list (kind 30005).
///
/// Shows stacked video thumbnails with a count badge,
/// plus title and description below. Designed for 2-column grid layout.
class CuratedListSearchCard extends StatelessWidget {
  const CuratedListSearchCard({
    required this.curatedList,
    required this.onTap,
    super.key,
  });

  final CuratedList curatedList;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: curatedList.name,
      container: true,
      child: GestureDetector(
        onTap: onTap,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            _StackedThumbnails(
              thumbnailUrls: curatedList.thumbnailUrls,
              videoCount: curatedList.videoEventIds.length,
            ),
            const SizedBox(height: 8),
            ListCardFooter(
              title: curatedList.name,
              description: curatedList.description,
            ),
          ],
        ),
      ),
    );
  }
}

/// Overlapping portrait cards arranged left-to-right.
///
/// Renders [_thumbnailSlotCount] cards where the leftmost card has the
/// highest z-index. Cards with a resolved thumbnail URL show the image;
/// the rest are colored placeholders.
class _StackedThumbnails extends StatelessWidget {
  const _StackedThumbnails({
    required this.thumbnailUrls,
    required this.videoCount,
  });

  final List<String> thumbnailUrls;
  final int videoCount;

  String? _urlAt(int index) =>
      index < thumbnailUrls.length ? thumbnailUrls[index] : null;

  @override
  Widget build(BuildContext context) {
    return AspectRatio(
      aspectRatio: _mediaAspectRatio,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(_cardRadius),
        child: LayoutBuilder(
          builder: (context, constraints) {
            final totalWidth = constraints.maxWidth;
            final cardHeight = constraints.maxHeight;
            final cardWidth = cardHeight * _slotAspectRatio;
            // The five slots fan out to fill the media box edge to edge.
            final step = (totalWidth - cardWidth) / (_thumbnailSlotCount - 1);

            return Stack(
              children: [
                // Cards in reverse order so index 0 is on top.
                for (int i = _thumbnailSlotCount - 1; i >= 0; i--)
                  Positioned(
                    left: i * step,
                    top: 0,
                    width: cardWidth,
                    height: cardHeight,
                    child: _ThumbnailCard(imageUrl: _urlAt(i)),
                  ),
                Positioned(
                  left: 8,
                  bottom: 9,
                  child: ListCardBadge(
                    icon: DivineIconName.play,
                    count: videoCount,
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

/// A single portrait card with a border and optional image.
class _ThumbnailCard extends StatelessWidget {
  const _ThumbnailCard({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    // Foreground border, or the full-bleed thumbnail paints over it and
    // only the empty placeholder cards show their seams.
    return DecoratedBox(
      position: DecorationPosition.foreground,
      decoration: BoxDecoration(
        border: Border.all(
          width: _cardBorder,
          color: context.vineColors.surfaceContainerHigh,
        ),
        borderRadius: BorderRadius.circular(_cardRadius),
      ),
      child: DecoratedBox(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(_cardRadius),
          color: context.vineColors.containerLow,
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(_cardRadius),
          child: imageUrl != null
              ? PassiveAuthThumbnailImage(
                  url: imageUrl!,
                  alignment: Alignment.center,
                  errorWidget: (_, _, _) => const SizedBox(),
                  logName: 'CuratedListSearchCard',
                  logPrefix: 'List thumbnail',
                )
              : const SizedBox(),
        ),
      ),
    );
  }
}
