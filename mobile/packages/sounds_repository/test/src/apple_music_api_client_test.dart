// ABOUTME: Tests for the Apple Music catalog client: the requests it sends,
// ABOUTME: the songs it reads from chart and search answers, and its errors.

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:mocktail/mocktail.dart';
import 'package:sounds_repository/sounds_repository.dart';
import 'package:test/test.dart';

class _MockHttpClient extends Mock implements http.Client {}

const _token = 'developer-token';

Map<String, dynamic> _songJson({
  String id = '1',
  String? name = 'Night Drive',
  String? artistName = 'The Paper Kites Club',
  String? url = 'https://music.apple.com/us/song/1',
  Object? previews = const [
    {'url': 'https://audio-ssl.itunes.apple.com/preview-1.m4a'},
  ],
  Object? artwork = const {
    'url': 'https://is1-ssl.mzstatic.com/image/1/{w}x{h}bb.jpg',
    'width': 3000,
    'height': 3000,
  },
  Object? genreNames = const ['Pop', 'Music'],
}) => {
  'id': id,
  'type': 'songs',
  'attributes': {
    'name': ?name,
    'artistName': ?artistName,
    'url': ?url,
    'previews': ?previews,
    'artwork': ?artwork,
    'genreNames': ?genreNames,
  },
};

http.Response _json(Object? body, {int status = 200}) => http.Response(
  jsonEncode(body),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

AppleMusicApiClient _clientAnswering(
  Object? body, {
  int status = 200,
  void Function(http.Request request)? onRequest,
}) => AppleMusicApiClient(
  developerToken: _token,
  httpClient: MockClient((request) async {
    onRequest?.call(request);
    return _json(body, status: status);
  }),
);

Map<String, dynamic> _chart(List<Object?> data) => {
  'results': {
    'songs': [
      {'chart': 'most-played', 'name': 'Top Songs', 'data': data},
    ],
  },
};

Map<String, dynamic> _search(List<Object?> data) => {
  'results': {
    'songs': {'data': data},
  },
};

void main() {
  group(AppleMusicApiClient, () {
    group('fetchTopSongs', () {
      test("asks the storefront's songs chart with the token", () async {
        late http.Request sent;
        final client = _clientAnswering(
          _chart([_songJson()]),
          onRequest: (request) => sent = request,
        );

        await client.fetchTopSongs(storefront: 'ar', limit: 30);

        expect(sent.method, equals('GET'));
        expect(sent.url.scheme, equals('https'));
        expect(sent.url.host, equals('api.music.apple.com'));
        expect(sent.url.path, equals('/v1/catalog/ar/charts'));
        expect(
          sent.url.queryParameters,
          equals({'types': 'songs', 'limit': '30'}),
        );
        expect(sent.headers['Authorization'], equals('Bearer $_token'));
      });

      test('reads the songs of the first chart, in order', () async {
        final client = _clientAnswering(
          _chart([
            _songJson(),
            _songJson(id: '2', name: 'Slow Morning'),
          ]),
        );

        final songs = await client.fetchTopSongs(storefront: 'us');

        expect(songs.map((song) => song.id), equals(['1', '2']));
        final first = songs.first;
        expect(first.name, equals('Night Drive'));
        expect(first.artistName, equals('The Paper Kites Club'));
        expect(first.url, equals('https://music.apple.com/us/song/1'));
        expect(
          first.previewUrl,
          equals('https://audio-ssl.itunes.apple.com/preview-1.m4a'),
        );
        expect(first.genreNames, equals(['Pop', 'Music']));
        expect(
          first.artworkUrl(200),
          equals('https://is1-ssl.mzstatic.com/image/1/200x200bb.jpg'),
        );
      });

      test('keeps the limit within what the chart accepts', () async {
        final limits = <String?>[];
        final client = _clientAnswering(
          _chart(const []),
          onRequest: (request) =>
              limits.add(request.url.queryParameters['limit']),
        );

        await client.fetchTopSongs(storefront: 'us', limit: 5000);
        await client.fetchTopSongs(storefront: 'us', limit: 0);

        expect(limits, equals(['200', '1']));
      });

      test('leaves out rows that are not songs with a title, an artist and '
          'a page', () async {
        final client = _clientAnswering(
          _chart([
            'not a row',
            {'id': 7, 'attributes': <String, dynamic>{}},
            {'id': '8'},
            _songJson(id: '9', name: null),
            _songJson(id: '10', artistName: null),
            _songJson(id: '11', url: null),
            _songJson(id: '12'),
          ]),
        );

        final songs = await client.fetchTopSongs(storefront: 'us');

        expect(songs.map((song) => song.id), equals(['12']));
      });

      test('reads a song without preview, artwork or genres', () async {
        final client = _clientAnswering(
          _chart([
            _songJson(previews: null, artwork: null, genreNames: null),
            _songJson(
              id: '2',
              previews: const [
                'not a preview',
                {'hlsUrl': 'https://example.com/preview.m3u8'},
              ],
              artwork: const {'width': 100},
              genreNames: 'Pop',
            ),
          ]),
        );

        final songs = await client.fetchTopSongs(storefront: 'us');

        expect(songs, hasLength(2));
        for (final song in songs) {
          expect(song.previewUrl, isNull);
          expect(song.artworkUrl(200), isNull);
          expect(song.genreNames, isEmpty);
        }
      });

      test('answers with no songs when the charts are missing', () async {
        for (final body in <Map<String, dynamic>>[
          {'results': <String, dynamic>{}},
          {
            'results': {'songs': <Object?>[]},
          },
          {
            'results': {
              'songs': [
                {'chart': 'most-played'},
              ],
            },
          },
          {'results': 'unexpected'},
        ]) {
          final songs = await _clientAnswering(
            body,
          ).fetchTopSongs(storefront: 'us');

          expect(songs, isEmpty, reason: 'for $body');
        }
      });
    });

    group('searchSongs', () {
      test('searches songs for the trimmed term', () async {
        late http.Request sent;
        final client = _clientAnswering(
          _search([_songJson()]),
          onRequest: (request) => sent = request,
        );

        await client.searchSongs(storefront: 'us', term: '  paper kites  ');

        expect(sent.url.path, equals('/v1/catalog/us/search'));
        expect(
          sent.url.queryParameters,
          equals({'term': 'paper kites', 'types': 'songs', 'limit': '25'}),
        );
        expect(sent.headers['Authorization'], equals('Bearer $_token'));
      });

      test('reads the matching songs, best match first', () async {
        final client = _clientAnswering(
          _search([
            _songJson(id: '5', name: 'Second Song'),
            _songJson(id: '6', name: 'Third Song'),
          ]),
        );

        final songs = await client.searchSongs(storefront: 'us', term: 'kites');

        expect(
          songs.map((song) => song.name),
          equals(['Second Song', 'Third Song']),
        );
      });

      test('keeps the limit within what a search accepts', () async {
        final limits = <String?>[];
        final client = _clientAnswering(
          _search(const []),
          onRequest: (request) =>
              limits.add(request.url.queryParameters['limit']),
        );

        await client.searchSongs(storefront: 'us', term: 'a', limit: 100);
        await client.searchSongs(storefront: 'us', term: 'a', limit: -3);

        expect(limits, equals(['25', '1']));
      });

      test('answers with no songs when nothing matches', () async {
        final client = _clientAnswering({
          'results': <String, dynamic>{},
          'meta': <String, dynamic>{},
        });

        final songs = await client.searchSongs(storefront: 'us', term: 'zzzz');

        expect(songs, isEmpty);
      });

      test('refuses a blank term without asking the catalog', () async {
        var requests = 0;
        final client = _clientAnswering(
          _search(const []),
          onRequest: (_) => requests++,
        );

        await expectLater(
          client.searchSongs(storefront: 'us', term: '   '),
          throwsA(isA<AppleMusicApiException>()),
        );
        expect(requests, equals(0));
      });
    });

    group('a failed request', () {
      test('carries the status the catalog answered with', () async {
        final client = _clientAnswering({
          'errors': <Object?>[],
        }, status: 401);

        await expectLater(
          client.fetchTopSongs(storefront: 'us'),
          throwsA(
            isA<AppleMusicApiException>().having(
              (error) => error.statusCode,
              'statusCode',
              equals(401),
            ),
          ),
        );
      });

      test('is reported when the catalog does not answer in time', () async {
        final client = AppleMusicApiClient(
          developerToken: _token,
          httpClient: MockClient((_) => Completer<http.Response>().future),
          timeout: const Duration(milliseconds: 1),
        );

        await expectLater(
          client.fetchTopSongs(storefront: 'us'),
          throwsA(
            isA<AppleMusicApiException>()
                .having((error) => error.statusCode, 'statusCode', isNull)
                .having(
                  (error) => error.message,
                  'message',
                  contains('timed out'),
                ),
          ),
        );
      });

      test('is reported when the connection fails', () async {
        final client = AppleMusicApiClient(
          developerToken: _token,
          httpClient: MockClient(
            (_) async => throw http.ClientException('connection closed'),
          ),
        );

        await expectLater(
          client.searchSongs(storefront: 'us', term: 'a'),
          throwsA(
            isA<AppleMusicApiException>().having(
              (error) => error.message,
              'message',
              contains('connection closed'),
            ),
          ),
        );
      });

      test('is reported when the answer is not JSON', () async {
        final client = AppleMusicApiClient(
          developerToken: _token,
          httpClient: MockClient(
            (_) async => http.Response('<html>', 200),
          ),
        );

        await expectLater(
          client.fetchTopSongs(storefront: 'us'),
          throwsA(
            isA<AppleMusicApiException>().having(
              (error) => error.message,
              'message',
              contains('not valid JSON'),
            ),
          ),
        );
      });

      test('is reported when the answer is not a JSON object', () async {
        final client = _clientAnswering(const ['unexpected']);

        await expectLater(
          client.fetchTopSongs(storefront: 'us'),
          throwsA(
            isA<AppleMusicApiException>().having(
              (error) => error.message,
              'message',
              contains('invalid'),
            ),
          ),
        );
      });

      test('never puts the token in its description', () async {
        final client = _clientAnswering(const <String, dynamic>{}, status: 500);

        Object? caught;
        try {
          await client.fetchTopSongs(storefront: 'us');
        } on AppleMusicApiException catch (error) {
          caught = error;
        }

        expect(caught, isNotNull);
        expect(caught.toString(), isNot(contains(_token)));
        expect(caught.toString(), contains('500'));
      });
    });

    group('close', () {
      test('closes the HTTP client it was given', () {
        final httpClient = _MockHttpClient();
        AppleMusicApiClient(
          developerToken: _token,
          httpClient: httpClient,
        ).close();

        verify(httpClient.close).called(1);
      });

      test('closes the HTTP client it made for itself', () {
        final client = AppleMusicApiClient(developerToken: _token);

        expect(client.close, returnsNormally);
      });
    });
  });

  group(AppleMusicApiException, () {
    test('describes a request that got no answer', () {
      expect(
        const AppleMusicApiException(
          'Apple Music request timed out',
        ).toString(),
        equals(
          'AppleMusicApiException: Apple Music request timed out (no status)',
        ),
      );
    });
  });
}
