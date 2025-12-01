// ABOUTME: Service for subscribing to and processing NIP-32 label events (kind 1985)
// ABOUTME: Enables Bluesky-style moderation feeds with trusted labelers

import 'dart:async';
import 'dart:convert';

import 'package:nostr_sdk/event.dart' as nostr_sdk;
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_list_service_mixin.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Represents a NIP-32 label applied to content
class ModerationLabel {
  const ModerationLabel({
    required this.labelId,
    required this.namespace,
    required this.label,
    required this.moderatorPubkey,
    required this.createdAt,
    this.targetEventId,
    this.targetPubkey,
    this.reason,
  });

  final String labelId; // Event ID of kind 1985
  final String namespace; // L tag
  final String label; // l tag
  final String? targetEventId; // e tag
  final String? targetPubkey; // p tag
  final String moderatorPubkey; // Author of label event
  final DateTime createdAt;
  final String? reason; // Optional context

  Map<String, dynamic> toJson() => {
    'labelId': labelId,
    'namespace': namespace,
    'label': label,
    'targetEventId': targetEventId,
    'targetPubkey': targetPubkey,
    'moderatorPubkey': moderatorPubkey,
    'createdAt': createdAt.toIso8601String(),
    'reason': reason,
  };

  static ModerationLabel fromJson(Map<String, dynamic> json) => ModerationLabel(
    labelId: json['labelId'],
    namespace: json['namespace'],
    label: json['label'],
    moderatorPubkey: json['moderatorPubkey'],
    createdAt: DateTime.parse(json['createdAt']),
    targetEventId: json['targetEventId'],
    targetPubkey: json['targetPubkey'],
    reason: json['reason'],
  );

  @override
  bool operator ==(Object other) =>
      other is ModerationLabel &&
      other.labelId == labelId &&
      other.namespace == namespace &&
      other.label == label;

  @override
  int get hashCode => Object.hash(labelId, namespace, label);
}

/// Service for managing NIP-32 label subscriptions (kind 1985)
class ModerationLabelService with NostrListServiceMixin {
  ModerationLabelService({
    required INostrService nostrService,
    required AuthService authService,
    required SharedPreferences prefs,
  }) : _nostrService = nostrService,
       _authService = authService,
       _prefs = prefs {
    _loadSubscribedLabelers();
    _loadLabelCache();
  }

  final INostrService _nostrService;
  final AuthService _authService;
  final SharedPreferences _prefs;

  // Mixin interface implementations
  @override
  INostrService get nostrService => _nostrService;
  @override
  AuthService get authService => _authService;

  // Storage keys
  static const String subscribedLabelersKey = 'subscribed_labelers';
  static const String labelCacheKey = 'label_cache';

  // State
  final Set<String> _subscribedLabelers = {};
  final Map<String, List<ModerationLabel>> _eventLabels = {};
  final Map<String, List<ModerationLabel>> _pubkeyLabels = {};
  final Map<String, ModerationLabel> _allLabels = {}; // labelId -> label

  bool _isInitialized = false;

  // Getters
  bool get isInitialized => _isInitialized;
  Set<String> get subscribedLabelers => Set.unmodifiable(_subscribedLabelers);

  /// Initialize the service
  Future<void> initialize() async {
    try {
      if (!_authService.isAuthenticated) {
        Log.warning(
          'Cannot initialize label service - user not authenticated',
          name: 'ModerationLabelService',
          category: LogCategory.system,
        );
        return;
      }

      // Load labels from subscribed labelers
      for (final labelerPubkey in _subscribedLabelers) {
        await _loadLabelsFromLabeler(labelerPubkey);
      }

      _isInitialized = true;
      Log.info(
        'Label service initialized with ${_subscribedLabelers.length} labelers, ${_allLabels.length} labels',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to initialize label service: $e',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
    }
  }

  /// Subscribe to a labeler's kind 1985 events
  Future<void> subscribeToLabeler(String labelerPubkey) async {
    try {
      if (_subscribedLabelers.contains(labelerPubkey)) {
        Log.debug(
          'Already subscribed to labeler: $labelerPubkey',
          name: 'ModerationLabelService',
          category: LogCategory.system,
        );
        return;
      }

      _subscribedLabelers.add(labelerPubkey);
      await _saveSubscribedLabelers();

      // Load labels from this labeler
      await _loadLabelsFromLabeler(labelerPubkey);

      Log.info(
        'Subscribed to labeler: ${labelerPubkey}... (${_allLabels.length} total labels)',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
    } catch (e) {
      _subscribedLabelers.remove(labelerPubkey);
      Log.error(
        'Failed to subscribe to labeler $labelerPubkey: $e',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
      rethrow;
    }
  }

  /// Unsubscribe from a labeler
  Future<void> unsubscribeFromLabeler(String labelerPubkey) async {
    try {
      _subscribedLabelers.remove(labelerPubkey);

      // Remove all labels from this labeler
      _allLabels.removeWhere(
        (_, label) => label.moderatorPubkey == labelerPubkey,
      );
      _eventLabels.forEach((_, labels) {
        labels.removeWhere((label) => label.moderatorPubkey == labelerPubkey);
      });
      _pubkeyLabels.forEach((_, labels) {
        labels.removeWhere((label) => label.moderatorPubkey == labelerPubkey);
      });

      // Clean up empty entries
      _eventLabels.removeWhere((_, labels) => labels.isEmpty);
      _pubkeyLabels.removeWhere((_, labels) => labels.isEmpty);

      await _saveSubscribedLabelers();
      await _saveLabelCache();

      Log.info(
        'Unsubscribed from labeler: ${labelerPubkey}...',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to unsubscribe from labeler: $e',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
    }
  }

  /// Get all labels for an event
  List<ModerationLabel> getLabelsForEvent(String eventId) {
    return List.unmodifiable(_eventLabels[eventId] ?? []);
  }

  /// Get all labels for a pubkey
  List<ModerationLabel> getLabelsForPubkey(String pubkey) {
    return List.unmodifiable(_pubkeyLabels[pubkey] ?? []);
  }

  /// Get labels for event filtered by namespace
  List<ModerationLabel> getLabelsForEventByNamespace(
    String eventId,
    String namespace,
  ) {
    final labels = _eventLabels[eventId] ?? [];
    return labels.where((label) => label.namespace == namespace).toList();
  }

  /// Check if event has specific label
  bool hasLabel(String eventId, String namespace, String label) {
    final labels = _eventLabels[eventId] ?? [];
    return labels.any((l) => l.namespace == namespace && l.label == label);
  }

  /// Get label count aggregation for an event
  Map<String, int> getLabelCounts(String eventId) {
    final labels = _eventLabels[eventId] ?? [];
    final counts = <String, int>{};

    for (final label in labels) {
      final key = label.label;
      counts[key] = (counts[key] ?? 0) + 1;
    }

    return counts;
  }

  /// Get service statistics
  Map<String, dynamic> getStats() {
    return {
      'subscribedLabelers': _subscribedLabelers.length,
      'totalLabels': _allLabels.length,
      'eventLabels': _eventLabels.length,
      'pubkeyLabels': _pubkeyLabels.length,
    };
  }

  /// Load labels from a specific labeler
  Future<void> _loadLabelsFromLabeler(String labelerPubkey) async {
    try {
      Log.debug(
        'Loading labels from: ${labelerPubkey}...',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );

      // Query for kind 1985 (label) events from this labeler
      final filter = Filter(
        authors: [labelerPubkey],
        kinds: [1985], // NIP-32 label events
      );

      final events = await _nostrService.getEvents(filters: [filter]);

      if (events.isEmpty) {
        Log.debug(
          'No labels found from labeler: ${labelerPubkey}...',
          name: 'ModerationLabelService',
          category: LogCategory.system,
        );
        return;
      }

      // Parse and store labels
      for (final event in events) {
        _parseLabelEvent(event);
      }

      await _saveLabelCache();

      Log.debug(
        'Loaded ${events.length} label events from ${labelerPubkey}...',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to load labels from labeler $labelerPubkey: $e',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
    }
  }

  /// Parse NIP-32 kind 1985 label event
  void _parseLabelEvent(nostr_sdk.Event event) {
    try {
      // Extract namespace and labels
      String? currentNamespace;
      final List<String> targetEvents = [];
      final List<String> targetPubkeys = [];
      final parsedLabels = <String>[];

      for (final tag in event.tags) {
        if (tag.isEmpty) continue;

        final tagType = tag[0];

        switch (tagType) {
          case 'L': // Namespace
            if (tag.length > 1) {
              currentNamespace = tag[1];
            }
            break;
          case 'l': // Label
            if (tag.length > 1) {
              parsedLabels.add(tag[1]);
            }
            break;
          case 'e': // Target event
            if (tag.length > 1) {
              targetEvents.add(tag[1]);
            }
            break;
          case 'p': // Target pubkey
            if (tag.length > 1) {
              targetPubkeys.add(tag[1]);
            }
            break;
        }
      }

      // Must have namespace and at least one label
      if (currentNamespace == null || parsedLabels.isEmpty) {
        return;
      }

      // Create label objects for each label + target combination
      for (final labelValue in parsedLabels) {
        for (final eventId in targetEvents) {
          final label = ModerationLabel(
            labelId: event.id,
            namespace: currentNamespace,
            label: labelValue,
            moderatorPubkey: event.pubkey,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              event.createdAt * 1000,
            ),
            targetEventId: eventId,
          );

          _allLabels[label.labelId] = label;
          _eventLabels.putIfAbsent(eventId, () => []).add(label);
        }

        for (final pubkey in targetPubkeys) {
          final label = ModerationLabel(
            labelId: event.id,
            namespace: currentNamespace,
            label: labelValue,
            moderatorPubkey: event.pubkey,
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              event.createdAt * 1000,
            ),
            targetPubkey: pubkey,
          );

          _allLabels[label.labelId] = label;
          _pubkeyLabels.putIfAbsent(pubkey, () => []).add(label);
        }
      }

      Log.debug(
        'Parsed ${parsedLabels.length} labels from event ${event.id}...',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to parse label event: $e',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
    }
  }

  /// Load subscribed labelers from storage
  void _loadSubscribedLabelers() {
    final json = _prefs.getString(subscribedLabelersKey);
    if (json != null) {
      try {
        final List<dynamic> labelers = jsonDecode(json);
        _subscribedLabelers.clear();
        _subscribedLabelers.addAll(labelers.cast<String>());
        Log.debug(
          'Loaded ${_subscribedLabelers.length} subscribed labelers',
          name: 'ModerationLabelService',
          category: LogCategory.system,
        );
      } catch (e) {
        Log.error(
          'Failed to load subscribed labelers: $e',
          name: 'ModerationLabelService',
          category: LogCategory.system,
        );
      }
    }
  }

  /// Save subscribed labelers to storage
  Future<void> _saveSubscribedLabelers() async {
    try {
      await _prefs.setString(
        subscribedLabelersKey,
        jsonEncode(_subscribedLabelers.toList()),
      );
    } catch (e) {
      Log.error(
        'Failed to save subscribed labelers: $e',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
    }
  }

  /// Load label cache from storage
  void _loadLabelCache() {
    final json = _prefs.getString(labelCacheKey);
    if (json != null) {
      try {
        final List<dynamic> labelsJson = jsonDecode(json);
        for (final labelJson in labelsJson) {
          final label = ModerationLabel.fromJson(
            labelJson as Map<String, dynamic>,
          );
          _allLabels[label.labelId] = label;

          if (label.targetEventId != null) {
            _eventLabels.putIfAbsent(label.targetEventId!, () => []).add(label);
          }
          if (label.targetPubkey != null) {
            _pubkeyLabels.putIfAbsent(label.targetPubkey!, () => []).add(label);
          }
        }
        Log.debug(
          'Loaded ${_allLabels.length} labels from cache',
          name: 'ModerationLabelService',
          category: LogCategory.system,
        );
      } catch (e) {
        Log.error(
          'Failed to load label cache: $e',
          name: 'ModerationLabelService',
          category: LogCategory.system,
        );
      }
    }
  }

  /// Save label cache to storage
  Future<void> _saveLabelCache() async {
    try {
      final labelsJson = _allLabels.values.map((l) => l.toJson()).toList();
      await _prefs.setString(labelCacheKey, jsonEncode(labelsJson));
    } catch (e) {
      Log.error(
        'Failed to save label cache: $e',
        name: 'ModerationLabelService',
        category: LogCategory.system,
      );
    }
  }

  void dispose() {
    // Clean up any active subscriptions
  }
}
