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

      test('writes no mark back once it is gone', () {
        final marks = createMarks(launchId: 'earlier');
        final mark = markOf('1');
        marks.readStarted(mark, _sender);
        mark.deleteSync();

        marks.readEnded(mark);

        expect(mark.existsSync(), isFalse);
      });

      test('writes nothing for an account removed from the device', () {
        final marks = createMarks(launchId: 'earlier');
        final mark = markOf('1');
        marks.readStarted(mark, _sender);
        final named = mark.readAsStringSync();
        ownerRemoved = true;

        marks.readEnded(mark);

        expect(named, isNotEmpty);
        expect(mark.readAsStringSync(), equals(named));
      });
    });

    group('readHung', () {
      test(
        'names the sender for good, so a kill in the background still blames '
        'them',
        () {
          final marks = createMarks(launchId: 'earlier');
          final mark = markOf('1');
          marks
            ..readStarted(mark, _sender)
            ..readHung(mark)
            ..appInForeground = false;

          expect(laterLaunchBlamesTheSender(), isTrue);
        },
      );

      test(
        'names the sender of a read found hung while the app was in the '
        'background',
        () {
          final marks = createMarks(launchId: 'earlier');
          final mark = markOf('1');
          marks
            ..readStarted(mark, _sender)
            ..appInForeground = false;
          expect(laterLaunchBlamesTheSender(), isFalse);

          marks.readHung(mark);

          expect(laterLaunchBlamesTheSender(), isTrue);
        },
      );

      test(
        'skips the sender for the rest of the session, even once the read '
        'ends',
        () {
          final marks = createMarks(launchId: 'earlier');
          final mark = markOf('1');
          marks
            ..readStarted(mark, _sender)
            ..readHung(mark);
          expect(marks.senderHungTheDecoder(dir, _sender), isTrue);

          marks.readEnded(mark);

          expect(marks.senderHungTheDecoder(dir, _sender), isTrue);
          expect(laterLaunchBlamesTheSender(), isFalse);
        },
      );

      test('does nothing once the read ended', () {
        final marks = createMarks(launchId: 'earlier');
        final mark = markOf('1');
        marks
          ..readStarted(mark, _sender)
          ..readEnded(mark)
          ..readHung(mark);

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

    group('appInForeground', () {
      test('is true until the app is reported in the background', () {
        final marks = createMarks();
        expect(marks.appInForeground, isTrue);

        marks.appInForeground = false;

        expect(marks.appInForeground, isFalse);
      });

      test(
        'empties the mark of a read under way when the app goes to the '
        'background, so a kill there blames no one',
        () {
          final marks = createMarks(launchId: 'earlier');
          final mark = markOf('1');
          marks.readStarted(mark, _sender);

          marks.appInForeground = false;

          expect(mark.existsSync(), isTrue);
          expect(laterLaunchBlamesTheSender(), isFalse);
        },
      );

      test(
        'names the sender again when the app returns with the read still '
        'under way, so a crash then is still caught',
        () {
          final marks = createMarks(launchId: 'earlier');
          marks
            ..readStarted(markOf('1'), _sender)
            ..appInForeground = false
            ..appInForeground = true;

          expect(laterLaunchBlamesTheSender(), isTrue);
        },
      );

      test(
        'starts a read in the background with an empty mark, naming the '
        'sender once the app returns',
        () {
          final marks = createMarks(launchId: 'earlier')
            ..appInForeground = false
            ..readStarted(markOf('1'), _sender);
          expect(markOf('1').existsSync(), isTrue);
          expect(laterLaunchBlamesTheSender(), isFalse);

          marks.appInForeground = true;

          expect(laterLaunchBlamesTheSender(), isTrue);
        },
      );

      test(
        'leaves the mark of a read that ended meanwhile empty on return',
        () {
          final marks = createMarks(launchId: 'earlier');
          final mark = markOf('1');
          marks
            ..readStarted(mark, _sender)
            ..appInForeground = false
            ..readEnded(mark)
            ..appInForeground = true;

          expect(mark.existsSync(), isTrue);
          expect(laterLaunchBlamesTheSender(), isFalse);
        },
      );

      test('does not bring back the mark of a frame kept meanwhile', () {
        final marks = createMarks(launchId: 'earlier');
        final mark = markOf('1');
        marks
          ..readStarted(mark, _sender)
          ..appInForeground = false
          ..frameKept(mark)
          ..appInForeground = true;

        expect(mark.existsSync(), isFalse);
      });

      test(
        'writes no mark back once it is gone, as when the system cleared '
        'the folder',
        () {
          final marks = createMarks(launchId: 'earlier');
          final mark = markOf('1');
          marks.readStarted(mark, _sender);
          mark.deleteSync();

          marks
            ..appInForeground = false
            ..appInForeground = true;

          expect(mark.existsSync(), isFalse);
        },
      );

      test(
        'writes nothing for an account removed from the device meanwhile',
        () {
          final marks = createMarks(launchId: 'earlier');
          final mark = markOf('1');
          marks
            ..readStarted(mark, _sender)
            ..appInForeground = false;
          ownerRemoved = true;

          marks.appInForeground = true;

          expect(mark.readAsStringSync(), isEmpty);
        },
      );
    });

    group('senderHungTheDecoder', () {
      test('is false for a sender no launch left a read of', () {
        createMarks(launchId: 'earlier').readStarted(markOf('1'), 'c' * 64);

        expect(laterLaunchBlamesTheSender(), isFalse);
      });
    });
  });
}
