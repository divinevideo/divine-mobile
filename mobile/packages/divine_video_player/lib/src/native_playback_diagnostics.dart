// ABOUTME: Value-only Apple process memory and native player resource gauges.
// ABOUTME: Reads without creating players; older binaries report unavailable.

import 'package:flutter/services.dart';

/// Process-wide Apple gauges, not the Dart isolate's controller count.
///
/// Only the fixed schema below crosses into diagnostics; never URLs, player
/// labels, account identifiers, or arbitrary platform error messages.
class NativePlaybackDiagnostics {
  NativePlaybackDiagnostics._(this._values);

  final Map<String, Object> _values;
  static const _channel = MethodChannel('divine_video_player');
  static const _gauges = [
    'registeredPlayers',
    'liveInstances',
    'players',
    'playingPlayers',
    'textures',
    'pendingLoads',
    'disposedPlayers',
    'framesDelivered',
  ];

  /// Parses the versioned channel response, or returns null when incompatible.
  static NativePlaybackDiagnostics? fromMap(Map<Object?, Object?> values) {
    if (values['version'] != 1 ||
        !const ['ios', 'ios_on_mac', 'macos'].contains(values['platform']) ||
        !const [
          'active',
          'inactive',
          'background',
          'unknown',
        ].contains(values['appState'])) {
      return null;
    }
    final footprint = values['footprintBytes'];
    if (footprint is! int || footprint < -1) return null;
    final parsed = <String, Object>{
      'version': 1,
      'platform': values['platform']! as String,
      'appState': values['appState']! as String,
      'footprintBytes': footprint,
    };
    for (final key in _gauges) {
      final value = values[key];
      if (value is! int || value < 0) return null;
      parsed[key] = value;
    }
    return NativePlaybackDiagnostics._(parsed);
  }

  /// Returns null for unsupported platforms/older native binaries.
  ///
  /// Throws [PlatformException] if the platform call fails. Sampling owns
  /// failure isolation and timeout policy; unavailable is never zero.
  static Future<NativePlaybackDiagnostics?> read() async {
    try {
      final values = await _channel.invokeMapMethod<Object?, Object?>(
        'getDiagnostics',
      );
      return values == null ? null : fromMap(values);
    } on MissingPluginException {
      return null;
    }
  }

  /// Current physical footprint in bytes, or -1 if the OS probe failed.
  int get footprintBytes => _values['footprintBytes']! as int;

  /// Disposed instances still owning AVQueuePlayers.
  /// Includes instances already removed from the registry.
  int get disposedPlayers => _values['disposedPlayers']! as int;

  /// In-progress asynchronous clip loads across all weakly tracked instances.
  int get pendingLoads => _values['pendingLoads']! as int;

  /// Cumulative delivered texture frames, including players already destroyed.
  int get framesDelivered => _values['framesDelivered']! as int;

  /// A copy of the allow-listed diagnostic fields.
  Map<String, Object> toMap() => Map.of(_values);
}
