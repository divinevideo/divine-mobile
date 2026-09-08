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

  /// Maximum entries emitted for one relay, site, and level in a window.
  final int maxEventsPerWindow;

  /// Duration of one suppression window.
  final Duration window;

  /// Maximum relay/site/level keys retained by the limiter.
  final int maxTrackedKeys;
  final RelayDiagnosticsClock _clock;
  final LinkedHashMap<_DiagnosticKey, _DiagnosticWindow> _windows =
      LinkedHashMap<_DiagnosticKey, _DiagnosticWindow>();

  /// Accepts one structured relay diagnostic.
  void call(RelayDiagnostic diagnostic) {
    final now = _clock();
    final key = _DiagnosticKey(
      diagnostic.relayUrl,
      diagnostic.site,
      diagnostic.level,
    );
    var state = _windows.remove(key);

    final elapsed = state == null
        ? Duration.zero
        : now.difference(state.startedAt);

    if (state == null || elapsed >= window) {
      if (state != null) _writeSuppressionSummary(key, state);
      state = _DiagnosticWindow(startedAt: now);
    }

    _windows[key] = state;
    while (_windows.length > maxTrackedKeys) {
      final evictedKey = _windows.keys.first;
      final evictedState = _windows.remove(evictedKey)!;
      _writeSuppressionSummary(evictedKey, evictedState);
    }

    if (state.emitted >= maxEventsPerWindow) {
      state.suppressed++;
      if (state.suppressed == 1) {
        _write(
          RelayDiagnostic(
            site: diagnostic.site,
            level: diagnostic.level,
            relayUrl: diagnostic.relayUrl,
            message:
                'Further ${diagnostic.site.name} '
                '${diagnostic.level.name} diagnostics suppressed until '
                '${state.startedAt.add(window).toUtc().toIso8601String()}',
          ),
        );
      }
      return;
    }
    state.emitted++;
    _write(diagnostic);
  }

  void _writeSuppressionSummary(
    _DiagnosticKey key,
    _DiagnosticWindow state,
  ) {
    if (state.suppressed == 0) return;
    _write(
      RelayDiagnostic(
        site: key.site,
        level: key.level,
        relayUrl: key.relayUrl,
        message:
            'Suppressed ${state.suppressed} repeated ${key.site.name} '
            '${key.level.name} diagnostics during the '
            '${window.inSeconds}-second window starting '
            '${state.startedAt.toUtc().toIso8601String()}',
      ),
    );
  }

  void _write(RelayDiagnostic diagnostic) {
    final errorType = diagnostic.error == null
        ? ''
        : ' (error type: ${diagnostic.error.runtimeType})';
    final message = '[${diagnostic.relayUrl}] ${diagnostic.message}$errorType';
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
  const _DiagnosticKey(this.relayUrl, this.site, this.level);

  final String relayUrl;
  final RelayDiagnosticSite site;
  final RelayDiagnosticLevel level;

  @override
  bool operator ==(Object other) =>
      other is _DiagnosticKey &&
      relayUrl == other.relayUrl &&
      site == other.site &&
      level == other.level;

  @override
  int get hashCode => Object.hash(relayUrl, site, level);
}

class _DiagnosticWindow {
  _DiagnosticWindow({required this.startedAt});

  final DateTime startedAt;
  int emitted = 0;
  int suppressed = 0;
}
