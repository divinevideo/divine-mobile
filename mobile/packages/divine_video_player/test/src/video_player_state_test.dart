import 'package:divine_video_player/divine_video_player.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(NativePlayerErrorCode, () {
    group('shouldFailover', () {
      test('returns false for mediaProcessing', () {
        expect(NativePlayerErrorCode.mediaProcessing.shouldFailover, isFalse);
      });

      test('returns false for authRequired', () {
        expect(NativePlayerErrorCode.authRequired.shouldFailover, isFalse);
      });

      test('returns true for forbidden', () {
        expect(NativePlayerErrorCode.forbidden.shouldFailover, isTrue);
      });

      // A 404 is one mirror's answer about one URL. Divine media is mirrored
      // across Blossom servers, so the feed must try the next source rather
      // than treating the media as deleted.
      test('returns true for notFound', () {
        expect(NativePlayerErrorCode.notFound.shouldFailover, isTrue);
      });

      test('returns true for httpClientError', () {
        expect(NativePlayerErrorCode.httpClientError.shouldFailover, isTrue);
      });

      test('returns true for httpServerError', () {
        expect(NativePlayerErrorCode.httpServerError.shouldFailover, isTrue);
      });

      test('returns true for ioError', () {
        expect(NativePlayerErrorCode.ioError.shouldFailover, isTrue);
      });

      test('returns true for parseError', () {
        expect(NativePlayerErrorCode.parseError.shouldFailover, isTrue);
      });

      test('returns false for networkError', () {
        expect(NativePlayerErrorCode.networkError.shouldFailover, isFalse);
      });

      test('returns false for timeout', () {
        expect(NativePlayerErrorCode.timeout.shouldFailover, isFalse);
      });

      test('returns false for decoderError', () {
        expect(NativePlayerErrorCode.decoderError.shouldFailover, isFalse);
      });

      test('returns false for unknown', () {
        expect(NativePlayerErrorCode.unknown.shouldFailover, isFalse);
      });
    });

    group('isTransient', () {
      test('returns true for mediaProcessing', () {
        expect(NativePlayerErrorCode.mediaProcessing.isTransient, isTrue);
      });

      test('returns true for networkError', () {
        expect(NativePlayerErrorCode.networkError.isTransient, isTrue);
      });

      test('returns true for timeout', () {
        expect(NativePlayerErrorCode.timeout.isTransient, isTrue);
      });

      test('returns false for ioError', () {
        expect(NativePlayerErrorCode.ioError.isTransient, isFalse);
      });

      test('returns false for authRequired', () {
        expect(NativePlayerErrorCode.authRequired.isTransient, isFalse);
      });

      test('returns false for forbidden', () {
        expect(NativePlayerErrorCode.forbidden.isTransient, isFalse);
      });

      test('returns false for notFound', () {
        expect(NativePlayerErrorCode.notFound.isTransient, isFalse);
      });

      test('returns false for httpServerError', () {
        expect(NativePlayerErrorCode.httpServerError.isTransient, isFalse);
      });

      test('returns false for httpClientError', () {
        expect(NativePlayerErrorCode.httpClientError.isTransient, isFalse);
      });

      test('returns false for parseError', () {
        expect(NativePlayerErrorCode.parseError.isTransient, isFalse);
      });

      test('returns false for decoderError', () {
        expect(NativePlayerErrorCode.decoderError.isTransient, isFalse);
      });

      test('returns false for unknown', () {
        expect(NativePlayerErrorCode.unknown.isTransient, isFalse);
      });
    });

    group('fromString', () {
      test('parses media_processing', () {
        expect(
          NativePlayerErrorCode.fromString('media_processing'),
          equals(NativePlayerErrorCode.mediaProcessing),
        );
      });

      test('parses auth_required', () {
        expect(
          NativePlayerErrorCode.fromString('auth_required'),
          equals(NativePlayerErrorCode.authRequired),
        );
      });

      test('parses forbidden', () {
        expect(
          NativePlayerErrorCode.fromString('forbidden'),
          equals(NativePlayerErrorCode.forbidden),
        );
      });

      test('parses not_found', () {
        expect(
          NativePlayerErrorCode.fromString('not_found'),
          equals(NativePlayerErrorCode.notFound),
        );
      });

      test('parses http_client_error', () {
        expect(
          NativePlayerErrorCode.fromString('http_client_error'),
          equals(NativePlayerErrorCode.httpClientError),
        );
      });

      test('parses http_server_error', () {
        expect(
          NativePlayerErrorCode.fromString('http_server_error'),
          equals(NativePlayerErrorCode.httpServerError),
        );
      });

      test('parses network_error', () {
        expect(
          NativePlayerErrorCode.fromString('network_error'),
          equals(NativePlayerErrorCode.networkError),
        );
      });

      test('parses timeout', () {
        expect(
          NativePlayerErrorCode.fromString('timeout'),
          equals(NativePlayerErrorCode.timeout),
        );
      });

      test('parses io_error', () {
        expect(
          NativePlayerErrorCode.fromString('io_error'),
          equals(NativePlayerErrorCode.ioError),
        );
      });

      test('parses parse_error', () {
        expect(
          NativePlayerErrorCode.fromString('parse_error'),
          equals(NativePlayerErrorCode.parseError),
        );
      });

      test('parses decoder_error', () {
        expect(
          NativePlayerErrorCode.fromString('decoder_error'),
          equals(NativePlayerErrorCode.decoderError),
        );
      });

      test('returns unknown for unrecognised value', () {
        expect(
          NativePlayerErrorCode.fromString('some_unknown_code'),
          equals(NativePlayerErrorCode.unknown),
        );
      });
    });
  });

  group(PlaybackStatus, () {
    test('isIdle returns true only for idle', () {
      expect(PlaybackStatus.idle.isIdle, isTrue);
      expect(PlaybackStatus.playing.isIdle, isFalse);
    });

    test('isReady returns true only for ready', () {
      expect(PlaybackStatus.ready.isReady, isTrue);
      expect(PlaybackStatus.idle.isReady, isFalse);
    });

    test('isPlaying returns true only for playing', () {
      expect(PlaybackStatus.playing.isPlaying, isTrue);
      expect(PlaybackStatus.paused.isPlaying, isFalse);
    });

    test('isPaused returns true only for paused', () {
      expect(PlaybackStatus.paused.isPaused, isTrue);
      expect(PlaybackStatus.playing.isPaused, isFalse);
    });

    test('isBuffering returns true only for buffering', () {
      expect(PlaybackStatus.buffering.isBuffering, isTrue);
      expect(PlaybackStatus.playing.isBuffering, isFalse);
    });

    test('isCompleted returns true only for completed', () {
      expect(PlaybackStatus.completed.isCompleted, isTrue);
      expect(PlaybackStatus.playing.isCompleted, isFalse);
    });

    test('hasError returns true only for error', () {
      expect(PlaybackStatus.error.hasError, isTrue);
      expect(PlaybackStatus.playing.hasError, isFalse);
    });
  });

  group(DivineVideoPlayerState, () {
    test('default constructor has correct defaults', () {
      const state = DivineVideoPlayerState();

      expect(state.status, equals(PlaybackStatus.idle));
      expect(state.position, equals(Duration.zero));
      expect(state.duration, equals(Duration.zero));
      expect(state.bufferedPosition, equals(Duration.zero));
      expect(state.currentClipIndex, isZero);
      expect(state.clipCount, isZero);
      expect(state.isLooping, isFalse);
      expect(state.volume, equals(1.0));
      expect(state.playbackSpeed, equals(1.0));
      expect(state.isFirstFrameRendered, isFalse);
      expect(state.videoWidth, isZero);
      expect(state.videoHeight, isZero);
      expect(state.pixelWidthHeightRatio, equals(1.0));
      expect(state.rotationDegrees, isZero);
    });

    test('isPlaying delegates to status', () {
      const playing = DivineVideoPlayerState(status: PlaybackStatus.playing);
      const paused = DivineVideoPlayerState(status: PlaybackStatus.paused);

      expect(playing.isPlaying, isTrue);
      expect(paused.isPlaying, isFalse);
    });

    test('isBuffering delegates to status', () {
      const buffering = DivineVideoPlayerState(
        status: PlaybackStatus.buffering,
      );
      const playing = DivineVideoPlayerState(status: PlaybackStatus.playing);

      expect(buffering.isBuffering, isTrue);
      expect(playing.isBuffering, isFalse);
    });

    test('isPaused delegates to status', () {
      const paused = DivineVideoPlayerState(status: PlaybackStatus.paused);
      const playing = DivineVideoPlayerState(status: PlaybackStatus.playing);

      expect(paused.isPaused, isTrue);
      expect(playing.isPaused, isFalse);
    });

    test('hasError delegates to status', () {
      const error = DivineVideoPlayerState(status: PlaybackStatus.error);
      const playing = DivineVideoPlayerState(status: PlaybackStatus.playing);

      expect(error.hasError, isTrue);
      expect(playing.hasError, isFalse);
    });

    group('aspectRatio', () {
      test('returns width / height when both are positive', () {
        const state = DivineVideoPlayerState(
          videoWidth: 1920,
          videoHeight: 1080,
        );
        expect(state.aspectRatio, closeTo(1.778, 0.001));
      });

      test('applies pixel aspect ratio to coded dimensions', () {
        const state = DivineVideoPlayerState(
          videoWidth: 1280,
          videoHeight: 720,
          pixelWidthHeightRatio: 9 / 16,
        );

        expect(state.aspectRatio, equals(1.0));
      });

      test('returns 0 when width is zero', () {
        const state = DivineVideoPlayerState(videoHeight: 1080);
        expect(state.aspectRatio, isZero);
      });

      test('returns 0 when height is zero', () {
        const state = DivineVideoPlayerState(videoWidth: 1920);
        expect(state.aspectRatio, isZero);
      });

      test('returns 0 when both are zero', () {
        const state = DivineVideoPlayerState();
        expect(state.aspectRatio, isZero);
      });
    });

    group('equality', () {
      test('two default states are equal', () {
        const a = DivineVideoPlayerState();
        const b = DivineVideoPlayerState();

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('states with identical fields are equal', () {
        const a = DivineVideoPlayerState(
          status: PlaybackStatus.playing,
          position: Duration(seconds: 5),
          duration: Duration(seconds: 30),
          bufferedPosition: Duration(seconds: 10),
          currentClipIndex: 1,
          clipCount: 3,
          isLooping: true,
          volume: 0.5,
          playbackSpeed: 2,
          isFirstFrameRendered: true,
          videoWidth: 1920,
          videoHeight: 1080,
        );
        const b = DivineVideoPlayerState(
          status: PlaybackStatus.playing,
          position: Duration(seconds: 5),
          duration: Duration(seconds: 30),
          bufferedPosition: Duration(seconds: 10),
          currentClipIndex: 1,
          clipCount: 3,
          isLooping: true,
          volume: 0.5,
          playbackSpeed: 2,
          isFirstFrameRendered: true,
          videoWidth: 1920,
          videoHeight: 1080,
        );

        expect(a, equals(b));
        expect(a.hashCode, equals(b.hashCode));
      });

      test('states with different status are not equal', () {
        const a = DivineVideoPlayerState(status: PlaybackStatus.playing);
        const b = DivineVideoPlayerState(status: PlaybackStatus.paused);

        expect(a, isNot(equals(b)));
      });

      test('states with different position are not equal', () {
        const a = DivineVideoPlayerState(position: Duration(seconds: 1));
        const b = DivineVideoPlayerState(position: Duration(seconds: 2));

        expect(a, isNot(equals(b)));
      });

      test('states with different rotationDegrees are not equal', () {
        const a = DivineVideoPlayerState();
        const b = DivineVideoPlayerState(rotationDegrees: 90);

        expect(a, isNot(equals(b)));
        expect(a.hashCode, isNot(equals(b.hashCode)));
      });

      test('states with different pixel aspect ratios are not equal', () {
        const a = DivineVideoPlayerState();
        const b = DivineVideoPlayerState(pixelWidthHeightRatio: 9 / 16);

        expect(a, isNot(equals(b)));
        expect(a.hashCode, isNot(equals(b.hashCode)));
      });

      test('copyWith without changes returns equal state', () {
        const original = DivineVideoPlayerState(
          status: PlaybackStatus.playing,
          position: Duration(seconds: 5),
        );
        final copy = original.copyWith();

        expect(copy, equals(original));
        expect(copy.hashCode, equals(original.hashCode));
      });
    });

    group('copyWith', () {
      test('returns identical state when no args given', () {
        const original = DivineVideoPlayerState(
          status: PlaybackStatus.playing,
          position: Duration(seconds: 5),
          duration: Duration(seconds: 30),
          bufferedPosition: Duration(seconds: 10),
          currentClipIndex: 1,
          clipCount: 3,
          isLooping: true,
          volume: 0.5,
          playbackSpeed: 2,
          isFirstFrameRendered: true,
          videoWidth: 1920,
          videoHeight: 1080,
        );
        final copy = original.copyWith();

        expect(copy.status, equals(original.status));
        expect(copy.position, equals(original.position));
        expect(copy.duration, equals(original.duration));
        expect(copy.bufferedPosition, equals(original.bufferedPosition));
        expect(copy.currentClipIndex, equals(original.currentClipIndex));
        expect(copy.clipCount, equals(original.clipCount));
        expect(copy.isLooping, equals(original.isLooping));
        expect(copy.volume, equals(original.volume));
        expect(copy.playbackSpeed, equals(original.playbackSpeed));
        expect(
          copy.isFirstFrameRendered,
          equals(original.isFirstFrameRendered),
        );
        expect(copy.videoWidth, equals(original.videoWidth));
        expect(copy.videoHeight, equals(original.videoHeight));
        expect(
          copy.pixelWidthHeightRatio,
          equals(original.pixelWidthHeightRatio),
        );
        expect(copy.rotationDegrees, equals(original.rotationDegrees));
      });

      test('overrides rotationDegrees when specified', () {
        const original = DivineVideoPlayerState();
        final copy = original.copyWith(rotationDegrees: 90);

        expect(copy.rotationDegrees, equals(90));
        expect(original.rotationDegrees, isZero);
      });

      test('overrides pixelWidthHeightRatio when specified', () {
        const original = DivineVideoPlayerState();
        final copy = original.copyWith(pixelWidthHeightRatio: 9 / 16);

        expect(copy.pixelWidthHeightRatio, equals(9 / 16));
        expect(original.pixelWidthHeightRatio, equals(1.0));
      });

      test('overrides only specified fields', () {
        const original = DivineVideoPlayerState();
        final copy = original.copyWith(
          status: PlaybackStatus.playing,
          volume: 0.7,
        );

        expect(copy.status, equals(PlaybackStatus.playing));
        expect(copy.volume, equals(0.7));
        expect(copy.position, equals(original.position));
      });

      test('clearError: true resets errorMessage and errorCode', () {
        const original = DivineVideoPlayerState(
          status: PlaybackStatus.error,
          errorMessage: 'boom',
          errorCode: NativePlayerErrorCode.networkError,
        );
        final copy = original.copyWith(
          status: PlaybackStatus.idle,
          clearError: true,
        );

        expect(copy.status, equals(PlaybackStatus.idle));
        expect(copy.errorMessage, isNull);
        expect(copy.errorCode, isNull);
      });

      test('without clearError, error fields persist on status change', () {
        const original = DivineVideoPlayerState(
          status: PlaybackStatus.error,
          errorMessage: 'boom',
          errorCode: NativePlayerErrorCode.networkError,
        );
        final copy = original.copyWith(status: PlaybackStatus.idle);

        expect(copy.errorMessage, equals('boom'));
        expect(copy.errorCode, equals(NativePlayerErrorCode.networkError));
      });
    });

    group('fromMap', () {
      test('parses a complete map', () {
        final state = DivineVideoPlayerState.fromMap({
          'status': 'playing',
          'positionMs': 5000,
          'durationMs': 30000,
          'bufferedPositionMs': 10000,
          'currentClipIndex': 1,
          'clipCount': 3,
          'isLooping': true,
          'volume': 0.5,
          'playbackSpeed': 2.0,
          'isFirstFrameRendered': true,
          'videoWidth': 1920,
          'videoHeight': 1080,
          'pixelWidthHeightRatio': 0.75,
          'rotationDegrees': 90,
        });

        expect(state.status, equals(PlaybackStatus.playing));
        expect(state.position, equals(const Duration(seconds: 5)));
        expect(state.duration, equals(const Duration(seconds: 30)));
        expect(state.bufferedPosition, equals(const Duration(seconds: 10)));
        expect(state.currentClipIndex, equals(1));
        expect(state.clipCount, equals(3));
        expect(state.isLooping, isTrue);
        expect(state.volume, equals(0.5));
        expect(state.playbackSpeed, equals(2.0));
        expect(state.isFirstFrameRendered, isTrue);
        expect(state.videoWidth, equals(1920));
        expect(state.videoHeight, equals(1080));
        expect(state.pixelWidthHeightRatio, equals(0.75));
        expect(state.rotationDegrees, equals(90));
      });

      test('uses defaults for missing keys', () {
        final state = DivineVideoPlayerState.fromMap({});

        expect(state.status, equals(PlaybackStatus.idle));
        expect(state.position, equals(Duration.zero));
        expect(state.duration, equals(Duration.zero));
        expect(state.bufferedPosition, equals(Duration.zero));
        expect(state.currentClipIndex, isZero);
        expect(state.clipCount, isZero);
        expect(state.isLooping, isFalse);
        expect(state.volume, equals(1.0));
        expect(state.playbackSpeed, equals(1.0));
        expect(state.isFirstFrameRendered, isFalse);
        expect(state.videoWidth, isZero);
        expect(state.videoHeight, isZero);
        expect(state.pixelWidthHeightRatio, equals(1.0));
        expect(state.rotationDegrees, isZero);
      });

      test('parses all status values', () {
        for (final name in [
          'idle',
          'ready',
          'playing',
          'paused',
          'buffering',
          'completed',
          'error',
        ]) {
          final state = DivineVideoPlayerState.fromMap({'status': name});
          expect(state.status.name, equals(name));
        }
      });

      test('accepts an integer pixel aspect ratio from the platform', () {
        final state = DivineVideoPlayerState.fromMap({
          'pixelWidthHeightRatio': 1,
        });

        expect(state.pixelWidthHeightRatio, equals(1.0));
      });

      test('parses errorCode string into NativePlayerErrorCode', () {
        final state = DivineVideoPlayerState.fromMap({
          'status': 'error',
          'errorCode': 'http_client_error',
          'errorMessage': 'HTTP 404',
        });

        expect(state.errorCode, equals(NativePlayerErrorCode.httpClientError));
        expect(state.errorMessage, equals('HTTP 404'));
      });

      test('leaves errorCode null when key is absent', () {
        final state = DivineVideoPlayerState.fromMap({'status': 'error'});
        expect(state.errorCode, isNull);
      });

      test('leaves errorCode null when value is not a string', () {
        final state = DivineVideoPlayerState.fromMap({
          'status': 'error',
          'errorCode': 42,
        });
        expect(state.errorCode, isNull);
      });

      test('defaults unknown status to idle', () {
        final state = DivineVideoPlayerState.fromMap({
          'status': 'unknown_status',
        });
        expect(state.status, equals(PlaybackStatus.idle));
      });

      test('handles null status', () {
        final state = DivineVideoPlayerState.fromMap({'status': null});
        expect(state.status, equals(PlaybackStatus.idle));
      });
    });

    group('toString', () {
      test('includes all fields', () {
        const state = DivineVideoPlayerState(
          status: PlaybackStatus.playing,
          videoWidth: 1920,
          videoHeight: 1080,
          pixelWidthHeightRatio: 0.75,
          rotationDegrees: 90,
        );
        final string = state.toString();

        expect(string, contains('playing'));
        expect(string, contains('1920x1080'));
        expect(string, contains('pixelRatio: 0.75'));
        expect(string, contains('rotation: 90'));
      });

      test('includes error message when present', () {
        const state = DivineVideoPlayerState(status: PlaybackStatus.error);
        expect(state.toString(), contains('error'));
      });

      test('omits error section when not in error state', () {
        const state = DivineVideoPlayerState();
        expect(state.toString(), isNot(contains('error')));
      });
    });
  });
}
