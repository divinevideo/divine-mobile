// ABOUTME: Test helper for creating SubscriptionManager instances in tests
// ABOUTME: Provides both mock and real implementations based on test needs

import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/subscription_manager.dart';

/// Creates a mock SubscriptionManager for unit tests
class MockSubscriptionManager extends Mock implements SubscriptionManager {
  final List<String> activeSubscriptions = [];

  @override
  Future<String> createSubscription({
    required String name,
    required List<Filter> filters,
    required Function(Event) onEvent,
    Function(dynamic)? onError,
    Function()? onComplete,
    Duration? timeout,
    int priority = 5,
  }) async {
    final id = 'mock_${DateTime.now().millisecondsSinceEpoch}';
    activeSubscriptions.add(id);

    // Simulate subscription behavior
    if (timeout != null) {
      Future.delayed(timeout, () {
        if (activeSubscriptions.contains(id)) {
          onComplete?.call();
          activeSubscriptions.remove(id);
        }
      });
    }

    return id;
  }

  @override
  Future<void> cancelSubscription(String subscriptionId) async {
    activeSubscriptions.remove(subscriptionId);
  }
}

/// Creates a real SubscriptionManager for integration tests
SubscriptionManager createRealSubscriptionManager(NostrClient nostrService) =>
    SubscriptionManager(nostrService);

/// Helper to set up common mock behaviors for SubscriptionManager
void setupMockSubscriptionManager(MockSubscriptionManager mock) {
  when(
    () => mock.createSubscription(
      name: any(named: 'name'),
      filters: any(named: 'filters'),
      onEvent: any(named: 'onEvent'),
      onError: any(named: 'onError'),
      onComplete: any(named: 'onComplete'),
      timeout: any(named: 'timeout'),
      priority: any(named: 'priority'),
    ),
  ).thenAnswer((invocation) async {
    final name = invocation.namedArguments[#name] as String;
    return 'mock_sub_$name';
  });

  when(() => mock.cancelSubscription(any())).thenAnswer((_) async {});
}

/// Helper to set up MockSubscriptionManager that forwards events from a StreamController to VideoEventService
void setupMockSubscriptionManagerWithEventStream(
  MockSubscriptionManager mock,
  StreamController<Event> eventStreamController,
) {
  when(
    () => mock.createSubscription(
      name: any(named: 'name'),
      filters: any(named: 'filters'),
      onEvent: any(named: 'onEvent'),
      onError: any(named: 'onError'),
      onComplete: any(named: 'onComplete'),
      timeout: any(named: 'timeout'),
      priority: any(named: 'priority'),
    ),
  ).thenAnswer((invocation) async {
    final onEvent =
        invocation.namedArguments[const Symbol('onEvent')] as Function(Event);
    final name = invocation.namedArguments[const Symbol('name')] as String;

    // Set up a stream listener that calls onEvent for each event
    eventStreamController.stream.listen(onEvent);

    return 'mock_sub_$name';
  });

  when(() => mock.cancelSubscription(any())).thenAnswer((_) async {});
}
