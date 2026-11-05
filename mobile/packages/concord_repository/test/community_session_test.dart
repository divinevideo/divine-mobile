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

/// A synthetic owner-rooted community whose owner and moderator keys the test
/// holds, so it can author control editions after the session has loaded.
class _Community {
  static const ownerSecret =
      'a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1a1';
  static const linkSecret =
      'b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2b2';
  static const moderatorSecret =
      'c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3c3';
  static const member =
      'd4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4d4';
  static const salt =
      'e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5e5';
  static const root =
      'f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6f6';
  static const channelId =
      'abababababababababababababababababababababababababababababababab';
  static const roleId =
      '5555555555555555555555555555555555555555555555555555555555555555';
  static final token = List<int>.generate(16, (i) => i + 1);
  final String owner = schnorr.getPublicKey(ownerSecret);
  final String link = schnorr.getPublicKey(linkSecret);
  final String moderator = schnorr.getPublicKey(moderatorSecret);
  late final String communityId = deriveCommunityId(owner, salt);
  late final GroupKey read = controlReadKey(root, communityId, 0);
  late final fragment = ConcordInviteFragment.decode(
    base64Url.encode([4, 0, 0, ...token]),
  );
  var _serial = 0;

  static Map<String, dynamic> _signed(
    String secret,
    int kind,
    List<List<String>> tags,
    String content,
  ) {
    final pubkey = schnorr.getPublicKey(secret);
    final id = computeEventId(
      pubkey: pubkey,
      createdAt: 1,
      kind: kind,
      tags: tags,
      content: content,
    );
    return {
      'id': id,
      'pubkey': pubkey,
      'created_at': 1,
      'kind': kind,
      'tags': tags,
      'content': content,
      'sig': schnorr.sign(secret, id, '00' * 32),
    };
  }

  Map<String, dynamic> _rumor(
    String author,
    int kind,
    List<List<String>> tags,
    String content,
  ) {
    // A distinct timestamp keeps otherwise identical rumors apart.
    final createdAt = ++_serial;
    return {
      'id': computeEventId(
        pubkey: author,
        createdAt: createdAt,
        kind: kind,
        tags: tags,
        content: content,
      ),
      'pubkey': author,
      'created_at': createdAt,
      'kind': kind,
      'tags': tags,
      'content': content,
    };
  }

  Future<Map<String, dynamic>> invite() async => _signed(
    linkSecret,
    33301,
    [
      ['d', ''],
      ['vsk', '6'],
    ],
    await nip44Encrypt(
      jsonEncode({
        'community_id': communityId,
        'owner': owner,
        'owner_salt': salt,
        'community_root': root,
        'root_epoch': 0,
        'channels': <dynamic>[],
        'relays': <String>[],
      }),
      inviteBundleKey(token),
    ),
  );

  /// An owner-authored control edition and the relay carrier holding it.
  Future<({Map<String, dynamic> wrap, String hash})> edition(
    String vsk,
    String entityId,
    Object content, {
    int version = 1,
    String? previous,
  }) async {
    final encoded = jsonEncode(content);
    final rumor = _rumor(owner, 3308, [
      ['vsk', vsk],
      ['eid', entityId],
      ['ev', '$version'],
      if (previous != null) ['ep', previous],
    ], encoded);
    final wrap = await wrapSeal(
      seal: await sealRumor(
        rumor: rumor,
        sealKind: 20014,
        streamSeedHex: read.seedHex,
        streamPubkey: read.pubkey,
        authorSecretHex: ownerSecret,
      ),
      streamSeedHex: read.seedHex,
      streamPubkey: read.pubkey,
    );
    return (
      wrap: wrap,
      hash: editionHash(entityId, version, previous, encoded),
    );
  }

  Future<Map<String, dynamic>> metadata(
    String name, {
    int version = 1,
    String? previous,
  }) async => (await edition(
    '0',
    communityId,
    {'name': name},
    version: version,
    previous: previous,
  )).wrap;

  /// A base-rotation signal from the moderator citing its grant edition.
  Future<Map<String, dynamic>> moderatorRotation(
    String grantHash, {
    List<String>? recipients,
    int chunkIndex = 1,
    int chunkCount = 1,
    int grantVersion = 1,
  }) async {
    final rekey = groupKey(
      'concord/base-rekey-pseudonym',
      root,
      communityId,
      epoch: 1,
    );
    final rumor = _rumor(
      moderator,
      3303,
      [
        ['scope', '00' * 32],
        ['prevepoch', '0'],
        ['newepoch', '1'],
        ['prevcommit', epochKeyCommitment(0, root)],
        [
          'vac',
          grantLocator(communityId, moderator),
          '$grantVersion',
          grantHash,
        ],
        ['chunk', '$chunkIndex', '$chunkCount'],
      ],
      jsonEncode([
        for (final recipient in recipients ?? [owner, moderator])
          {
            'locator': bytesToHex(
              hkdfSeed(
                hexToBytes(moderator + recipient),
                'concord/recipient-pseudonym',
                hexToBytes('00' * 32),
                epoch: 1,
              ),
            ),
            'wrapped': 'synthetic opaque recipient material',
          },
      ]),
    );
    return wrapSeal(
      seal: await sealRumor(
        rumor: rumor,
        sealKind: 20013,
        streamSeedHex: rekey.seedHex,
        streamPubkey: rekey.pubkey,
        authorSecretHex: moderatorSecret,
      ),
      streamSeedHex: rekey.seedHex,
      streamPubkey: rekey.pubkey,
    );
  }

  ConcordCommunitySession session(_Relay relay, AccountScopedStore store) =>
      ConcordCommunitySession(
        relay: relay,
        store: store,
        linkSigner: link,
        fragment: fragment,
        account: member,
        nowMs: () => 0,
      );
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
        final content = jsonEncode([
          for (final recipient in [_ReplayCommunity.owner, moderator])
            {
              'locator': bytesToHex(
                hkdfSeed(
                  hexToBytes(moderator + recipient),
                  'concord/recipient-pseudonym',
                  hexToBytes('00' * 32),
                  epoch: 1,
                ),
              ),
              'wrapped': 'synthetic opaque recipient material',
            },
        ]);
        final rumor = <String, dynamic>{
          'kind': 3303,
          'pubkey': moderator,
          'created_at': 1,
          'tags': tags,
          'content': content,
          'id': computeEventId(
            pubkey: moderator,
            createdAt: 1,
            kind: 3303,
            tags: tags,
            content: content,
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
        lifecycle['halfThenCompleteRekeyEvents'] = [
          ...(lifecycle['halfPublishedRekeyEvents'] as List),
          ...(lifecycle['baseRekeyEvents'] as List),
        ];
        for (final name in [
          'baseRekeyEvents',
          'dissolvedEvents',
          'impostorDissolvedEvents',
          'impostorRekeyEvents',
          'halfPublishedRekeyEvents',
          'halfThenCompleteRekeyEvents',
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
  group('ConcordCommunitySession after load', () {
    test(
      'editions replayed newest first after a reconnect do not close Rooms',
      () async {
        final c = _Community();
        final first = await c.edition('0', c.communityId, {'name': 'Divine'});
        final relay = _Relay([
          await c.invite(),
          first.wrap,
          (await c.edition('2', _Community.channelId, {
            'name': 'general',
          })).wrap,
        ]);
        final s = c.session(relay, InMemoryConcordStore(_Community.member));
        await s.start();
        expect(s.ready, isTrue);
        // Two renames while the socket was down. On reconnect the relay
        // replays stored events newest first, so v3 arrives before v2.
        final second = await c.edition(
          '0',
          c.communityId,
          {'name': 'Divine two'},
          version: 2,
          previous: first.hash,
        );
        final third = await c.metadata(
          'Divine three',
          version: 3,
          previous: second.hash,
        );
        final readiness = s.changes.map((_) => s.ready).take(2).toList();
        relay
          ..receive(third)
          ..receive(second.wrap);
        expect(await readiness.timeout(const Duration(seconds: 10)), [
          isFalse,
          isTrue,
        ]);
        expect(s.failure, isNull);
        expect(s.control!.name, 'Divine three');
        await s.close();
        await relay.close();
      },
    );
    test('a ban or a lasting gap after load keeps Rooms closed', () async {
      final c = _Community();
      final first = await c.edition('0', c.communityId, {'name': 'Divine'});
      final room = await c.edition('2', _Community.channelId, {
        'name': 'general',
      });
      for (final change in [
        await c.metadata('Divine three', version: 3, previous: '00' * 32),
        (await c.edition('4', banlistLocator(c.communityId), [
          _Community.member,
        ])).wrap,
      ]) {
        final relay = _Relay([await c.invite(), first.wrap, room.wrap]);
        final s = c.session(relay, InMemoryConcordStore(_Community.member));
        await s.start();
        expect(s.ready, isTrue);
        final changed = s.changes.first;
        relay.receive(change);
        await changed.timeout(const Duration(seconds: 10));
        expect(s.ready, isFalse);
        expect(s.canPublish, isFalse);
        // A held gap keeps the accepted name rather than the gapped edition.
        expect(s.control!.name, 'Divine');
        await s.close();
        await relay.close();
      }
    });
    test(
      'a moderator demoted since the last sync cannot stop a returning '
      'device with a rotation signal',
      () async {
        final c = _Community();
        final store = InMemoryConcordStore(_Community.member);
        final grantId = grantLocator(c.communityId, c.moderator);
        final authority = [
          await c.invite(),
          await c.metadata('Divine'),
          (await c.edition('2', _Community.channelId, {
            'name': 'general',
          })).wrap,
          (await c.edition('1', _Community.roleId, {
            'role_id': _Community.roleId,
            'position': 1,
            'permissions': 16,
          })).wrap,
        ];
        final grant = await c.edition('3', grantId, {
          'member': c.moderator,
          'role_ids': [_Community.roleId],
        });
        final firstRelay = _Relay([...authority, grant.wrap]);
        final first = c.session(firstRelay, store);
        await first.start();
        expect(first.control!.permits(c.moderator, 16), isTrue);
        await first.close();
        await firstRelay.close();
        final demotion = await c.edition(
          '3',
          grantId,
          {'member': c.moderator, 'role_ids': <String>[]},
          version: 2,
          previous: grant.hash,
        );
        final nextRelay = _Relay([
          ...authority,
          grant.wrap,
          demotion.wrap,
          await c.moderatorRotation(grant.hash),
        ]);
        final next = c.session(nextRelay, store);
        await next.start();
        expect(next.ready, isTrue);
        expect(next.control!.permits(c.moderator, 16), isFalse);
        expect(await store.get('community-stop'), isNull);
        await next.close();
        await nextRelay.close();
      },
    );
    test(
      'a rotation from a moderator whose demotion is still missing cannot '
      'stop a loaded device',
      () async {
        final c = _Community();
        final store = InMemoryConcordStore(_Community.member);
        final grantId = grantLocator(c.communityId, c.moderator);
        final grant = await c.edition('3', grantId, {
          'member': c.moderator,
          'role_ids': [_Community.roleId],
        });
        final relay = _Relay([
          await c.invite(),
          await c.metadata('Divine'),
          (await c.edition('2', _Community.channelId, {
            'name': 'general',
          })).wrap,
          (await c.edition('1', _Community.roleId, {
            'role_id': _Community.roleId,
            'position': 1,
            'permissions': 16,
          })).wrap,
          grant.wrap,
        ]);
        final s = c.session(relay, store);
        await s.start();
        expect(s.ready, isTrue);
        // The demotion is v2; v3 arrives first, so the held gap keeps the v1
        // grant and the fold still reports the moderator's ban permission.
        final demotion = await c.edition(
          '3',
          grantId,
          {'member': c.moderator, 'role_ids': <String>[]},
          version: 2,
          previous: grant.hash,
        );
        final after = await c.edition(
          '3',
          grantId,
          {'member': c.moderator, 'role_ids': <String>[]},
          version: 3,
          previous: demotion.hash,
        );
        final gap = s.changes.first;
        relay.receive(after.wrap);
        await gap.timeout(const Duration(seconds: 10));
        expect(s.control!.incomplete, isNotEmpty);
        expect(s.control!.permits(c.moderator, 16), isTrue);
        // Session work runs in order, so the change from re-delivering the
        // gapped edition lands only after the rotation has been checked.
        final checked = s.changes.first;
        relay
          ..receive(await c.moderatorRotation(grant.hash))
          ..receive(after.wrap);
        await checked.timeout(const Duration(seconds: 10));
        expect(await store.get('community-stop'), isNull);
        expect(s.failure, isNull);
        final complete = s.changes.firstWhere(
          (_) => s.control!.incomplete.isEmpty,
        );
        relay.receive(demotion.wrap);
        await complete.timeout(const Duration(seconds: 10));
        // The completed fold queues a signal check; the next re-delivery's
        // change lands after it.
        final rechecked = s.changes.first;
        relay.receive(after.wrap);
        await rechecked.timeout(const Duration(seconds: 10));
        expect(s.control!.permits(c.moderator, 16), isFalse);
        expect(await store.get('community-stop'), isNull);
        expect(s.failure, isNull);
        expect(s.ready, isTrue);
        await s.close();
        await relay.close();
      },
    );
  });
  group('Delegated base rotations', () {
    test('require every protected recipient across complete chunks', () async {
      final c = _Community();
      final equal = schnorr.getPublicKey('d1' * 32);
      final higher = schnorr.getPublicKey('d2' * 32);
      final higherRole = 'd3' * 32;
      final grant = await c.edition(
        '3',
        grantLocator(c.communityId, c.moderator),
        {
          'member': c.moderator,
          'role_ids': [_Community.roleId],
        },
      );
      final authority = [
        await c.invite(),
        await c.metadata('Divine'),
        (await c.edition('2', _Community.channelId, {'name': 'general'})).wrap,
        (await c.edition('1', _Community.roleId, {
          'role_id': _Community.roleId,
          'position': 2,
          'permissions': '16',
        })).wrap,
        (await c.edition('1', higherRole, {
          'role_id': higherRole,
          'position': 1,
          'permissions': '16',
        })).wrap,
        grant.wrap,
        (await c.edition('3', grantLocator(c.communityId, equal), {
          'member': equal,
          'role_ids': [_Community.roleId],
        })).wrap,
        (await c.edition('3', grantLocator(c.communityId, higher), {
          'member': higher,
          'role_ids': [higherRole],
        })).wrap,
      ];
      final protected = [c.owner, c.moderator, equal, higher];
      for (final omitted in <String?>['', ...protected, null]) {
        final recipients = omitted == ''
            ? <String>[]
            : protected.where((p) => p != omitted).toList();
        final relay = _Relay([
          ...authority,
          await c.moderatorRotation(
            grant.hash,
            recipients: recipients.take(2).toList(),
            chunkCount: 2,
          ),
          await c.moderatorRotation(
            grant.hash,
            recipients: recipients.skip(2).toList(),
            chunkIndex: 2,
            chunkCount: 2,
          ),
        ]);
        final store = InMemoryConcordStore(_Community.member);
        final session = c.session(relay, store);
        if (omitted == null) {
          await expectLater(session.start(), throwsStateError);
          expect(await store.get('community-stop'), isNotNull);
        } else {
          await session.start();
          expect(session.canPublish, isTrue, reason: 'omitted $omitted');
          expect(await store.get('community-stop'), isNull);
        }
        await session.close();
        await relay.close();
      }
    });
    test('may leave out a lower-ranked grant holder', () async {
      final c = _Community();
      final lower = schnorr.getPublicKey('d6' * 32);
      final lowerRole = 'd7' * 32;
      final grant = await c.edition(
        '3',
        grantLocator(c.communityId, c.moderator),
        {
          'member': c.moderator,
          'role_ids': [_Community.roleId],
        },
      );
      final relay = _Relay([
        await c.invite(),
        await c.metadata('Divine'),
        (await c.edition('2', _Community.channelId, {'name': 'general'})).wrap,
        (await c.edition('1', _Community.roleId, {
          'role_id': _Community.roleId,
          'position': 2,
          'permissions': '16',
        })).wrap,
        (await c.edition('1', lowerRole, {
          'role_id': lowerRole,
          'position': 3,
          'permissions': '0',
        })).wrap,
        grant.wrap,
        (await c.edition('3', grantLocator(c.communityId, lower), {
          'member': lower,
          'role_ids': [lowerRole],
        })).wrap,
        // The moderator outranks `lower`, so it may rotate them out.
        await c.moderatorRotation(
          grant.hash,
          recipients: [c.owner, c.moderator],
        ),
      ]);
      final store = InMemoryConcordStore(_Community.member);
      final session = c.session(relay, store);
      await expectLater(session.start(), throwsStateError);
      expect(await store.get('community-stop'), isNotNull);
      await session.close();
      await relay.close();
    });
    test('do not combine chunks that cite different grant editions', () async {
      final c = _Community();
      final grantId = grantLocator(c.communityId, c.moderator);
      final content = {
        'member': c.moderator,
        'role_ids': [_Community.roleId],
      };
      final grant = await c.edition('3', grantId, content);
      // An unchanged regrant: both citations are satisfied on their own.
      final regrant = await c.edition(
        '3',
        grantId,
        content,
        version: 2,
        previous: grant.hash,
      );
      final relay = _Relay([
        await c.invite(),
        await c.metadata('Divine'),
        (await c.edition('2', _Community.channelId, {'name': 'general'})).wrap,
        (await c.edition('1', _Community.roleId, {
          'role_id': _Community.roleId,
          'position': 1,
          'permissions': '16',
        })).wrap,
        grant.wrap,
        regrant.wrap,
        await c.moderatorRotation(
          grant.hash,
          recipients: [c.owner],
          chunkCount: 2,
        ),
        await c.moderatorRotation(
          regrant.hash,
          recipients: [c.moderator],
          chunkIndex: 2,
          chunkCount: 2,
          grantVersion: 2,
        ),
      ]);
      final store = InMemoryConcordStore(_Community.member);
      final session = c.session(relay, store);
      await session.start();
      expect(session.control!.permits(c.moderator, 16), isTrue);
      expect(session.canPublish, isTrue);
      expect(await store.get('community-stop'), isNull);
      await session.close();
      await relay.close();
    });
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
