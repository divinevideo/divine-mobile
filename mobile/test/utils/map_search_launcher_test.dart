// ABOUTME: Tests which map a tapped location sticker opens: the phone's own
// ABOUTME: map app, and OpenStreetMap in the browser when there is none.

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/map_search_launcher.dart';
import 'package:url_launcher/url_launcher.dart';

void main() {
  group('openMapSearch', () {
    const place = 'Zermatt, Wallis, Schweiz';
    late List<Uri> launched;

    setUp(() => launched = []);

    MapUrlLauncher launcher({bool Function(Uri uri)? opens}) =>
        (uri, {mode = LaunchMode.platformDefault}) async {
          expect(mode, equals(LaunchMode.externalApplication));
          launched.add(uri);
          return opens?.call(uri) ?? true;
        };

    test('searches Apple Maps on iOS', () async {
      final opened = await openMapSearch(
        place,
        platform: TargetPlatform.iOS,
        isWeb: false,
        launch: launcher(),
      );

      expect(opened, isTrue);
      expect(launched.single.host, equals('maps.apple.com'));
      expect(launched.single.queryParameters['q'], equals(place));
    });

    test('hands Android a geo address for its map app', () async {
      await openMapSearch(
        place,
        platform: TargetPlatform.android,
        isWeb: false,
        launch: launcher(),
      );

      expect(launched.single.scheme, equals('geo'));
      expect(launched.single.queryParameters['q'], equals(place));
    });

    test('opens OpenStreetMap when Android has no map app', () async {
      final opened = await openMapSearch(
        place,
        platform: TargetPlatform.android,
        isWeb: false,
        launch: (uri, {mode = LaunchMode.platformDefault}) async {
          launched.add(uri);
          if (uri.isScheme('geo')) {
            throw PlatformException(code: 'ACTIVITY_NOT_FOUND');
          }
          return true;
        },
      );

      expect(opened, isTrue);
      expect(launched.last, equals(mapSearchWebUri(place)));
      expect(launched.last.queryParameters['query'], equals(place));
    });

    test('opens OpenStreetMap on the web', () async {
      await openMapSearch(
        place,
        platform: TargetPlatform.iOS,
        isWeb: true,
        launch: launcher(),
      );

      expect(launched, equals([mapSearchWebUri(place)]));
    });
  });
}
