// ABOUTME: Regression test for the BlocProvider repo-swap pattern in
// ABOUTME: ConversationPage — verifies the ConversationBloc is recreated
// ABOUTME: when dmRepositoryProvider rebuilds (auth flip / sign-out /
// ABOUTME: account switch), so reads/writes never split between a stale
// ABOUTME: captured repo and the active one.
//
// Mirrors `pooled_video_feed_item_repo_swap_test.dart` (#3503). The
// production site is `conversation_page.dart`'s `BlocProvider<
// ConversationBloc>(key: ValueKey((dmRepository, currentPubkey)), …)`.
// Without this key, a `dmRepository` captured during a brief
// unauthenticated window scopes all message reads/writes by the wrong
// `_userPubkey` for the lifetime of the bloc, reproducing the
// "looks sent, then disappeared" bug.

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation/collaborator_invite_actions_cubit.dart';
import 'package:openvine/blocs/dm/conversation/conversation_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/inbox/conversation/conversation_view.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/collaborator_invite_state_store.dart';
import 'package:openvine/services/collaborator_response_service.dart';

import '../../../helpers/test_provider_overrides.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockAuthService extends Mock implements AuthService {}

class _MockCollaboratorInviteStateStore extends Mock
    implements CollaboratorInviteStateStore {}

class _MockCollaboratorResponseService extends Mock
    implements CollaboratorResponseService {}

/// Toggle a `StateProvider<int>` to force `dmRepositoryProvider` to
/// rebuild and return a different mock — mirrors what happens in
/// production when auth flips (the real provider rebuilds when
/// `nostrServiceProvider` rebuilds, which happens via
/// `_onAuthStateChanged` in `nostr_client_provider.dart`).
final _dmRepoSwap = StateProvider<int>((ref) => 0);

/// Toggle for [collaboratorResponseServiceProvider] swaps. The real
/// provider composes `authServiceProvider` + `nostrServiceProvider` in
/// `app_providers.dart`, so it rebuilds on auth flips.
final _responseSvcSwap = StateProvider<int>((ref) => 0);

void main() {
  const testPubkey =
      'aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd';
  const otherPubkey =
      '1122334455667788112233445566778811223344556677881122334455667788';
  const testConversationId =
      'ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00ff00';

  group('ConversationPage — BlocProvider repo-swap', () {
    late _MockDmRepository mockRepoA;
    late _MockDmRepository mockRepoB;
    late _MockAuthService mockAuthService;

    setUp(() {
      mockRepoA = _MockDmRepository();
      mockRepoB = _MockDmRepository();
      mockAuthService = _MockAuthService();

      // ConversationBloc subscribes to watchMessages on construction
      // (ConversationStarted) and marks the conversation as read.
      // Stub both mocks so the bloc can run without throwing.
      for (final repo in [mockRepoA, mockRepoB]) {
        // Both stand in for credentialed repositories: the bloc holds its
        // loading state while the owner is unknown (#8187), which would
        // otherwise mask the re-keying this file exists to pin.
        when(() => repo.userPubkey).thenReturn(testPubkey);
        when(
          () => repo.watchRefiledFrom(any()),
        ).thenAnswer((_) => const Stream<Set<String>>.empty());
        when(() => repo.markConversationAsRead(any()))
            .thenAnswer((_) async => true);
        when(repo.backfillHistoryIfNeeded).thenAnswer((_) async {});
        when(
          () => repo.watchMessages(any()),
        ).thenAnswer((_) => const Stream<List<DmMessage>>.empty());
        when(
          () => repo.watchOutgoing(any()),
        ).thenAnswer((_) => Stream.value(const <OutgoingDm>[]));
      }

      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPubkey);
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());
    });

    testWidgets(
      'recreates ConversationBloc when dmRepositoryProvider rebuilds with '
      'a new repository instance',
      (tester) async {
        await tester.pumpWidget(
          testMaterialApp(
            mockAuthService: mockAuthService,
            additionalOverrides: [
              isDmRestrictedProvider.overrideWithValue(false),
              dmRepositoryProvider.overrideWith((ref) {
                final v = ref.watch(_dmRepoSwap);
                return v == 0 ? mockRepoA : mockRepoB;
              }),
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => null),
            ],
            home: const ConversationPage(
              conversationId: testConversationId,
              participantPubkeys: [otherPubkey],
            ),
          ),
        );
        await tester.pump();

        // Capture the bloc that was created when the page first built.
        final viewContextBefore = tester.element(find.byType(ConversationView));
        final blocA = BlocProvider.of<ConversationBloc>(viewContextBefore);
        expect(blocA.isClosed, isFalse, reason: 'initial bloc should be alive');

        // Flip the toggle. dmRepositoryProvider rebuilds, ConversationPage's
        // ref.watch fires, the composite ValueKey changes, BlocProvider
        // unmounts blocA and creates a new bloc wrapping mockRepoB.
        final providerScope = ProviderScope.containerOf(
          tester.element(find.byType(ConversationPage)),
        );
        providerScope.read(_dmRepoSwap.notifier).state = 1;
        await tester.pump();

        final viewContextAfter = tester.element(find.byType(ConversationView));
        final blocB = BlocProvider.of<ConversationBloc>(viewContextAfter);

        expect(
          blocB,
          isNot(same(blocA)),
          reason:
              'BlocProvider must create a new ConversationBloc when '
              'dmRepository identity flips. Without the ValueKey on the '
              'BlocProvider, the bloc would keep using a stale '
              'DmRepository whose `_userPubkey` could be empty (or scope '
              'rows under a different ownerPubkey), causing watchMessages '
              'to return nothing and sent messages to "disappear".',
        );
      },
    );

    testWidgets(
      'holds loading on the owner-unknown repository and subscribes only '
      'once a credentialed repository arrives (#8187)',
      (tester) async {
        // repoA stands in for the uncredentialed instance
        // dmRepositoryProvider serves while signed out or tearing down:
        // owner unknown, so ConversationBloc must hold
        // loading and never reach the owner-scoped reads (which would
        // otherwise return every account's rows at the DAO). repoB is the
        // credentialed instance that arrives at nostrReady.
        when(() => mockRepoA.userPubkey).thenReturn('');

        await tester.pumpWidget(
          testMaterialApp(
            mockAuthService: mockAuthService,
            additionalOverrides: [
              isDmRestrictedProvider.overrideWithValue(false),
              dmRepositoryProvider.overrideWith((ref) {
                final v = ref.watch(_dmRepoSwap);
                return v == 0 ? mockRepoA : mockRepoB;
              }),
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => null),
            ],
            home: const ConversationPage(
              conversationId: testConversationId,
              participantPubkeys: [otherPubkey],
            ),
          ),
        );
        await tester.pump();

        // The uncredentialed bloc stayed in loading: it never subscribed to
        // messages and never advanced a read cursor on the owner-unknown
        // repository. Removing the bloc's owner guard reddens this line.
        verifyNever(() => mockRepoA.watchMessages(any()));
        verifyNever(() => mockRepoA.markConversationAsRead(any()));

        // Credentials arrive: dmRepositoryProvider rebuilds, the composite
        // ValueKey flips, and the recreated bloc re-dispatches
        // ConversationStarted against the credentialed repository.
        final providerScope = ProviderScope.containerOf(
          tester.element(find.byType(ConversationPage)),
        );
        providerScope.read(_dmRepoSwap.notifier).state = 1;
        await tester.pump();

        // Recovery: the credentialed repository is now subscribed. Without
        // the re-key the bloc would keep the owner-unknown repository and
        // spin in loading forever.
        verify(() => mockRepoB.watchMessages(any())).called(1);
      },
    );

    testWidgets(
      'preserves the same ConversationBloc when the dmRepository identity '
      'does not change across rebuilds',
      (tester) async {
        await tester.pumpWidget(
          testMaterialApp(
            mockAuthService: mockAuthService,
            additionalOverrides: [
              isDmRestrictedProvider.overrideWithValue(false),
              dmRepositoryProvider.overrideWith((ref) {
                ref.watch(_dmRepoSwap);
                return mockRepoA; // identity stays the same
              }),
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => null),
            ],
            home: const ConversationPage(
              conversationId: testConversationId,
              participantPubkeys: [otherPubkey],
            ),
          ),
        );
        await tester.pump();

        final blocA = BlocProvider.of<ConversationBloc>(
          tester.element(find.byType(ConversationView)),
        );

        // Force the provider to rebuild but return the same instance.
        // The record-typed ValueKey compares structurally on `==`; for
        // classes that don't override `==`, equality falls through to
        // identity, so the key stays equal and the bloc is preserved.
        final providerScope = ProviderScope.containerOf(
          tester.element(find.byType(ConversationPage)),
        );
        providerScope.read(_dmRepoSwap.notifier).state = 1;
        await tester.pump();

        final blocAfter = BlocProvider.of<ConversationBloc>(
          tester.element(find.byType(ConversationView)),
        );

        expect(
          blocAfter,
          same(blocA),
          reason:
              'Identical dmRepository identity should keep the same bloc '
              '— the record key prevents unnecessary churn on rebuilds.',
        );
      },
    );

    // Documents an intentional trade-off mirroring the four canonical
    // sites (`video_feed_page.dart` / `pooled_fullscreen_video_feed_screen
    // .dart`): when the composite key changes, the old bloc is closed and
    // the new one starts from initial state. Optimistic message rows and
    // any in-flight `_onMessageSent` against the previous repo are
    // intentionally dropped — the new repo points at a different
    // `NostrClient` (different signer, possibly different user) so
    // replaying them would be unsafe.
    //
    // Today the only paths that flip this key are auth state transitions
    // (cold-launch race, sign-in/out, account switch). If a future change
    // adds a non-auth invalidation of `dmRepositoryProvider`, this test
    // will fail loudly so the state-loss can be re-evaluated.
    testWidgets(
      'resets bloc state when dmRepositoryProvider rebuilds (intentional)',
      (tester) async {
        await tester.pumpWidget(
          testMaterialApp(
            mockAuthService: mockAuthService,
            additionalOverrides: [
              isDmRestrictedProvider.overrideWithValue(false),
              dmRepositoryProvider.overrideWith((ref) {
                final v = ref.watch(_dmRepoSwap);
                return v == 0 ? mockRepoA : mockRepoB;
              }),
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => null),
            ],
            home: const ConversationPage(
              conversationId: testConversationId,
              participantPubkeys: [otherPubkey],
            ),
          ),
        );
        await tester.pump();

        final blocBefore = BlocProvider.of<ConversationBloc>(
          tester.element(find.byType(ConversationView)),
        );

        // Synthesise a non-initial state to prove it actually gets lost
        // on swap — mirrors what an in-flight optimistic + failure would
        // look like.
        blocBefore.emit(
          const ConversationState(
            status: ConversationStatus.loaded,
            sendStatus: SendStatus.failed,
          ),
        );

        final providerScope = ProviderScope.containerOf(
          tester.element(find.byType(ConversationPage)),
        );
        providerScope.read(_dmRepoSwap.notifier).state = 1;
        await tester.pump();

        final blocAfter = BlocProvider.of<ConversationBloc>(
          tester.element(find.byType(ConversationView)),
        );
        expect(blocAfter, isNot(same(blocBefore)));
        // Fresh bloc starts from initial state (the failed status is lost).
        expect(blocAfter.state.sendStatus, equals(SendStatus.idle));
      },
    );
  });

  // The sibling BlocProvider in `conversation_page.dart` carries the same
  // ValueKey treatment for `CollaboratorInviteActionsCubit`. The cubit's
  // `responseService` composes `authServiceProvider` + `nostrServiceProvider`
  // (see `app_providers.dart`), so its identity flips on auth changes —
  // without the key, accept-invite would publish through a stale signer
  // for the cubit's lifetime.
  group('ConversationPage — invite cubit repo-swap', () {
    late _MockDmRepository mockDmRepository;
    late _MockAuthService mockAuthService;
    late _MockCollaboratorInviteStateStore mockStateStore;
    late _MockCollaboratorResponseService mockResponseSvcA;
    late _MockCollaboratorResponseService mockResponseSvcB;

    setUp(() {
      mockDmRepository = _MockDmRepository();
      mockAuthService = _MockAuthService();
      mockStateStore = _MockCollaboratorInviteStateStore();
      mockResponseSvcA = _MockCollaboratorResponseService();
      mockResponseSvcB = _MockCollaboratorResponseService();

      when(() => mockDmRepository.userPubkey).thenReturn(testPubkey);
      when(
        () => mockDmRepository.watchRefiledFrom(any()),
      ).thenAnswer((_) => const Stream<Set<String>>.empty());
      when(
        () => mockDmRepository.backfillHistoryIfNeeded(),
      ).thenAnswer((_) async {});
      when(
        () => mockDmRepository.markConversationAsRead(any()),
      ).thenAnswer((_) async => true);
      when(
        () => mockDmRepository.watchMessages(any()),
      ).thenAnswer((_) => const Stream<List<DmMessage>>.empty());
      when(
        () => mockDmRepository.watchOutgoing(any()),
      ).thenAnswer((_) => Stream.value(const <OutgoingDm>[]));

      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPubkey);
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());
    });

    testWidgets('recreates CollaboratorInviteActionsCubit when '
        'collaboratorResponseServiceProvider rebuilds with a new instance', (
      tester,
    ) async {
      await tester.pumpWidget(
        testMaterialApp(
          mockAuthService: mockAuthService,
          additionalOverrides: [
            isDmRestrictedProvider.overrideWithValue(false),
            dmRepositoryProvider.overrideWith((ref) => mockDmRepository),
            collaboratorInviteStateStoreProvider.overrideWith(
              (ref) => mockStateStore,
            ),
            collaboratorResponseServiceProvider.overrideWith((ref) {
              final v = ref.watch(_responseSvcSwap);
              return v == 0 ? mockResponseSvcA : mockResponseSvcB;
            }),
            fetchUserProfileProvider(
              otherPubkey,
            ).overrideWith((ref) async => null),
          ],
          home: const ConversationPage(
            conversationId: testConversationId,
            participantPubkeys: [otherPubkey],
          ),
        ),
      );
      await tester.pump();

      final cubitA = BlocProvider.of<CollaboratorInviteActionsCubit>(
        tester.element(find.byType(ConversationView)),
      );
      expect(cubitA.isClosed, isFalse);

      final providerScope = ProviderScope.containerOf(
        tester.element(find.byType(ConversationPage)),
      );
      providerScope.read(_responseSvcSwap.notifier).state = 1;
      await tester.pump();

      final cubitB = BlocProvider.of<CollaboratorInviteActionsCubit>(
        tester.element(find.byType(ConversationView)),
      );
      expect(
        cubitB,
        isNot(same(cubitA)),
        reason:
            'BlocProvider must recreate the cubit when '
            'collaboratorResponseServiceProvider identity flips. Without '
            'the ValueKey, accept-invite publishes would route through a '
            'stale signer/relay captured at first build.',
      );
    });

    testWidgets(
      'preserves the same CollaboratorInviteActionsCubit when the response '
      'service identity does not change across rebuilds',
      (tester) async {
        await tester.pumpWidget(
          testMaterialApp(
            mockAuthService: mockAuthService,
            additionalOverrides: [
              isDmRestrictedProvider.overrideWithValue(false),
              dmRepositoryProvider.overrideWith((ref) => mockDmRepository),
              collaboratorInviteStateStoreProvider.overrideWith(
                (ref) => mockStateStore,
              ),
              collaboratorResponseServiceProvider.overrideWith((ref) {
                ref.watch(_responseSvcSwap);
                return mockResponseSvcA; // identity stays the same
              }),
              fetchUserProfileProvider(
                otherPubkey,
              ).overrideWith((ref) async => null),
            ],
            home: const ConversationPage(
              conversationId: testConversationId,
              participantPubkeys: [otherPubkey],
            ),
          ),
        );
        await tester.pump();

        final cubitBefore = BlocProvider.of<CollaboratorInviteActionsCubit>(
          tester.element(find.byType(ConversationView)),
        );

        final providerScope = ProviderScope.containerOf(
          tester.element(find.byType(ConversationPage)),
        );
        providerScope.read(_responseSvcSwap.notifier).state = 1;
        await tester.pump();

        final cubitAfter = BlocProvider.of<CollaboratorInviteActionsCubit>(
          tester.element(find.byType(ConversationView)),
        );
        expect(cubitAfter, same(cubitBefore));
      },
    );
  });
}
