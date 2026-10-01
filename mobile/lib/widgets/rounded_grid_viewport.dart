// ABOUTME: Clips a scrolling grid's or list's top corners so content sliding
// ABOUTME: under the app bar keeps the rounded seam the design's radius cap draws.

import 'package:divine_ui/divine_ui.dart';
import 'package:material_ui/material_ui.dart';

/// Rounds the viewport of a list page's scrolling content.
///
/// On the grid pages it complements `ComposableVideoGrid.topOuterRadius`:
/// that rounds the grid block itself at rest, this rounds the viewport while
/// scrolled, so content sliding under the app bar keeps the same rounded
/// seam. The people-list roster puts its member list behind the same clip.
class RoundedGridViewport extends StatelessWidget {
  const RoundedGridViewport({required this.child, super.key});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: const BorderRadius.vertical(
        top: Radius.circular(VineTheme.shellInnerCornerRadius),
      ),
      child: child,
    );
  }
}
