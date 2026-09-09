// ABOUTME: Renders background pushes and routes a notification tap to a route
// ABOUTME: Split out of main.dart, which only wires the entry point (#3337)

import 'dart:async';
import 'dart:convert';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/notifications/routing/notification_tap_target.dart';
import 'package:openvine/notifications/view/notifications_page.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/deep_link_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/router/deep_link_coordinator.dart';
import 'package:openvine/router/router.dart';
import 'package:openvine/screens/curated_list_by_author_screen.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/services/deep_link_service.dart';
import 'package:openvine/services/firebase_initialization.dart';
import 'package:openvine/services/notification_helpers.dart'
    show localNotificationTapPayload;
import 'package:openvine/services/notification_target_resolver.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:unified_logger/unified_logger.dart';

/// Whether the background isolate should render a local notification for
/// [message].
///
/// iOS alert pushes (the push service sets `aps.alert` + `content_available`)
/// are presented by the OS *and* wake this handler — building our own local
/// notification on top would double-render (#4731). FlutterFire surfaces the
/// OS-presented alert as [RemoteMessage.notification], so we render only when
/// the OS has not already presented it: a data-only message that carries a
/// body. Today that is Android (the service stays data-only there); the
/// data-only iOS branch is defensive, for a future silent push the OS would
/// not surface.
@visibleForTesting
bool shouldRenderLocalPushNotification(RemoteMessage message) {
  if (message.notification != null) return false;
  final body = message.data['body'];
  return body is String && body.isNotEmpty;
}

typedef BackgroundFirebaseInitializer = Future<void> Function();
typedef BackgroundLocalPushRenderer = Future<void> Function({
  required int id,
  required String? title,
  required String body,
  required Map<String, dynamic> data,
});
Future<void> handleFirebaseMessagingBackgroundMessage(
  RemoteMessage message, {
  BackgroundFirebaseInitializer initializeFirebase =
      ensureDefaultFirebaseInitialized,
  BackgroundLocalPushRenderer renderLocalPush = _renderBackgroundLocalPush,
}) async {
  try {
    await initializeFirebase();
  } catch (error) {
    Log.warning(
      'Firebase init failed in background push handler; attempting local '
      'notification render: $error',
      name: 'PushNotifications',
    );
  }

  // The OS already presents iOS alert pushes (aps.alert); only render a local
  // notification for data-only messages so we don't double-render (#4731).
  if (!shouldRenderLocalPushNotification(message)) return;

  final data = message.data;
  final title = data['title'] as String? ?? 'Divine';
  final body = data['body'] as String? ?? '';

  await renderLocalPush(
    id: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    title: title,
    body: body,
    data: data,
  );
}

Future<void> _renderBackgroundLocalPush({
  required int id,
  required String? title,
  required String body,
  required Map<String, dynamic> data,
}) async {
  final plugin = FlutterLocalNotificationsPlugin();
  const androidInit = AndroidInitializationSettings('@mipmap/ic_launcher');
  const darwinInit = DarwinInitializationSettings(
    requestBadgePermission: false,
  );
  const initSettings = InitializationSettings(
    android: androidInit,
    iOS: darwinInit,
    macOS: darwinInit,
  );
  await plugin.initialize(settings: initSettings);

  const androidDetails = AndroidNotificationDetails(
    'openvine_push',
    'Push Notifications',
    channelDescription: 'Notifications from Divine',
    importance: Importance.high,
    priority: Priority.high,
  );
  const details = NotificationDetails(
    android: androidDetails,
    iOS: DarwinNotificationDetails(presentBadge: false),
    macOS: DarwinNotificationDetails(presentBadge: false),
  );

  await plugin.show(
    id: id,
    title: title,
    body: body,
    notificationDetails: details,
    // Carry the normalized tap payload (shared with the foreground path via
    // localNotificationTapPayload) so a tap on this background-built
    // notification routes identically to a system push tap.
    payload: jsonEncode(localNotificationTapPayload(data)),
  );
}

/// Resolves a push/local payload to a [NotificationTapTarget], the event id to
/// navigate to, and the authoritative video coordinate, via the shared
/// [resolveNotificationTapTarget] contract.
///
/// `referencedAddress` (the signed NIP-33 coordinate of the referenced video)
/// is the authoritative target: when it is a usable video coordinate
/// ([videoAddressableTarget]) it is returned as `videoCoordinate` and the
/// executor routes to it directly. Otherwise the video target is
/// `referencedEventId` (the event acted upon), falling back to `eventId` (the
/// source event) for follow/mention, which the executor walks to a root video.
///
/// At most one of `videoCoordinate` / `targetEventId` is non-null: a usable
/// coordinate suppresses the event-id walk entirely, encoding the
/// coordinate-over-walk precedence in the returned value rather than leaving
/// it to the executor's branch order.
///
/// Extracted and `@visibleForTesting` so the push-side per-kind routing can be
/// asserted without a navigator — mirrors [resolveVideoDeepLinkNavAction].
@visibleForTesting
({NotificationTapTarget target, String? targetEventId, String? videoCoordinate})
pushNotificationTapTarget({
  required String? referencedAddress,
  required String? referencedEventId,
  required String? eventId,
  required String? notificationType,
  required String? senderPubkey,
}) {
  final videoCoordinate = videoAddressableTarget(referencedAddress);
  final targetEventId = videoCoordinate != null
      ? null
      : (referencedEventId != null && referencedEventId.isNotEmpty)
      ? referencedEventId
      : eventId;
  final hasVideoTarget =
      videoCoordinate != null ||
      (targetEventId != null && targetEventId.isNotEmpty);
  return (
    target: resolveNotificationTapTarget(
      kind: notificationKindFromPushType(notificationType),
      hasVideoTarget: hasVideoTarget,
      actorPubkey: senderPubkey,
    ),
    targetEventId: targetEventId,
    videoCoordinate: videoCoordinate,
  );
}

/// Routes a notification tap (FCM system push, local notification, or
/// cold-start) to a destination using the shared [resolveNotificationTapTarget]
/// contract — the same contract the in-app notification rows use, so the three
/// entry points share one target-selection policy even though each executor
/// keeps its own navigation mechanics.
///
/// [referencedEventId] is the event acted upon (present for like/comment/
/// repost). [eventId] is the source event itself, used as the target for
/// mentions, which carry no `referencedEventId`. [senderPubkey] is the actor —
/// it opens a profile for follows and is the safe fallback when a video target
/// cannot be resolved.
///
/// Failure UX contract (decided in #5079): the profile/inbox fallback applies
/// only to the event-id walk, where resolution happens *before* a route exists
/// and can fail. A valid video coordinate is pushed without a pre-fetch; if
/// the video is then unfetchable (deleted, moderated, offline), the user
/// intentionally lands on [VideoDetailScreen]'s error state — same
/// trust-the-coordinate contract as the in-app rows, which push immediately on
/// an addressable id and surface fetch failure in place. Redirecting a "they
/// interacted with your video" tap to the actor's profile would be
/// misdirection, and a pre-push fetch would reintroduce the relay round-trip
/// this path exists to avoid. Transient failures are already mitigated
/// downstream: the route lookup tries cache → Funnelcake REST → relays, and
/// the screen retries once when relays become ready on cold start.
Future<void> routeNotificationTap({
  required String? referencedAddress,
  required String? referencedEventId,
  required String? eventId,
  required String? notificationType,
  required String? senderPubkey,
  required ProviderContainer container,
}) async {
  final (:target, :targetEventId, :videoCoordinate) = pushNotificationTapTarget(
    referencedAddress: referencedAddress,
    referencedEventId: referencedEventId,
    eventId: eventId,
    notificationType: notificationType,
    senderPubkey: senderPubkey,
  );

  switch (target) {
    case OpenListTarget(:final pubkey, :final listId):
      container
          .read(goRouterProvider)
          .push(
            CuratedListByAuthorScreen.pathFor(pubkey: pubkey, listId: listId),
          );
    case OpenProfileTarget(:final actorPubkey):
      _navigateToNotificationProfile(container, actorPubkey);
    case OpenInboxTarget():
      _navigateToNotificationInbox(container);
    case OpenVideoTarget(:final autoOpenComments):
      if (videoCoordinate != null) {
        // Authoritative path: the signed NIP-33 coordinate is stable across
        // metadata replacements and resolves without a relay round-trip, so
        // push it straight to the video route.
        _pushVideoDeepLink(
          container,
          videoRef: videoCoordinate,
          autoOpenComments: autoOpenComments,
        );
      } else {
        await _resolveAndPushVideoLink(
          container: container,
          targetEventId: targetEventId!,
          autoOpenComments: autoOpenComments,
          fallbackPubkey: senderPubkey,
        );
      }
  }
}

/// Resolves [targetEventId] to a root video and pushes a video [DeepLink].
///
/// For comment/reply targets [targetEventId] is a Kind 1111 comment event, not
/// a video; [NotificationTargetResolver] walks its NIP-22 `E` / NIP-10 `e`
/// tags to the root video. When resolution fails the tap falls back to the
/// actor's profile (or the inbox if no pubkey is known) instead of silently
/// doing nothing.
Future<void> _resolveAndPushVideoLink({
  required ProviderContainer container,
  required String targetEventId,
  required bool autoOpenComments,
  required String? fallbackPubkey,
}) async {
  String? videoEventId;
  try {
    videoEventId = await NotificationTargetResolver(
      videoEventService: container.read(videoEventServiceProvider),
      nostrService: container.read(nostrServiceProvider),
    ).resolveVideoEventIdFromNotificationTarget(targetEventId);
  } catch (e) {
    Log.error(
      'Failed to resolve notification target: $e',
      name: 'main',
      category: LogCategory.system,
    );
  }

  if (videoEventId == null) {
    Log.warning(
      'Could not resolve notification target to a video '
      '(targetEventId=$targetEventId) — falling back',
      name: 'main',
      category: LogCategory.system,
    );
    if (fallbackPubkey != null && fallbackPubkey.isNotEmpty) {
      _navigateToNotificationProfile(container, fallbackPubkey);
    } else {
      _navigateToNotificationInbox(container);
    }
    return;
  }

  _pushVideoDeepLink(
    container,
    videoRef: videoEventId,
    autoOpenComments: autoOpenComments,
  );
}

/// Pushes a video [DeepLink] for [videoRef] (an event id or a NIP-33
/// `kind:pubkey:d-tag` coordinate) through the shared deep-link stream.
void _pushVideoDeepLink(
  ProviderContainer container, {
  required String videoRef,
  required bool autoOpenComments,
}) {
  container
      .read(deepLinkServiceProvider)
      .pushLink(
        DeepLink(
          type: DeepLinkType.video,
          videoRef: videoRef,
          autoOpenComments: autoOpenComments,
        ),
      );
}

/// Opens the actor's profile. Used for follow taps and as the fallback when a
/// video target cannot be resolved.
void _navigateToNotificationProfile(
  ProviderContainer container,
  String actorPubkeyHex,
) {
  final npub = NostrKeyUtils.encodePubKey(actorPubkeyHex);
  container.read(goRouterProvider).push(OtherProfileScreen.pathForNpub(npub));
}

/// Opens the notifications inbox — the deterministic safe fallback when a tap
/// carries no resolvable target and no actor pubkey.
void _navigateToNotificationInbox(ProviderContainer container) {
  container.read(goRouterProvider).go(NotificationsPage.pathForIndex());
}
