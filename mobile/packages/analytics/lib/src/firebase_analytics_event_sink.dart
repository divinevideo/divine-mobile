// ABOUTME: Firebase-backed implementation of the analytics event sink.

import 'package:analytics/src/analytics_collection_control.dart';
import 'package:analytics/src/analytics_event_sink.dart';
import 'package:firebase_analytics/firebase_analytics.dart';

/// Routes analytics events to Firebase Analytics.
///
/// The underlying [FirebaseAnalytics] instance is resolved lazily on first
/// use rather than at construction. Trackers create this sink as a field
/// initializer (often via app-wide singletons that are built well before
/// `Firebase.initializeApp()` in some contexts, and never initialized at all
/// under `flutter test`). Touching `FirebaseAnalytics.instance` eagerly would
/// throw `[core/no-app]` and crash those call sites; deferring — and
/// failing closed when Firebase is unavailable — keeps analytics a no-op
/// instead of a crash.
class FirebaseAnalyticsEventSink
    implements AnalyticsEventSink, AnalyticsCollectionControl {
  /// Creates the sink. Pass [analytics] in tests to assert on calls; otherwise
  /// the instance is resolved lazily from [FirebaseAnalytics.instance].
  FirebaseAnalyticsEventSink({FirebaseAnalytics? analytics})
    : _analyticsOverride = analytics;

  final FirebaseAnalytics? _analyticsOverride;
  FirebaseAnalytics? _resolved;

  /// Resolves the Firebase instance, returning null when Firebase has not been
  /// initialized (e.g. in tests) so callers degrade to a no-op.
  FirebaseAnalytics? get _analytics {
    if (_analyticsOverride != null) return _analyticsOverride;
    try {
      return _resolved ??= FirebaseAnalytics.instance;
    } catch (_) {
      return null;
    }
  }

  @override
  Future<void> setUserId(String? userId) async {
    await _analytics?.setUserId(id: userId);
  }

  @override
  Future<void> setCollectionEnabled({required bool enabled}) async {
    await _analytics?.setAnalyticsCollectionEnabled(enabled);
  }

  @override
  Future<void> resetAnalyticsData() async {
    await _analytics?.resetAnalyticsData();
  }

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async {
    await _analytics?.setUserProperty(name: name, value: value);
  }

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    await _analytics?.logEvent(name: name, parameters: parameters);
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {
    await _analytics?.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
      parameters: parameters,
    );
  }
}
