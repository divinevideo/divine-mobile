// ABOUTME: Tests for ConversationListBloc - DM conversation list management.
// ABOUTME: Tests loading conversations via split streams (accepted + potential
// ABOUTME: requests), error handling, marking conversations as read, message
// ABOUTME: request classification, and event transformer behavior.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation_list/conversation_list_bloc.dart';
import 'package:openvine/blocs/dm/conversation_list/protected_minor_inbox_gate.dart';
import 'package:openvine/blocs/dm/dm_peer_name.dart';
import 'package:openvine/config/official_accounts.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:profile_repository/profile_repository.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockProfileRepository extends Mock implements ProfileRepository {}

// Full 64-character hex Nostr IDs for test data.
const _testConversationId1 =
    'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
const _testConversationId2 =
    'b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3';
const _testPubkey1 =
    'c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4';
const _testPubkey2 =
    'd4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5';
const _testPubkey3 =
    'e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6';

/// Approves a fixed set of counterparties; a conversation is visible only when
/// every non-self participant is approved. `changes` never emits (C1).
class _FakeInboxGate implements ProtectedMinorInboxGate {
  _FakeInboxGate({required this.approved});
  final Set<String> approved;

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  void notifyRestrictionChanged() {}

  @override
  List<DmConversation> filter(
    List<DmConversation> conversations, {
    required String userPubkey,
  }) {
    return conversations
        .where(
          (c) => c.participantPubkeys
              .where((p) => p != userPubkey)
              .every(approved.contains),
        )
        .toList();
  }
}

/// A gate whose approval set can change at runtime; revoking emits on [changes]
/// so the bloc must re-filter (models receive-time revalidation).
class _MutableInboxGate implements ProtectedMinorInboxGate {
  _MutableInboxGate(Set<String> approved) : _approved = approved;
  Set<String> _approved;
  final StreamController<void> _changes = StreamController<void>.broadcast();

  void revoke(String pubkey) {
    _approved = {..._approved}..remove(pubkey);
    _changes.add(null);
  }

  @override
  Stream<void> get changes => _changes.stream;

  @override
  void notifyRestrictionChanged() => _changes.add(null);

  @override
  List<DmConversation> filter(
    List<DmConversation> conversations, {
    required String userPubkey,
  }) {
    return conversations
        .where(
          (c) => c.participantPubkeys
              .where((p) => p != userPubkey)
              .every(_approved.contains),
        )
        .toList();
  }
}

DmConversation _createConversation({
  required String id,
  bool isRead = true,
  bool isGroup = false,
  bool currentUserHasSent = false,
  List<String>? participantPubkeys,
  String lastMessageContent = 'Hello',
  int lastMessageTimestamp = 1700000100,
  String? subject,
}) {
  return DmConversation(
    id: id,
    participantPubkeys:
        participantPubkeys ?? const [_testPubkey1, _testPubkey2],
    isGroup: isGroup,
    subject: subject,
    createdAt: 1700000000,
    lastMessageContent: lastMessageContent,
    lastMessageTimestamp: lastMessageTimestamp,
    lastMessageSenderPubkey: _testPubkey1,
    isRead: isRead,
    currentUserHasSent: currentUserHasSent,
  );
}

/// Stubs both split streams on the mock repository.
///
/// [accepted] goes to `watchAcceptedConversations` (currentUserHasSent=true).
/// [potentialRequests] goes to `watchPotentialRequests` (currentUserHasSent=false).
void _stubStreams(
  _MockDmRepository repo, {
  List<DmConversation> accepted = const [],
  List<DmConversation> potentialRequests = const [],
  Stream<bool>? recoveryStream,
  bool isRecovering = false,
  bool recoveryComplete = true,
}) {
  when(
    () => repo.watchAcceptedConversations(limit: any(named: 'limit')),
  ).thenAnswer((_) => Stream.value(accepted));
  when(
    () => repo.watchPotentialRequests(),
  ).thenAnswer((_) => Stream.value(potentialRequests));
  when(() => repo.isRecoveringHistory).thenReturn(isRecovering);
  // Recovery-aware request gate (#5304): defaults to "complete" so the normal
  // follow-based split applies; gate tests pass `recoveryComplete: false`.
  when(
    () => repo.hasCompletedHistoryRecoveryBefore,
  ).thenReturn(recoveryComplete);
  when(
    () => repo.historyRecoveryStream,
  ).thenAnswer((_) => recoveryStream ?? const Stream<bool>.empty());
  // Identity stream (#5374): seeded via `.startWith(userPubkey)` in the bloc.
  when(() => repo.userPubkey).thenReturn(_testPubkey1);
  when(
    () => repo.userPubkeyStream,
  ).thenAnswer((_) => const Stream<String>.empty());
}

void main() {
  group(ConversationListBloc, () {
    late _MockDmRepository mockDmRepository;
    late _MockFollowRepository mockFollowRepository;

    setUp(() {
      mockDmRepository = _MockDmRepository();
      mockFollowRepository = _MockFollowRepository();

      // Default: all pubkeys are followed (existing tests expect no splitting).
      when(() => mockFollowRepository.isFollowing(any())).thenReturn(true);
      when(
        () => mockFollowRepository.followingStream,
      ).thenAnswer((_) => const Stream<List<String>>.empty());
      when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey1);
      // Identity stream (#5374): seeded via `.startWith(userPubkey)` in the
      // bloc, so an empty stream is enough for the steady-state value to flow.
      when(
        () => mockDmRepository.userPubkeyStream,
      ).thenAnswer((_) => const Stream<String>.empty());
      // Recovery-aware request gate (#5304): default to "recovery complete"
      // so existing split assertions hold; gate tests override to false.
      when(
        () => mockDmRepository.hasCompletedHistoryRecoveryBefore,
      ).thenReturn(true);

      // Stub subscription lifecycle methods (#2766).
      when(() => mockDmRepository.startListening()).thenAnswer((_) async {});
      when(() => mockDmRepository.stopListening()).thenAnswer((_) async {});
      // One-time history drain fired on every inbox open (#4953).
      when(
        () => mockDmRepository.backfillHistoryIfNeeded(),
      ).thenAnswer((_) async {});
      // Failed-decrypt retry pass, also fired on every inbox open (#5202).
      when(
        () => mockDmRepository.retryPendingDecryptions(),
      ).thenAnswer((_) async {});
    });

    ConversationListBloc createBloc() => ConversationListBloc(
      dmRepository: mockDmRepository,
      followRepository: mockFollowRepository,
      // These tests assert state sequences/content, not coalescing timing, so
      // disable the recompute debounce for deterministic, prompt emissions.
      // The debounce itself is covered by a dedicated coalescing test.
      recomputeDebounce: Duration.zero,
    );

    group('blocked chats (#7025)', () {
      /// Behaves like the real repository: drop any conversation whose
      /// counterparty the viewer blocked, and report those pubkeys.
      _MockContentBlocklistRepository blocklistBlocking(Set<String> blocked) {
        final blocklist = _MockContentBlocklistRepository();
        when(() => blocklist.runtimeBlockedUsers).thenReturn(blocked);
        when(
          () => blocklist.filterBlockedConversations(
            any(),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((inv) {
          final input = inv.positionalArguments.first as List<DmConversation>;
          return input
              .where((c) => !c.participantPubkeys.any(blocked.contains))
              .toList();
        });
        return blocklist;
      }

      ConversationListBloc createBlocWith(
        ContentBlocklistRepository blocklist,
      ) => ConversationListBloc(
        dmRepository: mockDmRepository,
        followRepository: mockFollowRepository,
        contentBlocklistRepository: blocklist,
        recomputeDebounce: Duration.zero,
      );

      Future<ConversationListState> load(ConversationListBloc bloc) {
        bloc.add(const ConversationListStarted());
        return bloc.stream.firstWhere(
          (s) => s.status == ConversationListStatus.loaded,
        );
      }

      test('keeps a blocked conversation instead of dropping it', () async {
        _stubStreams(
          mockDmRepository,
          accepted: [_createConversation(id: _testConversationId1)],
        );
        final bloc = createBlocWith(blocklistBlocking({_testPubkey2}));
        addTearDown(bloc.close);

        final state = await load(bloc);

        expect(
          state.conversations,
          isEmpty,
          reason: 'the inbox still hides it — that is the block working',
        );
        expect(
          state.blockedConversations.map((c) => c.id),
          equals([_testConversationId1]),
          reason: 'but the viewer keeps their own copy to read as evidence',
        );
      });

      test('surfaces them only under the Blocked filter', () async {
        _stubStreams(
          mockDmRepository,
          accepted: [_createConversation(id: _testConversationId1)],
        );
        final bloc = createBlocWith(blocklistBlocking({_testPubkey2}));
        addTearDown(bloc.close);

        final loaded = await load(bloc);
        expect(loaded.visibleConversations, isEmpty);

        bloc.add(const ConversationListFilterChanged(InboxFilter.blocked));
        final state = await bloc.stream.firstWhere(
          (s) => s.filter == InboxFilter.blocked,
        );

        expect(
          state.visibleConversations.map((c) => c.id),
          equals([_testConversationId1]),
        );
      });

      test('lists a blocked account the viewer never messaged', () async {
        _stubStreams(mockDmRepository);
        final bloc = createBlocWith(blocklistBlocking({_testPubkey3}));
        addTearDown(bloc.close);

        final state = await load(bloc);

        final row = state.blockedConversations.single;
        expect(row.participantPubkeys, contains(_testPubkey3));
        expect(
          row.lastMessageTimestamp,
          isNull,
          reason: 'the inbox renders this row inert, with no thread to open',
        );
      });

      test(
        'keeps a blocked 1:1 that a group would otherwise displace',
        () async {
          // `filterBlockedConversations` drops a group whose first non-self
          // participant is blocked, so if the group took the account's only
          // slot the 1:1 appeared in no list at all — the exact evidence loss
          // this feature exists to prevent.
          final direct = _createConversation(id: _testConversationId1);
          final group = _createConversation(
            id: _testConversationId2,
            isGroup: true,
            participantPubkeys: const [
              _testPubkey1,
              _testPubkey2,
              _testPubkey3,
            ],
          );
          _stubStreams(mockDmRepository, accepted: [group, direct]);
          final bloc = createBlocWith(blocklistBlocking({_testPubkey2}));
          addTearDown(bloc.close);

          final state = await load(bloc);

          expect(
            state.blockedConversations.map((c) => c.id),
            containsAll([_testConversationId1, _testConversationId2]),
          );
        },
      );

      test(
        'resolves names for blocked counterparties so search matches',
        () async {
          // `conversations` never contains a blocked counterparty, so resolving
          // only that list left the Blocked slice searchable by the generated
          // fallback name while the row rendered the real one.
          _stubStreams(
            mockDmRepository,
            accepted: [_createConversation(id: _testConversationId1)],
          );
          final profiles = _MockProfileRepository();
          when(
            () => profiles.fetchBatchProfiles(pubkeys: any(named: 'pubkeys')),
          ).thenAnswer((_) async => const <String, UserProfile>{});
          when(
            profiles.watchVanishedPubkeys,
          ).thenAnswer((_) => Stream.value(const <String>{}));

          final bloc = ConversationListBloc(
            dmRepository: mockDmRepository,
            followRepository: mockFollowRepository,
            contentBlocklistRepository: blocklistBlocking({_testPubkey2}),
            profileRepository: profiles,
            recomputeDebounce: Duration.zero,
          );
          addTearDown(bloc.close);
          await load(bloc);

          bloc.add(const ConversationListSearchQueryChanged('zzzz'));
          final state = await bloc.stream.firstWhere(
            (s) => s.profileNames.isNotEmpty,
          );

          expect(
            state.profileNames.keys,
            contains(_testPubkey2),
            reason: 'the blocked counterparty must be resolvable by name',
          );
        },
      );

      test('falls back to All when the last block is lifted', () async {
        final acceptedController = StreamController<List<DmConversation>>();
        addTearDown(acceptedController.close);
        when(
          () => mockDmRepository.watchAcceptedConversations(
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) => acceptedController.stream);
        when(
          () => mockDmRepository.watchPotentialRequests(),
        ).thenAnswer((_) => Stream.value(const <DmConversation>[]));
        when(
          () => mockDmRepository.historyRecoveryStream,
        ).thenAnswer((_) => const Stream<bool>.empty());
        when(() => mockDmRepository.isRecoveringHistory).thenReturn(false);

        final blocked = {_testPubkey2};
        final blocklist = _MockContentBlocklistRepository();
        when(() => blocklist.runtimeBlockedUsers).thenAnswer((_) => blocked);
        when(
          () => blocklist.filterBlockedConversations(
            any(),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((inv) {
          final input = inv.positionalArguments.first as List<DmConversation>;
          return input
              .where((c) => !c.participantPubkeys.any(blocked.contains))
              .toList();
        });

        final bloc = createBlocWith(blocklist);
        addTearDown(bloc.close);
        bloc.add(const ConversationListStarted());
        final conversation = _createConversation(id: _testConversationId1);
        acceptedController.add([conversation]);
        await bloc.stream.firstWhere(
          (s) => s.blockedConversations.isNotEmpty,
        );

        bloc.add(const ConversationListFilterChanged(InboxFilter.blocked));
        await bloc.stream.firstWhere((s) => s.filter == InboxFilter.blocked);

        blocked.clear();
        acceptedController.add([conversation]);
        final state = await bloc.stream.firstWhere(
          (s) => s.blockedConversations.isEmpty,
        );

        expect(
          state.filter,
          equals(InboxFilter.all),
          reason: 'the Blocked chip is gone, so the filter cannot stay on it',
        );
        expect(
          state.visibleConversations.map((c) => c.id),
          equals([_testConversationId1]),
          reason: 'the unblocked conversation returns to the inbox',
        );
      });
    });

    group('protected-minor inbound filter (#176)', () {
      test(
        'hides inbox conversations whose counterparty is not approved',
        () async {
          final approvedConv = _createConversation(
            id: 'a',
            currentUserHasSent: true,
            participantPubkeys: const [_testPubkey1, _testPubkey2],
          );
          final blockedConv = _createConversation(
            id: 'b',
            currentUserHasSent: true,
            participantPubkeys: const [_testPubkey1, _testPubkey3],
          );
          _stubStreams(
            mockDmRepository,
            accepted: [approvedConv, blockedConv],
          );

          final bloc = ConversationListBloc(
            dmRepository: mockDmRepository,
            followRepository: mockFollowRepository,
            protectedMinorInboxGate: _FakeInboxGate(approved: {_testPubkey2}),
            recomputeDebounce: Duration.zero,
          )..add(const ConversationListStarted());
          addTearDown(bloc.close);

          final state = await bloc.stream.firstWhere(
            (s) => s.status == ConversationListStatus.loaded,
          );
          expect(state.conversations.map((c) => c.id).toList(), ['a']);
        },
      );

      test(
        'hides request conversations whose counterparty is not approved',
        () async {
          when(() => mockFollowRepository.isFollowing(any())).thenReturn(false);
          final blockedReq = _createConversation(
            id: 'r',
            participantPubkeys: const [_testPubkey1, _testPubkey3],
          );
          _stubStreams(mockDmRepository, potentialRequests: [blockedReq]);

          final bloc = ConversationListBloc(
            dmRepository: mockDmRepository,
            followRepository: mockFollowRepository,
            protectedMinorInboxGate: _FakeInboxGate(approved: {_testPubkey2}),
            recomputeDebounce: Duration.zero,
          )..add(const ConversationListStarted());
          addTearDown(bloc.close);

          final state = await bloc.stream.firstWhere(
            (s) => s.status == ConversationListStatus.loaded,
          );
          expect(state.requestConversations, isEmpty);
        },
      );

      test(
        're-filters when the gate signals a revocation (receive-time revalidation)',
        () async {
          final conv = _createConversation(
            id: 'c',
            currentUserHasSent: true,
            participantPubkeys: const [_testPubkey1, _testPubkey2],
          );
          // Single-subscription (buffering) so the value survives until the bloc
          // subscribes; a broadcast controller would drop it and the list would
          // never populate.
          final acceptedController = StreamController<List<DmConversation>>();
          addTearDown(acceptedController.close);
          when(
            () => mockDmRepository.watchAcceptedConversations(
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) => acceptedController.stream);
          when(
            () => mockDmRepository.watchPotentialRequests(),
          ).thenAnswer((_) => Stream.value(const <DmConversation>[]));
          when(
            () => mockDmRepository.historyRecoveryStream,
          ).thenAnswer((_) => const Stream<bool>.empty());
          when(() => mockDmRepository.isRecoveringHistory).thenReturn(false);

          final gate = _MutableInboxGate({_testPubkey2});
          final bloc = ConversationListBloc(
            dmRepository: mockDmRepository,
            followRepository: mockFollowRepository,
            protectedMinorInboxGate: gate,
            recomputeDebounce: Duration.zero,
          )..add(const ConversationListStarted());
          addTearDown(bloc.close);

          final visible = bloc.stream.firstWhere(
            (state) => state.status == ConversationListStatus.loaded,
          );
          acceptedController.add([conv]);
          final visibleState = await visible;
          expect(
            visibleState.conversations.map((c) => c.id).toList(),
            ['c'],
            reason: 'approved counterparty is visible before revocation',
          );

          // A revocation fires the gate's changes stream; the list must re-filter
          // and drop the now-unapproved counterparty without any new DAO write.
          final revoked = bloc.stream.firstWhere(
            (state) => state.conversations.isEmpty,
          );
          gate.revoke(_testPubkey2);
          expect(
            (await revoked).conversations,
            isEmpty,
            reason: 'a verdict flip re-filters the list without a DAO write',
          );
        },
      );

      test(
        'a group hidden unless every non-self participant is approved',
        () async {
          final groupConv = _createConversation(
            id: 'g',
            isGroup: true,
            currentUserHasSent: true,
            participantPubkeys: const [
              _testPubkey1,
              _testPubkey2,
              _testPubkey3,
            ],
          );
          _stubStreams(mockDmRepository, accepted: [groupConv]);

          final bloc = ConversationListBloc(
            dmRepository: mockDmRepository,
            followRepository: mockFollowRepository,
            // _testPubkey2 approved, _testPubkey3 not -> group hidden.
            protectedMinorInboxGate: _FakeInboxGate(approved: {_testPubkey2}),
            recomputeDebounce: Duration.zero,
          )..add(const ConversationListStarted());
          addTearDown(bloc.close);

          final state = await bloc.stream.firstWhere(
            (s) => s.status == ConversationListStatus.loaded,
          );
          expect(state.conversations, isEmpty);
        },
      );
    });

    test(
      'initial state is $ConversationListState with initial status',
      () async {
        final bloc = createBloc();

        expect(bloc.state, equals(const ConversationListState()));
        expect(bloc.state.status, equals(ConversationListStatus.initial));
        expect(bloc.state.conversations, equals(const <DmConversation>[]));

        await bloc.close();
      },
    );

    test(
      'coalesces a burst of conversation writes into a single recompute '
      '(debounce)',
      () async {
        final acceptedController =
            StreamController<List<DmConversation>>.broadcast();
        addTearDown(acceptedController.close);
        when(
          () => mockDmRepository.watchAcceptedConversations(
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) => acceptedController.stream);
        // combineLatest5 needs every source to emit at least once; potential
        // emits a single empty value (the others use startWith in the bloc).
        when(
          () => mockDmRepository.watchPotentialRequests(),
        ).thenAnswer((_) => Stream.value(const <DmConversation>[]));
        when(
          () => mockDmRepository.historyRecoveryStream,
        ).thenAnswer((_) => const Stream<bool>.empty());
        when(() => mockDmRepository.isRecoveringHistory).thenReturn(false);

        // filterBlockedConversations runs once per `onData` pass (inbox +
        // requests = 2 calls), so it doubles as a recompute counter.
        var filterCalls = 0;
        final blocklist = _MockContentBlocklistRepository();
        when(
          () => blocklist.runtimeBlockedUsers,
        ).thenReturn(const <String>{});
        when(
          () => blocklist.filterBlockedConversations(
            any(),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((inv) {
          filterCalls++;
          return inv.positionalArguments.first as List<DmConversation>;
        });

        final bloc = ConversationListBloc(
          dmRepository: mockDmRepository,
          followRepository: mockFollowRepository,
          contentBlocklistRepository: blocklist,
          recomputeDebounce: const Duration(milliseconds: 100),
        )..add(const ConversationListStarted());
        addTearDown(bloc.close);

        // Let _onStarted subscribe to the (broadcast) streams before the burst,
        // otherwise events emitted pre-subscription are dropped.
        await Future<void>.delayed(const Duration(milliseconds: 10));

        final convos = [
          _createConversation(
            id: _testConversationId1,
            isRead: false,
            currentUserHasSent: true,
          ),
        ];
        // Five rapid accepted-list updates inside the debounce window.
        for (var i = 0; i < 5; i++) {
          acceptedController.add(convos);
        }

        // Still inside the window: the expensive pass has not run yet.
        await Future<void>.delayed(const Duration(milliseconds: 20));
        expect(filterCalls, equals(0));

        // After the window settles: exactly one recompute (inbox + requests
        // filtered once each) for the whole burst, not two per write.
        await Future<void>.delayed(const Duration(milliseconds: 150));
        expect(filterCalls, equals(2));
        expect(bloc.state.status, equals(ConversationListStatus.loaded));
      },
    );

    group('ConversationListStarted', () {
      blocTest<ConversationListBloc, ConversationListState>(
        'triggers the one-time DM history drain on open (#4953)',
        setUp: () {
          _stubStreams(mockDmRepository);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ConversationListStarted()),
        verify: (_) {
          verify(() => mockDmRepository.backfillHistoryIfNeeded()).called(1);
        },
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'surfaces history-recovery progress as isRestoringHistory (#5202)',
        setUp: () {
          _stubStreams(
            mockDmRepository,
            recoveryStream: Stream.value(true),
            isRecovering: true,
          );
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ConversationListStarted()),
        verify: (bloc) {
          expect(bloc.state.isRestoringHistory, isTrue);
        },
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'isRestoringHistory is false when no recovery is running',
        setUp: () {
          _stubStreams(mockDmRepository);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ConversationListStarted()),
        verify: (bloc) {
          expect(bloc.state.isRestoringHistory, isFalse);
        },
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'emits [loading, loaded] when stream emits conversations',
        setUp: () {
          final conversations = [
            _createConversation(id: _testConversationId1),
            _createConversation(id: _testConversationId2),
          ];
          // Default currentUserHasSent=false → potential requests.
          // Default isFollowing=true → classified as followed.
          _stubStreams(mockDmRepository, potentialRequests: conversations);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ConversationListStarted()),
        expect: () => [
          const ConversationListState(status: ConversationListStatus.loading),
          ConversationListState(
            status: ConversationListStatus.loaded,
            conversations: [
              _createConversation(id: _testConversationId1),
              _createConversation(id: _testConversationId2),
            ],
            visibleConversations: [
              _createConversation(id: _testConversationId1),
              _createConversation(id: _testConversationId2),
            ],
            potentialRequests: [
              _createConversation(id: _testConversationId1),
              _createConversation(id: _testConversationId2),
            ],
            hasMore: false,
          ),
        ],
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'emits [loading, loaded] with empty list '
        'when stream emits no conversations',
        setUp: () {
          _stubStreams(mockDmRepository);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ConversationListStarted()),
        expect: () => [
          const ConversationListState(status: ConversationListStatus.loading),
          const ConversationListState(
            status: ConversationListStatus.loaded,
            hasMore: false,
          ),
        ],
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'emits [loading, error] when accepted stream emits an error',
        setUp: () {
          when(
            () => mockDmRepository.watchAcceptedConversations(
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) => Stream.error(Exception('db failure')));
          when(
            () => mockDmRepository.watchPotentialRequests(),
          ).thenAnswer((_) => Stream.value(const []));
          when(() => mockDmRepository.isRecoveringHistory).thenReturn(false);
          when(
            () => mockDmRepository.historyRecoveryStream,
          ).thenAnswer((_) => const Stream<bool>.empty());
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ConversationListStarted()),
        errors: () => [isA<Exception>()],
        expect: () => [
          const ConversationListState(status: ConversationListStatus.loading),
          const ConversationListState(status: ConversationListStatus.error),
        ],
      );

      // Retry from InboxErrorState. Without an error -> loading transition the
      // tap produced no state change at all: a repeat failure re-emits an
      // Equatable-equal error state, which `emit` suppresses, so the screen
      // looked identical before and after the tap.
      blocTest<ConversationListBloc, ConversationListState>(
        'retry from error emits loading so a repeat failure is visible',
        setUp: () {
          when(
            () => mockDmRepository.watchAcceptedConversations(
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) => Stream.error(Exception('db failure')));
          when(
            () => mockDmRepository.watchPotentialRequests(),
          ).thenAnswer((_) => Stream.value(const []));
          when(() => mockDmRepository.isRecoveringHistory).thenReturn(false);
          when(
            () => mockDmRepository.historyRecoveryStream,
          ).thenAnswer((_) => const Stream<bool>.empty());
        },
        build: createBloc,
        seed: () =>
            const ConversationListState(status: ConversationListStatus.error),
        act: (bloc) => bloc.add(const ConversationListStarted()),
        errors: () => [isA<Exception>()],
        expect: () => [
          const ConversationListState(status: ConversationListStatus.loading),
          const ConversationListState(status: ConversationListStatus.error),
        ],
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'retry preserves the render window the user had scrolled to',
        setUp: () {
          when(
            () => mockDmRepository.watchAcceptedConversations(
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) => Stream.error(Exception('db failure')));
          when(
            () => mockDmRepository.watchPotentialRequests(),
          ).thenAnswer((_) => Stream.value(const []));
          when(() => mockDmRepository.isRecoveringHistory).thenReturn(false);
          when(
            () => mockDmRepository.historyRecoveryStream,
          ).thenAnswer((_) => const Stream<bool>.empty());
        },
        build: createBloc,
        seed: () => const ConversationListState(
          status: ConversationListStatus.error,
          currentLimit: ConversationListState.pageSize * 3,
        ),
        act: (bloc) => bloc.add(const ConversationListStarted()),
        errors: () => [isA<Exception>()],
        verify: (bloc) {
          expect(
            bloc.state.currentLimit,
            equals(ConversationListState.pageSize * 3),
          );
        },
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'loaded state contains the correct conversations',
        setUp: () {
          final conversation = _createConversation(
            id: _testConversationId1,
            isRead: false,
          );
          _stubStreams(mockDmRepository, potentialRequests: [conversation]);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ConversationListStarted()),
        verify: (bloc) {
          expect(bloc.state.conversations, hasLength(1));
          expect(
            bloc.state.conversations.first.id,
            equals(_testConversationId1),
          );
          expect(bloc.state.conversations.first.isRead, isFalse);
          expect(
            bloc.state.conversations.first.participantPubkeys,
            equals([_testPubkey1, _testPubkey2]),
          );
        },
      );

      test(
        'emits updated state when streams emit multiple values',
        () async {
          final acceptedSubscribed = Completer<void>();
          final requestsSubscribed = Completer<void>();
          final acceptedController = StreamController<List<DmConversation>>(
            onListen: acceptedSubscribed.complete,
          );
          final requestsController = StreamController<List<DmConversation>>(
            onListen: requestsSubscribed.complete,
          );

          when(
            () => mockDmRepository.watchAcceptedConversations(
              limit: any(named: 'limit'),
            ),
          ).thenAnswer((_) => acceptedController.stream);
          when(
            () => mockDmRepository.watchPotentialRequests(),
          ).thenAnswer((_) => requestsController.stream);
          when(() => mockDmRepository.isRecoveringHistory).thenReturn(false);
          when(
            () => mockDmRepository.historyRecoveryStream,
          ).thenAnswer((_) => const Stream<bool>.empty());

          final firstConversation = _createConversation(
            id: _testConversationId1,
            currentUserHasSent: true,
          );
          final secondConversation = _createConversation(
            id: _testConversationId2,
            currentUserHasSent: true,
          );
          final emitted = <ConversationListState>[];
          final loadingEmitted = Completer<void>();
          final firstLoadedEmitted = Completer<void>();
          final secondLoadedEmitted = Completer<void>();

          final bloc = createBloc();
          late final StreamSubscription<ConversationListState> subscription;
          subscription = bloc.stream.listen((state) {
            emitted.add(state);
            if (!loadingEmitted.isCompleted &&
                state.status == ConversationListStatus.loading) {
              loadingEmitted.complete();
            }
            if (!firstLoadedEmitted.isCompleted &&
                state.status == ConversationListStatus.loaded &&
                state.conversations.length == 1) {
              firstLoadedEmitted.complete();
            }
            if (!secondLoadedEmitted.isCompleted &&
                state.status == ConversationListStatus.loaded &&
                state.conversations.length == 2) {
              secondLoadedEmitted.complete();
            }
          });
          addTearDown(() async {
            await subscription.cancel();
            await bloc.close();
            await acceptedController.close();
            await requestsController.close();
          });

          bloc.add(const ConversationListStarted());
          await loadingEmitted.future.timeout(const Duration(seconds: 2));
          await Future.wait([
            acceptedSubscribed.future,
            requestsSubscribed.future,
          ]).timeout(const Duration(seconds: 2));

          requestsController.add(const []);
          acceptedController.add([firstConversation]);
          await firstLoadedEmitted.future.timeout(const Duration(seconds: 2));

          acceptedController.add([firstConversation, secondConversation]);
          await secondLoadedEmitted.future.timeout(const Duration(seconds: 2));

          expect(emitted, [
            const ConversationListState(status: ConversationListStatus.loading),
            ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: [firstConversation],
              visibleConversations: [firstConversation],
              hasMore: false,
            ),
            ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: [firstConversation, secondConversation],
              visibleConversations: [firstConversation, secondConversation],
              hasMore: false,
            ),
          ]);
        },
      );
    });

    group('ConversationListMarkRead', () {
      blocTest<ConversationListBloc, ConversationListState>(
        'calls repository.markConversationAsRead with correct ID',
        setUp: () {
          when(
            () => mockDmRepository.markConversationAsRead(_testConversationId1),
          ).thenAnswer((_) async {});
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ConversationListMarkRead(_testConversationId1)),
        verify: (_) {
          verify(
            () => mockDmRepository.markConversationAsRead(_testConversationId1),
          ).called(1);
        },
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'does not emit new states',
        setUp: () {
          when(
            () => mockDmRepository.markConversationAsRead(_testConversationId1),
          ).thenAnswer((_) async {});
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ConversationListMarkRead(_testConversationId1)),
        expect: () => const <ConversationListState>[],
      );
    });

    group('ConversationListNavigateToUser', () {
      blocTest<ConversationListBloc, ConversationListState>(
        'emits state with navigationTarget '
        'containing computed conversation ID',
        setUp: () {
          when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey1);
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ConversationListNavigateToUser(_testPubkey2)),
        expect: () => [
          isA<ConversationListState>()
              .having((s) => s.navigationTarget, 'navigationTarget', isNotNull)
              .having(
                (s) => s.navigationTarget!.participantPubkeys,
                'participantPubkeys',
                equals([_testPubkey2]),
              )
              .having(
                (s) => s.navigationTarget!.conversationId,
                'conversationId',
                equals(
                  DmRepository.computeConversationId([
                    _testPubkey1,
                    _testPubkey2,
                  ]),
                ),
              ),
        ],
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'does not emit when userPubkey is empty',
        setUp: () {
          when(() => mockDmRepository.userPubkey).thenReturn('');
        },
        build: createBloc,
        act: (bloc) =>
            bloc.add(const ConversationListNavigateToUser(_testPubkey2)),
        expect: () => const <ConversationListState>[],
      );
    });

    group('ConversationListNavigationConsumed', () {
      blocTest<ConversationListBloc, ConversationListState>(
        'clears the navigation target',
        setUp: () {
          when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey1);
        },
        seed: () => ConversationListState(
          navigationTarget: ConversationNavigationTarget(
            conversationId: DmRepository.computeConversationId([
              _testPubkey1,
              _testPubkey2,
            ]),
            participantPubkeys: const [_testPubkey2],
          ),
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ConversationListNavigationConsumed()),
        expect: () => [
          isA<ConversationListState>().having(
            (s) => s.navigationTarget,
            'navigationTarget',
            isNull,
          ),
        ],
      );
    });

    group('event transformers', () {
      group('droppable() on $ConversationListMarkRead', () {
        blocTest<ConversationListBloc, ConversationListState>(
          'drops additional mark-read events while one is processing',
          setUp: () {
            final completer = Completer<void>();
            var callCount = 0;
            when(
              () => mockDmRepository.markConversationAsRead(any()),
            ).thenAnswer((_) {
              callCount++;
              if (callCount == 1) {
                // First call is slow
                return completer.future;
              }
              // Subsequent calls would complete instantly, but should be
              // dropped by the droppable() transformer.
              return Future.value();
            });

            // Complete the first call after some time
            final completion =
                Future<void>.delayed(
                  const Duration(milliseconds: 50),
                ).then((_) {
                  completer.complete();
                });
            addTearDown(() => completion);
          },
          build: createBloc,
          act: (bloc) {
            // Fire three mark-read events rapidly; the second and third
            // should be dropped while the first is still processing.
            bloc
              ..add(const ConversationListMarkRead(_testConversationId1))
              ..add(const ConversationListMarkRead(_testConversationId1))
              ..add(const ConversationListMarkRead(_testConversationId1));
          },
          wait: const Duration(milliseconds: 150),
          expect: () => const <ConversationListState>[],
          verify: (_) {
            // Only the first call should have been processed; the rest
            // are dropped by droppable().
            verify(
              () =>
                  mockDmRepository.markConversationAsRead(_testConversationId1),
            ).called(1);
          },
        );

        blocTest<ConversationListBloc, ConversationListState>(
          'processes a new event after the previous one completes',
          setUp: () {
            when(
              () => mockDmRepository.markConversationAsRead(any()),
            ).thenAnswer((_) async {});
          },
          build: createBloc,
          act: (bloc) async {
            bloc.add(const ConversationListMarkRead(_testConversationId1));
            // Wait for the first to complete before adding the second
            await Future<void>.delayed(const Duration(milliseconds: 30));
            bloc.add(const ConversationListMarkRead(_testConversationId2));
          },
          wait: const Duration(milliseconds: 100),
          verify: (_) {
            verify(
              () =>
                  mockDmRepository.markConversationAsRead(_testConversationId1),
            ).called(1);
            verify(
              () =>
                  mockDmRepository.markConversationAsRead(_testConversationId2),
            ).called(1);
          },
        );
      });

      group('restartable() on $ConversationListStarted', () {
        late StreamController<List<DmConversation>> acceptedCtrl1;
        late StreamController<List<DmConversation>> acceptedCtrl2;
        late StreamController<List<DmConversation>> requestsCtrl1;
        late StreamController<List<DmConversation>> requestsCtrl2;
        late Completer<void> acceptedSecondSubscribed;
        late Completer<void> requestsSecondSubscribed;
        var acceptedCallCount = 0;
        var requestsCallCount = 0;

        blocTest<ConversationListBloc, ConversationListState>(
          'cancels the old subscription and starts a new one '
          'when $ConversationListStarted is re-added',
          setUp: () {
            acceptedSecondSubscribed = Completer<void>();
            requestsSecondSubscribed = Completer<void>();
            acceptedCtrl1 = StreamController<List<DmConversation>>();
            requestsCtrl1 = StreamController<List<DmConversation>>();
            acceptedCtrl2 = StreamController<List<DmConversation>>(
              onListen: acceptedSecondSubscribed.complete,
            );
            requestsCtrl2 = StreamController<List<DmConversation>>(
              onListen: requestsSecondSubscribed.complete,
            );
            acceptedCallCount = 0;
            requestsCallCount = 0;

            when(
              () => mockDmRepository.watchAcceptedConversations(
                limit: any(named: 'limit'),
              ),
            ).thenAnswer((_) {
              acceptedCallCount++;
              if (acceptedCallCount == 1) return acceptedCtrl1.stream;
              return acceptedCtrl2.stream;
            });

            when(() => mockDmRepository.watchPotentialRequests()).thenAnswer((
              _,
            ) {
              requestsCallCount++;
              if (requestsCallCount == 1) return requestsCtrl1.stream;
              return requestsCtrl2.stream;
            });

            when(() => mockDmRepository.isRecoveringHistory).thenReturn(false);
            when(
              () => mockDmRepository.historyRecoveryStream,
            ).thenAnswer((_) => const Stream<bool>.empty());
          },
          build: createBloc,
          act: (bloc) async {
            bloc.add(const ConversationListStarted());
            requestsCtrl1.add(const []);
            acceptedCtrl1.add([
              _createConversation(
                id: _testConversationId1,
                currentUserHasSent: true,
              ),
            ]);
            await bloc.stream.firstWhere(
              (state) =>
                  state.status == ConversationListStatus.loaded &&
                  state.conversations.length == 1 &&
                  state.conversations.first.id == _testConversationId1,
            );

            bloc.add(const ConversationListStarted());
            await Future.wait([
              acceptedSecondSubscribed.future,
              requestsSecondSubscribed.future,
            ]);

            // The old streams emit after restart; restartable() should ignore them.
            requestsCtrl1.add(const []);
            acceptedCtrl1.add([
              _createConversation(
                id: _testConversationId1,
                currentUserHasSent: true,
              ),
              _createConversation(
                id: _testConversationId2,
                currentUserHasSent: true,
              ),
            ]);

            final secondLoaded = bloc.stream.firstWhere(
              (state) =>
                  state.status == ConversationListStatus.loaded &&
                  state.conversations.length == 1 &&
                  state.conversations.first.id == _testConversationId2,
            );
            requestsCtrl2.add(const []);
            acceptedCtrl2.add([
              _createConversation(
                id: _testConversationId2,
                currentUserHasSent: true,
              ),
            ]);
            await secondLoaded;
          },
          expect: () => [
            // First subscription starts (initial → loading)
            const ConversationListState(status: ConversationListStatus.loading),
            // First streams emit
            ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: [
                _createConversation(
                  id: _testConversationId1,
                  currentUserHasSent: true,
                ),
              ],
              visibleConversations: [
                _createConversation(
                  id: _testConversationId1,
                  currentUserHasSent: true,
                ),
              ],
              hasMore: false,
            ),
            // Second ConversationListStarted: no loading emission
            // because status is already loaded (not initial).
            // Second streams emit (old streams' late emission is
            // ignored because restartable() cancelled it)
            ConversationListState(
              status: ConversationListStatus.loaded,
              conversations: [
                _createConversation(
                  id: _testConversationId2,
                  currentUserHasSent: true,
                ),
              ],
              visibleConversations: [
                _createConversation(
                  id: _testConversationId2,
                  currentUserHasSent: true,
                ),
              ],
              hasMore: false,
            ),
          ],
          verify: (_) {
            verify(
              () => mockDmRepository.watchAcceptedConversations(
                limit: any(named: 'limit'),
              ),
            ).called(2);
            verify(() => mockDmRepository.watchPotentialRequests()).called(2);
          },
          tearDown: () async {
            await acceptedCtrl1.close();
            await acceptedCtrl2.close();
            await requestsCtrl1.close();
            await requestsCtrl2.close();
          },
        );
      });
    });

    group('ConversationListLoadMore', () {
      blocTest<ConversationListBloc, ConversationListState>(
        'widens the render window without re-querying the stream',
        setUp: () {
          _stubStreams(mockDmRepository);
        },
        seed: () => ConversationListState(
          status: ConversationListStatus.loaded,
          // Full set is already loaded: one more than a page.
          conversations: List.generate(
            ConversationListState.pageSize + 1,
            (i) => _createConversation(
              id: 'a${i.toRadixString(16).padLeft(63, '0')}',
              currentUserHasSent: true,
            ),
          ),
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ConversationListLoadMore()),
        wait: const Duration(milliseconds: 100),
        verify: (bloc) {
          expect(
            bloc.state.currentLimit,
            equals(ConversationListState.pageSize * 2),
          );
          expect(
            bloc.state.visibleConversations,
            hasLength(ConversationListState.pageSize + 1),
            reason: 'the widened window now reveals the whole loaded set',
          );
          expect(
            bloc.state.hasMore,
            isFalse,
            reason: 'the window is larger than the loaded set',
          );
          // Load-more is a pure re-slice: it must not restart the watch, so
          // the backfill side effects of _onStarted must not fire again.
          verifyNever(() => mockDmRepository.backfillHistoryIfNeeded());
        },
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'does not emit when hasMore is false',
        seed: () => const ConversationListState(
          status: ConversationListStatus.loaded,
          hasMore: false,
        ),
        build: createBloc,
        act: (bloc) => bloc.add(const ConversationListLoadMore()),
        expect: () => const <ConversationListState>[],
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'does not emit when status is not loaded',
        build: createBloc,
        act: (bloc) => bloc.add(const ConversationListLoadMore()),
        expect: () => const <ConversationListState>[],
      );
    });

    group('message request splitting', () {
      blocTest<ConversationListBloc, ConversationListState>(
        'classifies unfollowed contacts as requests',
        setUp: () {
          // _testPubkey2 is NOT followed.
          when(
            () => mockFollowRepository.isFollowing(_testPubkey1),
          ).thenReturn(true);
          when(
            () => mockFollowRepository.isFollowing(_testPubkey2),
          ).thenReturn(false);
          when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey1);

          // currentUserHasSent=false → come from potentialRequests stream.
          final conversations = [
            _createConversation(id: _testConversationId1),
            _createConversation(id: _testConversationId2),
          ];
          _stubStreams(mockDmRepository, potentialRequests: conversations);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ConversationListStarted()),
        verify: (bloc) {
          // Both conversations have participants [_testPubkey1, _testPubkey2].
          // The "other" pubkey from user _testPubkey1's perspective is
          // _testPubkey2, which is NOT followed. So both are requests.
          expect(bloc.state.conversations, isEmpty);
          expect(bloc.state.requestConversations, hasLength(2));
        },
      );

      group('recovery-aware request gate (#5304)', () {
        blocTest<ConversationListBloc, ConversationListState>(
          'holds back would-be requests (neither inbox nor requests) while '
          'DM history recovery is running, but keeps accepted chats visible',
          setUp: () {
            when(
              () => mockFollowRepository.isFollowing(any()),
            ).thenReturn(false);
            when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey1);
            // Recovery NOT complete. The accepted chat is unambiguous and
            // stays visible; the unfollowed/never-replied potential is
            // ambiguous (it may be an established chat whose own message
            // hasn't been re-ingested yet) and is held back until recovery
            // completes — shown neither in the inbox (the "reversed" churn
            // hm21 hit) nor as a request (the original #5304 bug).
            _stubStreams(
              mockDmRepository,
              accepted: [
                _createConversation(
                  id: _testConversationId1,
                  currentUserHasSent: true,
                ),
              ],
              potentialRequests: [
                _createConversation(id: _testConversationId2),
              ],
              recoveryComplete: false,
            );
          },
          build: createBloc,
          act: (bloc) => bloc.add(const ConversationListStarted()),
          verify: (bloc) {
            expect(bloc.state.conversations, hasLength(1));
            expect(
              bloc.state.conversations.first.id,
              equals(_testConversationId1),
            );
            expect(bloc.state.requestConversations, isEmpty);
          },
        );

        blocTest<ConversationListBloc, ConversationListState>(
          'applies the request split once history recovery completes',
          setUp: () {
            final recoveryController = StreamController<bool>();
            when(
              () => mockFollowRepository.isFollowing(any()),
            ).thenReturn(false);
            when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey1);
            final conversations = [
              _createConversation(id: _testConversationId1),
            ];
            // Start mid-recovery: the gate suppresses the split.
            _stubStreams(
              mockDmRepository,
              potentialRequests: conversations,
              recoveryComplete: false,
              isRecovering: true,
              recoveryStream: recoveryController.stream,
            );
            // Recovery completes: flip the flag, then signal via the recovery
            // stream so the combined stream re-fires and re-classifies.
            final recovery =
                Future<void>.delayed(
                  const Duration(milliseconds: 50),
                ).then((_) {
                  when(
                    () => mockDmRepository.hasCompletedHistoryRecoveryBefore,
                  ).thenReturn(true);
                  recoveryController.add(false);
                });
            addTearDown(() => recovery);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const ConversationListStarted()),
          wait: const Duration(milliseconds: 200),
          verify: (bloc) {
            // After recovery completes, the unfollowed/never-replied chat is
            // correctly classified as a request.
            expect(bloc.state.requestConversations, hasLength(1));
            expect(bloc.state.conversations, isEmpty);
            // …and the gate is no longer costing the user anything.
            expect(bloc.state.requestsWithheld, isFalse);
          },
        );

        blocTest<ConversationListBloc, ConversationListState>(
          'flags requestsWithheld while the gate hides would-be requests',
          setUp: () {
            when(
              () => mockFollowRepository.isFollowing(any()),
            ).thenReturn(false);
            when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey1);
            _stubStreams(
              mockDmRepository,
              potentialRequests: [
                _createConversation(id: _testConversationId2),
              ],
              recoveryComplete: false,
            );
          },
          build: createBloc,
          act: (bloc) => bloc.add(const ConversationListStarted()),
          verify: (bloc) {
            // The user has a real pending request that the gate is hiding.
            // Before this flag the inbox looked complete: no rows, no banner,
            // and — on every drain exit that is not a clean exhaustion — no
            // progress bar either.
            expect(bloc.state.requestConversations, isEmpty);
            expect(bloc.state.requestsWithheld, isTrue);
          },
        );

        blocTest<ConversationListBloc, ConversationListState>(
          'does not flag requestsWithheld when the gate hides nothing',
          setUp: () {
            when(
              () => mockFollowRepository.isFollowing(any()),
            ).thenReturn(false);
            when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey1);
            // Gate shut, but there is nothing behind it — no banner is owed.
            _stubStreams(
              mockDmRepository,
              accepted: [
                _createConversation(
                  id: _testConversationId1,
                  currentUserHasSent: true,
                ),
              ],
              recoveryComplete: false,
            );
          },
          build: createBloc,
          act: (bloc) => bloc.add(const ConversationListStarted()),
          verify: (bloc) {
            expect(bloc.state.conversations, hasLength(1));
            expect(bloc.state.requestsWithheld, isFalse);
          },
        );

        blocTest<ConversationListBloc, ConversationListState>(
          'restore retry re-arms both recovery passes and re-reads the gate',
          setUp: () {
            when(
              () => mockFollowRepository.isFollowing(any()),
            ).thenReturn(false);
            when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey1);
            _stubStreams(
              mockDmRepository,
              potentialRequests: [
                _createConversation(id: _testConversationId2),
              ],
              recoveryComplete: false,
            );
          },
          build: createBloc,
          act: (bloc) async {
            bloc.add(const ConversationListStarted());
            await Future<void>.delayed(const Duration(milliseconds: 250));
            // The drain succeeded this time.
            when(
              () => mockDmRepository.hasCompletedHistoryRecoveryBefore,
            ).thenReturn(true);
            bloc.add(const ConversationListRestoreRetryRequested());
          },
          wait: const Duration(milliseconds: 400),
          verify: (bloc) {
            // Retry re-runs both recovery passes (once from the initial
            // start, once from the retry) …
            verify(() => mockDmRepository.backfillHistoryIfNeeded()).called(2);
            verify(() => mockDmRepository.retryPendingDecryptions()).called(2);
            // … and the re-read gate releases the held-back request, clearing
            // the banner. Going through _onStarted matters: the drain returns
            // without ever touching the recovery stream when it is already
            // complete, so a stream-only path would leave the banner stuck.
            expect(bloc.state.requestsWithheld, isFalse);
            expect(bloc.state.requestConversations, hasLength(1));
          },
        );
      });

      blocTest<ConversationListBloc, ConversationListState>(
        'conversations from followed users stay in normal list',
        setUp: () {
          // All participants are followed.
          when(() => mockFollowRepository.isFollowing(any())).thenReturn(true);
          when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey1);

          final conversations = [_createConversation(id: _testConversationId1)];
          _stubStreams(mockDmRepository, potentialRequests: conversations);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ConversationListStarted()),
        verify: (bloc) {
          expect(bloc.state.conversations, hasLength(1));
          expect(bloc.state.requestConversations, isEmpty);
        },
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'accepted conversations always go to conversations list '
        'regardless of follow state',
        setUp: () {
          // Nobody is followed.
          when(() => mockFollowRepository.isFollowing(any())).thenReturn(false);
          when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey1);

          // currentUserHasSent=true → accepted stream.
          final conversations = [
            _createConversation(
              id: _testConversationId1,
              currentUserHasSent: true,
            ),
          ];
          _stubStreams(mockDmRepository, accepted: conversations);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ConversationListStarted()),
        verify: (bloc) {
          expect(bloc.state.conversations, hasLength(1));
          expect(bloc.state.requestConversations, isEmpty);
        },
      );

      test('requestUnreadCount counts unread requests', () {
        final state = ConversationListState(
          status: ConversationListStatus.loaded,
          requestConversations: [
            _createConversation(id: _testConversationId1, isRead: false),
            _createConversation(id: _testConversationId2),
          ],
        );

        expect(state.requestUnreadCount, equals(1));
      });

      group('following changes', () {
        test('re-splits conversations when follow list changes', () async {
          final followingController = StreamController<List<String>>();
          addTearDown(followingController.close);

          // Initially _testPubkey2 (the conversation's counterparty) is NOT
          // followed, so it classifies as a request.
          when(
            () => mockFollowRepository.isFollowing(_testPubkey2),
          ).thenReturn(false);
          when(
            () => mockFollowRepository.followingStream,
          ).thenAnswer((_) => followingController.stream);
          when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey1);
          _stubStreams(
            mockDmRepository,
            potentialRequests: [_createConversation(id: _testConversationId1)],
          );

          final bloc = createBloc();
          addTearDown(bloc.close);

          // Register both waiters before adding the event so a prompt emission
          // can never be missed by a late subscription. Debounce is zero (see
          // createBloc), so re-classification is driven purely by stream order,
          // not wall-clock time — the old version raced a real 50ms timer that
          // emitted the follow update against blocTest's `wait`, which flaked
          // under CI load.
          final requestClassified = bloc.stream.firstWhere(
            (s) => s.requestConversations.isNotEmpty,
          );
          final reSplit = bloc.stream.firstWhere(
            (s) => s.conversations.isNotEmpty,
          );

          bloc.add(const ConversationListStarted());

          await requestClassified;
          expect(bloc.state.conversations, isEmpty);

          // Follow the counterparty and push it through followingStream; the
          // combineLatest re-fires and the conversation moves into the inbox.
          when(
            () => mockFollowRepository.isFollowing(_testPubkey2),
          ).thenReturn(true);
          followingController.add([_testPubkey2]);

          await reSplit;
          expect(bloc.state.conversations, hasLength(1));
          expect(bloc.state.requestConversations, isEmpty);
        });
      });

      group('group conversation classification', () {
        blocTest<ConversationListBloc, ConversationListState>(
          'classifies group conversation as request '
          'when user has not sent and any member is unfollowed',
          setUp: () {
            // _testPubkey2 is followed, _testPubkey3 is not.
            when(
              () => mockFollowRepository.isFollowing(_testPubkey2),
            ).thenReturn(true);
            when(
              () => mockFollowRepository.isFollowing(_testPubkey3),
            ).thenReturn(false);
            when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey1);

            final conversations = [
              _createConversation(
                id: _testConversationId1,
                isGroup: true,
                participantPubkeys: [_testPubkey1, _testPubkey2, _testPubkey3],
              ),
            ];
            _stubStreams(mockDmRepository, potentialRequests: conversations);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const ConversationListStarted()),
          verify: (bloc) {
            expect(bloc.state.conversations, isEmpty);
            expect(bloc.state.requestConversations, hasLength(1));
          },
        );

        blocTest<ConversationListBloc, ConversationListState>(
          'classifies group conversation as inbox '
          'when every member is followed even if user has not sent',
          setUp: () {
            when(
              () => mockFollowRepository.isFollowing(_testPubkey2),
            ).thenReturn(true);
            when(
              () => mockFollowRepository.isFollowing(_testPubkey3),
            ).thenReturn(true);
            when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey1);

            final conversations = [
              _createConversation(
                id: _testConversationId1,
                isGroup: true,
                participantPubkeys: [_testPubkey1, _testPubkey2, _testPubkey3],
              ),
            ];
            _stubStreams(mockDmRepository, potentialRequests: conversations);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const ConversationListStarted()),
          verify: (bloc) {
            expect(bloc.state.conversations, hasLength(1));
            expect(bloc.state.requestConversations, isEmpty);
          },
        );

        blocTest<ConversationListBloc, ConversationListState>(
          'classifies group conversation as normal '
          'when user has sent',
          setUp: () {
            when(
              () => mockFollowRepository.isFollowing(_testPubkey2),
            ).thenReturn(true);
            when(
              () => mockFollowRepository.isFollowing(_testPubkey3),
            ).thenReturn(false);
            when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey1);

            final conversations = [
              _createConversation(
                id: _testConversationId1,
                isGroup: true,
                currentUserHasSent: true,
                participantPubkeys: [_testPubkey1, _testPubkey2, _testPubkey3],
              ),
            ];
            // currentUserHasSent=true → accepted stream.
            _stubStreams(mockDmRepository, accepted: conversations);
          },
          build: createBloc,
          act: (bloc) => bloc.add(const ConversationListStarted()),
          verify: (bloc) {
            expect(bloc.state.conversations, hasLength(1));
            expect(bloc.state.requestConversations, isEmpty);
          },
        );
      });

      group('pagination does not truncate requests', () {
        blocTest<ConversationListBloc, ConversationListState>(
          'requests appear even when accepted list fills page',
          setUp: () {
            when(
              () => mockFollowRepository.isFollowing(any()),
            ).thenReturn(false);
            when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey1);

            // More than a page of accepted conversations.
            final accepted = List.generate(
              ConversationListState.pageSize + 1,
              (i) => _createConversation(
                id: 'a${i.toRadixString(16).padLeft(63, '0')}',
                currentUserHasSent: true,
              ),
            );
            // Requests loaded separately, not truncated.
            final requests = [
              _createConversation(id: _testConversationId1),
              _createConversation(id: _testConversationId2),
            ];
            _stubStreams(
              mockDmRepository,
              accepted: accepted,
              potentialRequests: requests,
            );
          },
          build: createBloc,
          act: (bloc) => bloc.add(const ConversationListStarted()),
          verify: (bloc) {
            expect(
              bloc.state.conversations,
              hasLength(ConversationListState.pageSize + 1),
              reason: 'the complete accepted set is loaded, not one page',
            );
            expect(
              bloc.state.visibleConversations,
              hasLength(ConversationListState.pageSize),
              reason: 'pagination is now a render window over that set',
            );
            expect(bloc.state.requestConversations, hasLength(2));
            expect(bloc.state.hasMore, isTrue);
          },
        );
      });
    });

    // -----------------------------------------------------------------
    // Identity race (#5374)
    // -----------------------------------------------------------------

    group('identity race (#5374)', () {
      blocTest<ConversationListBloc, ConversationListState>(
        'stays loading and does not classify while userPubkey is empty',
        setUp: () {
          _stubStreams(
            mockDmRepository,
            potentialRequests: [_createConversation(id: 'c1')],
          );
          // Cold start: credentials not set yet and the identity stream never
          // delivers a real pubkey, so classification must be held back.
          when(() => mockDmRepository.userPubkey).thenReturn('');
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ConversationListStarted()),
        // Only the loading emit — the empty-pubkey guard prevents a
        // misclassified "requests" emission (which would leave self in
        // otherPubkeys, making the 1:1 look like a group).
        expect: () => [
          isA<ConversationListState>().having(
            (s) => s.status,
            'status',
            ConversationListStatus.loading,
          ),
        ],
      );

      blocTest<ConversationListBloc, ConversationListState>(
        'routes a followed 1:1 peer to the inbox once userPubkey arrives, '
        'not to requests',
        setUp: () {
          _stubStreams(
            mockDmRepository,
            potentialRequests: [
              _createConversation(
                id: 'c1',
                participantPubkeys: const [_testPubkey1, _testPubkey2],
              ),
            ],
          );
          // Empty at first; the identity stream then delivers the real pubkey,
          // mirroring the cold-start race the #5374 diagnostics captured.
          when(() => mockDmRepository.userPubkey).thenReturn('');
          when(
            () => mockDmRepository.userPubkeyStream,
          ).thenAnswer((_) => Stream.value(_testPubkey1));
          when(
            () => mockFollowRepository.isFollowing(_testPubkey2),
          ).thenReturn(true);
          when(
            () => mockFollowRepository.isFollowing(_testPubkey1),
          ).thenReturn(false);
        },
        build: createBloc,
        act: (bloc) => bloc.add(const ConversationListStarted()),
        verify: (bloc) {
          // Self (_testPubkey1) is filtered, leaving the single followed peer
          // _testPubkey2 → inbox. Before the fix the empty pubkey left self in
          // otherPubkeys (count 2 → treated as a group) → misrouted to
          // requests.
          expect(bloc.state.requestConversations, isEmpty);
          expect(bloc.state.conversations, hasLength(1));
          expect(bloc.state.conversations.single.id, equals('c1'));
        },
      );
    });
  });

  group('$ConversationListState', () {
    test('supports value equality', () {
      final conversations = [_createConversation(id: _testConversationId1)];

      final state1 = ConversationListState(
        status: ConversationListStatus.loaded,
        conversations: conversations,
      );
      final state2 = ConversationListState(
        status: ConversationListStatus.loaded,
        conversations: conversations,
      );

      expect(state1, equals(state2));
    });

    test('states with different status are not equal', () {
      const state1 = ConversationListState(
        status: ConversationListStatus.loading,
      );
      const state2 = ConversationListState(
        status: ConversationListStatus.loaded,
      );

      expect(state1, isNot(equals(state2)));
    });

    test('states with different conversations are not equal', () {
      final state1 = ConversationListState(
        status: ConversationListStatus.loaded,
        conversations: [_createConversation(id: _testConversationId1)],
      );
      final state2 = ConversationListState(
        status: ConversationListStatus.loaded,
        conversations: [_createConversation(id: _testConversationId2)],
      );

      expect(state1, isNot(equals(state2)));
    });

    test('copyWith creates copy with updated values', () {
      const state = ConversationListState();
      final conversations = [_createConversation(id: _testConversationId1)];

      final updated = state.copyWith(
        status: ConversationListStatus.loaded,
        conversations: conversations,
      );

      expect(updated.status, equals(ConversationListStatus.loaded));
      expect(updated.conversations, equals(conversations));
    });

    test('copyWith preserves values when not specified', () {
      final conversations = [_createConversation(id: _testConversationId1)];
      final state = ConversationListState(
        status: ConversationListStatus.loaded,
        conversations: conversations,
      );

      final updated = state.copyWith();

      expect(updated.status, equals(ConversationListStatus.loaded));
      expect(updated.conversations, equals(conversations));
    });

    test('props includes all fields', () {
      final conversations = [_createConversation(id: _testConversationId1)];
      final state = ConversationListState(
        status: ConversationListStatus.loaded,
        conversations: conversations,
      );

      expect(state.props, [
        ConversationListStatus.loaded,
        conversations,
        const <DmConversation>[], // visibleConversations
        const <DmConversation>[], // blockedConversations
        InboxFilter.all, // filter
        '', // searchQuery
        const <String, String>{}, // profileNames
        const <String>{}, // vanishedPubkeys
        null, // peerLabels
        const <DmConversation>[],
        const <DmConversation>[],
        true,
        false, // isRestoringHistory
        false, // requestsWithheld
        ConversationListState.pageSize,
        null, // navigationTarget
        null, // pinnedSupport
      ]);
    });
  });

  group('ConversationListEvent', () {
    test('$ConversationListStarted supports value equality', () {
      const event1 = ConversationListStarted();
      const event2 = ConversationListStarted();

      expect(event1, equals(event2));
    });

    test('$ConversationListStarted props is empty', () {
      const event = ConversationListStarted();

      expect(event.props, equals(const <Object?>[]));
    });

    test('$ConversationListMarkRead supports value equality', () {
      const event1 = ConversationListMarkRead(_testConversationId1);
      const event2 = ConversationListMarkRead(_testConversationId1);

      expect(event1, equals(event2));
    });

    test('$ConversationListMarkRead with different IDs are not equal', () {
      const event1 = ConversationListMarkRead(_testConversationId1);
      const event2 = ConversationListMarkRead(_testConversationId2);

      expect(event1, isNot(equals(event2)));
    });

    test('$ConversationListMarkRead props contains conversationId', () {
      const event = ConversationListMarkRead(_testConversationId1);

      expect(event.props, equals([_testConversationId1]));
    });

    test('$ConversationListNavigateToUser supports value equality', () {
      const event1 = ConversationListNavigateToUser(_testPubkey1);
      const event2 = ConversationListNavigateToUser(_testPubkey1);

      expect(event1, equals(event2));
    });

    test('$ConversationListNavigateToUser with different pubkeys '
        'are not equal', () {
      const event1 = ConversationListNavigateToUser(_testPubkey1);
      const event2 = ConversationListNavigateToUser(_testPubkey2);

      expect(event1, isNot(equals(event2)));
    });

    test('$ConversationListNavigateToUser props contains '
        'participantPubkey', () {
      const event = ConversationListNavigateToUser(_testPubkey1);

      expect(event.props, equals([_testPubkey1]));
    });

    test('$ConversationListNavigationConsumed supports value equality', () {
      const event1 = ConversationListNavigationConsumed();
      const event2 = ConversationListNavigationConsumed();

      expect(event1, equals(event2));
    });

    test('$ConversationListNavigationConsumed props is empty', () {
      const event = ConversationListNavigationConsumed();

      expect(event.props, equals(const <Object?>[]));
    });
  });

  group(ConversationNavigationTarget, () {
    test('supports value equality', () {
      const target1 = ConversationNavigationTarget(
        conversationId: _testConversationId1,
        participantPubkeys: [_testPubkey2],
      );
      const target2 = ConversationNavigationTarget(
        conversationId: _testConversationId1,
        participantPubkeys: [_testPubkey2],
      );

      expect(target1, equals(target2));
    });

    test('targets with different conversation IDs are not equal', () {
      const target1 = ConversationNavigationTarget(
        conversationId: _testConversationId1,
        participantPubkeys: [_testPubkey2],
      );
      const target2 = ConversationNavigationTarget(
        conversationId: _testConversationId2,
        participantPubkeys: [_testPubkey2],
      );

      expect(target1, isNot(equals(target2)));
    });
  });

  group('ConversationListUnreadFilterToggled', () {
    late _MockDmRepository mockDmRepository;
    late _MockFollowRepository mockFollowRepository;

    setUp(() {
      mockDmRepository = _MockDmRepository();
      mockFollowRepository = _MockFollowRepository();

      when(() => mockFollowRepository.isFollowing(any())).thenReturn(true);
      when(
        () => mockFollowRepository.followingStream,
      ).thenAnswer((_) => const Stream<List<String>>.empty());
      when(
        () => mockDmRepository.backfillHistoryIfNeeded(),
      ).thenAnswer((_) async {});
      when(
        () => mockDmRepository.retryPendingDecryptions(),
      ).thenAnswer((_) async {});
    });

    ConversationListBloc createBloc() => ConversationListBloc(
      dmRepository: mockDmRepository,
      followRepository: mockFollowRepository,
      recomputeDebounce: Duration.zero,
    );

    Future<ConversationListState> loadMixedList(
      ConversationListBloc bloc,
    ) async {
      bloc.add(const ConversationListStarted());
      return bloc.stream.firstWhere(
        (s) => s.status == ConversationListStatus.loaded,
      );
    }

    List<DmConversation> mixedConversations() => [
      _createConversation(id: 'unread-1', isRead: false),
      _createConversation(id: 'read-1'),
      _createConversation(id: 'unread-2', isRead: false),
    ];

    test(
      'loaded state exposes the full list as visibleConversations',
      () async {
        _stubStreams(mockDmRepository, accepted: mixedConversations());
        final bloc = createBloc();
        addTearDown(bloc.close);

        final state = await loadMixedList(bloc);

        expect(state.filter, equals(InboxFilter.all));
        expect(
          state.visibleConversations.map((c) => c.id).toList(),
          equals(['unread-1', 'read-1', 'unread-2']),
        );
      },
    );

    // The unread chip and search filter client-side. If the watch were
    // paginated, they would answer about the loaded page instead of the inbox:
    // the list claimed "You're all caught up" while the Messages badge — which
    // counts the full accepted set — still showed unread.
    group('filters see the whole inbox, not just the loaded page', () {
      /// One page of read conversations plus a single unread one ranked
      /// *below* the initial render window. Timestamps descend so the ranking
      /// is explicit rather than dependent on sort tie-breaking.
      List<DmConversation> unreadBeyondFirstPage() => [
        for (var i = 0; i < ConversationListState.pageSize; i++)
          _createConversation(
            id: 'read-$i',
            lastMessageTimestamp: 1700000100 - i,
          ),
        _createConversation(
          id: 'unread-beyond',
          isRead: false,
          lastMessageContent: 'needle in the tail',
          lastMessageTimestamp: 1700000100 - ConversationListState.pageSize,
        ),
      ];

      /// Stubs the accepted stream so it HONOURS `limit`, the way the DAO
      /// does (`conversations_dao.dart` applies `query.limit(limit)` only when
      /// limit is non-null). The shared `_stubStreams` helper ignores the
      /// argument, which would let these tests pass even against a paginated
      /// watch — they must reproduce the truncation to pin the fix.
      void stubTruncating(List<DmConversation> all) {
        _stubStreams(mockDmRepository, accepted: all);
        when(
          () => mockDmRepository.watchAcceptedConversations(
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((invocation) {
          final limit = invocation.namedArguments[#limit] as int?;
          return Stream.value(limit == null ? all : all.take(limit).toList());
        });
      }

      test('watches the accepted stream unpaginated', () async {
        stubTruncating(unreadBeyondFirstPage());
        final bloc = createBloc();
        addTearDown(bloc.close);

        await loadMixedList(bloc);

        verify(
          () => mockDmRepository.watchAcceptedConversations(),
        ).called(greaterThanOrEqualTo(1));
        verifyNever(
          () => mockDmRepository.watchAcceptedConversations(
            limit: any(named: 'limit', that: isNotNull),
          ),
        );
      });

      test('unread filter surfaces an unread chat below the window', () async {
        stubTruncating(unreadBeyondFirstPage());
        final bloc = createBloc();
        addTearDown(bloc.close);

        final loaded = await loadMixedList(bloc);
        expect(
          loaded.visibleConversations.map((c) => c.id),
          isNot(contains('unread-beyond')),
          reason: 'it is outside the initial render window',
        );

        bloc.add(const ConversationListFilterChanged(InboxFilter.unread));
        final state = await bloc.stream.firstWhere(
          (s) => s.filter == InboxFilter.unread,
        );

        expect(
          state.visibleConversations.map((c) => c.id).toList(),
          equals(['unread-beyond']),
          reason:
              'filtering the full set must not report "all caught up" while '
              'the unpaginated Messages badge counts this conversation',
        );
      });

      test('search matches a conversation below the window', () async {
        stubTruncating(unreadBeyondFirstPage());
        final bloc = createBloc();
        addTearDown(bloc.close);
        await loadMixedList(bloc);

        bloc.add(const ConversationListSearchQueryChanged('needle'));
        final state = await bloc.stream.firstWhere(
          (s) => s.searchQuery == 'needle',
        );

        expect(
          state.visibleConversations.map((c) => c.id).toList(),
          equals(['unread-beyond']),
          reason: 'search must not report "no matches" for unscrolled rows',
        );
      });
    });

    test('toggling on narrows visibleConversations to unread only', () async {
      _stubStreams(mockDmRepository, accepted: mixedConversations());
      final bloc = createBloc();
      addTearDown(bloc.close);
      await loadMixedList(bloc);

      bloc.add(const ConversationListFilterChanged(InboxFilter.unread));
      final state = await bloc.stream.firstWhere(
        (s) => s.filter == InboxFilter.unread,
      );

      expect(
        state.visibleConversations.map((c) => c.id).toList(),
        equals(['unread-1', 'unread-2']),
      );
      expect(
        state.conversations,
        hasLength(3),
        reason: 'the full list must stay available for the All filter',
      );
    });

    test('toggling off restores the full list', () async {
      _stubStreams(mockDmRepository, accepted: mixedConversations());
      final bloc = createBloc();
      addTearDown(bloc.close);
      await loadMixedList(bloc);

      bloc.add(const ConversationListFilterChanged(InboxFilter.unread));
      await bloc.stream.firstWhere((s) => s.filter == InboxFilter.unread);
      bloc.add(const ConversationListFilterChanged(InboxFilter.all));
      final state = await bloc.stream.firstWhere(
        (s) => s.filter == InboxFilter.all,
      );

      expect(
        state.visibleConversations.map((c) => c.id).toList(),
        equals(['unread-1', 'read-1', 'unread-2']),
      );
    });

    test(
      'new stream data arrives filtered while unread filter is on',
      () async {
        final acceptedController = StreamController<List<DmConversation>>();
        _stubStreams(mockDmRepository);
        when(
          () => mockDmRepository.watchAcceptedConversations(
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) => acceptedController.stream);

        final bloc = createBloc()..add(const ConversationListStarted());
        addTearDown(() async {
          await bloc.close();
          await acceptedController.close();
        });

        acceptedController.add(mixedConversations());
        await bloc.stream.firstWhere(
          (s) => s.status == ConversationListStatus.loaded,
        );

        bloc.add(const ConversationListFilterChanged(InboxFilter.unread));
        await bloc.stream.firstWhere((s) => s.filter == InboxFilter.unread);

        acceptedController.add([
          ...mixedConversations(),
          _createConversation(id: 'unread-3', isRead: false),
        ]);
        final state = await bloc.stream.firstWhere(
          (s) => s.visibleConversations.length == 3,
        );

        expect(
          state.visibleConversations.map((c) => c.id).toList(),
          equals(['unread-1', 'unread-2', 'unread-3']),
        );
        expect(state.conversations, hasLength(4));
      },
    );
  });

  group('search names a peer the way the row does (#8204)', () {
    late _MockDmRepository mockDmRepository;
    late _MockFollowRepository mockFollowRepository;
    late _MockProfileRepository mockProfileRepository;

    /// The two ARB values the inbox substitutes for a peer whose own name must
    /// not be shown, resolved rather than hardcoded so a copy change moves the
    /// test with the product.
    late DmPeerLabels labels;

    setUp(() {
      mockDmRepository = _MockDmRepository();
      mockFollowRepository = _MockFollowRepository();
      mockProfileRepository = _MockProfileRepository();

      final l10n = lookupAppLocalizations(const Locale('en'));
      labels = DmPeerLabels(
        deletedAccount: l10n.profileDeletedAccountName,
        moderation: l10n.inboxSupportRowTitle,
        retiredConversationClosed: l10n.dmRetiredThreadClosedTitle,
      );

      when(() => mockFollowRepository.isFollowing(any())).thenReturn(true);
      when(
        () => mockFollowRepository.followingStream,
      ).thenAnswer((_) => const Stream<List<String>>.empty());
      when(
        () => mockDmRepository.backfillHistoryIfNeeded(),
      ).thenAnswer((_) async {});
      when(
        () => mockDmRepository.retryPendingDecryptions(),
      ).thenAnswer((_) async {});
      // The batch path never yields a profile for either peer, which is the
      // measured reality: a PENDING vanish is stripped from the funnelcake
      // bulk response entirely, and a retired moderation key has no kind 0.
      when(
        () => mockProfileRepository.fetchBatchProfiles(
          pubkeys: any(named: 'pubkeys'),
        ),
      ).thenAnswer((_) async => const {});
    });

    void stubVanished(Set<String> pubkeys) {
      when(
        () => mockProfileRepository.watchVanishedPubkeys(),
      ).thenAnswer((_) => Stream.value(pubkeys));
    }

    ConversationListBloc createBloc({DmPeerLabels? withLabels}) {
      final bloc = ConversationListBloc(
        dmRepository: mockDmRepository,
        followRepository: mockFollowRepository,
        profileRepository: mockProfileRepository,
        recomputeDebounce: Duration.zero,
        moderationAccount: isModerationAccount,
        retiredModerationAccount: isRetiredModerationAccount,
      );
      if (withLabels != null) {
        bloc.add(ConversationListPeerLabelsChanged(withLabels));
      }
      return bloc;
    }

    /// Awaits the next state matching [test], failing fast instead of hanging.
    ///
    /// A bare `firstWhere` on a bloc stream never completes when the behaviour
    /// under test regresses, which turns a red test into a stuck CI job.
    Future<ConversationListState> firstMatch(
      ConversationListBloc bloc,
      bool Function(ConversationListState) test,
    ) => bloc.stream
        .firstWhere(test)
        .timeout(
          const Duration(seconds: 5),
          onTimeout: () => fail('no state matched within 5s'),
        );

    Future<ConversationListState> search(
      ConversationListBloc bloc,
      String query,
    ) async {
      bloc.add(const ConversationListStarted());
      await bloc.stream.firstWhere(
        (s) => s.status == ConversationListStatus.loaded,
      );
      bloc.add(ConversationListSearchQueryChanged(query));
      return bloc.stream.firstWhere((s) => s.searchQuery == query);
    }

    // The row for a titled group renders its NIP-17 subject and no
    // participant's name at all, so the index has to match on the subject or a
    // search finds a row by a string that is not on it (#8204's own rule).
    group('a group conversation', () {
      setUp(() => stubVanished(const {}));

      test('is found by the NIP-17 subject its row renders', () async {
        _stubStreams(
          mockDmRepository,
          accepted: [
            _createConversation(
              id: 'titled-group',
              isGroup: true,
              subject: 'Weekend trip',
              participantPubkeys: const [
                _testPubkey1,
                _testPubkey2,
                _testPubkey3,
              ],
            ),
          ],
        );
        final bloc = createBloc(withLabels: labels);
        addTearDown(bloc.close);

        final state = await search(bloc, 'weekend');

        expect(
          state.visibleConversations.map((c) => c.id).toList(),
          equals(['titled-group']),
        );
      });

      test(
        'is not found by a generated name the titled row never shows',
        () async {
          _stubStreams(
            mockDmRepository,
            accepted: [
              _createConversation(
                id: 'titled-group',
                isGroup: true,
                subject: 'Weekend trip',
                participantPubkeys: const [
                  _testPubkey1,
                  _testPubkey2,
                  _testPubkey3,
                ],
              ),
            ],
          );
          final bloc = createBloc(withLabels: labels);
          addTearDown(bloc.close);

          final state = await search(
            bloc,
            UserProfile.defaultDisplayNameFor(_testPubkey2),
          );

          expect(state.visibleConversations, isEmpty);
        },
      );

      test('is also found by a known participant name', () async {
        when(
          () => mockProfileRepository.fetchBatchProfiles(
            pubkeys: any(named: 'pubkeys'),
          ),
        ).thenAnswer(
          (_) async => {
            _testPubkey2: UserProfile(
              pubkey: _testPubkey2,
              displayName: 'Alice',
              rawData: const {},
              createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              eventId: _testConversationId1,
            ),
          },
        );
        _stubStreams(
          mockDmRepository,
          accepted: [
            _createConversation(
              id: 'titled-group',
              isGroup: true,
              subject: 'Weekend trip',
              participantPubkeys: const [
                _testPubkey1,
                _testPubkey2,
                _testPubkey3,
              ],
            ),
          ],
        );
        final bloc = createBloc(withLabels: labels);
        addTearDown(bloc.close);

        bloc.add(const ConversationListStarted());
        await bloc.stream.firstWhere(
          (s) => s.status == ConversationListStatus.loaded,
        );
        bloc.add(const ConversationListSearchQueryChanged('alice'));
        final state = await bloc.stream
            .firstWhere(
              (s) =>
                  s.searchQuery == 'alice' && s.visibleConversations.isNotEmpty,
            )
            .timeout(const Duration(seconds: 5));

        expect(
          state.visibleConversations.map((c) => c.id).toList(),
          equals(['titled-group']),
        );
      });

      // Without a subject the row DOES render a participant's name, inside
      // "<peer> and N others" — so that name must still match.
      test(
        'an untitled room is still found by the peer its row names',
        () async {
          _stubStreams(
            mockDmRepository,
            accepted: [
              _createConversation(
                id: 'untitled-group',
                isGroup: true,
                participantPubkeys: const [
                  _testPubkey1,
                  _testPubkey2,
                  _testPubkey3,
                ],
              ),
            ],
          );
          final bloc = createBloc(withLabels: labels);
          addTearDown(bloc.close);

          final state = await search(
            bloc,
            UserProfile.defaultDisplayNameFor(_testPubkey2),
          );

          expect(
            state.visibleConversations.map((c) => c.id).toList(),
            equals(['untitled-group']),
          );
        },
      );
    });

    group('a vanished counterparty', () {
      setUp(() => stubVanished({_testPubkey2}));

      test('is found by the deleted-account label the row shows', () async {
        _stubStreams(
          mockDmRepository,
          accepted: [_createConversation(id: 'vanished')],
        );
        final bloc = createBloc(withLabels: labels);
        addTearDown(bloc.close);

        final state = await search(bloc, labels.deletedAccount);

        expect(
          state.visibleConversations.map((c) => c.id).toList(),
          equals(['vanished']),
        );
      });

      test('is not found by the generated handle nobody has seen', () async {
        _stubStreams(
          mockDmRepository,
          accepted: [_createConversation(id: 'vanished')],
        );
        final bloc = createBloc(withLabels: labels);
        addTearDown(bloc.close);

        final state = await search(
          bloc,
          UserProfile.defaultDisplayNameFor(_testPubkey2),
        );

        expect(state.visibleConversations, isEmpty);
      });

      test('is still found by its message preview', () async {
        _stubStreams(
          mockDmRepository,
          accepted: [
            _createConversation(
              id: 'vanished',
              lastMessageContent: 'pizza friday?',
            ),
          ],
        );
        final bloc = createBloc(withLabels: labels);
        addTearDown(bloc.close);

        final state = await search(bloc, 'pizza');

        expect(
          state.visibleConversations.map((c) => c.id).toList(),
          equals(['vanished']),
        );
      });
    });

    group('a retired Divine Moderation key', () {
      // Rotated away from, so `_extractPinnedSupport` leaves it in the list as
      // an ordinary searchable row — while `isModerationAccount` still answers
      // for it, so the row renders the brand name.
      final retired = kLegacyModerationPubkeys.first;

      setUp(() => stubVanished(const {}));

      test('is found by the moderation name the row shows', () async {
        _stubStreams(
          mockDmRepository,
          accepted: [
            _createConversation(
              id: 'retired',
              participantPubkeys: [_testPubkey1, retired],
            ),
          ],
        );
        final bloc = createBloc(withLabels: labels);
        addTearDown(bloc.close);

        final state = await search(bloc, labels.moderation);

        expect(
          state.visibleConversations.map((c) => c.id).toList(),
          equals(['retired']),
        );
      });

      test('is not found by the generated handle', () async {
        _stubStreams(
          mockDmRepository,
          accepted: [
            _createConversation(
              id: 'retired',
              participantPubkeys: [_testPubkey1, retired],
            ),
          ],
        );
        final bloc = createBloc(withLabels: labels);
        addTearDown(bloc.close);

        final state = await search(
          bloc,
          UserProfile.defaultDisplayNameFor(retired),
        );

        expect(state.visibleConversations, isEmpty);
      });

      test('is found by the closed subtitle the row shows', () async {
        _stubStreams(
          mockDmRepository,
          accepted: [
            _createConversation(
              id: 'retired',
              participantPubkeys: [_testPubkey1, retired],
              lastMessageContent: 'Your video was removed',
            ),
          ],
        );
        final bloc = createBloc(withLabels: labels);
        addTearDown(bloc.close);

        final state = await search(bloc, labels.retiredConversationClosed);

        expect(state.visibleConversations.map((c) => c.id).toList(), [
          'retired',
        ]);
      });

      test('is not found by hidden last-message content', () async {
        _stubStreams(
          mockDmRepository,
          accepted: [
            _createConversation(
              id: 'retired',
              participantPubkeys: [_testPubkey1, retired],
              lastMessageContent: 'Your video was removed',
            ),
          ],
        );
        final bloc = createBloc(withLabels: labels);
        addTearDown(bloc.close);

        final state = await search(bloc, 'removed');

        expect(state.visibleConversations, isEmpty);
      });
    });

    blocTest<ConversationListBloc, ConversationListState>(
      'routes vanished-stream IO errors through the bloc error channel',
      setUp: () {
        when(
          () => mockProfileRepository.watchVanishedPubkeys(),
        ).thenAnswer((_) => Stream.error(Exception('db failure')));
      },
      build: createBloc,
      errors: () => [isA<Exception>()],
    );

    test('a live counterparty still matches its generated name', () async {
      stubVanished(const {});
      _stubStreams(
        mockDmRepository,
        accepted: [_createConversation(id: 'live')],
      );
      final bloc = createBloc(withLabels: labels);
      addTearDown(bloc.close);

      final state = await search(
        bloc,
        UserProfile.defaultDisplayNameFor(_testPubkey2),
      );

      expect(
        state.visibleConversations.map((c) => c.id).toList(),
        equals(['live']),
        reason: 'the vanished branch must not swallow ordinary rows',
      );
    });

    test('a vanish arriving after the query re-filters on its own', () async {
      // The row learns of a vanish from its own singular profile fetch, which
      // can land after the index was built. Without a live subscription the
      // results would stay wrong until the next keystroke.
      final vanished = StreamController<Set<String>>();
      addTearDown(vanished.close);
      when(
        () => mockProfileRepository.watchVanishedPubkeys(),
      ).thenAnswer((_) => vanished.stream);
      _stubStreams(
        mockDmRepository,
        accepted: [_createConversation(id: 'vanished')],
      );
      final bloc = createBloc(withLabels: labels);
      addTearDown(bloc.close);

      final before = await search(bloc, labels.deletedAccount);
      expect(before.visibleConversations, isEmpty);

      vanished.add({_testPubkey2});

      final after = await firstMatch(
        bloc,
        (s) => s.visibleConversations.isNotEmpty,
      );
      expect(after.visibleConversations.map((c) => c.id).toList(), [
        'vanished',
      ]);
    });

    test('changing the app language re-filters into the new one', () async {
      stubVanished({_testPubkey2});
      final german = lookupAppLocalizations(const Locale('de'));
      _stubStreams(
        mockDmRepository,
        accepted: [_createConversation(id: 'vanished')],
      );
      final bloc = createBloc(withLabels: labels);
      addTearDown(bloc.close);

      final inGerman = await search(bloc, german.profileDeletedAccountName);
      expect(
        inGerman.visibleConversations,
        isEmpty,
        reason: 'the German label must not match while the app is in English',
      );

      bloc.add(
        ConversationListPeerLabelsChanged(
          DmPeerLabels(
            deletedAccount: german.profileDeletedAccountName,
            moderation: german.inboxSupportRowTitle,
            retiredConversationClosed: german.dmRetiredThreadClosedTitle,
          ),
        ),
      );

      final after = await firstMatch(
        bloc,
        (s) => s.visibleConversations.isNotEmpty,
      );
      expect(after.visibleConversations.map((c) => c.id).toList(), [
        'vanished',
      ]);
    });

    test('a repository swap re-points the vanished subscription', () async {
      stubVanished(const {});
      _stubStreams(
        mockDmRepository,
        accepted: [_createConversation(id: 'vanished')],
      );
      final bloc = createBloc(withLabels: labels);
      addTearDown(bloc.close);
      await search(bloc, labels.deletedAccount);

      final swapped = _MockProfileRepository();
      when(
        () => swapped.fetchBatchProfiles(pubkeys: any(named: 'pubkeys')),
      ).thenAnswer((_) async => const {});
      when(
        swapped.watchVanishedPubkeys,
      ).thenAnswer((_) => Stream.value({_testPubkey2}));

      bloc.add(ConversationListProfileRepositoryChanged(swapped));

      final after = await firstMatch(
        bloc,
        (s) => s.visibleConversations.isNotEmpty,
      );
      expect(after.visibleConversations.map((c) => c.id).toList(), [
        'vanished',
      ]);
    });
  });

  group('ConversationListSearchQueryChanged', () {
    late _MockDmRepository mockDmRepository;
    late _MockFollowRepository mockFollowRepository;
    late _MockProfileRepository mockProfileRepository;

    setUp(() {
      mockDmRepository = _MockDmRepository();
      mockFollowRepository = _MockFollowRepository();
      mockProfileRepository = _MockProfileRepository();

      when(() => mockFollowRepository.isFollowing(any())).thenReturn(true);
      when(
        () => mockFollowRepository.followingStream,
      ).thenAnswer((_) => const Stream<List<String>>.empty());
      when(
        () => mockDmRepository.backfillHistoryIfNeeded(),
      ).thenAnswer((_) async {});
      when(
        () => mockDmRepository.retryPendingDecryptions(),
      ).thenAnswer((_) async {});
      when(
        () => mockProfileRepository.fetchBatchProfiles(
          pubkeys: any(named: 'pubkeys'),
        ),
      ).thenAnswer((_) async => const {});
      when(
        () => mockProfileRepository.watchVanishedPubkeys(),
      ).thenAnswer((_) => Stream.value(const <String>{}));
    });

    ConversationListBloc createBloc({bool withProfiles = true}) =>
        ConversationListBloc(
          dmRepository: mockDmRepository,
          followRepository: mockFollowRepository,
          profileRepository: withProfiles ? mockProfileRepository : null,
          recomputeDebounce: Duration.zero,
        );

    List<DmConversation> conversations() => [
      _createConversation(id: 'pizza', lastMessageContent: 'pizza friday?'),
      _createConversation(
        id: 'alice',
        lastMessageContent: 'see you soon',
        participantPubkeys: const [_testPubkey1, _testPubkey3],
      ),
    ];

    Future<ConversationListState> load(ConversationListBloc bloc) async {
      bloc.add(const ConversationListStarted());
      return bloc.stream.firstWhere(
        (s) => s.status == ConversationListStatus.loaded,
      );
    }

    test('filters by last message content', () async {
      _stubStreams(mockDmRepository, accepted: conversations());
      final bloc = createBloc();
      addTearDown(bloc.close);
      await load(bloc);

      bloc.add(const ConversationListSearchQueryChanged('pizza'));
      final state = await bloc.stream.firstWhere(
        (s) => s.searchQuery == 'pizza',
      );

      expect(
        state.visibleConversations.map((c) => c.id).toList(),
        equals(['pizza']),
      );
    });

    test(
      'single-character search does not fan out profile resolution',
      () async {
        _stubStreams(mockDmRepository, accepted: conversations());
        final bloc = createBloc();
        addTearDown(bloc.close);
        await load(bloc);

        bloc.add(const ConversationListSearchQueryChanged('p'));
        await Future<void>.delayed(const Duration(milliseconds: 350));

        expect(
          bloc.state.searchQuery,
          isEmpty,
          reason: 'inbox search follows the shared minSearchQueryLength gate',
        );
        expect(
          bloc.state.visibleConversations.map((c) => c.id).toList(),
          equals(['pizza', 'alice']),
        );
        verifyNever(
          () => mockProfileRepository.fetchBatchProfiles(
            pubkeys: any(named: 'pubkeys'),
          ),
        );
      },
    );

    // `profileRepositoryProvider` is nullable-gated on Nostr readiness, so the
    // inbox can mount before it resolves. The instance is delivered in place
    // rather than by re-keying the BlocProvider — a key on that provider is the
    // outermost entry of the nested chain and would tear down every other inbox
    // bloc and the whole InboxView subtree with it.
    test(
      'late-bound ProfileRepository re-resolves the active search',
      () async {
        _stubStreams(mockDmRepository, accepted: conversations());
        when(
          () => mockProfileRepository.fetchBatchProfiles(
            pubkeys: any(named: 'pubkeys'),
          ),
        ).thenAnswer(
          (_) async => {
            _testPubkey3: UserProfile(
              pubkey: _testPubkey3,
              displayName: 'Alice Wonder',
              rawData: const {},
              createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              eventId: _testConversationId1,
            ),
          },
        );
        when(
          () => mockProfileRepository.watchVanishedPubkeys(),
        ).thenAnswer((_) => Stream.value(const <String>{}));

        // Cold start: the repository is not ready yet.
        final bloc = createBloc(withProfiles: false);
        addTearDown(bloc.close);
        await load(bloc);

        bloc.add(const ConversationListSearchQueryChanged('alice w'));
        final unresolved = await bloc.stream.firstWhere(
          (s) => s.searchQuery == 'alice w',
        );
        expect(
          unresolved.visibleConversations,
          isEmpty,
          reason: 'no repository yet, so only the fallback name is available',
        );

        // The provider hands over the ready instance.
        bloc.add(
          ConversationListProfileRepositoryChanged(mockProfileRepository),
        );

        final resolved = await bloc.stream.firstWhere(
          (s) => s.visibleConversations.isNotEmpty,
        );
        expect(
          resolved.visibleConversations.map((c) => c.id).toList(),
          equals(['alice']),
          reason: 'the active query must re-resolve against the ready instance',
        );
      },
    );

    test('ignores a repository swap to the identical instance', () async {
      _stubStreams(mockDmRepository, accepted: conversations());
      final bloc = createBloc();
      addTearDown(bloc.close);
      await load(bloc);

      bloc.add(const ConversationListSearchQueryChanged('pizza'));
      // Wait for the staged name resolution to settle, so the only thing that
      // could emit afterwards is the repository swap under test.
      final before = await bloc.stream.firstWhere(
        (s) => s.searchQuery == 'pizza' && s.profileNames.isNotEmpty,
      );

      final emitted = <ConversationListState>[];
      final subscription = bloc.stream.listen(emitted.add);
      addTearDown(subscription.cancel);

      bloc.add(
        ConversationListProfileRepositoryChanged(mockProfileRepository),
      );
      await Future<void>.delayed(Duration.zero);

      expect(
        emitted,
        isEmpty,
        reason: 'a redundant provider fire must not churn the search',
      );
      expect(bloc.state, equals(before));
    });

    test('matches counterparty display name via ProfileRepository', () async {
      _stubStreams(mockDmRepository, accepted: conversations());
      when(
        () => mockProfileRepository.fetchBatchProfiles(
          pubkeys: any(named: 'pubkeys'),
        ),
      ).thenAnswer(
        (_) async => {
          _testPubkey3: UserProfile(
            pubkey: _testPubkey3,
            displayName: 'Alice Wonder',
            rawData: const {},
            createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
            eventId: _testConversationId1,
          ),
        },
      );
      when(
        () => mockProfileRepository.watchVanishedPubkeys(),
      ).thenAnswer((_) => Stream.value(const <String>{}));
      final bloc = createBloc();
      addTearDown(bloc.close);
      await load(bloc);

      bloc.add(const ConversationListSearchQueryChanged('alice w'));

      // Resolution is staged: the query lands immediately on what needs no
      // lookup, then refines once the profile batch resolves.
      final immediate = await bloc.stream.firstWhere(
        (s) => s.searchQuery == 'alice w',
      );
      expect(
        immediate.profileNames,
        isEmpty,
        reason: 'first emit must not wait on the network',
      );

      final state = await bloc.stream.firstWhere(
        (s) => s.profileNames.containsKey(_testPubkey3),
      );
      expect(
        state.visibleConversations.map((c) => c.id).toList(),
        equals(['alice']),
      );
      expect(state.profileNames[_testPubkey3], equals('Alice Wonder'));
    });

    test(
      'failed profile resolution still caches fallback names',
      () async {
        _stubStreams(mockDmRepository, accepted: conversations());
        when(
          () => mockProfileRepository.fetchBatchProfiles(
            pubkeys: any(named: 'pubkeys'),
          ),
        ).thenThrow(Exception('relay offline'));
        final bloc = createBloc();
        addTearDown(bloc.close);
        await load(bloc);

        bloc.add(const ConversationListSearchQueryChanged('alice'));
        final state = await bloc.stream.firstWhere(
          (s) => s.profileNames.containsKey(_testPubkey2),
        );

        expect(
          state.profileNames.keys,
          containsAll([_testPubkey2, _testPubkey3]),
        );
        expect(
          state.profileNames[_testPubkey2],
          equals(UserProfile.defaultDisplayNameFor(_testPubkey2)),
        );
        expect(
          state.profileNames[_testPubkey3],
          equals(UserProfile.defaultDisplayNameFor(_testPubkey3)),
        );
      },
    );

    test('resolves each pubkey at most once across queries', () async {
      _stubStreams(mockDmRepository, accepted: conversations());
      final bloc = createBloc();
      addTearDown(bloc.close);
      await load(bloc);

      bloc.add(const ConversationListSearchQueryChanged('one'));
      await bloc.stream.firstWhere((s) => s.searchQuery == 'one');
      bloc.add(const ConversationListSearchQueryChanged('two'));
      await bloc.stream.firstWhere((s) => s.searchQuery == 'two');

      verify(
        () => mockProfileRepository.fetchBatchProfiles(
          pubkeys: any(named: 'pubkeys'),
        ),
      ).called(1);
    });

    test('clearing the query restores the full list', () async {
      _stubStreams(mockDmRepository, accepted: conversations());
      final bloc = createBloc();
      addTearDown(bloc.close);
      await load(bloc);

      bloc.add(const ConversationListSearchQueryChanged('pizza'));
      await bloc.stream.firstWhere((s) => s.searchQuery == 'pizza');
      bloc.add(const ConversationListSearchQueryChanged(''));
      final state = await bloc.stream.firstWhere((s) => s.searchQuery.isEmpty);

      expect(state.visibleConversations, hasLength(2));
    });

    test('composes with the unread filter', () async {
      _stubStreams(
        mockDmRepository,
        accepted: [
          _createConversation(
            id: 'pizza-unread',
            isRead: false,
            lastMessageContent: 'pizza friday?',
          ),
          _createConversation(
            id: 'pizza-read',
            lastMessageContent: 'pizza saturday?',
          ),
        ],
      );
      final bloc = createBloc();
      addTearDown(bloc.close);
      await load(bloc);

      bloc.add(const ConversationListFilterChanged(InboxFilter.unread));
      await bloc.stream.firstWhere((s) => s.filter == InboxFilter.unread);
      bloc.add(const ConversationListSearchQueryChanged('pizza'));
      final state = await bloc.stream.firstWhere(
        (s) => s.searchQuery == 'pizza',
      );

      expect(
        state.visibleConversations.map((c) => c.id).toList(),
        equals(['pizza-unread']),
      );
    });

    test('search works without a ProfileRepository (fallback names)', () async {
      _stubStreams(mockDmRepository, accepted: conversations());
      final bloc = createBloc(withProfiles: false);
      addTearDown(bloc.close);
      await load(bloc);

      bloc.add(const ConversationListSearchQueryChanged('pizza'));
      final state = await bloc.stream.firstWhere(
        (s) => s.searchQuery == 'pizza',
      );

      expect(
        state.visibleConversations.map((c) => c.id).toList(),
        equals(['pizza']),
      );
    });

    test(
      'a conversation streaming in during an active search is re-resolved '
      'and surfaces without another keystroke',
      () async {
        final acceptedController = StreamController<List<DmConversation>>();
        _stubStreams(mockDmRepository);
        when(
          () => mockDmRepository.watchAcceptedConversations(
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) => acceptedController.stream);
        when(
          () => mockProfileRepository.fetchBatchProfiles(
            pubkeys: any(named: 'pubkeys'),
          ),
        ).thenAnswer(
          (_) async => {
            _testPubkey3: UserProfile(
              pubkey: _testPubkey3,
              displayName: 'Alice Wonder',
              rawData: const {},
              createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              eventId: _testConversationId1,
            ),
          },
        );
        when(
          () => mockProfileRepository.watchVanishedPubkeys(),
        ).thenAnswer((_) => Stream.value(const <String>{}));

        final bloc = createBloc()..add(const ConversationListStarted());
        addTearDown(() async {
          await bloc.close();
          await acceptedController.close();
        });

        acceptedController.add([
          _createConversation(id: 'pizza', lastMessageContent: 'pizza friday?'),
        ]);
        await bloc.stream.firstWhere(
          (s) => s.status == ConversationListStatus.loaded,
        );

        bloc.add(const ConversationListSearchQueryChanged('alice'));
        await bloc.stream.firstWhere((s) => s.searchQuery == 'alice');
        // Alice is not in the list yet, so nothing matches.
        expect(bloc.state.visibleConversations, isEmpty);

        // Alice's conversation arrives — her name was never resolved, so
        // without the data-path re-resolution it would stay filtered out.
        acceptedController.add([
          _createConversation(id: 'pizza', lastMessageContent: 'pizza friday?'),
          _createConversation(
            id: 'alice',
            lastMessageContent: 'see you soon',
            participantPubkeys: const [_testPubkey1, _testPubkey3],
          ),
        ]);

        final state = await bloc.stream.firstWhere(
          (s) => s.visibleConversations.any((c) => c.id == 'alice'),
        );
        expect(
          state.visibleConversations.map((c) => c.id),
          contains('alice'),
        );
      },
    );

    test(
      'stream re-resolution does not supersede a newer pending keystroke',
      () async {
        final acceptedController = StreamController<List<DmConversation>>();
        _stubStreams(mockDmRepository);
        when(
          () => mockDmRepository.watchAcceptedConversations(
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) => acceptedController.stream);
        when(
          () => mockProfileRepository.fetchBatchProfiles(
            pubkeys: any(named: 'pubkeys'),
          ),
        ).thenAnswer(
          (_) async => {
            _testPubkey3: UserProfile(
              pubkey: _testPubkey3,
              displayName: 'Alice Wonder',
              rawData: const {},
              createdAt: DateTime.fromMillisecondsSinceEpoch(1700000000000),
              eventId: _testConversationId1,
            ),
          },
        );
        when(
          () => mockProfileRepository.watchVanishedPubkeys(),
        ).thenAnswer((_) => Stream.value(const <String>{}));

        final bloc = createBloc()..add(const ConversationListStarted());
        addTearDown(() async {
          await bloc.close();
          await acceptedController.close();
        });

        acceptedController.add([
          _createConversation(id: 'pizza', lastMessageContent: 'pizza friday?'),
        ]);
        await bloc.stream.firstWhere(
          (s) => s.status == ConversationListStatus.loaded,
        );

        bloc.add(const ConversationListSearchQueryChanged('alice'));
        await bloc.stream.firstWhere((s) => s.searchQuery == 'alice');

        final pendingQueryApplied = bloc.stream.firstWhere(
          (state) => state.searchQuery == 'alice w',
        );
        bloc.add(const ConversationListSearchQueryChanged('alice w'));
        acceptedController.add([
          _createConversation(id: 'pizza', lastMessageContent: 'pizza friday?'),
          _createConversation(
            id: 'alice',
            lastMessageContent: 'see you soon',
            participantPubkeys: const [_testPubkey1, _testPubkey3],
          ),
        ]);

        await pendingQueryApplied;

        expect(
          bloc.state.searchQuery,
          equals('alice w'),
          reason:
              'data-path profile resolution must not enqueue the previous '
              'query into the debounced user-input stream',
        );
        expect(
          bloc.state.visibleConversations.map((c) => c.id),
          contains('alice'),
        );
      },
    );

    // Mirror of the test above, for the other path that re-resolves an active
    // query: _onProfileRepositoryChanged. Both must re-resolve without
    // enqueueing `state.searchQuery` into the debounced user-input stream,
    // where it would supersede a keystroke that has not fired yet.
    test(
      'repository swap does not supersede a newer pending keystroke',
      () async {
        final acceptedController = StreamController<List<DmConversation>>();
        _stubStreams(mockDmRepository);
        when(
          () => mockDmRepository.watchAcceptedConversations(
            limit: any(named: 'limit'),
          ),
        ).thenAnswer((_) => acceptedController.stream);
        when(
          () => mockProfileRepository.fetchBatchProfiles(
            pubkeys: any(named: 'pubkeys'),
          ),
        ).thenAnswer((_) async => const <String, UserProfile>{});
        when(
          () => mockProfileRepository.watchVanishedPubkeys(),
        ).thenAnswer((_) => Stream.value(const <String>{}));

        // Cold start: the nullable-gated provider has not handed over yet.
        final bloc = ConversationListBloc(
          dmRepository: mockDmRepository,
          followRepository: mockFollowRepository,
          recomputeDebounce: Duration.zero,
        )..add(const ConversationListStarted());
        addTearDown(() async {
          await bloc.close();
          await acceptedController.close();
        });

        acceptedController.add([
          _createConversation(id: 'pizza', lastMessageContent: 'pizza friday?'),
        ]);
        await bloc.stream.firstWhere(
          (s) => s.status == ConversationListStatus.loaded,
        );

        // User commits 'alice'...
        bloc.add(const ConversationListSearchQueryChanged('alice'));
        await bloc.stream.firstWhere((s) => s.searchQuery == 'alice');

        // ...then types one more character; still inside the 300ms debounce.
        final pendingQueryApplied = bloc.stream.firstWhere(
          (state) => state.searchQuery == 'alice w',
        );
        bloc.add(const ConversationListSearchQueryChanged('alice w'));

        // Nostr becomes ready and the provider hands over the repository.
        bloc.add(
          ConversationListProfileRepositoryChanged(mockProfileRepository),
        );

        await pendingQueryApplied;

        expect(
          bloc.state.searchQuery,
          equals('alice w'),
          reason:
              'the repository swap must not enqueue the previous query into '
              'the debounced user-input stream and rewind what the user typed',
        );
      },
    );
  });

  // Subscription lifecycle (#2931)
  // -------------------------------------------------------------------

  group('subscription lifecycle (#2931)', () {
    late _MockDmRepository mockDmRepository;
    late _MockFollowRepository mockFollowRepository;

    setUp(() {
      mockDmRepository = _MockDmRepository();
      mockFollowRepository = _MockFollowRepository();

      when(() => mockFollowRepository.isFollowing(any())).thenReturn(true);
      when(
        () => mockFollowRepository.followingStream,
      ).thenAnswer((_) => const Stream<List<String>>.empty());
      when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey1);
      when(
        () => mockDmRepository.hasCompletedHistoryRecoveryBefore,
      ).thenReturn(true);
      when(() => mockDmRepository.startListening()).thenAnswer((_) async {});
      when(() => mockDmRepository.stopListening()).thenAnswer((_) async {});
      when(
        () => mockDmRepository.backfillHistoryIfNeeded(),
      ).thenAnswer((_) async {});
      when(
        () => mockDmRepository.retryPendingDecryptions(),
      ).thenAnswer((_) async {});
    });

    blocTest<ConversationListBloc, ConversationListState>(
      'does not call startListening — auth-scoped via dmRepositoryProvider',
      build: () {
        _stubStreams(mockDmRepository);
        return ConversationListBloc(
          dmRepository: mockDmRepository,
          followRepository: mockFollowRepository,
        );
      },
      act: (bloc) => bloc.add(const ConversationListStarted()),
      verify: (_) {
        // Regression guard for #2931: the gift-wrap subscription lives
        // for the whole authenticated session via `dmRepositoryProvider`.
        // The BLoC must not start it on its own — that would break the
        // session-wide ingestion contract by creating overlapping
        // subscription bookkeeping.
        verifyNever(() => mockDmRepository.startListening());
      },
    );

    test('does not call stopListening on close', () async {
      _stubStreams(mockDmRepository);
      final bloc = ConversationListBloc(
        dmRepository: mockDmRepository,
        followRepository: mockFollowRepository,
      );

      await bloc.close();

      // Regression guard for #2931: closing the BLoC must NOT stop the
      // gift-wrap subscription. Doing so would silently break DM ingestion
      // for users who navigated away from the inbox tab.
      verifyNever(() => mockDmRepository.stopListening());
    });
  });

  group('pinned support row (#6283)', () {
    late _MockDmRepository mockDmRepository;
    late _MockFollowRepository mockFollowRepository;

    setUp(() {
      mockDmRepository = _MockDmRepository();
      mockFollowRepository = _MockFollowRepository();

      when(() => mockFollowRepository.isFollowing(any())).thenReturn(true);
      when(
        () => mockFollowRepository.followingStream,
      ).thenAnswer((_) => const Stream<List<String>>.empty());
      when(() => mockDmRepository.userPubkey).thenReturn(_testPubkey1);
      when(
        () => mockDmRepository.hasCompletedHistoryRecoveryBefore,
      ).thenReturn(true);
      when(() => mockDmRepository.startListening()).thenAnswer((_) async {});
      when(() => mockDmRepository.stopListening()).thenAnswer((_) async {});
      when(
        () => mockDmRepository.backfillHistoryIfNeeded(),
      ).thenAnswer((_) async {});
      when(
        () => mockDmRepository.retryPendingDecryptions(),
      ).thenAnswer((_) async {});
    });

    // The shipped moderation pin, and a key retired in #2321 — a thread opened
    // before that rotation is still keyed on it.
    const moderationPubkey = kModerationPubkeyHex;
    final legacyModerationPubkey = kLegacyModerationPubkeys.first;

    final supportId = DmRepository.computeConversationId([
      _testPubkey1,
      moderationPubkey,
    ]);
    final legacySupportId = DmRepository.computeConversationId([
      _testPubkey1,
      legacyModerationPubkey,
    ]);

    ConversationListBloc createSupportBloc({
      ContentBlocklistRepository? blocklist,
      ProtectedMinorInboxGate? gate,
    }) => ConversationListBloc(
      dmRepository: mockDmRepository,
      followRepository: mockFollowRepository,
      contentBlocklistRepository: blocklist,
      protectedMinorInboxGate: gate,
      recomputeDebounce: Duration.zero,
      supportRowPubkey: moderationPubkey,
    );

    Future<ConversationListState> loadedState(
      ConversationListBloc bloc,
    ) async {
      bloc.add(const ConversationListStarted());
      return bloc.stream.firstWhere(
        (s) => s.status == ConversationListStatus.loaded,
      );
    }

    test('is null when no moderation pubkey is injected', () async {
      // Every construction site outside the inbox omits supportRowPubkey;
      // the pin must stay off for them rather than synthesizing a row
      // pointing at an empty counterparty.
      _stubStreams(mockDmRepository);
      final bloc = ConversationListBloc(
        dmRepository: mockDmRepository,
        followRepository: mockFollowRepository,
        recomputeDebounce: Duration.zero,
      );
      addTearDown(bloc.close);

      final state = await loadedState(bloc);

      expect(state.pinnedSupport, isNull);
    });

    test('synthesizes a pin when no moderation thread exists', () async {
      _stubStreams(mockDmRepository);
      final bloc = createSupportBloc();
      addTearDown(bloc.close);

      final state = await loadedState(bloc);

      expect(state.pinnedSupport, isNotNull);
      expect(state.pinnedSupport!.conversation.id, equals(supportId));
      expect(
        state.pinnedSupport!.conversation.participantPubkeys,
        containsAll([_testPubkey1, moderationPubkey]),
      );
      // Nothing to preview and nothing unread until the team replies —
      // this is what keeps the row visually matching divine-web.
      expect(state.pinnedSupport!.conversation.lastMessageContent, isNull);
      expect(state.pinnedSupport!.conversation.isRead, isTrue);
    });

    test(
      'adopts the real thread and removes it from the list, so the inbox '
      'never shows Divine Moderation twice',
      () async {
        final supportThread = _createConversation(
          id: supportId,
          currentUserHasSent: true,
          isRead: false,
          lastMessageContent: 'We looked into your report.',
          participantPubkeys: const [_testPubkey1, moderationPubkey],
        );
        final other = _createConversation(
          id: _testConversationId2,
          currentUserHasSent: true,
        );
        _stubStreams(mockDmRepository, accepted: [supportThread, other]);
        final bloc = createSupportBloc();
        addTearDown(bloc.close);

        final state = await loadedState(bloc);

        expect(state.pinnedSupport?.conversation.id, equals(supportId));
        // The pin carries the real unread state, so the Messages badge
        // still corresponds to something the user can see.
        expect(state.pinnedSupport!.conversation.isRead, isFalse);
        expect(
          state.pinnedSupport!.conversation.lastMessageContent,
          equals('We looked into your report.'),
        );
        expect(
          state.conversations.map((c) => c.id),
          isNot(contains(supportId)),
        );
        expect(
          state.conversations.map((c) => c.id),
          contains(_testConversationId2),
        );
      },
    );

    test(
      'absorbs an inbound-only moderation thread out of message requests',
      () async {
        // The team wrote first: currentUserHasSent == false, and the user
        // does not follow moderation, so it classifies as a request.
        when(
          () => mockFollowRepository.isFollowing(moderationPubkey),
        ).thenReturn(false);
        final inbound = _createConversation(
          id: supportId,
          participantPubkeys: const [_testPubkey1, moderationPubkey],
        );
        _stubStreams(mockDmRepository, potentialRequests: [inbound]);
        final bloc = createSupportBloc();
        addTearDown(bloc.close);

        final state = await loadedState(bloc);

        expect(state.pinnedSupport?.conversation.id, equals(supportId));
        expect(
          state.requestConversations.map((c) => c.id),
          isNot(contains(supportId)),
        );
      },
    );

    test(
      'keeps pre-rotation legacy history visible and pins the CURRENT key, '
      'so a reply can never reach the retired pubkey',
      () async {
        final legacyThread = _createConversation(
          id: legacySupportId,
          currentUserHasSent: true,
          participantPubkeys: [_testPubkey1, legacyModerationPubkey],
        );
        _stubStreams(mockDmRepository, accepted: [legacyThread]);
        final bloc = createSupportBloc();
        addTearDown(bloc.close);

        final state = await loadedState(bloc);

        // Nothing remaps the recipient between the row's `extra` and
        // sendMessage, so adopting the legacy thread would silently address
        // support replies to a key the team retired in #2321.
        expect(state.pinnedSupport?.conversation.id, equals(supportId));
        expect(
          state.pinnedSupport?.conversation.participantPubkeys,
          isNot(contains(legacyModerationPubkey)),
        );
        // Synthetic, not adopted — the legacy thread's history does not
        // travel with the pin.
        expect(state.pinnedSupport?.isPersisted, isFalse);
        expect(state.conversations, equals([legacyThread]));
      },
    );

    test(
      'dedupes the current thread when BOTH a legacy and a current thread '
      'exist, while preserving legacy history',
      () async {
        final legacyThread = _createConversation(
          id: legacySupportId,
          currentUserHasSent: true,
          participantPubkeys: [_testPubkey1, legacyModerationPubkey],
        );
        final currentThread = _createConversation(
          id: supportId,
          currentUserHasSent: true,
          participantPubkeys: const [_testPubkey1, moderationPubkey],
        );
        _stubStreams(
          mockDmRepository,
          accepted: [legacyThread, currentThread],
        );
        final bloc = createSupportBloc();
        addTearDown(bloc.close);

        final state = await loadedState(bloc);

        expect(state.pinnedSupport?.conversation.id, equals(supportId));
        expect(state.pinnedSupport?.isPersisted, isTrue);
        expect(state.conversations, equals([legacyThread]));
      },
    );

    test('keeps a legacy thread visible in message requests too', () async {
      final legacyInbound = _createConversation(
        id: legacySupportId,
        participantPubkeys: [_testPubkey1, legacyModerationPubkey],
      );
      when(() => mockFollowRepository.isFollowing(any())).thenReturn(false);
      _stubStreams(mockDmRepository, potentialRequests: [legacyInbound]);
      final bloc = createSupportBloc();
      addTearDown(bloc.close);

      final state = await loadedState(bloc);

      expect(state.requestConversations, equals([legacyInbound]));
      expect(state.pinnedSupport?.conversation.id, equals(supportId));
    });

    test(
      'emits no pin when the signed-in user IS the moderation account',
      () async {
        _stubStreams(mockDmRepository);
        // After _stubStreams, which seeds userPubkey itself.
        when(() => mockDmRepository.userPubkey).thenReturn(moderationPubkey);
        final bloc = ConversationListBloc(
          dmRepository: mockDmRepository,
          followRepository: mockFollowRepository,
          recomputeDebounce: Duration.zero,
          supportRowPubkey: moderationPubkey,
        );
        addTearDown(bloc.close);

        final state = await loadedState(bloc);

        // A self-keyed pin routes with an empty counterparty list, and the
        // maintenance pass deletes self-conversations out from under it.
        expect(state.pinnedSupport, isNull);
      },
    );

    test(
      'leaves a group conversation containing moderation in the list',
      () async {
        final group = _createConversation(
          id: 'group-with-moderation',
          currentUserHasSent: true,
          participantPubkeys: const [
            _testPubkey1,
            moderationPubkey,
            _testPubkey2,
          ],
          isGroup: true,
        );
        _stubStreams(mockDmRepository, accepted: [group]);
        final bloc = createSupportBloc();
        addTearDown(bloc.close);

        final state = await loadedState(bloc);

        // The id is a hash over ALL sorted participants, so a group can never
        // collide with the 1:1 support thread.
        expect(state.conversations, contains(group));
        expect(state.pinnedSupport?.isPersisted, isFalse);
      },
    );

    test(
      'keeps an unread inbound moderation thread pinned during history '
      'recovery, while the requests list stays held back',
      () async {
        final inbound = _createConversation(
          id: supportId,
          isRead: false,
          participantPubkeys: const [_testPubkey1, moderationPubkey],
        );
        final stranger = _createConversation(
          id: 'stranger-request',
          isRead: false,
          participantPubkeys: const [_testPubkey1, _testPubkey2],
        );
        when(() => mockFollowRepository.isFollowing(any())).thenReturn(false);
        _stubStreams(
          mockDmRepository,
          potentialRequests: [inbound, stranger],
          recoveryComplete: false,
        );
        final bloc = createSupportBloc();
        addTearDown(bloc.close);

        final state = await loadedState(bloc);

        // The pin is extracted ahead of the #5304 hold-back: it never lands in
        // a bucket, so it cannot flash between two, and blanking its unread
        // dot for the length of the drain would just hide a real reply.
        expect(state.pinnedSupport?.isPersisted, isTrue);
        expect(state.pinnedSupport?.conversation.isRead, isFalse);
        expect(state.requestConversations, isEmpty);
        // The stranger IS hidden by the gate, so #6431's banner is owed.
        expect(state.requestsWithheld, isTrue);
      },
    );

    test(
      'does not claim requests are withheld when the pin is the only one',
      () async {
        final inbound = _createConversation(
          id: supportId,
          isRead: false,
          participantPubkeys: const [_testPubkey1, moderationPubkey],
        );
        when(() => mockFollowRepository.isFollowing(any())).thenReturn(false);
        _stubStreams(
          mockDmRepository,
          potentialRequests: [inbound],
          recoveryComplete: false,
        );
        final bloc = createSupportBloc();
        addTearDown(bloc.close);

        final state = await loadedState(bloc);

        // #6431's restore-paused banner reports that the recovery gate is
        // hiding would-be requests. Here the only one is the moderation
        // thread, which the gate is NOT hiding — it is on screen as the pin.
        // Measuring the flag against the raw classification instead of the
        // post-pin set would promise a Retry with nothing behind it.
        expect(state.pinnedSupport?.isPersisted, isTrue);
        expect(state.requestConversations, isEmpty);
        expect(state.requestsWithheld, isFalse);
      },
    );

    test(
      'does not leave the pin in message requests once recovery completes',
      () async {
        final inbound = _createConversation(
          id: supportId,
          isRead: false,
          participantPubkeys: const [_testPubkey1, moderationPubkey],
        );
        when(() => mockFollowRepository.isFollowing(any())).thenReturn(false);
        _stubStreams(mockDmRepository, potentialRequests: [inbound]);
        final bloc = createSupportBloc();
        addTearDown(bloc.close);

        final state = await loadedState(bloc);

        expect(state.requestConversations, isEmpty);
        expect(state.pinnedSupport?.isPersisted, isTrue);
      },
    );

    test(
      'withholds a recovery-window pin the protected-minor gate rejects',
      () async {
        final inbound = _createConversation(
          id: supportId,
          isRead: false,
          participantPubkeys: const [_testPubkey1, moderationPubkey],
        );
        when(() => mockFollowRepository.isFollowing(any())).thenReturn(false);
        _stubStreams(
          mockDmRepository,
          potentialRequests: [inbound],
          recoveryComplete: false,
        );
        final bloc = createSupportBloc(
          gate: _FakeInboxGate(approved: const {}),
        );
        addTearDown(bloc.close);

        final state = await loadedState(bloc);

        // Extracting ahead of the hold-back must not also mean extracting
        // ahead of the filters — the route guard would bounce this row.
        expect(state.pinnedSupport, isNull);
      },
    );

    test(
      'is null for a restricted minor whose approval was revoked, so the '
      'row cannot be tapped into a route-guard bounce',
      () async {
        _stubStreams(mockDmRepository);
        final bloc = createSupportBloc(
          gate: _FakeInboxGate(approved: const {}),
        );
        addTearDown(bloc.close);

        final state = await loadedState(bloc);

        expect(state.pinnedSupport, isNull);
      },
    );

    test(
      'survives blocking the moderation account, unlike every other row',
      () async {
        // Reverses #6388's behaviour on purpose (#7850).
        //
        // #6388 suppressed the pin for a blocked peer on the stated grounds
        // that "ConversationPage's route guard bounces straight back to the
        // inbox". That is true of the #176 minor gate — which this test's
        // sibling above still covers — but NOT of the blocklist:
        // `ConversationPage`'s guard consults `isDmRestricted` and the
        // official-accounts predicate only, never the blocklist. So a blocked
        // pin opens normally; suppressing it removed the route to the
        // enforcement notice for nothing.
        //
        // The cost of getting this wrong was real: blocking is one tap in the
        // conversation sheet, the adopted pin never survives the list filter,
        // and #7025's recovery slice is reachable only through a chip that
        // renders conditionally on having blocked someone.
        final blocklist = _MockContentBlocklistRepository();
        when(
          () => blocklist.runtimeBlockedUsers,
        ).thenReturn(const <String>{});
        when(
          () => blocklist.filterBlockedConversations(
            any(),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((invocation) {
          final input =
              invocation.positionalArguments.first as List<DmConversation>;
          return input
              .where(
                (c) => !c.participantPubkeys.contains(moderationPubkey),
              )
              .toList();
        });
        _stubStreams(mockDmRepository);
        final bloc = createSupportBloc(blocklist: blocklist);
        addTearDown(bloc.close);

        final state = await loadedState(bloc);

        expect(state.pinnedSupport, isNotNull);
        expect(
          state.pinnedSupport!.conversation.participantPubkeys,
          contains(moderationPubkey),
        );
      },
    );

    test('survives an active search query', () async {
      _stubStreams(mockDmRepository);
      final bloc = createSupportBloc();
      addTearDown(bloc.close);

      await loadedState(bloc);
      bloc.add(const ConversationListSearchQueryChanged('zzzz'));
      final searched = await bloc.stream.firstWhere(
        (s) => s.searchQuery == 'zzzz',
      );

      // The bloc keeps composing the pin through a search so it is ready the
      // moment the query clears — no refetch, no flash of an empty row. The
      // decision to *render* it under an active filter belongs to the view,
      // which drops it from searches its title does not match.
      expect(searched.pinnedSupport, isNotNull);
    });
  });
}
