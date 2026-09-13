// ABOUTME: Tests geo-block API parsing, caching, and fail-open behavior.
// ABOUTME: Uses an injected HTTP client so tests never reach the network.

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/services/geo_blocking_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(GeoBlockResponse, () {
    test('defaults missing API fields to a fail-open response', () {
      final response = GeoBlockResponse.fromJson(const {});

      expect(response.blocked, isFalse);
      expect(response.country, 'UNKNOWN');
      expect(response.region, 'UNKNOWN');
      expect(response.city, 'UNKNOWN');
      expect(response.reason, isNull);
    });
  });

  group(GeoBlockingService, () {
    setUp(() => SharedPreferences.setMockInitialValues({}));

    test('accepts a 451 response and caches it for later instances', () async {
      var requests = 0;
      final client = MockClient((_) async {
        requests += 1;
        return http.Response(
          '{"blocked":true,"country":"US","region":"XX",'
          '"city":"Example","reason":"regional policy"}',
          451,
        );
      });
      final first = GeoBlockingService(client: client);

      final response = await first.checkGeoBlock();
      final cached = await GeoBlockingService(
        client: MockClient((_) async {
          fail('persistent cache should prevent a second request');
        }),
      ).checkGeoBlock();

      expect(response.blocked, isTrue);
      expect(response.region, 'XX');
      expect(cached.toJson(), response.toJson());
      expect(requests, 1);
    });

    test('fails open when the API returns an unexpected status', () async {
      final service = GeoBlockingService(
        client: MockClient((_) async => http.Response('unavailable', 503)),
      );

      final response = await service.checkGeoBlock();

      expect(response.blocked, isFalse);
      expect(response.country, 'UNKNOWN');
    });

    test('clearCache forces the next check back to the API', () async {
      var requests = 0;
      final service = GeoBlockingService(
        client: MockClient((_) async {
          requests += 1;
          return http.Response(
            '{"blocked":false,"country":"CA","region":"ON",'
            '"city":"Toronto"}',
            200,
          );
        }),
      );

      await service.checkGeoBlock();
      await service.checkGeoBlock();
      await service.clearCache();
      await service.checkGeoBlock();

      expect(requests, 2);
    });
  });
}
