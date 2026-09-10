// ABOUTME: Cubit backing the bug report flow — diagnostics + Zendesk submission.

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:image_picker/image_picker.dart';
import 'package:openvine/blocs/bug_report/bug_report_state.dart';
import 'package:openvine/services/bug_report_service.dart';
import 'package:openvine/services/zendesk_support_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// Top-level submit-bug-report callable hidden behind a typedef so the
/// Cubit doesn't reach into the static `ZendeskSupportService` surface
/// directly. Tests inject a fake; production wires
/// `ZendeskSupportService.createStructuredBugReport`.
typedef SubmitBugReportAction = Future<bool> Function({
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
});

/// Builds the logs summary string the cubit passes to Zendesk.
typedef BuildLogsSummary = Future<String?> Function(List<LogEntry> logs);

/// Cubit backing the bug report flow. Owns the submission lifecycle plus
/// the `BugReportFailureKey` that distinguishes attachment-upload
/// failures from generic Zendesk failures — preserves the pre-migration
/// "show the upload-failed message specifically" UX without state
/// holding error strings.
///
/// The four `TextEditingController`s + the picked attachments list stay
/// in the route's form state. The View hands the values into
/// `submit(...)` and the Cubit drives diagnostics + Zendesk.
class BugReportCubit extends Cubit<BugReportState> {
  BugReportCubit({
    required BugReportService bugReportService,
    required BuildLogsSummary buildLogsSummary,
    SubmitBugReportAction submitBugReport =
        ZendeskSupportService.createStructuredBugReport,
  }) : _bugReportService = bugReportService,
       _buildLogsSummary = buildLogsSummary,
       _submit = submitBugReport,
       super(const BugReportState());

  final BugReportService _bugReportService;
  final BuildLogsSummary _buildLogsSummary;
  final SubmitBugReportAction _submit;

  Future<void> submit({
    required String subject,
    required String description,
    required String stepsToReproduce,
    required String expectedBehavior,
    required List<XFile> attachments,
    String? currentScreen,
    List<String> recentScreens = const [],
    String? userPubkey,
  }) async {
    final trimmedSubject = subject.trim();
    final trimmedDescription = description.trim();
    if (trimmedSubject.isEmpty || trimmedDescription.isEmpty) return;

    emit(
      state.copyWith(status: BugReportStatus.submitting, clearFailureKey: true),
    );
    try {
      final reportData = await _bugReportService.collectDiagnostics(
        userDescription: trimmedDescription,
        currentScreen: currentScreen,
        userPubkey: userPubkey,
      );
      final success = await _submit(
        subject: trimmedSubject,
        description: reportData.userDescription,
        stepsToReproduce: stepsToReproduce.trim(),
        expectedBehavior: expectedBehavior.trim(),
        reportId: reportData.reportId,
        appVersion: reportData.appVersion,
        deviceInfo: reportData.deviceInfo,
        currentScreen: currentScreen,
        recentScreens: recentScreens,
        userPubkey: userPubkey,
        errorCounts: reportData.errorCounts,
        logsSummary: await _buildLogsSummary(reportData.recentLogs),
        attachmentPaths: attachments.map((f) => f.path).toList(),
      );
      if (isClosed) return;
      if (success) {
        emit(
          state.copyWith(
            status: BugReportStatus.success,
            clearFailureKey: true,
          ),
        );
      } else {
        emit(
          state.copyWith(
            status: BugReportStatus.failure,
            failureKey: BugReportFailureKey.generic,
          ),
        );
      }
    } on ZendeskAttachmentUploadException catch (e, stackTrace) {
      Log.error(
        'Error submitting bug report (attachment): $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      addError(e, stackTrace);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: BugReportStatus.failure,
          failureKey: BugReportFailureKey.attachmentUpload,
        ),
      );
    } catch (e, stackTrace) {
      Log.error(
        'Error submitting bug report: $e',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      addError(e, stackTrace);
      if (isClosed) return;
      emit(
        state.copyWith(
          status: BugReportStatus.failure,
          failureKey: BugReportFailureKey.generic,
        ),
      );
    }
  }
}
