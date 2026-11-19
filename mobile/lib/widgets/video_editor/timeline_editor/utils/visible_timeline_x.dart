import 'package:flutter/widgets.dart';

/// Where [globalX] falls across the visible part of the horizontal timeline
/// [context] scrolls in, and that part's width.
///
/// Measured on the timeline's own viewport, which beside the preview of a wide
/// window is narrower than the screen and does not start at its left edge.
/// Without a timeline around [context], it falls back to the screen.
({double x, double width}) visibleTimelineX(
  BuildContext context,
  double globalX,
) {
  final viewport = Scrollable.maybeOf(
    context,
    axis: Axis.horizontal,
  )?.context.findRenderObject();
  if (viewport is! RenderBox || !viewport.hasSize) {
    return (x: globalX, width: MediaQuery.sizeOf(context).width);
  }
  return (
    x: viewport.globalToLocal(Offset(globalX, 0)).dx,
    width: viewport.size.width,
  );
}
