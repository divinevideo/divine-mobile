// ABOUTME: Kind 3 publishes are serialized across every caller (#10784):
// ABOUTME: two edits never replace the contact list at the same time.

import 'dart:async';

import 'package:cache_sync/cache_sync.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../cache_sync/test/fake_cache_dao.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockEvent extends Mock implements Event {}

class _FakeContactList extends Fake implements ContactList {}

typedef _ReadResult = ({List<Event> events, bool timedOut, bool noRelays});

const _owner =
    'a1b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012';
const _otherAccount =
    'f6789012345678901234567890abcdef1234567890123456789012a1b2c3d4e5';
const _alice =
    'b2c3d4e5f6789012345678901234567890abcdef1234567890123456789012a1';
const _bob = 'c3d4e5f6789012345678901234567890abcdef1234567890123456789012ab12';
const _carol =
    'd4e5f6789012345678901234567890abcdef1234567890123456789012ab12c3';

/// A relay whose kind 3 publishes stay in flight until [release]d.
class _GatedRelay {
  _GatedRelay(this.client);

  final _MockNostrClient client;

  /// The p tags of every publish the client started, in order.
  final started = <List<String>>[];

  /// The p tags of every publish that succeeded, in order.
  final accepted = <List<String>>[];

  /// Indexes into [started] whose publish the relay refuses.
  final refused = <int>{};

  final _gates = <Completer<void>>[];
  var _inFlight = 0;
  int maxInFlight = 0;

  void install() {
    when(
      () => client.sendContactList(
        any(),
        any(),
        tempRelays: any(named: 'tempRelays'),
        targetRelays: any(named: 'targetRelays'),
      ),
    ).thenAnswer((invocation) async {
      final contacts = invocation.positionalArguments[0] as ContactList;
      final follows = contacts
          .toJson()
          .where((tag) => tag.isNotEmpty && tag[0] == 'p')
          .map((tag) => tag[1])
          .toList();
      final index = started.length;
      started.add(follows);
      _inFlight++;
      if (_inFlight > maxInFlight) maxInFlight = _inFlight;
      final gate = Completer<void>();
      _gates.add(gate);
      await gate.future;
      _inFlight--;
      if (refused.contains(index)) return null;
      accepted.add(follows);
      return Event(_owner, EventKind.contactList, [
        for (final pubkey in follows) ['p', pubkey],
      ], '');
    });
  }

  /// Lets every publish complete, including ones that start meanwhile.
  Future<void> release() async {
    for (var round = 0; round < 50; round++) {
      await pumpEventQueue();
      final open = _gates.where((gate) => !gate.isCompleted).toList();
      if (open.isEmpty) return;
      for (final gate in open) {
        gate.complete();
      }
    }
    fail('publishes kept starting after 50 rounds');
  }

  /// Lets only the oldest publish still in flight complete.
  Future<void> releaseOldest() async {
    _gates.firstWhere((gate) => !gate.isCompleted).complete();
    await pumpEventQueue();
  }

  /// Waits until [count] publishes have started.
  Future<void> untilStarted(int count) async {
    for (var i = 0; i < 20 && started.length < count; i++) {
      await pumpEventQueue();
    }
    expect(started, hasLength(count), reason: 'publishes started');
  }
}

void main() {
  group('FollowRepository contact list broadcast queue (#10784)', () {
    late _MockNostrClient client;
    late _GatedRelay relay;
    late FollowRepository repository;
    late List<_ReadResult> reads;

    setUpAll(() {
      registerFallbackValue(_MockEvent());
      registerFallbackValue(<Filter>[]);
      registerFallbackValue(_FakeContactList());
      registerFallbackValue(Duration.zero);
    });

    setUp(() async {
      SharedPreferences.setMockInitialValues({});
      await CacheSync.init(dao: FakeCacheDao());
      client = _MockNostrClient();
      relay = _GatedRelay(client)..install();
      reads = [];

      when(() => client.hasKeys).thenReturn(true);
      when(() => client.publicKey).thenReturn(_owner);
      when(
        () => client.subscribe(
          any(),
          subscriptionId: any(named: 'subscriptionId'),
          tempRelays: any(named: 'tempRelays'),
          targetRelays: any(named: 'targetRelays'),
          relayTypes: any(named: 'relayTypes'),
          sendAfterAuth: any(named: 'sendAfterAuth'),
          onEose: any(named: 'onEose'),
        ),
      ).thenAnswer((_) => const Stream<Event>.empty());
      when(() => client.unsubscribe(any())).thenAnswer((_) async {});
      // Each pre-publish read takes the next scripted answer; once the script
      // runs out, the relay settles with no kind 3.
      when(
        () => client.queryEventsDetailed(
          any(),
          requireAllRelaysSettled: any(named: 'requireAllRelaysSettled'),
          timeout: any(named: 'timeout'),
        ),
      ).thenAnswer(
        (_) async => reads.isEmpty
            ? (events: <Event>[], timedOut: false, noRelays: false)
            : reads.removeAt(0),
      );

      repository = FollowRepository(
        nostrClient: client,
        isCacheInitialized: () => true,
        getCachedEventsByKind: (_) => [],
        cacheUserEvent: (_) {},
        indexerRelayUrls: const [],
      );
      await repository.initialize();
    });

    tearDown(() => repository.dispose());

    test('a second follow waits for the first publish to finish', () async {
      final first = repository.followWithResult(_alice);
      await relay.untilStarted(1);
      final second = repository.followWithResult(_bob);
      await pumpEventQueue();

      expect(relay.started, hasLength(1), reason: 'second publish waited');

      await relay.release();
      await Future.wait([first, second]);

      expect(relay.maxInFlight, equals(1));
      expect(relay.accepted, [
        [_alice],
        [_alice, _bob],
      ]);
    });

    test(
      'a third follow waits for the second publish, not only the first',
      () async {
        final first = repository.followWithResult(_alice);
        await relay.untilStarted(1);
        final second = repository.followWithResult(_bob);
        await pumpEventQueue();
        await relay.releaseOldest();
        await relay.untilStarted(2);
        final third = repository.followWithResult(_carol);
        await pumpEventQueue();

        expect(relay.started, hasLength(2), reason: 'third publish waited');

        await relay.release();
        await Future.wait([first, second, third]);

        expect(relay.maxInFlight, equals(1));
        expect(relay.accepted, [
          [_alice],
          [_alice, _bob],
          [_alice, _bob, _carol],
        ]);
      },
    );

    test(
      'a follow undone before its publish reports nothing changed',
      () async {
        final followed = repository.followWithResult(_alice);
        final unfollowed = repository.unfollow(_alice);
        await relay.release();

        expect(await followed, FollowOutcome.unchanged);
        await unfollowed;
        expect(relay.accepted, [<String>[]]);
        expect(repository.followingPubkeys, isEmpty);
      },
    );

    test('a follow the publish ahead of it already carried is not published '
        'again', () async {
      final first = repository.followWithResult(_alice);
      final second = repository.followWithResult(_bob);
      await relay.release();

      expect(await first, FollowOutcome.published);
      expect(await second, FollowOutcome.published);
      expect(relay.accepted, [
        [_alice, _bob],
      ]);
      expect(relay.started, hasLength(1));
    });

    test('a follow made while the publish ahead of it is sending survives '
        'a newer list from another device', () async {
      final unfollowed = <String>[];
      final subscription = repository.confirmedUnfollowStream.listen(
        unfollowed.add,
      );
      addTearDown(subscription.cancel);
      final first = repository.followWithResult(_alice);
      await relay.untilStarted(1);
      final second = repository.followWithResult(_bob);
      await pumpEventQueue();
      final otherDevice = Event(
        _owner,
        EventKind.contactList,
        [
          ['p', _alice],
          ['p', _carol],
        ],
        '',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000 + 60,
      );
      reads.add((events: [otherDevice], timedOut: false, noRelays: false));
      await relay.release();

      expect(await first, FollowOutcome.published);
      expect(await second, FollowOutcome.published);
      expect(relay.accepted.last, [_alice, _carol, _bob]);
      expect(unfollowed, isNot(contains(_bob)));
    });

    test('a refused publish does not reach the relay through the follow '
        'queued behind it', () async {
      relay.refused.add(0);
      final first = repository
          .followWithResult(_alice)
          .then<Object>((outcome) => outcome, onError: (Object e) => e);
      final second = repository.followWithResult(_bob);
      await relay.release();

      expect(await first, isA<Exception>());
      expect(await second, FollowOutcome.published);
      expect(relay.accepted, [
        [_bob],
      ]);
      expect(repository.followingPubkeys, [_bob]);
    });

    test('a follow queued behind a withheld publish still publishes', () async {
      reads.add((events: <Event>[], timedOut: true, noRelays: false));
      final first = repository.followWithResult(_alice);
      final second = repository.followWithResult(_bob);
      await relay.release();

      expect(await first, FollowOutcome.queued);
      expect(await second, FollowOutcome.published);
      expect(relay.accepted, [
        [_alice, _bob],
      ]);
    });

    test('fails a queued follow when the signed-in account changes while it '
        'waits, and keeps its follow out of the new account', () async {
      final first = repository.followWithResult(_alice);
      await relay.untilStarted(1);
      final second = repository
          .followWithResult(_bob)
          .then<Object>((outcome) => outcome, onError: (Object e) => e);
      await pumpEventQueue();
      when(() => client.publicKey).thenReturn(_otherAccount);
      await relay.release();

      await first;
      // Terminal, so PendingActionService does not retry it under the new key.
      expect(await second, isA<TerminalSocialActionException>());
      expect(relay.started, hasLength(1));
      // The follow already publishing saves under whichever key the client
      // reports when it lands; only the queued one is this test's concern.
      final prefs = await SharedPreferences.getInstance();
      expect(
        prefs.getString('following_list_$_otherAccount') ?? '',
        isNot(contains(_bob)),
      );
    });

    test('drops a queued publish when the repository is disposed while it '
        'waits, before dispose has finished', () async {
      // Dispose closes the following stream only after it unsubscribes, so
      // a queued publish can resume while dispose is still under way.
      final unsubscribed = Completer<void>();
      addTearDown(() {
        if (!unsubscribed.isCompleted) unsubscribed.complete();
      });
      when(
        () => client.unsubscribe(any()),
      ).thenAnswer((_) => unsubscribed.future);
      final first = repository.followWithResult(_alice);
      await relay.untilStarted(1);
      final second = repository.followWithResult(_bob);
      await pumpEventQueue();
      final disposed = repository.dispose();
      await relay.release();

      await first;
      expect(await second, FollowOutcome.queued);
      expect(relay.started, hasLength(1));
      unsubscribed.complete();
      await disposed;
    });
  });
}
