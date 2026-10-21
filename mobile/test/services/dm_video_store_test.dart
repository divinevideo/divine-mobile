// ABOUTME: Tests for DmVideoStore: one download per received video DM, a kept
// ABOUTME: preview frame, pruning by age and size, and per-account folders.

import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart';
import 'package:openvine/services/dm_video_decryptor.dart';
import 'package:openvine/services/dm_video_frame_read_marks.dart';
import 'package:openvine/services/dm_video_store.dart';
import 'package:path_provider/path_provider.dart'
    show MissingPlatformDirectoryException;
import 'package:unified_logger/unified_logger.dart';

final String _owner = 'e' * 64;
final Uint8List _plaintext = Uint8List.fromList(
  List<int>.generate(64, (i) => i),
);
final Uint8List _frame = Uint8List.fromList(const [0xFF, 0xD8, 0xFF, 0xE0]);

DmMessage _videoMessage({
  String? id,
  String conversationId = 'conversation',
  String fileType = 'video/mp4',
  int? fileSize,
  String? senderPubkey,
}) => DmMessage(
  id: id ?? 'a' * 64,
  conversationId: conversationId,
  senderPubkey: senderPubkey ?? 'b' * 64,
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

  FileSystemException get _denied => FileSystemException(
    'Directory listing failed',
    path,
    const OSError('Permission denied', 13),
  );

  @override
  Stream<FileSystemEntity> list({
    bool recursive = false,
    bool followLinks = true,
  }) => Stream.error(_denied);

  @override
  List<FileSystemEntity> listSync({
    bool recursive = false,
    bool followLinks = true,
  }) => throw _denied;

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

class _WriteHookFile implements File {
  _WriteHookFile(this.file, this.beforeWrite);

  final File file;
  final void Function(File) beforeWrite;

  @override
  String get path => file.path;

  @override
  Directory get parent => file.parent;

  @override
  Future<File> writeAsBytes(
    List<int> bytes, {
    FileMode mode = FileMode.write,
    bool flush = false,
  }) {
    beforeWrite(this);
    return file.writeAsBytes(bytes, mode: mode, flush: flush);
  }

  @override
  Future<File> create({bool recursive = false, bool exclusive = false}) {
    beforeWrite(this);
    return file.create(recursive: recursive, exclusive: exclusive);
  }

  @override
  Future<File> rename(String newPath) => file.rename(newPath);

  @override
  bool existsSync() => file.existsSync();

  @override
  Future<FileSystemEntity> delete({bool recursive = false}) =>
      file.delete(recursive: recursive);

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _WriteHooks extends IOOverrides {
  _WriteHooks(this.beforeWrite);

  final void Function(File) beforeWrite;

  @override
  File createFile(String path) {
    final file = super.createFile(path);
    return path.endsWith('.part') || path.endsWith('.failed')
        ? _WriteHookFile(file, beforeWrite)
        : file;
  }
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
    late List<bool Function()?> fetchLimitsApply;
    late int frameReads;
    late Future<Uint8List> Function(DmMessage message) fetch;
    late Future<Uint8List?> Function(File video) readFrame;

    setUp(() {
      root = Directory.systemTemp.createTempSync('dm_video_store_');
      now = DateTime(2026, 10, 20, 12);
      fetches = 0;
      fetchLimits = [];
      fetchWanted = [];
      fetchLimitsApply = [];
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
      Future<bool> Function(String conversationId, int sentAt)?
      isConversationRemoved,
      Future<DmVideoMessageLocation?> Function(String messageId)?
      findMessageLocation,
      Future<Directory> Function()? rootDirectory,
      // Not the default minute: a decode a test leaves running would log a
      // turn-limit warning into a later suite of the merged test isolate.
      Duration frameTurnLimit = const Duration(days: 1),
      Duration frameDeadline = DmVideoStore.defaultFrameDeadline,
      String? launchId,
    }) => DmVideoStore(
      ownerPubkey: _owner,
      fetchVideo: (message, {maxBytes, timeLimit, limitsApply, stillWanted}) {
        fetches++;
        fetchLimits.add((maxBytes: maxBytes, timeLimit: timeLimit));
        fetchLimitsApply.add(limitsApply);
        fetchWanted.add(stillWanted);
        return fetch(message);
      },
      readFrame: (video) {
        frameReads++;
        return readFrame(video);
      },
      rootDirectory: rootDirectory ?? () async => root,
      now: () => now,
      maxBytes: maxBytes,
      isMessageGone: isMessageGone,
      isConversationRemoved: isConversationRemoved,
      findMessageLocation: findMessageLocation,
      frameTurnLimit: frameTurnLimit,
      frameDeadline: frameDeadline,
      launchId: launchId,
    );

    Directory ownerDir([String? owner]) =>
        Directory('${root.path}/${DmVideoStore.dirName}/${owner ?? _owner}');

    File keptFile(String name, List<int> bytes, {required DateTime keptAt}) =>
        File('${ownerDir().path}/$name')
          ..createSync(recursive: true)
          ..writeAsBytesSync(bytes)
          ..setLastModifiedSync(keptAt);

    /// Everything kept for the account, none when nothing ever was.
    List<File> keptFiles() => ownerDir().existsSync()
        ? ownerDir().listSync().whereType<File>().toList()
        : const [];

    group('videoFor', () {
      test(
        'fetches again a kept video past its age that nothing uses, rather '
        'than hand it out',
        () async {
          final store = createStore();
          final message = _videoMessage();
          final first = await store.videoFor(message);
          store.releaseVideo(first);
          expect(fetches, equals(1));
          first.setLastModifiedSync(now.subtract(const Duration(days: 31)));

          final again = await store.videoFor(message);

          expect(fetches, equals(2));
          expect(again.readAsBytesSync(), equals(_plaintext));
        },
      );

      test(
        'hands out a video past its age while its frame is being read',
        () async {
          final reading = Completer<void>();
          final read = Completer<Uint8List?>();
          readFrame = (_) {
            reading.complete();
            return read.future;
          };
          final store = createStore();
          final message = _videoMessage();
          final preview = store.previewFor(message);
          await reading.future;
          final video = File(
            '${ownerDir().path}/${DmVideoStore.videoFileNameFor(message)}',
          )..setLastModifiedSync(now.subtract(const Duration(days: 31)));

          final tapped = await store.videoFor(message);

          expect(fetches, equals(1));
          expect(tapped.path, equals(video.path));
          expect(video.existsSync(), isTrue);
          read.complete(_frame);
          await preview;
        },
      );

      test(
        'hands out a video past its age that a caller still holds',
        () async {
          final store = createStore();
          final message = _videoMessage();
          final held = await store.videoFor(message);
          held.setLastModifiedSync(now.subtract(const Duration(days: 31)));

          final again = await store.videoFor(message);

          expect(fetches, equals(1));
          expect(again.path, equals(held.path));
        },
      );

      test('refuses a retracted video without fetching it', () async {
        final store = createStore(isMessageGone: (_) async => true);

        await expectLater(
          store.videoFor(_videoMessage()),
          throwsA(isA<DmVideoGoneException>()),
        );
        expect(fetches, equals(0));
        expect(keptFiles(), isEmpty);
      });

      test(
        'refuses a kept video once its conversation was removed',
        () async {
          var removed = false;
          final store = createStore(
            isConversationRemoved: (_, _) async => removed,
          );
          final message = _videoMessage();
          store.releaseVideo(await store.videoFor(message));
          expect(fetches, equals(1));
          removed = true;

          await expectLater(
            store.videoFor(message),
            throwsA(isA<DmVideoGoneException>()),
          );
          expect(fetches, equals(1));
        },
      );

      test(
        'refuses, and keeps, a video when it cannot tell whether its message '
        'is gone',
        () async {
          var lookupFails = false;
          final store = createStore(
            isMessageGone: (_) async =>
                lookupFails ? throw StateError('database closed') : false,
          );
          final message = _videoMessage();
          store.releaseVideo(await store.videoFor(message));
          lookupFails = true;
          await LogCaptureService().clearAllLogs();

          await expectLater(
            store.videoFor(message),
            throwsA(
              isA<DmVideoUnavailableException>().having(
                (error) => error.mayPass,
                'mayPass',
                isTrue,
              ),
            ),
          );

          expect(keptFiles(), isNotEmpty);
          expect(
            _loggedLines(),
            contains(contains('so its video is not handed out: StateError')),
          );
        },
      );

      test(
        'deletes what is kept for a message it refuses as gone',
        () async {
          var gone = false;
          final store = createStore(isMessageGone: (_) async => gone);
          final message = _videoMessage();
          store.releaseVideo(await store.videoFor(message));
          expect(keptFiles(), isNotEmpty);
          gone = true;

          await expectLater(
            store.videoFor(message),
            throwsA(isA<DmVideoGoneException>()),
          );

          expect(keptFiles(), isEmpty);
        },
      );

      test(
        'keeps no video whose message went while it downloaded',
        () async {
          final release = Completer<Uint8List>();
          fetch = (_) => release.future;
          var gone = false;
          var videoWrites = 0;
          final message = _videoMessage();

          await IOOverrides.runWithIOOverrides(
            () async {
              final store = createStore(isMessageGone: (_) async => gone);
              final tapped = store.videoFor(message);
              await pumpEventQueue();
              gone = true;
              release.complete(_plaintext);

              await expectLater(
                tapped,
                throwsA(isA<DmVideoGoneException>()),
              );
            },
            _WriteHooks((part) {
              if (part.path.contains(DmVideoStore.videoFileNameFor(message))) {
                videoWrites++;
              }
            }),
          );

          expect(videoWrites, equals(0));
        },
      );

      test(
        "refuses a card's download it took over once its message is gone",
        () async {
          final release = Completer<Uint8List>();
          fetch = (_) => release.future;
          var gone = false;
          final message = _videoMessage();

          await IOOverrides.runWithIOOverrides(
            () async {
              final store = createStore(isMessageGone: (_) async => gone);
              var cardShown = true;
              final preview = store.previewFor(
                message,
                stillWanted: () => cardShown,
              );
              await pumpEventQueue();
              final tapped = store.videoFor(message);
              // The tap keeps the download going; the card decodes nothing.
              cardShown = false;
              release.complete(_plaintext);

              await expectLater(
                tapped,
                throwsA(isA<DmVideoGoneException>()),
              );
              expect(fetches, equals(1));
              expect(await preview, isNull);
              // Deleted once the card let go too, without waiting on a prune.
              expect(keptFiles(), isEmpty);
            },
            _WriteHooks((part) {
              // Retracted once the card's download had asked, as it stores.
              if (part.path.contains(DmVideoStore.videoFileNameFor(message))) {
                gone = true;
              }
            }),
          );
        },
      );

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
      test(
        'reads a new frame once its frame is past its age, though its video '
        'is not',
        () async {
          final store = createStore();
          final message = _videoMessage();
          final frame = await store.previewFor(message);
          frame!.setLastModifiedSync(now.subtract(const Duration(days: 31)));

          final again = await store.previewFor(message);

          expect(again, isNotNull);
          expect(frameReads, equals(2));
          expect(fetches, equals(1));
        },
      );

      test(
        'reads no frame from a video past its age that a caller holds, and '
        'leaves it',
        () async {
          final store = createStore();
          final message = _videoMessage();
          final held = await store.videoFor(message);
          held.setLastModifiedSync(now.subtract(const Duration(days: 31)));

          final preview = await store.previewFor(message);

          expect(preview, isNull);
          expect(held.existsSync(), isTrue);
          expect(frameReads, equals(0));
        },
      );

      test(
        'shows no frame past its age, and reads one again from the video '
        'fetched again',
        () async {
          final store = createStore();
          final message = _videoMessage();
          await store.previewFor(message);
          for (final kept in keptFiles()) {
            kept.setLastModifiedSync(now.subtract(const Duration(days: 31)));
          }
          expect(fetches, equals(1));

          expect(store.knownPreviewPathFor(message), isNull);
          final preview = await store.previewFor(message);

          expect(preview!.readAsBytesSync(), equals(_frame));
          expect(fetches, equals(2));
          expect(frameReads, equals(2));
        },
      );

      test('grabs one frame from the video and keeps it', () async {
        final store = createStore();
        final message = _videoMessage();

        final first = await store.previewFor(message);
        final second = await store.previewFor(message);

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

        final first = store.previewFor(message);
        final second = store.previewFor(message);
        await pumpEventQueue();
        frameRead.complete(_frame);

        expect((await first)!.readAsBytesSync(), equals(_frame));
        expect((await second)!.readAsBytesSync(), equals(_frame));
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
          unawaited(createStore().previewFor(message));
          await readStarted.future;
          expect(frameReads, equals(1));

          readFrame = (_) async => _frame;
          final afterRestart = createStore();

          expect(
            await afterRestart.previewFor(message),
            isNull,
          );
          expect(frameReads, equals(1));
        },
      );

      group('after a frame read an earlier launch never finished', () {
        late Completer<void> readStarted;

        /// Starts a frame read of [message] that never finishes, as when the
        /// decoder crashed the app, in a store of an earlier launch unless
        /// [store] is given, and returns once it runs.
        Future<void> leaveHungRead(
          DmMessage message, {
          DmVideoStore? store,
        }) async {
          readStarted = Completer<void>();
          readFrame = (_) {
            readStarted.complete();
            return Completer<Uint8List?>().future;
          };
          unawaited(
            (store ?? createStore(launchId: 'earlier')).previewFor(message),
          );
          await readStarted.future;
          readFrame = (_) async => _frame;
        }

        test(
          "neither fetches nor reads that sender's other videos by itself, "
          'while a tap still plays them',
          () async {
            await leaveHungRead(_videoMessage(id: '1' * 64));
            final later = createStore();
            final other = _videoMessage(id: '2' * 64);

            expect(await later.previewFor(other), isNull);
            expect(fetches, equals(1));

            expect(
              (await later.videoFor(other)).readAsBytesSync(),
              equals(_plaintext),
            );
            expect(await later.previewFor(other), isNull);
            expect(frameReads, equals(1));
          },
        );

        test(
          'remembers that sender even when the message is pruned as gone '
          'before any card asks for a frame',
          () async {
            await leaveHungRead(_videoMessage(id: '1' * 64));
            final later = createStore(
              isMessageGone: (id) async => id == '1' * 64,
            );
            await later.prune();

            expect(await later.previewFor(_videoMessage(id: '2' * 64)), isNull);
            expect(fetches, equals(1));
            expect(frameReads, equals(1));
          },
        );

        test("still reads other senders' videos", () async {
          await leaveHungRead(_videoMessage(id: '1' * 64));

          final preview = await createStore().previewFor(
            _videoMessage(id: '2' * 64, senderPubkey: '9' * 64),
          );

          expect(preview, isNotNull);
          expect(frameReads, equals(2));
        });

        test(
          "reads that sender's videos again once it is 30 days old",
          () async {
            // Left on disk as by a launch that crashed reading it, with no
            // store of that launch left to read it on.
            final crashed = _videoMessage(id: '1' * 64);
            keptFile(
              DmVideoStore.videoFileNameFor(crashed),
              _plaintext,
              keptAt: now,
            );
            DmVideoFrameReadMarks(
              ownerRemoved: () => false,
              launchId: 'earlier',
            ).readStarted(
              DmVideoFrameReadMarks.readMarkOf(ownerDir(), crashed.id),
              crashed.senderPubkey,
            );
            await createStore().previewFor(_videoMessage(id: '2' * 64));
            for (final file in keptFiles()) {
              file.setLastModifiedSync(now.subtract(const Duration(days: 31)));
            }
            await createStore().prune();

            final preview = await createStore().previewFor(
              _videoMessage(id: '3' * 64),
            );

            expect(preview, isNotNull);
            expect(frameReads, equals(1));
          },
        );

        test(
          'keeps what it remembers of that sender while trimming for the cap',
          () async {
            await leaveHungRead(_videoMessage(id: '1' * 64));
            await createStore().previewFor(_videoMessage(id: '2' * 64));
            for (final file in keptFiles()) {
              file.setLastModifiedSync(now.subtract(const Duration(hours: 2)));
            }
            keptFile(
              '${'3' * 64}.mp4',
              const [1, 2, 3, 4],
              keptAt: now.subtract(const Duration(hours: 1)),
            );
            await createStore(maxBytes: 2).prune();

            expect(
              await createStore().previewFor(_videoMessage(id: '4' * 64)),
              isNull,
            );
            expect(frameReads, equals(1));
          },
        );

        test(
          'still blames the sender of a read that hung past its turn, '
          'though the app went to the background after',
          () async {
            final earlier = createStore(
              launchId: 'earlier',
              frameTurnLimit: const Duration(milliseconds: 1),
            );
            await leaveHungRead(_videoMessage(id: '1' * 64), store: earlier);
            // The next read starts only once the hung one used up its turn.
            final nextStarted = Completer<void>();
            readFrame = (_) async {
              nextStarted.complete();
              return _frame;
            };
            final next = earlier.previewFor(
              _videoMessage(id: '2' * 64, senderPubkey: '9' * 64),
            );
            await nextStarted.future;
            await next;

            earlier.appInForeground = false;
            final preview = await createStore().previewFor(
              _videoMessage(id: '3' * 64),
            );

            expect(preview, isNull);
            expect(frameReads, equals(2));
          },
        );

        test(
          'blames no sender for a read under way in a store replaced since, '
          'which no longer hears when the app goes to the background',
          () async {
            final earlier = createStore(launchId: 'earlier');
            await leaveHungRead(_videoMessage(id: '1' * 64), store: earlier);

            await earlier.dispose();
            final preview = await createStore().previewFor(
              _videoMessage(id: '2' * 64),
            );

            expect(preview, isNotNull);
            expect(frameReads, equals(2));
          },
        );

        test(
          'blames no sender for a read under way while the app was in the '
          'background, where the system kills apps',
          () async {
            final earlier = createStore(launchId: 'earlier');
            await leaveHungRead(_videoMessage(id: '1' * 64), store: earlier);

            earlier.appInForeground = false;
            final preview = await createStore().previewFor(
              _videoMessage(id: '2' * 64),
            );

            expect(preview, isNotNull);
            expect(frameReads, equals(2));
          },
        );

        test(
          'takes no read still running in another store of the account for '
          'one an earlier launch left',
          () async {
            await leaveHungRead(
              _videoMessage(id: '1' * 64),
              store: createStore(),
            );

            final preview = await createStore().previewFor(
              _videoMessage(id: '2' * 64),
            );

            expect(preview, isNotNull);
            expect(frameReads, equals(2));
          },
        );
      });

      group("after a sender's frame read finished without a frame", () {
        test("still reads that sender's other videos", () async {
          readFrame = (_) async => null;
          expect(
            await createStore(
              launchId: 'earlier',
            ).previewFor(_videoMessage(id: '1' * 64)),
            isNull,
          );
          readFrame = (_) async => _frame;

          final preview = await createStore().previewFor(
            _videoMessage(id: '2' * 64),
          );

          expect(preview, isNotNull);
          expect(frameReads, equals(2));
        });

        test(
          "still reads that sender's other videos when the read failed",
          () async {
            readFrame = (_) async => throw StateError('decoder failed');
            await expectLater(
              createStore(
                launchId: 'earlier',
              ).previewFor(_videoMessage(id: '1' * 64)),
              throwsStateError,
            );
            readFrame = (_) async => _frame;

            final preview = await createStore().previewFor(
              _videoMessage(id: '2' * 64),
            );

            expect(preview, isNotNull);
            expect(frameReads, equals(2));
          },
        );
      });

      test(
        'reads the frame from a video already kept, without fetching it again',
        () async {
          final store = createStore();
          final message = _videoMessage();
          await store.videoFor(message);

          final preview = await store.previewFor(message);

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

          final preview = await store.previewFor(message);

          expect(store.knownPreviewPathFor(message), equals(preview!.path));
        },
      );

      test(
        'forgets a frame the system cleared, so no card starts from it',
        () async {
          final store = createStore();
          final message = _videoMessage();
          final preview = await store.previewFor(message);
          expect(store.knownPreviewPathFor(message), equals(preview!.path));

          preview.deleteSync();

          expect(store.knownPreviewPathFor(message), isNull);
        },
      );

      test(
        'deletes a frame 30 days after it was kept, however recently a card '
        'showed it',
        () async {
          final message = _videoMessage();
          final frame = keptFile(
            '${message.id}.preview.jpg',
            _frame,
            keptAt: now.subtract(const Duration(days: 29)),
          );
          expect(await createStore().previewFor(message), isNotNull);
          now = now.add(const Duration(days: 2));

          await createStore().prune();

          expect(frame.existsSync(), isFalse);
        },
      );

      test(
        'remembers a frame an earlier session kept once it finds it',
        () async {
          final message = _videoMessage();
          final kept = await createStore().previewFor(message);
          final store = createStore();
          expect(store.knownPreviewPathFor(message), isNull);

          await store.previewFor(message);

          expect(store.knownPreviewPathFor(message), equals(kept!.path));
        },
      );

      test(
        'never tries again a frame that could not be read, even in a later '
        'session: the reader gives up while the decoder may still run',
        () async {
          readFrame = (_) async => null;
          final message = _videoMessage();
          final store = createStore();

          await store.previewFor(message);
          await store.previewFor(message);
          expect(frameReads, equals(1));

          expect(
            await createStore().previewFor(message),
            isNull,
          );
          expect(frameReads, equals(1));
        },
      );

      test(
        'reads one frame at a time, so a crash marks only its video',
        () async {
          final reads = <Completer<Uint8List?>>[];
          readFrame = (_) {
            final read = Completer<Uint8List?>();
            reads.add(read);
            return read.future;
          };
          final store = createStore();
          final first = _videoMessage(id: '1' * 64);
          final second = _videoMessage(id: '2' * 64);
          await store.videoFor(first);
          await store.videoFor(second);

          final firstFrame = store.previewFor(first);
          final secondFrame = store.previewFor(second);
          await pumpEventQueue();
          expect(reads, hasLength(1));

          reads.single.complete(_frame);
          expect(await firstFrame, isNotNull);
          await pumpEventQueue();
          expect(reads, hasLength(2));

          reads.last.complete(_frame);
          expect(await secondFrame, isNotNull);
        },
      );

      test(
        'lets the next frame read start once a decode has run for the turn '
        'limit, keeping its video leased until it returns',
        () async {
          final firstDecode = Completer<Uint8List?>();
          final secondReadStarted = Completer<void>();
          final first = _videoMessage(id: '1' * 64);
          // Another sender's: the first one's are skipped once it hangs.
          final second = _videoMessage(id: '2' * 64, senderPubkey: '9' * 64);
          readFrame = (video) {
            if (video.path.contains(first.id)) return firstDecode.future;
            secondReadStarted.complete();
            return Future.value(_frame);
          };
          var firstGone = false;
          final store = createStore(
            frameTurnLimit: const Duration(milliseconds: 1),
            frameDeadline: const Duration(milliseconds: 1),
            isMessageGone: (id) async => firstGone && id == first.id,
          );
          final firstVideo = keptFile(
            DmVideoStore.videoFileNameFor(first),
            _plaintext,
            keptAt: now,
          );
          keptFile(
            DmVideoStore.videoFileNameFor(second),
            _plaintext,
            keptAt: now,
          );

          expect(await store.previewFor(first), isNull);
          final secondKept = store.kept.firstWhere((id) => id == second.id);
          final secondFrame = store.previewFor(second);
          await secondReadStarted.future.timeout(const Duration(seconds: 5));
          // The card's 1 ms wait can end before the frame is written; the
          // store announces the frame once it is.
          await secondKept.timeout(
            const Duration(seconds: 5),
            onTimeout: () => fail('the second frame was never kept'),
          );
          await secondFrame;

          firstGone = true;
          await store.prune();
          expect(firstVideo.existsSync(), isTrue);

          firstDecode.complete();
          await pumpEventQueue();
          await store.prune();
          expect(firstVideo.existsSync(), isFalse);
        },
      );

      test(
        'neither fetches nor reads by itself, for the rest of the session, '
        'the videos of a sender one of whose decodes ran past the turn limit',
        () async {
          final hung = _videoMessage(id: '1' * 64);
          final nextStarted = Completer<void>();
          readFrame = (video) {
            if (video.path.contains(hung.id)) {
              return Completer<Uint8List?>().future;
            }
            nextStarted.complete();
            return Future.value(_frame);
          };
          final store = createStore(
            frameTurnLimit: const Duration(milliseconds: 1),
            frameDeadline: const Duration(milliseconds: 1),
          );
          expect(await store.previewFor(hung), isNull);
          // The next read starts only once the hung one used up its turn.
          final next = store.previewFor(
            _videoMessage(id: '2' * 64, senderPubkey: '9' * 64),
          );
          await nextStarted.future.timeout(const Duration(seconds: 5));
          await next;

          final preview = await store.previewFor(_videoMessage(id: '3' * 64));

          expect(preview, isNull);
          expect(fetches, equals(2));
          expect(frameReads, equals(2));
        },
      );

      test(
        'keeps a frame that arrives after its card stopped waiting, and says '
        'so, so the card shows it without another decode',
        () async {
          final decode = Completer<Uint8List?>();
          readFrame = (_) => decode.future;
          final message = _videoMessage();
          keptFile(
            DmVideoStore.videoFileNameFor(message),
            _plaintext,
            keptAt: now,
          );
          final store = createStore(
            frameDeadline: const Duration(milliseconds: 1),
          );
          final announced = <String>[];
          final subscription = store.kept.listen(announced.add);
          addTearDown(subscription.cancel);

          expect(await store.previewFor(message), isNull);
          expect(announced, isEmpty);

          final lateFrame = store.kept.firstWhere((id) => id == message.id);
          decode.complete(_frame);
          await lateFrame.timeout(
            const Duration(seconds: 5),
            onTimeout: () => fail('the late frame was never announced'),
          );

          expect(announced, equals([message.id]));
          expect(await store.previewFor(message), isNotNull);
          expect(frameReads, equals(1));
        },
      );

      test(
        'skips a queued frame read once no card waiting for it wants it',
        () async {
          final firstRead = Completer<Uint8List?>();
          var reads = 0;
          readFrame = (_) {
            reads++;
            return reads == 1 ? firstRead.future : Future.value(_frame);
          };
          final store = createStore();
          final first = _videoMessage(id: '1' * 64);
          final second = _videoMessage(id: '2' * 64);
          await store.videoFor(first);
          await store.videoFor(second);
          var secondWanted = true;

          final firstFrame = store.previewFor(first);
          final secondFrame = store.previewFor(
            second,
            stillWanted: () => secondWanted,
          );
          await pumpEventQueue();
          expect(reads, equals(1));
          secondWanted = false;
          firstRead.complete(_frame);

          expect(await firstFrame, isNotNull);
          expect(await secondFrame, isNull);
          expect(reads, equals(1));
          expect(
            ownerDir()
                .listSync()
                .map((entity) => entity.path)
                .where(
                  (path) =>
                      path.contains('2' * 64) &&
                      (path.endsWith('.jpg') ||
                          path.endsWith('.frame-attempt')),
                ),
            isEmpty,
          );
        },
      );

      test(
        'still reads a queued frame that another card waiting for it wants',
        () async {
          final firstRead = Completer<Uint8List?>();
          var reads = 0;
          readFrame = (_) {
            reads++;
            return reads == 1 ? firstRead.future : Future.value(_frame);
          };
          final store = createStore();
          final first = _videoMessage(id: '1' * 64);
          final shared = _videoMessage(id: '2' * 64);
          await store.videoFor(first);
          await store.videoFor(shared);
          var closedCardWanted = true;

          final firstFrame = store.previewFor(first);
          final closedCard = store.previewFor(
            shared,
            stillWanted: () => closedCardWanted,
          );
          final openCard = store.previewFor(shared);
          await pumpEventQueue();
          closedCardWanted = false;
          firstRead.complete(_frame);

          expect(await firstFrame, isNotNull);
          expect(await openCard, isNotNull);
          expect(reads, equals(2));
          await closedCard;
        },
      );

      test(
        'keeps the mark of a frame that could not be read for as long as its '
        'video stays',
        () async {
          readFrame = (_) async => null;
          final message = _videoMessage();
          final store = createStore();
          expect(await store.previewFor(message), isNull);
          // Held, as on a play page, past its age.
          final held = await store.videoFor(message);
          held.setLastModifiedSync(now.subtract(const Duration(days: 31)));

          await store.prune();

          expect(
            File(
              '${ownerDir().path}/${DmVideoStore.videoFileNameFor(message)}',
            ).existsSync(),
            isTrue,
          );
          expect(
            File('${ownerDir().path}/${message.id}.frame-attempt').existsSync(),
            isTrue,
          );
        },
      );

      test('clears the mark once its video is gone', () async {
        readFrame = (_) async => null;
        final message = _videoMessage();
        final store = createStore();
        expect(await store.previewFor(message), isNull);
        File(
          '${ownerDir().path}/${DmVideoStore.videoFileNameFor(message)}',
        ).deleteSync();

        await store.prune();

        readFrame = (_) async => _frame;
        expect(
          await createStore().previewFor(message),
          isNotNull,
        );
      });

      test('keeps no frame when none can be read', () async {
        readFrame = (_) async => null;
        final store = createStore();
        final message = _videoMessage();

        final preview = await store.previewFor(message);

        expect(preview, isNull);
        expect(
          File('${ownerDir().path}/${'a' * 64}.mp4').existsSync(),
          isTrue,
        );
        expect(
          ownerDir().listSync().where((entity) => entity.path.endsWith('.jpg')),
          isEmpty,
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

        final firstPreview = store.previewFor(_videoMessage());
        final secondPreview = store.previewFor(
          _videoMessage(id: '9' * 64),
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

          final preview = store.previewFor(message);
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
            store.previewFor(message),
            throwsA(isA<DmVideoUnavailableException>()),
          );
          await pumpEventQueue();
          final tapped = store.videoFor(message);
          release.completeError(
            const DmVideoLimitException('ciphertext exceeds the size limit'),
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
        'leave a tap with a failure the download it took over would hit '
        'again',
        () async {
          final release = Completer<Uint8List>();
          fetch = (_) => release.future;
          final store = createStore();
          final message = _videoMessage();

          final previewFailure = expectLater(
            store.previewFor(message),
            throwsA(isA<DmVideoUnavailableException>()),
          );
          await pumpEventQueue();
          final tapped = store.videoFor(message);
          release.completeError(
            const DmVideoUnavailableException(
              'ciphertext hash does not match the x tag',
            ),
          );

          await expectLater(
            tapped,
            throwsA(
              isA<DmVideoUnavailableException>().having(
                (e) => e.message,
                'message',
                contains('hash'),
              ),
            ),
          );
          expect(fetches, equals(1));
          await previewFailure;
        },
      );

      test(
        'leave a tap with a failure to store the download it took over',
        () async {
          final release = Completer<Uint8List>();
          fetch = (_) => release.future;
          final store = createStore();
          final message = _videoMessage();
          // A folder where the video goes makes storing it fail.
          Directory(
            '${ownerDir().path}/${DmVideoStore.videoFileNameFor(message)}/x',
          ).createSync(recursive: true);

          final previewFailure = expectLater(
            store.previewFor(message),
            throwsA(isA<DmVideoStorageException>()),
          );
          await pumpEventQueue();
          final tapped = store.videoFor(message);
          release.complete(_plaintext);

          await expectLater(tapped, throwsA(isA<DmVideoStorageException>()));
          expect(fetches, equals(1));
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
          final preview = store.previewFor(message);
          await pumpEventQueue();
          release.complete(_plaintext);

          expect(await preview, isNotNull);
          expect((await tapped).readAsBytesSync(), equals(_plaintext));
          expect(fetches, equals(1));
        },
      );

      test(
        "let other cards download while one waits on a tap's download",
        () async {
          final tapRelease = Completer<Uint8List>();
          final tappedMessage = _videoMessage(id: '1' * 64);
          final other = _videoMessage(id: '2' * 64);
          final fetchedIds = <String>[];
          fetch = (message) {
            fetchedIds.add(message.id);
            return message.id == tappedMessage.id
                ? tapRelease.future
                : Future.value(_plaintext);
          };
          final store = createStore();
          final tapped = store.videoFor(tappedMessage);
          await pumpEventQueue();

          final waiting = store.previewFor(tappedMessage);
          final otherPreview = store.previewFor(other);
          await pumpEventQueue();
          expect(fetchedIds, contains(other.id));
          expect(await otherPreview, isNotNull);

          tapRelease.complete(_plaintext);
          await tapped;
          expect(await waiting, isNotNull);
        },
      );

      test('lift their limits once a tap waits for the same video', () async {
        final release = Completer<Uint8List>();
        fetch = (_) => release.future;
        final store = createStore();
        final message = _videoMessage();

        final preview = store.previewFor(message);
        await pumpEventQueue();
        final limitsApply = fetchLimitsApply.single!;
        expect(limitsApply(), isTrue);

        final tapped = store.videoFor(message);
        expect(limitsApply(), isFalse);

        release.complete(_plaintext);
        expect((await tapped).readAsBytesSync(), equals(_plaintext));
        expect(await preview, isNotNull);
        expect(fetches, equals(1));
      });

      test(
        'let other cards download once a tap takes over a running download',
        () async {
          final release = Completer<Uint8List>();
          final joined = _videoMessage(id: '1' * 64);
          final other = _videoMessage(id: '2' * 64);
          final fetchedIds = <String>[];
          fetch = (message) {
            fetchedIds.add(message.id);
            return message.id == joined.id
                ? release.future
                : Future.value(_plaintext);
          };
          final store = createStore();
          final joinedPreview = store.previewFor(joined);
          final otherPreview = store.previewFor(other);
          await pumpEventQueue();
          expect(fetchedIds, equals([joined.id]));

          final tapped = store.videoFor(joined);
          await pumpEventQueue();
          expect(fetchedIds, equals([joined.id, other.id]));
          expect(await otherPreview, isNotNull);

          release.complete(_plaintext);
          await tapped;
          expect(await joinedPreview, isNotNull);
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
        );
        final queuedPreview = store.previewFor(queued);
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
          store.previewFor(message),
          throwsA(isA<DmVideoUnavailableException>()),
        );
        now = now.add(const Duration(days: 1));

        expect(await store.previewFor(message), isNull);
        expect(fetches, equals(1));
      });

      test(
        'are refused without a lasting failure once their message is gone',
        () async {
          final store = createStore(isMessageGone: (_) async => true);
          final message = _videoMessage();

          expect(await store.previewFor(message), isNull);

          expect(fetches, equals(0));
          expect(keptFiles(), isEmpty);
        },
      );

      test(
        'are not tried again after failing for good, even once no card waits',
        () async {
          final release = Completer<Uint8List>();
          fetch = (_) => release.future;
          final store = createStore();
          final message = _videoMessage();
          var wanted = true;
          final preview = store.previewFor(
            message,
            stillWanted: () => wanted,
          );
          await pumpEventQueue();
          wanted = false;
          release.completeError(
            const DmVideoUnavailableException(
              'ciphertext hash does not match the x tag',
            ),
          );
          expect(await preview, isNull);

          expect(await store.previewFor(message), isNull);
          expect(fetches, equals(1));
        },
      );

      test(
        'never hold a download stopped as unwanted against the next card',
        () async {
          fetch = (_) async => throw const DmVideoWithdrawnException();
          final store = createStore();
          final message = _videoMessage();
          expect(await store.previewFor(message), isNull);

          fetch = (_) async => _plaintext;

          expect(await store.previewFor(message), isNotNull);
          expect(fetches, equals(2));
        },
      );

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
            store.previewFor(message),
            throwsA(isA<DmVideoUnavailableException>()),
          );

          expect(await store.previewFor(message), isNull);
          expect(fetches, equals(1));

          now = now.add(DmVideoStore.autoDownloadRetryAfter);
          expect(await store.previewFor(message), isNotNull);
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
            store.previewFor(message),
            throwsA(isA<DmVideoUnavailableException>()),
          );

          expect(
            (await store.videoFor(message)).readAsBytesSync(),
            equals(_plaintext),
          );
          expect(await store.previewFor(message), isNotNull);
        },
      );

      test(
        'stop fetching a video by themselves after three failed tries this '
        'session, while a tap still fetches it',
        () async {
          fetch = (_) async => throw const DmVideoUnavailableException(
            'the download failed: connectionError',
            mayPass: true,
          );
          final store = createStore();
          final message = _videoMessage();
          for (
            var tries = 0;
            tries < DmVideoStore.autoDownloadMaxTries;
            tries++
          ) {
            await expectLater(
              store.previewFor(message),
              throwsA(isA<DmVideoUnavailableException>()),
            );
            now = now.add(DmVideoStore.autoDownloadRetryAfter);
          }
          expect(fetches, equals(3));

          expect(await store.previewFor(message), isNull);
          expect(fetches, equals(3));

          await expectLater(
            store.videoFor(message),
            throwsA(isA<DmVideoUnavailableException>()),
          );
          expect(fetches, equals(4));
        },
      );

      test(
        'are not tried in a later session after failing for good, while a tap '
        'still fetches it',
        () async {
          fetch = (_) async => throw const DmVideoUnavailableException(
            'the download failed: badResponse, HTTP 404',
          );
          final message = _videoMessage();
          await expectLater(
            createStore().previewFor(message),
            throwsA(isA<DmVideoUnavailableException>()),
          );
          expect(fetches, equals(1));

          final later = createStore();
          expect(await later.previewFor(message), isNull);
          expect(fetches, equals(1));

          fetch = (_) async => _plaintext;
          expect(
            (await later.videoFor(message)).readAsBytesSync(),
            equals(_plaintext),
          );
          expect(fetches, equals(2));
        },
      );

      test(
        'are tried again in a later session after a failure that may pass',
        () async {
          fetch = (_) async => fetches == 1
              ? throw const DmVideoUnavailableException(
                  'the download failed: connectionError',
                  mayPass: true,
                )
              : _plaintext;
          final message = _videoMessage();
          await expectLater(
            createStore().previewFor(message),
            throwsA(isA<DmVideoUnavailableException>()),
          );

          expect(await createStore().previewFor(message), isNotNull);
          expect(fetches, equals(2));
        },
      );

      test(
        'are tried again once a failure remembered from an earlier session is '
        '30 days old',
        () async {
          fetch = (_) async => fetches == 1
              ? throw const DmVideoUnavailableException(
                  'the download failed: badResponse, HTTP 404',
                )
              : _plaintext;
          final message = _videoMessage();
          await expectLater(
            createStore().previewFor(message),
            throwsA(isA<DmVideoUnavailableException>()),
          );
          for (final file in keptFiles()) {
            file.setLastModifiedSync(now.subtract(const Duration(days: 31)));
          }
          await createStore().prune();

          expect(await createStore().previewFor(message), isNotNull);
          expect(fetches, equals(2));
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

        final first = store.previewFor(_videoMessage());
        final dropped = store.previewFor(
          unwanted,
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

        final first = store.previewFor(_videoMessage());
        final closed = store.previewFor(
          shared,
          stillWanted: () => false,
        );
        final open = store.previewFor(
          shared,
          stillWanted: () => true,
        );
        await pumpEventQueue();
        blocking.complete(_plaintext);

        expect(await open, isNotNull);
        expect(await closed, isNotNull);
        expect(await first, isNotNull);
      });

      test(
        'keep nothing of a download nobody wants by the time it lands',
        () async {
          final release = Completer<Uint8List>();
          fetch = (_) => release.future;
          final store = createStore();
          final message = _videoMessage();
          var wanted = true;

          final preview = store.previewFor(
            message,
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
            isFalse,
          );
        },
      );

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

        await store.previewFor(_videoMessage());
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
        );

        expect(preview, isNull);
        expect(fetches, isZero);
      });
    });

    group('prune', () {
      test('deletes what was kept more than 30 days ago', () async {
        final stale = keptFile(
          'stale.mp4',
          const [1],
          keptAt: now.subtract(const Duration(days: 31)),
        );
        final recent = keptFile(
          'recent.mp4',
          const [1],
          keptAt: now.subtract(const Duration(days: 29)),
        );

        await createStore().prune();

        expect(stale.existsSync(), isFalse);
        expect(recent.existsSync(), isTrue);
      });

      test(
        'deletes a video 30 days after it was kept, however recently it was '
        'opened',
        () async {
          final message = _videoMessage();
          final video = keptFile(
            DmVideoStore.videoFileNameFor(message),
            _plaintext,
            keptAt: now.subtract(const Duration(days: 29)),
          );
          final player = createStore();
          player.releaseVideo(await player.videoFor(message));
          now = now.add(const Duration(days: 2));

          await createStore().prune();

          expect(video.existsSync(), isFalse);
        },
      );

      test(
        'deletes a frame with the video it was read from, however much later '
        'it was read',
        () async {
          final message = _videoMessage();
          final video = keptFile(
            DmVideoStore.videoFileNameFor(message),
            _plaintext,
            keptAt: now.subtract(const Duration(days: 10)),
          );
          final frame = await createStore().previewFor(message);
          expect(frame, isNotNull);
          now = now.add(const Duration(days: 21));

          await createStore().prune();

          expect(video.existsSync(), isFalse);
          expect(frame!.existsSync(), isFalse);
        },
      );

      test(
        'trims the oldest kept frame first while over the cap, however '
        'recently a card showed it',
        () async {
          final store = createStore(maxBytes: 8);
          final oldest = keptFile(
            '${'1' * 64}.preview.jpg',
            const [1, 2, 3, 4],
            keptAt: now.subtract(const Duration(hours: 3)),
          );
          final middle = keptFile(
            '${'2' * 64}.preview.jpg',
            const [1, 2, 3, 4],
            keptAt: now.subtract(const Duration(hours: 2)),
          );
          final newest = keptFile(
            '${'3' * 64}.preview.jpg',
            const [1, 2, 3, 4],
            keptAt: now.subtract(const Duration(hours: 1)),
          );
          expect(
            await store.previewFor(_videoMessage(id: '1' * 64)),
            isNotNull,
          );

          await store.prune();

          expect(oldest.existsSync(), isFalse);
          expect(middle.existsSync(), isTrue);
          expect(newest.existsSync(), isTrue);
        },
      );

      test(
        'leaves nothing of a gone message whose download failed for good',
        () async {
          fetch = (_) async => throw const DmVideoUnavailableException(
            'the download failed: badResponse, HTTP 404',
          );
          final message = _videoMessage();
          var gone = false;
          final store = createStore(isMessageGone: (_) async => gone);
          await expectLater(
            store.previewFor(message),
            throwsA(isA<DmVideoUnavailableException>()),
          );
          gone = true;

          await store.prune();

          expect(keptFiles(), isEmpty);
        },
      );

      test(
        'keeps what it remembers of a download that failed for good while '
        'trimming for the cap',
        () async {
          final failed = _videoMessage(id: '1' * 64);
          fetch = (_) async => throw const DmVideoUnavailableException(
            'the download failed: badResponse, HTTP 404',
          );
          await expectLater(
            createStore().previewFor(failed),
            throwsA(isA<DmVideoUnavailableException>()),
          );
          for (final file in keptFiles()) {
            file.setLastModifiedSync(now.subtract(const Duration(hours: 2)));
          }
          keptFile(
            '${'2' * 64}.mp4',
            const [1, 2, 3, 4],
            keptAt: now.subtract(const Duration(hours: 1)),
          );

          await createStore(maxBytes: 2).prune();

          expect(await createStore().previewFor(failed), isNull);
          expect(fetches, equals(1));
        },
      );

      test(
        "deletes an expired video's record and frame-read mark in the same "
        'prune',
        () async {
          final old = now.subtract(const Duration(days: 31));
          final video = keptFile('stale.mp4', const [1], keptAt: old);
          final frame = keptFile('stale.preview.jpg', const [1], keptAt: old);
          final record = keptFile(
            'stale.conversation',
            'conversation\n1757385263'.codeUnits,
            keptAt: now,
          );
          final mark = keptFile('stale.frame-attempt', const [], keptAt: now);

          await createStore().prune();

          expect(video.existsSync(), isFalse);
          expect(frame.existsSync(), isFalse);
          expect(record.existsSync(), isFalse);
          expect(mark.existsSync(), isFalse);
        },
      );

      test(
        'deletes the record of a video trimmed for the cap in the same prune',
        () async {
          final trimmed = keptFile(
            'oldest.mp4',
            const [1, 2, 3, 4],
            keptAt: now.subtract(const Duration(hours: 2)),
          );
          final record = keptFile(
            'oldest.conversation',
            'conversation\n1757385263'.codeUnits,
            keptAt: now,
          );
          final kept = keptFile(
            'newest.mp4',
            const [1, 2, 3, 4],
            keptAt: now.subtract(const Duration(hours: 1)),
          );

          await createStore(maxBytes: 4).prune();

          expect(trimmed.existsSync(), isFalse);
          expect(record.existsSync(), isFalse);
          expect(kept.existsSync(), isTrue);
        },
      );

      test(
        'deletes the oldest kept first while over the cap',
        () async {
          final oldest = keptFile(
            'oldest.mp4',
            const [1, 2, 3, 4],
            keptAt: now.subtract(const Duration(hours: 3)),
          );
          final middle = keptFile(
            'middle.mp4',
            const [1, 2, 3, 4],
            keptAt: now.subtract(const Duration(hours: 2)),
          );
          final newest = keptFile(
            'newest.mp4',
            const [1, 2, 3, 4],
            keptAt: now.subtract(const Duration(hours: 1)),
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
        final preview = await store.previewFor(message);
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
          unawaited(store.previewFor(message));
          await readStarted.future;

          await store.prune();

          readFrame = (_) async => _frame;
          expect(
            await createStore().previewFor(message),
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
          final goneFrame = await earlier.previewFor(gone);
          final shownFrame = await earlier.previewFor(shown);
          final goneVideo = File(
            '${ownerDir().path}/${DmVideoStore.videoFileNameFor(gone)}',
          );
          expect(goneVideo.existsSync(), isTrue);
          final store = createStore(
            isMessageGone: (messageId) async => messageId == gone.id,
          );
          expect(await store.previewFor(gone), isNotNull);

          await store.prune();

          expect(goneVideo.existsSync(), isFalse);
          expect(goneFrame!.existsSync(), isFalse);
          expect(shownFrame!.existsSync(), isTrue);
          expect(store.knownPreviewPathFor(gone), isNull);
        },
      );

      test(
        "deletes a gone message's video even after it was played: its sender "
        'took it back',
        () async {
          var gone = false;
          final store = createStore(isMessageGone: (_) async => gone);
          final played = await store.videoFor(_videoMessage());
          gone = true;

          await store.prune();

          expect(played.existsSync(), isFalse);
        },
      );

      test(
        "keeps a gone message's video while its frame is being read",
        () async {
          final readStarted = Completer<void>();
          readFrame = (_) {
            readStarted.complete();
            return Completer<Uint8List?>().future;
          };
          final message = _videoMessage();
          final video = keptFile(
            DmVideoStore.videoFileNameFor(message),
            _plaintext,
            keptAt: now,
          );
          final store = createStore(isMessageGone: (_) async => true);
          unawaited(store.previewFor(message));
          await readStarted.future;

          await store.prune();

          expect(video.existsSync(), isTrue);
        },
      );

      test(
        "deletes a gone message's video and frame once the read that held "
        'them ends, even when the message can no longer be looked up',
        () async {
          final read = Completer<Uint8List?>();
          final reading = Completer<void>();
          readFrame = (_) {
            reading.complete();
            return read.future;
          };
          final message = _videoMessage();
          final video = keptFile(
            DmVideoStore.videoFileNameFor(message),
            _plaintext,
            keptAt: now,
          );
          var gone = false;
          final store = createStore(isMessageGone: (_) async => gone);
          final preview = store.previewFor(message);
          await reading.future;
          gone = true;
          await store.prune();
          expect(video.existsSync(), isTrue);
          // Its row is cleared meanwhile, as an account switch does.
          gone = false;

          read.complete(_frame);
          await preview;
          await pumpEventQueue();

          expect(ownerDir().listSync(), isEmpty);
        },
      );

      test(
        "deletes a gone message's frame read while the prune looked the "
        'message up',
        () async {
          final read = Completer<Uint8List?>();
          final reading = Completer<void>();
          readFrame = (_) {
            reading.complete();
            return read.future;
          };
          final lookup = Completer<bool>();
          final lookingUp = Completer<void>();
          final message = _videoMessage();
          keptFile(
            DmVideoStore.videoFileNameFor(message),
            _plaintext,
            keptAt: now,
          );
          final store = createStore(
            isMessageGone: (_) {
              lookingUp.complete();
              return lookup.future;
            },
          );
          final preview = store.previewFor(message);
          await reading.future;

          final pruning = store.prune();
          await lookingUp.future;
          read.complete(_frame);
          expect(await preview, isNotNull);
          lookup.complete(true);
          await pruning;

          expect(ownerDir().listSync(), isEmpty);
        },
      );

      test(
        "keeps a gone message's video while a card reads the frame of a "
        "tap's download",
        () async {
          final release = Completer<Uint8List>();
          fetch = (_) => release.future;
          final readStarted = Completer<void>();
          readFrame = (_) {
            readStarted.complete();
            return Completer<Uint8List?>().future;
          };
          final message = _videoMessage();
          var gone = false;
          final store = createStore(isMessageGone: (_) async => gone);
          final tapped = store.videoFor(message);
          await pumpEventQueue();
          unawaited(store.previewFor(message));
          await pumpEventQueue();
          release.complete(_plaintext);
          final video = await tapped;
          await readStarted.future;
          gone = true;

          await store.prune();

          expect(video.existsSync(), isTrue);
        },
      );

      test("a tap takeover preserves the queued card's own lease", () async {
        final other = _videoMessage(id: '2' * 64);
        final message = _videoMessage();
        final download = Completer<Uint8List>();
        final blocker = Completer<Uint8List?>();
        final reading = Completer<void>();
        fetch = (asked) =>
            asked.id == message.id ? download.future : Future.value(_plaintext);
        readFrame = (video) {
          if (video.path.contains(other.id)) {
            reading.complete();
            return blocker.future;
          }
          return Future.value(_frame);
        };
        var gone = false;
        final store = createStore(
          isMessageGone: (id) async => gone && id == message.id,
        );
        final firstPreview = store.previewFor(other);
        await reading.future;
        final queuedPreview = store.previewFor(message);
        await pumpEventQueue();
        final tapped = store.videoFor(message);
        download.complete(_plaintext);
        final video = await tapped;
        await pumpEventQueue();
        gone = true;

        try {
          await store.prune();
          expect(video.existsSync(), isTrue);
        } finally {
          blocker.complete(_frame);
          await Future.wait([firstPreview, queuedPreview]);
        }
      });

      test(
        'deletes a kept video once its conversation is removed, with no row '
        'left to say so',
        () async {
          final removed = _videoMessage(id: '1' * 64, conversationId: 'gone');
          final shown = _videoMessage(id: '2' * 64, conversationId: 'shown');
          final asked = <(String, int)>[];
          var removedYet = false;
          final store = createStore(
            isMessageGone: (_) async => false,
            isConversationRemoved: (conversationId, sentAt) async {
              asked.add((conversationId, sentAt));
              return removedYet && conversationId == 'gone';
            },
          );
          await store.videoFor(removed);
          await store.videoFor(shown);
          removedYet = true;

          await store.prune();

          expect(asked, contains(('gone', removed.createdAt)));
          expect(
            ownerDir().listSync().where(
              (entity) => entity.path.contains('1' * 64),
            ),
            isEmpty,
          );
          expect(
            File(
              '${ownerDir().path}/${DmVideoStore.videoFileNameFor(shown)}',
            ).existsSync(),
            isTrue,
          );
        },
      );

      test(
        'logs nothing when a record is deleted while its message is looked '
        'up, as the launch sweep deletes an expired video',
        () async {
          keptFile('stale.mp4', const [1], keptAt: now);
          keptFile(
            'stale.conversation',
            'conversation\n1757385263'.codeUnits,
            keptAt: now,
          );
          final store = createStore(
            isMessageGone: (_) async {
              for (final file in ownerDir().listSync()) {
                file.deleteSync();
              }
              return false;
            },
            isConversationRemoved: (_, _) async => false,
          );
          await LogCaptureService().clearAllLogs();

          await store.prune();

          expect(ownerDir().listSync(), isEmpty);
          expect(_loggedLines(), isNot(contains(contains('is gone'))));
        },
      );

      test(
        "keeps a kept video's conversation record for as long as the video",
        () async {
          var removed = false;
          final store = createStore(
            isConversationRemoved: (_, _) async => removed,
          );
          await store.videoFor(_videoMessage());
          final record = File('${ownerDir().path}/${'a' * 64}.conversation');
          expect(record.existsSync(), isTrue);
          record.setLastModifiedSync(now.subtract(const Duration(days: 31)));

          await store.prune();
          removed = true;
          await store.prune();

          expect(ownerDir().listSync(), isEmpty);
        },
      );

      test(
        'keeps a conversation record while its video is still being written',
        () async {
          final record = keptFile(
            '${'a' * 64}.conversation',
            'conversation\n1757385263'.codeUnits,
            keptAt: now,
          );
          keptFile('${'a' * 64}.mp4.0.part', const [1], keptAt: now);

          await createStore().prune();

          expect(record.existsSync(), isTrue);
        },
      );

      test(
        'keeps a conversation record while its frame outlives its video',
        () async {
          var removed = false;
          final store = createStore(
            isConversationRemoved: (_, _) async => removed,
          );
          final message = _videoMessage();
          final frame = await store.previewFor(message);
          final video = File(
            '${ownerDir().path}/${DmVideoStore.videoFileNameFor(message)}',
          );
          frame!.setLastModifiedSync(now);
          video.setLastModifiedSync(now.subtract(const Duration(days: 31)));

          await store.prune();
          expect(video.existsSync(), isFalse);
          expect(frame.existsSync(), isTrue);
          // A pass that no longer lists the video either.
          await store.prune();
          removed = true;
          await store.prune();

          expect(ownerDir().listSync(), isEmpty);
        },
      );

      test(
        "deletes a gone message's video once the read that held it ends, even "
        'after it was handed to playback',
        () async {
          final read = Completer<Uint8List?>();
          final reading = Completer<void>();
          readFrame = (_) {
            reading.complete();
            return read.future;
          };
          final message = _videoMessage();
          var gone = false;
          final store = createStore(isMessageGone: (_) async => gone);
          final video = await store.videoFor(message);
          final preview = store.previewFor(message);
          await reading.future;
          gone = true;
          await store.prune();
          expect(video.existsSync(), isTrue);
          // Its row is cleared meanwhile, as an account switch does.
          gone = false;

          read.complete(_frame);
          await preview;
          await pumpEventQueue();

          expect(video.existsSync(), isFalse);
        },
      );

      test(
        "keeps a gone message's conversation record while a read holds its "
        'video, so a later launch can still tell, and deletes it with the '
        'video once the read ends',
        () async {
          final read = Completer<Uint8List?>();
          final reading = Completer<void>();
          readFrame = (_) {
            reading.complete();
            return read.future;
          };
          final message = _videoMessage();
          keptFile(
            DmVideoStore.videoFileNameFor(message),
            _plaintext,
            keptAt: now,
          );
          final record = keptFile(
            '${'a' * 64}.conversation',
            '${message.conversationId}\n${message.createdAt}'.codeUnits,
            keptAt: now,
          );
          var removed = false;
          final store = createStore(
            isMessageGone: (_) async => false,
            isConversationRemoved: (_, _) async => removed,
          );
          final preview = store.previewFor(message);
          await reading.future;
          removed = true;
          await store.prune();
          expect(record.existsSync(), isTrue);

          read.complete(_frame);
          await preview;
          await pumpEventQueue();

          expect(ownerDir().listSync(), isEmpty);
        },
      );

      test(
        "moves a kept video's record when a card shows its message in another "
        'conversation',
        () async {
          final store = createStore(
            isConversationRemoved: (conversationId, _) async =>
                conversationId == 'moved',
          );
          await store.videoFor(_videoMessage(conversationId: 'misfiled'));

          await store.previewFor(
            _videoMessage(conversationId: 'moved'),
          );
          await store.prune();

          expect(ownerDir().listSync(), isEmpty);
        },
      );

      test(
        "moves a kept frame's record when a card shows it from another "
        'conversation',
        () async {
          final store = createStore(
            isConversationRemoved: (conversationId, _) async =>
                conversationId == 'moved',
          );
          await store.previewFor(
            _videoMessage(conversationId: 'misfiled'),
          );

          await store.previewFor(
            _videoMessage(conversationId: 'moved'),
          );
          await store.prune();

          expect(ownerDir().listSync(), isEmpty);
        },
      );

      test(
        'keeps a conversation record while its video is downloading',
        () async {
          final release = Completer<Uint8List>();
          fetch = (_) => release.future;
          final store = createStore();
          final tapped = store.videoFor(_videoMessage());
          await pumpEventQueue();
          final record = keptFile(
            '${'a' * 64}.conversation',
            'conversation\n1757385263'.codeUnits,
            keptAt: now,
          );

          await store.prune();

          expect(record.existsSync(), isTrue);
          release.complete(_plaintext);
          await tapped;
        },
      );

      test(
        "moves a kept video's record when a tap plays its message from "
        'another conversation',
        () async {
          var removed = false;
          final store = createStore(
            isConversationRemoved: (conversationId, _) async =>
                removed && conversationId == 'moved',
          );
          await store.videoFor(_videoMessage(conversationId: 'misfiled'));

          await store.videoFor(_videoMessage(conversationId: 'moved'));
          removed = true;
          await store.prune();

          expect(ownerDir().listSync(), isEmpty);
        },
      );

      test(
        "writes a kept video's record again when it went missing",
        () async {
          var removed = false;
          final store = createStore(
            isConversationRemoved: (_, _) async => removed,
          );
          final message = _videoMessage();
          await store.videoFor(message);
          File('${ownerDir().path}/${'a' * 64}.conversation').deleteSync();

          await store.videoFor(message);
          removed = true;
          await store.prune();

          expect(ownerDir().listSync(), isEmpty);
        },
      );

      test(
        'deletes a conversation record and a frame-read mark once their video '
        'is gone',
        () async {
          keptFile(
            '${'a' * 64}.conversation',
            'conversation\n1757385263'.codeUnits,
            keptAt: now,
          );
          keptFile('${'a' * 64}.frame-attempt', const [], keptAt: now);

          await createStore().prune();

          expect(ownerDir().listSync(), isEmpty);
        },
      );

      test(
        'logs a conversation record it could not refresh as such, not as a '
        'message it could not look up',
        () async {
          final message = _videoMessage(conversationId: 'old-room');
          keptFile(
            DmVideoStore.videoFileNameFor(message),
            _plaintext,
            keptAt: now,
          );
          keptFile(
            '${message.id}.conversation',
            'old-room\n${message.createdAt}'.codeUnits,
            keptAt: now,
          );
          final store = createStore(
            isConversationRemoved: (_, _) async => false,
            findMessageLocation: (_) async =>
                (conversationId: 'repaired', sentAt: message.createdAt),
          );
          await LogCaptureService().clearAllLogs();

          await IOOverrides.runWithIOOverrides(
            store.prune,
            _WriteHooks((part) {
              if (part.path.contains('.conversation.')) {
                throw const FileSystemException('cannot write');
              }
            }),
          );

          expect(_loggedLines(), contains(contains('Could not refresh')));
          expect(_loggedLines(), isNot(contains(contains('is gone'))));
        },
      );

      test(
        'keeps everything when it cannot tell whether a message is gone',
        () async {
          final message = _videoMessage();
          final frame = await createStore().previewFor(message);
          final store = createStore(
            isMessageGone: (_) async => throw StateError('database closed'),
          );
          await LogCaptureService().clearAllLogs();

          await store.prune();

          expect(frame!.existsSync(), isTrue);
          expect(
            _loggedLines(),
            contains(contains('is gone: StateError')),
          );
        },
      );

      group('a video a caller holds', () {
        test('is kept past its age while held', () async {
          final store = createStore();
          final file = await store.videoFor(_videoMessage());
          file.setLastModifiedSync(now.subtract(const Duration(days: 31)));

          await store.prune();

          expect(file.existsSync(), isTrue);
        });

        test('is deleted for its age as soon as it is let go', () async {
          final store = createStore();
          final file = await store.videoFor(_videoMessage());
          file.setLastModifiedSync(now.subtract(const Duration(days: 31)));
          await store.prune();
          expect(file.existsSync(), isTrue);

          store.releaseVideo(file);

          expect(file.existsSync(), isFalse);
        });

        test(
          'takes its frame and record along when let go past its age',
          () async {
            final store = createStore();
            final message = _videoMessage();
            final file = await store.videoFor(message);
            await store.previewFor(message);
            for (final kept in keptFiles()) {
              kept.setLastModifiedSync(now.subtract(const Duration(days: 31)));
            }
            expect(keptFiles(), hasLength(3));

            store.releaseVideo(file);

            expect(keptFiles(), isEmpty);
          },
        );

        test(
          'stays kept for the next play when let go before its age',
          () async {
            final store = createStore();
            final file = await store.videoFor(_videoMessage());

            store.releaseVideo(file);
            await store.prune();

            expect(file.existsSync(), isTrue);
          },
        );

        test(
          'stays until every caller that asked for it at once lets go',
          () async {
            final store = createStore();
            final message = _videoMessage();
            final asked = [store.videoFor(message), store.videoFor(message)];
            final file = (await Future.wait(asked)).first;
            expect(fetches, equals(1));
            file.setLastModifiedSync(now.subtract(const Duration(days: 31)));

            store.releaseVideo(file);
            await store.prune();
            expect(file.existsSync(), isTrue);

            store.releaseVideo(file);
            expect(file.existsSync(), isFalse);
          },
        );

        test('counts against the cap again once let go', () async {
          final store = createStore(maxBytes: _plaintext.length - 1);
          final file = await store.videoFor(_videoMessage());
          await store.prune();
          expect(file.existsSync(), isTrue);

          store.releaseVideo(file);
          await store.prune();

          expect(file.existsSync(), isFalse);
        });

        test(
          'stays past its age when let go while its frame is being read',
          () async {
            final read = Completer<Uint8List?>();
            final reading = Completer<void>();
            readFrame = (_) {
              reading.complete();
              return read.future;
            };
            final store = createStore();
            final message = _videoMessage();
            final file = await store.videoFor(message);
            final preview = store.previewFor(message);
            await reading.future;
            file.setLastModifiedSync(now.subtract(const Duration(days: 31)));

            store.releaseVideo(file);

            expect(file.existsSync(), isTrue);
            read.complete(_frame);
            await preview;
            expect(keptFiles(), isEmpty);
          },
        );
      });

      group('a video another store of the account uses', () {
        late Completer<void> reading;
        late Completer<Uint8List?> read;

        /// Starts [store]'s frame read of [message], which runs until [read]
        /// completes, and returns once it runs.
        Future<Future<File?>> startRead(
          DmVideoStore store,
          DmMessage message,
        ) async {
          reading = Completer<void>();
          read = Completer<Uint8List?>();
          readFrame = (_) {
            reading.complete();
            return read.future;
          };
          final preview = store.previewFor(message);
          await reading.future;
          return preview;
        }

        File videoOf(DmMessage message) => File(
          '${ownerDir().path}/${DmVideoStore.videoFileNameFor(message)}',
        );

        File markOf(DmMessage message) =>
            File('${ownerDir().path}/${message.id}.frame-attempt');

        test(
          'is left past its age, with its read mark, while that store reads '
          'it',
          () async {
            final message = _videoMessage();
            final preview = await startRead(createStore(), message);
            videoOf(
              message,
            ).setLastModifiedSync(now.subtract(const Duration(days: 31)));

            expect(await createStore().previewFor(message), isNull);
            await createStore().prune();

            expect(videoOf(message).existsSync(), isTrue);
            expect(markOf(message).existsSync(), isTrue);
            read.complete(_frame);
            await preview;
          },
        );

        test(
          'is handed out as it is, past its age, while that store reads it',
          () async {
            final message = _videoMessage();
            final preview = await startRead(createStore(), message);
            videoOf(
              message,
            ).setLastModifiedSync(now.subtract(const Duration(days: 31)));

            final video = await createStore().videoFor(message);

            expect(fetches, equals(1));
            expect(video.path, equals(videoOf(message).path));
            read.complete(_frame);
            await preview;
          },
        );

        test(
          'is left, with its read mark, while that store reads it, and '
          'deleted once the read ends, when this one refuses it as gone',
          () async {
            final message = _videoMessage();
            final preview = await startRead(createStore(), message);

            await expectLater(
              createStore(isMessageGone: (_) async => true).videoFor(message),
              throwsA(isA<DmVideoGoneException>()),
            );

            expect(videoOf(message).existsSync(), isTrue);
            expect(markOf(message).existsSync(), isTrue);
            read.complete(_frame);
            await preview;
            expect(keptFiles(), isEmpty);
          },
        );

        test('is kept past its age while that store holds it', () async {
          final holder = createStore();
          final held = await holder.videoFor(_videoMessage());
          held.setLastModifiedSync(now.subtract(const Duration(days: 31)));

          await createStore().prune();

          expect(held.existsSync(), isTrue);
          holder.releaseVideo(held);
        });

        test(
          'is left, with its read mark, while that store reads it, and '
          'deleted once the read ends, when its message is gone',
          () async {
            final message = _videoMessage();
            final preview = await startRead(createStore(), message);

            await createStore(isMessageGone: (_) async => true).prune();

            expect(videoOf(message).existsSync(), isTrue);
            expect(markOf(message).existsSync(), isTrue);
            read.complete(_frame);
            await preview;
            expect(keptFiles(), isEmpty);
          },
        );

        test('is deleted while that store holds it, once its message is '
            'gone', () async {
          final holder = createStore();
          final held = await holder.videoFor(_videoMessage());

          await createStore(isMessageGone: (_) async => true).prune();

          expect(held.existsSync(), isFalse);
          holder.releaseVideo(held);
        });
      });

      test('prunes when the app comes back to the foreground', () async {
        final expired = keptFile(
          '${'a' * 64}.mp4',
          const [1],
          keptAt: now.subtract(const Duration(days: 31)),
        );
        final pruning = Completer<void>();
        final store = createStore(
          isMessageGone: (_) async {
            if (!pruning.isCompleted) pruning.complete();
            return false;
          },
        )..appInForeground = false;

        store.appInForeground = true;
        await pruning.future.timeout(const Duration(seconds: 5));
        await store.prune();

        expect(expired.existsSync(), isFalse);
      });

      test(
        'prunes on coming back to the foreground only once an hour has '
        'passed since the last prune',
        () async {
          var prunes = 0;
          final store = createStore(
            rootDirectory: () async {
              prunes++;
              return root;
            },
          );
          await store.prune();
          expect(prunes, equals(1));

          store
            ..appInForeground = false
            ..appInForeground = true;
          await store.prune();
          // Only the prune asked for here ran.
          expect(prunes, equals(2));

          now = now.add(DmVideoStore.foregroundPruneInterval);
          store
            ..appInForeground = false
            ..appInForeground = true;
          await store.prune();
          // Coming back pruned, and the prune asked for meanwhile ran after.
          expect(prunes, equals(4));
        },
      );

      test('clears a part file a crash left', () async {
        final crashed = keptFile(
          '${'a' * 64}.mp4.0.part',
          const [1],
          keptAt: now.subtract(const Duration(hours: 2)),
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
            keptAt: now,
          );

          await createStore().prune();

          expect(writing.existsSync(), isTrue);
        },
      );

      test(
        'runs one prune at a time, and one more for all asked meanwhile',
        () async {
          keptFile(
            DmVideoStore.videoFileNameFor(_videoMessage()),
            _plaintext,
            keptAt: now,
          );
          var lookups = 0;
          final store = createStore(
            isMessageGone: (_) async {
              lookups++;
              return false;
            },
          );

          await Future.wait([store.prune(), store.prune(), store.prune()]);

          expect(lookups, equals(2));
        },
      );

      test(
        'still runs the prune asked for meanwhile after one fails unexpectedly',
        () async {
          final video = keptFile(
            DmVideoStore.videoFileNameFor(_videoMessage()),
            _plaintext,
            keptAt: now,
          );
          var rootAsks = 0;
          final store = createStore(
            isMessageGone: (_) async => true,
            rootDirectory: () async {
              rootAsks++;
              if (rootAsks == 1) throw StateError('no cache directory');
              return root;
            },
          );

          final first = store.prune();
          final second = store.prune();

          await expectLater(first, throwsStateError);
          await expectLater(second, throwsStateError);
          expect(rootAsks, equals(2));
          expect(video.existsSync(), isFalse);
        },
      );

      test(
        "deletes a gone message's part file, however young: its write is no "
        'longer wanted',
        () async {
          final writing = keptFile(
            '${'a' * 64}.mp4.0.part',
            const [1],
            keptAt: now,
          );

          await createStore(isMessageGone: (_) async => true).prune();

          expect(writing.existsSync(), isFalse);
        },
      );

      test(
        'never trims a video a caller holds, even the oldest kept',
        () async {
          final store = createStore(maxBytes: 4);
          final played = await store.videoFor(_videoMessage());
          played.setLastModifiedSync(now.subtract(const Duration(hours: 2)));
          final newer = keptFile(
            'newer.mp4',
            const [1, 2, 3, 4, 5, 6, 7, 8],
            keptAt: now,
          );

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
          final preview = await store.previewFor(message);
          final video = File(
            '${ownerDir().path}/${DmVideoStore.videoFileNameFor(message)}',
          )..setLastModifiedSync(now.subtract(const Duration(minutes: 1)));
          preview!.setLastModifiedSync(now);

          await store.prune();

          expect(video.existsSync(), isFalse);
          expect(preview.existsSync(), isTrue);
        },
      );

      test(
        'leaves the rest alone when videos in use fill the cap by themselves',
        () async {
          // Room for one card's video and frame, not for the played videos.
          final store = createStore(
            maxBytes: _plaintext.length + _frame.length,
          );
          await store.videoFor(_videoMessage(id: '1' * 64));
          await store.videoFor(_videoMessage(id: '2' * 64));
          final message = _videoMessage();
          final frame = await store.previewFor(message);
          final video = File(
            '${ownerDir().path}/${DmVideoStore.videoFileNameFor(message)}',
          );

          await store.prune();

          expect(frame!.existsSync(), isTrue);
          expect(video.existsSync(), isTrue);
          expect(store.knownPreviewPathFor(message), equals(frame.path));
        },
      );

      test(
        'trims videos before frames, even frames kept longer ago',
        () async {
          final store = createStore(maxBytes: _plaintext.length - 1);
          final message = _videoMessage();
          final frame = await store.previewFor(message);
          frame!.setLastModifiedSync(now.subtract(const Duration(hours: 1)));
          final video = File(
            '${ownerDir().path}/${DmVideoStore.videoFileNameFor(message)}',
          )..setLastModifiedSync(now);

          await store.prune();

          expect(video.existsSync(), isFalse);
          expect(frame.existsSync(), isTrue);
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
          keptAt: now.subtract(const Duration(days: 31)),
        );
        final preview = store.previewFor(message);
        await pumpEventQueue();

        await store.prune();
        expect(video.existsSync(), isTrue);

        frameRead.complete(_frame);
        expect(await preview, isNotNull);
      });
    });

    group('account folders', () {
      test(
        'a store without file users does not suppress idle expiry',
        () async {
          final store = createStore();
          final idle = keptFile(
            'unused.mp4',
            _plaintext,
            keptAt: now.subtract(const Duration(days: 31)),
          );

          await DmVideoStore.sweepOwners(
            {_owner},
            rootDirectory: () async => root,
            now: () => now,
          );

          expect(idle.existsSync(), isFalse);
          await store.dispose();
        },
      );

      test('holds suppress expiry only while their store is live', () async {
        final store = createStore();
        final video = await store.videoFor(_videoMessage());
        video.setLastModifiedSync(now.subtract(const Duration(days: 31)));
        await DmVideoStore.sweepOwners(
          {_owner},
          rootDirectory: () async => root,
          now: () => now,
        );
        expect(video.existsSync(), isTrue);

        await store.dispose();
        await DmVideoStore.sweepOwners(
          {_owner},
          rootDirectory: () async => root,
          now: () => now,
        );
        expect(video.existsSync(), isFalse);
      });

      test(
        'a disposed store still protects an unsettled native file lease',
        () async {
          final message = _videoMessage();
          final video = keptFile(
            DmVideoStore.videoFileNameFor(message),
            _plaintext,
            keptAt: now,
          );
          final started = Completer<void>();
          final release = Completer<Uint8List?>();
          readFrame = (_) {
            started.complete();
            return release.future;
          };
          final store = createStore();
          final preview = store.previewFor(message);
          await started.future;
          // Past its age only once the decoder has it.
          video.setLastModifiedSync(now.subtract(const Duration(days: 31)));
          await store.dispose();
          try {
            await DmVideoStore.sweepOwners(
              {_owner},
              rootDirectory: () async => root,
              now: () => now,
            );
            expect(video.existsSync(), isTrue);
          } finally {
            release.complete(_frame);
            await preview;
          }
          await DmVideoStore.sweepOwners(
            {_owner},
            rootDirectory: () async => root,
            now: () => now,
          );
          expect(video.existsSync(), isFalse);
        },
      );

      test(
        'the known-owner sweep must not expire a live decoder input',
        () async {
          final message = _videoMessage();
          final video = keptFile(
            DmVideoStore.videoFileNameFor(message),
            _plaintext,
            keptAt: now,
          );
          final started = Completer<void>();
          final release = Completer<Uint8List?>();
          readFrame = (_) {
            started.complete();
            return release.future;
          };
          final store = createStore();
          final preview = store.previewFor(message);
          await started.future;
          // Past its age only once the decoder has it.
          video.setLastModifiedSync(now.subtract(const Duration(days: 31)));
          try {
            await DmVideoStore.sweepOwners(
              {_owner},
              rootDirectory: () async => root,
              now: () => now,
            );
            expect(video.existsSync(), isTrue);
          } finally {
            release.complete(_frame);
            await preview;
          }
          await store.prune();
          expect(video.existsSync(), isFalse);
        },
      );

      test(
        'legacy playback cleanup leaves other temporary files alone',
        () async {
          final legacy = File('${root.path}/dm_video_playback/clip.mp4')
            ..createSync(recursive: true)
            ..writeAsBytesSync(_plaintext);
          final unrelated = File('${root.path}/other/clip.mp4')
            ..createSync(recursive: true);

          await DmVideoStore.deleteLegacyPlaybackClips(
            temporaryDirectory: () async => root,
          );

          expect(legacy.parent.existsSync(), isFalse);
          expect(unrelated.existsSync(), isTrue);
        },
      );

      test(
        'legacy playback cleanup handles a missing temporary directory',
        () async {
          await expectLater(
            DmVideoStore.deleteLegacyPlaybackClips(
              temporaryDirectory: () async =>
                  throw MissingPlatformDirectoryException(
                    'no temporary folder',
                  ),
            ),
            completes,
          );
        },
      );

      test('legacy playback cleanup errors do not expose file paths', () async {
        await LogCaptureService().clearAllLogs();
        await IOOverrides.runZoned(
          () => DmVideoStore.deleteLegacyPlaybackClips(
            temporaryDirectory: () async => root,
          ),
          createDirectory: _UndeletableDirectory.new,
        );

        expect(_loggedLines(), contains(contains('Directory not empty')));
        expect(_loggedLines(), everyElement(isNot(contains(root.path))));
      });

      test("deleteOwner removes only that account's videos", () async {
        final other = 'f' * 64;
        keptFile('mine.mp4', const [1], keptAt: now);
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

      test(
        'remembers no failed download for an account removed during it',
        () async {
          final release = Completer<Uint8List>();
          fetch = (_) => release.future;
          final store = createStore();

          final preview = store.previewFor(_videoMessage());
          await pumpEventQueue();
          await DmVideoStore.deleteOwner(
            _owner,
            rootDirectory: () async => root,
          );
          release.completeError(
            const DmVideoUnavailableException(
              'the download failed: badResponse, HTTP 404',
            ),
          );

          await expectLater(
            preview,
            throwsA(isA<DmVideoUnavailableException>()),
          );
          expect(ownerDir().existsSync(), isFalse);
        },
      );

      test(
        'remembers no failure for an account removed while the mark is '
        'written',
        () async {
          fetch = (_) async => throw const DmVideoUnavailableException(
            'the download failed: badResponse, HTTP 404',
          );
          final store = createStore();

          await IOOverrides.runWithIOOverrides(
            () => expectLater(
              store.previewFor(_videoMessage()),
              throwsA(isA<DmVideoUnavailableException>()),
            ),
            _WriteHooks((file) {
              if (!file.path.endsWith('.failed')) return;
              // The account goes between the store's check and the write.
              unawaited(
                DmVideoStore.deleteOwner(
                  _owner,
                  rootDirectory: () => Completer<Directory>().future,
                ),
              );
              if (ownerDir().existsSync()) {
                ownerDir().deleteSync(recursive: true);
              }
            }),
          );

          expect(keptFiles(), isEmpty);
        },
      );

      test(
        'concurrent stores of one account do not share part-file names',
        () async {
          final release = Completer<Uint8List>();
          fetch = (_) => release.future;
          final message = _videoMessage();
          final first = createStore().videoFor(message);
          final second = createStore().videoFor(message);
          await pumpEventQueue();

          release.complete(_plaintext);
          final videos = await Future.wait([first, second]);

          expect(videos.map((video) => video.path).toSet(), hasLength(1));
          expect(videos.first.readAsBytesSync(), _plaintext);
        },
      );

      test(
        'refuses a rename if the account is removed during the part write',
        () async {
          final message = _videoMessage();
          final deletionRoot = Completer<Directory>();
          Future<void>? removal;
          final store = createStore();
          final kept = IOOverrides.runWithIOOverrides(
            () => store.videoFor(message),
            _WriteHooks((part) {
              if (removal != null || !part.path.contains('.mp4.')) return;
              // Hold the folder delete back: only the post-write owner check
              // can prevent the plaintext rename at this boundary.
              removal = DmVideoStore.deleteOwner(
                _owner,
                rootDirectory: () => deletionRoot.future,
              );
            }),
          );
          try {
            await expectLater(
              kept,
              throwsA(isA<DmVideoUnavailableException>()),
            );
            expect(removal, isNotNull);
            expect(
              File(
                '${ownerDir().path}/${DmVideoStore.videoFileNameFor(message)}',
              ).existsSync(),
              isFalse,
            );
            expect(
              ownerDir().listSync().map((file) => file.path),
              everyElement(isNot(endsWith('.part'))),
            );
          } finally {
            deletionRoot.complete(root);
            await removal;
          }
        },
      );

      test('a store created after the removal keeps videos again', () async {
        await DmVideoStore.deleteOwner(_owner, rootDirectory: () async => root);

        final video = await createStore().videoFor(_videoMessage());

        expect(video.readAsBytesSync(), equals(_plaintext));
      });

      test(
        'sweepOwners deletes what a known account kept more than 30 days ago, '
        'and part files a crash left',
        () async {
          final expired = keptFile(
            'expired.mp4',
            const [1],
            keptAt: now.subtract(const Duration(days: 31)),
          );
          final recent = keptFile(
            'recent.mp4',
            const [1],
            keptAt: now.subtract(const Duration(days: 1)),
          );
          final crashed = keptFile(
            'crashed.mp4.part',
            const [1],
            keptAt: now.subtract(const Duration(hours: 2)),
          );
          final writing = keptFile('writing.mp4.part', const [1], keptAt: now);

          await DmVideoStore.sweepOwners(
            {_owner},
            rootDirectory: () async => root,
            now: () => now,
          );

          expect(expired.existsSync(), isFalse);
          expect(crashed.existsSync(), isFalse);
          expect(recent.existsSync(), isTrue);
          expect(writing.existsSync(), isTrue);
        },
      );

      test(
        'sweepOwners keeps the marks of a message whose video a live store is '
        'still fetching, and only those',
        () async {
          final release = Completer<Uint8List>();
          fetch = (_) => release.future;
          final message = _videoMessage();
          final store = createStore();
          final download = store.videoFor(message);
          await pumpEventQueue();
          final fetching = keptFile(
            '${message.id}.frame-attempt',
            const [],
            keptAt: now,
          );
          final unrelated = keptFile(
            '${'9' * 64}.frame-attempt',
            const [],
            keptAt: now,
          );

          await DmVideoStore.sweepOwners(
            {_owner},
            rootDirectory: () async => root,
            now: () => now,
          );

          expect(fetching.existsSync(), isTrue);
          expect(unrelated.existsSync(), isFalse);
          release.complete(_plaintext);
          await download;
        },
      );

      test(
        "sweepOwners keeps a known account's conversation record while its "
        'video stays',
        () async {
          keptFile('recent.mp4', const [1], keptAt: now);
          final record = keptFile(
            'recent.conversation',
            'conversation\n1757385263'.codeUnits,
            keptAt: now.subtract(const Duration(days: 31)),
          );

          await DmVideoStore.sweepOwners(
            {_owner},
            rootDirectory: () async => root,
            now: () => now,
          );

          expect(record.existsSync(), isTrue);
        },
      );

      test(
        "sweepOwners keeps a known account's conversation record while its "
        'frame stays',
        () async {
          keptFile('recent.preview.jpg', const [1], keptAt: now);
          final record = keptFile(
            'recent.conversation',
            'conversation\n1757385263'.codeUnits,
            keptAt: now.subtract(const Duration(days: 31)),
          );

          await DmVideoStore.sweepOwners(
            {_owner},
            rootDirectory: () async => root,
            now: () => now,
          );

          expect(record.existsSync(), isTrue);
        },
      );

      test(
        "sweepOwners deletes an expired video's record and frame-read mark in "
        'the same sweep',
        () async {
          final video = keptFile(
            'stale.mp4',
            const [1],
            keptAt: now.subtract(const Duration(days: 31)),
          );
          final record = keptFile(
            'stale.conversation',
            'conversation\n1757385263'.codeUnits,
            keptAt: now,
          );
          final mark = keptFile('stale.frame-attempt', const [], keptAt: now);

          await DmVideoStore.sweepOwners(
            {_owner},
            rootDirectory: () async => root,
            now: () => now,
          );

          expect(video.existsSync(), isFalse);
          expect(record.existsSync(), isFalse);
          expect(mark.existsSync(), isFalse);
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
