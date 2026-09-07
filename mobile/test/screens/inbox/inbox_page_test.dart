// ABOUTME: Widget tests for InboxPage, verifying BLoC setup and route constants.
// ABOUTME: Ensures InboxPage provides ConversationListBloc and MyFollowingBloc
// ABOUTME: to InboxView; the unread badge cubit is app-shell-scoped (#4976).

import 'package:bloc_test/bloc_test.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/dm/conversation_list/conversation_list_bloc.dart';
import 'package:openvine/blocs/dm/conversation_mute/conversation_mute_cubit.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/inbox/inbox_page.dart';
import 'package:openvine/screens/inbox/inbox_view.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:profile_repository/profile_repository.dart';

import '../../helpers/go_router.dart';
import '../../helpers/test_provider_overrides.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockAuthService extends Mock implements AuthService {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockInviteStatusCubit extends MockCubit<InviteStatusState>
    implements InviteStatusCubit {}

class _MockDmUnreadCountCubit extends MockCubit<int>
    implements DmUnreadCountCubit {}

/// Flip this to force `dmRepositoryProvider` to hand over a different
/// DmRepository instance — mirrors production, where the keepAlive provider
/// rebuilds a fresh repository (initially not-ready, then ready) as the nostr
/// session advances identityKnown -> nostrReady. See repository_providers.dart.
final _dmRepoSwap = StateProvider<int>((ref) => 0);

/// Flip this to force `profileRepositoryProvider` to resolve from null to a
/// ready instance, the nullable-gated shape it has in production.
final _profileRepoSwap = StateProvider<int>((ref) => 0);

class _MockProfileRepository extends Mock implements ProfileRepository {}

void main() {
  const testPubkey =
      'aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd';

  group(InboxPage, () {
    late _MockDmRepository mockDmRepository;
    late _MockAuthService mockAuthService;
    late _MockFollowRepository mockFollowRepository;
    late _MockContentBlocklistRepository mockBlocklistRepository;
    late MockGoRouter mockGoRouter;
    late _MockInviteStatusCubit mockInviteCubit;
    late _MockDmUnreadCountCubit mockDmUnreadCountCubit;

    setUp(() {
      mockDmRepository = _MockDmRepository();
      mockAuthService = _MockAuthService();
      mockFollowRepository = _MockFollowRepository();
      mockBlocklistRepository = _MockContentBlocklistRepository();
      mockGoRouter = MockGoRouter();
      mockInviteCubit = _MockInviteStatusCubit();
      mockDmUnreadCountCubit = _MockDmUnreadCountCubit();
      when(() => mockInviteCubit.state).thenReturn(const InviteStatusState());
      when(mockInviteCubit.load).thenAnswer((_) async {});
      when(() => mockDmUnreadCountCubit.state).thenReturn(0);

      when(
        () => mockDmRepository.watchAcceptedConversations(
          limit: any(named: 'limit'),
        ),
      ).thenAnswer((_) => Stream.value(const []));
      when(
        () => mockDmRepository.watchPotentialRequests(),
      ).thenAnswer((_) => Stream.value(const []));
      when(() => mockDmRepository.userPubkey).thenReturn(testPubkey);

      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPubkey);
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.authState).thenReturn(AuthState.authenticated);
      when(
        () => mockAuthService.authStateStream,
      ).thenAnswer((_) => const Stream<AuthState>.empty());

      when(() => mockFollowRepository.followingPubkeys).thenReturn(const []);
      when(
        () => mockFollowRepository.followingStream,
      ).thenAnswer((_) => const Stream.empty());

      when(() => mockBlocklistRepository.isBlocked(any())).thenReturn(false);

      when(() => mockDmRepository.startListening()).thenAnswer((_) async {});
      when(() => mockDmRepository.stopListening()).thenAnswer((_) async {});
      when(
        () => mockDmRepository.backfillHistoryIfNeeded(),
      ).thenAnswer((_) async {});
    });

    test('has correct route constants', () {
      expect(InboxPage.routeName, equals('inbox'));
      expect(InboxPage.path, equals('/inbox'));
    });

    group('dm subscription lifecycle', () {
      testWidgets(
        'does not start or stop the subscription — auth-scoped (#2931)',
        (tester) async {
          await tester.pumpWidget(
            testMaterialApp(
              home: MultiBlocProvider(
                providers: [
                  // App-shell-scoped in production (#4976); provided here so the
                  // inbox toggle can read it after InboxPage stopped self-scoping.
                  BlocProvider<DmUnreadCountCubit>.value(
                    value: mockDmUnreadCountCubit,
                  ),
                  BlocProvider<InviteStatusCubit>.value(value: mockInviteCubit),
                ],
                child: const InboxPage(),
              ),
              mockAuthService: mockAuthService,
              mockFollowRepository: mockFollowRepository,
              additionalOverrides: [
                dmRepositoryProvider.overrideWithValue(mockDmRepository),
                contentBlocklistRepositoryProvider.overrideWithValue(
                  mockBlocklistRepository,
                ),
                goRouterProvider.overrideWithValue(mockGoRouter),
              ],
            ),
          );
          await tester.pump();

          // Regression guard for #2931: the gift-wrap subscription is owned
          // by `dmRepositoryProvider` for the entire authenticated session,
          // not by this screen. Mounting and unmounting the inbox must NOT
          // touch the subscription lifecycle, otherwise users who never
          // open the inbox would never receive DMs.
          verifyNever(() => mockDmRepository.startListening());
          verifyNever(() => mockDmRepository.stopListening());

          await tester.pumpWidget(const SizedBox.shrink());
          await tester.pump();

          verifyNever(() => mockDmRepository.startListening());
          verifyNever(() => mockDmRepository.stopListening());
        },
      );
    });

    group('renders', () {
      testWidgets('renders $InboxView', (tester) async {
        await tester.pumpWidget(
          testMaterialApp(
            home: MultiBlocProvider(
              providers: [
                // App-shell-scoped in production (#4976); provided here so the
                // inbox toggle can read it after InboxPage stopped self-scoping.
                BlocProvider<DmUnreadCountCubit>.value(
                  value: mockDmUnreadCountCubit,
                ),
                BlocProvider<InviteStatusCubit>.value(value: mockInviteCubit),
              ],
              child: const InboxPage(),
            ),
            mockAuthService: mockAuthService,
            mockFollowRepository: mockFollowRepository,
            additionalOverrides: [
              dmRepositoryProvider.overrideWithValue(mockDmRepository),
              contentBlocklistRepositoryProvider.overrideWithValue(
                mockBlocklistRepository,
              ),
              goRouterProvider.overrideWithValue(mockGoRouter),
            ],
          ),
        );
        await tester.pump();

        expect(find.byType(InboxView), findsOneWidget);
      });
    });

    // The keepAlive `dmRepositoryProvider` rebuilds a brand-new DmRepository
    // on the identityKnown -> nostrReady transition. The first instance can
    // read owner-scoped local history, but only the ready instance receives
    // credentials, post-auth maintenance, and newly ingested DMs. A keyless
    // BlocProvider strands the bloc on the superseded instance. These pin the
    // ValueKey rebind fix in inbox_page.dart. See
    // .claude/rules/state_management.md.
    group('rebinds ConversationListBloc when dmRepositoryProvider flips', () {
      void stubInbox(_MockDmRepository repo, {required String userPubkey}) {
        when(
          () => repo.watchAcceptedConversations(limit: any(named: 'limit')),
        ).thenAnswer((_) => Stream.value(const []));
        when(
          () => repo.watchPotentialRequests(),
        ).thenAnswer((_) => Stream.value(const []));
        when(() => repo.userPubkey).thenReturn(userPubkey);
        when(
          () => repo.userPubkeyStream,
        ).thenAnswer((_) => Stream.value(userPubkey));
        when(
          () => repo.historyRecoveryStream,
        ).thenAnswer((_) => const Stream<bool>.empty());
        when(() => repo.isRecoveringHistory).thenReturn(false);
        when(
          () => repo.hasCompletedHistoryRecoveryBefore,
        ).thenReturn(true);
        when(() => repo.backfillHistoryIfNeeded()).thenAnswer((_) async {});
        when(() => repo.retryPendingDecryptions()).thenAnswer((_) async {});
        when(() => repo.startListening()).thenAnswer((_) async {});
        when(() => repo.stopListening()).thenAnswer((_) async {});
      }

      Widget buildApp(
        DmRepository readyRepo, {
        ProfileRepository? readyProfileRepo,
      }) {
        return testMaterialApp(
          home: MultiBlocProvider(
            providers: [
              BlocProvider<DmUnreadCountCubit>.value(
                value: mockDmUnreadCountCubit,
              ),
              BlocProvider<InviteStatusCubit>.value(value: mockInviteCubit),
            ],
            child: const InboxPage(),
          ),
          mockAuthService: mockAuthService,
          mockFollowRepository: mockFollowRepository,
          additionalOverrides: [
            dmRepositoryProvider.overrideWith(
              (ref) =>
                  ref.watch(_dmRepoSwap) == 0 ? mockDmRepository : readyRepo,
            ),
            contentBlocklistRepositoryProvider.overrideWithValue(
              mockBlocklistRepository,
            ),
            // Nullable-gated in production: null until Nostr is ready.
            profileRepositoryProvider.overrideWith(
              (ref) =>
                  ref.watch(_profileRepoSwap) == 0 ? null : readyProfileRepo,
            ),
            profileReadRepositoryProvider.overrideWith(
              (ref) =>
                  ref.watch(_profileRepoSwap) == 0 ? null : readyProfileRepo,
            ),
            goRouterProvider.overrideWithValue(mockGoRouter),
          ],
        );
      }

      ConversationListBloc readBloc(WidgetTester tester) =>
          BlocProvider.of<ConversationListBloc>(
            tester.element(find.byType(InboxView)),
          );

      void flipToReady(WidgetTester tester) {
        ProviderScope.containerOf(
          tester.element(find.byType(InboxPage)),
          listen: false,
        ).read(_dmRepoSwap.notifier).state = 1;
      }

      testWidgets(
        'recreates the bloc bound to the ready repo when the provider hands '
        'over a fresh instance',
        (tester) async {
          final readyRepo = _MockDmRepository();
          // Model the signed-out/teardown instance (empty pubkey).
          stubInbox(mockDmRepository, userPubkey: '');
          stubInbox(readyRepo, userPubkey: testPubkey);

          await tester.pumpWidget(buildApp(readyRepo));
          await tester.pump();

          final blocA = readBloc(tester);
          expect(
            blocA.state.status,
            isNot(ConversationListStatus.loaded),
            reason:
                'bound to the not-ready repo (empty pubkey), so onData holds '
                'the loading spinner — the reported stuck inbox',
          );

          // Session advances identityKnown -> nostrReady: the provider hands
          // over a fresh, ready DmRepository.
          flipToReady(tester);
          await tester.pump();

          expect(
            readBloc(tester),
            isNot(same(blocA)),
            reason:
                'a keyless BlocProvider leaves the bloc wired to the orphaned '
                'not-ready DmRepository so the inbox never loads; the ValueKey '
                'must rebuild it bound to the ready instance',
          );
        },
      );

      testWidgets(
        'keeps the same bloc when the repository identity does not change',
        (tester) async {
          stubInbox(mockDmRepository, userPubkey: testPubkey);

          // Both swap states resolve to the same instance.
          await tester.pumpWidget(buildApp(mockDmRepository));
          await tester.pump();

          final blocA = readBloc(tester);

          flipToReady(tester);
          await tester.pump();

          // The premise: the flip rebuilt the provider and it handed out the
          // same repository, so this is an unrelated rebuild (#8617).
          expect(
            ProviderScope.containerOf(
              tester.element(find.byType(InboxPage)),
              listen: false,
            ).read(dmRepositoryProvider),
            same(mockDmRepository),
          );
          expect(
            readBloc(tester),
            same(blocA),
            reason:
                'an identical repo identity yields an equal record key, so the '
                'bloc must not churn on unrelated provider rebuilds',
          );
        },
      );

      // `profileRepositoryProvider` is nullable-gated on Nostr readiness, so it
      // resolves null -> instance after mount. Keying the ConversationListBloc
      // provider on it would be the OUTERMOST entry of the nested provider
      // chain, so it would re-inflate every provider below it and the whole
      // InboxView subtree. The instance is delivered as an event instead.
      testWidgets(
        'a profileRepository flip refreshes only the conversation bloc '
        'dependency, tearing down nothing',
        (tester) async {
          stubInbox(mockDmRepository, userPubkey: testPubkey);
          final readyProfileRepo = _MockProfileRepository();
          // The bloc subscribes to the vanished set on every repository swap,
          // so the incoming instance has to answer for it.
          when(
            readyProfileRepo.watchVanishedPubkeys,
          ).thenAnswer((_) => Stream.value(const <String>{}));

          await tester.pumpWidget(
            buildApp(mockDmRepository, readyProfileRepo: readyProfileRepo),
          );
          await tester.pump();

          final conversationBloc = readBloc(tester);
          final followingBloc = BlocProvider.of<MyFollowingBloc>(
            tester.element(find.byType(InboxView)),
          );
          final muteCubit = BlocProvider.of<ConversationMuteCubit>(
            tester.element(find.byType(InboxView)),
          );
          final viewState = tester.state(find.byType(InboxView));

          // The provider hands over the ready ProfileRepository.
          ProviderScope.containerOf(
            tester.element(find.byType(InboxPage)),
            listen: false,
          ).read(_profileRepoSwap.notifier).state = 1;
          await tester.pump();

          // Pin the ref.listen handoff: unchanged widget identities alone
          // would also pass if the profile-repository flip were never handled.
          verify(readyProfileRepo.watchVanishedPubkeys).called(1);
          expect(
            readBloc(tester),
            same(conversationBloc),
            reason: 'the bloc is re-pointed in place, not reconstructed',
          );
          expect(
            BlocProvider.of<MyFollowingBloc>(
              tester.element(find.byType(InboxView)),
            ),
            same(followingBloc),
            reason: 'an unrelated bloc must survive the flip',
          );
          expect(
            BlocProvider.of<ConversationMuteCubit>(
              tester.element(find.byType(InboxView)),
            ),
            same(muteCubit),
            reason: 'an unrelated cubit must survive the flip',
          );
          expect(
            tester.state(find.byType(InboxView)),
            same(viewState),
            reason:
                'remounting InboxView would discard the selected tab, scroll '
                'offset and search text',
          );
          expect(conversationBloc.isClosed, isFalse);
        },
      );
    });
  });
}
