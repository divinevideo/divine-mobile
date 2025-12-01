// ABOUTME: Service for managing video feed subscriptions with the Nostr network
// ABOUTME: Handles subscription lifecycle, filter building, and duplicate prevention

import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/exceptions/video_exceptions.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Service responsible for managing video feed subscriptions
class VideoSubscriptionService {
  VideoSubscriptionService({
    required INostrService nostrService,
    required SubscriptionManager subscriptionManager,
  }) : _nostrService = nostrService,
       _subscriptionManager = subscriptionManager;
  final INostrService _nostrService;
  final SubscriptionManager _subscriptionManager;

  String? _activeSubscriptionId;
  Map<String, dynamic> _currentSubscriptionParams = {};
  bool _isSubscribed = false;

  bool get isSubscribed => _isSubscribed;
  String? get activeSubscriptionId => _activeSubscriptionId;

  /// Create a video feed subscription with filters
  Future<String> createVideoSubscription({
    required Function(Event) onEvent,
    Function(dynamic)? onError,
    VoidCallback? onComplete,
    List<String>? authors,
    List<String>? hashtags,
    String? group,
    int? since,
    int? until,
    int limit = 50,
    bool includeReposts = false,
  }) async {
    // Check connection
    if (_nostrService.connectedRelayCount == 0) {
      throw ConnectionException('Not connected to any relays');
    }

    // Check for duplicate subscription
    final newParams = {
      'authors': authors,
      'hashtags': hashtags,
      'group': group,
      'since': since,
      'until': until,
      'limit': limit,
      'includeReposts': includeReposts,
    };

    if (_isSubscribed &&
        _parametersMatch(_currentSubscriptionParams, newParams)) {
      throw DuplicateSubscriptionException(
        'Already subscribed with same parameters',
      );
    }

    // Cancel existing subscription if any
    await cancelSubscription();

    // Build filters
    final filters = _buildFilters(
      authors: authors,
      hashtags: hashtags,
      group: group,
      since: since,
      until: until,
      limit: limit,
      includeReposts: includeReposts,
    );

    // Create subscription
    _activeSubscriptionId = await _subscriptionManager.createSubscription(
      name: 'video_feed',
      filters: filters,
      onEvent: onEvent,
      onError: onError,
      onComplete: onComplete,
    );

    _isSubscribed = true;
    _currentSubscriptionParams = newParams;

    Log.info(
      'Created video subscription: $_activeSubscriptionId',
      name: 'VideoSubscriptionService',
      category: LogCategory.video,
    );

    return _activeSubscriptionId!;
  }

  /// Cancel active subscription
  Future<void> cancelSubscription() async {
    if (_activeSubscriptionId != null) {
      await _subscriptionManager.cancelSubscription(_activeSubscriptionId!);
      _activeSubscriptionId = null;
      _isSubscribed = false;
      _currentSubscriptionParams = {};
    }
  }

  Future<void> dispose() async {
    await cancelSubscription();
  }

  List<Filter> _buildFilters({
    required int limit,
    required bool includeReposts,
    List<String>? authors,
    List<String>? hashtags,
    String? group,
    int? since,
    int? until,
  }) {
    final filters = <Filter>[];

    // Video events filter (kind 34236 only)
    filters.add(
      Filter(
        kinds: [34236],
        authors: authors,
        t: hashtags,
        h: group != null ? [group] : null,
        since: since,
        until: until,
        limit: limit,
      ),
    );

    // Repost filter (kind 16 generic repost) if requested
    if (includeReposts) {
      filters.add(
        Filter(
          kinds: [16],
          authors: authors,
          since: since,
          until: until,
          limit: limit ~/ 2,
        ),
      );
    }

    return filters;
  }

  bool _parametersMatch(
    Map<String, dynamic> params1,
    Map<String, dynamic> params2,
  ) => params1.toString() == params2.toString();
}
