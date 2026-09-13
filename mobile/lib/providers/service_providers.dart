// ABOUTME: Riverpod providers for infrastructure services migrated off the
// ABOUTME: lazy-static singleton pattern to constructor injection (#4743).

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:openvine/observability/network/firebase_http_metric_recorder.dart';
import 'package:openvine/observability/network/http_metric_recorder.dart';
import 'package:openvine/observability/network/performance_http_client.dart';
import 'package:openvine/services/logging_config_service.dart';
import 'package:openvine/services/nip07_service.dart';
import 'package:openvine/services/performance_monitoring_service.dart';
import 'package:openvine/services/top_hashtags_service.dart';

/// Provides the app's [LoggingConfigService].
///
/// Replaces the former `LoggingConfigService.instance` singleton so the
/// service can be overridden with a fake in tests instead of reaching into
/// static state. Kept alive for the app's lifetime (logging config is global).
final loggingConfigServiceProvider = Provider<LoggingConfigService>(
  (ref) => LoggingConfigService(),
);

/// Provides the app's shared [TopHashtagsService].
///
/// Replaces the former `TopHashtagsService.instance` singleton. A single
/// shared instance is kept alive so the in-memory hashtag list loaded by one
/// consumer (e.g. the explore cubit warming the cache) is visible to the
/// others (the hashtag repository and the popular-videos tab).
final topHashtagsServiceProvider = Provider<TopHashtagsService>(
  (ref) => TopHashtagsService(),
);

/// Provides the app's shared [Nip07Service], the bridge to a NIP-07 browser
/// extension such as Alby or nos2x.
///
/// Replaces the former `Nip07Service()` factory singleton (#8618). A single
/// shared instance is kept alive so `AuthService` and `WebAuthService`
/// observe the same extension session: a connection made through one is
/// visible to the other. Constructing it off-web is harmless — `isAvailable`
/// is false there and nothing touches `window.nostr` until it is true.
final nip07ServiceProvider = Provider<Nip07Service>((ref) => Nip07Service());

/// Provides the app's [PerformanceMonitoringService].
///
/// Replaces the former `PerformanceMonitoringService.instance` singleton. A
/// single shared instance is kept alive. Typed to the concrete class (not
/// [PerformanceTraceMonitor]) because app startup calls the concrete-only
/// [PerformanceMonitoringService.initialize]; consumers that only need the
/// trace API accept a [PerformanceTraceMonitor] in their constructor.
final performanceMonitoringServiceProvider =
    Provider<PerformanceMonitoringService>(
      (ref) => PerformanceMonitoringService(),
    );

/// Reports Dart-side HTTP requests as Firebase `NETWORK_REQUEST` metrics.
///
/// Firebase auto-instruments only the native HTTP stacks, so nothing the app
/// issues from Dart reaches the Network Requests tab on its own (#7122).
final httpMetricRecorderProvider = Provider<HttpMetricRecorder>((ref) {
  final monitoring = ref.watch(performanceMonitoringServiceProvider);
  return FirebaseHttpMetricRecorder(isEnabled: () => monitoring.isEnabled);
});

/// Builds an HTTP client that reports its Divine-host requests to Firebase
/// Performance. **Use this instead of `http.Client()` for any client that
/// talks to our own hosts.**
///
/// A factory rather than a shared client: each call site keeps owning (and
/// closing) its own client, so one consumer's `close()` cannot cancel
/// another's in-flight requests. Close the returned client as you would a
/// plain `http.Client` — it closes the client it wraps.
///
/// See `docs/NETWORK_PERFORMANCE_MONITORING.md` for what is instrumented and
/// what is deliberately not.
final instrumentedHttpClientFactoryProvider = Provider<http.Client Function()>((
  ref,
) {
  final recorder = ref.watch(httpMetricRecorderProvider);
  final monitor = ref.watch(performanceMonitoringServiceProvider);
  return () => PerformanceHttpClient(
    inner: http.Client(),
    recorder: recorder,
    performanceMonitor: monitor,
  );
});
