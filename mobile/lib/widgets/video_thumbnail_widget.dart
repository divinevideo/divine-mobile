// ABOUTME: Smart video thumbnail widget that displays thumbnails or blurhash placeholders
// ABOUTME: Uses existing thumbnail URLs from video events and falls back to blurhash when missing

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart'
    show HttpExceptionWithStatus;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' hide AspectRatio;
import 'package:openvine/extensions/video_event_content_type_extension.dart';
import 'package:openvine/models/viewer_auth_result.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/utils/blossom_blob_hash.dart';
import 'package:openvine/widgets/blurhash_display.dart';
import 'package:openvine/widgets/vine_cached_image.dart';
import 'package:unified_logger/unified_logger.dart';

/// Smart thumbnail widget that displays thumbnails with blurhash fallback
class VideoThumbnailWidget extends StatefulWidget {
  const VideoThumbnailWidget({
    required this.video,
    super.key,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.showPlayIcon = false,
    this.borderRadius,
  });
  final VideoEvent video;
  final double? width;
  final double? height;
  final BoxFit fit;
  final bool showPlayIcon;
  final BorderRadius? borderRadius;

  @override
  State<VideoThumbnailWidget> createState() => _VideoThumbnailWidgetState();
}

class _VideoThumbnailWidgetState extends State<VideoThumbnailWidget> {
  String? _thumbnailUrl;
  double? _resolvedAspectRatio;

  @override
  void initState() {
    super.initState();
    _loadThumbnail();
  }

  @override
  void didUpdateWidget(VideoThumbnailWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.video.id != widget.video.id ||
        oldWidget.video.thumbnailUrl != widget.video.thumbnailUrl ||
        oldWidget.video.blurhash != widget.video.blurhash ||
        oldWidget.video.dimensions != widget.video.dimensions) {
      _resolvedAspectRatio = null;
      _loadThumbnail();
    }
  }

  void _loadThumbnail() {
    final url = widget.video.thumbnailUrl;
    if (url != null &&
        url.isNotEmpty &&
        !VideoUrlResolver.isKnownDeadMediaUrl(url)) {
      _thumbnailUrl = url;
    } else {
      _thumbnailUrl = null;
    }
    if (mounted) setState(() {});
  }

  void _handleImageDimensionsResolved(String url, int width, int height) {
    if (url != _thumbnailUrl ||
        !mounted ||
        _hasUsableVideoDimensions ||
        width <= 0 ||
        height <= 0) {
      return;
    }

    final aspectRatio = width / height;
    if (_resolvedAspectRatio == aspectRatio) return;
    setState(() {
      _resolvedAspectRatio = aspectRatio;
    });
  }

  bool get _hasUsableVideoDimensions {
    final width = widget.video.width;
    final height = widget.video.height;
    return width != null && width > 0 && height != null && height > 0;
  }

  Widget _buildContent(BoxFit fit) {
    return Stack(
      fit: StackFit.expand,
      children: [
        // Show blurhash or flat color as background while image loads
        BlurhashDisplay(
          blurhash: widget.video.blurhash,
          contentType: widget.video.blurhashContentType,
          width: widget.width,
          height: widget.height,
          fit: fit,
        ),

        // Actual thumbnail image with error boundary, rendered on top of
        // the blurhash placeholder once it loads.
        if (_thumbnailUrl != null)
          PassiveAuthThumbnailImage(
            url: _thumbnailUrl!,
            width: widget.width,
            height: widget.height,
            fit: fit,
            videoId: widget.video.id,
            onImageDimensionsResolved: _handleImageDimensionsResolved,
          ),
        if (widget.showPlayIcon)
          Center(
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: VineTheme.backgroundColor.withValues(alpha: 0.6),
                shape: BoxShape.circle,
              ),
              child: const DivineIcon(
                icon: DivineIconName.play,
                color: VineTheme.whiteText,
                size: 32,
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    // Use video metadata dimensions, resolved image dimensions, or fallback
    final double aspectRatio;
    if (_hasUsableVideoDimensions) {
      aspectRatio = widget.video.width! / widget.video.height!;
    } else if (_resolvedAspectRatio != null) {
      aspectRatio = _resolvedAspectRatio!;
    } else {
      // Fallback to 2:3 portrait until image dimensions are resolved
      aspectRatio = 2 / 3;
    }

    // Clamp portrait videos to 2:3 minimum for grid thumbnails
    final double clampedAspectRatio = aspectRatio < 2 / 3 ? 2 / 3 : aspectRatio;

    // Match video player's BoxFit strategy to prevent visual jump:
    // - Portrait videos (aspectRatio < 0.9): Use BoxFit.cover to fill screen
    // - Square/Landscape videos (aspectRatio >= 0.9): Use BoxFit.contain to show full video
    final bool isPortrait = clampedAspectRatio < 0.9;
    final BoxFit effectiveFit = isPortrait ? BoxFit.cover : BoxFit.contain;

    // Build content with the calculated fit
    var content = _buildContent(effectiveFit);

    if (widget.borderRadius != null) {
      content = ClipRRect(borderRadius: widget.borderRadius!, child: content);
    }

    return AspectRatio(aspectRatio: clampedAspectRatio, child: content);
  }
}

/// Error-safe thumbnail image that retries Divine-hosted 401/403s once with
/// passive, hash-bound BUD-01 auth when viewer settings allow it.
///
/// Uses [VineCachedImage] for shared cache-backed loading where appropriate.
class PassiveAuthThumbnailImage extends StatefulWidget {
  const PassiveAuthThumbnailImage({
    required this.url,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.alignment = Alignment.topCenter,
    this.videoId,
    this.memCacheWidth,
    this.fadeInDuration = const Duration(milliseconds: 500),
    this.fadeOutDuration = const Duration(milliseconds: 1000),
    this.placeholder,
    this.errorWidget,
    this.onImageDimensionsResolved,
    this.logName = 'VideoThumbnailWidget',
    this.logPrefix = 'Thumbnail',
    super.key,
  });

  final String url;
  final String? videoId;
  final double? width;
  final double? height;
  final BoxFit fit;
  final Alignment alignment;
  final int? memCacheWidth;
  final Duration fadeInDuration;
  final Duration fadeOutDuration;
  final PlaceholderWidgetBuilder? placeholder;
  final LoadingErrorWidgetBuilder? errorWidget;
  final void Function(String url, int width, int height)?
  onImageDimensionsResolved;
  final String logName;
  final String logPrefix;

  static bool _shouldBypassCacheManager(String url) {
    final host = Uri.tryParse(url)?.host.toLowerCase();
    if (host == null || host.isEmpty) return false;

    // Explore/grid thumbnails are predominantly served from Divine-owned,
    // immutable blob URLs. These load reliably with Image.network, while the
    // shared cache-manager path has been less reliable under concurrent grid
    // loads on desktop.
    return host == 'divine.video' || host.endsWith('.divine.video');
  }

  static const int _maxUnauthorizedCacheEntries = 128;
  static const Duration _unauthorizedCacheTtl = Duration(minutes: 5);
  static final Map<_PassiveAuthSuppressionKey, DateTime>
  _unauthorizedWithoutPassiveAuth = <_PassiveAuthSuppressionKey, DateTime>{};

  static void _rememberUnauthorized(_PassiveAuthSuppressionKey key) {
    _unauthorizedWithoutPassiveAuth
      ..remove(key)
      ..[key] = DateTime.now().add(_unauthorizedCacheTtl);
    while (_unauthorizedWithoutPassiveAuth.length >
        _maxUnauthorizedCacheEntries) {
      _unauthorizedWithoutPassiveAuth.remove(
        _unauthorizedWithoutPassiveAuth.keys.first,
      );
    }
  }

  static bool _isUnauthorized(_PassiveAuthSuppressionKey key) {
    final expiresAt = _unauthorizedWithoutPassiveAuth.remove(key);
    if (expiresAt == null || !DateTime.now().isBefore(expiresAt)) return false;
    _unauthorizedWithoutPassiveAuth[key] = expiresAt;
    return true;
  }

  @visibleForTesting
  static void debugClearUnauthorizedCache() {
    _unauthorizedWithoutPassiveAuth.clear();
  }

  @visibleForTesting
  static int get debugUnauthorizedCacheLength =>
      _unauthorizedWithoutPassiveAuth.length;

  @visibleForTesting
  static void debugExpireUnauthorizedCache() {
    final expiredAt = DateTime.fromMillisecondsSinceEpoch(0);
    for (final key in _unauthorizedWithoutPassiveAuth.keys) {
      _unauthorizedWithoutPassiveAuth[key] = expiredAt;
    }
  }

  @override
  State<PassiveAuthThumbnailImage> createState() =>
      _PassiveAuthThumbnailImageState();
}

class PassiveAuthUnavailableThumbnailException implements Exception {
  const PassiveAuthUnavailableThumbnailException();

  @override
  String toString() => 'Passive thumbnail auth unavailable';
}

typedef _PassiveAuthSuppressionKey = ({
  String url,
  ProviderContainer container,
  Object? authState,
  int contentFilterVersion,
  int adultMediaAccessVersion,
});

class _PassiveAuthThumbnailImageState extends State<PassiveAuthThumbnailImage> {
  ProviderContainer? _providerContainer;
  ProviderSubscription<Object?>? _authStateSubscription;
  ProviderSubscription<int>? _contentFilterSubscription;
  ProviderSubscription<int>? _adultMediaAccessSubscription;
  Map<String, String>? _authHeaders;
  bool _authRetryAttempted = false;
  bool _passiveAuthSuppressed = false;
  Future<void>? _authRetryInFlight;
  int _imageGeneration = 0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncProviderSubscriptions();
  }

  @override
  void didUpdateWidget(covariant PassiveAuthThumbnailImage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.url != widget.url) {
      _resetPassiveAuthState();
    }
  }

  @override
  void dispose() {
    _clearProviderSubscriptions();
    super.dispose();
  }

  void _syncProviderSubscriptions() {
    ProviderContainer container;
    try {
      container = ProviderScope.containerOf(context, listen: false);
    } on Object catch (error) {
      if (error is! StateError) rethrow;
      return;
    }
    if (identical(container, _providerContainer)) return;

    _clearProviderSubscriptions();
    _providerContainer = container;
    _authStateSubscription = container.listen<Object?>(
      currentAuthStateProvider,
      (previous, next) => _resetPassiveAuthStateInFrame(),
    );
    _contentFilterSubscription = container.listen<int>(
      contentFilterVersionProvider,
      (previous, next) => _resetPassiveAuthStateInFrame(),
    );
    _adultMediaAccessSubscription = container.listen<int>(
      adultMediaAccessRevocationVersionProvider,
      (previous, next) => _resetPassiveAuthStateInFrame(),
    );
  }

  void _clearProviderSubscriptions() {
    _authStateSubscription?.close();
    _contentFilterSubscription?.close();
    _adultMediaAccessSubscription?.close();
    _authStateSubscription = null;
    _contentFilterSubscription = null;
    _adultMediaAccessSubscription = null;
    _providerContainer = null;
  }

  void _resetPassiveAuthStateInFrame() {
    if (!mounted) return;
    setState(_resetPassiveAuthState);
  }

  Future<void> _maybeRetryWithPassiveAuth(Object error) async {
    if (_authRetryAttempted ||
        _authRetryInFlight != null ||
        !PassiveAuthThumbnailImage._shouldBypassCacheManager(widget.url) ||
        !_isAuthChallenge(error)) {
      return;
    }

    final retry = _retryWithPassiveAuth();
    _authRetryInFlight = retry;
    await retry;
    if (identical(_authRetryInFlight, retry)) {
      _authRetryInFlight = null;
    }
  }

  Future<void> _retryWithPassiveAuth() async {
    final retryUrl = widget.url;
    final retryGeneration = _imageGeneration;
    final sha256Hash = extractSha256FromBlossomUrl(retryUrl);
    if (sha256Hash == null) {
      _markPassiveAuthUnavailable(retryUrl);
      return;
    }

    final container = _providerContainer;
    if (container == null) {
      _markPassiveAuthUnavailable(retryUrl);
      return;
    }

    final authResult = await container
        .read(mediaAuthInterceptorProvider)
        .createPassiveAuthHeadersForAdultMedia(
          sha256Hash: sha256Hash,
          serverUrl: extractMediaServerUrl(retryUrl),
        );
    if (!mounted ||
        widget.url != retryUrl ||
        _imageGeneration != retryGeneration) {
      return;
    }

    _authRetryAttempted = true;
    switch (authResult) {
      case ViewerAuthAuthorized(:final headers):
        Log.info(
          '${widget.logPrefix}: Passive auth retry succeeded for $retryUrl',
          name: widget.logName,
          category: LogCategory.video,
        );
        final suppressionKey = _suppressionKey(retryUrl);
        if (suppressionKey != null) {
          PassiveAuthThumbnailImage._unauthorizedWithoutPassiveAuth.remove(
            suppressionKey,
          );
        }
        setState(() {
          _authHeaders = headers;
        });
      case ViewerAuthSignerUnreachable():
        Log.warning(
          '${widget.logPrefix}: Passive auth retry failed; signer unreachable '
          'for $retryUrl',
          name: widget.logName,
          category: LogCategory.video,
        );
      case ViewerAuthBlockedByPreference():
        Log.info(
          '${widget.logPrefix}: Passive auth retry disabled by viewer '
          'preference for $retryUrl',
          name: widget.logName,
          category: LogCategory.video,
        );
        _markPassiveAuthUnavailable(retryUrl);
      case ViewerAuthUnavailable():
        Log.info(
          '${widget.logPrefix}: Passive auth retry unavailable for $retryUrl',
          name: widget.logName,
          category: LogCategory.video,
        );
        _markPassiveAuthUnavailable(retryUrl);
    }
  }

  void _markPassiveAuthUnavailable(String url) {
    _authRetryAttempted = true;
    final suppressionKey = _suppressionKey(url);
    if (suppressionKey == null) return;
    PassiveAuthThumbnailImage._rememberUnauthorized(suppressionKey);
    _passiveAuthSuppressed = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted &&
          widget.url == url &&
          PassiveAuthThumbnailImage._isUnauthorized(suppressionKey)) {
        setState(() {});
      }
    });
  }

  _PassiveAuthSuppressionKey? _suppressionKey(String url) {
    final container = _providerContainer;
    if (container == null) return null;
    return (
      url: url,
      container: container,
      authState: container.read(currentAuthStateProvider),
      contentFilterVersion: container.read(contentFilterVersionProvider),
      adultMediaAccessVersion: container.read(
        adultMediaAccessRevocationVersionProvider,
      ),
    );
  }

  void _resetPassiveAuthState() {
    _authHeaders = null;
    _authRetryAttempted = false;
    _passiveAuthSuppressed = false;
    _authRetryInFlight = null;
    _imageGeneration++;
  }

  bool _isAuthChallenge(Object error) {
    if (error is NetworkImageLoadException) {
      return error.statusCode == 401 || error.statusCode == 403;
    }
    return false;
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        // Decode thumbnails at their on-screen size rather than full source
        // resolution. Full-resolution decodes exhaust Flutter's in-memory image
        // cache within a few screens of fast scrolling, evicting already-loaded
        // thumbnails so they visibly reload on the way back. Capping the decode
        // width keeps far more thumbnails resident in the cache.
        final cacheWidth = _decodeWidth(context, constraints.maxWidth);
        final resolvedUrl = widget.url;

        if (PassiveAuthThumbnailImage._shouldBypassCacheManager(resolvedUrl)) {
          final suppressionKey = _suppressionKey(resolvedUrl);
          if (_authHeaders == null && suppressionKey != null) {
            if (PassiveAuthThumbnailImage._isUnauthorized(suppressionKey)) {
              final errorWidget = widget.errorWidget;
              if (errorWidget != null) {
                return errorWidget(
                  context,
                  resolvedUrl,
                  const PassiveAuthUnavailableThumbnailException(),
                );
              }
              return _TransparentImageBox(
                width: widget.width,
                height: widget.height,
              );
            }

            if (_passiveAuthSuppressed) {
              // An expired or evicted suppression starts a fresh retry window.
              _passiveAuthSuppressed = false;
              _authRetryAttempted = false;
            }
          }

          final imageProvider = ResizeImage.resizeIfNeeded(
            widget.memCacheWidth ?? cacheWidth,
            null,
            NetworkImage(resolvedUrl, headers: _authHeaders),
          );
          final image = Image(
            key: ValueKey('network-image-${widget.url}-$_imageGeneration'),
            image: imageProvider,
            width: widget.width,
            height: widget.height,
            fit: widget.fit,
            alignment: widget.alignment,
            frameBuilder: (context, child, frame, wasSynchronouslyLoaded) {
              if (wasSynchronouslyLoaded) return child;
              return _NetworkImageFrame(
                imageUrl: resolvedUrl,
                width: widget.width,
                height: widget.height,
                fadeInDuration: widget.fadeInDuration,
                fadeOutDuration: widget.fadeOutDuration,
                placeholder: widget.placeholder,
                frame: frame,
                child: child,
              );
            },
            errorBuilder: (context, error, stackTrace) {
              unawaited(_maybeRetryWithPassiveAuth(error));
              _logNetworkImageError(error, stackTrace);
              final errorWidget = widget.errorWidget;
              if (errorWidget != null) {
                return errorWidget(context, resolvedUrl, error);
              }
              return _TransparentImageBox(
                width: widget.width,
                height: widget.height,
              );
            },
          );

          return ImageWithDimensionsListener(
            key: ValueKey('network-${widget.url}-$_imageGeneration'),
            imageProvider: imageProvider,
            onImageDimensionsResolved: widget.onImageDimensionsResolved == null
                ? null
                : (width, height) => widget.onImageDimensionsResolved!(
                    resolvedUrl,
                    width,
                    height,
                  ),
            child: image,
          );
        }

        return VineCachedImage(
          key: ValueKey('cached-${widget.url}-$_imageGeneration'),
          imageUrl: resolvedUrl,
          width: widget.width,
          height: widget.height,
          fit: widget.fit,
          memCacheWidth: widget.memCacheWidth ?? cacheWidth,
          alignment: widget.alignment,
          fadeInDuration: widget.fadeInDuration,
          fadeOutDuration: widget.fadeOutDuration,
          onImageDimensionsResolved: widget.onImageDimensionsResolved == null
              ? null
              : (width, height) => widget.onImageDimensionsResolved!(
                  resolvedUrl,
                  width,
                  height,
                ),
          placeholder:
              widget.placeholder ??
              (context, url) => _TransparentImageBox(
                width: widget.width,
                height: widget.height,
              ),
          errorWidget: (context, url, error) {
            // 404s are expected — thumbnail may not exist yet.
            final is404 = error is HttpExceptionWithStatus
                ? error.statusCode == 404
                : error.toString().contains('404');

            if (!is404) {
              final videoId = widget.videoId;
              Log.warning(
                '🖼️ ${widget.logPrefix} load failed'
                '${videoId == null ? '' : ' for video $videoId'}:\n'
                '  URL: $url\n'
                '  Error type: ${error.runtimeType}\n'
                '  Error: $error',
                name: widget.logName,
                category: LogCategory.video,
              );
            }

            final errorWidget = widget.errorWidget;
            if (errorWidget != null) {
              return errorWidget(context, url, error);
            }

            // Show transparent so background surfaceContainer color shows through
            return _TransparentImageBox(
              width: widget.width,
              height: widget.height,
            );
          },
        );
      },
    );
  }

  /// Physical-pixel decode width for the thumbnail, derived from its laid-out
  /// [maxWidth] (or the explicit [width] when the layout is unbounded).
  ///
  /// Returns `null` when no finite width is available, leaving the framework to
  /// decode at native resolution.
  int? _decodeWidth(BuildContext context, double maxWidth) {
    final logicalWidth = maxWidth.isFinite && maxWidth > 0
        ? maxWidth
        : widget.width;
    if (logicalWidth == null || logicalWidth <= 0) return null;
    return (logicalWidth * MediaQuery.devicePixelRatioOf(context)).ceil();
  }

  void _logNetworkImageError(Object error, StackTrace? stackTrace) {
    final videoId = widget.videoId;
    Log.warning(
      '🖼️ [Image.network] ${widget.logPrefix} load failed'
      '${videoId == null ? '' : ' for video $videoId'}:\n'
      '  URL: ${widget.url}\n'
      '  Error type: ${error.runtimeType}\n'
      '  Error: $error\n'
      '  Stack: ${stackTrace?.toString().split('\n').take(5).join('\n')}',
      name: widget.logName,
      category: LogCategory.video,
    );
  }
}

class _NetworkImageFrame extends StatelessWidget {
  const _NetworkImageFrame({
    required this.imageUrl,
    required this.width,
    required this.height,
    required this.fadeInDuration,
    required this.fadeOutDuration,
    required this.placeholder,
    required this.frame,
    required this.child,
  });

  final String imageUrl;
  final double? width;
  final double? height;
  final Duration fadeInDuration;
  final Duration fadeOutDuration;
  final PlaceholderWidgetBuilder? placeholder;
  final int? frame;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hasImage = frame != null;
    final placeholderBuilder = placeholder;
    if (placeholderBuilder == null) {
      return AnimatedOpacity(
        key: const ValueKey('image'),
        opacity: hasImage ? 1 : 0,
        duration: fadeInDuration,
        child: child,
      );
    }

    return Stack(
      fit: StackFit.passthrough,
      children: [
        IgnorePointer(
          child: AnimatedOpacity(
            opacity: hasImage ? 0 : 1,
            duration: fadeOutDuration,
            child: placeholderBuilder(context, imageUrl),
          ),
        ),
        AnimatedOpacity(
          key: const ValueKey('image'),
          opacity: hasImage ? 1 : 0,
          duration: fadeInDuration,
          child: child,
        ),
      ],
    );
  }
}

class _TransparentImageBox extends StatelessWidget {
  const _TransparentImageBox({required this.width, required this.height});

  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      height: height,
      color: VineTheme.transparent,
    );
  }
}

/// Resolves [imageProvider] alongside the rendered [child] purely to report the
/// decoded image's intrinsic dimensions via [onImageDimensionsResolved].
///
/// Used by the Image.network thumbnail path (which has no built-in dimension
/// callback like [VineCachedImage]) so the aspect ratio can be recovered from
/// the displayed image instead of a separate probe decode.
@visibleForTesting
class ImageWithDimensionsListener extends StatefulWidget {
  const ImageWithDimensionsListener({
    required this.imageProvider,
    required this.child,
    super.key,
    this.onImageDimensionsResolved,
  });

  final ImageProvider<Object> imageProvider;
  final ImageDimensionsResolved? onImageDimensionsResolved;
  final Widget child;

  @override
  State<ImageWithDimensionsListener> createState() =>
      _ImageWithDimensionsListenerState();
}

class _ImageWithDimensionsListenerState
    extends State<ImageWithDimensionsListener> {
  ImageStream? _imageStream;
  ImageStreamListener? _listener;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _resolveImageStream();
  }

  @override
  void didUpdateWidget(covariant ImageWithDimensionsListener oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.imageProvider != widget.imageProvider) {
      _resolveImageStream();
    }
  }

  @override
  void dispose() {
    _removeImageListener();
    super.dispose();
  }

  void _resolveImageStream() {
    final newStream = widget.imageProvider.resolve(
      createLocalImageConfiguration(context),
    );
    if (_imageStream?.key == newStream.key) {
      return;
    }

    _removeImageListener();
    _imageStream = newStream;

    _listener = ImageStreamListener(
      (image, synchronousCall) {
        final imageWidth = image.image.width;
        final imageHeight = image.image.height;
        final onImageDimensionsResolved = widget.onImageDimensionsResolved;
        image.dispose();
        if (!mounted) return;
        if (onImageDimensionsResolved == null) return;
        if (synchronousCall) {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) {
              onImageDimensionsResolved(imageWidth, imageHeight);
            }
          });
        } else {
          onImageDimensionsResolved(imageWidth, imageHeight);
        }
      },
      // The rendered Image handles visible failures; this listener only needs
      // dimensions when decoding succeeds.
      onError: (Object error, StackTrace? stackTrace) {},
    );
    _imageStream!.addListener(_listener!);
  }

  void _removeImageListener() {
    if (_imageStream != null && _listener != null) {
      _imageStream!.removeListener(_listener!);
    }
    _imageStream = null;
    _listener = null;
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
