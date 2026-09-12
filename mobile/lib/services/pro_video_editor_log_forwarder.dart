import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Forwards native diagnostics emitted by `pro_video_editor` (the renderer,
/// thumbnail, metadata and audio operations) into the app's [UnifiedLogger],
/// so video-editor problems — e.g. a render that fails after many short clips
/// (#4801) — are captured for bug reports.
///
/// Native forwarding is gated per call by the `nativeLogLevel` argument passed
/// to each operation; this forwarder just pipes whatever the plugin emits into
/// the unified log under [LogCategory.video]. The plugin's stream stays empty
/// on Web, Windows, and Linux.
class ProVideoEditorLogForwarder {
  ProVideoEditorLogForwarder._();

  static StreamSubscription<NativeLogEntry>? _subscription;

  /// Starts forwarding `pro_video_editor` native logs into [UnifiedLogger].
  ///
  /// Idempotent — a second call while a subscription is active is a no-op.
  /// Warnings and errors also become sanitized [crashReporter] breadcrumbs,
  /// preserving native causes that method-channel exceptions omit.
  /// [proVideoEditor] is injectable for tests.
  static void start({
    ProVideoEditor? proVideoEditor,
    CrashReporter crashReporter = const SilentCrashReporter(),
  }) {
    if (_subscription != null) return;
    final editor = proVideoEditor ?? ProVideoEditor.instance;
    _subscription = editor.logStream.listen(
      (entry) => forwardEntry(entry, crashReporter: crashReporter),
    );
  }

  /// Stops forwarding and releases the subscription. Mainly for tests.
  static Future<void> stop() async {
    await _subscription?.cancel();
    _subscription = null;
  }

  /// Maps a single [NativeLogEntry] onto the [UnifiedLogger].
  @visibleForTesting
  static void forwardEntry(
    NativeLogEntry entry, {
    CrashReporter crashReporter = const SilentCrashReporter(),
  }) {
    if (entry.message.isEmpty) return;
    final name = (entry.tag?.isNotEmpty ?? false)
        ? entry.tag!
        : 'ProVideoEditorNative';
    // The final render owns the non-fatal report. Native fallback attempts
    // contribute context without each becoming a separate crash issue.
    if (entry.level == NativeLogLevel.warning ||
        entry.level == NativeLogLevel.error) {
      final stack = entry.stackTrace;
      crashReporter.log(
        sanitizeForCrashReport(
          '[$name] ${entry.message}'
          '${stack == null || stack.isEmpty ? '' : '\n$stack'}',
        ),
      );
    }
    switch (entry.level) {
      case NativeLogLevel.error:
        Log.error(
          entry.message,
          name: name,
          category: LogCategory.video,
          stackTrace: entry.stackTrace == null
              ? null
              : StackTrace.fromString(entry.stackTrace!),
        );
      case NativeLogLevel.warning:
        Log.warning(entry.message, name: name, category: LogCategory.video);
      case NativeLogLevel.debug:
        Log.debug(entry.message, name: name, category: LogCategory.video);
      case NativeLogLevel.verbose:
        Log.verbose(entry.message, name: name, category: LogCategory.video);
      case NativeLogLevel.info:
      case NativeLogLevel.none:
        Log.info(entry.message, name: name, category: LogCategory.video);
    }
  }
}
