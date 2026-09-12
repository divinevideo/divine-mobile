import 'package:material_ui/material_ui.dart';

/// Clips only vertically (to the widget's height) while allowing
/// horizontal overflow to remain visible — needed so overlay trim
/// handles can extend beyond the timeline's horizontal bounds.
class VerticalOnlyClipper extends CustomClipper<Rect> {
  const VerticalOnlyClipper();

  static const _horizontalOverflow = 10000.0;

  @override
  Rect getClip(Size size) => Rect.fromLTWH(
    -_horizontalOverflow,
    0,
    size.width + _horizontalOverflow * 2,
    size.height,
  );

  @override
  bool shouldReclip(covariant VerticalOnlyClipper oldClipper) => false;
}
