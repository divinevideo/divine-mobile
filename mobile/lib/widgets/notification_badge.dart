// ABOUTME: Badge widget to show unread notification count on icons
// ABOUTME: Displays count or red dot for high numbers with animation support

import 'package:flutter/material.dart';

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

    return Stack(
      clipBehavior: Clip.none,
      children: [
        child,
        Positioned(
          right: -8,
          top: -8,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            padding: EdgeInsets.symmetric(
              horizontal: count > 99 ? 4 : 6,
              vertical: 2,
            ),
            decoration: BoxDecoration(
              color: badgeColor ?? Colors.red,
              borderRadius: BorderRadius.circular(10),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.2),
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
                    ? Icon(
                        Icons.circle,
                        key: const ValueKey('dot'),
                        size: 8,
                        color: textColor ?? Colors.white,
                      )
                    : Text(
                        count.toString(),
                        key: ValueKey(count),
                        style: TextStyle(
                          color: textColor ?? Colors.white,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
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

    return Stack(
      clipBehavior: Clip.none,
      children: [
        widget.child,
        Positioned(
          right: -8,
          top: -8,
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
                color: widget.badgeColor ?? Colors.red,
                borderRadius: BorderRadius.circular(10),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              constraints: const BoxConstraints(minWidth: 20, minHeight: 20),
              child: Center(
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 150),
                  child: widget.count > 99
                      ? Icon(
                          Icons.circle,
                          key: const ValueKey('dot'),
                          size: 8,
                          color: widget.textColor ?? Colors.white,
                        )
                      : Text(
                          widget.count.toString(),
                          key: ValueKey(widget.count),
                          style: TextStyle(
                            color: widget.textColor ?? Colors.white,
                            fontSize: 11,
                            fontWeight: FontWeight.bold,
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
