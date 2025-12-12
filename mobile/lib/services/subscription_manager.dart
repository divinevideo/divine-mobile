// ABOUTME: Manages video event subscriptions and real-time feed updates
// ABOUTME: Handles subscription lifecycle, filtering, and event distribution

import 'dart:async';

import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Manages Nostr subscriptions for video events and other content
/// Smart subscription manager that checks event cache before requesting from relay
/// Supports both event ID filtering and author filtering for profiles
class SubscriptionManager {
  SubscriptionManager(
    this._nostrService, {
    Event? Function(String)? getCachedEvent,
    bool Function(String)? hasProfileCached,
  }) : _getCachedEvent = getCachedEvent,
       _hasProfileCached = hasProfileCached;

  final NostrClient _nostrService;
  Event? Function(String)? _getCachedEvent; // Returns cached Event for event ID
  bool Function(String)?
  _hasProfileCached; // Checks if profile cached for pubkey
  final Map<String, StreamSubscription<Event>> _activeSubscriptions = {};
  final Map<String, StreamController<Event>> _controllers = {};

  bool _isDisposed = false;

  /// Inject cache lookup functions after construction (for circular dependency resolution)
  void setCacheLookup({
    Event? Function(String)? getCachedEvent,
    bool Function(String)? hasProfileCached,
  }) {
    if (getCachedEvent != null) _getCachedEvent = getCachedEvent;
    if (hasProfileCached != null) _hasProfileCached = hasProfileCached;
  }

  /// Creates a new subscription with the given parameters
  /// Smart subscription that checks cache before requesting from relay
  Future<String> createSubscription({
    required String name,
    required List<Filter> filters,
    required Function(Event) onEvent,
    Function(dynamic)? onError,
    Function()? onComplete,
    Duration? timeout,
    int priority = 5,
  }) async {
    if (_isDisposed) throw StateError('SubscriptionManager is disposed');

    final id = '${name}_${DateTime.now().millisecondsSinceEpoch}';

    // Log incoming filter for debugging
    for (var i = 0; i < filters.length; i++) {
      final f = filters[i];
      Log.debug(
        '📋 Subscription "$name" filter[$i]: kinds=${f.kinds}, e=${f.e}, authors=${f.authors?.length ?? 0}, limit=${f.limit}',
        name: 'SubscriptionManager',
        category: LogCategory.system,
      );
    }

    // Smart filtering: Check cache for event IDs and profile authors
    final filteredFilters = _filterCachedData(filters, onEvent);

    // If all requested data was in cache, complete immediately
    if (filteredFilters.isEmpty) {
      Log.debug(
        '✨ All requested data found in cache - skipping relay subscription',
        name: 'SubscriptionManager',
        category: LogCategory.system,
      );
      onComplete?.call();
      return id;
    }

    // Log filtered filters for debugging
    for (var i = 0; i < filteredFilters.length; i++) {
      final f = filteredFilters[i];
      Log.debug(
        '📋 After filtering, filter[$i]: kinds=${f.kinds}, e=${f.e}, authors=${f.authors?.length ?? 0}, limit=${f.limit}',
        name: 'SubscriptionManager',
        category: LogCategory.system,
      );
    }

    // Create event stream from NostrService with filtered filters
    final eventStream = _nostrService.subscribe(filteredFilters);

    // Set up subscription
    final subscription = eventStream.listen(
      onEvent,
      onError: onError,
      onDone: onComplete,
    );

    _activeSubscriptions[id] = subscription;

    // Handle timeout if specified
    if (timeout != null) {
      Timer(timeout, () {
        if (_activeSubscriptions.containsKey(id)) {
          cancelSubscription(id);
          onComplete?.call();
        }
      });
    }

    return id;
  }

  /// Filter out cached data from subscription filters
  /// Returns filtered filters list (may be empty if all data is cached)
  /// Handles both event ID filtering and profile author filtering
  /// Optimizes limits to ≤100 for better relay performance
  List<Filter> _filterCachedData(
    List<Filter> filters,
    Function(Event) onEvent,
  ) {
    final filteredFilters = <Filter>[];

    for (final filter in filters) {
      Filter? modifiedFilter;

      // 1. Filter event IDs if we have event cache
      if (_getCachedEvent != null &&
          filter.ids != null &&
          filter.ids!.isNotEmpty) {
        final cachedIds = <String>[];
        final missingIds = <String>[];

        for (final eventId in filter.ids!) {
          final cached = _getCachedEvent!(eventId);
          if (cached != null) {
            cachedIds.add(eventId);
            Future.microtask(() => onEvent(cached));
          } else {
            missingIds.add(eventId);
          }
        }

        if (cachedIds.isNotEmpty) {
          Log.debug(
            '✨ Found ${cachedIds.length}/${filter.ids!.length} events in cache',
            name: 'SubscriptionManager',
            category: LogCategory.system,
          );
        }

        // Update filter with only missing IDs
        if (missingIds.isEmpty) {
          continue; // Skip this filter entirely - all events cached
        }

        // Optimize limit to ≤100 for better relay performance
        final optimizedLimit = filter.limit != null && filter.limit! > 100
            ? 100
            : filter.limit;

        modifiedFilter = Filter(
          ids: missingIds,
          kinds: filter.kinds,
          authors: filter.authors,
          limit: optimizedLimit,
          since: filter.since,
          until: filter.until,
          search: filter.search,
          e: filter.e,
          p: filter.p,
          t: filter.t,
          h: filter.h,
        );
      }

      // 2. Filter profile authors if this is a kind 0 request
      if (_hasProfileCached != null &&
          filter.kinds?.contains(0) == true &&
          filter.authors != null &&
          filter.authors!.isNotEmpty) {
        final authors = modifiedFilter?.authors ?? filter.authors!;
        final cachedAuthors = <String>[];
        final missingAuthors = <String>[];

        for (final author in authors) {
          if (_hasProfileCached!(author)) {
            cachedAuthors.add(author);
          } else {
            missingAuthors.add(author);
          }
        }

        if (cachedAuthors.isNotEmpty) {
          Log.debug(
            '✨ Found ${cachedAuthors.length}/${authors.length} profiles cached - skipping relay request',
            name: 'SubscriptionManager',
            category: LogCategory.system,
          );
        }

        // Update filter with only missing authors
        if (missingAuthors.isEmpty) {
          continue; // Skip this filter entirely - all profiles cached
        }

        // Optimize limit to ≤100 for better relay performance
        final optimizedLimit = filter.limit != null && filter.limit! > 100
            ? 100
            : filter.limit;

        modifiedFilter = Filter(
          ids: modifiedFilter?.ids,
          kinds: filter.kinds,
          authors: missingAuthors,
          limit: optimizedLimit,
          since: filter.since,
          until: filter.until,
          search: filter.search,
          e: modifiedFilter?.e ?? filter.e,
          p: modifiedFilter?.p ?? filter.p,
          t: modifiedFilter?.t ?? filter.t,
          h: modifiedFilter?.h ?? filter.h,
        );
      }

      // If no modifications were made, optimize the limit on the original filter
      if (modifiedFilter == null &&
          filter.limit != null &&
          filter.limit! > 100) {
        modifiedFilter = Filter(
          ids: filter.ids,
          kinds: filter.kinds,
          authors: filter.authors,
          limit: 100,
          since: filter.since,
          until: filter.until,
          search: filter.search,
          e: filter.e,
          p: filter.p,
          t: filter.t,
          h: filter.h,
        );
      }

      // Add the filter (modified or original)
      filteredFilters.add(modifiedFilter ?? filter);
    }

    return filteredFilters;
  }

  /// Cancels an active subscription
  Future<void> cancelSubscription(String subscriptionId) async {
    final subscription = _activeSubscriptions.remove(subscriptionId);
    await subscription?.cancel();

    final controller = _controllers.remove(subscriptionId);
    if (controller != null && !controller.isClosed) {
      await controller.close();
    }
  }

  /// Cancels all active subscriptions
  Future<void> cancelAllSubscriptions() async {
    final subscriptions = List.from(_activeSubscriptions.values);
    _activeSubscriptions.clear();

    for (final subscription in subscriptions) {
      await subscription.cancel();
    }

    final controllers = List.from(_controllers.values);
    _controllers.clear();

    for (final controller in controllers) {
      if (!controller.isClosed) {
        await controller.close();
      }
    }
  }

  /// Gets the list of active subscription IDs
  List<String> get activeSubscriptionIds =>
      List.from(_activeSubscriptions.keys);

  /// Gets the count of active subscriptions
  int get activeSubscriptionCount => _activeSubscriptions.length;

  /// Checks if a subscription is active
  bool isSubscriptionActive(String subscriptionId) {
    return _activeSubscriptions.containsKey(subscriptionId);
  }

  /// Cancels all subscriptions that match a name pattern
  Future<void> cancelSubscriptionsByName(String namePattern) async {
    final subscriptionsToCancel = _activeSubscriptions.keys
        .where((id) => id.contains(namePattern))
        .toList();

    for (final subscriptionId in subscriptionsToCancel) {
      await cancelSubscription(subscriptionId);
    }
  }

  /// Disposes the subscription manager and all active subscriptions
  Future<void> dispose() async {
    if (_isDisposed) return;

    await cancelAllSubscriptions();
    _isDisposed = true;
  }
}
