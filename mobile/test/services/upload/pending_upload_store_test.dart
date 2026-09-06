// ABOUTME: Unit tests for PendingUploadStore – the Hive persistence layer.
// ABOUTME: Covers CRUD, save-queue fallback, owner scoping, reuse detection,
// ABOUTME: and both cleanup routines.

import 'dart:io';

import 'package:blossom_upload_service/blossom_upload_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:openvine/models/pending_upload.dart';
import 'package:openvine/services/upload/pending_upload_store.dart';
import 'package:openvine/services/upload_initialization_helper.dart';
import 'package:path_provider_platform_interface/path_provider_platform_interface.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_helpers.dart';
import '../../mocks/mock_path_provider_platform.dart';

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _pubkeyA =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _pubkeyB =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

/// Create and open an unscoped store backed by a fresh Hive box.
Future<PendingUploadStore> _openStore({
  bool scopeUploadsToCurrentUser = false,
  String? currentNostrPubkey,
}) async {
  final store = PendingUploadStore(
    scopeUploadsToCurrentUser: scopeUploadsToCurrentUser,
    currentNostrPubkey: currentNostrPubkey,
  );
  await store.open();
  return store;
}

/// Force every box-open attempt to fail deterministically, so `save()` cannot
/// persist and must fall back to the deferred-save queue. Returns the isolated
/// dir to build upload paths from.
///
/// Hive.openBox returns any already-open box *by name* regardless of path, so a
/// box another test left open would let save() succeed. Close all boxes first
/// (swallowing the benign lock-file delete race when the backing temp dir was
/// already removed), then point Hive's home at a regular file so neither the
/// normal open nor the helper's recovery strategy can create box files.
Future<Directory> _forceStorageFailure() async {
  try {
    await Hive.close();
  } catch (_) {
    // Closing a box whose temp dir was already deleted races the lock-file
    // cleanup; the box is still unregistered, so ignore.
  }
  UploadInitializationHelper.reset();

  final isolatedDir = await Directory.systemTemp.createTemp(
    'pending_upload_store_queue_',
  );
  final blocker = File('${isolatedDir.path}/storage_blocker');
  await blocker.writeAsString('not a directory');

  addTearDown(() async {
    try {
      await Hive.close();
    } catch (_) {
      // See note above: ignore the benign lock-cleanup race.
    }
    UploadInitializationHelper.reset();
    if (isolatedDir.existsSync()) {
      await isolatedDir.delete(recursive: true);
    }
  });

  Hive.init(blocker.path);
  return isolatedDir;
}

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  setUpAll(() async {
    await initializeServiceTestEnvironment();
  });

  group(PendingUploadStore, () {
    late Directory tempDir;
    late PathProviderPlatform originalPathProvider;

    setUp(() async {
      await TestHelpers.cleanupHiveBox('pending_uploads');
      SharedPreferences.setMockInitialValues({});

      tempDir = await Directory.systemTemp.createTemp(
        'pending_upload_store_',
      );
      originalPathProvider = PathProviderPlatform.instance;
      PathProviderPlatform.instance = MockPathProviderPlatform()
        ..setTemporaryPath(tempDir.path)
        ..setApplicationDocumentsPath('${tempDir.path}/documents')
        ..setApplicationSupportPath('${tempDir.path}/support');
      await TestHelpers.initHiveHome();
    });

    tearDown(() async {
      await TestHelpers.cleanupHiveBox('pending_uploads');
      PathProviderPlatform.instance = originalPathProvider;
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });

    // -----------------------------------------------------------------------
    // Lifecycle
    // -----------------------------------------------------------------------

    group('lifecycle', () {
      test('isReady is false before open', () {
        final store = PendingUploadStore(
          scopeUploadsToCurrentUser: false,
          currentNostrPubkey: null,
        );
        expect(store.isReady, isFalse);
      });

      test('isReady is true after open()', () async {
        final store = await _openStore();
        addTearDown(store.disposeStore);
        expect(store.isReady, isTrue);
      });

      test('disposeStore() makes isReady false', () async {
        final store = await _openStore();
        store.disposeStore();
        expect(store.isReady, isFalse);
      });

      test('length returns 0 before open', () {
        final store = PendingUploadStore(
          scopeUploadsToCurrentUser: false,
          currentNostrPubkey: null,
        );
        expect(store.length, equals(0));
      });

      test('queuedCount starts at 0', () async {
        final store = await _openStore();
        addTearDown(store.disposeStore);
        expect(store.queuedCount, equals(0));
      });
    });

    // -----------------------------------------------------------------------
    // CRUD round-trips
    // -----------------------------------------------------------------------

    group('save / get / update / delete', () {
      test('save() persists and get() retrieves the record', () async {
        final store = await _openStore();
        addTearDown(store.disposeStore);

        final upload = PendingUpload.create(
          localVideoPath: '${tempDir.path}/video.mp4',
          nostrPubkey: _pubkeyA,
          title: 'Test video',
        );

        await store.save(upload);

        expect(store.length, equals(1));
        final retrieved = store.getUpload(upload.id);
        expect(retrieved, isNotNull);
        expect(retrieved!.id, equals(upload.id));
        expect(retrieved.title, equals('Test video'));
      });

      test('update() overwrites an existing record', () async {
        final store = await _openStore();
        addTearDown(store.disposeStore);

        final upload = PendingUpload.create(
          localVideoPath: '${tempDir.path}/video.mp4',
          nostrPubkey: _pubkeyA,
          title: 'Original',
        );
        await store.save(upload);

        final updated = upload.copyWith(
          status: UploadStatus.uploading,
          uploadProgress: 0.5,
        );
        await store.update(updated);

        final retrieved = store.getUpload(upload.id);
        expect(retrieved!.status, equals(UploadStatus.uploading));
        expect(retrieved.uploadProgress, equals(0.5));
      });

      test('delete() removes the record', () async {
        final store = await _openStore();
        addTearDown(store.disposeStore);

        final upload = PendingUpload.create(
          localVideoPath: '${tempDir.path}/video.mp4',
          nostrPubkey: _pubkeyA,
          title: 'To delete',
        );
        await store.save(upload);
        expect(store.length, equals(1));

        await store.delete(upload.id);
        expect(store.length, equals(0));
        expect(store.getUpload(upload.id), isNull);
      });

      test('get() returns null for unknown id', () async {
        final store = await _openStore();
        addTearDown(store.disposeStore);
        expect(store.getUpload('no-such-id'), isNull);
      });

      test('update() is a no-op when box is not ready', () async {
        final store = PendingUploadStore(
          scopeUploadsToCurrentUser: false,
          currentNostrPubkey: null,
        );
        final upload = PendingUpload.create(
          localVideoPath: '${tempDir.path}/video.mp4',
          nostrPubkey: _pubkeyA,
        );
        // Should not throw.
        await store.update(upload);
      });

      test('pendingUploads returns uploads sorted newest-first', () async {
        final store = await _openStore();
        addTearDown(store.disposeStore);

        // Pin createdAt explicitly so newest-first ordering is deterministic
        // rather than depending on a wall-clock gap between the two saves.
        final older = PendingUpload.create(
          localVideoPath: '${tempDir.path}/old.mp4',
          nostrPubkey: _pubkeyA,
          title: 'Older',
        ).copyWith(createdAt: DateTime(2024, 1, 1, 12));
        await store.save(older);

        final newer = PendingUpload.create(
          localVideoPath: '${tempDir.path}/new.mp4',
          nostrPubkey: _pubkeyA,
          title: 'Newer',
        ).copyWith(createdAt: DateTime(2024, 1, 1, 13));
        await store.save(newer);

        final uploads = store.pendingUploads;
        expect(uploads.first.id, equals(newer.id));
        expect(uploads.last.id, equals(older.id));
      });
    });

    // -----------------------------------------------------------------------
    // Save-queue fallback
    // -----------------------------------------------------------------------

    group('deferred save queue', () {
      test(
        'queues the upload and throws when storage cannot be opened',
        () async {
          final isolatedDir = await _forceStorageFailure();

          final store = PendingUploadStore(
            scopeUploadsToCurrentUser: false,
            currentNostrPubkey: null,
          );

          final upload = PendingUpload.create(
            localVideoPath: '${isolatedDir.path}/video.mp4',
            nostrPubkey: _pubkeyA,
          );

          // save() can neither use an existing box nor reopen one, so it
          // queues the upload for a later retry and rethrows.
          await expectLater(
            () => store.save(upload),
            throwsA(isA<Exception>()),
          );

          expect(store.queuedCount, equals(1));

          // Cancel the retry timer the store scheduled and clear the queue.
          store.disposeStore();
          expect(store.queuedCount, equals(0));
        },
      );

      test(
        'draining a still-failing upload does not double-enqueue it',
        () async {
          final isolatedDir = await _forceStorageFailure();

          final store = PendingUploadStore(
            scopeUploadsToCurrentUser: false,
            currentNostrPubkey: null,
          );
          addTearDown(store.disposeStore);

          final upload = PendingUpload.create(
            localVideoPath: '${isolatedDir.path}/video.mp4',
            nostrPubkey: _pubkeyA,
          );

          // First save fails and enqueues exactly one entry.
          await expectLater(
            () => store.save(upload),
            throwsA(isA<Exception>()),
          );
          expect(store.queuedCount, equals(1));

          // The drain retries the save; it re-fails and re-enqueues. Because the
          // queue is keyed by id, the count stays 1 — a raw List would grow to 2
          // (save()'s own re-queue + the drain loop's re-queue).
          await store.drainPendingSaves();
          expect(store.queuedCount, equals(1));
        },
      );

      test(
        'drain reschedules exactly one store-owned (cancellable) retry timer',
        () async {
          final isolatedDir = await _forceStorageFailure();

          final store = PendingUploadStore(
            scopeUploadsToCurrentUser: false,
            currentNostrPubkey: null,
          );

          final upload = PendingUpload.create(
            localVideoPath: '${isolatedDir.path}/video.mp4',
            nostrPubkey: _pubkeyA,
          );
          await expectLater(
            () => store.save(upload),
            throwsA(isA<Exception>()),
          );

          // After the drain a retry is scheduled, and it is owned by the store:
          // disposeStore() cancels it. Pre-fix, the 5 s timer set during the
          // drain was orphaned by the 30 s reschedule and survived disposal.
          await store.drainPendingSaves();
          expect(store.hasScheduledRetry, isTrue);

          store.disposeStore();
          expect(store.hasScheduledRetry, isFalse);
        },
      );

      test('a drain is a no-op while another drain is in flight', () async {
        final isolatedDir = await _forceStorageFailure();

        final store = PendingUploadStore(
          scopeUploadsToCurrentUser: false,
          currentNostrPubkey: null,
        );
        addTearDown(store.disposeStore);

        final upload = PendingUpload.create(
          localVideoPath: '${isolatedDir.path}/video.mp4',
          nostrPubkey: _pubkeyA,
        );
        await expectLater(
          () => store.save(upload),
          throwsA(isA<Exception>()),
        );

        // Start a drain but don't await it — it suspends on the failing save().
        final inFlight = store.drainPendingSaves();
        expect(store.isDraining, isTrue);

        // A second drain triggered while the first runs returns immediately
        // (the re-entrancy guard) instead of starting a concurrent drain.
        await store.drainPendingSaves();
        expect(store.isDraining, isTrue);

        await inFlight;
        expect(store.isDraining, isFalse);
      });

      test(
        'a drain that resumes after disposeStore() leaves no timer and an '
        'empty queue',
        () async {
          final isolatedDir = await _forceStorageFailure();

          final store = PendingUploadStore(
            scopeUploadsToCurrentUser: false,
            currentNostrPubkey: null,
          );

          final upload = PendingUpload.create(
            localVideoPath: '${isolatedDir.path}/video.mp4',
            nostrPubkey: _pubkeyA,
          );
          await expectLater(
            () => store.save(upload),
            throwsA(isA<Exception>()),
          );
          expect(store.queuedCount, equals(1));

          // Start a drain; it suspends on the still-failing save().
          final inFlight = store.drainPendingSaves();
          expect(store.isDraining, isTrue);

          // Tear the store down mid-drain. disposeStore() cancels the timer and
          // clears the queue, but the drain is still parked on `await save()`.
          store.disposeStore();
          expect(store.isDisposed, isTrue);

          // The drain resumes and re-fails. Pre-fix it would re-queue the upload
          // (via save()'s _queueUploadForLater and the loop catch) and arm a
          // fresh 30 s timer that disposeStore() can no longer cancel — a
          // self-perpetuating retry surviving disposal. The disposed latch makes
          // the resumed drain inert.
          await inFlight;

          expect(
            store.queuedCount,
            equals(0),
            reason: 'a disposed store must not repopulate its queue',
          );
          expect(
            store.hasScheduledRetry,
            isFalse,
            reason: 'no retry timer may survive disposal',
          );
        },
      );

      test(
        'open() clears the disposed latch so a reused store can queue again',
        () async {
          final store = await _openStore();
          addTearDown(store.disposeStore);

          store.disposeStore();
          expect(store.isDisposed, isTrue);

          // Re-initialising the same instance (the manager's initialize() path)
          // must restore a fully usable store — including the deferred-save
          // queue, which the disposed latch otherwise keeps inert.
          await store.open();
          expect(store.isDisposed, isFalse);
          expect(store.isReady, isTrue);
        },
      );

      test(
        'ensureOpen() does not revive the box after disposeStore()',
        () async {
          final store = await _openStore();
          addTearDown(store.disposeStore);

          store.disposeStore();
          expect(store.isReady, isFalse);

          // A zombie drain resumes through save()'s slow path -> ensureOpen()
          // with storage now healthy. ensureOpen() must stay inert: reviving the
          // box would leave a disposed store reporting isReady == true (a live,
          // open box behind a disposed latch). Only open() re-inits.
          await store.ensureOpen();

          expect(
            store.isReady,
            isFalse,
            reason: 'a disposed store must stay inert until open() re-inits it',
          );
          expect(store.isDisposed, isTrue);
        },
      );
    });

    // -----------------------------------------------------------------------
    // getUploadByFilePath
    // -----------------------------------------------------------------------

    group('getUploadByFilePath', () {
      test('returns upload matching the file path', () async {
        final store = await _openStore();
        addTearDown(store.disposeStore);

        final upload = PendingUpload.create(
          localVideoPath: '${tempDir.path}/video.mp4',
          nostrPubkey: _pubkeyA,
        );
        await store.save(upload);

        final result = store.getUploadByFilePath('${tempDir.path}/video.mp4');
        expect(result, isNotNull);
        expect(result!.id, equals(upload.id));
      });

      test('returns null when no upload matches the path', () async {
        final store = await _openStore();
        addTearDown(store.disposeStore);

        expect(store.getUploadByFilePath('/no/such/file.mp4'), isNull);
      });
    });

    // -----------------------------------------------------------------------
    // Owner-scope filtering
    // -----------------------------------------------------------------------

    group('owner-scope filtering', () {
      Future<Map<String, PendingUpload>> seedTwoAccounts(
        PendingUploadStore store,
      ) async {
        final aUpload = PendingUpload.create(
          localVideoPath: '${tempDir.path}/a.mp4',
          nostrPubkey: _pubkeyA,
          title: 'Account A upload',
        );
        final bUpload = PendingUpload.create(
          localVideoPath: '${tempDir.path}/b.mp4',
          nostrPubkey: _pubkeyB,
          title: 'Account B upload',
        );
        // Write directly to the box so both records exist regardless of scope.
        final box = Hive.box<PendingUpload>('pending_uploads');
        await box.put(aUpload.id, aUpload);
        await box.put(bUpload.id, bUpload);
        return {'a': aUpload, 'b': bUpload};
      }

      test(
        'unscoped store returns all uploads regardless of pubkey',
        () async {
          final store = await _openStore();
          addTearDown(store.disposeStore);
          await seedTwoAccounts(store);

          expect(store.pendingUploads, hasLength(2));
        },
      );

      test(
        'scoped store returns only uploads belonging to currentNostrPubkey',
        () async {
          final store = await _openStore(
            scopeUploadsToCurrentUser: true,
            currentNostrPubkey: _pubkeyA,
          );
          addTearDown(store.disposeStore);
          final uploads = await seedTwoAccounts(store);

          final visible = store.pendingUploads;
          expect(visible, hasLength(1));
          expect(visible.single.nostrPubkey, equals(_pubkeyA));

          // get() also respects scope.
          expect(store.getUpload(uploads['a']!.id), isNotNull);
          expect(store.getUpload(uploads['b']!.id), isNull);
        },
      );

      test(
        'scoped store with no current pubkey hides all uploads',
        () async {
          final store = await _openStore(
            scopeUploadsToCurrentUser: true,
          );
          addTearDown(store.disposeStore);
          await seedTwoAccounts(store);

          expect(store.pendingUploads, isEmpty);
        },
      );

      test('getUploadByFilePath obeys scope', () async {
        final store = await _openStore(
          scopeUploadsToCurrentUser: true,
          currentNostrPubkey: _pubkeyA,
        );
        addTearDown(store.disposeStore);
        await seedTwoAccounts(store);

        expect(
          store.getUploadByFilePath('${tempDir.path}/a.mp4'),
          isNotNull,
        );
        expect(
          store.getUploadByFilePath('${tempDir.path}/b.mp4'),
          isNull,
        );
      });

      test('uploadStats reflects only scoped uploads', () async {
        final store = await _openStore(
          scopeUploadsToCurrentUser: true,
          currentNostrPubkey: _pubkeyA,
        );
        addTearDown(store.disposeStore);
        await seedTwoAccounts(store);

        final stats = store.uploadStats;
        expect(stats['total'], equals(1));
      });

      test('deleteAllForOwner removes only the requested owner', () async {
        final store = await _openStore(
          scopeUploadsToCurrentUser: true,
          currentNostrPubkey: _pubkeyA,
        );
        addTearDown(store.disposeStore);
        final uploads = await seedTwoAccounts(store);

        final deleted = await store.deleteAllForOwner(_pubkeyA);

        expect(deleted, equals(1));
        expect(store.getUpload(uploads['a']!.id), isNull);

        final box = Hive.box<PendingUpload>('pending_uploads');
        expect(box.get(uploads['b']!.id), isNotNull);
        expect(box.values.map((upload) => upload.nostrPubkey), [_pubkeyB]);
      });

      test(
        'deleteAllForOwner purges queued saves for the requested owner',
        () async {
          final isolatedDir = await _forceStorageFailure();

          final store = PendingUploadStore(
            scopeUploadsToCurrentUser: false,
            currentNostrPubkey: null,
          );
          addTearDown(store.disposeStore);

          final uploadA = PendingUpload.create(
            localVideoPath: '${isolatedDir.path}/a.mp4',
            nostrPubkey: _pubkeyA,
          );
          final uploadB = PendingUpload.create(
            localVideoPath: '${isolatedDir.path}/b.mp4',
            nostrPubkey: _pubkeyB,
          );

          await expectLater(
            () => store.save(uploadA),
            throwsA(isA<Exception>()),
          );
          await expectLater(
            () => store.save(uploadB),
            throwsA(isA<Exception>()),
          );
          expect(store.queuedCount, equals(2));

          final deleted = await store.deleteAllForOwner(_pubkeyA);

          expect(deleted, equals(0));
          expect(store.queuedCount, equals(1));
        },
      );
    });

    // -----------------------------------------------------------------------
    // findReusableUpload
    // -----------------------------------------------------------------------

    group('findReusableUpload', () {
      late File videoFile;

      setUp(() {
        videoFile = File('${tempDir.path}/video.mp4')
          ..writeAsBytesSync(List<int>.generate(32, (i) => i));
      });

      test('returns upload in uploading status with matching path', () async {
        final store = await _openStore();
        addTearDown(store.disposeStore);

        final upload =
            PendingUpload.create(
              localVideoPath: videoFile.path,
              nostrPubkey: _pubkeyA,
            ).copyWith(
              status: UploadStatus.uploading,
              resumableSession: const BlossomResumableUploadSession(
                uploadId: 'up_1',
                uploadUrl: 'https://upload.divine.video/sessions/up_1',
                chunkSize: 8,
                nextOffset: 8,
              ),
            );
        await store.save(upload);

        final result = store.findReusableUpload(videoFile.path);
        expect(result, isNotNull);
        expect(result!.id, equals(upload.id));
      });

      test('returns publishable readyToPublish upload', () async {
        final store = await _openStore();
        addTearDown(store.disposeStore);

        final upload =
            PendingUpload.create(
              localVideoPath: videoFile.path,
              nostrPubkey: _pubkeyA,
            ).copyWith(
              status: UploadStatus.readyToPublish,
              videoId: 'ready-video-id',
              cdnUrl: 'https://media.divine.video/ready-video',
              thumbnailPath: 'https://media.divine.video/ready-video-thumb.jpg',
            );
        await store.save(upload);

        final result = store.findReusableUpload(videoFile.path);
        expect(result, isNotNull);
        expect(result!.status, equals(UploadStatus.readyToPublish));
      });

      test('skips readyToPublish upload without HTTP thumbnail', () async {
        final store = await _openStore();
        addTearDown(store.disposeStore);

        final upload =
            PendingUpload.create(
              localVideoPath: videoFile.path,
              nostrPubkey: _pubkeyA,
            ).copyWith(
              status: UploadStatus.readyToPublish,
              videoId: 'ready-video-id',
              cdnUrl: 'https://media.divine.video/ready-video',
              // thumbnailPath intentionally omitted → not publishable
            );
        await store.save(upload);

        expect(store.findReusableUpload(videoFile.path), isNull);
      });

      test('skips failed upload with no resumable session', () async {
        final store = await _openStore();
        addTearDown(store.disposeStore);

        final upload = PendingUpload.create(
          localVideoPath: videoFile.path,
          nostrPubkey: _pubkeyA,
        ).copyWith(status: UploadStatus.failed);
        await store.save(upload);

        expect(store.findReusableUpload(videoFile.path), isNull);
      });

      test('returns failed upload that has a resumable session', () async {
        final store = await _openStore();
        addTearDown(store.disposeStore);

        final upload =
            PendingUpload.create(
              localVideoPath: videoFile.path,
              nostrPubkey: _pubkeyA,
            ).copyWith(
              status: UploadStatus.failed,
              resumableSession: const BlossomResumableUploadSession(
                uploadId: 'up_2',
                uploadUrl: 'https://upload.divine.video/sessions/up_2',
                chunkSize: 8,
                nextOffset: 0,
              ),
            );
        await store.save(upload);

        final result = store.findReusableUpload(videoFile.path);
        expect(result, isNotNull);
      });

      test('skips pending and published uploads', () async {
        final store = await _openStore();
        addTearDown(store.disposeStore);

        for (final status in [
          UploadStatus.pending,
          UploadStatus.published,
          UploadStatus.paused,
        ]) {
          final box = Hive.box<PendingUpload>('pending_uploads');
          await box.clear();

          final upload = PendingUpload.create(
            localVideoPath: videoFile.path,
            nostrPubkey: _pubkeyA,
          ).copyWith(status: status);
          await box.put(upload.id, upload);

          expect(
            store.findReusableUpload(videoFile.path),
            isNull,
            reason: 'Expected null for status $status',
          );
        }
      });

      test('returns null when path does not match', () async {
        final store = await _openStore();
        addTearDown(store.disposeStore);

        final upload = PendingUpload.create(
          localVideoPath: videoFile.path,
          nostrPubkey: _pubkeyA,
        ).copyWith(status: UploadStatus.uploading);
        await store.save(upload);

        expect(store.findReusableUpload('/other/path.mp4'), isNull);
      });
    });

    // -----------------------------------------------------------------------
    // cleanupCompletedUploads
    // -----------------------------------------------------------------------

    group('cleanupCompletedUploads', () {
      test('removes published uploads immediately', () async {
        final store = await _openStore();
        addTearDown(store.disposeStore);

        final upload =
            PendingUpload.create(
              localVideoPath: '${tempDir.path}/pub.mp4',
              nostrPubkey: _pubkeyA,
            ).copyWith(
              status: UploadStatus.published,
              completedAt: DateTime.now(),
            );
        await store.save(upload);
        expect(store.length, equals(1));

        await store.cleanupCompletedUploads();
        expect(store.length, equals(0));
      });

      test(
        'removes failed upload whose video file no longer exists',
        () async {
          final store = await _openStore();
          addTearDown(store.disposeStore);

          // Path points to a non-existent file.
          final upload = PendingUpload.create(
            localVideoPath: '${tempDir.path}/gone.mp4',
            nostrPubkey: _pubkeyA,
          ).copyWith(status: UploadStatus.failed);
          await store.save(upload);
          expect(store.length, equals(1));

          await store.cleanupCompletedUploads();
          expect(store.length, equals(0));
        },
      );

      test('keeps failed upload whose file still exists', () async {
        final store = await _openStore();
        addTearDown(store.disposeStore);

        final videoFile = File('${tempDir.path}/keep.mp4')
          ..writeAsBytesSync([0]);
        final upload = PendingUpload.create(
          localVideoPath: videoFile.path,
          nostrPubkey: _pubkeyA,
        ).copyWith(status: UploadStatus.failed);
        await store.save(upload);

        await store.cleanupCompletedUploads();
        expect(store.length, equals(1));
      });

      test('operates on all uploads (not just owner-scoped)', () async {
        final store = await _openStore(
          scopeUploadsToCurrentUser: true,
          currentNostrPubkey: _pubkeyA,
        );
        addTearDown(store.disposeStore);

        // Record belonging to pubkeyB – outside owner scope.
        final otherPublished =
            PendingUpload.create(
              localVideoPath: '${tempDir.path}/other_pub.mp4',
              nostrPubkey: _pubkeyB,
            ).copyWith(
              status: UploadStatus.published,
              completedAt: DateTime.now(),
            );
        final box = Hive.box<PendingUpload>('pending_uploads');
        await box.put(otherPublished.id, otherPublished);

        await store.cleanupCompletedUploads();
        // Should be removed even though it belongs to pubkeyB.
        expect(store.length, equals(0));
      });
    });

    // -----------------------------------------------------------------------
    // cleanupProblematicUploads
    // -----------------------------------------------------------------------

    group('cleanupProblematicUploads', () {
      test(
        'moves readyToPublish without required CDN fields to failed',
        () async {
          final store = await _openStore();
          addTearDown(store.disposeStore);

          // Missing videoId / cdnUrl → not publishable.
          final stuck = PendingUpload.create(
            localVideoPath: '${tempDir.path}/stuck.mp4',
            nostrPubkey: _pubkeyA,
          ).copyWith(status: UploadStatus.readyToPublish);
          await store.save(stuck);

          await store.cleanupProblematicUploads();

          final afterClean = store.getUpload(stuck.id);
          expect(afterClean, isNotNull);
          expect(afterClean!.status, equals(UploadStatus.failed));
        },
      );

      test('leaves publishable readyToPublish uploads untouched', () async {
        final store = await _openStore();
        addTearDown(store.disposeStore);

        final good =
            PendingUpload.create(
              localVideoPath: '${tempDir.path}/good.mp4',
              nostrPubkey: _pubkeyA,
            ).copyWith(
              status: UploadStatus.readyToPublish,
              videoId: 'vid-123',
              cdnUrl: 'https://media.divine.video/vid-123',
              thumbnailPath: 'https://media.divine.video/vid-123-thumb.jpg',
            );
        await store.save(good);

        await store.cleanupProblematicUploads();

        final afterClean = store.getUpload(good.id);
        expect(afterClean!.status, equals(UploadStatus.readyToPublish));
      });

      test('respects owner scope (only fixes visible uploads)', () async {
        final store = await _openStore(
          scopeUploadsToCurrentUser: true,
          currentNostrPubkey: _pubkeyA,
        );
        addTearDown(store.disposeStore);

        // Stuck record for pubkeyB – outside scope.
        final stuckB = PendingUpload.create(
          localVideoPath: '${tempDir.path}/stuck_b.mp4',
          nostrPubkey: _pubkeyB,
        ).copyWith(status: UploadStatus.readyToPublish);
        final box = Hive.box<PendingUpload>('pending_uploads');
        await box.put(stuckB.id, stuckB);

        await store.cleanupProblematicUploads();

        // Should remain readyToPublish (outside scope, not touched).
        final afterClean = box.get(stuckB.id);
        expect(afterClean!.status, equals(UploadStatus.readyToPublish));
      });
    });
  });
}
