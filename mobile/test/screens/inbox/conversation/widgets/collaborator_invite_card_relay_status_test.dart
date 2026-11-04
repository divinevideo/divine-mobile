// ABOUTME: Pins the DM invite card against the same kind-34238 signal the
// ABOUTME: video surface reads, for both the sent and the received card.

import 'dart:async';
import 'dart:convert';

import 'package:bloc_test/bloc_test.dart';
import 'package:collaborator_repository/collaborator_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' hide AspectRatio;
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/blocs/dm/conversation/collaborator_invite_actions_cubit.dart';
import 'package:openvine/blocs/video_collaborator_status/video_collaborator_status_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/collaborator_invite.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/screens/inbox/conversation/widgets/collaborator_invite_card.dart';
import 'package:openvine/services/collaborator_invite_local_state_adapter.dart';
import 'package:openvine/services/collaborator_invite_state_store.dart';
import 'package:openvine/services/collaborator_response_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:videos_repository/videos_repository.dart';

import '../../../../helpers/test_provider_overrides.dart';

class _MockRelayClient extends Mock implements NostrClient {}

class _MockVideosRepository extends Mock implements VideosRepository {}

class _MockResponseService extends Mock
    implements CollaboratorResponseService {}

class _MockCollaboratorInviteActionsCubit
    extends MockCubit<CollaboratorInviteActionsState>
    implements CollaboratorInviteActionsCubit {}

class _FakeFilter extends Fake implements Filter {}

const _creatorPubkey =
    '1122334411223344112233441122334411223344112233441122334411223344';
const _inviteePubkey =
    '5566778855667788556677885566778855667788556677885566778855667788';
const _otherCollaboratorPubkey =
    '99aabbcc99aabbcc99aabbcc99aabbcc99aabbcc99aabbcc99aabbcc99aabbcc';
const _videoAddress = '34236:$_creatorPubkey:skate-loop';

const _invite = CollaboratorInvite(
  messageId: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
  videoAddress: _videoAddress,
  videoKind: 34236,
  creatorPubkey: _creatorPubkey,
  videoDTag: 'skate-loop',
  role: 'Collaborator',
  title: 'Skate loop',
);

Event _acceptance({String pubkey = _inviteePubkey}) => Event(pubkey, 34238, [
  ['a', _videoAddress, 'wss://relay.divine.video', 'root'],
  ['p', _creatorPubkey],
  ['status', 'accepted'],
], '');

VideoEvent _video({List<String> collaborators = const [_inviteePubkey]}) =>
    VideoEvent(
      id: 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
      pubkey: _creatorPubkey,
      createdAt: 1730000000,
      content: '',
      timestamp: DateTime.utc(2024, 10, 27),
      addressableDTag: 'skate-loop',
      collaboratorPubkeys: collaborators,
    );

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(_FakeFilter());
    registerFallbackValue(<CollaboratorInvite>[]);
    registerFallbackValue(_invite);
  });

  group(CollaboratorInviteCard, () {
    late _MockRelayClient relayClient;
    late StreamController<Event> relay;
    late _MockVideosRepository videosRepository;
    late int subscribeCalls;
    late int unsubscribeCalls;
    void Function()? onEose;

    void stubVideo(VideoEvent? video) {
      when(
        () => videosRepository.fetchVideoWithStatsForRouteId(
          any(),
          fallbackRouteIds: any(named: 'fallbackRouteIds'),
        ),
      ).thenAnswer((_) async => video);
    }

    setUp(() {
      relayClient = _MockRelayClient();
      relay = StreamController<Event>.broadcast();
      onEose = null;
      subscribeCalls = 0;
      unsubscribeCalls = 0;
      when(
        () => relayClient.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
          relayTypes: any(named: 'relayTypes'),
          sendAfterAuth: any(named: 'sendAfterAuth'),
          onEose: any(named: 'onEose'),
        ),
      ).thenAnswer((invocation) {
        subscribeCalls++;
        onEose = invocation.namedArguments[#onEose] as void Function()?;
        return relay.stream;
      });
      when(() => relayClient.unsubscribe(any())).thenAnswer((_) async {
        unsubscribeCalls++;
      });

      videosRepository = _MockVideosRepository();
      stubVideo(_video());
    });

    tearDown(() async {
      await relay.close();
    });

    Future<void> pumpCard(
      WidgetTester tester, {
      required bool isSent,
      required CollaboratorConfirmationRepository repo,
      required CollaboratorInviteActionsCubit cubit,
      String? collaboratorPubkey = _inviteePubkey,
    }) async {
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            nostrServiceProvider.overrideWithValue(createMockNostrService()),
            videosRepositoryProvider.overrideWithValue(videosRepository),
            collaboratorConfirmationRepositoryProvider.overrideWithValue(repo),
          ],
          child: MaterialApp(
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: BlocProvider<CollaboratorInviteActionsCubit>.value(
                value: cubit,
                child: CollaboratorInviteCard(
                  invite: _invite,
                  isSent: isSent,
                  collaboratorPubkey: collaboratorPubkey,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    /// The cubit the video's avatar row uses, on the same repository.
    VideoCollaboratorStatusCubit videoSurface(
      CollaboratorConfirmationRepository repo, {
      List<String> taggedPubkeys = const [_inviteePubkey],
    }) => VideoCollaboratorStatusCubit(
      repository: repo,
      videoAddress: _videoAddress,
      creatorPubkey: _creatorPubkey,
      taggedPubkeys: taggedPubkeys,
    );

    Future<void> deliver(
      WidgetTester tester, [
      List<Event> events = const [],
    ]) async {
      events.forEach(relay.add);
      onEose?.call();
      await tester.pump();
      await tester.pump();
    }

    group('sent card', () {
      late CollaboratorConfirmationRepository repo;
      late _MockCollaboratorInviteActionsCubit actionsCubit;

      setUp(() async {
        SharedPreferences.setMockInitialValues({});
        repo = CollaboratorConfirmationRepository(
          nostrClient: relayClient,
          localStateReader: CollaboratorInviteLocalStateAdapter(
            CollaboratorInviteStateStore(
              prefs: await SharedPreferences.getInstance(),
            ),
          ),
          currentUserPubkey: _creatorPubkey,
        );
        actionsCubit = _MockCollaboratorInviteActionsCubit();
        when(
          () => actionsCubit.state,
        ).thenReturn(const CollaboratorInviteActionsState());
      });

      tearDown(() => repo.close());

      group('renders', () {
        testWidgets('Accepted once the invitee accepts on the relay', (
          tester,
        ) async {
          final l10n = lookupAppLocalizations(const Locale('en'));
          final video = videoSurface(repo);
          addTearDown(video.close);

          await pumpCard(tester, isSent: true, repo: repo, cubit: actionsCubit);
          await deliver(tester, [_acceptance()]);

          expect(
            video.state.statusByPubkey[_inviteePubkey],
            CollaboratorStatus.confirmed,
          );
          expect(
            find.text(l10n.inboxCollabInviteAcceptedStatus),
            findsOneWidget,
          );
          expect(find.text(l10n.inboxCollabInviteSentStatus), findsNothing);
          expect(find.text(l10n.inboxCollabInviteCoPostButton), findsNothing);
          expect(find.text(l10n.inboxCollabInviteNotMineButton), findsNothing);
        });

        testWidgets('Invitation sent while no acceptance exists', (
          tester,
        ) async {
          final l10n = lookupAppLocalizations(const Locale('en'));
          final video = videoSurface(repo);
          addTearDown(video.close);

          await pumpCard(tester, isSent: true, repo: repo, cubit: actionsCubit);
          await deliver(tester);

          expect(
            video.state.statusByPubkey[_inviteePubkey],
            CollaboratorStatus.pending,
          );
          expect(find.text(l10n.inboxCollabInviteSentStatus), findsOneWidget);
          expect(find.text(l10n.inboxCollabInviteCoPostButton), findsNothing);
        });

        testWidgets(
          'Invitation sent when a different collaborator on the video accepts',
          (tester) async {
            final l10n = lookupAppLocalizations(const Locale('en'));
            const tagged = [_inviteePubkey, _otherCollaboratorPubkey];
            stubVideo(_video(collaborators: tagged));
            final video = videoSurface(repo, taggedPubkeys: tagged);
            addTearDown(video.close);

            await pumpCard(
              tester,
              isSent: true,
              repo: repo,
              cubit: actionsCubit,
            );
            await deliver(tester, [
              _acceptance(pubkey: _otherCollaboratorPubkey),
            ]);

            expect(
              video.state.statusByPubkey[_otherCollaboratorPubkey],
              CollaboratorStatus.confirmed,
            );
            expect(
              find.text(l10n.inboxCollabInviteSentStatus),
              findsOneWidget,
            );
            expect(
              find.text(l10n.inboxCollabInviteAcceptedStatus),
              findsNothing,
            );
          },
        );

        testWidgets(
          'Invitation sent when the invitee accepted but is no longer tagged',
          (tester) async {
            final l10n = lookupAppLocalizations(const Locale('en'));
            stubVideo(_video(collaborators: const [_otherCollaboratorPubkey]));

            await pumpCard(
              tester,
              isSent: true,
              repo: repo,
              cubit: actionsCubit,
            );
            await deliver(tester, [_acceptance()]);

            expect(subscribeCalls, 0);
            expect(
              find.text(l10n.inboxCollabInviteSentStatus),
              findsOneWidget,
            );
            expect(
              find.text(l10n.inboxCollabInviteAcceptedStatus),
              findsNothing,
            );
          },
        );

        testWidgets(
          'Invitation sent without watching when the found video belongs to '
          'another author',
          (tester) async {
            final l10n = lookupAppLocalizations(const Locale('en'));
            when(
              () => videosRepository.fetchVideoWithStatsForRouteId(
                any(),
                fallbackRouteIds: any(named: 'fallbackRouteIds'),
              ),
            ).thenAnswer(
              (_) async => VideoEvent(
                id: 'abababababababababababababababababababababababababababababababab',
                pubkey: _otherCollaboratorPubkey,
                createdAt: 1730000001,
                content: '',
                timestamp: DateTime.utc(2024, 10, 28),
                addressableDTag: 'skate-loop',
                collaboratorPubkeys: const [_inviteePubkey],
              ),
            );

            await pumpCard(
              tester,
              isSent: true,
              repo: repo,
              cubit: actionsCubit,
            );
            await deliver(tester, [_acceptance()]);

            expect(subscribeCalls, 0);
            expect(
              find.text(l10n.inboxCollabInviteSentStatus),
              findsOneWidget,
            );
            expect(
              find.text(l10n.inboxCollabInviteAcceptedStatus),
              findsNothing,
            );
          },
        );

        testWidgets(
          'Invitation sent without watching when the video cannot be found',
          (tester) async {
            final l10n = lookupAppLocalizations(const Locale('en'));
            stubVideo(null);

            await pumpCard(
              tester,
              isSent: true,
              repo: repo,
              cubit: actionsCubit,
            );

            expect(subscribeCalls, 0);
            expect(
              find.text(l10n.inboxCollabInviteSentStatus),
              findsOneWidget,
            );
          },
        );

        testWidgets(
          'Invitation sent without watching when the found video has another '
          'event kind with the same author and d-tag',
          (tester) async {
            final l10n = lookupAppLocalizations(const Locale('en'));
            stubVideo(_video().copyWith(eventKind: 34235));

            await pumpCard(
              tester,
              isSent: true,
              repo: repo,
              cubit: actionsCubit,
            );
            await deliver(tester, [_acceptance()]);

            expect(subscribeCalls, 0);
            expect(
              find.text(l10n.inboxCollabInviteSentStatus),
              findsOneWidget,
            );
            expect(
              find.text(l10n.inboxCollabInviteAcceptedStatus),
              findsNothing,
            );
          },
        );

        testWidgets(
          'Invitation sent without watching when the invitee is unknown',
          (tester) async {
            final l10n = lookupAppLocalizations(const Locale('en'));

            await pumpCard(
              tester,
              isSent: true,
              repo: repo,
              cubit: actionsCubit,
              collaboratorPubkey: null,
            );

            expect(subscribeCalls, 0);
            expect(
              find.text(l10n.inboxCollabInviteSentStatus),
              findsOneWidget,
            );
            expect(
              find.text(l10n.inboxCollabInviteCoPostButton),
              findsNothing,
            );
          },
        );
      });

      group('watch lifecycle', () {
        testWidgets('shares the video surface subscription and keeps it '
            'alive after the card goes away', (tester) async {
          final video = videoSurface(repo);
          addTearDown(video.close);
          await tester.pump();
          expect(subscribeCalls, 1);

          await pumpCard(tester, isSent: true, repo: repo, cubit: actionsCubit);
          expect(subscribeCalls, 1);
          await deliver(tester, [_acceptance()]);
          expect(
            find.text(
              lookupAppLocalizations(
                const Locale('en'),
              ).inboxCollabInviteAcceptedStatus,
            ),
            findsOneWidget,
          );

          await tester.pumpWidget(const SizedBox.shrink());
          // The release chain crosses a real event-loop turn, which fake-async
          // pumps never reach.
          await tester.runAsync(pumpEventQueue);
          expect(unsubscribeCalls, 0);
          expect(
            video.state.statusByPubkey[_inviteePubkey],
            CollaboratorStatus.confirmed,
          );
        });

        testWidgets('releases its own subscription when the card goes away', (
          tester,
        ) async {
          await pumpCard(tester, isSent: true, repo: repo, cubit: actionsCubit);
          expect(subscribeCalls, 1);

          await tester.pumpWidget(const SizedBox.shrink());
          // The release chain crosses a real event-loop turn, which fake-async
          // pumps never reach.
          await tester.runAsync(pumpEventQueue);

          expect(unsubscribeCalls, 1);
        });
      });
    });

    group('received card', () {
      late CollaboratorInviteStateStore store;
      late CollaboratorConfirmationRepository repo;
      late CollaboratorInviteActionsCubit actionsCubit;

      late _MockResponseService responseService;

      Future<void> build({String? stored}) async {
        responseService = _MockResponseService();
        SharedPreferences.setMockInitialValues({
          if (stored != null)
            CollaboratorInviteStateStore.storageKey: jsonEncode({
              '$_videoAddress|$_creatorPubkey|$_inviteePubkey': stored,
            }),
        });
        store = CollaboratorInviteStateStore(
          prefs: await SharedPreferences.getInstance(),
        );
        repo = CollaboratorConfirmationRepository(
          nostrClient: relayClient,
          localStateReader: CollaboratorInviteLocalStateAdapter(store),
          currentUserPubkey: _inviteePubkey,
        );
        actionsCubit = CollaboratorInviteActionsCubit(
          stateStore: store,
          responseService: responseService,
          currentUserPubkey: _inviteePubkey,
          confirmationRepository: repo,
        );
        addTearDown(actionsCubit.close);
        addTearDown(repo.close);
      }

      group('renders', () {
        testWidgets('Accepted when another device accepted it', (
          tester,
        ) async {
          await build();
          final l10n = lookupAppLocalizations(const Locale('en'));
          final video = videoSurface(repo);
          addTearDown(video.close);

          await pumpCard(
            tester,
            isSent: false,
            repo: repo,
            cubit: actionsCubit,
          );
          await deliver(tester, [_acceptance()]);

          expect(
            video.state.statusByPubkey[_inviteePubkey],
            CollaboratorStatus.confirmed,
          );
          expect(
            find.text(l10n.inboxCollabInviteAcceptedStatus),
            findsOneWidget,
          );
          expect(find.text(l10n.inboxCollabInviteCoPostButton), findsNothing);
        });

        testWidgets('Accepted when this device stored the acceptance', (
          tester,
        ) async {
          await build(stored: 'accepted');
          final l10n = lookupAppLocalizations(const Locale('en'));

          await pumpCard(
            tester,
            isSent: false,
            repo: repo,
            cubit: actionsCubit,
          );

          expect(
            find.text(l10n.inboxCollabInviteAcceptedStatus),
            findsOneWidget,
          );
          expect(find.text(l10n.inboxCollabInviteCoPostButton), findsNothing);
        });

        testWidgets(
          'Accepted over a failed local attempt once the relay holds one',
          (tester) async {
            await build(stored: 'failed');
            final l10n = lookupAppLocalizations(const Locale('en'));

            await pumpCard(
              tester,
              isSent: false,
              repo: repo,
              cubit: actionsCubit,
            );
            expect(
              find.text(l10n.inboxCollabInviteAcceptError),
              findsOneWidget,
            );

            await deliver(tester, [_acceptance()]);

            expect(
              find.text(l10n.inboxCollabInviteAcceptedStatus),
              findsOneWidget,
            );
            expect(find.text(l10n.inboxCollabInviteAcceptError), findsNothing);
          },
        );

        testWidgets('Accepted over an accept left in flight by an earlier '
            'session once the relay holds one', (tester) async {
          await build(stored: 'accepting');
          final l10n = lookupAppLocalizations(const Locale('en'));

          await pumpCard(
            tester,
            isSent: false,
            repo: repo,
            cubit: actionsCubit,
          );
          await deliver(tester, [_acceptance()]);

          expect(
            find.text(l10n.inboxCollabInviteAcceptedStatus),
            findsOneWidget,
          );
          expect(find.text(l10n.inboxCollabInviteCoPostButton), findsNothing);
        });

        testWidgets('keeps both actions after a failed attempt while the '
            'relay has no acceptance', (tester) async {
          await build(stored: 'failed');
          final l10n = lookupAppLocalizations(const Locale('en'));

          await pumpCard(
            tester,
            isSent: false,
            repo: repo,
            cubit: actionsCubit,
          );
          await deliver(tester);

          expect(find.text(l10n.inboxCollabInviteAcceptError), findsOneWidget);
          expect(find.text(l10n.inboxCollabInviteCoPostButton), findsOneWidget);
          expect(
            find.text(l10n.inboxCollabInviteNotMineButton),
            findsOneWidget,
          );
        });

        testWidgets('Accepted right after a successful accept on this device', (
          tester,
        ) async {
          await build();
          when(() => responseService.acceptInvite(any())).thenAnswer(
            (_) async => const CollaboratorResponseResult.success(
              'abcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcdabcd',
            ),
          );
          final l10n = lookupAppLocalizations(const Locale('en'));

          await pumpCard(
            tester,
            isSent: false,
            repo: repo,
            cubit: actionsCubit,
          );
          await deliver(tester);
          expect(find.text(l10n.inboxCollabInviteCoPostButton), findsOneWidget);

          await tester.tap(find.text(l10n.inboxCollabInviteCoPostButton));
          await tester.runAsync(pumpEventQueue);
          await tester.pump();

          expect(
            find.text(l10n.inboxCollabInviteAcceptedStatus),
            findsOneWidget,
          );
          expect(find.text(l10n.inboxCollabInviteCoPostButton), findsNothing);
        });

        testWidgets('Ignored over any relay acceptance', (tester) async {
          await build(stored: 'ignored');
          final l10n = lookupAppLocalizations(const Locale('en'));

          await pumpCard(
            tester,
            isSent: false,
            repo: repo,
            cubit: actionsCubit,
          );
          await deliver(tester, [_acceptance()]);

          expect(
            find.text(l10n.inboxCollabInviteIgnoredStatus),
            findsOneWidget,
          );
          expect(
            find.text(l10n.inboxCollabInviteAcceptedStatus),
            findsNothing,
          );
        });
      });
    });
  });
}
