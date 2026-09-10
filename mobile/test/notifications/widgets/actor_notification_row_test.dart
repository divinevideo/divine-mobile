// ABOUTME: Tests for ActorNotificationRow — follow / mention / system /
// ABOUTME: like / likeComment / reply rendering, follow-back button visibility,
// ABOUTME: and tap callbacks.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart';
import 'package:openvine/constants/notification_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/notifications/widgets/actor_notification_row.dart';
import 'package:openvine/notifications/widgets/notification_comment_quote.dart';
import 'package:openvine/widgets/notification_type_icon.dart';
import 'package:openvine/widgets/user_avatar.dart';

const _alice = ActorInfo(
  pubkey: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
  displayName: 'Alice',
);

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));
final AppLocalizations _jaL10n = lookupAppLocalizations(const Locale('ja'));

ActorNotification _actor({
  String id = 'n1',
  NotificationKind type = NotificationKind.follow,
  String? commentText,
  bool isFollowingBack = false,
  bool isRead = false,
}) {
  return ActorNotification(
    id: id,
    type: type,
    actor: _alice,
    timestamp: DateTime.utc(2026, 5, 4, 12),
    commentText: commentText,
    isFollowingBack: isFollowingBack,
    isRead: isRead,
  );
}

Future<void> _pump(
  WidgetTester tester, {
  required ActorNotification notification,
  VoidCallback? onTap,
  VoidCallback? onProfileTap,
  VoidCallback? onFollowBack,
  Locale? locale,
  double textScaleFactor = 1,
}) async {
  // Pin a tall, deterministic surface: the 2× stacked layout needs the
  // vertical room production's scrollable list gives it, and pinning makes
  // the file immune to surface-size leaks under the shared-isolate CI run
  // (`very_good test --optimization`). Reset after each test. See #4719.
  await tester.binding.setSurfaceSize(const Size(420, 1200));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(
    MaterialApp(
      locale: locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MediaQuery(
          data: MediaQueryData(textScaler: TextScaler.linear(textScaleFactor)),
          child: SizedBox(
            width: 320,
            child: ActorNotificationRow(
              notification: notification,
              onTap: onTap ?? () {},
              onProfileTap: onProfileTap ?? () {},
              onFollowBack: onFollowBack,
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  group(ActorNotificationRow, () {
    group('renders', () {
      testWidgets('leading $NotificationTypeIcon for every kind', (
        tester,
      ) async {
        await _pump(tester, notification: _actor());
        expect(find.byType(NotificationTypeIcon), findsOneWidget);
      });

      testWidgets('"{actor} started following you" for follow', (tester) async {
        await _pump(tester, notification: _actor());

        expect(
          find.textContaining(_l10n.notificationStartedFollowing('Alice')),
          findsOneWidget,
        );
      });

      testWidgets('"{actor} mentioned you" for mention', (tester) async {
        await _pump(
          tester,
          notification: _actor(type: NotificationKind.mention),
        );

        expect(
          find.textContaining(_l10n.notificationMentionedYou('Alice')),
          findsOneWidget,
        );
      });

      testWidgets('system message for system kind', (tester) async {
        await _pump(
          tester,
          notification: _actor(type: NotificationKind.system),
        );

        expect(
          find.textContaining(_l10n.notificationSystemUpdate),
          findsOneWidget,
        );
      });

      testWidgets('"{actor} liked your comment" for likeComment', (
        tester,
      ) async {
        await _pump(
          tester,
          notification: _actor(type: NotificationKind.likeComment),
        );

        expect(
          find.textContaining(_l10n.notificationLikedYourComment('Alice')),
          findsOneWidget,
        );
      });

      testWidgets('"{actor} liked your video" for anchorless like', (
        tester,
      ) async {
        await _pump(
          tester,
          notification: _actor(type: NotificationKind.like),
        );

        expect(
          find.textContaining(_l10n.notificationLikedYourVideo('Alice')),
          findsOneWidget,
        );
        expect(
          find.textContaining(_l10n.notificationLikedYourComment('Alice')),
          findsNothing,
        );
      });

      testWidgets('"{actor} replied to your comment" for reply', (
        tester,
      ) async {
        await _pump(tester, notification: _actor(type: NotificationKind.reply));

        expect(
          find.textContaining(_l10n.notificationRepliedToYourComment('Alice')),
          findsOneWidget,
        );
      });

      testWidgets(
        'uses locale-correct single-actor wording for Japanese mention text',
        (tester) async {
          await _pump(
            tester,
            locale: const Locale('ja'),
            notification: _actor(type: NotificationKind.mention),
          );

          expect(
            find.textContaining(_jaL10n.notificationMentionedYou('Alice')),
            findsOneWidget,
          );
        },
      );

      testWidgets('uses locale-correct reply wording for Japanese reply text', (
        tester,
      ) async {
        await _pump(
          tester,
          locale: const Locale('ja'),
          notification: _actor(type: NotificationKind.reply),
        );

        expect(
          find.textContaining(
            _jaL10n.notificationRepliedToYourComment('Alice'),
          ),
          findsOneWidget,
        );
      });

      testWidgets('Follow back button when not yet following', (tester) async {
        await _pump(tester, notification: _actor());

        expect(find.text(_l10n.notificationFollowBack), findsOneWidget);
      });

      testWidgets(
        'Follow back button uses DivineButtonSize.tiny (32px visible)',
        (tester) async {
          await _pump(tester, notification: _actor());

          final button = tester.widget<DivineButton>(find.byType(DivineButton));
          expect(button.size, equals(DivineButtonSize.tiny));
        },
      );

      testWidgets(
        'Follow back button shares its row with the avatar so message '
        'text width is stable when the button appears / disappears',
        (tester) async {
          await _pump(tester, notification: _actor());

          // The Row that holds the avatar must also hold the Follow back
          // button — they're siblings, not children of separate columns.
          // If the button were a sibling of the entire content column the
          // message text below would re-wrap when the button appears or
          // disappears.
          final avatarRow = find
              .ancestor(of: find.byType(UserAvatar), matching: find.byType(Row))
              .first;
          expect(
            find.descendant(of: avatarRow, matching: find.byType(DivineButton)),
            findsOneWidget,
          );
        },
      );

      testWidgets('no Follow back button when already following back', (
        tester,
      ) async {
        await _pump(tester, notification: _actor(isFollowingBack: true));

        expect(find.text(_l10n.notificationFollowBack), findsNothing);
      });

      testWidgets('stacks Follow back below the avatar at large text sizes', (
        tester,
      ) async {
        await _pump(tester, notification: _actor(), textScaleFactor: 2);

        final avatar = tester.getTopLeft(find.byType(UserAvatar));
        final button = tester.getTopLeft(find.byType(DivineButton));
        expect(button.dy, greaterThan(avatar.dy));
      });

      testWidgets('keeps Follow back inline below the stack threshold', (
        tester,
      ) async {
        await _pump(
          tester,
          notification: _actor(),
          textScaleFactor:
              NotificationConstants.actorRowLargeTextStackThreshold - 0.01,
        );

        final avatarRow = find
            .ancestor(of: find.byType(UserAvatar), matching: find.byType(Row))
            .first;
        expect(
          find.descendant(of: avatarRow, matching: find.byType(DivineButton)),
          findsOneWidget,
        );
      });

      testWidgets('stacks Follow back above the stack threshold', (
        tester,
      ) async {
        await _pump(
          tester,
          notification: _actor(),
          textScaleFactor:
              NotificationConstants.actorRowLargeTextStackThreshold + 0.01,
        );

        final avatar = tester.getTopLeft(find.byType(UserAvatar));
        final button = tester.getTopLeft(find.byType(DivineButton));
        final avatarRow = find
            .ancestor(of: find.byType(UserAvatar), matching: find.byType(Row))
            .first;
        expect(
          find.descendant(of: avatarRow, matching: find.byType(DivineButton)),
          findsNothing,
        );
        expect(button.dy, greaterThan(avatar.dy));
      });

      testWidgets('comment text for mention with commentText', (tester) async {
        await _pump(
          tester,
          notification: _actor(
            type: NotificationKind.mention,
            commentText: 'Hey check this out',
          ),
        );

        expect(find.textContaining('Hey check this out'), findsOneWidget);
      });

      testWidgets('renders $NotificationCommentQuote when commentText is set', (
        tester,
      ) async {
        await _pump(
          tester,
          notification: _actor(
            type: NotificationKind.reply,
            commentText: 'I guess xd',
          ),
        );

        expect(find.byType(NotificationCommentQuote), findsOneWidget);
      });

      testWidgets('quotes the liked comment beneath a likeComment message', (
        tester,
      ) async {
        // Without the quote the row reads "Alice liked your comment" and
        // names neither the comment nor the video it lives on.
        await _pump(
          tester,
          notification: _actor(
            type: NotificationKind.likeComment,
            commentText: 'this vine still holds up',
          ),
        );

        expect(
          find.textContaining(_l10n.notificationLikedYourComment('Alice')),
          findsOneWidget,
        );
        expect(find.byType(NotificationCommentQuote), findsOneWidget);
        final quote = tester.widget<NotificationCommentQuote>(
          find.byType(NotificationCommentQuote),
        );
        expect(quote.text, equals('this vine still holds up'));
      });

      testWidgets('timestamp moves to the quote when commentText is present', (
        tester,
      ) async {
        // The timestamp must anchor to the visual end of the row, so
        // when a comment quote sits below the message the trailing
        // relative time goes inside the quote (not on the message
        // line). This locks the rendering contract that fixes the
        // "2d sandwiched between message and quote" layout regression.
        await _pump(
          tester,
          notification: _actor(
            type: NotificationKind.reply,
            commentText: 'I guess xd',
          ),
        );

        final quoteWidget = tester.widget<NotificationCommentQuote>(
          find.byType(NotificationCommentQuote),
        );
        expect(quoteWidget.timestamp, isNotNull);
        expect(quoteWidget.timestamp, isNotEmpty);
      });
    });

    group('interactions', () {
      testWidgets('tap on row fires onTap', (tester) async {
        var tapped = false;

        await _pump(tester, notification: _actor(), onTap: () => tapped = true);

        await tester.tap(find.byType(ActorNotificationRow));
        await tester.pump();

        expect(tapped, isTrue);
      });

      testWidgets('tap on Follow back fires onFollowBack', (tester) async {
        var tapped = false;

        await _pump(
          tester,
          notification: _actor(),
          onFollowBack: () => tapped = true,
        );

        await tester.tap(find.text(_l10n.notificationFollowBack));
        await tester.pump();

        expect(tapped, isTrue);
      });

      testWidgets('does not overflow at large text sizes', (tester) async {
        await _pump(
          tester,
          notification: _actor(
            commentText:
                'This is a longer quoted comment to exercise the max-font '
                'layout path.',
          ),
          textScaleFactor: 2,
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      });
    });
  });
}
