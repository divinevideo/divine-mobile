// ABOUTME: Analytics for crossposting call-to-action and connect lifecycles.
// ABOUTME: Fire-and-forget; a failed log must never break crossposting UI.

import 'package:analytics/analytics.dart';
import 'package:openvine/services/crossposting_api_client.dart';
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
  /// The share-menu entry, before connection status is known.
  crosspostRow('crosspost_row'),

  /// Connect a first platform.
  connect('connect'),

  /// Switch a connected platform to automatic crossposting.
  automaticMode('automatic_mode');

  const CrosspostCta(this.wireName);

  /// The `cta` parameter value sent to analytics.
  final String wireName;
}

/// Terminal result of an external-platform connection attempt.
enum CrosspostConnectResult {
  connected('connected'),
  denied('denied'),
  failed('failed'),
  cancelled('cancelled'),
  timedOut('timed_out'),

  /// The settings screen closed before the attempt reached a result.
  abandoned('abandoned');

  const CrosspostConnectResult(this.wireName);

  /// The `result` parameter value sent to analytics.
  final String wireName;
}

/// Records that a crossposting CTA became visible.
Future<void> logCrosspostCtaShown(
  AnalyticsEventSink sink, {
  required CrosspostCtaSurface surface,
  required CrosspostCta cta,
}) => _logCrosspostingEvent(
  sink,
  name: 'crosspost_cta_shown',
  parameters: {'surface': surface.wireName, 'cta': cta.wireName},
);

/// Records a tap on a crossposting CTA.
///
/// The share-menu row uses [CrosspostCta.crosspostRow] regardless of connection
/// status; settings retains the connect and automatic-mode distinctions.
Future<void> logCrosspostCtaTapped(
  AnalyticsEventSink sink, {
  required CrosspostCtaSurface surface,
  required CrosspostCta cta,
}) => _logCrosspostingEvent(
  sink,
  name: 'crosspost_cta_tapped',
  parameters: {'surface': surface.wireName, 'cta': cta.wireName},
);

/// Records the start of an external-platform connection attempt.
Future<void> logCrosspostConnectStarted(
  AnalyticsEventSink sink, {
  required CrosspostingPlatform platform,
}) => _logCrosspostingEvent(
  sink,
  name: 'crosspost_connect_started',
  parameters: {'platform': platform.wireName},
);

/// Records the terminal result of an external-platform connection attempt.
Future<void> logCrosspostConnectResult(
  AnalyticsEventSink sink, {
  required CrosspostingPlatform platform,
  required CrosspostConnectResult result,
}) => _logCrosspostingEvent(
  sink,
  name: 'crosspost_connect_result',
  parameters: {'platform': platform.wireName, 'result': result.wireName},
);

Future<void> _logCrosspostingEvent(
  AnalyticsEventSink sink, {
  required String name,
  required Map<String, Object> parameters,
}) async {
  try {
    await sink.logEvent(name: name, parameters: parameters);
  } catch (error, stackTrace) {
    Log.warning(
      'Crossposting analytics failed: $error',
      name: 'CrosspostingAnalytics',
      category: LogCategory.ui,
      stackTrace: stackTrace,
    );
  }
}
