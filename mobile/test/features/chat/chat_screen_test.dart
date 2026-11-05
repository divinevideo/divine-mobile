import 'dart:async';
import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' hide AspectRatio;
import 'package:openvine/blocs/chat/chat_cubit.dart';
import 'package:openvine/features/chat/chat_message_tile.dart';
import 'package:openvine/features/chat/chat_screen.dart';
import 'package:openvine/features/chat/concord_reports_provider.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/widgets/user_avatar.dart';

class _ChatCubit extends MockCubit<ChatState> implements ChatCubit {}

Future<void> _pumpChatWidget(WidgetTester tester, Widget widget) =>
    tester.pumpWidget(ProviderScope(child: widget));

void main() {
  group(ChatScreen, () {
    testWidgets('retired pending messages restore as drafts without retrying', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final cubit = _ChatCubit();
      final author = '33' * 32;
      final message = ChatMessage(
        id: '44' * 32,
        channelId: 'general',
        author: author,
        body: 'Earlier message',
        createdAt: 1,
      );
      final state = ChatState(
        pendingIds: [message.id],
        retiredPendingIds: [message.id],
      );
      when(() => cubit.state).thenReturn(state);
      whenListen(cubit, const Stream<ChatState>.empty(), initialState: state);
      when(cubit.visibleMessages).thenReturn([message]);
      when(() => cubit.discardPendingDraft(message.id))
          .thenAnswer((_) async {});
      await _pumpChatWidget(
        tester,
        ProviderScope(
          overrides: [
            fetchUserProfileProvider(author).overrideWith(
              (ref) async => UserProfile(
                pubkey: author,
                displayName: 'Synthetic member',
                rawData: const {},
                createdAt: DateTime(2026),
                eventId: '88' * 32,
              ),
            ),
            profileIdentityResolvingProvider(author).overrideWithValue(false),
            profileVanishedProvider(author).overrideWith((ref) => false),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<ChatCubit>.value(
              value: cubit,
              child: const ChatScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'Current draft');
      await tester.tap(find.text(l10n.messagesRoomRestoreDraft));
      await tester.pump();
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Current draft\nEarlier message',
      );
      verifyNever(() => cubit.retry(any()));
      verifyNever(
        () => cubit.send(
          communityId: any(named: 'communityId'),
          channelId: any(named: 'channelId'),
          author: any(named: 'author'),
          body: any(named: 'body'),
          nowMilliseconds: any(named: 'nowMilliseconds'),
        ),
      );
      await tester.tap(find.text(l10n.messagesRoomDiscardDraft));
      await tester.pump();
      verify(() => cubit.discardPendingDraft(message.id)).called(1);
      expect(
        tester.widget<TextField>(find.byType(TextField)).controller!.text,
        'Current draft\nEarlier message',
      );
    });
    testWidgets(
      'reports the selected real room message with signed HTTP authentication',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        final cubit = _ChatCubit();
        final community = '11' * 32;
        final channel = '22' * 32;
        final author = '33' * 32;
        final message = ChatMessage(
          id: '44' * 32,
          channelId: channel,
          author: author,
          body: 'Report this message',
          createdAt: 1,
        );
        final state = ChatState(
          isTestCommunity: false,
          communities: [
            ChatCommunity(
              community,
              'Synthetic',
              [channel],
              channelNames: {channel: 'general'},
            ),
          ],
          selectedCommunityId: community,
          selectedChannelId: channel,
        );
        when(() => cubit.state).thenReturn(state);
        whenListen(cubit, const Stream<ChatState>.empty(), initialState: state);
        when(cubit.visibleMessages).thenReturn([message]);
        Map<String, dynamic>? submitted;
        final reports = ConcordReports(
          url: Uri.parse('https://reports.example/v1/reports'),
          signer: (template) async => {
            ...template,
            'pubkey': '55' * 32,
            'id': '66' * 32,
            'sig': '77' * 64,
          },
          post: (url, body, headers) async {
            submitted = jsonDecode(body) as Map<String, dynamic>;
            expect(headers['authorization'], startsWith('Nostr '));
            return {'caseId': 'synthetic-case'};
          },
        );
        await _pumpChatWidget(
          tester,
          ProviderScope(
            overrides: [
              concordReportsProvider.overrideWithValue(reports),
              fetchUserProfileProvider(author).overrideWith(
                (ref) async => UserProfile(
                  pubkey: author,
                  displayName: 'Synthetic member',
                  rawData: const {},
                  createdAt: DateTime(2026),
                  eventId: '88' * 32,
                ),
              ),
              profileIdentityResolvingProvider(author).overrideWithValue(false),
              profileVanishedProvider(author).overrideWith((ref) => false),
            ],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: BlocProvider<ChatCubit>.value(
                value: cubit,
                child: const ChatScreen(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.text(l10n.reportSubmit));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.reportReasonSpam));
        await tester.pumpAndSettle();
        expect(submitted!['target'] as Map, {
          'communityId': community,
          'channelId': channel,
          'rumorId': message.id,
        });
        expect(submitted!['reason'], 'NS-spam');
        expect(
          find.text(l10n.reportReceivedThankYou),
          findsOneWidget,
        );
      },
    );
    testWidgets('a room report can name child safety and CSAM', (
      tester,
    ) async {
      final l10n = lookupAppLocalizations(const Locale('en'));
      final cubit = _ChatCubit();
      final community = '11' * 32;
      final channel = '22' * 32;
      final author = '33' * 32;
      final message = ChatMessage(
        id: '44' * 32,
        channelId: channel,
        author: author,
        body: 'Report this message',
        createdAt: 1,
      );
      final state = ChatState(
        isTestCommunity: false,
        communities: [
          ChatCommunity(community, 'Synthetic', [channel]),
        ],
        selectedCommunityId: community,
        selectedChannelId: channel,
      );
      when(() => cubit.state).thenReturn(state);
      whenListen(cubit, const Stream<ChatState>.empty(), initialState: state);
      when(cubit.visibleMessages).thenReturn([message]);
      Map<String, dynamic>? submitted;
      final reports = ConcordReports(
        url: Uri.parse('https://reports.example/v1/reports'),
        signer: (template) async => {
          ...template,
          'pubkey': '55' * 32,
          'id': '66' * 32,
          'sig': '77' * 64,
        },
        post: (url, body, headers) async {
          submitted = jsonDecode(body) as Map<String, dynamic>;
          return {'caseId': 'synthetic-case'};
        },
      );
      await _pumpChatWidget(
        tester,
        ProviderScope(
          overrides: [
            concordReportsProvider.overrideWithValue(reports),
            fetchUserProfileProvider(author).overrideWith(
              (ref) async => UserProfile(
                pubkey: author,
                displayName: 'Synthetic member',
                rawData: const {},
                createdAt: DateTime(2026),
                eventId: '88' * 32,
              ),
            ),
            profileIdentityResolvingProvider(author).overrideWithValue(false),
            profileVanishedProvider(author).overrideWith((ref) => false),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<ChatCubit>.value(
              value: cubit,
              child: const ChatScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(find.text(l10n.reportSubmit));
      await tester.pumpAndSettle();
      expect(find.text(l10n.reportReasonChildSafety), findsOneWidget);
      await tester.ensureVisible(find.text(l10n.reportReasonCsam));
      await tester.tap(find.text(l10n.reportReasonCsam));
      await tester.pumpAndSettle();
      expect(submitted!['reason'], 'NS-csam');
    });
    testWidgets(
      'a report submits through the provider current when the reason is '
      'chosen',
      (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        final cubit = _ChatCubit();
        final community = '11' * 32;
        final channel = '22' * 32;
        final author = '33' * 32;
        final message = ChatMessage(
          id: '44' * 32,
          channelId: channel,
          author: author,
          body: 'Report this message',
          createdAt: 1,
        );
        final state = ChatState(
          isTestCommunity: false,
          communities: [
            ChatCommunity(community, 'Synthetic', [channel]),
          ],
          selectedCommunityId: community,
          selectedChannelId: channel,
        );
        when(() => cubit.state).thenReturn(state);
        whenListen(cubit, const Stream<ChatState>.empty(), initialState: state);
        when(cubit.visibleMessages).thenReturn([message]);
        final submittedBy = <String>[];
        ConcordReports reportsNamed(String name) => ConcordReports(
          url: Uri.parse('https://reports.example/v1/reports'),
          signer: (template) async => {
            ...template,
            'pubkey': '55' * 32,
            'id': '66' * 32,
            'sig': '77' * 64,
          },
          post: (url, body, headers) async {
            submittedBy.add(name);
            return {'caseId': 'synthetic-case'};
          },
        );
        var current = reportsNamed('first');
        await _pumpChatWidget(
          tester,
          ProviderScope(
            overrides: [
              concordReportsProvider.overrideWith((ref) => current),
              fetchUserProfileProvider(author).overrideWith(
                (ref) async => UserProfile(
                  pubkey: author,
                  displayName: 'Synthetic member',
                  rawData: const {},
                  createdAt: DateTime(2026),
                  eventId: '88' * 32,
                ),
              ),
              profileIdentityResolvingProvider(author).overrideWithValue(false),
              profileVanishedProvider(author).overrideWith((ref) => false),
            ],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: BlocProvider<ChatCubit>.value(
                value: cubit,
                child: const ChatScreen(),
              ),
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.text(l10n.reportSubmit));
        await tester.pumpAndSettle();
        // The catalog changes while the reason sheet is open, which rebuilds
        // the provider and ends the instance read before it.
        current = reportsNamed('second');
        ProviderScope.containerOf(
          tester.element(find.byType(ChatScreen)),
        ).invalidate(concordReportsProvider);
        await tester.tap(find.text(l10n.reportReasonSpam));
        await tester.pumpAndSettle();
        expect(submittedBy, ['second']);
        expect(find.text(l10n.reportReceivedThankYou), findsOneWidget);
      },
    );
    testWidgets('a failed draft discard is logged, not thrown', (
      tester,
    ) async {
      final cubit = _ChatCubit();
      final author = '33' * 32;
      final message = ChatMessage(
        id: '44' * 32,
        channelId: 'general',
        author: author,
        body: 'Earlier message',
        createdAt: 1,
      );
      final state = ChatState(
        pendingIds: [message.id],
        retiredPendingIds: [message.id],
      );
      when(() => cubit.state).thenReturn(state);
      whenListen(cubit, const Stream<ChatState>.empty(), initialState: state);
      when(cubit.visibleMessages).thenReturn([message]);
      when(
        () => cubit.discardPendingDraft(message.id),
      ).thenAnswer((_) async => throw StateError('store unavailable'));
      await _pumpChatWidget(
        tester,
        ProviderScope(
          overrides: [
            fetchUserProfileProvider(author).overrideWith(
              (ref) async => UserProfile(
                pubkey: author,
                displayName: 'Synthetic member',
                rawData: const {},
                createdAt: DateTime(2026),
                eventId: '88' * 32,
              ),
            ),
            profileIdentityResolvingProvider(author).overrideWithValue(false),
            profileVanishedProvider(author).overrideWith((ref) => false),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<ChatCubit>.value(
              value: cubit,
              child: const ChatScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.tap(
        find.text(
          lookupAppLocalizations(const Locale('en')).messagesRoomDiscardDraft,
        ),
      );
      await tester.pump();
      verify(() => cubit.discardPendingDraft(message.id)).called(1);
      expect(tester.takeException(), isNull);
    });
    testWidgets('offers Report only on other members’ messages', (
      tester,
    ) async {
      final cubit = _ChatCubit();
      final self = '55' * 32;
      final other = '33' * 32;
      final own = ChatMessage(
        id: '44' * 32,
        channelId: '22' * 32,
        author: self,
        body: 'My message',
        createdAt: 1,
      );
      final theirs = ChatMessage(
        id: '66' * 32,
        channelId: '22' * 32,
        author: other,
        body: 'Their message',
        createdAt: 2,
      );
      final state = ChatState(
        account: self,
        isTestCommunity: false,
        pendingIds: [own.id],
      );
      when(() => cubit.state).thenReturn(state);
      whenListen(cubit, const Stream<ChatState>.empty(), initialState: state);
      when(cubit.visibleMessages).thenReturn([own, theirs]);
      final reports = ConcordReports(
        url: Uri.parse('https://reports.example/v1/reports'),
        signer: (template) async => template,
        post: (url, body, headers) async => {'caseId': 'synthetic-case'},
      );
      await _pumpChatWidget(
        tester,
        ProviderScope(
          overrides: [
            concordReportsProvider.overrideWithValue(reports),
            for (final author in [self, other]) ...[
              fetchUserProfileProvider(author).overrideWith(
                (ref) async => UserProfile(
                  pubkey: author,
                  displayName: 'Synthetic member',
                  rawData: const {},
                  createdAt: DateTime(2026),
                  eventId: '88' * 32,
                ),
              ),
              profileIdentityResolvingProvider(
                author,
              ).overrideWithValue(false),
              profileVanishedProvider(author).overrideWith((ref) => false),
            ],
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<ChatCubit>.value(
              value: cubit,
              child: const ChatScreen(),
            ),
          ),
        ),
      );
      await tester.pump();
      ChatMessageTile tileOf(ChatMessage message) =>
          tester.widget<ChatMessageTile>(
            find.ancestor(
              of: find.text(message.body),
              matching: find.byType(ChatMessageTile),
            ),
          );
      expect(
        find.text(lookupAppLocalizations(const Locale('en')).reportSubmit),
        findsOneWidget,
      );
      expect(tileOf(theirs).onReport, isNotNull);
      expect(tileOf(own).onReport, isNull);
    });
    testWidgets('keeps focus and a new draft while a send finishes', (
      tester,
    ) async {
      final cubit = _ChatCubit();
      final states = StreamController<ChatState>();
      addTearDown(states.close);
      whenListen(cubit, states.stream, initialState: const ChatState());
      when(cubit.visibleMessages).thenReturn([]);
      final sent = Completer<bool>();
      when(
        () => cubit.send(
          communityId: any(named: 'communityId'),
          channelId: any(named: 'channelId'),
          author: any(named: 'author'),
          body: any(named: 'body'),
          nowMilliseconds: any(named: 'nowMilliseconds'),
        ),
      ).thenAnswer((_) => sent.future);
      await _pumpChatWidget(
        tester,
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<ChatCubit>.value(
            value: cubit,
            child: const ChatScreen(),
          ),
        ),
      );
      await tester.enterText(find.byType(TextField), 'first message');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      verify(
        () => cubit.send(
          communityId: any(named: 'communityId'),
          channelId: any(named: 'channelId'),
          author: any(named: 'author'),
          body: 'first message',
          nowMilliseconds: any(named: 'nowMilliseconds'),
        ),
      ).called(1);
      states.add(const ChatState(sending: true));
      await tester.pump();
      expect(tester.widget<TextField>(find.byType(TextField)).enabled, isTrue);
      expect(tester.testTextInput.isVisible, isTrue);
      await tester.enterText(find.byType(TextField), 'next draft');
      sent.complete(true);
      states.add(const ChatState());
      await tester.pump();
      expect(find.text('next draft'), findsOneWidget);
      expect(tester.testTextInput.isVisible, isTrue);
    });
    testWidgets('a send that finishes after leaving the room is not restored', (
      tester,
    ) async {
      final cubit = _ChatCubit();
      whenListen(
        cubit,
        const Stream<ChatState>.empty(),
        initialState: const ChatState(),
      );
      when(cubit.visibleMessages).thenReturn([]);
      final sent = Completer<bool>();
      final next = Completer<bool>();
      final sends = [sent, next];
      when(
        () => cubit.send(
          communityId: any(named: 'communityId'),
          channelId: any(named: 'channelId'),
          author: any(named: 'author'),
          body: any(named: 'body'),
          nowMilliseconds: any(named: 'nowMilliseconds'),
        ),
      ).thenAnswer((_) => sends.removeAt(0).future);
      final container = ProviderContainer();
      addTearDown(container.dispose);
      Future<void> pumpRoom({required bool open}) => tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: open
                ? BlocProvider<ChatCubit>.value(
                    value: cubit,
                    child: const ChatScreen(),
                  )
                : const SizedBox(),
          ),
        ),
      );
      await pumpRoom(open: true);
      await tester.enterText(find.byType(TextField), 'first message');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await pumpRoom(open: false);
      sent.complete(true);
      await tester.pump();
      await pumpRoom(open: true);
      expect(find.text('first message'), findsNothing);

      // A draft typed while the send was in flight is still the person's.
      await tester.enterText(find.byType(TextField), 'second message');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      await tester.enterText(find.byType(TextField), 'third message');
      await tester.pump();
      await pumpRoom(open: false);
      next.complete(true);
      await tester.pump();
      await pumpRoom(open: true);
      expect(find.text('third message'), findsOneWidget);
    });
    for (final width in [390.0, 1400.0]) {
      for (final theme in [VineTheme.theme, VineTheme.lightTheme]) {
        testWidgets(
          'sender identity and readable layout at $width in ${theme.brightness}',
          (
            tester,
          ) async {
            const author =
                '3333333333333333333333333333333333333333333333333333333333333333';
            final cubit = _ChatCubit();
            when(() => cubit.state).thenReturn(const ChatState());
            when(cubit.visibleMessages).thenReturn([
              ChatMessage(
                id: '5555555555555555555555555555555555555555555555555555555555555555',
                channelId: 'general',
                author: author,
                body: 'Hello room',
                createdAt: 1,
              ),
            ]);
            whenListen(cubit, const Stream<ChatState>.empty());
            tester.view.physicalSize = Size(width, 900);
            tester.view.devicePixelRatio = 1;
            addTearDown(tester.view.reset);
            await _pumpChatWidget(
              tester,
              ProviderScope(
                overrides: [
                  fetchUserProfileProvider(author).overrideWith(
                    (ref) async => UserProfile(
                      pubkey: author,
                      displayName: 'Room member',
                      rawData: const {},
                      createdAt: DateTime(2026),
                      eventId: '6' * 64,
                    ),
                  ),
                  profileIdentityResolvingProvider(author)
                      .overrideWithValue(false),
                  profileVanishedProvider(author).overrideWith((ref) => false),
                ],
                child: MaterialApp(
                  theme: theme,
                  builder: (context, child) => MediaQuery(
                    data: MediaQuery.of(context)
                        .copyWith(textScaler: const TextScaler.linear(2)),
                    child: child!,
                  ),
                  localizationsDelegates: appLocalizationsDelegates,
                  supportedLocales: AppLocalizations.supportedLocales,
                  home: BlocProvider<ChatCubit>.value(
                    value: cubit,
                    child: const ChatScreen(),
                  ),
                ),
              ),
            );
            await tester.pump();
            expect(find.text('Room member'), findsOneWidget);
            expect(find.text('Hello room'), findsOneWidget);
            expect(find.byType(SelectableText), findsOneWidget);
            expect(find.text(author), findsNothing);
            expect(find.byType(UserAvatar), findsOneWidget);
            expect(
              tester.getSize(find.byType(TextField)).width,
              lessThanOrEqualTo(720),
            );
            expect(tester.takeException(), isNull);
          },
        );
      }
    }
    testWidgets('shows the selected room and no local-only join wizard', (
      tester,
    ) async {
      final cubit = _ChatCubit();
      when(
        () => cubit.state,
      ).thenReturn(const ChatState(selectedChannelId: 'introductions'));
      when(cubit.visibleMessages).thenReturn([]);
      whenListen(cubit, const Stream<ChatState>.empty());
      await _pumpChatWidget(
        tester,
        MaterialApp(
          localizationsDelegates: appLocalizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: BlocProvider<ChatCubit>.value(
            value: cubit,
            child: const ChatScreen(),
          ),
        ),
      );
      expect(find.text('#introductions'), findsNWidgets(2));
      expect(find.byType(Drawer), findsNothing);
      expect(
        find.text(
          lookupAppLocalizations(
            const Locale('en'),
          ).messagesPublicTestDisclosure,
        ),
        findsOneWidget,
      );
    });
    for (final key in [
      null,
      LogicalKeyboardKey.enter,
      LogicalKeyboardKey.numpadEnter,
    ]) {
      for (final accepted in [false, true]) {
        testWidgets(
          'composer clears only when durably accepted: $accepted via $key',
          (
            tester,
          ) async {
            final cubit = _ChatCubit();
            when(() => cubit.state).thenReturn(const ChatState());
            when(cubit.visibleMessages).thenReturn([]);
            whenListen(cubit, const Stream<ChatState>.empty());
            when(
              () => cubit.send(
                communityId: any(named: 'communityId'),
                channelId: any(named: 'channelId'),
                author: any(named: 'author'),
                body: any(named: 'body'),
                nowMilliseconds: any(named: 'nowMilliseconds'),
              ),
            ).thenAnswer((_) async => accepted);
            await _pumpChatWidget(
              tester,
              MaterialApp(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: BlocProvider<ChatCubit>.value(
                  value: cubit,
                  child: const ChatScreen(),
                ),
              ),
            );
            await tester.enterText(find.byType(TextField), 'keep this draft');
            await tester.pump();
            if (key == null) {
              await tester.tap(
                find.bySemanticsLabel(
                  lookupAppLocalizations(const Locale('en')).dmMessageSendLabel,
                ),
              );
            } else {
              await tester.sendKeyEvent(key);
            }
            await tester.pump();
            verify(
              () => cubit.send(
                communityId: any(named: 'communityId'),
                channelId: any(named: 'channelId'),
                author: any(named: 'author'),
                body: 'keep this draft',
                nowMilliseconds: any(named: 'nowMilliseconds'),
              ),
            ).called(1);
            expect(
              tester.widget<TextField>(find.byType(TextField)).controller!.text,
              accepted ? '' : 'keep this draft',
            );
          },
        );
      }
    }
    group('hardware keyboard composition', () {
      late _ChatCubit cubit;

      setUp(() {
        cubit = _ChatCubit();
        when(() => cubit.state).thenReturn(const ChatState());
        when(cubit.visibleMessages).thenReturn([]);
        whenListen(cubit, const Stream<ChatState>.empty());
        when(
          () => cubit.send(
            communityId: any(named: 'communityId'),
            channelId: any(named: 'channelId'),
            author: any(named: 'author'),
            body: any(named: 'body'),
            nowMilliseconds: any(named: 'nowMilliseconds'),
          ),
        ).thenAnswer((_) async => false);
      });

      Future<TextEditingController> pumpComposer(WidgetTester tester) async {
        await _pumpChatWidget(
          tester,
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<ChatCubit>.value(
              value: cubit,
              child: const ChatScreen(),
            ),
          ),
        );
        await tester.enterText(find.byType(TextField), 'draft');
        return tester.widget<TextField>(find.byType(TextField)).controller!;
      }

      void expectNoSend() => verifyNever(
        () => cubit.send(
          communityId: any(named: 'communityId'),
          channelId: any(named: 'channelId'),
          author: any(named: 'author'),
          body: any(named: 'body'),
          nowMilliseconds: any(named: 'nowMilliseconds'),
        ),
      );

      testWidgets(
        'Shift+Enter leaves newline entry to the platform without sending',
        (
          tester,
        ) async {
          final controller = await pumpComposer(tester);
          await tester.sendKeyDownEvent(LogicalKeyboardKey.shiftLeft);
          final handled = await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.sendKeyUpEvent(LogicalKeyboardKey.shiftLeft);
          expect(handled, isFalse);
          // Text insertion comes from the platform text-input connection.
          tester.testTextInput.updateEditingValue(
            const TextEditingValue(
              text: 'draft\n',
              selection: TextSelection.collapsed(offset: 6),
            ),
          );
          await tester.pump();
          expect(controller.text, 'draft\n');
          expectNoSend();
        },
      );

      for (final modifier in [
        LogicalKeyboardKey.controlLeft,
        LogicalKeyboardKey.altLeft,
        LogicalKeyboardKey.metaLeft,
      ]) {
        testWidgets('${modifier.keyLabel} with Enter does not send', (
          tester,
        ) async {
          await pumpComposer(tester);
          await tester.sendKeyDownEvent(modifier);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.sendKeyUpEvent(modifier);
          await tester.pump();
          expectNoSend();
        });
      }

      testWidgets('Enter does not send while an IME is composing', (
        tester,
      ) async {
        final controller = await pumpComposer(tester);
        controller.value = const TextEditingValue(
          text: 'draft',
          selection: TextSelection.collapsed(offset: 5),
          composing: TextRange(start: 0, end: 5),
        );
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expectNoSend();
      });

      testWidgets('holding Enter sends only once', (tester) async {
        await pumpComposer(tester);
        await tester.sendKeyDownEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyRepeatEvent(LogicalKeyboardKey.enter);
        await tester.sendKeyUpEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        verify(
          () => cubit.send(
            communityId: any(named: 'communityId'),
            channelId: any(named: 'channelId'),
            author: any(named: 'author'),
            body: 'draft',
            nowMilliseconds: any(named: 'nowMilliseconds'),
          ),
        ).called(1);
      });

      testWidgets('Enter does not send a whitespace-only draft', (
        tester,
      ) async {
        final controller = await pumpComposer(tester);
        controller.text = '  ';
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        expectNoSend();
      });

      for (final state in [
        const ChatState(sending: true),
        const ChatState(loading: true),
        const ChatState(loadFailed: true),
      ]) {
        testWidgets('Enter respects the composer access gate: $state', (
          tester,
        ) async {
          await pumpComposer(tester);
          // The state can change before BlocBuilder rebuilds the field.
          when(() => cubit.state).thenReturn(state);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pump();
          expectNoSend();
        });
      }
    });
    testWidgets(
      'failed initial loading disables the composer and offers retry',
      (tester) async {
        final cubit = _ChatCubit();
        when(() => cubit.state).thenReturn(const ChatState(loadFailed: true));
        when(cubit.visibleMessages).thenReturn([]);
        whenListen(cubit, const Stream<ChatState>.empty());
        when(cubit.start).thenAnswer((_) async {});
        await _pumpChatWidget(
          tester,
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<ChatCubit>.value(
              value: cubit,
              child: const ChatScreen(),
            ),
          ),
        );
        expect(
          tester.widget<TextField>(find.byType(TextField)).enabled,
          isFalse,
        );
        await tester.tap(
          find.text(lookupAppLocalizations(const Locale('en')).commonRetry),
        );
        verify(cubit.start).called(1);
      },
    );

    group('undelivered message', () {
      const author =
          '3333333333333333333333333333333333333333333333333333333333333333';
      const messageId =
          '5555555555555555555555555555555555555555555555555555555555555555';
      late _ChatCubit cubit;

      setUp(() {
        cubit = _ChatCubit();
        when(cubit.visibleMessages).thenReturn([
          ChatMessage(
            id: messageId,
            channelId: 'general',
            author: author,
            body: 'Hello room',
            createdAt: 1,
          ),
        ]);
        whenListen(cubit, const Stream<ChatState>.empty());
      });

      Future<AppLocalizations> pumpRoom(
        WidgetTester tester,
        ChatState state,
      ) async {
        when(() => cubit.state).thenReturn(state);
        await _pumpChatWidget(
          tester,
          ProviderScope(
            overrides: [
              fetchUserProfileProvider(author)
                  .overrideWith((ref) async => null),
              profileIdentityResolvingProvider(author).overrideWithValue(false),
              profileVanishedProvider(author).overrideWith((ref) => false),
            ],
            child: MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: BlocProvider<ChatCubit>.value(
                value: cubit,
                child: const ChatScreen(),
              ),
            ),
          ),
        );
        await tester.pump();
        return lookupAppLocalizations(const Locale('en'));
      }

      testWidgets('is marked as failed and can be retried', (tester) async {
        when(() => cubit.retry(messageId)).thenAnswer((_) async {});
        final l10n = await pumpRoom(
          tester,
          const ChatState(pendingIds: [messageId]),
        );
        expect(find.text(l10n.dmStatusFailed), findsOneWidget);

        await tester.tap(find.text(l10n.dmSendFailedRetry));

        verify(() => cubit.retry(messageId)).called(1);
      });

      testWidgets('is not marked once it is delivered', (tester) async {
        final l10n = await pumpRoom(tester, const ChatState());
        expect(find.text('Hello room'), findsOneWidget);
        expect(find.text(l10n.dmStatusFailed), findsNothing);
        expect(find.text(l10n.dmSendFailedRetry), findsNothing);
      });

      testWidgets('is announced above the conversation', (tester) async {
        final l10n = await pumpRoom(
          tester,
          const ChatState(sendFailed: true, pendingIds: [messageId]),
        );
        expect(find.text(l10n.dmSendFailedMessage), findsOneWidget);
      });
    });

    group('composer', () {
      late _ChatCubit cubit;

      setUp(() {
        cubit = _ChatCubit();
        when(() => cubit.state).thenReturn(const ChatState());
        when(cubit.visibleMessages).thenReturn([]);
        whenListen(cubit, const Stream<ChatState>.empty());
      });

      testWidgets('stays clear of the home indicator and the screen edge', (
        tester,
      ) async {
        const homeIndicator = EdgeInsets.only(bottom: 34);
        await _pumpChatWidget(
          tester,
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery(
              data: MediaQuery.of(context).copyWith(
                padding: homeIndicator,
                viewPadding: homeIndicator,
              ),
              child: child!,
            ),
            home: BlocProvider<ChatCubit>.value(
              value: cubit,
              child: const ChatScreen(),
            ),
          ),
        );
        final field = tester.getRect(find.byType(TextField));
        final screen = tester.getRect(find.byType(Scaffold));
        expect(field.bottom, lessThanOrEqualTo(screen.bottom - 34));
        expect(field.left, greaterThanOrEqualTo(16));
      });

      testWidgets('the message field is set up for multi-line messages', (
        tester,
      ) async {
        await _pumpChatWidget(
          tester,
          MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<ChatCubit>.value(
              value: cubit,
              child: const ChatScreen(),
            ),
          ),
        );
        final field = tester.widget<TextField>(find.byType(TextField));
        expect(field.keyboardType, TextInputType.multiline);
        expect(field.textInputAction, TextInputAction.newline);
        expect(field.textCapitalization, TextCapitalization.sentences);
      });
    });
  });
}
