// ABOUTME: Structured, injectable relay diagnostics for SDK consumers.
// ABOUTME: Keeps support logging policy outside nostr_sdk's dependency graph.

/// Severity of a relay diagnostic.
enum RelayDiagnosticLevel { debug, info, warning, error }

/// Stable diagnostic shapes used for volume bounding and support triage.
enum RelayDiagnosticSite {
  connectionLifecycle,
  subscriptionReplay,
  queryDispatch,
  requestSettlement,
  authentication,
  notice,
}

/// A safe, structured description of relay activity.
///
/// [error] and [stackTrace] are available to SDK consumers that inject a sink,
/// but support exporters must not serialize either value. The Divine support
/// adapter exports only [error]'s runtime type as a bounded failure category.
class RelayDiagnostic {
  const RelayDiagnostic({
    required this.site,
    required this.level,
    required this.relayUrl,
    required this.message,
    this.error,
    this.stackTrace,
  });

  /// Reserved [relayUrl] value for a diagnostic about the pool as a whole.
  ///
  /// Real relay diagnostics always carry their WebSocket URL. Pool-level
  /// summaries use this stable key so consumers can group and rate-limit them
  /// without presenting it as a configured relay.
  static const String poolScope = 'relay-pool';

  final RelayDiagnosticSite site;
  final RelayDiagnosticLevel level;

  /// The relay WebSocket URL, or [poolScope] for a pool-level summary.
  final String relayUrl;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;
}

/// Receives structured relay diagnostics from nostr_sdk.
///
/// A null sink disables this structured channel. Console logging is owned by
/// relay call sites so diagnostics never duplicate an existing console entry.
typedef RelayDiagnosticsSink = void Function(RelayDiagnostic diagnostic);

/// Emits [diagnostic] to [sink] without allowing observability failures to
/// affect relay I/O.
void emitRelayDiagnostic(
  RelayDiagnosticsSink? sink,
  RelayDiagnostic diagnostic,
) {
  if (sink == null) return;
  try {
    sink(diagnostic);
  } on Object catch (_) {
    // Diagnostics are best-effort and must never change relay behavior.
  }
}
