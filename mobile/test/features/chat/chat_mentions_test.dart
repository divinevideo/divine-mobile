import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' hide AspectRatio;
import 'package:openvine/blocs/chat/chat_cubit.dart';
import 'package:openvine/blocs/mention_search/mention_search_cubit.dart';
import 'package:openvine/features/chat/chat_screen.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/mention_resolution_service.dart';
import 'package:openvine/widgets/mentions/mention_overlay.dart';
import 'package:profile_repository/profile_repository.dart';

class _ChatCubit extends MockCubit<ChatState> implements ChatCubit {}

class _Profiles extends Mock implements ProfileRepository {}

const _river =
    '3333333333333333333333333333333333333333333333333333333333333333';

void main() {
  setUpAll(() => registerFallbackValue(const <MentionBinding>[]));
  group('room mention lookup', () {
    for (final compact in [false, true]) {
      testWidgets('offers and selects accounts; compact keyboard: $compact', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        try {
          if (compact) {
            tester.view.physicalSize = const Size(320, 720);
            tester.view.devicePixelRatio = 1;
            tester.view.viewInsets = const FakeViewPadding(bottom: 340);
            addTearDown(tester.view.reset);
          }
          final chat = _ChatCubit();
          whenListen(
            chat,
            const Stream<ChatState>.empty(),
            initialState: const ChatState(),
          );
          when(chat.visibleMessages).thenReturn([]);
          when(
            () => chat.send(
              communityId: any(named: 'communityId'),
              channelId: any(named: 'channelId'),
              author: any(named: 'author'),
              body: any(named: 'body'),
              nowMilliseconds: any(named: 'nowMilliseconds'),
              selectedMentions: any(named: 'selectedMentions'),
            ),
          ).thenAnswer((_) async => false);
          final profiles = _Profiles();
          when(() => profiles.getCachedProfiles(pubkeys: any(named: 'pubkeys')))
              .thenAnswer((_) async => []);
          when(
            () => profiles.searchUsersFromApi(
              query: 'riv',
              limit: any(named: 'limit'),
              sortBy: any(named: 'sortBy'),
            ),
          ).thenAnswer(
            (_) async => [
              UserProfile(
                pubkey: _river,
                displayName: 'River',
                rawData: const {},
                createdAt: DateTime(2026),
                eventId: '4' * 64,
              ),
              for (final digit in ['4', '5', '6', '7'])
                UserProfile(
                  pubkey: digit * 64,
                  displayName: 'River $digit',
                  rawData: const {},
                  createdAt: DateTime(2026),
                  eventId: '8' * 64,
                ),
            ],
          );
          final mentions = MentionSearchCubit(
            profileRepositoryOf: () => profiles,
          );
          addTearDown(mentions.close);
          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                userProfileReactiveProvider(_river)
                    .overrideWith((ref) => Stream.value(null)),
              ],
              child: MaterialApp(
                builder: (context, child) => MediaQuery(
                  data: MediaQuery.of(context)
                      .copyWith(textScaler: TextScaler.linear(compact ? 2 : 1)),
                  child: child!,
                ),
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: MultiBlocProvider(
                  providers: [
                    BlocProvider<ChatCubit>.value(value: chat),
                    BlocProvider<MentionSearchCubit>.value(value: mentions),
                  ],
                  child: const ChatScreen(),
                ),
              ),
            ),
          );
          await tester.enterText(find.byType(TextField), '  Hello @riv');
          await tester.pumpAndSettle();
          expect(find.byType(MentionOverlay), findsOneWidget);
          await tester.tap(find.text('River'));
          await tester.pumpAndSettle();
          expect(find.text('  Hello @River '), findsOneWidget);
          expect(find.byType(MentionOverlay), findsNothing);
          expect(tester.testTextInput.isVisible, isTrue);
          await tester.tap(
            find.bySemanticsIdentifier('dm_message_send_button'),
          );
          final bindings =
              verify(
                    () => chat.send(
                      communityId: any(named: 'communityId'),
                      channelId: any(named: 'channelId'),
                      author: any(named: 'author'),
                      body: '  Hello @River ',
                      nowMilliseconds: any(named: 'nowMilliseconds'),
                      selectedMentions: captureAny(named: 'selectedMentions'),
                    ),
                  ).captured.single
                  as List<MentionBinding>;
          expect(bindings.single.pubkey, _river);
          expect(bindings.single.start, 8);
          expect(bindings.single.end, 14);
          expect(tester.takeException(), isNull);
        } finally {
          semantics.dispose();
        }
      });
    }
  });
}
