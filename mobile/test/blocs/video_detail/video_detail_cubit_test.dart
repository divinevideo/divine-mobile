// ABOUTME: Tests VideoDetailCubit's load telemetry: a link's lookup is timed
// ABOUTME: until the video, its hidden notice or the load error shows.

import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_detail/video_detail_cubit.dart';
import 'package:openvine/observability/screen_load_telemetry.dart';
import 'package:videos_repository/videos_repository.dart';

import '../../helpers/screen_load_recorder.dart';
import '../../helpers/test_pubkeys.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

const _routeId =
    'f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2d3c4b5a6f1e2';

final _video = VideoEvent(
  id: _routeId,
  pubkey: testPubkeyFromSeed(1),
  createdAt: 1700000000,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1700000000 * 1000),
  videoUrl: 'https://example.com/video.mp4',
);

void main() {
  group(VideoDetailCubit, () {
    group('load telemetry', () {
      late _MockVideosRepository repository;
      late ScreenLoadRecorder recorder;

      setUp(() {
        repository = _MockVideosRepository();
        recorder = ScreenLoadRecorder();
      });

      VideoDetailCubit createCubit() => VideoDetailCubit(
        videosRepository: () => repository,
        isRelayReady: () => true,
        relayReadyStream: () => const Stream<bool>.empty(),
        loadTelemetry: recorder.telemetry(AnalyticsSurface.videoDetail),
      );

      void stubLookup(Future<VideoRouteLookupResult> Function() answer) {
        when(
          () => repository.lookupVideoForRouteId(
            any(),
            fallbackRouteIds: any(named: 'fallbackRouteIds'),
            expectedAuthor: any(named: 'expectedAuthor'),
          ),
        ).thenAnswer((_) => answer());
      }

      Future<VideoDetailCubit> openLink() async {
        final cubit = createCubit()..search(routeId: _routeId);
        addTearDown(cubit.close);
        await pumpEventQueue();
        return cubit;
      }

      test('completes when the linked video is found', () async {
        stubLookup(() async => VideoRouteFound(_video));

        final cubit = await openLink();

        expect(cubit.state.status, VideoDetailStatus.ready);
        expect(recorder.results, [SurfaceLoadResult.success]);
        expect(
          recorder.loads.single,
          containsPair(AnalyticsParam.entryPoint, ScreenLoadEntryPoint.link),
        );
      });

      test('reports empty when the viewer settings hide the video', () async {
        stubLookup(() async => VideoRouteHiddenByFilter(_video));

        final cubit = await openLink();

        expect(cubit.state.status, VideoDetailStatus.hiddenBySettings);
        expect(recorder.results, [SurfaceLoadResult.empty]);
      });

      test('reports failure when the lookup fails, and times the retry as '
          'retry', () async {
        stubLookup(() async => throw Exception('malformed link'));

        final cubit = await openLink();
        expect(cubit.state.status, VideoDetailStatus.loadFailed);

        stubLookup(() async => VideoRouteFound(_video));
        cubit.retry();
        await pumpEventQueue();

        expect(recorder.results, [
          SurfaceLoadResult.failure,
          SurfaceLoadResult.success,
        ]);
        expect(
          recorder.loads.last,
          containsPair(AnalyticsParam.entryPoint, ScreenLoadEntryPoint.retry),
        );
      });

      test('reports dismissed when closed during the lookup', () async {
        final lookup = Completer<VideoRouteLookupResult>();
        addTearDown(() {
          if (!lookup.isCompleted) lookup.complete(const VideoRouteMissing());
        });
        stubLookup(() => lookup.future);
        final cubit = createCubit()..search(routeId: _routeId);
        await pumpEventQueue();

        await cubit.close();
        await pumpEventQueue();

        expect(recorder.results, [SurfaceLoadResult.dismissed]);
      });

      test('does not time a video handed over by the opening screen', () async {
        final cubit = createCubit()
          ..search(routeId: _routeId, initialVideo: _video);
        addTearDown(cubit.close);
        await pumpEventQueue();

        expect(cubit.state.status, VideoDetailStatus.ready);
        expect(recorder.loads, isEmpty);
      });
    });
  });
}
