// ABOUTME: Unit tests for ClipThumbnailManager.
// ABOUTME: Validates notifier lifecycle, sync logic, and disposal.

import 'dart:async';
import 'dart:io';

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/services/video_editor/clip_thumbnail_manager.dart';
import 'package:openvine/services/video_thumbnail_service.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group(ClipThumbnailManager, () {
    late ClipThumbnailManager manager;

    setUp(() {
      manager = ClipThumbnailManager();
    });

    tearDown(() {
      manager.dispose();
    });

    group('sync', () {
      test('creates notifier for each clip', () {
        final clips = [_createTestClip(id: 'a'), _createTestClip(id: 'b')];

        manager.sync(clips: clips, devicePixelRatio: 1);

        expect(manager['a'], isA<ValueNotifier<List<StripThumbnail>>>());
        expect(manager['b'], isA<ValueNotifier<List<StripThumbnail>>>());
      });

      test('notifiers start with empty list', () {
        final clips = [_createTestClip(id: 'a')];

        manager.sync(clips: clips, devicePixelRatio: 1);

        expect(manager['a'].value, isEmpty);
      });

      test('removes stale notifiers when clips change', () {
        manager.sync(
          clips: [
            _createTestClip(id: 'a'),
            _createTestClip(id: 'b'),
          ],
          devicePixelRatio: 1,
        );

        // Second sync without clip 'b'.
        manager.sync(clips: [_createTestClip(id: 'a')], devicePixelRatio: 1);

        expect(manager['a'], isA<ValueNotifier<List<StripThumbnail>>>());
        expect(() => manager['b'], throwsA(isA<TypeError>()));
      });

      test('does not recreate existing notifiers on re-sync', () {
        final clips = [_createTestClip(id: 'a')];

        manager.sync(clips: clips, devicePixelRatio: 1);
        final notifier1 = manager['a'];

        manager.sync(clips: clips, devicePixelRatio: 1);
        final notifier2 = manager['a'];

        expect(identical(notifier1, notifier2), isTrue);
      });

      test('handles empty clip list', () {
        expect(
          () => manager.sync(clips: [], devicePixelRatio: 1),
          returnsNormally,
        );
      });

      test('handles transition from clips to empty', () {
        manager.sync(clips: [_createTestClip(id: 'a')], devicePixelRatio: 1);

        manager.sync(clips: [], devicePixelRatio: 1);

        expect(() => manager['a'], throwsA(isA<TypeError>()));
      });
    });

    // ---------------------------------------------------------
    // seedFromSource
    // ---------------------------------------------------------

    group('seedFromSource', () {
      test('populates target notifier with time-shifted thumbnails', () {
        final sourceClip = _createTestClip(id: 'src', seconds: 4);
        manager.sync(clips: [sourceClip], devicePixelRatio: 1);

        manager['src'].value = [
          const StripThumbnail(path: '/t/0.jpg', timestamp: Duration.zero),
          const StripThumbnail(
            path: '/t/1.jpg',
            timestamp: Duration(seconds: 1),
          ),
          const StripThumbnail(
            path: '/t/2.jpg',
            timestamp: Duration(seconds: 2),
          ),
          const StripThumbnail(
            path: '/t/3.jpg',
            timestamp: Duration(seconds: 3),
          ),
        ];

        manager.seedFromSource(
          sourceClipId: 'src',
          targetClipId: 'tgt',
          sourceRange: const DurationRange(
            start: Duration(seconds: 1),
            end: Duration(seconds: 3),
          ),
          currentSourcePath: '/video/src.mp4',
        );

        final thumbnails = manager['tgt'].value;
        expect(thumbnails, hasLength(2));
        // 1 s thumbnail shifted by −1 s → 0 s
        expect(thumbnails[0].path, equals('/t/1.jpg'));
        expect(thumbnails[0].timestamp, equals(Duration.zero));
        // 2 s thumbnail shifted by −1 s → 1 s
        expect(thumbnails[1].path, equals('/t/2.jpg'));
        expect(thumbnails[1].timestamp, equals(const Duration(seconds: 1)));
      });

      test('excludes thumbnails outside the requested range', () {
        final sourceClip = _createTestClip(id: 'src', seconds: 10);
        manager.sync(clips: [sourceClip], devicePixelRatio: 1);

        manager['src'].value = [
          const StripThumbnail(path: '/t/0.jpg', timestamp: Duration.zero),
          const StripThumbnail(
            path: '/t/5.jpg',
            timestamp: Duration(seconds: 5),
          ),
          const StripThumbnail(
            path: '/t/9.jpg',
            timestamp: Duration(seconds: 9),
          ),
        ];

        manager.seedFromSource(
          sourceClipId: 'src',
          targetClipId: 'tgt',
          sourceRange: const DurationRange(
            start: Duration(seconds: 4),
            end: Duration(seconds: 6),
          ),
          currentSourcePath: '/video/src.mp4',
        );

        final thumbnails = manager['tgt'].value;
        expect(thumbnails, hasLength(1));
        expect(thumbnails.first.path, equals('/t/5.jpg'));
        expect(thumbnails.first.timestamp, equals(const Duration(seconds: 1)));
      });

      test('is a no-op when source notifier does not exist', () {
        expect(
          () => manager.seedFromSource(
            sourceClipId: 'nonexistent',
            targetClipId: 'tgt',
            sourceRange: const DurationRange(
              start: Duration.zero,
              end: Duration(seconds: 1),
            ),
            currentSourcePath: '/video/src.mp4',
          ),
          returnsNormally,
        );
      });

      test('creates target notifier even when target is not yet in sync', () {
        final sourceClip = _createTestClip(id: 'src', seconds: 2);
        manager.sync(clips: [sourceClip], devicePixelRatio: 1);

        manager['src'].value = [
          const StripThumbnail(path: '/t/0.jpg', timestamp: Duration.zero),
        ];

        manager.seedFromSource(
          sourceClipId: 'src',
          targetClipId: 'tgt',
          sourceRange: const DurationRange(
            start: Duration.zero,
            end: Duration(seconds: 2),
          ),
          currentSourcePath: '/video/src.mp4',
        );

        expect(manager['tgt'], isA<ValueNotifier<List<StripThumbnail>>>());
        expect(manager['tgt'].value, hasLength(1));
      });

      test('seeded notifier value is preserved after re-sync', () {
        // Simulates the window between split (seed) and render complete
        // (path swap). While the target clip still points at the source
        // video (no file path / null), re-syncing must not reset the
        // already-correct seeded thumbnails.
        final sourceClip = _createTestClip(id: 'src', seconds: 4);
        final targetClip = _createTestClip(id: 'tgt', seconds: 2);
        manager.sync(clips: [sourceClip], devicePixelRatio: 1);

        manager['src'].value = [
          const StripThumbnail(path: '/t/0.jpg', timestamp: Duration.zero),
          const StripThumbnail(
            path: '/t/1.jpg',
            timestamp: Duration(seconds: 1),
          ),
        ];

        manager.seedFromSource(
          sourceClipId: 'src',
          targetClipId: 'tgt',
          sourceRange: const DurationRange(
            start: Duration.zero,
            end: Duration(seconds: 2),
          ),
          currentSourcePath: '/video/src.mp4',
        );

        final seededValue = manager['tgt'].value;
        expect(seededValue, hasLength(2));

        // Re-sync with target added. targetClip uses a network URL so
        // _loadThumbnails exits early and never overwrites the notifier.
        manager.sync(clips: [sourceClip, targetClip], devicePixelRatio: 1);

        expect(manager['tgt'].value, equals(seededValue));
      });

      test('seeded target is removed from sync when absent from clip list', () {
        final sourceClip = _createTestClip(id: 'src', seconds: 2);
        manager.sync(clips: [sourceClip], devicePixelRatio: 1);
        manager['src'].value = [
          const StripThumbnail(path: '/t/0.jpg', timestamp: Duration.zero),
        ];

        manager.seedFromSource(
          sourceClipId: 'src',
          targetClipId: 'tgt',
          sourceRange: const DurationRange(
            start: Duration.zero,
            end: Duration(seconds: 2),
          ),
          currentSourcePath: '/video/src.mp4',
        );

        // Sync without the target clip — it should be cleaned up.
        manager.sync(clips: [sourceClip], devicePixelRatio: 1);

        expect(() => manager['tgt'], throwsA(isA<TypeError>()));
      });

      test('borrows source files without copying and protects them from '
          'source cleanup', () async {
        final tempDir = Directory.systemTemp.createTempSync(
          'clip_thumbnail_seed_test_',
        );
        addTearDown(() {
          if (tempDir.existsSync()) {
            tempDir.deleteSync(recursive: true);
          }
        });

        final borrowedThumbnail = File('${tempDir.path}/borrowed.jpg')
          ..writeAsStringSync('borrowed-thumbnail');
        final unborrowedThumbnail = File('${tempDir.path}/unborrowed.jpg')
          ..writeAsStringSync('unborrowed-thumbnail');
        final sourceVideoPath = '${tempDir.path}/source.mp4';

        // The seeded target starts a real subscription on the next sync, so
        // use a fake stream factory to keep that off the native extractor.
        final controllers = <StreamController<List<StripThumbnail>>>[];
        final manager = ClipThumbnailManager(
          stripThumbnailStreamFactory:
              ({
                required String videoPath,
                required String clipId,
                required Duration duration,
                required Size outputSize,
                required int thumbsPerSecond,
                Duration startOffset = Duration.zero,
                List<Duration>? priorityTimestamps,
              }) {
                final controller = StreamController<List<StripThumbnail>>();
                controllers.add(controller);
                return controller.stream;
              },
        );
        addTearDown(() {
          manager.dispose();
          for (final controller in controllers) {
            unawaited(controller.close());
          }
        });

        final sourceClip = _createTestClip(id: 'src', seconds: 4);
        final targetClip = _createFileClip(
          id: 'tgt',
          videoPath: sourceVideoPath,
          seconds: 2,
        );
        manager.sync(clips: [sourceClip], devicePixelRatio: 1);
        manager['src'].value = [
          StripThumbnail(
            path: borrowedThumbnail.path,
            timestamp: const Duration(seconds: 1),
          ),
          StripThumbnail(
            path: unborrowedThumbnail.path,
            timestamp: const Duration(seconds: 3),
          ),
        ];

        manager.seedFromSource(
          sourceClipId: 'src',
          targetClipId: 'tgt',
          sourceRange: const DurationRange(
            start: Duration.zero,
            end: Duration(seconds: 2),
          ),
          currentSourcePath: sourceVideoPath,
        );

        // Borrowed, not copied — the image cache entry decoded for the
        // source tile stays valid, so the new tile paints instantly
        // instead of flashing black on a cold decode.
        final seededPath = manager['tgt'].value.single.path;
        expect(seededPath, equals(borrowedThumbnail.path));

        // Simulate the split lifecycle: the source clip is removed, but
        // the seeded target still points at the source video until render
        // completes. Borrowed files must survive stale source cleanup;
        // files nobody borrowed are deleted.
        manager.sync(clips: [targetClip], devicePixelRatio: 1);
        await Future<void>.delayed(Duration.zero);

        expect(borrowedThumbnail.existsSync(), isTrue);
        expect(unborrowedThumbnail.existsSync(), isFalse);
      });

      test('can preserve source timestamps while filtering a range', () {
        final sourceClip = _createTestClip(id: 'src', seconds: 6);
        manager.sync(clips: [sourceClip], devicePixelRatio: 1);
        manager['src'].value = [
          const StripThumbnail(
            path: '/t/2.jpg',
            timestamp: Duration(seconds: 2),
          ),
          const StripThumbnail(
            path: '/t/3.jpg',
            timestamp: Duration(seconds: 3),
          ),
          const StripThumbnail(
            path: '/t/4.jpg',
            timestamp: Duration(seconds: 4),
          ),
          const StripThumbnail(
            path: '/t/5.jpg',
            timestamp: Duration(seconds: 5),
          ),
        ];

        manager.seedFromSource(
          sourceClipId: 'src',
          targetClipId: 'tgt',
          sourceRange: const DurationRange(
            start: Duration(seconds: 3),
            end: Duration(seconds: 5),
          ),
          timestampOffset: Duration.zero,
          currentSourcePath: '/video/src.mp4',
        );

        final thumbnails = manager['tgt'].value;
        expect(thumbnails, hasLength(2));
        expect(thumbnails[0].path, equals('/t/3.jpg'));
        expect(thumbnails[0].timestamp, equals(const Duration(seconds: 3)));
        expect(thumbnails[1].path, equals('/t/4.jpg'));
        expect(thumbnails[1].timestamp, equals(const Duration(seconds: 4)));
      });
    });

    group('seeded split half subscription', () {
      late List<StreamController<List<StripThumbnail>>> controllers;
      late ClipThumbnailManager fakeStreamManager;
      late Directory tempDir;

      setUp(() {
        controllers = [];
        fakeStreamManager = ClipThumbnailManager(
          stripThumbnailStreamFactory:
              ({
                required String videoPath,
                required String clipId,
                required Duration duration,
                required Size outputSize,
                required int thumbsPerSecond,
                Duration startOffset = Duration.zero,
                List<Duration>? priorityTimestamps,
              }) {
                final controller = StreamController<List<StripThumbnail>>();
                controllers.add(controller);
                return controller.stream;
              },
        );
        tempDir = Directory.systemTemp.createTempSync(
          'clip_thumbnail_path_change_test_',
        );
      });

      tearDown(() {
        fakeStreamManager.dispose();
        for (final controller in controllers) {
          unawaited(controller.close());
        }
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      test(
        'starts the real subscription on the next sync against the shared '
        'source file, holding source-timed seeds until the first fresh batch',
        () async {
          final borrowed = File('${tempDir.path}/borrowed.jpg')
            ..writeAsStringSync('borrowed');
          final sourceVideoPath = '${tempDir.path}/source.mp4';

          final sourceClip = _createFileClip(
            id: 'src',
            videoPath: sourceVideoPath,
            seconds: 10,
          );
          fakeStreamManager.sync(clips: [sourceClip], devicePixelRatio: 1);
          fakeStreamManager['src'].value = [
            StripThumbnail(
              path: borrowed.path,
              timestamp: const Duration(seconds: 4),
            ),
          ];

          // Split at 3 s: a trim-based split, so the end half keeps the shared
          // source file; its seeds stay source-timed (no rebase).
          fakeStreamManager.seedFromSource(
            sourceClipId: 'src',
            targetClipId: 'end',
            sourceRange: const DurationRange(
              start: Duration(seconds: 3),
              end: Duration(seconds: 10),
            ),
            timestampOffset: Duration.zero,
            currentSourcePath: sourceVideoPath,
          );
          expect(
            fakeStreamManager['end'].value.single.timestamp,
            equals(const Duration(seconds: 4)),
          );

          // The very next sync starts the real subscription against the shared
          // source file — no rendered-file swap is coming, so waiting for one
          // would freeze the strip at its seeded density forever. The seeded
          // frame stays visible, source-timed.
          final endClip = _createFileClip(
            id: 'end',
            videoPath: sourceVideoPath,
            seconds: 10,
          );
          fakeStreamManager.sync(clips: [endClip], devicePixelRatio: 1);
          expect(controllers, hasLength(2));
          final held = fakeStreamManager['end'].value.single;
          expect(held.path, equals(borrowed.path));
          expect(held.timestamp, equals(const Duration(seconds: 4)));
          expect(borrowed.existsSync(), isTrue);

          // First fresh batch replaces the seed (same timestamp, so the
          // carried frame is pruned) — the borrowed file survives in the
          // retired source strip for an undo restore.
          final fresh = File('${tempDir.path}/fresh.jpg')
            ..writeAsStringSync('fresh');
          controllers[1].add([
            StripThumbnail(
              path: fresh.path,
              timestamp: const Duration(seconds: 4),
            ),
          ]);
          await pumpEventQueue();

          expect(
            fakeStreamManager['end'].value.single.path,
            equals(fresh.path),
          );
          expect(borrowed.existsSync(), isTrue);
          expect(fresh.existsSync(), isTrue);
        },
      );

      // Regression for the visible thumbnail shuffle after a split: the
      // seeded frames are dense (borrowed from the source strip) while the
      // first fresh batches are sparse. Replacing the seeds wholesale with a
      // sparse batch collapses the strip to a few frames + poster fallbacks,
      // so the tile visibly reshuffles while batches stream in. Carried
      // frames must stay as gap-fillers until fresh frames cover their spot.
      test(
        'keeps dense seeded frames as gap-fillers while sparse fresh '
        'batches stream in, pruning each once a fresh frame lands nearby',
        () async {
          final sourceVideoPath = '${tempDir.path}/source.mp4';

          // Dense source strip: one frame per second at 3.5s..9.5s.
          final borrowedFiles = <File>[];
          final sourceFrames = <StripThumbnail>[];
          for (var i = 0; i < 7; i++) {
            final file = File('${tempDir.path}/borrowed_$i.jpg')
              ..writeAsStringSync('borrowed_$i');
            borrowedFiles.add(file);
            sourceFrames.add(
              StripThumbnail(
                path: file.path,
                timestamp: Duration(milliseconds: 3500 + i * 1000),
              ),
            );
          }

          final sourceClip = _createFileClip(
            id: 'src',
            videoPath: sourceVideoPath,
            seconds: 10,
          );
          fakeStreamManager.sync(clips: [sourceClip], devicePixelRatio: 1);
          fakeStreamManager['src'].value = sourceFrames;

          // Split at 3s: seed the end half, then the next sync starts the real
          // subscription against the shared source file. Seeds stay
          // source-timed at 3.5s..9.5s (no rebase).
          fakeStreamManager.seedFromSource(
            sourceClipId: 'src',
            targetClipId: 'end',
            sourceRange: const DurationRange(
              start: Duration(seconds: 3),
              end: Duration(seconds: 10),
            ),
            timestampOffset: Duration.zero,
            currentSourcePath: sourceVideoPath,
          );
          final endClip = _createFileClip(
            id: 'end',
            videoPath: sourceVideoPath,
            seconds: 10,
          );
          fakeStreamManager.sync(clips: [endClip], devicePixelRatio: 1);
          expect(controllers, hasLength(2));
          expect(fakeStreamManager['end'].value, hasLength(7));

          // Sparse first batch: a single fresh frame at 4.5s (source-timed).
          // Only the seeded frame at that spot may be replaced — the other
          // six must stay so the strip keeps its coverage.
          final fresh1 = File('${tempDir.path}/fresh_1.jpg')
            ..writeAsStringSync('fresh_1');
          controllers[1].add([
            StripThumbnail(
              path: fresh1.path,
              timestamp: const Duration(milliseconds: 4500),
            ),
          ]);
          await pumpEventQueue();

          final afterBatch1 = fakeStreamManager['end'].value;
          expect(afterBatch1, hasLength(7));
          expect(afterBatch1.map((t) => t.path), contains(fresh1.path));
          // Every borrowed file survives — even the displaced seed's — since
          // the retired source strip still references them for undo.
          expect(borrowedFiles[1].existsSync(), isTrue);
          expect(borrowedFiles[0].existsSync(), isTrue);
          expect(borrowedFiles[6].existsSync(), isTrue);
          // Timestamps stay sorted for the strip's binary slot search.
          for (var i = 1; i < afterBatch1.length; i++) {
            expect(
              afterBatch1[i].timestamp >= afterBatch1[i - 1].timestamp,
              isTrue,
            );
          }

          // Stream completes: remaining carried frames are pruned so the
          // final strip holds only fresh frames. The borrowed files stay on
          // disk — the retired source strip references them for undo.
          final fresh2 = File('${tempDir.path}/fresh_2.jpg')
            ..writeAsStringSync('fresh_2');
          controllers[1].add([
            StripThumbnail(
              path: fresh1.path,
              timestamp: const Duration(milliseconds: 4500),
            ),
            StripThumbnail(
              path: fresh2.path,
              timestamp: const Duration(milliseconds: 7500),
            ),
          ]);
          await pumpEventQueue();
          await controllers[1].close();
          await pumpEventQueue();

          expect(
            fakeStreamManager['end'].value.map((t) => t.path).toList(),
            equals([fresh1.path, fresh2.path]),
          );
          for (final file in borrowedFiles) {
            expect(file.existsSync(), isTrue);
          }
          expect(fresh1.existsSync(), isTrue);
          expect(fresh2.existsSync(), isTrue);
        },
      );

      test(
        'accumulating batches never delete still-referenced files',
        () async {
          final first = File('${tempDir.path}/first.jpg')
            ..writeAsStringSync('first');
          final second = File('${tempDir.path}/second.jpg')
            ..writeAsStringSync('second');

          fakeStreamManager.sync(
            clips: [
              _createFileClip(id: 'a', videoPath: '${tempDir.path}/a.mp4'),
            ],
            devicePixelRatio: 1,
          );

          controllers.single.add([
            StripThumbnail(path: first.path, timestamp: Duration.zero),
          ]);
          await pumpEventQueue();
          controllers.single.add([
            StripThumbnail(path: first.path, timestamp: Duration.zero),
            StripThumbnail(
              path: second.path,
              timestamp: const Duration(seconds: 1),
            ),
          ]);
          await pumpEventQueue();

          expect(fakeStreamManager['a'].value, hasLength(2));
          expect(first.existsSync(), isTrue);
          expect(second.existsSync(), isTrue);
        },
      );

      test(
        'restart keeps a dropped frame whose file a sibling clip still shows',
        () async {
          final shared = File('${tempDir.path}/shared.jpg')
            ..writeAsStringSync('shared');
          final freshA = File('${tempDir.path}/fresh_a.jpg')
            ..writeAsStringSync('fresh-a');

          fakeStreamManager.sync(
            clips: [
              _createFileClip(id: 'a', videoPath: '${tempDir.path}/a.mp4'),
              _createFileClip(id: 'b', videoPath: '${tempDir.path}/b.mp4'),
            ],
            devicePixelRatio: 1,
          );
          expect(controllers, hasLength(2));

          // Both clips end up showing the same file (an overlapping
          // borrow). A fresh batch on 'a' that drops the shared path must
          // not delete the file while 'b' still references it.
          controllers[0].add([
            StripThumbnail(path: shared.path, timestamp: Duration.zero),
          ]);
          controllers[1].add([
            StripThumbnail(path: shared.path, timestamp: Duration.zero),
          ]);
          await pumpEventQueue();

          controllers[0].add([
            StripThumbnail(path: freshA.path, timestamp: Duration.zero),
          ]);
          await pumpEventQueue();

          expect(fakeStreamManager['a'].value.single.path, equals(freshA.path));
          expect(shared.existsSync(), isTrue);
          expect(freshA.existsSync(), isTrue);
        },
      );

      test(
        'START half: seeds held source-timed, subscription starts on the '
        'next sync, first fresh batch supersedes the seed (files kept for undo)',
        () async {
          final borrowed = File('${tempDir.path}/start_borrowed.jpg')
            ..writeAsStringSync('borrowed');
          final sourceVideoPath = '${tempDir.path}/source.mp4';

          final sourceClip = _createFileClip(
            id: 'src',
            videoPath: sourceVideoPath,
            seconds: 10,
          );
          fakeStreamManager.sync(clips: [sourceClip], devicePixelRatio: 1);
          fakeStreamManager['src'].value = [
            StripThumbnail(
              path: borrowed.path,
              timestamp: const Duration(seconds: 1),
            ),
          ];

          // Split at 3 s: the start half keeps the shared source file and
          // begins at zero, so the seed keeps its source-timed timestamp.
          fakeStreamManager.seedFromSource(
            sourceClipId: 'src',
            targetClipId: 'start',
            sourceRange: const DurationRange(
              start: Duration.zero,
              end: Duration(seconds: 3),
            ),
            timestampOffset: Duration.zero,
            currentSourcePath: sourceVideoPath,
          );
          expect(
            fakeStreamManager['start'].value.single.timestamp,
            equals(const Duration(seconds: 1)),
          );

          // The next sync starts the real subscription against the shared
          // source file; the seed is held unchanged (source-timed).
          final startClip = _createFileClip(
            id: 'start',
            videoPath: sourceVideoPath,
          );
          fakeStreamManager.sync(clips: [startClip], devicePixelRatio: 1);
          expect(controllers, hasLength(2));
          final held = fakeStreamManager['start'].value.single;
          expect(held.path, equals(borrowed.path));
          expect(held.timestamp, equals(const Duration(seconds: 1)));
          expect(borrowed.existsSync(), isTrue);

          final fresh = File('${tempDir.path}/fresh_start.jpg')
            ..writeAsStringSync('fresh');
          controllers[1].add([
            StripThumbnail(
              path: fresh.path,
              timestamp: const Duration(seconds: 1),
            ),
          ]);
          await pumpEventQueue();

          expect(
            fakeStreamManager['start'].value.single.path,
            equals(fresh.path),
          );
          // The borrowed file survives in the retired source strip for undo.
          expect(borrowed.existsSync(), isTrue);
          expect(fresh.existsSync(), isTrue);
        },
      );

      test('seeds the target empty when the source has no thumbnails yet, then '
          'still starts the subscription on the next sync', () async {
        final sourceVideoPath = '${tempDir.path}/empty_source.mp4';

        final sourceClip = _createFileClip(
          id: 'src',
          videoPath: sourceVideoPath,
          seconds: 10,
        );
        fakeStreamManager.sync(clips: [sourceClip], devicePixelRatio: 1);
        expect(controllers, hasLength(1));

        // Source frames haven't been extracted yet — seeding is
        // best-effort: the target is created empty but still marked seeded.
        fakeStreamManager.seedFromSource(
          sourceClipId: 'src',
          targetClipId: 'end',
          sourceRange: const DurationRange(
            start: Duration(seconds: 3),
            end: Duration(seconds: 10),
          ),
          timestampOffset: Duration.zero,
          currentSourcePath: sourceVideoPath,
        );
        expect(fakeStreamManager['end'].value, isEmpty);

        // The next sync starts the real subscription against the shared
        // source file even though the seed was empty.
        final endClip = _createFileClip(
          id: 'end',
          videoPath: sourceVideoPath,
          seconds: 10,
        );
        fakeStreamManager.sync(clips: [endClip], devicePixelRatio: 1);
        expect(controllers, hasLength(2));
      });

      // Regression: a native extraction failure mid-stream errors the
      // subscription with only a partial fresh set delivered. That partial
      // set must not be treated as complete — the carried gap-fillers stay
      // on screen (and on disk), and a later retire/restore starts a fresh
      // subscription instead of parking the truncated strip as final.
      test('keeps carried gap-fillers and re-extracts on restore when the '
          'stream is truncated by an extraction error', () async {
        final dense = [
          for (var i = 0; i < 4; i++)
            File('${tempDir.path}/dense_$i.jpg')..writeAsStringSync('d$i'),
        ];
        final clip = _createFileClip(
          id: 'a',
          videoPath: '${tempDir.path}/a.mp4',
          seconds: 4,
        );
        fakeStreamManager.sync(clips: [clip], devicePixelRatio: 1);
        controllers.single.add([
          for (var i = 0; i < 4; i++)
            StripThumbnail(
              path: dense[i].path,
              timestamp: Duration(milliseconds: 500 + i * 1000),
            ),
        ]);
        await pumpEventQueue();

        // The clip's file is re-rendered — a restart carries the dense
        // frames as gap-fillers while the new extraction streams in.
        final rerenderedClip = _createFileClip(
          id: 'a',
          videoPath: '${tempDir.path}/a_rerendered.mp4',
          seconds: 4,
        );
        fakeStreamManager.sync(clips: [rerenderedClip], devicePixelRatio: 1);
        expect(controllers, hasLength(2));

        final fresh = File('${tempDir.path}/fresh.jpg')
          ..writeAsStringSync('fresh');
        controllers[1].add([
          StripThumbnail(
            path: fresh.path,
            timestamp: const Duration(milliseconds: 500),
          ),
        ]);
        await pumpEventQueue();
        expect(fakeStreamManager['a'].value, hasLength(4));

        // Decoder failure truncates the stream after the sparse batch.
        controllers[1].addError(StateError('decoder died'));
        await controllers[1].close();
        await pumpEventQueue();

        // The carried gap-fillers survive — the strip must not collapse
        // to the single fresh frame — and their files stay on disk.
        final afterError = fakeStreamManager['a'].value;
        expect(afterError, hasLength(4));
        expect(afterError.map((t) => t.path), contains(fresh.path));
        for (final file in dense.skip(1)) {
          expect(file.existsSync(), isTrue);
        }

        // Remove and restore: the strip was truncated, not complete, so
        // a fresh subscription starts to fill the missing frames.
        fakeStreamManager.sync(clips: [], devicePixelRatio: 1);
        fakeStreamManager.sync(clips: [rerenderedClip], devicePixelRatio: 1);
        expect(fakeStreamManager['a'].value, hasLength(4));
        expect(controllers, hasLength(3));
      });
    });

    group('retired strips', () {
      late List<StreamController<List<StripThumbnail>>> controllers;
      late ClipThumbnailManager fakeStreamManager;
      late Directory tempDir;

      setUp(() {
        controllers = [];
        fakeStreamManager = ClipThumbnailManager(
          stripThumbnailStreamFactory:
              ({
                required String videoPath,
                required String clipId,
                required Duration duration,
                required Size outputSize,
                required int thumbsPerSecond,
                Duration startOffset = Duration.zero,
                List<Duration>? priorityTimestamps,
              }) {
                final controller = StreamController<List<StripThumbnail>>();
                controllers.add(controller);
                return controller.stream;
              },
        );
        tempDir = Directory.systemTemp.createTempSync(
          'clip_thumbnail_retired_test_',
        );
      });

      tearDown(() {
        fakeStreamManager.dispose();
        for (final controller in controllers) {
          unawaited(controller.close());
        }
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      File writeFrame(String name) =>
          File('${tempDir.path}/$name.jpg')..writeAsStringSync(name);

      test('restores a complete strip instantly without re-extraction when the '
          'clip id returns with the same file (undo)', () async {
        final frame = writeFrame('a_frame');
        final clipA = _createFileClip(
          id: 'a',
          videoPath: '${tempDir.path}/a.mp4',
        );

        fakeStreamManager.sync(clips: [clipA], devicePixelRatio: 1);
        controllers.single.add([
          StripThumbnail(
            path: frame.path,
            timestamp: const Duration(seconds: 1),
          ),
        ]);
        await pumpEventQueue();
        // Stream completes — the strip is at full density.
        await controllers.single.close();
        await pumpEventQueue();

        // Clip 'a' is replaced (e.g. by split halves) — its strip retires.
        final clipB = _createFileClip(
          id: 'b',
          videoPath: '${tempDir.path}/b.mp4',
        );
        fakeStreamManager.sync(clips: [clipB], devicePixelRatio: 1);
        expect(frame.existsSync(), isTrue);

        // Undo: 'a' returns with the same file. The strip is restored
        // instantly and — being complete — no new subscription starts.
        fakeStreamManager.sync(clips: [clipA, clipB], devicePixelRatio: 1);
        expect(fakeStreamManager['a'].value.single.path, equals(frame.path));
        expect(controllers, hasLength(2));

        // Subsequent syncs must not re-subscribe either.
        fakeStreamManager.sync(clips: [clipA, clipB], devicePixelRatio: 1);
        expect(controllers, hasLength(2));
      });

      test('re-extracts a restored complete strip when the clip returns with a '
          'wider trim than its frames were generated for', () async {
        final frame = writeFrame('widened_frame');
        final trimmed = _createFileClip(
          id: 'a',
          videoPath: '${tempDir.path}/a.mp4',
          seconds: 60,
          trimStart: const Duration(seconds: 20),
          trimEnd: const Duration(milliseconds: 33700),
        );

        fakeStreamManager.sync(clips: [trimmed], devicePixelRatio: 1);
        controllers.single.add([
          StripThumbnail(
            path: frame.path,
            timestamp: const Duration(seconds: 22),
          ),
        ]);
        await pumpEventQueue();
        await controllers.single.close();
        await pumpEventQueue();

        // 'a' leaves the timeline and returns with the trim dragged wide
        // open. Its retired frames only cover the old window, so being
        // "complete" is not enough to skip re-extraction.
        fakeStreamManager.sync(clips: [], devicePixelRatio: 1);
        fakeStreamManager.sync(
          clips: [
            _createFileClip(
              id: 'a',
              videoPath: '${tempDir.path}/a.mp4',
              seconds: 60,
            ),
          ],
          devicePixelRatio: 1,
        );

        expect(controllers, hasLength(2));
        expect(fakeStreamManager['a'].value.single.path, equals(frame.path));
      });

      test(
        'restores a partial strip and starts a gap-filling subscription',
        () async {
          final frame = writeFrame('partial_frame');
          final clipA = _createFileClip(
            id: 'a',
            videoPath: '${tempDir.path}/a.mp4',
          );

          fakeStreamManager.sync(clips: [clipA], devicePixelRatio: 1);
          controllers.single.add([
            StripThumbnail(
              path: frame.path,
              timestamp: const Duration(seconds: 1),
            ),
          ]);
          await pumpEventQueue();
          // Stream still open — the strip is incomplete when 'a' retires.

          fakeStreamManager.sync(clips: [], devicePixelRatio: 1);
          fakeStreamManager.sync(clips: [clipA], devicePixelRatio: 1);

          // Frames restored instantly, plus a fresh subscription for gaps.
          expect(fakeStreamManager['a'].value.single.path, equals(frame.path));
          expect(controllers, hasLength(2));
        },
      );

      test(
        'drops the retired strip when the id returns with a different file',
        () async {
          final frame = writeFrame('stale_frame');
          final clipA = _createFileClip(
            id: 'a',
            videoPath: '${tempDir.path}/a.mp4',
          );

          fakeStreamManager.sync(clips: [clipA], devicePixelRatio: 1);
          controllers.single.add([
            StripThumbnail(
              path: frame.path,
              timestamp: const Duration(seconds: 1),
            ),
          ]);
          await pumpEventQueue();

          fakeStreamManager.sync(clips: [], devicePixelRatio: 1);

          // 'a' returns pointing at a different video — the retired frames
          // would show stale content, so the strip starts cold and the old
          // frame file is deleted.
          final swappedA = _createFileClip(
            id: 'a',
            videoPath: '${tempDir.path}/a_other.mp4',
          );
          fakeStreamManager.sync(clips: [swappedA], devicePixelRatio: 1);

          expect(fakeStreamManager['a'].value, isEmpty);
          expect(controllers, hasLength(2));
          expect(frame.existsSync(), isFalse);
        },
      );

      test('evicts the oldest retired strip beyond the cap and deletes its '
          'unreferenced files', () async {
        // Retire 9 strips in sequence — one more than the cap of 8.
        final frames = <File>[];
        for (var i = 0; i < 9; i++) {
          final frame = writeFrame('evict_$i');
          frames.add(frame);
          final clip = _createFileClip(
            id: 'clip_$i',
            videoPath: '${tempDir.path}/clip_$i.mp4',
          );
          fakeStreamManager.sync(clips: [clip], devicePixelRatio: 1);
          fakeStreamManager['clip_$i'].value = [
            StripThumbnail(path: frame.path, timestamp: Duration.zero),
          ];
        }
        // Retire the 9th strip too.
        fakeStreamManager.sync(clips: [], devicePixelRatio: 1);

        // The oldest strip fell off the FIFO; the newest 8 survive.
        expect(frames.first.existsSync(), isFalse);
        for (final frame in frames.skip(1)) {
          expect(frame.existsSync(), isTrue);
        }
      });
    });

    group('pauseAll / resumeAll', () {
      late StreamController<List<StripThumbnail>> streamController;
      late int pauses;
      late int resumes;
      late ClipThumbnailManager fakeStreamManager;

      const firstBatch = [
        StripThumbnail(path: '/t/a0.jpg', timestamp: Duration.zero),
      ];
      const secondBatch = [
        StripThumbnail(path: '/t/a0.jpg', timestamp: Duration.zero),
        StripThumbnail(path: '/t/a1.jpg', timestamp: Duration(seconds: 1)),
      ];

      setUp(() {
        pauses = 0;
        resumes = 0;
        streamController = StreamController<List<StripThumbnail>>(
          onPause: () => pauses++,
          onResume: () => resumes++,
        );
        fakeStreamManager = ClipThumbnailManager(
          stripThumbnailStreamFactory:
              ({
                required String videoPath,
                required String clipId,
                required Duration duration,
                required Size outputSize,
                required int thumbsPerSecond,
                Duration startOffset = Duration.zero,
                List<Duration>? priorityTimestamps,
              }) => streamController.stream,
        );
      });

      tearDown(() {
        fakeStreamManager.dispose();
        // Not awaited: close() only completes once a listener receives the
        // done event, and the idle test never attaches one.
        unawaited(streamController.close());
      });

      void syncFileClip() {
        fakeStreamManager.sync(
          clips: [_createFileClip(id: 'a', videoPath: '/video/a.mp4')],
          devicePixelRatio: 1,
        );
      }

      test('are safe on an idle manager with no active subscriptions', () {
        expect(manager.pauseAll, returnsNormally);
        expect(manager.resumeAll, returnsNormally);
      });

      test(
        'pauseAll holds thumbnail delivery and resumeAll releases it',
        () async {
          syncFileClip();
          streamController.add(firstBatch);
          await pumpEventQueue();
          expect(fakeStreamManager['a'].value, hasLength(1));

          fakeStreamManager.pauseAll();
          await pumpEventQueue();
          expect(pauses, equals(1));

          streamController.add(secondBatch);
          await pumpEventQueue();
          // Buffered while paused — the notifier still shows the first batch.
          expect(fakeStreamManager['a'].value, hasLength(1));

          fakeStreamManager.resumeAll();
          await pumpEventQueue();
          expect(resumes, equals(1));
          // The held batch arrives after resume — pausing is lossless.
          expect(fakeStreamManager['a'].value, hasLength(2));
        },
      );

      test('subscriptions created while paused start paused', () async {
        fakeStreamManager.pauseAll();
        syncFileClip();
        await pumpEventQueue();
        expect(pauses, equals(1));

        streamController.add(firstBatch);
        await pumpEventQueue();
        expect(fakeStreamManager['a'].value, isEmpty);

        fakeStreamManager.resumeAll();
        await pumpEventQueue();
        expect(fakeStreamManager['a'].value, hasLength(1));
      });

      test('the route pause and the startup hold are independent', () async {
        syncFileClip();
        streamController.add(firstBatch);
        await pumpEventQueue();
        expect(fakeStreamManager['a'].value, hasLength(1));

        // Two independent hold reasons; the second must not re-pause.
        fakeStreamManager.pauseAll();
        fakeStreamManager.holdForPlayerStartup();
        await pumpEventQueue();
        expect(pauses, equals(1));

        streamController.add(secondBatch);
        await pumpEventQueue();
        expect(fakeStreamManager['a'].value, hasLength(1));

        // Releasing one reason while the other still holds must not resume.
        fakeStreamManager.releasePlayerStartupHold();
        await pumpEventQueue();
        expect(resumes, equals(0));
        expect(fakeStreamManager['a'].value, hasLength(1));

        // Only when the last reason clears does delivery resume, losslessly.
        fakeStreamManager.resumeAll();
        await pumpEventQueue();
        expect(resumes, equals(1));
        expect(fakeStreamManager['a'].value, hasLength(2));
      });
    });

    group('dispose', () {
      test('can be called on empty manager', () {
        final localManager = ClipThumbnailManager();

        // Should not throw.
        localManager.dispose();
      });

      test('can be called after sync', () {
        final localManager = ClipThumbnailManager();
        localManager.sync(
          clips: [_createTestClip(id: 'a')],
          devicePixelRatio: 1,
        );

        // Should not throw.
        localManager.dispose();
      });

      test('deletes a borrowed seed file once when two notifiers share it', () {
        final tempDir = Directory.systemTemp.createTempSync(
          'clip_thumbnail_dispose_test_',
        );
        addTearDown(() {
          if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
        });
        final borrowed = File('${tempDir.path}/borrowed.jpg')
          ..writeAsStringSync('borrowed');

        final localManager = ClipThumbnailManager();
        localManager.sync(
          clips: [
            _createFileClip(id: 'src', videoPath: '${tempDir.path}/src.mp4'),
          ],
          devicePixelRatio: 1,
        );
        localManager['src'].value = [
          StripThumbnail(path: borrowed.path, timestamp: Duration.zero),
        ];
        // The start half borrows the same source frame file, so both
        // notifiers reference it — dispose must delete it once and
        // swallow the second (already-gone) deleteSync.
        localManager.seedFromSource(
          sourceClipId: 'src',
          targetClipId: 'start',
          sourceRange: const DurationRange(
            start: Duration.zero,
            end: Duration(seconds: 1),
          ),
          currentSourcePath: '${tempDir.path}/src.mp4',
        );
        expect(localManager['start'].value.single.path, equals(borrowed.path));

        expect(localManager.dispose, returnsNormally);
        expect(borrowed.existsSync(), isFalse);
      });
    });

    // =========================================================
    // Trim window sizing
    // =========================================================

    group('trim window', () {
      late List<_StripRequest> requests;
      late List<StreamController<List<StripThumbnail>>> controllers;
      late ClipThumbnailManager windowManager;
      late Directory tempDir;

      setUp(() {
        requests = [];
        controllers = [];
        windowManager = ClipThumbnailManager(
          stripThumbnailStreamFactory:
              ({
                required String videoPath,
                required String clipId,
                required Duration duration,
                required Size outputSize,
                required int thumbsPerSecond,
                Duration startOffset = Duration.zero,
                List<Duration>? priorityTimestamps,
              }) {
                requests.add(
                  _StripRequest(startOffset: startOffset, duration: duration),
                );
                final controller = StreamController<List<StripThumbnail>>();
                controllers.add(controller);
                return controller.stream;
              },
        );
        tempDir = Directory.systemTemp.createTempSync(
          'clip_thumbnail_window_test_',
        );
      });

      tearDown(() {
        windowManager.dispose();
        for (final controller in controllers) {
          unawaited(controller.close());
        }
        if (tempDir.existsSync()) {
          tempDir.deleteSync(recursive: true);
        }
      });

      /// A 60 s library import seeded with a trim down to the 6.3 s
      /// recording budget: visible source range `[20 s, 26.3 s]`.
      DivineVideoClip importClip({
        Duration trimStart = const Duration(seconds: 20),
        Duration trimEnd = const Duration(milliseconds: 33700),
      }) => _createFileClip(
        id: 'import',
        videoPath: '${tempDir.path}/import.mp4',
        seconds: 60,
        trimStart: trimStart,
        trimEnd: trimEnd,
      );

      test('asks only for the trimmed window plus a second of slack', () {
        final clip = importClip();

        windowManager.sync(clips: [clip], devicePixelRatio: 1);

        // Not the untrimmed 60 s source: at 13 thumbs/s that hit the
        // generator's 500-frame cap for footage the strip cannot show.
        expect(requests, hasLength(1));
        expect(
          requests.single.startOffset,
          equals(const Duration(seconds: 19)),
        );
        expect(
          requests.single.end,
          equals(const Duration(milliseconds: 27300)),
        );
        expect(requests.single.duration, lessThan(clip.duration));
      });

      test('covers the whole source when the clip is untrimmed', () {
        final clip = _createFileClip(
          id: 'import',
          videoPath: '${tempDir.path}/import.mp4',
          seconds: 6,
        );

        windowManager.sync(clips: [clip], devicePixelRatio: 1);

        expect(requests.single.startOffset, equals(Duration.zero));
        expect(requests.single.duration, equals(clip.duration));
      });

      test('does not restart while the trim stays inside the slack', () {
        windowManager.sync(clips: [importClip()], devicePixelRatio: 1);

        // Half a second of handle drag outwards on each side — still inside
        // the padded window, so the in-flight extraction is left alone.
        windowManager.sync(
          clips: [
            importClip(
              trimStart: const Duration(milliseconds: 19500),
              trimEnd: const Duration(milliseconds: 33200),
            ),
          ],
          devicePixelRatio: 1,
        );

        expect(requests, hasLength(1));
      });

      test('restarts against the widened window when the trim reaches past '
          'the generated range', () {
        windowManager.sync(clips: [importClip()], devicePixelRatio: 1);

        windowManager.sync(
          clips: [importClip(trimStart: const Duration(seconds: 10))],
          devicePixelRatio: 1,
        );

        expect(requests, hasLength(2));
        expect(requests.last.startOffset, equals(const Duration(seconds: 9)));
        expect(requests.last.end, equals(const Duration(milliseconds: 27300)));
      });

      test('restarts when the trim window moves to a different part of the '
          'source', () {
        windowManager.sync(clips: [importClip()], devicePixelRatio: 1);

        // Same 6.3 s length, shifted 20 s later in the source.
        windowManager.sync(
          clips: [
            importClip(
              trimStart: const Duration(seconds: 40),
              trimEnd: const Duration(milliseconds: 13700),
            ),
          ],
          devicePixelRatio: 1,
        );

        expect(requests, hasLength(2));
        expect(requests.last.startOffset, equals(const Duration(seconds: 39)));
        expect(requests.last.end, equals(const Duration(milliseconds: 47300)));
      });

      test(
        'keeps the frames it already has while the wider window loads',
        () async {
          final frame = File('${tempDir.path}/loaded.jpg')
            ..writeAsStringSync('loaded');
          windowManager.sync(clips: [importClip()], devicePixelRatio: 1);
          controllers.single.add([
            StripThumbnail(
              path: frame.path,
              timestamp: const Duration(seconds: 22),
            ),
          ]);
          await pumpEventQueue();
          expect(windowManager['import'].value, hasLength(1));

          windowManager.sync(
            clips: [importClip(trimStart: const Duration(seconds: 10))],
            devicePixelRatio: 1,
          );

          // The restart must not blank the strip — the already-extracted
          // frame stays on screen until fresh batches cover its slot.
          expect(requests, hasLength(2));
          expect(windowManager['import'].value.single.path, equals(frame.path));
          expect(frame.existsSync(), isTrue);
        },
      );
    });
  });

  // =========================================================
  // DurationRange
  // =========================================================

  group(DurationRange, () {
    test('stores start and end', () {
      const range = DurationRange(
        start: Duration(seconds: 1),
        end: Duration(seconds: 5),
      );

      expect(range.start, equals(const Duration(seconds: 1)));
      expect(range.end, equals(const Duration(seconds: 5)));
    });

    test('allows zero-length range', () {
      const range = DurationRange(
        start: Duration(seconds: 2),
        end: Duration(seconds: 2),
      );

      expect(range.start, equals(range.end));
    });
  });
}

/// Creates a test clip whose [EditorVideo] has no local file so
/// [ClipThumbnailManager._loadThumbnails] exits early without
/// triggering a platform channel call.
DivineVideoClip _createTestClip({required String id, int seconds = 3}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.network('https://example.com/$id.mp4'),
    duration: Duration(seconds: seconds),
    recordedAt: DateTime(2025),
    originalAspectRatio: 9 / 16,
    targetAspectRatio: .vertical,
  );
}

DivineVideoClip _createFileClip({
  required String id,
  required String videoPath,
  int seconds = 3,
  Duration trimStart = Duration.zero,
  Duration trimEnd = Duration.zero,
}) {
  return DivineVideoClip(
    id: id,
    video: EditorVideo.file(videoPath),
    duration: Duration(seconds: seconds),
    recordedAt: DateTime(2025),
    originalAspectRatio: 9 / 16,
    targetAspectRatio: .vertical,
    trimStart: trimStart,
    trimEnd: trimEnd,
  );
}

/// One [StripThumbnailStreamFactory] invocation, so tests can assert what
/// range the manager actually asked the extractor for.
class _StripRequest {
  const _StripRequest({required this.startOffset, required this.duration});

  final Duration startOffset;
  final Duration duration;

  Duration get end => startOffset + duration;
}
