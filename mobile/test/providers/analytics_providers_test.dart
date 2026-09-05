// ABOUTME: Tests authenticated identity fan-out to Analytics and Crashlytics.

import 'package:analytics/analytics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/analytics_providers.dart';

class _RecordingSink implements AnalyticsEventSink {
  final userIds = <String?>[];
  final properties = <({String name, String? value})>[];

  @override
  Future<void> setUserId(String? userId) async => userIds.add(userId);

  @override
  Future<void> setUserProperty({
    required String name,
    required String? value,
  }) async => properties.add((name: name, value: value));

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {}

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {}
}

void main() {
  const pubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
  test('fans out the exact 64-character hex identity', () async {
    final sink = _RecordingSink();
    final crashIds = <String?>[];
    final coordinator = AnalyticsIdentityCoordinator(
      analytics: sink,
      setCrashUserId: (userId) async => crashIds.add(userId),
    );

    await coordinator.setUserId(pubkey);

    expect(sink.userIds, [pubkey]);
    expect(crashIds, [pubkey]);
  });

  test('clears user identity on logout', () async {
    final sink = _RecordingSink();
    final crashIds = <String?>[];
    final coordinator = AnalyticsIdentityCoordinator(
      analytics: sink,
      setCrashUserId: (userId) async => crashIds.add(userId),
    );

    await coordinator.setUserId(null);

    expect(sink.userIds, [null]);
    expect(crashIds, [null]);
  });

  test('lowercases identities so the campaign join stays exact', () async {
    final sink = _RecordingSink();
    final crashIds = <String?>[];
    final coordinator = AnalyticsIdentityCoordinator(
      analytics: sink,
      setCrashUserId: (userId) async => crashIds.add(userId),
    );

    await coordinator.setUserId(pubkey.toUpperCase());

    expect(sink.userIds, [pubkey]);
    expect(crashIds, [pubkey]);
  });

  test('refuses bech32 and malformed identities', () async {
    final sink = _RecordingSink();
    final crashIds = <String?>[];
    final coordinator = AnalyticsIdentityCoordinator(
      analytics: sink,
      setCrashUserId: (userId) async => crashIds.add(userId),
    );

    await coordinator.setUserId('npub1not-a-hex-key');

    expect(sink.userIds, isEmpty);
    expect(crashIds, isEmpty);
  });

  group('pageLoadHistoryProvider', () {
    // The default Firebase sink resolves lazily and fails closed under
    // `flutter test`, so the real providers are safe to read here unoverridden.
    test('collects records from both performance trackers', () async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      container.read(screenAnalyticsServiceProvider)
        ..startScreenLoad('explore')
        ..markDataLoaded('explore');

      final surface = container.read(surfacePerformanceTrackerProvider)
        ..startSurfaceLoad('comments_sheet');
      await surface.completeSurfaceLoad(
        'comments_sheet',
        result: SurfaceLoadResult.success,
      );

      // Developer Options reads this buffer back, so both writers have to land
      // in the same one.
      expect(
        container.read(pageLoadHistoryProvider).records.map((r) => r.source),
        containsAll(<String>[PageLoadSource.route, PageLoadSource.surface]),
      );
    });
  });

  group('feedPerformanceTrackerProvider', () {
    test('hands every reader the same session-tracking instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // One consumer starts a feed load that another completes, and the app
      // lifecycle handler resets them all on resume.
      container.read(feedPerformanceTrackerProvider).startFeedLoad('popular');

      expect(
        container.read(feedPerformanceTrackerProvider).activeSessionCount,
        1,
      );
    });
  });

  group('screenAnalyticsServiceProvider', () {
    test('hands every reader the same session-tracking instance', () {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // The navigator observer starts a load that a screen completes later, so
      // a second read must see the first read's in-flight session.
      container.read(screenAnalyticsServiceProvider).startScreenLoad('explore');

      expect(
        container.read(screenAnalyticsServiceProvider).activeSessionCount,
        1,
      );
    });

    test('is replaceable by an override without touching static state', () {
      final replacement = ScreenAnalyticsService(
        history: PageLoadHistory(),
        sink: const NoOpAnalyticsEventSink(),
      );
      final container = ProviderContainer(
        overrides: [
          screenAnalyticsServiceProvider.overrideWithValue(replacement),
        ],
      );
      addTearDown(container.dispose);

      expect(
        container.read(screenAnalyticsServiceProvider),
        same(replacement),
      );
    });
  });
}
