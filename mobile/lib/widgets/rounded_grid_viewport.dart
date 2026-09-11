// ABOUTME: Clips a scrolling grid's top corners so content sliding under the
// ABOUTME: app bar keeps the rounded seam the design's radius cap draws.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// Rounds the viewport of a list page's grid while it scrolls.
///
/// Complements `ComposableVideoGrid.topOuterRadius`: that rounds the grid
/// block itself at rest, this rounds the viewport while scrolled, so content
/// sliding under the app bar keeps the same rounded seam.
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
