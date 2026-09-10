// ABOUTME: Content deletion service for user's own content using NIP-09 delete events
// ABOUTME: Implements kind 5 delete events for Apple App Store compliance and user content management

import 'dart:convert';

import 'package:db_client/db_client.dart';
import 'package:models/models.dart' hide NIP71VideoKinds;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/constants/nip71_migration.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

/// Machine-readable reason when [DeleteResult.success] is false.
enum DeleteFailureKind {
  /// [ContentDeletionService] was not initialized.
  notInitialized,

  /// The video does not belong to the signed-in user.
  notOwner,

  /// User is not authenticated when creating the delete event.
  notAuthenticated,

  /// Signing or constructing the kind 5 delete event failed.
  couldNotSign,

  /// Every relay that responded rejected the delete event. The delete is NOT
  /// persisted locally so the user can retry.
  relayRejected,

  /// Every responding relay rejected deletion because the account is
  /// explicitly suspended or banned.
  accountRestricted,

  /// No relay accepted or rejected the delete event before the publish
  /// timeout. The delete is NOT persisted locally so the user can retry.
  relayNoResponse,

  /// Unexpected error (including outer [deleteContent] catch).
  unknown,
}

/// How broadly the relay network took a delete request that succeeded.
///
/// Set on every successful [DeleteResult] so callers can tell the user what
/// actually happened. Deletion under NIP-09 is a *request* relays SHOULD
/// honour, so neither value is a promise the video is gone from the network.
enum DeleteAcceptance {
  /// Every relay the publish targeted answered `OK true`.
  everyRelay,

  /// At least one relay accepted, and at least one rejected the request,
  /// stayed silent, or was never reached.
  ///
  /// The video is out of this device's library and the tombstone is recorded,
  /// but the relays that did not accept can still serve it. Nothing here
  /// republishes to them.
  someRelays,
}

/// Delete request result
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class DeleteResult {
  const DeleteResult({
    required this.success,
    required this.timestamp,
    this.error,
    this.deleteEventId,
    this.failureKind,
    this.acceptance,
  });
  final bool success;
  final String? error;
  final String? deleteEventId;
  final DateTime timestamp;

  /// Set when [success] is false; use for localized UI messages.
  final DeleteFailureKind? failureKind;

  /// Set when [success] is true; how broadly the relays took the request.
  final DeleteAcceptance? acceptance;

  factory DeleteResult.createSuccess(
    String deleteEventId, {
    required DeleteAcceptance acceptance,
  }) => DeleteResult(
    success: true,
    deleteEventId: deleteEventId,
    acceptance: acceptance,
    timestamp: DateTime.now(),
  );

  factory DeleteResult.failure(String error, DeleteFailureKind kind) =>
      DeleteResult(
        success: false,
        error: error,
        failureKind: kind,
        timestamp: DateTime.now(),
      );
}

/// Content deletion record for tracking
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class ContentDeletion {
  const ContentDeletion({
    required this.deleteEventId,
    required this.originalEventId,
    required this.reason,
    required this.deletedAt,
    this.addressableId,
    this.additionalContext,
  });
  final String deleteEventId;
  final String originalEventId;
  final String? addressableId;
  final String reason;
  final DateTime deletedAt;
  final String? additionalContext;

  Map<String, dynamic> toJson() => {
    'deleteEventId': deleteEventId,
    'originalEventId': originalEventId,
    if (addressableId != null) 'addressableId': addressableId,
    'reason': reason,
    'deletedAt': deletedAt.toIso8601String(),
    'additionalContext': additionalContext,
  };

  factory ContentDeletion.fromJson(Map<String, dynamic> json) =>
      ContentDeletion(
        deleteEventId: json['deleteEventId'] as String,
        originalEventId: json['originalEventId'] as String,
        addressableId: json['addressableId'] as String?,
        reason: json['reason'] as String,
        deletedAt: DateTime.parse(json['deletedAt'] as String),
        additionalContext: json['additionalContext'] as String?,
      );
}

/// Service for deleting user's own content via NIP-09
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class ContentDeletionService {
  ContentDeletionService({
    required NostrClient nostrService,
    required AuthService authService,
    required SharedPreferences prefs,
    ProfileStatsDao? profileStatsDao,
  }) : _nostrService = nostrService,
       _authService = authService,
       _prefs = prefs,
       _profileStatsDao = profileStatsDao {
    _loadDeletionHistory();
  }
  final NostrClient _nostrService;
  final AuthService _authService;
  final SharedPreferences _prefs;
  final ProfileStatsDao? _profileStatsDao;

  static const String deletionsStorageKey = 'content_deletions_history';

  final List<ContentDeletion> _deletionHistory = [];
  bool _isInitialized = false;

  // Getters
  List<ContentDeletion> get deletionHistory =>
      List.unmodifiable(_deletionHistory);
  bool get isInitialized => _isInitialized;

  static List<ContentDeletion> parseDeletionHistory(String? historyJson) {
    if (historyJson == null) return const [];

    final deletionsJson = jsonDecode(historyJson) as List<dynamic>;
    return deletionsJson
        .map((json) => ContentDeletion.fromJson(json as Map<String, dynamic>))
        .toList(growable: false);
  }

  /// Initialize deletion service
  Future<void> initialize() async {
    try {
      if (!_nostrService.isInitialized) {
        Log.warning(
          'Nostr service not initialized, cannot setup content deletion',
          name: 'ContentDeletionService',
          category: LogCategory.system,
        );
        return;
      }

      _isInitialized = true;
      Log.info(
        'Content deletion service initialized',
        name: 'ContentDeletionService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.error(
        'Failed to initialize content deletion: $e',
        name: 'ContentDeletionService',
        category: LogCategory.system,
      );
    }
  }

  /// Delete user's own content using NIP-09.
  ///
  /// Succeeds once **any** targeted relay returns `OK true`, which is the
  /// point at which the tombstone exists somewhere other than this device.
  /// The deletion is then recorded locally and the video leaves the user's
  /// library. When only part of the relay set accepted, the result carries
  /// [DeleteAcceptance.someRelays] so the caller can say so rather than
  /// claiming the video is gone everywhere.
  ///
  /// When no relay accepted, nothing was recorded anywhere: the deletion is
  /// NOT added to local deletion history, the video stays visible, and the
  /// caller can retry.
  Future<DeleteResult> deleteContent({
    required VideoEvent video,
    required String reason,
    String? additionalContext,
  }) async {
    try {
      if (!_isInitialized) {
        return DeleteResult.failure(
          'Deletion service not initialized',
          DeleteFailureKind.notInitialized,
        );
      }

      // Verify this is the user's own content
      if (!_isUserOwnContent(video)) {
        return DeleteResult.failure(
          'Can only delete your own content',
          DeleteFailureKind.notOwner,
        );
      }

      final addressableId = _addressableDeletionTarget(video);

      // Create NIP-09 delete event (kind 5)
      // OpenVine only uses kind 34236 (addressable short videos)
      final deleteOutcome = await _createDeleteEvent(
        originalEventId: video.id,
        addressableId: addressableId,
        originalEventKind: NIP71VideoKinds.getPreferredKind(),
        reason: reason,
        additionalContext: additionalContext,
      );

      final deleteEvent = deleteOutcome.event;
      if (deleteEvent == null) {
        final kind = deleteOutcome.failureKind!;
        return DeleteResult.failure(_failureMessageForKind(kind), kind);
      }

      final publishOutcome = await _nostrService.publishEventAwaitOk(
        deleteEvent,
      );

      // Counts only — never relay URLs — so this is safe to keep on in every
      // build and still answers "how often is a delete only partly accepted?".
      final breadth =
          'accepted=${publishOutcome.acceptedBy.length}/'
          '${publishOutcome.targetCount} '
          'rejected=${publishOutcome.rejectedBy.length} '
          'silent=${publishOutcome.noResponseFrom.length} '
          'unreachable=${publishOutcome.unreachableTargets.length}';

      // One acceptance is the bar, not all of them. NIP-09 deletion is a
      // request relays SHOULD honour, so no acknowledgement proves the video
      // is gone. Requiring every targeted relay buys a guarantee that does not
      // exist and costs the user the feature when a relay rejects, times out, or
      // cannot be reached. Breadth is reported on [DeleteResult.acceptance]
      // instead.
      if (publishOutcome.failed) {
        Log.error(
          'Delete publish not confirmed by any relay: '
          '${publishOutcome.summary}',
          name: 'ContentDeletionService',
          category: LogCategory.system,
        );
        return DeleteResult.failure(
          'Relay did not confirm deletion: ${publishOutcome.summary}',
          isAccountRestrictedOutcome(
                publishOutcome,
                trustedRelayUrl: _nostrService.defaultRelayUrl,
              )
              ? DeleteFailureKind.accountRestricted
              : publishOutcome.rejectedBy.isNotEmpty
              ? DeleteFailureKind.relayRejected
              : DeleteFailureKind.relayNoResponse,
        );
      }

      final acceptance = publishOutcome.acceptedByAll
          ? DeleteAcceptance.everyRelay
          : DeleteAcceptance.someRelays;

      if (acceptance == DeleteAcceptance.someRelays) {
        Log.warning(
          'Delete only partly accepted: $breadth',
          name: 'ContentDeletionService',
          category: LogCategory.system,
        );
      } else {
        Log.info(
          'Delete request confirmed by every relay: $breadth',
          name: 'ContentDeletionService',
          category: LogCategory.system,
        );
      }

      // A relay took the tombstone — now it is safe to persist the deletion.
      final deletion = ContentDeletion(
        deleteEventId: deleteEvent.id,
        originalEventId: video.id,
        addressableId: addressableId,
        reason: reason,
        deletedAt: DateTime.now(),
        additionalContext: additionalContext,
      );

      _deletionHistory.add(deletion);
      await _saveDeletionHistory();
      await _invalidateProfileStatsAfterConfirmedDelete();

      Log.debug(
        '📱️ Content deletion confirmed: ${deleteEvent.id}',
        name: 'ContentDeletionService',
        category: LogCategory.system,
      );
      return DeleteResult.createSuccess(deleteEvent.id, acceptance: acceptance);
    } catch (e) {
      Log.error(
        'Failed to delete content: $e',
        name: 'ContentDeletionService',
        category: LogCategory.system,
      );
      return DeleteResult.failure(
        'Failed to delete content: $e',
        DeleteFailureKind.unknown,
      );
    }
  }

  Future<void> _invalidateProfileStatsAfterConfirmedDelete() async {
    final dao = _profileStatsDao;
    if (dao == null) return;

    final currentPubkey = _authService.currentPublicKeyHex;
    if (currentPubkey == null || currentPubkey.isEmpty) return;

    try {
      await dao.deleteStats(currentPubkey);
      Log.debug(
        'Invalidated profile stats cache after content deletion',
        name: 'ContentDeletionService',
        category: LogCategory.system,
      );
    } catch (e) {
      Log.warning(
        'Failed to invalidate profile stats after content deletion: $e',
        name: 'ContentDeletionService',
        category: LogCategory.system,
      );
    }
  }

  static String _failureMessageForKind(DeleteFailureKind kind) {
    switch (kind) {
      case DeleteFailureKind.notInitialized:
        return 'Deletion service not initialized';
      case DeleteFailureKind.notOwner:
        return 'Can only delete your own content';
      case DeleteFailureKind.notAuthenticated:
        return 'Cannot create delete event: not authenticated';
      case DeleteFailureKind.couldNotSign:
        return 'Failed to create delete event';
      case DeleteFailureKind.relayRejected:
        return 'Relay rejected deletion';
      case DeleteFailureKind.accountRestricted:
        return 'Account is restricted from publishing deletion';
      case DeleteFailureKind.relayNoResponse:
        return 'Relay did not confirm deletion';
      case DeleteFailureKind.unknown:
        return 'Failed to delete content';
    }
  }

  /// Quick delete with common reasons
  Future<DeleteResult> quickDelete({
    required VideoEvent video,
    required DeleteReason reason,
  }) async {
    final reasonText = _getDeleteReasonText(reason);

    return deleteContent(
      video: video,
      reason: reasonText,
      additionalContext: 'Quick delete: ${reason.name}',
    );
  }

  /// Check if content has been deleted by user
  bool hasBeenDeleted(String eventId, {String? addressableId}) =>
      _deletionHistory.any(
        (deletion) =>
            deletion.originalEventId == eventId ||
            (addressableId != null && deletion.addressableId == addressableId),
      );

  /// Get deletion record for event
  ContentDeletion? getDeletionForEvent(
    String eventId, {
    String? addressableId,
  }) {
    try {
      return _deletionHistory.firstWhere(
        (deletion) =>
            deletion.originalEventId == eventId ||
            (addressableId != null && deletion.addressableId == addressableId),
      );
    } catch (e) {
      return null;
    }
  }

  /// Clear old deletion records (privacy cleanup)
  Future<void> clearOldDeletions({
    Duration maxAge = const Duration(days: 90),
  }) async {
    final cutoffDate = DateTime.now().subtract(maxAge);
    final initialCount = _deletionHistory.length;

    _deletionHistory.removeWhere(
      (deletion) => deletion.deletedAt.isBefore(cutoffDate),
    );

    if (_deletionHistory.length != initialCount) {
      await _saveDeletionHistory();

      final removedCount = initialCount - _deletionHistory.length;
      Log.debug(
        '🧹 Cleared $removedCount old deletion records',
        name: 'ContentDeletionService',
        category: LogCategory.system,
      );
    }
  }

  /// Create NIP-09 delete event (kind 5).
  /// On success [event] is non-null and [failureKind] is null; otherwise [event] is null.
  Future<({Event? event, DeleteFailureKind? failureKind})> _createDeleteEvent({
    required String originalEventId,
    required int originalEventKind,
    required String reason,
    String? addressableId,
    String? additionalContext,
  }) async {
    try {
      if (!_authService.isAuthenticated) {
        Log.error(
          'Cannot create delete event: not authenticated',
          name: 'ContentDeletionService',
          category: LogCategory.system,
        );
        return (event: null, failureKind: DeleteFailureKind.notAuthenticated);
      }

      // Build NIP-09 compliant tags (kind 5). Addressable videos need an
      // `a` tag so every replacement for the same d-tag is tombstoned.
      final tags = <List<String>>[
        ['e', originalEventId], // Event being deleted
        if (addressableId != null && addressableId.isNotEmpty)
          ['a', addressableId],
        [
          'k',
          originalEventKind.toString(),
        ], // Kind of event being deleted (NIP-09)
      ];

      // Add additional context as tags if provided
      if (additionalContext != null) {
        tags.add(['alt', additionalContext]); // Alternative description
      }

      // Create NIP-09 compliant content
      final deleteContent = _formatNip09DeleteContent(
        reason,
        additionalContext,
      );

      // Create and sign event via AuthService
      final signedEvent = await _authService.createAndSignEvent(
        kind: 5, // NIP-09 delete event kind
        content: deleteContent,
        tags: tags,
      );

      if (signedEvent == null) {
        Log.error(
          'Failed to create and sign NIP-09 delete event',
          name: 'ContentDeletionService',
          category: LogCategory.system,
        );
        return (event: null, failureKind: DeleteFailureKind.couldNotSign);
      }

      Log.info(
        'Created NIP-09 delete event (kind 5): ${signedEvent.id}',
        name: 'ContentDeletionService',
        category: LogCategory.system,
      );
      Log.debug(
        'Deleting: $originalEventId for reason: $reason',
        name: 'ContentDeletionService',
        category: LogCategory.system,
      );

      return (event: signedEvent, failureKind: null);
    } catch (e) {
      Log.error(
        'Failed to create NIP-09 delete event: $e',
        name: 'ContentDeletionService',
        category: LogCategory.system,
      );
      return (event: null, failureKind: DeleteFailureKind.unknown);
    }
  }

  /// Format delete content for NIP-09 compliance (kind 5)
  String _formatNip09DeleteContent(String reason, String? additionalContext) {
    final buffer = StringBuffer();
    buffer.writeln('CONTENT DELETION - NIP-09');
    buffer.writeln('Reason: $reason');

    if (additionalContext != null) {
      buffer.writeln('Additional Context: $additionalContext');
    }

    buffer.writeln(
      'Content deleted by author via Divine for Apple App Store compliance',
    );
    return buffer.toString();
  }

  /// Check if this is the user's own content
  bool _isUserOwnContent(VideoEvent video) {
    final userPubkey = _authService.currentPublicKeyHex;

    return video.pubkey == userPubkey;
  }

  String? _addressableDeletionTarget(VideoEvent video) {
    // Do not emit an empty-d coordinate for d-less addressable videos; delete
    // only the concrete event id when the event carried no real d tag.
    return video.hasAddressableDTag ? video.addressableId : null;
  }

  /// Get delete reason text for common cases
  String _getDeleteReasonText(DeleteReason reason) {
    switch (reason) {
      case DeleteReason.personalChoice:
        return 'Personal choice - no longer wish to share this content';
      case DeleteReason.privacy:
        return 'Privacy concerns - content contains personal information';
      case DeleteReason.inappropriate:
        return 'Content inappropriate - does not meet community standards';
      case DeleteReason.copyrightViolation:
        return 'Copyright violation - content may infringe on intellectual property';
      case DeleteReason.technicalIssues:
        return 'Technical issues - content has quality or playback problems';
      case DeleteReason.other:
        return 'Other reasons - user requested content removal';
    }
  }

  /// Load deletion history from storage
  void _loadDeletionHistory() {
    final historyJson = _prefs.getString(deletionsStorageKey);
    if (historyJson != null) {
      try {
        _deletionHistory.clear();
        _deletionHistory.addAll(parseDeletionHistory(historyJson));
        Log.debug(
          '📱 Loaded ${_deletionHistory.length} deletions from history',
          name: 'ContentDeletionService',
          category: LogCategory.system,
        );
      } catch (e) {
        Log.error(
          'Failed to load deletion history: $e',
          name: 'ContentDeletionService',
          category: LogCategory.system,
        );
      }
    }
  }

  /// Save deletion history to storage
  Future<void> _saveDeletionHistory() async {
    try {
      final deletionsJson = _deletionHistory
          .map((deletion) => deletion.toJson())
          .toList();
      await _prefs.setString(deletionsStorageKey, jsonEncode(deletionsJson));
    } catch (e) {
      Log.error(
        'Failed to save deletion history: $e',
        name: 'ContentDeletionService',
        category: LogCategory.system,
      );
    }
  }

  void dispose() {
    // Clean up any active operations
  }
}

/// Common delete reasons for user content
enum DeleteReason {
  personalChoice,
  privacy,
  inappropriate,
  copyrightViolation,
  technicalIssues,
  other,
}
