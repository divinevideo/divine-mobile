// ABOUTME: SharedPreferences implementation of RelayStorage for persistence.
// ABOUTME: Stores configured relay URLs as a string list.

import 'package:nostr_client/src/models/relay_manager_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// {@template shared_preferences_relay_storage}
/// SharedPreferences implementation of [RelayStorage].
///
/// Persists relay URLs to device storage using SharedPreferences.
/// This is the recommended storage implementation for production use.
///
/// Example:
/// ```dart
/// final storage = SharedPreferencesRelayStorage();
/// final relayManager = RelayManager(
///   config: RelayManagerConfig(
///     defaultRelayUrl: 'wss://relay.example.com',
///     storage: storage,
///   ),
/// );
/// ```
/// {@endtemplate}
class SharedPreferencesRelayStorage implements RelayStorage {
  /// {@macro shared_preferences_relay_storage}
  ///
  /// [key] is the SharedPreferences key to use for storage.
  /// Defaults to 'configured_relays'.
  SharedPreferencesRelayStorage({String? key}) : _key = key ?? _defaultKey;

  static const String _defaultKey = 'configured_relays';
  final String _key;

  @override
  Future<List<String>> loadRelays() async {
    final prefs = await SharedPreferences.getInstance();
    final relays = prefs.getStringList(_key);
    return relays != null ? List<String>.from(relays) : <String>[];
  }

  @override
  Future<void> saveRelays(List<String> relayUrls) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, relayUrls);
  }
}
