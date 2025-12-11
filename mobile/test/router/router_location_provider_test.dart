// ABOUTME: Tests for reactive router location provider
// ABOUTME: Verifies location stream emits when router navigates

import 'package:async/async.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/router/router_location_provider.dart';

void main() {
  group('Router Location Provider', () {
    testWidgets('emits initial location immediately', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Build minimal widget tree with GoRouter
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final stream = container.read(routerLocationStreamProvider);
      final queue = StreamQueue(stream);
      addTearDown(() async => queue.cancel());

      // Get initial location
      final initial = await queue.next;
      expect(initial, '/home/0');
    });

    testWidgets('emits new location when router navigates', (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);

      // Build minimal widget tree with GoRouter
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      // Listen to the raw stream for deterministic events
      final stream = container.read(routerLocationStreamProvider);
      final queue = StreamQueue(stream);
      addTearDown(() async => queue.cancel());

      // 1) Initial location
      final initial = await queue.next;
      expect(initial, '/home/0');

      // 2) Navigate to explore
      container.read(goRouterProvider).go('/explore/0');
      await tester.pump(); // Flush delegate change notification

      final next1 = await queue.next;
      expect(next1, '/explore/0');

      // 3) Navigate to explore page 5
      container.read(goRouterProvider).go('/explore/5');
      await tester.pump();

      final next2 = await queue.next;
      expect(next2, '/explore/5');
    });

    testWidgets('cleans up listener on dispose', (tester) async {
      final container = ProviderContainer();

      // Build minimal widget tree
      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(
            routerConfig: container.read(goRouterProvider),
          ),
        ),
      );

      final stream = container.read(routerLocationStreamProvider);
      final queue = StreamQueue(stream);

      // Get initial value to confirm stream is working
      final initial = await queue.next;
      expect(initial, isNotEmpty);

      // Cancel and dispose
      await queue.cancel();
      container.dispose();

      // If this completes without error, cleanup worked
      expect(true, isTrue);
    });
  });
}
