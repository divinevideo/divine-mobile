// ABOUTME: Tests for the divine-clip rumor tag on encrypted video DMs.

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/models/dm_clip_tag.dart';

const _videoMetadata = DmFileMetadata(
  fileType: 'video/mp4',
  encryptionAlgorithm: 'aes-gcm',
  decryptionKey: 'key',
  decryptionNonce: 'nonce',
  fileHash: 'hash',
);

DmMessage _message({
  List<List<String>> tags = const [],
  int messageKind = 15,
  DmFileMetadata? fileMetadata = _videoMetadata,
}) => DmMessage(
  id: 'rumor-id',
  conversationId: 'conversation-id',
  senderPubkey: 'sender',
  content: 'https://media.divine.video/cipher',
  createdAt: 1,
  giftWrapId: 'wrap-id',
  messageKind: messageKind,
  tags: tags,
  fileMetadata: fileMetadata,
);

void main() {
  group(DmClipTag, () {
    group('build', () {
      test('writes the tag name and the aspect ratio name', () {
        expect(
          DmClipTag.build(AspectRatio.square),
          equals(['divine-clip', 'square']),
        );
      });
    });

    group('targetAspectRatioIn', () {
      test('reads back the ratio it wrote', () {
        expect(
          DmClipTag.targetAspectRatioIn([
            ['file-type', 'video/mp4'],
            DmClipTag.build(AspectRatio.vertical),
          ]),
          equals(AspectRatio.vertical),
        );
      });

      test('returns null for a ratio this build does not know', () {
        expect(
          DmClipTag.targetAspectRatioIn([
            ['divine-clip', 'panorama'],
          ]),
          isNull,
        );
      });
    });
  });

  group('DmClipMessage', () {
    group('isDivineClip', () {
      test('is true for a tagged encrypted video', () {
        final message = _message(tags: [DmClipTag.build(AspectRatio.square)]);

        expect(message.isDivineClip, isTrue);
        expect(message.clipTargetAspectRatio, equals(AspectRatio.square));
      });

      test('is false for an untagged encrypted video', () {
        final message = _message(
          tags: [
            ['file-type', 'video/mp4'],
          ],
        );

        expect(message.isDivineClip, isFalse);
        expect(message.clipTargetAspectRatio, isNull);
      });

      test('is false for a tagged file that is not a video', () {
        final message = _message(
          tags: [DmClipTag.build(AspectRatio.square)],
          fileMetadata: const DmFileMetadata(
            fileType: 'image/jpeg',
            encryptionAlgorithm: 'aes-gcm',
            decryptionKey: 'key',
            decryptionNonce: 'nonce',
            fileHash: 'hash',
          ),
        );

        expect(message.isDivineClip, isFalse);
      });
    });
  });
}
