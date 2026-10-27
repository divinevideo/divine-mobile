// ABOUTME: Verifies short-link resolution and destination validation at the HTTP boundary.
import 'dart:async';
import 'dart:convert';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/services/deep_link_service.dart';
import 'package:openvine/services/short_link_resolver.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

void main() {
  const target = 'https://divine.video/video/CaseSensitive_Stable-ID';
  final shortUrl = Uri.parse('https://www.divine.video/l/Abc12345?ignored=1');
  String responseBody({String url = target, String code = 'Abc12345'}) =>
      jsonEncode({
        'code': code,
        'short_url': 'https://divine.video/l/$code',
        'url': url,
      });

  group('resolve', () {
    test(
      'resolves complete hex and checksum-valid npub profile destinations',
      () async {
        final hex = List.filled(32, '01').join();
        for (final id in [hex, NostrKeyUtils.encodePubKey(hex)]) {
          final resolver = ShortLinkResolver(
            client: MockClient(
              (_) async => http.Response(
                jsonEncode({
                  'code': 'Abc12345',
                  'short_url': 'https://divine.video/l/Abc12345',
                  'url': 'https://divine.video/profile/$id',
                }),
                200,
              ),
            ),
          );
          final result = await resolver.resolve(
            Uri.parse('https://divine.video/l/Abc12345'),
          );
          expect(result.type, DeepLinkType.profile);
          expect(result.npub, id);
        }
      },
    );
    test('resolves through the fixed canonical endpoint and preserves identifier case', () async {
      final resolver = ShortLinkResolver(
        client: MockClient((request) async {
          expect(
            request.url.toString(),
            'https://divine.video/api/links/Abc12345',
          );
          expect(request.followRedirects, isFalse);
          return http.Response(responseBody(), 200);
        }),
      );
      final result = await resolver.resolve(shortUrl);
      expect(result.type, DeepLinkType.video);
      expect(result.videoRef, 'CaseSensitive_Stable-ID');
    });

    test(
      'rejects malformed codes and untrusted origins before making a request',
      () async {
        var requests = 0;
        final resolver = ShortLinkResolver(
          client: MockClient((_) async {
            requests++;
            return http.Response(responseBody(), 200);
          }),
        );
        for (final url in [
          'https://evil.example/l/Abc12345',
          'https://alice.divine.video/l/Abc12345',
          'http://divine.video/l/Abc12345',
          'https://user@divine.video/l/Abc12345',
          'https://divine.video:8443/l/Abc12345',
          'https://divine.video/l/short',
          'https://divine.video/l/Abc%31345',
          'https://divine.video/l/Abc12345/extra',
        ]) {
          await expectLater(
            resolver.resolve(Uri.parse(url)),
            throwsA(isA<ShortLinkResolutionException>()),
          );
        }
        expect(requests, 0);
      },
    );

    test(
      'rejects mismatched aliases and destinations outside the service contract',
      () async {
        for (final body in [
          responseBody(code: 'Other123'),
          responseBody(url: 'https://evil.example/video/test'),
          responseBody(url: 'https://divine.video/l/Other123'),
          responseBody(url: 'https://divine.video/video/test?query=1'),
          responseBody(url: 'https://divine.video/video/%2e%2e'),
          responseBody(url: 'https://divine.video/profile/not-a-key'),
          responseBody(
            url: 'https://divine.video/profile/npub1invalidchecksum',
          ),
          ' ' * 4097,
          '{',
        ]) {
          final resolver = ShortLinkResolver(
            client: MockClient((_) async => http.Response(body, 200)),
          );
          await expectLater(
            resolver.resolve(shortUrl),
            throwsA(isA<ShortLinkResolutionException>()),
          );
        }
      },
    );

    test(
      'retries a propagation miss once and returns the resolved destination',
      () async {
        var attempts = 0;
        final resolver = ShortLinkResolver(
          client: MockClient((_) async {
            attempts++;
            return attempts == 1
                ? http.Response('{}', 404)
                : http.Response(responseBody(), 200);
          }),
        );
        final result = await resolver.resolve(shortUrl);
        expect(result.videoRef, 'CaseSensitive_Stable-ID');
        expect(attempts, 2);
      },
    );

    test(
      'bounds missing, unavailable, redirected and offline results',
      () async {
        for (final status in [302, 404, 503]) {
          var attempts = 0;
          final resolver = ShortLinkResolver(
            client: MockClient((_) async {
              attempts++;
              return http.Response('{}', status);
            }),
          );
          await expectLater(
            resolver.resolve(shortUrl),
            throwsA(isA<ShortLinkResolutionException>()),
          );
          expect(attempts, status == 302 ? 1 : 2);
        }
        final resolver = ShortLinkResolver(
          client: MockClient(
            (_) async => throw http.ClientException('offline'),
          ),
        );
        await expectLater(
          resolver.resolve(shortUrl),
          throwsA(isA<ShortLinkResolutionException>()),
        );
      },
    );

    test('times out the complete resolution within its total budget', () {
      fakeAsync((async) {
        final pending = Completer<http.Response>();
        final resolver = ShortLinkResolver(
          client: MockClient((_) => pending.future),
          timeout: const Duration(milliseconds: 10),
        );
        var timedOut = false;
        unawaited(
          resolver
              .resolve(shortUrl)
              .then<void>(
                (_) => fail('An unresolved request must time out'),
                onError: (Object error) {
                  expect(error, isA<ShortLinkResolutionException>());
                  timedOut = true;
                },
              ),
        );
        async.elapse(const Duration(milliseconds: 11));
        expect(timedOut, isTrue);
        pending.complete(http.Response('{}', 200));
        async.flushMicrotasks();
      });
    });
  });
}
