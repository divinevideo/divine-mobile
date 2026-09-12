import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// Rounded-square type indicator shown on the leading edge of a notification
/// row (32×32, radius 12). Optionally overlays a small red unread dot.
///
/// Background and foreground colors are passed in so the widget stays a
/// pure design primitive — callers map their own notification-type enum to
/// the matching accent pair from [VineTheme].
class NotificationTypeIcon extends StatelessWidget {
  const NotificationTypeIcon({
    required this.icon,
    required this.backgroundColor,
    required this.foregroundColor,
    this.showUnreadDot = false,
    super.key,
  });

  /// Icon shown inside the rounded square.
  final DivineIconName icon;

  /// Solid fill color of the rounded square.
  final Color backgroundColor;

  /// Tint color for the inner icon.
  final Color foregroundColor;

  /// Whether to show the unread red dot at the top-right corner.
  final bool showUnreadDot;

  static const double _containerSize = 32;
  static const double _iconSize = 20;
  static const double _radius = 12;
  static const double _dotSize = 8;
  static const double _dotBorder = 3;

  @override
  Widget build(BuildContext context) {
    // Decorative: the surrounding row already announces the notification
    // type via its message text and unread state via its semantic label.
    return ExcludeSemantics(
      child: SizedBox.square(
        dimension: _containerSize + _dotBorder,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Container(
              width: _containerSize,
              height: _containerSize,
              decoration: BoxDecoration(
                color: backgroundColor,
                borderRadius: BorderRadius.circular(_radius),
              ),
              alignment: Alignment.center,
              child: DivineIcon(
                icon: icon,
                size: _iconSize,
                color: foregroundColor,
              ),
            ),
            if (showUnreadDot)
              const Positioned(
                top: -_dotBorder + 2,
                right: -_dotBorder + 2,
                child: _UnreadDot(),
              ),
          ],
        ),
      ),
    );
  }
}

class _UnreadDot extends StatelessWidget {
  const _UnreadDot();

  @override
  Widget build(BuildContext context) {
    return Container(
      width:
          NotificationTypeIcon._dotSize + NotificationTypeIcon._dotBorder * 2,
      height:
          NotificationTypeIcon._dotSize + NotificationTypeIcon._dotBorder * 2,
      decoration: BoxDecoration(
        color: context.vineColors.surfaceContainerHigh,
        shape: BoxShape.circle,
      ),
      alignment: Alignment.center,
      child: Container(
        width: NotificationTypeIcon._dotSize,
        height: NotificationTypeIcon._dotSize,
        decoration: const BoxDecoration(
          color: VineTheme.error,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}
