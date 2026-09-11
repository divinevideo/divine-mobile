import 'dart:convert';
import 'dart:io';

import 'package:db_client/db_client.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:media_cache/media_cache.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/constants/storage_cache_constants.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/models/stop_motion_clip_frame.dart';
import 'package:openvine/models/storage_footprint.dart';
import 'package:openvine/services/clip_library_service.dart';
import 'package:openvine/services/storage_management_service.dart';
import 'package:openvine/services/temp_render_janitor.dart';
import 'package:path/path.dart' as p;
import 'package:pro_video_editor/pro_video_editor.dart' as editor;
import 'package:shared_preferences/shared_preferences.dart';

class _MockCache extends Mock implements MediaCacheManager {}

/// Whether [dir] can still be listed, i.e. the mode bits actually took.
bool _isReadable(Directory dir) {
  try {
    dir.listSync();
    return true;
  } on FileSystemException {
    return false;
  }
}

class _MockClipLibrary extends Mock implements ClipLibraryService {}

void main() {
  group(StorageManagementService, () {
    late _MockCache videoCache;
    late _MockCache imageCache;
    late _MockClipLibrary clipLibrary;
    late AppDatabase db;
    late Directory temp;
    late Directory docs;
    late SharedPreferences prefs;
    late StorageManagementService service;

    // Fixed so a file's age relative to the sweep's grace period is a property
    // of the test, not of how long the suite took to reach it.
    final now = DateTime(2026, 9, 11, 12);

    StorageManagementService buildService({
      Future<int> Function(File file)? fileLengthProvider,
      Set<String> Function()? protectedPaths,
      Future<Directory> Function()? applicationSupportDirectoryProvider,
      Future<Directory> Function()? applicationCacheDirectoryProvider,
    }) => StorageManagementService(
      videoCache: videoCache,
      imageCache: imageCache,
      clipLibrary: clipLibrary,
      clipsDao: db.clipsDao,
      draftsDao: db.draftsDao,
      prefs: prefs,
      temporaryDirectoryProvider: () async => temp,
      documentsDirectoryProvider: () async => docs,
      applicationSupportDirectoryProvider: applicationSupportDirectoryProvider,
      applicationCacheDirectoryProvider: applicationCacheDirectoryProvider,
      fileLengthProvider: fileLengthProvider,
      now: () => now,
      protectedPaths: protectedPaths,
    );

    setUp(() async {
      videoCache = _MockCache();
      imageCache = _MockCache();
      clipLibrary = _MockClipLibrary();
      db = AppDatabase.test(NativeDatabase.memory());
      temp = Directory.systemTemp.createTempSync('storage_temp_');
      docs = Directory.systemTemp.createTempSync('storage_docs_');
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();
      when(() => videoCache.clearCache()).thenAnswer((_) async {});
      when(() => imageCache.clearCache()).thenAnswer((_) async {});
      when(() => imageCache.maxCacheSizeBytes).thenReturn(256 * 1024 * 1024);
      service = buildService();
    });

    tearDown(() async {
      await db.close();
      if (temp.existsSync()) temp.deleteSync(recursive: true);
      if (docs.existsSync()) docs.deleteSync(recursive: true);
    });

    File writeFile(String path, int bytes, {Duration? age}) {
      final file = File(path)..parent.createSync(recursive: true);
      file.writeAsBytesSync(List<int>.filled(bytes, 0));
      if (age != null) file.setLastModifiedSync(now.subtract(age));
      return file;
    }

    DivineVideoClip clip(String id, String videoPath) => DivineVideoClip(
      id: id,
      video: editor.EditorVideo.file(File(videoPath)),
      duration: const Duration(seconds: 3),
      recordedAt: DateTime(2024),
      targetAspectRatio: model.AspectRatio.square,
      originalAspectRatio: 1,
    );

    DivineVideoClip stopMotionClip(String id, List<String> framePaths) =>
        DivineVideoClip(
          id: id,
          stopMotionFrames: [
            for (final path in framePaths)
              StopMotionClipFrame(
                path: path,
                duration: const Duration(milliseconds: 167),
              ),
          ],
          duration: const Duration(milliseconds: 167),
          recordedAt: DateTime(2024),
          targetAspectRatio: model.AspectRatio.vertical,
          originalAspectRatio: 9 / 16,
        );

    group('cacheSizeBytes', () {
      test('sums cache dirs, seams and temp renders, ignoring other '
          'files', () async {
        writeFile('${temp.path}/openvine_video_cache/a.mp4', 100);
        writeFile('${temp.path}/openvine_image_cache/b.jpg', 50);
        writeFile('${docs.path}/transition_seams/s.mp4', 30);
        writeFile('${temp.path}/watermarked_1.mp4', 20);
        writeFile('${temp.path}/merged_2.mp4', 10);
        writeFile('${temp.path}/merged_audio_3.wav', 40);
        writeFile('${temp.path}/unrelated.txt', 5);
        writeFile('${docs.path}/my_clip.mp4', 999);

        expect(await service.cacheSizeBytes(), 100 + 50 + 30 + 20 + 10 + 40);
      });

      test('returns zero when nothing is cached', () async {
        expect(await service.cacheSizeBytes(), 0);
      });

      test('reports per-category usage against matching budgets', () async {
        await prefs.setInt(kCacheLimitPrefKey, 3 * 1024);
        writeFile('${temp.path}/openvine_video_cache/a.mp4', 100);
        writeFile('${temp.path}/openvine_image_cache/b.jpg', 50);
        writeFile('${docs.path}/transition_seams/s.mp4', 30);
        writeFile('${temp.path}/merged_2.mp4', 10);

        final usage = await service.cacheUsage();

        expect(usage.totalBytes, 190);
        expect(
          usage.video,
          const CacheUsageCategory(usedBytes: 100, limitBytes: 3 * 1024),
        );
        expect(
          usage.images,
          const CacheUsageCategory(
            usedBytes: 50,
            limitBytes: 256 * 1024 * 1024,
          ),
        );
        expect(
          usage.transitionSeams,
          const CacheUsageCategory(
            usedBytes: 30,
            limitBytes: kSeamCacheLimitBytes,
          ),
        );
        expect(usage.tempRenders, const CacheUsageCategory(usedBytes: 10));
      });

      test('counts the boundary frames beside the transition seams', () async {
        writeFile('${docs.path}/transition_seams/s.mp4', 30);
        writeFile('${docs.path}/transition_frames/c_h_0_0_head.jpg', 12);

        final usage = await service.cacheUsage();

        // Nothing cleared transition_frames before #7641; it is the same
        // kind of regenerable preview as the seams and lives beside them.
        expect(usage.transitionSeams.usedBytes, 42);
      });

      test('keeps scanning temp renders when one vanishes mid-walk', () async {
        final vanished = writeFile('${temp.path}/watermarked_vanished.mp4', 20);
        final merged = writeFile('${temp.path}/merged_2.mp4', 10);
        final audio = writeFile('${temp.path}/merged_audio_3.wav', 40);
        service = buildService(
          fileLengthProvider: (file) async {
            if (file.path == vanished.path) {
              throw const FileSystemException('vanished');
            }
            return file.length();
          },
        );

        final usage = await service.cacheUsage();

        expect(
          usage.tempRenders.usedBytes,
          merged.lengthSync() + audio.lengthSync(),
        );
      });
    });

    group('clearCaches', () {
      // The issue behind #7641: only three of the editor's temp patterns were
      // counted and cleared, so the routine clear reported a fraction of what
      // the temp directory held and reclaimed as little. Every pattern and
      // scratch directory the editor writes must round-trip through both.
      test('counts and clears every temp render pattern and scratch '
          'directory', () async {
        final files = <File>[];
        var expected = 0;
        for (final (index, pattern) in TempRenderPatterns.all.indexed) {
          final bytes = 10 + index;
          files.add(
            writeFile(
              '${temp.path}/${pattern.prefix}$index${pattern.extension}',
              bytes,
            ),
          );
          expected += bytes;
        }
        for (final (index, dir) in TempRenderDirectories.all.indexed) {
          final bytes = 100 + index;
          files.add(writeFile('${temp.path}/$dir/scratch_$index.bin', bytes));
          expected += bytes;
        }
        final unrelated = writeFile('${temp.path}/unrelated.txt', 5);
        final unrelatedDir = writeFile('${temp.path}/keep_me/inside.bin', 7);

        expect(await service.cacheSizeBytes(), expected);

        await service.clearCaches();

        for (final file in files) {
          expect(file.existsSync(), isFalse, reason: '${file.path} kept');
        }
        expect(unrelated.existsSync(), isTrue);
        expect(unrelatedDir.existsSync(), isTrue);
        expect(await service.cacheSizeBytes(), 0);
      });

      test('deletes the transition boundary frames with the seams', () async {
        final seam = writeFile('${docs.path}/transition_seams/s.mp4', 30);
        final frame = writeFile(
          '${docs.path}/transition_frames/c_h_0_0_head.jpg',
          12,
        );
        final userClip = writeFile('${docs.path}/my_clip.mp4', 999);

        await service.clearCaches();

        expect(seam.existsSync(), isFalse);
        expect(frame.existsSync(), isFalse);
        expect(userClip.existsSync(), isTrue);
      });

      test('clears both caches, deletes temp renders and seams, keeps other '
          'files', () async {
        final watermark = writeFile('${temp.path}/watermarked_1.mp4', 20);
        final merged = writeFile('${temp.path}/merged_2.mp4', 10);
        final audio = writeFile('${temp.path}/merged_audio_3.wav', 40);
        final seam = writeFile('${docs.path}/transition_seams/s.mp4', 30);
        final unrelated = writeFile('${temp.path}/unrelated.txt', 5);
        final userClip = writeFile('${docs.path}/my_clip.mp4', 999);

        await service.clearCaches();

        verify(() => videoCache.clearCache()).called(1);
        verify(() => imageCache.clearCache()).called(1);
        expect(watermark.existsSync(), isFalse);
        expect(merged.existsSync(), isFalse);
        expect(audio.existsSync(), isFalse);
        expect(seam.existsSync(), isFalse);
        expect(unrelated.existsSync(), isTrue, reason: 'non-render temp kept');
        expect(userClip.existsSync(), isTrue, reason: 'user clip untouched');
      });

      test('does not throw when nothing exists to clear', () async {
        await expectLater(service.clearCaches(), completes);
      });

      test('deletes orphaned files left behind in the cache dirs', () async {
        // clearCache() (mocked here, as in flutter_cache_manager) removes only
        // DB-tracked entries; these leaked files are what inflated the cache.
        final orphanVideo = writeFile(
          '${temp.path}/openvine_video_cache/leaked.mp4',
          100,
        );
        final orphanImage = writeFile(
          '${temp.path}/openvine_image_cache/leaked.jpg',
          50,
        );

        await service.clearCaches();

        expect(orphanVideo.existsSync(), isFalse);
        expect(orphanImage.existsSync(), isFalse);
        expect(await service.cacheSizeBytes(), 0);
      });

      test('keeps temp renders referenced by pending uploads', () async {
        final active = writeFile('${temp.path}/merged_active.mp4', 100);
        final stale = writeFile('${temp.path}/merged_stale.mp4', 50);
        service = buildService(protectedPaths: () => {active.path});

        expect(await service.cacheSizeBytes(), 50);

        await service.clearCaches();

        expect(active.existsSync(), isTrue);
        expect(stale.existsSync(), isFalse);
        expect(await service.cacheSizeBytes(), 0);
      });
    });

    group('documentsUsage', () {
      const stale = StorageManagementService.orphanGraceAge;
      final old = stale + const Duration(minutes: 1);
      final fresh = stale - const Duration(minutes: 1);

      Future<void> insertLibraryClip({
        required String id,
        String? filePath,
        String? thumbnailPath,
        Map<String, Object?> data = const {},
      }) => db.clipsDao.upsertClip(
        id: id,
        orderIndex: 0,
        durationMs: 1000,
        recordedAt: DateTime(2026),
        data: json.encode(data),
        filePath: filePath,
        thumbnailPath: thumbnailPath,
      );

      Future<void> insertDraft({
        required String id,
        String? renderedFilePath,
        List<String> ownedFileBasenames = const [],
      }) => db.draftsDao.saveDraftWithClips(
        id: id,
        title: 'Draft $id',
        description: '',
        publishStatus: 'draft',
        createdAt: DateTime(2026),
        lastModified: DateTime(2026),
        renderedFilePath: renderedFilePath,
        renderedThumbnailPath: null,
        customThumbnailPath: null,
        data: json.encode({draftOwnedFileBasenamesKey: ownedFileBasenames}),
        clipDataList: const [],
      );

      test('splits the documents root into content and orphans', () async {
        // Referenced through the indexed clip columns.
        writeFile('${docs.path}/VID_1.mp4', 100, age: old);
        writeFile('${docs.path}/thumbnail_1.jpg', 10, age: old);
        await insertLibraryClip(
          id: 'clip',
          filePath: 'VID_1.mp4',
          thumbnailPath: 'thumbnail_1.jpg',
        );
        // Referenced only inside the clip JSON blob, the way a stop-motion
        // still or a ghost frame is, and stored with a container path from
        // a previous install — only the basename can be expected to match.
        writeFile('${docs.path}/still_1.png', 20, age: old);
        await insertLibraryClip(
          id: 'stop_motion',
          data: {
            'stopMotionFrames': [
              {'path': '/old/container/Documents/still_1.png'},
            ],
          },
        );
        // Referenced through a draft's indexed column and its layer manifest.
        writeFile('${docs.path}/divine_render.mp4', 200, age: old);
        writeFile('${docs.path}/layer.mp4', 30, age: old);
        await insertDraft(
          id: 'draft',
          renderedFilePath: 'divine_render.mp4',
          ownedFileBasenames: ['layer.mp4'],
        );
        // Orphans: nothing points at these and they are past the grace age.
        writeFile('${docs.path}/divine_abandoned.mp4', 1000, age: old);
        writeFile('${docs.path}/ghost_2.jpg', 5, age: old);
        // Too fresh to judge — a render that has not been given a row yet.
        writeFile('${docs.path}/divine_in_flight.mp4', 400, age: fresh);
        // Not media the app writes; never swept whatever the database says.
        writeFile('${docs.path}/legacy.hive', 50, age: old);
        // Subdirectories are content wholesale (sounds, voice-overs) …
        writeFile('${docs.path}/voice_over_recordings/take.m4a', 60, age: old);
        // … except the regenerable caches, which cacheUsage() owns.
        writeFile('${docs.path}/transition_seams/s.mp4', 70, age: old);
        writeFile('${docs.path}/transition_frames/f.jpg', 80, age: old);

        final usage = await service.documentsUsage();

        expect(usage.orphanedFileCount, 2);
        expect(usage.orphanedBytes, 1005);
        expect(
          usage.contentBytes,
          100 + 10 + 20 + 200 + 30 + 400 + 50 + 60,
          reason:
              'referenced, fresh, non-media and subdirectory bytes are '
              'content; cache directories are not counted at all',
        );
      });

      test('protects pending upload inputs by basename', () async {
        // The pending upload recorded the path under the previous container;
        // the file now sits under the current one.
        final upload = writeFile(
          '${docs.path}/divine_queued.mp4',
          300,
          age: old,
        );
        final thumbnail = writeFile('${docs.path}/thumb_q.jpg', 3, age: old);
        service = buildService(
          protectedPaths: () => {
            '/old/container/Documents/${p.basename(upload.path)}',
            '/old/container/Documents/${p.basename(thumbnail.path)}',
          },
        );

        final usage = await service.documentsUsage();

        expect(usage.orphanedFileCount, 0);
        expect(usage.contentBytes, 303);
      });

      test('reports nothing when the documents directory is missing', () async {
        docs.deleteSync(recursive: true);

        expect(await service.documentsUsage(), DocumentsUsage.empty);
      });
    });

    group('removeOrphanedFiles', () {
      const stale = StorageManagementService.orphanGraceAge;
      final old = stale + const Duration(minutes: 1);
      final fresh = stale - const Duration(minutes: 1);

      test('deletes only the orphans and reports what it freed', () async {
        final referenced = writeFile('${docs.path}/VID_1.mp4', 100, age: old);
        await db.clipsDao.upsertClip(
          id: 'clip',
          orderIndex: 0,
          durationMs: 1000,
          recordedAt: DateTime(2026),
          data: '{}',
          filePath: 'VID_1.mp4',
          thumbnailPath: null,
        );
        final orphanVideo = writeFile(
          '${docs.path}/divine_abandoned.mp4',
          1000,
          age: old,
        );
        final orphanFrame = writeFile('${docs.path}/ghost_2.jpg', 5, age: old);
        final inFlight = writeFile(
          '${docs.path}/divine_now.mp4',
          400,
          age: fresh,
        );
        final nonMedia = writeFile('${docs.path}/legacy.hive', 50, age: old);
        final sound = writeFile(
          '${docs.path}/library_audio_imports/track.mp3',
          60,
          age: old,
        );

        final freed = await service.removeOrphanedFiles();

        expect(freed, 1005);
        expect(orphanVideo.existsSync(), isFalse);
        expect(orphanFrame.existsSync(), isFalse);
        expect(referenced.existsSync(), isTrue);
        expect(inFlight.existsSync(), isTrue);
        expect(nonMedia.existsSync(), isTrue);
        expect(sound.existsSync(), isTrue);
        expect((await service.documentsUsage()).orphanedFileCount, 0);
      });

      test('keeps a file that gained a row since it was measured', () async {
        final file = writeFile('${docs.path}/divine_late.mp4', 10, age: old);
        expect((await service.documentsUsage()).orphanedFileCount, 1);

        // The row lands between the readout and the tap on "remove".
        await db.draftsDao.upsertDraft(
          id: 'late',
          title: 'Late',
          description: '',
          publishStatus: 'draft',
          createdAt: DateTime(2026),
          lastModified: DateTime(2026),
          renderedFilePath: 'divine_late.mp4',
          renderedThumbnailPath: null,
          data: '{}',
        );

        expect(await service.removeOrphanedFiles(), 0);
        expect(file.existsSync(), isTrue);
      });
    });

    group('findBrokenClips', () {
      test('returns only clips whose backing file is missing', () async {
        final present = writeFile('${docs.path}/present.mp4', 10);
        final good = clip('good', present.path);
        final broken = clip('broken', '${docs.path}/gone.mp4');
        when(clipLibrary.getAllClips).thenAnswer((_) async => [good, broken]);

        final result = await service.findBrokenClips();

        expect(result.map((c) => c.id), equals(['broken']));
      });

      test(
        'keeps a stop-motion set with at least one surviving still',
        () async {
          final present = writeFile('${docs.path}/frame_present.png', 10);
          final salvageable = stopMotionClip('salvageable', [
            present.path,
            '${docs.path}/frame_gone.png',
          ]);
          final brokenVideo = clip('broken', '${docs.path}/gone.mp4');
          when(
            clipLibrary.getAllClips,
          ).thenAnswer((_) async => [salvageable, brokenVideo]);

          final result = await service.findBrokenClips();

          // One still is missing but another survives, so the set is
          // salvageable — only the video clip with a gone file is broken.
          expect(result.map((c) => c.id), equals(['broken']));
        },
      );

      test('flags a stop-motion set whose stills are all gone', () async {
        final dead = stopMotionClip('dead', [
          '${docs.path}/gone_a.png',
          '${docs.path}/gone_b.png',
        ]);
        when(clipLibrary.getAllClips).thenAnswer((_) async => [dead]);

        final result = await service.findBrokenClips();

        expect(result.map((c) => c.id), equals(['dead']));
      });
    });

    group('removeBrokenClips', () {
      test('hard-deletes each given clip', () async {
        when(() => clipLibrary.hardDelete(any())).thenAnswer((_) async {});
        final broken = [
          clip('a', '${docs.path}/gone_a.mp4'),
          clip('b', '${docs.path}/gone_b.mp4'),
        ];

        await service.removeBrokenClips(broken);

        verify(() => clipLibrary.hardDelete('a')).called(1);
        verify(() => clipLibrary.hardDelete('b')).called(1);
      });
    });

    group('cache limit', () {
      const oneGb = 1024 * 1024 * 1024;

      test('videoCacheLimitBytes returns the default when unset', () {
        expect(service.videoCacheLimitBytes(), kCacheLimitDefaultBytes);
      });

      test('videoCacheLimitBytes returns the stored value', () async {
        await prefs.setInt(kCacheLimitPrefKey, 3 * oneGb);
        expect(service.videoCacheLimitBytes(), 3 * oneGb);
      });

      test('setVideoCacheLimit persists, applies and force-trims', () async {
        when(
          () => videoCache.enforceCacheLimits(force: any(named: 'force')),
        ).thenAnswer((_) async {});

        await service.setVideoCacheLimit(oneGb);

        expect(prefs.getInt(kCacheLimitPrefKey), oneGb);
        verify(() => videoCache.maxCacheSizeBytes = oneGb).called(1);
        verify(() => videoCache.enforceCacheLimits(force: true)).called(1);
      });

      test('setVideoCacheLimit clamps below the minimum', () async {
        when(
          () => videoCache.enforceCacheLimits(force: any(named: 'force')),
        ).thenAnswer((_) async {});

        await service.setVideoCacheLimit(1);

        expect(prefs.getInt(kCacheLimitPrefKey), kCacheLimitMinBytes);
      });
    });

    group('measureFootprint', () {
      late Directory appSupport;
      late Directory caches;

      StorageManagementService footprintService({Directory? cacheDirectory}) =>
          buildService(
            applicationSupportDirectoryProvider: () async => appSupport,
            applicationCacheDirectoryProvider: () async =>
                cacheDirectory ?? caches,
          );

      setUp(() {
        appSupport = Directory.systemTemp.createTempSync('storage_support_');
        caches = Directory.systemTemp.createTempSync('storage_caches_');
      });

      tearDown(() {
        if (appSupport.existsSync()) appSupport.deleteSync(recursive: true);
        if (caches.existsSync()) caches.deleteSync(recursive: true);
      });

      test('totals each root and ranks its children largest first', () async {
        writeFile('${docs.path}/divine_small.mp4', 100);
        writeFile('${docs.path}/divine_big.mp4', 900);
        writeFile('${docs.path}/transition_seams/seam.jpg', 400);
        writeFile('${appSupport.path}/openvine/database/divine_db.db', 700);

        final footprint = await footprintService().measureFootprint();
        final documents = footprint.roots.firstWhere(
          (root) => root.label == 'Documents',
        );

        expect(documents.totalBytes, 1400);
        expect(documents.largestChildren.map((child) => child.name), [
          'divine_big.mp4',
          'transition_seams',
          'divine_small.mp4',
        ]);
        expect(documents.largestChildren.first.isDirectory, isFalse);
        expect(documents.largestChildren[1].isDirectory, isTrue);
        expect(footprint.totalBytes, 2100);
      });

      test('counts the durable database no in-app action clears', () async {
        writeFile('${appSupport.path}/openvine/database/divine_db.db', 4096);

        final footprint = await footprintService().measureFootprint();

        // cacheUsage() reports only what clearCaches() reclaims, so the
        // database is invisible there — this is what makes the diagnostic
        // able to explain an unaccounted-for footprint.
        expect(await footprintService().cacheSizeBytes(), 0);
        expect(footprint.totalBytes, 4096);
      });

      test(
        'reports a root shared by two providers once, naming both',
        () async {
          writeFile('${temp.path}/leftover.mp4', 500);

          // Android resolves the temporary and cache directories to the same
          // getCacheDir(); counting both would double the reported total.
          final footprint = await footprintService(
            cacheDirectory: temp,
          ).measureFootprint();

          final shared = footprint.roots.where(
            (root) => root.path == temp.path,
          );
          expect(shared, hasLength(1));
          expect(footprint.totalBytes, 500);
          // Both names appear, so a report with one root fewer than another
          // platform's reads as a merge rather than as a failed walk.
          expect(shared.single.label, 'Caches + Temporary');
        },
      );

      test('report text carries the totals and the biggest entries', () async {
        writeFile('${docs.path}/divine_big.mp4', 2048);

        final report = (await footprintService().measureFootprint())
            .toReportText();

        expect(report, contains('Total: 2.0 KB (2048 bytes)'));
        expect(report, contains('Documents: 2.0 KB (2048 bytes)'));
        expect(report, contains('divine_big.mp4'));
      });

      test('report accounts for the entries it did not list', () async {
        for (var i = 0; i < 15; i++) {
          writeFile('${docs.path}/divine_$i.mp4', 100 + i);
        }

        final report = (await footprintService().measureFootprint())
            .toReportText();

        // 15 children, 12 listed: the three smallest (100, 101, 102) are
        // left out, so the report has to name them or the listed sizes look
        // like they should add up to the root total and do not.
        expect(report, contains('(3 smaller entries not listed)'));
        expect(report, contains('303 B\t(3 smaller entries not listed)'));
      });

      test('report marks a root when part of its walk was incomplete', () {
        const footprint = StorageFootprint(
          roots: [
            StorageFootprintRoot(
              label: 'Documents',
              path: '/documents',
              totalBytes: 0,
              largestChildren: [],
              childCount: 0,
              isIncomplete: true,
            ),
          ],
        );

        final report = footprint.toReportText();

        expect(report, contains('Documents: 0 B (0 bytes)'));
        expect(report, contains('(walk incomplete; totals may be low)'));
        expect(report, isNot(contains('(empty)')));
      });

      test('an unreadable subdirectory does not zero its readable '
          'siblings', () async {
        if (Platform.isWindows) {
          markTestSkipped(
            'POSIX permission bits are needed to make a '
            'directory unreadable.',
          );
          return;
        }

        writeFile('${docs.path}/media/locked/inside.mp4', 10);
        writeFile('${docs.path}/media/keep.mp4', 400);
        writeFile('${docs.path}/media/sub/also_keep.mp4', 600);
        final locked = Directory('${docs.path}/media/locked');

        Process.runSync('chmod', ['000', locked.path]);
        // Restore before the group tearDown, which cannot delete an
        // unreadable directory. addTearDown runs first.
        addTearDown(() => Process.runSync('chmod', ['755', locked.path]));
        if (_isReadable(locked)) {
          markTestSkipped(
            'Running with permissions that ignore the mode '
            'bits (e.g. as root), so the walk cannot be made to fail.',
          );
          return;
        }

        final footprint = await footprintService().measureFootprint();
        final documents = footprint.roots.firstWhere(
          (root) => root.label == 'Documents',
        );

        // A single recursive listing surfaces the whole tree through one
        // stream, so the throw on `locked` used to abandon everything not
        // yet visited and report zero for the entire subtree (#7642).
        expect(documents.totalBytes, 1000);
      });
    });
  });
}
