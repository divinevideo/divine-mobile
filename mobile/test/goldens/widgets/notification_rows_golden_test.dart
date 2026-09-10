// ABOUTME: Combined layout tests for notification rows, covering the default
// ABOUTME: and large-text layouts that were stabilized for issues #4206/#3387.
import 'package:clock/clock.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/notifications/widgets/actor_notification_row.dart';
import 'package:openvine/notifications/widgets/notification_video_thumbnail.dart';
import 'package:openvine/notifications/widgets/video_notification_row.dart';
import 'package:openvine/widgets/user_avatar.dart';

const _alice = ActorInfo(
  pubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  displayName: 'Alice',
);

const _bob = ActorInfo(
  pubkey: 'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb',
  displayName: 'Bob',
);

final _goldenNow = DateTime.utc(2026, 5, 15, 23);
final _notificationTimestamp = DateTime.utc(2026, 5, 15, 12);
final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

void main() {
  group('Notification row layouts', () {
    testWidgets('notification rows render default layout', (tester) async {
      await withClock(Clock(() => _goldenNow), () async {
        await _pumpScenario(
          tester,
          textScaleFactor: 1,
          surfaceSize: const Size(420, 680),
        );

        expect(find.byType(ActorNotificationRow), findsOneWidget);
        expect(find.byType(VideoNotificationRow), findsNWidgets(2));
        expect(find.text(_l10n.notificationFollowBack), findsOneWidget);
        expect(find.textContaining('Literature'), findsOneWidget);
        expect(
          find.byType(NotificationVideoThumbnail),
          findsNWidgets(2),
          reason: 'Default layout should keep the thumbnail inline.',
        );
        final actorAvatar = find.descendant(
          of: find.byType(ActorNotificationRow),
          matching: find.byType(UserAvatar),
        );
        final avatarRow = find
            .ancestor(of: actorAvatar, matching: find.byType(Row))
            .first;
        expect(
          find.descendant(of: avatarRow, matching: find.byType(DivineButton)),
          findsOneWidget,
          reason: 'Default layout should keep Follow back inline with avatar.',
        );
        final message = tester.getTopLeft(
          find
              .descendant(
                of: find.byType(VideoNotificationRow),
                matching: find.textContaining('Alice'),
              )
              .first,
        );
        final thumbnail = tester.getTopLeft(
          find.byType(NotificationVideoThumbnail).first,
        );
        expect(
          thumbnail.dy,
          lessThan(message.dy),
          reason: 'Default layout should keep the thumbnail inline.',
        );
        expect(tester.takeException(), isNull);
      });
    }, tags: ['golden']);

    testWidgets('notification rows render max-font layout', (tester) async {
      await withClock(Clock(() => _goldenNow), () async {
        await _pumpScenario(
          tester,
          textScaleFactor: 2,
          surfaceSize: const Size(420, 1400),
        );

        expect(find.byType(ActorNotificationRow), findsOneWidget);
        expect(find.byType(VideoNotificationRow), findsNWidgets(2));
        expect(find.text(_l10n.notificationFollowBack), findsOneWidget);
        expect(find.textContaining('Literature'), findsOneWidget);
        expect(
          find.byType(NotificationVideoThumbnail),
          findsNWidgets(2),
          reason: 'Large-text layout should still render the thumbnail.',
        );
        final actorAvatar = find.descendant(
          of: find.byType(ActorNotificationRow),
          matching: find.byType(UserAvatar),
        );
        final avatar = tester.getTopLeft(actorAvatar);
        final button = tester.getTopLeft(find.byType(DivineButton));
        expect(
          button.dy,
          greaterThan(avatar.dy),
          reason: 'Large-text layout should stack Follow back below avatar.',
        );
        final message = tester.getTopLeft(
          find
              .descendant(
                of: find.byType(VideoNotificationRow),
                matching: find.textContaining('Alice'),
              )
              .first,
        );
        final thumbnail = tester.getTopLeft(
          find.byType(NotificationVideoThumbnail).first,
        );
        expect(
          thumbnail.dy,
          greaterThan(message.dy),
          reason: 'Large-text layout should stack the thumbnail below text.',
        );
        expect(tester.takeException(), isNull);
      });
    }, tags: ['golden']);
  });
}

Widget _scenarioColumn({required double textScaleFactor}) {
  final actorNotification = ActorNotification(
    id: 'follow-1',
    type: NotificationKind.follow,
    actor: _alice,
    timestamp: _notificationTimestamp,
  );
  final videoNotification = VideoNotification(
    id: 'comment-1',
    type: NotificationKind.comment,
    videoEventId:
        '1111111111111111111111111111111111111111111111111111111111111111',
    actors: const [_alice, _bob],
    totalCount: 2,
    timestamp: _notificationTimestamp,
    videoTitle: 'A longer title that exercises the responsive row layout',
    commentText:
        'This is a longer preview comment that should still render cleanly.',
  );
  final listAddNotification = VideoNotification(
    id: 'list-add-1',
    type: NotificationKind.listAdd,
    videoEventId:
        '2222222222222222222222222222222222222222222222222222222222222222',
    actors: const [_alice],
    totalCount: 1,
    timestamp: _notificationTimestamp,
    videoTitle: 'A vine that found a new shelf',
    listTitle: 'Literature',
    listCoordinate: '30005:aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa:literature',
  );

  return Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      _scenario(
        textScaleFactor: textScaleFactor,
        child: ActorNotificationRow(
          notification: actorNotification,
          onTap: () {},
          onProfileTap: () {},
          onFollowBack: () {},
        ),
      ),
      const SizedBox(height: 16),
      _scenario(
        textScaleFactor: textScaleFactor,
        child: VideoNotificationRow(
          notification: videoNotification,
          onTap: () {},
          onProfileTap: () {},
          onThumbnailTap: () {},
        ),
      ),
      const SizedBox(height: 16),
      _scenario(
        textScaleFactor: textScaleFactor,
        child: VideoNotificationRow(
          notification: listAddNotification,
          onTap: () {},
          onProfileTap: () {},
          onThumbnailTap: () {},
        ),
      ),
    ],
  );
}

Future<void> _pumpScenario(
  WidgetTester tester, {
  required double textScaleFactor,
  required Size surfaceSize,
}) async {
  await tester.binding.setSurfaceSize(surfaceSize);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      theme: VineTheme.theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      // Scrollable so the column's height is unbounded. VineTheme renders
      // through google_fonts, which registers its families asynchronously:
      // whichever test runs first in the isolate lays out with the fallback
      // test font, whose glyphs are ~2x wider and re-wrap the rows into
      // roughly twice the height. Against a fixed surface that overflowed
      // the flex and failed the run-order lottery under
      // `--test-randomize-ordering-seed random`.
      home: Scaffold(
        body: SingleChildScrollView(
          child: _scenarioColumn(textScaleFactor: textScaleFactor),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

Widget _scenario({required double textScaleFactor, required Widget child}) {
  return SizedBox(
    width: 320,
    child: MediaQuery(
      data: MediaQueryData(textScaler: TextScaler.linear(textScaleFactor)),
      child: DecoratedBox(
        decoration: const BoxDecoration(color: VineTheme.backgroundColor),
        child: child,
      ),
    ),
  );
}
