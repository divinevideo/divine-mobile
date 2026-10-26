// ABOUTME: Warms public notification targets without delaying display or taps.
// ABOUTME: Reuses the routing contract and injected repository/cache operations.

import 'dart:async';

import 'package:models/models.dart';
import 'package:openvine/notifications/routing/notification_tap_target.dart';
import 'package:openvine/services/notification_helpers.dart';

/// Best-effort warming of public metadata and thumbnails. It never downloads
/// video bytes, opens private messages, changes navigation, or displays alerts.
class NotificationContentPreloader {
  NotificationContentPreloader({
    required Future<VideoEvent?> Function(String routeId) loadVideo,
    required Future<void> Function(String url) cacheThumbnail,
    Future<void> Function(String pubkey)? loadProfile,
    Future<String?> Function(String eventId)? resolveVideoTarget,
    Duration timeout = const Duration(seconds: 5),
  }) : _loadVideo = loadVideo,
       _cacheThumbnail = cacheThumbnail,
       _loadProfile = loadProfile,
       _resolveVideoTarget = resolveVideoTarget,
       _timeout = timeout;

  final Future<VideoEvent?> Function(String) _loadVideo;
  final Future<void> Function(String) _cacheThumbnail;
  final Future<void> Function(String)? _loadProfile;
  final Future<String?> Function(String)? _resolveVideoTarget;
  final Duration _timeout;
  final _active = <String>{};
  bool _disposed = false;

  void dispose() => _disposed = true;

  Future<void> preload(Map<String, dynamic> data) async {
    if (_disposed || _active.length >= 2) return;
    final payload = parseFcmPayload(data);
    if (payload == null ||
        !const {
          'like',
          'comment',
          'mention',
          'repost',
          'newPost',
          'follow',
        }.contains(payload.notificationType)) {
      return;
    }
    final coordinate = videoAddressableTarget(payload.referencedAddress);
    final eventId = payload.referencedEventId ?? payload.eventId;
    final routeId = coordinate ?? eventId;
    final isFollow = payload.notificationType == 'follow';
    final key = isFollow ? payload.senderPubkey : routeId;
    if (key == null || !_active.add(key)) return;
    final deadline = DateTime.now().add(_timeout);
    bool current() => !_disposed && DateTime.now().isBefore(deadline);
    final profileWork = () async {
      try {
        final actor = payload.senderPubkey;
        if (actor != null && current()) await _loadProfile?.call(actor);
      } on Object {
        // Missing profile metadata must not prevent warming the video.
      }
    }();
    final work = () async {
      try {
        if (isFollow || routeId == null || !current()) return;
        final resolved = coordinate != null || _resolveVideoTarget == null
            ? routeId
            : await _resolveVideoTarget(routeId);
        if (resolved == null || !current()) return;
        final video = await _loadVideo(resolved);
        if (video == null || !current()) return;
        final thumbnail = video.thumbnailUrl;
        if (thumbnail != null && thumbnail.isNotEmpty) {
          await _cacheThumbnail(thumbnail);
        }
      } on Object {
        // Warming is optional. Repositories retain their normal failure and
        // retry behavior when the user opens the notification.
      } finally {
        await profileWork;
        _active.remove(key);
      }
    }();
    // Keep the active slot until the underlying work ends, even on timeout:
    // a stalled lookup must not let a push burst start unbounded requests.
    await work.timeout(_timeout, onTimeout: () {});
  }
}
