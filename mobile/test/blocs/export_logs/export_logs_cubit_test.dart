// ABOUTME: Tests the log-export cubit's status mapping and in-flight guard
// ABOUTME: Four of the six export outcomes are not failures (#8113, #8114)

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/export_logs/export_logs_cubit.dart';
import 'package:openvine/services/bug_report_service.dart';

class _MockBugReportService extends Mock implements BugReportService {}

const _pubkeyHex =
    '3bf0c63fcb93463407af97a5e5ee64fa883d107ef9e558472c4eb9aaaefa459d';

void main() {
  group(ExportLogsCubit, () {
    late _MockBugReportService bugReportService;

    setUp(() {
      bugReportService = _MockBugReportService();
    });

    ExportLogsCubit build() => ExportLogsCubit(
      bugReportService: bugReportService,
      currentScreen: 'DeveloperOptionsScreen',
      recentScreens: const ['home', 'developerOptions'],
      userPubkey: _pubkeyHex,
    );

    void stubExport(LogExportResult result) {
      when(
        () => bugReportService.exportLogsToFile(
          currentScreen: any(named: 'currentScreen'),
          recentScreens: any(named: 'recentScreens'),
          userPubkey: any(named: 'userPubkey'),
          sharePositionOrigin: any(named: 'sharePositionOrigin'),
        ),
      ).thenAnswer((_) async => result);
    }

    group('export', () {
      blocTest<ExportLogsCubit, ExportLogsState>(
        'passes the screen and pubkey through to the service',
        setUp: () => stubExport(const LogExportResult.shared()),
        build: build,
        act: (cubit) => cubit.export(),
        verify: (_) {
          verify(
            () => bugReportService.exportLogsToFile(
              currentScreen: 'DeveloperOptionsScreen',
              recentScreens: const ['home', 'developerOptions'],
              userPubkey: _pubkeyHex,
              sharePositionOrigin: any(named: 'sharePositionOrigin'),
            ),
          ).called(1);
        },
      );

      // The mobile happy path: another app confirmed it took the file. It
      // carries no path (unlike a desktop save) and the UI stays silent, so
      // nothing else guards this mapping against a mis-wire to failure.
      blocTest<ExportLogsCubit, ExportLogsState>(
        'maps a confirmed share to shared',
        setUp: () => stubExport(const LogExportResult.shared()),
        build: build,
        act: (cubit) => cubit.export(),
        expect: () => const [
          ExportLogsState(status: ExportLogsStatus.exporting),
          ExportLogsState(status: ExportLogsStatus.shared),
        ],
      );

      // #8113: share_plus reports `unavailable` whenever it cannot attach to
      // an Activity, even though the sheet opened. Mapping that to failure is
      // what told the user log export was broken.
      blocTest<ExportLogsCubit, ExportLogsState>(
        'maps an unknown outcome to unconfirmed, not failed',
        setUp: () => stubExport(const LogExportResult.unconfirmed()),
        build: build,
        act: (cubit) => cubit.export(),
        expect: () => const [
          ExportLogsState(status: ExportLogsStatus.exporting),
          ExportLogsState(status: ExportLogsStatus.unconfirmed),
        ],
      );

      // #8114: the capture buffer is memory-only, so a crash empties it.
      blocTest<ExportLogsCubit, ExportLogsState>(
        'maps an empty buffer to noLogs, not failed',
        setUp: () => stubExport(const LogExportResult.noLogs()),
        build: build,
        act: (cubit) => cubit.export(),
        expect: () => const [
          ExportLogsState(status: ExportLogsStatus.exporting),
          ExportLogsState(status: ExportLogsStatus.noLogs),
        ],
      );

      blocTest<ExportLogsCubit, ExportLogsState>(
        'maps a dismissed sheet to cancelled',
        setUp: () => stubExport(const LogExportResult.cancelled()),
        build: build,
        act: (cubit) => cubit.export(),
        expect: () => const [
          ExportLogsState(status: ExportLogsStatus.exporting),
          ExportLogsState(status: ExportLogsStatus.cancelled),
        ],
      );

      blocTest<ExportLogsCubit, ExportLogsState>(
        'maps a real failure to failed',
        setUp: () => stubExport(const LogExportResult.failed()),
        build: build,
        act: (cubit) => cubit.export(),
        expect: () => const [
          ExportLogsState(status: ExportLogsStatus.exporting),
          ExportLogsState(status: ExportLogsStatus.failed),
        ],
      );

      blocTest<ExportLogsCubit, ExportLogsState>(
        'carries the saved path so the UI can offer to reveal it',
        setUp: () => stubExport(const LogExportResult.saved('/tmp/logs.txt')),
        build: build,
        act: (cubit) => cubit.export(),
        expect: () => const [
          ExportLogsState(status: ExportLogsStatus.exporting),
          ExportLogsState(
            status: ExportLogsStatus.saved,
            filePath: '/tmp/logs.txt',
          ),
        ],
      );

      blocTest<ExportLogsCubit, ExportLogsState>(
        'ignores a second export while one is in flight',
        setUp: () {
          when(
            () => bugReportService.exportLogsToFile(
              currentScreen: any(named: 'currentScreen'),
              recentScreens: any(named: 'recentScreens'),
              userPubkey: any(named: 'userPubkey'),
              sharePositionOrigin: any(named: 'sharePositionOrigin'),
            ),
          ).thenAnswer((_) => Completer<LogExportResult>().future);
        },
        build: build,
        act: (cubit) {
          unawaited(cubit.export());
          unawaited(cubit.export());
        },
        expect: () => const [
          ExportLogsState(status: ExportLogsStatus.exporting),
        ],
        verify: (_) {
          verify(
            () => bugReportService.exportLogsToFile(
              currentScreen: any(named: 'currentScreen'),
              recentScreens: any(named: 'recentScreens'),
              userPubkey: any(named: 'userPubkey'),
              sharePositionOrigin: any(named: 'sharePositionOrigin'),
            ),
          ).called(1);
        },
      );

      // close() does not cancel an in-flight export; the resumed emit would
      // throw without the guard (#7370).
      test('drops the outcome when closed mid-export', () async {
        final gate = Completer<LogExportResult>();
        when(
          () => bugReportService.exportLogsToFile(
            currentScreen: any(named: 'currentScreen'),
            recentScreens: any(named: 'recentScreens'),
            userPubkey: any(named: 'userPubkey'),
            sharePositionOrigin: any(named: 'sharePositionOrigin'),
          ),
        ).thenAnswer((_) => gate.future);

        final cubit = build();
        final pending = cubit.export();
        await cubit.close();
        gate.complete(const LogExportResult.shared());

        await expectLater(pending, completes);
      });
    });

    group('revealFile', () {
      test('asks the service to open the containing folder', () async {
        when(
          () => bugReportService.revealExportedFile(any()),
        ).thenAnswer((_) async {});

        await build().revealFile('/tmp/logs.txt');

        verify(
          () => bugReportService.revealExportedFile('/tmp/logs.txt'),
        ).called(1);
      });
    });
  });
}
