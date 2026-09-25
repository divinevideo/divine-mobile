// ABOUTME: Analytics for crossposting call-to-action taps.
// ABOUTME: Fire-and-forget; a failed log must never break a CTA.

import 'package:analytics/analytics.dart';
import 'package:unified_logger/unified_logger.dart';

/// Records a crossposting CTA tap. [surface] is `settings` or `share_sheet`.
Future<void> logCrosspostCtaTapped(
  AnalyticsEventSink sink,
  String surface,
) async {
  try {
    await sink.logEvent(
      name: 'crosspost_cta_tapped',
      parameters: {'surface': surface},
    );
  } catch (error, stackTrace) {
    Log.warning(
      'Crosspost CTA analytics failed: $error',
      name: 'CrosspostingAnalytics',
      category: LogCategory.ui,
      stackTrace: stackTrace,
    );
  }
}
