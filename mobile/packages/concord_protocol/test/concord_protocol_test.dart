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

String _readFixture() {
  const rel = 'test/fixtures/concord_v1.json';
  final candidates = <String>[
    rel,
    'packages/concord_protocol/$rel',
    '../concord_protocol/$rel',
  ];
  var dir = Directory.current;
  for (var i = 0; i < 6; i++) {
    candidates
      ..add('${dir.path}/packages/concord_protocol/$rel')
      ..add('${dir.path}/$rel');
    dir = dir.parent;
  }
  for (final path in candidates) {
    final file = File(path);
    if (file.existsSync()) return file.readAsStringSync();
  }
  throw StateError(
    'concord_v1.json fixture not found from ${Directory.current.path}',
  );
}

void main() {
  group('concord_protocol', () {
    test('fixture vectors match (same JSON format as web slice)', () {
      final f = jsonDecode(_readFixture()) as Map<String, dynamic>;
      final v = f['streamId'] as Map<String, dynamic>;
      expect(
        deriveStreamId(v['communityId'] as String, v['channelId'] as String),
        v['expected'],
      );
      final frag = CommunityListFragment.decode(
        jsonEncode(f['communityListFragment']),
      );
      expect(frag.kind, communityListKind);
      expect(frag.raw['unknownFutureField'], 'preserved');
      expect(frag.encode(), contains('unknownFutureField'));
    });
    test('envelope is distinct from NIP-59 kinds and round-trips', () {
      final e = StreamEnvelope.seal(
        _XorCipher(),
        streamId: 's1',
        plaintext: 'hello',
        createdAt: 1,
      );
      expect(e.toEventJson('pk')['kind'], isNot(anyOf(1059, 13, 14)));
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
