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

/// How far each card overlaps the one behind it.
const _cardOverlap = 60.0;

/// Border width around each portrait card.
const _cardBorder = 2.0;

/// Corner radius for each portrait card.
const _cardRadius = 16.0;

/// Portrait aspect ratio (width:height = 3:4, from Figma 177:236).
const double _cardAspectRatio = 3 / 4;

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
            ListCardTitle(title: curatedList.name),
            if (curatedList.description != null &&
                curatedList.description!.isNotEmpty) ...[
              const SizedBox(height: 2),
              ListCardDescription(description: curatedList.description!),
            ],
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
    return LayoutBuilder(
      builder: (context, constraints) {
        final totalWidth = constraints.maxWidth;
        final cardWidth =
            (totalWidth + _cardOverlap * (_thumbnailSlotCount - 1)) /
            _thumbnailSlotCount;
        final cardHeight = cardWidth / _cardAspectRatio;

        return SizedBox(
          height: cardHeight,
          child: Stack(
            children: [
              // Cards in reverse order so index 0 is on top.
              for (int i = _thumbnailSlotCount - 1; i >= 0; i--)
                Positioned(
                  left: i * (cardWidth - _cardOverlap),
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
          ),
        );
      },
    );
  }
}

/// A single portrait card with a border and optional image.
class _ThumbnailCard extends StatelessWidget {
  const _ThumbnailCard({this.imageUrl});

  final String? imageUrl;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        border: Border.all(
          width: _cardBorder,
          color: context.vineColors.surface,
        ),
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
    );
  }
}
