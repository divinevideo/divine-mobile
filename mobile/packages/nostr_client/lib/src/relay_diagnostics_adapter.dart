// ABOUTME: Bounds relay diagnostics before forwarding them to support logs.
// ABOUTME: Adapts nostr_sdk's logging port to the shared UnifiedLogger.

import 'dart:collection';

import 'package:meta/meta.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:unified_logger/unified_logger.dart';

/// Supplies the current time for deterministic diagnostic-window tests.
typedef RelayDiagnosticsClock = DateTime Function();

/// Bounds structured relay diagnostics and forwards them to support logs.
class RelayDiagnosticsAdapter {
  /// Creates a relay diagnostics adapter.
  RelayDiagnosticsAdapter({
    this.maxEventsPerWindow = 3,
    this.window = const Duration(minutes: 1),
    this.maxTrackedKeys = 256,
    RelayDiagnosticsClock? clock,
  }) : _clock = clock ?? DateTime.now;

  /// Maximum entries emitted for one relay and site in a window.
  final int maxEventsPerWindow;

  /// Duration of one suppression window.
  final Duration window;

  /// Maximum relay/site keys retained by the limiter.
  final int maxTrackedKeys;
  final RelayDiagnosticsClock _clock;
  final LinkedHashMap<_DiagnosticKey, _DiagnosticWindow> _windows =
      LinkedHashMap<_DiagnosticKey, _DiagnosticWindow>();

  /// Accepts one structured relay diagnostic.
  void call(RelayDiagnostic diagnostic) {
    final now = _clock();
    final key = _DiagnosticKey(diagnostic.relayUrl, diagnostic.site);
    var state = _windows.remove(key);

    final elapsed = state == null
        ? Duration.zero
        : now.difference(state.startedAt);

    if (state == null || elapsed >= window) {
      if (state != null && state.suppressed > 0) {
        _write(
          RelayDiagnostic(
            site: diagnostic.site,
            level: RelayDiagnosticLevel.info,
            relayUrl: diagnostic.relayUrl,
            message:
                'Suppressed ${state.suppressed} repeated '
                '${diagnostic.site.name} diagnostics in the '
                '${elapsed.inSeconds} seconds since '
                '${state.startedAt.toUtc().toIso8601String()}',
          ),
        );
      }
      state = _DiagnosticWindow(startedAt: now);
    }

    _windows[key] = state;
    while (_windows.length > maxTrackedKeys) {
      _windows.remove(_windows.keys.first);
    }

    if (state.emitted >= maxEventsPerWindow) {
      state.suppressed++;
      return;
    }
    state.emitted++;
    _write(diagnostic);
  }

  void _write(RelayDiagnostic diagnostic) {
    final message = '[${diagnostic.relayUrl}] ${diagnostic.message}';
    switch (diagnostic.level) {
      case RelayDiagnosticLevel.debug:
        Log.debug(
          message,
          name: 'RelayDiagnostics',
          category: LogCategory.relay,
        );
      case RelayDiagnosticLevel.info:
        Log.info(
          message,
          name: 'RelayDiagnostics',
          category: LogCategory.relay,
        );
      case RelayDiagnosticLevel.warning:
        Log.warning(
          message,
          name: 'RelayDiagnostics',
          category: LogCategory.relay,
        );
      case RelayDiagnosticLevel.error:
        Log.error(
          message,
          name: 'RelayDiagnostics',
          category: LogCategory.relay,
        );
    }
  }
}

@immutable
class _DiagnosticKey {
  const _DiagnosticKey(this.relayUrl, this.site);

  final String relayUrl;
  final RelayDiagnosticSite site;

  @override
  bool operator ==(Object other) =>
      other is _DiagnosticKey &&
      relayUrl == other.relayUrl &&
      site == other.site;

  @override
  int get hashCode => Object.hash(relayUrl, site);
}

class _DiagnosticWindow {
  _DiagnosticWindow({required this.startedAt});

  final DateTime startedAt;
  int emitted = 0;
  int suppressed = 0;
}
