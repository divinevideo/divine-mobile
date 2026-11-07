// ABOUTME: Compact recognition that leads with one rotating real fact.
// ABOUTME: Records presentation only after a visible card has painted.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/features/creator_highlights/creator_highlight.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/notifications/widgets/notification_video_thumbnail.dart';
import 'package:visibility_detector/visibility_detector.dart';

class CreatorHighlightCard extends StatefulWidget {
  const CreatorHighlightCard({
    required this.highlight,
    required this.isVisible,
    required this.onPresented,
    required this.onAnalytics,
    required this.onWatch,
    super.key,
  });

  final CreatorHighlight highlight;
  final bool isVisible;
  final VoidCallback onPresented;
  final VoidCallback onAnalytics;
  final VoidCallback onWatch;

  @override
  State<CreatorHighlightCard> createState() => _CreatorHighlightCardState();
}

class _CreatorHighlightCardState extends State<CreatorHighlightCard> {
  String? _presented;
  String? _animationIdentity;
  bool _animate = false;
  bool _inViewport = false;
  Key _visibilityKey = UniqueKey();

  @override
  void didUpdateWidget(CreatorHighlightCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.isVisible != widget.isVisible ||
        oldWidget.highlight.owner != widget.highlight.owner ||
        oldWidget.highlight.localDate != widget.highlight.localDate) {
      // Reopening a retained scroll position needs fresh viewport evidence.
      _inViewport = false;
      _animate = false;
      _visibilityKey = UniqueKey();
    }
  }

  void _onVisibilityChanged(VisibilityInfo info) {
    if (!mounted || info.key != _visibilityKey) return;
    final inViewport = info.visibleFraction > 0;
    if (_inViewport != inViewport) {
      setState(() => _inViewport = inViewport);
    }
  }

  @override
  Widget build(BuildContext context) {
    final card = widget.highlight;
    // Each spotlight is its own showing, so advancing it re-arms presentation.
    final identity = '${card.owner}:${card.localDate}:${card.rotation}';
    final visible = widget.isVisible && _inViewport;
    if (visible && _presented != identity) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !widget.isVisible ||
            !_inViewport ||
            _presented == identity ||
            identity !=
                '${widget.highlight.owner}:${widget.highlight.localDate}:'
                    '${widget.highlight.rotation}') {
          return;
        }
        _presented = identity;
        widget.onPresented();
      });
    }
    final colors = context.vineColors;
    final l10n = context.l10n;
    if (visible && _animationIdentity != identity) {
      _animationIdentity = identity;
      _animate = card.celebrate;
    }
    // Consuming eligibility does not cancel an animation already in progress.
    final animate =
        _animationIdentity == identity &&
        _animate &&
        !MediaQuery.disableAnimationsOf(context);
    return VisibilityDetector(
      key: _visibilityKey,
      onVisibilityChanged: _onVisibilityChanged,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
        // The whole card opens stats across every video; only the thumbnail
        // opens the single video it shows.
        child: Semantics(
          container: true,
          button: true,
          child: Material(
            color: colors.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: colors.accentPositive),
            ),
            clipBehavior: Clip.antiAlias,
            child: InkWell(
              onTap: widget.onAnalytics,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  spacing: 10,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(
                          child: _Spotlight(
                            highlight: card,
                            animationKey: ValueKey((identity, animate)),
                            animate: animate,
                          ),
                        ),
                        if (card.spotlight == CreatorSpotlight.topVideo)
                          if (card.topVideo case final video?) ...[
                            const SizedBox(width: 12),
                            // Its own node, so the video stays reachable
                            // apart from the card's stats action.
                            Semantics(
                              container: true,
                              child: NotificationVideoThumbnail(
                                imageUrl: video.thumbnailUrl,
                                title: video.displayTitle,
                                onTap: widget.onWatch,
                              ),
                            ),
                          ],
                      ],
                    ),
                    Row(
                      mainAxisSize: MainAxisSize.min,
                      spacing: 4,
                      children: [
                        Flexible(
                          child: Text(
                            l10n.creatorHighlightAnalytics,
                            style: VineTheme.labelLargeFont(
                              color: colors.accentPositive,
                            ),
                          ),
                        ),
                        DivineIcon(
                          icon: DivineIconName.arrowRight,
                          size: 16,
                          color: colors.accentPositive,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Label, headline and supporting fact for the current spotlight.
class _Spotlight extends StatelessWidget {
  const _Spotlight({
    required this.highlight,
    required this.animationKey,
    required this.animate,
  });

  final CreatorHighlight highlight;
  final Key animationKey;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final colors = context.vineColors;
    final l10n = context.l10n;
    final card = highlight;
    final (headline, support) = switch (card.spotlight) {
      CreatorSpotlight.createdToday => (
        l10n.creatorHighlightCreatedToday(card.createdToday),
        l10n.creatorHighlightCreationDays(card.creationDaysThisWeek),
      ),
      CreatorSpotlight.topVideo => (
        l10n.creatorHighlightTopVideoViews(card.topVideoViews ?? 0),
        l10n.creatorHighlightTopVideo,
      ),
      CreatorSpotlight.weeklyViews => (
        l10n.creatorHighlightWeeklyViews(card.views ?? 0),
        null,
      ),
      CreatorSpotlight.weeklyLikes => (
        l10n.creatorHighlightWeeklyLikes(card.likes ?? 0),
        null,
      ),
      CreatorSpotlight.weeklyComments => (
        l10n.creatorHighlightWeeklyComments(card.comments ?? 0),
        null,
      ),
      CreatorSpotlight.creativeDays => (
        l10n.creatorHighlightCreationDays(card.creationDaysThisWeek),
        null,
      ),
    };
    final title = card.spotlight == CreatorSpotlight.topVideo
        ? card.topVideo?.displayTitle
        : null;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          spacing: 6,
          children: [
            TweenAnimationBuilder<double>(
              key: animationKey,
              tween: Tween(begin: animate ? 0.65 : 1, end: 1),
              duration: animate
                  ? const Duration(milliseconds: 450)
                  : Duration.zero,
              builder: (_, scale, child) =>
                  Transform.scale(scale: scale, child: child),
              child: DivineIcon(
                icon: DivineIconName.sparkle,
                size: 18,
                color: colors.accentPositive,
              ),
            ),
            Expanded(
              child: Text(
                l10n.creatorHighlightLabel,
                style: VineTheme.labelMediumFont(color: colors.accentPositive),
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Text(
          headline,
          style: VineTheme.titleMediumFont(color: colors.primaryText),
        ),
        if (title != null && title.trim().isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: VineTheme.bodyMediumFont(color: colors.primaryText),
          ),
        ],
        if (support != null) ...[
          const SizedBox(height: 2),
          Text(
            support,
            style: VineTheme.bodySmallFont(color: colors.secondaryText),
          ),
        ],
      ],
    );
  }
}
