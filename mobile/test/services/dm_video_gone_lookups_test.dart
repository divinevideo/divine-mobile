// ABOUTME: Unit tests for DmVideoGoneLookups: which kept video DMs' messages
// ABOUTME: are gone, and the conversation records it refreshes on the way.

import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/services/dm_video_conversation_records.dart';
import 'package:openvine/services/dm_video_gone_lookups.dart';
import 'package:unified_logger/unified_logger.dart';

const _sentAt = 1757385263;

DmMessage _videoMessage({String? id, String conversationId = 'room'}) =>
    DmMessage(
      id: id ?? 'a' * 64,
      conversationId: conversationId,
      senderPubkey: 'b' * 64,
      content: 'https://media.divine.video/${'d' * 64}',
      createdAt: _sentAt,
      giftWrapId: 'c' * 64,
      messageKind: 15,
    );

/// Everything logged since the last clear, error text included.
List<String> _loggedLines() => [
  for (final entry in LogCaptureService().getRecentLogs())
    '${entry.message} ${entry.error}',
];

void main() {
  group(DmVideoGoneLookups, () {
    late Directory dir;
    late DmVideoConversationRecords records;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('dm_video_gone_lookups_');
      records = DmVideoConversationRecords(
        writeAtomically: (File file, Uint8List bytes) async =>
            file.writeAsBytesSync(bytes),
      );
    });

    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    File recordOf(String id, String conversationId) =>
        DmVideoConversationRecords.recordOf(dir, id)
          ..writeAsStringSync('$conversationId\n$_sentAt');

    group('isGone', () {
      test('says a retracted message is gone', () async {
        final lookups = DmVideoGoneLookups(
          records: records,
          isMessageGone: (id) async => id == 'a' * 64,
        );

        expect(await lookups.isGone(_videoMessage(), dir), isTrue);
        expect(await lookups.isGone(_videoMessage(id: 'e' * 64), dir), isFalse);
      });

      test(
        'says a message is gone once its conversation was removed after it '
        'was sent',
        () async {
          final asked = <(String, int)>[];
          final lookups = DmVideoGoneLookups(
            records: records,
            isConversationRemoved: (conversationId, sentAt) async {
              asked.add((conversationId, sentAt));
              return conversationId == 'removed';
            },
          );

          expect(
            await lookups.isGone(_videoMessage(conversationId: 'removed'), dir),
            isTrue,
          );
          expect(
            await lookups.isGone(_videoMessage(id: 'e' * 64), dir),
            isFalse,
          );
          expect(asked, equals([('removed', _sentAt), ('room', _sentAt)]));
        },
      );

      test(
        'judges a message a repair moved by the conversation it is in now',
        () async {
          final lookups = DmVideoGoneLookups(
            records: records,
            isConversationRemoved: (conversationId, _) async =>
                conversationId == 'old-room',
            findMessageLocation: (_) async =>
                (conversationId: 'repaired', sentAt: _sentAt),
          );

          expect(
            await lookups.isGone(
              _videoMessage(conversationId: 'old-room'),
              dir,
            ),
            isFalse,
          );
        },
      );

      test(
        'remembers a message it found gone, once the rows that said so are '
        'cleared',
        () async {
          var retracted = true;
          final lookups = DmVideoGoneLookups(
            records: records,
            isMessageGone: (_) async => retracted,
          );
          await lookups.goneAmong({'1' * 64}, dir, {});
          expect(await lookups.isGone(_videoMessage(), dir), isTrue);

          // As an account switch clears the rows.
          retracted = false;

          expect(await lookups.isGone(_videoMessage(), dir), isTrue);
          expect(
            await lookups.isGone(_videoMessage(id: '1' * 64), dir),
            isTrue,
          );
          expect(
            (await lookups.goneAmong({'1' * 64}, dir, {})).gone,
            {'1' * 64},
          );
        },
      );

      group('with its row missing', () {
        DmVideoGoneLookups lookupsWithoutRows() => DmVideoGoneLookups(
          records: records,
          isConversationRemoved: (conversationId, _) async =>
              conversationId == 'removed',
          findMessageLocation: (_) async => null,
        );

        test(
          "cannot tell when its record and the caller's copy disagree on "
          'whether its conversation was removed, as either can predate a '
          'repair',
          () async {
            final lookups = lookupsWithoutRows();
            recordOf('a' * 64, 'room');
            recordOf('e' * 64, 'removed');

            await expectLater(
              lookups.isGone(_videoMessage(conversationId: 'removed'), dir),
              throwsA(isA<DmVideoGoneUndecided>()),
            );
            await expectLater(
              // In the conversation the helper names by default, 'room'.
              lookups.isGone(_videoMessage(id: 'e' * 64), dir),
              throwsA(isA<DmVideoGoneUndecided>()),
            );
          },
        );

        test(
          "goes by its record and the caller's copy where they agree",
          () async {
            final lookups = lookupsWithoutRows();
            recordOf('a' * 64, 'removed');
            recordOf('e' * 64, 'room');

            expect(
              await lookups.isGone(
                _videoMessage(conversationId: 'removed'),
                dir,
              ),
              isTrue,
            );
            expect(
              await lookups.isGone(
                _videoMessage(id: 'e' * 64, conversationId: 'other-room'),
                dir,
              ),
              isFalse,
            );
          },
        );
      });

      test(
        "does not remember a verdict from a record or the caller's copy, "
        'either of which can predate a repair',
        () async {
          DmVideoMessageLocation? row;
          final lookups = DmVideoGoneLookups(
            records: records,
            isConversationRemoved: (conversationId, _) async =>
                conversationId == 'old-room',
            findMessageLocation: (_) async => row,
          );
          final stale = _videoMessage(conversationId: 'old-room');
          expect(await lookups.isGone(stale, dir), isTrue);
          recordOf(stale.id, 'old-room');
          expect(await lookups.isGone(stale, dir), isTrue);

          row = (conversationId: 'repaired', sentAt: _sentAt);

          expect(await lookups.isGone(stale, dir), isFalse);
        },
      );

      test(
        'remembers a removal the row decided, once the rows that said so are '
        'cleared',
        () async {
          var cleared = false;
          final lookups = DmVideoGoneLookups(
            records: records,
            isConversationRemoved: (conversationId, _) async =>
                !cleared && conversationId == 'removed',
            findMessageLocation: (_) async =>
                cleared ? null : (conversationId: 'removed', sentAt: _sentAt),
          );
          expect(await lookups.isGone(_videoMessage(), dir), isTrue);

          cleared = true;

          expect(await lookups.isGone(_videoMessage(), dir), isTrue);
        },
      );

      test('says nothing is gone without lookups', () async {
        expect(
          await DmVideoGoneLookups(records: records)
              .isGone(_videoMessage(), dir),
          isFalse,
        );
      });

      test('throws what a lookup throws', () async {
        final lookups = DmVideoGoneLookups(
          records: records,
          isMessageGone: (_) async => throw StateError('database closed'),
        );

        await expectLater(
          lookups.isGone(_videoMessage(), dir),
          throwsA(isA<StateError>()),
        );
      });
    });

    group('goneAmong', () {
      test('finds retracted messages among those kept', () async {
        final lookups = DmVideoGoneLookups(
          records: records,
          isMessageGone: (id) async => id == '1' * 64,
        );

        final (:gone, :decided) = await lookups.goneAmong(
          {'1' * 64, '2' * 64},
          dir,
          {},
        );

        expect(gone, equals({'1' * 64}));
        expect(decided, isTrue);
      });

      test(
        'finds a message whose conversation is removed, by its row, or by its '
        'record once the row is gone',
        () async {
          final withRow = '1' * 64;
          final withoutRow = '2' * 64;
          final lookups = DmVideoGoneLookups(
            records: records,
            isConversationRemoved: (conversationId, _) async =>
                conversationId == 'removed',
            findMessageLocation: (id) async => id == withRow
                ? (conversationId: 'removed', sentAt: _sentAt)
                : null,
          );

          final (:gone, decided: _) = await lookups.goneAmong(
            {withRow, withoutRow},
            dir,
            {
              withoutRow: recordOf(withoutRow, 'removed'),
            },
          );

          expect(gone, equals({withRow, withoutRow}));
        },
      );

      test(
        'writes no record for a message still being fetched, and still says '
        'whether it is gone',
        () async {
          final fetching = '1' * 64;
          final lookups = DmVideoGoneLookups(
            records: records,
            isConversationRemoved: (conversationId, _) async =>
                conversationId == 'removed',
            findMessageLocation: (id) async => (
              conversationId: id == fetching ? 'room' : 'removed',
              sentAt: _sentAt,
            ),
          );

          final (:gone, :decided) = await lookups.goneAmong(
            {fetching, '2' * 64},
            dir,
            {},
            inFlight: {fetching, '2' * 64},
          );

          expect(gone, equals({'2' * 64}));
          expect(decided, isTrue);
          expect(dir.listSync(), isEmpty);
        },
      );

      test(
        'remembers no verdict it drew from a record, which can predate a '
        'repair',
        () async {
          final id = '1' * 64;
          DmVideoMessageLocation? row;
          final lookups = DmVideoGoneLookups(
            records: records,
            isConversationRemoved: (conversationId, _) async =>
                conversationId == 'removed',
            findMessageLocation: (_) async => row,
          );
          final (:gone, decided: _) = await lookups.goneAmong(
            {id},
            dir,
            {
              id: recordOf(id, 'removed'),
            },
          );
          expect(gone, equals({id}));

          // Back, in a conversation nobody removed.
          row = (conversationId: 'room', sentAt: _sentAt);

          expect(await lookups.isGone(_videoMessage(id: id), dir), isFalse);
        },
      );

      test(
        'remembers a removal a row decided, once the rows are cleared',
        () async {
          final id = '1' * 64;
          var cleared = false;
          final lookups = DmVideoGoneLookups(
            records: records,
            isConversationRemoved: (conversationId, _) async =>
                !cleared && conversationId == 'removed',
            findMessageLocation: (_) async =>
                cleared ? null : (conversationId: 'removed', sentAt: _sentAt),
          );
          await lookups.goneAmong({id}, dir, {});

          cleared = true;

          expect(await lookups.isGone(_videoMessage(id: id), dir), isTrue);
        },
      );

      test('rewrites the record of a message a repair moved', () async {
        final id = '1' * 64;
        final record = recordOf(id, 'old-room');
        final lookups = DmVideoGoneLookups(
          records: records,
          isConversationRemoved: (_, _) async => false,
          findMessageLocation: (_) async =>
              (conversationId: 'repaired', sentAt: _sentAt),
        );

        final (:gone, :decided) = await lookups.goneAmong(
          {id},
          dir,
          {id: record},
        );

        expect(gone, isEmpty);
        expect(decided, isTrue);
        expect(record.readAsStringSync(), equals('repaired\n$_sentAt'));
      });

      test(
        'keeps a message whose lookup fails, and says why without naming it',
        () async {
          final id = '1' * 64;
          final lookups = DmVideoGoneLookups(
            records: records,
            isMessageGone: (_) async => throw StateError('database closed'),
          );
          await LogCaptureService().clearAllLogs();

          final (:gone, :decided) = await lookups.goneAmong({id}, dir, {});

          expect(gone, isEmpty);
          expect(decided, isFalse);
          expect(_loggedLines(), contains(contains('is gone: StateError')));
          expect(_loggedLines(), isNot(contains(contains(id))));
        },
      );

      test(
        'finds nothing gone, and no failure, for a record deleted since the '
        'listing',
        () async {
          final id = '1' * 64;
          final lookups = DmVideoGoneLookups(
            records: records,
            isConversationRemoved: (_, _) async => true,
          );
          await LogCaptureService().clearAllLogs();

          final (:gone, :decided) = await lookups.goneAmong(
            {id},
            dir,
            {
              id: DmVideoConversationRecords.recordOf(dir, id),
            },
          );

          expect(gone, isEmpty);
          expect(decided, isTrue);
          expect(_loggedLines(), isNot(contains(contains('is gone'))));
        },
      );
    });
  });
}
