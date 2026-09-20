// ABOUTME: Screen-reader announcement helper that owns its detached future
// ABOUTME: Pairs SemanticsService.sendAnnouncement with the caller's log route

import 'package:flutter/semantics.dart' show SemanticsService;
import 'package:flutter/widgets.dart';
import 'package:openvine/utils/detached_future.dart';
import 'package:unified_logger/unified_logger.dart';

/// Announces [message] to screen readers without awaiting the platform call.
///
/// Holds the two lookups every call site would otherwise repeat. The reading
/// direction comes from [Directionality] rather than a hardcoded
/// [TextDirection], which is what the RTL locales depend on.
///
/// [description] names the operation in the failure log (for example
/// `'announce list deletion'`); [logName] routes that log the same way the
/// caller's other [Log] calls do.
void announceDetached(
  BuildContext context,
  String message, {
  required String description,
  required String logName,
}) {
  runDetached(
    SemanticsService.sendAnnouncement(
      View.of(context),
      message,
      Directionality.of(context),
    ),
    description,
    logName: logName,
    category: LogCategory.ui,
  );
}
