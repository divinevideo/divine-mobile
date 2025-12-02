// ABOUTME: Configuration for Zendesk Support SDK credentials
// ABOUTME: Loads from build-time environment variables to keep secrets out of source

/// Zendesk Support SDK configuration
class ZendeskConfig {
  /// Zendesk Mobile SDK "Application ID"
  /// Get from: Admin → Channels → Mobile SDK
  /// Set via: --dart-define=ZENDESK_APP_ID=xxx
  static const String appId = String.fromEnvironment(
    'ZENDESK_APP_ID',
    defaultValue: '',
  );

  /// App identifier for Zendesk (can be any string, e.g., "divine.video")
  /// Get from: Admin → Channels → Mobile SDK
  /// Set via: --dart-define=ZENDESK_CLIENT_ID=xxx
  static const String clientId = String.fromEnvironment(
    'ZENDESK_CLIENT_ID',
    defaultValue: '',
  );

  /// Zendesk instance URL
  /// Set via: --dart-define=ZENDESK_URL=xxx
  static const String zendeskUrl = String.fromEnvironment(
    'ZENDESK_URL',
    defaultValue: 'https://rabblelabs.zendesk.com',
  );

  /// Zendesk API token for REST API (used when native SDK unavailable)
  /// Get from: Admin → Channels → API → Add API Token
  /// Set via: --dart-define=ZENDESK_API_TOKEN=xxx
  static const String apiToken = String.fromEnvironment(
    'ZENDESK_API_TOKEN',
    defaultValue: '',
  );

  /// Email for API authentication (used with API token)
  /// Set via: --dart-define=ZENDESK_API_EMAIL=xxx
  static const String apiEmail = String.fromEnvironment(
    'ZENDESK_API_EMAIL',
    defaultValue: 'support@divine.video',
  );

  /// Check if REST API is configured
  static bool get isRestApiConfigured => apiToken.isNotEmpty;
}
