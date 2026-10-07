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

    PublishedClipSourceResolver buildResolver({
      required http.Response Function() respond,
      List<VideoEvent> authorVideos = const [],
      Object? authorError,
    }) {
      requested = [];
      authorQueries = [];
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
  });
}
