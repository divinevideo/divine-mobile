// ABOUTME: Reproduction + regression guard for #7330 — the DM unread badge
// ABOUTME: must not keep rendering the previous account's count after an
// ABOUTME: in-app sign-out/sign-in-as-a-different-account. Drives the REAL
// ABOUTME: AppShellBadgeScope over the REAL dmRepositoryProvider, a real
// ABOUTME: DmRepository and a real in-memory Drift database, stepping
// ABOUTME: nostrSessionProvider through the production phase sequence
// ABOUTME: (nostrReady -> tearingDown -> identityKnown -> nostrReady).

import 'dart:async';
import 'dart:convert';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart' as nostr_filter;
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:notification_repository/notification_repository.dart';
import 'package:openvine/blocs/dm/conversation_list/protected_minor_inbox_gate.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';
import 'package:openvine/notifications/providers/notification_repository_provider.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/providers/official_accounts_providers.dart';
import 'package:openvine/providers/protected_minor_providers.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/app_shell_badge_scope.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockNotificationRepository extends Mock
    implements NotificationRepository {}

class _FakeFilter extends Fake implements nostr_filter.Filter {}

/// Pass-through inbox gate — these tests are about identity scoping, not the
/// protected-minor predicate, so nothing is ever hidden.
class _PassThroughInboxGate implements ProtectedMinorInboxGate {
  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  void notifyRestrictionChanged() {}

  @override
  List<DmConversation> filter(
    List<DmConversation> conversations, {
    required String userPubkey,
  }) => conversations;
}

/// Seeded [NostrSession] whose phase the test drives directly, standing in for
/// `NostrService._handleAuthStateChange`.
class _TestNostrSession extends NostrSession {
  _TestNostrSession(this._initial);

  final NostrSessionReadiness _initial;

  @override
  NostrSessionReadiness build() => stateOrNull ?? _initial;
}

// Full 64-character hex Nostr IDs — never truncate.
const _accountA =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
const _accountB =
    'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3';
const _peerOne =
    'c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4';
const _peerTwo =
    'd4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5';
const _privateKey =
    '0000000000000000000000000000000000000000000000000000000000000001';

void main() {
  setUpAll(() {
    registerFallbackValue(<nostr_filter.Filter>[_FakeFilter()]);
  });

  group(AppShellBadgeScope, () {
    group('in-app account switch (#7330)', () {
      late AppDatabase database;
      late SharedPreferences prefs;
      late _MockNostrClient nostrClient;
      late _MockAuthService authService;
      late StreamController<Event> giftWraps;
      late ProviderContainer container;
      late bool containerDisposed;

      setUp(() async {
        containerDisposed = false;
        database = AppDatabase.test(NativeDatabase.memory());
        SharedPreferences.setMockInitialValues({});
        prefs = await SharedPreferences.getInstance();

        nostrClient = _MockNostrClient();
        authService = _MockAuthService();
        // A stream that stays open. `Stream.empty()` completes immediately,
        // which DmRepository reads as a dropped relay subscription and answers
        // with its 2s reconnect timer, on a loop.
        giftWraps = StreamController<Event>.broadcast();

        when(() => nostrClient.connectedRelayCount).thenReturn(1);
        when(() => nostrClient.configuredRelayCount).thenReturn(1);
        when(() => nostrClient.hasKeys).thenReturn(true);
        when(() => nostrClient.publicKey).thenReturn(_accountA);
        when(
          () => nostrClient.signer,
        ).thenReturn(LocalNostrSigner(_privateKey));
        when(
          () => nostrClient.subscribe(
            any(),
            subscriptionId: any(named: 'subscriptionId'),
            onStoredEventsStart: any(named: 'onStoredEventsStart'),
            onStoredEventsEnd: any(named: 'onStoredEventsEnd'),
          ),
        ).thenAnswer((_) => giftWraps.stream);
        when(() => nostrClient.queryEvents(any())).thenAnswer((_) async => []);
        when(() => nostrClient.unsubscribe(any())).thenAnswer((_) async {});

        when(() => authService.isAuthenticated).thenReturn(true);
        when(() => authService.currentPublicKeyHex).thenReturn(_accountA);
        when(() => authService.currentIdentity).thenReturn(null);
        when(() => authService.userRelays).thenReturn(const []);
        when(
          () => authService.authStateStream,
        ).thenAnswer((_) => const Stream<AuthState>.empty());
      });

      tearDown(() async {
        await giftWraps.close();
        await database.close();
      });

      _MockFollowRepository buildFollow() {
        final follow = _MockFollowRepository();
        when(
          () => follow.followingStream,
        ).thenAnswer((_) => const Stream<List<String>>.empty());
        when(() => follow.isFollowing(any())).thenReturn(false);
        return follow;
      }

      _MockContentBlocklistRepository buildBlocklist() {
        final blocklist = _MockContentBlocklistRepository();
        when(
          () => blocklist.stateStream,
        ).thenAnswer((_) => const Stream<ContentPolicyState>.empty());
        when(
          () => blocklist.filterBlockedConversations(
            any(),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer(
          (invocation) =>
              invocation.positionalArguments.first as List<DmConversation>,
        );
        return blocklist;
      }

      _MockNotificationRepository buildNotification() {
        final repo = _MockNotificationRepository();
        when(
          repo.watchUnreadCount,
        ).thenAnswer((_) => const Stream<int>.empty());
        return repo;
      }

      /// Persists an unread, already-accepted conversation owned by [owner] —
      /// the row shape the DM ingest path writes.
      ///
      /// Two owners' conversations coexist in production: an account switch
      /// keeps the departing account's conversation rows for its return
      /// (#10276). Seeding both proves the badge counts by owner rather than
      /// by row count.
      Future<void> seedUnreadConversation({
        required String id,
        required String owner,
        required String peer,
      }) {
        return database.conversationsDao.upsertConversation(
          id: id,
          participantPubkeys: jsonEncode([owner, peer]),
          isGroup: false,
          createdAt: 1700000000,
          lastMessageTimestamp: 1700000000,
          lastMessageContent: 'hello',
          lastMessageSenderPubkey: peer,
          isRead: false,
          currentUserHasSent: true,
          ownerPubkey: owner,
        );
      }

      void disposeContainerOnce() {
        if (containerDisposed) return;
        containerDisposed = true;
        container.dispose();
      }

      Future<void> pumpScope(WidgetTester tester) async {
        container = ProviderContainer(
          overrides: [
            nostrServiceProvider.overrideWithValue(nostrClient),
            authServiceProvider.overrideWithValue(authService),
            currentAuthStateProvider.overrideWithValue(AuthState.authenticated),
            nostrSessionProvider.overrideWith(
              () => _TestNostrSession(
                NostrSessionReadiness.nostrReady(
                  pubkey: _accountA,
                  client: nostrClient,
                ),
              ),
            ),
            databaseProvider.overrideWithValue(database),
            sharedPreferencesProvider.overrideWithValue(prefs),
            followRepositoryProvider.overrideWithValue(buildFollow()),
            contentBlocklistRepositoryProvider.overrideWithValue(
              buildBlocklist(),
            ),
            protectedMinorInboxGateProvider.overrideWithValue(
              _PassThroughInboxGate(),
            ),
            notificationRepositoryProvider.overrideWithValue(
              buildNotification(),
            ),
            isDmRestrictedProvider.overrideWithValue(false),
          ],
        );
        // Safety net: a failing expectation skips [disposeSession], and a
        // leaked DmRepository reconnect timer then stalls the whole run for
        // minutes instead of failing fast.
        addTearDown(disposeContainerOnce);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: AppShellBadgeScope(
              child: BlocBuilder<DmUnreadCountCubit, int>(
                builder: (context, count) =>
                    Text('badge=$count', textDirection: TextDirection.ltr),
              ),
            ),
          ),
        );
      }

      /// Tears the session down inside the test body. `DmRepository` arms a
      /// reconnect timer while it is listening and cancelling a Drift query
      /// stream posts a zero-duration `markAsClosed` timer — and the widget
      /// invariant that fails on a pending timer runs before `tearDown` does,
      /// so both have to be flushed here. Disposing the container is what
      /// stops the repository: `dmRepositoryProvider` registers
      /// `ref.onDispose(repository.stopListening)`.
      Future<void> disposeSession(WidgetTester tester) async {
        if (containerDisposed) return;
        await tester.pumpWidget(const SizedBox.shrink());
        disposeContainerOnce();
        await tester.pump(const Duration(milliseconds: 1));
      }

      /// Steps the session exactly as `NostrService._handleAuthStateChange`
      /// does when the signed-in pubkey changes: tear the old client down,
      /// publish the new identity, and only reach `nostrReady` once the new
      /// client has finished initializing.
      void driveSessionTo(NostrSessionReadiness readiness) {
        container.read(nostrSessionProvider.notifier).update(readiness);
      }

      Future<void> switchToAccountB(WidgetTester tester) async {
        when(() => nostrClient.publicKey).thenReturn(_accountB);
        when(() => authService.currentPublicKeyHex).thenReturn(_accountB);
        driveSessionTo(
          const NostrSessionReadiness.tearingDown(pubkey: _accountA),
        );
        await tester.pump();
        driveSessionTo(
          const NostrSessionReadiness.identityKnown(pubkey: _accountB),
        );
        await tester.pump(const Duration(milliseconds: 250));
      }

      testWidgets(
        'drops the previous account unread count while the incoming account '
        'is identity-known but not yet nostr-ready',
        (tester) async {
          await seedUnreadConversation(
            id: 'a-convo',
            owner: _accountA,
            peer: _peerOne,
          );
          await pumpScope(tester);
          await tester.pump(const Duration(milliseconds: 250));

          // Account A is signed in with one unread accepted conversation.
          expect(find.text('badge=1'), findsOneWidget);

          // The user signs out and signs straight back in as account B. This
          // path does not rebuild the Riverpod container, so the badge cubit
          // above MaterialApp survives holding account A's count.
          await switchToAccountB(tester);

          // Account B owns no conversations. The badge must not advertise
          // account A's unread messages to them.
          expect(find.text('badge=0'), findsOneWidget);
          expect(find.text('badge=1'), findsNothing);

          await disposeSession(tester);
        },
      );

      testWidgets(
        'counts the incoming account own unread conversations as soon as the '
        'identity is known',
        (tester) async {
          await seedUnreadConversation(
            id: 'a-convo',
            owner: _accountA,
            peer: _peerOne,
          );
          await seedUnreadConversation(
            id: 'b-convo-1',
            owner: _accountB,
            peer: _peerOne,
          );
          await seedUnreadConversation(
            id: 'b-convo-2',
            owner: _accountB,
            peer: _peerTwo,
          );
          await pumpScope(tester);
          await tester.pump(const Duration(milliseconds: 250));

          expect(find.text('badge=1'), findsOneWidget);

          await switchToAccountB(tester);

          // Identity is enough to scope local storage. Account A's unread is
          // gone and account B's two are visible without waiting for the
          // signer/client to become ready.
          expect(find.text('badge=2'), findsOneWidget);

          driveSessionTo(
            NostrSessionReadiness.nostrReady(
              pubkey: _accountB,
              client: nostrClient,
            ),
          );
          await tester.pump(const Duration(milliseconds: 250));

          // Full client readiness must preserve the already-correct local
          // count while it enables relay-backed work.
          expect(find.text('badge=2'), findsOneWidget);

          await disposeSession(tester);
        },
      );
    });
  });
}
