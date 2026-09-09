// ABOUTME: Unit tests for BugReportCubit — diagnostics + Zendesk submission
// ABOUTME: lifecycle, with the typed failure-key distinguishing
// ABOUTME: attachment-upload errors from generic failures.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image_picker/image_picker.dart';
import 'package:logging_types/logging_types.dart' show LogEntry, LogLevel;
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show BugReportData;
import 'package:openvine/blocs/bug_report/bug_report_cubit.dart';
import 'package:openvine/blocs/bug_report/bug_report_state.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/services/zendesk_support_service.dart';

class _MockBugReportService extends Mock implements BugReportService {}

const _rawNsec =
    'nsec1qqqsyrhq4p4d8hf40q7tlujzw87hqhz9axhfnm35s2a3u3rrnwsq9sp5p6';
const _rawEmail = 'liz@example.com';

BugReportData _makeReportData({
  String userDescription = '',
  List<LogEntry> recentLogs = const [],
}) => BugReportData(
  reportId: 'report-1',
  timestamp: DateTime.fromMillisecondsSinceEpoch(0),
  userDescription: userDescription,
  deviceInfo: const {'platform': 'test'},
  appVersion: '1.0.0+1',
  recentLogs: recentLogs,
  errorCounts: const {},
);

void main() {
  group(BugReportCubit, () {
    late _MockBugReportService service;

    setUp(() {
      service = _MockBugReportService();
      when(
        () => service.collectDiagnostics(
          userDescription: any(named: 'userDescription'),
          currentScreen: any(named: 'currentScreen'),
          userPubkey: any(named: 'userPubkey'),
          additionalContext: any(named: 'additionalContext'),
        ),
      ).thenAnswer((_) async => _makeReportData());
    });

    SubmitBugReportAction buildSubmit({
      bool returnValue = true,
      Object? throwError,
    }) {
      return ({
        required String subject,
        required String description,
        required String reportId,
        required String appVersion,
        required Map<String, dynamic> deviceInfo,
        String? stepsToReproduce,
        String? expectedBehavior,
        String? currentScreen,
        List<String>? recentScreens,
        String? userPubkey,
        Map<String, int>? errorCounts,
        String? logsSummary,
        List<String>? attachmentPaths,
      }) async {
        if (throwError != null) throw throwError;
        return returnValue;
      };
    }

    BugReportCubit buildCubit({
      bool returnValue = true,
      Object? throwError,
      BuildLogsSummary? buildLogsSummary,
      SubmitBugReportAction? submitBugReport,
    }) {
      return BugReportCubit(
        bugReportService: service,
        buildLogsSummary: buildLogsSummary ?? (_) async => null,
        submitBugReport:
            submitBugReport ??
            buildSubmit(returnValue: returnValue, throwError: throwError),
      );
    }

    blocTest<BugReportCubit, BugReportState>(
      'submit happy path emits submitting then success',
      build: buildCubit,
      act: (cubit) => cubit.submit(
        subject: 'Crash',
        description: 'It crashed',
        stepsToReproduce: '',
        expectedBehavior: '',
        attachments: const [],
      ),
      expect: () => [
        const BugReportState(status: BugReportStatus.submitting),
        const BugReportState(status: BugReportStatus.success),
      ],
    );

    test(
      'awaits off-main log summary construction before submitting',
      () async {
        final summaryCompleter = Completer<String?>();
        var submitCalls = 0;
        String? submittedSummary;
        final cubit = buildCubit(
          buildLogsSummary: (_) => summaryCompleter.future,
          submitBugReport:
              ({
                required String subject,
                required String description,
                required String reportId,
                required String appVersion,
                required Map<String, dynamic> deviceInfo,
                String? stepsToReproduce,
                String? expectedBehavior,
                String? currentScreen,
                List<String>? recentScreens,
                String? userPubkey,
                Map<String, int>? errorCounts,
                String? logsSummary,
                List<String>? attachmentPaths,
              }) async {
                submitCalls++;
                submittedSummary = logsSummary;
                return true;
              },
        );

        final submission = cubit.submit(
          subject: 'Crash',
          description: 'It crashed',
          stepsToReproduce: '',
          expectedBehavior: '',
          attachments: const [],
        );
        await pumpEventQueue();

        expect(submitCalls, 0);
        summaryCompleter.complete('off-main summary');
        await submission;

        expect(submitCalls, 1);
        expect(submittedSummary, 'off-main summary');
        await cubit.close();
      },
    );

    blocTest<BugReportCubit, BugReportState>(
      'submit no-op when subject empty',
      build: buildCubit,
      act: (cubit) => cubit.submit(
        subject: '',
        description: 'desc',
        stepsToReproduce: '',
        expectedBehavior: '',
        attachments: const [],
      ),
      expect: () => const <BugReportState>[],
    );

    blocTest<BugReportCubit, BugReportState>(
      'submit emits failure with generic key when service returns false',
      build: () => buildCubit(returnValue: false),
      act: (cubit) => cubit.submit(
        subject: 'X',
        description: 'Y',
        stepsToReproduce: '',
        expectedBehavior: '',
        attachments: const [],
      ),
      expect: () => [
        const BugReportState(status: BugReportStatus.submitting),
        const BugReportState(
          status: BugReportStatus.failure,
          failureKey: BugReportFailureKey.generic,
        ),
      ],
    );

    blocTest<BugReportCubit, BugReportState>(
      'submit emits attachmentUpload key on ZendeskAttachmentUploadException',
      build: () =>
          buildCubit(throwError: const ZendeskAttachmentUploadException()),
      act: (cubit) => cubit.submit(
        subject: 'X',
        description: 'Y',
        stepsToReproduce: '',
        expectedBehavior: '',
        attachments: [XFile('/tmp/x.png')],
      ),
      expect: () => [
        const BugReportState(status: BugReportStatus.submitting),
        const BugReportState(
          status: BugReportStatus.failure,
          failureKey: BugReportFailureKey.attachmentUpload,
        ),
      ],
      errors: () => [isA<ZendeskAttachmentUploadException>()],
    );

    blocTest<BugReportCubit, BugReportState>(
      'submit emits generic key on other exceptions',
      build: () => buildCubit(throwError: StateError('boom')),
      act: (cubit) => cubit.submit(
        subject: 'X',
        description: 'Y',
        stepsToReproduce: '',
        expectedBehavior: '',
        attachments: const [],
      ),
      expect: () => [
        const BugReportState(status: BugReportStatus.submitting),
        const BugReportState(
          status: BugReportStatus.failure,
          failureKey: BugReportFailureKey.generic,
        ),
      ],
      errors: () => [isA<StateError>()],
    );

    blocTest<BugReportCubit, BugReportState>(
      'submit sends sanitized diagnostics and logs to Zendesk',
      setUp: () {
        when(
          () => service.collectDiagnostics(
            userDescription: any(named: 'userDescription'),
            currentScreen: any(named: 'currentScreen'),
            userPubkey: any(named: 'userPubkey'),
            additionalContext: any(named: 'additionalContext'),
          ),
        ).thenAnswer(
          (_) async => _makeReportData(
            userDescription: 'Description [REDACTED] [REDACTED]',
            recentLogs: [
              LogEntry(
                timestamp: DateTime.fromMillisecondsSinceEpoch(0),
                level: LogLevel.error,
                message: 'Log [REDACTED] [REDACTED]',
                error: 'Error [REDACTED]',
                stackTrace: 'Stack [REDACTED]',
              ),
            ],
          ),
        );
      },
      build: () {
        return buildCubit(
          buildLogsSummary: (logs) async => logs
              .map((log) => '${log.message}\n${log.error}\n${log.stackTrace}')
              .join('\n'),
          submitBugReport:
              ({
                required String subject,
                required String description,
                required String reportId,
                required String appVersion,
                required Map<String, dynamic> deviceInfo,
                String? stepsToReproduce,
                String? expectedBehavior,
                String? currentScreen,
                List<String>? recentScreens,
                String? userPubkey,
                Map<String, int>? errorCounts,
                String? logsSummary,
                List<String>? attachmentPaths,
              }) async {
                final submitted = [description, logsSummary].join('\n');
                expect(submitted, isNot(contains(_rawNsec)));
                expect(submitted, isNot(contains(_rawEmail)));
                expect(submitted, contains('[REDACTED]'));
                expect(subject, 'Crash $_rawNsec');
                expect(stepsToReproduce, 'Step $_rawNsec');
                expect(expectedBehavior, 'Expected $_rawEmail');
                expect(currentScreen, 'settings');
                expect(recentScreens, ['home', 'profile', 'settings']);
                return true;
              },
        );
      },
      act: (cubit) => cubit.submit(
        subject: 'Crash $_rawNsec',
        description: 'Description $_rawNsec $_rawEmail',
        stepsToReproduce: 'Step $_rawNsec',
        expectedBehavior: 'Expected $_rawEmail',
        attachments: const [],
        currentScreen: 'settings',
        recentScreens: const ['home', 'profile', 'settings'],
      ),
      expect: () => [
        const BugReportState(status: BugReportStatus.submitting),
        const BugReportState(status: BugReportStatus.success),
      ],
    );
  });
}
