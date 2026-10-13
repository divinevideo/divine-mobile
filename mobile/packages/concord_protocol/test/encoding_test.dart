// MPL-2.0
import 'package:concord_protocol/concord_protocol.dart';
import 'package:test/test.dart';

// Kept separate from the file-backed fixtures so these vectors run on Chrome.
void main() {
  group('u64be', () {
    test('u64be preserves all bytes on VM and JavaScript', () {
      expect(bytesToHex(u64be(0)), '0000000000000000');
      expect(bytesToHex(u64be(1)), '0000000000000001');
      expect(bytesToHex(u64be(4294967296)), '0000000100000000');
      expect(bytesToHex(u64be(9007199254740991)), '001fffffffffffff');
      expect(() => u64be(-1), throwsArgumentError);
    });
  });

  group('CommunityListFragment.fromJson', () {
    test('fragment index is independent of its community entries', () {
      final fragment = CommunityListFragment.fromJson({
        'kind': communityListKind,
        'tags': [
          ['d', '3'],
        ],
        'entries': [
          {'community_id': 'A' * 43},
          {'community_id': 'B' * 43},
        ],
        'future': {'preserved': true},
      });
      expect(fragment.fragmentIndex, '3');
      expect(CommunityListFragment.decode(fragment.encode()).raw, fragment.raw);
    });
  });

  group('foldControls', () {
    for (final type in [ControlType.edit, ControlType.delete]) {
      test('$type only accepts the message author', () {
        final message = ChatMessage(
          id: '11' * 32,
          channelId: '22' * 32,
          author: '33' * 32,
          body: 'original',
          createdAt: 1,
        );
        for (final actor in ['', '44' * 32]) {
          final folded = foldControls(
            [message],
            [
              ControlEvent(
                type: type,
                targetId: message.id,
                createdAt: 2,
                actor: actor,
                body: 'edited',
              ),
            ],
            now: 3,
          );
          expect(folded.messages.single.effectiveBody, 'original');
        }
      });
    }
  });
}
