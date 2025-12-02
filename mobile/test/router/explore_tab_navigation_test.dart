// ABOUTME: Test that verifies Explore tab always resets to grid mode when tapped
// ABOUTME: Prevents bug where returning to Explore shows "No videos available" in feed mode

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mockito/annotations.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/router/page_context_provider.dart';
import 'package:openvine/router/route_utils.dart';
import 'package:openvine/router/router_location_provider.dart';
import 'package:openvine/screens/explore_screen.dart';

@GenerateNiceMocks([MockSpec<GoRouter>()])
void main() {
  group('Explore Tab Navigation', () {
    testWidgets(
      'tapping Explore tab after viewing a video should reset to grid mode, not feed mode',
      (tester) async {
        // ARRANGE: Set up providers to simulate navigation flow
        final container = ProviderContainer(
          overrides: [
            // Simulate URL changes: explore grid → explore feed → home → explore grid
            routerLocationStreamProvider.overrideWith((ref) {
              return Stream.fromIterable([
                '/explore', // 1. Initially on Explore grid
                '/explore/0', // 2. User taps video, enters feed mode
                '/home/0', // 3. User taps Home tab
                '/explore', // 4. User taps Explore tab - should reset to grid!
              ]);
            }),
            // Mock the exploreTabVideosProvider to return null (no videos stored)
            exploreTabVideosProvider.overrideWith((ref) => null),
          ],
        );

        addTearDown(container.dispose);

        // ACT: Build widget and pump through the navigation sequence
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: MaterialApp(
              home: Scaffold(
                body: Consumer(
                  builder: (context, ref, _) {
                    final ctx = ref.watch(pageContextProvider);
                    return ctx.when(
                      data: (context) => Text(
                        'Route: ${context.type}, Index: ${context.videoIndex}',
                      ),
                      loading: () => const CircularProgressIndicator(),
                      error: (e, s) => Text('Error: $e'),
                    );
                  },
                ),
              ),
            ),
          ),
        );

        // Wait for all route changes to complete
        await tester.pumpAndSettle();

        // ASSERT: Final route should be Explore in grid mode (videoIndex = null)
        final pageCtx = container.read(pageContextProvider).asData!.value;
        expect(
          pageCtx.type,
          RouteType.explore,
          reason: 'Should be on Explore tab',
        );
        expect(
          pageCtx.videoIndex,
          isNull,
          reason: 'Should be in grid mode, not feed mode',
        );
      },
    );

    testWidgets(
      'ExploreScreen should show TabBarView in grid mode, not "No videos available"',
      (tester) async {
        // ARRANGE: Set up providers for grid mode
        final container = ProviderContainer(
          overrides: [
            routerLocationStreamProvider.overrideWith(
              (ref) => Stream.value('/explore'),
            ),
            exploreTabVideosProvider.overrideWith((ref) => null),
          ],
        );

        addTearDown(container.dispose);

        // ACT: Build ExploreScreen in grid mode
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: Scaffold(body: ExploreScreen())),
          ),
        );

        await tester.pumpAndSettle();

        // ASSERT: Should show TabBarView tabs, not "No videos available" message
        expect(
          find.text('New Vines'),
          findsOneWidget,
          reason: 'Should show New Vines tab',
        );
        expect(
          find.text('Trending'),
          findsOneWidget,
          reason: 'Should show Trending tab',
        );
        expect(
          find.text("Editor's Pick"),
          findsOneWidget,
          reason: "Should show Editor's Pick tab",
        );
        expect(
          find.text('No videos available'),
          findsNothing,
          reason: 'Should NOT show "No videos available" in grid mode',
        );
      },
    );
  });
}
