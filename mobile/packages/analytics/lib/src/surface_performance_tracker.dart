// ABOUTME: Tracks user-visible surface load timing with semantic analytics.
// ABOUTME: Emits safe terminal surface_load events for sheets and panels.

import 'package:analytics/src/analytics_event_sink.dart';
import 'package:analytics/src/analytics_surface.dart';
import 'package:analytics/src/firebase_analytics_event_sink.dart';
import 'package:analytics/src/page_load_history.dart';
import 'package:unified_logger/unified_logger.dart';

/// Maximum age for a session before it is considered stale and discarded.
///
/// App background/resume cycles can leave old sessions active. Dropping
/// sessions older than this avoids logging inflated load times.
const _maxSurfaceSessionAge = Duration(seconds: 60);

const _surfaceLoadEventName = 'surface_load';

const Set<String> _safeSurfaceParamKeys = {
  AnalyticsParam.entryPoint,
  AnalyticsParam.initialCount,
  AnalyticsParam.itemCount,
  AnalyticsParam.hasMore,
  AnalyticsParam.featureFlag,
  AnalyticsParam.sortMode,
  AnalyticsParam.configId,
  AnalyticsParam.tab,
};

/// Tracks perceived load performance for user-visible surfaces.
class SurfacePerformanceTracker {
  /// Creates a tracker writing timing records into [history].
  ///
  /// Defaults to the Firebase analytics sink in production; pass a [sink]
  /// (e.g. [NoOpAnalyticsEventSink]) and [now] clock in tests.
  SurfacePerformanceTracker({
    required PageLoadHistory history,
    AnalyticsEventSink? sink,
    DateTime Function()? now,
  }) : _history = history,
       _sink = sink ?? FirebaseAnalyticsEventSink(),
       _now = now ?? DateTime.now;

  final PageLoadHistory _history;
  AnalyticsEventSink _sink;
  final DateTime Function() _now;
  final Map<String, _SurfaceLoadSession> _activeSessions = {};

  /// Number of active tracking sessions.
  int get activeSessionCount => _activeSessions.length;

  /// Clear all active sessions.
  ///
  /// Call this when the app resumes from background to prevent stale start
  /// times from producing inaccurate surface load measurements.
  void resetAllSessions() {
    if (_activeSessions.isNotEmpty) {
      UnifiedLogger.info(
        'Resetting ${_activeSessions.length} stale surface '
        'performance sessions on app resume',
        name: 'SurfacePerf',
      );
      _activeSessions.clear();
    }
  }

  /// Start tracking a surface load.
  void startSurfaceLoad(String surfaceName, {Map<String, Object>? params}) {
    final safeName = AnalyticsSurface.sanitizeName(surfaceName);
    _activeSessions[safeName] = _SurfaceLoadSession(
      surfaceName: safeName,
      startedAt: _now(),
      params: _safeParameters(params),
    );

    UnifiedLogger.info('Surface load started: $safeName', name: 'SurfacePerf');
  }

  /// Mark when the surface is first visible.
  void markSurfaceVisible(String surfaceName) {
    final session = _sessionFor(surfaceName);
    if (session == null) return;

    session.visibleAt ??= _now();
    final visibleMs = session.visibleAt!
        .difference(session.startedAt)
        .inMilliseconds;

    UnifiedLogger.info(
      'Surface visible: ${session.surfaceName} in ${visibleMs}ms',
      name: 'SurfacePerf',
    );
  }

  /// Complete the surface load with a terminal result.
  ///
  /// Missing or stale sessions are ignored. Completion always removes the
  /// active session so dismissed/failed surfaces do not leak.
  Future<void> completeSurfaceLoad(
    String surfaceName, {
    required String result,
    Map<String, Object>? metrics,
  }) async {
    final safeName = AnalyticsSurface.sanitizeName(surfaceName);
    final session = _activeSessions.remove(safeName);
    if (session == null) return;

    if (_isStale(session)) {
      _logStaleDiscard(session);
      return;
    }

    final completedAt = _now();
    final visibleMs = session.visibleAt == null
        ? -1
        : session.visibleAt!.difference(session.startedAt).inMilliseconds;
    final totalMs = completedAt.difference(session.startedAt).inMilliseconds;
    final dataMs = result == SurfaceLoadResult.dismissed ? -1 : totalMs;
    final slowBucket = AnalyticsSurface.slowBucket(totalMs);

    final parameters = <String, Object>{
      AnalyticsParam.surfaceName: safeName,
      AnalyticsParam.result: result,
      AnalyticsParam.visibleMs: visibleMs,
      AnalyticsParam.dataMs: dataMs,
      AnalyticsParam.totalMs: totalMs,
      AnalyticsParam.slowBucket: slowBucket,
      ...session.params,
      ..._safeParameters(metrics),
    };

    await _logSurfaceLoad(parameters);
    _history.addOrUpdate(
      PageLoadRecord(
        screenName: safeName,
        timestamp: session.startedAt,
        contentVisibleMs: visibleMs >= 0 ? visibleMs : null,
        dataLoadedMs: dataMs >= 0 ? dataMs : null,
        result: result,
        source: PageLoadSource.surface,
        dataMetrics: {
          AnalyticsParam.slowBucket: slowBucket,
          ...session.params,
          ..._safeParameters(metrics),
        },
      ),
    );

    final slowFlag = totalMs >= 3000 ? ' [SLOW]' : '';
    UnifiedLogger.info(
      'PERF: $safeName surface result=$result visible=${visibleMs}ms, '
      'data=${dataMs}ms, total=${totalMs}ms$slowFlag',
      name: 'SurfacePerf',
    );
  }

  _SurfaceLoadSession? _sessionFor(String surfaceName) {
    final safeName = AnalyticsSurface.sanitizeName(surfaceName);
    final session = _activeSessions[safeName];
    if (session == null) return null;

    if (_isStale(session)) {
      _activeSessions.remove(safeName);
      _logStaleDiscard(session);
      return null;
    }

    return session;
  }

  bool _isStale(_SurfaceLoadSession session) {
    return _now().difference(session.startedAt) > _maxSurfaceSessionAge;
  }

  Future<void> _logSurfaceLoad(Map<String, Object> parameters) async {
    try {
      await _sink.logEvent(name: _surfaceLoadEventName, parameters: parameters);
    } catch (error) {
      _sink = const NoOpAnalyticsEventSink();
      UnifiedLogger.warning(
        'Surface performance analytics disabled after log failure: $error',
        name: 'SurfacePerf',
      );
    }
  }

  void _logStaleDiscard(_SurfaceLoadSession session) {
    final age = _now().difference(session.startedAt);
    UnifiedLogger.warning(
      'Discarding stale surface session "${session.surfaceName}" '
      '(started ${age.inSeconds}s ago)',
      name: 'SurfacePerf',
    );
  }

  static Map<String, Object> _safeParameters(Map<String, Object>? parameters) {
    if (parameters == null) return const {};

    final safe = <String, Object>{};
    for (final entry in parameters.entries) {
      if (!_safeSurfaceParamKeys.contains(entry.key)) continue;

      final value = _firebaseSafeValue(entry.value);
      if (value != null) {
        safe[entry.key] = value;
      }
    }
    return safe;
  }

  static Object? _firebaseSafeValue(Object value) {
    if (value is bool) return value ? 1 : 0;
    if (value is String || value is num) return value;
    return null;
  }
}

class _SurfaceLoadSession {
  _SurfaceLoadSession({
    required this.surfaceName,
    required this.startedAt,
    required this.params,
  });

  final String surfaceName;
  final DateTime startedAt;
  final Map<String, Object> params;
  DateTime? visibleAt;
}
