// ABOUTME: Reports the sound picker's tab loads, relay searches and picks.
// ABOUTME: Sends fixed vocabulary only: no query text, ids, pubkeys or titles.

import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:openvine/observability/performance_operation.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:sounds_repository/sounds_repository.dart'
    show SoundSearchRelays, SoundSearchSource;
import 'package:unified_logger/unified_logger.dart';

/// The sound picker's list tabs, as its load telemetry names them.
enum SoundPickerTab { forYou, popular, newest, mySounds }

/// Where a picked sound came from: one of the picker's tabs, or a file the
/// user imported.
enum SoundPickSource { forYou, popular, newest, mySounds, imported }

/// How picking a sound ended.
enum SoundPickOutcome {
  /// The user confirmed the sound, and the picker handed it to the editor.
  attached,

  /// The reuse check refused the sound: its creator does not allow reuse, or
  /// the check could not be completed and failed closed.
  reuseBlocked,

  /// The sound's file could not be downloaded for the preview.
  downloadFailed,

  /// Anything else that stopped the pick: an import the app could not read,
  /// or a preview that would not play.
  failed,
}

/// Telemetry for one open sound picker.
///
/// Reports three things, each at most once per user action:
///
/// * `surface_load` for [AnalyticsSurface.soundPicker], once per tab: the
///   time from the tab opening until its list first shows.
/// * A `sound_search` Firebase Performance trace per search, from the
///   debounced query until its first page arrives, with the `source` that
///   answered it: Funnelcake, or the relays it falls back to. A search the
///   relays did not answer either, which the picker covers with cached
///   matches, ends as `fallback`, so it never counts as a result.
/// * A `sound_selected` Analytics event when a pick is attached, refused or
///   fails.
///
/// Create one per picker and call [dispose] when it closes.
class SoundPickerTelemetry {
  SoundPickerTelemetry({
    required SurfacePerformanceTracker surfaceTracker,
    required AnalyticsEventSink analytics,
    required PerformanceTraceMonitor performanceMonitor,
  }) : _surfaceTracker = surfaceTracker,
       _analytics = analytics,
       _performanceMonitor = performanceMonitor;

  /// The Firebase Performance trace timing a search.
  static const searchTraceName = 'sound_search';

  /// The Analytics event reporting how a pick ended.
  static const soundSelectedEvent = 'sound_selected';

  final SurfacePerformanceTracker _surfaceTracker;
  final AnalyticsEventSink _analytics;
  final PerformanceTraceMonitor _performanceMonitor;

  /// The tab whose load is being timed.
  SoundPickerTab? _loadingTab;

  /// Tabs whose list showed, which are not timed again.
  final _shownTabs = <SoundPickerTab>{};

  PerformanceOperation? _search;
  final _searchStopwatch = Stopwatch();

  /// Starts timing [tab], which just opened, until its list first shows.
  ///
  /// A different tab still being timed is reported dismissed: the user left
  /// it before its list showed. A tab whose list already showed in this
  /// picker, or that is being timed, is not timed again. [isFirstTab] says
  /// the tab opened with the picker rather than by switching to it.
  ///
  /// Returns whether timing started.
  bool startTabLoad(SoundPickerTab tab, {required bool isFirstTab}) {
    if (_loadingTab == tab) return false;
    _dismissTabLoad();
    if (_shownTabs.contains(tab)) return false;
    _loadingTab = tab;
    _surfaceTracker.startSurfaceLoad(
      AnalyticsSurface.soundPicker,
      params: {
        AnalyticsParam.tab: _tabValue(tab),
        AnalyticsParam.entryPoint: isFirstTab ? 'sheet_open' : 'tab_switch',
      },
    );
    return true;
  }

  /// Marks the first frame drawn after [tab] started loading.
  void markTabVisible(SoundPickerTab tab) {
    if (_loadingTab != tab) return;
    _surfaceTracker.markSurfaceVisible(AnalyticsSurface.soundPicker);
  }

  /// Reports that [tab] shows its list of [itemCount] sounds.
  ///
  /// [wasLoaded] says the list was loaded before the tab opened, as a
  /// preloaded or earlier list is: it shows at once rather than after a load.
  void completeTabLoad(
    SoundPickerTab tab, {
    required int itemCount,
    required bool wasLoaded,
    bool? hasMore,
  }) {
    if (_loadingTab != tab) return;
    _loadingTab = null;
    _shownTabs.add(tab);
    unawaited(
      _surfaceTracker.completeSurfaceLoad(
        AnalyticsSurface.soundPicker,
        result: itemCount == 0
            ? SurfaceLoadResult.empty
            : SurfaceLoadResult.success,
        metrics: {
          AnalyticsParam.itemCount: itemCount,
          AnalyticsParam.initialCount: wasLoaded ? itemCount : 0,
          AnalyticsParam.hasMore: ?hasMore,
        },
      ),
    );
  }

  /// Reports that [tab]'s list failed to load.
  void failTabLoad(SoundPickerTab tab) {
    if (_loadingTab != tab) return;
    _loadingTab = null;
    _shownTabs.add(tab);
    unawaited(
      _surfaceTracker.completeSurfaceLoad(
        AnalyticsSurface.soundPicker,
        result: SurfaceLoadResult.failure,
      ),
    );
  }

  /// Starts timing a search. One still in flight is reported
  /// abandoned: the user searched for something else before it answered.
  void startSearch() {
    abandonSearch();
    _search = PerformanceOperation(_performanceMonitor, searchTraceName);
    _searchStopwatch
      ..reset()
      ..start();
  }

  /// Reports that the search in flight answered with [resultCount] sounds on
  /// its first page, who answered it, and how the relays answered it.
  ///
  /// An answer from Funnelcake or the relays is `results` or `empty`.
  /// Otherwise the sounds are cached matches standing in for the relays, and
  /// the search ends as `fallback`, with [relays] as its `reason`.
  void completeSearch(
    int resultCount, {
    required SoundSearchSource source,
    required SoundSearchRelays relays,
  }) {
    final reason = source == SoundSearchSource.funnelcake
        ? null
        : _fallbackReason(relays);
    _finishSearch(
      reason != null
          ? 'fallback'
          : resultCount == 0
          ? 'empty'
          : 'results',
      source: source,
      reason: reason,
      resultCount: resultCount,
    );
  }

  /// Reports that the search in flight failed.
  void failSearch() => _finishSearch('failure');

  /// Reports that the search in flight will not be waited for: the query
  /// changed, its tab closed, or the picker did.
  void abandonSearch() => _finishSearch('abandoned');

  /// Reports how picking a sound from [source] ended. [searched] says a
  /// search narrowed the list when the sound was picked.
  void reportPick({
    required SoundPickSource source,
    required SoundPickOutcome outcome,
    required bool searched,
  }) {
    final parameters = <String, Object>{
      'source': _sourceValue(source),
      'outcome': _outcomeValue(outcome),
      'searched': searched ? 1 : 0,
    };
    Log.info(
      'Sound pick: $parameters',
      name: 'SoundPickerTelemetry',
      category: LogCategory.ui,
    );
    unawaited(_logEvent(soundSelectedEvent, parameters));
  }

  /// Ends whatever is still being timed: a loading tab as dismissed, a
  /// search in flight as abandoned.
  void dispose() {
    _dismissTabLoad();
    abandonSearch();
  }

  void _dismissTabLoad() {
    if (_loadingTab == null) return;
    _loadingTab = null;
    unawaited(
      _surfaceTracker.completeSurfaceLoad(
        AnalyticsSurface.soundPicker,
        result: SurfaceLoadResult.dismissed,
      ),
    );
  }

  void _finishSearch(
    String outcome, {
    SoundSearchSource? source,
    String? reason,
    int? resultCount,
  }) {
    final search = _search;
    if (search == null) return;
    _search = null;
    _searchStopwatch.stop();
    Log.info(
      'Sound search: outcome=$outcome, source=${source?.name ?? '-'}, '
      'reason=${reason ?? '-'}, results=${resultCount ?? '-'}, '
      '${_searchStopwatch.elapsedMilliseconds}ms',
      name: 'SoundPickerTelemetry',
      category: LogCategory.ui,
    );
    search.finish(
      attributes: {
        'outcome': outcome,
        'source': ?source?.name,
        'reason': ?reason,
        if (resultCount != null) 'result_bucket': _resultBucket(resultCount),
      },
      metrics: {'result_count': ?resultCount},
    );
  }

  Future<void> _logEvent(String name, Map<String, Object> parameters) async {
    try {
      await _analytics.logEvent(name: name, parameters: parameters);
    } on Object catch (error) {
      Log.warning(
        'Failed to log $name: $error',
        name: 'SoundPickerTelemetry',
        category: LogCategory.ui,
      );
    }
  }

  static String _tabValue(SoundPickerTab tab) => switch (tab) {
    SoundPickerTab.forYou => 'for_you',
    SoundPickerTab.popular => 'popular',
    SoundPickerTab.newest => 'newest',
    SoundPickerTab.mySounds => 'my_sounds',
  };

  static String _sourceValue(SoundPickSource source) => switch (source) {
    SoundPickSource.forYou => 'for_you',
    SoundPickSource.popular => 'popular',
    SoundPickSource.newest => 'newest',
    SoundPickSource.mySounds => 'my_sounds',
    SoundPickSource.imported => 'import',
  };

  static String _outcomeValue(SoundPickOutcome outcome) => switch (outcome) {
    SoundPickOutcome.attached => 'attached',
    SoundPickOutcome.reuseBlocked => 'reuse_blocked',
    SoundPickOutcome.downloadFailed => 'download_failed',
    SoundPickOutcome.failed => 'failed',
  };

  /// Why the relays did not answer a search, or null when they did.
  static String? _fallbackReason(SoundSearchRelays relays) => switch (relays) {
    SoundSearchRelays.answered => null,
    SoundSearchRelays.timedOut => 'timed_out',
    SoundSearchRelays.noRelays => 'no_relays',
    SoundSearchRelays.failed => 'relay_error',
    SoundSearchRelays.notAsked => 'not_asked',
  };

  static String _resultBucket(int count) => switch (count) {
    0 => '0',
    <= 10 => '1_10',
    <= 50 => '11_50',
    _ => 'over_50',
  };
}
