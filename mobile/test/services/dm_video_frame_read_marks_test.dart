// ABOUTME: Unit tests for DmVideoFrameReadMarks: the marks around a video DM's
// ABOUTME: frame read, and the senders whose read an earlier launch left.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/dm_video_frame_read_marks.dart';

final String _sender = 'b' * 64;

void main() {
  group(DmVideoFrameReadMarks, () {
    late Directory dir;
    late bool ownerRemoved;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('dm_video_frame_read_marks_');
      ownerRemoved = false;
    });

    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    DmVideoFrameReadMarks createMarks({String? launchId}) =>
        DmVideoFrameReadMarks(
          ownerRemoved: () => ownerRemoved,
          launchId: launchId,
        );

    File markOf(String messageId) =>
        DmVideoFrameReadMarks.readMarkOf(dir, messageId);

    /// Whether a store of a later launch, looking at [dir] first, takes
    /// [_sender] for one whose frame read crashed the app.
    bool laterLaunchBlamesTheSender() =>
        (createMarks()..lookForUnfinishedReads(dir)).senderHungTheDecoder(
          dir,
          _sender,
        );

    List<File> senderMarks() => dir
        .listSync()
        .whereType<File>()
        .where(DmVideoFrameReadMarks.isSenderMark)
        .toList();

    group('readMarkOf', () {
      test('names a read mark after its message, inside the folder', () {
        final mark = markOf('../${'a' * 64}');

        expect(mark.parent.path, equals(dir.path));
        expect(DmVideoFrameReadMarks.isReadMark(mark), isTrue);
        expect(DmVideoFrameReadMarks.isSenderMark(mark), isFalse);
      });
    });

    group('readStarted', () {
      test(
        'leaves a mark a later launch takes for a read that never finished',
        () {
          createMarks(launchId: 'earlier').readStarted(markOf('1'), _sender);

          expect(laterLaunchBlamesTheSender(), isTrue);
        },
      );

      test('throws when the mark cannot be written', () {
        final elsewhere = DmVideoFrameReadMarks.readMarkOf(
          Directory('${dir.path}/missing'),
          '1',
        );

        expect(
          () => createMarks().readStarted(elsewhere, _sender),
          throwsA(isA<FileSystemException>()),
        );
      });
    });

    group('readEnded', () {
      test('keeps the mark, so the video is not read again, but blames no '
          'one', () {
        final marks = createMarks(launchId: 'earlier');
        final mark = markOf('1');
        marks
          ..readStarted(mark, _sender)
          ..readEnded(mark);

        expect(mark.existsSync(), isTrue);
        expect(laterLaunchBlamesTheSender(), isFalse);
      });
    });

    group('frameKept', () {
      test('deletes the mark', () {
        final marks = createMarks(launchId: 'earlier');
        final mark = markOf('1');
        marks
          ..readStarted(mark, _sender)
          ..frameKept(mark);

        expect(mark.existsSync(), isFalse);
        expect(laterLaunchBlamesTheSender(), isFalse);
      });
    });

    group('lookForUnfinishedReads', () {
      test("takes no read of this launch's for one an earlier launch left", () {
        createMarks(launchId: 'this').readStarted(markOf('1'), _sender);

        final sameLaunch = createMarks(launchId: 'this')
          ..lookForUnfinishedReads(dir);

        expect(sameLaunch.senderHungTheDecoder(dir, _sender), isFalse);
      });

      test('leaves a mark of the sender that outlasts the read mark', () {
        createMarks(launchId: 'earlier').readStarted(markOf('1'), _sender);
        createMarks().lookForUnfinishedReads(dir);
        // As when the video and its read mark expired before the sender's.
        markOf('1').deleteSync();

        expect(senderMarks(), hasLength(1));
        expect(laterLaunchBlamesTheSender(), isTrue);
      });

      test(
        'remembers the sender for its own store only once the account is '
        'removed from the device, writing nothing back into its folder',
        () {
          createMarks(launchId: 'earlier').readStarted(markOf('1'), _sender);
          ownerRemoved = true;

          final marks = createMarks()..lookForUnfinishedReads(dir);

          expect(marks.senderHungTheDecoder(dir, _sender), isTrue);
          expect(senderMarks(), isEmpty);
        },
      );

      test('finds nothing in a folder that does not exist', () {
        final marks = createMarks()
          ..lookForUnfinishedReads(Directory('${dir.path}/missing'));

        expect(marks.senderHungTheDecoder(dir, _sender), isFalse);
      });
    });

    group('senderHungTheDecoder', () {
      test('is false for a sender no launch left a read of', () {
        createMarks(launchId: 'earlier').readStarted(markOf('1'), 'c' * 64);

        expect(laterLaunchBlamesTheSender(), isFalse);
      });
    });
  });
}
