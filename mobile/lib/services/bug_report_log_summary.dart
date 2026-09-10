// ABOUTME: Formats sanitized bug report logs for public support submissions
// ABOUTME: Keeps diagnostic transformation out of the bug report UI layer

import 'package:flutter/foundation.dart' show compute;
import 'package:openvine/config/bug_report_config.dart';
import 'package:unified_logger/unified_logger.dart';

/// Builds the public-support log summary outside the main isolate.
///
/// Production input logs have already been sanitized field by field, while
/// [buildLogsSummary] also guarantees sanitized output for any other caller.
/// Keep that potentially expensive pre-truncation scan off the UI isolate. If
/// a worker cannot start, fall back inline rather than risk transmitting an
/// unsanitized summary.
Future<String?> buildLogsSummaryOffMain(List<LogEntry> logs) async {
  try {
    return await compute(buildLogsSummary, logs);
  } on Object catch (error) {
    Log.warning(
      'Off-main bug report summary failed ($error); building inline so the '
      'report remains sanitized',
      category: LogCategory.system,
    );
    return buildLogsSummary(logs);
  }
}

/// Build a log summary prioritizing errors/warnings with recent context.
///
/// Returns null if logs are empty. Takes up to 200 most recent error/warning
/// entries plus the last 50 entries of any level, deduplicates, and sorts
/// chronologically. Individual entries are truncated to
/// [BugReportConfig.maxLogEntryLength] characters and the total summary is
/// capped at [BugReportConfig.maxLogSummaryLength] characters.
String? buildLogsSummary(List<LogEntry> logs) {
  if (logs.isEmpty) return null;

  final errorWarnings = logs
      .where((l) => l.level == LogLevel.error || l.level == LogLevel.warning)
      .toList();
  final recentErrors = errorWarnings.length > 200
      ? errorWarnings.sublist(errorWarnings.length - 200)
      : errorWarnings;

  final recentContext = logs.length > 50
      ? logs.sublist(logs.length - 50)
      : logs;

  final merged = <LogEntry>{...recentErrors, ...recentContext}.toList()
    ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

  final buffer = StringBuffer();
  for (var i = 0; i < merged.length; i++) {
    // Sanitize per entry, before truncation. Redaction can consume a bounded
    // run of text around what it matches, so doing it here caps that run at
    // one log entry instead of letting it reach across the assembled report.
    //
    // Before truncation, so a value running past the entry limit is redacted
    // whole rather than half-cut and then matched. That order costs something
    // too: a stray `{` early in a long entry can now consume up to the
    // collection bound *inside* that entry, where truncating first would have
    // capped the entry at 500 characters before the closing delimiter was
    // reachable. Losing part of one entry beats losing the entries after it.
    var line = sanitizeDiagnosticText(merged[i].toFormattedString());
    if (line.length > BugReportConfig.maxLogEntryLength) {
      line =
          '${line.substring(0, BugReportConfig.maxLogEntryLength)}... [truncated]';
    }
    if (buffer.length + line.length + 1 > BugReportConfig.maxLogSummaryLength) {
      final remaining = merged.length - i;
      final noun = remaining == 1 ? 'entry' : 'entries';
      buffer.writeln('... [$remaining $noun truncated]');
      break;
    }
    buffer.writeln(line);
  }

  final result = buffer.toString().trimRight();
  return result.isEmpty ? null : result;
}
