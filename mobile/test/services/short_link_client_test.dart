// ABOUTME: Verifies anonymous shortening, bounded requests and canonical fallback.
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

  test('disabled and unsupported destinations make no requests', () async {
    var requests = 0;
    final transport = MockClient((_) async {
      requests++;
      return http.Response('{}', 200);
    });
    final disabled = ShortLinkClient(client: transport);
    final enabled = ShortLinkClient(client: transport, enabled: true);
    expect(await disabled.shorten(target), target);
    for (final url in [
      'https://evil.example/video/a',
      'https://divine.video/video/a?q=1',
      'https://divine.video/l/Abc12345',
      'https://divine.video/profile/short',
    ]) {
      expect(await enabled.shorten(url), url);
    }
    expect(requests, 0);
    disabled.close();
    enabled.close();
    transport.close();
  });

  test(
    'creates anonymously, deduplicates and caches validated successes',
    () async {
      var requests = 0;
      final transport = MockClient((request) async {
        requests++;
        expect(
          request.url.toString(),
          'https://gateway.divine.video/api/links',
        );
        expect(request.method, 'POST');
        expect(request.followRedirects, isFalse);
        expect(request.headers.containsKey('Authorization'), isFalse);
        expect(request.body, jsonEncode({'url': target}));
        return http.Response(mapping(), 201);
      });
      final client = ShortLinkClient(client: transport, enabled: true);
      expect(
        await Future.wait([client.shorten(target), client.shorten(target)]),
        [short, short],
      );
      expect(await client.shorten(target), short);
      expect(requests, 1);
      client.close();
      transport.close();
    },
  );

  test(
    'failed and invalid responses preserve the full URL and permit retry',
    () async {
      for (final bad in [
        http.Response('{}', 401),
        http.Response('{}', 429),
        http.Response('{}', 503),
        http.Response(mapping(url: 'https://divine.video/video/other'), 200),
        http.Response(mapping(code: 'short'), 200),
        http.Response(' ' * 4097, 200),
        http.Response('{', 200),
      ]) {
        var requests = 0;
        final transport = MockClient(
          (_) async => ++requests == 1 ? bad : http.Response(mapping(), 200),
        );
        final client = ShortLinkClient(client: transport, enabled: true);
        expect(await client.shorten(target), target);
        expect(await client.shorten(target), short);
        client.close();
        transport.close();
      }
    },
  );

  test(
    'slow HTTP work exhausts the budget and late responses are not cached',
    () {
      fakeAsync((async) {
        final response = Completer<http.Response>();
        final transport = MockClient((_) => response.future);
        final client = ShortLinkClient(client: transport, enabled: true);
        String? result;
        unawaited(client.shorten(target).then((value) => result = value));
        async.flushMicrotasks();
        async.elapse(const Duration(milliseconds: 2001));
        expect(result, target);
        response.complete(http.Response(mapping(), 200));
        async.flushMicrotasks();
        expect(result, target);
        client.close();
        transport.close();
      });
    },
  );

  test('closing drops pending responses and cached results', () async {
    final response = Completer<http.Response>();
    final transport = MockClient((_) => response.future);
    final client = ShortLinkClient(client: transport, enabled: true);
    final pending = client.shorten(target);
    client.close();
    response.complete(http.Response(mapping(), 200));
    expect(await pending, target);
    expect(await client.shorten(target), target);
    transport.close();
  });
}
