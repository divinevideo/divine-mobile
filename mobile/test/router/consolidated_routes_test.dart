// ABOUTME: Tests for consolidated routes with optional parameters
// ABOUTME: Verifies single route handles both grid and feed modes without GlobalKey conflicts

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/explore/explore_screen.dart';
import 'package:openvine/screens/hashtag_screen_router.dart';

void main() {
  group('Consolidated Route Tests', () {
    test('parseRoute handles optional index for explore', () {
      final gridMode = parseRoute(ExploreScreen.path);
      expect(gridMode.type, RouteType.explore);
      expect(gridMode.videoIndex, null);

      final feedMode = parseRoute(ExploreScreen.pathForIndex(5));
      expect(feedMode.type, RouteType.explore);
      expect(feedMode.videoIndex, 5);
    });

    test('parseRoute handles hashtag grid mode', () {
      final gridMode = parseRoute(HashtagScreenRouter.pathForTag('bitcoin'));
      expect(gridMode.type, RouteType.hashtag);
      expect(gridMode.hashtag, 'bitcoin');
      expect(gridMode.videoIndex, null);
    });
  });
}
