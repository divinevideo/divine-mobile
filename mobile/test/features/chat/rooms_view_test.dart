import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:models/models.dart' hide AspectRatio;
import 'package:openvine/blocs/chat/chat_cubit.dart';
import 'package:openvine/features/chat/rooms_view.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/moderation_presentation.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/user_avatar.dart';

void main() {
  const author =
      '3333333333333333333333333333333333333333333333333333333333333333';
  const secondAuthor =
      '4444444444444444444444444444444444444444444444444444444444444444';
  final l10n = lookupAppLocalizations(const Locale('en'));

  Widget subject({
    Map<String, RoomActivitySummary> activity = const {},
    List<ChatCommunity> communities = const [
      ChatCommunity('one', 'First', ['general']),
    ],
    String Function(String, String)? channelIdFor,
    VoidCallback? onRetry,
    ThemeData? theme,
    double textScale = 1,
    bool vanished = false,
    Locale locale = const Locale('en'),
  }) => ProviderScope(
    overrides: [
      for (final pubkey in [author, secondAuthor]) ...[
        fetchUserProfileProvider(pubkey).overrideWith(
          (ref) async => UserProfile(
            pubkey: pubkey,
            displayName: pubkey == author ? 'River' : 'Sky',
            rawData: const {},
            createdAt: DateTime(2026),
            eventId: 'a' * 64,
          ),
        ),
        profileIdentityResolvingProvider(pubkey).overrideWithValue(false),
        profileVanishedProvider(pubkey).overrideWith((ref) => vanished),
        moderationPresentationProvider(pubkey).overrideWithValue(
          ModerationPresentation.ordinary,
        ),
      ],
    ],
    child: MaterialApp(
      theme: theme,
      locale: locale,
      localizationsDelegates: appLocalizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => MediaQuery(
        data: MediaQuery.of(context).copyWith(
          textScaler: TextScaler.linear(textScale),
        ),
        child: child!,
      ),
      home: Scaffold(
        body: RoomsView(
          communities: communities,
          activity: activity,
          channelIdFor: channelIdFor,
          onRetry: onRetry,
          onRoomSelected: (_, _) {},
        ),
      ),
    ),
  );

  RoomActivitySummary activeSummary({
    int unreadCount = 12,
    bool historyLimited = false,
  }) => RoomActivitySummary(
    channelId: 'general',
    latestMessage: ChatMessage(
      id: 'b' * 64,
      channelId: 'general',
      author: author,
      body: 'Original message',
      editedBody: 'Hello everyone',
      createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
    ),
    unreadCount: unreadCount,
    recentMessageCount: 24,
    recentAuthors: const [author, secondAuthor],
    historyLimited: historyLimited,
    loading: false,
  );

  group(RoomsView, () {
    testWidgets(
      'shows recent contributors, edited preview and unread activity',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          subject(activity: {'general': activeSummary()}),
        );
        await tester.pump();
        expect(find.text(l10n.listVisibilityPublic), findsOneWidget);
        expect(find.text(l10n.messagesRoomNewCount(12, '12')), findsOneWidget);
        expect(
          find.text(l10n.messagesRoomLatestMessage('River', 'Hello everyone')),
          findsOneWidget,
        );
        expect(find.text(l10n.timeNow), findsOneWidget);
        expect(
          find.text(l10n.messagesRoomContributors(2, '2')),
          findsOneWidget,
        );
        expect(
          find.text(l10n.messagesRoomRecentMessages(24, '24')),
          findsOneWidget,
        );
        expect(find.text(l10n.messagesRoomActivityPeriod), findsOneWidget);
        expect(find.byType(UserAvatar), findsNWidgets(2));
        expect(find.text('Original message'), findsNothing);
        expect(find.text(author), findsNothing);
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      'chooses badge grammar from unread count while preserving lower bounds',
      (tester) async {
        const locale = Locale('sv');
        final localized = lookupAppLocalizations(locale);
        for (final count in [1, 2]) {
          await tester.pumpWidget(
            subject(
              locale: locale,
              activity: {
                'general': activeSummary(
                  unreadCount: count,
                  historyLimited: true,
                ),
              },
            ),
          );
          await tester.pump();
          expect(
            find.text(localized.messagesRoomNewCount(count, '$count+')),
            findsOneWidget,
          );
          expect(
            find.text(
              localized.messagesRoomNewCount(count == 1 ? 2 : 1, '$count+'),
            ),
            findsNothing,
          );
        }
      },
    );

    testWidgets('caps visual badges while announcing the full unread count', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(
        subject(
          activity: {
            'general': activeSummary(unreadCount: 124),
          },
        ),
      );
      await tester.pump();
      expect(find.text(l10n.messagesRoomNewCount(124, '99+')), findsOneWidget);
      expect(
        find.bySemanticsLabel(
          RegExp(RegExp.escape(l10n.messagesRoomUnreadLabel(124, '124'))),
        ),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets(
      'keeps activity associated with the resolved channel identity',
      (
        tester,
      ) async {
        await tester.pumpWidget(
          subject(
            communities: const [
              ChatCommunity('one', 'First', ['general']),
              ChatCommunity('two', 'Second', ['general']),
            ],
            channelIdFor: (community, channel) => '$community/$channel',
            activity: {'two/general': activeSummary()},
          ),
        );
        await tester.pump();
        expect(find.text(l10n.messagesRoomLoading), findsOneWidget);
        expect(find.text(l10n.messagesRoomNewCount(12, '12')), findsOneWidget);
      },
    );

    testWidgets(
      'distinguishes unknown activity, empty rooms and retryable errors',
      (
        tester,
      ) async {
        var retried = false;
        await tester.pumpWidget(subject());
        expect(find.text(l10n.messagesRoomLoading), findsOneWidget);
        expect(find.text(l10n.messagesRoomEmpty), findsNothing);
        await tester.pumpWidget(
          subject(
            activity: const {
              'general': RoomActivitySummary(
                channelId: 'general',
                loading: false,
              ),
            },
          ),
        );
        expect(find.text(l10n.messagesRoomEmpty), findsOneWidget);
        expect(find.text(l10n.messagesRoomNewCount(0, '0')), findsNothing);
        await tester.pumpWidget(
          subject(
            activity: const {
              'general': RoomActivitySummary(
                channelId: 'general',
                loading: false,
                loadFailed: true,
              ),
            },
            onRetry: () => retried = true,
          ),
        );
        expect(find.text(l10n.messagesRoomLoadFailed), findsOneWidget);
        expect(find.text(l10n.messagesRoomEmpty), findsNothing);
        await tester.tap(find.text(l10n.commonRetry));
        expect(retried, isTrue);
      },
    );

    testWidgets('shows retained counts as lower bounds and hides read badges', (
      tester,
    ) async {
      await tester.pumpWidget(
        subject(
          activity: {
            'general': activeSummary(unreadCount: 0, historyLimited: true),
          },
        ),
      );
      await tester.pump();
      expect(find.text(l10n.messagesRoomNewCount(0, '0')), findsNothing);
      expect(find.text(l10n.messagesRoomContributors(2, '2+')), findsOneWidget);
      expect(
        find.text(l10n.messagesRoomRecentMessages(24, '24+')),
        findsOneWidget,
      );
    });

    testWidgets('uses deleted-account identity for a vanished contributor', (
      tester,
    ) async {
      await tester.pumpWidget(
        subject(
          activity: {'general': activeSummary()},
          vanished: true,
        ),
      );
      await tester.pump();
      expect(
        find.text(
          l10n.messagesRoomLatestMessage(
            l10n.profileDeletedAccountName,
            'Hello everyone',
          ),
        ),
        findsOneWidget,
      );
      expect(find.textContaining('River'), findsNothing);
    });

    for (final theme in [VineTheme.theme, VineTheme.lightTheme]) {
      testWidgets(
        'activity supports narrow large text in ${theme.brightness}',
        (
          tester,
        ) async {
          tester.view.physicalSize = const Size(320, 1200);
          tester.view.devicePixelRatio = 1;
          addTearDown(tester.view.reset);
          await tester.pumpWidget(
            subject(
              activity: {'general': activeSummary()},
              textScale: 2,
              theme: theme,
            ),
          );
          await tester.pump();
          expect(
            find.text(l10n.messagesRoomNewCount(12, '12')),
            findsOneWidget,
          );
          expect(tester.takeException(), isNull);
        },
      );
    }
    testWidgets('keeps same-named channels bound to their community', (
      tester,
    ) async {
      (String, String)? selected;
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RoomsView(
              communities: const [
                ChatCommunity('one', 'First', ['general']),
                ChatCommunity('two', 'Second', ['general']),
              ],
              onRoomSelected: (community, channel) =>
                  selected = (community, channel),
            ),
          ),
        ),
      );
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.messagesPublicTestDisclosure), findsOneWidget);
      expect(find.text('First'), findsOneWidget);
      expect(find.text('Second'), findsOneWidget);
      await tester.tap(find.text('general').last);
      expect(selected, ('two', 'general'));
    });

    testWidgets('rows draw cleanly on the coloured Messages surface', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            // The Messages tab hosts this list inside a coloured box.
            body: ColoredBox(
              color: VineTheme.surfaceBackground,
              child: RoomsView(
                communities: const [
                  ChatCommunity('one', 'First', ['general']),
                ],
                onRoomSelected: (_, _) {},
              ),
            ),
          ),
        ),
      );
      expect(find.text('general'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('empty list does not invent a join action or a room', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: RoomsView(
              communities: const [],
              onRoomSelected: (_, _) => fail('no room should be selectable'),
            ),
          ),
        ),
      );
      expect(
        find.text(lookupAppLocalizations(const Locale('en')).messagesNoRooms),
        findsOneWidget,
      );
      expect(find.byType(ListTile), findsNothing);
    });
  });
}
