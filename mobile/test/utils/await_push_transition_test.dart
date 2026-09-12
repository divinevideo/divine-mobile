import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:openvine/utils/await_push_transition.dart';

void main() {
  group('awaitPushTransition', () {
    testWidgets('completes once the pushed route finishes its transition', (
      tester,
    ) async {
      late BuildContext homeContext;
      final navigatorKey = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        MaterialApp(
          navigatorKey: navigatorKey,
          home: Builder(
            builder: (context) {
              homeContext = context;
              return const Scaffold(body: Text('home'));
            },
          ),
        ),
      );

      navigatorKey.currentState!.push(
        MaterialPageRoute<void>(
          builder: (_) => const Scaffold(body: Text('next')),
        ),
      );

      var completed = false;
      unawaited(
        awaitPushTransition(homeContext).then((_) => completed = true),
      );

      // Mid-transition: the cover animation has not reached completed yet.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      expect(completed, isFalse);

      await tester.pumpAndSettle();
      expect(completed, isTrue);
    });

    testWidgets('resolves via the timeout when no transition completes', (
      tester,
    ) async {
      late BuildContext homeContext;
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) {
              homeContext = context;
              return const Scaffold(body: Text('home'));
            },
          ),
        ),
      );

      var completed = false;
      unawaited(
        awaitPushTransition(
          homeContext,
          timeout: const Duration(milliseconds: 200),
        ).then((_) => completed = true),
      );

      // endOfFrame resolves, the secondary animation never completes, so only
      // the timeout can release the wait.
      await tester.pump();
      expect(completed, isFalse);

      await tester.pump(const Duration(milliseconds: 250));
      expect(completed, isTrue);
    });
  });
}
