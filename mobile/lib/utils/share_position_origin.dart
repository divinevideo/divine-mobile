import 'package:material_ui/material_ui.dart';

/// The global bounds of [context]'s render box, or `null` when it has no
/// usable size.
Rect? sharePositionOriginForContext(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) return null;
  final topLeft = renderObject.localToGlobal(Offset.zero);
  final rect = topLeft & renderObject.size;
  if (rect.isEmpty) return null;
  return rect;
}

/// The share-sheet popover anchor for [context], clamped to the view.
///
/// iPad idiom rejects a share whose anchor is empty or reaches outside the
/// source view, so a widget that is unsized or scrolled partly off-screen
/// falls back to (or is clipped against) the whole view instead of handing
/// share_plus a rect it will refuse.
Rect? shareAnchorForContext(BuildContext context) {
  final viewRect = Offset.zero & MediaQuery.sizeOf(context);
  final origin = sharePositionOriginForContext(context);
  if (viewRect.isEmpty) return origin;
  if (origin == null) return viewRect;
  final clamped = origin.intersect(viewRect);
  return clamped.isEmpty ? viewRect : clamped;
}
