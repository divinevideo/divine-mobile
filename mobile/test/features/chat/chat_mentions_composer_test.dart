import 'package:bloc_test/bloc_test.dart';
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

void main() {
  for (final removeSecond in [false, true]) {
    testWidgets('same display identities; remove second: $removeSecond', (
      tester,
    ) async {
      final alice = 'a' * 64;
      final other = 'b' * 64;
      final profiles = _Profiles();
      final follows = _Follows();
      final chat = _Chat();
      when(() => chat.state).thenReturn(const ChatState());
      when(chat.visibleMessages).thenReturn([]);
      whenListen(chat, const Stream<ChatState>.empty());
      when(() => follows.followingPubkeys).thenReturn([alice, other]);
      when(() => profiles.getCachedProfiles(pubkeys: any(named: 'pubkeys')))
          .thenAnswer(
            (_) async => [
              for (final key in [alice, other])
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
            profileRepositoryProvider.overrideWithValue(profiles),
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
      await tester.enterText(find.byType(TextField), '@Al');
      await tester.pumpAndSettle();
      tester
          .widget<MentionOverlay>(find.byType(MentionOverlay))
          .onSelect(alice, 'Alice');
      await tester.pump();
      await tester.enterText(find.byType(TextField), '@Alice @Al');
      await tester.pumpAndSettle();
      tester
          .widget<MentionOverlay>(find.byType(MentionOverlay))
          .onSelect(other, 'Alice');
      await tester.pump();
      if (removeSecond) {
        await tester.enterText(find.byType(TextField), '@Alice ');
        await tester.pump();
      }
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      verify(
        () => chat.send(
          communityId: 'community-test',
          channelId: 'general',
          author: '',
          body: removeSecond
              ? 'nostr:${NostrKeyUtils.encodePubKey(alice)}'
              : 'nostr:${NostrKeyUtils.encodePubKey(alice)} nostr:${NostrKeyUtils.encodePubKey(other)}',
          nowMilliseconds: any(named: 'nowMilliseconds'),
        ),
      ).called(1);
    });
  }
}
