// ABOUTME: Horizontal row of circular content actions for a video.
// ABOUTME: Shared by the share sheet and the video info sheet.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:material_ui/material_ui.dart';
import 'package:visibility_detector/visibility_detector.dart';

/// One tappable entry in a [VideoActionRow].
class VideoActionRowItem {
  const VideoActionRowItem({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPending = false,
    this.isDisabled = false,
    this.onShown,
  });

  final DivineIconName icon;
  final String label;
  final VoidCallback onTap;

  /// Called on each visibility change while any part of the item is
  /// visible; callers that log an exposure dedupe it themselves.
  final VoidCallback? onShown;

  /// Whether the action is mid-flight, so the circle shows a spinner and stops
  /// responding to taps.
  final bool isPending;

  /// Whether another operation temporarily prevents this action.
  final bool isDisabled;
}

/// A horizontally scrolling row of [VideoActionRowItem]s with an optional
/// heading above it.
class VideoActionRow extends StatelessWidget {
  const VideoActionRow({
    required this.actions,
    this.title,
    this.isLocked = false,
    super.key,
  });

  final List<VideoActionRowItem> actions;

  /// Heading shown above the row; no heading is rendered when null.
  final String? title;

  /// Whether an action in flight holds the whole row, so another action
  /// cannot dismiss the sheet before its outcome is reported. Every action
  /// not already pending is disabled.
  final bool isLocked;

  @override
  Widget build(BuildContext context) {
    final heading = title;
    return Padding(
      padding: const EdgeInsets.only(top: 12, bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        spacing: 12,
        children: [
          if (heading != null)
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Text(
                heading,
                style: VineTheme.titleMediumFont(
                  color: context.vineColors.primaryText,
                ),
              ),
            ),
          SizedBox(
            height: 86,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              itemCount: actions.length,
              separatorBuilder: (_, _) => const SizedBox(width: 4),
              itemBuilder: (context, index) {
                final action = actions[index];
                final circle = _ActionCircle(
                  icon: action.icon,
                  label: action.label,
                  onTap: action.onTap,
                  isPending: action.isPending,
                  isDisabled:
                      action.isDisabled || (isLocked && !action.isPending),
                );
                final onShown = action.onShown;
                if (onShown == null) return circle;
                return VisibilityDetector(
                  key: ValueKey(onShown),
                  onVisibilityChanged: (info) {
                    if (info.visibleFraction > 0) onShown();
                  },
                  child: circle,
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _ActionCircle extends StatelessWidget {
  const _ActionCircle({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isPending = false,
    this.isDisabled = false,
  });

  final DivineIconName icon;
  final String label;
  final VoidCallback onTap;
  final bool isPending;

  /// Disables the action without presenting it as the pending operation.
  final bool isDisabled;

  static const double _circleSize = 48;
  static const double _iconSize = 22;

  @override
  Widget build(BuildContext context) {
    final bgColor = isDisabled
        ? context.vineColors.surfaceContainer
        : VineTheme.vineGreen.withValues(alpha: 0.15);
    final iconColor = isDisabled
        ? context.vineColors.secondaryText
        : context.vineColors.accentPositive;

    return Semantics(
      button: true,
      label: label,
      enabled: !isPending && !isDisabled,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: isPending || isDisabled ? null : onTap,
        child: SizedBox(
          width: 68,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              Container(
                width: _circleSize,
                height: _circleSize,
                decoration: BoxDecoration(
                  color: bgColor,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: isPending
                      // Same footprint as the icon it replaces, so the row does
                      // not reflow while the action is in flight.
                      ? SizedBox.square(
                          dimension: _iconSize,
                          child: DivineCircularProgressIndicator(
                            strokeWidth: 2,
                            valueColor: AlwaysStoppedAnimation<Color>(
                              iconColor,
                            ),
                          ),
                        )
                      : DivineIcon(
                          icon: icon,
                          size: _iconSize,
                          color: iconColor,
                        ),
                ),
              ),
              Text(
                label,
                style: VineTheme.labelSmallFont(
                  color: context.vineColors.secondaryText,
                ),
                textScaler: TextScaler.noScaling,
                textAlign: TextAlign.center,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
