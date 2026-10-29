import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/chat/chat_cubit.dart';
import 'package:openvine/features/chat/chat_screen.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/repository_providers.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/mentions/mention_overlay.dart';
import 'package:profile_repository/profile_repository.dart';

class _Chat extends MockCubit<ChatState> implements ChatCubit {}

class _Profiles extends Mock implements ProfileRepository {}

class _Follows extends Mock implements FollowRepository {}

final String _alice = 'a' * 64;
final String _other = 'b' * 64;
final String _self = 'f' * 64;

/// Pumps a composer whose followed accounts all share the display name Alice.
Future<_Chat> _pumpComposer(
  WidgetTester tester, {
  bool profilesReady = true,
}) async {
  tester.view.physicalSize = const Size(390, 667);
  tester.view.devicePixelRatio = 1;
  tester.view.viewInsets = const FakeViewPadding(bottom: 300);
  addTearDown(tester.view.reset);
  final keys = [_alice, _other, 'c' * 64, 'd' * 64, 'e' * 64];
  final profiles = _Profiles();
  final follows = _Follows();
  final chat = _Chat();
  when(() => chat.state).thenReturn(const ChatState());
  when(chat.visibleMessages).thenReturn([]);
  whenListen(chat, const Stream<ChatState>.empty());
  when(() => follows.followingPubkeys).thenReturn(keys);
  when(
    () => profiles.getCachedProfiles(pubkeys: any(named: 'pubkeys')),
  ).thenAnswer(
    (_) async => [
      for (final key in keys)
        UserProfile(
          pubkey: key,
          displayName: 'Alice',
          rawData: const {},
          createdAt: DateTime.utc(2026),
          eventId: 'c' * 64,
        ),
    ],
  );
  when(
    () => profiles.searchUsersFromApi(
      query: any(named: 'query'),
      limit: any(named: 'limit'),
      sortBy: any(named: 'sortBy'),
    ),
  ).thenAnswer((_) async => []);
  when(
    () => chat.send(
      communityId: any(named: 'communityId'),
      channelId: any(named: 'channelId'),
      author: any(named: 'author'),
      body: any(named: 'body'),
      nowMilliseconds: any(named: 'nowMilliseconds'),
    ),
  ).thenAnswer((_) async => true);
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        profileRepositoryProvider.overrideWithValue(
          profilesReady ? profiles : null,
        ),
        followRepositoryProvider.overrideWithValue(follows),
      ],
      child: MaterialApp(
        localizationsDelegates: appLocalizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: BlocProvider<ChatCubit>.value(
          value: chat,
          child: const ChatScreen(),
        ),
      ),
    ),
  );
  return chat;
}

/// The profiles the pumped composer resolves typed mentions against.
_Profiles _profilesOf(WidgetTester tester) =>
    ProviderScope.containerOf(
          tester.element(find.byType(ChatScreen)),
        ).read(profileRepositoryProvider)!
        as _Profiles;

/// Types [draft] and picks [pubkey] for the `@Al` token at its end.
Future<void> _pick(WidgetTester tester, String draft, String pubkey) async {
  await tester.enterText(find.byType(TextField), draft);
  await tester.pumpAndSettle();
  tester
      .widget<MentionOverlay>(find.byType(MentionOverlay))
      .onSelect(pubkey, 'Alice');
  await tester.pump();
}

void _verifySent(_Chat chat, String body) => verify(
  () => chat.send(
    communityId: 'community-test',
    channelId: 'general',
    author: '',
    body: body,
    nowMilliseconds: any(named: 'nowMilliseconds'),
  ),
).called(1);

void main() {
  final aliceRef = 'nostr:${NostrKeyUtils.encodePubKey(_alice)}';
  final otherRef = 'nostr:${NostrKeyUtils.encodePubKey(_other)}';

  group(ChatScreen, () {
    group('interactions', () {
      for (final removeSecond in [false, true]) {
        testWidgets(
          'small screen with keyboard preserves identities; remove second: $removeSecond',
          (tester) async {
            final chat = await _pumpComposer(tester);
            await tester.enterText(find.byType(TextField), '@Al');
            await tester.pumpAndSettle();
            expect(tester.takeException(), isNull);
            expect(
              tester.getBottomLeft(find.byType(MentionOverlay)).dy,
              lessThanOrEqualTo(tester.getTopLeft(find.byType(TextField)).dy),
            );
            await _pick(tester, '@Al', _alice);
            await _pick(tester, '@Alice @Al', _other);
            if (removeSecond) {
              await tester.enterText(find.byType(TextField), '@Alice ');
              await tester.pump();
            }
            await tester.sendKeyEvent(LogicalKeyboardKey.enter);
            await tester.pumpAndSettle();
            _verifySent(chat, removeSecond ? aliceRef : '$aliceRef $otherRef');
          },
        );
      }

      testWidgets('an unpicked display name stays plain text', (tester) async {
        final chat = await _pumpComposer(tester);
        when(
          () => _profilesOf(tester).searchCachedProfilesByIdentity(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => [
            UserProfile(
              pubkey: _alice,
              displayName: 'Alice',
              rawData: const {},
              createdAt: DateTime.utc(2026),
              eventId: 'c' * 64,
            ),
          ],
        );
        await tester.enterText(find.byType(TextField), 'hi @Alice');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        _verifySent(chat, 'hi @Alice');
      });

      testWidgets('pasting over a selected pick leaves pasted names plain', (
        tester,
      ) async {
        final chat = await _pumpComposer(tester);
        await _pick(tester, '@Al', _alice);
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '@Alice ',
            selection: TextSelection(baseOffset: 0, extentOffset: 7),
          ),
        );
        await tester.pump();
        tester.testTextInput.updateEditingValue(
          const TextEditingValue(
            text: '@Alice @Alice ',
            selection: TextSelection.collapsed(offset: 14),
          ),
        );
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        _verifySent(chat, '@Alice @Alice');
      });

      testWidgets(
        'picked accounts work before the profile repository is ready',
        (tester) async {
          final chat = await _pumpComposer(tester, profilesReady: false);
          await _pick(tester, '@Al', _alice);
          await tester.sendKeyEvent(LogicalKeyboardKey.enter);
          await tester.pumpAndSettle();
          _verifySent(chat, aliceRef);
        },
      );

      testWidgets("typing the sender's own name does not tag the sender", (
        tester,
      ) async {
        final chat = await _pumpComposer(tester);
        when(
          () => _profilesOf(tester).searchCachedProfilesByIdentity(
            query: any(named: 'query'),
            limit: any(named: 'limit'),
          ),
        ).thenAnswer(
          (_) async => [
            UserProfile(
              pubkey: _self,
              displayName: 'Me',
              rawData: const {},
              createdAt: DateTime.utc(2026),
              eventId: 'c' * 64,
            ),
          ],
        );
        await tester.enterText(find.byType(TextField), 'hi @Me');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        _verifySent(chat, 'hi @Me');
      });

      testWidgets('a send the composer reports failed shows the failure line', (
        tester,
      ) async {
        final chat = await _pumpComposer(tester);
        when(
          () => chat.send(
            communityId: any(named: 'communityId'),
            channelId: any(named: 'channelId'),
            author: any(named: 'author'),
            body: any(named: 'body'),
            nowMilliseconds: any(named: 'nowMilliseconds'),
          ),
        ).thenAnswer((_) async => false);
        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.enterText(find.byType(TextField), 'hi');
        await tester.pump();
        expect(find.text(l10n.dmSendFailedMessage), findsNothing);
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pumpAndSettle();
        expect(find.text(l10n.dmSendFailedMessage), findsOneWidget);
      });

      testWidgets('a second Enter while sending sends once', (tester) async {
        final chat = await _pumpComposer(tester);
        final held = Completer<bool>();
        when(
          () => chat.send(
            communityId: any(named: 'communityId'),
            channelId: any(named: 'channelId'),
            author: any(named: 'author'),
            body: any(named: 'body'),
            nowMilliseconds: any(named: 'nowMilliseconds'),
          ),
        ).thenAnswer((_) => held.future);
        await tester.enterText(find.byType(TextField), 'hi @Bob');
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        await tester.sendKeyEvent(LogicalKeyboardKey.enter);
        await tester.pump();
        held.complete(true);
        await tester.pumpAndSettle();
        _verifySent(chat, 'hi @Bob');
      });

      testWidgets(
        'send button keeps each identity on its own token after a leading space',
        (tester) async {
          final chat = await _pumpComposer(tester);
          await _pick(tester, ' @Al', _alice);
          await _pick(tester, ' @Alice @Al', _other);
          await tester.tap(
            find.ancestor(
              of: find.byWidgetPredicate(
                (widget) =>
                    widget is DivineIcon &&
                    widget.icon == DivineIconName.arrowUp,
              ),
              matching: find.byType(IconButton),
            ),
          );
          await tester.pumpAndSettle();
          _verifySent(chat, '$aliceRef $otherRef');
        },
      );
    });
  });
}
