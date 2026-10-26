// ABOUTME: Tests for PublishedClipSourceResolver: a received clip that is an
// ABOUTME: already published post is traced to whoever published it.

import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:models/models.dart';
import 'package:openvine/services/published_clip_source_resolver.dart';

const _sha256 =
    '791b379f2921ae2e8f474e6ba3429dcbd270da0ce35e6b70207db32ed6bba7d4';
const _owner =
    '75bab6dccb6fbb9ef30597b43af6330b5933358a4cab11de51abb4f8836f7101';
const _uploadedAt = 1791393749;

VideoEvent _post({required String id, required String sha256}) => VideoEvent(
  id: id,
  pubkey: _owner,
  createdAt: _uploadedAt + 60,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(
    (_uploadedAt + 60) * 1000,
    isUtc: true,
  ),
  sha256: sha256,
);

VideoEvent _vine({
  required String id,
  required String sha256,
  int createdAt = 1458771798,
}) => VideoEvent(
  id: id,
  pubkey: _owner,
  createdAt: createdAt,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(
    createdAt * 1000,
    isUtc: true,
  ),
  sha256: sha256,
  rawTags: const {'platform': 'vine'},
);

http.Response _provenance({Object? owner = _owner}) => http.Response(
  jsonEncode({
    'owner': owner,
    'sha256': _sha256,
    'upload_auth_event': {'created_at': _uploadedAt, 'kind': 24242},
    'uploaders': [?owner],
  }),
  200,
);

void main() {
  group(PublishedClipSourceResolver, () {
    late List<Uri> requested;
    late List<({String pubkey, int limit, int? before})> authorQueries;

    late List<String> hashQueries;

    PublishedClipSourceResolver buildResolver({
      required http.Response Function() respond,
      List<VideoEvent> authorVideos = const [],
      Object? authorError,
      List<VideoEvent> hashVideos = const [],
      Object? hashError,
    }) {
      requested = [];
      authorQueries = [];
      hashQueries = [];
      return PublishedClipSourceResolver(
        mediaServer: Uri.parse('https://media.divine.video'),
        httpClientFactory: () => MockClient((request) async {
          requested.add(request.url);
          return respond();
        }),
        videosByAuthor: ({required pubkey, required limit, before}) async {
          authorQueries.add((pubkey: pubkey, limit: limit, before: before));
          if (authorError != null) throw authorError;
          return authorVideos;
        },
        videosByFileHash: (sha256) async {
          hashQueries.add(sha256);
          if (hashError != null) throw hashError;
          return hashVideos;
        },
      );
    }

    group('resolve', () {
      test('credits whoever published the file and finds the post', () async {
        final post = _post(id: 'e' * 64, sha256: _sha256);
        final resolver = buildResolver(
          respond: _provenance,
          authorVideos: [
            _post(id: 'f' * 64, sha256: 'a' * 64),
            post,
          ],
        );

        final source = await resolver.resolve(_sha256.toUpperCase());

        expect(source?.ownerPubkey, equals(_owner));
        expect(source?.video, same(post));
        expect(
          requested.single,
          equals(Uri.parse('https://media.divine.video/$_sha256/provenance')),
        );
        expect(authorQueries.single.pubkey, equals(_owner));
        expect(
          authorQueries.single.before,
          equals(
            _uploadedAt + PublishedClipSourceResolver.publishWindow.inSeconds,
          ),
        );
      });

      test('is null for a file the media server never held', () async {
        final resolver = buildResolver(respond: () => _provenance(owner: null));

        expect(await resolver.resolve(_sha256), isNull);
        expect(authorQueries, isEmpty);
      });

      test('is null for a file the media server does not know', () async {
        final resolver = buildResolver(respond: () => http.Response('', 404));

        expect(await resolver.resolve(_sha256), isNull);
      });

      test('still credits the owner when the post cannot be found', () async {
        final resolver = buildResolver(
          respond: _provenance,
          authorError: Exception('api down'),
        );

        final source = await resolver.resolve(_sha256);

        expect(source?.ownerPubkey, equals(_owner));
        expect(source?.video, isNull);
      });

      test('throws when the media server cannot be asked', () async {
        final resolver = buildResolver(respond: () => http.Response('', 503));

        await expectLater(
          resolver.resolve(_sha256),
          throwsA(isA<PublishedClipSourceLookupException>()),
        );
      });

      test('throws when the owner is not a pubkey', () async {
        final resolver = buildResolver(
          respond: () => _provenance(owner: 'not-a-pubkey'),
        );

        await expectLater(
          resolver.resolve(_sha256),
          throwsA(isA<PublishedClipSourceLookupException>()),
        );
      });
    });

    group('findArchivedVine', () {
      http.Response unused() => throw StateError('no provenance request');

      test('returns the oldest Vine post that names the file', () async {
        final claim = _post(id: 'f' * 64, sha256: _sha256);
        final vine = _vine(id: 'e' * 64, sha256: _sha256);
        final laterVine = _vine(
          id: 'd' * 64,
          sha256: _sha256,
          createdAt: 1772932336,
        );
        final resolver = buildResolver(
          respond: unused,
          hashVideos: [claim, laterVine, vine],
        );

        final found = await resolver.findArchivedVine(_sha256.toUpperCase());

        expect(found, same(vine));
        expect(hashQueries, equals([_sha256]));
        expect(requested, isEmpty);
      });

      test(
        'is null when only posts that are not Vines name the file',
        () async {
          final resolver = buildResolver(
            respond: unused,
            hashVideos: [_post(id: 'f' * 64, sha256: _sha256)],
          );

          expect(await resolver.findArchivedVine(_sha256), isNull);
        },
      );

      test('ignores a Vine post that names another file', () async {
        final resolver = buildResolver(
          respond: unused,
          hashVideos: [_vine(id: 'e' * 64, sha256: 'a' * 64)],
        );

        expect(await resolver.findArchivedVine(_sha256), isNull);
      });

      test('throws when the relays cannot be asked', () async {
        final resolver = buildResolver(
          respond: unused,
          hashError: Exception('no relay took the read'),
        );

        await expectLater(
          resolver.findArchivedVine(_sha256),
          throwsA(isA<PublishedClipSourceLookupException>()),
        );
      });
    });
  });
}
