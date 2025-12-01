// ABOUTME: Mock implementation of SubscriptionManager for testing
// ABOUTME: Provides controlled subscription behavior without real Nostr connections

import 'dart:async';

import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/subscription_manager.dart';

class MockSubscriptionManager extends SubscriptionManager {
  MockSubscriptionManager(super.nostrService);
  final Map<String, StreamController<Event>> _subscriptions = {};
  final Map<String, Filter> _filters = {};
  int _subscriptionCounter = 0;

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
    final id = 'mock_sub_${_subscriptionCounter++}';
    final controller = StreamController<Event>.broadcast();

    _subscriptions[id] = controller;
    _filters[id] = filters.first;

    // Set up listeners
    controller.stream.listen(onEvent, onError: onError, onDone: onComplete);

    // Auto-complete after timeout if specified
    if (timeout != null) {
      Future.delayed(timeout, () {
        if (_subscriptions.containsKey(id)) {
          completeSubscription(id);
        }
      });
    }

    return id;
  }

  @override
  Future<void> cancelSubscription(String subscriptionId) async {
    final controller = _subscriptions.remove(subscriptionId);
    await controller?.close();
    _filters.remove(subscriptionId);
  }

  void completeSubscription(String subscriptionId) {
    final controller = _subscriptions[subscriptionId];
    if (controller != null && !controller.isClosed) {
      controller.close();
    }
  }

  void emitEvent(String subscriptionId, Event event) {
    final controller = _subscriptions[subscriptionId];
    if (controller != null && !controller.isClosed) {
      controller.add(event);
    }
  }

  @override
  Future<void> dispose() async {
    for (final controller in _subscriptions.values) {
      controller.close();
    }
    _subscriptions.clear();
    _filters.clear();
    super.dispose();
  }
}
