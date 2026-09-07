// ABOUTME: Riverpod providers for the analytics package's tracker services,
// ABOUTME: migrated off the factory-singleton pattern to constructor injection (#4743).

import 'package:analytics/analytics.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/features/creation_analytics/creation_analytics_tracker.dart';
import 'package:openvine/providers/crash_reporting_provider.dart';
import 'package:unified_logger/unified_logger.dart';

typedef CrashUserIdSetter = Future<void> Function(String? userId);

/// Keeps Firebase Analytics and Crashlytics on the same authenticated identity.
class AnalyticsIdentityCoordinator {
  AnalyticsIdentityCoordinator({
    required AnalyticsEventSink analytics,
    required CrashUserIdSetter setCrashUserId,
  }) : _analytics = analytics,
       _setCrashUserId = setCrashUserId;

  static final _hexPubkey = RegExp(r'^[0-9a-fA-F]{64}$');

  /// The identity this app process last applied to Firebase.
  ///
  /// Static because the Firebase identity is process-global while this
  /// coordinator is not: an account switch builds a fresh [ProviderContainer],
  /// so a per-instance field would start at `null` and read the switch as a
  /// first login.
  static String? _lastAppliedUserId;

  @visibleForTesting
  static void resetLastAppliedUserId() => _lastAppliedUserId = null;

  final AnalyticsEventSink _analytics;
  final CrashUserIdSetter _setCrashUserId;

  Future<void> setUserId(String? rawPubkeyHex) async {
    if (rawPubkeyHex != null && !_hexPubkey.hasMatch(rawPubkeyHex)) {
      Log.error(
        'Refusing to set a non-hex analytics user ID',
        name: 'AnalyticsIdentityCoordinator',
        category: LogCategory.auth,
      );
      return;
    }

    // An external signer can hand back uppercase hex. The campaign join is a
    // string compare against the lowercase pubkey stored downstream, so the
    // identity is lowercased rather than passed through as received.
    final pubkeyHex = rawPubkeyHex?.toLowerCase();

    // `invite_code` is user-scoped, so it outlives the identity it was
    // recorded for unless every identity change clears it. Logout is not the
    // only one: an in-place account switch swaps containers without ever
    // passing through an unauthenticated state.
    final previousUserId = _lastAppliedUserId;
    final identityChanged =
        previousUserId != null && previousUserId != pubkeyHex;
    _lastAppliedUserId = pubkeyHex;

    try {
      await _analytics.setUserId(pubkeyHex);
    } catch (error) {
      Log.warning(
        'Failed to update the Firebase Analytics identity: $error',
        name: 'AnalyticsIdentityCoordinator',
        category: LogCategory.auth,
      );
    }

    if (pubkeyHex == null || identityChanged) {
      try {
        await _analytics.setUserProperty(
          name: AnalyticsUserProperty.inviteCode,
          value: null,
        );
      } catch (error) {
        Log.warning(
          'Failed to clear Firebase Analytics invite attribution: $error',
          name: 'AnalyticsIdentityCoordinator',
          category: LogCategory.auth,
        );
      }
    }

    try {
      await _setCrashUserId(pubkeyHex);
    } catch (error) {
      Log.warning(
        'Failed to update the Crashlytics identity: $error',
        name: 'AnalyticsIdentityCoordinator',
        category: LogCategory.auth,
      );
    }
  }
}

/// Provides the low-level analytics event sink for feature-specific events.
final analyticsEventSinkProvider = Provider<AnalyticsEventSink>(
  (ref) => FirebaseAnalyticsEventSink(),
);

/// Provides the SDK-level consent gate for the Firebase analytics backend.
///
/// Derived from [analyticsEventSinkProvider] so both reach the same backend.
/// A sink that cannot be gated (a test double, or a future non-Firebase sink)
/// degrades to a no-op rather than crashing — the first-party queue is gated
/// independently, so consent is still enforced where it is owned.
final analyticsCollectionControlProvider = Provider<AnalyticsCollectionControl>(
  (ref) {
    final sink = ref.watch(analyticsEventSinkProvider);
    if (sink case final AnalyticsCollectionControl control) return control;
    return const NoOpAnalyticsCollectionControl();
  },
);

final creationAnalyticsTrackerProvider = Provider<CreationAnalyticsTracker>(
  (ref) => CreationAnalyticsTracker(
    analytics: ref.watch(analyticsEventSinkProvider),
  ),
);

final analyticsIdentityCoordinatorProvider =
    Provider<AnalyticsIdentityCoordinator>(
      (ref) => AnalyticsIdentityCoordinator(
        analytics: ref.watch(analyticsEventSinkProvider),
        setCrashUserId: ref.read(crashReportingServiceProvider).setUserId,
      ),
    );

/// Provides the app's shared [PageLoadHistory] ring buffer.
///
/// Replaces the former `PageLoadHistory()` singleton. Both performance
/// trackers write into it and Developer Options reads it back, so they must
/// resolve the same buffer.
final pageLoadHistoryProvider = Provider<PageLoadHistory>(
  (ref) => PageLoadHistory(),
);

/// Provides the app's shared [SurfacePerformanceTracker].
///
/// Replaces the former `SurfacePerformanceTracker()` factory singleton. A
/// single shared instance is kept alive so surface-load sessions started by
/// one consumer are visible to the resume-time reset in the app lifecycle
/// handler, and the tracker is mockable through a provider override in tests
/// instead of reaching into static state.
final surfacePerformanceTrackerProvider = Provider<SurfacePerformanceTracker>(
  (ref) =>
      SurfacePerformanceTracker(history: ref.watch(pageLoadHistoryProvider)),
);

/// Provides the app's shared [ScreenAnalyticsService].
///
/// Replaces the former `ScreenAnalyticsService()` factory singleton. A single
/// shared instance is kept alive because a screen-load session is started by
/// the navigator observer and completed later by the screen itself; a
/// per-consumer instance would drop every session in between.
final screenAnalyticsServiceProvider = Provider<ScreenAnalyticsService>(
  (ref) => ScreenAnalyticsService(history: ref.watch(pageLoadHistoryProvider)),
);

/// Provides the app's shared [FeedPerformanceTracker].
///
/// Replaces the former `FeedPerformanceTracker()` factory singleton. A single
/// shared instance is kept alive because a feed-load session is started by one
/// consumer and completed by another, and the app lifecycle handler clears
/// them all on resume.
final feedPerformanceTrackerProvider = Provider<FeedPerformanceTracker>(
  (ref) => FeedPerformanceTracker(),
);

/// Provides the app's shared [ErrorAnalyticsTracker].
///
/// Replaces the former `ErrorAnalyticsTracker()` factory singleton. A single
/// shared instance is kept alive so per-error counts accumulate in one place
/// (read back by the bug-report diagnostics), and the tracker is mockable
/// through a provider override in tests instead of reaching into static state.
final errorAnalyticsTrackerProvider = Provider<ErrorAnalyticsTracker>(
  (ref) => ErrorAnalyticsTracker(),
);
