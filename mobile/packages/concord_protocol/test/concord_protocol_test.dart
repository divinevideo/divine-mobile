// MPL-2.0
import 'dart:convert';
import 'dart:io';
import 'package:concord_protocol/concord_protocol.dart';
import 'package:test/test.dart';

class _XorCipher implements StreamCipher {
  @override
  String seal(String p, String s) => base64.encode(utf8.encode(p));
  @override
  String open(String c, String s) => utf8.decode(base64.decode(c));
}

String _readFixture(String name) {
  var dir = Directory.current;
  for (var i = 0; i < 8; i++) {
    for (final rel in [
      'test/fixtures/$name',
      'packages/concord_protocol/test/fixtures/$name',
      '../concord_protocol/test/fixtures/$name',
    ]) {
      final file = File('${dir.path}/$rel');
      if (file.existsSync()) return file.readAsStringSync();
    }
    dir = dir.parent;
  }
  throw StateError('$name fixture not found from ${Directory.current.path}');
}

void main() {
  group('concord_protocol', () {
    test('frozen v2 fixtures match TypeScript outputs bidirectionally', () {
      final f =
          jsonDecode(_readFixture('fixtures.json')) as Map<String, dynamic>;
      expect(f['version'], 2);
      final ids = f['identities'] as Map<String, dynamic>;
      final alice = ids['alice'] as Map<String, dynamic>;
      final secrets = f['secrets'] as Map<String, dynamic>;
      final d = f['derivations'] as Map<String, dynamic>;
      expect(
        deriveCommunityId(
          alice['pubkey'] as String,
          secrets['ownerSalt'] as String,
        ),
        d['communityId'],
      );
      void checkGk(Map<String, dynamic> v, GroupKey Function() fn) {
        final gk = fn();
        expect(gk.seedHex, v['seed']);
        expect(gk.pubkey, v['pubkey']);
      }

      checkGk(
        d['controlSigner'] as Map<String, dynamic>,
        () => controlSignerKey(
          secrets['controlRoot'] as String,
          d['communityId'] as String,
          0,
        ),
      );
      checkGk(
        d['controlRead'] as Map<String, dynamic>,
        () => controlReadKey(
          secrets['communityRoot'] as String,
          d['communityId'] as String,
          0,
        ),
      );
      checkGk(
        d['guestbook'] as Map<String, dynamic>,
        () => guestbookKey(
          secrets['communityRoot'] as String,
          d['communityId'] as String,
          0,
        ),
      );
      final pubCh = d['publicChannel'] as Map<String, dynamic>;
      checkGk(
        pubCh,
        () => publicChannelKey(
          secrets['communityRoot'] as String,
          pubCh['channelId'] as String,
          0,
        ),
      );
      final privCh = d['privateChannel'] as Map<String, dynamic>;
      checkGk(
        privCh,
        () => privateChannelKey(
          secrets['channelKey'] as String,
          privCh['channelId'] as String,
          1,
        ),
      );
      expect(
        dissolvedPubkey(d['communityId'] as String),
        (d['dissolved'] as Map<String, dynamic>)['pubkey'],
      );
      expect(
        grantLocator(d['communityId'] as String, alice['pubkey'] as String),
        d['grantLocatorAlice'],
      );
      expect(banlistLocator(d['communityId'] as String), d['banlistLocator']);
      expect(
        epochKeyCommitment(0, secrets['communityRoot'] as String),
        d['epochKeyCommitment'],
      );
      for (final v
          in (f['sha256Vectors'] as List).cast<Map<String, dynamic>>()) {
        expect(sha256Hex(v['input'] as String), v['expected']);
      }
      final rumors = f['rumors'] as Map<String, dynamic>;
      for (final key in ['message', 'reaction']) {
        final r = rumors[key] as Map<String, dynamic>;
        final tags = (r['tags'] as List)
            .map((t) => (t as List).map((e) => '$e').toList())
            .toList();
        expect(
          computeEventId(
            pubkey: r['pubkey'] as String,
            createdAt: r['created_at'] as int,
            kind: r['kind'] as int,
            tags: tags,
            content: r['content'] as String,
          ),
          r['id'],
        );
      }
      final ev = f['editionHashVector'] as Map<String, dynamic>;
      expect(
        editionHash(
          ev['eid'] as String,
          ev['version'] as int,
          null,
          ev['content'] as String,
        ),
        ev['expected'],
      );
      final list = f['communityList33302'] as Map<String, dynamic>;
      final entry = (list['entries'] as List).first as Map<String, dynamic>;
      expect(isB64url32(entry['community_id'] as String), isTrue);
      expect(entry['unknownEntryField'], 'preserve-me');
      expect(list['unknownFragmentField'], 'preserve-me-too');
      expect(hexToB64url(d['communityId'] as String), entry['community_id']);
    });

    test('held 33302 keys resolve public and private stream keys', () {
      final f =
          jsonDecode(_readFixture('fixtures.json')) as Map<String, dynamic>;
      final list = f['communityList33302'] as Map<String, dynamic>;
      final entry = (list['entries'] as List).first as Map<String, dynamic>;
      final current = entry['current'] as Map<String, dynamic>;
      final firstChannel =
          (current['channels'] as List).first as Map<String, dynamic>;
      final channelId = firstChannel['id'] as String;
      final pub = streamKeyFromListEntry(entry, channelId);
      final derivations = f['derivations'] as Map<String, dynamic>;
      expect(
        pub?.pubkey,
        (derivations['publicChannel'] as Map<String, dynamic>)['pubkey'],
      );
      final privEntry = jsonDecode(jsonEncode(entry)) as Map<String, dynamic>;
      final ch =
          ((privEntry['current'] as Map)['channels'] as List).first
              as Map<String, dynamic>;
      ch['key'] = hexToB64url(
        (f['secrets'] as Map<String, dynamic>)['channelKey'] as String,
      );
      ch['epoch'] = 1;
      final priv = streamKeyFromListEntry(privEntry, channelId);
      expect(
        priv?.pubkey,
        (derivations['privateChannel'] as Map<String, dynamic>)['pubkey'],
      );
      expect(streamKeyFromListEntry(entry, hexToB64url('ab' * 32)), isNull);
    });
    test('legacy v1 fixture still readable; unknown fields preserved', () {
      final f =
          jsonDecode(_readFixture('concord_v1.json')) as Map<String, dynamic>;
      final frag = CommunityListFragment.decode(
        jsonEncode(f['communityListFragment']),
      );
      expect(frag.kind, communityListKind);
      expect(frag.raw['unknownFutureField'], 'preserved');
      expect(frag.encode(), contains('unknownFutureField'));
    });
    test('envelope uses Concord wrap/seal kinds and round-trips', () {
      final e = StreamEnvelope.seal(
        _XorCipher(),
        streamId: 's1',
        plaintext: 'hello',
        createdAt: 1,
      );
      expect(e.toEventJson('pk')['kind'], streamWrapKind);
      expect(sealKindForPlane('chat'), 20013);
      expect(sealKindForPlane('control'), 20014);
      expect(e.open(_XorCipher()), 'hello');
    });
    test('folding applies edit/delete/reaction/expiry', () {
      final msgs = [
        ChatMessage(
          id: 'a',
          channelId: 'c',
          author: 'u',
          body: 'hi',
          createdAt: 1,
        ),
        ChatMessage(
          id: 'b',
          channelId: 'c',
          author: 'u',
          body: 'bye',
          createdAt: 2,
        ),
        ChatMessage(
          id: 'x',
          channelId: 'c',
          author: 'u',
          body: 'old',
          createdAt: 0,
          expiresAt: 5,
        ),
      ];
      final folded = foldControls(msgs, [
        ControlEvent(
          type: ControlType.edit,
          targetId: 'a',
          createdAt: 3,
          body: 'edited',
        ),
        ControlEvent(type: ControlType.delete, targetId: 'b', createdAt: 4),
        ControlEvent(
          type: ControlType.reaction,
          targetId: 'a',
          createdAt: 5,
          emoji: '❤️',
        ),
      ], now: 10);
      expect(folded.messages.map((m) => m.effectiveBody), ['edited']);
      expect(folded.reactions['a'], {'❤️': 1});
    });
  });
}
