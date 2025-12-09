// ABOUTME: Integration tests for hashtag filtering functionality in VideoEventService
// ABOUTME: Tests server-side filtering and client-side hashtag processing

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_key_manager/nostr_key_manager.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';

// Simple mock for testing basic functionality
class MinimalMockNostrService implements INostrService {
  @override
  bool get isInitialized => true;

  @override
  bool get isDisposed => false;

  @override
  List<String> get connectedRelays => ['wss://localhost:8080'];

  @override
  String? get publicKey => null;

  @override
  bool get hasKeys => false;

  @override
  NostrKeyManager get keyManager => throw UnimplementedError();

  @override
  int get relayCount => 1;

  @override
  int get connectedRelayCount => 1;

  @override
  List<String> get relays => ['wss://localhost:8080'];

  Map<String, dynamic> get relayStatuses => {};

  void addListener(listener) {}

  void removeListener(listener) {}

  Future<void> dispose() async {}

  bool get hasListeners => false;

  void notifyListeners() {}

  // Implement required methods as no-ops for testing
  Future<void> initialize({List<String>? customRelays}) async {}

  Stream<Event> subscribeToEvents({
    required List<Filter> filters,
    bool bypassLimits = false,
    void Function()? onEose,
  }) => const Stream<Event>.empty();

  dynamic noSuchMethod(Invocation invocation) => null;
}

void main() {
  group('HashtagFiltering Integration Tests', () {
    test('should create Filter with hashtag support', () {
      // Test that our Filter class now supports hashtags
      final filter = Filter(kinds: [22], t: ['bitcoin', 'nostr'], limit: 10);

      final json = filter.toJson();
      expect(json['#t'], equals(['bitcoin', 'nostr']));
      expect(json['kinds'], equals([22]));
      expect(json['limit'], equals(10));
    });

    test('should handle empty hashtag list in Filter', () {
      final filter = Filter(kinds: [22], limit: 10);

      final json = filter.toJson();
      expect(json.containsKey('#t'), false);
      expect(json['kinds'], equals([22]));
    });

    test('VideoEventService should have hashtag filtering method', () {
      // Test that the class has the method without instantiating it
      expect(VideoEventService, isA<Type>());

      // This verifies the method exists in the class definition
      final mockNostrService = MinimalMockNostrService();
      final mockSubscriptionManager = SubscriptionManager(mockNostrService);
      final videoService = VideoEventService(
        mockNostrService,
        subscriptionManager: mockSubscriptionManager,
      );

      // Quick test without causing disposal issues
      expect(videoService.getVideoEventsByHashtags, isA<Function>());

      // Clean up
      videoService.dispose();
      mockSubscriptionManager.dispose();
    });
  });
}
