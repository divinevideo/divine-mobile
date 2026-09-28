import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/community_suggest/community_suggest_cubit.dart';
import 'package:openvine/blocs/community_suggest/community_suggest_state.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/repositories/community_content_label_repository.dart';

class _MockRepository extends Mock implements CommunityContentLabelRepository {}

class _MockVideoEvent extends Mock implements VideoEvent {}

void main() {
  group(CommunitySuggestCubit, () {
    late _MockRepository repository;
    late _MockVideoEvent video;
    late Completer<void> publishGate;
    const myPubkey =
        'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';

    setUpAll(() {
      registerFallbackValue(_MockVideoEvent());
      registerFallbackValue(<ContentLabel>{});
    });

    setUp(() {
      repository = _MockRepository();
      video = _MockVideoEvent();
      publishGate = Completer<void>();
    });

    CommunitySuggestCubit build() => CommunitySuggestCubit(
      repository: repository,
      video: video,
      myPubkey: myPubkey,
    );

    group('loadExisting', () {
      blocTest<CommunitySuggestCubit, CommunitySuggestState>(
        'emits loading then ready with the existing suggestions',
        setUp: () {
          when(
            () => repository.mySuggestedLabels(any(), any()),
          ).thenAnswer((_) async => {'gambling'});
        },
        build: build,
        act: (cubit) => cubit.loadExisting(),
        expect: () => const [
          CommunitySuggestState(status: CommunitySuggestStatus.loading),
          CommunitySuggestState(
            status: CommunitySuggestStatus.ready,
            alreadySuggested: {'gambling'},
          ),
        ],
      );

      blocTest<CommunitySuggestCubit, CommunitySuggestState>(
        'emits failure and reports the error when loading throws',
        setUp: () {
          when(
            () => repository.mySuggestedLabels(any(), any()),
          ).thenThrow(Exception('relay down'));
        },
        build: build,
        act: (cubit) => cubit.loadExisting(),
        expect: () => const [
          CommunitySuggestState(status: CommunitySuggestStatus.loading),
          CommunitySuggestState(status: CommunitySuggestStatus.failure),
        ],
        errors: () => [isA<Exception>()],
      );
    });

    group('toggle', () {
      blocTest<CommunitySuggestCubit, CommunitySuggestState>(
        'adds then removes a label from the selection',
        build: build,
        act: (cubit) => cubit
          ..toggle(ContentLabel.gambling)
          ..toggle(ContentLabel.gambling),
        expect: () => const [
          CommunitySuggestState(
            status: CommunitySuggestStatus.ready,
            selected: {ContentLabel.gambling},
          ),
          CommunitySuggestState(status: CommunitySuggestStatus.ready),
        ],
      );

      blocTest<CommunitySuggestCubit, CommunitySuggestState>(
        'ignores a label the viewer already suggested',
        seed: () => const CommunitySuggestState(
          status: CommunitySuggestStatus.ready,
          alreadySuggested: {'gambling'},
        ),
        build: build,
        act: (cubit) => cubit.toggle(ContentLabel.gambling),
        expect: () => const <CommunitySuggestState>[],
      );
    });

    group('submit', () {
      blocTest<CommunitySuggestCubit, CommunitySuggestState>(
        'emits submitting then success and records the suggestion',
        setUp: () {
          when(
            () => repository.suggestLabels(
              video: any(named: 'video'),
              labels: any(named: 'labels'),
            ),
          ).thenAnswer((_) async {});
        },
        build: build,
        seed: () => const CommunitySuggestState(
          status: CommunitySuggestStatus.ready,
          selected: {ContentLabel.gambling},
        ),
        act: (cubit) => cubit.submit(),
        expect: () => const [
          CommunitySuggestState(
            status: CommunitySuggestStatus.submitting,
            selected: {ContentLabel.gambling},
          ),
          CommunitySuggestState(
            status: CommunitySuggestStatus.success,
            alreadySuggested: {'gambling'},
          ),
        ],
      );

      blocTest<CommunitySuggestCubit, CommunitySuggestState>(
        'ignores a second submit while the first is in flight (droppable)',
        setUp: () {
          // Hold the first publish open across the second submit call so the
          // two overlap in the same frame — the real double-tap race.
          when(
            () => repository.suggestLabels(
              video: any(named: 'video'),
              labels: any(named: 'labels'),
            ),
          ).thenAnswer((_) => publishGate.future);
        },
        build: build,
        seed: () => const CommunitySuggestState(
          status: CommunitySuggestStatus.ready,
          selected: {ContentLabel.gambling},
        ),
        act: (cubit) async {
          final firstSubmit = cubit.submit();
          final secondSubmit = cubit.submit();
          publishGate.complete();
          await Future.wait([firstSubmit, secondSubmit]);
        },
        expect: () => const [
          CommunitySuggestState(
            status: CommunitySuggestStatus.submitting,
            selected: {ContentLabel.gambling},
          ),
          CommunitySuggestState(
            status: CommunitySuggestStatus.success,
            alreadySuggested: {'gambling'},
          ),
        ],
        verify: (_) {
          verify(
            () => repository.suggestLabels(
              video: any(named: 'video'),
              labels: any(named: 'labels'),
            ),
          ).called(1);
        },
      );

      blocTest<CommunitySuggestCubit, CommunitySuggestState>(
        'emits failure and reports the error when publish throws',
        setUp: () {
          when(
            () => repository.suggestLabels(
              video: any(named: 'video'),
              labels: any(named: 'labels'),
            ),
          ).thenThrow(const CommunityLabelPublishException());
        },
        build: build,
        seed: () => const CommunitySuggestState(
          status: CommunitySuggestStatus.ready,
          selected: {ContentLabel.gambling},
        ),
        act: (cubit) => cubit.submit(),
        expect: () => const [
          CommunitySuggestState(
            status: CommunitySuggestStatus.submitting,
            selected: {ContentLabel.gambling},
          ),
          CommunitySuggestState(
            status: CommunitySuggestStatus.failure,
            selected: {ContentLabel.gambling},
          ),
        ],
        errors: () => [isA<CommunityLabelPublishException>()],
      );
    });
  });
}
