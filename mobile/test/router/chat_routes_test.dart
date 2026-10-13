// ABOUTME: Tests the gate that keeps the Concord chat POC route closed
// ABOUTME: unless its internal flag is on and the account may message.

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/features/feature_flags/models/feature_flag.dart';
import 'package:openvine/features/feature_flags/providers/feature_flag_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/router/routes/chat_routes.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';

class _FakeBuildContext extends Fake implements BuildContext {}

class _FakeGoRouterState extends Fake implements GoRouterState {}

void main() {
  group('chatRedirectIfUnavailable', () {
    String? redirectWith({
      required bool chatEnabled,
      required bool dmRestricted,
    }) {
      final redirectProvider = Provider<String?>(chatRedirectIfUnavailable);
      final container = ProviderContainer(
        overrides: [
          featureFlagStateProvider.overrideWithValue({
            FeatureFlag.concordChat: chatEnabled,
          }),
          isDmRestrictedProvider.overrideWithValue(dmRestricted),
        ],
      );
      addTearDown(container.dispose);
      return container.read(redirectProvider);
    }

    test('sends the chat route home when the flag is off', () {
      expect(
        redirectWith(chatEnabled: false, dmRestricted: false),
        VideoFeedPage.pathForIndex(0),
      );
    });

    test('opens the chat route when the flag is on', () {
      expect(redirectWith(chatEnabled: true, dmRestricted: false), isNull);
    });

    test('keeps a messaging-restricted account out with the flag on', () {
      expect(
        redirectWith(chatEnabled: true, dmRestricted: true),
        VideoFeedPage.pathForIndex(0),
      );
    });

    test('the /chat route runs the gate before building', () async {
      final routesProvider = Provider<List<RouteBase>>(chatRoutes);
      final container = ProviderContainer(
        overrides: [
          featureFlagStateProvider.overrideWithValue({
            FeatureFlag.concordChat: false,
          }),
          isDmRestrictedProvider.overrideWithValue(false),
        ],
      );
      addTearDown(container.dispose);
      final route = container.read(routesProvider).single as GoRoute;

      expect(
        await route.redirect!(_FakeBuildContext(), _FakeGoRouterState()),
        VideoFeedPage.pathForIndex(0),
      );
    });
  });
}
