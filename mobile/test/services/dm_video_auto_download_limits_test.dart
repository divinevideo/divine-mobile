// ABOUTME: Unit tests for DmVideoAutoDownloadLimits: how often, and how soon
// ABOUTME: after a failure, a video DM card fetches a video by itself.

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/dm_video_auto_download_limits.dart';

final String _messageId = 'a' * 64;
const Duration _retryAfter = Duration(minutes: 2);

void main() {
  group(DmVideoAutoDownloadLimits, () {
    late Directory dir;
    late DateTime now;
    late bool Function() ownerRemoved;

    setUp(() {
      dir = Directory.systemTemp.createTempSync('dm_video_auto_downloads_');
      now = DateTime(2026, 9, 9, 12);
      ownerRemoved = () => false;
    });

    tearDown(() {
      if (dir.existsSync()) dir.deleteSync(recursive: true);
    });

    DmVideoAutoDownloadLimits createLimits() => DmVideoAutoDownloadLimits(
      maxTries: 3,
      retryAfter: _retryAfter,
      now: () => now,
      ownerRemoved: () => ownerRemoved(),
    );

    List<String> namesInDir() => [
      for (final file in dir.listSync()) file.uri.pathSegments.last,
    ];

    group('mayStart', () {
      test('lets downloads start until the most tries have started', () {
        final limits = createLimits();

        for (var started = 0; started < 3; started++) {
          expect(limits.mayStart(dir, _messageId), isTrue);
          limits.started(_messageId);
        }

        expect(limits.mayStart(dir, _messageId), isFalse);
      });

      test('counts the tries of each message apart', () {
        final limits = createLimits();
        for (var started = 0; started < 3; started++) {
          limits.started(_messageId);
        }

        expect(limits.mayStart(dir, 'b' * 64), isTrue);
      });
    });

    group('failed', () {
      test('waits before a download that may pass starts again', () async {
        final limits = createLimits();

        await limits.failed(dir, _messageId, mayPass: true, wanted: true);

        expect(limits.mayStart(dir, _messageId), isFalse);
        now = now.add(_retryAfter);
        expect(limits.mayStart(dir, _messageId), isTrue);
        expect(namesInDir(), isEmpty);
      });

      test(
        'does not hold back a download that may pass when no card wanted it',
        () async {
          final limits = createLimits();

          await limits.failed(dir, _messageId, mayPass: true, wanted: false);

          expect(limits.mayStart(dir, _messageId), isTrue);
        },
      );

      test(
        'starts no download that would fail again, in this session or a '
        'later one',
        () async {
          final limits = createLimits();

          await limits.failed(dir, _messageId, mayPass: false, wanted: true);

          now = now.add(_retryAfter * 10);
          expect(limits.mayStart(dir, _messageId), isFalse);
          expect(createLimits().mayStart(dir, _messageId), isFalse);
          final mark = dir.listSync().single as File;
          expect(DmVideoAutoDownloadLimits.isFailureMark(mark), isTrue);
        },
      );

      test(
        'leaves no mark, nor its folder, for an account removed from the '
        'device',
        () async {
          ownerRemoved = () => true;
          final accountDir = Directory('${dir.path}/removed');

          await createLimits().failed(
            accountDir,
            _messageId,
            mayPass: false,
            wanted: true,
          );

          expect(accountDir.existsSync(), isFalse);
        },
      );

      test(
        'deletes its mark when the account is removed while it is written',
        () async {
          var asked = 0;
          ownerRemoved = () => asked++ > 0;

          await createLimits().failed(
            dir,
            _messageId,
            mayPass: false,
            wanted: true,
          );

          expect(asked, equals(2));
          expect(namesInDir(), isEmpty);
        },
      );
    });

    group('isFailureMark', () {
      test('tells a failure mark from a kept video', () {
        expect(
          DmVideoAutoDownloadLimits.isFailureMark(
            File('${dir.path}/$_messageId.failed'),
          ),
          isTrue,
        );
        expect(
          DmVideoAutoDownloadLimits.isFailureMark(
            File('${dir.path}/$_messageId.mp4'),
          ),
          isFalse,
        );
      });
    });
  });
}
