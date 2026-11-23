// ABOUTME: Reports a screen_frames trace for the screen it wraps.
// ABOUTME: Ends each visit when an opaque route covers it or the app leaves.

import 'dart:ui' show FlutterView;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/observability/screen_frame_trace.dart';
import 'package:openvine/providers/service_providers.dart';

/// Measures how smoothly [child] draws while it is on screen, as a
/// [ScreenFrameTrace] for [screen].
///
/// The screen counts as covered while its tickers are off, which is what an
/// opaque route on top does once its transition ends. Dialogs and sheets are
/// not opaque, so their frames count towards the screen beneath them, as do
/// the frames of a transition to or from the screen.
class ScreenFrameTraceScope extends ConsumerStatefulWidget {
  const ScreenFrameTraceScope({
    required this.screen,
    required this.child,
    this.timings,
    super.key,
  });

  final TracedScreen screen;
  final Widget child;

  /// Replaces the engine's frame timings in tests.
  @visibleForTesting
  final FrameTimingsSource? timings;

  @override
  ConsumerState<ScreenFrameTraceScope> createState() =>
      _ScreenFrameTraceScopeState();
}

class _ScreenFrameTraceScopeState extends ConsumerState<ScreenFrameTraceScope> {
  ScreenFrameTrace? _trace;
  AppLifecycleListener? _lifecycle;
  ValueListenable<TickerModeData>? _tickerMode;
  FlutterView? _view;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _view = View.of(context);
    final state = WidgetsBinding.instance.lifecycleState;
    _trace ??= ScreenFrameTrace(
      ref.read(performanceMonitoringServiceProvider),
      screen: widget.screen,
      refreshRate: () => _view?.display.refreshRate ?? 0,
      foreground: ScreenFrameTrace.isForeground(state),
      covered:
          _canReadCoverage(state) &&
          !TickerMode.getValuesNotifier(context).value.enabled,
      timings: widget.timings ?? const SchedulerFrameTimingsSource(),
    );
    _lifecycle ??= AppLifecycleListener(
      onStateChange: _onLifecycleChanged,
    );
    _watchTickerMode();
  }

  @override
  void activate() {
    super.activate();
    _watchTickerMode();
  }

  /// Follows the [TickerMode] above this widget, which changes when it moves.
  void _watchTickerMode() {
    final tickerMode = TickerMode.getValuesNotifier(context);
    if (tickerMode != _tickerMode) {
      _tickerMode?.removeListener(_onTickerModeChanged);
      tickerMode.addListener(_onTickerModeChanged);
      _tickerMode = tickerMode;
    }
    _onTickerModeChanged();
  }

  void _onTickerModeChanged() {
    final tickerMode = _tickerMode;
    if (tickerMode == null ||
        !_canReadCoverage(WidgetsBinding.instance.lifecycleState)) {
      return;
    }
    _trace?.setCovered(!tickerMode.value.enabled);
  }

  // The app can mute every route's tickers while inactive, even though the
  // top route is still visible. Keep the last known coverage until resume.
  bool _canReadCoverage(AppLifecycleState? state) =>
      state == null || state == AppLifecycleState.resumed;

  void _onLifecycleChanged(AppLifecycleState state) {
    _trace?.setForeground(ScreenFrameTrace.isForeground(state));
    if (state == AppLifecycleState.resumed) {
      // Read after the app-wide ticker mode has been restored. A covered
      // route can remain muted and never get a notifier event on resume.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _onTickerModeChanged();
      });
    }
  }

  @override
  void dispose() {
    _tickerMode?.removeListener(_onTickerModeChanged);
    _lifecycle?.dispose();
    _trace?.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
