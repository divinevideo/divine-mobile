// ABOUTME: Structured, injectable relay diagnostics for SDK consumers.
// ABOUTME: Keeps support logging policy outside nostr_sdk's dependency graph.

import 'dart:developer' as developer;

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
class RelayDiagnostic {
  const RelayDiagnostic({
    required this.site,
    required this.level,
    required this.relayUrl,
    required this.message,
    this.error,
    this.stackTrace,
  });

  final RelayDiagnosticSite site;
  final RelayDiagnosticLevel level;
  final String relayUrl;
  final String message;
  final Object? error;
  final StackTrace? stackTrace;
}

/// Receives structured relay diagnostics from nostr_sdk.
typedef RelayDiagnosticsSink = void Function(RelayDiagnostic diagnostic);

/// Emits [diagnostic] without allowing observability failures to affect I/O.
void emitRelayDiagnostic(
  RelayDiagnosticsSink? sink,
  RelayDiagnostic diagnostic,
) {
  try {
    if (sink != null) {
      sink(diagnostic);
      return;
    }
    developer.log(
      diagnostic.message,
      name: 'RelayDiagnostics',
      error: diagnostic.error,
      stackTrace: diagnostic.stackTrace,
    );
  } on Object catch (_) {
    // Diagnostics are best-effort and must never change relay behavior.
  }
}
