import 'package:divine_video_player/divine_video_player.dart';
import 'package:infinite_video_feed/src/utils/playback_sources.dart';

const _mediaProcessingRetryDelays = <Duration>[
  Duration(seconds: 1),
  Duration(seconds: 2),
  Duration(seconds: 3),
  Duration(seconds: 5),
  Duration(seconds: 8),
];

/// Signals that source loading was cancelled because the owning controller
/// window moved on while fallbacks were still in flight.
class SourceLoadAborted implements Exception {
  /// Creates an abort signal for the stale source load at [index].
  const SourceLoadAborted({required this.index, required this.source});

  /// Feed index whose source load was aborted.
  final int index;

  /// Source URL being attempted when the load became stale.
  final String source;

  @override
  String toString() =>
      'Source load aborted for stale controller index $index source=$source';
}

/// Sequentially attempts each URL in [sources] until one loads successfully.
///
/// Returns a record of `(source, attemptIndex)` for the URL that opened.
/// Logs each failure via [log] and re-throws the last error when every
/// source fails.
///
/// Authentication errors always stop the source ladder immediately. When
/// [applyTypedFailoverPolicy] is true, other typed player errors that cannot be
/// fixed by changing sources also stop immediately and preserve their original
/// error and stack trace. Media-processing errors remain eligible for fallback
/// because another rendition may already be ready.
///
/// [maxPlaybackDuration] becomes the clip's end position, so the native
/// player stops (and loops) there. Sources shorter than the cap are
/// unaffected — both backends clamp the clip end to the real duration.
///
/// [trimToCommonTrackEnd] hides the loop seam left by a source whose audio and
/// video tracks end a few milliseconds apart, and is what a looping feed wants.
/// Turn it off wherever playback is measured against the container duration —
/// an editor timeline, for instance — because the clamp can end playback up to
/// 500 ms before the duration such an axis is drawn from.
Future<(String, int)> setSourceWithFallbacks({
  required int index,
  required DivineVideoPlayerController controller,
  required List<String> sources,
  required void Function(String) log,
  required bool trimToCommonTrackEnd,
  Map<String, String>? Function(String source)? httpHeadersForSource,
  bool Function()? isLoadCurrent,
  Duration? maxPlaybackDuration,
  bool applyTypedFailoverPolicy = true,
  Future<void> Function(Duration duration) delay = Future<void>.delayed,
  void Function(String source)? onFailoverSourceFailure,
  void Function(String source)? onSourceLoadFailure,
}) async {
  Object? lastError;
  StackTrace? lastStackTrace;

  void abortIfStale(String source) {
    if (isLoadCurrent != null && !isLoadCurrent()) {
      throw SourceLoadAborted(index: index, source: source);
    }
  }

  for (var attemptIndex = 0; attemptIndex < sources.length; attemptIndex++) {
    final source = sources[attemptIndex];
    abortIfStale(source);
    try {
      await controller.setSource(
        VideoClip.network(
          source,
          end: maxPlaybackDuration,
          httpHeaders: httpHeadersForSource?.call(source) ?? const {},
          trimToCommonTrackEnd: trimToCommonTrackEnd,
        ),
      );
      abortIfStale(source);
      return (source, attemptIndex);
    } on SourceLoadAborted {
      rethrow;
    } on Object catch (error, stackTrace) {
      abortIfStale(source);
      lastError = error;
      lastStackTrace = stackTrace;
      onSourceLoadFailure?.call(source);
      final nativeErrorCode = nativePlayerErrorCodeFromError(error);
      final isTypedNonFailoverError =
          nativeErrorCode == NativePlayerErrorCode.authRequired ||
          (applyTypedFailoverPolicy &&
              nativeErrorCode != null &&
              nativeErrorCode != NativePlayerErrorCode.unknown &&
              nativeErrorCode != NativePlayerErrorCode.mediaProcessing &&
              !nativeErrorCode.shouldFailover);
      if (isTypedNonFailoverError) {
        log(
          'Source failed without failover index $index: '
          'failedSource=$source '
          'attempt=$attemptIndex '
          'code=$nativeErrorCode '
          'error=$lastError',
        );
        Error.throwWithStackTrace(error, stackTrace);
      }
      // Only wait-and-retry a processing (HTTP 202) source when it is the last
      // resort. While another source is queued, prefer it immediately instead
      // of stalling up to ~19s for a derivative that is still transcoding.
      final isLastSource = attemptIndex == sources.length - 1;
      if (isLastSource && isMediaProcessingError(error)) {
        for (final retryDelay in _mediaProcessingRetryDelays) {
          log(
            'Source processing index $index: '
            'source=$source '
            'attempt=$attemptIndex '
            'retryInMs=${retryDelay.inMilliseconds} '
            'error=$error',
          );
          await delay(retryDelay);
          abortIfStale(source);
          try {
            await controller.setSource(
              VideoClip.network(
                source,
                end: maxPlaybackDuration,
                httpHeaders: httpHeadersForSource?.call(source) ?? const {},
                trimToCommonTrackEnd: trimToCommonTrackEnd,
              ),
            );
            abortIfStale(source);
            return (source, attemptIndex);
          } on SourceLoadAborted {
            rethrow;
          } on Object catch (retryError, retryStackTrace) {
            abortIfStale(source);
            lastError = retryError;
            lastStackTrace = retryStackTrace;
            if (isMediaProcessingError(retryError)) {
              continue;
            }
            break;
          }
        }
      }
      final nextAttempt = attemptIndex + 1;
      if (nextAttempt < sources.length) {
        if (_shouldRecordFailoverSourceFailure(error)) {
          onFailoverSourceFailure?.call(source);
        }
        log(
          'Source failed index $index: '
          'failedSource=$source '
          'retrySource=${sources[nextAttempt]} '
          'attempt=$attemptIndex '
          'error=$lastError',
        );
        continue;
      }

      log(
        'All sources failed index $index: '
        'failedSource=$source '
        'attempt=$attemptIndex '
        'error=$lastError',
      );
    }
  }

  if (lastError != null && lastStackTrace != null) {
    Error.throwWithStackTrace(lastError, lastStackTrace);
  }

  throw StateError('No playback sources resolved for index $index');
}

bool _shouldRecordFailoverSourceFailure(Object error) {
  if (isMediaProcessingError(error)) return true;

  final nativeErrorCode = nativePlayerErrorCodeFromError(error);
  return nativeErrorCode?.shouldFailover ?? false;
}
