// ABOUTME: Tests the tag mapping for video-view traffic sources.
// ABOUTME: Tags are stored and parsed back, so every source must round-trip.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/view_traffic_source.dart';

void main() {
  group(ViewTrafficSource, () {
    group('toTag', () {
      test('keeps the discovery:new tag on the Latest feed', () {
        expect(ViewTrafficSource.discoveryNew.tagValue, 'discovery:new');
      });

      test('gives the New feed a tag of its own', () {
        expect(
          ViewTrafficSource.discoveryNewCreators.tagValue,
          'discovery:newcreators',
        );
      });
    });

    group('viewTrafficSourceFromTag', () {
      test('round-trips every source through its tag', () {
        for (final source in ViewTrafficSource.values) {
          expect(viewTrafficSourceFromTag(source.tagValue), source);
        }
      });

      test('reads the snake-case alias of the New feed', () {
        expect(
          viewTrafficSourceFromTag('discovery_new_creators'),
          ViewTrafficSource.discoveryNewCreators,
        );
      });
    });
  });
}
