import 'dart:async';
import 'dart:math' as math;
import 'dart:typed_data';
import 'dart:ui';

import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:loop_alignment_repository/loop_alignment_repository.dart';
import 'package:openvine/services/video_editor/native_loop_alignment_client.dart';
import 'package:openvine/services/video_editor/video_render_failures.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group('NativeLoopAlignmentClient', () {
    test(
      'portrait offsets use independent dimensions and crop exactly once',
      () {
        final plan = LoopClipPlan(
          clipId: 'a',
          sourceStart: Duration.zero,
          sourceEnd: const Duration(seconds: 1),
          keyframes: [
            const LoopKeyframe(
              sourceTime: Duration(milliseconds: 517),
              correction: LoopPose(a: 1, b: 0, tx: 2, ty: 3),
            ),
          ],
        );
        final native = NativeLoopAlignmentClient.stabilizationFor(
          plan,
          1.04,
          180,
          320,
        );
        expect(native.keyframes.single.time, const Duration(milliseconds: 517));
        expect(
          native.keyframes.single.offset.dx,
          closeTo(2 * 1.04 / 180, 1e-12),
        );
        expect(
          native.keyframes.single.offset.dy,
          closeTo(3 * 1.04 / 320, 1e-12),
        );
        expect(native.keyframes.single.scale, 1.04);
      },
    );
    test('bounded portrait decode uses actual irregular timestamps', () async {
      final backend = FakeBackend();
      final client = NativeLoopAlignmentClient(backend: backend);
      final analysis = await client.analyze(
        input(),
        const LoopAlignmentLimits(),
        'a',
        (_) {},
      );
      expect(analysis.alreadySmooth, isFalse);
      expect(analysis.eligibleTrimEnds, backend.times);
      expect(backend.configs.single.outputSize, const Size(320, 320));
      expect(backend.configs.single.maxParallelDecoders, 1);
      expect(backend.configs.single.startTime, const Duration(seconds: 50));
      expect(backend.configs.single.endTime, const Duration(seconds: 51));
      await client.finish('a');
    });
    test('nonmonotonic PTS fails rather than assuming a frame rate', () async {
      final backend = FakeBackend()
        ..times = [const Duration(seconds: 50), const Duration(seconds: 50)];
      final client = NativeLoopAlignmentClient(backend: backend);
      await expectLater(
        client.analyze(input(), const LoopAlignmentLimits(), 'a', (_) {}),
        throwsA(isA<LoopAlignmentFailure>()),
      );
      await client.finish('a');
    });
    test('malformed dimensions fail before worker', () async {
      final backend = FakeBackend()..badSize = true;
      final client = NativeLoopAlignmentClient(backend: backend);
      await expectLater(
        client.analyze(input(), const LoopAlignmentLimits(), 'a', (_) {}),
        throwsA(isA<LoopAlignmentFailure>()),
      );
      await client.finish('a');
    });
    test(
      'cancellation during metadata blocks decode; next operation independent',
      () async {
        final backend = FakeBackend()
          ..metadataGate = Completer<VideoMetadata>();
        final client = NativeLoopAlignmentClient(backend: backend);
        final pending = client.analyze(
          input(),
          const LoopAlignmentLimits(),
          'a',
          (_) {},
        );
        final assertion = expectLater(
          pending,
          throwsA(isA<LoopAlignmentCancelled>()),
        );
        await client.cancel('a');
        backend.metadataGate!.complete(metadata());
        await assertion;
        expect(backend.configs, isEmpty);
        await client.finish('a');
        backend.metadataGate = null;
        await client.analyze(input(), const LoopAlignmentLimits(), 'a', (_) {});
        expect(backend.configs.length, 1);
        await client.finish('a');
      },
    );
    test(
      'render bakes at native speed one with full source PTS and audio default',
      () async {
        final backend = FakeBackend();
        final client = NativeLoopAlignmentClient(backend: backend);
        await client.analyze(input(), const LoopAlignmentLimits(), 'a', (_) {});
        final output = await client.render(input(), repairPlan(), 'a', (_) {});
        final segment = backend.renders.single.videoSegments!.single;
        expect(segment.startTime, const Duration(seconds: 50));
        expect(segment.endTime, const Duration(seconds: 51));
        expect(backend.renders.single.maxFrameRate, isNull);
        expect(segment.playbackSpeed, isNull);
        expect(segment.reverseVideo, isFalse);
        expect(segment.volume, isNull);
        expect(
          segment.stabilization!.keyframes.first.time,
          const Duration(seconds: 50),
        );
        await client.discard(output);
        expect(backend.files, isEmpty);
        expect(backend.deleted, isNot(contains('/source.mp4')));
        await client.finish('a');
      },
    );
    test('disk-full partial render is deleted and source survives', () async {
      final backend = FakeBackend()..renderFails = true;
      final client = NativeLoopAlignmentClient(backend: backend);
      await client.analyze(input(), const LoopAlignmentLimits(), 'a', (_) {});
      await expectLater(
        client.render(input(), repairPlan(), 'a', (_) {}),
        throwsA(isA<StateError>()),
      );
      expect(backend.files, isEmpty);
      expect(backend.deleted, isNot(contains('/source.mp4')));
      await client.finish('a');
    });
    test(
      'late canceled render completion deletes its newly written output',
      () async {
        final backend = FakeBackend()..renderGate = Completer<void>();
        final client = NativeLoopAlignmentClient(backend: backend);
        await client.analyze(input(), const LoopAlignmentLimits(), 'a', (_) {});
        final pending = client.render(input(), repairPlan(), 'a', (_) {});
        final assertion = expectLater(
          pending,
          throwsA(isA<LoopAlignmentCancelled>()),
        );
        await backend.renderStarted.future;
        await client.cancel('a');
        await assertion;
        await client.finish('a');
        backend.renderGate!.complete();
        await pumpEventQueue();
        expect(backend.files, isEmpty);
        expect(backend.deleted.length, greaterThanOrEqualTo(2));
      },
    );
    test(
      'inspection uses actual native pixels timestamps and audio metadata',
      () async {
        final backend = FakeBackend()..texture = true;
        final client = NativeLoopAlignmentClient(backend: backend);
        await client.analyze(input(), const LoopAlignmentLimits(), 'a', (_) {});
        final output = await client.render(input(), repairPlan(), 'a', (_) {});
        final proof = await client.inspect(input(), repairPlan(), output, 'a');
        expect(proof.covered, isTrue);
        expect(proof.metadata['a']!.frameTimes.length, backend.times.length);
        expect(proof.audioDuration, const Duration(seconds: 1));
        backend.dropOutput = true;
        final dropped = await client.inspect(
          input(),
          repairPlan(),
          output,
          'a',
        );
        expect(dropped.covered, isFalse);
        backend.dropOutput = false;
        backend.loseAudio = true;
        final silent = await client.inspect(input(), repairPlan(), output, 'a');
        expect(silent.covered, isFalse);
        await client.discard(output);
        await client.finish('a');
      },
    );
    test(
      'iOS 30fps output accepts the same 29.97fps source pictures',
      () async {
        const length = Duration(milliseconds: 6300);
        final backend = FakeBackend()
          ..texture = true
          ..outputDuration = length
          ..sourceFrameRate = 30000 / 1001
          ..outputFrameRate = 30
          ..times = [
            for (var i = 0; i < 189; i++)
              Duration(microseconds: 50000000 + (i * 1001000 / 30).round()),
          ]
          ..outputTimes = [
            for (var i = 0; i < 189; i++)
              Duration(microseconds: 50000000 + (i * 1000000 / 30).round()),
          ];
        final request = input(duration: length);
        final plan = repairPlan(duration: length);
        final client = NativeLoopAlignmentClient(backend: backend);
        await client.analyze(
          request,
          const LoopAlignmentLimits(),
          'cadence',
          (_) {},
        );
        final output = await client.render(request, plan, 'cadence', (_) {});
        final proof = await client.inspect(request, plan, output, 'cadence');
        expect(proof.covered, isTrue);
        final regularOutput = backend.outputTimes!;
        backend.outputTimes = [
          for (var i = 0; i < regularOutput.length; i++)
            regularOutput[i] + Duration(milliseconds: i == 90 ? 10 : 0),
        ];
        final jittered = await client.inspect(request, plan, output, 'cadence');
        expect(jittered.covered, isFalse);
        backend.outputTimes = regularOutput;
        backend.outputFrameRate = null;
        final unknownClock = await client.inspect(
          request,
          plan,
          output,
          'cadence',
        );
        expect(unknownClock.covered, isFalse);
        backend.outputFrameRate = 30;
        backend.outputTimes = [
          for (var i = 0; i < 189; i++)
            Duration(
              microseconds:
                  50000000 + (i * 1000000 / 30).round() + (i == 0 ? 0 : 33000),
            ),
        ];
        final shifted = await client.inspect(request, plan, output, 'cadence');
        expect(shifted.covered, isFalse);
        await client.discard(output);
        await client.finish('cadence');
      },
    );

    group('the native clock exception keeps the other timing checks', () {
      const length = Duration(milliseconds: 6300);
      List<Duration> clock(double fps, {Duration offset = Duration.zero}) => [
        for (var i = 0; i < 189; i++)
          Duration(microseconds: 50000000 + (i * 1000000 / fps).round()) +
              offset,
      ];
      Future<bool> covered({
        required double sourceFps,
        required double outputFps,
        required List<Duration> times,
        required List<Duration> outputTimes,
      }) async {
        final backend = FakeBackend()
          ..texture = true
          ..outputDuration = length
          ..sourceFrameRate = sourceFps
          ..outputFrameRate = outputFps
          ..times = times
          ..outputTimes = outputTimes;
        final request = input(duration: length);
        final plan = repairPlan(duration: length);
        final client = NativeLoopAlignmentClient(backend: backend);
        await client.analyze(request, const LoopAlignmentLimits(), 'c', (_) {});
        final output = await client.render(request, plan, 'c', (_) {});
        final proof = await client.inspect(request, plan, output, 'c');
        await client.discard(output);
        await client.finish('c');
        return proof.covered;
      }

      test('rejects a 3ms same-rate gap that stays near both clocks', () async {
        final times = clock(30);
        final outputTimes = clock(30);
        times[90] -= const Duration(microseconds: 1500);
        outputTimes[90] += const Duration(microseconds: 1500);
        expect(
          await covered(
            sourceFps: 30,
            outputFps: 30,
            times: times,
            outputTimes: outputTimes,
          ),
          isFalse,
        );
      });

      test('rejects drift toward an output clock iOS does not use', () async {
        expect(
          await covered(
            sourceFps: 30,
            outputFps: 30000 / 1001,
            times: clock(30),
            outputTimes: clock(30000 / 1001),
          ),
          isFalse,
        );
      });

      test('rejects a source picture off its own clock', () async {
        final times = clock(30000 / 1001);
        times[90] += const Duration(milliseconds: 10);
        expect(
          await covered(
            sourceFps: 30000 / 1001,
            outputFps: 30,
            times: times,
            outputTimes: clock(30),
          ),
          isFalse,
        );
      });

      test('falls back to the strict check for a non-finite rate', () async {
        expect(
          await covered(
            sourceFps: double.nan,
            outputFps: 30,
            times: clock(30000 / 1001),
            outputTimes: clock(30),
          ),
          isFalse,
        );
      });

      test('rejects an output one picture short', () async {
        expect(
          await covered(
            sourceFps: 30000 / 1001,
            outputFps: 30,
            times: clock(30000 / 1001),
            outputTimes: clock(30).take(188).toList(),
          ),
          isFalse,
        );
      });

      test('keeps the first picture within 2ms of the cut', () async {
        expect(
          await covered(
            sourceFps: 30000 / 1001,
            outputFps: 30,
            times: clock(
              30000 / 1001,
              offset: const Duration(milliseconds: 10),
            ),
            outputTimes: clock(30),
          ),
          isFalse,
        );
      });
    });

    test('same-rate middle-frame jitter is still rejected', () async {
      final backend = FakeBackend()
        ..texture = true
        ..sourceFrameRate = 30
        ..outputFrameRate = 30
        ..times = [
          for (var i = 0; i < 30; i++)
            Duration(microseconds: 50000000 + (i * 1000000 / 30).round()),
        ];
      backend.outputTimes = [
        for (var i = 0; i < backend.times.length; i++)
          backend.times[i] + Duration(milliseconds: i == 15 ? 10 : 0),
      ];
      final client = NativeLoopAlignmentClient(backend: backend);
      await client.analyze(
        input(),
        const LoopAlignmentLimits(),
        'jitter',
        (_) {},
      );
      final output = await client.render(
        input(),
        repairPlan(),
        'jitter',
        (_) {},
      );
      final proof = await client.inspect(
        input(),
        repairPlan(),
        output,
        'jitter',
      );
      expect(proof.covered, isFalse);
      await client.discard(output);
      await client.finish('jitter');
    });

    test(
      'watchdog cancels a stuck metadata call and ignores its late result',
      () {
        fakeAsync((clock) {
          final backend = FakeBackend()
            ..metadataGate = Completer<VideoMetadata>();
          final client = NativeLoopAlignmentClient(
            backend: backend,
            watchdogTimeout: const Duration(milliseconds: 10),
          );
          Object? failure;
          unawaited(
            client
                .analyze(input(), const LoopAlignmentLimits(), 'a', (_) {})
                .then<void>(
                  (_) => fail('A stalled metadata call must time out'),
                  onError: (Object error) {
                    failure = error;
                  },
                ),
          );
          clock.flushMicrotasks();
          clock.elapse(const Duration(milliseconds: 10));
          clock.flushMicrotasks();
          expect(failure, isA<VideoRenderFailedException>());
          backend.metadataGate!.complete(metadata());
          clock.flushMicrotasks();
          expect(backend.configs, isEmpty);
          unawaited(client.finish('a'));
          clock.flushMicrotasks();
        });
      },
    );

    test(
      'montage applies common crop to every clip and correction only to final',
      () async {
        final backend = FakeBackend();
        final client = NativeLoopAlignmentClient(backend: backend);
        final composition = LoopRepairInput(
          clips: [
            input().clips.single,
            const LoopClipInput(
              clipId: 'b',
              path: '/second.mp4',
              sourceStart: Duration(seconds: 50),
              sourceEnd: Duration(seconds: 51),
              speed: 1,
              width: 180,
              height: 320,
            ),
          ],
          revision: 'b',
        );
        final base = repairPlan();
        final plan = LoopAlignmentPlan(
          clips: [
            base.clips.single,
            LoopClipPlan(
              clipId: 'b',
              sourceStart: const Duration(seconds: 50),
              sourceEnd: const Duration(seconds: 51),
              keyframes: [
                const LoopKeyframe(
                  sourceTime: Duration(seconds: 50),
                  correction: LoopPose.identity,
                ),
                const LoopKeyframe(
                  sourceTime: Duration(seconds: 51),
                  correction: LoopPose(a: 1, b: 0, tx: 2, ty: 0),
                ),
              ],
            ),
          ],
          zoom: base.zoom,
          confidence: base.confidence,
          predictedScores: base.predictedScores,
          baselineScores: base.baselineScores,
        );
        await client.analyze(
          composition,
          const LoopAlignmentLimits(),
          'b',
          (_) {},
        );
        final output = await client.render(composition, plan, 'b', (_) {});
        expect(backend.renders.length, 2);
        final first =
            backend.renders.first.videoSegments!.single.stabilization!;
        final last = backend.renders.last.videoSegments!.single.stabilization!;
        expect(first.keyframes.last.offset, Offset.zero);
        expect(last.keyframes.last.offset.dx, closeTo(2 * 1.02 / 180, 1e-12));
        expect(first.keyframes.last.scale, 1.02);
        expect(last.keyframes.last.scale, 1.02);
        await client.discard(output);
        await client.finish('b');
      },
    );
  });
}

LoopRepairInput input({Duration duration = const Duration(seconds: 1)}) =>
    LoopRepairInput(
      clips: [
        LoopClipInput(
          clipId: 'a',
          path: '/source.mp4',
          sourceStart: const Duration(seconds: 50),
          sourceEnd: const Duration(seconds: 50) + duration,
          speed: 1,
          width: 180,
          height: 320,
        ),
      ],
      revision: 'a',
    );
VideoMetadata metadata() => VideoMetadata(
  duration: const Duration(seconds: 60),
  extension: 'mp4',
  fileSize: 1,
  resolution: const Size(180, 320),
  rotation: 0,
  bitrate: 100,
);

class FakeBackend implements LoopNativeBackend {
  final configs = <LumaFrameConfigs>[];
  List<Duration> times = [
    for (final ms in [50000, 50017, 50034, 50052, 50070, 50087])
      Duration(milliseconds: ms),
  ];
  double? sourceFrameRate;
  double? outputFrameRate;
  List<Duration>? outputTimes;
  Duration outputDuration = const Duration(seconds: 1);
  bool badSize = false;
  bool renderFails = false;
  bool texture = false;
  bool dropOutput = false;
  bool loseAudio = false;
  Completer<void>? renderGate;
  final renders = <VideoRenderData>[];
  final renderStarted = Completer<void>();
  final files = <String>{};
  final deleted = <String>[];
  Completer<VideoMetadata>? metadataGate;
  @override
  Stream<LumaFrame> decode(LumaFrameConfigs c) async* {
    configs.add(c);
    final output = c.video.file?.path.startsWith('/output/') ?? false;
    final pixels = Uint8List(badSize ? 1 : 180 * 320);
    if (texture && !badSize) {
      for (var y = 0; y < 320; y++) {
        for (var x = 0; x < 180; x++) {
          pixels[y * 180 + x] =
              (100 +
                      26 * math.sin(x * .43 + y * .11) +
                      23 * math.cos(y * .37 - x * .09) +
                      21 * math.sin(x * .17 + y * .23) +
                      17 * math.cos(x * .61 - y * .41))
                  .round()
                  .clamp(0, 255);
        }
      }
    }
    final bytes = texture && output
        ? const LoopFrameResampler()
              .warp(
                LoopFrame(
                  time: Duration.zero,
                  width: 180,
                  height: 320,
                  luma: pixels,
                ),
                LoopPose.identity,
                1.02,
                longestEdge: 320,
              )
              .luma
        : pixels;
    for (final time
        in (output
            ? (dropOutput
                  ? (outputTimes ?? times).take(
                      (outputTimes ?? times).length - 1,
                    )
                  : outputTimes ?? times)
            : times)) {
      yield LumaFrame(
        time: output ? time - const Duration(seconds: 50) : time,
        width: 180,
        height: 320,
        bytes: bytes,
        progress: 0,
      );
    }
  }

  @override
  Future<VideoMetadata> metadata(String path) async => metadataGate == null
      ? nativeMetadata(output: path.startsWith('/output/'))
      : await metadataGate!.future;
  VideoMetadata nativeMetadata({bool output = false}) => VideoMetadata(
    frameRate: output ? outputFrameRate : sourceFrameRate,
    duration: output ? outputDuration : const Duration(seconds: 60),
    audioDuration: output && loseAudio
        ? null
        : output
        ? outputDuration
        : const Duration(seconds: 60),
    extension: 'mp4',
    fileSize: 1,
    resolution: const Size(180, 320),
    rotation: 0,
    bitrate: 100,
  );
  @override
  Future<void> render(String path, VideoRenderData d) async {
    renders.add(d);
    if (!renderStarted.isCompleted) renderStarted.complete();
    if (renderGate != null) await renderGate!.future;
    files.add(path);
    if (renderFails) throw StateError('disk full');
  }

  @override
  Future<void> cancel(String id) async {}
  @override
  Future<String> outputPath(String namespace, int index) async =>
      '/output/$namespace-$index.mp4';
  @override
  Future<void> delete(String path) async {
    deleted.add(path);
    files.remove(path);
  }
}

LoopAlignmentPlan repairPlan({
  Duration duration = const Duration(seconds: 1),
}) => LoopAlignmentPlan(
  clips: [
    LoopClipPlan(
      clipId: 'a',
      sourceStart: const Duration(seconds: 50),
      sourceEnd: const Duration(seconds: 50) + duration,
      keyframes: [
        const LoopKeyframe(
          sourceTime: Duration(seconds: 50),
          correction: LoopPose.identity,
        ),
        const LoopKeyframe(
          sourceTime: Duration(seconds: 51),
          correction: LoopPose.identity,
        ),
      ],
    ),
  ],
  zoom: 1.02,
  confidence: const LoopFrameMatch(
    pose: LoopPose.identity,
    consistentCount: 20,
    retainedCount: 20,
    occupiedCells: 4,
    widthSpan: .5,
    heightSpan: .5,
    withheldCount: 5,
    withheldMedianError: 0,
    left: LoopBoundarySupport(agreeing: 4, retained: 4),
    right: LoopBoundarySupport(agreeing: 4, retained: 4),
    top: LoopBoundarySupport(agreeing: 0, retained: 0),
    bottom: LoopBoundarySupport(agreeing: 0, retained: 0),
  ),
  predictedScores: const LoopSeamScores(difference: 0, motion: 0),
  baselineScores: const LoopSeamScores(difference: .05, motion: 0),
);
