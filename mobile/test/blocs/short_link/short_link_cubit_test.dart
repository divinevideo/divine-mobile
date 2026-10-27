// ABOUTME: Ensures stale lookups cannot replace a newer short-link destination.
import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:openvine/blocs/short_link/short_link_cubit.dart';
import 'package:openvine/services/short_link_resolver.dart';

void main() {
  test('a late first lookup cannot replace the latest navigation', () async {
    final first = Completer<http.Response>();
    final client = MockClient((request) async {
      if (request.url.path.endsWith('First123')) return first.future;
      return http.Response(
        jsonEncode({
          'code': 'Next1234',
          'short_url': 'https://divine.video/l/Next1234',
          'url': 'https://divine.video/video/second-destination',
        }),
        200,
      );
    });
    final cubit = ShortLinkCubit(ShortLinkResolver(client: client));
    final pending = cubit.resolve(Uri.parse('https://divine.video/l/First123'));
    await cubit.resolve(Uri.parse('https://divine.video/l/Next1234'));
    expect((cubit.state as ShortLinkReady).link.videoRef, 'second-destination');
    first.complete(
      http.Response(
        jsonEncode({
          'code': 'First123',
          'short_url': 'https://divine.video/l/First123',
          'url': 'https://divine.video/video/first-destination',
        }),
        200,
      ),
    );
    await pending;
    expect((cubit.state as ShortLinkReady).link.videoRef, 'second-destination');
    await cubit.close();
    client.close();
  });

  test(
    'a failed lookup is retryable and closing drops later results',
    () async {
      var fail = true;
      final client = MockClient(
        (_) async => http.Response(
          fail
              ? '{}'
              : jsonEncode({
                  'code': 'Abc12345',
                  'short_url': 'https://divine.video/l/Abc12345',
                  'url': 'https://divine.video/video/retry-destination',
                }),
          fail ? 503 : 200,
        ),
      );
      final cubit = ShortLinkCubit(ShortLinkResolver(client: client));
      final url = Uri.parse('https://divine.video/l/Abc12345');
      await cubit.resolve(url);
      expect(cubit.state, isA<ShortLinkFailed>());
      fail = false;
      await cubit.resolve(url);
      expect(
        (cubit.state as ShortLinkReady).link.videoRef,
        'retry-destination',
      );
      final pending = cubit.resolve(url);
      await cubit.close();
      await pending;
      client.close();
    },
  );
}
