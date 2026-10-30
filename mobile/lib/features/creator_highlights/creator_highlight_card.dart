// ABOUTME: Adaptive, accessible recognition with real video and creation actions.
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
    required this.onCreate,
    required this.onAnalytics,
    required this.onWatch,
    super.key,
  });

  final CreatorHighlight highlight;
  final bool isVisible;
  final VoidCallback onPresented;
  final VoidCallback onCreate;
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
    final identity = '${card.owner}:${card.localDate}';
    final visible = widget.isVisible && _inViewport;
    if (visible && _presented != identity) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted ||
            !widget.isVisible ||
            !_inViewport ||
            _presented == identity ||
            identity !=
                '${widget.highlight.owner}:${widget.highlight.localDate}') {
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
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.card,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: colors.accentPositive),
          ),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    TweenAnimationBuilder<double>(
                      key: ValueKey((identity, animate)),
                      tween: Tween(begin: animate ? 0.65 : 1, end: 1),
                      duration: animate
                          ? const Duration(milliseconds: 450)
                          : Duration.zero,
                      builder: (_, scale, child) =>
                          Transform.scale(scale: scale, child: child),
                      child: DivineIcon(
                        icon: DivineIconName.sparkle,
                        size: 28,
                        color: colors.accentPositive,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        l10n.creatorHighlightLabel,
                        style: VineTheme.labelLargeFont(
                          color: colors.accentPositive,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),
                Text(
                  card.createdToday > 0
                      ? l10n.creatorHighlightCreatedToday(card.createdToday)
                      : l10n.creatorHighlightWeekTitle,
                  style: VineTheme.titleLargeFont(color: colors.primaryText),
                ),
                const SizedBox(height: 8),
                Text(
                  l10n.creatorHighlightCreationDays(card.creationDaysThisWeek),
                  style: VineTheme.bodyMediumFont(color: colors.secondaryText),
                ),
                if (card.views case final views?) ...[
                  const SizedBox(height: 8),
                  Text(
                    l10n.creatorHighlightWeeklyViews(views),
                    style: VineTheme.bodyMediumFont(
                      color: colors.secondaryText,
                    ),
                  ),
                ],
                if (card.topVideo case final video?) ...[
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      NotificationVideoThumbnail(
                        imageUrl: video.thumbnailUrl,
                        title: video.title,
                        onTap: widget.onWatch,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              l10n.creatorHighlightTopVideo,
                              style: VineTheme.labelLargeFont(
                                color: colors.primaryText,
                              ),
                            ),
                            if (video.title case final title?)
                              Text(
                                title,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: VineTheme.bodyMediumFont(
                                  color: colors.secondaryText,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  DivineButton(
                    label: l10n.creatorHighlightWatch,
                    type: DivineButtonType.quiet,
                    onPressed: widget.onWatch,
                  ),
                ],
                const SizedBox(height: 12),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    DivineButton(
                      label: l10n.creatorHighlightCreate,
                      leadingIcon: DivineIconName.camera,
                      onPressed: widget.onCreate,
                    ),
                    DivineButton(
                      label: l10n.creatorHighlightAnalytics,
                      type: DivineButtonType.quiet,
                      onPressed: widget.onAnalytics,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
