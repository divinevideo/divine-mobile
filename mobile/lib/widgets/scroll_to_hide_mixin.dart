// ABOUTME: Mixin providing scroll-to-hide behavior for overlay headers
// ABOUTME: Used by tabs with a collapsible header above a scrollable grid

import 'package:material_ui/material_ui.dart';

/// Mixin that provides scroll-to-hide behavior for an overlay header widget.
///
/// The header pushes up 1:1 with scroll-down movement, then slides back in
/// with a 250ms animation when the user scrolls up after fully hiding it.
///
/// Usage:
/// 1. Mix into a [State] subclass.
/// 2. Assign [headerKey] to the header widget's key.
/// 3. Call [measureHeaderHeight] in `build()`.
/// 4. Wrap the scrollable child with
///    `NotificationListener<ScrollNotification>(onNotification: handleScrollNotification, ...)`.
/// 5. Use [headerOffset], [headerHeight], and [headerFullyHidden] to position
///    the header via [AnimatedPositioned].
mixin ScrollToHideMixin<T extends StatefulWidget> on State<T> {
  /// Assign this key to the header widget to enable height measurement.
  final GlobalKey headerKey = GlobalKey();

  /// Measured height of the header widget.
  double get headerHeight => _headerHeight;
  double _headerHeight = 0;

  /// Current vertical offset of the header (0 = visible, -height = hidden).
  double get headerOffset => _headerOffset;
  double _headerOffset = 0;

  /// Whether the header is fully hidden and should animate back on scroll-up.
  bool get headerFullyHidden => _headerFullyHidden;
  bool _headerFullyHidden = false;

  bool _isScrollingDown = true;

  /// Call this in `build()` to measure the header after layout.
  void measureHeaderHeight() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final box = headerKey.currentContext?.findRenderObject() as RenderBox?;
      if (box != null && _headerHeight == 0) {
        setState(() {
          _headerHeight = box.size.height;
        });
      }
    });
  }

  /// Pass this as the `onNotification` callback for a
  /// [NotificationListener<ScrollNotification>].
  bool handleScrollNotification(ScrollNotification notification) {
    if (notification is ScrollUpdateNotification) {
      final delta = notification.scrollDelta ?? 0;
      final pixels = notification.metrics.pixels;

      // Ignore overscroll (pull-to-refresh rubber band)
      if (pixels <= 0) return false;

      if (delta > 0) {
        // Scrolling down: push header up 1:1
        _isScrollingDown = true;
        _headerFullyHidden = false;
        setState(() {
          _headerOffset = (_headerOffset - delta).clamp(-_headerHeight, 0);
        });
      } else if (delta < 0) {
        // Scrolling up: if header is hidden, animate it in as overlay
        if (_isScrollingDown && _headerOffset <= -_headerHeight) {
          _isScrollingDown = false;
          _headerFullyHidden = true;
          setState(() {
            _headerOffset = 0;
          });
        } else if (!_headerFullyHidden) {
          // Still partially visible during scroll down, push back 1:1
          setState(() {
            _headerOffset = (_headerOffset - delta).clamp(-_headerHeight, 0);
          });
        }
      }
    }
    return false;
  }
}
