import 'dart:async';
import 'dart:convert';

import 'package:bip340/bip340.dart' as schnorr;
import 'package:concord_protocol/concord_protocol.dart';
import 'package:concord_repository/concord_repository.dart';
import 'package:test/test.dart';

import 'fixture_reader.dart';

class _Relay
    implements RelayGateway, RelayHistoryStatus, RelayScopedHistoryStatus {
  _Relay(this.events);
  final List<Map<String, dynamic>> events;
  final pending = <Future<void>>[];
  int publications = 0;
  final filters = <Map<String, dynamic>>[];
  final controllers = <StreamController<Map<String, dynamic>>>[];
  @override
  bool historyLimited = false;
  bool controlLimited = false;
  @override
  bool historyLimitedForAuthor(String pubkey) => controlLimited;
  @override
  Future<void> get historyReady => Future.wait(pending);
  @override
  Future<void> publish(Map<String, dynamic> event) async {
    publications++;
    throw StateError('Read-only bootstrap');
  }

  void receive(Map<String, dynamic> event) {
    for (var i = 0; i < filters.length; i++) {
      if ((filters[i]['authors'] as List).contains(event['pubkey']) &&
          (filters[i]['kinds'] as List).contains(event['kind'])) {
        controllers[i].add(event);
      }
    }
  }

  @override
  Stream<Map<String, dynamic>> subscribe(Map<String, dynamic> filter) {
    final controller = StreamController<Map<String, dynamic>>();
    controllers.add(controller);
    filters.add(filter);
    final done = Completer<void>();
    pending.add(done.future);
    scheduleMicrotask(() async {
      for (final event in events) {
        if ((filter['kinds'] as List).contains(event['kind']) &&
            (filter['authors'] as List).contains(event['pubkey'])) {
          controller.add(event);
        }
      }
      await Future<void>.delayed(Duration.zero);
      done.complete();
    });
    return controller.stream;
  }

  Future<void> close() async {
    for (final c in controllers) {
      await c.close();
    }
  }
}

class _OutboxCipher implements StreamCipher {
  @override
  String open(String p, String k) => throw UnimplementedError();
  @override
  String seal(String p, String k) => throw UnimplementedError();
}

class _DelayedStore extends InMemoryConcordStore {
  _DelayedStore(super.pubkey);
  final writing = Completer<void>();
  final release = Completer<void>();
  @override
  Future<void> writeBatch(
    Map<String, String> values, {
    List<String> remove = const [],
  }) async {
    if (!writing.isCompleted) writing.complete();
    await release.future;
    await super.writeBatch(values, remove: remove);
  }
}

class _ReplayCommunity {
  static final String owner = schnorr.getPublicKey('31' * 32);
  static final String id = deriveCommunityId(owner, '32' * 32);
  static final String channel = '53' * 32;
  static final GroupKey read = controlReadKey('42' * 32, id, 0);
  static String channelContent(int version) =>
      jsonEncode({'name': 'room-$version', 'private': false});
  static String hash(int version) => editionHash(
    channel,
    version,
    version == 1 ? null : hash(version - 1),
    channelContent(version),
  );
  static Future<Map<String, dynamic>> edition(
    String eid,
    String vsk,
    String content, {
    int version = 1,
    String? previous,
  }) async {
    final tags = <List<String>>[
      ['vsk', vsk],
      ['eid', eid],
      ['ev', '$version'],
      if (previous != null) ['ep', previous],
    ];
    final rumor = <String, dynamic>{
      'pubkey': owner,
      'kind': 3308,
      'created_at': version,
      'tags': tags,
      'content': content,
    };
    rumor['id'] = computeEventId(
      pubkey: owner,
      createdAt: version,
      kind: 3308,
      tags: tags,
      content: content,
    );
    return wrapSeal(
      seal: await sealRumor(
        rumor: rumor,
        sealKind: 20014,
        streamSeedHex: read.seedHex,
        streamPubkey: read.pubkey,
        authorSecretHex: '31' * 32,
      ),
      streamSeedHex: read.seedHex,
      streamPubkey: read.pubkey,
    );
  }

  static Future<Map<String, dynamic>> channelWrap(int version) => edition(
    channel,
    '2',
    channelContent(version),
    version: version,
    previous: version == 1 ? null : hash(version - 1),
  );
  static Future<List<Map<String, dynamic>>> bootstrap(
    ConcordInviteFragment fragment,
  ) async {
    final bundle = {
      'community_id': id,
      'owner': owner,
      'owner_salt': '32' * 32,
      'community_root': '42' * 32,
      'root_epoch': 0,
      'channels': <dynamic>[],
      'relays': <String>[],
      'name': 'Replay community',
    };
    final content = await nip44Encrypt(
      jsonEncode(bundle),
      inviteBundleKey(fragment.token),
    );
    final pubkey = schnorr.getPublicKey('64' * 32);
    final tags = <List<String>>[
      ['d', ''],
      ['vsk', '6'],
    ];
    final eventId = computeEventId(
      pubkey: pubkey,
      createdAt: 1,
      kind: 33301,
      tags: tags,
      content: content,
    );
    final event = <String, dynamic>{
      'pubkey': pubkey,
      'kind': 33301,
      'created_at': 1,
      'tags': tags,
      'content': content,
      'id': eventId,
      'sig': schnorr.sign('64' * 32, eventId, '00' * 32),
    };
    return [
      event,
      await edition(id, '0', jsonEncode({'name': 'Replay community'})),
      await channelWrap(1),
    ];
  }
}

void main() {
  final fixture = readConcordFixture('community-interop.json');
  final event = fixture['bundleEvent'] as Map<String, dynamic>;
  final expected = fixture['expected'] as Map;
  final fragment = ConcordInviteFragment.decode(
    Uri.parse(fixture['inviteUrl'] as String).fragment,
  );
  List<Map<String, dynamic>> events({bool incomplete = false}) => [
    event,
    ...(fixture['controlEvents'] as List).cast<Map<String, dynamic>>(),
    if (incomplete)
      ...(fixture['rejectedControlEvents'] as List)
          .cast<Map<String, dynamic>>(),
  ];
  ConcordCommunitySession session(
    _Relay relay,
    String account,
    AccountScopedStore store,
  ) => ConcordCommunitySession(
    relay: relay,
    store: store,
    linkSigner: event['pubkey'] as String,
    fragment: fragment,
    account: account,
    nowMs: () => 0,
  );
  group('ConcordCommunitySession.start', () {
    test(
      'real session exposes only verified public control rooms '
      'and stream epochs',
      () async {
        final relay = _Relay(events());
        final s = session(
          relay,
          expected['member'] as String,
          InMemoryConcordStore('11' * 32),
        );
        await s.start();
        expect(s.ready, isTrue);
        expect(s.control!.publicChannels.map((c) => c.name).toSet(), {
          'general',
          'introductions',
        });
        for (final raw in expected['channels'] as List) {
          final c = raw as Map<String, dynamic>;
          final stream = publicChannelKey(
            s.bundle!.communityRoot,
            c['id'] as String,
            s.bundle!.rootEpoch,
          );
          expect(
            stream.pubkey,
            ((c['streams'] as List).first as Map)['pubkey'],
          );
        }
        await s.close();
        await relay.close();
      },
    );
    test(
      'incomplete authority and banned membership fail visibly closed',
      () async {
        for (final bad in [false, true]) {
          final relay = _Relay(events(incomplete: bad));
          final s = session(
            relay,
            expected[bad ? 'member' : 'bannedMember'] as String,
            InMemoryConcordStore('22' * 32),
          );
          await expectLater(s.start(), throwsStateError);
          expect(s.ready, isFalse);
          expect(s.failure, isNotNull);
          await s.close();
          await relay.close();
        }
      },
    );
    test(
      'unrelated history limits do not hide complete control authority',
      () async {
        final relay = _Relay(events())..historyLimited = true;
        final s = session(
          relay,
          expected['member'] as String,
          InMemoryConcordStore('34' * 32),
        );
        await s.start();
        expect(s.ready, isTrue);
        expect(relay.filters.first.containsKey('limit'), isFalse);
        relay.controlLimited = true;
        expect(s.canPublish, isFalse);
        await s.close();
        await relay.close();
      },
    );
    test(
      'terminal signals use current bootstrap authority, not cached grants',
      () async {
        final bootstrap = await _ReplayCommunity.bootstrap(fragment);
        final moderator = schnorr.getPublicKey('65' * 32);
        final role = '66' * 32;
        final grant = grantLocator(_ReplayCommunity.id, moderator);
        final grantContent = jsonEncode({
          'member': moderator,
          'role_ids': [role],
        });
        final grantHash = editionHash(grant, 1, null, grantContent);
        final granted = [
          ...bootstrap,
          await _ReplayCommunity.edition(
            role,
            '1',
            jsonEncode({
              'role_id': role,
              'position': 1,
              'permissions': '16',
            }),
          ),
          await _ReplayCommunity.edition(grant, '3', grantContent),
        ];
        final store = InMemoryConcordStore('67' * 32);
        ConcordCommunitySession make(_Relay relay) => ConcordCommunitySession(
          relay: relay,
          store: store,
          linkSigner: bootstrap.first['pubkey'] as String,
          fragment: fragment,
          account: 'aa' * 32,
          nowMs: () => 0,
        );
        final originalRelay = _Relay(granted);
        final original = make(originalRelay);
        await original.start();
        expect(original.control!.permits(moderator, 16), isTrue);
        await original.close();
        await originalRelay.close();
        final group = groupKey(
          'concord/base-rekey-pseudonym',
          '42' * 32,
          _ReplayCommunity.id,
          epoch: 1,
        );
        final tags = <List<String>>[
          ['scope', '00' * 32],
          ['prevepoch', '0'],
          ['newepoch', '1'],
          ['prevcommit', epochKeyCommitment(0, '42' * 32)],
          ['vac', grant, '1', grantHash],
        ];
        final rumor = <String, dynamic>{
          'kind': 3303,
          'pubkey': moderator,
          'created_at': 1,
          'tags': tags,
          'content': '[]',
          'id': computeEventId(
            pubkey: moderator,
            createdAt: 1,
            kind: 3303,
            tags: tags,
            content: '[]',
          ),
        };
        final signal = await wrapSeal(
          seal: await sealRumor(
            rumor: rumor,
            sealKind: 20013,
            streamSeedHex: group.seedHex,
            streamPubkey: group.pubkey,
            authorSecretHex: '65' * 32,
          ),
          streamSeedHex: group.seedHex,
          streamPubkey: group.pubkey,
        );
        final currentRelay = _Relay([
          signal,
          ...granted,
          await _ReplayCommunity.edition(
            grant,
            '3',
            jsonEncode({'member': moderator, 'role_ids': <String>[]}),
            version: 2,
            previous: grantHash,
          ),
        ]);
        final current = make(currentRelay);
        await current.start();
        expect(current.control!.permits(moderator, 16), isFalse);
        expect(current.canPublish, isTrue);
        expect(await store.get('community-stop'), isNull);
        await current.close();
        await currentRelay.close();
      },
    );
    test(
      'newest signed revocation marker wins over an older live invite',
      () async {
        final revoked = fixture['revokedBundleEvent'] as Map<String, dynamic>;
        final relay = _Relay([
          fixture['revokedLiveBundleEvent'] as Map<String, dynamic>,
          revoked,
          ...(fixture['controlEvents'] as List).cast<Map<String, dynamic>>(),
        ]);
        final s = ConcordCommunitySession(
          relay: relay,
          store: InMemoryConcordStore('68' * 32),
          linkSigner: revoked['pubkey'] as String,
          fragment: ConcordInviteFragment.decode(
            Uri.parse(fixture['revokedInviteUrl'] as String).fragment,
          ),
          account: expected['member'] as String,
          nowMs: () => 0,
        );
        await expectLater(s.start(), throwsFormatException);
        expect(s.bundle, isNull);
        expect(s.canPublish, isFalse);
        await s.close();
        await relay.close();
      },
    );
    test('a missing invite cannot open deterministic POC rooms', () async {
      final relay = _Relay([]);
      final s = session(
        relay,
        expected['member'] as String,
        InMemoryConcordStore('33' * 32),
      );
      await expectLater(s.start(), throwsStateError);
      expect(s.bundle, isNull);
      expect(s.ready, isFalse);
      await s.close();
      await relay.close();
    });
    test(
      'owner lifecycle signals stop publication; impostors do not',
      () async {
        final lifecycle = readConcordFixture('community-lifecycle.json');
        final bundleEvent = lifecycle['bundleEvent'] as Map<String, dynamic>;
        for (final name in [
          'baseRekeyEvents',
          'dissolvedEvents',
          'impostorDissolvedEvents',
          'impostorRekeyEvents',
          'halfPublishedRekeyEvents',
          'forgedAuthorDissolvedEvents',
          'replayedDissolvedEvents',
          'zeroEidDissolvedEvents',
        ]) {
          final relay = _Relay([
            bundleEvent,
            ...(lifecycle['controlEvents'] as List)
                .cast<Map<String, dynamic>>(),
            ...(lifecycle[name] as List).cast<Map<String, dynamic>>(),
          ]);
          final s = ConcordCommunitySession(
            relay: relay,
            store: InMemoryConcordStore('88' * 32),
            linkSigner: bundleEvent['pubkey'] as String,
            fragment: ConcordInviteFragment.decode(
              Uri.parse(lifecycle['inviteUrl'] as String).fragment,
            ),
            account: (lifecycle['expected'] as Map)['member'] as String,
            nowMs: () => 0,
          );
          if (name != 'baseRekeyEvents' && name != 'dissolvedEvents') {
            await s.start();
            expect(s.canPublish, isTrue);
          } else {
            await expectLater(s.start(), throwsStateError);
            expect(s.canPublish, isFalse);
          }
          await s.close();
          await relay.close();
        }
      },
    );
    test(
      'a lifecycle signal citing an out-of-range version cannot close Rooms',
      () async {
        // The dissolved address derives from the public community id, so any
        // key can sign a carrier there.
        final bundle = await openInviteBundle(
          event: event,
          expectedSigner: event['pubkey'] as String,
          token: fragment.token,
          nowMs: 0,
        );
        final address = groupKey(
          'concord/dissolved',
          bundle.communityId,
          '00' * 32,
        );
        const stranger =
            '0000000000000000000000000000000000000000000000000000000000000003';
        final author = schnorr.getPublicKey(stranger);
        final tags = [
          ['vac', '00' * 32, '99999999999999999999', '00' * 32],
        ];
        final rumor = <String, dynamic>{
          'pubkey': author,
          'created_at': 1,
          'kind': 1,
          'tags': tags,
          'content': '',
        };
        rumor['id'] = computeEventId(
          pubkey: author,
          createdAt: 1,
          kind: 1,
          tags: tags,
          content: '',
        );
        final carrier = await wrapSeal(
          seal: await sealRumor(
            rumor: rumor,
            sealKind: 20014,
            streamSeedHex: address.seedHex,
            streamPubkey: address.pubkey,
            authorSecretHex: stranger,
          ),
          streamSeedHex: address.seedHex,
          streamPubkey: address.pubkey,
        );
        final relay = _Relay([...events(), carrier]);
        final s = session(
          relay,
          expected['member'] as String,
          InMemoryConcordStore('aa' * 32),
        );
        await s.start();
        expect(s.ready, isTrue);
        expect(s.failure, isNull);
        await s.close();
        await relay.close();
      },
    );
    test(
      'malformed relay carriers do not suppress valid community authority',
      () async {
        final carriers = events();
        final valid =
            (fixture['controlEvents'] as List).first as Map<String, dynamic>;
        carriers.insert(1, {...valid, 'content': 'corrupt encrypted carrier'});
        final relay = _Relay(carriers);
        final s = session(
          relay,
          expected['member'] as String,
          InMemoryConcordStore('99' * 32),
        );
        await s.start();
        expect(s.ready, isTrue);
        expect(s.control!.publicChannels.length, 2);
        await s.close();
        await relay.close();
      },
    );
    test(
      'a refreshed invite retains old-epoch authority and accepted floors',
      () async {
        final lifecycle = readConcordFixture('community-lifecycle.json');
        final bundleEvent = lifecycle['bundleEvent'] as Map<String, dynamic>;
        final link = ConcordInviteFragment.decode(
          Uri.parse(lifecycle['inviteUrl'] as String).fragment,
        );
        final account = (lifecycle['expected'] as Map)['member'] as String;
        final store = InMemoryConcordStore(account);
        ConcordCommunitySession build(_Relay relay) => ConcordCommunitySession(
          relay: relay,
          store: store,
          linkSigner: bundleEvent['pubkey'] as String,
          fragment: link,
          account: account,
          nowMs: () => 0,
        );
        final firstRelay = _Relay([
          bundleEvent,
          ...(lifecycle['controlEvents'] as List).cast<Map<String, dynamic>>(),
        ]);
        final first = build(firstRelay);
        await first.start();
        final priorHeads = {
          for (final entry in first.control!.heads.entries)
            entry.key: entry.value.hash,
        };
        final stopped = first.changes.firstWhere((_) => !first.ready);
        for (final event in lifecycle['baseRekeyEvents'] as List) {
          firstRelay.controllers.last.add(event as Map<String, dynamic>);
        }
        await stopped.timeout(const Duration(seconds: 10));
        expect(first.canPublish, isFalse);
        await first.close();
        await firstRelay.close();
        final nextRelay = _Relay([
          lifecycle['refreshedBundleEvent'] as Map<String, dynamic>,
          ...(lifecycle['nextEpochControlEvents'] as List)
              .cast<Map<String, dynamic>>(),
        ]);
        final next = build(nextRelay);
        await next.start();
        expect(next.bundle!.rootEpoch, 1);
        expect(next.canPublish, isTrue);
        expect({
          for (final entry in next.control!.heads.entries)
            entry.key: entry.value.hash,
        }, priorHeads);
        expect(next.control!.publicChannels.map((c) => c.name).toSet(), {
          'general',
          'introductions',
        });
        await next.close();
        await nextRelay.close();
      },
    );
  });
  group('ConcordCommunitySession reconnect', () {
    test(
      'newest-first replay recovers once the missing predecessor arrives',
      () async {
        final bootstrap = await _ReplayCommunity.bootstrap(fragment);
        final relay = _Relay(bootstrap);
        final s = ConcordCommunitySession(
          relay: relay,
          store: InMemoryConcordStore('aa' * 32),
          linkSigner: bootstrap.first['pubkey'] as String,
          fragment: fragment,
          account: 'aa' * 32,
          nowMs: () => 0,
        );
        await s.start();
        final gap = s.changes.firstWhere(
          (_) => s.control!.incomplete.isNotEmpty,
        );
        relay.receive(await _ReplayCommunity.channelWrap(3));
        await gap;
        expect(s.ready, isFalse);
        final complete = s.changes.firstWhere(
          (_) =>
              s.control!.channels[_ReplayCommunity.channel]!.name == 'room-3' &&
              s.control!.incomplete.isEmpty,
        );
        relay.receive(await _ReplayCommunity.channelWrap(2));
        await complete;
        await Future<void>.delayed(Duration.zero);
        expect(s.ready, isTrue);
        expect(s.failure, isNull);
        expect(s.canPublish, isTrue);
        await s.close();
        await relay.close();
      },
    );
  });
  group('ConcordCommunitySession.close', () {
    test(
      'close drains a pending bootstrap write before account erasure',
      () async {
        final relay = _Relay(events());
        final store = _DelayedStore(expected['member'] as String);
        final s = session(relay, expected['member'] as String, store);
        final bootstrap = s.start();
        await store.writing.future;
        final erased = s.close().then((_) => store.clearAccount());
        await Future<void>.delayed(Duration.zero);
        store.release.complete();
        await Future.wait([bootstrap, erased]);
        expect(await store.get('community-held-roots'), isNull);
        expect(await store.get('community-control-wraps'), isNull);
        expect(await store.get('community-control-heads'), isNull);
        await relay.close();
      },
    );
  });
  group('Retained outbox drafts', () {
    test(
      'earlier-epoch pending messages remain recoverable without replay',
      () async {
        final lifecycle = readConcordFixture('community-lifecycle.json');
        final bundleEvent = lifecycle['bundleEvent'] as Map<String, dynamic>;
        final link = ConcordInviteFragment.decode(
          Uri.parse(lifecycle['inviteUrl'] as String).fragment,
        );
        final secret = '33' * 32;
        final account = schnorr.getPublicKey(secret);
        final memberStore = InMemoryConcordStore(account);
        final outboxStore = InMemoryConcordStore(account);
        final channel =
            (((lifecycle['expected'] as Map)['channels'] as List).first
                    as Map)['id']
                as String;
        ConcordCommunitySession membership(_Relay relay) =>
            ConcordCommunitySession(
              relay: relay,
              store: memberStore,
              linkSigner: bundleEvent['pubkey'] as String,
              fragment: link,
              account: account,
              nowMs: () => 0,
            );
        ConcordRepository chat(_Relay relay, ConcordCommunitySession member) =>
            ConcordRepository(
              relay: relay,
              store: outboxStore,
              cipher: _OutboxCipher(),
              outboxAuthor: account,
              canPublish: () => member.canPublish,
              controlState: () => member.control,
              historicalOutboxKeys: () => {
                for (final root in member.heldMembership)
                  if (root.rootEpoch < member.bundle!.rootEpoch)
                    publicChannelKey(
                      root.communityRoot,
                      channel,
                      root.rootEpoch,
                    ).pubkey: (
                      key: publicChannelKey(
                        root.communityRoot,
                        channel,
                        root.rootEpoch,
                      ),
                      epoch: root.rootEpoch,
                    ),
              },
              sealedTransport: SealedChatTransport(
                relay: relay,
                signer: (template) async {
                  final id = computeEventId(
                    pubkey: account,
                    createdAt: template['created_at'] as int,
                    kind: template['kind'] as int,
                    tags: (template['tags'] as List).cast<List<String>>(),
                    content: template['content'] as String,
                  );
                  return {
                    ...template,
                    'pubkey': account,
                    'id': id,
                    'sig': schnorr.sign(secret, id, '00' * 32),
                  };
                },
              ),
            );
        final firstRelay = _Relay([
          bundleEvent,
          ...(lifecycle['controlEvents'] as List).cast<Map<String, dynamic>>(),
        ]);
        final firstMember = membership(firstRelay);
        await firstMember.start();
        final first = chat(firstRelay, firstMember);
        final oldKey = publicChannelKey(
          firstMember.bundle!.communityRoot,
          channel,
          0,
        );
        await first.startChannel(
          channelId: channel,
          epoch: 0,
          streamSeedHex: oldKey.seedHex,
          streamPubkey: oldKey.pubkey,
        );
        await expectLater(
          first.sendSealedMessage(
            channelId: channel,
            author: account,
            body: 'Keep this pending draft',
            createdAt: 1793760000,
            ms: 0,
            streamSeedHex: oldKey.seedHex,
            streamPubkey: oldKey.pubkey,
          ),
          throwsStateError,
        );
        final originalId = first.pendingIds.single;
        final stopped = firstMember.changes.firstWhere(
          (_) => !firstMember.ready,
        );
        for (final event in lifecycle['baseRekeyEvents'] as List) {
          firstRelay.receive(event as Map<String, dynamic>);
        }
        await stopped.timeout(const Duration(seconds: 10));
        await first.close();
        await firstMember.close();
        await firstRelay.close();
        final nextRelay = _Relay([
          lifecycle['refreshedBundleEvent'] as Map<String, dynamic>,
          ...(lifecycle['nextEpochControlEvents'] as List)
              .cast<Map<String, dynamic>>(),
        ]);
        final nextMember = membership(nextRelay);
        await nextMember.start();
        final next = chat(nextRelay, nextMember);
        final currentKey = publicChannelKey(
          nextMember.bundle!.communityRoot,
          channel,
          1,
        );
        await next.startChannel(
          channelId: channel,
          epoch: 1,
          streamSeedHex: currentKey.seedHex,
          streamPubkey: currentKey.pubkey,
        );
        expect(next.pendingIds, [originalId]);
        expect(next.pendingRequiresDraftRestore(originalId), isTrue);
        final draft = next.timeline(now: 1793761700).messages.single;
        expect(draft.body, 'Keep this pending draft');
        await expectLater(
          next.retryPending(messageId: originalId),
          throwsStateError,
        );
        expect(nextRelay.publications, 0);
        await expectLater(
          next.sendSealedMessage(
            channelId: channel,
            author: account,
            body: draft.body,
            createdAt: 1793760001,
            ms: 0,
            epoch: 1,
            streamSeedHex: currentKey.seedHex,
            streamPubkey: currentKey.pubkey,
          ),
          throwsStateError,
        );
        expect(next.pendingIds.length, 2);
        final newId = next.pendingIds.singleWhere((id) => id != originalId);
        final saved =
            jsonDecode((await outboxStore.get('sealed:$newId'))!) as Map;
        expect((saved['wrap'] as Map)['pubkey'], currentKey.pubkey);
        await next.discardPendingDraft(originalId);
        expect(next.pendingIds, [newId]);
        await next.close();
        await nextMember.close();
        await nextRelay.close();
      },
    );
  });
}
