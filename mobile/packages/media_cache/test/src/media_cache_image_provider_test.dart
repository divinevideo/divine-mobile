import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:file/local.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';

import 'helpers/mocks.dart';
import 'helpers/test_helpers.dart';

const _transparentPng = <int>[
  0x89,
  0x50,
  0x4E,
  0x47,
  0x0D,
  0x0A,
  0x1A,
  0x0A,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x48,
  0x44,
  0x52,
  0x00,
  0x00,
  0x00,
  0x01,
  0x00,
  0x00,
  0x00,
  0x01,
  0x08,
  0x06,
  0x00,
  0x00,
  0x00,
  0x1F,
  0x15,
  0xC4,
  0x89,
  0x00,
  0x00,
  0x00,
  0x0D,
  0x49,
  0x44,
  0x41,
  0x54,
  0x78,
  0x9C,
  0x63,
  0xF8,
  0xCF,
  0xC0,
  0x00,
  0x00,
  0x03,
  0x01,
  0x01,
  0x00,
  0x18,
  0xDD,
  0x8D,
  0xB1,
  0x00,
  0x00,
  0x00,
  0x00,
  0x49,
  0x45,
  0x4E,
  0x44,
  0xAE,
  0x42,
  0x60,
  0x82,
];

class _MockMediaCacheManager extends Mock implements MediaCacheManager {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('MediaCacheImageProvider', () {
    setUpTestEnvironment();

    setUpAll(() async {
      await setUpTestDirectories();
    });

    tearDownAll(() async {
      await tearDownTestDirectories();
    });

    test('obtainKey returns the provider synchronously', () async {
      const url = 'https://example.com/image.jpg';
      final cacheManager = _MockMediaCacheManager();
      final provider = MediaCacheImageProvider(url, cacheManager: cacheManager);

      final key = await provider.obtainKey(ImageConfiguration.empty);

      expect(key, same(provider));
    });

    test(
      'equal providers with separate but equal authHeaders share a hash code',
      () {
        const url = 'https://example.com/image.jpg';
        final cacheManager = _MockMediaCacheManager();
        final first = MediaCacheImageProvider(
          url,
          cacheManager: cacheManager,
          authHeaders: const {
            'Authorization': 'Bearer token',
            'X-Trace': 'abc123',
          },
        );
        final second = MediaCacheImageProvider(
          url,
          cacheManager: cacheManager,
          authHeaders: const {
            'X-Trace': 'abc123',
            'Authorization': 'Bearer token',
          },
        );

        expect(first, equals(second));
        expect(first.hashCode, equals(second.hashCode));
      },
    );

    test('cacheKey and scale still participate in equality', () {
      const url = 'https://example.com/image.jpg';
      final cacheManager = _MockMediaCacheManager();
      final base = MediaCacheImageProvider(url, cacheManager: cacheManager);
      final customCacheKey = MediaCacheImageProvider(
        url,
        cacheManager: cacheManager,
        cacheKey: 'custom-key',
      );
      final customScale = MediaCacheImageProvider(
        url,
        cacheManager: cacheManager,
        scale: 2,
      );

      expect(base, isNot(equals(customCacheKey)));
      expect(base.hashCode, isNot(equals(customCacheKey.hashCode)));
      expect(base, isNot(equals(customScale)));
      expect(base.hashCode, isNot(equals(customScale.hashCode)));
    });

    test(
      'cancels in-flight download when the last listener is removed',
      () async {
        const url = 'https://example.com/image.jpg';
        final cacheManager = _MockMediaCacheManager();
        final download = FakeCancellableDownload(
          url: url,
          targetFile: File('$testTempPath/pending.jpg'),
          headers: null,
        );
        final operation = CancellableCacheOperation.fromDownload(download);

        when(
          () => cacheManager.getFileFromCache(url),
        ).thenAnswer((_) async => null);
        when(
          () => cacheManager.cacheFileCancellable(url, key: url),
        ).thenReturn(operation);

        final provider = MediaCacheImageProvider(
          url,
          cacheManager: cacheManager,
        );
        final completer = provider.loadImage(
          provider,
          (buffer, {getTargetSize}) => Completer<ui.Codec>().future,
        );
        final listener = ImageStreamListener((image, synchronousCall) {
          image.dispose();
        });

        completer.addListener(listener);
        await Future<void>.delayed(Duration.zero);

        verify(() => cacheManager.getFileFromCache(url)).called(1);
        verify(
          () => cacheManager.cacheFileCancellable(url, key: url),
        ).called(1);
        expect(download.isCancelled, isFalse);

        completer.removeListener(listener);

        expect(download.isCancelled, isTrue);
      },
    );

    test(
      'keeps a shared in-flight download alive until every listener leaves',
      () async {
        const url = 'https://example.com/image.jpg';
        final cacheManager = _MockMediaCacheManager();
        final download = FakeCancellableDownload(
          url: url,
          targetFile: File('$testTempPath/shared.jpg'),
          headers: null,
        );
        final operation = CancellableCacheOperation.fromDownload(download);

        when(
          () => cacheManager.getFileFromCache(url),
        ).thenAnswer((_) async => null);
        when(
          () => cacheManager.cacheFileCancellable(url, key: url),
        ).thenReturn(operation);

        final provider = MediaCacheImageProvider(
          url,
          cacheManager: cacheManager,
        );
        final completer = provider.loadImage(
          provider,
          (buffer, {getTargetSize}) => Completer<ui.Codec>().future,
        );
        final firstListener = ImageStreamListener((image, synchronousCall) {
          image.dispose();
        });
        final secondListener = ImageStreamListener((image, synchronousCall) {
          image.dispose();
        });

        completer
          ..addListener(firstListener)
          ..addListener(secondListener);
        await Future<void>.delayed(Duration.zero);

        verify(() => cacheManager.getFileFromCache(url)).called(1);
        verify(
          () => cacheManager.cacheFileCancellable(url, key: url),
        ).called(1);

        completer.removeListener(firstListener);
        expect(download.isCancelled, isFalse);

        completer.removeListener(secondListener);
        expect(download.isCancelled, isTrue);
      },
    );

    test(
      'decodes an existing cached file without starting a new download',
      () async {
        const url = 'https://example.com/cached-image.jpg';
        final cacheManager = _MockMediaCacheManager();
        final imageFile = const LocalFileSystem().file(
          '$testTempPath/cached-image.png',
        )..writeAsBytesSync(Uint8List.fromList(_transparentPng));

        final fileInfo = MockFileInfo();
        when(() => fileInfo.file).thenReturn(imageFile);
        when(
          () => cacheManager.getFileFromCache(url),
        ).thenAnswer((_) async => fileInfo);

        var decodeCalled = false;
        final decodeAttempted = Completer<void>();
        final provider = MediaCacheImageProvider(
          url,
          cacheManager: cacheManager,
        );
        final completer = provider.loadImage(provider, (
          buffer, {
          getTargetSize,
        }) {
          decodeCalled = true;
          if (!decodeAttempted.isCompleted) {
            decodeAttempted.complete();
          }
          throw StateError('stop after verifying decode entry');
        });
        final listener = ImageStreamListener((image, synchronousCall) {
          image.dispose();
        }, onError: (error, stackTrace) {});

        completer.addListener(listener);
        await decodeAttempted.future;

        expect(decodeCalled, isTrue);
        verify(() => cacheManager.getFileFromCache(url)).called(1);
        verifyNever(
          () =>
              cacheManager.cacheFileCancellable(any(), key: any(named: 'key')),
        );

        completer.removeListener(listener);
      },
    );

    test('decodes a downloaded dart:io file after cache miss', () async {
      const url = 'https://example.com/downloaded-image.png';
      final cacheManager = _MockMediaCacheManager();
      final imageFile = File('$testTempPath/downloaded-image.png')
        ..writeAsBytesSync(Uint8List.fromList(_transparentPng));
      final download = FakeCancellableDownload(
        url: url,
        targetFile: imageFile,
        headers: null,
      );
      final operation = CancellableCacheOperation.fromDownload(download);

      when(
        () => cacheManager.getFileFromCache(url),
      ).thenAnswer((_) async => null);
      when(
        () => cacheManager.cacheFileCancellable(url, key: url),
      ).thenReturn(operation);

      var decodeCalled = false;
      final decodeAttempted = Completer<void>();
      final provider = MediaCacheImageProvider(url, cacheManager: cacheManager);
      final completer = provider.loadImage(provider, (buffer, {getTargetSize}) {
        decodeCalled = true;
        if (!decodeAttempted.isCompleted) {
          decodeAttempted.complete();
        }
        throw StateError('stop after verifying decode entry');
      });
      final listener = ImageStreamListener((image, synchronousCall) {
        image.dispose();
      }, onError: (error, stackTrace) {});

      completer.addListener(listener);
      await Future<void>.delayed(Duration.zero);
      download.completeWith(imageFile);
      await decodeAttempted.future;

      expect(decodeCalled, isTrue);
      verify(() => cacheManager.getFileFromCache(url)).called(1);
      verify(() => cacheManager.cacheFileCancellable(url, key: url)).called(1);

      completer.removeListener(listener);
    });

    test('evicts and stops decode when the download resolves null', () async {
      const url = 'https://example.com/cancelled-image.png';
      final cacheManager = _MockMediaCacheManager();
      final download = FakeCancellableDownload(
        url: url,
        targetFile: File('$testTempPath/cancelled-image.png'),
        headers: null,
      );
      final operation = CancellableCacheOperation.fromDownload(download);

      when(
        () => cacheManager.getFileFromCache(url),
      ).thenAnswer((_) async => null);
      when(
        () => cacheManager.cacheFileCancellable(url, key: url),
      ).thenReturn(operation);

      final provider = MediaCacheImageProvider(url, cacheManager: cacheManager);
      final errors = <Object>[];
      final completer = provider.loadImage(provider, (buffer, {getTargetSize}) {
        throw StateError('decode should not run after null result');
      });
      final listener = ImageStreamListener(
        (image, synchronousCall) {
          image.dispose();
        },
        onError: (error, stackTrace) {
          errors.add(error);
        },
      );

      completer.addListener(listener);
      await Future<void>.delayed(Duration.zero);
      download.completeNull();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(errors, hasLength(1));
      final failure = errors.single;
      expect(failure, isA<MediaCacheImageLoadException>());
      expect((failure as MediaCacheImageLoadException).url, equals(url));
      expect(failure.toString(), contains(url));
      expect(failure.toString(), contains('download completed without a file'));
      expect(
        PaintingBinding.instance.imageCache.containsKey(provider),
        isFalse,
      );

      completer.removeListener(listener);
    });

    test('does not report a FlutterError when the last listener leaves '
        'before an in-flight download resolves', () async {
      const url = 'https://example.com/scrolled-away.png';
      final cacheManager = _MockMediaCacheManager();
      final download = FakeCancellableDownload(
        url: url,
        targetFile: File('$testTempPath/scrolled-away.png'),
        headers: null,
      );
      final operation = CancellableCacheOperation.fromDownload(download);

      when(
        () => cacheManager.getFileFromCache(url),
      ).thenAnswer((_) async => null);
      when(
        () => cacheManager.cacheFileCancellable(url, key: url),
      ).thenReturn(operation);

      final flutterErrors = <FlutterErrorDetails>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = flutterErrors.add;
      addTearDown(() => FlutterError.onError = previousOnError);

      final provider = MediaCacheImageProvider(url, cacheManager: cacheManager);
      final completer = provider.loadImage(
        provider,
        (buffer, {getTargetSize}) => Completer<ui.Codec>().future,
      );
      final listener = ImageStreamListener((image, synchronousCall) {
        image.dispose();
      });

      completer.addListener(listener);
      await Future<void>.delayed(Duration.zero);

      completer.removeListener(listener);
      expect(download.isCancelled, isTrue);

      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(flutterErrors, isEmpty);
      expect(
        PaintingBinding.instance.imageCache.containsKey(provider),
        isFalse,
      );
    });

    test('throws for an empty cached file', () async {
      const url = 'https://example.com/empty-image.png';
      final cacheManager = _MockMediaCacheManager();
      final imageFile = const LocalFileSystem().file(
        '$testTempPath/empty-image.png',
      )..writeAsBytesSync(Uint8List(0));

      final fileInfo = MockFileInfo();
      when(() => fileInfo.file).thenReturn(imageFile);
      when(
        () => cacheManager.getFileFromCache(url),
      ).thenAnswer((_) async => fileInfo);

      final provider = MediaCacheImageProvider(url, cacheManager: cacheManager);
      final errors = <Object>[];
      final errorReported = Completer<void>();
      final completer = provider.loadImage(provider, (buffer, {getTargetSize}) {
        throw StateError('decode should not run for an empty file');
      });
      final listener = ImageStreamListener(
        (image, synchronousCall) {
          image.dispose();
        },
        onError: (error, stackTrace) {
          errors.add(error);
          errorReported.complete();
        },
      );

      completer.addListener(listener);
      await errorReported.future.timeout(const Duration(seconds: 5));

      expect(errors, hasLength(1));
      expect(errors.single, isA<StateError>());
      expect(errors.single.toString(), contains('is empty'));

      completer.removeListener(listener);
    });

    test('skips the download and reports nothing when cancelled before the '
        'cache miss resolves', () async {
      const url = 'https://example.com/cancel-before-download.png';
      final cacheManager = _MockMediaCacheManager();
      final release = Completer<void>();
      when(() => cacheManager.getFileFromCache(url)).thenAnswer((_) async {
        await release.future;
        return null;
      });

      final flutterErrors = <FlutterErrorDetails>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = flutterErrors.add;
      addTearDown(() => FlutterError.onError = previousOnError);

      final provider = MediaCacheImageProvider(url, cacheManager: cacheManager);
      final completer = provider.loadImage(
        provider,
        (buffer, {getTargetSize}) => Completer<ui.Codec>().future,
      );
      final listener = ImageStreamListener((image, synchronousCall) {
        image.dispose();
      });

      completer.addListener(listener);
      await Future<void>.delayed(Duration.zero);

      completer.removeListener(listener);
      release.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(flutterErrors, isEmpty);
      verifyNever(
        () => cacheManager.cacheFileCancellable(any(), key: any(named: 'key')),
      );
      expect(
        PaintingBinding.instance.imageCache.containsKey(provider),
        isFalse,
      );
    });

    test('does not decode or report when cancelled while an existing cache '
        'entry resolves', () async {
      const url = 'https://example.com/cancel-existing.png';
      final cacheManager = _MockMediaCacheManager();
      final imageFile = const LocalFileSystem().file(
        '$testTempPath/cancel-existing.png',
      )..writeAsBytesSync(Uint8List.fromList(_transparentPng));
      final fileInfo = MockFileInfo();
      when(() => fileInfo.file).thenReturn(imageFile);
      final release = Completer<void>();
      when(() => cacheManager.getFileFromCache(url)).thenAnswer((_) async {
        await release.future;
        return fileInfo;
      });

      final flutterErrors = <FlutterErrorDetails>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = flutterErrors.add;
      addTearDown(() => FlutterError.onError = previousOnError);

      final provider = MediaCacheImageProvider(url, cacheManager: cacheManager);
      var decodeCalled = false;
      final completer = provider.loadImage(provider, (buffer, {getTargetSize}) {
        decodeCalled = true;
        return Completer<ui.Codec>().future;
      });
      final listener = ImageStreamListener((image, synchronousCall) {
        image.dispose();
      });

      completer.addListener(listener);
      await Future<void>.delayed(Duration.zero);

      completer.removeListener(listener);
      release.complete();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(decodeCalled, isFalse);
      expect(flutterErrors, isEmpty);
      expect(
        PaintingBinding.instance.imageCache.containsKey(provider),
        isFalse,
      );
    });

    test('still surfaces a genuine null-result download failure through '
        'FlutterError when a listener without onError remains', () async {
      const url = 'https://example.com/null-download.png';
      final cacheManager = _MockMediaCacheManager();
      final download = FakeCancellableDownload(
        url: url,
        targetFile: File('$testTempPath/null-download.png'),
        headers: null,
      );
      final operation = CancellableCacheOperation.fromDownload(download);

      when(
        () => cacheManager.getFileFromCache(url),
      ).thenAnswer((_) async => null);
      when(
        () => cacheManager.cacheFileCancellable(url, key: url),
      ).thenReturn(operation);

      final flutterErrors = <FlutterErrorDetails>[];
      final previousOnError = FlutterError.onError;
      FlutterError.onError = flutterErrors.add;
      addTearDown(() => FlutterError.onError = previousOnError);

      final provider = MediaCacheImageProvider(url, cacheManager: cacheManager);
      final completer = provider.loadImage(
        provider,
        (buffer, {getTargetSize}) => Completer<ui.Codec>().future,
      );
      final listener = ImageStreamListener((image, synchronousCall) {
        image.dispose();
      });

      completer.addListener(listener);
      await Future<void>.delayed(Duration.zero);
      download.completeNull();
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(flutterErrors, hasLength(1));
      expect(flutterErrors.single.toString(), contains(url));

      completer.removeListener(listener);
    });

    test('evicts the image cache entry when decoding a cached file '
        'fails', () async {
      const url = 'https://example.com/decode-failure-cached.png';
      final cacheManager = _MockMediaCacheManager();
      final imageFile = const LocalFileSystem().file(
        '$testTempPath/decode-failure-cached.png',
      )..writeAsBytesSync(Uint8List.fromList(_transparentPng));

      final fileInfo = MockFileInfo();
      when(() => fileInfo.file).thenReturn(imageFile);
      when(
        () => cacheManager.getFileFromCache(url),
      ).thenAnswer((_) async => fileInfo);

      final provider = MediaCacheImageProvider(url, cacheManager: cacheManager);
      final imageCache = PaintingBinding.instance.imageCache
        ..putIfAbsent(
          provider,
          () => OneFrameImageStreamCompleter(Completer<ImageInfo>().future),
        );
      addTearDown(() => imageCache.evict(provider));
      expect(imageCache.containsKey(provider), isTrue);

      final errors = <Object>[];
      final decodeAttempted = Completer<void>();
      final completer = provider.loadImage(provider, (buffer, {getTargetSize}) {
        if (!decodeAttempted.isCompleted) {
          decodeAttempted.complete();
        }
        throw StateError('decode failed for a cached file');
      });
      final listener = ImageStreamListener(
        (image, synchronousCall) {
          image.dispose();
        },
        onError: (error, stackTrace) {
          errors.add(error);
        },
      );

      completer.addListener(listener);
      await decodeAttempted.future;
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(errors, hasLength(1));
      expect(errors.single, isA<StateError>());
      expect(imageCache.containsKey(provider), isFalse);

      completer.removeListener(listener);
    });

    test('evicts the image cache entry when decoding a downloaded file '
        'fails', () async {
      const url = 'https://example.com/decode-failure-downloaded.png';
      final cacheManager = _MockMediaCacheManager();
      final imageFile = File('$testTempPath/decode-failure-downloaded.png')
        ..writeAsBytesSync(Uint8List.fromList(_transparentPng));
      final download = FakeCancellableDownload(
        url: url,
        targetFile: imageFile,
        headers: null,
      );
      final operation = CancellableCacheOperation.fromDownload(download);

      when(
        () => cacheManager.getFileFromCache(url),
      ).thenAnswer((_) async => null);
      when(
        () => cacheManager.cacheFileCancellable(url, key: url),
      ).thenReturn(operation);

      final provider = MediaCacheImageProvider(url, cacheManager: cacheManager);
      final imageCache = PaintingBinding.instance.imageCache
        ..putIfAbsent(
          provider,
          () => OneFrameImageStreamCompleter(Completer<ImageInfo>().future),
        );
      addTearDown(() => imageCache.evict(provider));
      expect(imageCache.containsKey(provider), isTrue);

      final errors = <Object>[];
      final decodeAttempted = Completer<void>();
      final completer = provider.loadImage(provider, (buffer, {getTargetSize}) {
        if (!decodeAttempted.isCompleted) {
          decodeAttempted.complete();
        }
        throw StateError('decode failed for a downloaded file');
      });
      final listener = ImageStreamListener(
        (image, synchronousCall) {
          image.dispose();
        },
        onError: (error, stackTrace) {
          errors.add(error);
        },
      );

      completer.addListener(listener);
      await Future<void>.delayed(Duration.zero);
      download.completeWith(imageFile);
      await decodeAttempted.future;
      await Future<void>.delayed(Duration.zero);
      await Future<void>.delayed(Duration.zero);

      expect(errors, hasLength(1));
      expect(errors.single, isA<StateError>());
      expect(imageCache.containsKey(provider), isFalse);

      completer.removeListener(listener);
    });
  });
}
