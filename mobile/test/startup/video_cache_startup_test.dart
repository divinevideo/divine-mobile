import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/startup/app_bootstrap.dart' as app;
import 'package:openvine/startup/startup_phases.dart';

void main() {
  group('configureVideoPlayerCacheForStartup', () {
    test('skips cache configuration when skip is true', () async {
      var invoked = false;

      await app.configureVideoPlayerCacheForStartup(
        skip: true,
        configureCache: () async {
          invoked = true;
        },
      );

      expect(invoked, isFalse);
    });

    test('configures cache when skip is false', () async {
      var invoked = false;

      await app.configureVideoPlayerCacheForStartup(
        skip: false,
        configureCache: () async {
          invoked = true;
        },
      );

      expect(invoked, isTrue);
    });
  });

  group('sweepThenBudgetMediaCaches', () {
    test('sizes the caches only once every sweep has measured them', () async {
      final videoSweep = Completer<void>();
      final imageSweep = Completer<void>();
      final events = <String>[];

      final done = sweepThenBudgetMediaCaches(
        sweeps: [() => videoSweep.future, () => imageSweep.future],
        refreshBudget: () async => events.add('budget'),
      );
      await pumpEventQueue();
      videoSweep.complete();
      await pumpEventQueue();
      expect(events, isEmpty, reason: 'the image sweep is still running');

      imageSweep.complete();
      await done;

      expect(events, equals(['budget']));
    });
  });

  group('disposeVideoPlayersForStartup', () {
    test('skips disposal when skip is true', () async {
      var invoked = false;

      await app.disposeVideoPlayersForStartup(
        skip: true,
        disposeAll: () async {
          invoked = true;
        },
      );

      expect(invoked, isFalse);
    });

    test('disposes players when skip is false', () async {
      var invoked = false;

      await app.disposeVideoPlayersForStartup(
        skip: false,
        disposeAll: () async {
          invoked = true;
        },
      );

      expect(invoked, isTrue);
    });
  });
}
