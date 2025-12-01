// ABOUTME: Service for sharing videos with other users via Nostr DMs and social features
// ABOUTME: Handles sending videos to specific users and managing sharing options

import 'dart:async';

import 'package:openvine/models/video_event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/nostr_service_interface.dart';
import 'package:openvine/services/user_profile_service.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Represents a user that can receive shared videos
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class ShareableUser {
  const ShareableUser({
    required this.pubkey,
    this.displayName,
    this.picture,
    this.isFollowing = false,
    this.isFollower = false,
  });
  final String pubkey;
  final String? displayName;
  final String? picture;
  final bool isFollowing;
  final bool isFollower;
}

/// Result of sharing operation
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class ShareResult {
  const ShareResult({
    required this.success,
    this.error,
    this.messageEventId,
  });
  final bool success;
  final String? error;
  final String? messageEventId;

  static ShareResult createSuccess(String messageEventId) => ShareResult(
        success: true,
        messageEventId: messageEventId,
      );

  static ShareResult failure(String error) => ShareResult(
        success: false,
        error: error,
      );
}

/// Service for sharing videos with other users
/// REFACTORED: Removed ChangeNotifier - now uses pure state management via Riverpod
class VideoSharingService {
  VideoSharingService({
    required INostrService nostrService,
    required AuthService authService,
    required UserProfileService userProfileService,
  })  : _nostrService = nostrService,
        _authService = authService,
        _userProfileService = userProfileService;
  final INostrService _nostrService;
  final AuthService _authService;
  final UserProfileService _userProfileService;

  final List<ShareableUser> _recentlySharedWith = [];
  final Map<String, DateTime> _shareHistory = {};

  // Getters
  List<ShareableUser> get recentlySharedWith =>
      List.unmodifiable(_recentlySharedWith);

  /// Share a video with a specific user via Nostr DM
  Future<ShareResult> shareVideoWithUser({
    required VideoEvent video,
    required String recipientPubkey,
    String? personalMessage,
  }) async {
    try {
      Log.debug(
          '📱 Sharing video with user: $recipientPubkey',
          name: 'VideoSharingService',
          category: LogCategory.video);

      if (!_authService.isAuthenticated) {
        return ShareResult.failure('User not authenticated');
      }

      // Create encrypted DM with video reference
      final dmContent = _createShareMessage(video, personalMessage);

      // Create NIP-04 encrypted DM (kind 4)
      final tags = <List<String>>[
        ['p', recipientPubkey], // Recipient
        ['client', 'diVine'],
      ];

      // Add video reference as tag
      tags.add(['e', video.id]); // Reference to video event

      final event = await _authService.createAndSignEvent(
        kind: 4, // NIP-04 encrypted direct message
        content: dmContent,
        tags: tags,
      );

      if (event == null) {
        return ShareResult.failure('Failed to create share message');
      }

      // Broadcast the DM
      final result = await _nostrService.broadcastEvent(event);

      if (result.successCount > 0) {
        // Update sharing history
        _shareHistory[recipientPubkey] = DateTime.now();
        await _updateRecentlySharedWith(recipientPubkey);

        Log.info('Video shared successfully: ${event.id}',
            name: 'VideoSharingService', category: LogCategory.video);

        return ShareResult.createSuccess(event.id);
      } else {
        return ShareResult.failure('Failed to broadcast share message');
      }
    } catch (e) {
      Log.error('Error sharing video: $e',
          name: 'VideoSharingService', category: LogCategory.video);
      return ShareResult.failure('Error sharing video: $e');
    }
  }

  /// Share video to multiple users at once
  Future<Map<String, ShareResult>> shareVideoWithMultipleUsers({
    required VideoEvent video,
    required List<String> recipientPubkeys,
    String? personalMessage,
  }) async {
    final results = <String, ShareResult>{};

    for (final pubkey in recipientPubkeys) {
      final result = await shareVideoWithUser(
        video: video,
        recipientPubkey: pubkey,
        personalMessage: personalMessage,
      );
      results[pubkey] = result;
    }

    return results;
  }

  /// Get shareable users (followers, following, recent contacts)
  Future<List<ShareableUser>> getShareableUsers({int limit = 20}) async {
    try {
      final shareableUsers = <ShareableUser>[];

      // Add recently shared with users first
      shareableUsers.addAll(_recentlySharedWith.take(5));

      // TODO: Add followers and following when social service integration is complete
      // For now, return recent users

      Log.info('Found ${shareableUsers.length} shareable users',
          name: 'VideoSharingService', category: LogCategory.video);
      return shareableUsers.take(limit).toList();
    } catch (e) {
      Log.error('Error getting shareable users: $e',
          name: 'VideoSharingService', category: LogCategory.video);
      return [];
    }
  }

  /// Search for users to share with (by display name or pubkey)
  Future<List<ShareableUser>> searchUsersToShareWith(String query) async {
    try {
      // TODO: Implement user search when user directory service is available
      // For now, check if query looks like a pubkey and create a basic user

      if (query.length == 64 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(query)) {
        // Looks like a hex pubkey
        final profile = await _userProfileService.fetchProfile(query);
        return [
          ShareableUser(
            pubkey: query,
            displayName: profile?.displayName,
            picture: profile?.picture,
          ),
        ];
      }

      Log.debug('User search not yet implemented for: $query',
          name: 'VideoSharingService', category: LogCategory.video);
      return [];
    } catch (e) {
      Log.error('Error searching users: $e',
          name: 'VideoSharingService', category: LogCategory.video);
      return [];
    }
  }

  /// Generate external share URL for the video
  String generateShareUrl(VideoEvent video) {
    const baseUrl = 'https://divine.video';
    return '$baseUrl/video/${video.id}';
  }

  /// Generate share text for external sharing (social media, etc.)
  String generateShareText(VideoEvent video) {
    final title = video.title ?? 'Check out this vine!';
    final url = generateShareUrl(video);

    var shareText = title;
    if (video.hashtags.isNotEmpty) {
      final hashtags = video.hashtags.map((tag) => '#$tag').join(' ');
      shareText += '\n\n$hashtags';
    }
    shareText += '\n\nWatch on divine: $url';

    return shareText;
  }

  /// Check if user has been shared with recently
  bool hasSharedWithRecently(String pubkey) {
    final lastShared = _shareHistory[pubkey];
    if (lastShared == null) return false;

    final daysSinceShared = DateTime.now().difference(lastShared).inDays;
    return daysSinceShared < 7; // Consider "recent" as within 7 days
  }

  /// Get sharing statistics
  Map<String, dynamic> getSharingStats() {
    final totalShares = _shareHistory.length;
    final recentShares = _shareHistory.values
        .where((date) => DateTime.now().difference(date).inDays <= 30)
        .length;

    return {
      'totalShares': totalShares,
      'recentShares': recentShares,
      'uniqueRecipients': _shareHistory.keys.length,
      'averageSharesPerMonth': recentShares, // Simplified calculation
    };
  }

  /// Create the message content for sharing a video
  String _createShareMessage(VideoEvent video, String? personalMessage) {
    final buffer = StringBuffer();

    if (personalMessage != null && personalMessage.isNotEmpty) {
      buffer.writeln(personalMessage);
      buffer.writeln();
    }

    buffer.writeln('🎬 Check out this vine:');

    if (video.title != null && video.title!.isNotEmpty) {
      buffer.writeln('"${video.title}"');
    }

    if (video.videoUrl != null) {
      buffer.writeln();
      buffer.writeln(video.videoUrl);
    }

    if (video.hashtags.isNotEmpty) {
      buffer.writeln();
      buffer.writeln(video.hashtags.map((tag) => '#$tag').join(' '));
    }

    buffer.writeln();
    buffer.writeln('Shared via divine 🍇');

    return buffer.toString();
  }

  /// Update recently shared with list
  Future<void> _updateRecentlySharedWith(String pubkey) async {
    try {
      // Remove if already in list
      _recentlySharedWith.removeWhere((user) => user.pubkey == pubkey);

      // Fetch user profile for display
      final profile = await _userProfileService.fetchProfile(pubkey);

      // Add to front of list
      _recentlySharedWith.insert(
        0,
        ShareableUser(
          pubkey: pubkey,
          displayName: profile?.displayName,
          picture: profile?.picture,
        ),
      );

      // Keep only recent 10 users
      if (_recentlySharedWith.length > 10) {
        _recentlySharedWith.removeRange(10, _recentlySharedWith.length);
      }
    } catch (e) {
      Log.error('Failed to update recently shared with: $e',
          name: 'VideoSharingService', category: LogCategory.video);
    }
  }

  /// Clear sharing history (for privacy)
  void clearSharingHistory() {
    _shareHistory.clear();
    _recentlySharedWith.clear();

    Log.debug('🧹 Cleared sharing history',
        name: 'VideoSharingService', category: LogCategory.video);
  }
}
