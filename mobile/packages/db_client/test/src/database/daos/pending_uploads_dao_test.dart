// ABOUTME: Unit tests for PendingUploadsDao with domain model conversion.
// ABOUTME: Tests upsertUpload, getUpload, getPendingUploads, updateStatus,
// ABOUTME: watchUploads.

import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:models/models.dart';
import 'package:test/test.dart';

void main() {
  late AppDatabase database;
  late PendingUploadsDao dao;
  late String tempDbPath;

  /// Valid 64-char hex pubkey for testing
  const testPubkey =
      '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';

  /// Valid 64-char hex event ID for testing
  const testEventId =
      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

  /// Helper to create a test upload
  PendingUpload createTestUpload({
    String id = 'upload_1',
    String localVideoPath = '/path/to/video.mp4',
    String nostrPubkey = testPubkey,
    UploadStatus status = UploadStatus.pending,
    DateTime? createdAt,
    String? title,
    String? description,
    List<String>? hashtags,
    String? nostrEventId,
    double? uploadProgress,
  }) {
    return PendingUpload(
      id: id,
      localVideoPath: localVideoPath,
      nostrPubkey: nostrPubkey,
      status: status,
      createdAt: createdAt ?? DateTime(2024, 1, 1, 12),
      title: title,
      description: description,
      hashtags: hashtags,
      nostrEventId: nostrEventId,
      uploadProgress: uploadProgress,
    );
  }

  setUp(() async {
    final tempDir = Directory.systemTemp.createTempSync('dao_test_');
    tempDbPath = '${tempDir.path}/test.db';

    database = AppDatabase.test(NativeDatabase(File(tempDbPath)));
    dao = database.pendingUploadsDao;
  });

  tearDown(() async {
    await database.close();
    final file = File(tempDbPath);
    if (file.existsSync()) {
      file.deleteSync();
    }
    final dir = Directory(tempDbPath).parent;
    if (dir.existsSync()) {
      dir.deleteSync(recursive: true);
    }
  });

  group('PendingUploadsDao', () {
    group('upsertUpload', () {
      test('inserts new upload', () async {
        final upload = createTestUpload(
          title: 'My Video',
          description: 'A cool video',
          hashtags: ['flutter', 'nostr'],
        );

        await dao.upsertUpload(upload);

        final result = await dao.getUpload('upload_1');
        expect(result, isNotNull);
        expect(result!.id, equals('upload_1'));
        expect(result.localVideoPath, equals('/path/to/video.mp4'));
        expect(result.nostrPubkey, equals(testPubkey));
        expect(result.status, equals(UploadStatus.pending));
        expect(result.title, equals('My Video'));
        expect(result.description, equals('A cool video'));
        expect(result.hashtags, equals(['flutter', 'nostr']));
      });

      test('updates existing upload with same ID', () async {
        final upload1 = createTestUpload(
          uploadProgress: 0,
        );
        await dao.upsertUpload(upload1);

        final upload2 = createTestUpload(
          status: UploadStatus.uploading,
          uploadProgress: 0.5,
        );
        await dao.upsertUpload(upload2);

        final result = await dao.getUpload('upload_1');
        expect(result, isNotNull);
        expect(result!.status, equals(UploadStatus.uploading));
        expect(result.uploadProgress, equals(0.5));

        // Verify only one entry exists
        final all = await dao.getAllUploads();
        expect(all, hasLength(1));
      });

      test('handles all optional fields', () async {
        final upload = PendingUpload(
          id: 'upload_1',
          localVideoPath: '/path/to/video.mp4',
          nostrPubkey: testPubkey,
          status: UploadStatus.published,
          createdAt: DateTime(2024),
          cloudinaryPublicId: 'cloud_123',
          videoId: 'video_456',
          cdnUrl: 'https://cdn.example.com/video.mp4',
          uploadProgress: 1,
          thumbnailPath: '/path/to/thumb.jpg',
          title: 'Test Video',
          description: 'Test description',
          hashtags: const ['test'],
          nostrEventId: testEventId,
          completedAt: DateTime(2024, 1, 1, 12, 30),
          retryCount: 3,
          videoWidth: 1080,
          videoHeight: 1920,
          videoDurationMillis: 15000,
          proofManifestJson: '{"proof": true}',
          streamingMp4Url: 'https://stream.example.com/video.mp4',
          streamingHlsUrl: 'https://stream.example.com/video.m3u8',
          fallbackUrl: 'https://fallback.example.com/video.mp4',
        );

        await dao.upsertUpload(upload);
        final result = await dao.getUpload('upload_1');

        expect(result, isNotNull);
        expect(result!.cloudinaryPublicId, equals('cloud_123'));
        expect(result.videoId, equals('video_456'));
        expect(result.cdnUrl, equals('https://cdn.example.com/video.mp4'));
        expect(result.thumbnailPath, equals('/path/to/thumb.jpg'));
        expect(result.nostrEventId, equals(testEventId));
        expect(result.retryCount, equals(3));
        expect(result.videoWidth, equals(1080));
        expect(result.videoHeight, equals(1920));
        expect(result.videoDurationMillis, equals(15000));
        expect(result.proofManifestJson, equals('{"proof": true}'));
        expect(
          result.streamingMp4Url,
          equals('https://stream.example.com/video.mp4'),
        );
        expect(
          result.streamingHlsUrl,
          equals('https://stream.example.com/video.m3u8'),
        );
        expect(
          result.fallbackUrl,
          equals('https://fallback.example.com/video.mp4'),
        );
      });
    });

    group('getUpload', () {
      test('returns null for non-existent ID', () async {
        final result = await dao.getUpload('nonexistent');
        expect(result, isNull);
      });

      test('converts database row to domain model', () async {
        await dao.upsertUpload(createTestUpload());

        final result = await dao.getUpload('upload_1');
        expect(result, isA<PendingUpload>());
      });
    });

    group('getPendingUploads', () {
      test('returns only uploads not published or failed', () async {
        await dao.upsertUpload(
          createTestUpload(id: 'pending'),
        );
        await dao.upsertUpload(
          createTestUpload(id: 'uploading', status: UploadStatus.uploading),
        );
        await dao.upsertUpload(
          createTestUpload(id: 'processing', status: UploadStatus.processing),
        );
        await dao.upsertUpload(
          createTestUpload(id: 'published', status: UploadStatus.published),
        );
        await dao.upsertUpload(
          createTestUpload(id: 'failed', status: UploadStatus.failed),
        );

        final results = await dao.getPendingUploads();

        expect(results, hasLength(3));
        expect(
          results.map((r) => r.id),
          containsAll(['pending', 'uploading', 'processing']),
        );
        expect(results.map((r) => r.id), isNot(contains('published')));
        expect(results.map((r) => r.id), isNot(contains('failed')));
      });

      test('returns uploads sorted by createdAt ascending', () async {
        await dao.upsertUpload(
          createTestUpload(
            id: 'first',
            createdAt: DateTime(2024),
          ),
        );
        await dao.upsertUpload(
          createTestUpload(
            id: 'third',
            createdAt: DateTime(2024, 1, 3),
          ),
        );
        await dao.upsertUpload(
          createTestUpload(
            id: 'second',
            createdAt: DateTime(2024, 1, 2),
          ),
        );

        final results = await dao.getPendingUploads();

        expect(results[0].id, equals('first'));
        expect(results[1].id, equals('second'));
        expect(results[2].id, equals('third'));
      });

      test('returns empty list when no pending uploads', () async {
        await dao.upsertUpload(
          createTestUpload(id: 'published', status: UploadStatus.published),
        );

        final results = await dao.getPendingUploads();
        expect(results, isEmpty);
      });
    });

    group('getAllUploads', () {
      test('returns all uploads sorted by createdAt descending', () async {
        await dao.upsertUpload(
          createTestUpload(
            id: 'first',
            createdAt: DateTime(2024),
          ),
        );
        await dao.upsertUpload(
          createTestUpload(
            id: 'third',
            createdAt: DateTime(2024, 1, 3),
          ),
        );
        await dao.upsertUpload(
          createTestUpload(
            id: 'second',
            createdAt: DateTime(2024, 1, 2),
          ),
        );

        final results = await dao.getAllUploads();

        expect(results, hasLength(3));
        expect(results[0].id, equals('third'));
        expect(results[1].id, equals('second'));
        expect(results[2].id, equals('first'));
      });

      test('returns empty list when no uploads exist', () async {
        final results = await dao.getAllUploads();
        expect(results, isEmpty);
      });
    });

    group('getUploadsByStatus', () {
      test('filters by status', () async {
        await dao.upsertUpload(
          createTestUpload(id: 'pending1'),
        );
        await dao.upsertUpload(
          createTestUpload(id: 'pending2'),
        );
        await dao.upsertUpload(
          createTestUpload(id: 'uploading', status: UploadStatus.uploading),
        );

        final results = await dao.getUploadsByStatus(UploadStatus.pending);

        expect(results, hasLength(2));
        expect(results.every((r) => r.status == UploadStatus.pending), isTrue);
      });

      test('returns empty list when no uploads match status', () async {
        await dao.upsertUpload(
          createTestUpload(id: 'pending'),
        );

        final results = await dao.getUploadsByStatus(UploadStatus.failed);
        expect(results, isEmpty);
      });
    });

    group('updateStatus', () {
      test('updates status for existing upload', () async {
        await dao.upsertUpload(
          createTestUpload(),
        );

        final result = await dao.updateStatus(
          'upload_1',
          UploadStatus.uploading,
          uploadProgress: 0.25,
        );

        expect(result, isTrue);
        final upload = await dao.getUpload('upload_1');
        expect(upload!.status, equals(UploadStatus.uploading));
        expect(upload.uploadProgress, equals(0.25));
      });

      test('updates error message when provided', () async {
        await dao.upsertUpload(
          createTestUpload(status: UploadStatus.uploading),
        );

        await dao.updateStatus(
          'upload_1',
          UploadStatus.failed,
          errorMessage: 'Network error',
        );

        final upload = await dao.getUpload('upload_1');
        expect(upload!.status, equals(UploadStatus.failed));
        expect(upload.errorMessage, equals('Network error'));
      });

      test('returns false for non-existent upload', () async {
        final result = await dao.updateStatus(
          'nonexistent',
          UploadStatus.uploading,
        );
        expect(result, isFalse);
      });
    });

    group('deleteUpload', () {
      test('deletes upload by ID', () async {
        await dao.upsertUpload(createTestUpload());
        await dao.upsertUpload(createTestUpload(id: 'upload_2'));

        final deleted = await dao.deleteUpload('upload_1');

        expect(deleted, equals(1));
        final remaining = await dao.getAllUploads();
        expect(remaining, hasLength(1));
        expect(remaining.first.id, equals('upload_2'));
      });

      test('returns 0 for non-existent upload', () async {
        final deleted = await dao.deleteUpload('nonexistent');
        expect(deleted, equals(0));
      });
    });

    group('deleteCompleted', () {
      test('deletes only published and failed uploads', () async {
        await dao.upsertUpload(
          createTestUpload(id: 'pending'),
        );
        await dao.upsertUpload(
          createTestUpload(id: 'published', status: UploadStatus.published),
        );
        await dao.upsertUpload(
          createTestUpload(id: 'failed', status: UploadStatus.failed),
        );

        final deleted = await dao.deleteCompleted();

        expect(deleted, equals(2));
        final remaining = await dao.getAllUploads();
        expect(remaining, hasLength(1));
        expect(remaining.first.id, equals('pending'));
      });

      test('returns 0 when no completed uploads', () async {
        await dao.upsertUpload(
          createTestUpload(),
        );

        final deleted = await dao.deleteCompleted();
        expect(deleted, equals(0));
      });
    });

    group('watchAllUploads', () {
      test('emits initial list', () async {
        await dao.upsertUpload(createTestUpload());
        await dao.upsertUpload(createTestUpload(id: 'upload_2'));

        final stream = dao.watchAllUploads();
        final results = await stream.first;

        expect(results, hasLength(2));
      });

      test('emits sorted by createdAt descending', () async {
        await dao.upsertUpload(
          createTestUpload(id: 'old', createdAt: DateTime(2024)),
        );
        await dao.upsertUpload(
          createTestUpload(id: 'new', createdAt: DateTime(2024, 1, 2)),
        );

        final stream = dao.watchAllUploads();
        final results = await stream.first;

        expect(results[0].id, equals('new'));
        expect(results[1].id, equals('old'));
      });
    });

    group('watchPendingUploads', () {
      test('emits only pending uploads', () async {
        await dao.upsertUpload(
          createTestUpload(id: 'pending'),
        );
        await dao.upsertUpload(
          createTestUpload(id: 'published', status: UploadStatus.published),
        );

        final stream = dao.watchPendingUploads();
        final results = await stream.first;

        expect(results, hasLength(1));
        expect(results.first.id, equals('pending'));
      });

      test('emits sorted by createdAt ascending', () async {
        await dao.upsertUpload(
          createTestUpload(
            id: 'second',
            createdAt: DateTime(2024, 1, 2),
          ),
        );
        await dao.upsertUpload(
          createTestUpload(
            id: 'first',
            createdAt: DateTime(2024),
          ),
        );

        final stream = dao.watchPendingUploads();
        final results = await stream.first;

        expect(results[0].id, equals('first'));
        expect(results[1].id, equals('second'));
      });
    });

    group('clearAll', () {
      test('deletes all uploads', () async {
        await dao.upsertUpload(createTestUpload());
        await dao.upsertUpload(createTestUpload(id: 'upload_2'));

        final deleted = await dao.clearAll();

        expect(deleted, equals(2));
        final results = await dao.getAllUploads();
        expect(results, isEmpty);
      });

      test('returns 0 when table is empty', () async {
        final deleted = await dao.clearAll();
        expect(deleted, equals(0));
      });
    });
  });
}
