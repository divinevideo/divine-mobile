// ABOUTME: Enforces fullscreen-feed first-frame latency under a 5 Mbps network
// ABOUTME: Samples native first-frame events instead of fixed waits or log scraping

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/infinite_video_feed.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/main.dart' as app;
import 'package:patrol/patrol.dart';

import '../helpers/db_helpers.dart';
import '../helpers/http_helpers.dart';
import '../helpers/navigation_helpers.dart';
import '../helpers/patrol_semantics.dart';
import '../helpers/test_setup.dart';
import 'feed_ttff_budget.dart';

Future<bool> _waitForSampleCount(
  WidgetTester tester,
  Map<String, FeedFirstFrameMetric> samples,
  int count, {
  int maxSeconds = 15,
}) async {
  for (var i = 0; i < maxSeconds * 4; i++) {
    await tester.pump(const Duration(milliseconds: 250));
    if (samples.length >= count) return true;
  }
  return false;
}

void main() {
  ignorePlatformSemanticsHandle();

  group('time to first frame', () {
    patrolTest('feed TTFF stays within the 5 Mbps p90 budget', ($) async {
      final tester = $.tester;
      final samplesByVideoId = <String, FeedFirstFrameMetric>{};
      final metricSubscription = FeedFirstFrameMetrics.events.listen((metric) {
        samplesByVideoId.putIfAbsent(metric.videoId, () => metric);
        logPhase(
          'perf: ttff videoId=${metric.videoId} index=${metric.index} '
          'durationMs=${metric.duration.inMilliseconds} '
          'cache=${metric.loadedFromCache ? 'hit' : 'miss'}',
        );
      });
      addTearDown(metricSubscription.cancel);

      final originalOnError = suppressSetStateErrors();
      addTearDown(() => restoreErrorHandler(originalOnError));
      final originalErrorBuilder = saveErrorWidgetBuilder();
      addTearDown(() => restoreErrorWidgetBuilder(originalErrorBuilder));

      launchAppGuarded(app.main);
      await tester.pumpAndSettle(const Duration(seconds: 3));

      logPhase('perf: register_start');
      await navigateToCreateAccount(tester);
      final email = 'perf-${DateTime.now().millisecondsSinceEpoch}@test.com';
      await registerNewUser(tester, email, 'TestPass123!');

      logPhase('perf: verify_email');
      final token = await getVerificationToken(email);
      await callVerifyEmail(token);

      final l10n = lookupAppLocalizations(const Locale('en'));
      logPhase('perf: wait_for_feed');
      final feedLoaded = await waitForText(
        tester,
        l10n.feedModeForYou,
        maxSeconds: 30,
      );
      expect(
        feedLoaded,
        isTrue,
        reason: 'Feed did not load within 30s after email verification',
      );

      final firstSampleArrived = await _waitForSampleCount(
        tester,
        samplesByVideoId,
        1,
      );
      expect(
        firstSampleArrived,
        isTrue,
        reason: 'The first feed video never rendered a native frame',
      );

      while (samplesByVideoId.length < feedTtffSampleCount) {
        final expectedCount = samplesByVideoId.length + 1;
        logPhase('perf: scroll_for_sample_$expectedCount');
        final size = tester.view.physicalSize / tester.view.devicePixelRatio;
        await tester.flingFrom(
          Offset(size.width / 2, size.height * 0.8),
          Offset(0, -size.height * 0.6),
          800,
        );
        final sampleArrived = await _waitForSampleCount(
          tester,
          samplesByVideoId,
          expectedCount,
        );
        expect(
          sampleArrived,
          isTrue,
          reason:
              'No first-frame metric arrived for feed sample '
              '$expectedCount of $feedTtffSampleCount',
        );
      }

      final samples = samplesByVideoId.values
          .take(feedTtffSampleCount)
          .toList();
      final p90 = feedTtffPercentile(samples, percentile: 90);
      final evidence = formatFeedTtffSamples(samples);
      logPhase('$evidence\nFeed TTFF p90=${p90.inMilliseconds}ms');
      expect(
        p90,
        lessThanOrEqualTo(feedTtffP90Budget),
        reason:
            '$evidence\n'
            'p90=${p90.inMilliseconds}ms exceeded '
            '${feedTtffP90Budget.inMilliseconds}ms',
      );

      restoreErrorWidgetBuilder(originalErrorBuilder);
      drainAsyncErrors(tester);
    });
  });
}
