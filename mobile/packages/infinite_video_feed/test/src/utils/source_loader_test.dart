import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:infinite_video_feed/src/utils/source_loader.dart';

import '../../helpers/fake_controller.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('setSourceWithFallbacks', () {
    final logs = <String>[];

    setUp(logs.clear);

    test('returns (source, 0) when first source succeeds', () async {
      final controller = FakeController();
      addTearDown(controller.dispose);

      final result = await setSourceWithFallbacks(
        index: 0,
        controller: controller,
        sources: ['urlA', 'urlB'],
        trimToCommonTrackEnd: true,
        log: logs.add,
      );

      expect(result, equals(('urlA', 0)));
      expect(controller.lastSource?.httpHeaders, isEmpty);
      // No cap requested — the package must not invent one of its own.
      expect(controller.lastSource?.end, isNull);
      expect(logs, isEmpty);
    });

    test('caps every source in the chain at maxPlaybackDuration', () async {
      final clips = <VideoClip>[];
      final controller = _RecordingControllerWithOneFailure(clips.add);
      addTearDown(controller.dispose);

      const cap = Duration(seconds: 7);
      final result = await setSourceWithFallbacks(
        index: 0,
        controller: controller,
        sources: ['optimizedUrl', 'rawUrl'],
        trimToCommonTrackEnd: true,
        log: logs.add,
        maxPlaybackDuration: cap,
      );

      expect(result, equals(('rawUrl', 1)));
      expect(clips.map((clip) => clip.end), equals([cap, cap]));
    });

    test('keeps the cap on a source retried after HTTP 202', () async {
      final clips = <VideoClip>[];
      final controller = _RecordingControllerWithFailures(
        clips.add,
        failures: [Exception('CoreMediaErrorDomain error -12667 - HTTP 202')],
      );
      addTearDown(controller.dispose);

      const cap = Duration(seconds: 7);
      final result = await setSourceWithFallbacks(
        index: 0,
        controller: controller,
        sources: ['processingUrl'],
        trimToCommonTrackEnd: true,
        log: logs.add,
        maxPlaybackDuration: cap,
        delay: (_) async {},
      );

      expect(result, equals(('processingUrl', 0)));
      expect(clips.map((clip) => clip.end), equals([cap, cap]));
    });

    test('opts every source into loop-seam trimming', () async {
      final controller = FakeController();
      addTearDown(controller.dispose);

      await setSourceWithFallbacks(
        index: 0,
        controller: controller,
        sources: ['urlA'],
        trimToCommonTrackEnd: true,
        log: logs.add,
      );

      expect(
        controller.lastSource?.trimToCommonTrackEnd,
        isTrue,
        reason:
            'Feed playback loops, so a clip must end where both tracks still '
            'have content rather than at the container duration.',
      );
    });

    test('leaves every source untrimmed when the caller opts out', () async {
      final clips = <VideoClip>[];
      // One 202 first, so the assertion covers the retried clip as well as the
      // first attempt — the flag has to reach both construction sites.
      final controller = _RecordingControllerWithFailures(
        clips.add,
        failures: [Exception('CoreMediaErrorDomain error -12667 - HTTP 202')],
      );
      addTearDown(controller.dispose);

      await setSourceWithFallbacks(
        index: 0,
        controller: controller,
        sources: ['processingUrl'],
        log: logs.add,
        trimToCommonTrackEnd: false,
        delay: (_) async {},
      );

      expect(
        clips.map((clip) => clip.trimToCommonTrackEnd),
        equals([false, false]),
        reason:
            'A caller measuring playback against the container duration loses '
            'the tail of its axis if the clip is clamped to the shorter track.',
      );
    });

    test('passes headers for the selected source', () async {
      final controller = FakeController();
      addTearDown(controller.dispose);

      final result = await setSourceWithFallbacks(
        index: 0,
        controller: controller,
        sources: ['urlA'],
        trimToCommonTrackEnd: true,
        log: logs.add,
        httpHeadersForSource: (source) =>
            source == 'urlA' ? {'Authorization': 'Nostr token'} : null,
      );

      expect(result, equals(('urlA', 0)));
      expect(
        controller.lastSource?.httpHeaders,
        equals({'Authorization': 'Nostr token'}),
      );
    });

    test('returns (nextSource, 1) and logs when first source fails', () async {
      final controller = _FakeControllerWithOneFailure();
      addTearDown(controller.dispose);

      final result = await setSourceWithFallbacks(
        index: 1,
        controller: controller,
        sources: ['badUrl', 'goodUrl'],
        trimToCommonTrackEnd: true,
        log: logs.add,
      );

      expect(result, equals(('goodUrl', 1)));
      expect(logs, hasLength(1));
      expect(logs.first, contains('badUrl'));
    });

    test('notifies each failed source before failover succeeds', () async {
      final controller = _FakeControllerWithOneFailure();
      addTearDown(controller.dispose);
      final failedSources = <String>[];

      final result = await setSourceWithFallbacks(
        index: 1,
        controller: controller,
        sources: ['badUrl', 'goodUrl'],
        trimToCommonTrackEnd: true,
        log: logs.add,
        onSourceLoadFailure: failedSources.add,
      );

      expect(result, equals(('goodUrl', 1)));
      expect(failedSources, equals(['badUrl']));
    });

    test('fails over when Android reports NOT_READY for a source', () async {
      final clips = <VideoClip>[];
      final controller = _RecordingControllerWithFailures(
        clips.add,
        failures: [
          PlatformException(
            code: 'NOT_READY',
            message: 'setClips timed out before player reached STATE_READY',
          ),
        ],
      );
      addTearDown(controller.dispose);

      final result = await setSourceWithFallbacks(
        index: 1,
        controller: controller,
        sources: ['slowOptimizedUrl', 'rawUrl'],
        trimToCommonTrackEnd: true,
        log: logs.add,
      );

      expect(result, equals(('rawUrl', 1)));
      expect(
        clips.map((clip) => clip.uri),
        equals(['slowOptimizedUrl', 'rawUrl']),
      );
      expect(logs, hasLength(1));
      expect(logs.single, contains('failedSource=slowOptimizedUrl'));
      expect(logs.single, contains('retrySource=rawUrl'));
    });

    test('fails over typed media-processing errors immediately', () async {
      final clips = <VideoClip>[];
      final controller = _RecordingControllerWithFailures(
        clips.add,
        failures: [
          PlatformException(
            code: 'PLAYER_ERROR',
            details: const <String, Object?>{'errorCode': 'media_processing'},
          ),
        ],
      );
      addTearDown(controller.dispose);

      final delays = <Duration>[];
      final result = await setSourceWithFallbacks(
        index: 2,
        controller: controller,
        sources: ['processingUrl', 'rawUrl'],
        trimToCommonTrackEnd: true,
        log: logs.add,
        delay: (duration) async => delays.add(duration),
      );

      // The processing source is not the last resort, so we do not stall on it:
      // the queued fallback is preferred immediately.
      expect(result, equals(('rawUrl', 1)));
      expect(
        clips.map((clip) => clip.uri),
        equals(['processingUrl', 'rawUrl']),
      );
      expect(delays, isEmpty);
      expect(logs.where((line) => line.contains('Source processing')), isEmpty);
      expect(logs.any((line) => line.contains('retrySource=rawUrl')), isTrue);
    });

    test('retries typed media-processing error on the last source', () async {
      final clips = <VideoClip>[];
      final controller = _RecordingControllerWithFailures(
        clips.add,
        failures: [
          PlatformException(
            code: 'PLAYER_ERROR',
            details: const <String, Object?>{'errorCode': 'media_processing'},
          ),
        ],
      );
      addTearDown(controller.dispose);

      final delays = <Duration>[];
      final result = await setSourceWithFallbacks(
        index: 2,
        controller: controller,
        sources: ['processingUrl'],
        trimToCommonTrackEnd: true,
        log: logs.add,
        delay: (duration) async => delays.add(duration),
      );

      expect(result, equals(('processingUrl', 0)));
      expect(clips.map((clip) => clip.uri), ['processingUrl', 'processingUrl']);
      expect(delays, [const Duration(seconds: 1)]);
      expect(logs.single, contains('Source processing'));
    });

    test('records media-processing source failure before failover', () async {
      final controller = _RecordingControllerWithFailures(
        (_) {},
        failures: [Exception('CoreMediaErrorDomain error -12667 - HTTP 202')],
      );
      addTearDown(controller.dispose);
      final recordedFailures = <String>[];

      await setSourceWithFallbacks(
        index: 2,
        controller: controller,
        sources: ['processingUrl', 'rawUrl'],
        trimToCommonTrackEnd: true,
        log: logs.add,
        onFailoverSourceFailure: recordedFailures.add,
      );

      expect(recordedFailures, equals(['processingUrl']));
    });

    for (final errorCode in [
      NativePlayerErrorCode.httpClientError,
      NativePlayerErrorCode.httpServerError,
      NativePlayerErrorCode.ioError,
      NativePlayerErrorCode.parseError,
    ]) {
      test('fails over typed ${errorCode.name} failures', () async {
        final clips = <VideoClip>[];
        final controller = _RecordingControllerWithFailures(
          clips.add,
          failures: [
            PlatformException(
              code: 'PLAYER_ERROR',
              message: errorCode.name,
              details: <String, Object?>{
                'errorCode': switch (errorCode) {
                  NativePlayerErrorCode.httpClientError => 'http_client_error',
                  NativePlayerErrorCode.httpServerError => 'http_server_error',
                  NativePlayerErrorCode.ioError => 'io_error',
                  NativePlayerErrorCode.parseError => 'parse_error',
                  _ => throw StateError('unsupported test case'),
                },
              },
            ),
          ],
        );
        addTearDown(controller.dispose);
        final recordedFailures = <String>[];

        await setSourceWithFallbacks(
          index: 2,
          controller: controller,
          sources: ['derivedMp4', 'hlsUrl'],
          trimToCommonTrackEnd: true,
          log: logs.add,
          onFailoverSourceFailure: recordedFailures.add,
        );

        expect(clips.map((clip) => clip.uri), equals(['derivedMp4', 'hlsUrl']));
        expect(recordedFailures, equals(['derivedMp4']));
      });
    }

    for (final errorCode in [
      NativePlayerErrorCode.networkError,
      NativePlayerErrorCode.timeout,
      NativePlayerErrorCode.decoderError,
    ]) {
      test('does not fail over typed ${errorCode.name} failures', () async {
        final clips = <VideoClip>[];
        final error = PlatformException(
          code: 'PLAYER_ERROR',
          message: errorCode.name,
          details: <String, Object?>{
            'errorCode': switch (errorCode) {
              NativePlayerErrorCode.networkError => 'network_error',
              NativePlayerErrorCode.timeout => 'timeout',
              NativePlayerErrorCode.decoderError => 'decoder_error',
              _ => throw StateError('unsupported test case'),
            },
          },
        );
        final controller = _RecordingControllerWithFailures(
          clips.add,
          failures: [error],
        );
        addTearDown(controller.dispose);

        await expectLater(
          () => setSourceWithFallbacks(
            index: 2,
            controller: controller,
            sources: ['derivedMp4', 'hlsUrl'],
            trimToCommonTrackEnd: true,
            log: logs.add,
          ),
          throwsA(same(error)),
        );

        expect(clips.map((clip) => clip.uri), equals(['derivedMp4']));
        expect(logs.single, contains('Source failed without failover'));
      });
    }

    test('allows non-feed callers to retain typed source fallback', () async {
      final clips = <VideoClip>[];
      final controller = _RecordingControllerWithFailures(
        clips.add,
        failures: [
          PlatformException(
            code: 'PLAYER_ERROR',
            details: const <String, Object?>{'errorCode': 'decoder_error'},
          ),
        ],
      );
      addTearDown(controller.dispose);

      final result = await setSourceWithFallbacks(
        index: 2,
        controller: controller,
        sources: ['derivedMp4', 'hlsUrl'],
        trimToCommonTrackEnd: true,
        log: logs.add,
        applyTypedFailoverPolicy: false,
      );

      expect(result, equals(('hlsUrl', 1)));
      expect(clips.map((clip) => clip.uri), equals(['derivedMp4', 'hlsUrl']));
    });

    test('uses source headers when retrying after HTTP 202', () async {
      final clips = <VideoClip>[];
      final controller = _RecordingControllerWithFailures(
        clips.add,
        failures: [Exception('CoreMediaErrorDomain error -12667 - HTTP 202')],
      );
      addTearDown(controller.dispose);

      const headers = {'Authorization': 'Nostr token'};
      final result = await setSourceWithFallbacks(
        index: 2,
        controller: controller,
        sources: ['processingUrl'],
        trimToCommonTrackEnd: true,
        log: logs.add,
        httpHeadersForSource: (_) => headers,
        delay: (_) async {},
      );

      expect(result, equals(('processingUrl', 0)));
      expect(clips, hasLength(2));
      expect(clips[0].httpHeaders, equals(headers));
      expect(clips[1].httpHeaders, equals(headers));
    });

    test(
      'retries the last source across the HTTP 202 budget then gives up',
      () async {
        final clips = <VideoClip>[];
        final controller = _RecordingControllerWithFailures(
          clips.add,
          failures: List<Exception>.filled(
            6,
            Exception('CoreMediaErrorDomain error -12667 - HTTP 202'),
          ),
        );
        addTearDown(controller.dispose);

        await expectLater(
          () => setSourceWithFallbacks(
            index: 2,
            controller: controller,
            sources: ['processingUrl'],
            trimToCommonTrackEnd: true,
            log: logs.add,
            delay: (_) async {},
          ),
          throwsA(isA<Exception>()),
        );

        // The last source is the only resort, so it is retried across the full
        // 202 budget (initial attempt + 5 delayed retries) before giving up.
        expect(
          clips.map((clip) => clip.uri),
          equals(List<String>.filled(6, 'processingUrl')),
        );
        expect(
          logs.where((line) => line.contains('Source processing')),
          hasLength(5),
        );
        expect(logs.any((line) => line.contains('All sources failed')), isTrue);
      },
    );

    test(
      'applies the same headers to every source in the fallover chain',
      () async {
        final clips = <VideoClip>[];
        final controller = _RecordingControllerWithOneFailure(clips.add);
        addTearDown(controller.dispose);

        const headers = {'Authorization': 'Nostr token'};
        final result = await setSourceWithFallbacks(
          index: 0,
          controller: controller,
          sources: ['optimizedUrl', 'hlsUrl'],
          trimToCommonTrackEnd: true,
          log: logs.add,
          // Mirrors _httpHeadersByIndex: one hash-bound header set returned for
          // every resolved source, so the fallback authenticates too.
          httpHeadersForSource: (_) => headers,
        );

        expect(result, equals(('hlsUrl', 1)));
        expect(clips, hasLength(2));
        expect(clips[0].uri, 'optimizedUrl');
        expect(clips[0].httpHeaders, equals(headers));
        expect(clips[1].uri, 'hlsUrl');
        expect(clips[1].httpHeaders, equals(headers));
      },
    );

    test(
      'keeps auth terminal when typed failover policy is disabled',
      () async {
        final clips = <VideoClip>[];
        final authError = PlatformException(
          code: 'COMPOSITION_ERROR',
          message: 'NSURLErrorDomain error -1013',
          details: const <String, Object?>{'errorCode': 'auth_required'},
        );
        final controller = _RecordingControllerWithFailures(
          clips.add,
          failures: [authError],
        );
        addTearDown(controller.dispose);

        await expectLater(
          () => setSourceWithFallbacks(
            index: 0,
            controller: controller,
            sources: ['optimizedUrl', 'hlsUrl'],
            trimToCommonTrackEnd: true,
            log: logs.add,
            applyTypedFailoverPolicy: false,
          ),
          throwsA(same(authError)),
        );

        expect(clips.map((clip) => clip.uri), equals(['optimizedUrl']));
        expect(logs, hasLength(1));
        expect(logs.single, contains('Source failed without failover'));
        expect(
          logs.single,
          contains('code=NativePlayerErrorCode.authRequired'),
        );
      },
    );

    test(
      'preserves the original stack trace for non-failover errors',
      () async {
        final error = PlatformException(
          code: 'PLAYER_ERROR',
          details: const <String, Object?>{'errorCode': 'network_error'},
        );
        final originalStackTrace = StackTrace.current;
        final controller = _StackTraceController(
          error: error,
          stackTrace: originalStackTrace,
        );
        addTearDown(controller.dispose);

        Object? caughtError;
        StackTrace? caughtStackTrace;
        try {
          await setSourceWithFallbacks(
            index: 0,
            controller: controller,
            sources: ['optimizedUrl', 'hlsUrl'],
            trimToCommonTrackEnd: true,
            log: logs.add,
          );
        } on Object catch (error, stackTrace) {
          caughtError = error;
          caughtStackTrace = stackTrace;
        }

        expect(caughtError, same(error));
        expect(
          caughtStackTrace.toString(),
          equals(originalStackTrace.toString()),
        );
      },
    );

    test('uses headers returned for the successful failover source', () async {
      final clips = <VideoClip>[];
      final controller = _RecordingControllerWithOneFailure(clips.add);
      addTearDown(controller.dispose);

      const headers = {'Authorization': 'Nostr token'};
      final result = await setSourceWithFallbacks(
        index: 0,
        controller: controller,
        sources: ['anonymousUrl', 'authedUrl'],
        trimToCommonTrackEnd: true,
        log: logs.add,
        httpHeadersForSource: (source) =>
            source == 'authedUrl' ? headers : null,
      );

      expect(result, equals(('authedUrl', 1)));
      expect(clips, hasLength(2));
      expect(clips[0].uri, 'anonymousUrl');
      expect(clips[0].httpHeaders, isEmpty);
      expect(clips[1].uri, 'authedUrl');
      expect(clips[1].httpHeaders, equals(headers));
    });

    test('aborts stale fallback without logging all sources failed', () async {
      var isCurrent = true;
      final controller = _DisposedDuringFallbackController(
        onDisposedFallback: () => isCurrent = false,
      );
      addTearDown(controller.dispose);

      await expectLater(
        () => setSourceWithFallbacks(
          index: 0,
          controller: controller,
          sources: ['derivedMp4', 'hls', 'raw'],
          trimToCommonTrackEnd: true,
          log: logs.add,
          isLoadCurrent: () => isCurrent,
        ),
        throwsA(isA<SourceLoadAborted>()),
      );

      expect(controller.attempts, equals(2));
      expect(logs, hasLength(1));
      expect(logs.single, contains('failedSource=derivedMp4'));
      expect(logs.single, contains('retrySource=hls'));
      expect(logs.any((line) => line.contains('All sources failed')), isFalse);
    });

    test(
      'aborts when the controller goes stale after a source opens',
      () async {
        var isCurrent = true;
        final controller = _StaleAfterSuccessController(
          onOpened: () => isCurrent = false,
        );
        addTearDown(controller.dispose);

        await expectLater(
          () => setSourceWithFallbacks(
            index: 3,
            controller: controller,
            sources: ['derivedMp4', 'hls', 'raw'],
            trimToCommonTrackEnd: true,
            log: logs.add,
            isLoadCurrent: () => isCurrent,
          ),
          throwsA(
            isA<SourceLoadAborted>()
                .having((e) => e.index, 'index', 3)
                .having((e) => e.source, 'source', 'derivedMp4')
                .having(
                  (e) => e.toString(),
                  'message',
                  contains(
                    'Source load aborted for stale controller index 3 '
                    'source=derivedMp4',
                  ),
                ),
          ),
        );

        // Only the first source is attempted; the post-open staleness check
        // aborts before returning a record or trying any fallback.
        expect(controller.attempts, equals(1));
        expect(logs, isEmpty);
      },
    );

    test('rethrows when all sources fail', () async {
      final controller = FakeController()
        ..setSourceError = Exception('always fails');
      addTearDown(controller.dispose);

      await expectLater(
        () => setSourceWithFallbacks(
          index: 0,
          controller: controller,
          sources: ['url1', 'url2'],
          trimToCommonTrackEnd: true,
          log: logs.add,
        ),
        throwsA(isA<Exception>()),
      );
    });

    test('throws StateError when sources list is empty', () async {
      final controller = FakeController();
      addTearDown(controller.dispose);

      await expectLater(
        () => setSourceWithFallbacks(
          index: 0,
          controller: controller,
          sources: [],
          trimToCommonTrackEnd: true,
          log: logs.add,
        ),
        throwsA(isA<StateError>()),
      );
    });

    test(
      'returns single source when only one provided and it succeeds',
      () async {
        final controller = FakeController();
        addTearDown(controller.dispose);

        final result = await setSourceWithFallbacks(
          index: 5,
          controller: controller,
          sources: ['onlyUrl'],
          trimToCommonTrackEnd: true,
          log: logs.add,
        );

        expect(result, equals(('onlyUrl', 0)));
      },
    );
  });
}

/// A [FakeController] that fails only on the first [setSource] call.
class _FakeControllerWithOneFailure extends FakeController {
  var _failed = false;

  @override
  Future<void> setSource(VideoClip clip) async {
    if (!_failed) {
      _failed = true;
      throw Exception('first source error');
    }
  }
}

/// A [FakeController] that records every clip and fails only on the first
/// [setSource] call, so a fallover chain can be asserted clip-by-clip.
class _RecordingControllerWithOneFailure extends FakeController {
  _RecordingControllerWithOneFailure(this._record);

  final void Function(VideoClip) _record;
  var _failed = false;

  @override
  Future<void> setSource(VideoClip clip) async {
    _record(clip);
    if (!_failed) {
      _failed = true;
      throw Exception('first source error');
    }
  }
}

class _RecordingControllerWithFailures extends FakeController {
  _RecordingControllerWithFailures(this._record, {required this.failures});

  final void Function(VideoClip) _record;
  final List<Exception> failures;
  int attempts = 0;

  @override
  Future<void> setSource(VideoClip clip) async {
    _record(clip);
    if (attempts < failures.length) {
      throw failures[attempts++];
    }
    attempts++;
  }
}

class _StackTraceController extends FakeController {
  _StackTraceController({required this.error, required this.stackTrace});

  final Object error;
  final StackTrace stackTrace;

  @override
  Future<void> setSource(VideoClip clip) async {
    Error.throwWithStackTrace(error, stackTrace);
  }
}

class _DisposedDuringFallbackController extends FakeController {
  _DisposedDuringFallbackController({required this.onDisposedFallback});

  final VoidCallback onDisposedFallback;
  int attempts = 0;

  @override
  Future<void> setSource(VideoClip clip) async {
    attempts++;
    if (attempts == 1) {
      throw Exception('first source error');
    }

    onDisposedFallback();
    throw StateError('Controller has been disposed.');
  }
}

/// A [FakeController] whose first [setSource] succeeds but marks the load
/// stale (e.g. the feed window scrolled past) before the caller can register
/// the opened source.
class _StaleAfterSuccessController extends FakeController {
  _StaleAfterSuccessController({required this.onOpened});

  final VoidCallback onOpened;
  int attempts = 0;

  @override
  Future<void> setSource(VideoClip clip) async {
    attempts++;
    onOpened();
  }
}
