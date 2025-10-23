// ABOUTME: Helper utilities for managing Nostr subscriptions with proper completion handling
// ABOUTME: Provides patterns for querying event counts and handling subscription lifecycle

import 'dart:async';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/subscription_manager.dart';

/// Utilities for common subscription patterns and event counting
class SubscriptionUtils {
  /// Queries event count with proper completion handling
  ///
  /// Creates a subscription, counts events as they arrive, and completes
  /// when the relay signals EOSE (end of stored events).
  ///
  /// Parameters:
  /// - [subscriptionManager]: Manager to create the subscription with
  /// - [name]: Unique subscription name
  /// - [filters]: Nostr filters to apply
  /// - [priority]: Subscription priority (lower = higher priority)
  /// - [timeout]: Max time to wait for completion
  /// - [countMapper]: Optional function to extract count from event (e.g., for Kind 7 reactions, return count tag value)
  ///
  /// Returns the total count when EOSE is received or timeout occurs.
  /// On error, returns partial count collected so far.
  static Future<int> queryEventCount({
    required SubscriptionManager subscriptionManager,
    required String name,
    required List<Filter> filters,
    required int priority,
    required Duration timeout,
    int Function(Event)? countMapper,
  }) async {
    final completer = Completer<int>();
    var count = 0;

    await subscriptionManager.createSubscription(
      name: name,
      filters: filters,
      onEvent: (event) {
        if (countMapper != null) {
          count += countMapper(event);
        } else {
          count++;
        }
      },
      onComplete: () {
        if (!completer.isCompleted) {
          completer.complete(count);
        }
      },
      onError: (error) {
        if (!completer.isCompleted) {
          // Return partial count on error rather than throwing
          completer.complete(count);
        }
      },
      timeout: timeout,
      priority: priority,
    );

    return completer.future;
  }
}
