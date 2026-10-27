// ABOUTME: Verifies bounded authenticated shortening, cache ownership and canonical fallback.
import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/services/short_link_client.dart';

void main() {
  const target = 'https://divine.video/video/CaseSensitive_Stable-ID';
  const short = 'https://divine.video/l/Abc12345';
  String mapping({String url = target, String code = 'Abc12345'}) =>
      jsonEncode({
        'code': code,
        'short_url': 'https://divine.video/l/$code',
        'url': url,
      });

  group('shorten', () {
    test(
      'disabled and unsupported targets do not sign or make requests',
      () async {
        var signs = 0;
        var requests = 0;
        final httpClient = MockClient((_) async {
          requests++;
          return http.Response('{}', 200);
        });
        final client = ShortLinkClient(
          client: httpClient,
          authorize: (_, _) async {
            signs++;
            return 'Nostr synthetic';
          },
        );
        expect(await client.shorten(target), target);
        final enabled = ShortLinkClient(
          client: httpClient,
          enabled: true,
          authorize: (_, _) async {
            signs++;
            return 'Nostr synthetic';
          },
        );
        for (final url in [
          'https://evil.example/video/a',
          'https://divine.video/video/a?q=1',
          'https://divine.video/l/Abc12345',
          'https://divine.video/profile/short',
        ]) {
          expect(await enabled.shorten(url), url);
        }
        expect(signs, 0);
        expect(requests, 0);
        client.close();
        enabled.close();
        httpClient.close();
      },
    );

    test(
      'binds exact body, deduplicates and caches only validated successes',
      () async {
        var requests = 0;
        final httpClient = MockClient((request) async {
          requests++;
          expect(
            request.url.toString(),
            'https://gateway.divine.video/api/links',
          );
          expect(request.method, 'POST');
          expect(request.followRedirects, isFalse);
          expect(request.headers['Authorization'], 'Nostr synthetic');
          expect(request.body, jsonEncode({'url': target}));
          return http.Response(mapping(), 201);
        });
        final client = ShortLinkClient(
          client: httpClient,
          enabled: true,
          authorize: (endpoint, body) async {
            expect(endpoint, 'https://gateway.divine.video/api/links');
            expect(body, jsonEncode({'url': target}));
            return 'Nostr synthetic';
          },
        );
        expect(
          await Future.wait([client.shorten(target), client.shorten(target)]),
          [short, short],
        );
        expect(await client.shorten(target), short);
        expect(requests, 1);
        client.close();
        httpClient.close();
      },
    );

    test('quota, unavailable, mismatched and oversized responses preserve the full URL and permit retry', () async {
      for (final bad in [
        http.Response('{}', 401),
        http.Response('{}', 429),
        http.Response('{}', 503),
        http.Response(mapping(url: 'https://divine.video/video/other'), 200),
        http.Response(mapping(code: 'short'), 200),
        http.Response(' ' * 4097, 200),
        http.Response('{', 200),
      ]) {
        var calls = 0;
        final httpClient = MockClient(
          (_) async => ++calls == 1 ? bad : http.Response(mapping(), 200),
        );
        final client = ShortLinkClient(
          client: httpClient,
          enabled: true,
          authorize: (_, _) async => 'Nostr synthetic',
        );
        expect(await client.shorten(target), target);
        expect(await client.shorten(target), short);
        client.close();
        httpClient.close();
      }
    });

    test('slow signing exhausts the total budget and cannot send late', () {
      fakeAsync((async) {
        final authorization = Completer<String?>();
        var requests = 0;
        final httpClient = MockClient((_) async {
          requests++;
          return http.Response(mapping(), 200);
        });
        final client = ShortLinkClient(
          client: httpClient,
          enabled: true,
          authorize: (_, _) => authorization.future,
        );
        String? result;
        unawaited(client.shorten(target).then((value) => result = value));
        async.elapse(const Duration(milliseconds: 2001));
        expect(result, target);
        authorization.complete('Nostr synthetic');
        async.flushMicrotasks();
        expect(requests, 0);
        client.close();
        httpClient.close();
      });
    });

    test(
      'closing during signing drops the request and cached results',
      () async {
        final authorization = Completer<String?>();
        var requests = 0;
        final httpClient = MockClient((_) async {
          requests++;
          return http.Response(mapping(), 200);
        });
        final client = ShortLinkClient(
          client: httpClient,
          enabled: true,
          authorize: (_, _) => authorization.future,
        );
        final result = client.shorten(target);
        client.close();
        authorization.complete('Nostr synthetic');
        expect(await result, target);
        expect(await client.shorten(target), target);
        expect(requests, 0);
        httpClient.close();
      },
    );
  });
}
