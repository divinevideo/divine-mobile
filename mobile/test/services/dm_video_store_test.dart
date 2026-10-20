// ABOUTME: Tests for DmVideoStore: one download per received video DM, a kept
// ABOUTME: preview frame, pruning by age and size, and per-account folders.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/services/dm_video_decryptor.dart';
import 'package:openvine/services/dm_video_store.dart';

final String _owner = 'e' * 64;
final Uint8List _plaintext = Uint8List.fromList(
  List<int>.generate(64, (i) => i),
);
final Uint8List _frame = Uint8List.fromList(const [0xFF, 0xD8, 0xFF, 0xE0]);

DmMessage _videoMessage({
  String? id,
  String fileType = 'video/mp4',
  int? fileSize,
}) => DmMessage(
  id: id ?? 'a' * 64,
  conversationId: 'conversation',
  senderPubkey: 'b' * 64,
  content: 'https://media.divine.video/${'d' * 64}',
  createdAt: 1757385263,
  giftWrapId: 'c' * 64,
  messageKind: 15,
  fileMetadata: DmFileMetadata(
    fileType: fileType,
    encryptionAlgorithm: 'aes-gcm',
    decryptionKey: '00' * 32,
    decryptionNonce: '00' * 12,
    fileHash: 'f' * 64,
    fileSize: fileSize,
  ),
);

void main() {
  group(DmVideoStore, () {
    late Directory root;
    late DateTime now;
    late int fetches;
    late List<({int? maxBytes, Duration? timeLimit})> fetchLimits;
    late int frameReads;
    late Future<Uint8List> Function(DmMessage message) fetch;
    late Future<Uint8List?> Function(File video) readFrame;

    setUp(() {
      root = Directory.systemTemp.createTempSync('dm_video_store_');
      now = DateTime(2026, 10, 20, 12);
      fetches = 0;
      fetchLimits = [];
      frameReads = 0;
      fetch = (_) async => _plaintext;
      readFrame = (_) async => _frame;
    });

    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    DmVideoStore createStore({int maxBytes = DmVideoStore.defaultMaxBytes}) =>
        DmVideoStore(
          ownerPubkey: _owner,
          fetchVideo: (message, {maxBytes, timeLimit}) {
            fetches++;
            fetchLimits.add((maxBytes: maxBytes, timeLimit: timeLimit));
            return fetch(message);
          },
          readFrame: (video) {
            frameReads++;
            return readFrame(video);
          },
          rootDirectory: () async => root,
          now: () => now,
          maxBytes: maxBytes,
        );

    Directory ownerDir([String? owner]) =>
        Directory('${root.path}/${DmVideoStore.dirName}/${owner ?? _owner}');

    File keptFile(String name, List<int> bytes, {required DateTime opened}) =>
        File('${ownerDir().path}/$name')
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes)
          ..setLastModifiedSync(opened);

    group('videoFor', () {
      test(
        'downloads and decrypts a video once and keeps it for the account',
        () async {
          final store = createStore();
          final message = _videoMessage();

          final first = await store.videoFor(message);
          final second = await store.videoFor(message);

          expect(fetches, equals(1));
          expect(second.path, equals(first.path));
          expect(
            first.path,
            equals('${ownerDir().path}/${'a' * 64}.mp4'),
          );
          expect(first.readAsBytesSync(), equals(_plaintext));
        },
      );

      test('shares one download between callers asking at once', () async {
        final release = Completer<Uint8List>();
        fetch = (_) => release.future;
        final store = createStore();
        final message = _videoMessage();

        final first = store.videoFor(message);
        final second = store.videoFor(message);
        release.complete(_plaintext);

        expect((await first).path, equals((await second).path));
        expect(fetches, equals(1));
      });

      test('keeps no file when the download fails, and tries again', () async {
        fetch = (_) async => throw const SocketException('offline');
        final store = createStore();
        final message = _videoMessage();

        await expectLater(
          store.videoFor(message),
          throwsA(isA<SocketException>()),
        );
        expect(
          ownerDir().existsSync() ? ownerDir().listSync() : const <Never>[],
          isEmpty,
        );

        fetch = (_) async => _plaintext;
        final file = await store.videoFor(message);
        expect(file.readAsBytesSync(), equals(_plaintext));
        expect(fetches, equals(2));
      });

      test(
        'still returns a video that lands after the store is disposed',
        () async {
          final release = Completer<Uint8List>();
          fetch = (_) => release.future;
          final store = createStore();

          final video = store.videoFor(_videoMessage());
          await store.dispose();
          release.complete(_plaintext);

          expect((await video).readAsBytesSync(), equals(_plaintext));
        },
      );

      test('announces each newly kept video', () async {
        final store = createStore();
        final message = _videoMessage();
        final kept = <String>[];
        final subscription = store.kept.listen(kept.add);
        addTearDown(subscription.cancel);

        await store.videoFor(message);
        await store.videoFor(message);
        await pumpEventQueue();

        expect(kept, equals([message.id]));
      });

      test('marks a kept video as opened now', () async {
        final store = createStore();
        final message = _videoMessage();
        final file = await store.videoFor(message);
        file.setLastModifiedSync(now.subtract(const Duration(days: 20)));

        await store.videoFor(message);

        expect(file.lastModifiedSync(), equals(now));
      });
    });

    group('videoFileNameFor', () {
      // iOS picks the container parser from the file extension and refuses a
      // video named after the MIME subtype, such as `.quicktime`.
      const extensionsByFileType = {
        'video/mp4': 'mp4',
        'video/quicktime': 'mov',
        'video/QuickTime': 'mov',
        'video/x-m4v': 'm4v',
        'video/webm': 'webm',
        'video/x-msvideo': 'avi',
        'video/x-matroska': 'mkv',
        'video/3gpp': '3gp',
        'video/x-unknown': 'mp4',
      };

      for (final MapEntry(key: fileType, value: extension)
          in extensionsByFileType.entries) {
        test('names a $fileType video with the .$extension extension', () {
          expect(
            DmVideoStore.videoFileNameFor(_videoMessage(fileType: fileType)),
            equals('${'a' * 64}.$extension'),
          );
        });
      }
    });

    group('previewFor', () {
      test('grabs one frame from the video and keeps it', () async {
        final store = createStore();
        final message = _videoMessage();

        final first = await store.previewFor(message, download: true);
        final second = await store.previewFor(message, download: true);

        expect(first, isNotNull);
        expect(first!.readAsBytesSync(), equals(_frame));
        expect(second!.path, equals(first.path));
        expect(frameReads, equals(1));
        expect(fetches, equals(1));
      });

      test('downloads nothing when it may not download', () async {
        final store = createStore();

        final preview = await store.previewFor(
          _videoMessage(),
          download: false,
        );

        expect(preview, isNull);
        expect(fetches, isZero);
        expect(frameReads, isZero);
      });

      test(
        'uses a video already kept even when it may not download',
        () async {
          final store = createStore();
          final message = _videoMessage();
          await store.videoFor(message);

          final preview = await store.previewFor(message, download: false);

          expect(preview!.readAsBytesSync(), equals(_frame));
          expect(fetches, equals(1));
        },
      );

      test('keeps nothing when no frame can be read', () async {
        readFrame = (_) async => null;
        final store = createStore();
        final message = _videoMessage();

        final preview = await store.previewFor(message, download: true);

        expect(preview, isNull);
        expect(
          ownerDir().listSync().map((entity) => entity.path),
          equals(['${ownerDir().path}/${'a' * 64}.mp4']),
        );
      });
    });

    group('automatic downloads', () {
      test('run one video at a time', () async {
        final first = Completer<Uint8List>();
        final second = Completer<Uint8List>();
        fetch = (message) =>
            message.id == 'a' * 64 ? first.future : second.future;
        final store = createStore();

        final firstPreview = store.previewFor(_videoMessage(), download: true);
        final secondPreview = store.previewFor(
          _videoMessage(id: '9' * 64),
          download: true,
        );
        await pumpEventQueue();
        expect(fetches, equals(1));

        first.complete(_plaintext);
        await firstPreview;
        await pumpEventQueue();
        expect(fetches, equals(2));

        second.complete(_plaintext);
        expect(await secondPreview, isNotNull);
      });

      test('are limited in size and time, unlike a tap on play', () async {
        final store = createStore();

        await store.previewFor(_videoMessage(), download: true);
        await store.videoFor(_videoMessage(id: '9' * 64));

        expect(fetchLimits, [
          (
            maxBytes: DmVideoStore.autoDownloadMaxBytes,
            timeLimit: DmVideoStore.autoDownloadTimeLimit,
          ),
          (maxBytes: null, timeLimit: null),
        ]);
      });

      test('leave a video declared too big for a tap on play', () async {
        final store = createStore();

        final preview = await store.previewFor(
          _videoMessage(fileSize: DmVideoStore.autoDownloadMaxBytes + 1),
          download: true,
        );

        expect(preview, isNull);
        expect(fetches, isZero);
      });
    });

    group('prune', () {
      test('deletes what nobody opened for 30 days', () async {
        final stale = keptFile(
          'stale.mp4',
          const [1],
          opened: now.subtract(const Duration(days: 31)),
        );
        final recent = keptFile(
          'recent.mp4',
          const [1],
          opened: now.subtract(const Duration(days: 29)),
        );

        await createStore().prune();

        expect(stale.existsSync(), isFalse);
        expect(recent.existsSync(), isTrue);
      });

      test(
        'deletes the least recently opened first while over the cap',
        () async {
          final oldest = keptFile(
            'oldest.mp4',
            const [1, 2, 3, 4],
            opened: now.subtract(const Duration(hours: 3)),
          );
          final middle = keptFile(
            'middle.mp4',
            const [1, 2, 3, 4],
            opened: now.subtract(const Duration(hours: 2)),
          );
          final newest = keptFile(
            'newest.mp4',
            const [1, 2, 3, 4],
            opened: now.subtract(const Duration(hours: 1)),
          );

          await createStore(maxBytes: 8).prune();

          expect(oldest.existsSync(), isFalse);
          expect(middle.existsSync(), isTrue);
          expect(newest.existsSync(), isTrue);
        },
      );

      test('opening a kept video keeps it from expiring', () async {
        final store = createStore();
        final message = _videoMessage();
        final file = await store.videoFor(message);
        file.setLastModifiedSync(now.subtract(const Duration(days: 31)));

        await store.videoFor(message);
        await store.prune();

        expect(file.existsSync(), isTrue);
      });

      test('clears a write a crash left unfinished', () async {
        final unfinished = keptFile(
          '${'a' * 64}.mp4.part',
          const [1],
          opened: now,
        );

        await createStore().prune();

        expect(unfinished.existsSync(), isFalse);
      });
    });

    group('account folders', () {
      test("deleteOwner removes only that account's videos", () async {
        final other = 'f' * 64;
        keptFile('mine.mp4', const [1], opened: now);
        final theirs = File('${ownerDir(other).path}/theirs.mp4')
          ..createSync(recursive: true);

        await DmVideoStore.deleteOwner(_owner, rootDirectory: () async => root);

        expect(ownerDir().existsSync(), isFalse);
        expect(theirs.existsSync(), isTrue);
      });

      test(
        'sweepOwners removes accounts the device no longer knows',
        () async {
          final known = 'f' * 64;
          final forgotten = '1' * 64;
          for (final owner in [known, forgotten, _owner]) {
            File(
              '${ownerDir(owner).path}/video.mp4',
            ).createSync(recursive: true);
          }

          final deleted = await DmVideoStore.sweepOwners({
            known,
            _owner,
          }, rootDirectory: () async => root);

          expect(deleted, equals(1));
          expect(ownerDir(forgotten).existsSync(), isFalse);
          expect(ownerDir(known).existsSync(), isTrue);
          expect(ownerDir().existsSync(), isTrue);
        },
      );

      test(
        'writes nothing back for an account removed during its download',
        () async {
          final release = Completer<Uint8List>();
          fetch = (_) => release.future;
          final store = createStore();

          final video = store.videoFor(_videoMessage());
          await DmVideoStore.deleteOwner(
            _owner,
            rootDirectory: () async => root,
          );
          release.complete(_plaintext);

          await expectLater(video, throwsA(isA<DmVideoUnavailableException>()));
          expect(ownerDir().existsSync(), isFalse);
        },
      );

      test('a store created after the removal keeps videos again', () async {
        await DmVideoStore.deleteOwner(_owner, rootDirectory: () async => root);

        final video = await createStore().videoFor(_videoMessage());

        expect(video.readAsBytesSync(), equals(_plaintext));
      });

      test(
        'sweepOwners deletes what a known account left unopened for 30 days, '
        'and part files a crash left',
        () async {
          final unopened = keptFile(
            'unopened.mp4',
            const [1],
            opened: now.subtract(const Duration(days: 31)),
          );
          final recent = keptFile(
            'recent.mp4',
            const [1],
            opened: now.subtract(const Duration(days: 1)),
          );
          final crashed = keptFile(
            'crashed.mp4.part',
            const [1],
            opened: now.subtract(const Duration(hours: 2)),
          );
          final writing = keptFile('writing.mp4.part', const [1], opened: now);

          await DmVideoStore.sweepOwners(
            {_owner},
            rootDirectory: () async => root,
            now: () => now,
          );

          expect(unopened.existsSync(), isFalse);
          expect(crashed.existsSync(), isFalse);
          expect(recent.existsSync(), isTrue);
          expect(writing.existsSync(), isTrue);
        },
      );

      test('sweepOwners counts nothing when no video was kept', () async {
        final deleted = await DmVideoStore.sweepOwners(
          const {},
          rootDirectory: () async => root,
        );

        expect(deleted, isZero);
      });
    });
  });
}
