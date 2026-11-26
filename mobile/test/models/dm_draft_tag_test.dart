import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/models/dm_draft_tag.dart';

DmMessage _message({
  required String fileType,
  List<List<String>> tags = const [],
}) => DmMessage(
  id: '1' * 64,
  conversationId: 'conversation',
  senderPubkey: 'a' * 64,
  content: 'https://media.example.test/encrypted',
  createdAt: 1,
  giftWrapId: '2' * 64,
  messageKind: 15,
  tags: tags,
  fileMetadata: DmFileMetadata(
    fileType: fileType,
    encryptionAlgorithm: 'aes-gcm',
    decryptionKey: 'b' * 64,
    decryptionNonce: 'c' * 24,
    fileHash: 'd' * 64,
  ),
);

void main() {
  group(DmDraftTag, () {
    group('build', () {
      test('trims the title', () {
        expect(DmDraftTag.build('  Beach cut '), ['title', 'Beach cut']);
      });

      test('returns null for a missing or blank title', () {
        expect(DmDraftTag.build(null), isNull);
        expect(DmDraftTag.build('   '), isNull);
      });
    });

    group('titleIn', () {
      test('reads the first title tag', () {
        expect(
          DmDraftTag.titleIn([
            ['p', 'e' * 64],
            ['title', ' Beach cut '],
            ['title', 'Second'],
          ]),
          'Beach cut',
        );
      });

      test('ignores a missing, short or blank title tag', () {
        expect(DmDraftTag.titleIn(const []), isNull);
        expect(
          DmDraftTag.titleIn([
            ['title'],
          ]),
          isNull,
        );
        expect(
          DmDraftTag.titleIn([
            ['title', '  '],
          ]),
          isNull,
        );
      });
    });
  });

  group('DmDraftMessage', () {
    group('draftTitle', () {
      test('reads the title of a shared draft', () {
        final message = _message(
          fileType: DmFileMetadata.editableDraftMimeType,
          tags: [
            ['title', 'Beach cut'],
          ],
        );

        expect(message.isEditableDraft, isTrue);
        expect(message.draftTitle, 'Beach cut');
      });

      test('is null for a video that carries a title tag', () {
        final message = _message(
          fileType: 'video/mp4',
          tags: [
            ['title', 'Beach cut'],
          ],
        );

        expect(message.isEditableDraft, isFalse);
        expect(message.draftTitle, isNull);
      });
    });
  });
}
