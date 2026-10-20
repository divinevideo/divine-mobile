// ABOUTME: Tests for DmVideoStore: one download per received video DM, a kept
// ABOUTME: preview frame, pruning by age and size, and per-account folders.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/services/dm_video_decryptor.dart';
import 'package:openvine/services/dm_video_store.dart';
import 'package:unified_logger/unified_logger.dart';

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

/// A folder that exists but cannot be listed, as when its permissions change.
class _UnreadableDirectory implements Directory {
  _UnreadableDirectory(this.path);

  @override
  final String path;

  @override
  bool existsSync() => true;

  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) => Stream.error(
    FileSystemException(
      'Directory listing failed',
      path,
      const OSError('Permission denied', 13),
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A folder that exists, may hold [children], and cannot be deleted.
class _UndeletableDirectory implements Directory {
  _UndeletableDirectory(this.path, {this.children = const []});

  @override
  final String path;

  final List<FileSystemEntity> children;

  @override
  Uri get uri => Uri.directory(path);

  @override
  bool existsSync() => true;

  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) => Stream.fromIterable(children);

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) => Future.error(
    FileSystemException(
      'Deletion failed',
      path,
      const OSError('Directory not empty', 66),
    ),
  );

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// A folder that records its deletion.
class _DeletableDirectory implements Directory {
  _DeletableDirectory(this.path);

  @override
  final String path;

  bool deleted = false;

  @override
  Uri get uri => Uri.directory(path);

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) async {
    deleted = true;
    return this;
  }

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

/// Everything logged since the last clear, error text included.
List<String> _loggedLines() => [
  for (final entry in LogCaptureService().getRecentLogs())
    '${entry.message} ${entry.error}',
];

void main() {
  group(DmVideoStore, () {
    late Directory root;
    late DateTime now;
    late int fetches;
    late List<({int? maxBytes, Duration? timeLimit})> fetchLimits;
    late List<bool Function()?> fetchWanted;
    late int frameReads;
    late Future<Uint8List> Function(DmMessage message) fetch;
    late Future<Uint8List?> Function(File video) readFrame;

    setUp(() {
      root = Directory.systemTemp.createTempSync('dm_video_store_');
      now = DateTime(2026, 10, 20, 12);
      fetches = 0;
      fetchLimits = [];
      fetchWanted = [];
      frameReads = 0;
      fetch = (_) async => _plaintext;
      readFrame = (_) async => _frame;
    });

    tearDown(() {
      if (root.existsSync()) root.deleteSync(recursive: true);
    });

    DmVideoStore createStore({
      int maxBytes = DmVideoStore.defaultMaxBytes,
      Future<bool> Function(String messageId)? isMessageGone,
    }) => DmVideoStore(
      ownerPubkey: _owner,
      fetchVideo: (message, {maxBytes, timeLimit, stillWanted}) {
        fetches++;
        fetchLimits.add((maxBytes: maxBytes, timeLimit: timeLimit));
        fetchWanted.add(stillWanted);
        return fetch(message);
      },
      readFrame: (video) {
        frameReads++;
        return readFrame(video);
      },
      rootDirectory: () async => root,
      now: () => now,
      maxBytes: maxBytes,
      isMessageGone: isMessageGone,
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

      test(
        'reports a video it cannot store without naming the file, which '
        'carries the account and the message',
        () async {
          // A file where the account's folder belongs: nothing can be stored.
          File(ownerDir().path).createSync(recursive: true);

          await expectLater(
            createStore().videoFor(_videoMessage()),
            throwsA(
              isA<DmVideoUnavailableException>().having(
                (error) => error.toString(),
                'description',
                isNot(contains(root.path)),
              ),
            ),
          );
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

      test('two reads of the same frame at once both succeed', () async {
        final frameRead = Completer<Uint8List?>();
        readFrame = (_) => frameRead.future;
        final store = createStore();
        final message = _videoMessage();
        await store.videoFor(message);

        final allowed = store.previewFor(message, download: true);
        final notAllowed = store.previewFor(message, download: false);
        await pumpEventQueue();
        frameRead.complete(_frame);

        expect((await allowed)!.readAsBytesSync(), equals(_frame));
        expect((await notAllowed)!.readAsBytesSync(), equals(_frame));
        expect(frameReads, equals(1));
      });

      test(
        'never decodes again a video whose last frame read never finished, '
        'as when the decoder crashed the app',
        () async {
          final readStarted = Completer<void>();
          readFrame = (_) {
            readStarted.complete();
            return Completer<Uint8List?>().future;
          };
          final message = _videoMessage();
          unawaited(createStore().previewFor(message, download: true));
          await readStarted.future;
          expect(frameReads, equals(1));

          readFrame = (_) async => _frame;
          final afterRestart = createStore();

          expect(
            await afterRestart.previewFor(message, download: true),
            isNull,
          );
          expect(frameReads, equals(1));
        },
      );

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

      test(
        'remembers a frame it read, so a card built again can show it at once',
        () async {
          final store = createStore();
          final message = _videoMessage();
          expect(store.knownPreviewPathFor(message), isNull);

          final preview = await store.previewFor(message, download: true);

          expect(store.knownPreviewPathFor(message), equals(preview!.path));
        },
      );

      test(
        'forgets a frame the system cleared, so no card starts from it',
        () async {
          final store = createStore();
          final message = _videoMessage();
          final preview = await store.previewFor(message, download: true);
          expect(store.knownPreviewPathFor(message), equals(preview!.path));

          preview.deleteSync();

          expect(store.knownPreviewPathFor(message), isNull);
        },
      );

      test(
        'remembers a frame an earlier session kept once it finds it',
        () async {
          final message = _videoMessage();
          final kept = await createStore().previewFor(message, download: true);
          final store = createStore();
          expect(store.knownPreviewPathFor(message), isNull);

          await store.previewFor(message, download: false);

          expect(store.knownPreviewPathFor(message), equals(kept!.path));
        },
      );

      test(
        'tries a frame that cannot be read only once a session',
        () async {
          readFrame = (_) async => null;
          final message = _videoMessage();
          final store = createStore();

          await store.previewFor(message, download: true);
          await store.previewFor(message, download: true);
          expect(frameReads, equals(1));

          await createStore().previewFor(message, download: true);
          expect(frameReads, equals(2));
        },
      );

      test(
        'decodes nothing when told not to, showing only a frame read before',
        () async {
          final store = createStore();
          final message = _videoMessage();
          await store.videoFor(message);

          expect(
            await store.previewFor(message, download: false, decode: false),
            isNull,
          );
          expect(frameReads, isZero);

          final read = await store.previewFor(message, download: false);
          expect(
            (await store.previewFor(
              message,
              download: false,
              decode: false,
            ))?.path,
            equals(read!.path),
          );
          expect(frameReads, equals(1));
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

      test(
        'share a download a tap is waiting on, rather than fetching twice',
        () async {
          final release = Completer<Uint8List>();
          fetch = (_) => release.future;
          final store = createStore();
          final message = _videoMessage();

          final preview = store.previewFor(message, download: true);
          await pumpEventQueue();
          expect(fetches, equals(1));
          final tapped = store.videoFor(message);
          release.complete(_plaintext);

          expect((await tapped).readAsBytesSync(), equals(_plaintext));
          expect(await preview, isNotNull);
          expect(fetches, equals(1));
        },
      );

      test(
        'leave a tap to fetch in full when the download it joined fails on a '
        'limit',
        () async {
          final release = Completer<Uint8List>();
          fetch = (_) =>
              fetches == 1 ? release.future : Future.value(_plaintext);
          final store = createStore();
          final message = _videoMessage();

          final previewFailure = expectLater(
            store.previewFor(message, download: true),
            throwsA(isA<DmVideoUnavailableException>()),
          );
          await pumpEventQueue();
          final tapped = store.videoFor(message);
          release.completeError(
            const DmVideoUnavailableException('ciphertext exceeds the size'),
          );

          expect((await tapped).readAsBytesSync(), equals(_plaintext));
          expect(
            fetchLimits.map((limits) => limits.maxBytes),
            equals([DmVideoStore.autoDownloadMaxBytes, null]),
          );
          await previewFailure;
        },
      );

      test(
        'use a video a tap is already fetching, rather than fetching again',
        () async {
          final release = Completer<Uint8List>();
          fetch = (_) => release.future;
          final store = createStore();
          final message = _videoMessage();

          final tapped = store.videoFor(message);
          await pumpEventQueue();
          expect(fetches, equals(1));
          final preview = store.previewFor(message, download: true);
          await pumpEventQueue();
          release.complete(_plaintext);

          expect(await preview, isNotNull);
          expect((await tapped).readAsBytesSync(), equals(_plaintext));
          expect(fetches, equals(1));
        },
      );

      test('never make a tap wait behind them', () async {
        final blocking = Completer<Uint8List>();
        final queued = _videoMessage(id: '9' * 64);
        final fetchedIds = <String>[];
        fetch = (message) {
          fetchedIds.add(message.id);
          return message.id == queued.id
              ? Future.value(_plaintext)
              : blocking.future;
        };
        final store = createStore();

        final blockingPreview = store.previewFor(
          _videoMessage(),
          download: true,
        );
        final queuedPreview = store.previewFor(queued, download: true);
        await pumpEventQueue();

        final tapped = await store.videoFor(queued);
        expect(tapped.readAsBytesSync(), equals(_plaintext));

        blocking.complete(_plaintext);
        await blockingPreview;
        expect(await queuedPreview, isNotNull);
        expect(fetchedIds.where((id) => id == queued.id), hasLength(1));
      });

      test('are not tried again this session after failing for good', () async {
        fetch = (_) async => throw const DmVideoUnavailableException(
          'ciphertext hash does not match the x tag',
        );
        final store = createStore();
        final message = _videoMessage();

        await expectLater(
          store.previewFor(message, download: true),
          throwsA(isA<DmVideoUnavailableException>()),
        );
        now = now.add(const Duration(days: 1));

        expect(await store.previewFor(message, download: true), isNull);
        expect(fetches, equals(1));
      });

      test(
        'are tried again after a failure that may pass, once a while has '
        'passed',
        () async {
          fetch = (_) async => fetches == 1
              ? throw const DmVideoUnavailableException(
                  'the download failed: connectionError',
                  mayPass: true,
                )
              : _plaintext;
          final store = createStore();
          final message = _videoMessage();
          await expectLater(
            store.previewFor(message, download: true),
            throwsA(isA<DmVideoUnavailableException>()),
          );

          expect(await store.previewFor(message, download: true), isNull);
          expect(fetches, equals(1));

          now = now.add(DmVideoStore.autoDownloadRetryAfter);
          expect(await store.previewFor(message, download: true), isNotNull);
          expect(fetches, equals(2));
        },
      );

      test(
        'leave a tap free to fetch a video whose download failed',
        () async {
          fetch = (_) async => fetches == 1
              ? throw const DmVideoUnavailableException(
                  'ciphertext exceeds the size limit',
                )
              : _plaintext;
          final store = createStore();
          final message = _videoMessage();
          await expectLater(
            store.previewFor(message, download: true),
            throwsA(isA<DmVideoUnavailableException>()),
          );

          expect(
            (await store.videoFor(message)).readAsBytesSync(),
            equals(_plaintext),
          );
          expect(await store.previewFor(message, download: true), isNotNull);
        },
      );

      test('drop a queued download nobody wants any more', () async {
        final blocking = Completer<Uint8List>();
        final unwanted = _videoMessage(id: '9' * 64);
        final fetchedIds = <String>[];
        fetch = (message) {
          fetchedIds.add(message.id);
          return message.id == unwanted.id
              ? Future.value(_plaintext)
              : blocking.future;
        };
        final store = createStore();
        var wanted = true;

        final first = store.previewFor(_videoMessage(), download: true);
        final dropped = store.previewFor(
          unwanted,
          download: true,
          stillWanted: () => wanted,
        );
        await pumpEventQueue();
        wanted = false;
        blocking.complete(_plaintext);

        expect(await first, isNotNull);
        expect(await dropped, isNull);
        expect(fetchedIds, isNot(contains(unwanted.id)));
      });

      test('keep a queued download that another card still wants', () async {
        final blocking = Completer<Uint8List>();
        final shared = _videoMessage(id: '9' * 64);
        fetch = (message) => message.id == shared.id
            ? Future.value(_plaintext)
            : blocking.future;
        final store = createStore();

        final first = store.previewFor(_videoMessage(), download: true);
        final closed = store.previewFor(
          shared,
          download: true,
          stillWanted: () => false,
        );
        final open = store.previewFor(
          shared,
          download: true,
          stillWanted: () => true,
        );
        await pumpEventQueue();
        blocking.complete(_plaintext);

        expect(await open, isNotNull);
        expect(await closed, isNotNull);
        expect(await first, isNotNull);
      });

      test('read no frame of a video nobody wants any more', () async {
        final release = Completer<Uint8List>();
        fetch = (_) => release.future;
        final store = createStore();
        final message = _videoMessage();
        var wanted = true;

        final preview = store.previewFor(
          message,
          download: true,
          stillWanted: () => wanted,
        );
        await pumpEventQueue();
        wanted = false;
        release.complete(_plaintext);

        expect(await preview, isNull);
        expect(frameReads, isZero);
        expect(
          File(
            '${ownerDir().path}/${DmVideoStore.videoFileNameFor(message)}',
          ).existsSync(),
          isTrue,
        );
      });

      test(
        'let the download stop once nobody wants it, unless a tap waits',
        () async {
          final release = Completer<Uint8List>();
          fetch = (_) => release.future;
          final store = createStore();
          final message = _videoMessage();
          var wanted = true;

          final preview = store.previewFor(
            message,
            download: true,
            stillWanted: () => wanted,
          );
          await pumpEventQueue();
          final stillWanted = fetchWanted.single!;
          wanted = false;
          expect(stillWanted(), isFalse);

          final tapped = store.videoFor(message);
          expect(stillWanted(), isTrue);

          release.complete(_plaintext);
          await tapped;
          await preview;
        },
      );

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

      test('forgets a frame it deleted, so no card starts from it', () async {
        final store = createStore();
        final message = _videoMessage();
        final preview = await store.previewFor(message, download: true);
        preview!.setLastModifiedSync(now.subtract(const Duration(days: 31)));

        await store.prune();

        expect(preview.existsSync(), isFalse);
        expect(store.knownPreviewPathFor(message), isNull);
      });

      test(
        'gives up on a folder it cannot list, logging why but not where',
        () async {
          await LogCaptureService().clearAllLogs();

          await IOOverrides.runZoned(
            () => expectLater(createStore().prune(), completes),
            createDirectory: _UnreadableDirectory.new,
          );

          expect(_loggedLines(), contains(contains('Permission denied')));
          expect(_loggedLines(), everyElement(isNot(contains(root.path))));
        },
      );

      test(
        'keeps the mark of a frame read still running, whatever the cap',
        () async {
          final readStarted = Completer<void>();
          readFrame = (_) {
            readStarted.complete();
            return Completer<Uint8List?>().future;
          };
          final message = _videoMessage();
          final store = createStore(maxBytes: 0);
          unawaited(store.previewFor(message, download: true));
          await readStarted.future;

          await store.prune();

          readFrame = (_) async => _frame;
          expect(
            await createStore().previewFor(message, download: true),
            isNull,
          );
          expect(frameReads, equals(1));
        },
      );

      test(
        'deletes what is kept for a message that is gone, retracted or '
        'removed',
        () async {
          final gone = _videoMessage(id: '9' * 64);
          final shown = _videoMessage();
          final earlier = createStore();
          final goneFrame = await earlier.previewFor(gone, download: true);
          final shownFrame = await earlier.previewFor(shown, download: true);
          final goneVideo = File(
            '${ownerDir().path}/${DmVideoStore.videoFileNameFor(gone)}',
          );
          expect(goneVideo.existsSync(), isTrue);
          final store = createStore(
            isMessageGone: (messageId) async => messageId == gone.id,
          );
          expect(await store.previewFor(gone, download: false), isNotNull);

          await store.prune();

          expect(goneVideo.existsSync(), isFalse);
          expect(goneFrame!.existsSync(), isFalse);
          expect(shownFrame!.existsSync(), isTrue);
          expect(store.knownPreviewPathFor(gone), isNull);
        },
      );

      test("keeps a gone message's video while it is played", () async {
        final message = _videoMessage();
        final store = createStore(isMessageGone: (_) async => true);
        final played = await store.videoFor(message);

        await store.prune();

        expect(played.existsSync(), isTrue);
      });

      test(
        'keeps everything when it cannot tell whether a message is gone',
        () async {
          final message = _videoMessage();
          final store = createStore(
            isMessageGone: (_) async => throw StateError('database closed'),
          );
          final frame = await store.previewFor(message, download: true);

          await store.prune();

          expect(frame!.existsSync(), isTrue);
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

      test('clears a part file a crash left', () async {
        final crashed = keptFile(
          '${'a' * 64}.mp4.0.part',
          const [1],
          opened: now.subtract(const Duration(hours: 2)),
        );

        await createStore().prune();

        expect(crashed.existsSync(), isFalse);
      });

      test(
        'leaves a part file younger than an hour: it may still be written',
        () async {
          final writing = keptFile(
            '${'a' * 64}.mp4.0.part',
            const [1],
            opened: now,
          );

          await createStore().prune();

          expect(writing.existsSync(), isTrue);
        },
      );

      test(
        'never trims a video handed to playback or a save, even the least '
        'recently opened',
        () async {
          final store = createStore(maxBytes: 4);
          final played = await store.videoFor(_videoMessage());
          played.setLastModifiedSync(now.subtract(const Duration(hours: 2)));
          final newer = keptFile('newer.mp4', const [1, 2, 3, 4], opened: now);

          await store.prune();

          expect(played.existsSync(), isTrue);
          expect(newer.existsSync(), isFalse);
        },
      );

      test(
        'trims a video fetched only for its frame, keeping the frame, once '
        'the frame is read',
        () async {
          final store = createStore(maxBytes: _frame.length);
          final message = _videoMessage();
          final preview = await store.previewFor(message, download: true);
          final video = File(
            '${ownerDir().path}/${DmVideoStore.videoFileNameFor(message)}',
          )..setLastModifiedSync(now.subtract(const Duration(minutes: 1)));
          preview!.setLastModifiedSync(now);

          await store.prune();

          expect(video.existsSync(), isFalse);
          expect(preview.existsSync(), isTrue);
        },
      );

      test('never deletes a video whose frame is being read', () async {
        final frameRead = Completer<Uint8List?>();
        readFrame = (_) => frameRead.future;
        final store = createStore();
        final message = _videoMessage();
        final video = keptFile(
          DmVideoStore.videoFileNameFor(message),
          _plaintext,
          opened: now.subtract(const Duration(days: 31)),
        );
        final preview = store.previewFor(message, download: false);
        await pumpEventQueue();

        await store.prune();
        expect(video.existsSync(), isTrue);

        frameRead.complete(_frame);
        expect(await preview, isNotNull);
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

      test(
        'sweepOwners gives up on a folder it cannot list, logging why but '
        'not where',
        () async {
          Directory('${root.path}/${DmVideoStore.dirName}').createSync();
          await LogCaptureService().clearAllLogs();

          final deleted = await IOOverrides.runZoned(
            () => DmVideoStore.sweepOwners(
              {_owner},
              rootDirectory: () async => root,
              now: () => now,
            ),
            createDirectory: _UnreadableDirectory.new,
          );

          expect(deleted, isZero);
          expect(_loggedLines(), contains(contains('Permission denied')));
          expect(_loggedLines(), everyElement(isNot(contains(root.path))));
        },
      );

      test(
        "deleteOwner reports a folder it cannot delete without the folder's "
        'path',
        () async {
          await expectLater(
            IOOverrides.runZoned(
              () => DmVideoStore.deleteOwner(
                _owner,
                rootDirectory: () async => root,
              ),
              createDirectory: _UndeletableDirectory.new,
            ),
            throwsA(
              isA<DmVideoUnavailableException>().having(
                (error) => error.toString(),
                'description',
                isNot(contains(root.path)),
              ),
            ),
          );
        },
      );

      test(
        'sweepOwners goes on past a folder it cannot delete',
        () async {
          final stuck = _UndeletableDirectory('${root.path}/stuck');
          final gone = _DeletableDirectory('${root.path}/gone');

          final deleted = await IOOverrides.runZoned(
            () => DmVideoStore.sweepOwners(
              {_owner},
              rootDirectory: () async => root,
              now: () => now,
            ),
            createDirectory: (path) =>
                _UndeletableDirectory(path, children: [stuck, gone]),
          );

          expect(gone.deleted, isTrue);
          expect(deleted, equals(1));
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
