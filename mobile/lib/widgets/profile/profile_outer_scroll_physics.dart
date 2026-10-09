// ABOUTME: Outer scroll physics for the profile's NestedScrollView that stop
// ABOUTME: the header scrolling past the point where a short tab's last row
// ABOUTME: reaches the bottom of the screen.

import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

/// Resolves the furthest the outer scroll may travel for a viewport of
/// [viewportExtent], or `null` when the active tab imposes no limit.
typedef ProfileOuterScrollLimit = double? Function(double viewportExtent);

/// The outer offset at which a tab of [content] height ends exactly at the
/// bottom of a [viewport] tall screen.
///
/// The pinned tab bar grows by up to [safeAreaTop] while it slides under the
/// status bar (see `ProfileTabBar`), so the content bottom stands still for
/// that stretch of scrolling. The two branches are the solutions either side
/// of it: the bar never pins, or it pins with the full inset.
double profileOuterScrollExtentFor({
  required double header,
  required double tabBar,
  required double safeAreaTop,
  required double content,
  required double viewport,
}) {
  if (tabBar + content + safeAreaTop > viewport) {
    return header + tabBar + content + safeAreaTop - viewport;
  }
  return math.max(0, header + tabBar + content - viewport);
}

/// The least content height a profile tab is given room for: one row of the
/// three-column video grid plus the bottom safe area.
///
/// An empty, loading or short tab still scrolls far enough to show this much
/// below the tabs, so its message is never squeezed against the bottom edge.
double profileTabMinimumContentExtent({
  required double tabWidth,
  required double bottomSafeArea,
}) =>
    (tabWidth - _gridSpacing * (_gridColumns - 1)) / _gridColumns +
    bottomSafeArea;

/// The geometry of the Videos tab's grid, which the other grids match.
const _gridColumns = 3;
const _gridSpacing = 4.0;

/// Physics for the profile's outer scroll position.
///
/// `NestedScrollView` always lets the header scroll fully away, because its
/// body fills whatever the pinned headers leave. On a tab with a row or two
/// that leaves most of the screen empty below the last row. These physics cap
/// the outer offset at [scrollLimit] instead, for drags and flings alike.
class ProfileOuterScrollPhysics extends ScrollPhysics {
  const ProfileOuterScrollPhysics({required this.scrollLimit, super.parent});

  final ProfileOuterScrollLimit scrollLimit;

  @override
  ProfileOuterScrollPhysics applyTo(ScrollPhysics? ancestor) =>
      ProfileOuterScrollPhysics(
        scrollLimit: scrollLimit,
        parent: buildParent(ancestor),
      );

  double? _limitFor(ScrollMetrics metrics) {
    final limit = scrollLimit(metrics.viewportDimension);
    if (limit == null || limit >= metrics.maxScrollExtent) return null;
    return math.max(limit, metrics.minScrollExtent);
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    final overscroll = super.applyBoundaryConditions(position, value);
    if (overscroll != 0) return overscroll;
    final limit = _limitFor(position);
    // Only refuse movement further past the limit: an offset already beyond
    // it (the user switched from a longer tab) can still scroll back.
    if (limit == null || value <= limit || value <= position.pixels) return 0;
    return value - math.max(limit, position.pixels);
  }

  @override
  Simulation? createBallisticSimulation(
    ScrollMetrics position,
    double velocity,
  ) {
    final simulation = super.createBallisticSimulation(position, velocity);
    final limit = _limitFor(position);
    if (simulation == null || limit == null || velocity <= 0) {
      return simulation;
    }
    if (position.pixels >= limit) return null;
    return _CappedSimulation(simulation, limit);
  }
}

/// Follows [_simulation] until it reaches [_cap], then stops there.
///
/// Ending the fling on the cap (rather than letting boundary conditions cut
/// it) matters inside a `NestedScrollView`: its outer ballistic activity
/// asserts that every step lands in range.
class _CappedSimulation extends Simulation {
  _CappedSimulation(this._simulation, this._cap)
    : super(tolerance: _simulation.tolerance);

  final Simulation _simulation;
  final double _cap;

  @override
  double x(double time) => math.min(_simulation.x(time), _cap);

  @override
  double dx(double time) =>
      _simulation.x(time) >= _cap ? 0 : _simulation.dx(time);

  @override
  bool isDone(double time) =>
      _simulation.isDone(time) || _simulation.x(time) >= _cap;
}

/// The height of the content in the first viewport below [context], or
/// `null` when it has not been laid out yet.
///
/// Empty, loading and error states fill the tab with [SliverFillRemaining],
/// whose own extent is just the space it was given; those count as the
/// natural height of their message instead, the same height the sliver
/// itself grows to when the message does not fit.
double? profileTabContentExtent(BuildContext? context) {
  final viewport = _firstViewportBelow(context?.findRenderObject());
  if (viewport == null) return null;
  double? extent = 0;
  viewport.visitChildren((child) {
    final sliver = child as RenderSliver;
    final geometry = sliver.geometry;
    final sliverExtent = switch (sliver) {
      _ when geometry == null => null,
      RenderSliverFillRemainingWithScrollable() => null,
      RenderSliverFillRemaining(:final child) ||
      RenderSliverFillRemainingAndOverscroll(:final child) =>
        child?.getMaxIntrinsicHeight(sliver.constraints.crossAxisExtent) ?? 0,
      _ => geometry.scrollExtent,
    };
    extent = sliverExtent == null || extent == null
        ? null
        : extent! + sliverExtent;
  });
  return extent;
}

RenderViewportBase? _firstViewportBelow(RenderObject? root) {
  if (root == null) return null;
  final queue = <RenderObject>[root];
  while (queue.isNotEmpty) {
    final node = queue.removeAt(0);
    if (node is RenderViewportBase) return node;
    node.visitChildren(queue.add);
  }
  return null;
}
