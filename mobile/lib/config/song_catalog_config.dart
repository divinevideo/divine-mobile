// ABOUTME: Build-time configuration for the experimental song catalog.
// ABOUTME: The Apple Music developer token comes from a dart-define, never
// ABOUTME: from source.

/// Configuration for the song catalog behind the sound picker's Songs list.
abstract final class SongCatalogConfig {
  /// The signed MusicKit developer token the Apple Music API asks for.
  ///
  /// Set via: --dart-define=APPLE_MUSIC_DEVELOPER_TOKEN=xxx
  static const developerToken = String.fromEnvironment(
    'APPLE_MUSIC_DEVELOPER_TOKEN',
  );

  /// Whether this build carries a developer token. Without one the catalog
  /// cannot be read, so the feature is not offered at all.
  static const isConfigured = developerToken != '';
}
