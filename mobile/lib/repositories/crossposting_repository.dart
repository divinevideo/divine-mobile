// ABOUTME: Aggregates crossposter platform, connection, and preference data
// ABOUTME: Exposes immutable settings values and crossposting mutations

import 'package:equatable/equatable.dart';
import 'package:openvine/services/crossposting_api_client.dart';

export 'package:openvine/services/crossposting_api_client.dart'
    show CrosspostingMode, CrosspostingPlatform;

/// User-visible crossposting state for one enabled platform.
class CrosspostingPlatformSettings extends Equatable {
  const CrosspostingPlatformSettings({
    required this.platform,
    required this.supportsAutomatic,
    required this.mode,
    this.connection,
  });

  final CrosspostingPlatform platform;
  final bool supportsAutomatic;
  final CrosspostingConnection? connection;
  final CrosspostingMode mode;

  bool get isConnected =>
      connection?.status == CrosspostingConnectionStatus.connected;

  bool get needsReauth =>
      connection?.status == CrosspostingConnectionStatus.needsReauth;

  CrosspostingPlatformSettings copyWith({CrosspostingMode? mode}) {
    return CrosspostingPlatformSettings(
      platform: platform,
      supportsAutomatic: supportsAutomatic,
      connection: connection,
      mode: mode ?? this.mode,
    );
  }

  @override
  List<Object?> get props => [
    platform,
    supportsAutomatic,
    connection,
    mode,
  ];
}

/// Coordinates crossposter reads and writes for the settings feature.
class CrosspostingRepository {
  const CrosspostingRepository(this._apiClient);

  final CrosspostingApiClient _apiClient;

  /// Loads all settings data in strict sequence.
  ///
  /// Each request can refresh the same rotating Keycast token, so these calls
  /// must never run concurrently.
  Future<List<CrosspostingPlatformSettings>> loadSettings() async {
    final platforms = await _apiClient.getPlatforms();
    final connections = await _apiClient.getConnections();
    final preferences = await _apiClient.getPreferences();

    return [
      for (final platformInfo in platforms)
        if (platformInfo.enabled && platformInfo.platform.isVisibleInApp)
          _settingsFor(platformInfo, connections, preferences),
    ];
  }

  CrosspostingPlatformSettings _settingsFor(
    CrosspostingPlatformInfo platformInfo,
    List<CrosspostingConnection> connections,
    List<CrosspostingPreference> preferences,
  ) {
    final preference = _preferenceFor(
      preferences,
      platformInfo.platform,
    );
    // Degrade a stale automatic preference instead of failing the whole load:
    // one inconsistent server value must never brick the settings screen.
    // The user can still pick any supported mode; clamping to manual keeps the
    // platform reachable while surfaces that hide the automatic chip stay
    // driven by [CrosspostingPlatformSettings.supportsAutomatic].
    final mode =
        !platformInfo.supportsAutomatic &&
            preference?.mode == CrosspostingMode.automatic
        ? CrosspostingMode.manual
        : (preference?.mode ?? CrosspostingMode.disabled);
    return CrosspostingPlatformSettings(
      platform: platformInfo.platform,
      supportsAutomatic: platformInfo.supportsAutomatic,
      connection: _connectionFor(
        connections,
        platformInfo.platform,
        preference?.connectionId,
      ),
      mode: mode,
    );
  }

  CrosspostingConnection? _connectionFor(
    List<CrosspostingConnection> connections,
    CrosspostingPlatform platform,
    String? preferredConnectionId,
  ) {
    CrosspostingConnection? preferredNeedsReauth;
    if (preferredConnectionId != null) {
      for (final connection in connections) {
        if (connection.platform != platform ||
            connection.id != preferredConnectionId) {
          continue;
        }
        if (connection.status == CrosspostingConnectionStatus.connected) {
          return connection;
        }
        if (connection.status == CrosspostingConnectionStatus.needsReauth) {
          preferredNeedsReauth = connection;
        }
        break;
      }
    }

    CrosspostingConnection? needsReauth;
    for (final connection in connections) {
      if (connection.platform != platform) continue;
      switch (connection.status) {
        case CrosspostingConnectionStatus.connected:
          return connection;
        case CrosspostingConnectionStatus.needsReauth:
          needsReauth ??= connection;
        case CrosspostingConnectionStatus.disconnected:
          break;
      }
    }
    return preferredNeedsReauth ?? needsReauth;
  }

  CrosspostingPreference? _preferenceFor(
    List<CrosspostingPreference> preferences,
    CrosspostingPlatform platform,
  ) {
    for (final preference in preferences) {
      if (preference.platform == platform) return preference;
    }
    return null;
  }

  Future<CrosspostingStart> startConnection(
    CrosspostingPlatform platform, {
    required Uri returnUrl,
  }) {
    return _apiClient.startConnection(platform, returnUrl: returnUrl);
  }

  Future<void> disconnect(
    CrosspostingPlatform platform,
    String connectionId,
  ) {
    return _apiClient.disconnect(platform, connectionId);
  }

  Future<void> setMode(
    CrosspostingPlatform platform,
    CrosspostingMode mode,
  ) {
    return _apiClient.setMode(platform, mode);
  }
}
