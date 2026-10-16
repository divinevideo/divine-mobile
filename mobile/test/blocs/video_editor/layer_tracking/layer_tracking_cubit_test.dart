import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/layer_tracking/layer_tracking_cubit.dart';
import 'package:openvine/models/video_editor/layer_track_target.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:openvine/services/video_editor/layer_tracking_service.dart';
import 'package:openvine/services/video_editor/video_render_failures.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  final target = LayerTrackTarget(
    clipId: 'clip',
    video: EditorVideo.file('/tmp/clip.mp4'),
    clipStart: Duration.zero,
    trimStart: Duration.zero,
    speed: 1,
    start: Duration.zero,
    end: const Duration(seconds: 2),
    anchor: const Duration(seconds: 1),
    videoAspectRatio: 9 / 16,
    targetAspectRatio: 9 / 16,
  );
  const region = Rect.fromLTWH(0.4, 0.4, 0.2, 0.2);

  ObjectTrackSample sample(int ms) => ObjectTrackSample(
    time: Duration(milliseconds: ms),
    center: const Offset(0.5, 0.5),
    size: const Size(0.2, 0.2),
  );

  final followed = VideoObjectTrack(
    anchorTime: const Duration(seconds: 1),
    samples: [sample(967), sample(1000), sample(1033)],
  );
  final notFollowed = VideoObjectTrack(
    anchorTime: const Duration(seconds: 1),
    samples: [sample(1000)],
  );

  /// Tracks by handing back [result] after reporting [progress].
  TrackLayerObjectFn tracker(
    FutureOr<VideoObjectTrack> Function() result, {
    List<String>? taskIds,
    List<double> progress = const [],
  }) =>
      ({
        required target,
        required region,
        required taskId,
        onProgress,
      }) async {
        taskIds?.add(taskId);
        progress.forEach(onProgress!.call);
        return result();
      };

  group(LayerTrackingCubit, () {
    test('starts idle', () {
      expect(LayerTrackingCubit().state, const LayerTrackingState());
    });

    group('track', () {
      final taskIds = <String>[];
      setUp(taskIds.clear);

      blocTest<LayerTrackingCubit, LayerTrackingState>(
        'reports its progress, then the path of the object',
        build: () => LayerTrackingCubit(
          trackObject: tracker(
            () => followed,
            taskIds: taskIds,
            progress: const [0.5],
          ),
        ),
        act: (cubit) =>
            cubit.track(layerId: 'layer', target: target, region: region),
        expect: () => [
          LayerTrackingState(
            status: LayerTrackingStatus.tracking,
            layerId: 'layer',
            target: target,
          ),
          LayerTrackingState(
            status: LayerTrackingStatus.tracking,
            progress: 0.5,
            layerId: 'layer',
            target: target,
          ),
          LayerTrackingState(
            status: LayerTrackingStatus.followed,
            progress: 1,
            layerId: 'layer',
            target: target,
            track: followed,
          ),
        ],
        verify: (_) =>
            expect(taskIds, [LayerTrackingService.taskIdFor('layer')]),
      );

      blocTest<LayerTrackingCubit, LayerTrackingState>(
        'says when the region could not be followed past its frame',
        build: () =>
            LayerTrackingCubit(trackObject: tracker(() => notFollowed)),
        act: (cubit) =>
            cubit.track(layerId: 'layer', target: target, region: region),
        skip: 1,
        expect: () => [
          isA<LayerTrackingState>()
              .having(
                (s) => s.status,
                'status',
                LayerTrackingStatus.notFollowed,
              )
              .having((s) => s.track, 'track', notFollowed),
        ],
      );

      blocTest<LayerTrackingCubit, LayerTrackingState>(
        'goes back to idle when cancelled',
        build: () => LayerTrackingCubit(
          trackObject: tracker(() => throw const RenderCanceledException()),
        ),
        act: (cubit) =>
            cubit.track(layerId: 'layer', target: target, region: region),
        skip: 1,
        expect: () => [const LayerTrackingState()],
        errors: () => isEmpty,
      );

      blocTest<LayerTrackingCubit, LayerTrackingState>(
        'fails without reporting a clip it cannot read',
        build: () => LayerTrackingCubit(
          trackObject: tracker(
            () => throw PlatformException(code: 'FRAME_STREAM_ERROR'),
          ),
        ),
        act: (cubit) =>
            cubit.track(layerId: 'layer', target: target, region: region),
        skip: 1,
        expect: () => [
          const LayerTrackingState(
            status: LayerTrackingStatus.failed,
            layerId: 'layer',
          ),
        ],
        errors: () => [isA<PlatformException>()],
      );

      blocTest<LayerTrackingCubit, LayerTrackingState>(
        'fails without reporting again a track the watchdog ended',
        build: () => LayerTrackingCubit(
          trackObject: tracker(
            () => throw const VideoRenderFailedException(
              VideoRenderFailureReason.timedOut,
            ),
          ),
        ),
        act: (cubit) =>
            cubit.track(layerId: 'layer', target: target, region: region),
        skip: 1,
        expect: () => [
          const LayerTrackingState(
            status: LayerTrackingStatus.failed,
            layerId: 'layer',
          ),
        ],
        errors: () => [isA<VideoRenderFailedException>()],
      );

      blocTest<LayerTrackingCubit, LayerTrackingState>(
        'reports a failure of its own',
        build: () => LayerTrackingCubit(
          trackObject: tracker(() => throw StateError('worker died')),
        ),
        act: (cubit) =>
            cubit.track(layerId: 'layer', target: target, region: region),
        skip: 1,
        expect: () => [
          const LayerTrackingState(
            status: LayerTrackingStatus.failed,
            layerId: 'layer',
          ),
        ],
        errors: () => [
          isA<Reportable<Object>>().having(
            (r) => r.unwrap(),
            'unwrap',
            isA<StateError>(),
          ),
        ],
      );

      test('ignores a second track while one runs', () async {
        final pending = Completer<VideoObjectTrack>();
        var calls = 0;
        final cubit = LayerTrackingCubit(
          trackObject: tracker(() {
            calls++;
            return pending.future;
          }),
        );
        addTearDown(cubit.close);
        final first = cubit.track(
          layerId: 'a',
          target: target,
          region: region,
        );
        await cubit.track(layerId: 'b', target: target, region: region);
        expect(calls, 1);
        expect(cubit.state.layerId, 'a');
        pending.complete(followed);
        await first;
        expect(cubit.state.status, LayerTrackingStatus.followed);
      });
    });

    group('cancel', () {
      test('stops the track that runs', () async {
        final pending = Completer<VideoObjectTrack>();
        final cancelled = <String>[];
        final cubit = LayerTrackingCubit(
          trackObject: tracker(() => pending.future),
          cancelTracking: (taskId) async {
            cancelled.add(taskId);
            pending.completeError(const RenderCanceledException());
          },
        );
        addTearDown(cubit.close);
        final running = cubit.track(
          layerId: 'layer',
          target: target,
          region: region,
        );
        await pumpEventQueue();
        await cubit.cancel();
        await running;
        expect(cancelled, [LayerTrackingService.taskIdFor('layer')]);
        expect(cubit.state, const LayerTrackingState());
      });

      test('does nothing while nothing runs', () async {
        final cancelled = <String>[];
        final cubit = LayerTrackingCubit(
          cancelTracking: (taskId) async => cancelled.add(taskId),
        );
        addTearDown(cubit.close);
        await cubit.cancel();
        expect(cancelled, isEmpty);
      });

      test('runs when the cubit closes mid-track', () async {
        final pending = Completer<VideoObjectTrack>();
        final cancelled = <String>[];
        final cubit = LayerTrackingCubit(
          trackObject: tracker(() => pending.future),
          cancelTracking: (taskId) async => cancelled.add(taskId),
        );
        unawaited(
          cubit.track(layerId: 'layer', target: target, region: region),
        );
        await pumpEventQueue();
        await cubit.close();
        expect(cancelled, [LayerTrackingService.taskIdFor('layer')]);
        // The result arriving after the close changes nothing.
        pending.complete(followed);
        await pumpEventQueue();
        expect(cubit.state.isTracking, isTrue);
      });
    });

    group('resultHandled', () {
      blocTest<LayerTrackingCubit, LayerTrackingState>(
        'forgets a result once the editor applied it',
        build: () => LayerTrackingCubit(trackObject: tracker(() => followed)),
        act: (cubit) async {
          await cubit.track(layerId: 'layer', target: target, region: region);
          cubit.resultHandled();
        },
        skip: 2,
        expect: () => [const LayerTrackingState()],
      );

      blocTest<LayerTrackingCubit, LayerTrackingState>(
        'leaves a running track alone',
        build: () => LayerTrackingCubit(
          trackObject: tracker(() => Completer<VideoObjectTrack>().future),
        ),
        act: (cubit) async {
          unawaited(
            cubit.track(layerId: 'layer', target: target, region: region),
          );
          await pumpEventQueue();
          cubit.resultHandled();
        },
        expect: () => [
          isA<LayerTrackingState>().having(
            (s) => s.isTracking,
            'isTracking',
            isTrue,
          ),
        ],
      );
    });
  });
}
