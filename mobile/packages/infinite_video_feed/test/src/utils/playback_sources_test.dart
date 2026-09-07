import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/src/models/video_error_type.dart';
import 'package:infinite_video_feed/src/services/derivative_failure_cache.dart';
import 'package:infinite_video_feed/src/utils/playback_sources.dart';
import 'package:models/models.dart';

/// Minimal [VideoEvent] factory for tests.
VideoEvent _makeVideo({String id = 'vid1', String? videoUrl}) => VideoEvent(
  id: id,
  pubkey: 'pubkey',
  createdAt: 0,
  content: '',
  timestamp: DateTime(2024),
  videoUrl: videoUrl,
);

const _hash =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
const _rawUrl = 'https://media.divine.video/$_hash';
const _cdnRawUrl = 'https://cdn.divine.video/$_hash';
const _queryRawUrl = 'https://media.divine.video/$_hash?download=1';
const _hlsUrl = 'https://media.divine.video/$_hash/hls/master.m3u8';

void main() {
  group('resolvePlaybackSources', () {
    group('when videoUrl is null and no resolver', () {
      test('returns empty list', () {
        final video = _makeVideo();
        expect(resolvePlaybackSources(video), isEmpty);
      });
    });

    group('when videoUrl is empty and no resolver', () {
      test('returns empty list', () {
        final video = _makeVideo(videoUrl: '');
        expect(resolvePlaybackSources(video), isEmpty);
      });
    });

    group('when URL is a non-divine URL', () {
      test('returns [resolvedSource, originalUrl] deduplicated', () {
        final video = _makeVideo(videoUrl: 'https://example.com/video.mp4');
        expect(
          resolvePlaybackSources(video),
          equals(['https://example.com/video.mp4']),
        );
      });

      test('includes both resolver result and original when different', () {
        final video = _makeVideo(videoUrl: 'https://example.com/original.mp4');
        final result = resolvePlaybackSources(
          video,
          urlResolver: (_) => 'https://example.com/resolved.mp4',
        );
        expect(
          result,
          equals([
            'https://example.com/resolved.mp4',
            'https://example.com/original.mp4',
          ]),
        );
      });
    });

    group('when URL is a canonical HLS URL', () {
      test('adds the raw blob as the final fallback', () {
        final video = _makeVideo(videoUrl: _hlsUrl);
        expect(resolvePlaybackSources(video), equals([_hlsUrl, _rawUrl]));
      });

      test('canonicalizes a raw original when the resolver selects HLS', () {
        final video = _makeVideo(videoUrl: _queryRawUrl);
        final result = resolvePlaybackSources(
          video,
          urlResolver: (_) => _hlsUrl,
        );

        expect(result, equals([_hlsUrl, _rawUrl]));
      });
    });

    group('when URL is the raw blob URL', () {
      test('returns [rawUrl, hlsUrl, originalUrl] deduplicated', () {
        final video = _makeVideo(videoUrl: _rawUrl);
        // raw == original -> progressive raw first, HLS as fallback
        expect(resolvePlaybackSources(video), equals([_rawUrl, _hlsUrl]));
      });

      test('includes originalUrl when it differs from rawUrl', () {
        const otherOriginal = 'https://example.com/original.mp4';
        final video = _makeVideo(videoUrl: otherOriginal);
        final result = resolvePlaybackSources(
          video,
          urlResolver: (_) => _rawUrl,
        );
        expect(result, equals([_rawUrl, _hlsUrl, otherOriginal]));
      });

      test('keeps a query-bearing raw URL when it is selected', () {
        final video = _makeVideo(videoUrl: _queryRawUrl);

        expect(resolvePlaybackSources(video), equals([_queryRawUrl, _hlsUrl]));
      });
    });

    group('when URL is a quality-specific Divine variant', () {
      const variantUrl = 'https://media.divine.video/$_hash/720p.mp4';

      test('returns variant, HLS, then raw blob fallback', () {
        final video = _makeVideo(videoUrl: variantUrl);
        expect(
          resolvePlaybackSources(video),
          equals([variantUrl, _hlsUrl, _rawUrl]),
        );
      });

      test('uses canonical raw fallback when resolver selects a variant', () {
        final video = _makeVideo(videoUrl: _cdnRawUrl);
        final result = resolvePlaybackSources(
          video,
          urlResolver: (_) => variantUrl,
        );

        expect(result, equals([variantUrl, _hlsUrl, _rawUrl]));
      });

      test('keeps canonical raw last after an alternate-host failure', () {
        final video = _makeVideo(videoUrl: _cdnRawUrl);
        final cache = DerivativeFailureCache()
          ..recordFailureForSource(variantUrl);

        final result = resolvePlaybackSources(
          video,
          urlResolver: (_) => variantUrl,
          derivativeFailureCache: cache,
        );

        expect(result, equals([_hlsUrl, variantUrl, _rawUrl]));
      });

      test('leads with HLS and keeps raw last after a fresh failure', () {
        final video = _makeVideo(videoUrl: variantUrl);
        final cache = DerivativeFailureCache()
          ..recordFailureForSource(variantUrl);

        expect(
          resolvePlaybackSources(video, derivativeFailureCache: cache),
          equals([_hlsUrl, variantUrl, _rawUrl]),
        );
      });

      test('restores derivative-first ordering after failure TTL expires', () {
        var now = DateTime(2026, 8, 14, 12);
        final cache = DerivativeFailureCache(clock: () => now)
          ..recordFailureForSource(variantUrl);
        final video = _makeVideo(videoUrl: variantUrl);

        now = now.add(
          derivativeFailureCacheTtl + const Duration(milliseconds: 1),
        );

        expect(
          resolvePlaybackSources(video, derivativeFailureCache: cache),
          equals([variantUrl, _hlsUrl, _rawUrl]),
        );
      });
    });

    group('with resolver returning null', () {
      test('falls back to videoUrl', () {
        final video = _makeVideo(videoUrl: 'https://example.com/video.mp4');
        final result = resolvePlaybackSources(video, urlResolver: (_) => null);
        expect(result, equals(['https://example.com/video.mp4']));
      });
    });

    group('with resolver returning empty string', () {
      test('falls back to videoUrl', () {
        final video = _makeVideo(videoUrl: 'https://example.com/video.mp4');
        final result = resolvePlaybackSources(video, urlResolver: (_) => '');
        expect(result, equals(['https://example.com/video.mp4']));
      });
    });
  });

  group('classifyVideoError', () {
    test('returns ageRestricted for typed authRequired without 401 text', () {
      expect(
        classifyVideoError(
          errorCode: NativePlayerErrorCode.authRequired,
          errorMessage: 'NSURLErrorDomain error -1013',
        ),
        equals(VideoErrorType.ageRestricted),
      );
    });

    // The message scan below cannot see a status the platform did not spell
    // out in English. These two prove the typed code alone is enough.
    test('returns forbidden for typed forbidden without 403 text', () {
      expect(
        classifyVideoError(
          errorCode: NativePlayerErrorCode.forbidden,
          errorMessage: 'Der Server hat die Anfrage abgelehnt',
        ),
        equals(VideoErrorType.forbidden),
      );
    });

    test('returns notFound for typed notFound without 404 text', () {
      expect(
        classifyVideoError(
          errorCode: NativePlayerErrorCode.notFound,
          errorMessage: 'Die Datei wurde nicht gefunden',
        ),
        equals(VideoErrorType.notFound),
      );
    });

    // httpClientError still means "some other 4xx", so it must not be
    // upgraded to a specific category on the typed path.
    test('leaves typed httpClientError on the message-scan path', () {
      expect(
        classifyVideoError(
          errorCode: NativePlayerErrorCode.httpClientError,
          errorMessage: 'HTTP 410 Gone',
        ),
        equals(VideoErrorType.generic),
      );
    });

    test('keeps null typed code on the existing generic path', () {
      expect(
        classifyVideoError(errorMessage: 'NSURLErrorDomain error -1013'),
        equals(VideoErrorType.generic),
      );
    });

    test('returns ageRestricted for 401', () {
      expect(
        classifyVideoError(errorMessage: 'HTTP 401 Unauthorized'),
        equals(VideoErrorType.ageRestricted),
      );
    });

    test('returns ageRestricted for "unauthorized" (case-insensitive)', () {
      expect(
        classifyVideoError(errorMessage: 'unauthorized access'),
        equals(VideoErrorType.ageRestricted),
      );
    });

    test('returns forbidden for 403', () {
      expect(
        classifyVideoError(errorMessage: 'HTTP 403 Forbidden'),
        equals(VideoErrorType.forbidden),
      );
    });

    test('returns forbidden for "forbidden" (case-insensitive)', () {
      expect(
        classifyVideoError(errorMessage: 'forbidden content'),
        equals(VideoErrorType.forbidden),
      );
    });

    test('returns notFound for 404', () {
      expect(
        classifyVideoError(errorMessage: 'HTTP 404 Not Found'),
        equals(VideoErrorType.notFound),
      );
    });

    test('returns notFound for "not found" (case-insensitive)', () {
      expect(
        classifyVideoError(errorMessage: 'content not found'),
        equals(VideoErrorType.notFound),
      );
    });

    test('returns generic for HTTP 202 while Divine derivatives process', () {
      expect(
        classifyVideoError(
          errorMessage: 'CoreMediaErrorDomain error -12667 - HTTP 202',
          source: 'https://media.divine.video/$_hash/720p.mp4',
        ),
        equals(VideoErrorType.generic),
      );
    });

    test('returns generic for HTTP 422 while Divine derivatives process', () {
      expect(
        classifyVideoError(
          errorMessage: 'HTTP 422 Unprocessable Entity',
          source: 'https://media.divine.video/$_hash/720p.mp4',
        ),
        equals(VideoErrorType.generic),
      );
    });

    test('returns notFound for explicit HTTP 404 on a Divine blob URL', () {
      expect(
        classifyVideoError(
          errorMessage: 'HTTP 404 Not Found',
          source: 'https://media.divine.video/$_hash/720p.mp4',
        ),
        equals(VideoErrorType.notFound),
      );
    });

    test('does not let a hash-like 422 mask explicit HTTP 404', () {
      expect(
        classifyVideoError(
          errorMessage:
              'HTTP 404 Not Found: https://media.divine.video/a422b/video.mp4',
          source: 'https://media.divine.video/$_hash/720p.mp4',
        ),
        equals(VideoErrorType.notFound),
      );
    });

    test('returns generic for Android response-code 202 messages', () {
      expect(
        classifyVideoError(
          errorMessage: 'Response code: 202',
          source: 'https://media.divine.video/$_hash/720p.mp4',
        ),
        equals(VideoErrorType.generic),
      );
    });

    test('does not classify unrelated numbers as HTTP 202', () {
      expect(
        classifyVideoError(
          errorMessage: 'Response completed in 2025 ms',
          source: 'https://media.divine.video/$_hash/720p.mp4',
        ),
        equals(VideoErrorType.notFound),
      );
    });

    test('returns notFound when source is a Divine blob URL', () {
      expect(
        classifyVideoError(source: _rawUrl),
        equals(VideoErrorType.notFound),
      );
    });

    test('returns generic for unknown error', () {
      expect(
        classifyVideoError(errorMessage: 'something went wrong'),
        equals(VideoErrorType.generic),
      );
    });

    test('returns generic when both message and source are null', () {
      expect(classifyVideoError(), equals(VideoErrorType.generic));
    });

    test('returns generic when source is not a Divine URL', () {
      expect(
        classifyVideoError(source: 'https://example.com/video.mp4'),
        equals(VideoErrorType.generic),
      );
    });
  });

  group('isMediaProcessingError', () {
    test('matches iOS CoreMedia HTTP 202 messages', () {
      expect(
        isMediaProcessingError(
          Exception('CoreMediaErrorDomain error -12667 - HTTP 202'),
        ),
        isTrue,
      );
    });

    test('matches Android response-code 202 messages', () {
      expect(
        isMediaProcessingError(Exception('Source error. Response code: 202')),
        isTrue,
      );
    });

    test('matches derived-rendition HTTP 422 messages', () {
      expect(
        isMediaProcessingError(Exception('Source error. Response code: 422')),
        isTrue,
      );
    });

    test('does not match unrelated 202 numbers', () {
      expect(
        isMediaProcessingError(Exception('Response completed in 2025 ms')),
        isFalse,
      );
    });

    test('does not match status-like numbers inside hex hashes', () {
      expect(
        isMediaProcessingError(
          Exception('HTTP load failed for https://media.divine.video/a422b'),
        ),
        isFalse,
      );
    });
  });

  group('nativePlayerErrorCodeFromError', () {
    test('parses errorCode from PlatformException details', () {
      expect(
        nativePlayerErrorCodeFromError(
          PlatformException(
            code: 'COMPOSITION_ERROR',
            message: 'NSURLErrorDomain error -1013',
            details: const <String, Object?>{'errorCode': 'auth_required'},
          ),
        ),
        equals(NativePlayerErrorCode.authRequired),
      );
    });

    test('ignores unknown PlatformException codes', () {
      expect(
        nativePlayerErrorCodeFromError(
          PlatformException(code: 'COMPOSITION_ERROR'),
        ),
        isNull,
      );
    });
  });
}
