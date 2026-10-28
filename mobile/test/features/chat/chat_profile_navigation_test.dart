// ABOUTME: Room sender links use the existing Divine profile route.
// ABOUTME: Returning from a profile preserves the room and its draft.

import 'package:bloc_test/bloc_test.dart';
import 'package:concord_protocol/concord_protocol.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' hide AspectRatio;
import 'package:openvine/blocs/chat/chat_cubit.dart';
import 'package:openvine/features/chat/chat_screen.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/other_profile_screen.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/user_avatar.dart';

class _ChatCubit extends MockCubit<ChatState> implements ChatCubit {}

void main() {
  group('sender profile navigation', () {
    for (final tapAvatar in [false, true]) {
      testWidgets(
        'opens sender profile and returns to draft: avatar=$tapAvatar',
        (
          tester,
        ) async {
          const author =
              '3333333333333333333333333333333333333333333333333333333333333333';
          final cubit = _ChatCubit();
          when(() => cubit.state).thenReturn(const ChatState());
          whenListen(cubit, const Stream<ChatState>.empty());
          when(cubit.visibleMessages).thenReturn([
            ChatMessage(
              id: '5555555555555555555555555555555555555555555555555555555555555555',
              channelId: 'general',
              author: author,
              body: 'Hello room',
              createdAt: 1,
            ),
          ]);
          final router = GoRouter(
            routes: [
              GoRoute(
                path: '/',
                builder: (_, _) => BlocProvider<ChatCubit>.value(
                  value: cubit,
                  child: const ChatScreen(),
                ),
              ),
              GoRoute(
                path: OtherProfileScreen.pathWithNpub,
                builder: (_, state) => Scaffold(
                  appBar: AppBar(),
                  body: Text(state.pathParameters['npub']!),
                ),
              ),
            ],
          );
          addTearDown(router.dispose);
          await tester.pumpWidget(
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
              child: MaterialApp.router(
                routerConfig: router,
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
              ),
            ),
          );
          await tester.pumpAndSettle();
          await tester.enterText(find.byType(TextField), 'unfinished reply');
          await tester.tap(
            tapAvatar ? find.byType(UserAvatar) : find.text('Room member'),
          );
          await tester.pumpAndSettle();
          expect(find.text(NostrKeyUtils.encodePubKey(author)), findsOneWidget);
          await tester.tap(find.byType(BackButton));
          await tester.pumpAndSettle();
          expect(find.text('Hello room'), findsOneWidget);
          expect(
            tester.widget<TextField>(find.byType(TextField)).controller!.text,
            'unfinished reply',
          );
        },
      );
    }

    testWidgets('a mention in a message opens the mentioned profile', (
      tester,
    ) async {
      const author =
          '3333333333333333333333333333333333333333333333333333333333333333';
      const mentioned =
          '7777777777777777777777777777777777777777777777777777777777777777';
      final cubit = _ChatCubit();
      when(() => cubit.state).thenReturn(const ChatState());
      whenListen(cubit, const Stream<ChatState>.empty());
      when(cubit.visibleMessages).thenReturn([
        ChatMessage(
          id: '5555555555555555555555555555555555555555555555555555555555555555',
          channelId: 'general',
          author: author,
          body: 'hi nostr:${NostrKeyUtils.encodePubKey(mentioned)}',
          createdAt: 1,
          mentionedPubkeys: const [mentioned],
        ),
      ]);
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => BlocProvider<ChatCubit>.value(
              value: cubit,
              child: const ChatScreen(),
            ),
          ),
          GoRoute(
            path: OtherProfileScreen.pathWithNpub,
            builder: (_, state) =>
                Scaffold(body: Text(state.pathParameters['npub']!)),
          ),
        ],
      );
      addTearDown(router.dispose);
      UserProfile profile(String pubkey, String name) => UserProfile(
        pubkey: pubkey,
        displayName: name,
        rawData: const {},
        createdAt: DateTime(2026),
        eventId: '6' * 64,
      );
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            for (final (pubkey, name) in [
              (author, 'Room member'),
              (mentioned, 'Mentioned friend'),
            ]) ...[
              fetchUserProfileProvider(
                pubkey,
              ).overrideWith((ref) async => profile(pubkey, name)),
              profileIdentityResolvingProvider(pubkey).overrideWithValue(false),
              profileVanishedProvider(pubkey).overrideWith((ref) => false),
            ],
          ],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final message = tester.widget<SelectableText>(
        find.byWidgetPredicate(
          (widget) => widget is SelectableText && widget.textSpan != null,
        ),
      );
      final link = message.textSpan!.children!
          .whereType<TextSpan>()
          .singleWhere(
            (span) => span.recognizer != null,
          );
      // SelectableText paints through RenderEditable, which text-range
      // finders cannot see, so fire the mention span's own recognizer.
      (link.recognizer! as TapGestureRecognizer).onTap!();
      await tester.pumpAndSettle();
      expect(
        find.text(NostrKeyUtils.encodePubKey(mentioned)),
        findsOneWidget,
      );
    });
  });
}
