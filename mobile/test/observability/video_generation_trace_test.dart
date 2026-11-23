// ABOUTME: Verifies the video_generation trace reports where an export's time
// ABOUTME: went, what came out, which features it used, and how it ended.

import 'dart:async';
import 'dart:io';
import 'dart:ui';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/observability/video_generation_trace.dart';
import 'package:pro_image_editor/pro_image_editor.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

import '../helpers/recording_performance_monitor.dart';

DivineVideoClip _clip({
  double? playbackSpeed,
  bool reversed = false,
  ClipChromaKey? chromaKey,
}) => DivineVideoClip(
  id: 'clip',
  video: EditorVideo.file('/docs/clip.mp4'),
  duration: const Duration(seconds: 2),
  recordedAt: DateTime(2026),
  targetAspectRatio: model.AspectRatio.vertical,
  originalAspectRatio: 9 / 16,
  playbackSpeed: playbackSpeed,
  reversed: reversed,
  chromaKey: chromaKey,
);

DivineVideoClip _stopMotionClip() => DivineVideoClip(
  id: 'stop-motion',
  stopMotionFrames: const [
    StopMotionClipFrame(
      path: '/frames/f0.jpg',
      duration: Duration(milliseconds: 83),
    ),
  ],
  duration: const Duration(milliseconds: 83),
  recordedAt: DateTime(2026),
  targetAspectRatio: model.AspectRatio.vertical,
  originalAspectRatio: 9 / 16,
);

const _noFeatures = {
  'layer_count': 0,
  'has_text': 0,
  'has_filter': 0,
  'has_adjustment': 0,
  'has_effect': 0,
  'has_audio_track': 0,
  'has_speed_change': 0,
  'has_reverse': 0,
  'has_chroma_key': 0,
  'has_stop_motion': 0,
};

void main() {
  group(VideoGenerationTrace, () {
    late RecordingPerformanceMonitor monitor;

    setUp(() => monitor = RecordingPerformanceMonitor());

    RecordedPerformanceTrace onlyTrace() {
      expect(monitor.traces, hasLength(1));
      return monitor.traces.single;
    }

    VideoGenerationTrace startTrace() => VideoGenerationTrace(
      monitor,
      clipCount: 3,
      aspectRatio: 'vertical',
    );

    group('phases', () {
      test('reports a metric only for the steps that ran', () {
        fakeAsync((async) {
          final trace = startTrace();
          trace
            ..time(VideoGenerationPhase.render, () async {
              async.elapse(const Duration(milliseconds: 1200));
            }).ignore()
            ..time(VideoGenerationPhase.proof, () async {
              async.elapse(const Duration(milliseconds: 300));
            }).ignore();
          async.flushMicrotasks();
          trace.finish();

          expect(onlyTrace().metrics, {'render_ms': 1200, 'proof_ms': 300});
        });
      });

      test('sums a step that runs more than once', () {
        fakeAsync((async) {
          final trace = startTrace();
          for (final ms in [400, 250]) {
            trace.time(VideoGenerationPhase.assembly, () async {
              async.elapse(Duration(milliseconds: ms));
            }).ignore();
            async.flushMicrotasks();
          }
          trace.finish();

          expect(onlyTrace().metrics, {'assembly_ms': 650});
        });
      });

      test('reports the time of a step that threw, and rethrows', () {
        fakeAsync((async) {
          final trace = startTrace();
          Object? thrown;
          unawaited(
            trace
                .time<void>(VideoGenerationPhase.render, () async {
                  async.elapse(const Duration(milliseconds: 900));
                  throw StateError('encoder died');
                })
                .catchError((Object e) {
                  thrown = e;
                }),
          );
          async.flushMicrotasks();
          trace.finish();

          expect(thrown, isA<StateError>());
          expect(onlyTrace().metrics, {'render_ms': 900});
        });
      });

      test('returns what the step returned', () async {
        final trace = startTrace();

        final value = await trace.time(
          VideoGenerationPhase.metadata,
          () async => 42,
        );

        expect(value, 42);
      });

      test('drops a step that ends after the trace was reported', () {
        fakeAsync((async) {
          final trace = startTrace();
          trace.time(VideoGenerationPhase.proof, () async {
            async.elapse(const Duration(seconds: 2));
          }).ignore();
          trace.finish();
          async.flushMicrotasks();

          expect(onlyTrace().metrics, isEmpty);
          expect(onlyTrace().stops, 1);
        });
      });
    });

    group('outcome', () {
      test('reports the attributes it was started with and its outcome', () {
        startTrace()
          ..tagOutcome(VideoGenerationOutcome.success)
          ..finish();

        expect(onlyTrace().name, 'video_generation');
        expect(onlyTrace().attributes, {
          'outcome': 'success',
          'clip_count': '3',
          'aspect_ratio': 'vertical',
        });
      });

      test('reports a stale render as stale', () {
        startTrace()
          ..tagOutcome(VideoGenerationOutcome.stale)
          ..finish();

        expect(onlyTrace().attributes['outcome'], 'stale');
      });

      test('carries the failure reason next to the outcome', () {
        startTrace()
          ..tagOutcome(
            VideoGenerationOutcome.failed,
            failureReason: 'native_render:RENDER_ERROR',
          )
          ..finish();

        expect(onlyTrace().attributes, containsPair('outcome', 'failed'));
        expect(
          onlyTrace().attributes,
          containsPair('failure_reason', 'native_render:RENDER_ERROR'),
        );
      });

      test('lets a later outcome replace an earlier one', () {
        startTrace()
          ..tagOutcome(VideoGenerationOutcome.success)
          ..tagOutcome(VideoGenerationOutcome.error, failureReason: 'IOError')
          ..finish();

        expect(onlyTrace().attributes['outcome'], 'error');
        expect(onlyTrace().attributes['failure_reason'], 'IOError');
      });

      test('leaves the aspect ratio out when the render had no clips', () {
        VideoGenerationTrace(monitor, clipCount: 0, aspectRatio: null)
          ..tagOutcome(VideoGenerationOutcome.failed, failureReason: 'empty')
          ..finish();

        expect(onlyTrace().attributes, {
          'outcome': 'failed',
          'failure_reason': 'empty',
          'clip_count': '0',
        });
      });

      test('reports once however often it is finished', () {
        startTrace()
          ..tagOutcome(VideoGenerationOutcome.success)
          ..finish()
          ..tagOutcome(VideoGenerationOutcome.error)
          ..finish();

        expect(onlyTrace().stops, 1);
        expect(onlyTrace().attributes['outcome'], 'success');
      });
    });

    group('output', () {
      test('reports the duration, resolution and size of the video', () {
        startTrace()
          ..recordOutput(
            duration: const Duration(milliseconds: 6300),
            width: 1080,
            height: 1920,
            bytes: 4096,
          )
          ..finish();

        expect(onlyTrace().metrics, {
          'output_duration_ms': 6300,
          'output_width': 1080,
          'output_height': 1920,
          'output_bytes': 4096,
        });
      });

      test('leaves the size out when it could not be read', () {
        startTrace()
          ..recordOutput(
            duration: const Duration(seconds: 6),
            width: 1080,
            height: 1080,
          )
          ..finish();

        expect(onlyTrace().metrics, isNot(contains('output_bytes')));
        expect(onlyTrace().metrics['output_width'], 1080);
      });

      group('recordOutputOf', () {
        late Directory dir;

        setUp(() => dir = Directory.systemTemp.createTempSync('video_gen'));
        tearDown(() => dir.deleteSync(recursive: true));

        VideoMetadata metadata() => VideoMetadata(
          duration: const Duration(milliseconds: 5900),
          extension: 'mp4',
          fileSize: 1,
          resolution: const Size(1080, 1920),
          rotation: 0,
          bitrate: 1000,
        );

        test('reads the size from the file, not the metadata', () async {
          final file = File('${dir.path}/out.mp4')
            ..writeAsBytesSync(List.filled(2048, 0));
          final trace = startTrace();

          await trace.recordOutputOf(file.path, metadata());
          trace.finish();

          expect(onlyTrace().metrics, {
            'output_duration_ms': 5900,
            'output_width': 1080,
            'output_height': 1920,
            'output_bytes': 2048,
          });
        });

        test('reports the rest when the file is gone', () async {
          final trace = startTrace();

          await trace.recordOutputOf('${dir.path}/missing.mp4', metadata());
          trace.finish();

          expect(onlyTrace().metrics, isNot(contains('output_bytes')));
          expect(onlyTrace().metrics['output_duration_ms'], 5900);
        });
      });
    });

    group('features', () {
      test('reports each feature as a 0/1 metric', () {
        startTrace()
          ..recordFeatures(
            () => VideoGenerationFeatures.of(
              clips: [_clip(playbackSpeed: 2)],
              parameters: CompleteParameters.fromMap(const {}).copyWith(
                layers: [
                  TextLayer(text: 'Hi'),
                  EmojiLayer(emoji: '🎬'),
                ],
              ),
            ),
          )
          ..finish();

        expect(onlyTrace().metrics, {
          ..._noFeatures,
          'layer_count': 2,
          'has_text': 1,
          'has_speed_change': 1,
        });
      });

      test('leaves the features out when reading them throws', () {
        final trace = startTrace();

        expect(
          () => trace.recordFeatures(() => throw StateError('bad meta')),
          returnsNormally,
        );
        trace.finish();

        expect(onlyTrace().metrics, isEmpty);
      });
    });
  });

  group(VideoGenerationFeatures, () {
    Map<String, int> metricsOf({
      List<DivineVideoClip>? clips,
      CompleteParameters? parameters,
    }) => VideoGenerationFeatures.of(
      clips: clips ?? [_clip()],
      parameters: parameters,
    ).metrics;

    CompleteParameters params() => CompleteParameters.fromMap(const {});

    test('reports no feature for a plain clip without parameters', () {
      expect(metricsOf(), _noFeatures);
    });

    test('reports no feature for a plain clip with empty parameters', () {
      expect(metricsOf(parameters: params()), _noFeatures);
    });

    test('sees a filter look', () {
      final metrics = metricsOf(
        parameters: params().copyWith(
          filterStates: [
            FilterState(
              id: 'look',
              name: 'look',
              matrices: const [
                [1.0],
              ],
            ),
          ],
        ),
      );

      expect(metrics['has_filter'], 1);
      expect(metrics['has_adjustment'], 0);
    });

    test('sees an Adjust setting', () {
      final metrics = metricsOf(
        parameters: params().copyWith(
          tuneAdjustments: [
            TuneAdjustmentMatrix(id: 'brightness', value: 1, matrix: const [1]),
          ],
        ),
      );

      expect(metrics['has_adjustment'], 1);
      expect(metrics['has_filter'], 0);
    });

    test('sees a video effect', () {
      final metrics = metricsOf(
        parameters: params().copyWith(
          meta: {
            VideoEditorConstants.effectsStateHistoryKey: [
              const VideoEffect.strobe().toMap(),
            ],
          },
        ),
      );

      expect(metrics['has_effect'], 1);
    });

    test('sees a sound under the video', () {
      final metrics = metricsOf(
        parameters: params().copyWith(
          audioTracks: [
            AudioTrack(
              id: 'sound',
              title: 'sound',
              subtitle: 'artist',
              duration: const Duration(seconds: 6),
              audio: EditorAudio.asset('sound.mp3'),
            ),
          ],
        ),
      );

      expect(metrics['has_audio_track'], 1);
    });

    test('sees a reversed clip', () {
      expect(metricsOf(clips: [_clip(reversed: true)])['has_reverse'], 1);
    });

    test('does not count normal speed as a speed change', () {
      expect(
        metricsOf(clips: [_clip(playbackSpeed: 1)])['has_speed_change'],
        0,
      );
    });

    test('sees a keyed clip', () {
      final metrics = metricsOf(
        clips: [
          _clip(),
          _clip(chromaKey: const ClipChromaKey(key: ChromaKey.greenScreen())),
        ],
      );

      expect(metrics['has_chroma_key'], 1);
    });

    test('sees a stop-motion clip', () {
      expect(
        metricsOf(clips: [_clip(), _stopMotionClip()])['has_stop_motion'],
        1,
      );
    });
  });
}
