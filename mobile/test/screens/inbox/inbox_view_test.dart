// ABOUTME: Widget tests for InboxView.
// ABOUTME: Verifies segmented toggle, message list states (loading, error,
// ABOUTME: empty, loaded), and tab switching between messages and notifications.

import 'dart:async';
import 'dart:math' as math;

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation_actions/conversation_actions_cubit.dart';
import 'package:openvine/blocs/dm/conversation_list/conversation_list_bloc.dart';
import 'package:openvine/blocs/dm/conversation_mute/conversation_mute_cubit.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';
import 'package:openvine/blocs/invite_status/invite_status_cubit.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/blocs/notifications/badge/notification_badge_cubit.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/inbox/conversation/conversation_page.dart';
import 'package:openvine/screens/inbox/inbox_view.dart';
import 'package:openvine/screens/inbox/message_requests/message_requests_page.dart';
import 'package:openvine/screens/inbox/message_requests/widgets/message_requests_banner.dart';
import 'package:openvine/screens/inbox/widgets/conversation_tile.dart';
import 'package:openvine/screens/inbox/widgets/following_bar.dart';
import 'package:openvine/screens/inbox/widgets/inbox_empty_state.dart';
import 'package:openvine/screens/inbox/widgets/inbox_error_state.dart';
import 'package:openvine/screens/inbox/widgets/inbox_fab.dart';
import 'package:openvine/screens/inbox/widgets/inbox_filter_chips.dart';
import 'package:openvine/screens/inbox/widgets/inbox_segmented_toggle.dart';
import 'package:openvine/screens/inbox/widgets/restore_paused_banner.dart';
import 'package:openvine/services/auth_service.dart' hide UserProfile;
import 'package:riverpod/misc.dart' show Override;

import '../../helpers/go_router.dart';
import '../../helpers/test_provider_overrides.dart';

class _MockConversationListBloc
    extends MockBloc<ConversationListEvent, ConversationListState>
    implements ConversationListBloc {}

class _MockMyFollowingBloc extends MockBloc<MyFollowingEvent, MyFollowingState>
    implements MyFollowingBloc {}

class _MockConversationMuteCubit extends MockCubit<ConversationMuteState>
    implements ConversationMuteCubit {}

class _MockConversationActionsCubit extends MockCubit<ConversationActionsState>
    implements ConversationActionsCubit {}

class _MockInviteStatusCubit extends MockCubit<InviteStatusState>
    implements InviteStatusCubit {}

class _MockDmUnreadCountCubit extends MockCubit<int>
    implements DmUnreadCountCubit {}

class _MockNotificationBadgeCubit extends MockCubit<int>
    implements NotificationBadgeCubit {}

class _MockAuthService extends MockAuthService {
  _MockAuthService(this.pubkey) {
    when(() => authState).thenReturn(AuthState.authenticated);
    when(() => isAuthenticated).thenReturn(true);
    when(
      () => authStateStream,
    ).thenAnswer((_) => const Stream<AuthState>.empty());
  }

  /// Mutable so a test can simulate an account switch mid-flight.
  String pubkey;

  @override
  String? get currentPublicKeyHex => pubkey;
}

void main() {
  setUpAll(
    () => registerFallbackValue(
      DmConversation(
        id: 'fallback',
        participantPubkeys: const [],
        isGroup: false,
        createdAt: 0,
      ),
    ),
  );

  const currentPubkey =
      'aabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccddaabbccdd';
  const otherPubkey =
      '1122334411223344112233441122334411223344112233441122334411223344';

  final now = DateTime.now();
  final nowUnix = now.millisecondsSinceEpoch ~/ 1000;

  group(InboxView, () {
    late _MockConversationListBloc mockBloc;
    late _MockMyFollowingBloc mockFollowingBloc;
    late _MockAuthService mockAuthService;
    late MockGoRouter mockGoRouter;

    setUp(() {
      mockBloc = _MockConversationListBloc();
      mockFollowingBloc = _MockMyFollowingBloc();
      mockAuthService = _MockAuthService(currentPubkey);
      mockGoRouter = MockGoRouter();

      whenListen(
        mockFollowingBloc,
        const Stream<MyFollowingState>.empty(),
        initialState: const MyFollowingState(),
      );
    });

    Widget buildSubject({
      ConversationListState? state,
      int dmUnreadCount = 0,
      int notificationUnreadCount = 0,
      Stream<int>? notificationStream,
      TextScaler? textScaler,
      ConversationActionsCubit? actionsCubit,
      List<Override> additionalOverrides = const [],
      // InboxView has no Scaffold of its own, and a ScaffoldMessenger with
      // no registered Scaffold silently queues SnackBars instead of showing
      // them. Opt in when the test asserts on one.
      bool wrapInScaffold = false,
    }) {
      if (state != null) {
        whenListen(
          mockBloc,
          Stream<ConversationListState>.value(state),
          initialState: state,
        );
      } else {
        whenListen(
          mockBloc,
          const Stream<ConversationListState>.empty(),
          initialState: const ConversationListState(),
        );
      }

      final mockInviteCubit = _MockInviteStatusCubit();
      when(() => mockInviteCubit.state).thenReturn(const InviteStatusState());
      when(mockInviteCubit.load).thenAnswer((_) async {});

      final mockDmUnreadCubit = _MockDmUnreadCountCubit();
      when(() => mockDmUnreadCubit.state).thenReturn(dmUnreadCount);
      whenListen(
        mockDmUnreadCubit,
        const Stream<int>.empty(),
        initialState: dmUnreadCount,
      );

      final mockNotifBadgeCubit = _MockNotificationBadgeCubit();
      when(() => mockNotifBadgeCubit.state).thenReturn(notificationUnreadCount);
      whenListen(
        mockNotifBadgeCubit,
        notificationStream ?? const Stream<int>.empty(),
        initialState: notificationUnreadCount,
      );

      final mockMuteCubit = _MockConversationMuteCubit();
      when(() => mockMuteCubit.state).thenReturn(const ConversationMuteState());
      whenListen(
        mockMuteCubit,
        const Stream<ConversationMuteState>.empty(),
        initialState: const ConversationMuteState(),
      );

      final mockActionsCubit = actionsCubit ?? _MockConversationActionsCubit();
      when(
        () => mockActionsCubit.state,
      ).thenReturn(const ConversationActionsState());
      when(() => mockActionsCubit.isBlocked(any())).thenReturn(false);
      when(
        () => mockActionsCubit.isRemovalProtected(any()),
      ).thenReturn(false);
      whenListen(
        mockActionsCubit,
        const Stream<ConversationActionsState>.empty(),
        initialState: const ConversationActionsState(),
      );

      final baseInbox = textScaler == null
          ? const InboxView()
          : MediaQuery(
              data: MediaQueryData(textScaler: textScaler),
              child: const InboxView(),
            );
      final inbox = wrapInScaffold ? Scaffold(body: baseInbox) : baseInbox;

      return testMaterialApp(
        mockAuthService: mockAuthService,
        additionalOverrides: [
          notificationRepositoryProvider.overrideWithValue(null),
          goRouterProvider.overrideWithValue(mockGoRouter),
          ...additionalOverrides,
        ],
        home: MockGoRouterProvider(
          goRouter: mockGoRouter,
          child: MultiBlocProvider(
            providers: [
              BlocProvider<ConversationListBloc>.value(value: mockBloc),
              BlocProvider<MyFollowingBloc>.value(value: mockFollowingBloc),
              BlocProvider<InviteStatusCubit>.value(value: mockInviteCubit),
              BlocProvider<DmUnreadCountCubit>.value(value: mockDmUnreadCubit),
              BlocProvider<NotificationBadgeCubit>.value(
                value: mockNotifBadgeCubit,
              ),
              BlocProvider<ConversationMuteCubit>.value(value: mockMuteCubit),
              BlocProvider<ConversationActionsCubit>.value(
                value: mockActionsCubit,
              ),
            ],
            child: inbox,
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('renders $InboxSegmentedToggle', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        expect(find.byType(InboxSegmentedToggle), findsOneWidget);
      });

      testWidgets('forwards DmUnreadCountCubit state to '
          '$InboxSegmentedToggle.messageCount', (tester) async {
        await tester.pumpWidget(buildSubject(dmUnreadCount: 5));
        await tester.pump();

        final toggle = tester.widget<InboxSegmentedToggle>(
          find.byType(InboxSegmentedToggle),
        );
        expect(toggle.messageCount, equals(5));
      });

      testWidgets('forwards NotificationBadgeCubit state to '
          '$InboxSegmentedToggle.notificationCount', (tester) async {
        await tester.pumpWidget(buildSubject(notificationUnreadCount: 7));
        await tester.pump();

        final toggle = tester.widget<InboxSegmentedToggle>(
          find.byType(InboxSegmentedToggle),
        );
        expect(toggle.notificationCount, equals(7));
      });

      testWidgets('renders $FollowingBar in messages tab', (tester) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        // Switch to Messages tab (default is Notifications).
        await tester.tap(find.text('Messages'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // skipOffstage: false because the bar now lives in a sliver and this
        // subject follows nobody, so it collapses to SizedBox.shrink() — a
        // zero-extent sliver, which the default finder treats as offstage.
        expect(find.byType(FollowingBar, skipOffstage: false), findsOneWidget);
      });

      testWidgets('renders $CircularProgressIndicator when status is initial', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());
        await tester.pump();

        // Switch to Messages tab (default is Notifications).
        await tester.tap(find.text('Messages'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        // Both tabs stay alive in the TabBarView, so scope to the Messages
        // subtree (the Notifications tab shows its own spinner with a null
        // notification repository).
        expect(
          find.descendant(
            of: find.byKey(const ValueKey('messages-$currentPubkey')),
            matching: find.byType(CircularProgressIndicator),
          ),
          findsOneWidget,
        );
      });

      testWidgets('renders $InboxErrorState when status is error', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            state: const ConversationListState(
              status: ConversationListStatus.error,
            ),
          ),
        );
        await tester.pump();

        // Switch to Messages tab (default is Notifications).
        await tester.tap(find.text('Messages'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.byType(InboxErrorState), findsOneWidget);
        expect(find.byType(InboxEmptyState), findsNothing);
      });

      testWidgets('retry on $InboxErrorState re-dispatches load', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildSubject(
            state: const ConversationListState(
              status: ConversationListStatus.error,
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Messages'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.commonRetry));
        await tester.pump();

        verify(() => mockBloc.add(const ConversationListStarted())).called(1);
      });

      testWidgets(
        'renders $InboxEmptyState when loaded with no conversations',
        (tester) async {
          await tester.pumpWidget(
            buildSubject(
              state: const ConversationListState(
                status: ConversationListStatus.loaded,
              ),
            ),
          );
          await tester.pump();

          // Switch to Messages tab (default is Notifications).
          await tester.tap(find.text('Messages'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          expect(find.byType(InboxEmptyState), findsOneWidget);
        },
      );

      testWidgets('renders $ConversationTile when loaded with conversations', (
        tester,
      ) async {
        final conversation = DmConversation(
          id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
          participantPubkeys: const [currentPubkey, otherPubkey],
          isGroup: false,
          createdAt: nowUnix,
          lastMessageContent: 'Hello',
          lastMessageTimestamp: nowUnix,
        );

        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: [conversation],
              visibleConversations: [conversation],
              hasMore: false,
            ),
          ),
        );
        await tester.pump();

        // Switch to Messages tab (default is Notifications).
        await tester.tap(find.text('Messages'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.byType(ConversationTile), findsOneWidget);
      });

      // #7025. Holding a block keeps the chip row alive past the empty-inbox
      // early return, so the unfiltered empty state has to stay honest — "All"
      // with no query must not claim "You're all caught up", which asserts a
      // filter did the emptying.
      testWidgets('an all-blocked inbox still shows the empty state', (
        tester,
      ) async {
        final blocked = DmConversation(
          id: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
          participantPubkeys: const [currentPubkey, otherPubkey],
          isGroup: false,
          createdAt: nowUnix,
        );

        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              blockedConversations: [blocked],
              hasMore: false,
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('Messages'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.byType(InboxEmptyState), findsOneWidget);
        expect(find.text(l10n.inboxUnreadEmptyTitle), findsNothing);
      });

      // #7025. Only the Blocked slice synthesises message-less rows. A real
      // conversation whose first message has not landed yet must stay
      // tappable, or the inert treatment leaks into the ordinary inbox.
      testWidgets('a message-less conversation stays tappable under All', (
        tester,
      ) async {
        final conversation = DmConversation(
          id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
          participantPubkeys: const [currentPubkey, otherPubkey],
          isGroup: false,
          createdAt: nowUnix,
        );

        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: [conversation],
              visibleConversations: [conversation],
              hasMore: false,
            ),
          ),
        );
        await tester.pump();
        await tester.tap(find.text('Messages'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        final tile = tester.widget<ConversationTile>(
          find.byType(ConversationTile),
        );
        expect(tile.onTap, isNotNull);
        expect(tile.subtitleOverride, isNull);
      });

      testWidgets('renders $InboxFilterChips when loaded with conversations', (
        tester,
      ) async {
        final conversation = DmConversation(
          id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
          participantPubkeys: const [currentPubkey, otherPubkey],
          isGroup: false,
          createdAt: nowUnix,
          lastMessageContent: 'Hello',
          lastMessageTimestamp: nowUnix,
        );

        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: [conversation],
              visibleConversations: [conversation],
              hasMore: false,
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Messages'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.byType(InboxFilterChips), findsOneWidget);
      });

      testWidgets('tapping the Unread chip dispatches '
          '$ConversationListFilterChanged', (tester) async {
        final conversation = DmConversation(
          id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
          participantPubkeys: const [currentPubkey, otherPubkey],
          isGroup: false,
          createdAt: nowUnix,
          lastMessageContent: 'Hello',
          lastMessageTimestamp: nowUnix,
        );

        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: [conversation],
              visibleConversations: [conversation],
              hasMore: false,
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Messages'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.inboxFilterUnread));
        await tester.pump();

        verify(
          () => mockBloc.add(
            const ConversationListFilterChanged(InboxFilter.unread),
          ),
        ).called(1);
      });

      testWidgets('tapping the already-active All chip dispatches nothing', (
        tester,
      ) async {
        final conversation = DmConversation(
          id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
          participantPubkeys: const [currentPubkey, otherPubkey],
          isGroup: false,
          createdAt: nowUnix,
          lastMessageContent: 'Hello',
          lastMessageTimestamp: nowUnix,
        );

        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: [conversation],
              visibleConversations: [conversation],
              hasMore: false,
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Messages'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.inboxFilterAll));
        await tester.pump();

        verifyNever(
          () => mockBloc.add(
            const ConversationListFilterChanged(InboxFilter.unread),
          ),
        );
      });

      testWidgets(
        'shows caught-up state when unread filter is on and everything '
        'is read',
        (tester) async {
          final conversation = DmConversation(
            id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
            participantPubkeys: const [currentPubkey, otherPubkey],
            isGroup: false,
            createdAt: nowUnix,
            lastMessageContent: 'Hello',
            lastMessageTimestamp: nowUnix,
          );

          await tester.pumpWidget(
            buildSubject(
              state: ConversationListState(
                status: ConversationListStatus.loaded,
                conversations: [conversation],
                filter: InboxFilter.unread,
                hasMore: false,
              ),
            ),
          );
          await tester.pump();

          await tester.tap(find.text('Messages'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          final l10n = lookupAppLocalizations(const Locale('en'));
          expect(find.text(l10n.inboxUnreadEmptyTitle), findsOneWidget);
          expect(find.byType(ConversationTile), findsNothing);
        },
      );

      testWidgets('typing in the search bar dispatches '
          '$ConversationListSearchQueryChanged', (tester) async {
        final conversation = DmConversation(
          id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
          participantPubkeys: const [currentPubkey, otherPubkey],
          isGroup: false,
          createdAt: nowUnix,
          lastMessageContent: 'Hello',
          lastMessageTimestamp: nowUnix,
        );

        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: [conversation],
              visibleConversations: [conversation],
              hasMore: false,
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Messages'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.byType(DivineSearchBar), findsOneWidget);
        await tester.enterText(
          find.descendant(
            of: find.byType(DivineSearchBar),
            matching: find.byType(TextField),
          ),
          'pizza',
        );
        await tester.pump();

        verify(
          () => mockBloc.add(const ConversationListSearchQueryChanged('pizza')),
        ).called(1);
      });

      testWidgets('shows no-matches state when a search finds nothing', (
        tester,
      ) async {
        final conversation = DmConversation(
          id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
          participantPubkeys: const [currentPubkey, otherPubkey],
          isGroup: false,
          createdAt: nowUnix,
          lastMessageContent: 'Hello',
          lastMessageTimestamp: nowUnix,
        );

        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: [conversation],
              searchQuery: 'zzz',
              hasMore: false,
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Messages'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.inboxSearchEmptyTitle), findsOneWidget);
        expect(find.text(l10n.inboxUnreadEmptyTitle), findsNothing);
        expect(find.byType(ConversationTile), findsNothing);
      });

      testWidgets('renders only visibleConversations, not the full list', (
        tester,
      ) async {
        DmConversation conversationWith({
          required String id,
          required bool isRead,
        }) => DmConversation(
          id: id,
          participantPubkeys: const [currentPubkey, otherPubkey],
          isGroup: false,
          createdAt: nowUnix,
          lastMessageContent: 'Hello',
          lastMessageTimestamp: nowUnix,
          isRead: isRead,
        );

        final unread = conversationWith(id: 'unread-conv', isRead: false);
        final read = conversationWith(id: 'read-conv', isRead: true);

        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: [unread, read],
              visibleConversations: [unread],
              filter: InboxFilter.unread,
              hasMore: false,
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Messages'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        expect(find.byType(ConversationTile), findsOneWidget);
        final tile = tester.widget<ConversationTile>(
          find.byType(ConversationTile),
        );
        expect(tile.conversation.id, equals('unread-conv'));
      });

      testWidgets(
        'suppresses the load-more spinner while a filter narrows the list',
        (tester) async {
          // A full page is loaded (hasMore true) but the unread filter leaves
          // one short row. The trailing load-more spinner must not render — a
          // list too short to scroll can never trigger onLoadMore, so it would
          // spin forever.
          final conversations = List.generate(
            20,
            (index) => DmConversation(
              id: 'conv$index',
              participantPubkeys: const [currentPubkey, otherPubkey],
              isGroup: false,
              createdAt: nowUnix - index,
              lastMessageContent: 'Hello $index',
              lastMessageTimestamp: nowUnix - index,
              isRead: index != 0,
            ),
          );
          final unread = conversations.where((c) => !c.isRead).toList();

          await tester.pumpWidget(
            buildSubject(
              state: ConversationListState(
                status: ConversationListStatus.loaded,
                conversations: conversations,
                visibleConversations: unread,
                filter: InboxFilter.unread,
                // hasMore defaults to true.
              ),
            ),
          );
          await tester.pump();

          await tester.tap(find.text('Messages'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          expect(find.byType(ConversationTile), findsOneWidget);
          expect(
            find.descendant(
              of: find.byKey(const ValueKey('messages-$currentPubkey')),
              matching: find.byType(CircularProgressIndicator),
            ),
            findsNothing,
          );
        },
      );

      testWidgets(
        'shows the load-more spinner when hasMore and no filter is active',
        (tester) async {
          final conversations = List.generate(
            3,
            (index) => DmConversation(
              id: 'conv$index',
              participantPubkeys: const [currentPubkey, otherPubkey],
              isGroup: false,
              createdAt: nowUnix - index,
              lastMessageContent: 'Hello $index',
              lastMessageTimestamp: nowUnix - index,
            ),
          );

          await tester.pumpWidget(
            buildSubject(
              state: ConversationListState(
                status: ConversationListStatus.loaded,
                conversations: conversations,
                visibleConversations: conversations,
                // hasMore defaults to true.
              ),
            ),
          );
          await tester.pump();

          await tester.tap(find.text('Messages'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          expect(
            find.descendant(
              of: find.byKey(const ValueKey('messages-$currentPubkey')),
              matching: find.byType(CircularProgressIndicator),
            ),
            findsOneWidget,
          );
        },
      );

      // The search query lives in the bloc, but the controller lives in
      // _ConversationListState, which is destroyed whenever the status leaves
      // `loaded`. A fresh empty controller would leave the list filtered by an
      // invisible query: the search empty state over a blank field.
      testWidgets(
        'restores the search field after an error and retry remount',
        (tester) async {
          final matching = DmConversation(
            id: 'match',
            participantPubkeys: const [currentPubkey, otherPubkey],
            isGroup: false,
            createdAt: nowUnix,
            lastMessageContent: 'quokka sighting',
            lastMessageTimestamp: nowUnix,
          );
          final other = DmConversation(
            id: 'other',
            participantPubkeys: const [currentPubkey, otherPubkey],
            isGroup: false,
            createdAt: nowUnix - 1,
            lastMessageContent: 'unrelated',
            lastMessageTimestamp: nowUnix - 1,
          );

          final searching = ConversationListState(
            status: ConversationListStatus.loaded,
            conversations: [matching, other],
            visibleConversations: [matching],
            searchQuery: 'quokka',
            hasMore: false,
          );
          final failed = searching.copyWith(
            status: ConversationListStatus.error,
          );

          // Build first: buildSubject() installs its own whenListen stub, so
          // the controller-backed one has to replace it afterwards. Broadcast
          // because the view attaches many context.select listeners.
          final subject = buildSubject();
          final controller =
              StreamController<ConversationListState>.broadcast();
          addTearDown(controller.close);
          whenListen(mockBloc, controller.stream, initialState: searching);

          await tester.pumpWidget(subject);
          await tester.pump();
          await tester.tap(find.text('Messages'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          final searchField = find.byType(DivineSearchBar);
          expect(
            tester.widget<DivineSearchBar>(searchField).controller?.text,
            equals('quokka'),
          );

          // Stream fails: _ConversationList unmounts and its controller is
          // disposed. The bloc — and its searchQuery — survive.
          controller.add(failed);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          expect(
            find.byType(DivineSearchBar),
            findsNothing,
            reason:
                'the search bar must actually unmount, or this test would '
                'pass trivially without exercising a remount',
          );

          // Retry succeeds: the list remounts with the query still active.
          controller.add(searching);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          expect(
            tester.widget<DivineSearchBar>(searchField).controller?.text,
            equals('quokka'),
            reason:
                'an empty field over a filtered list hides why rows are '
                'missing and leaves the user no way to see the active query',
          );
          expect(find.byType(ConversationTile), findsOneWidget);
        },
      );

      testWidgets(
        'keeps the last conversation tile clear of the FAB when scrolled '
        'to the end',
        (tester) async {
          final conversations = List.generate(
            30,
            (index) => DmConversation(
              id: 'conv$index',
              participantPubkeys: const [currentPubkey, otherPubkey],
              isGroup: false,
              createdAt: nowUnix - index,
              lastMessageContent: 'Hello $index',
              lastMessageTimestamp: nowUnix - index,
            ),
          );

          await tester.pumpWidget(
            buildSubject(
              state: ConversationListState(
                status: ConversationListStatus.loaded,
                conversations: conversations,
                visibleConversations: conversations,
                hasMore: false,
              ),
            ),
          );
          await tester.pump();

          await tester.tap(find.text('Messages'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          // Scroll the conversation list to its very end so the last tile is
          // pinned against the reserved bottom inset.
          final position = tester
              .state<ScrollableState>(
                find.ancestor(
                  of: find.byType(ConversationTile).first,
                  matching: find.byType(Scrollable),
                ),
              )
              .position;
          position.jumpTo(position.maxScrollExtent);
          await tester.pump();

          // The bottom edge of the last visible tile must sit at or above the
          // FAB's top edge — i.e. the FAB never overlaps the last tile.
          final lastTileBottom = tester
              .widgetList<ConversationTile>(find.byType(ConversationTile))
              .map((tile) => tester.getRect(find.byWidget(tile)).bottom)
              .reduce(math.max);
          final fabTop = tester.getRect(find.byType(InboxFab)).top;

          expect(lastTileBottom, lessThanOrEqualTo(fabTop));
        },
      );

      testWidgets(
        'excludes inactive mounted pane from semantics after tab switch',
        (tester) async {
          final semantics = tester.ensureSemantics();
          try {
            final conversation = DmConversation(
              id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
              participantPubkeys: const [currentPubkey, otherPubkey],
              isGroup: false,
              createdAt: nowUnix,
              lastMessageContent: 'Hello',
              lastMessageTimestamp: nowUnix,
            );

            await tester.pumpWidget(
              buildSubject(
                state: ConversationListState(
                  status: ConversationListStatus.loaded,
                  conversations: [conversation],
                  visibleConversations: [conversation],
                  hasMore: false,
                ),
              ),
            );
            await tester.pump();

            await tester.tap(find.text('Messages'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 350));

            final conversationLabel = UserProfile.defaultDisplayNameFor(
              otherPubkey,
            );
            bool hasConversationSemantics() {
              SemanticsNode? root;
              bool visitPipelineOwner(PipelineOwner owner) {
                root ??= owner.semanticsOwner?.rootSemanticsNode;
                owner.visitChildren(visitPipelineOwner);
                return true;
              }

              visitPipelineOwner(RendererBinding.instance.rootPipelineOwner);
              expect(root, isNotNull);

              var found = false;
              bool visit(SemanticsNode node) {
                if (node.label.contains(conversationLabel)) {
                  found = true;
                }
                node.visitChildren(visit);
                return true;
              }

              visit(root!);
              return found;
            }

            expect(hasConversationSemantics(), isTrue);

            await tester.tap(find.text('Notifications'));
            await tester.pump();
            await tester.pump(const Duration(milliseconds: 350));

            expect(find.byType(ConversationTile), findsOneWidget);
            expect(hasConversationSemantics(), isFalse);
          } finally {
            semantics.dispose();
          }
        },
      );

      testWidgets(
        'collapses back to Notifications when the signed-in identity changes',
        (tester) async {
          final notificationController = StreamController<int>();
          addTearDown(notificationController.close);

          final conversation = DmConversation(
            id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
            participantPubkeys: const [currentPubkey, otherPubkey],
            isGroup: false,
            createdAt: nowUnix,
            lastMessageContent: 'Hello',
            lastMessageTimestamp: nowUnix,
          );

          await tester.pumpWidget(
            buildSubject(
              state: ConversationListState(
                status: ConversationListStatus.loaded,
                conversations: [conversation],
                visibleConversations: [conversation],
                hasMore: false,
              ),
              notificationStream: notificationController.stream,
            ),
          );
          await tester.pump();

          // Open Messages so the pane is activated and the tab is selected.
          await tester.tap(find.text('Messages'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));
          expect(find.byType(ConversationTile), findsOneWidget);

          // Simulate an account switch: the auth service reports a new pubkey
          // and a watched cubit emits to drive the InboxView rebuild.
          mockAuthService.pubkey = otherPubkey;
          notificationController.add(1);
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          final toggle = tester.widget<InboxSegmentedToggle>(
            find.byType(InboxSegmentedToggle),
          );
          expect(toggle.selected, InboxTab.notifications);
          expect(find.byType(ConversationTile), findsNothing);
        },
      );

      testWidgets(
        'renders $MessageRequestsBanner when request conversations exist',
        (tester) async {
          final request = DmConversation(
            id: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
            participantPubkeys: const [currentPubkey, otherPubkey],
            isGroup: false,
            createdAt: nowUnix,
            lastMessageContent: 'Hey',
            lastMessageTimestamp: nowUnix,
          );

          await tester.pumpWidget(
            buildSubject(
              state: ConversationListState(
                status: ConversationListStatus.loaded,
                requestConversations: [request],
                hasMore: false,
              ),
            ),
          );
          await tester.pump();

          // Switch to Messages tab (default is Notifications).
          await tester.tap(find.text('Messages'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          expect(find.byType(MessageRequestsBanner), findsOneWidget);
          expect(find.byType(InboxEmptyState), findsOneWidget);
          final l10n = lookupAppLocalizations(const Locale('en'));
          expect(find.text(l10n.inboxUnreadEmptyTitle), findsNothing);
        },
      );

      testWidgets(
        'renders $MessageRequestsBanner above conversations when both exist',
        (tester) async {
          final conversation = DmConversation(
            id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
            participantPubkeys: const [currentPubkey, otherPubkey],
            isGroup: false,
            createdAt: nowUnix,
            lastMessageContent: 'Hello',
            lastMessageTimestamp: nowUnix,
          );

          final request = DmConversation(
            id: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
            participantPubkeys: const [currentPubkey, otherPubkey],
            isGroup: false,
            createdAt: nowUnix,
            lastMessageContent: 'Hey',
            lastMessageTimestamp: nowUnix,
          );

          await tester.pumpWidget(
            buildSubject(
              state: ConversationListState(
                status: ConversationListStatus.loaded,
                conversations: [conversation],
                visibleConversations: [conversation],
                requestConversations: [request],
                hasMore: false,
              ),
            ),
          );
          await tester.pump();

          // Switch to Messages tab (default is Notifications).
          await tester.tap(find.text('Messages'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          expect(find.byType(MessageRequestsBanner), findsOneWidget);
          expect(find.byType(ConversationTile), findsOneWidget);
        },
      );

      testWidgets(
        'shows restoring progress bar when isRestoringHistory is true',
        (tester) async {
          await tester.pumpWidget(
            buildSubject(
              state: const ConversationListState(
                status: ConversationListStatus.loaded,
                isRestoringHistory: true,
              ),
            ),
          );
          await tester.pump();

          // Switch to Messages tab (default is Notifications).
          await tester.tap(find.text('Messages'));
          // pump (not pumpAndSettle): LinearProgressIndicator animates forever.
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          expect(find.byType(LinearProgressIndicator), findsOneWidget);
        },
      );

      testWidgets(
        'hides restoring progress bar when isRestoringHistory is false',
        (tester) async {
          await tester.pumpWidget(
            buildSubject(
              state: const ConversationListState(
                status: ConversationListStatus.loaded,
              ),
            ),
          );
          await tester.pump();

          // Switch to Messages tab (default is Notifications).
          await tester.tap(find.text('Messages'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          expect(find.byType(LinearProgressIndicator), findsNothing);
        },
      );

      testWidgets(
        'shows the restore-paused banner when requests are withheld',
        (tester) async {
          // The gate can stay shut with no drain running (page cap, exception,
          // no connected relay), so isRestoringHistory alone left the user with
          // an inbox that looked complete while requests were hidden.
          await tester.pumpWidget(
            buildSubject(
              state: const ConversationListState(
                status: ConversationListStatus.loaded,
                requestsWithheld: true,
              ),
            ),
          );
          await tester.pump();

          await tester.tap(find.text('Messages'));
          await tester.pumpAndSettle();

          expect(find.byType(RestorePausedBanner), findsOneWidget);
          // Static, not a progress bar: nothing is actually running.
          expect(find.byType(LinearProgressIndicator), findsNothing);
        },
      );

      testWidgets(
        'hides the restore-paused banner while recovery is actively running',
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

          await tester.tap(find.text('Messages'));
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 350));

          expect(find.byType(RestorePausedBanner), findsNothing);
          expect(find.byType(LinearProgressIndicator), findsOneWidget);
        },
      );

      testWidgets('hides the restore-paused banner when nothing is withheld', (
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

        await tester.tap(find.text('Messages'));
        await tester.pumpAndSettle();

        expect(find.byType(RestorePausedBanner), findsNothing);
      });

      testWidgets('restore-paused banner Retry dispatches the retry event', (
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

        await tester.tap(find.text('Messages'));
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.inboxRestoreRetryAction));
        await tester.pumpAndSettle();

        verify(
          () => mockBloc.add(const ConversationListRestoreRetryRequested()),
        ).called(1);
      });
    });

    group('navigation', () {
      testWidgets('dispatches load more when conversation list scrolls', (
        tester,
      ) async {
        final conversations = List.generate(
          30,
          (index) => DmConversation(
            id: 'conv$index',
            participantPubkeys: const [currentPubkey, otherPubkey],
            isGroup: false,
            createdAt: nowUnix - index,
            lastMessageContent: 'Hello $index',
            lastMessageTimestamp: nowUnix - index,
          ),
        );

        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: conversations,
              visibleConversations: conversations,
            ),
          ),
        );
        await tester.pump();

        await tester.tap(find.text('Messages'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        await tester.drag(
          find.byType(CustomScrollView),
          const Offset(0, -5000),
        );
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));

        verify(
          () => mockBloc.add(const ConversationListLoadMore()),
        ).called(greaterThanOrEqualTo(1));
      });

      testWidgets('calls push when a conversation is tapped', (tester) async {
        final conversation = DmConversation(
          id: 'conv123',
          participantPubkeys: const [currentPubkey, otherPubkey],
          isGroup: false,
          createdAt: nowUnix,
          lastMessageContent: 'Hello',
          lastMessageTimestamp: nowUnix,
        );

        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: [conversation],
              visibleConversations: [conversation],
              hasMore: false,
            ),
          ),
        );
        await tester.pump();

        // Switch to Messages tab (default is Notifications).
        await tester.tap(find.text('Messages'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        when(
          () => mockGoRouter.push(any(), extra: any(named: 'extra')),
        ).thenAnswer((_) async => null);

        await tester.tap(find.byType(ConversationTile));
        await tester.pump();

        verify(
          () => mockGoRouter.push(
            ConversationPage.pathForId('conv123'),
            extra: [otherPubkey],
          ),
        ).called(1);
      });

      testWidgets('calls pushNamed to message requests when banner is tapped', (
        tester,
      ) async {
        final request = DmConversation(
          id: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
          participantPubkeys: const [currentPubkey, otherPubkey],
          isGroup: false,
          createdAt: nowUnix,
          lastMessageContent: 'Hey',
          lastMessageTimestamp: nowUnix,
        );

        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              requestConversations: [request],
              hasMore: false,
            ),
          ),
        );
        await tester.pump();

        // Switch to Messages tab (default is Notifications).
        await tester.tap(find.text('Messages'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        when(() => mockGoRouter.pushNamed(any())).thenAnswer((_) async => null);

        await tester.tap(find.byType(MessageRequestsBanner));
        await tester.pump();

        verify(
          () => mockGoRouter.pushNamed(MessageRequestsPage.routeName),
        ).called(1);
      });

      testWidgets('adds navigate event when user is tapped in following bar', (
        tester,
      ) async {
        // Mock MyFollowingBloc state to show one user BEFORE building the subject
        whenListen(
          mockFollowingBloc,
          Stream<MyFollowingState>.value(
            const MyFollowingState(
              status: MyFollowingStatus.success,
              followingPubkeys: ['user123'],
            ),
          ),
          initialState: const MyFollowingState(
            status: MyFollowingStatus.success,
            followingPubkeys: ['user123'],
          ),
        );

        await tester.pumpWidget(buildSubject());
        await tester.pump();

        // Switch to Messages tab (default is Notifications).
        await tester.tap(find.text('Messages'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
        await tester.pump(const Duration(milliseconds: 100));

        // FollowingBar uses fetchUserProfileProvider for names. When the
        // profile is not found, it falls back to the deterministic
        // generated name from UserProfile.defaultDisplayNameFor.
        final fallbackName = UserProfile.defaultDisplayNameFor('user123');

        expect(find.text(fallbackName), findsOneWidget);

        await tester.tap(find.text(fallbackName));
        await tester.pump();

        verify(
          () => mockBloc.add(const ConversationListNavigateToUser('user123')),
        ).called(1);
      });
    });

    group('scroll layout (#6388 review, items 4 + 5)', () {
      Future<void> openMessages(WidgetTester tester) async {
        await tester.pump();
        await tester.tap(find.text('Messages'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
      }

      List<DmConversation> manyConversations() => List.generate(
        30,
        (index) => DmConversation(
          id: 'c${index.toString().padLeft(63, '0')}',
          participantPubkeys: const [currentPubkey, otherPubkey],
          isGroup: false,
          createdAt: nowUnix - index,
          lastMessageContent: 'Message $index',
          lastMessageTimestamp: nowUnix - index,
        ),
      );

      testWidgets('scrolls the search field away and keeps the filter chips '
          'pinned, so the keyboard cannot squeeze the list', (tester) async {
        final conversations = manyConversations();
        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: conversations,
              visibleConversations: conversations,
              hasMore: false,
            ),
          ),
        );
        await openMessages(tester);

        expect(find.byType(DivineSearchBar), findsOneWidget);
        final chipsBefore = tester.getTopLeft(find.byType(InboxFilterChips));

        await tester.drag(find.byType(CustomScrollView), const Offset(0, -400));
        await tester.pump();

        // The search field is chrome now, not a fixed header: it leaves the
        // viewport entirely, handing its height back to the conversations.
        expect(find.byType(DivineSearchBar), findsNothing);
        // The chips do not — losing the way back to All while filtered by
        // Unread would be a trap.
        expect(find.byType(InboxFilterChips), findsOneWidget);
        expect(
          tester.getTopLeft(find.byType(InboxFilterChips)).dy,
          lessThanOrEqualTo(chipsBefore.dy),
        );
      });

      // `laidOut` is the height the chips actually got; `needed` is their
      // intrinsic height, computed from the content and independent of the
      // constraint they were laid out under. Comparing the two is what catches
      // a clipped label, since a Row overflowing on its cross axis does not
      // throw. Both matter: a header shorter than `needed` clips the chips,
      // and a header taller than what its child lays out to used to blank the
      // whole pane — see the Dynamic Type sweep below.
      Future<({double laidOut, double needed})> pumpChips(
        WidgetTester tester, {
        required TextScaler textScaler,
      }) async {
        final conversations = manyConversations();
        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: conversations,
              visibleConversations: conversations,
              hasMore: false,
            ),
            textScaler: textScaler,
          ),
        );
        await openMessages(tester);

        // skipOffstage:false so this helper still reports sizes when the
        // viewport is broken: the onstage element walk itself null-crashes on
        // a sliver left unlaid-out, and swallowing that here would hide which
        // assertion below actually failed.
        final box = tester.renderObject<RenderBox>(
          find.byType(InboxFilterChips, skipOffstage: false),
        );
        return (
          laidOut: box.size.height,
          needed: box.getMaxIntrinsicHeight(box.size.width),
        );
      }

      // Every Dynamic Type size iOS can hand us, as the ratio of that
      // category's body point size to the 17pt default — the mapping the
      // engine uses to turn `preferredContentSizeCategory` into
      // `textScaleFactor`.
      //
      // `TextScaler.linear` is a stand-in: on device `MediaQuery.textScalerOf`
      // is a `SystemTextScaler`, whose `scale()` defers to
      // `PlatformDispatcher.scaleFontSize`. That falls back to
      // `size * textScaleFactor` only while the platform sends no
      // `configurationId` — otherwise it asks the engine for a per-size curve,
      // which is the Android 14+ non-linear path. Measured on an iPhone at
      // extraLarge, a 14pt/1.4x paragraph lays out at 22.0, matching the
      // linear form, so the ladder is faithful where it has been checked.
      //
      // Neither form is what a declared extent has to match, though: the
      // child's height comes from a laid-out line box that snaps to whole
      // pixels, and no arithmetic over `scale()` reproduces that rounding.
      // Measuring the child is immune to all of it; a declared extent is not,
      // on either platform.
      //
      // The header used to declare its own extent as arithmetic over
      // `textScaler.scale(20)` while its child settled on whatever the font
      // metrics produced, and those snap to whole pixels. Eleven of these
      // twelve diverged. Six declared MORE than the child laid out to —
      // extraSmall, extraLarge (one notch above the default), XXXL, and
      // AX3/AX4/AX5 — leaving paintExtent below layoutExtent, which fails
      // SliverGeometry's contract inside the viewport's performLayout, aborts
      // the child layout sequence, and leaves the conversation list with a
      // null geometry: a blank pane. The other five declared LESS than the
      // chips need — small, medium, XXL, AX1, AX2 — silently clipping them.
      // Only the default was correct (#7854). The scale this file covered
      // before, 2.0, lands on a whole pixel and never diverged, which is why
      // it did not catch either half.
      const iosDynamicTypeScales = <String, double>{
        'extraSmall': 14 / 17,
        'small': 15 / 17,
        'medium': 16 / 17,
        'large (default)': 1,
        'extraLarge': 19 / 17,
        'extraExtraLarge': 21 / 17,
        'extraExtraExtraLarge': 23 / 17,
        'AX1': 28 / 17,
        'AX2': 33 / 17,
        'AX3': 40 / 17,
        'AX4': 47 / 17,
        'AX5': 53 / 17,
      };

      for (final MapEntry(key: category, value: scale)
          in iosDynamicTypeScales.entries) {
        testWidgets('renders the conversation list at iOS $category', (
          tester,
        ) async {
          final size = await pumpChips(
            tester,
            textScaler: TextScaler.linear(scale),
          );

          expect(
            tester.takeException(),
            isNull,
            reason: 'the header must not break the SliverGeometry contract',
          );
          expect(
            size.laidOut,
            greaterThanOrEqualTo(size.needed),
            reason: 'the header must not clip the chips',
          );
          // The canary: this finder walks the onstage element tree, which is
          // exactly what null-crashes when a sliver was left unlaid-out. It
          // failing IS the blank pane.
          expect(find.byType(ConversationTile), findsWidgets);

          // Pinning only engages once there is something to pin against, and
          // that is a different geometry path — scrollOffset above zero,
          // layoutExtent shrinking toward zero — than the initial layout.
          // `PinnedHeaderSliver` derives paintExtent as
          // `min(childExtent, remainingPaintExtent - overlap)`. That second
          // term has no lower clamp, so it is safe here only because nothing
          // pinned sits above this header and `overlap` stays at zero. Adding
          // one would put paintExtent back under layoutExtent and blank the
          // pane again, so pin it.
          await tester.drag(
            find.byType(CustomScrollView),
            const Offset(0, -400),
          );
          await tester.pump();

          expect(
            tester.takeException(),
            isNull,
            reason: 'the header must survive scrolling to its pinned edge',
          );
          expect(find.byType(ConversationTile), findsWidgets);
        });
      }

      testWidgets('the pinned header fits the chips at the default text scale', (
        tester,
      ) async {
        final size = await pumpChips(tester, textScaler: TextScaler.noScaling);

        // 48 = 8px padding either side of a DivineButtonSize.tiny chip, which
        // is itself 6 + a 20px line box + 6. Asserting the chips ASK for 48 is
        // the half that can fail: if a divine_ui token moves, this breaks here
        // rather than as a clipped chip on someone's phone.
        expect(size.needed, equals(48));
        expect(size.laidOut, equals(48));
      });

      testWidgets('the pinned header grows with the text scale rather than '
          'clipping the chips', (tester) async {
        final size = await pumpChips(
          tester,
          textScaler: const TextScaler.linear(2),
        );

        // Only the 20px line box scales; the two paddings do not. 16 + 12 + 40.
        expect(size.needed, equals(68));
        expect(size.laidOut, greaterThanOrEqualTo(size.needed));
      });

      testWidgets('filter chips honour the system text scale', (tester) async {
        final conversations = manyConversations();
        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: conversations,
              visibleConversations: conversations,
              hasMore: false,
            ),
            textScaler: const TextScaler.linear(2),
          ),
        );
        await openMessages(tester);

        // These are controls the user reads and taps, so they must not be
        // frozen at 1.0 the way a fixed overlay badge is.
        final unreadTextContext = tester.element(find.text('Unread'));
        expect(
          MediaQuery.textScalerOf(unreadTextContext).scale(20),
          equals(40),
        );
      });

      testWidgets('collapses the following bar when the search field takes '
          'focus, before any query is typed', (tester) async {
        // FollowingBar needs real extent to lose, so give it one follow.
        whenListen(
          mockFollowingBloc,
          Stream<MyFollowingState>.value(
            const MyFollowingState(
              status: MyFollowingStatus.success,
              followingPubkeys: ['user123'],
            ),
          ),
          initialState: const MyFollowingState(
            status: MyFollowingStatus.success,
            followingPubkeys: ['user123'],
          ),
        );

        final conversations = manyConversations();
        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: conversations,
              visibleConversations: conversations,
              hasMore: false,
            ),
          ),
        );
        await openMessages(tester);

        expect(tester.getSize(find.byType(FollowingBar)).height, equals(128));
        final firstTileBefore = tester.getTopLeft(find.text('Message 0')).dy;

        await tester.tap(find.byType(DivineSearchBar));
        await tester.pumpAndSettle();

        // Focus alone reclaims the bar — no text needed. minSearchQueryLength
        // is 2, so a query-driven collapse would still be showing faces here.
        expect(find.byType(FollowingBar, skipOffstage: false), findsNothing);
        expect(
          tester.getTopLeft(find.text('Message 0')).dy,
          lessThan(firstTileBefore - 100),
        );
      });

      testWidgets('restores the following bar when search focus is released', (
        tester,
      ) async {
        // FollowingBar needs real extent to lose, so give it one follow.
        whenListen(
          mockFollowingBloc,
          Stream<MyFollowingState>.value(
            const MyFollowingState(
              status: MyFollowingStatus.success,
              followingPubkeys: ['user123'],
            ),
          ),
          initialState: const MyFollowingState(
            status: MyFollowingStatus.success,
            followingPubkeys: ['user123'],
          ),
        );

        final conversations = manyConversations();
        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: conversations,
              visibleConversations: conversations,
              hasMore: false,
            ),
          ),
        );
        await openMessages(tester);

        await tester.tap(find.byType(DivineSearchBar));
        await tester.pumpAndSettle();
        expect(find.byType(FollowingBar, skipOffstage: false), findsNothing);

        // Submitting unfocuses (DivineSearchBar dismisses the keyboard so the
        // results stay visible), which must bring the bar back.
        await tester.testTextInput.receiveAction(TextInputAction.done);
        await tester.pumpAndSettle();

        expect(tester.getSize(find.byType(FollowingBar)).height, equals(128));
      });

      testWidgets('renders the whole pane as one scroll view', (tester) async {
        final conversations = manyConversations();
        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: conversations,
              visibleConversations: conversations,
              hasMore: false,
            ),
          ),
        );
        await openMessages(tester);

        // One scrollable for the pane — the old layout nested a ListView
        // inside a Column of fixed-height chrome, which is what left the list
        // roughly one row tall with the keyboard open.
        expect(find.byType(CustomScrollView), findsOneWidget);
      });
    });

    group('conversation identity and pinned support row (#6283)', () {
      const moderationPubkey = kModerationPubkeyHex;

      PinnedSupport supportPin({
        String? lastMessageContent,
        bool isRead = true,
        bool isPersisted = false,
      }) => PinnedSupport(
        isPersisted: isPersisted,
        conversation: DmConversation(
          id: 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
          participantPubkeys: const [currentPubkey, moderationPubkey],
          isGroup: false,
          createdAt: 0,
          lastMessageContent: lastMessageContent,
          isRead: isRead,
        ),
      );

      Future<void> openMessages(WidgetTester tester) async {
        await tester.pump();
        await tester.tap(find.text('Messages'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));
      }

      Future<void> pumpVanishedConversation(
        WidgetTester tester, {
        bool isBlocked = false,
      }) async {
        final actionsCubit = _MockConversationActionsCubit();
        when(
          () => actionsCubit.blockUser(otherPubkey),
        ).thenAnswer((_) async {});
        when(
          () => actionsCubit.unblockUser(otherPubkey),
        ).thenAnswer((_) async {});
        when(
          () => actionsCubit.reportUser(otherPubkey),
        ).thenAnswer((_) async => true);
        final conversation = DmConversation(
          id: 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
          participantPubkeys: const [currentPubkey, otherPubkey],
          isGroup: false,
          createdAt: nowUnix,
          lastMessageContent: 'Hello',
          lastMessageTimestamp: nowUnix,
        );
        final subject = buildSubject(
          wrapInScaffold: true,
          actionsCubit: actionsCubit,
          state: ConversationListState(
            status: ConversationListStatus.loaded,
            conversations: [conversation],
            visibleConversations: [conversation],
            hasMore: false,
          ),
          additionalOverrides: [
            profileVanishedProvider(otherPubkey).overrideWith((ref) => true),
            profileVanishedSnapshotProvider(
              otherPubkey,
            ).overrideWith((ref) async => true),
          ],
        );
        when(() => actionsCubit.isBlocked(otherPubkey)).thenReturn(isBlocked);

        await tester.pumpWidget(subject);
        await openMessages(tester);
      }

      final wordmarkFinder = find.byWidgetPredicate(
        (widget) => widget is DivineIcon && widget.icon == DivineIconName.logo,
        description: 'bundled Divine wordmark',
      );

      testWidgets('renders the moderation title from l10n, never a '
          'generated profile name', (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              pinnedSupport: supportPin(),
            ),
          ),
        );
        await openMessages(tester);

        expect(find.text(l10n.inboxSupportRowTitle), findsOneWidget);
        expect(find.text(l10n.inboxSupportRowSubtitle), findsOneWidget);
        // The tile's profile fallback is a deterministic "Adjective Animal N"
        // string. If the override ever regresses, the moderation row silently
        // renders as a random user, so pin the exact fallback out.
        expect(
          find.text(UserProfile.defaultDisplayNameFor(moderationPubkey)),
          findsNothing,
        );
      });

      // The bloc withholds the pin for a restricted minor whose approval was
      // revoked, and wherever no moderation pubkey is configured. Blocking
      // moderation no longer withholds it (#7850). The view must render
      // nothing at all when the bloc emits no pin, not an empty tile.
      testWidgets('is absent when the bloc emits no pin', (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.pumpWidget(
          buildSubject(
            state: const ConversationListState(
              status: ConversationListStatus.loaded,
            ),
          ),
        );
        await openMessages(tester);

        expect(find.text(l10n.inboxSupportRowTitle), findsNothing);
      });

      testWidgets('renders BESIDE the empty state, not instead of it — the '
          'user with zero conversations is the one who needs it most', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              pinnedSupport: supportPin(),
            ),
          ),
        );
        await openMessages(tester);

        expect(find.byType(InboxEmptyState), findsOneWidget);
        expect(find.text(l10n.inboxSupportRowTitle), findsOneWidget);
      });

      testWidgets(
        'distinguishes a retired moderation thread from the live pin',
        (
          tester,
        ) async {
          final l10n = lookupAppLocalizations(const Locale('en'));
          final retiredConversation = DmConversation(
            id: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
            participantPubkeys: [currentPubkey, kLegacyModerationPubkeys.first],
            isGroup: false,
            createdAt: nowUnix,
            lastMessageContent: 'You can reply to this message to appeal.',
            lastMessageTimestamp: nowUnix,
          );

          await tester.pumpWidget(
            buildSubject(
              state: ConversationListState(
                status: ConversationListStatus.loaded,
                conversations: [retiredConversation],
                visibleConversations: [retiredConversation],
                pinnedSupport: supportPin(),
                hasMore: false,
              ),
            ),
          );
          await openMessages(tester);

          expect(find.byType(ConversationTile), findsNWidgets(2));
          expect(find.text(l10n.inboxSupportRowTitle), findsNWidgets(2));
          expect(find.text(l10n.inboxSupportRowSubtitle), findsOneWidget);
          expect(find.text(l10n.dmRetiredThreadClosedTitle), findsOneWidget);
          expect(
            find.text('You can reply to this message to appeal.'),
            findsNothing,
          );
        },
      );

      // #7380: the long-press sheet resolves the peer name on its own, and
      // that chain omits `moderationDisplayName`. The tile above it reads
      // "Divine Moderation"; the sheet it opens must not disagree.
      testWidgets('names moderation in the sheet a retired-key row opens', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        final retiredConversation = DmConversation(
          id: 'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee',
          participantPubkeys: [currentPubkey, kLegacyModerationPubkeys.first],
          isGroup: false,
          createdAt: nowUnix,
          lastMessageContent: 'You can reply to this message to appeal.',
          lastMessageTimestamp: nowUnix,
        );

        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: [retiredConversation],
              visibleConversations: [retiredConversation],
              hasMore: false,
            ),
          ),
        );
        await openMessages(tester);

        await tester.longPress(find.byType(ConversationTile));
        await tester.pumpAndSettle();

        // The tile and the sheet it opened must name the same account.
        expect(find.text(l10n.inboxSupportRowTitle), findsOneWidget);
        expect(
          find.text(l10n.inboxActionBlock(l10n.inboxSupportRowTitle)),
          findsOneWidget,
        );
        expect(
          find.text(l10n.inboxActionReport(l10n.inboxSupportRowTitle)),
          findsOneWidget,
        );
        // #7380: the peer used to resolve to the bare literal 'user', so the
        // sheet offered to block "user" under a tile titled "Divine
        // Moderation". No profile lookup can produce that string now.
        expect(find.text(l10n.inboxActionBlock('user')), findsNothing);
      });

      // The other half of #7380. Blocking moderation suppresses the pin, so
      // the thread falls back into the Blocked slice as an ordinary row — and
      // that row is the one a user unblocks through. Its long-press is only
      // live once the thread carries a message; a blocked account with no
      // thread renders a placeholder whose long-press is null.
      testWidgets('names moderation in the sheet the Blocked slice opens', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        final blockedModeration = DmConversation(
          id: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
          participantPubkeys: const [currentPubkey, moderationPubkey],
          isGroup: false,
          createdAt: nowUnix,
          lastMessageContent: 'Your video was removed.',
          lastMessageTimestamp: nowUnix,
        );
        final actionsCubit = _MockConversationActionsCubit();

        final subject = buildSubject(
          actionsCubit: actionsCubit,
          state: ConversationListState(
            status: ConversationListStatus.loaded,
            filter: InboxFilter.blocked,
            visibleConversations: [blockedModeration],
            blockedConversations: [blockedModeration],
            hasMore: false,
          ),
        );
        // After buildSubject, which stubs isBlocked to false by default.
        when(() => actionsCubit.isBlocked(any())).thenReturn(true);

        await tester.pumpWidget(subject);
        await openMessages(tester);

        await tester.longPress(find.byType(ConversationTile));
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.inboxActionUnblock(l10n.inboxSupportRowTitle)),
          findsOneWidget,
        );
        expect(find.text(l10n.inboxActionUnblock('user')), findsNothing);
      });

      // A group room has no single counterparty. `otherPubkey` is whichever
      // peer sorts first, so naming the row after them hides that anyone else
      // is in it, and Report/Block would act on that one account alone while
      // reading as though they dealt with the thread.
      group('group conversations', () {
        const peerA =
            'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1';
        const peerB =
            'b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2';

        DmConversation groupConversation({String? subject}) => DmConversation(
          id: 'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
          participantPubkeys: const [currentPubkey, peerA, peerB],
          isGroup: true,
          createdAt: nowUnix,
          subject: subject,
          lastMessageContent: 'Anyone free on Saturday?',
          lastMessageTimestamp: nowUnix,
        );

        Future<void> openSheet(
          WidgetTester tester,
          DmConversation conversation,
        ) async {
          await tester.pumpWidget(
            buildSubject(
              state: ConversationListState(
                status: ConversationListStatus.loaded,
                conversations: [conversation],
                visibleConversations: [conversation],
                hasMore: false,
              ),
            ),
          );
          await openMessages(tester);
          await tester.longPress(find.byType(ConversationTile));
          await tester.pumpAndSettle();
        }

        testWidgets('names a titled room by its NIP-17 subject', (
          tester,
        ) async {
          await openSheet(tester, groupConversation(subject: 'Weekend trip'));

          // The row and the sheet it opened must agree, and neither may fall
          // back to a participant's generated name.
          expect(find.text('Weekend trip'), findsWidgets);
          expect(
            find.text(UserProfile.defaultDisplayNameFor(peerA)),
            findsNothing,
          );
        });

        testWidgets('names an untitled room for who is in it', (tester) async {
          final l10n = lookupAppLocalizations(const Locale('en'));
          await openSheet(tester, groupConversation());

          expect(
            find.text(
              l10n.inboxGroupConversationTitle(
                UserProfile.defaultDisplayNameFor(peerA),
                1,
              ),
            ),
            findsWidgets,
          );
        });

        testWidgets('offers no single-target Report or Block', (tester) async {
          final l10n = lookupAppLocalizations(const Locale('en'));
          await openSheet(tester, groupConversation(subject: 'Weekend trip'));

          // Conversation-scoped actions stay: both mean what they say here.
          expect(find.text(l10n.inboxActionMute), findsOneWidget);
          expect(find.text(l10n.inboxActionRemove), findsOneWidget);
          // Account-scoped ones do not, in any of their label variants.
          expect(
            find.text(l10n.inboxActionReport('Weekend trip')),
            findsNothing,
          );
          expect(
            find.text(l10n.inboxActionBlock('Weekend trip')),
            findsNothing,
          );
          expect(
            find.text(l10n.inboxActionUnblock('Weekend trip')),
            findsNothing,
          );
          expect(
            find.text(l10n.inboxActionReportVanishedAccount),
            findsNothing,
          );
          expect(find.text(l10n.inboxActionBlockVanishedAccount), findsNothing);
        });

        testWidgets('a 1:1 still offers both, so the guard is not blanket', (
          tester,
        ) async {
          final l10n = lookupAppLocalizations(const Locale('en'));
          final oneToOne = DmConversation(
            id: 'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc',
            participantPubkeys: const [currentPubkey, peerA],
            isGroup: false,
            createdAt: nowUnix,
            lastMessageContent: 'Hey',
            lastMessageTimestamp: nowUnix,
          );
          await openSheet(tester, oneToOne);

          final name = UserProfile.defaultDisplayNameFor(peerA);
          expect(find.text(l10n.inboxActionReport(name)), findsOneWidget);
          expect(find.text(l10n.inboxActionBlock(name)), findsOneWidget);
        });

        // "This removes your conversation with Weekend trip from your inbox"
        // reads as a conversation with the room, not with the people in it.
        testWidgets('removes without claiming a conversation with the room', (
          tester,
        ) async {
          final l10n = lookupAppLocalizations(const Locale('en'));
          await openSheet(tester, groupConversation(subject: 'Weekend trip'));

          await tester.tap(find.text(l10n.inboxActionRemove));
          await tester.pumpAndSettle();

          expect(find.text(l10n.inboxRemoveConfirmBodyGroup), findsOneWidget);
          expect(
            find.text(l10n.inboxRemoveConfirmBody('Weekend trip')),
            findsNothing,
          );
        });
      });

      group('vanished conversation actions', () {
        // #8185, the same shape one layer out: `ConversationTile`
        // short-circuits on the NIP-62 vanish before every other branch, and
        // the sheet's own chain had no such branch. Applying a vanish evicts
        // the cached profile, so the sheet did not fall back to the peer's
        // last known name — it fell all the way to a generated
        // "Adjective Animal N" and offered to block that, under a row reading
        // "Deleted account".
        testWidgets('names a vanished peer in the sheet its row opens', (
          tester,
        ) async {
          final l10n = lookupAppLocalizations(const Locale('en'));
          await pumpVanishedConversation(tester);

          expect(find.text(l10n.profileDeletedAccountName), findsOneWidget);

          await tester.longPress(find.byType(ConversationTile));
          await tester.pumpAndSettle();

          expect(
            find.text(l10n.inboxActionBlockVanishedAccount),
            findsOneWidget,
          );
          expect(
            find.text(l10n.inboxActionReportVanishedAccount),
            findsOneWidget,
          );
          expect(
            find.textContaining(UserProfile.defaultDisplayNameFor(otherPubkey)),
            findsNothing,
          );
        });

        testWidgets('confirms reporting a vanished peer', (tester) async {
          final l10n = lookupAppLocalizations(const Locale('en'));
          await pumpVanishedConversation(tester);

          await tester.longPress(find.byType(ConversationTile));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.inboxActionReportVanishedAccount));
          await tester.pumpAndSettle();

          expect(find.text(l10n.inboxReportedVanishedAccount), findsOneWidget);
        });

        testWidgets('confirms blocking a vanished peer', (tester) async {
          final l10n = lookupAppLocalizations(const Locale('en'));
          await pumpVanishedConversation(tester);

          await tester.longPress(find.byType(ConversationTile));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.inboxActionBlockVanishedAccount));
          await tester.pumpAndSettle();

          expect(find.text(l10n.inboxBlockedVanishedAccount), findsOneWidget);
        });

        testWidgets('confirms unblocking a vanished peer', (tester) async {
          final l10n = lookupAppLocalizations(const Locale('en'));
          await pumpVanishedConversation(tester, isBlocked: true);

          await tester.longPress(find.byType(ConversationTile));
          await tester.pumpAndSettle();
          expect(
            find.text(l10n.inboxActionUnblockVanishedAccount),
            findsOneWidget,
          );
          await tester.tap(find.text(l10n.inboxActionUnblockVanishedAccount));
          await tester.pumpAndSettle();

          expect(find.text(l10n.inboxUnblockedVanishedAccount), findsOneWidget);
        });

        testWidgets('removes a vanished peer without using a name template', (
          tester,
        ) async {
          final l10n = lookupAppLocalizations(const Locale('en'));
          await pumpVanishedConversation(tester);

          await tester.longPress(find.byType(ConversationTile));
          await tester.pumpAndSettle();
          await tester.tap(find.text(l10n.inboxActionRemove));
          await tester.pumpAndSettle();

          expect(
            find.text(l10n.inboxRemoveConfirmBodyVanishedAccount),
            findsOneWidget,
          );
          expect(
            find.text(
              l10n.inboxRemoveConfirmBody(l10n.profileDeletedAccountName),
            ),
            findsNothing,
          );
        });
      });

      testWidgets('drops out of a search it does not match', (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        final conversation = DmConversation(
          id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
          participantPubkeys: const [currentPubkey, otherPubkey],
          isGroup: false,
          createdAt: nowUnix,
          lastMessageContent: 'Hello',
          lastMessageTimestamp: nowUnix,
        );
        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: [conversation],
              searchQuery: 'zzzz',
              hasMore: false,
              pinnedSupport: supportPin(),
            ),
          ),
        );
        await openMessages(tester);

        // Now that the row sits inside the list rather than above it, a row
        // matching neither the query nor anything else would read as a search
        // hit that isn't one. It is pinned against the sort, not the filters.
        expect(find.text(l10n.inboxSearchEmptyTitle), findsOneWidget);
        expect(find.text(l10n.inboxSupportRowTitle), findsNothing);
      });

      // A real conversation has to be present for the filtered branch to run
      // at all: an inbox with nothing in it skips the search field and chips
      // entirely, so there is no filter for the row to be judged against.
      final realConversation = DmConversation(
        id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
        participantPubkeys: const [currentPubkey, otherPubkey],
        isGroup: false,
        createdAt: nowUnix,
        lastMessageContent: 'Hello',
        lastMessageTimestamp: nowUnix,
      );

      testWidgets('stays in a search whose query matches its title', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: [realConversation],
              // 'moderation' matches inboxSupportRowTitle, but no real thread.
              searchQuery: 'moderation',
              hasMore: false,
              pinnedSupport: supportPin(),
            ),
          ),
        );
        await openMessages(tester);

        expect(find.text(l10n.inboxSupportRowTitle), findsOneWidget);
      });

      testWidgets('stays in a search whose query matches the subtitle blurb '
          'it actually renders', (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        // A synthetic pin renders inboxSupportRowSubtitle as its preview, so
        // a query drawn from that text must keep it — hiding the row while
        // the matched words are on screen reads as a broken search.
        const query = 'bugs';
        expect(
          l10n.inboxSupportRowSubtitle.toLowerCase(),
          contains(query),
          reason: 'query must be drawn from the rendered subtitle',
        );
        expect(
          l10n.inboxSupportRowTitle.toLowerCase(),
          isNot(contains(query)),
          reason: 'otherwise the title branch would carry the test',
        );

        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: [realConversation],
              searchQuery: query,
              hasMore: false,
              pinnedSupport: supportPin(),
            ),
          ),
        );
        await openMessages(tester);

        expect(find.text(l10n.inboxSupportRowTitle), findsOneWidget);
      });

      testWidgets('is hidden by the Unread chip once it has been read', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: [realConversation],
              filter: InboxFilter.unread,
              hasMore: false,
              pinnedSupport: supportPin(),
            ),
          ),
        );
        await openMessages(tester);

        expect(find.text(l10n.inboxSupportRowTitle), findsNothing);
      });

      testWidgets('survives the Unread chip while it still has unread', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: [realConversation],
              filter: InboxFilter.unread,
              hasMore: false,
              pinnedSupport: supportPin(
                isRead: false,
                lastMessageContent: 'We looked into your report.',
              ),
            ),
          ),
        );
        await openMessages(tester);

        expect(find.text(l10n.inboxSupportRowTitle), findsOneWidget);
      });

      testWidgets('is the first tile, ahead of the requests banner and every '
          'real conversation', (tester) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        final conversation = DmConversation(
          id: 'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd',
          participantPubkeys: const [currentPubkey, otherPubkey],
          isGroup: false,
          createdAt: nowUnix,
          lastMessageContent: 'Hello',
          lastMessageTimestamp: nowUnix,
        );
        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: [conversation],
              visibleConversations: [conversation],
              requestConversations: [
                DmConversation(
                  id:
                      'eeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeeee'
                      'eeeeeeeeeeeeeeeeeeeeeeee',
                  participantPubkeys: const [currentPubkey, otherPubkey],
                  isGroup: false,
                  createdAt: nowUnix,
                ),
              ],
              hasMore: false,
              pinnedSupport: supportPin(),
            ),
          ),
        );
        await openMessages(tester);

        // Ordering is asserted geometrically: the conversation list carries no
        // index the test can read, and the moderation row must outrank both
        // the requests banner and a conversation with a far newer timestamp.
        final supportY = tester
            .getTopLeft(find.text(l10n.inboxSupportRowTitle))
            .dy;
        final bannerY = tester
            .getTopLeft(find.byType(MessageRequestsBanner))
            .dy;
        final conversationY = tester.getTopLeft(find.text('Hello')).dy;

        expect(supportY, lessThan(bannerY));
        expect(bannerY, lessThan(conversationY));
      });

      testWidgets('still renders for a brand-new user with an empty inbox', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              hasMore: false,
              pinnedSupport: supportPin(),
            ),
          ),
        );
        await openMessages(tester);

        // The empty-state copy still shows, but the support row is not lost
        // with it — this is the user who most needs to reach moderation.
        expect(find.byType(InboxEmptyState), findsOneWidget);
        expect(find.text(l10n.inboxSupportRowTitle), findsOneWidget);
      });

      testWidgets('shows the real last message once the team has replied', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              pinnedSupport: supportPin(
                lastMessageContent: 'We looked into your report.',
                isRead: false,
              ),
            ),
          ),
        );
        await openMessages(tester);

        expect(find.text('We looked into your report.'), findsOneWidget);
        expect(find.text(l10n.inboxSupportRowSubtitle), findsNothing);
      });

      testWidgets('opens the conversation with MODERATION, not with self', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        final pin = supportPin();
        when(
          () => mockGoRouter.push<Object?>(any(), extra: any(named: 'extra')),
        ).thenAnswer((_) async => null);

        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              pinnedSupport: pin,
            ),
          ),
        );
        await openMessages(tester);
        await tester.tap(find.text(l10n.inboxSupportRowTitle));
        await tester.pump();

        // The route reads `extra` as the COUNTERPARTY list. Passing the raw
        // participants (which include self) opened a conversation with the
        // signed-in user — caught only by running the app, because a mocked
        // router happily accepts either list.
        final captured = verify(
          () => mockGoRouter.push<Object?>(
            ConversationPage.pathForId(pin.conversation.id),
            extra: captureAny(named: 'extra'),
          ),
        ).captured.single;
        expect(captured, equals([moderationPubkey]));
        expect(captured, isNot(contains(currentPubkey)));
      });

      testWidgets('exposes a tappable button to assistive tech', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              pinnedSupport: supportPin(),
            ),
          ),
        );
        await openMessages(tester);

        final data = tester
            .getSemantics(find.byType(ConversationTile))
            .getSemanticsData();
        expect(data.label, contains(l10n.inboxSupportRowTitle));
        expect(data.flagsCollection.isButton, isTrue);
        // Nothing is persisted yet, so there is no action sheet to open and
        // the row must not advertise a long-press it cannot honour.
        expect(data.hasAction(SemanticsAction.longPress), isFalse);
      });

      testWidgets(
        'advertises long-press to assistive tech once a thread is adopted',
        (tester) async {
          await tester.pumpWidget(
            buildSubject(
              state: ConversationListState(
                status: ConversationListStatus.loaded,
                pinnedSupport: supportPin(isPersisted: true),
              ),
            ),
          );
          await openMessages(tester);

          final data = tester
              .getSemantics(find.byType(ConversationTile))
              .getSemanticsData();
          // The adopted thread carries the actions the ordinary row had before
          // the pin replaced it, so the affordance must be discoverable.
          expect(data.hasAction(SemanticsAction.longPress), isTrue);
        },
      );

      testWidgets('renders the bundled wordmark rather than the account '
          'picture', (tester) async {
        // The moderation account's kind-0 picture is divine-logo.svg, which
        // colours itself through a <style> block. flutter_svg's parser has no
        // <style> support, discards it, and paints every path opaque black —
        // 1.1:1 against the inbox surface. The row must not depend on it.
        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              pinnedSupport: supportPin(),
            ),
          ),
        );
        await openMessages(tester);

        expect(wordmarkFinder, findsOneWidget);
      });

      testWidgets('renders no wordmark when there is no pin', (tester) async {
        await tester.pumpWidget(
          buildSubject(
            state: const ConversationListState(
              status: ConversationListStatus.loaded,
            ),
          ),
        );
        await openMessages(tester);

        expect(wordmarkFinder, findsNothing);
      });

      testWidgets(
        'long-press on an adopted thread opens the actions sheet labelled '
        'Divine Moderation, never a generated profile name',
        (tester) async {
          final l10n = lookupAppLocalizations(const Locale('en'));
          await tester.pumpWidget(
            buildSubject(
              state: ConversationListState(
                status: ConversationListStatus.loaded,
                pinnedSupport: supportPin(
                  isPersisted: true,
                  lastMessageContent: 'We looked into your report',
                ),
              ),
            ),
          );
          await openMessages(tester);

          await tester.longPress(find.text(l10n.inboxSupportRowTitle));
          await tester.pumpAndSettle();

          // The pin replaced an ordinary row that had these actions; losing
          // them on adoption is the regression this guards (#6388 review).
          // Remove is the deliberate exception — see the sibling test below.
          expect(
            find.text(l10n.inboxActionBlock(l10n.inboxSupportRowTitle)),
            findsOneWidget,
          );
          // Sourcing the sheet's name from kind-0 would label it with the
          // deterministic "Adjective Animal N" fallback for this pubkey.
          expect(
            find.text(
              l10n.inboxActionBlock(
                UserProfile.defaultDisplayNameFor(moderationPubkey),
              ),
            ),
            findsNothing,
          );
        },
      );

      // #8391: the arc #6971 -> #8302 made an enforcement notice unremovable
      // in Message Requests, but the CURRENT-key notice never goes there — it
      // is lifted into the pinned row, whose long-press offered "Remove
      // conversation" through a cubit with no policy at all. Withdrawing the
      // action is the deliberate reversal of the #6388-review expectation
      // above: Mute / Report / Block still survive adoption, Remove does not,
      // because removal is permanent and the notice is the user's only copy
      // of why they were actioned.
      testWidgets(
        'withdraws Remove from the sheet for a protected moderation thread',
        (tester) async {
          final l10n = lookupAppLocalizations(const Locale('en'));
          final actionsCubit = _MockConversationActionsCubit();

          await tester.pumpWidget(
            buildSubject(
              actionsCubit: actionsCubit,
              state: ConversationListState(
                status: ConversationListStatus.loaded,
                pinnedSupport: supportPin(
                  isPersisted: true,
                  lastMessageContent: 'We looked into your report',
                ),
              ),
            ),
          );
          when(
            () => actionsCubit.isRemovalProtected(any()),
          ).thenReturn(true);
          await openMessages(tester);

          await tester.longPress(find.text(l10n.inboxSupportRowTitle));
          await tester.pumpAndSettle();

          expect(find.text(l10n.inboxActionRemove), findsNothing);
          // The safety actions the pin inherited are untouched.
          expect(
            find.text(l10n.inboxActionBlock(l10n.inboxSupportRowTitle)),
            findsOneWidget,
          );
          expect(
            find.text(l10n.inboxActionReport(l10n.inboxSupportRowTitle)),
            findsOneWidget,
          );
        },
      );

      // Defence in depth: if the action is reached anyway, the repository
      // still refuses, and a refusal must read as an explanation rather than
      // as an error or a false success.
      testWidgets('explains a refusal instead of reporting success', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        final actionsCubit = _MockConversationActionsCubit();

        await tester.pumpWidget(
          buildSubject(
            actionsCubit: actionsCubit,
            wrapInScaffold: true,
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              pinnedSupport: supportPin(
                isPersisted: true,
                lastMessageContent: 'We looked into your report',
              ),
            ),
          ),
        );
        when(
          () => actionsCubit.removeConversation(any()),
        ).thenAnswer((_) async => RemoveConversationOutcome.refused);
        await openMessages(tester);

        await tester.longPress(find.text(l10n.inboxSupportRowTitle));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.inboxActionRemove));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.inboxRemoveConfirmConfirm));
        await tester.pumpAndSettle();

        expect(
          find.text(l10n.messageRequestModerationNoticeCannotBeRemoved),
          findsOneWidget,
        );
        expect(find.text(l10n.inboxRemovedConversation), findsNothing);
      });

      testWidgets('reports a failed removal instead of staying silent', (
        tester,
      ) async {
        // #7850. `failed` used to `break`, so a Drift throw closed the dialog,
        // showed nothing, and left the row in place — indistinguishable from a
        // mistap. It must also not borrow the refusal copy: a refusal is the
        // guard working, a failure is not.
        final l10n = lookupAppLocalizations(const Locale('en'));
        final actionsCubit = _MockConversationActionsCubit();

        await tester.pumpWidget(
          buildSubject(
            actionsCubit: actionsCubit,
            wrapInScaffold: true,
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              pinnedSupport: supportPin(
                isPersisted: true,
                lastMessageContent: 'We looked into your report',
              ),
            ),
          ),
        );
        when(
          () => actionsCubit.removeConversation(any()),
        ).thenAnswer((_) async => RemoveConversationOutcome.failed);
        await openMessages(tester);

        await tester.longPress(find.text(l10n.inboxSupportRowTitle));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.inboxActionRemove));
        await tester.pumpAndSettle();
        await tester.tap(find.text(l10n.inboxRemoveConfirmConfirm));
        await tester.pumpAndSettle();

        expect(find.text(l10n.commonSomethingWentWrong), findsOneWidget);
        expect(find.text(l10n.inboxRemovedConversation), findsNothing);
        expect(
          find.text(l10n.messageRequestModerationNoticeCannotBeRemoved),
          findsNothing,
        );
      });

      testWidgets(
        'keeps moderation safety actions named when the vanish lookup fails',
        (tester) async {
          final l10n = lookupAppLocalizations(const Locale('en'));
          await tester.pumpWidget(
            buildSubject(
              state: ConversationListState(
                status: ConversationListStatus.loaded,
                pinnedSupport: supportPin(
                  isPersisted: true,
                  lastMessageContent: 'We looked into your report',
                ),
              ),
              additionalOverrides: [
                profileVanishedSnapshotProvider(moderationPubkey).overrideWith(
                  (ref) => Future<bool>.error(StateError('database closed')),
                ),
              ],
            ),
          );
          await openMessages(tester);

          await tester.longPress(find.text(l10n.inboxSupportRowTitle));
          await tester.pumpAndSettle();

          expect(
            find.text(l10n.inboxActionReport(l10n.inboxSupportRowTitle)),
            findsOneWidget,
          );
          expect(
            find.text(l10n.inboxActionBlock(l10n.inboxSupportRowTitle)),
            findsOneWidget,
          );
        },
      );

      testWidgets('keeps safety actions available when identity lookups fail', (
        tester,
      ) async {
        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.pumpWidget(
          buildSubject(
            state: ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: [
                DmConversation(
                  id: 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
                  participantPubkeys: const [currentPubkey, otherPubkey],
                  isGroup: false,
                  createdAt: nowUnix,
                  lastMessageContent: 'Hello',
                  lastMessageTimestamp: nowUnix,
                ),
              ],
              visibleConversations: [
                DmConversation(
                  id: 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
                  participantPubkeys: const [currentPubkey, otherPubkey],
                  isGroup: false,
                  createdAt: nowUnix,
                  lastMessageContent: 'Hello',
                  lastMessageTimestamp: nowUnix,
                ),
              ],
              hasMore: false,
            ),
            additionalOverrides: [
              profileVanishedSnapshotProvider(otherPubkey).overrideWith(
                (ref) => Future<bool>.error(StateError('database closed')),
              ),
              fetchUserProfileProvider(otherPubkey).overrideWith(
                (ref) => Future<UserProfile?>.error(
                  StateError('profile cache closed'),
                ),
              ),
            ],
          ),
        );
        await openMessages(tester);

        await tester.longPress(find.byType(ConversationTile));
        await tester.pumpAndSettle();

        final fallback = UserProfile.defaultDisplayNameFor(otherPubkey);
        expect(find.text(l10n.inboxActionReport(fallback)), findsOneWidget);
        expect(find.text(l10n.inboxActionBlock(fallback)), findsOneWidget);
      });

      testWidgets(
        "survives a search that matches the adopted pin's last message",
        (tester) async {
          final l10n = lookupAppLocalizations(const Locale('en'));
          await tester.pumpWidget(
            buildSubject(
              state: ConversationListState(
                status: ConversationListStatus.loaded,
                searchQuery: 'looked',
                pinnedSupport: supportPin(
                  isPersisted: true,
                  lastMessageContent: 'We looked into your report',
                ),
              ),
            ),
          );
          await openMessages(tester);

          // The bloc's own filter matches name OR preview; matching only the
          // title here hid the row on a query drawn from the team's reply.
          expect(find.text(l10n.inboxSupportRowTitle), findsOneWidget);
        },
      );
    });

    group('report action feedback', () {
      // #6387: reportUser returns false when the report reached no channel
      // off this device. Without an else the user got no feedback at all,
      // which is less than the (false) confirmation it replaced.
      late _MockConversationActionsCubit reportCubit;

      final conversation = DmConversation(
        id: 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
        participantPubkeys: const [currentPubkey, otherPubkey],
        isGroup: false,
        createdAt: nowUnix,
        lastMessageContent: 'Hello',
        lastMessageTimestamp: nowUnix,
      );

      setUp(() {
        reportCubit = _MockConversationActionsCubit();
      });

      Widget buildReportSubject() => buildSubject(
        actionsCubit: reportCubit,
        wrapInScaffold: true,
        state: ConversationListState(
          status: ConversationListStatus.loaded,
          conversations: [conversation],
          visibleConversations: [conversation],
          hasMore: false,
        ),
        additionalOverrides: [
          fetchUserProfileProvider(
            otherPubkey,
          ).overrideWith((ref) async => null),
        ],
      );

      Future<void> longPressAndReport(WidgetTester tester) async {
        await tester.pump();
        await tester.tap(find.text('Messages'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        await tester.longPress(find.byType(ConversationTile));
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(
          find.text(
            l10n.inboxActionReport(
              UserProfile.defaultDisplayNameFor(otherPubkey),
            ),
          ),
        );
        await tester.pumpAndSettle();
      }

      testWidgets('confirms when the report reached a channel', (tester) async {
        when(() => reportCubit.reportUser(any())).thenAnswer((_) async => true);

        await tester.pumpWidget(buildReportSubject());
        await longPressAndReport(tester);

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.text(
            l10n.inboxReportedUser(
              UserProfile.defaultDisplayNameFor(otherPubkey),
            ),
          ),
          findsOneWidget,
        );
      });

      testWidgets('surfaces an error when the report reached no channel', (
        tester,
      ) async {
        when(
          () => reportCubit.reportUser(any()),
        ).thenAnswer((_) async => false);

        await tester.pumpWidget(buildReportSubject());
        await longPressAndReport(tester);

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.reportNotSent), findsOneWidget);
        // Silence is the regression, so the confirmation must not render.
        expect(
          find.text(
            l10n.inboxReportedUser(
              UserProfile.defaultDisplayNameFor(otherPubkey),
            ),
          ),
          findsNothing,
        );
      });
    });

    group('remove confirmation copy', () {
      final conversation = DmConversation(
        id: 'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff',
        participantPubkeys: const [currentPubkey, otherPubkey],
        isGroup: false,
        createdAt: nowUnix,
        lastMessageContent: 'Hello',
        lastMessageTimestamp: nowUnix,
      );

      Widget buildRemoveSubject() => buildSubject(
        wrapInScaffold: true,
        state: ConversationListState(
          status: ConversationListStatus.loaded,
          conversations: [conversation],
          visibleConversations: [conversation],
          hasMore: false,
        ),
        additionalOverrides: [
          fetchUserProfileProvider(
            otherPubkey,
          ).overrideWith((ref) async => null),
        ],
      );

      // The headline of #7881: the confirmation must describe what removing
      // actually does (clears the inbox, a new message reopens it) rather than
      // promise a permanent, irreversible delete the protocol cannot deliver.
      testWidgets('tells the truth about what removing does', (tester) async {
        await tester.pumpWidget(buildRemoveSubject());
        await tester.pump();
        await tester.tap(find.text('Messages'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 350));

        await tester.longPress(find.byType(ConversationTile));
        await tester.pumpAndSettle();

        final l10n = lookupAppLocalizations(const Locale('en'));
        await tester.tap(find.text(l10n.inboxActionRemove));
        await tester.pumpAndSettle();

        expect(find.text(l10n.inboxRemoveConfirmTitle), findsOneWidget);
        expect(
          find.text(
            l10n.inboxRemoveConfirmBody(
              UserProfile.defaultDisplayNameFor(otherPubkey),
            ),
          ),
          findsOneWidget,
        );
      });
    });
  });
}
