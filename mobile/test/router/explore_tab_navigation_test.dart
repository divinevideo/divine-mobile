// ABOUTME: Test that verifies Explore tab always resets to grid mode when tapped
// ABOUTME: Prevents bug where returning to Explore shows "No videos available" in feed mode

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/route_feed_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
import 'package:openvine/screens/explore/widgets/explore_tab_bar.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../helpers/test_provider_overrides.dart';

void main() {
  group('Explore Tab Navigation', () {
    late SharedPreferences prefs;

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
    });

    testWidgets(
      'tapping Explore tab after viewing a video should reset to grid mode, not feed mode',
      (tester) async {
        // ARRANGE: Set up providers to simulate navigation flow
        final container = ProviderContainer(
          overrides: [
            sharedPreferencesProvider.overrideWithValue(prefs),
            // Simulate URL changes: explore grid → explore feed → home → explore grid
            routerLocationStreamProvider.overrideWith((ref) {
              return Stream.fromIterable([
                ExploreScreen.path, // 1. Initially on Explore grid
                ExploreScreen.pathForIndex(
                  0,
                ), // 2. User taps video, enters feed mode
                VideoFeedPage.pathForIndex(0), // 3. User taps Home tab
                ExploreScreen.path,
                // 4. User taps Explore tab - should reset to grid!
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
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
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
      'ExploreScreen shows the tab bar in grid mode, not the empty-feed message',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        final container = ProviderContainer(
          overrides: [
            ...getStandardTestOverrides(
              mockSharedPreferences: prefs,
              mockNostrService: createMockNostrServiceWithRelayStatus(),
            ),
            routerLocationStreamProvider.overrideWith(
              (ref) => Stream.value(ExploreScreen.path),
            ),
            exploreTabVideosProvider.overrideWith((ref) => null),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              locale: Locale('en'),
              home: Scaffold(body: ExploreScreen()),
            ),
          ),
        );
        await tester.pumpAndSettle();

        // Assert on the tab bar itself rather than on individual tab names:
        // the tab list is server-driven, so pinning labels here re-breaks the
        // test every time Explore gains or renames a tab. The contract is that
        // grid mode shows the bar at all instead of the feed's empty state.
        final tabBarFound = find.byType(ExploreTabBar).evaluate().length;
        final emptyMessageFound = find
            .text(l10n.exploreNoVideosAvailable)
            .evaluate()
            .length;

        await tester.pumpWidget(const SizedBox.shrink());
        container.dispose();
        await tester.pump(const Duration(milliseconds: 1));

        expect(
          tabBarFound,
          equals(1),
          reason: 'grid mode should render the Explore tab bar',
        );
        expect(
          emptyMessageFound,
          equals(0),
          reason: 'grid mode should not show the feed-mode empty state',
        );
      },
    );
  });
}
