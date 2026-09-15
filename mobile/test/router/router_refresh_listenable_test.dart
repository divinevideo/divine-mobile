import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/router_refresh_listenable.dart';

void main() {
  group('RouterRefreshListenable', () {
    late StreamController<void> controller;
    late RouterRefreshListenable listenable;

    setUp(() {
      controller = StreamController<void>();
      listenable = RouterRefreshListenable(controller.stream);
    });

    tearDown(() async {
      await listenable.dispose();
      await controller.close();
    });

    test('defers a manual refresh out of the caller stack', () async {
      var calls = 0;
      listenable.addListener(() => calls++);

      listenable.refresh();

      expect(calls, 0);

      await Future<void>.microtask(() {});

      expect(calls, 1);
    });

    test(
      'coalesces a burst of manual refreshes into one notification',
      () async {
        var calls = 0;
        listenable.addListener(() => calls++);

        listenable
          ..refresh()
          ..refresh()
          ..refresh();

        expect(calls, 0);

        await Future<void>.microtask(() {});

        expect(calls, 1);
      },
    );

    test('does not notify a scheduled refresh after disposal', () async {
      var calls = 0;
      listenable.addListener(() => calls++);

      listenable.refresh();
      await listenable.dispose();

      await Future<void>.microtask(() {});

      expect(calls, 0);
    });
  });
}
