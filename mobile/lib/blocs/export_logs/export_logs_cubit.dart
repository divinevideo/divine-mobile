// ABOUTME: Drives the Support Center log export and reveal actions
// ABOUTME: Keeps BugReportService out of the widget layer (UI -> Cubit -> Service)

import 'dart:ui' show Rect;

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:openvine/blocs/close_guard.dart';
import 'package:openvine/blocs/export_logs/export_logs_state.dart';
import 'package:openvine/services/bug_report_service.dart';

export 'package:openvine/blocs/export_logs/export_logs_state.dart';

class ExportLogsCubit extends Cubit<ExportLogsState>
    with CloseGuardedEmit<ExportLogsState> {
  ExportLogsCubit({
    required BugReportService bugReportService,
    String? currentScreen,
    List<String> recentScreens = const [],
    String? userPubkey,
  }) : _bugReportService = bugReportService,
       _currentScreen = currentScreen,
       _recentScreens = List.unmodifiable(recentScreens),
       _userPubkey = userPubkey,
       super(const ExportLogsState());

  final BugReportService _bugReportService;
  final String? _currentScreen;
  final List<String> _recentScreens;
  final String? _userPubkey;

  /// Writes the captured logs to a file and hands it to the platform.
  ///
  /// [sharePositionOrigin] anchors the iPad popover and must be resolved by
  /// the caller before the first suspension point — the iPad idiom rejects
  /// the share sheet without it.
  Future<void> export({Rect? sharePositionOrigin}) async {
    if (state.status == ExportLogsStatus.exporting) return;
    emitIfOpen(const ExportLogsState(status: ExportLogsStatus.exporting));

    final result = await _bugReportService.exportLogsToFile(
      currentScreen: _currentScreen,
      recentScreens: _recentScreens,
      userPubkey: _userPubkey,
      sharePositionOrigin: sharePositionOrigin,
    );

    emitIfOpen(
      ExportLogsState(
        status: _statusFor(result.status),
        filePath: result.filePath,
      ),
    );
  }

  /// Opens the folder containing an exported file.
  Future<void> revealFile(String filePath) =>
      _bugReportService.revealExportedFile(filePath);

  static ExportLogsStatus _statusFor(LogExportStatus status) =>
      switch (status) {
        LogExportStatus.shared => ExportLogsStatus.shared,
        LogExportStatus.saved => ExportLogsStatus.saved,
        LogExportStatus.cancelled => ExportLogsStatus.cancelled,
        LogExportStatus.noLogs => ExportLogsStatus.noLogs,
        LogExportStatus.unconfirmed => ExportLogsStatus.unconfirmed,
        LogExportStatus.failed => ExportLogsStatus.failed,
      };
}
