// ABOUTME: Service for managing account-level content warning self-labels
// ABOUTME: Persists labels in SharedPreferences and publishes Kind 1985 events

import 'dart:async';

import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/constants/nostr_event_kinds.dart';
import 'package:openvine/models/content_label.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Service for managing account-level content warning labels.
///
/// Allows creators to declare their account contains sensitive content.
/// Persists labels locally and publishes a Kind 1985 self-label event
/// targeting the creator's own pubkey.
class AccountLabelService {
  AccountLabelService({
    required AuthService authService,
    required NostrClient nostrClient,
  }) : _authService = authService,
       _nostrClient = nostrClient;

  final AuthService _authService;
  final NostrClient _nostrClient;

  /// SharedPreferences key for the account content labels.
  /// Public so `UserDataCleanupService` can clear it by reference.
  /// A copied literal cannot detect that this key was renamed (#8314).
  static const String accountLabelStorageKey = 'account_content_label';

  final Completer<void> _initCompleter = Completer<void>();

  /// A future that completes when [initialize] has finished loading labels
  /// from SharedPreferences. Await this before reading [defaultVideoLabels]
  /// to avoid a race condition where labels appear empty.
  Future<void> get initialized => _initCompleter.future;

  Set<ContentLabel> _accountLabels = {};

  /// The current account-level content labels (empty if none set).
  Set<ContentLabel> get accountLabels => Set.unmodifiable(_accountLabels);

  /// Whether the user has set any account-level content labels.
  bool get hasAccountLabels => _accountLabels.isNotEmpty;

  /// Returns the default content warnings for new videos based on account
  /// labels.
  ///
  /// Returns an empty set if no account labels are set.
  Set<ContentLabel> get defaultVideoLabels => Set.unmodifiable(_accountLabels);

  /// Initialize by loading persisted labels.
  ///
  /// After this completes, [initialized] resolves and [defaultVideoLabels]
  /// returns the persisted labels.
  Future<void> initialize() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final value = prefs.getString(accountLabelStorageKey);
      _accountLabels = ContentLabel.fromCsv(value);
    } catch (e) {
      Log.error(
        'Error loading account labels: $e',
        name: 'AccountLabelService',
        category: LogCategory.system,
      );
    } finally {
      if (!_initCompleter.isCompleted) {
        _initCompleter.complete();
      }
    }
  }

  /// Set the account-level content labels and publish a Kind 1985 event.
  ///
  /// Pass an empty set to clear account labels.
  Future<void> setAccountLabels(Set<ContentLabel> labels) async {
    _accountLabels = Set.of(labels);

    try {
      final prefs = await SharedPreferences.getInstance();
      final csv = ContentLabel.toCsv(labels);
      if (csv != null) {
        await prefs.setString(accountLabelStorageKey, csv);
      } else {
        await prefs.remove(accountLabelStorageKey);
      }
    } catch (e) {
      Log.error(
        'Error saving account labels: $e',
        name: 'AccountLabelService',
        category: LogCategory.system,
      );
    }

    // Publish Kind 1985 self-label event if labels are set
    if (labels.isNotEmpty) {
      await _publishAccountLabels(labels);
    }
  }

  /// Publish a Kind 1985 self-label event targeting own pubkey.
  ///
  /// Format:
  /// ```json
  /// {
  ///   "kind": 1985,
  ///   "tags": [
  ///     ["L", "content-warning"],
  ///     ["l", "<label1>", "content-warning"],
  ///     ["l", "<label2>", "content-warning"],
  ///     ["p", "<own_pubkey>", "wss://relay.divine.video"]
  ///   ]
  /// }
  /// ```
  Future<void> _publishAccountLabels(Set<ContentLabel> labels) async {
    final pubkey = _authService.currentPublicKeyHex;
    if (pubkey == null) {
      Log.warning(
        'Cannot publish account labels - not authenticated',
        name: 'AccountLabelService',
        category: LogCategory.system,
      );
      return;
    }

    try {
      final tags = <List<String>>[
        ['L', 'content-warning'],
        for (final label in labels) ['l', label.value, 'content-warning'],
        ['p', pubkey, 'wss://relay.divine.video'],
      ];

      final event = await _authService.createAndSignEvent(
        kind: NostrEventKinds.label,
        content: '',
        tags: tags,
      );

      if (event == null) {
        Log.error(
          'Failed to create Kind 1985 event',
          name: 'AccountLabelService',
          category: LogCategory.system,
        );
        return;
      }

      final sentEvent = await _nostrClient.publishEvent(event);
      if (sentEvent is PublishSuccess) {
        Log.info(
          'Published account labels: '
          '${labels.map((l) => l.value).join(", ")}',
          name: 'AccountLabelService',
          category: LogCategory.system,
        );
      } else {
        Log.warning(
          'Failed to publish account labels to relays',
          name: 'AccountLabelService',
          category: LogCategory.system,
        );
      }
    } catch (e, stackTrace) {
      Log.error(
        'Error publishing account labels: $e\n$stackTrace',
        name: 'AccountLabelService',
        category: LogCategory.system,
      );
    }
  }

  /// Build NIP-32 content-warning tags for a Kind 0 profile event.
  ///
  /// Returns an empty list if no account labels are set.
  List<List<String>> buildProfileTags() {
    if (_accountLabels.isEmpty) return const [];
    return [
      ['L', 'content-warning'],
      for (final label in _accountLabels) ['l', label.value, 'content-warning'],
    ];
  }
}
