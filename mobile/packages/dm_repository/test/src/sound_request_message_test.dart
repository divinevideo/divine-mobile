import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';

const owner =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const viewer =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
const requestId =
    'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
const audioId =
    'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
const coordinate = '34236:$owner:clip:one';

DmMessage message(List<List<String>> tags, {String sender = viewer}) =>
    DmMessage(
      id: requestId,
      conversationId: DmRepository.computeConversationId([owner, viewer]),
      senderPubkey: sender,
      content: 'Readable fallback',
      createdAt: 1,
      giftWrapId: audioId,
      tags: tags,
    );

void main() {
  group('interactions', () {
    test('request keeps the complete address including colons in d-tag', () {
      final result = parseSoundRequestMessage(
        message([
          ['p', owner],
          ['divine', 'sound-request', '1'],
          ['a', coordinate, '', 'root'],
        ]),
        ownerPubkey: owner,
        isGroup: false,
      );
      expect(result?.videoAddress, coordinate);
      expect(result?.creatorPubkey, owner);
      expect(result?.kind, SoundRequestMessageKind.request);
    });
  });
  group('interactions', () {
    test(
      'ready message links request and sound and requires creator signature',
      () {
        final tags = soundReadyTags(
          videoAddress: coordinate,
          requestId: requestId,
          audioEventId: audioId,
        );
        final result = parseSoundRequestMessage(
          message([
            ['p', viewer],
            ...tags,
          ], sender: owner),
          ownerPubkey: viewer,
          isGroup: false,
        );
        expect(result?.audioEventId, audioId);
        expect(result?.requestId, requestId);
        expect(
          parseSoundRequestMessage(
            message([
              ['p', owner],
              ...tags,
            ]),
            ownerPubkey: owner,
            isGroup: false,
          ),
          isNull,
        );
      },
    );
  });
  group('interactions', () {
    test('rejects groups, unsupported versions and conflicting addresses', () {
      final tags = [
        ['p', owner],
        ...soundRequestTags(videoAddress: coordinate),
      ];
      expect(
        parseSoundRequestMessage(
          message(tags),
          ownerPubkey: owner,
          isGroup: true,
        ),
        isNull,
      );
      for (final invalid in [
        [
          ...tags,
          ['a', '34236:$viewer:other', '', 'root'],
        ],
        [
          ['p', owner],
          ['divine', 'sound-request', '2'],
          ['a', coordinate, '', 'root'],
        ],
        [
          ['p', owner],
          ['divine', 'sound-ready', '1'],
          ['a', coordinate, '', 'root'],
        ],
        [
          ['p', owner],
          ['divine', 'sound-request', '1'],
          ['a', '22:$owner:x', '', 'root'],
        ],
        [
          ['p', viewer],
          ...soundRequestTags(videoAddress: coordinate),
        ],
      ]) {
        expect(
          parseSoundRequestMessage(
            message(invalid),
            ownerPubkey: owner,
            isGroup: false,
          ),
          isNull,
        );
      }
    });
  });
  group('interactions', () {
    test('builders preserve event and reply markers independently', () {
      expect(
        soundReadyTags(
          videoAddress: coordinate,
          requestId: requestId,
          audioEventId: audioId,
        ),
        [
          ['divine', 'sound-ready', '1'],
          ['a', coordinate, '', 'root'],
          ['e', requestId, '', 'reply'],
          ['e', audioId, '', 'audio'],
        ],
      );
    });
  });
}
