// ABOUTME: Reports a screen_frames trace for the screen it wraps.
// ABOUTME: Ends a visit on an opaque route, a tab switch, or the app leaving.

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
/// opaque route on top does once its transition ends, and what the app shell
/// does to the tabs that are not selected; under a [ScreenFrameTraceTab] the
/// latter ends the visit as a tab switch. Dialogs and sheets are not opaque,
/// so their frames count towards the screen beneath them, as do the frames of
/// a transition to or from the screen.
///
/// Frames are drawn for the whole app, so a scope must not sit inside
/// another: both would count the same frames.
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

/// Tells the [ScreenFrameTraceScope]s in one tab of the app shell whether
/// that tab is selected, so that leaving it ends their visit as a tab switch
/// rather than as covered.
///
/// Must sit above the [TickerMode] that mutes the tab: the scopes read it the
/// moment their tickers go off.
class ScreenFrameTraceTab extends InheritedWidget {
  const ScreenFrameTraceTab({
    required this.selected,
    required super.child,
    super.key,
  });

  /// Whether the tab is the one on screen.
  final bool selected;

  /// Whether [context] is in a tab of the app shell that is not selected.
  static bool isInUnselectedTab(BuildContext context) =>
      context.getInheritedWidgetOfExactType<ScreenFrameTraceTab>()?.selected ==
      false;

  // Read without a dependency, when the tickers below change.
  @override
  bool updateShouldNotify(ScreenFrameTraceTab oldWidget) => false;
}

class _ScreenFrameTraceScopeState extends ConsumerState<ScreenFrameTraceScope> {
  ScreenFrameTrace? _trace;
  AppLifecycleListener? _lifecycle;
  ValueListenable<TickerModeData>? _tickerMode;
  FlutterView? _view;

  @override
  void didUpdateWidget(ScreenFrameTraceScope oldWidget) {
    super.didUpdateWidget(oldWidget);
    assert(
      widget.screen == oldWidget.screen,
      'Key each ScreenFrameTraceScope by its screen: the trace keeps the '
      'screen it was created for.',
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    assert(
      _trace != null ||
          context.findAncestorStateOfType<_ScreenFrameTraceScopeState>() ==
              null,
      'A ScreenFrameTraceScope inside another counts the same frames twice.',
    );
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
    final covered = !tickerMode.value.enabled;
    _trace?.setCovered(
      covered,
      byTabSwitch: covered && ScreenFrameTraceTab.isInUnselectedTab(context),
    );
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
