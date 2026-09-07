import 'package:app_update_repository/app_update_repository.dart';
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/app_update/app_update.dart';

class _MockAppUpdateRepository extends Mock implements AppUpdateRepository {}

void main() {
  group(AppUpdateBloc, () {
    late _MockAppUpdateRepository repository;

    setUp(() {
      repository = _MockAppUpdateRepository();
    });

    AppUpdateBloc buildBloc() => AppUpdateBloc(repository: repository);

    const gentleResult = UpdateCheckResult(
      urgency: UpdateUrgency.gentle,
      downloadUrl: DownloadUrls.github,
      latestVersion: '1.0.8',
      releaseHighlights: ['New feature'],
      releaseNotesUrl:
          'https://github.com/divinevideo/divine-mobile/releases/tag/1.0.8',
    );

    group('AppUpdateCheckRequested', () {
      blocTest<AppUpdateBloc, AppUpdateState>(
        'emits resolved with result when repository returns update',
        build: buildBloc,
        setUp: () {
          when(
            () => repository.checkForUpdate(),
          ).thenAnswer((_) async => gentleResult);
        },
        act: (bloc) => bloc.add(const AppUpdateCheckRequested()),
        expect: () => [
          const AppUpdateState(status: AppUpdateStatus.checking),
          const AppUpdateState(
            status: AppUpdateStatus.resolved,
            urgency: UpdateUrgency.gentle,
            latestVersion: '1.0.8',
            downloadUrl: DownloadUrls.github,
            releaseHighlights: ['New feature'],
            releaseNotesUrl:
                'https://github.com/divinevideo/divine-mobile/releases/'
                'tag/1.0.8',
          ),
        ],
      );

      blocTest<AppUpdateBloc, AppUpdateState>(
        'emits resolved none when no update available',
        build: buildBloc,
        setUp: () {
          when(
            () => repository.checkForUpdate(),
          ).thenAnswer((_) async => const UpdateCheckResult.none());
        },
        act: (bloc) => bloc.add(const AppUpdateCheckRequested()),
        expect: () => [
          const AppUpdateState(status: AppUpdateStatus.checking),
          const AppUpdateState(status: AppUpdateStatus.resolved),
        ],
      );

      blocTest<AppUpdateBloc, AppUpdateState>(
        'reverts to initial when repository returns null',
        build: buildBloc,
        setUp: () {
          when(() => repository.checkForUpdate()).thenAnswer((_) async => null);
        },
        act: (bloc) => bloc.add(const AppUpdateCheckRequested()),
        expect: () => [
          const AppUpdateState(status: AppUpdateStatus.checking),
          const AppUpdateState(),
        ],
      );

      blocTest<AppUpdateBloc, AppUpdateState>(
        'emits urgent when repository returns urgent',
        build: buildBloc,
        setUp: () {
          when(() => repository.checkForUpdate()).thenAnswer(
            (_) async => const UpdateCheckResult(
              urgency: UpdateUrgency.urgent,
              downloadUrl: DownloadUrls.github,
              latestVersion: '1.0.8',
              releaseHighlights: ['Security fix'],
            ),
          );
        },
        act: (bloc) => bloc.add(const AppUpdateCheckRequested()),
        expect: () => [
          const AppUpdateState(status: AppUpdateStatus.checking),
          isA<AppUpdateState>().having(
            (s) => s.urgency,
            'urgency',
            UpdateUrgency.urgent,
          ),
        ],
      );
    });

    group('AppUpdateDismissed', () {
      blocTest<AppUpdateBloc, AppUpdateState>(
        'clears urgency but keeps the resolved update reachable',
        build: buildBloc,
        seed: () => const AppUpdateState(
          status: AppUpdateStatus.resolved,
          urgency: UpdateUrgency.gentle,
          latestVersion: '1.0.8',
          downloadUrl: DownloadUrls.github,
        ),
        setUp: () {
          when(() => repository.dismissUpdate(any())).thenAnswer((_) async {});
        },
        act: (bloc) => bloc.add(const AppUpdateDismissed()),
        expect: () => [
          isA<AppUpdateState>()
              .having((s) => s.urgency, 'urgency', UpdateUrgency.none)
              // Settings keeps offering the update after the nudge is
              // dismissed, so the resolved release must survive the emit.
              .having((s) => s.status, 'status', AppUpdateStatus.resolved)
              .having((s) => s.latestVersion, 'latestVersion', '1.0.8')
              .having(
                (s) => s.downloadUrl,
                'downloadUrl',
                DownloadUrls.github,
              ),
        ],
        verify: (_) {
          verify(() => repository.dismissUpdate('1.0.8')).called(1);
        },
      );
    });
  });
}
