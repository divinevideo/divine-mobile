// ABOUTME: Analytics for crossposting call-to-action taps.
// ABOUTME: Fire-and-forget; a failed log must never break a CTA.

import 'package:analytics/analytics.dart';
import 'package:unified_logger/unified_logger.dart';

/// Where a crossposting CTA is shown.
enum CrosspostCtaSurface {
  settings('settings'),
  shareSheet('share_sheet');

  const CrosspostCtaSurface(this.wireName);

  /// The `surface` parameter value sent to analytics.
  final String wireName;
}

/// Which crossposting CTA was tapped.
enum CrosspostCta {
  /// Connect a first platform.
  connect('connect'),

  /// Switch a connected platform to automatic crossposting.
  automaticMode('automatic_mode');

  const CrosspostCta(this.wireName);

  /// The `cta` parameter value sent to analytics.
  final String wireName;
}

/// Records a tap on a crossposting CTA.
///
/// Log only taps that act as a call to action. Using the share-menu Crosspost
/// row to crosspost through an existing connection is not a CTA tap.
Future<void> logCrosspostCtaTapped(
  AnalyticsEventSink sink, {
  required CrosspostCtaSurface surface,
  required CrosspostCta cta,
}) async {
  try {
    await sink.logEvent(
      name: 'crosspost_cta_tapped',
      parameters: {'surface': surface.wireName, 'cta': cta.wireName},
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
