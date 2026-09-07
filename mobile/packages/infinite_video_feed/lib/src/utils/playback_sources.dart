import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/services.dart';
import 'package:infinite_video_feed/src/models/video_error_type.dart';
import 'package:infinite_video_feed/src/services/derivative_failure_cache.dart';
import 'package:infinite_video_feed/src/utils/canonical_divine_url.dart';
import 'package:models/models.dart';

/// Resolves the ordered list of playback URLs to attempt for [video].
///
/// When [urlResolver] is provided, its output is preferred over
/// [VideoEvent.videoUrl]. For Divine blob URLs the list is expanded with
/// canonical alternatives so the runtime can fail over between them.
///
/// Derivative-resolved Divine blobs use the bare blob as their final fallback,
/// after quality-specific and HLS sources have been attempted.
List<String> resolvePlaybackSources(
  VideoEvent video, {
  String? Function(VideoEvent video)? urlResolver,
  DerivativeFailureCache? derivativeFailureCache,
}) {
  final resolvedSource = urlResolver?.call(video) ?? video.videoUrl;
  final originalUrl = video.videoUrl;

  if (resolvedSource == null || resolvedSource.isEmpty) {
    return orderedUniqueSources([originalUrl]);
  }

  final hash = extractCanonicalDivineBlobHash(resolvedSource);
  if (hash != null) {
    final hlsUrl = canonicalDivineBlobHlsUrl(hash);
    final rawUrl = canonicalDivineBlobRawUrl(hash);
    final isAlreadyHls = resolvedSource.contains('/hls/');
    if (isAlreadyHls) {
      final originalFallback =
          originalUrl != null && isDivineBlobRawUrl(originalUrl)
          ? null
          : originalUrl;
      return orderedUniqueSources([resolvedSource, originalFallback, rawUrl]);
    }

    final isRawBlob = isDivineBlobRawUrl(resolvedSource);
    if (isRawBlob) {
      return orderedUniqueSources([resolvedSource, hlsUrl, originalUrl]);
    }

    final originalFallback =
        originalUrl != null && isDivineBlobRawUrl(originalUrl)
        ? null
        : originalUrl;
    if (derivativeFailureCache?.hasFreshFailureForHash(hash) ?? false) {
      return orderedUniqueSources([
        hlsUrl,
        resolvedSource,
        originalFallback,
        rawUrl,
      ]);
    }

    return orderedUniqueSources([
      resolvedSource,
      hlsUrl,
      originalFallback,
      rawUrl,
    ]);
  }

  return orderedUniqueSources([resolvedSource, originalUrl]);
}

/// Classifies a playback failure into a [VideoErrorType] using the typed native
/// error code, error message, and optionally the source that produced it.
VideoErrorType classifyVideoError({
  NativePlayerErrorCode? errorCode,
  String? errorMessage,
  String? source,
}) {
  // The typed native code is authoritative when the platform supplied one:
  // it survives localisation and platform wording, unlike the message scan
  // below, which stays as the fallback for paths that carry no typed code.
  final typedErrorType = switch (errorCode) {
    NativePlayerErrorCode.authRequired => VideoErrorType.ageRestricted,
    NativePlayerErrorCode.forbidden => VideoErrorType.forbidden,
    NativePlayerErrorCode.notFound => VideoErrorType.notFound,
    _ => null,
  };
  if (typedErrorType != null) return typedErrorType;

  final lower = (errorMessage ?? '').toLowerCase();
  if (lower.contains('401') || lower.contains('unauthorized')) {
    return VideoErrorType.ageRestricted;
  }
  if (lower.contains('403') || lower.contains('forbidden')) {
    return VideoErrorType.forbidden;
  }
  if (lower.contains('404') || lower.contains('not found')) {
    return VideoErrorType.notFound;
  }
  // Divine derivative URLs can legitimately return HTTP 202/422 while MP4/HLS
  // processing catches up after upload. Treat those as transient playback
  // failures, not as proof that the blob is missing.
  if (_mentionsHttpStatus(lower, 202) || _mentionsHttpStatus(lower, 422)) {
    return VideoErrorType.generic;
  }

  // Only use the Divine blob heuristic when a concrete source was provided
  // by a failing load/init path. Runtime error events often lack detailed
  // context and should stay generic unless we have explicit 4xx evidence.
  if (source != null && extractCanonicalDivineBlobHash(source) != null) {
    return VideoErrorType.notFound;
  }

  return VideoErrorType.generic;
}

/// Whether an error represents Divine media still preparing renditions.
///
/// Freshly-published Divine derivative URLs can return HTTP 202 while the
/// server finishes MP4/HLS processing. Some derived renditions also return
/// HTTP 422 while the raw blob is already available. Playback should treat both
/// as transient source failures instead of terminal missing-media evidence.
bool isMediaProcessingError(Object? error, {String? errorMessage}) {
  if (nativePlayerErrorCodeFromError(error) ==
      NativePlayerErrorCode.mediaProcessing) {
    return true;
  }
  final lower = '${errorMessage ?? ''} ${error ?? ''}'.toLowerCase();
  return _mentionsHttpStatus(lower, 202) || _mentionsHttpStatus(lower, 422);
}

/// Extracts a canonical native player error code from method-channel failures.
NativePlayerErrorCode? nativePlayerErrorCodeFromError(Object? error) {
  if (error is! PlatformException) return null;

  final details = error.details;
  if (details is Map) {
    final rawCode = details['errorCode'];
    if (rawCode is String) {
      final parsed = NativePlayerErrorCode.fromString(rawCode);
      if (parsed != NativePlayerErrorCode.unknown) return parsed;
    }
  }

  final parsed = NativePlayerErrorCode.fromString(error.code);
  return parsed == NativePlayerErrorCode.unknown ? null : parsed;
}

bool _mentionsHttpStatus(String lower, int status) {
  if (!lower.contains('http') &&
      !lower.contains('status') &&
      !lower.contains('response code')) {
    return false;
  }
  return RegExp('(^|[^0-9a-f])$status([^0-9a-f]|\$)').hasMatch(lower);
}
