// ABOUTME: Mock implementation of Nostr service for testing camera screen functionality
// ABOUTME: Provides controllable mock behavior for testing various service states

import 'package:nostr_client/nostr_client.dart';

class MockNostrService implements NostrClient {
  bool _isInitialized = false;
  String? _lastError;

  @override
  bool get isInitialized => _isInitialized;

  @override
  Future<void> initialize({List<String>? customRelays}) async {
    // Simulate initialization delay
    await Future.delayed(const Duration(milliseconds: 100));
    _isInitialized = true;
  }

  @override
  Future<void> dispose() async {
    _isInitialized = false;
  }

  // Mock methods to control test behavior
  void setInitialized(bool value) {
    _isInitialized = value;
  }

  void setError(String? error) {
    _lastError = error;
  }

  String? get lastError => _lastError;

  // Implement other required interface methods as no-ops for testing
  @override
  dynamic noSuchMethod(Invocation invocation) => null;
}
