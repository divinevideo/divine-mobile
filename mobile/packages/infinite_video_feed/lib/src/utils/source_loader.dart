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
/// [maxPlaybackDuration] becomes the clip's end position, so the native
/// player stops (and loops) there. Sources shorter than the cap are
/// unaffected — both backends clamp the clip end to the real duration.
///
/// The two playback-policy flags are required rather than defaulted, so a new
/// surface states its own intent instead of silently inheriting the feed's.
/// Neither has a norm to deviate from; read both as a choice.
///
/// [trimToCommonTrackEnd] hides the loop seam left by a source whose audio and
/// video tracks end a few milliseconds apart. Pass `true` on a surface that
/// loops a finished clip and draws no duration axis, which is what a feed does.
/// Pass `false` wherever playback is measured against the container duration —
/// an editor timeline, for instance — because the clamp can end playback up to
/// 500 ms before the duration such an axis is drawn from.
///
/// [applyTypedFailoverPolicy] decides whether a typed player error ends the
/// ladder. Pass `true` to stop on a typed error that changing sources cannot
/// fix, preserving its original error and stack trace, so a doomed ladder fails
/// fast instead of retrying every rendition of the same broken file. Pass
/// `false` to keep walking the ladder, which is what a surface offering
/// hand-picked alternate renditions wants. Either way, authentication errors
/// stop the ladder immediately and media-processing errors stay eligible for
/// fallback, because another rendition may already be ready.
Future<(String, int)> setSourceWithFallbacks({
  required int index,
  required DivineVideoPlayerController controller,
  required List<String> sources,
  required void Function(String) log,
  required bool trimToCommonTrackEnd,
  required bool applyTypedFailoverPolicy,
  Map<String, String>? Function(String source)? httpHeadersForSource,
  bool Function()? isLoadCurrent,
  Duration? maxPlaybackDuration,
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
