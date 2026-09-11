// ABOUTME: Pins the screenshot-mode discovered-list fixtures: deterministic,
// ABOUTME: on-brand, and authorless so no by-line can leak into captures.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/lists_discovery/lists_discovery_screenshot_fixtures.dart';

void main() {
  group('screenshotDiscoverListsFixtures', () {
    test('fixtures are deterministic and on-brand', () {
      final fixtures = screenshotDiscoverListsFixtures();

      expect(fixtures, hasLength(6));
      expect(fixtures.map((list) => list.id).toSet(), hasLength(6));
      expect(fixtures.map((list) => list.name), everyElement(isNotEmpty));
      expect(
        fixtures.map((list) => list.videoEventIds),
        everyElement(isNotEmpty),
      );
      expect(fixtures.map((list) => list.pubkey), everyElement(isNull));
      expect(fixtures.map((list) => list.createdAt).toSet(), hasLength(1));
    });
  });
}
