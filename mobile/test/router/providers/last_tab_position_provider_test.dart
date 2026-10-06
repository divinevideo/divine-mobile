// ABOUTME: Pins the difference between getPosition and recordedPosition
// ABOUTME: getPosition defaults notifications to 0, which hid a routing bug

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/providers/providers.dart';

void main() {
  late StreamController<String> locations;
  late ProviderContainer container;

  setUp(() {
    locations = StreamController<String>.broadcast();
    container = ProviderContainer(
      overrides: [
        routerLocationStreamProvider.overrideWithValue(locations.stream),
      ],
    );
    container.read(lastTabPositionProvider);
    container.listen(pageContextProvider, (_, _) {});
  });

  tearDown(() async {
    container.dispose();
    await locations.close();
  });

  Future<void> visit(List<String> paths) async {
    for (final path in paths) {
      locations.add(path);
      await pumpEventQueue();
    }
  }

  group('LastTabPosition', () {
    group('getPosition', () {
      test('defaults notifications to 0 even when never visited', () {
        expect(
          container
              .read(lastTabPositionProvider.notifier)
              .getPosition(RouteType.notifications),
          equals(0),
          reason:
              'This default is the whole reason recordedPosition exists — a '
              'caller cannot tell "never opened" from "opened at index 0".',
        );
      });

      test('leaves explore null so it opens in grid mode', () {
        expect(
          container
              .read(lastTabPositionProvider.notifier)
              .getPosition(RouteType.explore),
          isNull,
        );
      });

      // #8084: the writer recorded `ctx.videoIndex ?? 0`, so visiting the
      // grid stored index 0 and explore never read as null again. Every
      // consumer's grid-mode branch became unreachable, and restoring the
      // tab opened a video the user never chose.
      test('stays null after visiting the explore grid', () async {
        await visit(['/explore']);

        expect(
          container
              .read(lastTabPositionProvider.notifier)
              .getPosition(RouteType.explore),
          isNull,
          reason: 'the grid carries no index, so there is none to remember',
        );
      });

      test('reports the index once an explore video is opened', () async {
        await visit(['/explore', '/explore/5']);

        expect(
          container
              .read(lastTabPositionProvider.notifier)
              .getPosition(RouteType.explore),
          equals(5),
        );
      });

      test('clears back to null on returning to the explore grid', () async {
        await visit(['/explore/5', '/explore']);

        expect(
          container
              .read(lastTabPositionProvider.notifier)
              .getPosition(RouteType.explore),
          isNull,
          reason:
              'returning to the grid must erase the stale feed index, not '
              'leave the tab resuming a video the user backed out of',
        );
      });
    });

    group('recordedPosition', () {
      // Regression for #3337: back navigation to tab 2 read getPosition, got
      // 0, and sent a user who had only ever opened the Inbox into the
      // notification video feed instead.
      test('is null for notifications until one is actually opened', () {
        expect(
          container
              .read(lastTabPositionProvider.notifier)
              .recordedPosition(RouteType.notifications),
          isNull,
        );
      });

      test('reports the index once a notification feed is visited', () async {
        await visit(['/notifications/3']);

        expect(
          container
              .read(lastTabPositionProvider.notifier)
              .recordedPosition(RouteType.notifications),
          equals(3),
        );
      });

      test('clears a notification feed after returning to the inbox', () async {
        await visit(['/notifications/3', '/inbox']);

        expect(
          container
              .read(lastTabPositionProvider.notifier)
              .recordedPosition(RouteType.notifications),
          isNull,
          reason: 'tab 2 should restore the inbox the user last visited',
        );
      });

      test(
        'stays null for notifications after only visiting the inbox',
        () async {
          await visit(['/home/0', '/inbox']);

          expect(
            container
                .read(lastTabPositionProvider.notifier)
                .recordedPosition(RouteType.notifications),
            isNull,
            reason: '/inbox is RouteType.inbox, not a notification feed',
          );
        },
      );
    });
  });
}
