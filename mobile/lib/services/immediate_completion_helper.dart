// ABOUTME: Helper utility for implementing immediate completion patterns in Nostr queries
// ABOUTME: Provides reusable methods for completing operations as soon as relevant data arrives

import 'dart:async';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Completion mode for different types of queries
enum CompletionMode {
  /// Complete immediately when the first matching event arrives
  first,

  /// Complete when a specific number of events are received
  count,

  /// Complete when all requested items are received (for batch requests)
  all,

  /// Complete when no more events are expected (e.g., for stats queries)
  exhaustive,
}

/// Configuration for immediate completion behavior
class CompletionConfig {
  const CompletionConfig({
    required this.mode,
    this.expectedCount,
    this.expectedItems,
    this.fallbackTimeoutSeconds = 30,
    this.logCategory = LogCategory.system,
    this.serviceName = 'ImmediateCompletion',
  });

  final CompletionMode mode;
  final int? expectedCount;
  final Set<String>?
  expectedItems; // For tracking specific items (e.g., pubkeys)
  final int fallbackTimeoutSeconds;
  final LogCategory logCategory;
  final String serviceName;
}

/// Result of an immediate completion operation
class CompletionResult<T> {
  const CompletionResult({
    required this.items,
    required this.completedEarly,
    required this.receivedCount,
    required this.expectedCount,
  });

  final List<T> items;
  final bool completedEarly; // True if completed before timeout/EOSE
  final int receivedCount;
  final int? expectedCount;
}

/// Helper class for implementing immediate completion patterns
class ImmediateCompletionHelper {
  /// Create an immediate completion subscription that completes as soon as relevant data arrives
  static StreamSubscription<Event> createImmediateSubscription({
    required Stream<Event> eventStream,
    required CompletionConfig config,
    required Function(Event) onEvent,
    required Function(CompletionResult) onComplete,
    Function(dynamic)? onError,
  }) {
    final receivedItems = <Event>[];
    final receivedItemIds = <String>{};
    late StreamSubscription<Event> subscription;
    final completer = Completer<void>();

    void tryComplete({required bool isEarly}) {
      if (completer.isCompleted) return;

      final result = CompletionResult(
        items: List.unmodifiable(receivedItems),
        completedEarly: isEarly,
        receivedCount: receivedItems.length,
        expectedCount: config.expectedCount,
      );

      Log.debug(
        '✅ Immediate completion triggered: early=$isEarly, received=${result.receivedCount}, expected=${config.expectedCount}',
        name: config.serviceName,
        category: config.logCategory,
      );

      subscription.cancel();
      completer.complete();
      onComplete(result);
    }

    subscription = eventStream.listen(
      (event) {
        // Avoid duplicates
        if (receivedItemIds.contains(event.id)) return;

        receivedItemIds.add(event.id);
        receivedItems.add(event);
        onEvent(event);

        // Check completion conditions
        switch (config.mode) {
          case CompletionMode.first:
            // Complete immediately on first event
            tryComplete(isEarly: true);
            break;

          case CompletionMode.count:
            // Complete when we have enough events
            if (config.expectedCount != null &&
                receivedItems.length >= config.expectedCount!) {
              tryComplete(isEarly: true);
            }
            break;

          case CompletionMode.all:
            // Complete when all expected items are received
            if (config.expectedItems != null) {
              final received = receivedItems
                  .map((e) => _getItemKey(e, config))
                  .toSet();
              if (received.containsAll(config.expectedItems!)) {
                tryComplete(isEarly: true);
              }
            }
            break;

          case CompletionMode.exhaustive:
            // For exhaustive mode, rely on natural stream completion
            // This is handled by onDone callback
            break;
        }
      },
      onError: (error) {
        Log.error(
          'Immediate completion subscription error: $error',
          name: config.serviceName,
          category: config.logCategory,
        );
        onError?.call(error);
        if (!completer.isCompleted) {
          subscription.cancel();
          completer.complete();
        }
      },
      onDone: () {
        // Natural stream completion (EOSE or connection closed)
        Log.debug(
          '📡 Stream completed naturally (EOSE)',
          name: config.serviceName,
          category: config.logCategory,
        );
        tryComplete(isEarly: false);
      },
    );

    // Fallback timeout for extreme edge cases
    Timer(Duration(seconds: config.fallbackTimeoutSeconds), () {
      if (!completer.isCompleted) {
        Log.debug(
          '⏰ Fallback timeout reached (${config.fallbackTimeoutSeconds}s)',
          name: config.serviceName,
          category: config.logCategory,
        );
        tryComplete(isEarly: false);
      }
    });

    return subscription;
  }

  /// Create a Future-based immediate completion query
  static Future<CompletionResult<T>> queryWithImmediateCompletion<T>({
    required Stream<Event> eventStream,
    required CompletionConfig config,
    required T Function(Event) eventMapper,
    bool Function(Event)? eventFilter,
  }) {
    final completer = Completer<CompletionResult<T>>();
    final results = <T>[];

    createImmediateSubscription(
      eventStream: eventStream,
      config: config,
      onEvent: (event) {
        if (eventFilter == null || eventFilter(event)) {
          results.add(eventMapper(event));
        }
      },
      onComplete: (result) {
        final typedResult = CompletionResult<T>(
          items: List.unmodifiable(results),
          completedEarly: result.completedEarly,
          receivedCount: results.length,
          expectedCount: result.expectedCount,
        );
        if (!completer.isCompleted) {
          completer.complete(typedResult);
        }
      },
      onError: (error) {
        if (!completer.isCompleted) {
          completer.completeError(error);
        }
      },
    );

    return completer.future;
  }

  /// Get a key for tracking specific items based on completion mode
  static String _getItemKey(Event event, CompletionConfig config) {
    switch (config.mode) {
      case CompletionMode.all:
        // For profile queries, use pubkey
        if (event.kind == 0) return event.pubkey;
        // For other queries, use event ID
        return event.id;
      default:
        return event.id;
    }
  }
}

/// Specialized helpers for common Nostr event types

class ProfileCompletionHelper {
  /// Query profiles with immediate completion
  static Future<Map<String, dynamic>> queryProfiles({
    required Stream<Event> eventStream,
    required Set<String> requestedPubkeys,
    int fallbackTimeoutSeconds = 30,
  }) async {
    final config = CompletionConfig(
      mode: CompletionMode.all,
      expectedItems: requestedPubkeys,
      fallbackTimeoutSeconds: fallbackTimeoutSeconds,
      serviceName: 'ProfileQuery',
      logCategory: LogCategory.ui,
    );

    final result =
        await ImmediateCompletionHelper.queryWithImmediateCompletion<
          Map<String, dynamic>
        >(
          eventStream: eventStream,
          config: config,
          eventMapper: (event) => {'pubkey': event.pubkey, 'event': event},
          eventFilter: (event) =>
              event.kind == 0 && requestedPubkeys.contains(event.pubkey),
        );

    return {
      'profiles': result.items,
      'completedEarly': result.completedEarly,
      'receivedCount': result.receivedCount,
      'expectedCount': requestedPubkeys.length,
    };
  }
}

class ContactListCompletionHelper {
  /// Query contact list with immediate completion
  static Future<Event?> queryContactList({
    required Stream<Event> eventStream,
    required String pubkey,
    int fallbackTimeoutSeconds = 10,
  }) async {
    final config = CompletionConfig(
      mode: CompletionMode.first,
      fallbackTimeoutSeconds: fallbackTimeoutSeconds,
      serviceName: 'ContactListQuery',
      logCategory: LogCategory.system,
    );

    final result =
        await ImmediateCompletionHelper.queryWithImmediateCompletion<Event>(
          eventStream: eventStream,
          config: config,
          eventMapper: (event) => event,
          eventFilter: (event) => event.kind == 3 && event.pubkey == pubkey,
        );

    return result.items.isEmpty ? null : result.items.first;
  }
}

class VideoEventCompletionHelper {
  /// Query video events with immediate completion when sufficient data is received
  static StreamSubscription<Event> createVideoSubscription({
    required Stream<Event> eventStream,
    required Function(Event) onVideoEvent,
    required Function() onSufficientData,
    int sufficientDataThreshold = 5,
    int fallbackTimeoutSeconds = 60,
  }) {
    int receivedCount = 0;

    final config = CompletionConfig(
      mode: CompletionMode.exhaustive, // Don't auto-complete, let caller decide
      fallbackTimeoutSeconds: fallbackTimeoutSeconds,
      serviceName: 'VideoEventQuery',
      logCategory: LogCategory.video,
    );

    return ImmediateCompletionHelper.createImmediateSubscription(
      eventStream: eventStream,
      config: config,
      onEvent: (event) {
        if (event.kind == 32222) {
          onVideoEvent(event);
          receivedCount++;

          // Trigger sufficient data callback when threshold is reached
          if (receivedCount >= sufficientDataThreshold) {
            onSufficientData();
          }
        }
      },
      onComplete: (result) {
        // Video subscriptions typically stay open for ongoing updates
        Log.debug(
          'Video subscription completed: received=${result.receivedCount}',
          name: 'VideoEventQuery',
          category: LogCategory.video,
        );
      },
    );
  }
}
