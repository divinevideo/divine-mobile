// ABOUTME: Tests for fetching and caching the ProofSign C2PA trust anchors.

import 'package:cache_sync/cache_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/services/c2pa_trust_anchor_service.dart';

class _InMemoryCacheDao implements CacheDao {
  final Map<String, String> store = {};

  @override
  Future<String?> read(String key) async => store[key];

  @override
  Future<void> write({
    required String key,
    required String payload,
    Duration? ttl,
  }) async {
    store[key] = payload;
  }

  @override
  Future<void> delete(String key) async => store.remove(key);

  @override
  Future<void> deletePrefix(String prefix) async =>
      store.removeWhere((key, _) => key.startsWith(prefix));

  @override
  Future<int> totalPayloadBytes() async =>
      store.values.fold<int>(0, (sum, value) => sum + value.length);

  @override
  Future<void> evictOldest(int bytesToFree) async {}
}

const _certificate =
    '-----BEGIN CERTIFICATE-----\n'
    'MIIB0zCCAXmgAwIBAgIUAAAA\n'
    '-----END CERTIFICATE-----';

const _bundle =
    '# ProofSign current iOS signer\n'
    '$_certificate\n'
    '\n'
    '# ProofSign current Android signer\n'
    '$_certificate\n';

final Uri _anchorsUrl = Uri.parse(
  'https://proofsign.divine.video/.well-known/c2pa-trust-anchors.pem',
);

void main() {
  group(C2paTrustAnchorService, () {
    late DateTime now;
    late int requests;

    setUp(() async {
      await CacheSync.init(dao: _InMemoryCacheDao());
      now = DateTime(2026, 9, 28, 12);
      requests = 0;
    });

    C2paTrustAnchorService createService({http.Response Function()? respond}) {
      return C2paTrustAnchorService(
        now: () => now,
        httpClient: MockClient((request) async {
          requests++;
          expect(request.url, equals(_anchorsUrl));
          return (respond ?? () => http.Response(_bundle, 200))();
        }),
      );
    }

    group('load', () {
      test(
        'fetches the bundle and strips everything but certificates',
        () async {
          final anchors = await createService().load();

          expect(anchors, isNotNull);
          expect(anchors!.isFresh, isTrue);
          expect(anchors.pem, equals('$_certificate\n$_certificate\n'));
        },
      );

      test(
        'serves a bundle younger than the refresh interval from cache',
        () async {
          await createService().load();
          now = now.add(const Duration(minutes: 30));

          final anchors = await createService().load();

          expect(requests, equals(1));
          expect(anchors!.isFresh, isFalse);
        },
      );

      test('refetches a cached bundle when forced', () async {
        await createService().load();

        final anchors = await createService().load(forceRefresh: true);

        expect(requests, equals(2));
        expect(anchors!.isFresh, isTrue);
      });

      test(
        'falls back to a stale cached bundle when the fetch fails',
        () async {
          await createService().load();
          now = now.add(const Duration(days: 2));

          final anchors = await createService(
            respond: () => http.Response('unavailable', 503),
          ).load();

          expect(anchors, isNotNull);
          expect(anchors!.isFresh, isFalse);
        },
      );

      test('drops a cached bundle older than the stale limit', () async {
        await createService().load();
        now = now.add(const Duration(days: 8));

        final anchors = await createService(
          respond: () => http.Response('unavailable', 503),
        ).load();

        expect(anchors, isNull);
      });

      test(
        'does not trust a bundle cached under a clock that ran ahead',
        () async {
          await createService().load();
          now = now.subtract(const Duration(days: 30));

          final anchors = await createService(
            respond: () => http.Response('unavailable', 503),
          ).load();

          expect(requests, equals(2));
          expect(anchors, isNull);
        },
      );

      test('rejects a response without a certificate', () async {
        final anchors = await createService(
          respond: () => http.Response('<html>landing page</html>', 200),
        ).load();

        expect(anchors, isNull);
      });
    });
  });
}
