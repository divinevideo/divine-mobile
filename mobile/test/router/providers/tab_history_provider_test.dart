// ABOUTME: Regression tests for tab history recording every bottom-nav tab
// ABOUTME: /inbox was silently dropped, which made Android back exit the app

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
    // Arm TabHistory's ref.listen before emitting any location.
    container.read(tabHistoryProvider);
    container.listen(pageContextProvider, (_, _) {});
  });

  tearDown(() async {
    container.dispose();
    await locations.close();
  });

  Future<List<int>> visit(List<String> paths) async {
    for (final path in paths) {
      locations.add(path);
      await pumpEventQueue();
    }
    return container.read(tabHistoryProvider);
  }

  group('TabHistory', () {
    group('records each bottom-nav tab', () {
      test('records /explore as tab 1', () async {
        expect(await visit(['/home/0', '/explore']), equals([0, 1]));
      });

      test('records a pushed hashtag grid under the explore tab', () async {
        expect(await visit(['/home/0', '/hashtag/flutter']), equals([0, 1]));
      });

      test('records /notifications as tab 2', () async {
        expect(await visit(['/home/0', '/notifications/0']), equals([0, 2]));
      });

      // Regression for #3337: RouteType.inbox had no arm in this provider's
      // private copy of the tab map, so the Inbox tab was never pushed onto
      // the history. Android system back then found no previous tab and
      // reported the press unhandled, and the OS closed the app.
      test(
        'records /inbox as tab 2, the tab the bottom nav sends it to',
        () async {
          expect(await visit(['/home/0', '/inbox']), equals([0, 2]));
        },
      );
    });

    group('getPreviousTab', () {
      test('returns the tab visited before the current one', () async {
        await visit(['/home/0', '/inbox']);
        expect(
          container.read(tabHistoryProvider.notifier).getPreviousTab(),
          equals(0),
        );
      });

      test('returns null when only one tab has been visited', () async {
        await visit(['/home/0']);
        expect(
          container.read(tabHistoryProvider.notifier).getPreviousTab(),
          isNull,
        );
      });
    });

    group('does not record routes outside the bottom nav', () {
      test('leaves history untouched for /settings', () async {
        expect(await visit(['/home/0', '/settings']), equals([0]));
      });
    });
  });
}
