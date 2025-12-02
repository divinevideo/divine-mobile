// ABOUTME: Video icon placeholder widget for when thumbnails are missing or loading
// ABOUTME: Provides a clean video icon instead of fake stock images

import 'package:flutter/material.dart';

/// Professional video icon placeholder that displays instead of missing thumbnails
/// Uses a proper video icon with subtle animations and proper theming
class VideoIconPlaceholder extends StatefulWidget {
  const VideoIconPlaceholder({
    super.key,
    this.width,
    this.height,
    this.backgroundColor,
    this.iconColor,
    this.showLoading = false,
    this.borderRadius = 8.0,
    this.showPlayIcon = true,
  });
  final double? width;
  final double? height;
  final Color? backgroundColor;
  final Color? iconColor;
  final bool showLoading;
  final double borderRadius;
  final bool showPlayIcon;

  @override
  State<VideoIconPlaceholder> createState() => _VideoIconPlaceholderState();
}

class _VideoIconPlaceholderState extends State<VideoIconPlaceholder>
    with SingleTickerProviderStateMixin {
  late AnimationController _animationController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      duration: const Duration(seconds: 2),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 0.8, end: 1).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );

    if (widget.showLoading) {
      _animationController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(VideoIconPlaceholder oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.showLoading != oldWidget.showLoading) {
      if (widget.showLoading) {
        _animationController.repeat(reverse: true);
      } else {
        _animationController.stop();
        _animationController.reset();
      }
    }
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor =
        widget.backgroundColor ??
        (isDark ? Colors.grey[800] : Colors.grey[200]);
    final iconColorValue =
        widget.iconColor ?? (isDark ? Colors.grey[400] : Colors.grey[600]);

    return Container(
      width: widget.width,
      height: widget.height,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(widget.borderRadius),
        border: Border.all(
          color: isDark ? Colors.grey[700]! : Colors.grey[300]!,
          width: 1,
        ),
      ),
      child: widget.showLoading
          ? AnimatedBuilder(
              animation: _pulseAnimation,
              builder: (context, child) => Transform.scale(
                scale: _pulseAnimation.value,
                child: _buildIcon(iconColorValue),
              ),
            )
          : _buildIcon(iconColorValue),
    );
  }

  Widget _buildIcon(Color? iconColor) => Center(
    child: widget.showPlayIcon
        ? Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.play_circle_outline, size: 48, color: iconColor),
              const SizedBox(height: 8),
              Text(
                'Video',
                style: TextStyle(
                  fontSize: 12,
                  color: iconColor,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          )
        : Text(
            'Video',
            style: TextStyle(
              fontSize: 14,
              color: iconColor,
              fontWeight: FontWeight.w500,
            ),
          ),
  );
}

/// Compact version for smaller spaces
class VideoIconPlaceholderCompact extends StatelessWidget {
  const VideoIconPlaceholderCompact({
    super.key,
    this.size = 24,
    this.iconColor,
    this.backgroundColor,
  });
  final double size;
  final Color? iconColor;
  final Color? backgroundColor;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    final bgColor =
        backgroundColor ?? (isDark ? Colors.grey[800] : Colors.grey[200]);
    final iconColorValue =
        iconColor ?? (isDark ? Colors.grey[400] : Colors.grey[600]);

    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(4),
      ),
      child: Icon(Icons.videocam, size: size * 0.6, color: iconColorValue),
    );
  }
}
