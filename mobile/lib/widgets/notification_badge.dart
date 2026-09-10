// ABOUTME: Badge widget to show unread notification count on icons
// ABOUTME: Displays count or dot for high numbers with animation support

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

class NotificationBadge extends StatelessWidget {
  const NotificationBadge({
    required this.child,
    required this.count,
    super.key,
    this.showBadge = true,
    this.badgeColor,
    this.textColor,
  });
  final Widget child;
  final int count;
  final bool showBadge;
  final Color? badgeColor;
  final Color? textColor;

  @override
  Widget build(BuildContext context) {
    if (!showBadge || count <= 0) {
      return child;
    }

    final foreground = textColor ?? context.vineColors.primaryText;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        PositionedDirectional(
          end: -8,
          top: -8,
          child: ExcludeSemantics(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 200),
              padding: EdgeInsets.symmetric(
                horizontal: count > 99 ? 4 : 6,
                vertical: 2,
              ),
              decoration: BoxDecoration(
                color: badgeColor ?? VineTheme.error,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: VineTheme.backgroundColor.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: count > 99
                      ? _OverflowDot(
                          key: const ValueKey('dot'),
                          color: foreground,
                        )
                      : Text(
                          count.toString(),
                          key: ValueKey(count),
                          style: VineTheme.labelSmallFont(color: foreground),
                        ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

/// Animated notification badge with pulse effect for new notifications
class AnimatedNotificationBadge extends StatefulWidget {
  const AnimatedNotificationBadge({
    required this.child,
    required this.count,
    super.key,
    this.showBadge = true,
    this.pulseOnNewNotification = true,
    this.badgeColor,
    this.textColor,
  });
  final Widget child;
  final int count;
  final bool showBadge;
  final bool pulseOnNewNotification;
  final Color? badgeColor;
  final Color? textColor;

  @override
  State<AnimatedNotificationBadge> createState() =>
      _AnimatedNotificationBadgeState();
}

class _AnimatedNotificationBadgeState extends State<AnimatedNotificationBadge>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _scaleAnimation;
  int _previousCount = 0;

  @override
  void initState() {
    super.initState();
    _previousCount = widget.count;

    _animationController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(begin: 1, end: 1.3).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.elasticOut),
    );
  }

  @override
  void didUpdateWidget(AnimatedNotificationBadge oldWidget) {
    super.didUpdateWidget(oldWidget);

    if (widget.count > _previousCount && widget.pulseOnNewNotification) {
      _animationController.forward().then((_) {
        _animationController.reverse();
      });
    }
    _previousCount = widget.count;
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.showBadge || widget.count <= 0) {
      return widget.child;
    }

    final foreground = widget.textColor ?? context.vineColors.primaryText;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        PositionedDirectional(
          end: -8,
          top: -8,
          child: ExcludeSemantics(
            child: RepaintBoundary(
              child: AnimatedBuilder(
                animation: _scaleAnimation,
                builder: (context, child) =>
                    Transform.scale(scale: _scaleAnimation.value, child: child),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: EdgeInsets.symmetric(
                    horizontal: widget.count > 99 ? 4 : 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: widget.badgeColor ?? VineTheme.error,
                    borderRadius: BorderRadius.circular(10),
                    boxShadow: [
                      BoxShadow(
                        color: VineTheme.backgroundColor.withValues(
                          alpha: 0.2,
                        ),
                        blurRadius: 4,
                        offset: const Offset(0, 2),
                      ),
                    ],
                  ),
                  constraints: const BoxConstraints(
                    minWidth: 20,
                    minHeight: 20,
                  ),
                  child: Center(
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 150),
                      child: widget.count > 99
                          ? _OverflowDot(
                              key: const ValueKey('dot'),
                              color: foreground,
                            )
                          : Text(
                              widget.count.toString(),
                              key: ValueKey(widget.count),
                              style: VineTheme.labelSmallFont(
                                color: foreground,
                              ),
                            ),
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

class _OverflowDot extends StatelessWidget {
  const _OverflowDot({required this.color, super.key});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(color: color, shape: BoxShape.circle),
    );
  }
}
