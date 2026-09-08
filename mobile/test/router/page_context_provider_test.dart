// ABOUTME: Tests for the page context provider's route derivation.
// ABOUTME: Verifies router locations become structured, updating contexts.

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/settings/settings_screen.dart';
import 'package:openvine/screens/video_recorder_screen.dart';

void main() {
  group('Page Context Provider', () {
    Future<RouteContext> contextFor(String location) async {
      final container = ProviderContainer(
        overrides: [
          routerLocationStreamProvider.overrideWith(
            (ref) => Stream.value(location),
          ),
        ],
      );
      addTearDown(container.dispose);
      final result = Completer<RouteContext>();
      final subscription = container.listen(
        pageContextProvider,
        (_, next) {
          final value = next.value;
          if (value != null && !result.isCompleted) result.complete(value);
        },
        fireImmediately: true,
      );
      addTearDown(subscription.close);
      return result.future;
    }

    test('parses home route from router location', () async {
      final context = await contextFor('/home/0');
      expect(context.type, RouteType.home);
      expect(context.videoIndex, 0);
    });

    test('updates context when router location changes', () async {
      final locations = StreamController<String>();
      addTearDown(locations.close);
      final container = ProviderContainer(
        overrides: [
          routerLocationStreamProvider.overrideWith((ref) => locations.stream),
        ],
      );
      addTearDown(container.dispose);
      final contexts = StreamController<RouteContext>.broadcast();
      addTearDown(contexts.close);
      container.listen(
        pageContextProvider,
        (_, next) {
          final value = next.value;
          if (value != null) contexts.add(value);
        },
        fireImmediately: true,
      );

      locations.add('/home/0');
      var context = await contexts.stream.first;
      expect(context.type, RouteType.home);
      expect(context.videoIndex, 0);

      locations.add(ExploreScreen.pathForIndex(3));
      context = await contexts.stream.firstWhere(
        (value) => value.type == RouteType.explore,
      );
      expect(context.videoIndex, 3);

      locations.add(ProfileScreenRouter.pathForIndex('npub1test', 7));
      context = await contexts.stream.firstWhere(
        (value) => value.type == RouteType.profile,
      );
      expect(context.npub, 'npub1test');
      expect(context.videoIndex, 7);
    });

    test('parses hashtag route correctly', () async {
      final context = await contextFor(
        HashtagScreenRouter.pathForTag('bitcoin'),
      );
      expect(context.type, RouteType.hashtag);
      expect(context.hashtag, 'bitcoin');
      expect(context.videoIndex, isNull);
    });

    test('parses video-recorder route correctly', () async {
      final context = await contextFor(VideoRecorderScreen.path);
      expect(context.type, RouteType.videoRecorder);
      expect(context.videoIndex, isNull);
    });

    test('parses video-editor route correctly', () async {
      final context = await contextFor('/video-editor');
      expect(context.type, RouteType.videoEditor);
      expect(context.videoIndex, isNull);
    });

    test('parses settings route correctly', () async {
      final context = await contextFor(SettingsScreen.path);
      expect(context.type, RouteType.settings);
      expect(context.videoIndex, isNull);
    });
  });
}
