import 'dart:io';

import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_editor/render_audio_fetcher.dart';
import 'package:openvine/services/video_editor/video_render_failures.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group(VideoRenderFailedException, () {
    test('traceValue uses the stable reason when there is no cause', () {
      const failure = VideoRenderFailedException(
        VideoRenderFailureReason.emptyClips,
      );

      expect(failure.traceValue, 'empty_clips');
    });

    test('traceValue adds the platform code, never the message', () {
      final failure = VideoRenderFailedException(
        VideoRenderFailureReason.nativeRender,
        cause: PlatformException(
          code: 'RENDER_ERROR',
          message: '/var/mobile/Containers/Data/Application/x/clip.mp4',
        ),
      );

      expect(failure.traceValue, 'native_render:RENDER_ERROR');
      expect(failure.traceValue, isNot(contains('/var/mobile')));
    });

    test('traceValue adds the type of a non-platform cause', () {
      const failure = VideoRenderFailedException(
        VideoRenderFailureReason.canceled,
        cause: RenderCanceledException(),
      );

      expect(failure.traceValue, 'canceled:RenderCanceledException');
    });

    test(
      'traceValue names a sound that could not be fetched without its URL',
      () {
        final failure = VideoRenderFailedException(
          VideoRenderFailureReason.audioUnavailable,
          cause: RenderAudioFetchException(
            Uri.parse('https://media.example/blob'),
            statusCode: 503,
          ),
        );

        expect(
          failure.traceValue,
          'audio_unavailable:RenderAudioFetchException',
        );
        expect(failure.traceValue, isNot(contains('media.example')));
      },
    );

    group('native', () {
      test('classifies a Dart disk-full write as insufficientStorage', () {
        final failure = VideoRenderFailedException.native(
          const FileSystemException(
            'write failed',
            '/tmp/render-audio.part',
            OSError('No space left on device', 28),
          ),
        );

        expect(failure.reason, VideoRenderFailureReason.insufficientStorage);
        expect(failure.traceValue, 'insufficient_storage:disk_full');
      });

      test('classifies an out-of-storage export as insufficientStorage by the '
          "platform's code, not its wording", () {
        final failure = VideoRenderFailedException.native(
          PlatformException(
            code: 'RENDER_ERROR',
            message: 'Das Volume ist voll.',
            details: <Object?, Object?>{
              'domain': 'AVFoundationErrorDomain',
              'code': NativeFailureDetails.avErrorDiskFull,
            },
          ),
        );

        expect(failure.reason, VideoRenderFailureReason.insufficientStorage);
        expect(failure.traceValue, 'insufficient_storage:disk_full');
      });

      test("classifies Android's full disk from the muxer's cause", () {
        final failure = VideoRenderFailedException.native(
          PlatformException(
            code: 'RENDER_ERROR',
            message: 'Muxer error',
            details: <Object?, Object?>{
              'domain': 'androidx.media3.transformer.ExportException',
              'code': 7001,
              'codeName': 'ERROR_CODE_MUXING_FAILED',
              'cause':
                  'androidx.media3.muxer.MuxerException: write <- '
                  'java.io.IOException: write failed: ENOSPC '
                  '(No space left on device)',
            },
          ),
        );

        expect(failure.reason, VideoRenderFailureReason.insufficientStorage);
      });

      test('keeps every other platform failure under nativeRender', () {
        final failure = VideoRenderFailedException.native(
          PlatformException(
            code: 'RENDER_ERROR',
            message: 'Video frame processing error',
            details: <Object?, Object?>{
              'domain': 'androidx.media3.transformer.ExportException',
              'code': 5001,
              'codeName': 'ERROR_CODE_VIDEO_FRAME_PROCESSING_FAILED',
            },
          ),
        );

        expect(failure.reason, VideoRenderFailureReason.nativeRender);
        expect(
          failure.traceValue,
          'native_render:video_frame_processing_failed',
        );
      });

      test('marks a failure the plugin reports on an HDR source', () {
        final failure = VideoRenderFailedException.native(
          PlatformException(
            code: 'RENDER_ERROR',
            message: 'Video frame processing error',
            details: <Object?, Object?>{
              'domain': 'androidx.media3.transformer.ExportException',
              'code': 5001,
              'codeName': 'ERROR_CODE_VIDEO_FRAME_PROCESSING_FAILED',
              'sources': <Object?>[
                <Object?, Object?>{'mime': 'video/avc', 'transfer': 'sdr'},
                <Object?, Object?>{'mime': 'video/hevc', 'transfer': 'hlg'},
              ],
            },
          ),
        );

        expect(
          failure.traceValue,
          'native_render:video_frame_processing_failed:hdr',
        );
      });

      test('leaves a failure on SDR sources unmarked', () {
        final failure = VideoRenderFailedException.native(
          PlatformException(
            code: 'RENDER_ERROR',
            message: 'Video frame processing error',
            details: <Object?, Object?>{
              'domain': 'androidx.media3.transformer.ExportException',
              'codeName': 'ERROR_CODE_VIDEO_FRAME_PROCESSING_FAILED',
              'sources': <Object?>[
                <Object?, Object?>{'mime': 'video/avc', 'transfer': 'sdr'},
              ],
            },
          ),
        );

        expect(
          failure.traceValue,
          'native_render:video_frame_processing_failed',
        );
      });

      test('still classifies a full disk behind an HDR source', () {
        final failure = VideoRenderFailedException.native(
          PlatformException(
            code: 'RENDER_ERROR',
            message: 'Muxer error',
            details: <Object?, Object?>{
              'domain': 'androidx.media3.transformer.ExportException',
              'codeName': 'ERROR_CODE_MUXING_FAILED',
              'sources': <Object?>[
                <Object?, Object?>{'mime': 'video/hevc', 'transfer': 'pq'},
              ],
              'cause': 'java.io.IOException: write failed: ENOSPC',
            },
          ),
        );

        expect(failure.reason, VideoRenderFailureReason.insufficientStorage);
        expect(failure.traceValue, 'insufficient_storage:disk_full:hdr');
      });

      test('marks a stall on an HDR source', () {
        final failure = VideoRenderFailedException.native(
          PlatformException(
            code: 'RENDER_ERROR',
            message:
                'Render export stalled after 20s with no progress '
                '[progress=0.00 format=mp4 bitrate=preset]',
            details: <Object?, Object?>{
              'domain': 'java.lang.IllegalStateException',
              'sources': <Object?>[
                <Object?, Object?>{'mime': 'video/hevc', 'transfer': 'pq'},
              ],
            },
          ),
        );

        expect(failure.traceValue, 'native_render:stalled:hdr');
      });
    });
  });

  group('nativeRenderFailureLabel', () {
    PlatformException renderError(
      String message, {
      Map<String, Object?>? details,
    }) => PlatformException(
      code: 'RENDER_ERROR',
      message: message,
      details: details,
    );

    test("names Apple's stall watchdog by its domain", () {
      expect(
        nativeRenderFailureLabel(
          renderError(
            'Render export stalled after 20s with no progress '
            '[progress=0.00 mode=AVAssetExportPresetHighestQuality '
            'bitrate=preset]',
            details: {'domain': 'ExportWatchdog', 'code': 408},
          ),
        ),
        'stalled',
      );
    });

    test("names Android's stall watchdog by the plugin's own wording", () {
      expect(
        nativeRenderFailureLabel(
          renderError(
            'Render export stalled after 20s with no progress',
            details: {'domain': 'java.lang.IllegalStateException'},
          ),
        ),
        'stalled',
      );
    });

    test('names a Media3 failure by its error code', () {
      expect(
        nativeRenderFailureLabel(
          renderError(
            'Muxer error',
            details: {
              'domain': 'androidx.media3.transformer.ExportException',
              'code': 7001,
              'codeName': 'ERROR_CODE_MUXING_FAILED',
            },
          ),
        ),
        'muxing_failed',
      );
    });

    test('names any other Apple failure by its domain and code', () {
      expect(
        nativeRenderFailureLabel(
          renderError(
            'Cannot Open',
            details: {'domain': 'AVFoundationErrorDomain', 'code': -11828},
          ),
        ),
        'AVFoundationErrorDomain(-11828)',
      );
    });

    test('falls back to the platform code when the plugin attached no '
        'details', () {
      expect(
        nativeRenderFailureLabel(renderError('Unexpected runtime error')),
        'RENDER_ERROR',
      );
      expect(
        nativeRenderFailureLabel(
          PlatformException(
            code: 'TASK_ALREADY_RUNNING',
            message:
                'Task with id 1788376999167349_start_normalized is '
                'already running',
          ),
        ),
        'TASK_ALREADY_RUNNING',
      );
    });

    test('never carries the message', () {
      final label = nativeRenderFailureLabel(
        renderError(
          '/var/mobile/Containers/Data/Application/x/clip.mp4',
          details: {'domain': 'NSCocoaErrorDomain', 'code': 260},
        ),
      );

      expect(label, 'NSCocoaErrorDomain(260)');
      expect(label, isNot(contains('/var/mobile')));
    });

    test('tells a starved codec from an unsupported encoder', () {
      expect(
        nativeRenderFailureLabel(const RenderEncoderException.transient()),
        'codec_exhausted',
      );
      expect(
        nativeRenderFailureLabel(const RenderEncoderException()),
        'encoder_unsupported',
      );
    });

    test('keeps the type of a cause the plugin did not throw', () {
      expect(nativeRenderFailureLabel(StateError('boom')), 'StateError');
    });
  });
}
