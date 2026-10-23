import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:openvine/config/bug_report_config.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/observability/crash_reporter.dart';
import 'package:openvine/observability/reportable_error.dart';
import 'package:pro_video_editor/pro_video_editor.dart';
import 'package:unified_logger/unified_logger.dart';

/// Forwards native diagnostics emitted by `pro_video_editor` (the renderer,
/// thumbnail, metadata and audio operations) into the app's [UnifiedLogger].
/// Warnings and errors also become sanitized crash-report breadcrumbs, so
/// video-editor failures retain native diagnostic context.
///
/// Native forwarding is gated per call by the `nativeLogLevel` argument passed
/// to each operation. The plugin's stream stays empty on Web, Windows, and
/// Linux.
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

  /// Forwards one [NativeLogEntry] to local and crash-report logging.
  @visibleForTesting
  static void forwardEntry(
    NativeLogEntry entry, {
    CrashReporter crashReporter = const SilentCrashReporter(),
  }) {
    if (entry.message.isEmpty) return;
    final name = _redact(
      (entry.tag?.isNotEmpty ?? false) ? entry.tag! : 'ProVideoEditorNative',
    );
    // Redact before either sink: the local capture also retains native logs.
    final message = _redact(entry.message);
    final stack = entry.stackTrace == null ? null : _redact(entry.stackTrace!);
    // The final render owns the non-fatal report. Native fallback attempts
    // contribute context without each becoming a separate crash issue.
    if (entry.level == NativeLogLevel.warning ||
        entry.level == NativeLogLevel.error) {
      // A native message can quote a file's path, and a kept video DM's path
      // names the account and the message.
      crashReporter.log(
        sanitizeForCrashReport(
          '[$name] $message'
          '${stack == null || stack.isEmpty ? '' : '\n$stack'}',
        ),
      );
    }
    switch (entry.level) {
      case NativeLogLevel.error:
        Log.error(
          message,
          name: name,
          category: LogCategory.video,
          stackTrace: stack == null ? null : StackTrace.fromString(stack),
        );
      case NativeLogLevel.warning:
        Log.warning(message, name: name, category: LogCategory.video);
      case NativeLogLevel.debug:
        Log.debug(message, name: name, category: LogCategory.video);
      case NativeLogLevel.verbose:
        Log.verbose(message, name: name, category: LogCategory.video);
      case NativeLogLevel.info:
      case NativeLogLevel.none:
        Log.info(message, name: name, category: LogCategory.video);
    }
  }

  // A kept video DM's files are named after its message, and an iOS file
  // error quotes that name without the path around it. A render cache file
  // named after its hash looks the same and is hidden too; a task id that
  // carries the hash is not, since only a name followed by a dot is. A clip
  // added from a DM carries the message id in its own id, which a render can
  // use as its task id.
  static final _messageNamedFile = RegExp(
    r'(?<![A-Za-z0-9])[A-Za-z0-9]{64}(?=\.)|'
    '${DivineVideoClip.receivedDmClipIdPrefix}[A-Za-z0-9]{64}',
  );

  static String _redact(String text) => redactFilesystemPaths(
    text,
  ).replaceAll(_messageNamedFile, '[REDACTED]');
}
