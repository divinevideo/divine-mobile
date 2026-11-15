// ABOUTME: Unit tests for VideoRemixesCubit: the remixes it reads for the info
// ABOUTME: sheet, a video with no address, a failed read, and close mid-read.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/widgets/video_feed_item/metadata/video_remixes_cubit.dart';
import 'package:video_responses_repository/video_responses_repository.dart';

class _MockVideoResponsesRepository extends Mock
    implements VideoResponsesRepository {}

const _address =
    '34236:0000000000000000000000000000000000000000000000000000000000000001:d';

VideoEvent _remix(String id) => VideoEvent(
  id: id,
  pubkey: '0000000000000000000000000000000000000000000000000000000000000002',
  createdAt: 1000,
  content: '',
  timestamp: DateTime.fromMillisecondsSinceEpoch(1000000),
);

List<VideoEvent> _keepAll(List<VideoEvent> remixes) => remixes;

void main() {
  group(VideoRemixesCubit, () {
    late _MockVideoResponsesRepository repository;

    setUp(() {
      repository = _MockVideoResponsesRepository();
    });

    blocTest<VideoRemixesCubit, VideoRemixesState>(
      'emits the remixes the repository reads',
      setUp: () {
        when(
          () => repository.fetchRemixesOf(_address, filter: _keepAll),
        ).thenAnswer((_) async => [_remix('a'), _remix('b')]);
      },
      build: () => VideoRemixesCubit(
        videoResponsesRepository: repository,
        addressableId: _address,
        filter: _keepAll,
      ),
      expect: () => [
        VideoRemixesState(
          remixes: [_remix('a'), _remix('b')],
          isLoading: false,
        ),
      ],
    );

    test('reads nothing for a video with no address', () {
      final cubit = VideoRemixesCubit(
        videoResponsesRepository: repository,
        addressableId: null,
        filter: _keepAll,
      );
      addTearDown(cubit.close);

      expect(cubit.state, equals(const VideoRemixesState(isLoading: false)));
      verifyNever(
        () => repository.fetchRemixesOf(any(), filter: any(named: 'filter')),
      );
    });

    test('reads nothing for an empty address', () {
      final cubit = VideoRemixesCubit(
        videoResponsesRepository: repository,
        addressableId: '',
        filter: _keepAll,
      );
      addTearDown(cubit.close);

      expect(cubit.state, equals(const VideoRemixesState(isLoading: false)));
      verifyNever(
        () => repository.fetchRemixesOf(any(), filter: any(named: 'filter')),
      );
    });

    blocTest<VideoRemixesCubit, VideoRemixesState>(
      'emits no remixes and reports the error when the read throws',
      setUp: () {
        when(
          () => repository.fetchRemixesOf(_address, filter: _keepAll),
        ).thenAnswer((_) async => throw Exception('relay down'));
      },
      build: () => VideoRemixesCubit(
        videoResponsesRepository: repository,
        addressableId: _address,
        filter: _keepAll,
      ),
      expect: () => const [VideoRemixesState(isLoading: false)],
      errors: () => [isA<Exception>()],
    );

    test('does not emit when closed before the read finishes', () async {
      final read = Completer<List<VideoEvent>>();
      when(
        () => repository.fetchRemixesOf(_address, filter: _keepAll),
      ).thenAnswer((_) => read.future);
      final cubit = VideoRemixesCubit(
        videoResponsesRepository: repository,
        addressableId: _address,
        filter: _keepAll,
      );
      final states = <VideoRemixesState>[];
      final subscription = cubit.stream.listen(states.add);

      await cubit.close();
      read.complete([_remix('a')]);
      await pumpEventQueue();
      await subscription.cancel();

      expect(cubit.isClosed, isTrue);
      expect(states, isEmpty);
      expect(cubit.state, equals(const VideoRemixesState()));
    });
  });
}
