import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/widgets/video_recorder/remote_record_pause.dart';

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

void main() {
  group('showWithRemoteRecordPaused', () {
    late _MockVideoRecorderBloc bloc;

    setUp(() {
      bloc = _MockVideoRecorderBloc();
      when(() => bloc.isClosed).thenReturn(false);
    });

    test('pauses before the sheet shows and resumes once it closes', () async {
      final result = await showWithRemoteRecordPaused(bloc, () async {
        verify(
          () => bloc.add(const VideoRecorderRemoteRecordPaused()),
        ).called(1);
        verifyNever(() => bloc.add(const VideoRecorderRemoteRecordResumed()));
        return 'picked';
      });

      expect(result, equals('picked'));
      verify(() => bloc.add(const VideoRecorderRemoteRecordResumed()))
          .called(1);
    });

    test('resumes when showing the sheet throws', () async {
      await expectLater(
        showWithRemoteRecordPaused<void>(
          bloc,
          () => Future.error(StateError('no navigator')),
        ),
        throwsStateError,
      );

      verify(() => bloc.add(const VideoRecorderRemoteRecordResumed()))
          .called(1);
    });

    test(
      'does not resume a recorder that closed while the sheet was open',
      () async {
        await showWithRemoteRecordPaused<void>(bloc, () async {
          when(() => bloc.isClosed).thenReturn(true);
        });

        verifyNever(() => bloc.add(const VideoRecorderRemoteRecordResumed()));
      },
    );
  });
}
