// ABOUTME: Regression tests for #11182: a read of someone's reposts that no
// ABOUTME: relay answered is not an empty list. Drives RepostsRepository
// ABOUTME: through a real NostrClient and relay pool over a scripted relay
// ABOUTME: that answers, refuses with CLOSED, or stays silent.

import 'dart:async';

import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:nostr_sdk/relay/client_connected.dart';
import 'package:reposts_repository/reposts_repository.dart';
import 'package:test/test.dart';

class _MockRelayManager extends Mock implements RelayManager {}

/// How a [_ScriptedRelay] answers a read of reposts.
enum _Reply {
  /// Every matching event, then EOSE.
  answer,

  /// A CLOSED before any event.
  closed,

  /// Nothing at all, so the read runs to its deadline.
  silent,
}

/// A relay whose answer to a read is chosen by the test.
class _ScriptedRelay extends Relay {
  _ScriptedRelay(String url) : super(url, RelayStatus(url));

  final List<Event> store = [];
  _Reply reply = _Reply.answer;

  @override
  Future<bool> doConnect() async {
    relayStatus.connected = ClientConnected.connected;
    return true;
  }

  @override
  Future<void> disconnect() async {
    relayStatus.connected = ClientConnected.disconnect;
  }

  @override
  Future<bool> send(
    List<dynamic> message, {
    bool queueIfFailed = true,
    bool skipReconnect = false,
    DateTime? deadline,
  }) async {
    if (message.length > 2 && message.first == 'REQ') {
      final subId = message[1] as String;
      final filters = [
        for (final f in message.skip(2))
          Filter.fromJson(Map<String, dynamic>.from(f as Map)),
      ];
      unawaited(_answer(subId, filters));
    }
    return true;
  }

  Future<void> _answer(String subId, List<Filter> filters) async {
    // The pool records a query only after send() returns, so let it.
    await pumpEventQueue();
    switch (reply) {
      case _Reply.silent:
        return;
      case _Reply.closed:
        await _deliver(['CLOSED', subId, 'error: shutting down']);
      case _Reply.answer:
        for (final filter in filters) {
          for (final event in store.where(filter.checkEvent)) {
            await _deliver(['EVENT', subId, event.toJson()]);
          }
        }
        await _deliver(['EOSE', subId]);
    }
  }

  Future<void> _deliver(List<dynamic> json) async {
    final handler = onMessage;
    if (handler == null) return;
    final dynamic result = handler(this, json);
    if (result is Future) await result;
  }
}

class _MemoryRepostsStorage implements RepostsLocalStorage {
  final Map<String, RepostRecord> records = {};

  @override
  Future<void> saveRepostRecord(RepostRecord record) async {
    records[record.addressableId] = record;
  }

  @override
  Future<void> saveRepostRecordsBatch(List<RepostRecord> batch) async {
    for (final record in batch) {
      records[record.addressableId] = record;
    }
  }

  @override
  Future<bool> deleteRepostRecord(String addressableId) async =>
      records.remove(addressableId) != null;

  @override
  Future<RepostRecord?> getRepostRecord(String addressableId) async =>
      records[addressableId];

  @override
  Future<String?> getRepostEventId(String addressableId) async =>
      records[addressableId]?.repostEventId;

  @override
  Future<List<RepostRecord>> getAllRepostRecords() async =>
      records.values.toList();

  @override
  Future<Set<String>> getRepostedAddressableIds() async => records.keys.toSet();

  @override
  Future<bool> isReposted(String addressableId) async =>
      records.containsKey(addressableId);

  @override
  Stream<Set<String>> watchRepostedAddressableIds() =>
      Stream.value(records.keys.toSet());

  @override
  Future<void> clearAll() async => records.clear();
}

// Synthetic keys and ids only.
const _userSecret =
    '5ee1c8000ab28edd64d74a7d951ac2dd559814887b1b9e1ac7c5f89e96125c12';
const _author =
    '4f2c1b7e9a3d5c8f0e6b2a1d7c9e3f5a8b0d2c4e6f8a1b3c5d7e9f0a2b4c6d8e';
const _coord = '34236:$_author:short-read-11182';
const _relayUrl = 'wss://scripted.example';
const _otherRelayUrl = 'wss://other.example';

int get _now => DateTime.now().millisecondsSinceEpoch ~/ 1000;

class _Harness {
  _Harness({
    required this.repo,
    required this.relay,
    required this.other,
    required this.storage,
    required this.signer,
    required this.user,
  });

  final RepostsRepository repo;
  final _ScriptedRelay relay;
  final _ScriptedRelay? other;
  final _MemoryRepostsStorage storage;
  final LocalNostrSigner signer;
  final String user;

  /// A kind 16 by this account reposting the video at [_coord].
  Future<Event> repost() async => (await signer.signEvent(
    Event(
      user,
      EventKind.genericRepost,
      [
        ['k', '34236'],
        ['a', _coord],
        ['p', _author],
      ],
      '',
      createdAt: _now - 60,
    ),
  ))!;
}

Future<_Harness> _harness({bool withOtherRelay = false}) async {
  final signer = LocalNostrSigner(_userSecret);
  final nostr = Nostr(signer, [], _ScriptedRelay.new);
  final user = await nostr.ensurePublicKey();
  final relay = _ScriptedRelay(_relayUrl);
  final other = withOtherRelay ? _ScriptedRelay(_otherRelayUrl) : null;
  for (final scripted in [relay, ?other]) {
    expect(await nostr.relayPool.add(scripted), isTrue);
  }
  final urls = [_relayUrl, if (other != null) _otherRelayUrl];

  final relayManager = _MockRelayManager();
  when(() => relayManager.connectedRelays).thenReturn(urls);
  when(() => relayManager.configuredRelays).thenReturn(urls);
  when(() => relayManager.isRelayAllowed(any())).thenReturn(true);
  when(() => relayManager.diagnosticsSink).thenReturn(null);
  when(relayManager.dispose).thenAnswer((_) async {});
  when(relayManager.retryDisconnectedRelays).thenAnswer((_) async {});

  final client = NostrClient.forTesting(
    nostr: nostr,
    relayManager: relayManager,
  );
  final storage = _MemoryRepostsStorage();
  final repo = RepostsRepository(nostrClient: client, localStorage: storage);
  addTearDown(() async {
    repo.dispose();
    await client.dispose();
  });
  return _Harness(
    repo: repo,
    relay: relay,
    other: other,
    storage: storage,
    signer: signer,
    user: user,
  );
}

void main() {
  setUpAll(() => registerFallbackValue(''));

  group('RepostsRepository when no relay answers a read (#11182)', () {
    group('syncUserReposts', () {
      test('returns the repost a relay answered with', () async {
        final h = await _harness();
        h.relay.store.add(await h.repost());

        final result = await h.repo.syncUserReposts();

        expect(result.orderedAddressableIds, equals([_coord]));
      });

      test('returns an empty result when the relay answered with '
          'nothing', () async {
        final h = await _harness();

        final result = await h.repo.syncUserReposts();

        expect(result.orderedAddressableIds, isEmpty);
      });

      test('throws $SyncFailedException when the relay stays silent and '
          'nothing is kept locally', () async {
        final h = await _harness();
        h.relay
          ..store.add(await h.repost())
          ..reply = _Reply.silent;

        await expectLater(
          h.repo.syncUserReposts(),
          throwsA(isA<SyncFailedException>()),
        );
      });

      test('throws $SyncFailedException when the relay refuses the read and '
          'nothing is kept locally', () async {
        final h = await _harness();
        h.relay
          ..store.add(await h.repost())
          ..reply = _Reply.closed;

        await expectLater(
          h.repo.syncUserReposts(),
          throwsA(isA<SyncFailedException>()),
        );
      });

      test('returns what is kept locally when the relay stays '
          'silent', () async {
        final h = await _harness();
        final kept = await h.repost();
        h.storage.records[_coord] = RepostRecord(
          addressableId: _coord,
          repostEventId: kept.id,
          originalAuthorPubkey: _author,
          createdAt: DateTime.fromMillisecondsSinceEpoch(kept.createdAt * 1000),
        );
        h.relay.reply = _Reply.silent;

        final result = await h.repo.syncUserReposts();

        expect(result.orderedAddressableIds, equals([_coord]));
      });

      test('returns what one relay answered while another stays '
          'silent', () async {
        final h = await _harness(withOtherRelay: true);
        h.relay.store.add(await h.repost());
        h.other!.reply = _Reply.silent;

        final result = await h.repo.syncUserReposts();

        expect(result.orderedAddressableIds, equals([_coord]));
      });
    });

    group('fetchUserReposts', () {
      test('returns the repost a relay answered with', () async {
        final h = await _harness();
        h.relay.store.add(await h.repost());

        expect(await h.repo.fetchUserReposts(h.user), equals([_coord]));
      });

      test('returns an empty list when the relay answered with '
          'nothing', () async {
        final h = await _harness();

        expect(await h.repo.fetchUserReposts(h.user), isEmpty);
      });

      test('throws $FetchRepostsFailedException when the relay stays '
          'silent', () async {
        final h = await _harness();
        h.relay
          ..store.add(await h.repost())
          ..reply = _Reply.silent;

        await expectLater(
          h.repo.fetchUserReposts(h.user),
          throwsA(isA<FetchRepostsFailedException>()),
        );
      });

      test('throws $FetchRepostsFailedException when the relay refuses the '
          'read', () async {
        final h = await _harness();
        h.relay
          ..store.add(await h.repost())
          ..reply = _Reply.closed;

        await expectLater(
          h.repo.fetchUserReposts(h.user),
          throwsA(isA<FetchRepostsFailedException>()),
        );
      });
    });

    group('fetchUserRepostRecords', () {
      test('returns the repost a relay answered with', () async {
        final h = await _harness();
        final repost = await h.repost();
        h.relay.store.add(repost);

        final records = await h.repo.fetchUserRepostRecords(h.user);

        expect(records.map((r) => r.repostEventId), equals([repost.id]));
      });

      test('throws $FetchRepostsFailedException when the relay stays '
          'silent', () async {
        final h = await _harness();
        h.relay
          ..store.add(await h.repost())
          ..reply = _Reply.silent;

        await expectLater(
          h.repo.fetchUserRepostRecords(h.user),
          throwsA(isA<FetchRepostsFailedException>()),
        );
      });
    });
  });
}
