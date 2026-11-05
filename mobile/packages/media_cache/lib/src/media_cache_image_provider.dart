import 'dart:async';
import 'dart:io' as io;
import 'dart:ui' as ui;

import 'package:file/file.dart' as fs;
import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'package:media_cache/src/cancellable_cache_operation.dart';
import 'package:media_cache/src/media_cache_manager.dart';

typedef _SimpleDecoderCallback =
    Future<ui.Codec> Function(ui.ImmutableBuffer buffer);

/// Loads native images through the cancellation-aware [MediaCacheManager].
///
/// Web uses the browser loader, including HTML image fallback for origins that
/// cannot expose image bytes through CORS, without opening a native cache file.
@immutable
class MediaCacheImageProvider extends ImageProvider<MediaCacheImageProvider> {
  /// Creates a provider that resolves [url] through [cacheManager].
  const MediaCacheImageProvider(
    this.url, {
    required this.cacheManager,
    this.scale = 1.0,
    this.cacheKey,
    this.authHeaders,
  });

  /// The remote URL to load.
  final String url;

  /// The cache manager that owns the backing on-disk file.
  final MediaCacheManager cacheManager;

  /// The scale to report in the resulting [ImageInfo].
  final double scale;

  /// Optional explicit cache key. Defaults to [url].
  final String? cacheKey;

  /// Optional request headers.
  final Map<String, String>? authHeaders;

  String get _resolvedCacheKey => cacheKey ?? url;

  @override
  Future<MediaCacheImageProvider> obtainKey(ImageConfiguration configuration) {
    return SynchronousFuture<MediaCacheImageProvider>(this);
  }

  @override
  ImageStreamCompleter loadImage(
    MediaCacheImageProvider key,
    ImageDecoderCallback decode,
  ) {
    if (kIsWeb) {
      final browserImage = NetworkImage(
        key.url,
        scale: key.scale,
        headers: key.authHeaders,
        webHtmlElementStrategy: WebHtmlElementStrategy.fallback,
      );
      return browserImage.loadImage(browserImage, decode);
    }

    final loadHandle = _ImageLoadHandle();
    return MultiFrameImageStreamCompleter(
      codec: _loadAsync(key, loadHandle, decode: decode),
      scale: key.scale,
      debugLabel: key.url,
      informationCollector: () => <DiagnosticsNode>[
        DiagnosticsProperty<ImageProvider>('Image provider', this),
        DiagnosticsProperty<MediaCacheImageProvider>('Image key', key),
      ],
    )..addOnLastListenerRemovedCallback(loadHandle.cancel);
  }

  Future<ui.Codec> _loadAsync(
    MediaCacheImageProvider key,
    _ImageLoadHandle loadHandle, {
    required _SimpleDecoderCallback decode,
  }) async {
    final ui.Codec? codec;
    try {
      codec = await _resolveCodec(key, loadHandle, decode: decode);
    } catch (error) {
      scheduleMicrotask(() {
        PaintingBinding.instance.imageCache.evict(key);
      });
      rethrow;
    }
    if (codec == null) {
      // Returned outside the try because [_abortCancelledLoad] never
      // completes: awaiting it there would strand this frame — and the file
      // handles it captured — for the lifetime of the isolate.
      return _abortCancelledLoad(key);
    }
    return codec;
  }

  /// Resolves the codec for [key], or `null` if the load was cancelled.
  Future<ui.Codec?> _resolveCodec(
    MediaCacheImageProvider key,
    _ImageLoadHandle loadHandle, {
    required _SimpleDecoderCallback decode,
  }) async {
    assert(
      key == this,
      'MediaCacheImageProvider.loadImage received a mismatched key.',
    );

    final existing = await cacheManager.getFileFromCache(_resolvedCacheKey);
    if (existing != null && existing.file.existsSync()) {
      if (loadHandle.isCancelled) {
        return null;
      }
      return _decodeFile(existing.file, decode: decode);
    }

    if (loadHandle.isCancelled) {
      return null;
    }

    final operation = cacheManager.cacheFileCancellable(
      url,
      key: _resolvedCacheKey,
      authHeaders: authHeaders,
    );
    loadHandle.attach(operation);

    final file = await operation.file;
    if (loadHandle.isCancelled) {
      return null;
    }
    if (file == null) {
      // The download completed but produced no file (network/DNS failure,
      // non-2xx response, …). This is a genuine load failure, distinct from
      // the benign scroll-away cancellation handled above via
      // `_abortCancelledLoad` — the latter never throws.
      throw MediaCacheImageLoadException(url);
    }

    return _decodeFile(file, decode: decode);
  }

  /// Stops a load whose last listener was removed before it finished.
  ///
  /// Cancellation is expected during fast scrolling. Throwing here would let
  /// [MultiFrameImageStreamCompleter] forward the error to
  /// `FlutterError.onError` (and therefore Crashlytics) once no listener
  /// remains, turning a benign scroll-away into a fatal report. Instead we
  /// evict the stale cache entry and return a future that never completes, so
  /// the cancelled load simply stops.
  Future<ui.Codec> _abortCancelledLoad(MediaCacheImageProvider key) {
    scheduleMicrotask(() {
      PaintingBinding.instance.imageCache.evict(key);
    });
    return Completer<ui.Codec>().future;
  }

  Future<ui.Codec> _decodeFile(
    Object file, {
    required _SimpleDecoderCallback decode,
  }) async {
    if (file is io.File) {
      final lengthInBytes = await file.length();
      if (lengthInBytes == 0) {
        throw StateError('$file is empty and cannot be loaded as an image.');
      }
      return decode(await ui.ImmutableBuffer.fromFilePath(file.path));
    }
    if (file is fs.File) {
      final lengthInBytes = await file.length();
      if (lengthInBytes == 0) {
        throw StateError('$file is empty and cannot be loaded as an image.');
      }
      return decode(
        await ui.ImmutableBuffer.fromUint8List(await file.readAsBytes()),
      );
    }
    throw StateError(
      'Unsupported file type for image decode: ${file.runtimeType}',
    );
  }

  @override
  bool operator ==(Object other) {
    if (other.runtimeType != runtimeType) {
      return false;
    }
    return other is MediaCacheImageProvider &&
        other.url == url &&
        identical(other.cacheManager, cacheManager) &&
        other.scale == scale &&
        other.cacheKey == cacheKey &&
        mapEquals(other.authHeaders, authHeaders);
  }

  @override
  int get hashCode => Object.hash(
    url,
    identityHashCode(cacheManager),
    scale,
    cacheKey,
    Object.hashAllUnordered(
      authHeaders?.entries.map(
            (entry) => Object.hash(entry.key, entry.value),
          ) ??
          const <int>[],
    ),
  );

  @override
  String toString() {
    return '${objectRuntimeType(this, 'MediaCacheImageProvider')}'
        '("$url", scale: ${scale.toStringAsFixed(1)})';
  }
}

class _ImageLoadHandle {
  CancellableCacheOperation? _operation;
  bool _isCancelled = false;

  bool get isCancelled => _isCancelled;

  void attach(CancellableCacheOperation operation) {
    _operation = operation;
    if (_isCancelled) {
      operation.cancel();
    }
  }

  void cancel() {
    if (_isCancelled) return;
    _isCancelled = true;
    _operation?.cancel();
  }
}

/// Thrown by [MediaCacheImageProvider] when a download completes without
/// producing a usable file.
///
/// This signals a genuine load failure — a network or DNS error, a non-2xx
/// response, or an otherwise dead URL — and is distinct from the benign
/// scroll-away cancellation the provider handles silently (which returns a
/// never-completing future rather than throwing). Callers that maintain a
/// negative cache of broken URLs should treat this as a cacheable failure.
class MediaCacheImageLoadException implements Exception {
  /// Creates an exception for the [url] whose download produced no file.
  const MediaCacheImageLoadException(this.url);

  /// The URL whose download completed without a file.
  final String url;

  @override
  String toString() =>
      'MediaCacheImageProvider failed to load "$url": '
      'download completed without a file';
}
