// ABOUTME: #7923 — the Messages badge counts from unread conversations only,
// ABOUTME: so a DM write does not re-read the whole inbox on every screen,
// ABOUTME: and still matches what the Messages list renders from the same rows.

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/blocs/dm/conversation_list/conversation_list_bloc.dart';
import 'package:openvine/blocs/dm/conversation_list/protected_minor_inbox_gate.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';

class _MockNostrClient extends Mock implements NostrClient {}

/// Lets every conversation through and records each counterparty it is
/// handed, which is whom a restricted gate re-checks in the background (#176).
class _RecordingGate implements ProtectedMinorInboxGate {
  final askedAbout = <String>{};
  final handed = <DmConversation>[];

  @override
  Stream<void> get changes => const Stream<void>.empty();

  @override
  void notifyRestrictionChanged() {}

  @override
  List<DmConversation> filter(
    List<DmConversation> conversations, {
    required String userPubkey,
  }) {
    handed.addAll(conversations);
    for (final conversation in conversations) {
      askedAbout.addAll(
        conversation.participantPubkeys.where((p) => p != userPubkey),
      );
    }
    return conversations;
  }
}

class _FakeFollowRepository extends Fake implements FollowRepository {
  _FakeFollowRepository(this._following);

  final Set<String> _following;

  @override
  Stream<List<String>> get followingStream => const Stream.empty();

  @override
  bool isFollowing(String pubkey) => _following.contains(pubkey);
}

/// The real repository, keeping every conversation it hands out.
class _RecordingDmRepository extends DmRepository {
  _RecordingDmRepository({
    required super.nostrClient,
    required super.directMessagesDao,
    required super.conversationsDao,
    super.userPubkey,
  });

  final delivered = <DmConversation>[];

  @override
  Stream<List<DmConversation>> watchAcceptedConversations({
    int? limit,
    bool unreadOnly = false,
  }) => super
      .watchAcceptedConversations(limit: limit, unreadOnly: unreadOnly)
      .map((rows) => rows..forEach(delivered.add));

  @override
  Stream<List<DmConversation>> watchPotentialRequests({
    bool unreadOnly = false,
  }) => super
      .watchPotentialRequests(unreadOnly: unreadOnly)
      .map((rows) => rows..forEach(delivered.add));
}

const _owner =
    'a4f5c1b2d3e4f5061728394a5b6c7d8e9f0a1b2c3d4e5f60718293a4b5c6d7e8';

String _peer(int i) => i.toRadixString(16).padLeft(64, '0');

void main() {
  group('$DmUnreadCountCubit unread source (#7923)', () {
    late AppDatabase db;
    late _RecordingDmRepository repository;
    late ContentBlocklistRepository blocklist;
    late DmUnreadCountCubit cubit;

    Future<void> seed(
      String peer, {
      required bool sent,
      required bool isRead,
      int timestamp = 1700000100,
    }) => db.conversationsDao.upsertConversation(
      id: DmRepository.computeConversationId([_owner, peer]),
      participantPubkeys: '["$_owner","$peer"]',
      isGroup: false,
      createdAt: 1700000000,
      lastMessageTimestamp: timestamp,
      lastMessageSenderPubkey: peer,
      isRead: isRead,
      currentUserHasSent: sent,
      ownerPubkey: _owner,
      isNewMessage: true,
    );

    setUp(() async {
      db = AppDatabase.test(NativeDatabase.memory());
      repository = _RecordingDmRepository(
        nostrClient: _MockNostrClient(),
        directMessagesDao: db.directMessagesDao,
        conversationsDao: db.conversationsDao,
        userPubkey: _owner,
      );
      blocklist = ContentBlocklistRepository();
      await blocklist.blockUsers([_peer(3)], ourPubkey: _owner);

      await seed(_peer(1), sent: true, isRead: true);
      await seed(_peer(2), sent: true, isRead: false);
      // Blocked: hidden from the inbox, so never counted.
      await seed(_peer(3), sent: true, isRead: false);
      // Followed: shown in the inbox although the viewer never replied.
      await seed(_peer(4), sent: false, isRead: false);
      // A stranger's request: lives under Message requests, not counted.
      await seed(_peer(5), sent: false, isRead: false);
      await seed(_peer(6), sent: false, isRead: true);

      cubit = DmUnreadCountCubit(
        dmRepository: repository,
        followRepository: _FakeFollowRepository({_peer(4), _peer(6)}),
        contentBlocklistRepository: blocklist,
        recomputeDebounce: Duration.zero,
      );
    });

    tearDown(() async {
      await cubit.close();
      await repository.stopListening();
      blocklist.dispose();
      await db.close();
    });

    Future<void> expectCount(int count) => expectLater(
      cubit.stream,
      emitsThrough(count),
    ).timeout(const Duration(seconds: 5));

    test('counts a conversation while it is unread, not once read', () async {
      await expectCount(2);

      // A read conversation gets a new message: it joins the count.
      await seed(_peer(1), sent: true, isRead: false, timestamp: 1700000200);
      await expectCount(3);

      // Reading one takes it back out.
      await db.conversationsDao.markAsRead(
        DmRepository.computeConversationId([_owner, _peer(2)]),
        ownerPubkey: _owner,
      );
      await expectCount(2);
    });

    test('is never handed a conversation the user has read', () async {
      await expectCount(2);

      expect(repository.delivered, isNotEmpty);
      expect(
        repository.delivered.where((c) => c.isRead).map((c) => c.id),
        isEmpty,
        reason:
            'the badge only counts unread rows, so reading the rest on every '
            'DM write is the per-message cost #7923 measured',
      );
    });

    test(
      'still hands the protected-minor gate the support account while its '
      'thread is read',
      () async {
        final supportPubkey = _peer(40);
        await seed(supportPubkey, sent: false, isRead: true);
        final gate = _RecordingGate();
        final supportAware = DmUnreadCountCubit(
          dmRepository: repository,
          followRepository: _FakeFollowRepository({_peer(4), _peer(6)}),
          contentBlocklistRepository: blocklist,
          protectedMinorInboxGate: gate,
          recomputeDebounce: Duration.zero,
          supportRowPubkey: supportPubkey,
        );
        addTearDown(supportAware.close);

        await expectLater(
          supportAware.stream,
          emitsThrough(2),
        ).timeout(const Duration(seconds: 5));

        expect(
          gate.askedAbout,
          contains(supportPubkey),
          reason:
              'the gate re-checks only whom it is handed, and with the inbox '
              'closed the badge is the only caller left to hand it this one',
        );
        expect(
          supportAware.state,
          equals(2),
          reason: 'the read stand-in must not be counted',
        );
      },
    );

    test(
      'hands the gate the same support stand-in as the Messages list',
      () async {
        final supportPubkey = _peer(40);
        final supportId = DmRepository.computeConversationId([
          _owner,
          supportPubkey,
        ]);
        final follows = _FakeFollowRepository({_peer(4), _peer(6)});
        final listGate = _RecordingGate();
        final badgeGate = _RecordingGate();
        final bloc = ConversationListBloc(
          dmRepository: repository,
          followRepository: follows,
          contentBlocklistRepository: blocklist,
          protectedMinorInboxGate: listGate,
          recomputeDebounce: Duration.zero,
          supportRowPubkey: supportPubkey,
        )..add(const ConversationListStarted());
        final badge = DmUnreadCountCubit(
          dmRepository: repository,
          followRepository: follows,
          contentBlocklistRepository: blocklist,
          protectedMinorInboxGate: badgeGate,
          recomputeDebounce: Duration.zero,
          supportRowPubkey: supportPubkey,
        );
        addTearDown(() async {
          await bloc.close();
          await badge.close();
        });

        await Future.wait([
          if (badge.state != 2) badge.stream.firstWhere((count) => count == 2),
          if (bloc.state.status != ConversationListStatus.loaded)
            bloc.stream.firstWhere(
              (s) => s.status == ConversationListStatus.loaded,
            ),
        ]).timeout(const Duration(seconds: 5));

        // No support thread exists, so both build a stand-in for the pin.
        DmConversation standIn(_RecordingGate gate) =>
            gate.handed.lastWhere((c) => c.id == supportId);
        expect(standIn(badgeGate), equals(standIn(listGate)));
      },
    );
  });

  group('$DmUnreadCountCubit parity with $ConversationListBloc (#7923)', () {
    late AppDatabase db;
    late DmRepository repository;
    late ContentBlocklistRepository blocklist;

    final blockedMember = _peer(30);
    final supportPubkey = _peer(40);
    late String readGroup;

    Future<String> seed(
      List<String> peers, {
      required bool sent,
      required bool isRead,
      String? lastSender,
      int timestamp = 1700000100,
    }) async {
      final participants = [_owner, ...peers];
      final id = DmRepository.computeConversationId(participants);
      await db.conversationsDao.upsertConversation(
        id: id,
        participantPubkeys: '[${participants.map((p) => '"$p"').join(',')}]',
        isGroup: peers.length > 1,
        createdAt: 1700000000,
        lastMessageTimestamp: timestamp,
        lastMessageSenderPubkey: lastSender ?? peers.first,
        isRead: isRead,
        currentUserHasSent: sent,
        ownerPubkey: _owner,
        isNewMessage: true,
      );
      return id;
    }

    Future<void> message(String conversationId, String sender, int at) =>
        db.directMessagesDao.insertMessage(
          id: 'rumor-$conversationId-$at',
          conversationId: conversationId,
          senderPubkey: sender,
          content: 'message at $at',
          createdAt: at,
          giftWrapId: 'wrap-$conversationId-$at',
          ownerPubkey: _owner,
        );

    setUp(() async {
      db = AppDatabase.test(NativeDatabase.memory());
      repository = DmRepository(
        nostrClient: _MockNostrClient(),
        directMessagesDao: db.directMessagesDao,
        conversationsDao: db.conversationsDao,
        userPubkey: _owner,
      );
      blocklist = ContentBlocklistRepository();
      await blocklist.blockUsers([_peer(3), blockedMember], ourPubkey: _owner);

      await seed([_peer(1)], sent: true, isRead: true);
      await seed([_peer(2)], sent: true, isRead: false);
      await seed([_peer(3)], sent: true, isRead: false);
      await seed([_peer(4)], sent: false, isRead: false);
      await seed([_peer(5)], sent: false, isRead: false);
      // The blocked member wrote last, but a visible member wrote before:
      // the group stays unread with the visible message (#10150).
      final stillUnread = await seed(
        [_peer(20), blockedMember],
        sent: true,
        isRead: false,
        lastSender: blockedMember,
      );
      await message(stillUnread, _peer(20), 1700000050);
      await message(stillUnread, blockedMember, 1700000100);
      // Only the blocked member wrote: the group turns read.
      final turnsRead = await seed(
        [_peer(21), blockedMember],
        sent: true,
        isRead: false,
        lastSender: blockedMember,
      );
      await message(turnsRead, blockedMember, 1700000100);
      // The moderation thread arrives as a request and is lifted into the
      // pinned row, unread dot and all (#6283).
      await seed([supportPubkey], sent: false, isRead: false);
      // Read rows only the list reads: a followed request, and a group stored
      // read whose visible member wrote past its read cursor. The hidden-member
      // pass may only turn a row read, so this one must stay read.
      await seed([_peer(6)], sent: false, isRead: true);
      readGroup = await seed(
        [_peer(22), blockedMember],
        sent: true,
        isRead: true,
        lastSender: blockedMember,
      );
      await message(readGroup, _peer(22), 1700000050);
      await message(readGroup, blockedMember, 1700000100);
    });

    tearDown(() async {
      await repository.stopListening();
      blocklist.dispose();
      await db.close();
    });

    test('counts the unread rows the Messages list renders', () async {
      final follows = _FakeFollowRepository({_peer(4), _peer(6)});
      final bloc = ConversationListBloc(
        dmRepository: repository,
        followRepository: follows,
        contentBlocklistRepository: blocklist,
        recomputeDebounce: Duration.zero,
        supportRowPubkey: supportPubkey,
      )..add(const ConversationListStarted());
      final cubit = DmUnreadCountCubit(
        dmRepository: repository,
        followRepository: follows,
        contentBlocklistRepository: blocklist,
        recomputeDebounce: Duration.zero,
        supportRowPubkey: supportPubkey,
      );
      addTearDown(() async {
        await bloc.close();
        await cubit.close();
      });

      int unreadRendered(ConversationListState state) =>
          state.conversations.where((c) => !c.isRead).length +
          (state.pinnedSupport?.conversation.isRead == false ? 1 : 0);

      // Both streams are broadcast and do not replay, so read the current
      // state first and only wait when it is not there yet.
      Future<void> reach(
        int Function() current,
        Stream<Object?> changes,
        int count,
      ) async {
        if (current() == count) return;
        await changes.firstWhere((_) => current() == count);
      }

      Future<void> expectBoth(int count) async {
        await Future.wait([
          reach(() => unreadRendered(bloc.state), bloc.stream, count),
          reach(() => cubit.state, cubit.stream, count),
        ]).timeout(const Duration(seconds: 5), onTimeout: () => const []);
        expect(
          unreadRendered(bloc.state),
          equals(count),
          reason: 'Messages list',
        );
        expect(cubit.state, equals(count), reason: 'Messages badge');
      }

      // Peer 2, followed peer 4, the group a visible member keeps unread,
      // and the pinned support row.
      await expectBoth(4);
      expect(bloc.state.pinnedSupport, isNotNull);
      expect(
        bloc.state.conversations.map((c) => c.id),
        containsAll([
          DmRepository.computeConversationId([_owner, _peer(1)]),
          DmRepository.computeConversationId([_owner, _peer(6)]),
          readGroup,
        ]),
        reason: 'the list still reads every row, read ones included',
      );

      await db.conversationsDao.markAsRead(
        DmRepository.computeConversationId([_owner, _peer(2)]),
        ownerPubkey: _owner,
      );
      await expectBoth(3);

      // Reading the support thread drops it from both, and the pin stays.
      await db.conversationsDao.markAsRead(
        DmRepository.computeConversationId([_owner, supportPubkey]),
        ownerPubkey: _owner,
      );
      await expectBoth(2);
      expect(bloc.state.pinnedSupport?.conversation.isRead, isTrue);
    });
  });
}
