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
  static const _platforms = ['ios', 'ios_on_mac', 'macos'];
  static const _appStates = ['active', 'inactive', 'background', 'unknown'];
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

  /// Memory ledgers a newer native binary adds; -1 when the OS cannot tell.
  static const _memoryLedgers = [
    'graphicsFootprintBytes',
    'mediaFootprintBytes',
    'memoryLimitRemainingBytes',
  ];

  /// Parses the versioned channel response, or returns null when incompatible.
  static NativePlaybackDiagnostics? fromMap(Map<Object?, Object?> values) {
    if (values['version'] != 1) return null;

    final platform = values['platform'];
    if (platform is! String || !_platforms.contains(platform)) return null;

    final appState = values['appState'];
    if (appState is! String || !_appStates.contains(appState)) return null;

    final footprint = values['footprintBytes'];
    if (footprint is! int || footprint < -1) return null;

    final parsed = <String, Object>{
      'version': 1,
      'platform': platform,
      'appState': appState,
      'footprintBytes': footprint,
    };
    for (final key in _gauges) {
      final value = values[key];
      if (value is! int || value < 0) return null;
      parsed[key] = value;
    }
    for (final key in _memoryLedgers) {
      final value = values[key];
      // An older native binary sends none of them.
      if (value == null) continue;
      if (value is! int || value < -1) return null;
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

  /// The part of [footprintBytes] GPU resources own, -1 when the OS cannot
  /// tell, or null from a native binary that does not report it.
  int? get graphicsFootprintBytes => _values['graphicsFootprintBytes'] as int?;

  /// The part of [footprintBytes] media buffers (decoders, encoders) own, -1
  /// when the OS cannot tell, or null from a native binary that does not
  /// report it.
  int? get mediaFootprintBytes => _values['mediaFootprintBytes'] as int?;

  /// How far [footprintBytes] may still grow before the OS ends the app, -1
  /// when the OS cannot tell, or null from a native binary that does not
  /// report it.
  int? get memoryLimitRemainingBytes =>
      _values['memoryLimitRemainingBytes'] as int?;

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
