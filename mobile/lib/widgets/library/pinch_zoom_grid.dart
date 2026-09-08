// ABOUTME: Pinch-to-zoom wrapper that maps a scale gesture to a column count
// ABOUTME: Slides the next column in and crossfades in step with the pinch

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';

/// Builds the grid for a given column count.
///
/// The [controller] must be handed to the built scroll view — [PinchZoomGrid]
/// uses it to keep the same region of the grid on screen when the column
/// count changes.
typedef PinchZoomGridBuilder = Widget Function(
  BuildContext context,
  int columnCount,
  ScrollController controller,
);

/// Dispatched when a pinch on a [PinchZoomGrid] starts and ends.
///
/// Ancestors that drag on the same pointers — a `TabBarView`'s page swipe,
/// most importantly — should suspend themselves while a pinch is active.
class PinchZoomNotification extends Notification {
  const PinchZoomNotification({required this.active});

  /// Whether a pinch is in progress.
  final bool active;
}

/// Wraps a scrollable grid and turns a two-finger pinch into a column-count
/// change, the way a device photo gallery does.
///
/// The gesture tracks a *fractional* column count `c` — a damped version of
/// the pinch, see `_zoomGain` — and everything on screen is a function of it,
/// with no timed animation while the fingers are down. Both the layout being
/// left behind and the one being moved to are drawn at the same tile width,
/// `viewport / c`:
///
/// * The outgoing layout is the frame before the step, frozen as a raster and
///   scaled by `itsColumns / c`. Going from 3 columns to 2 it grows, so its
///   third column slides off the right edge.
/// * The incoming layout is the live grid, laid out for the neighbouring
///   count and scaled by `itsColumns / c`. Going from 2 columns to 3 it
///   starts oversized with its third column past the right edge, which then
///   slides in as the fingers close.
/// * The raster fades out linearly with the distance travelled between the
///   two steps, so a pinch stopped half way sits at half opacity.
///
/// Both layers are anchored at the top-left and the scroll offset is
/// converted between the two layouts, so the clip at the top of the viewport
/// stays there and the change happens at the right edge.
///
/// On release the fractional count settles onto the nearest whole one, which
/// finishes the slide and the crossfade together, and the new count is
/// reported via [onColumnCountChanged].
class PinchZoomGrid extends StatefulWidget {
  const PinchZoomGrid({
    required this.columnCount,
    required this.minColumnCount,
    required this.maxColumnCount,
    required this.onColumnCountChanged,
    required this.backgroundColor,
    required this.builder,
    this.scrollController,
    super.key,
  }) : assert(
         minColumnCount >= 1 && maxColumnCount >= minColumnCount,
         'minColumnCount must be >= 1 and <= maxColumnCount',
       );

  /// The committed column count, e.g. restored from preferences.
  final int columnCount;

  /// Fewest columns the pinch can reach (largest thumbnails).
  final int minColumnCount;

  /// Most columns the pinch can reach (smallest thumbnails).
  final int maxColumnCount;

  /// Called once per pinch, when the gesture ends on a new column count.
  final ValueChanged<int> onColumnCountChanged;

  /// Surface the grid sits on, painted behind it inside the crossfade.
  ///
  /// A grid is transparent between its tiles, and two stacked transparent
  /// layouts do not crossfade — through the gaps of the one in front, the one
  /// behind stays fully visible however far the fade has come, and then blinks
  /// away with it. Giving each layout its own opaque backing makes the gaps
  /// part of the layout they belong to. Pass the colour actually behind this
  /// widget, or the grid will sit on the wrong shade.
  final Color backgroundColor;

  /// Builds the grid for the currently rendered column count.
  final PinchZoomGridBuilder builder;

  /// Scroll controller for the built grid. When null, one is created and
  /// owned by this widget.
  final ScrollController? scrollController;

  @override
  State<PinchZoomGrid> createState() => _PinchZoomGridState();
}

class _PinchZoomGridState extends State<PinchZoomGrid>
    with SingleTickerProviderStateMixin {
  /// How long the fractional count takes to settle onto a whole one.
  static const _settleDuration = Duration(milliseconds: 220);

  /// Distance in columns below which two counts are treated as the same.
  static const _epsilon = 0.001;

  /// How much of the fingers' movement reaches the column count.
  ///
  /// At 1 the tile size tracks them exactly, so spreading by half is already
  /// a whole column step — which is twitchy in the hand. At 0.65 the same
  /// step asks for roughly 87% more travel instead. The whole range is still
  /// within one comfortable pinch.
  static const _zoomGain = 0.65;

  /// Held as a constant so a rebuild that does not change the lock does not
  /// look like a physics change to the grid below.
  static const _lockedPhysics = NeverScrollableScrollPhysics();

  /// Fractional column count the fingers are currently at.
  final _columns = ValueNotifier<double>(0);

  final GlobalKey _liveLayoutKey = GlobalKey();

  late final AnimationController _settleController = AnimationController(
    vsync: this,
    duration: _settleDuration,
  );

  ScrollController? _ownedController;
  Animation<double>? _settle;

  /// Whole column count the running settle is heading for.
  double _settleTarget = 0;

  /// The layout being left behind, frozen as a raster.
  ui.Image? _frozenLayout;

  /// Column count the frozen layout was laid out with — the step the current
  /// crossfade runs from.
  int _frozenColumns = 0;

  bool _captureScheduled = false;

  /// Column count the live grid is laid out with.
  late int _renderColumns = widget.columnCount;

  /// Column count last handed to [PinchZoomGrid.onColumnCountChanged].
  ///
  /// The owner persists before it emits, so [PinchZoomGrid.columnCount] can
  /// still be the pre-pinch count when the next pinch ends. Deciding whether
  /// a pinch is worth reporting against that would drop the second of two
  /// pinches inside one round trip, leaving the owner — and what it persists
  /// — on a step the user has already left.
  late int _lastReportedColumns = widget.columnCount;

  /// Fractional column count when the current pinch started.
  double _gestureStartColumns = 0;

  /// Pointers currently down on the grid.
  int _pointerCount = 0;

  /// Whether the grid's own scrolling is suspended for a pinch.
  bool _scrollLocked = false;

  ScrollController get _controller =>
      widget.scrollController ?? _ownedController!;

  bool get _isGestureActive =>
      _scrollLocked || _settleController.isAnimating || _captureScheduled;

  @override
  void initState() {
    super.initState();
    _columns.value = widget.columnCount.toDouble();
    if (widget.scrollController == null) {
      _ownedController = ScrollController();
    }
    _settleController.addListener(() {
      final settle = _settle;
      if (settle != null) _setColumns(settle.value);
    });
  }

  @override
  void didUpdateWidget(PinchZoomGrid oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.scrollController != oldWidget.scrollController) {
      if (widget.scrollController == null) {
        _ownedController ??= ScrollController();
      } else {
        _ownedController?.dispose();
        _ownedController = null;
      }
    }
    // Only a count that actually changed is the owner's decision. A rebuild
    // repeating the previous one is the owner not having caught up with what
    // the last pinch reported — the state layer persists before it emits, and
    // this widget's own pinch notification rebuilds the tab in between. Taking
    // that would snap the grid back to the step the pinch just left.
    if (widget.columnCount == oldWidget.columnCount) return;
    // A count arriving mid-pinch (or mid-settle) is that same echo, just early
    // enough to fight the gesture.
    if (widget.columnCount == _renderColumns || _isGestureActive) return;
    _disposeFrozenLayout();
    _renderColumns = widget.columnCount;
    _lastReportedColumns = widget.columnCount;
    _columns.value = widget.columnCount.toDouble();
  }

  @override
  void deactivate() {
    // Leaving mid-pinch would otherwise strand an ancestor with its own
    // dragging switched off.
    if (_scrollLocked) {
      const PinchZoomNotification(active: false).dispatch(context);
      _scrollLocked = false;
    }
    super.deactivate();
  }

  @override
  void dispose() {
    _settleController.dispose();
    _disposeFrozenLayout();
    _columns.dispose();
    _ownedController?.dispose();
    super.dispose();
  }

  void _onPointerDown(PointerDownEvent event) {
    _pointerCount++;
    if (_pointerCount < 2 || _scrollLocked) return;
    // Lock before the arena resolves: with the grid's drag recognizer gone,
    // the scale recognizer cannot lose the pinch to a stray scroll.
    _stopScroll();
    const PinchZoomNotification(active: true).dispatch(context);
    setState(() => _scrollLocked = true);
  }

  void _onPointerStop(PointerEvent event) {
    if (_pointerCount > 0) _pointerCount--;
    if (_pointerCount >= 2 || !_scrollLocked) return;
    const PinchZoomNotification(active: false).dispatch(context);
    setState(() => _scrollLocked = false);
  }

  void _onScaleStart(ScaleStartDetails details) {
    // Lifting one finger off a pinch ends the gesture but leaves the
    // recognizer running for the one still down, which starts again as soon
    // as it moves. Taking that for a new pinch would cancel the settle the
    // lift just started and strand the grid between two steps.
    if (details.pointerCount < 2) return;
    _settleController.stop();
    _gestureStartColumns = _columns.value;
  }

  void _onScaleUpdate(ScaleUpdateDetails details) {
    if (details.pointerCount < 2 || details.scale <= 0) return;
    // Spreading the fingers (scale > 1) grows the thumbnails, which means
    // fewer columns.
    _setColumns(_gestureStartColumns / math.pow(details.scale, _zoomGain));
  }

  void _onScaleEnd(ScaleEndDetails details) {
    final target = _columns.value.round().toDouble();
    // The recognizer reports the end once per finger leaving, so the same
    // release can arrive twice.
    if (_settleController.isAnimating && _settleTarget == target) return;
    _settleTarget = target;
    final columns = target.toInt();
    if (columns != _lastReportedColumns) {
      _lastReportedColumns = columns;
      widget.onColumnCountChanged(columns);
    }
    if ((_columns.value - target).abs() < _epsilon) {
      _setColumns(target);
      return;
    }
    _settle = Tween<double>(begin: _columns.value, end: target).animate(
      CurvedAnimation(parent: _settleController, curve: Curves.easeOutCubic),
    );
    _settleController.forward(from: 0);
  }

  void _setColumns(double value) {
    _columns.value = value.clamp(
      widget.minColumnCount.toDouble(),
      widget.maxColumnCount.toDouble(),
    );
    _syncLayers();
  }

  /// Keeps the pair of layouts on screen in step with the fractional count:
  /// retires a finished crossfade and starts the next one.
  void _syncLayers() {
    final columns = _columns.value;

    if (_frozenLayout != null) {
      final low = math.min(_frozenColumns, _renderColumns);
      final high = math.max(_frozenColumns, _renderColumns);
      if (columns > low + _epsilon && columns < high - _epsilon) return;
      // One of the two steps has been reached, so it is the only one left on
      // screen — and it has to be the live grid rather than the raster.
      final reached =
          (columns - _frozenColumns).abs() < (columns - _renderColumns).abs()
          ? _frozenColumns
          : _renderColumns;
      final previous = _renderColumns;
      setState(() {
        _disposeFrozenLayout();
        _renderColumns = reached;
      });
      if (reached != previous) _keepScrollAnchored(from: previous, to: reached);
    }

    if (_captureScheduled) return;
    if ((columns - _renderColumns).abs() <= _epsilon) return;
    // The outgoing layout can only be captured from a painted, clean layer
    // tree, which is what the end of the frame guarantees.
    _captureScheduled = true;
    WidgetsBinding.instance
      ..ensureVisualUpdate()
      ..addPostFrameCallback(_startCrossfade);
  }

  void _startCrossfade(Duration _) {
    _captureScheduled = false;
    if (!mounted) return;

    final columns = _columns.value;
    final anchor = _renderColumns;
    if ((columns - anchor).abs() <= _epsilon) return;
    final target = columns > anchor ? anchor + 1 : anchor - 1;

    // A step reached exactly needs no crossfade, only the new layout.
    if ((columns - target).abs() > _epsilon) _captureLiveLayout(anchor);
    setState(() => _renderColumns = target);
    _keepScrollAnchored(from: anchor, to: target);
  }

  /// Freezes the layout that is on screen right now, so the incoming one can
  /// dissolve out of it.
  void _captureLiveLayout(int columnCount) {
    final boundary = _liveLayoutKey.currentContext?.findRenderObject();
    if (boundary is! RenderRepaintBoundary) return;
    _disposeFrozenLayout();
    _frozenLayout = boundary.toImageSync(
      pixelRatio: MediaQuery.devicePixelRatioOf(context),
    );
    _frozenColumns = columnCount;
  }

  void _disposeFrozenLayout() {
    // RawImage renders a clone, so this handle is ours to release.
    _frozenLayout?.dispose();
    _frozenLayout = null;
  }

  void _stopScroll() {
    final controller = _controller;
    if (!controller.hasClients) return;
    // Also cancels an in-flight drag or fling, so the grid holds still under
    // the fingers for the whole pinch.
    controller.position.jumpTo(controller.position.pixels);
  }

  /// Keeps the clip at the top of the viewport in place across a column
  /// change.
  ///
  /// The masonry grid mixes square and vertical clips, so this is an
  /// approximation: the square-grid ratio keeps the visible area close, and the
  /// post-frame clamp absorbs extent differences once masonry layout settles.
  void _keepScrollAnchored({required int from, required int to}) {
    final controller = _controller;
    if (!controller.hasClients) return;
    final ratio = from / to;
    final target = controller.position.pixels * ratio * ratio;

    void apply() {
      if (!controller.hasClients) return;
      final position = controller.position;
      position.jumpTo(
        target.clamp(position.minScrollExtent, position.maxScrollExtent),
      );
    }

    // Straight away, so the incoming layout is never painted at the outgoing
    // one's offset, and again once it has laid out and the extent it can
    // actually reach is known.
    apply();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) apply();
    });
  }

  @override
  Widget build(BuildContext context) {
    // Both wrappers stay in the tree unconditionally. Adding or removing a
    // widget above the grid would remount it, which throws away its scroll
    // position and re-resolves every thumbnail.
    final grid = ScrollConfiguration(
      behavior: ScrollConfiguration.of(
        context,
      ).copyWith(physics: _scrollLocked ? _lockedPhysics : null),
      child: widget.builder(context, _renderColumns, _controller),
    );

    return Listener(
      onPointerDown: _onPointerDown,
      onPointerUp: _onPointerStop,
      onPointerCancel: _onPointerStop,
      child: RawGestureDetector(
        excludeFromSemantics: true,
        gestures: <Type, GestureRecognizerFactory>{
          _PinchGestureRecognizer:
              GestureRecognizerFactoryWithHandlers<_PinchGestureRecognizer>(
                () => _PinchGestureRecognizer(debugOwner: this),
                (instance) => instance
                  ..onStart = _onScaleStart
                  ..onUpdate = _onScaleUpdate
                  ..onEnd = _onScaleEnd,
              ),
        },
        child: ClipRect(
          child: Stack(fit: StackFit.expand, children: _layers(grid)),
        ),
      ),
    );
  }

  /// The one or two layouts on screen, back to front.
  ///
  /// Of the two, only the magnified one covers the whole viewport: the other
  /// is drawn below its own tile count, so it stops short of the trailing
  /// edge and of the bottom row. That one has to be the layer that fades, on
  /// top of the other — the reverse would fade the covered layer away and
  /// leave the area the shrunken one never reaches empty, until it snapped
  /// into place at the end of the pinch.
  List<Widget> _layers(Widget grid) {
    final frozen = _frozenLayout;
    final liveIsMagnified = frozen == null || _renderColumns > _frozenColumns;
    final live = _CrossfadeLayer(
      key: const ValueKey('live'),
      columns: _columns,
      layoutColumns: _renderColumns.toDouble(),
      role: liveIsMagnified ? _LayerRole.solid : _LayerRole.arriving,
      // Captured from here, so the raster holds the plain layout at the size
      // it is laid out for — backing and all — and both layers scale by the
      // same rule.
      child: RepaintBoundary(
        key: _liveLayoutKey,
        child: ColoredBox(color: widget.backgroundColor, child: grid),
      ),
    );
    if (frozen == null) return [live];

    final outgoing = _CrossfadeLayer(
      key: const ValueKey('frozen'),
      columns: _columns,
      layoutColumns: _frozenColumns.toDouble(),
      role: liveIsMagnified ? _LayerRole.leaving : _LayerRole.solid,
      child: IgnorePointer(
        child: RawImage(image: frozen, fit: BoxFit.fill),
      ),
    );
    return liveIsMagnified ? [live, outgoing] : [outgoing, live];
  }
}

/// What a layer does over the course of one step.
enum _LayerRole {
  /// Underneath and fully opaque. Always the magnified layout, the only one
  /// that reaches every edge of the viewport.
  solid,

  /// Fading in over [solid], on its way to becoming the next step.
  arriving,

  /// Fading out over [solid], on its way off screen.
  leaving,
}

/// One of the two layouts on screen during a step.
///
/// [child] is laid out for [layoutColumns] columns and scaled to the tile size
/// the current fractional count asks for, anchored top-left so the columns
/// stay pinned to the leading edge and the count changes at the trailing one.
/// Unless it is [_LayerRole.solid] it also carries the crossfade, driven by
/// how far the pinch has come rather than by a clock.
class _CrossfadeLayer extends StatelessWidget {
  const _CrossfadeLayer({
    required this.columns,
    required this.layoutColumns,
    required this.role,
    required this.child,
    super.key,
  });

  /// Share of the way between the two steps that the crossfade takes.
  ///
  /// Deliberately short of all of it. Run to the very end, the fade is still
  /// finishing its last percent when the outgoing layer is taken off screen —
  /// and by then the settle has slowed almost to a stop, so that last percent
  /// reads as a blink. Finishing early means the layer being removed has been
  /// invisible for a while.
  static const _fadeSpan = 0.85;

  final ValueListenable<double> columns;
  final double layoutColumns;
  final _LayerRole role;
  final Widget child;

  double _opacityAt(double value) {
    final distance = (value - layoutColumns).abs();
    return switch (role) {
      _LayerRole.solid => 1,
      _LayerRole.leaving => (1 - distance / _fadeSpan).clamp(0.0, 1.0),
      _LayerRole.arriving => ((1 - distance) / _fadeSpan).clamp(0.0, 1.0),
    };
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<double>(
      valueListenable: columns,
      // Always an Opacity around a Transform, even at 1: dropping either would
      // remount the subtree, and for the live grid that means losing its
      // scroll position.
      builder: (context, value, child) => Opacity(
        opacity: _opacityAt(value),
        child: Transform.scale(
          scale: value <= 0 ? 1.0 : layoutColumns / value,
          alignment: Alignment.topLeft,
          child: child,
        ),
      ),
      child: child,
    );
  }
}

/// A [ScaleGestureRecognizer] tuned for a grid that lives inside other
/// draggable surfaces.
///
/// Two changes to the stock behaviour:
///
/// * It never claims a one-finger gesture, which would otherwise stop the
///   grid from scrolling at all.
/// * It claims a two-finger gesture earlier than the stock recognizer does.
///   [computeScaleSlop] is a fixed 18 logical pixels while a competing drag —
///   a `TabBarView` page swipe, say — uses the device's own touch slop, which
///   is around 8 on Android. The stock recognizer therefore loses the arena
///   to the page swipe on every pinch. Deriving the threshold from the same
///   device slop puts it back in front.
class _PinchGestureRecognizer extends ScaleGestureRecognizer {
  _PinchGestureRecognizer({super.debugOwner});

  /// Fraction of the competing drag threshold at which the pinch claims the
  /// gesture.
  static const _slopFactor = 0.6;

  final _positions = <int, Offset>{};
  double? _initialSpan;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    _track(event);
    super.addAllowedPointer(event);
  }

  @override
  void handleEvent(PointerEvent event) {
    _track(event);
    super.handleEvent(event);

    if (_positions.length < 2) return;
    final span = _span();
    final initialSpan = _initialSpan ??= span;
    if ((span - initialSpan).abs() >
        computeHitSlop(event.kind, gestureSettings) * _slopFactor) {
      resolve(GestureDisposition.accepted);
    }
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _positions.clear();
    _initialSpan = null;
    super.didStopTrackingLastPointer(pointer);
  }

  @override
  void resolve(GestureDisposition disposition) {
    if (disposition == GestureDisposition.accepted && pointerCount < 2) {
      // Stay in the arena as a candidate: the recognizer retries on every
      // pointer event, so the pinch is still picked up if a second finger
      // lands before another recognizer wins.
      return;
    }
    super.resolve(disposition);
  }

  void _track(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      _positions.remove(event.pointer);
    } else {
      _positions[event.pointer] = event.position;
    }
    // The span is only comparable within one finger configuration.
    if (event is PointerDownEvent ||
        event is PointerUpEvent ||
        event is PointerCancelEvent) {
      _initialSpan = null;
    }
  }

  double _span() {
    final focal =
        _positions.values.reduce((a, b) => a + b) /
        _positions.length.toDouble();
    var total = 0.0;
    for (final position in _positions.values) {
      total += (position - focal).distance;
    }
    return total / _positions.length;
  }
}
