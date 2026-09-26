import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// iOS wakes an app to deliver background URLSession completion events, then
/// expects the app-delegate completion handler to be called only after all
/// application work triggered by those events is done. The upload's terminal
/// event still has to cross into Dart, upload a thumbnail, sign the video
/// event, and publish it to relays.
///
/// The native plugin has no host-side Swift test harness because it links
/// Flutter, so this lifecycle boundary is pinned as a source contract.
void main() {
  group('Apple background URLSession handoff contract', () {
    late String source;

    setUpAll(() {
      source = _appleSourceFile().readAsStringSync();
    });

    test(
      'tracks publish work separately from expiring UI background tasks',
      () {
        expect(
          source,
          contains('activeForegroundSessionIds'),
          reason:
              'A UIBackgroundTask assertion can expire before a large upload '
              'finishes, but the logical publish session must remain active so '
              'the later URLSession wake is retained for Dart follow-up work.',
        );
        expect(
          source,
          contains('expireBackgroundTaskAssertion(sessionId)'),
          reason:
              'Expiration may release only the short-lived assertion; calling '
              'endForegroundSession here also forgets unfinished publish work.',
        );
      },
    );

    test('defers the app-delegate completion until publish work ends', () {
      final handleBackgroundEvents = source.indexOf(
        'func handleBackgroundEvents(',
      );
      final resetDeliveryBatch = source.indexOf(
        'backgroundEventsFinished = false',
        handleBackgroundEvents,
      );
      final urlSessionFinished = source.indexOf(
        'func urlSessionDidFinishEvents(',
      );
      final guardedCompletion = source.indexOf(
        'func finishBackgroundEventsIfReady()',
      );
      final activeSessionGuard = source.indexOf(
        'guard activeForegroundSessionIds.isEmpty',
        guardedCompletion,
      );
      final completionCall = source.indexOf('handler()', guardedCompletion);
      final finishCallFromUrlSession = source.indexOf(
        'self.finishBackgroundEventsIfReady()',
        urlSessionFinished,
      );

      expect(handleBackgroundEvents, greaterThanOrEqualTo(0));
      expect(resetDeliveryBatch, greaterThan(handleBackgroundEvents));
      expect(resetDeliveryBatch, lessThan(urlSessionFinished));
      expect(urlSessionFinished, greaterThanOrEqualTo(0));
      expect(guardedCompletion, greaterThanOrEqualTo(0));
      expect(activeSessionGuard, greaterThan(guardedCompletion));
      expect(completionCall, greaterThan(activeSessionGuard));
      expect(finishCallFromUrlSession, greaterThan(urlSessionFinished));
    });

    test(
      'rechecks retained background events when the publish session ends',
      () {
        final endSession = source.indexOf(
          'func endForegroundSession(_ sessionId: String)',
        );
        final removeSession = source.indexOf(
          'activeForegroundSessionIds.remove(sessionId)',
          endSession,
        );
        final retryCompletion = source.indexOf(
          'finishBackgroundEventsIfReady()',
          removeSession,
        );

        expect(endSession, greaterThanOrEqualTo(0));
        expect(removeSession, greaterThan(endSession));
        expect(retryCompletion, greaterThan(removeSession));
      },
    );

    test('creates the background session off the main thread on attach', () {
      final attach = source.indexOf(
        'func attach(_ channel: FlutterMethodChannel)',
      );
      final attachBody = source.substring(
        attach,
        source.indexOf('\n  }\n', attach),
      );

      expect(attach, greaterThanOrEqualTo(0));
      expect(
        attachBody,
        contains('DispatchQueue.global('),
        reason:
            'attach runs during plugin registration, on the main thread, '
            'before the first frame. Creating a background URLSession is a '
            'synchronous round trip to nsurlsessiond that held every launch '
            'for ~6 ms (#9493).',
      );
      expect(
        attachBody,
        isNot(contains('\n    _ = session')),
        reason: 'The session must not be created inline on the main thread.',
      );
      expect(
        source,
        isNot(contains('lazy var session')),
        reason:
            'The session is now created from a background queue and from '
            'the main queue, and a lazy var is not safe to initialize from '
            'two threads at once.',
      );
    });

    test('arms a watchdog that balances the app-delegate completion', () {
      final handleBackgroundEvents = source.indexOf(
        'func handleBackgroundEvents(',
      );
      final watchdogInterval = source.indexOf(
        'backgroundCompletionWatchdogInterval',
      );
      final scheduledTimer = source.indexOf(
        'Timer.scheduledTimer',
        handleBackgroundEvents,
      );
      final forceFinish = source.indexOf('func forceFinishBackgroundEvents()');
      final completeBackgroundEvents = source.indexOf(
        'func completeBackgroundEvents()',
      );
      final clearsHandler = source.indexOf(
        'backgroundCompletionHandler = nil',
        completeBackgroundEvents,
      );
      final invalidatesWatchdog = source.indexOf(
        'backgroundCompletionWatchdog?.invalidate()',
        completeBackgroundEvents,
      );
      final completionCall = source.indexOf(
        'handler()',
        completeBackgroundEvents,
      );

      expect(watchdogInterval, greaterThanOrEqualTo(0));
      expect(scheduledTimer, greaterThan(handleBackgroundEvents));
      expect(forceFinish, greaterThan(scheduledTimer));
      expect(completeBackgroundEvents, greaterThan(forceFinish));
      expect(clearsHandler, greaterThan(completeBackgroundEvents));
      expect(invalidatesWatchdog, greaterThan(clearsHandler));
      expect(completionCall, greaterThan(invalidatesWatchdog));
    });
  });
}

File _appleSourceFile() {
  final packageRelative = File(
    'darwin/background_uploader/Sources/background_uploader/'
    'BackgroundUploaderPlugin.swift',
  );
  if (packageRelative.existsSync()) {
    return packageRelative;
  }

  return File(
    'packages/background_uploader/darwin/background_uploader/Sources/'
    'background_uploader/BackgroundUploaderPlugin.swift',
  );
}
