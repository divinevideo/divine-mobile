// ABOUTME: Provides synthetic environment configuration for route probe tests.
// ABOUTME: Kept outside test suites so CI shard pruning preserves shared fixtures.

const currentConfigFixture = r'''
const productionApiBaseUrl = 'https://api.divine.video';
enum AppEnvironment { poc, staging, production, local }
class EnvironmentConfig {
  String get relayUrl {
    switch (environment) {
      case AppEnvironment.poc: return 'wss://relay.poc.dvines.org';
      case AppEnvironment.staging: return 'wss://relay.staging.divine.video';
      case AppEnvironment.local: return 'ws://$localHost:47777';
      case AppEnvironment.production: return 'wss://relay.divine.video';
    }
  }
  String get apiBaseUrl {
    if (environment == AppEnvironment.local) return 'http://$localHost:47777';
    if (environment == AppEnvironment.production) return productionApiBaseUrl;
    final url = relayUrl;
    if (url.startsWith('wss://')) return url.replaceFirst('wss://', 'https://');
    if (url.startsWith('ws://')) return url.replaceFirst('ws://', 'http://');
    return url;
  }
}
''';
