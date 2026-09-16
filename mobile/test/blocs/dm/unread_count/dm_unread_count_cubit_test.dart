// ABOUTME: Unit tests for DmUnreadCountCubit.
// ABOUTME: Verifies the badge count mirrors the follow-aware, blocklist-filtered
// ABOUTME: Messages list (accepted union followed-but-unreplied), per #4976.

import 'dart:async';

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:content_policy/content_policy.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/dm/conversation_list/protected_minor_inbox_gate.dart';
import 'package:openvine/blocs/dm/unread_count/dm_unread_count_cubit.dart';
import 'package:openvine/config/official_accounts.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockFollowRepository extends Mock implements FollowRepository {}

class _MockContentBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

class _MockContentPolicyState extends Mock implements ContentPolicyState {}

// Full 64-character hex Nostr IDs for test data — never truncate.
const _me = 'a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2';
const _alice =
    'c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4';
const _bob = 'd4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5';
const _carol =
    'e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6a1b2c3d4e5f6';

/// Approves a fixed set of counterparties; used to prove the badge applies the
/// same protected-minor predicate as the list (no leaked hidden attempts).
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

DmConversation _convo(
  String id, {
  required String peer,
  required bool isRead,
  required bool currentUserHasSent,
  int timestamp = 1700000000,
}) {
  return DmConversation(
    id: id,
    participantPubkeys: [_me, peer],
    isGroup: false,
    createdAt: timestamp,
    lastMessageTimestamp: timestamp,
    isRead: isRead,
    currentUserHasSent: currentUserHasSent,
  );
}

DmConversation _groupConvo(
  String id, {
  required List<String> peers,
  required bool isRead,
  required bool currentUserHasSent,
  int timestamp = 1700000000,
}) {
  return DmConversation(
    id: id,
    participantPubkeys: [_me, ...peers],
    isGroup: true,
    createdAt: timestamp,
    lastMessageTimestamp: timestamp,
    isRead: isRead,
    currentUserHasSent: currentUserHasSent,
  );
}

/// Pad an index into a unique 64-char hex conversation id / pubkey.
String _hex(int i) => i.toRadixString(16).padLeft(64, '0');

void _settle(FakeAsync fake) {
  fake.flushMicrotasks();
  fake.elapse(Duration.zero);
}

/// Closes [cubit] from inside the fake zone.
///
/// Deliberately not `addTearDown(cubit.close)`: tear-downs run after
/// `fakeAsync` has returned, and awaiting `close()` there never completes —
/// the cubit's rxdart subscription belongs to the discarded zone — so the
/// suite hangs instead of failing. Called inline, the upstream cancel is
/// synchronous, which is what leaves the shared controllers listener-free for
/// the group `tearDown`.
void _close(FakeAsync fake, DmUnreadCountCubit cubit) {
  unawaited(cubit.close());
  fake.flushMicrotasks();
}

void _testWithFakeAsync(
  String description,
  void Function(FakeAsync fake) body,
) {
  test(description, () => fakeAsync(body));
}

void main() {
  setUpAll(() {
    registerFallbackValue(<DmConversation>[]);
  });

  group(DmUnreadCountCubit, () {
    late _MockDmRepository dmRepository;
    late _MockFollowRepository followRepository;
    late StreamController<List<DmConversation>> acceptedController;
    late StreamController<List<DmConversation>> potentialController;
    late StreamController<List<String>> followingController;
    late Set<String> followed;

    setUp(() {
      dmRepository = _MockDmRepository();
      followRepository = _MockFollowRepository();
      acceptedController = StreamController<List<DmConversation>>();
      potentialController = StreamController<List<DmConversation>>();
      followingController = StreamController<List<String>>();
      followed = <String>{};

      when(() => dmRepository.userPubkey).thenReturn(_me);
      // Identity stream (#5374): seeded via `.startWith(userPubkey)` in the
      // cubit, so an empty stream suffices for the steady-state value to flow.
      when(
        () => dmRepository.userPubkeyStream,
      ).thenAnswer((_) => const Stream<String>.empty());
      // No-arg stub: this matches only a call WITHOUT a limit, locking in that
      // the badge counts the full (unpaginated) accepted set, not a page.
      when(
        () => dmRepository.watchAcceptedConversations(),
      ).thenAnswer((_) => acceptedController.stream);
      when(
        () => dmRepository.watchPotentialRequests(),
      ).thenAnswer((_) => potentialController.stream);
      when(
        () => followRepository.followingStream,
      ).thenAnswer((_) => followingController.stream);
      when(
        () => followRepository.isFollowing(any()),
      ).thenAnswer((inv) => followed.contains(inv.positionalArguments.first));
    });

    tearDown(() async {
      await acceptedController.close();
      await potentialController.close();
      await followingController.close();
    });

    DmUnreadCountCubit buildCubit({
      ContentBlocklistRepository? contentBlocklistRepository,
    }) {
      return DmUnreadCountCubit(
        dmRepository: dmRepository,
        followRepository: followRepository,
        contentBlocklistRepository: contentBlocklistRepository,
        // Behaviour tests assert the final settled count, not coalescing
        // timing. The debounce itself is covered by the dedicated test below.
        recomputeDebounce: Duration.zero,
      );
    }

    _testWithFakeAsync('initial state is 0', (fake) {
      final cubit = buildCubit();
      expect(cubit.state, equals(0));
      _close(fake, cubit);
    });

    _testWithFakeAsync(
      'excludes unread conversations from non-approved counterparties (#176)',
      (fake) {
        // alice approved, bob not. The badge must not reveal bob's hidden attempt.
        final cubit = DmUnreadCountCubit(
          dmRepository: dmRepository,
          followRepository: followRepository,
          protectedMinorInboxGate: _FakeInboxGate(approved: {_alice}),
          recomputeDebounce: Duration.zero,
        );
        acceptedController.add([
          _convo('a', peer: _alice, isRead: false, currentUserHasSent: true),
          _convo('b', peer: _bob, isRead: false, currentUserHasSent: true),
        ]);
        potentialController.add(const []);
        _settle(fake);

        expect(cubit.state, equals(1));
        _close(fake, cubit);
      },
    );

    _testWithFakeAsync('stays at 0 when there are no conversations', (fake) {
      final cubit = buildCubit();

      acceptedController.add(const []);
      potentialController.add(const []);
      _settle(fake);

      expect(cubit.state, equals(0));
      _close(fake, cubit);
    });

    _testWithFakeAsync(
      'counts an unread conversation from a followed peer the user has '
      'never replied to (#4976 regression — old follow-blind count returned 0)',
      (fake) {
        followed.add(_alice);
        final cubit = buildCubit();

        acceptedController.add(const []);
        potentialController.add([
          _convo('c1', peer: _alice, isRead: false, currentUserHasSent: false),
        ]);
        _settle(fake);

        expect(cubit.state, equals(1));
        _close(fake, cubit);
      },
    );

    _testWithFakeAsync(
      'counts an unread group when every peer is followed and the user has '
      'never replied',
      (fake) {
        followed.addAll({_alice, _bob});
        final cubit = buildCubit();

        acceptedController.add(const []);
        potentialController.add([
          _groupConvo(
            'group-1',
            peers: [_alice, _bob],
            isRead: false,
            currentUserHasSent: false,
          ),
        ]);
        _settle(fake);

        expect(cubit.state, equals(1));
        _close(fake, cubit);
      },
    );

    _testWithFakeAsync(
      'holds the count while userPubkey is empty, then counts the followed '
      '1:1 once the identity arrives (#5374)',
      (fake) {
        followed.add(_alice);
        // Cold start: empty pubkey until the identity stream delivers it.
        when(() => dmRepository.userPubkey).thenReturn('');
        final pubkeyController = StreamController<String>();
        when(
          () => dmRepository.userPubkeyStream,
        ).thenAnswer((_) => pubkeyController.stream);

        final cubit = buildCubit();

        acceptedController.add(const []);
        potentialController.add([
          _convo('c1', peer: _alice, isRead: false, currentUserHasSent: false),
        ]);
        _settle(fake);
        // Empty pubkey: self cannot be filtered, so the guard holds the count
        // instead of misclassifying the 1:1 as a group and dropping it.
        expect(cubit.state, equals(0));

        // Identity arrival re-fires the recompute.
        pubkeyController.add(_me);
        _settle(fake);
        // Identity arrived → the followed-but-unreplied 1:1 is counted.
        expect(cubit.state, equals(1));
        _close(fake, cubit);
        unawaited(pubkeyController.close());
        fake.flushMicrotasks();
      },
    );

    _testWithFakeAsync('counts an unread accepted conversation', (fake) {
      final cubit = buildCubit();

      acceptedController.add([
        _convo('c2', peer: _bob, isRead: false, currentUserHasSent: true),
      ]);
      potentialController.add(const []);
      _settle(fake);

      expect(cubit.state, equals(1));
      _close(fake, cubit);
    });

    _testWithFakeAsync(
      'excludes an unread request from a non-followed peer the user has '
      'never replied to (it is not shown in the Messages list)',
      (fake) {
        // _carol is not in `followed`, never replied -> classifies as a request.
        final cubit = buildCubit();

        acceptedController.add(const []);
        potentialController.add([
          _convo('c3', peer: _carol, isRead: false, currentUserHasSent: false),
        ]);
        _settle(fake);

        expect(cubit.state, equals(0));
        _close(fake, cubit);
      },
    );

    _testWithFakeAsync('excludes read conversations', (fake) {
      final cubit = buildCubit();

      acceptedController.add([
        _convo('c4', peer: _bob, isRead: true, currentUserHasSent: true),
      ]);
      potentialController.add(const []);
      _settle(fake);

      expect(cubit.state, equals(0));
      _close(fake, cubit);
    });

    _testWithFakeAsync('counts the full unpaginated accepted set', (fake) {
      final cubit = buildCubit();

      // More than one inbox page of unread accepted conversations.
      final many = List.generate(
        60,
        (i) => _convo(
          _hex(i),
          peer: _hex(1000 + i),
          isRead: false,
          currentUserHasSent: true,
        ),
      );
      acceptedController.add(many);
      potentialController.add(const []);
      _settle(fake);

      expect(cubit.state, equals(60));
      // The badge must subscribe without a limit (full count, not a page).
      verify(() => dmRepository.watchAcceptedConversations()).called(1);
      _close(fake, cubit);
    });

    _testWithFakeAsync('recomputes when the following list changes', (fake) {
      final cubit = buildCubit();

      acceptedController.add(const []);
      potentialController.add([
        _convo('c5', peer: _alice, isRead: false, currentUserHasSent: false),
      ]);
      _settle(fake);
      // _alice not followed yet -> request -> not counted.
      expect(cubit.state, equals(0));

      followed.add(_alice);
      followingController.add([_alice]);
      _settle(fake);
      // Now followed -> appears in the Messages list -> counted.
      expect(cubit.state, equals(1));
      _close(fake, cubit);
    });

    group('blocklist-aware', () {
      late _MockContentBlocklistRepository blocklist;
      late StreamController<ContentPolicyState> stateController;

      setUp(() {
        blocklist = _MockContentBlocklistRepository();
        stateController = StreamController<ContentPolicyState>();
        when(
          () => blocklist.stateStream,
        ).thenAnswer((_) => stateController.stream);
      });

      tearDown(() async {
        await stateController.close();
      });

      _testWithFakeAsync('excludes a blocked unread accepted conversation', (
        fake,
      ) {
        // Blocklist drops _bob's conversation, mirroring the list.
        when(
          () => blocklist.filterBlockedConversations(
            any(),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenReturn(const <DmConversation>[]);

        final cubit = buildCubit(contentBlocklistRepository: blocklist);

        acceptedController.add([
          _convo('c6', peer: _bob, isRead: false, currentUserHasSent: true),
        ]);
        potentialController.add(const []);
        _settle(fake);

        expect(cubit.state, equals(0));
        _close(fake, cubit);
      });

      _testWithFakeAsync('counts conversations the blocklist passes through', (
        fake,
      ) {
        when(
          () => blocklist.filterBlockedConversations(
            any(),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer(
          (inv) => inv.positionalArguments.first as List<DmConversation>,
        );

        final cubit = buildCubit(contentBlocklistRepository: blocklist);

        acceptedController.add([
          _convo('c7', peer: _bob, isRead: false, currentUserHasSent: true),
        ]);
        potentialController.add(const []);
        _settle(fake);

        expect(cubit.state, equals(1));
        _close(fake, cubit);
      });

      _testWithFakeAsync('recomputes when the blocklist changes', (fake) {
        // Initially passes through -> counted.
        when(
          () => blocklist.filterBlockedConversations(
            any(),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer(
          (inv) => inv.positionalArguments.first as List<DmConversation>,
        );

        final cubit = buildCubit(contentBlocklistRepository: blocklist);

        acceptedController.add([
          _convo('c8', peer: _bob, isRead: false, currentUserHasSent: true),
        ]);
        potentialController.add(const []);
        _settle(fake);
        expect(cubit.state, equals(1));

        // Block _bob mid-session: the filter now drops it, and a blocklist
        // state tick must force the badge to recompute.
        when(
          () => blocklist.filterBlockedConversations(
            any(),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenReturn(const <DmConversation>[]);
        stateController.add(_MockContentPolicyState());
        _settle(fake);

        expect(cubit.state, equals(0));
        _close(fake, cubit);
      });
    });

    _testWithFakeAsync(
      'setRepositories re-points the count at fresh repositories and stops '
      'counting against the stale ones (app-shell auth-ready rebuild, #4976)',
      (fake) {
        final cubit = buildCubit();

        // Pre-auth repository emits one unread accepted conversation.
        acceptedController.add([
          _convo('c9', peer: _bob, isRead: false, currentUserHasSent: true),
        ]);
        potentialController.add(const []);
        _settle(fake);
        expect(cubit.state, equals(1));

        // Auth becomes ready: the providers rebuild into fresh instances.
        final dmRepository2 = _MockDmRepository();
        final followRepository2 = _MockFollowRepository();
        final acceptedController2 = StreamController<List<DmConversation>>();
        final potentialController2 = StreamController<List<DmConversation>>();
        final followingController2 = StreamController<List<String>>();
        when(() => dmRepository2.userPubkey).thenReturn(_me);
        when(
          () => dmRepository2.userPubkeyStream,
        ).thenAnswer((_) => const Stream<String>.empty());
        when(
          dmRepository2.watchAcceptedConversations,
        ).thenAnswer((_) => acceptedController2.stream);
        when(
          dmRepository2.watchPotentialRequests,
        ).thenAnswer((_) => potentialController2.stream);
        when(
          () => followRepository2.followingStream,
        ).thenAnswer((_) => followingController2.stream);
        when(() => followRepository2.isFollowing(any())).thenReturn(false);

        cubit.setRepositories(
          dmRepository: dmRepository2,
          followRepository: followRepository2,
        );

        // The fresh repository drives the count.
        acceptedController2.add([
          _convo('c10', peer: _bob, isRead: false, currentUserHasSent: true),
          _convo('c11', peer: _carol, isRead: false, currentUserHasSent: true),
        ]);
        potentialController2.add(const []);
        _settle(fake);
        expect(cubit.state, equals(2));

        // The stale repository must no longer affect the badge.
        acceptedController.add(const []);
        _settle(fake);
        expect(cubit.state, equals(2));

        _close(fake, cubit);
        unawaited(acceptedController2.close());
        unawaited(potentialController2.close());
        unawaited(followingController2.close());
        fake.flushMicrotasks();
      },
    );

    _testWithFakeAsync(
      'coalesces a burst of conversation writes into a single recompute '
      '(debounce)',
      (fake) {
        var filterCalls = 0;
        final blocklist = _MockContentBlocklistRepository();
        final stateController = StreamController<ContentPolicyState>();
        when(
          () => blocklist.stateStream,
        ).thenAnswer((_) => stateController.stream);
        // filterBlockedConversations runs once per `_countUnread` pass, so it
        // doubles as a recompute counter.
        when(
          () => blocklist.filterBlockedConversations(
            any(),
            userPubkey: any(named: 'userPubkey'),
          ),
        ).thenAnswer((inv) {
          filterCalls++;
          return inv.positionalArguments.first as List<DmConversation>;
        });

        // Real (non-zero) debounce window so the burst is genuinely coalesced.
        final cubit = DmUnreadCountCubit(
          dmRepository: dmRepository,
          followRepository: followRepository,
          contentBlocklistRepository: blocklist,
          recomputeDebounce: const Duration(milliseconds: 100),
        );

        potentialController.add(const []);
        // Five rapid accepted-list updates inside the debounce window.
        for (var i = 0; i < 5; i++) {
          acceptedController.add([
            _convo('c$i', peer: _bob, isRead: false, currentUserHasSent: true),
          ]);
        }

        fake.flushMicrotasks();

        // Still immediately before the boundary: the expensive pass has not run.
        fake.elapse(const Duration(milliseconds: 99));
        expect(filterCalls, equals(0));

        // At the boundary: exactly one recompute for the whole burst.
        fake.elapse(const Duration(milliseconds: 1));
        expect(filterCalls, equals(1));
        expect(cubit.state, equals(1));

        _close(fake, cubit);
        unawaited(stateController.close());
        fake.flushMicrotasks();
      },
    );

    _testWithFakeAsync('cancels subscription on close', (fake) {
      final cubit = buildCubit();
      _close(fake, cubit);

      // Assert the cancel directly. The writes below cannot fail this test on
      // their own: with the cancel removed they feed a still-open cubit and
      // throw in neither case.
      expect(acceptedController.hasListener, isFalse);
      expect(potentialController.hasListener, isFalse);

      // Emitting after close must not throw (subscription cancelled).
      acceptedController.add(const []);
      potentialController.add(const []);
      _settle(fake);
    });

    group('pinned support row parity (#6283)', () {
      const moderation = kModerationPubkeyHex;
      final legacyModeration = kLegacyModerationPubkeys.first;
      final supportId = DmRepository.computeConversationId([_me, moderation]);
      final legacySupportId = DmRepository.computeConversationId([
        _me,
        legacyModeration,
      ]);

      DmUnreadCountCubit buildPinAwareCubit({ProtectedMinorInboxGate? gate}) =>
          DmUnreadCountCubit(
            dmRepository: dmRepository,
            followRepository: followRepository,
            protectedMinorInboxGate: gate,
            recomputeDebounce: Duration.zero,
            supportRowPubkey: moderation,
          );

      _testWithFakeAsync(
        'counts an inbound-only unread moderation thread, which the inbox '
        'renders as the pin rather than as a request',
        (fake) {
          final cubit = buildPinAwareCubit();

          // Nobody is followed, so both classify as requests. The moderation
          // one becomes the pinned row (dot and all); the stranger stays in
          // Requests, which this count has never included.
          acceptedController.add(const []);
          potentialController.add([
            _convo(
              supportId,
              peer: moderation,
              isRead: false,
              currentUserHasSent: false,
            ),
            _convo(
              'stranger',
              peer: _bob,
              isRead: false,
              currentUserHasSent: false,
            ),
          ]);
          _settle(fake);

          expect(cubit.state, equals(1));
          _close(fake, cubit);
        },
      );

      _testWithFakeAsync(
        'counts a retired-key moderation thread, matching the list that keeps '
        'legacy history visible',
        (fake) {
          final cubit = buildPinAwareCubit();

          acceptedController.add([
            _convo(
              legacySupportId,
              peer: legacyModeration,
              isRead: false,
              currentUserHasSent: true,
            ),
          ]);
          potentialController.add(const []);
          _settle(fake);

          // The inbox keeps this legacy-history row visible until #6416 gives
          // it an archived read-only presentation, so the badge can point at a
          // row the user can still find.
          expect(cubit.state, equals(1));
          _close(fake, cubit);
        },
      );

      _testWithFakeAsync('counts an adopted moderation thread exactly once', (
        fake,
      ) {
        final cubit = buildPinAwareCubit();

        // The accepted and potential-request streams are independent, so a
        // currentUserHasSent flip can be observed in one before the other.
        final thread = _convo(
          supportId,
          peer: moderation,
          isRead: false,
          currentUserHasSent: true,
        );
        acceptedController.add([thread]);
        potentialController.add([thread]);
        _settle(fake);

        expect(cubit.state, equals(1));
        _close(fake, cubit);
      });

      _testWithFakeAsync(
        'excludes a pinned thread the protected-minor gate rejects (#176)',
        (fake) {
          final cubit = buildPinAwareCubit(
            gate: _FakeInboxGate(approved: const {}),
          );

          acceptedController.add(const []);
          potentialController.add([
            _convo(
              supportId,
              peer: moderation,
              isRead: false,
              currentUserHasSent: false,
            ),
          ]);
          _settle(fake);

          // The pin is filtered out of the list for this user, so the badge
          // must not leak its existence.
          expect(cubit.state, equals(0));
          _close(fake, cubit);
        },
      );

      _testWithFakeAsync(
        'counts exactly as before when no support pubkey is injected',
        (fake) {
          final cubit = buildCubit();

          acceptedController.add([
            _convo(
              supportId,
              peer: moderation,
              isRead: false,
              currentUserHasSent: true,
            ),
          ]);
          potentialController.add(const []);
          _settle(fake);

          // Degrades to the un-pinned behaviour rather than partitioning
          // against an empty key.
          expect(cubit.state, equals(1));
          _close(fake, cubit);
        },
      );
    });
  });
}
