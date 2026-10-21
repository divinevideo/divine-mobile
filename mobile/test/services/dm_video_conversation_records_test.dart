// ABOUTME: Unit tests for DmVideoConversationRecords: the record kept beside a
// ABOUTME: video DM of its conversation and send time, written and refreshed.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/services/dm_video_conversation_records.dart';
import 'package:openvine/services/dm_video_decryptor.dart';

DmMessage _videoMessage({String conversationId = 'conversation'}) => DmMessage(
  id: 'a' * 64,
  conversationId: conversationId,
  senderPubkey: 'b' * 64,
  content: 'https://media.divine.video/${'d' * 64}',
  createdAt: 1757385263,
  giftWrapId: 'c' * 64,
  messageKind: 15,
);

void main() {
  group(DmVideoConversationRecords, () {
    late Directory dir;
    late int writes;
    late bool failWrites;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('dm_video_records_');
      writes = 0;
      failWrites = false;
    });

    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    DmVideoConversationRecords createRecords() => DmVideoConversationRecords(
      writeAtomically: (File file, Uint8List bytes) async {
        writes++;
        if (failWrites) {
          throw const DmVideoStorageException('could not store the file');
        }
        file.writeAsBytesSync(bytes);
      },
    );

    File recordOf(DmMessage message) =>
        DmVideoConversationRecords.recordOf(dir, message.id);

    group('recordOf', () {
      test('names a record after its message, inside the folder', () {
        final record = DmVideoConversationRecords.recordOf(
          dir,
          '../${'a' * 64}',
        );

        expect(record.parent.path, equals(dir.path));
        expect(DmVideoConversationRecords.isRecord(record), isTrue);
        expect(
          DmVideoConversationRecords.isRecord(File('${dir.path}/a.mp4')),
          isFalse,
        );
      });
    });

    group('write', () {
      test('writes the conversation and when the message was sent', () async {
        final message = _videoMessage();

        await createRecords().write(message, dir);

        expect(
          recordOf(message).readAsStringSync(),
          equals('conversation\n1757385263'),
        );
      });

      test('writes nothing again while the record says the same', () async {
        final records = createRecords();
        final message = _videoMessage();
        await records.write(message, dir);
        expect(writes, equals(1));

        await records.write(message, dir);
        await createRecords().write(message, dir);

        expect(writes, equals(1));
      });

      test('writes again when the record went missing', () async {
        final records = createRecords();
        final message = _videoMessage();
        await records.write(message, dir);

        recordOf(message).deleteSync();
        await records.write(message, dir);

        expect(writes, equals(2));
        expect(recordOf(message).existsSync(), isTrue);
      });

      test(
        "leaves a record it has to a refresh, whatever a caller's copy says, "
        'as that copy can predate a repair',
        () async {
          final records = createRecords();
          await records.write(_videoMessage(conversationId: 'repaired'), dir);

          await records.write(_videoMessage(conversationId: 'old-room'), dir);
          await createRecords().write(
            _videoMessage(conversationId: 'old-room'),
            dir,
          );

          expect(
            recordOf(_videoMessage()).readAsStringSync(),
            equals('repaired\n1757385263'),
          );
          expect(writes, equals(1));
        },
      );

      test('throws when the record cannot be written', () async {
        failWrites = true;

        await expectLater(
          createRecords().write(_videoMessage(), dir),
          throwsA(isA<DmVideoStorageException>()),
        );
      });
    });

    group('writeQuietly', () {
      test('carries on when the record cannot be written', () async {
        failWrites = true;

        await expectLater(
          createRecords().writeQuietly(_videoMessage(), dir),
          completes,
        );
        expect(writes, equals(1));
      });
    });

    group('refresh', () {
      test(
        'rewrites a record a repair moved, and nothing when current',
        () async {
          final records = createRecords();
          final message = _videoMessage(conversationId: 'misfiled');
          await records.write(message, dir);
          final record = recordOf(message);
          const location = (conversationId: 'moved', sentAt: 1757385263);

          await records.refresh(record, location);
          await records.refresh(record, location);

          expect(record.readAsStringSync(), equals('moved\n1757385263'));
          expect(writes, equals(2));
        },
      );

      test(
        'leaves a record it could not rewrite to the next refresh',
        () async {
          final records = createRecords();
          final message = _videoMessage(conversationId: 'misfiled');
          await records.write(message, dir);
          failWrites = true;
          const moved = (conversationId: 'moved', sentAt: 1757385263);

          await records.refresh(recordOf(message), moved);
          failWrites = false;
          await records.refresh(recordOf(message), moved);

          expect(
            recordOf(message).readAsStringSync(),
            equals('moved\n1757385263'),
          );
          expect(writes, equals(3));
        },
      );
    });

    group('read', () {
      test('names the conversation and send time the record holds', () async {
        final message = _videoMessage();
        await createRecords().write(message, dir);

        final said = await DmVideoConversationRecords.read(recordOf(message));

        expect(said?.conversationId, equals('conversation'));
        expect(said?.sentAt, equals(1757385263));
      });

      test('names nothing when the record does not hold both', () async {
        final record = recordOf(_videoMessage())..writeAsStringSync('only');

        expect(await DmVideoConversationRecords.read(record), isNull);
      });

      test('throws when the record is gone', () async {
        await expectLater(
          DmVideoConversationRecords.read(recordOf(_videoMessage())),
          throwsA(isA<PathNotFoundException>()),
        );
      });
    });
  });
}
