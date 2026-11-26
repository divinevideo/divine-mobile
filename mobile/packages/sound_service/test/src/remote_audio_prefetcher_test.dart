import 'dart:async';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:sound_service/sound_service.dart';

/// Records what the prefetcher asks of the cache and holds each request
/// until the test finishes it.
class _HeldCache extends Fake implements RemoteAudioCache {
  final downloads = <Uri>[];
  final warmed = <Uri>[];
  final kept = <Uri>{};
  final _pending = <Uri, Completer<void>>{};
  Exception? downloadError;

  @override
  File? cachedFileFor(Uri uri) => kept.contains(uri) ? File('/cache/x') : null;

  @override
  Future<File> fileFor(Uri uri) async {
    downloads.add(uri);
    await (_pending[uri] = Completer<void>()).future;
    if (downloadError case final error?) throw error;
    return File('/cache/${uri.pathSegments.last}');
  }

  @override
  Future<void> warm(Uri uri) {
    warmed.add(uri);
    return (_pending[uri] = Completer<void>()).future;
  }

  void finish(Uri uri) => _pending.remove(uri)!.complete();
}

Uri _sound(int n) => Uri.parse('https://media.example/sound-$n');

void main() {
  group(RemoteAudioPrefetcher, () {
    late _HeldCache cache;
    late RemoteAudioPrefetcher prefetcher;

    setUp(() {
      cache = _HeldCache();
      prefetcher = RemoteAudioPrefetcher(
        cache: cache,
        downloadUpTo: 1000,
        maxRunning: 2,
        maxWaiting: 3,
      );
    });

    tearDown(() => prefetcher.dispose());

    group('prefetch', () {
      test('downloads a small sound', () async {
        prefetcher.prefetch(_sound(1), sizeBytes: 800);
        await pumpEventQueue();

        expect(cache.downloads, [_sound(1)]);
        expect(cache.warmed, isEmpty);
      });

      test('only warms a large sound or one of unknown size', () async {
        prefetcher
          ..prefetch(_sound(1), sizeBytes: 5000000)
          ..prefetch(_sound(2));
        await pumpEventQueue();

        expect(cache.warmed, [_sound(1), _sound(2)]);
        expect(cache.downloads, isEmpty);
      });

      test('readies each sound once', () async {
        prefetcher.prefetch(_sound(1), sizeBytes: 800);
        await pumpEventQueue();
        cache.finish(_sound(1));
        await pumpEventQueue();
        prefetcher.prefetch(_sound(1), sizeBytes: 800);
        await pumpEventQueue();

        expect(cache.downloads, [_sound(1)]);
      });

      test('skips a sound the cache keeps, local sounds and no host', () async {
        cache.kept.add(_sound(1));
        prefetcher
          ..prefetch(_sound(1), sizeBytes: 800)
          ..prefetch(Uri.parse('asset://assets/sounds/bruh.mp3'))
          ..prefetch(Uri.file('/imports/song.m4a'))
          ..prefetch(Uri.parse('https:///sound'), sizeBytes: 800);
        await pumpEventQueue();

        expect(cache.downloads, isEmpty);
        expect(cache.warmed, isEmpty);
      });

      test('readies a few at a time, the one asked for last first', () async {
        for (var n = 1; n <= 4; n++) {
          prefetcher.prefetch(_sound(n), sizeBytes: 800);
        }
        await pumpEventQueue();
        expect(cache.downloads, [_sound(1), _sound(2)]);

        cache.finish(_sound(1));
        await pumpEventQueue();
        expect(cache.downloads, [_sound(1), _sound(2), _sound(4)]);
      });

      test('drops the sound that waited longest when too many wait', () async {
        for (var n = 1; n <= 6; n++) {
          prefetcher.prefetch(_sound(n), sizeBytes: 800);
        }
        await pumpEventQueue();
        // 1 and 2 run; 3, 4, 5 and 6 wait, one more than fits, so 3 goes.
        for (final n in [1, 2, 6, 5, 4]) {
          cache.finish(_sound(n));
          await pumpEventQueue();
        }

        expect(cache.downloads, [
          _sound(1),
          _sound(2),
          _sound(6),
          _sound(5),
          _sound(4),
        ]);
      });

      test('goes on after a download fails', () async {
        cache.downloadError = RemoteAudioDownloadException(
          _sound(1),
          statusCode: 502,
        );
        prefetcher
          ..prefetch(_sound(1), sizeBytes: 800)
          ..prefetch(_sound(2), sizeBytes: 800)
          ..prefetch(_sound(3), sizeBytes: 800);
        await pumpEventQueue();
        cache.finish(_sound(1));
        await pumpEventQueue();

        expect(cache.downloads, [_sound(1), _sound(2), _sound(3)]);
      });
    });

    group('dispose', () {
      test('stops readying sounds', () async {
        for (var n = 1; n <= 3; n++) {
          prefetcher.prefetch(_sound(n), sizeBytes: 800);
        }
        await pumpEventQueue();
        prefetcher
          ..dispose()
          ..prefetch(_sound(4), sizeBytes: 800);
        cache.finish(_sound(1));
        await pumpEventQueue();

        expect(cache.downloads, [_sound(1), _sound(2)]);
      });
    });
  });
}
