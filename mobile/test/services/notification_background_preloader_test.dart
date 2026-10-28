import 'dart:async';
import 'dart:convert';
import 'dart:io' as io;

import 'package:fake_async/fake_async.dart';
import 'package:file/local.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/notification_background_preloader.dart';

class _MockMediaCacheManager extends Mock implements MediaCacheManager {}

class _MockCacheOperation extends Mock implements CancellableCacheOperation {}

void main() {
  final author = 'a' * 64;
  final eventId = 'b' * 64;
  final otherAuthor = 'c' * 64;
  const thumbnail = 'https://example.com/thumbnail.jpg';

  group('cacheNotificationThumbnail', () {
    late _MockMediaCacheManager cache;
    late io.Directory directory;

    setUp(() {
      cache = _MockMediaCacheManager();
      directory = io.Directory.systemTemp.createTempSync('push_thumbnail_');
    });

    tearDown(() => directory.deleteSync(recursive: true));

    FileInfo indexed({required bool onDisk}) {
      final file = const LocalFileSystem().file(
        '${directory.path}/thumbnail.jpg',
      );
      if (onDisk) file.writeAsBytesSync([1]);
      return FileInfo(file, FileSource.Cache, DateTime.utc(2030), thumbnail);
    }

    test('reuses a thumbnail that is already on disk', () async {
      when(
        () => cache.getFileFromCache(thumbnail),
      ).thenAnswer((_) async => indexed(onDisk: true));

      await cacheNotificationThumbnail(thumbnail, cache: cache);

      verifyNever(
        () => cache.cacheFileCancellable(any(), key: any(named: 'key')),
      );
    });

    for (final onDisk in [null, false]) {
      test(
        'downloads under the URL key when the index '
        '${onDisk == null ? 'has no row' : 'points at a missing file'}',
        () async {
          when(() => cache.getFileFromCache(thumbnail)).thenAnswer(
            (_) async => onDisk == null ? null : indexed(onDisk: onDisk),
          );
          when(
            () => cache.cacheFileCancellable(thumbnail, key: thumbnail),
          ).thenReturn(
            CancellableCacheOperation.completed(
              io.File('${directory.path}/downloaded.jpg'),
            ),
          );

          await cacheNotificationThumbnail(thumbnail, cache: cache);

          verify(
            () => cache.cacheFileCancellable(thumbnail, key: thumbnail),
          ).called(1);
        },
      );
    }

    test('cancels a download that outlives its budget', () {
      fakeAsync((async) {
        final operation = _MockCacheOperation();
        when(
          () => operation.result,
        ).thenAnswer((_) => Completer<CancellableDownloadResult>().future);
        when(
          () => cache.getFileFromCache(thumbnail),
        ).thenAnswer((_) async => null);
        when(
          () => cache.cacheFileCancellable(thumbnail, key: thumbnail),
        ).thenReturn(operation);

        var settled = false;
        unawaited(
          cacheNotificationThumbnail(
            thumbnail,
            cache: cache,
          ).then((_) => settled = true),
        );
        async.elapse(const Duration(seconds: 3));

        expect(settled, isTrue);
        verify(operation.cancel).called(1);
      });
    });
  });

  group('preloadBackgroundNotification', () {
    for (final matchesAuthor in [true, false]) {
      test(
        'background thumbnail warming validates the coordinate author: $matchesAuthor',
        () async {
          final requests = <Uri>[];
          final cached = <String>[];
          final transport = MockClient((request) async {
            requests.add(request.url);
            return http.Response(
              jsonEncode({
                'event': {
                  'id': eventId,
                  'pubkey': matchesAuthor ? author : otherAuthor,
                  'created_at': 1735689600,
                  'kind': 34236,
                  'tags': [
                    ['d', 'synthetic-video'],
                    ['url', 'https://example.com/video.mp4'],
                    ['thumb', thumbnail],
                  ],
                  'content': 'Synthetic notification video',
                  'sig': 'd' * 128,
                },
              }),
              200,
            );
          });
          final api = FunnelcakeApiClient(
            baseUrl: 'https://example.com',
            httpClient: transport,
          );
          addTearDown(transport.close);
          await preloadBackgroundNotification(
            {
              'type': 'like',
              'referencedAddress': '34236:$author:synthetic-video',
            },
            apiClient: api,
            cacheThumbnail: (url) async {
              cached.add(url);
            },
          );
          expect(requests, [
            Uri.parse('https://example.com/api/videos/synthetic-video'),
          ]);
          expect(cached, matchesAuthor ? [thumbnail] : isEmpty);
        },
      );
    }

    test(
      'private and unsupported notifications cause no background requests',
      () async {
        var requests = 0;
        final transport = MockClient((request) async {
          requests++;
          return http.Response('', 500);
        });
        final api = FunnelcakeApiClient(
          baseUrl: 'https://example.com',
          httpClient: transport,
        );
        addTearDown(transport.close);
        for (final type in ['directMessage', 'campaign', 'unknown']) {
          await preloadBackgroundNotification({
            'type': type,
            'eventId': eventId,
          }, apiClient: api);
        }
        expect(requests, 0);
      },
    );
  });
}
