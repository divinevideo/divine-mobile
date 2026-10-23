import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/video_loops/video_loops_cubit.dart';
import 'package:videos_repository/videos_repository.dart';

class _MockVideosRepository extends Mock implements VideosRepository {}

void main() {
  final video = VideoEvent(
    id: 'a' * 64,
    pubkey: 'b' * 64,
    createdAt: 1700000000,
    content: '',
    timestamp: DateTime.utc(2026),
    rawTags: const {'views': '10'},
  );
  late _MockVideosRepository repository;

  setUp(() {
    repository = _MockVideosRepository();
    when(() => repository.fetchLoopCount(video)).thenAnswer((_) async => 10);
  });

  group('loopCompleted', () {
    test('own completed loops update immediately and server catch-up is not added twice', () async {
      final cubit = VideoLoopsCubit(video: video, videosRepository: repository);
      cubit.setActive(true);
      await Future<void>.value();
      cubit.loopCompleted();
      cubit.loopCompleted();
      expect(cubit.state.count, 12);
      when(() => repository.fetchLoopCount(video)).thenAnswer((_) async => 12);
      await cubit.refresh();
      expect(cubit.state.count, 12);
      when(() => repository.fetchLoopCount(video)).thenAnswer((_) async => 20);
      await cubit.refresh();
      expect(cubit.state.count, 20);
      cubit.loopCompleted();
      expect(cubit.state.count, 21);
      await cubit.close();
    });

    test(
      'a video with no metadata gains a visible count from completed playback',
      () async {
        final unknown = video.copyWith(rawTags: const {});
        when(() => repository.fetchLoopCount(unknown))
            .thenAnswer((_) async => null);
        final cubit = VideoLoopsCubit(
          video: unknown,
          videosRepository: repository,
        );
        expect(cubit.state.count, isNull);
        cubit.setActive(true);
        await Future<void>.value();
        cubit.loopCompleted();
        expect(cubit.state.count, 1);
        await cubit.close();
      },
    );
  });

  group('refresh', () {
    test(
      'a slow refresh preserves loops completed while it was pending',
      () async {
        final response = Completer<int?>();
        when(() => repository.fetchLoopCount(video))
            .thenAnswer((_) => response.future);
        final cubit = VideoLoopsCubit(
          video: video,
          videosRepository: repository,
        );
        cubit.setActive(true);
        cubit.loopCompleted();
        await cubit.refresh();
        verify(() => repository.fetchLoopCount(video)).called(1);
        response.complete(10);
        await Future<void>.value();
        expect(cubit.state.count, 11);
        await cubit.close();
      },
    );

    test('stale and missing totals never lower the visible count', () async {
      final cubit = VideoLoopsCubit(video: video, videosRepository: repository);
      cubit.setActive(true);
      await Future<void>.value();
      cubit.loopCompleted();
      when(() => repository.fetchLoopCount(video)).thenAnswer((_) async => 2);
      await cubit.refresh();
      expect(cubit.state.count, 11);
      when(() => repository.fetchLoopCount(video))
          .thenAnswer((_) async => null);
      await cubit.refresh();
      expect(cubit.state.count, 11);
      await cubit.close();
    });

    test(
      'a failed refresh keeps local loops and allows the next refresh',
      () async {
        when(() => repository.fetchLoopCount(video))
            .thenThrow(StateError('offline'));
        final cubit = VideoLoopsCubit(
          video: video,
          videosRepository: repository,
        );
        cubit.setActive(true);
        await Future<void>.value();
        cubit.loopCompleted();
        expect(cubit.state.count, 11);
        when(() => repository.fetchLoopCount(video))
            .thenAnswer((_) async => 15);
        await cubit.refresh();
        expect(cubit.state.count, 15);
        await cubit.close();
      },
    );
  });

  group('setActive', () {
    test('inactive playback neither refreshes nor adds loops', () async {
      final cubit = VideoLoopsCubit(video: video, videosRepository: repository);
      await cubit.refresh();
      cubit.loopCompleted();
      verifyNever(() => repository.fetchLoopCount(video));
      expect(cubit.state.count, 10);
      cubit.setActive(true);
      await Future<void>.value();
      cubit.setActive(false);
      await cubit.refresh();
      cubit.loopCompleted();
      expect(cubit.state.count, 10);
      verify(() => repository.fetchLoopCount(video)).called(1);
      await cubit.close();
    });

    test(
      'ignores a response from playback that has since become inactive',
      () async {
        final response = Completer<int?>();
        when(() => repository.fetchLoopCount(video))
            .thenAnswer((_) => response.future);
        final cubit = VideoLoopsCubit(
          video: video,
          videosRepository: repository,
        );
        cubit.setActive(true);
        cubit.setActive(false);
        response.complete(100);
        await Future<void>.value();
        expect(cubit.state.count, 10);
        await cubit.close();
      },
    );
  });
}
