// ABOUTME: Performance monitoring service for tracking app performance metrics
// ABOUTME: Uses Firebase Performance Monitoring to track screen transitions, network requests, and custom operations

import 'package:app_update_repository/app_update_repository.dart';
import 'package:firebase_performance/firebase_performance.dart';
import 'package:flutter/foundation.dart';
import 'package:openvine/utils/platform_support.dart';
import 'package:unified_logger/unified_logger.dart';

/// A handle to a single started performance trace.
///
/// Callers capture the handle returned by
/// [PerformanceTraceMonitor.startOperationTrace] and tag/stop *that* handle, so
/// each operation owns its own trace. This avoids the pitfalls of the removed
/// name-keyed API: a fast operation can't tag/stop before a shared
/// registration completes, and two overlapping operations can't stop or
/// re-attribute each other's trace.
abstract class PerformanceTrace {
  /// Adds an attribute for filtering in the Firebase console.
  void putAttribute(String attribute, String value);

  /// Sets a custom metric on this trace, so an operation can report a
  /// breakdown (per-phase durations, payload sizes) next to its duration.
  void setMetric(String metric, int value);

  /// Stops the trace and records its duration.
  Future<void> stop();
}

/// Minimal trace API used by services that need testable performance spans.
///
/// Deliberately handle-only. The name-keyed API this replaced treated the
/// trace *name* as the identity of a measurement, so starting a second trace
/// of the same name reported the first one wherever it happened to be —
/// truncating it — and a trace that was never stopped stayed open until some
/// later start reported it, which is how a 23.6-hour `feed_load_profile`
/// sample reached the console (#7119).
abstract class PerformanceTraceMonitor {
  /// Starts a trace and returns the handle that owns it.
  ///
  /// Returns a no-op handle when monitoring is unavailable, so callers never
  /// need to null-check.
  PerformanceTrace startOperationTrace(String traceName);
}

/// No-op [PerformanceTrace] returned when monitoring is unavailable.
class _NoOpPerformanceTrace implements PerformanceTrace {
  const _NoOpPerformanceTrace();

  @override
  void putAttribute(String attribute, String value) {}

  @override
  void setMetric(String metric, int value) {}

  @override
  Future<void> stop() async {}
}

/// A [PerformanceTrace] backed by a live Firebase [Trace].
class _FirebasePerformanceTrace implements PerformanceTrace {
  _FirebasePerformanceTrace(this._trace, this._started);

  final Trace _trace;

  /// Completion of the trace's start round-trip. [stop] waits on it because
  /// the plugin drops a stop that arrives before the platform handed back a
  /// trace handle — the trace is then never reported *and* leaks natively.
  /// Operations that fail fast (an auth or ownership check that returns after
  /// a single await) are exactly the ones that would race it.
  final Future<void> _started;

  @override
  void putAttribute(String attribute, String value) {
    try {
      _trace.putAttribute(attribute, value);
    } catch (e) {
      Log.error(
        'Failed to put attribute $attribute: $e',
        name: 'PerformanceMonitoring',
      );
    }
  }

  @override
  void setMetric(String metric, int value) {
    try {
      _trace.setMetric(metric, value);
    } catch (e) {
      Log.error(
        'Failed to set metric $metric: $e',
        name: 'PerformanceMonitoring',
      );
    }
  }

  @override
  Future<void> stop() async {
    try {
      await _started;
      await _trace.stop();
    } catch (e) {
      Log.error('Failed to stop trace: $e', name: 'PerformanceMonitoring');
    }
  }
}

/// Receives the person's analytics consent decision.
///
/// `AnalyticsService` owns the decision and pushes it down, as it does for its
/// other collectors; nothing here reads it back.
abstract class PerformanceConsentControl {
  /// Applies the decision to performance collection.
  Future<void> setAnalyticsConsent({required bool enabled});
}

/// No-op [PerformanceTraceMonitor] used as the default when no real monitor is
/// injected (e.g. in tests). Mirrors the prior behaviour of the uninitialised
/// singleton, whose methods early-returned without touching Firebase.
class NoOpPerformanceTraceMonitor implements PerformanceTraceMonitor {
  const NoOpPerformanceTraceMonitor();

  @override
  PerformanceTrace startOperationTrace(String traceName) =>
      const _NoOpPerformanceTrace();
}

/// Performance monitoring service for tracking app performance.
///
/// Collects only while the build may report and the person has not opted out
/// of analytics (#11398).
class PerformanceMonitoringService
    implements PerformanceTraceMonitor, PerformanceConsentControl {
  PerformanceMonitoringService({
    @visibleForTesting FirebasePerformance Function()? performance,
    @visibleForTesting bool releaseBuild = collectionEnabled,
  }) : _performanceFactory = performance ?? _firebasePerformance,
       _releaseBuild = releaseBuild;

  static FirebasePerformance _firebasePerformance() =>
      FirebasePerformance.instance;

  /// Whether this build may report to the production Firebase Performance
  /// dataset.
  ///
  /// Release-only, which is stricter than the `!kDebugMode` gate
  /// `CrashReportingService` uses: a profile build is a developer device too,
  /// and its timings land in the same dataset as real users rather than in a
  /// separate bucket.
  ///
  /// Debug and profile builds are excluded because they are far slower than
  /// release and there is no way to tell them apart once the data has landed.
  /// In #7123 this skewed the release comparison it was being read for: local
  /// builds — identifiable only because they carry the `pubspec.yaml` build
  /// number, which store builds never use — were 9.5% of the 1.0.19 sample at
  /// a p50 of 919 ms, against ~100 ms for the same phone model on a store
  /// build.
  ///
  /// Paired with a native deactivation in the debug and profile Android
  /// manifests and in iOS `Debug.xcconfig` / `Profile.xcconfig`, which is what
  /// actually suppresses `_app_start` — that trace is captured natively before
  /// Dart runs.
  @visibleForTesting
  static const bool collectionEnabled = kReleaseMode;

  /// Whether a release build must also be a distributed one to report.
  ///
  /// [collectionEnabled] cannot tell a store build from `flutter run
  /// --release` on a developer's phone: both are release mode, and the local
  /// one still reached the dataset under the `pubspec.yaml` build number —
  /// 449 rows from four devices in the month after #7158 shipped (#7302).
  /// [isDistributedBuild] is the runtime half: the Shorebird engine that only
  /// `shorebird release` links, or an installer we recognise. Flip this to
  /// `false` for a local run that should report; revert before committing.
  @visibleForTesting
  static const bool distributedBuildsOnly = true;

  /// Whether this build reached the device through a channel real users use.
  ///
  /// Every store and TestFlight artifact comes out of `shorebird release` and
  /// carries the updater engine, so [shorebirdAvailable] alone covers Play,
  /// the App Store and TestFlight. Zapstore installs the split APKs Codemagic
  /// builds with plain `flutter build`, which have no engine, so its installer
  /// package is accepted on its own. A GitHub-release APK installed by hand is
  /// indistinguishable from a local build by either signal and is excluded
  /// with it — the only population this loses.
  static bool isDistributedBuild({
    required bool shorebirdAvailable,
    required InstallSource installSource,
  }) => shorebirdAvailable || installSource == InstallSource.zapstore;

  final FirebasePerformance Function() _performanceFactory;

  /// [collectionEnabled], injectable so tests can exercise a release build.
  final bool _releaseBuild;

  /// Set at the start of [initialize], so a consent decision that lands while
  /// it is still in flight reaches the SDK instead of waiting for a launch.
  FirebasePerformance? _performance;
  bool _initialized = false;

  /// Whether this build may report at all. Settled by [initialize].
  bool _buildMayReport = false;

  /// The person's analytics consent, or null until [initialize] or
  /// [setAnalyticsConsent] supplies it.
  bool? _analyticsConsent;

  bool get _collecting => _buildMayReport && _analyticsConsent == true;

  /// Whether Firebase Performance is usable and the person has not opted out
  /// of analytics.
  ///
  /// Sampled per operation by consumers built before startup finishes — an
  /// instrumented HTTP client is constructed with the provider graph, well
  /// before [initialize] resolves — so an opt-out also stops the ones already
  /// running.
  bool get isEnabled => _initialized && _analyticsConsent == true;

  /// Initialize performance monitoring.
  ///
  /// [distributedBuild] is [isDistributedBuild] evaluated by the caller, which
  /// has the container; it only matters when [distributedBuildsOnly] holds.
  ///
  /// [analyticsConsent] is the stored consent decision, read by the caller:
  /// `AnalyticsService` initializes long after this, and waiting for it would
  /// let every startup trace report for someone who opted out. A decision
  /// already pushed through [setAnalyticsConsent] is at least as recent, so it
  /// wins.
  Future<void> initialize({
    required bool distributedBuild,
    required bool analyticsConsent,
  }) async {
    if (_initialized || !isFirebaseSupported) return;

    _buildMayReport =
        _releaseBuild && (!distributedBuildsOnly || distributedBuild);
    _analyticsConsent ??= analyticsConsent;
    try {
      final performance = _performance = _performanceFactory();

      // Always assert the flag rather than skipping the call when collection
      // is off: the SDK persists it across launches, so a device that ran an
      // earlier build — which enabled collection unconditionally — keeps
      // reporting until something actively sets it back to false.
      final collect = _collecting;
      await performance.setPerformanceCollectionEnabled(collect);

      _initialized = true;
      Log.info(
        'Performance monitoring initialized successfully '
        '(collection enabled: $collect, release: $_releaseBuild, '
        'distributed build: $distributedBuild, '
        'analytics consent: $_analyticsConsent)',
        name: 'PerformanceMonitoring',
      );
    } catch (e) {
      Log.error(
        'Failed to initialize performance monitoring: $e',
        name: 'PerformanceMonitoring',
      );
      // Don't throw - app should continue even if performance monitoring fails
    }
  }

  /// Applies the person's analytics consent right away.
  ///
  /// New traces and HTTP metrics stop at once through [isEnabled]. The SDK
  /// flag is re-asserted as well, because it governs what the SDK records
  /// natively (`_app_start`, screen rendering, native network requests). The
  /// plugin documents that flag as applying to future launches, so the native
  /// traces may only stop at the next one.
  @override
  Future<void> setAnalyticsConsent({required bool enabled}) async {
    _analyticsConsent = enabled;
    final performance = _performance;
    // Not started yet: [initialize] applies the decision.
    if (performance == null) return;

    final collect = _collecting;
    try {
      await performance.setPerformanceCollectionEnabled(collect);
      Log.info(
        'Applied analytics consent to performance monitoring '
        '(consent: $enabled, collection enabled: $collect)',
        name: 'PerformanceMonitoring',
      );
    } catch (e) {
      Log.error(
        'Failed to apply analytics consent to performance monitoring: $e',
        name: 'PerformanceMonitoring',
      );
    }
  }

  /// Start an operation-scoped trace and return its handle.
  ///
  /// The caller owns the returned [PerformanceTrace] and tags/stops it
  /// directly, so overlapping operations of the same name keep independent
  /// traces and a handle that is never stopped simply never reports. Start is
  /// fire-and-forget so callers stay synchronous; attributes and metrics are
  /// buffered until stop, and stop itself waits for the start round-trip so a
  /// short operation cannot end its trace before the platform opened it.
  @override
  PerformanceTrace startOperationTrace(String traceName) {
    final performance = _performance;
    if (!isEnabled || performance == null) {
      return const _NoOpPerformanceTrace();
    }

    try {
      final trace = performance.newTrace(traceName);
      final started = trace.start().catchError((Object e) {
        Log.error(
          'Failed to start trace $traceName: $e',
          name: 'PerformanceMonitoring',
        );
      });
      return _FirebasePerformanceTrace(trace, started);
    } catch (e) {
      Log.error(
        'Failed to start trace $traceName: $e',
        name: 'PerformanceMonitoring',
      );
      return const _NoOpPerformanceTrace();
    }
  }
}
