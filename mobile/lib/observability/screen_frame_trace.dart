// ABOUTME: Measures how smoothly one screen draws while it is on screen.
// ABOUTME: Emits one screen_frames trace per visit, judged by the display's rate.

import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui'
    show AppLifecycleState, FramePhase, FrameTiming, TimingsCallback;

import 'package:clock/clock.dart';
import 'package:flutter/scheduler.dart';
import 'package:openvine/observability/performance_operation.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// The screens that report a `screen_frames` trace, as their `screen`
/// attribute.
enum TracedScreen { recorder, editor }

/// Where frame timings come from. Replaced in tests.
abstract interface class FrameTimingsSource {
  void addTimingsCallback(TimingsCallback callback);

  void removeTimingsCallback(TimingsCallback callback);

  /// The number of the frame being drawn, or of the last one drawn, as
  /// [FrameTiming.frameNumber] reports it. `null` where the platform does not
  /// number frames.
  int? get frameNumber;

  /// Whether a frame is being drawn, so that [frameNumber] is the first frame
  /// that shows a change made now.
  bool get drawingFrame;
}

/// Frame timings reported by the engine through [SchedulerBinding].
class SchedulerFrameTimingsSource implements FrameTimingsSource {
  const SchedulerFrameTimingsSource();

  @override
  void addTimingsCallback(TimingsCallback callback) =>
      SchedulerBinding.instance.addTimingsCallback(callback);

  @override
  void removeTimingsCallback(TimingsCallback callback) =>
      SchedulerBinding.instance.removeTimingsCallback(callback);

  @override
  int? get frameNumber {
    final number =
        SchedulerBinding.instance.platformDispatcher.frameData.frameNumber;
    return number < 0 ? null : number;
  }

  @override
  bool get drawingFrame => switch (SchedulerBinding.instance.schedulerPhase) {
    SchedulerPhase.persistentCallbacks ||
    SchedulerPhase.postFrameCallbacks => true,
    _ => false,
  };
}

/// Reports how smoothly one screen draws, as one `screen_frames` trace per
/// visit.
///
/// A visit is a stretch of time in which the screen is on screen with the app
/// in the foreground. It ends when the screen closes, when an opaque route
/// covers it, or when the app goes to the background, and a new visit starts
/// when the screen shows again. Visits shorter than [minimumVisible] or with
/// fewer than [minimumFrames] frames are not reported.
///
/// A frame is slow when it misses the display's frame budget — 16.7 ms at 60
/// Hz, 8.3 ms at 120 Hz — on either thread: the UI thread, counted from the
/// vsync signal so a UI isolate still busy with other work when the frame was
/// due counts too, or the raster thread. It is frozen when that takes longer
/// than 700 ms, Firebase's definition. Frozen frames are also slow.
///
/// The engine reports frame timings in batches up to a second late. A visit
/// keeps only the frames it showed in, by frame number, and one that ends in
/// a frame waits for the frames it showed in to arrive before it reports. One
/// that ends outside a frame — the app going to the background — reports at
/// once, as the app may not draw again before it is killed, and loses the
/// frames that were still to arrive.
///
/// Attributes: `screen` ([TracedScreen]), `refresh` (`60`, `90`, `120` or
/// `other`) and `end` (`closed`, `covered` or `background`). Metrics:
/// `frames`, `slow_frames`, `frozen_frames`, `slow_per_mille`, `visible_ms`,
/// and the 90th percentile of the UI thread's time from vsync to the end of
/// the build (`build_p90_us`) and of the raster time (`raster_p90_us`).
///
/// The Firebase trace starts and stops when the visit reports, so its own
/// duration means nothing; `visible_ms` is the visit's length.
class ScreenFrameTrace {
  /// Starts a visit at once unless the screen starts [covered] or the app is
  /// not in the [foreground].
  ///
  /// [refreshRate] is read when each visit starts.
  ScreenFrameTrace(
    PerformanceTraceMonitor monitor, {
    required this.screen,
    required double Function() refreshRate,
    required bool foreground,
    bool covered = false,
    FrameTimingsSource timings = const SchedulerFrameTimingsSource(),
  }) : _monitor = monitor,
       _refreshRate = refreshRate,
       _timings = timings,
       _foreground = foreground,
       _covered = covered {
    _sync(_VisitEnd.closed);
  }

  static const traceName = 'screen_frames';

  /// Visits shorter than this are not reported.
  static const minimumVisible = Duration(seconds: 1);

  /// Visits with fewer frames than this are not reported.
  static const minimumFrames = 10;

  /// Firebase's threshold for a frozen frame.
  static const int frozenFrameMicros =
      700 * Duration.microsecondsPerMillisecond;

  /// How many timing batches a visit that ended waits for its last frames
  /// before it reports without them.
  static const _batchesBeforeGivingUp = 2;

  final TracedScreen screen;
  final PerformanceTraceMonitor _monitor;
  final double Function() _refreshRate;
  final FrameTimingsSource _timings;

  bool _foreground;
  bool _covered;
  bool _closed = false;

  /// The visit in progress, if any.
  _FrameVisit? _active;

  /// The visit in progress and those still waiting for their last frames,
  /// oldest first.
  final List<_FrameVisit> _visits = [];

  bool _listening = false;

  /// The highest frame number the engine reported while listening.
  int _latestFrame = -1;

  /// Whether the app is in the foreground in [state].
  ///
  /// `inactive` counts: the app still draws behind a system prompt or the
  /// app switcher.
  static bool isForeground(AppLifecycleState? state) => switch (state) {
    null || AppLifecycleState.resumed || AppLifecycleState.inactive => true,
    _ => false,
  };

  /// The `refresh` attribute for a display running at [hz].
  static String refreshBucket(double hz) {
    for (final bucket in const [60, 90, 120]) {
      if ((hz - bucket).abs() <= 3) return '$bucket';
    }
    return 'other';
  }

  /// The time a frame has at [hz] before it misses the display, in
  /// microseconds. 60 Hz when the rate is unknown.
  static int frameBudgetMicros(double hz) {
    final rate = hz.isFinite && hz > 0 ? hz : 60;
    return (Duration.microsecondsPerSecond / rate).round();
  }

  /// Records whether an opaque route covers the screen.
  void setCovered(bool covered) {
    if (_covered == covered) return;
    _covered = covered;
    _sync(_VisitEnd.covered);
  }

  /// Records whether the app is in the foreground.
  void setForeground(bool foreground) {
    if (_foreground == foreground) return;
    _foreground = foreground;
    _sync(_VisitEnd.background);
  }

  /// Ends the visit in progress for good. Later calls do nothing.
  void close() {
    if (_closed) return;
    _closed = true;
    _sync(_VisitEnd.closed);
  }

  bool get _visible => !_closed && !_covered && _foreground;

  void _sync(_VisitEnd reason) {
    final active = _active;
    if (_visible) {
      if (active == null) _begin();
    } else if (active != null) {
      _end(active, reason);
    }
  }

  void _begin() {
    final frame = _timings.frameNumber;
    final visit = _FrameVisit(
      firstFrame: frame == null || _timings.drawingFrame ? frame : frame + 1,
      refreshRate: _refreshRate(),
    );
    _active = visit;
    _visits.add(visit);
    if (_listening) return;
    _listening = true;
    _timings.addTimingsCallback(_onTimings);
  }

  void _end(_FrameVisit visit, _VisitEnd reason) {
    _active = null;
    visit.end(reason);
    final frame = _timings.frameNumber;
    if (frame != null && visit.firstFrame != null && _timings.drawingFrame) {
      // The frame being drawn no longer shows the screen.
      visit.endFrame = frame;
      if (_latestFrame < frame - 1) return;
    }
    _report(visit);
  }

  void _onTimings(List<FrameTiming> timings) {
    for (var i = 0; i < timings.length; i++) {
      final timing = timings[i];
      final number = timing.frameNumber;
      if (number > _latestFrame) _latestFrame = number;
      for (var v = 0; v < _visits.length; v++) {
        final visit = _visits[v];
        if (visit.shows(number)) {
          visit.add(timing);
          break;
        }
      }
    }
    for (var v = _visits.length - 1; v >= 0; v--) {
      final visit = _visits[v];
      final endFrame = visit.endFrame;
      if (endFrame == null) continue;
      if (_latestFrame >= endFrame - 1 ||
          ++visit.batchesAfterEnd >= _batchesBeforeGivingUp) {
        _report(visit);
      }
    }
  }

  void _report(_FrameVisit visit) {
    _visits.remove(visit);
    if (_visits.isEmpty && _listening) {
      _listening = false;
      _timings.removeTimingsCallback(_onTimings);
    }
    final sample = visit.sample(screen);
    if (sample == null) return;
    // Builds that do not report to Firebase still show the sample here.
    Log.info(
      '$traceName ${sample.attributes} ${sample.metrics}',
      name: 'ScreenFrameTrace',
      category: LogCategory.ui,
    );
    PerformanceOperation(
      _monitor,
      traceName,
    ).finish(attributes: sample.attributes, metrics: sample.metrics);
  }
}

/// How a visit ended, as its `end` attribute.
enum _VisitEnd { covered, background, closed }

/// The frames of one visit.
final class _FrameVisit {
  _FrameVisit({required this.firstFrame, required double refreshRate})
    : _refresh = ScreenFrameTrace.refreshBucket(refreshRate),
      _budgetMicros = ScreenFrameTrace.frameBudgetMicros(refreshRate);

  /// The first frame the screen showed in, or `null` when frames are not
  /// numbered and every reported frame counts.
  final int? firstFrame;

  /// The first frame after the visit, once it ended in a frame.
  int? endFrame;

  int batchesAfterEnd = 0;

  final String _refresh;
  final int _budgetMicros;
  final Stopwatch _visible = clock.stopwatch()..start();
  _VisitEnd? _end;

  int _frames = 0;
  int _slowFrames = 0;
  int _frozenFrames = 0;
  final _FrameHistogram _build = _FrameHistogram();
  final _FrameHistogram _raster = _FrameHistogram();

  /// Whether frame [number] belongs to this visit.
  bool shows(int number) {
    final first = firstFrame;
    if (first == null) return true;
    final end = endFrame;
    return number >= first && (end == null || number < end);
  }

  void add(FrameTiming timing) {
    final build =
        timing.timestampInMicroseconds(FramePhase.buildFinish) -
        timing.timestampInMicroseconds(FramePhase.vsyncStart);
    final raster =
        timing.timestampInMicroseconds(FramePhase.rasterFinish) -
        timing.timestampInMicroseconds(FramePhase.rasterStart);
    final frame = math.max(build, raster);
    _frames++;
    if (frame > _budgetMicros) _slowFrames++;
    if (frame > ScreenFrameTrace.frozenFrameMicros) _frozenFrames++;
    _build.add(build);
    _raster.add(raster);
  }

  void end(_VisitEnd reason) {
    _end = reason;
    _visible.stop();
  }

  /// The trace fields of this visit, or `null` when it is too short to tell
  /// anything.
  ({Map<String, String> attributes, Map<String, int> metrics})? sample(
    TracedScreen screen,
  ) {
    final visibleMs = _visible.elapsedMilliseconds;
    if (visibleMs < ScreenFrameTrace.minimumVisible.inMilliseconds ||
        _frames < ScreenFrameTrace.minimumFrames) {
      return null;
    }
    return (
      attributes: {
        'screen': screen.name,
        'refresh': _refresh,
        'end': (_end ?? _VisitEnd.closed).name,
      },
      metrics: {
        'frames': _frames,
        'slow_frames': _slowFrames,
        'frozen_frames': _frozenFrames,
        'slow_per_mille': _slowFrames * 1000 ~/ _frames,
        'visible_ms': visibleMs,
        'build_p90_us': _build.percentile(90),
        'raster_p90_us': _raster.percentile(90),
      },
    );
  }
}

/// Frame durations in fixed buckets, so a frame costs one increment.
///
/// Quarter-millisecond buckets up to 32 ms, where nearly every frame falls,
/// then 2 ms buckets up to 288 ms; longer frames share the last bucket.
final class _FrameHistogram {
  static const _fineWidth = 250;
  static const _fineBuckets = 128;
  static const int _fineLimit = _fineWidth * _fineBuckets;
  static const _coarseWidth = 2000;
  static const _coarseBuckets = 128;
  static const int _coarseLimit = _fineLimit + _coarseWidth * _coarseBuckets;

  final _counts = Uint32List(_fineBuckets + _coarseBuckets + 1);
  int _total = 0;
  int _longest = 0;

  void add(int micros) {
    final value = math.max(micros, 0);
    final bucket = value < _fineLimit
        ? value ~/ _fineWidth
        : value < _coarseLimit
        ? _fineBuckets + (value - _fineLimit) ~/ _coarseWidth
        : _counts.length - 1;
    _counts[bucket]++;
    _total++;
    if (value > _longest) _longest = value;
  }

  /// The duration [percent] percent of the frames took at most, as the upper
  /// edge of its bucket and never longer than the longest frame.
  int percentile(int percent) {
    final rank = (_total * percent + 99) ~/ 100;
    var seen = 0;
    for (var bucket = 0; bucket < _counts.length; bucket++) {
      seen += _counts[bucket];
      if (seen >= rank) return math.min(_upperEdge(bucket), _longest);
    }
    return _longest;
  }

  int _upperEdge(int bucket) {
    if (bucket < _fineBuckets) return (bucket + 1) * _fineWidth;
    if (bucket < _fineBuckets + _coarseBuckets) {
      return _fineLimit + (bucket - _fineBuckets + 1) * _coarseWidth;
    }
    return _longest;
  }
}
