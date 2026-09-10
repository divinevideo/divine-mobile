// ABOUTME: Widget tests for MessageRequestsView.
// ABOUTME: Verifies list rendering (loading, empty, with requests), navigation
// ABOUTME: to request preview, and app bar title.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation_list/conversation_list_bloc.dart';
import 'package:openvine/blocs/dm/message_requests/message_request_actions_cubit.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/inbox/message_requests/message_requests_view.dart';
import 'package:openvine/screens/inbox/message_requests/request_preview_page.dart';
import 'package:openvine/screens/inbox/message_requests/widgets/request_tile.dart';
import 'package:openvine/screens/inbox/widgets/restore_paused_banner.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;

import '../../../helpers/go_router.dart';
import '../../../helpers/test_provider_overrides.dart';

class _MockConversationListBloc
    extends MockBloc<ConversationListEvent, ConversationListState>
    implements ConversationListBloc {}

class _MockMessageRequestActionsCubit
    extends MockCubit<MessageRequestActionsState>
    implements MessageRequestActionsCubit {}

class _MockAuthService extends MockAuthService {
  _MockAuthService(this._pubkey) {
    when(() => authState).thenReturn(AuthState.authenticated);
    when(
      () => authStateStream,
    ).thenAnswer((_) => const Stream<AuthState>.empty());
  }
  final String _pubkey;

  @override
  String? get currentPublicKeyHex => _pubkey;
}

void main() {
  const currentPubkey =
      'aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd';
  const otherPubkey =
      '1122334411223344112233441122334411223344112233441122334411223344';

  final now = DateTime.now();
  final nowUnix = now.millisecondsSinceEpoch ~/ 1000;

  group(MessageRequestsView, () {
    late _MockConversationListBloc mockBloc;
    late _MockMessageRequestActionsCubit mockActionsCubit;
    late _MockAuthService mockAuthService;
    late MockGoRouter mockGoRouter;

    setUpAll(() {
      registerFallbackValue(<DmConversation>[]);
    });

    setUp(() {
      mockBloc = _MockConversationListBloc();
      mockActionsCubit = _MockMessageRequestActionsCubit();
      mockAuthService = _MockAuthService(currentPubkey);
      mockGoRouter = MockGoRouter();

      when(
        () => mockActionsCubit.state,
      ).thenReturn(const MessageRequestActionsState());
    });

    Widget buildSubject({ConversationListState? state}) {
      final blocState = state ?? const ConversationListState();
      whenListen(
        mockBloc,
        Stream<ConversationListState>.value(blocState),
        initialState: blocState,
      );

      return testMaterialApp(
        mockAuthService: mockAuthService,
        additionalOverrides: [goRouterProvider.overrideWithValue(mockGoRouter)],
        home: MockGoRouterProvider(
          goRouter: mockGoRouter,
          child: MultiBlocProvider(
            providers: [
              BlocProvider<ConversationListBloc>.value(value: mockBloc),
              BlocProvider<MessageRequestActionsCubit>.value(
                value: mockActionsCubit,
              ),
            ],
            child: const MessageRequestsView(),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders app bar with "Message requests" title', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.text('Message requests'), findsOneWidget);
      });

      testWidgets('renders $CircularProgressIndicator when status is initial', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('renders "No message requests" when loaded with empty list', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            state: const ConversationListState(
              status: ConversationListStatus.loaded,
            ),
          ),
        );
        await tester.pump();

        expect(find.text('No message requests'), findsOneWidget);
      });

      testWidgets(
        'renders restore progress when requests are withheld during recovery',
        (tester) async {
          await tester.pumpWidget(
            buildSubject(
              state: const ConversationListState(
                status: ConversationListStatus.loaded,
                isRestoringHistory: true,
                requestsWithheld: true,
              ),
            ),
          );
          await tester.pump();

          expect(find.byType(CircularProgressIndicator), findsOneWidget);
          expect(find.text('No message requests'), findsNothing);
        },
      );

      testWidgets(
        'renders restore-paused banner when requests are withheld after recovery stops',
        (tester) async {
          await tester.pumpWidget(
            buildSubject(
              state: const ConversationListState(
                status: ConversationListStatus.loaded,
                requestsWithheld: true,
              ),
            ),
          );
          await tester.pump();

          expect(find.byType(RestorePausedBanner), findsOneWidget);
          expect(find.text('No message requests'), findsNothing);
        },
      );

      testWidgets('restore-paused Retry dispatches the retry event', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            state: const ConversationListState(
              status: ConversationListStatus.loaded,
              requestsWithheld: true,
            ),
          ),
        );
        await tester.pump();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.inboxRestoreRetryAction));
        await tester.pumpAndSettle();

        verify(
          () => mockBloc.add(const ConversationListRestoreRetryRequested()),
        ).called(1);
      });

      testWidgets('renders $RequestTile when loaded with requests', (
        tester,
      ) async {
        final testProfile = UserProfile(
          pubkey: otherPubkey,
          displayName: 'RequestUser',
          rawData: const {},
          createdAt: now,
          eventId: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        );

        final request = DmConversation(
          id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
          participantPubkeys: const [currentPubkey, otherPubkey],
          isGroup: false,
          createdAt: nowUnix,
          lastMessageContent: 'Hey',
          lastMessageTimestamp: nowUnix,
        );

        final state = ConversationListState(
          status: ConversationListStatus.loaded,
          requestConversations: [request],
        );

        whenListen(
          mockBloc,
          Stream<ConversationListState>.value(state),
          initialState: state,
        );

        await tester.pumpWidget(
          testMaterialApp(
            mockAuthService: mockAuthService,
            additionalOverrides: [
              goRouterProvider.overrideWithValue(mockGoRouter),
              userProfileReactiveProvider(
                otherPubkey,
              ).overrideWith((ref) => Stream.value(testProfile)),
            ],
            home: MockGoRouterProvider(
              goRouter: mockGoRouter,
              child: MultiBlocProvider(
                providers: [
                  BlocProvider<ConversationListBloc>.value(value: mockBloc),
                  BlocProvider<MessageRequestActionsCubit>.value(
                    value: mockActionsCubit,
                  ),
                ],
                child: const MessageRequestsView(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        expect(find.byType(RequestTile), findsOneWidget);
      });
    });

    // #8347. "Remove all requests" is the routine spam-clearing gesture, and
    // since #8302 the cubit withholds a Divine moderation notice from it.
    // Saying nothing makes that guard read as a broken button: with only a
    // notice in the list the sweep removes nothing and reports nothing.
    group('bulk removal', () {
      final l10n = lookupAppLocalizations(const Locale('en'));

      final moderationRequest = DmConversation(
        id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
        participantPubkeys: [currentPubkey, kLegacyModerationPubkeys.first],
        isGroup: false,
        createdAt: nowUnix,
        lastMessageTimestamp: nowUnix,
      );

      // A real GoRouter, not the MockGoRouter the rest of this file uses. The
      // bulk sheet dismisses through go_router's `context.pop(result)`, and a
      // mock no-ops it — so `VineBottomSheet.show` never completes its future
      // and the sweep below is simply unreachable, with no error and no missed
      // tap to explain why. A real router pops the modal route with its result,
      // which is what the app does. `/requests` is nested under `/` so the pop
      // after the sweep has somewhere to land.
      Widget buildRoutedSubject() {
        final loaded = ConversationListState(
          status: ConversationListStatus.loaded,
          requestConversations: [moderationRequest],
        );
        whenListen(
          mockBloc,
          Stream<ConversationListState>.value(loaded),
          initialState: loaded,
        );

        final router = GoRouter(
          initialLocation: '/requests',
          routes: [
            GoRoute(
              path: '/',
              builder: (_, _) => const Scaffold(),
              routes: [
                GoRoute(
                  path: 'requests',
                  builder: (_, _) => MultiBlocProvider(
                    providers: [
                      BlocProvider<ConversationListBloc>.value(value: mockBloc),
                      BlocProvider<MessageRequestActionsCubit>.value(
                        value: mockActionsCubit,
                      ),
                    ],
                    child: const MessageRequestsView(),
                  ),
                ),
              ],
            ),
          ],
        );
        addTearDown(router.dispose);

        return testProviderScope(
          mockAuthService: mockAuthService,
          additionalOverrides: [goRouterProvider.overrideWithValue(router)],
          child: MaterialApp.router(
            routerConfig: router,
            localizationsDelegates: appLocalizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: ThemeData.dark(),
          ),
        );
      }

      Future<void> sweep(WidgetTester tester) async {
        await tester.pumpWidget(buildRoutedSubject());
        await tester.pumpAndSettle();

        await tester.tap(
          find.bySemanticsLabel(l10n.profileMoreSemanticLabel),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.inboxRequestsRemoveAll));
        await tester.pumpAndSettle();
      }

      testWidgets('explains the notice the sweep kept', (tester) async {
        when(
          () => mockActionsCubit.removeAllRequests(any()),
        ).thenAnswer((_) async => (withheld: true, failed: false));

        await sweep(tester);

        expect(
          find.text(l10n.messageRequestModerationNoticeCannotBeRemoved),
          findsOneWidget,
        );
      });

      testWidgets('stays quiet when the sweep kept nothing', (tester) async {
        when(
          () => mockActionsCubit.removeAllRequests(any()),
        ).thenAnswer((_) async => (withheld: false, failed: false));

        await sweep(tester);

        // Without this the assertion above would also pass if the sweep were
        // never reached at all — which is exactly how this test behaves under
        // a MockGoRouter, whose no-op pop leaves the sheet future hanging.
        verify(() => mockActionsCubit.removeAllRequests(any())).called(1);
        expect(
          find.text(l10n.messageRequestModerationNoticeCannotBeRemoved),
          findsNothing,
        );
      });

      // The removal is transactional, so a failed sweep left the spam in place
      // too. Naming the notice there would blame the guard for the whole
      // no-op, which is why the cubit reports the two separately.
      testWidgets('reports a failed sweep instead of blaming the notice', (
        tester,
      ) async {
        when(
          () => mockActionsCubit.removeAllRequests(any()),
        ).thenAnswer((_) async => (withheld: true, failed: true));

        await sweep(tester);

        expect(find.text(l10n.commonSomethingWentWrong), findsOneWidget);
        expect(
          find.text(l10n.messageRequestModerationNoticeCannotBeRemoved),
          findsNothing,
        );
      });
    });

    group('navigation', () {
      testWidgets('calls pushNamed to request preview when request is tapped', (
        tester,
      ) async {
        final testProfile = UserProfile(
          pubkey: otherPubkey,
          displayName: 'RequestUser',
          rawData: const {},
          createdAt: now,
          eventId: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
        );

        final request = DmConversation(
          id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
          participantPubkeys: const [currentPubkey, otherPubkey],
          isGroup: false,
          createdAt: nowUnix,
          lastMessageContent: 'Hey',
          lastMessageTimestamp: nowUnix,
        );

        whenListen(
          mockBloc,
          Stream<ConversationListState>.value(
            ConversationListState(
              status: ConversationListStatus.loaded,
              requestConversations: [request],
            ),
          ),
          initialState: ConversationListState(
            status: ConversationListStatus.loaded,
            requestConversations: [request],
          ),
        );

        when(
          () => mockGoRouter.pushNamed(
            any(),
            pathParameters: any(named: 'pathParameters'),
            extra: any(named: 'extra'),
          ),
        ).thenAnswer((_) async => null);

        await tester.pumpWidget(
          testMaterialApp(
            mockAuthService: mockAuthService,
            additionalOverrides: [
              goRouterProvider.overrideWithValue(mockGoRouter),
              userProfileReactiveProvider(
                otherPubkey,
              ).overrideWith((ref) => Stream.value(testProfile)),
            ],
            home: MockGoRouterProvider(
              goRouter: mockGoRouter,
              child: MultiBlocProvider(
                providers: [
                  BlocProvider<ConversationListBloc>.value(value: mockBloc),
                  BlocProvider<MessageRequestActionsCubit>.value(
                    value: mockActionsCubit,
                  ),
                ],
                child: const MessageRequestsView(),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.byType(RequestTile));
        await tester.pump();

        verify(
          () => mockGoRouter.pushNamed(
            RequestPreviewPage.routeName,
            pathParameters: {
              'id': 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
            },
            extra: [otherPubkey],
          ),
        ).called(1);
      });
    });
  });
}
