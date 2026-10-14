// ABOUTME: Fails if anything in lib/ but ReportSubmissionCubit submits a report
// ABOUTME: Three report surfaces had drifted into three different forms (#10003)

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// A call to, or tear-off of, `ContentReportingService.reportContent` or
/// `reportUser` through a receiver: `service.reportContent(`, `?.reportUser`,
/// `..reportContent(`. The service's own unqualified call from `reportUser`
/// into `reportContent` has no receiver, so it is not one.
final _submission = RegExp(r'\.\s*report(Content|User)\b');

/// Doc comments name these methods (`ContentReportingService.reportUser`),
/// and a mention is not a call.
final _comments = RegExp(r'/\*[\s\S]*?\*/|//.*');

const _owner = 'lib/blocs/report/report_submission_cubit.dart';

List<String> _filesSubmittingReports() =>
    Directory('lib')
        .listSync(recursive: true)
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))
        .where(
          (f) => _submission.hasMatch(
            f.readAsStringSync().replaceAll(_comments, ''),
          ),
        )
        .map((f) => f.path)
        .toList()
      ..sort();

void main() {
  group('reports have exactly one submission path', () {
    // Comments had their own reason sheet with no note, the inbox filed a
    // report with no form at all, and only the main form let a reporter
    // explain themselves. Every surface now opens ReportContentDialog, whose
    // cubit is the one caller; a surface that calls the service directly
    // skips the form and its note rules again.
    test('only ReportSubmissionCubit calls reportContent or reportUser', () {
      expect(
        _filesSubmittingReports(),
        equals([_owner]),
        reason:
            'Open ReportContentDialog (show, showForUser, showForMessage, '
            'showForList, showForComment) instead of calling '
            'ContentReportingService directly, so every report gets the same '
            'reasons and note rules.',
      );
    });
  });
}
