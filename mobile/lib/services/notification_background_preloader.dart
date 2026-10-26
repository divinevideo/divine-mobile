// ABOUTME: Best-effort public thumbnail warming in the Firebase background isolate.
// ABOUTME: Uses a short-lived HTTP client and the foreground thumbnail disk cache.

import 'dart:async';

import 'package:funnelcake_api_client/funnelcake_api_client.dart';
import 'package:models/models.dart';
import 'package:openvine/services/environment_service.dart';
import 'package:openvine/services/notification_content_preloader.dart';
import 'package:openvine/services/notification_helpers.dart';
import 'package:openvine/utils/open_vine_image_cache.dart';

/// Cache the same URL key used by VineCachedImage, cancelling slow downloads.
Future<void> cacheNotificationThumbnail(String url) async {
  final operation = openVineImageCache.cacheFileCancellable(url, key: url);
  try {
    await operation.result.timeout(const Duration(seconds: 3));
  } on TimeoutException {
    operation.cancel();
  }
}

/// Background execution is optional: a missing platform service, offline device,
/// unsupported target, or OS suspension must never prevent notification display.
/// Only public thumbnails are warmed here; the account's foreground repository
/// owns metadata/profile persistence and all content filtering on open.
Future<void> preloadBackgroundNotification(
  Map<String, dynamic> data, {
  FunnelcakeApiClient? apiClient,
  Future<void> Function(String) cacheThumbnail = cacheNotificationThumbnail,
}) async {
  final payload = parseFcmPayload(data);
  if (payload == null ||
      !const {
        'like',
        'comment',
        'mention',
        'repost',
        'newPost',
      }.contains(payload.notificationType)) {
    return;
  }
  final environment = EnvironmentService();
  FunnelcakeApiClient? client;
  NotificationContentPreloader? preloader;
  try {
    if (apiClient == null) {
      await environment.initialize().timeout(const Duration(seconds: 1));
    }
    final api =
        apiClient ??
        FunnelcakeApiClient(
          baseUrl: environment.currentConfig.apiBaseUrl,
          timeout: const Duration(seconds: 3),
        );
    client = api;
    preloader = NotificationContentPreloader(
      loadVideo: (routeId) async {
        final coordinate = parseAddressableId(routeId);
        final id = coordinate?.dTag ?? routeId;
        // getVideoEvent safely percent-encodes a route id. Validate the signed
        // target's author before using a same-d-tag REST result.
        final event = await api.getVideoEvent(id);
        if (event == null ||
            (coordinate == null && event.id != routeId) ||
            (coordinate != null &&
                (event.pubkey != coordinate.pubkey ||
                    event.kind != coordinate.kind ||
                    !event.tags.any(
                      (tag) =>
                          tag.length >= 2 &&
                          tag[0] == 'd' &&
                          tag[1] == coordinate.dTag,
                    )))) {
          return null;
        }
        return VideoEvent.fromNostrEvent(event);
      },
      cacheThumbnail: cacheThumbnail,
    );
    await preloader.preload(data);
  } on Object {
    // Preloading is expendable; opening follows the normal repository path.
  } finally {
    preloader?.dispose();
    if (apiClient == null) client?.dispose();
    environment.dispose();
  }
}
