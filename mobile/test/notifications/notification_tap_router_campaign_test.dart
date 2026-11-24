import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/notifications/notification_tap_router.dart';
import 'package:openvine/notifications/routing/notification_tap_target.dart';
import 'package:openvine/router/route_paths.dart';
import 'package:openvine/services/notification_helpers.dart';
import 'package:unified_logger/unified_logger.dart';

void main() {
  final creator = 'a' * 64;
  const revision = '12345678-1234-4234-8234-123456789abc';

  group('marketing destinations', () {
    test(
      'a video campaign opens its stable coordinate without a social event',
      () {
        final coordinate = '34236:$creator:clip:with:colons';
        final result = pushNotificationTapTarget(
          referencedAddress: null,
          referencedEventId: null,
          eventId: null,
          notificationType: 'campaign',
          senderPubkey: null,
          tapTargetType: 'video_address',
          tapTargetValue: coordinate,
        );
        expect(result.target, const OpenVideoTarget(autoOpenComments: false));
        expect(result.videoCoordinate, coordinate);
        expect(result.targetEventId, isNull);
      },
    );

    test('a creator campaign opens that profile without an actor field', () {
      final result = pushNotificationTapTarget(
        referencedAddress: null,
        referencedEventId: null,
        eventId: null,
        notificationType: 'campaign',
        senderPubkey: null,
        tapTargetType: 'creator_profile',
        tapTargetValue: creator,
      );
      expect(result.target, OpenProfileTarget(creator));
      expect(result.videoCoordinate, isNull);
    });

    test('every advertised target type routes a valid value', () {
      final validValues = {
        NotificationWireValues.appRoute: RoutePaths.followingNew,
        NotificationWireValues.videoAddress: '34236:$creator:clip',
        NotificationWireValues.creatorProfile: creator,
        NotificationWireValues.announcement: revision,
        NotificationWireValues.featuredFeed: 'ft_a1b2c3d4',
      };
      for (final type in NotificationWireValues.campaignTargetTypes) {
        final result = pushNotificationTapTarget(
          referencedAddress: null,
          referencedEventId: null,
          eventId: null,
          notificationType: 'campaign',
          senderPubkey: null,
          tapTargetType: type,
          tapTargetValue: validValues[type],
        );
        expect(result.target, isNot(const OpenInboxTarget()), reason: type);
      }
    });

    for (final (type, id, location) in [
      (
        'announcement',
        revision,
        RoutePaths.announcementDetailForId(revision),
      ),
      // Funnelcake's featured-tab id shape, as `FeaturedTabsRepository`
      // compares it against the tab's id.
      (
        'featured_feed',
        'ft_a1b2c3d4',
        '/explore/tab/featured?campaignFeedId=ft_a1b2c3d4',
      ),
    ]) {
      test('$type opens the exact id through the shared tap contract', () {
        final result = pushNotificationTapTarget(
          referencedAddress: null,
          referencedEventId: null,
          eventId: null,
          notificationType: 'campaign',
          senderPubkey: null,
          tapTargetType: type,
          tapTargetValue: id,
        );
        expect(result.target, OpenAppRouteTarget(location));
      });
    }

    for (final target in [
      ('video_address', '34236:short:clip'),
      ('video_address', '34236:$creator:'),
      ('video_address', '30023:$creator:article'),
      ('video_address', '34236:${'A' * 64}:clip'),
      ('video_address', creator),
      ('creator_profile', 'short'),
      ('creator_profile', 'A' * 64),
      ('creator_profile', '34236:$creator:clip'),
      ('app_route', '/not-a-campaign-destination'),
      ('app_route', '34236:$creator:clip'),
      ('app_route', creator),
      ('https_url', 'https://example.com'),
      ('announcement', '../other'),
      ('announcement', 'ft_a1b2c3d4'),
      ('featured_feed', 'short'),
      ('featured_feed', revision),
      ('featured_feed', 'ft_A1B2C3D4'),
      ('featured_feed', 'ft_a1b2c3d'),
    ]) {
      test('unsupported ${target.$1} target "${target.$2}" falls back to the '
          'inbox', () {
        final result = pushNotificationTapTarget(
          referencedAddress: null,
          referencedEventId: null,
          eventId: null,
          notificationType: 'campaign',
          senderPubkey: null,
          tapTargetType: target.$1,
          tapTargetValue: target.$2,
        );
        expect(result.target, const OpenInboxTarget());
        expect(result.videoCoordinate, isNull);
      });
    }

    test(
      'logs the unsupported target type without the target value',
      () async {
        final logs = LogCaptureService();
        await logs.clearAllLogs();
        pushNotificationTapTarget(
          referencedAddress: null,
          referencedEventId: null,
          eventId: null,
          notificationType: 'campaign',
          senderPubkey: null,
          tapTargetType: 'video_address',
          tapTargetValue: creator,
        );
        final warning = logs
            .getRecentLogs(minLevel: LogLevel.warning)
            .map((entry) => entry.message)
            .singleWhere((message) => message.contains('Unsupported campaign'));
        expect(warning, contains('tapTargetType=video_address'));
        expect(warning, isNot(contains(creator)));
      },
    );

    test(
      'local notification normalization preserves the campaign revision',
      () {
        final normalized = localNotificationTapPayload({
          'type': 'campaign',
          'tapTargetType': 'creator_profile',
          'tapTargetValue': creator,
          'campaignRevisionId': revision,
        });
        expect(normalized['campaignRevisionId'], revision);
        expect(normalized['tapTargetValue'], creator);
      },
    );
  });
}
