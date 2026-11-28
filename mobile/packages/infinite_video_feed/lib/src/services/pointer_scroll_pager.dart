/// Turns pointer scroll deltas into single page steps.
///
/// A mouse wheel notch arrives as one scroll event, and a browser reports a
/// trackpad swipe as a run of small scroll events that keeps going through the
/// swipe's momentum. Handed to a page view as they are, both move the page by
/// their delta and snap back, so the next page is never reached.
///
/// This adds up the deltas of one scroll gesture, answers a single step once
/// they pass a threshold, and ignores the rest of that gesture. A gesture ends
/// when no scroll event arrives for [gestureGap], so the momentum of a swipe
/// that already turned the page cannot turn it again.
class PointerScrollPager {
  /// Creates a pager that treats a pause of [gestureGap] between scroll events
  /// as the end of a gesture.
  PointerScrollPager({this.gestureGap = const Duration(milliseconds: 150)});

  /// How long the scroll events have to stop before the next one starts a new
  /// gesture.
  final Duration gestureGap;

  double _accumulated = 0;
  Duration? _lastEventTime;
  bool _steppedThisGesture = false;

  /// Records a scroll the feed does not claim, without counting its delta.
  ///
  /// A gesture keeps its place while the feed is at a boundary, even if more
  /// videos arrive before the gesture ends.
  void observe(Duration timeStamp) {
    final lastEventTime = _lastEventTime;
    _lastEventTime = timeStamp;
    if (lastEventTime == null || timeStamp - lastEventTime >= gestureGap) {
      _accumulated = 0;
      _steppedThisGesture = false;
    }
  }

  /// Adds one scroll event's [delta] along the page axis.
  ///
  /// Returns `1` to move to the next page, `-1` to move to the previous one,
  /// and `0` to stay.
  ///
  /// [timeStamp] is the event's time stamp. [threshold] is how far one gesture
  /// has to scroll before it steps; `0` steps on any movement. Pass
  /// [canStep] `false` while the page view is still moving, so scroll events
  /// during a page animation are dropped rather than stacked onto it; a gesture
  /// that has not stepped yet can still step once the page has settled.
  int add(
    double delta, {
    required Duration timeStamp,
    required double threshold,
    required bool canStep,
  }) {
    observe(timeStamp);
    if (_steppedThisGesture || !canStep || delta == 0) return 0;

    // A gesture that turns around starts counting again from its new
    // direction.
    if (_accumulated * delta < 0) _accumulated = 0;
    _accumulated += delta;
    if (_accumulated.abs() < threshold) return 0;

    final step = _accumulated > 0 ? 1 : -1;
    _accumulated = 0;
    _steppedThisGesture = true;
    return step;
  }
}
