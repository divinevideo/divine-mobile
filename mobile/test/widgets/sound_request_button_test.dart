import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/sound_requests/sound_requests_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/router/routes/messaging_routes.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/widgets/video_feed_item/metadata/sound_request_button.dart';

class _Repository extends Mock implements SoundRequestsRepository {}

const owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const creator =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const address = '34236:$creator:clip';
void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  group('interactions', () {
    testWidgets(
      'a fulfilled request does not label a new request as already sent',
      (tester) async {
        final repo = _Repository();
        when(() => repo.ownerPubkey).thenReturn(owner);
        when(repo.watchState).thenAnswer(
          (_) => Stream.value(
            SoundRequestSnapshot(
              requests: {
                'c' * 64: SoundRequestEntry(
                  id: 'c' * 64,
                  requester: owner,
                  videoAddress: address,
                  status: SoundRequestStatus.ready,
                ),
              },
            ),
          ),
        );
        when(repo.start).thenAnswer((_) async {});
        when(() => repo.canRequest(address)).thenAnswer((_) async => true);
        final cubit = SoundRequestsCubit();
        await cubit.connect(repo);
        addTearDown(cubit.close);
        await tester.pumpWidget(
          BlocProvider.value(
            value: cubit,
            child: const MaterialApp(
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: Scaffold(body: SoundRequestButton(videoAddress: address)),
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text(l10n.soundRequestAction), findsOneWidget);
        expect(find.text(l10n.soundRequestSent), findsNothing);
      },
    );
  });

  for (final available in [true, false]) {
    group('interactions', () {
      testWidgets(
        'request action follows current source eligibility: $available',
        (tester) async {
          final repo = _Repository();
          when(() => repo.ownerPubkey).thenReturn(owner);
          when(repo.watchState).thenAnswer((_) => const Stream.empty());
          when(repo.start).thenAnswer((_) async {});
          when(() => repo.canRequest(address))
              .thenAnswer((_) async => available);
          final cubit = SoundRequestsCubit();
          await cubit.connect(repo);
          addTearDown(cubit.close);
          await tester.pumpWidget(
            BlocProvider.value(
              value: cubit,
              child: const MaterialApp(
                localizationsDelegates: appLocalizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: Scaffold(
                  body: SoundRequestButton(videoAddress: address),
                ),
              ),
            ),
          );
          await tester.pumpAndSettle();
          expect(
            find.text(l10n.soundRequestAction),
            available ? findsOneWidget : findsNothing,
          );
        },
      );
    });
  }

  group('navigation', () {
    testWidgets('opens the creator thread with the creator as counterparty', (
      tester,
    ) async {
      final repo = _Repository();
      when(() => repo.ownerPubkey).thenReturn(owner);
      when(repo.watchState).thenAnswer(
        (_) => Stream.value(
          SoundRequestSnapshot(
            requests: {
              'c' * 64: SoundRequestEntry(
                id: 'c' * 64,
                requester: owner,
                videoAddress: address,
              ),
            },
          ),
        ),
      );
      when(repo.start).thenAnswer((_) async {});
      when(() => repo.canRequest(address)).thenAnswer((_) async => true);
      final cubit = SoundRequestsCubit();
      await cubit.connect(repo);
      addTearDown(cubit.close);
      GoRouterState? opened;
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => const Scaffold(
              body: SoundRequestButton(videoAddress: address),
            ),
          ),
          GoRoute(
            path: ConversationPage.pathPattern,
            builder: (_, state) {
              opened = state;
              return const SizedBox.shrink();
            },
          ),
        ],
      );
      addTearDown(router.dispose);
      await tester.pumpWidget(
        ProviderScope(
          child: BlocProvider.value(
            value: cubit,
            child: MaterialApp.router(
              routerConfig: router,
              localizationsDelegates: appLocalizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      await tester.tap(find.text(l10n.soundRequestSent));
      await tester.pumpAndSettle();

      expect(
        opened?.pathParameters['id'],
        equals(DmRepository.computeConversationId([owner, creator])),
      );
      // The conversation route reads its hint through dmRouteExtra, and the
      // hint names the counterparties only, never the signed-in account.
      expect(
        dmRouteExtra(opened?.extra).participantPubkeys,
        equals([creator]),
      );
    });
  });
}
